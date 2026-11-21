class_name WorldLevel
extends Node3D
## Fase de percurso com movimento livre: uma trilha por um vale de floresta morta, com clareiras
## de combate (barreira de raios até vencer), fogueiras de checkpoint, patrulhas e um santuário no fim.
## Inimigos dão ouro e XP; quanto maior o nível do herói, mais inimigos surgem e mais fortes eles são.
## Morrer volta à última fogueira (perde metade do ouro ainda não guardado). Chegar ao santuário vence.

signal zone_started(index: int, total: int)
signal zone_cleared(index: int)
signal checkpoint_lit(checkpoint: Checkpoint)
signal player_respawned
signal completed
signal finished(victory: bool, gold_earned: int)

const TITLE_COLOR := Color(0.95, 0.9, 0.7)
const LEVEL_UP_COLOR := Color(1.0, 0.85, 0.35)
const DANGER_COLOR := Color(1.0, 0.4, 0.35)

@export var waypoints: PackedVector3Array = PackedVector3Array()
@export var start_delay: float = 0.4
@export var show_element_select: bool = true
@export var capture_mouse: bool = true
@export var element_select_scene: PackedScene
@export var result_scene: PackedScene
@export var pause_scene: PackedScene
@export var rewards: RewardData
@export var sword_upgrade: UpgradeData
@export var armor_upgrade: UpgradeData
@export var layout_seed: int = 5
@export var shrine_radius: float = 4.5
@export var respawn_delay: float = 2.0
@export var zone_clear_heal_fraction: float = 0.25

@export_group("Patrulhas")
@export var patrol_entry: SpawnEntry
## Distâncias ao longo da trilha onde ficam grupos de patrulha.
@export var patrol_progress: Array[float] = []
@export var patrol_base_size: int = 1
@export var patrol_size_per_level: float = 0.34
@export var patrol_max_size: int = 3

var zones: Array[CombatZone] = []
var checkpoints: Array[Checkpoint] = []
var run_gold: int = 0
var gold_earned: int = 0
var is_complete: bool = false

var _active_zone: CombatZone
var _zone_generation: int = 0
var _finished: bool = false
var _started: bool = false
var _respawn_point: Vector3 = Vector3.ZERO
var _pause_menu: PauseMenu

@onready var player: Player = %Player
@onready var camera: ThirdPersonCamera = %Camera
@onready var spawner: WaveSpawner = %WaveSpawner
@onready var terrain: TrailTerrain = %Terrain
@onready var route: Path3D = %Route
@onready var _props: PropScatter = %Props
@onready var _hud: GameHUD = %HUD
@onready var _zones_root: Node3D = %Zones
@onready var _checkpoints_root: Node3D = %Checkpoints
@onready var _shrine: Node3D = %Shrine
@onready var _environment: WorldEnvironment = %WorldEnvironment


func _ready() -> void:
	Hitstop.reset()
	_build_route()
	for child: Node in _zones_root.get_children():
		if child is CombatZone:
			zones.append(child)
	zones.sort_custom(func(a: CombatZone, b: CombatZone) -> bool: return a.route_progress < b.route_progress)
	for child: Node in _checkpoints_root.get_children():
		if child is Checkpoint:
			checkpoints.append(child)
	var centers: Array[Vector3] = []
	for zone: CombatZone in zones:
		zone.global_position = route_point(zone.route_progress)
		centers.append(zone.global_position)
	terrain.build(centers)
	var keep_out := centers.duplicate()
	keep_out.append(route_point(route_length()))
	keep_out.append(route_point(0.0))
	_props.scatter(keep_out)
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed
	for zone: CombatZone in zones:
		zone.setup(terrain, route_direction(zone.route_progress), rng)
	for checkpoint: Checkpoint in checkpoints:
		var side := route_direction(checkpoint.route_progress).cross(Vector3.UP) * 2.8
		checkpoint.global_position = route_point(checkpoint.route_progress) + side
		checkpoint.setup(terrain)
		checkpoint.look_at(terrain.ground_point(route_point(checkpoint.route_progress)), Vector3.UP)
		checkpoint.lit.connect(_on_checkpoint_lit)
	_shrine.global_position = terrain.ground_point(route_point(route_length()))
	_shrine.look_at(terrain.ground_point(route_point(route_length() - 5.0)), Vector3.UP)

	spawner.target = player
	spawner.progression = GameState.progression
	spawner.scaling_level = GameState.level
	spawner.enemy_spawned.connect(_on_enemy_spawned)
	GameState.leveled_up.connect(_on_leveled_up)
	player.died.connect(_on_player_died)
	_apply_player_stats()
	_respawn_point = terrain.ground_point(route_point(1.5)) + Vector3.UP * 0.2
	_place_player(_respawn_point, route_direction(1.5))
	_hud.bind_player(player)
	_hud.bind_progression()
	_hud.show_gold(run_gold)
	GraphicsSettings.apply(get_viewport(), _environment.environment, GameState.graphics_quality)
	_spawn_patrols()
	_run()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and _started and not _finished and pause_scene != null and _pause_menu == null:
		get_viewport().set_input_as_handled()
		_pause_menu = pause_scene.instantiate() as PauseMenu
		_pause_menu.environment = _environment.environment
		add_child(_pause_menu)
		_pause_menu.restart_requested.connect(func() -> void: Scenes.go(get_tree(), Scenes.TRAIL))
		_pause_menu.tree_exited.connect(func() -> void: _pause_menu = null)


func _physics_process(_delta: float) -> void:
	if not _started or _finished or player.health.is_dead:
		return
	var hero := player.global_position
	var hero_progress := progress_of(hero)
	for checkpoint: Checkpoint in checkpoints:
		checkpoint.try_activate(hero, hero_progress)
	if _active_zone == null:
		for zone: CombatZone in zones:
			if not zone.is_cleared and zone.contains(hero):
				_start_zone(zone)
				break
	if not is_complete and hero.distance_to(_shrine.global_position) <= shrine_radius:
		if _all_zones_cleared():
			_victory()


# --- Percurso ----------------------------------------------------------------

func route_length() -> float:
	return route.curve.get_baked_length()


## Ponto da trilha (com a altura da trilha) a uma distância ao longo do percurso.
func route_point(progress: float) -> Vector3:
	var point := route.to_global(route.curve.sample_baked(clampf(progress, 0.0, route_length())))
	point.y = terrain.route_height(progress) if terrain != null else 0.0
	return point


func route_direction(progress: float) -> Vector3:
	var a := route_point(clampf(progress - 1.0, 0.0, route_length()))
	var b := route_point(clampf(progress + 1.0, 0.0, route_length()))
	var direction := b - a
	direction.y = 0.0
	return direction.normalized()


## Distância ao longo da trilha mais próxima de um ponto (para testes e HUD).
func progress_of(point: Vector3) -> float:
	return route.curve.get_closest_offset(route.to_local(point))


## Curva suave (Catmull-Rom) passando pelos waypoints.
func _build_route() -> void:
	if waypoints.size() < 2:
		return
	var curve := Curve3D.new()
	for i: int in waypoints.size():
		var previous := waypoints[maxi(i - 1, 0)]
		var next := waypoints[mini(i + 1, waypoints.size() - 1)]
		var tangent := (next - previous) * 0.25
		curve.add_point(waypoints[i], -tangent, tangent)
	route.curve = curve


# --- Fluxo da partida -------------------------------------------------------

func _run() -> void:
	if show_element_select and element_select_scene != null:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var menu := element_select_scene.instantiate() as ElementSelect
		add_child(menu)
		var chosen: int = await menu.element_chosen
		menu.queue_free()
		GameState.sword_element = chosen as Element.Type
	player.set_element(GameState.sword_element)
	_hud.show_element(GameState.sword_element)
	if capture_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await get_tree().create_timer(start_delay, false, true).timeout
	_started = true
	_hud.show_encounter_text("Siga a trilha até o santuário")


func _start_zone(zone: CombatZone) -> void:
	_active_zone = zone
	_zone_generation += 1
	var generation := _zone_generation
	var index := zones.find(zone)
	zone.activate()
	spawner.scaling_level = GameState.level
	_hud.show_encounter_text("Clareira %d / %d — %s" % [index + 1, zones.size(), zone.display_name])
	_hud.show_feedback(zone.display_name.to_upper(), TITLE_COLOR)
	zone_started.emit(index, zones.size())
	for wave: WaveData in zone.waves:
		await spawner.run_wave(wave, zone)
		if generation != _zone_generation:
			return
	zone.finish()
	_active_zone = null
	player.heal(player.health.max_health * zone_clear_heal_fraction)
	_hud.show_feedback("CLAREIRA VENCIDA", TITLE_COLOR)
	_hud.show_encounter_text("Siga a trilha até o santuário")
	zone_cleared.emit(index)


func _all_zones_cleared() -> bool:
	for zone: CombatZone in zones:
		if not zone.is_cleared:
			return false
	return true


func _spawn_patrols() -> void:
	if patrol_entry == null:
		return
	var size := mini(patrol_max_size, patrol_base_size + floori((GameState.level - 1) * patrol_size_per_level))
	var side_sign := 1.0
	for progress: float in patrol_progress:
		var side := route_direction(progress).cross(Vector3.UP) * side_sign
		side_sign = -side_sign
		for i: int in size:
			var point := route_point(progress + i * 2.0) + side * (2.5 + i * 1.2)
			spawner.spawn_enemy(patrol_entry, terrain.ground_point(point) + Vector3.UP * 0.3)


func _on_enemy_spawned(enemy: Enemy) -> void:
	enemy.died.connect(_on_enemy_killed.bind(enemy))


func _on_enemy_killed(enemy: Enemy) -> void:
	run_gold += enemy.data.gold_reward
	_hud.show_gold(run_gold)
	GameState.add_xp(enemy.data.xp_reward)


func _on_leveled_up(level: int) -> void:
	_apply_player_stats()
	spawner.scaling_level = level
	_hud.show_feedback("NÍVEL %d!" % level, LEVEL_UP_COLOR)
	SfxLibrary.play(player, &"charge_full")
	var color := player.lightning_color()
	for i: int in 6:
		var angle := TAU * i / 6.0
		var base := player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * 0.6
		LightningArc.spawn(self, base, base + Vector3.UP * 2.4, color, 0.5, 1.2, 1.5 if i == 0 else 0.0)


## Status do herói = upgrades da loja + bônus do nível. Também cura por completo.
func _apply_player_stats() -> void:
	var progression := GameState.progression
	var level_bonus := GameState.level - 1
	var damage := player.weapon.base_damage
	var max_health := player.data.max_health
	var reduction := player.data.damage_reduction
	if sword_upgrade != null and armor_upgrade != null:
		damage = sword_upgrade.value_at(GameState.level_of(sword_upgrade))
		max_health = armor_upgrade.value_at(GameState.level_of(armor_upgrade))
		reduction = armor_upgrade.secondary_at(GameState.level_of(armor_upgrade))
	player.apply_stats(damage + level_bonus * progression.damage_per_level,
			max_health + level_bonus * progression.health_per_level, reduction)


func _on_checkpoint_lit(checkpoint: Checkpoint) -> void:
	_respawn_point = checkpoint.respawn_point()
	GameState.add_gold(run_gold)
	run_gold = 0
	_hud.show_gold(run_gold)
	player.heal(player.health.max_health)
	SaveManager.save_game()
	_hud.show_feedback("FOGUEIRA ACESA — PROGRESSO SALVO", TITLE_COLOR)
	checkpoint_lit.emit(checkpoint)


func _on_player_died() -> void:
	await get_tree().create_timer(respawn_delay, true, false, true).timeout
	if _finished:
		return
	var kept := floori(run_gold * (rewards.death_keep_fraction if rewards != null else 0.5))
	GameState.add_gold(kept)
	run_gold = 0
	_hud.show_gold(run_gold)
	if _active_zone != null:
		_zone_generation += 1
		spawner.abort_wave()
		_active_zone.reset_zone()
		_active_zone = null
	player.reset_state()
	_apply_player_stats()
	_place_player(_respawn_point, player.forward())
	SaveManager.save_game()
	_hud.show_feedback("VOCÊ CAIU — DE VOLTA À FOGUEIRA", DANGER_COLOR)
	_hud.show_encounter_text("Siga a trilha até o santuário")
	player_respawned.emit()


func _place_player(point: Vector3, facing: Vector3) -> void:
	player.global_position = point
	player.velocity = Vector3.ZERO
	player.face_direction(facing)
	camera.yaw = player.rotation.y
	camera.snap()


func _victory() -> void:
	is_complete = true
	completed.emit()
	_finish(true)


func _finish(victory: bool) -> void:
	if _finished:
		return
	_finished = true
	gold_earned = run_gold + (rewards.completion_bonus if rewards != null and victory else 0)
	GameState.add_gold(gold_earned)
	SaveManager.save_game()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if result_scene != null:
		var screen := result_scene.instantiate() as ResultScreen
		add_child(screen)
		screen.show_result(victory, run_gold, gold_earned, "PERCURSO CONCLUÍDO")
		screen.replay_requested.connect(func() -> void: Scenes.go(get_tree(), Scenes.TRAIL))
	finished.emit(victory, gold_earned)
