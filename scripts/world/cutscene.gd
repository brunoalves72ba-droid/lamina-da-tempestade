class_name Cutscene
extends Node
## Cenas cinematográficas curtas (GDD §4.2): faixas pretas, câmera própria, título e narração.
## O herói fica parado e invulnerável enquanto toca; Espaço/Enter/Esc pulam.
## - Introdução: voo sobre o vale até o herói, contando quem ele é e o objetivo.
## - Chefão derrotado: órbita lenta em câmera lenta em volta do corpo.
## - Arco concluído: cartão de título.
## - Final: a câmera sobe sobre o santuário, epílogo e "FIM".

signal finished

const BAR_HEIGHT: float = 90.0

var level: WorldLevel
var is_playing: bool = false

var _camera: Camera3D
var _layer: CanvasLayer
var _bars: Array[ColorRect] = []
var _title: Label
var _subtitle: Label
var _skip_hint: Label
var _skipped: bool = false
var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 40
	_layer.visible = false
	add_child(_layer)
	for top: bool in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		if top:
			bar.offset_bottom = BAR_HEIGHT
		else:
			bar.offset_top = -BAR_HEIGHT
		_layer.add_child(bar)
		_bars.append(bar)
	_title = _make_label(46, Color(0.85, 0.92, 1.0))
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_title.offset_left = -600.0
	_title.offset_right = 600.0
	_title.offset_top = -80.0
	_title.offset_bottom = -20.0
	_subtitle = _make_label(20, Color(0.75, 0.72, 0.65))
	_subtitle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_subtitle.offset_left = -600.0
	_subtitle.offset_right = 600.0
	_subtitle.offset_top = -10.0
	_subtitle.offset_bottom = 30.0
	_skip_hint = _make_label(14, Color(0.6, 0.6, 0.65))
	_skip_hint.text = "Espaço: pular"
	_skip_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip_hint.offset_left = -220.0
	_skip_hint.offset_right = -24.0
	_skip_hint.offset_top = -60.0
	_skip_hint.offset_bottom = -30.0
	_camera = Camera3D.new()
	_camera.fov = 55.0
	add_child(_camera)


func _unhandled_input(event: InputEvent) -> void:
	if not is_playing:
		return
	if event.is_action_pressed(&"dodge") or event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		_skipped = true


# --- Cenas ------------------------------------------------------------------------

func play_intro() -> void:
	_begin()
	_show_title("LÂMINA DA TEMPESTADE", "Valdren, o reino que a Mácula engoliu")
	var lines: Array[String] = [
		"Há um ano, a Mácula subiu das criptas de Valdren. Vilas, estradas e homens viraram sombra.",
		"A Ordem do Grifo de Prata caiu defendendo o vale. Só um cavaleiro voltou: Kael.",
		"No dia em que tudo acabou, um raio atingiu a espada dele — e ficou nela.",
		"Kael|O Santuário das Tempestades fica no fim desta trilha. Se o fogo do céu ainda arde lá, eu o reacendo.",
	]
	var route_end := level.route_point(level.route_length())
	var start := level.route_point(0.0)
	var high := start.lerp(route_end, 0.5) + Vector3.UP * 45.0
	_camera.global_position = route_end + Vector3(0.0, 30.0, 0.0)
	_camera.look_at(start, Vector3.UP)
	_camera.make_current()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(_fly.bind(route_end + Vector3(0, 30, 0), high, start), 0.0, 1.0, 7.0)
	var hero_view := level.player.global_position + level.player.global_basis.z * 4.5 + Vector3.UP * 2.2
	_tween.tween_method(_fly.bind(high, hero_view, level.player.global_position + Vector3.UP * 1.2), 0.0, 1.0, 5.0)
	await _narrate(lines, 12.0)
	_end()


func play_boss_defeat(boss: Enemy, title: String) -> void:
	_begin()
	var center := boss.global_position
	Hitstop.apply(get_tree(), 0.35, 3.2)
	_show_title(title.to_upper(), "derrotado")
	_tween = create_tween().set_ignore_time_scale(true)
	_tween.tween_method(func(t: float) -> void:
		var angle := t * PI * 0.8
		_camera.global_position = center + Vector3(cos(angle) * 6.0, 2.5 + t, sin(angle) * 6.0)
		_camera.look_at(center + Vector3.UP * 1.0, Vector3.UP), 0.0, 1.0, 3.2)
	_camera.make_current()
	await _wait_real(3.2)
	_end()


func play_arc_complete(arc_title: String) -> void:
	_show_card("ARCO CONCLUÍDO", arc_title)


func play_ending(lines: Array[String]) -> void:
	_begin()
	var shrine := level.route_point(level.route_length())
	_camera.global_position = shrine + Vector3(5.0, 2.0, 5.0)
	_camera.look_at(shrine + Vector3.UP * 2.0, Vector3.UP)
	_camera.make_current()
	_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_tween.tween_method(func(t: float) -> void:
		_camera.global_position = shrine + Vector3(5.0 + t * 10.0, 2.0 + t * 28.0, 5.0 + t * 6.0)
		_camera.look_at(shrine + Vector3.UP * 2.0, Vector3.UP), 0.0, 1.0, 14.0)
	for i: int in 6:
		Vfx.lightning_strike(level, shrine + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5)), Color(0.7, 0.88, 1.0), 3.0, i == 0)
		await _wait_real(0.25)
	await _narrate(lines, 10.0)
	_show_title("FIM", "Obrigado por jogar")
	await _wait_real(2.5)
	_end()


# --- Internos ---------------------------------------------------------------------

func _begin() -> void:
	is_playing = true
	_skipped = false
	_layer.visible = true
	_title.text = ""
	_subtitle.text = ""
	if _skip_hint.get_parent() == null:
		_layer.add_child(_skip_hint)
	level.player.use_scripted_input = true
	level.player.scripted_move_input = Vector2.ZERO
	level.player.hurtbox.invulnerable = true
	level.set_hud_visible(false)


func _end() -> void:
	if _tween != null:
		_tween.kill()
	Hitstop.reset()
	is_playing = false
	_layer.visible = false
	level.player.use_scripted_input = false
	level.player.hurtbox.invulnerable = false
	level.camera.camera.make_current()
	level.set_hud_visible(true)
	finished.emit()


func _fly(t: float, from: Vector3, to: Vector3, look: Vector3) -> void:
	_camera.global_position = from.lerp(to, t)
	_camera.look_at(look, Vector3.UP)


## Mostra as falas uma a uma (o tempo total é dividido entre elas); retorna ao fim ou se pular.
func _narrate(lines: Array[String], total: float) -> void:
	var each := total / maxf(lines.size(), 1)
	for line: String in lines:
		if _skipped:
			return
		var parts := line.split("|", true, 1)
		var speaker := "Narrador" if parts.size() == 1 else parts[0]
		var text := parts[0] if parts.size() == 1 else parts[1]
		Events.narration_requested.emit(speaker, text, each)
		await _wait_real(each)


func _wait_real(seconds: float) -> void:
	var timer := get_tree().create_timer(seconds, true, false, true)
	while timer.time_left > 0.0 and not _skipped:
		await get_tree().process_frame


func _show_title(title: String, subtitle: String) -> void:
	_title.text = title
	_subtitle.text = subtitle
	_title.modulate.a = 0.0
	_subtitle.modulate.a = 0.0
	var fade := create_tween().set_ignore_time_scale(true).set_parallel(true)
	fade.tween_property(_title, "modulate:a", 1.0, 0.8)
	fade.tween_property(_subtitle, "modulate:a", 1.0, 1.2)
	fade.chain().tween_interval(2.2)
	fade.chain().tween_property(_title, "modulate:a", 0.0, 0.8)
	fade.parallel().tween_property(_subtitle, "modulate:a", 0.0, 0.8)


## Cartão rápido sem tirar o controle do jogador (fim de arco).
func _show_card(title: String, subtitle: String) -> void:
	_layer.visible = true
	for bar: ColorRect in _bars:
		bar.visible = false
	if _skip_hint.get_parent() != null:
		_layer.remove_child(_skip_hint)
	_show_title(title, subtitle)
	await _wait_real(4.0)
	for bar: ColorRect in _bars:
		bar.visible = true
	if not is_playing:
		_layer.visible = false


func _make_label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_constant_override(&"outline_size", 8)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_layer.add_child(label)
	return label
