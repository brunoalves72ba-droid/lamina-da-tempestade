extends Node
## Teste ponta a ponta do percurso com movimento livre. Um "piloto automático" anda pela trilha,
## trava no inimigo mais próximo, ataca, defende cada aviso no tempo certo, usa os poderes,
## acende as fogueiras e chega ao santuário. Na pasta do projeto:
##   godot --headless --path . --fixed-fps 60 res://tests/auto_trail_test.tscn
## Sai com código 0 se tudo passar e 1 se algo falhar. Não grava no save do jogador.

const TRAIL_SCENE: PackedScene = preload("res://scenes/levels/trail_01.tscn")
const PARRY_LEAD_TIME: float = 0.1
const PARRY_GUARD_TIME: float = 0.6
const LOOK_AHEAD: float = 6.0
const ENGAGE_RANGE: float = 9.0
const MELEE_RANGE: float = 2.0
const ATTACK_INTERVAL: float = 0.2
const TIMEOUT_SECONDS: float = 600.0

var _level: WorldLevel
var _player: Player
var _failures: int = 0
var _clock: float = 0.0
var _done: bool = false
var _impact_times: Array[float] = []
var _attack_cooldown: float = 0.0
var _zones_cleared: int = 0
var _checkpoints_lit: int = 0
var _respawns: int = 0
var _kills: int = 0
var _parries: int = 0
var _levels_gained: int = 0
var _powers_used: int = 0
var _max_wave_size: int = 0
var _zone_spawns: int = 0


func _ready() -> void:
	SaveManager.persist = false
	GameState.reset()
	GameState.sword_element = Element.Type.HEROIC
	get_tree().create_timer(TIMEOUT_SECONDS, true, true).timeout.connect(_on_timeout)
	_level = TRAIL_SCENE.instantiate() as WorldLevel
	_level.show_element_select = false
	_level.dynamic_events = false
	_level.cinematics = false
	_level.capture_mouse = false
	add_child(_level)
	_player = _level.player
	_player.use_scripted_input = true
	_level.spawner.enemy_spawned.connect(_on_enemy_spawned)
	_level.zone_started.connect(func(_i: int, _t: int) -> void: _zone_spawns = 0)
	_level.zone_cleared.connect(func(_i: int) -> void: _zones_cleared += 1)
	_level.checkpoint_lit.connect(func(_c: Checkpoint) -> void: _checkpoints_lit += 1)
	_level.player_respawned.connect(func() -> void: _respawns += 1)
	_level.finished.connect(_on_finished)
	_player.parry_succeeded.connect(func(_a: Node3D) -> void: _parries += 1)
	_player.powers.power_used.connect(func(_s: int) -> void: _powers_used += 1)
	GameState.leveled_up.connect(func(_l: int) -> void: _levels_gained += 1)


func _physics_process(delta: float) -> void:
	_clock += delta
	if _done or _player.health.is_dead:
		_player.scripted_move_input = Vector2.ZERO
		return
	_attack_cooldown -= delta
	var enemy := _nearest_enemy()
	if enemy != null:
		_fight(enemy)
	else:
		if _player.targeting.locked:
			_player.targeting.toggle_lock()
		var progress := _level.progress_of(_player.global_position)
		_move_toward(_level.route_point(progress + LOOK_AHEAD))


func _fight(enemy: Enemy) -> void:
	if _player.target != enemy or not _player.targeting.locked:
		_player.targeting.set_target(enemy)
	var distance := _player.distance_to_target()
	if distance > MELEE_RANGE and not _impact_soon():
		_move_toward(enemy.global_position)
	else:
		_player.scripted_move_input = Vector2.ZERO
	if _impact_soon() or _attack_cooldown > 0.0:
		return
	_attack_cooldown = ATTACK_INTERVAL
	var powers := _player.powers
	if powers.is_ready(2):
		_player.input_buffer.press(&"skill_3")
	elif powers.is_ready(1) and _player.targeting.candidates().size() >= 2:
		_player.input_buffer.press(&"skill_2")
	elif distance <= MELEE_RANGE + 0.5:
		_player.input_buffer.press(&"skill_1" if powers.is_ready(0) else &"attack")


func _nearest_enemy() -> Enemy:
	var best: Enemy = null
	var best_distance := ENGAGE_RANGE
	for enemy: Enemy in _player.targeting.candidates():
		var distance := enemy.global_position.distance_to(_player.global_position)
		if distance < best_distance and enemy.is_aware:
			best_distance = distance
			best = enemy
	return best


## Converte uma direção no mundo para a entrada de movimento (relativa à câmera).
func _move_toward(point: Vector3) -> void:
	var direction := point - _player.global_position
	direction.y = 0.0
	if direction.length_squared() < 0.01:
		_player.scripted_move_input = Vector2.ZERO
		return
	var local := direction.normalized().rotated(Vector3.UP, -_player.view_yaw)
	_player.scripted_move_input = Vector2(local.x, local.z)


func _impact_soon() -> bool:
	for impact: float in _impact_times:
		if impact - _clock <= PARRY_GUARD_TIME:
			return true
	return false


func _on_enemy_spawned(enemy: Enemy) -> void:
	_zone_spawns += 1
	_max_wave_size = maxi(_max_wave_size, _zone_spawns)
	enemy.attack_telegraphed.connect(_on_attack_telegraphed)
	enemy.died.connect(func() -> void: _kills += 1)


func _on_attack_telegraphed(time_to_impact: float) -> void:
	var impact := _clock + time_to_impact
	_impact_times.append(impact)
	await get_tree().create_timer(maxf(time_to_impact - PARRY_LEAD_TIME, 0.01), true, true).timeout
	_player.input_buffer.press(&"parry")
	await get_tree().create_timer(PARRY_LEAD_TIME * 2.0, true, true).timeout
	_impact_times.erase(impact)


func _on_finished(victory: bool, gold: int) -> void:
	_done = true
	var total_zones := _level.zones.size()
	print("\n[Percurso completo]")
	_check(victory, "chega ao santuário e vence")
	_check(_zones_cleared == total_zones, "vence as %d clareiras (venceu %d)" % [total_zones, _zones_cleared])
	_check(_checkpoints_lit == _level.checkpoints.size(), "acende as %d fogueiras (acendeu %d)" % [_level.checkpoints.size(), _checkpoints_lit])
	_check(_levels_gained >= 1 and GameState.level >= 2, "sobe de nível com o XP (nível %d)" % GameState.level)
	_check(gold > 0 and GameState.gold >= gold, "ganha ouro (%d na chegada, %d no total)" % [gold, GameState.gold])
	_check(_parries > 0 and _powers_used > 0, "defende e usa poderes (%d parries, %d poderes)" % [_parries, _powers_used])
	print("  INFO tempo de jogo %.0f s · inimigos derrotados %d · mortes %d · maior onda %d · vida final %.0f/%.0f"
			% [_clock, _kills, _respawns, _max_wave_size, _player.health.current_health, _player.health.max_health])
	print("\n%s — %d falha(s)" % ["TRILHA OK" if _failures == 0 else "TRILHA FALHOU", _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _check(condition: bool, description: String) -> void:
	print("  %s %s" % ["PASS" if condition else "FAIL", description])
	if not condition:
		_failures += 1


func _on_timeout() -> void:
	if _done:
		return
	_done = true
	var progress := _level.progress_of(_player.global_position)
	print("\n  FAIL tempo esgotado em %.0f m de %.0f m (clareiras %d, fogueiras %d, mortes %d, nível %d)"
			% [progress, _level.route_length(), _zones_cleared, _checkpoints_lit, _respawns, GameState.level])
	get_tree().quit(1)
