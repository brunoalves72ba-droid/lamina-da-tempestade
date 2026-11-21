class_name LightningArc
extends MeshInstance3D
## Raio procedural reutilizável (CLAUDE.md › Efeitos elétricos). Toda magia de raio usa esta cena,
## passando origem, destino, cor (do elemento), duração, espessura e flash de luz opcional.
## As instâncias vêm do Object Pooling (autoload Pools) e voltam para ele ao apagar.

const SCENE_PATH := "res://scenes/vfx/lightning_arc.tscn"
const DEFAULT_COLOR := Color(0.6, 0.85, 1.0)
const FLASH_RANGE: float = 7.0
const SHADER := preload("res://shaders/lightning.gdshader")
## A fita é mais larga que o raio para caber o halo (o núcleo ocupa o meio).
const HALO_SCALE: float = 3.5

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
var _material: ShaderMaterial
var _fade: float = 1.0
var _forks: int = 0
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
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter(&"core_width", 0.5 / HALO_SCALE)
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
	_fade = 1.0
	_material.set_shader_parameter(&"color", _color)
	_material.set_shader_parameter(&"alpha", 1.0)
	_material.set_shader_parameter(&"seed", randf() * 100.0)
	# Raios grossos ganham ramificações curtas.
	_forks = clampi(int(width_scale * 1.5), 0, 3) if width_scale >= 1.2 else 0
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
	_fade = 1.0 - _age / lifetime
	_material.set_shader_parameter(&"alpha", _fade)
	_since_flicker += delta
	if _since_flicker >= flicker_interval:
		_since_flicker = 0.0
		_rebuild()


## Redesenha o raio com um novo zigue-zague (a cada flicker_interval). A luz pulsa junto.
func _rebuild() -> void:
	_immediate.clear_surfaces()
	var camera := get_viewport().get_camera_3d()
	_immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _material)
	var points := _jagged_points(_from, _to, jaggedness)
	_add_ribbon(points, width * HALO_SCALE, camera)
	for i: int in _forks:
		var start := points[randi_range(1, maxi(1, points.size() - 2))]
		var span := (_to - _from).length()
		var direction := (_to - _from).normalized() + Vector3(randf_range(-0.8, 0.8), randf_range(-0.8, 0.8), randf_range(-0.8, 0.8))
		var end := start + direction.normalized() * span * randf_range(0.12, 0.3)
		_add_ribbon(_jagged_points(start, end, jaggedness * 0.7), width * HALO_SCALE * 0.45, camera)
	_immediate.surface_end()
	if _light.visible:
		_light.light_energy = _flash_energy * _fade * randf_range(0.45, 1.0)


## Fita virada para a câmera; a largura em cada ponto usa a direção média dos dois segmentos
## vizinhos, então as dobras do raio ficam sem frestas.
func _add_ribbon(points: PackedVector3Array, half_width: float, camera: Camera3D) -> void:
	var count := points.size() - 1
	var sides := PackedVector3Array()
	sides.resize(points.size())
	for i: int in points.size():
		var previous := points[maxi(i - 1, 0)]
		var following := points[mini(i + 1, count)]
		var view := Vector3.UP if camera == null else (camera.global_position - points[i]).normalized()
		var side := (following - previous).cross(view)
		if side.length_squared() < 0.000001:
			side = Vector3.RIGHT
		sides[i] = side.normalized() * half_width
	for i: int in count:
		var a := points[i]
		var b := points[i + 1]
		var u0 := float(i) / count
		var u1 := float(i + 1) / count
		_vertex(a - sides[i], u0, 0.0)
		_vertex(a + sides[i], u0, 1.0)
		_vertex(b + sides[i + 1], u1, 1.0)
		_vertex(a - sides[i], u0, 0.0)
		_vertex(b + sides[i + 1], u1, 1.0)
		_vertex(b - sides[i + 1], u1, 0.0)


func _vertex(point: Vector3, u: float, v: float) -> void:
	_immediate.surface_set_uv(Vector2(u, v))
	_immediate.surface_add_vertex(point)


func _jagged_points(from: Vector3, to: Vector3, jag: float) -> PackedVector3Array:
	var points := PackedVector3Array()
	var span := to - from
	var count := maxi(2, ceili(span.length() / segment_length))
	var direction := span.normalized() if span.length() > 0.001 else Vector3.FORWARD
	for i: int in count + 1:
		var point := from.lerp(to, float(i) / float(count))
		if i > 0 and i < count:
			var offset := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
			offset -= direction * offset.dot(direction)
			point += offset * jag
		points.append(point)
	return points
