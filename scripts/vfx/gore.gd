class_name Gore
extends RefCounted
## Sangue estilizado e desmembramento (GDD §6.7). Tudo respeita GameState.gore_enabled
## (Configurações) e usa o Object Pooling. Sangue escuro, quase preto, para combinar com o tom
## sombrio sem virar splatter.

const BLOOD := Color(0.32, 0.01, 0.02)
const BLOOD_DARK := Color(0.12, 0.0, 0.01)
## Ossos que podem ser cortados e o peso de cada um no sorteio.
const SEVERABLE: Dictionary = {
	&"mixamorig_Head": 3, &"mixamorig_RightForeArm": 1, &"mixamorig_LeftForeArm": 1,
}
const GIB_LIFETIME: float = 5.0
const POOL_LIFETIME: float = 8.0


static func enabled() -> bool:
	return GameState.gore_enabled


## Respingo de sangue no golpe (mais forte e com mancha no chão se for pesado).
static func blood_hit(parent: Node, at: Vector3, ground: Vector3, heavy: bool) -> void:
	if not enabled():
		return
	Vfx.sparks(parent, at, BLOOD, 18 if heavy else 9, 4.5 if heavy else 3.0, 0.45, -16.0)
	if heavy:
		blood_pool(parent, ground, randf_range(0.5, 0.8))


## Mancha de sangue no chão que some devagar.
static func blood_pool(parent: Node, ground: Vector3, radius: float) -> void:
	if not enabled():
		return
	var mark := Pools.acquire(&"gore_pool", _new_pool, parent) as MeshInstance3D
	mark.global_position = ground + Vector3.UP * 0.035
	mark.rotation.y = randf() * TAU
	mark.scale = Vector3(radius * 2.0, 1.0, radius * 2.0 * randf_range(0.7, 1.0))
	var material := mark.material_override as StandardMaterial3D
	material.albedo_color = Color(BLOOD_DARK.r, BLOOD_DARK.g, BLOOD_DARK.b, 0.9)
	var tween := Pools.tween(mark)
	tween.tween_interval(POOL_LIFETIME * 0.7)
	tween.tween_property(material, "albedo_color:a", 0.0, POOL_LIFETIME * 0.3)
	Pools.release_after(mark, POOL_LIFETIME)


## Corta uma parte do corpo do inimigo: some do modelo, jorra sangue e caem pedaços.
## Retorna o nome do osso cortado (vazio se o gore estiver desligado).
static func dismember(enemy: Enemy, push: Vector3 = Vector3.ZERO) -> StringName:
	if not enabled():
		return &""
	var skeleton := enemy.body.skeleton
	var bone_name := _pick_bone()
	var bone := skeleton.find_bone(bone_name)
	if bone == -1:
		return &""
	var severed := skeleton.get_node_or_null(^"SeveredBones") as SeveredBones
	if severed == null:
		severed = SeveredBones.new()
		severed.name = "SeveredBones"
		skeleton.add_child(severed)
	var stump := skeleton.global_transform * skeleton.get_bone_global_pose(bone).origin
	severed.sever(bone)
	var parent := enemy.get_parent()
	var skeleton_id := skeleton.get_instance_id()
	var parent_id := parent.get_instance_id()
	# Jorro: algumas rajadas em sequência saindo do corte.
	for i: int in 4:
		parent.get_tree().create_timer(0.08 * i, false).timeout.connect(func() -> void:
			var skeleton_now := instance_from_id(skeleton_id) as Skeleton3D
			var parent_now := instance_from_id(parent_id) as Node
			if skeleton_now != null and parent_now != null and skeleton_now.is_inside_tree():
				var point := skeleton_now.global_transform * skeleton_now.get_bone_global_pose(bone).origin
				Vfx.sparks(parent_now, point, BLOOD, 14, 3.5, 0.5, -14.0))
	for i: int in randi_range(3, 5):
		_gib(parent, stump, push)
	blood_pool(parent, enemy.global_position, randf_range(0.8, 1.2))
	return bone_name


## Desfaz cortes (inimigo que renasce no sandbox).
static func restore(enemy: Enemy) -> void:
	var severed := enemy.body.skeleton.get_node_or_null(^"SeveredBones") as SeveredBones
	if severed != null:
		severed.clear()


static func _pick_bone() -> StringName:
	var total := 0
	for bone: StringName in SEVERABLE:
		total += SEVERABLE[bone]
	var roll := randi_range(1, total)
	for bone: StringName in SEVERABLE:
		roll -= SEVERABLE[bone]
		if roll <= 0:
			return bone
	return &"mixamorig_Head"


## Pedaço que voa do corte e quica no chão (corpo rígido simples, do pool).
static func _gib(parent: Node, at: Vector3, push: Vector3) -> void:
	var gib := Pools.acquire(&"gore_gib", _new_gib, parent) as RigidBody3D
	gib.global_position = at + Vector3(randf_range(-0.1, 0.1), 0.0, randf_range(-0.1, 0.1))
	gib.linear_velocity = push * 2.0 + Vector3(randf_range(-2.5, 2.5), randf_range(2.0, 4.5), randf_range(-2.5, 2.5))
	gib.angular_velocity = Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
	var size := randf_range(0.06, 0.13)
	(gib.get_child(0) as MeshInstance3D).scale = Vector3(size, size * randf_range(0.6, 1.4), size)
	Pools.release_after(gib, GIB_LIFETIME)


static func _new_gib() -> Node:
	var gib := RigidBody3D.new()
	gib.collision_layer = 0
	gib.collision_mask = 1
	gib.mass = 0.3
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 1.6
	sphere.radial_segments = 6
	sphere.rings = 3
	var material := StandardMaterial3D.new()
	material.albedo_color = BLOOD
	material.roughness = 0.35
	sphere.material = material
	mesh.mesh = sphere
	gib.add_child(mesh)
	var shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.08
	shape.shape = sphere_shape
	gib.add_child(shape)
	return gib


static func _new_pool() -> Node:
	var mark := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.orientation = PlaneMesh.FACE_Y
	mark.mesh = quad
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.15
	material.metallic = 0.3
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.6, Color(1, 1, 1, 0.9))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	material.albedo_texture = texture
	mark.material_override = material
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mark
