class_name Equipment
extends RefCounted
## Monta as armas presas aos ossos (AnimatedBody.attach). Eixos calibrados no esqueleto da Mixamo:
## na mão direita a lâmina sai em +X; no antebraço esquerdo a face do escudo aponta para +Z.

const KITE_SHIELD_PATH := "res://assets/environment/models/kite_shield/kite_shield_1k.gltf"
const STEEL := Color(0.78, 0.8, 0.85)
const DARK_IRON := Color(0.18, 0.18, 0.2)
const LEATHER := Color(0.2, 0.13, 0.08)
const WOOD := Color(0.32, 0.21, 0.12)
const BONE := Color(0.85, 0.8, 0.65)


## Espada: lâmina (material próprio, para brilhar na cor do elemento), guarda, cabo e pomo.
static func sword(blade_material: Material, blade_length: float = 0.85) -> Node3D:
	var root := Node3D.new()
	root.name = "Sword"
	root.add_child(_box("Blade", Vector3(blade_length, 0.055, 0.012), Vector3(0.1 + blade_length * 0.5, 0, 0), blade_material))
	root.add_child(_box("Guard", Vector3(0.035, 0.24, 0.05), Vector3(0.09, 0, 0), _metal(DARK_IRON)))
	var grip := _cylinder("Grip", 0.022, 0.16, _material(LEATHER, 0.0, 0.8))
	grip.rotation.z = PI * 0.5
	grip.position = Vector3(0.0, 0, 0)
	root.add_child(grip)
	root.add_child(_sphere("Pommel", 0.035, Vector3(-0.09, 0, 0), _metal(DARK_IRON)))
	return root


## Encaixa uma espada qualquer (modelo baixado) na mão, no lugar de uma espada de referência.
## O eixo mais longo do modelo vira a lâmina; o lado do cabo é a ponta mais fina por mais tempo
## (o cabo é estreito em todo o comprimento, a ponta da lâmina afina só no fim); o fio fica no plano
## de maior largura. `reference` = Equipment.blade_frame() da espada original (espaço do osso).
## Retorna {"node": Node3D já posicionado, "base": Vector3, "tip": Vector3} no espaço do osso.
static func fit_sword(item: SwordItem, reference: Dictionary) -> Dictionary:
	var node := item.model.instantiate() as Node3D
	var points := _model_points(node)
	var frame := _blade_frame_from_points(points)
	var model_basis := Basis(frame.axis, frame.width, frame.axis.cross(frame.width))
	var target_axis: Vector3 = reference.axis
	var target_width: Vector3 = reference.width
	var target_basis := Basis(target_axis, target_width, target_axis.cross(target_width))
	var rotation := target_basis * model_basis.inverse()
	rotation = Basis(target_axis, deg_to_rad(item.roll_degrees)) * rotation
	var scale := item.length / maxf(frame.length, 0.001)
	var basis := rotation * Basis.from_scale(Vector3.ONE * scale)
	var grip: Vector3 = reference.grip
	node.transform = Transform3D(basis, grip - basis * frame.grip)
	if item.material != null:
		for mesh: Node in node.find_children("*", "MeshInstance3D", true, false):
			(mesh as MeshInstance3D).material_override = item.material
	for mesh: Node in node.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var tip_distance: float = (frame.tip - frame.grip).dot(frame.axis) * scale
	var guard_distance: float = (frame.guard - frame.grip).dot(frame.axis) * scale
	return {"node": node, "base": grip + target_axis * guard_distance, "tip": grip + target_axis * tip_distance}


## Referencial de uma espada a partir de pontos já no espaço do osso, com a base (mais perto do
## osso) e a ponta conhecidas: eixo, plano do fio e onde a mão segura.
static func blade_frame(points: PackedVector3Array, base: Vector3, tip: Vector3) -> Dictionary:
	var axis := (tip - base).normalized()
	var grip := base + axis * (-base).dot(axis)
	return {"axis": axis, "width": _width_direction(points, axis, base, tip), "grip": grip}


## Vértices de todas as malhas do modelo, no espaço da raiz (amostrados se forem muitos).
static func _model_points(root: Node3D) -> PackedVector3Array:
	var points := PackedVector3Array()
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var to_root := Transform3D.IDENTITY
		var current: Node = mesh
		while current != root and current is Node3D:
			to_root = (current as Node3D).transform * to_root
			current = current.get_parent()
		var faces := mesh.mesh.get_faces()
		var step := maxi(1, faces.size() / 20000)
		for i: int in range(0, faces.size(), step):
			points.append(to_root * faces[i])
	return points


## Eixo da lâmina (do cabo para a ponta), largura, comprimento e pontos de cabo/guarda/ponta.
static func _blade_frame_from_points(points: PackedVector3Array) -> Dictionary:
	var box := AABB(points[0], Vector3.ZERO)
	for point: Vector3 in points:
		box = box.expand(point)
	var long := box.get_longest_axis_index()
	var length := box.size[long]
	var slices := 24
	var center := box.get_center()
	var widths: Array[float] = []
	widths.resize(slices)
	widths.fill(0.0)
	for point: Vector3 in points:
		var t := clampf((point[long] - box.position[long]) / length, 0.0, 0.9999)
		var offset := point - center
		offset[long] = 0.0
		var index := int(t * slices)
		widths[index] = maxf(widths[index], offset.length())
	var end_slices := maxi(2, slices * 15 / 100)
	var low_end := _median(widths.slice(0, end_slices))
	var high_end := _median(widths.slice(slices - end_slices, slices))
	var grip_at_low := low_end <= high_end
	var axis := Vector3.ZERO
	axis[long] = 1.0 if grip_at_low else -1.0
	var grip_end := center
	grip_end[long] = box.position[long] if grip_at_low else box.end[long]
	var tip := center
	tip[long] = box.end[long] if grip_at_low else box.position[long]
	# Guarda: primeira fatia (a partir do cabo) bem mais larga que o cabo.
	var grip_width := minf(low_end, high_end)
	var guard_slice := slices / 4
	for i: int in slices:
		var index := i if grip_at_low else slices - 1 - i
		if widths[index] > grip_width * 2.2 and i > 0:
			guard_slice = i
			break
	var guard := grip_end + axis * length * (float(guard_slice) / slices)
	var grip := grip_end + axis * length * (float(guard_slice) / slices) * 0.5
	return {"axis": axis, "width": _width_direction(points, axis, grip_end, tip), "length": length,
			"grip": grip, "guard": guard, "tip": tip}


## Direção (perpendicular ao eixo) em que a lâmina é mais larga: componente principal dos pontos
## do meio da lâmina projetados no plano perpendicular.
static func _width_direction(points: PackedVector3Array, axis: Vector3, from: Vector3, to: Vector3) -> Vector3:
	var helper := Vector3.UP if absf(axis.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var u := axis.cross(helper).normalized()
	var v := axis.cross(u).normalized()
	var span := (to - from).dot(axis)
	var mean := Vector2.ZERO
	var samples: Array[Vector2] = []
	for point: Vector3 in points:
		var t := (point - from).dot(axis) / span
		if t < 0.3 or t > 0.85:
			continue
		var offset := point - from
		var sample := Vector2(offset.dot(u), offset.dot(v))
		samples.append(sample)
		mean += sample
	if samples.is_empty():
		return u
	mean /= samples.size()
	var xx := 0.0
	var xy := 0.0
	var yy := 0.0
	for sample: Vector2 in samples:
		var d := sample - mean
		xx += d.x * d.x
		xy += d.x * d.y
		yy += d.y * d.y
	var angle := 0.5 * atan2(2.0 * xy, xx - yy)
	return (u * cos(angle) + v * sin(angle)).normalized()


static func _median(values: Array[float]) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]


## Escudo realista (Poly Haven) no antebraço esquerdo do herói.
static func kite_shield() -> Node3D:
	var shield := (load(KITE_SHIELD_PATH) as PackedScene).instantiate() as Node3D
	shield.name = "KiteShield"
	return shield


static func kite_shield_offset() -> Transform3D:
	return Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.0, 0.12, -0.08))


## Escudo redondo de madeira com bossa de ferro (inimigos).
static func round_shield(radius: float = 0.32) -> Node3D:
	var root := Node3D.new()
	root.name = "RoundShield"
	var board := _cylinder("Board", radius, 0.045, _material(WOOD, 0.0, 0.85))
	board.rotation.x = PI * 0.5
	root.add_child(board)
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.02
	torus.outer_radius = radius + 0.01
	torus.material = _metal(DARK_IRON)
	rim.mesh = torus
	rim.rotation.x = PI * 0.5
	root.add_child(rim)
	root.add_child(_sphere("Boss", 0.07, Vector3(0, 0, 0.03), _metal(DARK_IRON)))
	return root


static func round_shield_offset() -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(0.0, 0.15, -0.09))


## Besta: coronha ao longo da mão (+X) e arco atravessado na ponta.
static func crossbow() -> Node3D:
	var root := Node3D.new()
	root.name = "Crossbow"
	root.add_child(_box("Stock", Vector3(0.7, 0.07, 0.06), Vector3(0.25, 0, 0), _material(WOOD, 0.0, 0.8)))
	root.add_child(_box("Limbs", Vector3(0.05, 0.85, 0.04), Vector3(0.55, 0, 0), _material(WOOD.darkened(0.3), 0.0, 0.8)))
	root.add_child(_box("String", Vector3(0.01, 0.8, 0.01), Vector3(0.45, 0, 0), _material(BONE, 0.0, 1.0)))
	return root


## Chifres de osso presos à cabeça (Elite).
static func horns() -> Node3D:
	var root := Node3D.new()
	root.name = "Horns"
	for side: float in [-1.0, 1.0]:
		var horn := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.045
		cone.height = 0.3
		cone.material = _material(BONE, 0.0, 0.6)
		horn.mesh = cone
		horn.position = Vector3(0.1 * side, 0.2, 0.0)
		horn.rotation.z = -0.6 * side
		root.add_child(horn)
	return root


static func _box(node_name: String, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	instance.mesh = mesh
	instance.position = position
	return instance


static func _cylinder(node_name: String, radius: float, height: float, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.material = material
	instance.mesh = mesh
	return instance


static func _sphere(node_name: String, radius: float, position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.material = material
	instance.mesh = mesh
	instance.position = position
	return instance


static func _metal(color: Color) -> StandardMaterial3D:
	return _material(color, 0.8, 0.35)


static func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material
