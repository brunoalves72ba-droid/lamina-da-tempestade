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
