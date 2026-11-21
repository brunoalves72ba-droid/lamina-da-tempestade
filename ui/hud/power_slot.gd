class_name PowerSlot
extends Control
## Ícone de um poder no HUD (GDD §11): círculo com a tecla, preenchimento radial da recarga
## (ou da Carga, na Fúria) e o nome embaixo. Desenhado em código, sem texturas.

const BACKGROUND := Color(0.06, 0.06, 0.08, 0.9)
const WAITING := Color(0.35, 0.35, 0.4)
const LABEL_HEIGHT: float = 22.0
const RING_WIDTH: float = 3.0
const PIE_SEGMENTS: int = 40

var key_text: String = "1"
var title: String = ""
var status_text: String = ""
## 0..1: quanto da recarga/Carga já foi cumprido (1 = pronto).
var fill: float = 1.0
var accent: Color = Color(0.6, 0.85, 1.0)


func set_state(new_title: String, new_status: String, new_fill: float, new_accent: Color) -> void:
	if new_title == title and new_status == status_text and is_equal_approx(new_fill, fill) and new_accent == accent:
		return
	title = new_title
	status_text = new_status
	fill = clampf(new_fill, 0.0, 1.0)
	accent = new_accent
	queue_redraw()


func _draw() -> void:
	var radius := minf(size.x, size.y - LABEL_HEIGHT * 2.0) * 0.5 - RING_WIDTH
	var center := Vector2(size.x * 0.5, radius + RING_WIDTH)
	var ready := fill >= 1.0
	draw_circle(center, radius, BACKGROUND)
	if not ready and fill > 0.0:
		var points := PackedVector2Array([center])
		var segments := maxi(2, ceili(PIE_SEGMENTS * fill))
		for i: int in segments + 1:
			var angle := -PI * 0.5 + TAU * fill * float(i) / float(segments)
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		draw_colored_polygon(points, Color(accent, 0.35))
	draw_arc(center, radius, 0.0, TAU, PIE_SEGMENTS, accent if ready else WAITING, RING_WIDTH, true)
	var font := get_theme_default_font()
	var key_size := int(radius * 0.9)
	draw_string(font, center + Vector2(-radius, key_size * 0.35), key_text, HORIZONTAL_ALIGNMENT_CENTER,
			radius * 2.0, key_size, Color.WHITE if ready else WAITING)
	var text_top := center.y + radius + RING_WIDTH
	draw_string(font, Vector2(0.0, text_top + 16.0), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color.WHITE)
	draw_string(font, Vector2(0.0, text_top + 16.0 + LABEL_HEIGHT * 0.8), status_text, HORIZONTAL_ALIGNMENT_CENTER,
			size.x, 13, accent if ready else WAITING)
