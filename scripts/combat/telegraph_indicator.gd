class_name TelegraphIndicator
extends Node3D
## Aviso de ataque (GDD §6.2): anel no chão que se fecha até o momento do impacto
## e "!" acima da cabeça, indo do amarelo ao vermelho. O anel fechado = hora de defender.

@export var start_scale: float = 2.6
@export var end_scale: float = 0.8
@export var start_color: Color = Color(1.0, 0.85, 0.2)
@export var end_color: Color = Color(1.0, 0.15, 0.1)

var _material: StandardMaterial3D
var _tween: Tween

@onready var _ring: MeshInstance3D = %Ring
@onready var _mark: Label3D = %Mark


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring.material_override = _material
	visible = false


func play(duration: float) -> void:
	_kill_tween()
	visible = true
	_ring.scale = Vector3.ONE * start_scale
	_set_color(start_color)
	_tween = create_tween().set_parallel().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_property(_ring, "scale", Vector3.ONE * end_scale, duration)
	_tween.tween_method(_set_color, start_color, end_color, duration)


func stop() -> void:
	_kill_tween()
	visible = false


func _set_color(color: Color) -> void:
	_material.albedo_color = color
	_mark.modulate = color


func _kill_tween() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
