extends Node
## Teste ponta a ponta (GDD §12, M2–M3). Um "piloto automático" atravessa a arena_01:
## ataca o alvo atual, usa os poderes de raio quando prontos e defende cada aviso no tempo certo.
##   godot --headless --path . --fixed-fps 60 res://tests/auto_rail_test.tscn
## Sai com código 0 se tudo passar e 1 se algo falhar.

const ARENA_SCENE: PackedScene = preload("res://scenes/levels/arena_01.tscn")
const PARRY_LEAD_TIME: float = 0.1
const ATTACK_INTERVAL: float = 0.2
## O piloto não ataca se um impacto vem dentro deste tempo (para não estar no meio de um Passo).
const PARRY_GUARD_TIME: float = 0.6
const SPAWN_WAIT: float = 1.3
const TIMEOUT_SECONDS: float = 300.0

var _level: Level
var _player: Player
var _failures: int = 0
var _clock: float = 0.0
var _done: bool = false
var _impact_times: Array[float] = []
var _active_attacks: int = 0
var _max_simultaneous_attacks: int = 0
var _encounters_started: int = 0
var _encounters_cleared: int = 0
var _enemies_spawned: int = 0
var _parries: int = 0
var _ranged_parries: int = 0
var _bolts: int = 0
var _dashes: int = 0
var _hits_taken: int = 0
var _powers_used: Array[int] = [0, 0, 0]
var _finishers: int = 0
var _finisher_since_check: bool = false
var _finisher_checks_ok: int = 0
var _last_dead: Enemy


func _ready() -> void:
	# Não mexe no save do jogador; começa sempre do zero.
	SaveManager.persist = false
	GameState.reset()
	get_tree().create_timer(TIMEOUT_SECONDS, true, true).timeout.connect(_on_timeout)
	_level = ARENA_SCENE.instantiate() as Level
	_level.show_element_select = false
	GameState.sword_element = Element.Type.DIVINE
	add_child(_level)
	_player = _level.player
	_level.spawner.enemy_spawned.connect(_on_enemy_spawned)
	_level.spawner.wave_cleared.connect(_on_wave_cleared)
	Events.wave_finisher.connect(_on_wave_finisher)
	_player.powers.power_used.connect(func(slot: int) -> void: _powers_used[slot] += 1)
	_level.encounter_started.connect(_on_encounter_started)
	_level.encounter_cleared.connect(_on_encounter_cleared)
	_level.finished.connect(_on_level_finished)
	_player.died.connect(_on_player_died)
	_player.parry_succeeded.connect(_on_parry)
	_player.bolt_fired.connect(func(_t: Enemy) -> void: _bolts += 1)
	_player.dash_started.connect(func(_a: Vector3, _b: Vector3) -> void: _dashes += 1)
	_player.hit_taken.connect(func(_i: DamageInfo, _e: bool) -> void: _hits_taken += 1)
	_bot_loop()


func _physics_process(delta: float) -> void:
	_clock += delta


func _bot_loop() -> void:
	while not _done:
		if not _player.is_traveling() and _player.target != null and not _impact_soon():
			_player.input_buffer.press(_choose_action())
		await _wait(ATTACK_INTERVAL)


## Fúria com Carga cheia; Corrente com 2+ inimigos; Lâmina quando pronta; senão ataque.
func _choose_action() -> StringName:
	var powers := _player.powers
	if powers.is_ready(2):
		return &"skill_3"
	if powers.is_ready(1) and _player.targeting.candidates().size() >= 2:
		return &"skill_2"
	if powers.is_ready(0):
		return &"skill_1"
	return &"attack"


func _impact_soon() -> bool:
	for impact: float in _impact_times:
		if impact - _clock <= PARRY_GUARD_TIME:
			return true
	return false


func _on_enemy_spawned(enemy: Enemy) -> void:
	_enemies_spawned += 1
	enemy.attack_telegraphed.connect(_on_attack_telegraphed)
	enemy.died.connect(func() -> void: _last_dead = enemy)


func _on_attack_telegraphed(time_to_impact: float) -> void:
	var impact := _clock + time_to_impact
	_impact_times.append(impact)
	_active_attacks += 1
	_max_simultaneous_attacks = maxi(_max_simultaneous_attacks, _active_attacks)
	await _wait(time_to_impact - PARRY_LEAD_TIME)
	_player.input_buffer.press(&"parry")
	await _wait(PARRY_LEAD_TIME)
	_active_attacks -= 1
	await _wait(PARRY_LEAD_TIME)
	_impact_times.erase(impact)


func _on_encounter_started(index: int, _total: int) -> void:
	_encounters_started += 1
	if index == 1:
		await _wait(SPAWN_WAIT)
		var before := _player.target
		_player.targeting.cycle(1)
		_check(_player.target != null and _player.target != before, "troca de alvo com 4 inimigos na tela")


func _on_wave_finisher(_enemy: Node3D) -> void:
	_finishers += 1
	_finisher_since_check = true


## Finisher deve acontecer se, e só se, o último inimigo da onda caiu com golpe forte.
func _on_wave_cleared() -> void:
	var had_finisher := _finisher_since_check
	_finisher_since_check = false
	# O WaveSpawner reage ao "died" antes deste teste; espera o _last_dead ser atualizado.
	await get_tree().physics_frame
	var heavy := _last_dead != null and _last_dead.last_hit != null and _last_dead.last_hit.is_heavy
	if heavy == had_finisher:
		_finisher_checks_ok += 1
	else:
		_check(false, "finisher (%s) não bate com o último golpe (forte: %s)" % [had_finisher, heavy])


func _on_encounter_cleared(_index: int) -> void:
	_encounters_cleared += 1


func _on_parry(attacker: Node3D) -> void:
	_parries += 1
	var enemy := attacker as Enemy
	if enemy != null and enemy.is_ranged():
		_ranged_parries += 1


func _on_level_finished(_victory: bool, _gold: int) -> void:
	_finish()


func _on_player_died() -> void:
	_check(false, "herói sobrevive à arena")
	_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	var total := _level.encounters.size()
	_check(_encounters_started == total, "%d de %d encontros iniciados" % [_encounters_started, total])
	_check(_encounters_cleared == total, "%d de %d encontros vencidos" % [_encounters_cleared, total])
	_check(_enemies_spawned == 10, "10 inimigos surgiram (surgiram %d)" % _enemies_spawned)
	_check(_level.is_complete, "fase chega ao fim do trilho")
	var expected_gold := _expected_run_gold() + _level.rewards.completion_bonus
	_check(_level.gold_earned == expected_gold and GameState.gold == expected_gold,
			"ouro da vitória: inimigos + bônus = %d (ganhou %d, total %d)" % [expected_gold, _level.gold_earned, GameState.gold])
	var has_result := false
	for child: Node in _level.get_children():
		has_result = has_result or child is ResultScreen
	_check(has_result, "tela de resultado aparece no fim")
	var end_point := _level.rail.position_at(_level.rail.length())
	_check(_player.global_position.distance_to(end_point) < 0.1, "herói termina no fim do trilho")
	_check(_max_simultaneous_attacks <= 1, "nunca há dois ataques ao mesmo tempo (máx. %d)" % _max_simultaneous_attacks)
	_check(_bolts > 0 and _dashes > 0, "Dardo de Raio e Passo Relâmpago usados (%d / %d)" % [_bolts, _dashes])
	_check(_powers_used[0] > 0 and _powers_used[1] > 0, "Lâmina Voltaica e Corrente usadas (%d / %d)" % [_powers_used[0], _powers_used[1]])
	_check(_finisher_checks_ok == total, "finisher coerente nas %d ondas (%d finisher(s))" % [total, _finishers])
	_check(is_equal_approx(Engine.time_scale, 1.0) or _finisher_since_check, "escala de tempo volta ao normal")
	print("  INFO tempo de jogo %.1f s · parries %d (%d em virotes) · golpes recebidos %d · vida final %.0f"
			% [_clock, _parries, _ranged_parries, _hits_taken, _player.health.current_health])
	print("  INFO poderes usados: Lâmina %d · Corrente %d · Fúria %d" % _powers_used)
	print("\n%s — %d falha(s)" % ["ARENA OK" if _failures == 0 else "ARENA FALHOU", _failures])
	get_tree().quit(0 if _failures == 0 else 1)


## Espera em tempo de JOGO (respeita hitstop e câmera lenta).
## Soma do ouro de todos os inimigos de todas as ondas da arena (GDD §8).
func _expected_run_gold() -> int:
	var total := 0
	for encounter: Encounter in _level.encounters:
		for wave: WaveData in encounter.waves:
			for entry: SpawnEntry in wave.spawns:
				total += entry.enemy_data.gold_reward
	return total


func _wait(seconds: float) -> void:
	await get_tree().create_timer(maxf(seconds, 0.001), true, true).timeout


func _check(condition: bool, description: String) -> void:
	print("  %s %s" % ["PASS" if condition else "FAIL", description])
	if not condition:
		_failures += 1


func _on_timeout() -> void:
	push_error("Teste excedeu %d s de jogo" % TIMEOUT_SECONDS)
	_check(false, "fase termina dentro do tempo limite")
	_finish()
