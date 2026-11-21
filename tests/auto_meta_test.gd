extends Node
## Teste automático da progressão: loja, save/load, XP e níveis, upgrades + nível aplicados ao herói
## na trilha, morte (volta à fogueira guardando metade do ouro) e pausa. Na pasta do projeto:
##   godot --headless --path . --fixed-fps 60 res://tests/auto_meta_test.tscn
## Sai com código 0 se tudo passar e 1 se algo falhar. Usa um arquivo de save próprio.

const SWORD: UpgradeData = preload("res://data/upgrades/sword.tres")
const ARMOR: UpgradeData = preload("res://data/upgrades/armor.tres")
const TRAIL_SCENE: PackedScene = preload("res://scenes/levels/trail_01.tscn")
const PAUSE_SCENE: PackedScene = preload("res://ui/menus/pause_menu.tscn")
const TEST_SAVE_PATH := "user://test_save.json"

var _failures: int = 0


func _ready() -> void:
	SaveManager.persist = false
	GameState.reset()
	_test_shop()
	_test_save_roundtrip()
	_test_levels()
	await _test_upgrades_applied()
	await _test_death_respawn()
	await _test_pause()
	GameState.reset()
	print("\n%s — %d falha(s)" % ["META OK" if _failures == 0 else "META FALHOU", _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _test_shop() -> void:
	print("\n[Loja]")
	GameState.reset()
	GameState.add_gold(60)
	_check(GameState.try_buy(SWORD), "compra o nível 1 da Espada com 60 de ouro")
	_check(GameState.level_of(SWORD) == 1 and GameState.gold == 10, "nível 1, sobram 10 de ouro")
	_check(not GameState.try_buy(SWORD), "sem ouro suficiente, não compra o nível 2 (custa 100)")
	GameState.add_gold(10000)
	while GameState.try_buy(SWORD):
		pass
	_check(GameState.level_of(SWORD) == SWORD.max_level(), "para no nível máximo (%d)" % SWORD.max_level())
	_check(SWORD.cost_for_next(GameState.level_of(SWORD)) == -1 and not GameState.can_buy(SWORD), "no máximo, não há próximo custo")
	var spent := 0
	for cost: int in SWORD.costs:
		spent += cost
	_check(GameState.gold == 60 + 10000 - spent, "gasto total da Espada = %d" % spent)


func _test_save_roundtrip() -> void:
	print("\n[Save em JSON]")
	SaveManager.save_path = TEST_SAVE_PATH
	SaveManager.persist = true
	GameState.reset()
	GameState.add_gold(321)
	GameState.add_gold(1000)
	GameState.try_buy(ARMOR)
	GameState.try_buy(ARMOR)
	GameState.sword_element = Element.Type.HEROIC
	var gold_before := GameState.gold
	_check(SaveManager.save_game(), "grava o arquivo")
	GameState.reset()
	_check(SaveManager.load_game(), "lê o arquivo")
	_check(GameState.gold == gold_before, "ouro preservado (%d)" % GameState.gold)
	_check(GameState.level_of(ARMOR) == 2, "nível da Armadura preservado")
	_check(GameState.sword_element == Element.Type.HEROIC, "elemento preservado")
	SaveManager.delete_save()
	_check(not FileAccess.file_exists(TEST_SAVE_PATH), "apaga o arquivo de teste")
	SaveManager.persist = false
	SaveManager.save_path = SaveManager.DEFAULT_PATH


func _test_levels() -> void:
	print("
[XP e níveis]")
	GameState.reset()
	var progression := GameState.progression
	var first := progression.xp_to_next(1)
	_check(GameState.add_xp(first - 1) == 0 and GameState.level == 1, "abaixo de %d XP continua no nível 1" % first)
	_check(GameState.add_xp(1) == 1 and GameState.level == 2 and GameState.xp == 0, "com %d XP sobe para o nível 2" % first)
	var big := progression.xp_to_next(2) + progression.xp_to_next(3) + 5
	_check(GameState.add_xp(big) == 2 and GameState.level == 4 and GameState.xp == 5, "XP de sobra sobe vários níveis de uma vez")
	_check(progression.extra_enemies(1) == 0 and progression.extra_enemies(5) == 2, "nível 5 traz 2 inimigos extras por onda")
	_check(progression.enemy_health_scale(5) > 1.0, "inimigos ficam mais fortes com o nível do herói")


func _test_upgrades_applied() -> void:
	print("
[Upgrades e nível aplicados ao herói]")
	GameState.reset()
	GameState.add_gold(10000)
	GameState.try_buy(SWORD)
	GameState.try_buy(SWORD)
	GameState.try_buy(ARMOR)
	GameState.add_xp(GameState.progression.xp_to_next(1))
	var level := _spawn_trail()
	await get_tree().physics_frame
	var bonus := GameState.level - 1
	var expected_damage := SWORD.value_at(2) + bonus * GameState.progression.damage_per_level
	var expected_health := ARMOR.value_at(1) + bonus * GameState.progression.health_per_level
	_check(is_equal_approx(level.player.base_damage, expected_damage), "Espada nv 2 + nível 2 → ATK %.0f" % expected_damage)
	_check(is_equal_approx(level.player.health.max_health, expected_health), "Armadura nv 1 + nível 2 → vida %.0f" % expected_health)
	_check(is_equal_approx(level.player.damage_reduction, ARMOR.secondary_at(1)), "Armadura nv 1 → redução %.0f%%" % (ARMOR.secondary_at(1) * 100.0))
	level.queue_free()
	await get_tree().physics_frame


func _test_death_respawn() -> void:
	print("
[Morte: volta à fogueira]")
	GameState.reset()
	var level := _spawn_trail()
	await get_tree().physics_frame
	var start := level.player.global_position
	level.player.global_position = start + Vector3(0.0, 0.5, -6.0)
	level.run_gold = 35
	var info := DamageInfo.new()
	info.amount = 9999.0
	level.player.hurtbox.receive_hit(info)
	_check(level.player.health.is_dead, "golpe fatal mata o herói")
	await level.player_respawned
	var expected := floori(35 * level.rewards.death_keep_fraction)
	_check(GameState.gold == expected and level.run_gold == 0, "guarda %d de 35 de ouro não guardado (50%%)" % expected)
	_check(not level.player.health.is_dead and is_equal_approx(level.player.health.current_health, level.player.health.max_health),
			"volta com a vida cheia")
	_check(level.player.global_position.distance_to(start) < 1.5, "volta ao ponto de partida (sem fogueira acesa)")
	level.queue_free()
	await get_tree().physics_frame


func _test_pause() -> void:
	print("\n[Pausa]")
	var menu := PAUSE_SCENE.instantiate() as PauseMenu
	add_child(menu)
	_check(get_tree().paused, "abrir a pausa congela o jogo")
	menu._resume()
	_check(not get_tree().paused, "Continuar descongela")
	await get_tree().process_frame


func _spawn_trail() -> WorldLevel:
	var level := TRAIL_SCENE.instantiate() as WorldLevel
	level.show_element_select = false
	level.capture_mouse = false
	add_child(level)
	return level


func _check(condition: bool, description: String) -> void:
	print("  %s %s" % ["PASS" if condition else "FAIL", description])
	if not condition:
		_failures += 1
