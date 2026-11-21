class_name ElementSelect
extends CanvasLayer
## Escolha do elemento da espada antes da fase (GDD §4, §7). Clique ou teclas 1/2/3.

signal element_chosen(element: int)

@onready var _divine_button: Button = %DivineButton
@onready var _demonic_button: Button = %DemonicButton
@onready var _heroic_button: Button = %HeroicButton


func _ready() -> void:
	_style(_divine_button, Element.Type.DIVINE)
	_style(_demonic_button, Element.Type.DEMONIC)
	_style(_heroic_button, Element.Type.HEROIC)
	_divine_button.pressed.connect(_choose.bind(Element.Type.DIVINE))
	_demonic_button.pressed.connect(_choose.bind(Element.Type.DEMONIC))
	_heroic_button.pressed.connect(_choose.bind(Element.Type.HEROIC))
	_divine_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"skill_1"):
		_choose(Element.Type.DIVINE)
	elif event.is_action_pressed(&"skill_2"):
		_choose(Element.Type.DEMONIC)
	elif event.is_action_pressed(&"skill_3"):
		_choose(Element.Type.HEROIC)


func _style(button: Button, element: Element.Type) -> void:
	var color := Element.color(element)
	button.add_theme_color_override(&"font_color", color)
	button.add_theme_color_override(&"font_hover_color", color.lightened(0.3))
	button.add_theme_color_override(&"font_focus_color", color.lightened(0.3))


func _choose(element: Element.Type) -> void:
	get_viewport().set_input_as_handled()
	element_chosen.emit(element)
