class_name WeaponTrail
extends MeshInstance3D
## Rastro luminoso da lâmina: guarda as últimas posições da base e da ponta e desenha uma fita que
## some com o tempo. Ligue com `emit_for(segundos)` durante o golpe.

const MAX_SAMPLES: int = 14
const SAMPLE_LIFETIME: float = 0.16

var base_marker: Node3D
var tip_marker: Node3D
var color: Color = Color(0.6, 0.85, 1.0)

var _samples: Array[Array] = []  # [base, tip, idade]
var _emit_time: float = 0.0
var _immediate: ImmediateMesh
var _material: StandardMaterial3D


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_immediate = ImmediateMesh.new()
	mesh = _immediate
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.vertex_color_use_as_albedo = true


func emit_for(seconds: float) -> void:
	_emit_time = maxf(_emit_time, seconds)


func _process(delta: float) -> void:
	for sample: Array in _samples:
		sample[2] += delta
	while not _samples.is_empty() and _samples[0][2] > SAMPLE_LIFETIME:
		_samples.pop_front()
	if _emit_time > 0.0 and base_marker != null and tip_marker != null:
		_emit_time -= delta
		_samples.append([base_marker.global_position, tip_marker.global_position, 0.0])
		if _samples.size() > MAX_SAMPLES:
			_samples.pop_front()
	_rebuild()


func _rebuild() -> void:
	_immediate.clear_surfaces()
	if _samples.size() < 2:
		return
	_material.albedo_color = Color(color.r * 1.3, color.g * 1.3, color.b * 1.3, 1.0)
	_immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _material)
	for sample: Array in _samples:
		var alpha := 1.0 - float(sample[2]) / SAMPLE_LIFETIME
		_immediate.surface_set_color(Color(1, 1, 1, alpha * 0.15))
		_immediate.surface_add_vertex(sample[0])
		_immediate.surface_set_color(Color(1, 1, 1, alpha * 0.7))
		_immediate.surface_add_vertex(sample[1])
	_immediate.surface_end()
