class_name TrailTerrain
extends Node3D
## Gera o terreno do percurso a partir de um Path3D: um vale com trilha de lama no fundo,
## clareiras largas para as lutas e paredões de rocha nas laterais (que guiam o jogador).
## Cria malha (com cores para o shader misturar lama/chão/rocha) e colisão por heightmap.
## Também responde a altura do chão em qualquer ponto (height_at), usada para posicionar tudo.

@export var route: Path3D
@export var terrain_material: Material
@export var noise_seed: int = 7
@export var cell_size: float = 1.0
@export var margin: float = 38.0
@export var stamp_spacing: float = 1.5

@export_group("Trilha e vale")
@export var path_half_width: float = 3.5
@export var path_falloff: float = 3.0
@export var mud_half_width: float = 1.8
@export var mud_falloff: float = 1.6
@export var valley_half_width: float = 14.0
@export var valley_falloff: float = 9.0
@export var cliff_height: float = 13.0
@export var bump_height: float = 1.1
## Subida/descida suave ao longo da trilha.
@export var route_height_amplitude: float = 2.5

@export_group("Clareiras")
@export var clearing_radius: float = 10.0
@export_group("Vales laterais")
@export var side_path_half_width: float = 2.5
@export var side_valley_half_width: float = 9.0
@export var side_area_radius: float = 20.0
@export_group("")
@export var clearing_valley_radius: float = 19.0
@export var clearing_mud_radius: float = 5.0

var _origin: Vector2 = Vector2.ZERO
var _width: int = 0
var _depth: int = 0
var _heights: PackedFloat32Array
var _route_noise: FastNoiseLite
var _bump_noise: FastNoiseLite
var _cliff_noise: FastNoiseLite


func _ready() -> void:
	_make_noises()


## Altura da trilha em uma distância (m) ao longo do percurso.
func route_height(progress: float) -> float:
	return _route_noise.get_noise_1d(progress) * route_height_amplitude


## Pontos do percurso a cada `spacing` metros, já com a altura da trilha.
func route_points(spacing: float) -> PackedVector3Array:
	var curve := route.curve
	var length := curve.get_baked_length()
	var points := PackedVector3Array()
	var progress := 0.0
	while progress <= length:
		var point := route.to_global(curve.sample_baked(progress))
		point.y = route_height(progress)
		points.append(point)
		progress += spacing
	return points


## Gera tudo. `clearings` = centros das clareiras (no plano; a altura vem da trilha mais próxima).
## `side_paths` = vales laterais (pontos com altura) que saem da trilha e terminam numa área aberta.
func build(clearings: Array[Vector3], side_paths: Array[PackedVector3Array] = []) -> void:
	var stamps := route_points(stamp_spacing)
	var all_points := stamps.duplicate()
	for path: PackedVector3Array in side_paths:
		all_points.append_array(path)
	_allocate_grid(all_points)
	var count := _width * _depth
	var core := PackedFloat32Array()
	var valley := PackedFloat32Array()
	var mud := PackedFloat32Array()
	var base := PackedFloat32Array()
	var best := PackedFloat32Array()
	for field: PackedFloat32Array in [core, valley, mud, base, best]:
		field.resize(count)
	best.fill(INF)
	base.fill(route_height(0.0))
	for stamp: Vector3 in stamps:
		_stamp(stamp, path_half_width, path_falloff, valley_half_width, valley_falloff, mud_half_width, mud_falloff,
				core, valley, mud, base, best)
	for center: Vector3 in clearings:
		var with_height := _nearest_stamp(center, stamps)
		_stamp(with_height, clearing_radius, path_falloff, clearing_valley_radius, valley_falloff,
				clearing_mud_radius, mud_falloff, core, valley, mud, base, best)
	for path: PackedVector3Array in side_paths:
		for point: Vector3 in path:
			_stamp(point, side_path_half_width, path_falloff, side_valley_half_width, valley_falloff,
					mud_half_width * 0.6, mud_falloff, core, valley, mud, base, best)
		if not path.is_empty():
			# Área aberta no fim do vale lateral.
			_stamp(path[path.size() - 1], clearing_radius, path_falloff, side_area_radius, valley_falloff,
					clearing_mud_radius * 0.6, mud_falloff, core, valley, mud, base, best)
	_heights = PackedFloat32Array()
	_heights.resize(count)
	for z: int in _depth:
		for x: int in _width:
			var i := z * _width + x
			var world := _cell_to_world(x, z)
			var bump := _bump_noise.get_noise_2d(world.x, world.y) * bump_height * (1.0 - core[i])
			var cliff := (1.0 - valley[i]) * cliff_height * (0.7 + 0.6 * (_cliff_noise.get_noise_2d(world.x, world.y) * 0.5 + 0.5))
			_heights[i] = base[i] + bump + cliff
	_build_mesh(mud, valley)
	_build_collision()


## Altura do chão (bilinear) em um ponto do mundo.
func height_at(world_x: float, world_z: float) -> float:
	if _heights.is_empty():
		return 0.0
	var gx := clampf((world_x - _origin.x) / cell_size, 0.0, _width - 1.001)
	var gz := clampf((world_z - _origin.y) / cell_size, 0.0, _depth - 1.001)
	var x0 := int(gx)
	var z0 := int(gz)
	var fx := gx - x0
	var fz := gz - z0
	var h00 := _heights[z0 * _width + x0]
	var h10 := _heights[z0 * _width + x0 + 1]
	var h01 := _heights[(z0 + 1) * _width + x0]
	var h11 := _heights[(z0 + 1) * _width + x0 + 1]
	return lerpf(lerpf(h00, h10, fx), lerpf(h01, h11, fx), fz)


func ground_point(world_position: Vector3) -> Vector3:
	return Vector3(world_position.x, height_at(world_position.x, world_position.z), world_position.z)


func _make_noises() -> void:
	_route_noise = FastNoiseLite.new()
	_route_noise.seed = noise_seed
	_route_noise.frequency = 0.012
	_bump_noise = FastNoiseLite.new()
	_bump_noise.seed = noise_seed + 1
	_bump_noise.frequency = 0.08
	_bump_noise.fractal_octaves = 3
	_cliff_noise = FastNoiseLite.new()
	_cliff_noise.seed = noise_seed + 2
	_cliff_noise.frequency = 0.05


func _allocate_grid(stamps: PackedVector3Array) -> void:
	var min_corner := Vector2(INF, INF)
	var max_corner := Vector2(-INF, -INF)
	for point: Vector3 in stamps:
		min_corner = min_corner.min(Vector2(point.x, point.z))
		max_corner = max_corner.max(Vector2(point.x, point.z))
	min_corner -= Vector2.ONE * margin
	max_corner += Vector2.ONE * margin
	_origin = min_corner
	_width = ceili((max_corner.x - min_corner.x) / cell_size) + 1
	_depth = ceili((max_corner.y - min_corner.y) / cell_size) + 1


func _cell_to_world(x: int, z: int) -> Vector2:
	return _origin + Vector2(x, z) * cell_size


func _nearest_stamp(center: Vector3, stamps: PackedVector3Array) -> Vector3:
	var best := stamps[0]
	for point: Vector3 in stamps:
		if Vector2(point.x - center.x, point.z - center.z).length_squared() < Vector2(best.x - center.x, best.z - center.z).length_squared():
			best = point
	return Vector3(center.x, best.y, center.z)


## Marca as células perto de um ponto: abertura do caminho, do vale, lama e altura base.
func _stamp(point: Vector3, core_radius: float, core_falloff: float, valley_radius: float, valley_fall: float,
		mud_radius: float, mud_fall: float, core: PackedFloat32Array, valley: PackedFloat32Array,
		mud: PackedFloat32Array, base: PackedFloat32Array, best: PackedFloat32Array) -> void:
	var reach := valley_radius + valley_fall
	var min_x := maxi(0, floori((point.x - reach - _origin.x) / cell_size))
	var max_x := mini(_width - 1, ceili((point.x + reach - _origin.x) / cell_size))
	var min_z := maxi(0, floori((point.z - reach - _origin.y) / cell_size))
	var max_z := mini(_depth - 1, ceili((point.z + reach - _origin.y) / cell_size))
	for z: int in range(min_z, max_z + 1):
		for x: int in range(min_x, max_x + 1):
			var world := _cell_to_world(x, z)
			var distance := Vector2(world.x - point.x, world.y - point.z).length()
			if distance > reach:
				continue
			var i := z * _width + x
			core[i] = maxf(core[i], 1.0 - smoothstep(core_radius, core_radius + core_falloff, distance))
			valley[i] = maxf(valley[i], 1.0 - smoothstep(valley_radius, valley_radius + valley_fall, distance))
			mud[i] = maxf(mud[i], 1.0 - smoothstep(mud_radius, mud_radius + mud_fall, distance))
			if distance < best[i]:
				best[i] = distance
				base[i] = point.y


func _build_mesh(mud: PackedFloat32Array, valley: PackedFloat32Array) -> void:
	var count := _width * _depth
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	vertices.resize(count)
	normals.resize(count)
	tangents.resize(count * 4)
	colors.resize(count)
	uvs.resize(count)
	for z: int in _depth:
		for x: int in _width:
			var i := z * _width + x
			var world := _cell_to_world(x, z)
			vertices[i] = Vector3(world.x, _heights[i], world.y)
			var left := _heights[z * _width + maxi(x - 1, 0)]
			var right := _heights[z * _width + mini(x + 1, _width - 1)]
			var down := _heights[maxi(z - 1, 0) * _width + x]
			var up := _heights[mini(z + 1, _depth - 1) * _width + x]
			var normal := Vector3(left - right, 2.0 * cell_size, down - up).normalized()
			normals[i] = normal
			var tangent := Vector3(1.0, 0.0, 0.0)
			tangent = (tangent - normal * normal.dot(tangent)).normalized()
			tangents[i * 4] = tangent.x
			tangents[i * 4 + 1] = tangent.y
			tangents[i * 4 + 2] = tangent.z
			tangents[i * 4 + 3] = 1.0
			colors[i] = Color(mud[i], 1.0 - valley[i], 0.0)
			uvs[i] = world
	var indices := PackedInt32Array()
	indices.resize((_width - 1) * (_depth - 1) * 6)
	var k := 0
	for z: int in _depth - 1:
		for x: int in _width - 1:
			var a := z * _width + x
			var b := a + 1
			var c := a + _width
			var d := c + 1
			indices[k] = a
			indices[k + 1] = b
			indices[k + 2] = c
			indices[k + 3] = b
			indices[k + 4] = d
			indices[k + 5] = c
			k += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, terrain_material)
	var instance := MeshInstance3D.new()
	instance.name = "TerrainMesh"
	instance.mesh = mesh
	add_child(instance)


func _build_collision() -> void:
	var shape := HeightMapShape3D.new()
	shape.map_width = _width
	shape.map_depth = _depth
	shape.map_data = _heights
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	body.collision_layer = 1
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(_origin.x + (_width - 1) * cell_size * 0.5, 0.0, _origin.y + (_depth - 1) * cell_size * 0.5)
	body.add_child(collision)
	add_child(body)
