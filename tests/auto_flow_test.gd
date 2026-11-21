extends Node
## Teste do fluxo de telas (precisa de janela): menu título → carregamento → introdução →
## jogo; menu → Arena de Hordas. Não grava o save do jogador.
##   godot --path . --resolution 1280x720 res://tests/auto_flow_test.tscn

const OUT := "user://flow_shots/"
var _failures := 0


func _ready() -> void:
	# O controle fica na raiz: sobrevive às trocas de cena.
	var controller := Node.new()
	controller.set_script(get_script())
	controller.set_meta(&"controller", true)
	if not has_meta(&"controller"):
		get_tree().root.add_child.call_deferred(controller)
		return
	SaveManager.persist = false
	GameState.reset()
	GameState.game_completed = true
	await _run()


func _run() -> void:
	get_tree().change_scene_to_file(Scenes.MAIN_MENU)
	await _wait(2.5)
	var menu := get_tree().current_scene
	var texts: Array[String] = []
	for button: Node in menu.find_children("*", "Button", true, false):
		texts.append((button as Button).text)
	_check("Novo Jogo" in texts and "Arena de Hordas" in texts and "Configurações" in texts, "menu título com Novo Jogo, Arena e Configurações")
	_check(texts.any(func(t: String) -> bool: return t.begins_with("New Game+")), "New Game+ aparece depois de zerar")
	_shot("flow_menu")
	GameState.launch_mode = &"story"
	GameState.play_intro = true
	LoadingScreen.go(get_tree(), Scenes.TRAIL)
	await _wait(0.4)
	_check(get_tree().current_scene is LoadingScreen, "tela de carregamento aparece")
	_shot("flow_loading")
	var level := await _wait_level()
	_check(level != null, "a trilha carregou")
	await _wait(4.0)
	_check(level.cutscene.is_playing, "introdução cinematográfica toca")
	_shot("flow_intro")
	level.cutscene._skipped = true
	await _wait(1.0)
	var picker := level.find_children("*", "ElementSelect", true, false)
	if not picker.is_empty():
		(picker[0] as ElementSelect).element_chosen.emit(Element.Type.DIVINE)
	await _wait(1.5)
	_check(not level.cutscene.is_playing and level.is_running(), "pular a introdução libera o controle")
	_check(level._hud.story.objective_text() != "", "objetivo do arco aparece na HUD")
	_shot("flow_game")
	GameState.launch_mode = &"arena"
	LoadingScreen.go(get_tree(), Scenes.TRAIL)
	var arena := await _wait_level()
	await _wait(5.0)
	_check(arena != null and arena.is_arena() and arena._arena.wave >= 1, "Arena de Hordas começa a primeira onda")
	_check(get_tree().get_nodes_in_group(Enemy.GROUP).size() > 0, "inimigos surgem na arena")
	_shot("flow_arena")
	GameState.launch_mode = &"story"
	print("\n%s — %d falha(s)" % ["FLUXO OK" if _failures == 0 else "FLUXO FALHOU", _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _wait_level() -> WorldLevel:
	for i: int in 300:
		await get_tree().process_frame
		if get_tree().current_scene is WorldLevel:
			return get_tree().current_scene as WorldLevel
		await _wait(0.1)
	return null


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _shot(file_name: String) -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	get_viewport().get_texture().get_image().save_png(OUT + file_name + ".png")


func _check(condition: bool, description: String) -> void:
	print("  %s %s" % ["PASS" if condition else "FAIL", description])
	if not condition:
		_failures += 1
