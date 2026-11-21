class_name DamageNumberSpawner
extends Node3D
## Números de dano flutuantes (GDD §6.7). Escuta Events.damage_taken; deve ficar na origem da fase.
## Vantagem elemental = verde e maior; desvantagem = cinza e menor (GDD §7).

const COLOR_NORMAL := Color(1.0, 1.0, 1.0)
const COLOR_HEAVY := Color(1.0, 0.7, 0.25)
const COLOR_COUNTER := Color(1.0, 0.85, 0.3)
const COLOR_PLAYER := Color(1.0, 0.3, 0.25)
const COLOR_ADVANTAGE := Color(0.45, 1.0, 0.4)
const COLOR_DISADVANTAGE := Color(0.55, 0.55, 0.6)

@export var height_offset: float = 1.7
@export var horizontal_jitter: float = 0.3
@export var rise_height: float = 0.9
@export var lifetime: float = 0.8
@export var font_size: int = 72
@export var heavy_font_size: int = 104
@export var weak_font_size: int = 56
## Números que nasceriam colados na câmera ficariam gigantes: são omitidos.
@export var min_camera_distance: float = 2.5


func _ready() -> void:
	Events.damage_taken.connect(_on_damage_taken)


func _on_damage_taken(target: Node3D, info: DamageInfo) -> void:
	var text := str(roundi(info.amount))
	var color := COLOR_NORMAL
	var size := font_size
	if target is Player:
		color = COLOR_PLAYER
	elif info.is_counter:
		text = "%s!" % text
		color = COLOR_COUNTER
		size = heavy_font_size
	elif info.element_multiplier > 1.0:
		text = "%s!" % text
		color = COLOR_ADVANTAGE
		size = heavy_font_size
	elif info.element_multiplier < 1.0:
		color = COLOR_DISADVANTAGE
		size = weak_font_size
	elif info.is_heavy:
		color = COLOR_HEAVY
		size = heavy_font_size
	var jitter := Vector3(randf_range(-horizontal_jitter, horizontal_jitter), height_offset, 0.0)
	_spawn(target.global_position + jitter, text, color, size)


func _spawn(spawn_position: Vector3, text: String, color: Color, size: int) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera != null and camera.global_position.distance_to(spawn_position) < min_camera_distance:
		return
	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.font_size = size
	label.outline_size = size / 6
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)
	label.position = spawn_position
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", spawn_position.y + rise_height, lifetime)
	tween.tween_property(label, "modulate:a", 0.0, lifetime * 0.5).set_delay(lifetime * 0.5)
	tween.chain().tween_callback(label.queue_free)
