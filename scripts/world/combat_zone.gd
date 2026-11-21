class_name CombatZone
extends Encounter
## Clareira de combate no percurso. Quando o herói entra, ergue uma barreira de raios em volta
## (ninguém sai até vencer), e as ondas surgem do lado de dentro, mais à frente na trilha.
## Herda Encounter: os pontos de surgimento (Marker3D) são criados em setup().

signal activated(zone: CombatZone)
signal cleared(zone: CombatZone)

const BARRIER_SEGMENTS: int = 20
const BARRIER_HEIGHT: float = 3.0
const BARRIER_THICKNESS: float = 0.5
const BARRIER_COLOR := Color(0.55, 0.7, 1.0, 0.07)

@export var display_name: String = "Clareira"
## Distância ao longo da trilha (m) onde fica o centro da clareira.
@export var route_progress: float = 30.0
@export var trigger_radius: float = 14.0
@export var barrier_radius: float = 17.0
@export var spawn_radius_min: float = 5.5
@export var spawn_radius_max: float = 8.5
@export var spawn_point_count: int = 10

var is_active: bool = false
var is_cleared: bool = false

var _barrier: Node3D


## Posiciona a zona no chão e cria os pontos de surgimento à frente (direção da trilha).
func setup(terrain: TrailTerrain, forward_direction: Vector3, rng: RandomNumberGenerator) -> void:
	global_position = terrain.ground_point(global_position)
	var forward_angle := atan2(forward_direction.x, forward_direction.z)
	for i: int in spawn_point_count:
		var angle := forward_angle + rng.randf_range(-1.6, 1.6)
		var radius := rng.randf_range(spawn_radius_min, spawn_radius_max)
		var marker := Marker3D.new()
		add_child(marker)
		var point := global_position + Vector3(sin(angle), 0.0, cos(angle)) * radius
		marker.global_position = terrain.ground_point(point) + Vector3.UP * 0.3
	_build_barrier()
	set_barrier(false)


func contains(point: Vector3) -> bool:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length() <= trigger_radius


func activate() -> void:
	is_active = true
	set_barrier(true)
	activated.emit(self)


func finish() -> void:
	is_active = false
	is_cleared = true
	set_barrier(false)
	cleared.emit(self)


## Volta ao estado inicial (herói morreu dentro da zona).
## Vencida num save anterior (Continuar): sem barreira e sem inimigos.
func restore_cleared() -> void:
	is_cleared = true
	set_barrier(false)


func reset_zone() -> void:
	is_active = false
	set_barrier(false)


func set_barrier(up: bool) -> void:
	if _barrier == null:
		return
	_barrier.visible = up
	for body: Node in _barrier.find_children("*", "StaticBody3D", true, false):
		(body as StaticBody3D).collision_layer = 1 if up else 0


func _build_barrier() -> void:
	_barrier = Node3D.new()
	_barrier.name = "Barrier"
	add_child(_barrier)
	var wall := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = barrier_radius
	cylinder.bottom_radius = barrier_radius
	cylinder.height = BARRIER_HEIGHT
	cylinder.cap_top = false
	cylinder.cap_bottom = false
	cylinder.radial_segments = 48
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = BARRIER_COLOR
	cylinder.material = material
	wall.mesh = cylinder
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wall.position = Vector3.UP * BARRIER_HEIGHT * 0.4
	_barrier.add_child(wall)
	var light := OmniLight3D.new()
	light.light_color = Color(BARRIER_COLOR, 1.0)
	light.light_energy = 1.2
	light.omni_range = barrier_radius + 4.0
	light.position = Vector3.UP * 3.0
	_barrier.add_child(light)
	var segment_length := TAU * barrier_radius / BARRIER_SEGMENTS * 1.1
	for i: int in BARRIER_SEGMENTS:
		var angle := TAU * i / BARRIER_SEGMENTS
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(segment_length, BARRIER_HEIGHT * 2.0, BARRIER_THICKNESS)
		shape.shape = box
		body.add_child(shape)
		_barrier.add_child(body)
		body.position = Vector3(sin(angle), 0.0, cos(angle)) * barrier_radius
		body.rotation.y = angle
