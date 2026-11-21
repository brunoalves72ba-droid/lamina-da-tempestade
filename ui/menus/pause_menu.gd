class_name PauseMenu
extends CanvasLayer
## Pausa (GDD §11): Esc/P abre e fecha. Continuar, gráficos, som, recomeçar a fase e sair para o menu.
## Mostra o cursor enquanto aberta e devolve o modo do mouse (capturado no jogo) ao continuar.

signal restart_requested

## Ambiente da fase, para aplicar a qualidade gráfica na hora.
var environment: Environment

var _sound_button: Button
var _graphics_button: Button
var _continue_button: Button
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var column := MenuKit.overlay(self)
	column.add_child(MenuKit.label("PAUSA", 34))
	_continue_button = MenuKit.button("Continuar", _resume)
	column.add_child(_continue_button)
	_graphics_button = MenuKit.button("", _cycle_graphics)
	column.add_child(_graphics_button)
	_sound_button = MenuKit.button("", _toggle_sound)
	column.add_child(_sound_button)
	column.add_child(MenuKit.button("Configurações", _open_settings))
	column.add_child(MenuKit.button("Recomeçar a fase", _restart))
	column.add_child(MenuKit.button("Sair para o menu", _go_to_menu))
	_refresh_texts()
	_continue_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		_resume()


func _resume() -> void:
	get_tree().paused = false
	Input.mouse_mode = _previous_mouse_mode
	queue_free()


func _cycle_graphics() -> void:
	GameState.graphics_quality = (GameState.graphics_quality + 1) % GraphicsSettings.NAMES.size()
	GraphicsSettings.apply(get_viewport(), environment, GameState.graphics_quality)
	SaveManager.save_game()
	_refresh_texts()


func _toggle_sound() -> void:
	var bus := AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_mute(bus, not AudioServer.is_bus_mute(bus))
	_refresh_texts()


func _refresh_texts() -> void:
	var muted := AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master"))
	_sound_button.text = "Som: desligado" if muted else "Som: ligado"
	_graphics_button.text = "Gráficos: %s" % GraphicsSettings.display_name(GameState.graphics_quality)


func _open_settings() -> void:
	var settings := SettingsMenu.new()
	settings.environment = environment
	add_child(settings)
	settings.closed.connect(func() -> void:
		_refresh_texts()
		_continue_button.grab_focus())


func _restart() -> void:
	get_tree().paused = false
	restart_requested.emit()


func _go_to_menu() -> void:
	Scenes.go(get_tree(), Scenes.MAIN_MENU)
