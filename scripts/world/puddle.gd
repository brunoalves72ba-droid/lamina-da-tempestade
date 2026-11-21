class_name Puddle
extends Node3D
## Poça d'água no chão (GDD §6.9): reflete o céu e conduz o raio para quem pisa nela.
## Com chuva (Weather) as poças crescem um pouco.

const GROUP := &"puddles"

@export var radius: float = 1.6

var _surface: MeshInstance3D
var _material: StandardMaterial3D
var _glow_tween: Tween


func _ready() -> void:
	add_to_group(GROUP)
	_surface = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.01
	mesh.radial_segments = 24
	mesh.rings = 1
	_surface.mesh = mesh
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(0.16, 0.18, 0.22, 0.55)
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.metallic = 0.7
	_material.roughness = 0.03
	_material.rim_enabled = true
	_material.rim = 0.6
	_material.emission_enabled = true
	_material.emission = Color.BLACK
	_surface.material_override = _material
	_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_surface.position.y = 0.03
	add_child(_surface)
	set_radius(radius)


func set_radius(value: float) -> void:
	radius = value
	if _surface != null:
		_surface.scale = Vector3(radius, 1.0, radius * 0.8)


func contains(point: Vector3) -> bool:
	var offset := point - global_position
	if absf(offset.y) > 1.5:
		return false
	offset.y = 0.0
	offset.z /= 0.8
	return offset.length() <= radius + 0.3


## Clarão elétrico na superfície quando o raio passa pela poça.
func electrify(color: Color) -> void:
	if _glow_tween != null:
		_glow_tween.kill()
	_material.emission = color
	_material.emission_energy_multiplier = 3.0
	_glow_tween = create_tween()
	_glow_tween.tween_property(_material, "emission_energy_multiplier", 0.0, 0.5)
	for i: int in 3:
		var angle := randf() * TAU
		var edge := global_position + Vector3(cos(angle), 0.05, sin(angle) * 0.8) * radius
		LightningArc.spawn(get_parent(), global_position + Vector3.UP * 0.05, edge, color, 0.2, 0.5)
