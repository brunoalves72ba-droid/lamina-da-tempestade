class_name StoryOverlay
extends Control
## Parte da HUD ligada à história e à mira (GDD §4.1, §6.4):
## - caixa de objetivo (arco atual + o que fazer agora), no canto superior direito;
## - legendas de narração/diálogo em fila, embaixo no centro;
## - mira no centro da tela no modo de mira livre.
## Escuta só Events (objective_changed, narration_requested, aim_mode_changed).

const OBJECTIVE_COLOR := Color(1.0, 0.86, 0.55)
const SPEAKER_COLOR := Color(0.6, 0.85, 1.0)
const NARRATION_FADE: float = 0.25

var _arc_label: Label
var _objective_label: Label
var _objective_tween: Tween
var _narration_panel: PanelContainer
var _speaker_label: Label
var _line_label: Label
var _queue: Array[Array] = []  # [quem, texto, duração]
var _line_time: float = 0.0
var _crosshair: Label
var _weather_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_objective()
	_build_narration()
	_build_crosshair()
	Events.objective_changed.connect(show_objective)
	Events.narration_requested.connect(queue_line)
	Events.weather_changed.connect(func(weather_name: String, is_storm: bool) -> void:
		_weather_label.text = weather_name.to_upper() + ("  ·  raios +30%" if is_storm else "")
		_weather_label.add_theme_color_override(&"font_color", Color(0.65, 0.85, 1.0) if is_storm else Color(0.7, 0.7, 0.72)))
	Events.aim_mode_changed.connect(func(mode: int) -> void: _crosshair.visible = mode == GameState.AimMode.FREE)
	_crosshair.visible = GameState.aim_mode == GameState.AimMode.FREE


func _process(delta: float) -> void:
	if _line_time > 0.0:
		_line_time -= delta
		if _line_time <= 0.0:
			_next_line()
	elif not _queue.is_empty():
		_next_line()


func show_objective(arc_title: String, objective_text: String) -> void:
	_arc_label.text = arc_title.to_upper()
	_objective_label.text = ("◆ " + objective_text) if objective_text != "" else ""
	if _objective_tween != null:
		_objective_tween.kill()
	_objective_label.modulate = Color(1.6, 1.6, 1.2)
	_objective_tween = create_tween()
	_objective_tween.tween_property(_objective_label, "modulate", Color.WHITE, 1.2)


func queue_line(speaker: String, text: String, duration: float) -> void:
	_queue.append([speaker, text, duration])


## Fala exibida agora (testes e cutscenes).
func current_line() -> String:
	return _line_label.text if _narration_panel.visible else ""


func objective_text() -> String:
	return _objective_label.text


func _next_line() -> void:
	if _queue.is_empty():
		var tween := create_tween()
		tween.tween_property(_narration_panel, "modulate:a", 0.0, NARRATION_FADE)
		tween.tween_callback(func() -> void: _narration_panel.visible = _line_time > 0.0)
		_line_time = 0.0
		return
	var line: Array = _queue.pop_front()
	_speaker_label.text = String(line[0]).to_upper()
	_line_label.text = line[1]
	_line_time = line[2]
	_narration_panel.visible = true
	_narration_panel.modulate.a = 1.0


func _build_objective() -> void:
	var box := VBoxContainer.new()
	box.name = "Objective"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	box.offset_left = -430.0
	box.offset_right = -24.0
	box.offset_top = 92.0
	box.offset_bottom = 160.0
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(box)
	_arc_label = _label(15, Color(0.75, 0.72, 0.65), HORIZONTAL_ALIGNMENT_RIGHT)
	box.add_child(_arc_label)
	_objective_label = _label(20, OBJECTIVE_COLOR, HORIZONTAL_ALIGNMENT_RIGHT)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_objective_label)
	_weather_label = _label(14, Color(0.7, 0.7, 0.72), HORIZONTAL_ALIGNMENT_RIGHT)
	box.add_child(_weather_label)


func _build_narration() -> void:
	_narration_panel = PanelContainer.new()
	_narration_panel.name = "Narration"
	_narration_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_narration_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_narration_panel.offset_left = -380.0
	_narration_panel.offset_right = 380.0
	_narration_panel.offset_top = -270.0
	_narration_panel.offset_bottom = -190.0
	_narration_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_narration_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.02, 0.03, 0.72)
	style.border_color = Color(0.45, 0.38, 0.25, 0.8)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 8
	style.content_margin_bottom = 10
	_narration_panel.add_theme_stylebox_override(&"panel", style)
	_narration_panel.visible = false
	add_child(_narration_panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_narration_panel.add_child(column)
	_speaker_label = _label(14, SPEAKER_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(_speaker_label)
	_line_label = _label(19, Color(0.95, 0.93, 0.88), HORIZONTAL_ALIGNMENT_CENTER)
	_line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_line_label)


func _build_crosshair() -> void:
	_crosshair = _label(30, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	_crosshair.name = "Crosshair"
	_crosshair.text = "+"
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.offset_left = -20.0
	_crosshair.offset_right = 20.0
	_crosshair.offset_top = -24.0
	_crosshair.offset_bottom = 16.0
	add_child(_crosshair)


func _label(size: int, color: Color, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = align
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_constant_override(&"outline_size", 6)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	return label
