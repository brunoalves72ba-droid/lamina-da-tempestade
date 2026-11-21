class_name SettingsMenu
extends CanvasLayer
## Configurações (GDD §11): gráficos, modo de mira, gore, volume e a lista de controles.
## Tudo é salvo na hora. Abre pelo menu principal e pela pausa.

signal closed

const CONTROLS: Array[String] = [
	"WASD — andar  ·  Shift — correr  ·  Espaço — esquiva relâmpago",
	"Botão esquerdo / J — atacar  ·  Botão direito / K — parry e bloqueio",
	"1 / 2 / 3 — poderes  ·  Q / botão do meio — travar alvo  ·  Tab / roda — trocar alvo",
	"T — mira livre / assistida  ·  E — interagir (fogueira: loja)  ·  Esc — pausa",
]

## Ambiente da fase (para aplicar a qualidade na hora); pode ficar vazio no menu.
var environment: Environment

var _column: VBoxContainer
var _first: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_column = MenuKit.overlay(self)
	_column.add_child(MenuKit.label("CONFIGURAÇÕES", 32))
	_add_option("Gráficos", GraphicsSettings.NAMES, GameState.graphics_quality, func(index: int) -> void:
		GameState.graphics_quality = index
		GraphicsSettings.apply(get_viewport(), environment, index))
	_add_option("Mira", ["Assistida (destaca o alvo)", "Livre (acerta onde apontar)"], GameState.aim_mode, func(index: int) -> void:
		GameState.aim_mode = index as GameState.AimMode
		Events.aim_mode_changed.emit(index))
	_add_option("Sangue e desmembramento", ["Ligado", "Desligado"], 0 if GameState.gore_enabled else 1, func(index: int) -> void:
		GameState.gore_enabled = index == 0)
	_add_volume()
	_column.add_child(MenuKit.label("Controles", 20, MenuKit.GOLD_COLOR))
	for line: String in CONTROLS:
		_column.add_child(MenuKit.label(line, 14, MenuKit.MUTED_COLOR))
	var back := MenuKit.button("Voltar", _close)
	_column.add_child(back)
	(_first if _first != null else back).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	SaveManager.save_game()
	closed.emit()
	queue_free()


func _add_option(title: String, options: Array, selected: int, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	var label := MenuKit.label(title, 18)
	label.custom_minimum_size = Vector2(240, 0)
	row.add_child(label)
	var picker := OptionButton.new()
	picker.custom_minimum_size = Vector2(300, 40)
	for option: String in options:
		picker.add_item(option)
	picker.select(selected)
	picker.item_selected.connect(on_change)
	row.add_child(picker)
	_column.add_child(row)
	if _first == null:
		_first = picker


func _add_volume() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	var label := MenuKit.label("Volume", 18)
	label.custom_minimum_size = Vector2(240, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(300, 32)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = db_to_linear(AudioServer.get_bus_volume_db(0))
	slider.value_changed.connect(func(value: float) -> void:
		AudioServer.set_bus_volume_db(0, linear_to_db(maxf(value, 0.0001)))
		GameState.master_volume = value)
	row.add_child(slider)
	_column.add_child(row)
