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


func scatter(clearings: Array[Vector3]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var total_weight := 0.0
	for entry: PropEntry in props:
		total_weight += entry.weight
	var points := terrain.route_points(spacing)
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
			if _near_clearing(position, clearings):
				continue
			_place(entry, terrain.ground_point(position), rng)


func _pick(rng: RandomNumberGenerator, total_weight: float) -> PropEntry:
	var roll := rng.randf() * total_weight
	for entry: PropEntry in props:
		roll -= entry.weight
		if roll <= 0.0:
			return entry
	return props[props.size() - 1]


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
