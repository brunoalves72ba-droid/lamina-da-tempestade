class_name EventDirector
extends Node
## Eventos dinâmicos do mundo aberto (GDD §9.3). De tempos em tempos, longe das clareiras da
## história, algo acontece perto do herói — e ele decide se intervém ou ignora:
## - Emboscada: inimigos surgem em volta dele.
## - Cavaleiro da Ordem cercado (Ordem do Grifo) / Mercador da Guilda atacado (Guilda dos
##   Mercadores): um NPC resiste até alguém ajudar. Salvar = reputação e ouro; ele morrer ou o
##   herói se afastar = reputação perdida.
## - Patrulha sombria: grupo forte rondando; derrotar = reputação com o Vilarejo de Pedra-Cinza.
## Reputação muito baixa com uma facção faz os pedidos de socorro dela pararem de aparecer.

signal event_started(kind: Kind, title: String, at: Vector3)
signal event_finished(kind: Kind, success: bool)

enum Kind { AMBUSH, RESCUE_KNIGHT, MERCHANT, DARK_PATROL }

const TITLES: Array[String] = ["Emboscada!", "Cavaleiro da Ordem cercado", "Mercador da Guilda atacado", "Patrulha sombria"]
const MIN_INTERVAL: float = 40.0
const MAX_INTERVAL: float = 80.0
## Distância até onde o evento acontece (pedidos de socorro e patrulhas).
const EVENT_DISTANCE_MIN: float = 28.0
const EVENT_DISTANCE_MAX: float = 55.0
## Afastar-se além disso por IGNORE_TIME segundos = ignorou o pedido.
const IGNORE_DISTANCE: float = 85.0
const IGNORE_TIME: float = 30.0
## Inimigos do evento atacam o NPC até o herói chegar a esta distância.
const ENGAGE_HERO_DISTANCE: float = 13.0
const HOSTILE_REPUTATION: int = -40

var level: WorldLevel
var enabled: bool = true
var active_kind: int = -1
var active_title: String = ""
var active_position: Vector3 = Vector3.ZERO

var _timer: float = 0.0
var _enemies: Array[Enemy] = []
var _npc: WorldNpc
var _ignored_for: float = 0.0
var _beacon: Node3D
var _soldier: EnemyData = preload("res://data/enemies/soldier.tres")
var _caster: EnemyData = preload("res://data/enemies/crossbowman.tres")
var _elite: EnemyData = preload("res://data/enemies/elite.tres")
var _npc_model: PackedScene = preload("res://assets/characters/hero/paladin.fbx")
var _library: AnimationLibrary = preload("res://assets/characters/animations/combat_library.res")
var _enemy_scene: PackedScene = preload("res://scenes/enemies/enemy_base.tscn")


func _ready() -> void:
	_timer = randf_range(MIN_INTERVAL * 0.5, MAX_INTERVAL * 0.6)


func is_active() -> bool:
	return active_kind != -1


func _physics_process(delta: float) -> void:
	if level == null or not level.is_running():
		return
	if is_active():
		_update_active(delta)
		return
	if not enabled or level.is_in_combat_zone():
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(MIN_INTERVAL, MAX_INTERVAL)
		start_event(_pick_kind())


## Começa um evento agora (testes também usam). Retorna false se não deu para começar.
func start_event(kind: Kind) -> bool:
	if is_active():
		return false
	var hero := level.player.global_position
	var spot := hero if kind == Kind.AMBUSH else _pick_spot(hero)
	active_kind = kind
	active_title = TITLES[kind]
	active_position = spot
	_ignored_for = 0.0
	_enemies.clear()
	var threat := GameState.threat_level()
	match kind:
		Kind.AMBUSH:
			var count := 3 + mini(GameState.story_arc, 2)
			for i: int in count:
				var angle := TAU * i / count + randf_range(-0.3, 0.3)
				var data := _caster if i == count - 1 else _soldier
				_spawn(data, spot + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(9.0, 13.0), null)
		Kind.RESCUE_KNIGHT, Kind.MERCHANT:
			var knight := kind == Kind.RESCUE_KNIGHT
			_npc = WorldNpc.new()
			_npc.setup(_npc_model, _library, "Cavaleiro da Ordem" if knight else "Mercador da Guilda",
					&"ordem_grifo" if knight else &"guilda_mercadores",
					Color(1.0, 0.85, 0.4) if knight else Color(0.55, 1.0, 0.6), 120.0 + threat * 6.0)
			level.add_child(_npc)
			_npc.global_position = level.terrain.ground_point(spot) + Vector3.UP * 0.2
			_npc.died.connect(_on_npc_died)
			for i: int in 3 + mini(GameState.story_arc, 1):
				var angle := TAU * i / 3.0
				_spawn(_soldier if i < 2 else _elite if knight else _caster,
						spot + Vector3(cos(angle), 0.0, sin(angle)) * 3.5, _npc)
		Kind.DARK_PATROL:
			_spawn(_elite, spot, null)
			for i: int in 2 + mini(GameState.story_arc, 2):
				_spawn(_soldier, spot + Vector3(randf_range(-3, 3), 0.0, randf_range(-3, 3)), null)
	_place_beacon(spot)
	SfxLibrary.play(level.player, &"telegraph")
	Events.world_event_changed.emit(active_title, spot, true)
	event_started.emit(kind, active_title, spot)
	return true


func _update_active(delta: float) -> void:
	_enemies = _enemies.filter(func(enemy: Enemy) -> bool: return is_instance_valid(enemy) and not enemy.health.is_dead)
	var hero := level.player.global_position
	if _npc != null and is_instance_valid(_npc) and _npc.is_alive():
		_npc.face(hero)
		if hero.distance_to(_npc.global_position) <= ENGAGE_HERO_DISTANCE:
			for enemy: Enemy in _enemies:
				if enemy.target != level.player:
					enemy.set_target(level.player)
					enemy.is_aware = true
	if _enemies.is_empty():
		_finish(true)
		return
	if hero.distance_to(active_position) > IGNORE_DISTANCE:
		_ignored_for += delta
		if _ignored_for >= IGNORE_TIME:
			_finish(false, true)
	else:
		_ignored_for = 0.0


func _finish(success: bool, ignored: bool = false) -> void:
	var kind := active_kind
	var faction := _faction_of(kind)
	if success and kind != Kind.AMBUSH:
		var gold := 40 + GameState.story_arc * 20
		GameState.add_gold(gold)
		GameState.change_reputation(faction, 12)
		Events.narration_requested.emit(_npc_speaker(kind), _thanks_line(kind, faction), 4.0)
		Events.reputation_feedback.emit(GameState.FACTIONS[faction], 12, gold)
	elif success:
		Events.narration_requested.emit("Kael", "Emboscada desfeita. A Mácula está ficando ousada.", 3.0)
	elif ignored:
		_cleanup_enemies()
		if kind != Kind.AMBUSH:
			GameState.change_reputation(faction, -4)
			Events.reputation_feedback.emit(GameState.FACTIONS[faction], -4, 0)
	else:
		GameState.change_reputation(faction, -6)
		Events.narration_requested.emit("Narrador", "Tarde demais. A notícia vai correr pelas estradas.", 3.5)
		Events.reputation_feedback.emit(GameState.FACTIONS[faction], -6, 0)
	if _npc != null and is_instance_valid(_npc):
		var npc := _npc
		get_tree().create_timer(6.0, false).timeout.connect(func() -> void:
			if is_instance_valid(npc):
				npc.queue_free())
	_npc = null
	if _beacon != null and is_instance_valid(_beacon):
		_beacon.queue_free()
	_beacon = null
	active_kind = -1
	active_title = ""
	Events.world_event_changed.emit("", Vector3.ZERO, false)
	event_finished.emit(kind, success)
	SaveManager.autosave()


func _on_npc_died() -> void:
	if is_active():
		_finish(false)


func _spawn(data: EnemyData, at: Vector3, npc_target: Node3D) -> void:
	var entry := SpawnEntry.new()
	entry.enemy_scene = _enemy_scene
	entry.enemy_data = data
	entry.element = (randi() % 3 + 1) as Element.Type
	var enemy := level.spawner.spawn_enemy(entry, level.terrain.ground_point(at) + Vector3.UP * 0.3)
	if npc_target != null:
		enemy.set_target(npc_target)
		enemy.is_aware = true
	_enemies.append(enemy)


func _cleanup_enemies() -> void:
	for enemy: Enemy in _enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_enemies.clear()


## Facções com reputação muito baixa não pedem mais ajuda.
func _pick_kind() -> Kind:
	var options: Array[Kind] = [Kind.AMBUSH, Kind.DARK_PATROL]
	if GameState.reputation_of(&"ordem_grifo") > HOSTILE_REPUTATION:
		options.append(Kind.RESCUE_KNIGHT)
	if GameState.reputation_of(&"guilda_mercadores") > HOSTILE_REPUTATION:
		options.append(Kind.MERCHANT)
	return options.pick_random()


## Lugar do evento: área aberta de vale lateral próxima, senão um ponto da trilha à frente,
## sempre fora das clareiras da história.
func _pick_spot(hero: Vector3) -> Vector3:
	for area: Vector3 in level.side_areas:
		var distance := hero.distance_to(area)
		if distance >= EVENT_DISTANCE_MIN and distance <= EVENT_DISTANCE_MAX * 1.4:
			return area
	var progress := level.progress_of(hero)
	for attempt: int in 8:
		var ahead := progress + randf_range(EVENT_DISTANCE_MIN, EVENT_DISTANCE_MAX)
		var point := level.route_point(clampf(ahead, 2.0, level.route_length() - 2.0))
		if not level.is_point_in_zone(point):
			return point
	return level.route_point(clampf(progress + EVENT_DISTANCE_MIN, 0.0, level.route_length()))


func _faction_of(kind: int) -> StringName:
	match kind:
		Kind.RESCUE_KNIGHT:
			return &"ordem_grifo"
		Kind.MERCHANT:
			return &"guilda_mercadores"
	return &"vilarejo_cinzas"


func _npc_speaker(kind: int) -> String:
	return "Cavaleiro da Ordem" if kind == Kind.RESCUE_KNIGHT else "Mercador da Guilda"


## Agradecimento conforme a reputação (desconfiado, neutro, amigo, honrado).
func _thanks_line(kind: int, faction: StringName) -> String:
	var reputation := GameState.reputation_of(faction)
	if kind == Kind.RESCUE_KNIGHT:
		if reputation >= 50:
			return "Irmão da tempestade! A Ordem inteira saberá disto."
		if reputation >= 15:
			return "Ainda bem que o raio passa por esta estrada. Obrigado, cavaleiro."
		return "Você... ajudou. Não esperava isso de um forasteiro."
	if reputation >= 50:
		return "Para você, meus preços são de amigo. Leve isto também."
	if reputation >= 15:
		return "A Guilda paga as dívidas dela. Aqui, pela ajuda."
	return "Hum. Obrigado. Mas não pense que isso abaixa meus preços."


## Coluna de luz marcando o lugar do evento (visível de longe).
func _place_beacon(at: Vector3) -> void:
	_beacon = Node3D.new()
	_beacon.name = "EventBeacon"
	level.add_child(_beacon)
	_beacon.global_position = level.terrain.ground_point(at)
	var pillar := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.25
	cylinder.bottom_radius = 0.6
	cylinder.height = 30.0
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(1.0, 0.55, 0.2, 0.18) if active_kind != Kind.DARK_PATROL else Color(0.7, 0.2, 1.0, 0.18)
	cylinder.material = material
	pillar.mesh = cylinder
	pillar.position.y = 15.0
	pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beacon.add_child(pillar)
