class_name PropScatter
extends Node3D
## Espalha objetos de cenário (PropEntry) dos dois lados da trilha, de forma determinística
## (mesma semente = mesmo cenário), evitando a trilha e as clareiras de combate.

@export var terrain: TrailTerrain
@export var props: Array[PropEntry] = []
@export var random_seed: int = 11
@export var spacing: float = 4.0
@export_range(0.0, 1.0) var density: float = 0.8
## Objetos além desta distância da câmera não são desenhados (desempenho).
@export var visibility_distance: float = 75.0
@export var clearing_keep_out: float = 12.0

const SIDE_PATH_KEEP_OUT: float = 4.5
const SIDE_AREA_KEEP_OUT: float = 9.0


## `side_paths`: vales laterais — ficam livres de objetos no meio e ganham objetos dos lados.
func scatter(clearings: Array[Vector3], side_paths: Array[PackedVector3Array] = []) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var total_weight := 0.0
	for entry: PropEntry in props:
		total_weight += entry.weight
	_side_paths = side_paths
	_scatter_along(terrain.route_points(spacing), clearings, rng, total_weight)
	for path: PackedVector3Array in side_paths:
		var sparse := PackedVector3Array()
		for i: int in range(0, path.size(), maxi(1, int(spacing / 1.5))):
			sparse.append(path[i])
		var area_keep_out := clearings.duplicate()
		area_keep_out.append(path[path.size() - 1])
		_scatter_along(sparse, area_keep_out, rng, total_weight)


var _side_paths: Array[PackedVector3Array] = []


func _scatter_along(points: PackedVector3Array, clearings: Array[Vector3], rng: RandomNumberGenerator,
		total_weight: float) -> void:
	for i: int in range(1, points.size() - 1):
		var along := (points[i + 1] - points[i - 1])
		along.y = 0.0
		along = along.normalized()
		var side := Vector3(-along.z, 0.0, along.x)
		for sign_value: float in [-1.0, 1.0]:
			if rng.randf() > density:
				continue
			var entry := _pick(rng, total_weight)
			var distance := rng.randf_range(entry.side_distance_min, entry.side_distance_max)
			var position := points[i] + side * sign_value * distance + along * rng.randf_range(-spacing, spacing) * 0.5
			if _near_clearing(position, clearings) or _near_side_path(position):
				continue
			_place(entry, terrain.ground_point(position), rng)


func _pick(rng: RandomNumberGenerator, total_weight: float) -> PropEntry:
	var roll := rng.randf() * total_weight
	for entry: PropEntry in props:
		roll -= entry.weight
		if roll <= 0.0:
			return entry
	return props[props.size() - 1]


## Não bloqueia a entrada nem o leito dos vales laterais.
func _near_side_path(position: Vector3) -> bool:
	for path: PackedVector3Array in _side_paths:
		for i: int in range(0, path.size(), 2):
			if Vector2(position.x - path[i].x, position.z - path[i].z).length() < SIDE_PATH_KEEP_OUT:
				return true
		var end := path[path.size() - 1]
		if Vector2(position.x - end.x, position.z - end.z).length() < SIDE_AREA_KEEP_OUT:
			return true
	return false


func _near_clearing(position: Vector3, clearings: Array[Vector3]) -> bool:
	for center: Vector3 in clearings:
		if Vector2(position.x - center.x, position.z - center.z).length() < clearing_keep_out:
			return true
	return false


func _place(entry: PropEntry, ground: Vector3, rng: RandomNumberGenerator) -> void:
	var prop := entry.scene.instantiate() as Node3D
	var scale_value := rng.randf_range(entry.scale_min, entry.scale_max)
	add_child(prop)
	prop.global_position = ground - Vector3.UP * entry.sink * scale_value
	prop.rotation.y = rng.randf() * TAU
	prop.scale = Vector3.ONE * scale_value
	for node: Node in prop.find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		geometry.visibility_range_end = visibility_distance
		geometry.visibility_range_end_margin = 5.0
	if entry.collision_radius > 0.0:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = entry.collision_radius * scale_value
		cylinder.height = 3.0
		shape.shape = cylinder
		shape.position = Vector3.UP * 1.5
		body.add_child(shape)
		add_child(body)
		body.global_position = ground
