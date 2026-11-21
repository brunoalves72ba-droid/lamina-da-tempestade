class_name LightningArc
extends MeshInstance3D
## Raio procedural reutilizável (CLAUDE.md › Efeitos elétricos). Toda magia de raio usa esta cena,
## passando origem, destino, cor (do elemento), duração, espessura e flash de luz opcional.
## As instâncias vêm do Object Pooling (autoload Pools) e voltam para ele ao apagar.

const SCENE_PATH := "res://scenes/vfx/lightning_arc.tscn"
const DEFAULT_COLOR := Color(0.6, 0.85, 1.0)
const FLASH_RANGE: float = 7.0

@export var segment_length: float = 0.45
@export var jaggedness: float = 0.22
@export var width: float = 0.05
@export var lifetime: float = 0.18
@export var flicker_interval: float = 0.035

var _from: Vector3 = Vector3.ZERO
var _to: Vector3 = Vector3.ZERO
var _color: Color = DEFAULT_COLOR
var _flash_energy: float = 0.0
var _age: float = 0.0
var _since_flicker: float = 0.0
var _material: StandardMaterial3D
var _immediate: ImmediateMesh
var _light: OmniLight3D


static var _scene: PackedScene

var _base_width: float = 0.0
var _base_jaggedness: float = 0.0
var _base_lifetime: float = 0.0
var _initialized: bool = false


static func spawn(parent: Node, from: Vector3, to: Vector3, color: Color = DEFAULT_COLOR,
		duration: float = -1.0, width_scale: float = 1.0, flash_energy: float = 0.0) -> LightningArc:
	if _scene == null:
		_scene = load(SCENE_PATH) as PackedScene
	var arc := Pools.acquire(&"lightning_arc", _scene.instantiate, parent) as LightningArc
	arc._begin(from, to, color, duration, width_scale, flash_energy)
	return arc


func _ready() -> void:
	if _initialized:
		return
	_initialized = true
	_base_width = width
	_base_jaggedness = jaggedness
	_base_lifetime = lifetime
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_immediate = ImmediateMesh.new()
	mesh = _immediate
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_light = OmniLight3D.new()
	_light.omni_range = FLASH_RANGE
	_light.shadow_enabled = false
	add_child(_light)


## Prepara um raio novo (primeiro uso ou reutilizado do pool).
func _begin(from: Vector3, to: Vector3, color: Color, duration: float, width_scale: float, flash_energy: float) -> void:
	_from = from
	_to = to
	_color = color
	_flash_energy = flash_energy
	width = _base_width * width_scale
	jaggedness = _base_jaggedness * sqrt(width_scale)
	lifetime = duration if duration > 0.0 else _base_lifetime
	_age = 0.0
	_since_flicker = 0.0
	global_transform = Transform3D.IDENTITY
	_material.albedo_color = _color
	_light.visible = _flash_energy > 0.0
	if _light.visible:
		_light.light_color = _color
		_light.light_energy = _flash_energy
		_light.global_position = _from.lerp(_to, 0.5)
	_rebuild()


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		Pools.release(self)
		return
	var faded: Color = _material.albedo_color
	faded.a = 1.0 - _age / lifetime
	_material.albedo_color = faded
	if _light.visible:
		_light.light_energy = _flash_energy * faded.a
	_since_flicker += delta
	if _since_flicker >= flicker_interval:
		_since_flicker = 0.0
		_rebuild()


func _rebuild() -> void:
	_immediate.clear_surfaces()
	var points := _jagged_points()
	var camera := get_viewport().get_camera_3d()
	_immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _material)
	for i: int in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var view := Vector3.UP if camera == null else (camera.global_position - a).normalized()
		var side := (b - a).cross(view)
		if side.length_squared() < 0.000001:
			side = Vector3.RIGHT
		side = side.normalized() * width
		_immediate.surface_add_vertex(a - side)
		_immediate.surface_add_vertex(a + side)
		_immediate.surface_add_vertex(b + side)
		_immediate.surface_add_vertex(a - side)
		_immediate.surface_add_vertex(b + side)
		_immediate.surface_add_vertex(b - side)
	_immediate.surface_end()


func _jagged_points() -> PackedVector3Array:
	var points := PackedVector3Array()
	var span := _to - _from
	var count := maxi(2, ceili(span.length() / segment_length))
	var direction := span.normalized() if span.length() > 0.001 else Vector3.FORWARD
	for i: int in count + 1:
		var point := _from.lerp(_to, float(i) / float(count))
		if i > 0 and i < count:
			var offset := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
			offset -= direction * offset.dot(direction)
			point += offset * jaggedness
		points.append(point)
	return points
