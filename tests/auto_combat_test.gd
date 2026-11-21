extends Node
## Teste automático das mecânicas de combate (M1–M3, GDD §12) no sandbox. Na pasta do projeto:
##   godot --headless --path . --fixed-fps 60 res://tests/auto_combat_test.tscn
## Sai com código 0 se tudo passar e 1 se algo falhar.

const SANDBOX_SCENE: PackedScene = preload("res://tests/sandbox_combat.tscn")
const CROSSBOW_DATA: EnemyData = preload("res://data/enemies/crossbowman.tres")
const CROSSBOW_POSITION := Vector3(3.0, 0.0, -8.0)
const SOLDIER_DATA: EnemyData = preload("res://data/enemies/soldier.tres")
const ELITE_DATA: EnemyData = preload("res://data/enemies/elite.tres")
const BOSS_DATA: EnemyData = preload("res://data/enemies/boss_warrok.tres")
const LEAP_BOSS_DATA: EnemyData = preload("res://data/enemies/boss_mutant.tres")
## Pausa maior que a janela do combo, para cada ataque começar do 1º golpe.
const COMBO_BREAK_TIME: float = 1.0
## Aperta o parry este tempo antes do impacto (dentro da janela de 0,25 s).
const PARRY_LEAD_TIME: float = 0.12
## Aperta o parry este tempo depois do início do aviso (cedo demais: 0,6 s antes do impacto).
const EARLY_PRESS_DELAY: float = 0.2
const SETTLE_TIME: float = 0.1
const COMBO_PRESS_INTERVAL: float = 0.25
const TIMEOUT_SECONDS: float = 300.0

var _sandbox: SandboxCombat
var _player: Player
var _enemy: Enemy
var _failures: int = 0
var _parries: int = 0
var _early_hits: int = 0
var _bolts: int = 0
var _dashes: int = 0


func _ready() -> void:
	# Não mexe no save do jogador; começa sempre do zero.
	SaveManager.persist = false
	GameState.reset()
	get_tree().create_timer(TIMEOUT_SECONDS, true, false, true).timeout.connect(_on_timeout)
	_sandbox = SANDBOX_SCENE.instantiate() as SandboxCombat
	add_child(_sandbox)
	_player = _sandbox.player
	_enemy = _sandbox.enemy
	_player.parry_succeeded.connect(_on_parry)
	_player.hit_taken.connect(_on_hit_taken)
	_player.bolt_fired.connect(_on_bolt_fired)
	_player.dash_started.connect(_on_dash_started)
	await _wait(_enemy.data.spawn_time + SETTLE_TIME)

	await _test_perfect_parry_and_counter()
	await _test_early_parry()
	await _test_no_parry()
	await _test_crossbow_targeting_and_bolt()
	await _test_elements_and_charge()
	await _test_voltaic_blade()
	await _test_chain_lightning()
	await _test_storm_fury()
	await _test_elite_double_strike()
	await _test_free_movement()
	await _test_boss_powers()
	await _test_free_aim()
	await _test_lightning_physics()
	await _test_combo_and_kill()

	print("\n%s — %d falha(s)" % ["COMBATE OK" if _failures == 0 else "COMBATE FALHOU", _failures])
	get_tree().quit(0 if _failures == 0 else 1)


## Fase B: eletrocutado (lento, crítico), condução por poça, desmembramento e tempestade.
func _test_lightning_physics() -> void:
	print("
[Eletrocutado, condução, gore e tempestade]")
	_sandbox.reset()
	_enemy.auto_attack = false
	await _wait(0.2)
	var info := _player.build_power_info(0.1, false)
	_enemy.hurtbox.receive_hit(info)
	_check(_enemy.is_shocked(), "poder de raio deixa o inimigo eletrocutado")
	var physical := _player.build_attack_info(0)
	var hp := _enemy.health.current_health
	_enemy.hurtbox.receive_hit(physical)
	_check(physical.is_critical and is_equal_approx(hp - _enemy.health.current_health,
			_player.weapon.base_damage * Enemy.SHOCK_CRIT_MULTIPLIER), "golpe de espada no eletrocutado é crítico")
	await _wait(2.5)
	_check(not _enemy.is_shocked(), "o efeito passa sozinho")
	# Poça: um raio que cai nela eletrifica quem está dentro.
	var puddle := Puddle.new()
	puddle.radius = 2.0
	_sandbox.add_child(puddle)
	puddle.global_position = Vector3(3.0, 0.0, -6.0)
	var wet := _sandbox.spawn_extra_enemy(SOLDIER_DATA, Vector3(3.5, 0.0, -6.0))
	wet.auto_attack = false
	await _wait(SOLDIER_DATA.spawn_time + 0.2)
	wet.global_position = Vector3(3.5, 0.0, -6.0)
	var wet_hp := wet.health.current_health
	var conducted := Conduction.discharge(get_tree(), Vector3(2.5, 0.0, -6.0), Color.CYAN,
			_player.build_power_info.bind(1.0, false))
	_check(wet in conducted and wet.health.current_health < wet_hp and wet.is_shocked(), "poça conduz o raio para quem pisa nela")
	puddle.queue_free()
	# Gore: corte num inimigo morto por golpe forte.
	GameState.gore_enabled = true
	var bone := Gore.dismember(wet)
	var severed := wet.body.skeleton.get_node_or_null(^"SeveredBones") as SeveredBones
	_check(bone != &"" and severed != null and severed.has_severed(), "golpe forte desmembra (%s)" % bone)
	GameState.gore_enabled = false
	_check(Gore.dismember(wet) == &"", "com o gore desligado não há desmembramento")
	GameState.gore_enabled = true
	# Tempestade: raios mais fortes.
	var calm := _player.build_power_info(1.0, false).amount
	var weather := Weather.new()
	add_child(weather)
	var environment := Environment.new()
	weather.setup(environment, null, null, null, null)
	weather.set_state(Weather.Condition.STORM, true)
	await _wait(0.1)
	var stormy := _player.build_power_info(1.0, false).amount
	_check(GameState.storm_intensity > 0.9 and stormy > calm * 1.25, "na tempestade os raios ficam ~30%% mais fortes (%.1f → %.1f)" % [calm, stormy])
	weather.queue_free()
	GameState.storm_intensity = 0.0
	GameState.night_factor = 0.0
	_sandbox.reset()
	_enemy.auto_attack = true


## Mira livre: só o inimigo na mira vira alvo (sem pegar o mais próximo); assistida volta ao normal.
func _test_free_aim() -> void:
	print("\n[Mira híbrida]")
	_sandbox.reset()
	_enemy.auto_attack = false
	await _wait(0.3)
	_check(_player.target == _enemy, "mira assistida pega o inimigo mais próximo")
	_player.targeting.set_aim_mode(GameState.AimMode.FREE)
	var camera := get_viewport().get_camera_3d()
	camera.look_at(_enemy.global_position + Vector3.UP * 1.1, Vector3.UP)
	await _wait(0.2)
	_check(_player.target == _enemy, "mira livre pega o inimigo que está na mira")
	camera.look_at(_enemy.global_position + Vector3(6.0, 1.1, 0.0), Vector3.UP)
	await _wait(0.2)
	_check(_player.target == null, "mira livre: inimigo fora da mira não vira alvo")
	_player.targeting.set_aim_mode(GameState.AimMode.ASSISTED)
	await _wait(0.2)
	_check(_player.target == _enemy, "voltando à mira assistida, o alvo volta")
	camera.look_at(_sandbox.camera_focus, Vector3.UP)
	_sandbox.reset()
	_enemy.auto_attack = true


## Chefão: ruge ao perceber o herói (barra de vida), golpe no chão acerta quem está no círculo
## e não acerta quem esquiva; salto cai onde o herói estava.
func _test_boss_powers() -> void:
	print("
[Chefões: rugido, golpe no chão e salto]")
	_sandbox.reset()
	_enemy.auto_attack = false
	var engaged: Array[Node3D] = []
	var on_engaged := func(boss: Node3D) -> void: engaged.append(boss)
	Events.boss_engaged.connect(on_engaged)
	var boss := _sandbox.spawn_extra_enemy(BOSS_DATA, Vector3(0.0, 0.0, -4.5))
	boss.auto_attack = false
	await _wait(BOSS_DATA.spawn_time + BossBrain.ROAR_TIME + 0.6)
	_check(engaged.has(boss), "chefão ruge e aparece a barra de vida")
	_check(boss.boss_brain != null and boss.data.has_poise, "chefão tem poderes e postura")
	var before := _player.health.current_health
	boss.state_machine.transition_to(&"Power", {"power": BossData.Power.SLAM})
	await _wait(BOSS_DATA.boss.slam_windup + 0.2)
	_check(_player.health.current_health < before, "golpe no chão acerta o herói dentro do círculo")
	await _wait(1.5)
	_player.reset_state()
	before = _player.health.current_health
	boss.state_machine.transition_to(&"Power", {"power": BossData.Power.SLAM})
	await _wait(BOSS_DATA.boss.slam_windup - 0.12)
	_player.use_scripted_input = true
	_player.scripted_move_input = Vector2(0.0, 1.0)
	_player.input_buffer.press(&"dodge")
	await _wait(0.4)
	_player.scripted_move_input = Vector2.ZERO
	_player.use_scripted_input = false
	_check(is_equal_approx(_player.health.current_health, before), "esquivar na hora do impacto evita o dano")
	await _wait(1.5)
	boss.queue_free()
	var leaper := _sandbox.spawn_extra_enemy(LEAP_BOSS_DATA, Vector3(6.0, 0.0, -8.0))
	leaper.auto_attack = false
	await _wait(LEAP_BOSS_DATA.spawn_time + BossBrain.ROAR_TIME + 0.6)
	var target_spot := _player.global_position
	leaper.state_machine.transition_to(&"Power", {"power": BossData.Power.LEAP})
	await _wait(LEAP_BOSS_DATA.boss.leap_windup + LEAP_BOSS_DATA.boss.leap_air_time + 0.2)
	var landing := Vector2(leaper.global_position.x - target_spot.x, leaper.global_position.z - target_spot.z).length()
	_check(landing < 2.0, "salto cai onde o herói estava (%.2f m)" % landing)
	Events.boss_engaged.disconnect(on_engaged)
	_sandbox.reset()
	_enemy.auto_attack = true


func _test_perfect_parry_and_counter() -> void:
	print("\n[Parry certo + contra-ataque]")
	_sandbox.reset()
	_enemy.auto_attack = true
	var parries_before := _parries
	var time_to_impact: float = await _enemy.attack_telegraphed
	await _wait(time_to_impact - PARRY_LEAD_TIME)
	_player.input_buffer.press(&"parry")
	await _wait(PARRY_LEAD_TIME + SETTLE_TIME)
	_check(_parries == parries_before + 1, "parry dentro da janela vira Descarga")
	_check(is_equal_approx(_player.health.current_health, _player.health.max_health), "Descarga bloqueia todo o dano")
	_check(_enemy.is_stunned(), "Descarga atordoa o inimigo")
	_check(is_equal_approx(_player.charge.value, _player.data.charge_parry), "parry certo dá +%.0f de Carga" % _player.data.charge_parry)

	var weapon := _player.weapon
	var hp_before := _enemy.health.current_health
	_player.input_buffer.press(&"attack")
	await _wait(_hit_land_time())
	var expected := weapon.base_damage * weapon.combo_multipliers[0] * _player.data.counter_multiplier
	_check(is_equal_approx(hp_before - _enemy.health.current_health, expected),
			"contra-ataque causa %.0f (recebeu %.0f)" % [expected, hp_before - _enemy.health.current_health])
	var charge_expected := _player.data.charge_parry + _player.data.charge_counter
	_check(is_equal_approx(_player.charge.value, charge_expected), "contra-ataque dá +%.0f de Carga" % _player.data.charge_counter)

	hp_before = _enemy.health.current_health
	_player.input_buffer.press(&"attack")
	await _wait(_hit_land_time())
	expected = weapon.base_damage * weapon.combo_multipliers[1]
	_check(_enemy.is_stunned(), "inimigo continua atordoado durante o 2º golpe")
	_check(is_equal_approx(hp_before - _enemy.health.current_health, expected),
			"só o 1º golpe é contra-ataque: 2º causa %.0f (recebeu %.0f)" % [expected, hp_before - _enemy.health.current_health])


func _test_early_parry() -> void:
	print("\n[Parry cedo]")
	_sandbox.reset()
	_enemy.auto_attack = true
	var early_before := _early_hits
	var time_to_impact: float = await _enemy.attack_telegraphed
	await _wait(EARLY_PRESS_DELAY)
	_player.input_buffer.press(&"parry")
	await _wait(time_to_impact - EARLY_PRESS_DELAY + SETTLE_TIME)
	_check(_early_hits == early_before + 1, "golpe acerta durante a recuperação do parry")
	_check(is_equal_approx(_player.health.current_health, _expected_hp_after_one_hit()), "parry cedo toma o dano integral")
	_check(not _enemy.is_stunned(), "parry cedo não atordoa")


func _test_no_parry() -> void:
	print("\n[Sem defesa]")
	_sandbox.reset()
	_enemy.auto_attack = true
	_player.charge.add(30.0)
	var early_before := _early_hits
	var time_to_impact: float = await _enemy.attack_telegraphed
	await _wait(time_to_impact + SETTLE_TIME)
	_check(is_equal_approx(_player.health.current_health, _expected_hp_after_one_hit()), "sem parry toma o dano integral")
	_check(_early_hits == early_before, "sem parry não conta como parry cedo")
	_check(is_equal_approx(_player.charge.value, 30.0 - _player.data.charge_damage_loss),
			"tomar dano tira %.0f de Carga" % _player.data.charge_damage_loss)


func _test_crossbow_targeting_and_bolt() -> void:
	print("\n[Besteiro: troca de alvo, virote, Dardo de Raio e Passo Relâmpago]")
	_sandbox.reset()
	_enemy.auto_attack = false
	var bowman := _sandbox.spawn_extra_enemy(CROSSBOW_DATA, CROSSBOW_POSITION)
	# Sem atacar até o teste estar esperando o aviso (senão o 1º aviso pode passar despercebido).
	bowman.auto_attack = false
	await _wait(bowman.data.spawn_time + SETTLE_TIME)

	var first := _player.target
	_player.targeting.cycle(1)
	_check(_player.target != null and _player.target != first, "A/D troca o alvo entre os inimigos")

	bowman.auto_attack = true
	var parries_before := _parries
	var time_to_impact: float = await bowman.attack_telegraphed
	await _wait(time_to_impact - PARRY_LEAD_TIME)
	_player.input_buffer.press(&"parry")
	await _wait(PARRY_LEAD_TIME + SETTLE_TIME)
	_check(_parries == parries_before + 1, "parry anula o virote")
	_check(is_equal_approx(_player.health.current_health, _player.health.max_health), "virote aparado não causa dano")
	_check(not bowman.is_stunned(), "parry no virote não atordoa o besteiro")

	time_to_impact = await bowman.attack_telegraphed
	await _wait(time_to_impact + SETTLE_TIME)
	var expected_hp := _player.health.max_health - bowman.data.attack_damage * (1.0 - _player.data.damage_reduction)
	_check(is_equal_approx(_player.health.current_health, expected_hp), "virote sem defesa causa o dano integral")

	bowman.auto_attack = false
	await _wait(_player.data.hurt_time + SETTLE_TIME)
	_player.targeting.set_target(bowman)
	var bolts_before := _bolts
	var dashes_before := _dashes
	var hp_before := bowman.health.current_health
	_player.input_buffer.press(&"attack")
	await _wait(_player.data.bolt_cast_time + _player.data.dash_duration + _hit_land_time())
	var weapon := _player.weapon
	# O Dardo eletrocuta: o 1º golpe de espada logo depois é crítico (GDD §6.9).
	var expected := weapon.base_damage * (_player.data.bolt_damage_multiplier
			+ weapon.combo_multipliers[0] * Enemy.SHOCK_CRIT_MULTIPLIER)
	_check(_bolts == bolts_before + 1, "alvo distante: dispara o Dardo de Raio")
	_check(_dashes == dashes_before + 1, "alvo distante: faz o Passo Relâmpago")
	_check(_player.is_target_in_melee_range(), "Passo Relâmpago termina ao alcance da espada")
	_check(is_equal_approx(hp_before - bowman.health.current_health, expected),
			"Dardo + 1º golpe (crítico no eletrocutado) causam %.0f (recebeu %.0f)" % [expected, hp_before - bowman.health.current_health])

	await _wait(weapon.hit_recovery + SETTLE_TIME)
	_player.global_position = Vector3.ZERO
	await _wait(SETTLE_TIME)
	bolts_before = _bolts
	dashes_before = _dashes
	_player.input_buffer.press(&"attack")
	await _wait(_player.data.dash_duration + SETTLE_TIME)
	_check(_bolts == bolts_before and _dashes == dashes_before + 1, "Dardo em recarga: só faz o Passo Relâmpago")


func _test_elements_and_charge() -> void:
	print("\n[Ciclo elemental e Carga por golpe]")
	_sandbox.reset()
	_enemy.auto_attack = false
	_player.set_element(Element.Type.DIVINE)
	var base := _player.weapon.base_damage * _player.weapon.combo_multipliers[0]
	var cases: Array = [
		[Element.Type.DEMONIC, 1.5, "Divino > Demoníaco: vantagem 1,5×"],
		[Element.Type.HEROIC, 0.75, "Heroico > Divino: desvantagem 0,75×"],
		[Element.Type.DIVINE, 1.0, "mesmo elemento: 1×"],
	]
	for case: Array in cases:
		_enemy.set_element(case[0])
		var hp_before := _enemy.health.current_health
		_player.input_buffer.press(&"attack")
		await _wait(_hit_land_time())
		var dealt := hp_before - _enemy.health.current_health
		_check(is_equal_approx(dealt, base * case[1]), "%s (%.1f de dano)" % [case[2], dealt])
		await _wait(COMBO_BREAK_TIME)
	_check(is_equal_approx(_player.charge.value, _player.data.charge_combo_hit * cases.size()),
			"cada golpe de combo dá +%.0f de Carga" % _player.data.charge_combo_hit)
	_player.set_element(Element.Type.NONE)
	_enemy.set_element(Element.Type.NONE)


func _test_voltaic_blade() -> void:
	print("\n[Lâmina Voltaica]")
	_sandbox.reset()
	_enemy.auto_attack = true
	var time_to_impact: float = await _enemy.attack_telegraphed
	await _wait(0.2)
	var hp_before := _enemy.health.current_health
	_player.input_buffer.press(&"skill_1")
	var blade := _player.powers.power(0)
	await _wait(blade.cast_time + SETTLE_TIME)
	_enemy.auto_attack = false
	_check(not _enemy.is_telegraphing() and not _enemy.state_machine.is_in(&"Strike"), "interrompe o aviso do inimigo")
	var expected := _player.weapon.base_damage * blade.damage_multiplier
	_check(is_equal_approx(hp_before - _enemy.health.current_health, expected), "causa %.0f de dano" % expected)
	await _wait(time_to_impact)
	_check(is_equal_approx(_player.health.current_health, _player.health.max_health), "o golpe interrompido não acerta o herói")
	_check(not _player.powers.cooldown(0).is_ready, "entra em recarga")
	_player.input_buffer.press(&"skill_1")
	await _wait(blade.cast_time + SETTLE_TIME)
	_check(_player.state_machine.is_in(&"Idle"), "em recarga, a tecla 1 não faz nada")


func _test_chain_lightning() -> void:
	print("\n[Corrente em Cadeia]")
	_sandbox.reset()
	_enemy.auto_attack = false
	var all: Array[Enemy] = [_enemy]
	var offsets: Array[Vector3] = [Vector3(-2.0, 0, -3.0), Vector3(2.0, 0, -3.0), Vector3(-1.5, 0, 2.0), Vector3(1.5, 0, 2.0)]
	for offset: Vector3 in offsets:
		var extra := _sandbox.spawn_extra_enemy(SOLDIER_DATA, offset)
		extra.auto_attack = false
		all.append(extra)
	await _wait(SOLDIER_DATA.spawn_time + 0.8)
	_player.targeting.set_target(_enemy)
	var before: Array[float] = []
	for enemy: Enemy in all:
		before.append(enemy.health.current_health)
	_player.input_buffer.press(&"skill_2")
	var chain := _player.powers.power(1)
	await _wait(chain.cast_time + SETTLE_TIME)
	var dealt: Array[float] = []
	for i: int in all.size():
		var amount := before[i] - all[i].health.current_health
		if amount > 0.0:
			dealt.append(amount)
	dealt.sort()
	dealt.reverse()
	var expected: Array[float] = []
	for multiplier: float in chain.chain_multipliers:
		expected.append(_player.weapon.base_damage * multiplier)
	_check(dealt.size() == chain.chain_multipliers.size(),
			"atinge o alvo + %d saltos, com 5 inimigos perto (atingiu %d)" % [chain.chain_multipliers.size() - 1, dealt.size()])
	_check(dealt == expected, "dano decrescente %s (recebido %s)" % [expected, dealt])


func _test_storm_fury() -> void:
	print("\n[Fúria da Tempestade]")
	_sandbox.reset()
	_enemy.auto_attack = false
	var neighbor := _sandbox.spawn_extra_enemy(SOLDIER_DATA, Vector3(1.5, 0.0, -3.0))
	neighbor.auto_attack = false
	await _wait(SOLDIER_DATA.spawn_time + 0.8)
	_player.targeting.set_target(_enemy)
	var fury := _player.powers.power(2)
	_player.input_buffer.press(&"skill_3")
	await _wait(fury.cast_time + SETTLE_TIME)
	_check(is_equal_approx(_enemy.health.current_health, _enemy.health.max_health), "sem Carga cheia, não é lançada")
	_player.charge.add(_player.data.charge_max)
	# Os inimigos circulam o herói; põe o vizinho colado no alvo logo antes de lançar.
	neighbor.global_position = _enemy.global_position + _enemy.global_basis.x * 1.3
	var neighbor_distance := neighbor.global_position.distance_to(_enemy.global_position)
	_player.input_buffer.press(&"skill_3")
	await _wait(fury.cast_time + SETTLE_TIME)
	var base := _player.weapon.base_damage
	_check(is_equal_approx(_enemy.health.max_health - _enemy.health.current_health, base * fury.damage_multiplier),
			"alvo recebe %.0f" % (base * fury.damage_multiplier))
	_check(neighbor_distance <= fury.area_radius, "vizinho está dentro do raio de %.0f m (%.1f m)" % [fury.area_radius, neighbor_distance])
	_check(is_equal_approx(neighbor.health.max_health - neighbor.health.current_health, base * fury.area_multiplier),
			"vizinho recebe %.0f de área" % (base * fury.area_multiplier))
	_check(is_zero_approx(_player.charge.value), "consome toda a Carga")


func _test_elite_double_strike() -> void:
	print("\n[Elite: golpe duplo]")
	_sandbox.reset()
	_enemy.auto_attack = false
	var elite := _sandbox.spawn_extra_enemy(ELITE_DATA, Vector3(2.0, 0.0, -1.5))
	var time_to_impact: float = await elite.attack_telegraphed
	# O 2º aviso começa strike_active_time depois do impacto: espera só metade disso.
	await _wait(time_to_impact + elite.data.strike_active_time * 0.5)
	_check(_player.health.current_health < _player.health.max_health, "1º golpe da Elite acerta sem defesa")
	var hp_after_first := _player.health.current_health
	var parries_before := _parries
	time_to_impact = await elite.attack_telegraphed
	_check(elite.state_machine.is_in(&"Telegraph"), "2º aviso vem logo em seguida, no mesmo ataque")
	await _wait(time_to_impact - PARRY_LEAD_TIME)
	_player.input_buffer.press(&"parry")
	await _wait(PARRY_LEAD_TIME + SETTLE_TIME)
	_check(_parries == parries_before + 1, "2º golpe pode ser aparado (parries: +%d)" % (_parries - parries_before))
	_check(is_equal_approx(_player.health.current_health, hp_after_first),
			"2º golpe aparado não causa dano (vida %.0f → %.0f)" % [hp_after_first, _player.health.current_health])
	_check(elite.is_stunned(), "aparar o 2º golpe atordoa a Elite")
	elite.auto_attack = false

func _test_free_movement() -> void:
	print("\n[Movimento livre: andar, esquiva e bloqueio]")
	_sandbox.reset()
	_enemy.auto_attack = false
	await _wait(SETTLE_TIME)
	_player.use_scripted_input = true
	var start := _player.global_position
	_player.scripted_move_input = Vector2(1.0, 0.0)
	await _wait(0.6)
	_player.scripted_move_input = Vector2.ZERO
	var moved := _player.global_position.x - start.x
	_check(moved > 1.5, "anda para o lado com a entrada (andou %.1f m em 0,6 s)" % moved)
	await _wait(0.3)
	_check(_player.horizontal_speed() < 0.2, "para de andar ao soltar (desaceleração)")

	_sandbox.reset()
	_enemy.auto_attack = true
	var time_to_impact: float = await _enemy.attack_telegraphed
	await _wait(time_to_impact - 0.1)
	var before_dodge := _player.global_position
	_player.input_buffer.press(&"dodge")
	await _wait(0.1 + SETTLE_TIME + 0.3)
	_check(is_equal_approx(_player.health.current_health, _player.health.max_health), "esquiva no impacto: invencível, sem dano")
	_check(_player.global_position.distance_to(before_dodge) > _player.data.dodge_distance * 0.7,
			"esquiva desloca ~%.0f m" % _player.data.dodge_distance)

	_sandbox.reset()
	_enemy.auto_attack = true
	_player.scripted_defend_held = true
	time_to_impact = await _enemy.attack_telegraphed
	await _wait(time_to_impact - 0.6)
	_player.input_buffer.press(&"parry")
	await _wait(0.6 + SETTLE_TIME)
	var blocked := _player.health.max_health - _player.health.current_health
	var expected_block := _enemy.data.attack_damage * (1.0 - _player.data.block_reduction)
	_check(_player.state_machine.is_in(&"Block"), "segurando a defesa após a janela vira Bloqueio")
	_check(is_equal_approx(blocked, expected_block), "bloqueio reduz o dano para %.1f (recebeu %.1f)" % [expected_block, blocked])
	_player.scripted_defend_held = false
	_player.use_scripted_input = false
	_enemy.auto_attack = false
	await _wait(SETTLE_TIME)


func _test_combo_and_kill() -> void:
	print("\n[Combo de 3 golpes]")
	_sandbox.reset()
	_enemy.auto_attack = false
	await _wait(SETTLE_TIME)
	var weapon := _player.weapon
	for i: int in weapon.combo_multipliers.size():
		_player.input_buffer.press(&"attack")
		await _wait(COMBO_PRESS_INTERVAL)
	await _wait(weapon.final_hit_recovery)
	var expected := 0.0
	for multiplier: float in weapon.combo_multipliers:
		expected += weapon.base_damage * multiplier
	var dealt := _enemy.health.max_health - _enemy.health.current_health
	_check(is_equal_approx(dealt, expected), "combo completo causa %.0f (recebeu %.0f)" % [expected, dealt])

	await _wait(_player.data.combo_reset_time + SETTLE_TIME)
	var hp_before := _enemy.health.current_health
	_player.input_buffer.press(&"attack")
	await _wait(_hit_land_time())
	_check(_enemy.health.current_health < hp_before, "após a pausa o combo recomeça do 1º golpe")
	_check(_enemy.health.is_dead and _enemy.state_machine.is_in(&"Dead"), "inimigo com 0 de vida vai para Dead")


# --- Utilidades -------------------------------------------------------------

func _hit_land_time() -> float:
	return _player.weapon.hit_windup + _player.weapon.hit_active + SETTLE_TIME


func _expected_hp_after_one_hit() -> float:
	var damage := _enemy.data.attack_damage * (1.0 - _player.data.damage_reduction)
	return _player.health.max_health - damage


## Espera em tempo de JOGO (respeita hitstop e câmera lenta).
func _wait(seconds: float) -> void:
	await get_tree().create_timer(maxf(seconds, 0.001), true, true).timeout


func _check(condition: bool, description: String) -> void:
	print("  %s %s" % ["PASS" if condition else "FAIL", description])
	if not condition:
		_failures += 1


func _on_parry(_attacker: Node3D) -> void:
	_parries += 1


func _on_hit_taken(_info: DamageInfo, parry_was_early: bool) -> void:
	if parry_was_early:
		_early_hits += 1


func _on_bolt_fired(_target: Enemy) -> void:
	_bolts += 1


func _on_dash_started(_from: Vector3, _to: Vector3) -> void:
	_dashes += 1


func _on_timeout() -> void:
	push_error("Teste excedeu %d s" % TIMEOUT_SECONDS)
	get_tree().quit(2)
