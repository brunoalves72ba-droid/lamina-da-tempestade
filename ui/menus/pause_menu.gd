class_name PauseMenu
extends CanvasLayer
## Pausa (GDD §11): Esc/P abre e fecha. Continuar, som, recomeçar a fase e sair para o menu.

signal restart_requested

var _sound_button: Button
var _continue_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	var column := MenuKit.overlay(self)
	column.add_child(MenuKit.label("PAUSA", 34))
	_continue_button = MenuKit.button("Continuar", _resume)
	column.add_child(_continue_button)
	_sound_button = MenuKit.button("", _toggle_sound)
	column.add_child(_sound_button)
	column.add_child(MenuKit.button("Recomeçar a fase", _restart))
	column.add_child(MenuKit.button("Sair para o menu", _go_to_menu))
	_refresh_sound_text()
	_continue_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		_resume()


func _resume() -> void:
	get_tree().paused = false
	queue_free()


func _toggle_sound() -> void:
	var bus := AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_mute(bus, not AudioServer.is_bus_mute(bus))
	_refresh_sound_text()


func _refresh_sound_text() -> void:
	var muted := AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master"))
	_sound_button.text = "Som: desligado" if muted else "Som: ligado"


func _restart() -> void:
	get_tree().paused = false
	restart_requested.emit()


func _go_to_menu() -> void:
	Scenes.go(get_tree(), Scenes.MAIN_MENU)
