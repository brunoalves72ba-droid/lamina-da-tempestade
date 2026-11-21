class_name MenuKit
extends RefCounted
## Peças comuns das telas de menu (painel escurecido, títulos, botões), para todas ficarem iguais.

const DIM_COLOR := Color(0.0, 0.0, 0.0, 0.6)
const PANEL_COLOR := Color(0.05, 0.05, 0.07, 0.94)
const BORDER_COLOR := Color(0.3, 0.3, 0.38)
const MUTED_COLOR := Color(0.72, 0.72, 0.78)
const GOLD_COLOR := Color(1.0, 0.82, 0.35)
const BUTTON_SIZE := Vector2(300, 46)
const PANEL_MARGIN: float = 32.0
const SPACING: int = 14


## Fundo escurecido + painel centralizado. Retorna a coluna onde entram os itens.
static func overlay(layer: CanvasLayer, dim_color: Color = DIM_COLOR) -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = dim_color
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	return panel(center)


static func panel(parent: Control) -> VBoxContainer:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(2)
	style.set_content_margin_all(PANEL_MARGIN)
	var panel_container := PanelContainer.new()
	panel_container.add_theme_stylebox_override(&"panel", style)
	parent.add_child(panel_container)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", SPACING)
	panel_container.add_child(column)
	return column


static func label(text: String, font_size: int = 18, color: Color = Color.WHITE) -> Label:
	var result := Label.new()
	result.text = text
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.add_theme_font_size_override(&"font_size", font_size)
	result.add_theme_color_override(&"font_color", color)
	return result


static func button(text: String, on_pressed: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size = BUTTON_SIZE
	result.add_theme_font_size_override(&"font_size", 20)
	result.pressed.connect(on_pressed)
	return result
