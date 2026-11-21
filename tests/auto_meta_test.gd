extends Node
## Teste automático do M4 (GDD §12): loja, save/load, upgrades aplicados ao herói,
## regra de ouro na derrota e pausa. Na pasta do projeto:
##   godot --headless --path . --fixed-fps 60 res://tests/auto_meta_test.tscn
## Sai com código 0 se tudo passar e 1 se algo falhar. Usa um arquivo de save próprio.

const SWORD: UpgradeData = preload("res://data/upgrades/sword.tres")
const ARMOR: UpgradeData = preload("res://data/upgrades/armor.tres")
const ARENA_SCENE: PackedScene = preload("res://scenes/levels/arena_01.tscn")
const PAUSE_SCENE: PackedScene = preload("res://ui/menus/pause_menu.tscn")
const TEST_SAVE_PATH := "user://test_save.json"

var _failures: int = 0


func _ready() -> void:
	SaveManager.persist = false
	GameState.reset()
	_test_shop()
	_test_save_roundtrip()
	await _test_upgrades_applied()
	await _test_defeat_gold()
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


func _test_upgrades_applied() -> void:
	print("\n[Upgrades aplicados ao herói]")
	GameState.reset()
	GameState.add_gold(10000)
	GameState.try_buy(SWORD)
	GameState.try_buy(SWORD)
	GameState.try_buy(ARMOR)
	var level := _spawn_arena()
	await get_tree().physics_frame
	_check(is_equal_approx(level.player.base_damage, SWORD.value_at(2)), "Espada nv 2 → ATK %.0f" % SWORD.value_at(2))
	_check(is_equal_approx(level.player.health.max_health, ARMOR.value_at(1)), "Armadura nv 1 → vida %.0f" % ARMOR.value_at(1))
	_check(is_equal_approx(level.player.damage_reduction, ARMOR.secondary_at(1)), "Armadura nv 1 → redução %.0f%%" % (ARMOR.secondary_at(1) * 100.0))
	level.queue_free()
	await get_tree().physics_frame


func _test_defeat_gold() -> void:
	print("\n[Ouro na derrota]")
	GameState.reset()
	var level := _spawn_arena()
	await get_tree().physics_frame
	level.run_gold = 35
	level._finish(false)
	var expected := floori(35 * level.rewards.death_keep_fraction)
	_check(level.gold_earned == expected and GameState.gold == expected, "mantém %d de 35 (50%%)" % expected)
	var has_result := false
	for child: Node in level.get_children():
		has_result = has_result or child is ResultScreen
	_check(has_result, "mostra a tela de resultado")
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


func _spawn_arena() -> Level:
	var level := ARENA_SCENE.instantiate() as Level
	level.show_element_select = false
	add_child(level)
	return level


func _check(condition: bool, description: String) -> void:
	print("  %s %s" % ["PASS" if condition else "FAIL", description])
	if not condition:
		_failures += 1
