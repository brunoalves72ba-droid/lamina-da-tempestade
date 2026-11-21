class_name Vfx
extends RefCounted
## Efeitos visuais "dispara e esquece" (faíscas, ondas de choque, raios do céu, marcas no chão,
## cortes elétricos, cinzas). Os nós vêm do Object Pooling (autoload Pools) e voltam para ele
## sozinhos; materiais e malhas ficam em cache.
## Uso: Vfx.sparks(get_tree().current_scene, posição, cor).

const SPARK_SIZE: float = 0.05
const RING_SEGMENTS: int = 40

static var _additive_cache: Dictionary = {}
static var _spark_mesh: QuadMesh
static var _ring_mesh: Mesh
static var _disc_mesh: QuadMesh
static var _scorch_texture: GradientTexture2D
static var _disc_texture: GradientTexture2D
static var _crescent_cache: Dictionary = {}


## Faíscas que explodem de um ponto (impacto de golpe, raio acertando).
static func sparks(parent: Node, at: Vector3, color: Color, amount: int = 24, speed: float = 6.0,
		lifetime: float = 0.35, gravity: float = -12.0) -> void:
	var particles := _place(&"vfx_sparks", _new_sparks, parent, at, lifetime + 0.1) as CPUParticles3D
	particles.amount = amount
	particles.lifetime = lifetime
	particles.material_override = _additive(color.lightened(0.2), 4.0)
	particles.initial_velocity_min = speed * 0.4
	particles.initial_velocity_max = speed
	particles.gravity = Vector3(0.0, gravity, 0.0)
	particles.restart()


## Anel que se expande no chão (onda de choque).
static func shockwave(parent: Node, at: Vector3, radius: float, color: Color, duration: float = 0.35) -> void:
	var ring := _place(&"vfx_ring", _new_ring, parent, at + Vector3.UP * 0.08, duration + 0.05) as MeshInstance3D
	var material := ring.material_override as StandardMaterial3D
	material.albedo_color = _energy_color(color, 3.0)
	ring.scale = Vector3(0.2, 1.0, 0.2)
	var tween := Pools.tween(ring).set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(radius, 1.0, radius), duration) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, duration).set_ease(Tween.EASE_IN)


## Clarão de luz curto (raio, explosão). Luzes custam caro: use só em impactos importantes.
static func flash_light(parent: Node, at: Vector3, color: Color, energy: float = 4.0, light_range: float = 8.0,
		duration: float = 0.25) -> void:
	var light := _place(&"vfx_light", _new_light, parent, at, duration + 0.05) as OmniLight3D
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	Pools.tween(light).tween_property(light, "light_energy", 0.0, duration)


## Marca queimada/brilhante no chão que some devagar.
static func scorch(parent: Node, at: Vector3, radius: float, color: Color, duration: float = 2.5) -> void:
	var mark := _place(&"vfx_scorch", _new_scorch, parent, at + Vector3.UP * 0.04, duration) as MeshInstance3D
	mark.scale = Vector3(radius * 2.0, 1.0, radius * 2.0)
	var material := mark.material_override as StandardMaterial3D
	material.albedo_color = Color(0.05, 0.04, 0.04, 0.85)
	var glow := mark.get_child(0) as MeshInstance3D
	var glow_material := glow.material_override as StandardMaterial3D
	glow_material.albedo_color = _energy_color(color, 2.0)
	var tween := Pools.tween(mark)
	tween.tween_property(glow_material, "albedo_color:a", 0.0, duration * 0.3)
	tween.tween_property(material, "albedo_color:a", 0.0, duration * 0.7)


## Raio caindo do céu num ponto do chão, com clarão, faíscas, onda de choque e marca queimada.
static func lightning_strike(parent: Node, ground: Vector3, color: Color, radius: float = 2.0,
		with_light: bool = true) -> void:
	var sky := ground + Vector3(randf_range(-1.5, 1.5), 16.0, randf_range(-1.5, 1.5))
	LightningArc.spawn(parent, sky, ground + Vector3.UP * 0.1, color, 0.4, 2.4, 0.0)
	LightningArc.spawn(parent, sky, ground + Vector3.UP * 0.1, Color(1, 1, 1), 0.2, 0.8, 0.0)
	LightningArc.spawn(parent, sky.lerp(ground, 0.4), ground + Vector3(randf_range(-1, 1), 0.1, randf_range(-1, 1)),
			color, 0.25, 1.5, 0.0)
	sparks(parent, ground + Vector3.UP * 0.2, color, 40, 9.0, 0.5)
	shockwave(parent, ground, radius, color, 0.4)
	scorch(parent, ground, radius * 0.6, color)
	if with_light:
		flash_light(parent, ground + Vector3.UP * 2.0, color, 8.0, radius * 5.0, 0.35)


## Corte elétrico em meia-lua (Lâmina Voltaica), virado para `facing` e inclinado `tilt` rad.
static func slash_arc(parent: Node, center: Vector3, facing: Vector3, color: Color, radius: float = 1.6,
		duration: float = 0.22, tilt: float = 0.35) -> void:
	var arc := _place(&"vfx_slash", _new_slash, parent, center, duration + 0.05) as MeshInstance3D
	arc.mesh = _crescent_mesh(radius)
	var material := arc.material_override as StandardMaterial3D
	material.albedo_color = _energy_color(color.lightened(0.3), 4.0)
	arc.rotation = Vector3.ZERO
	facing.y = 0.0
	if facing.length_squared() > 0.0001:
		arc.look_at(center + facing.normalized(), Vector3.UP)
	arc.rotate_object_local(Vector3.FORWARD, tilt)
	arc.scale = Vector3.ONE * 0.6
	var tween := Pools.tween(arc).set_parallel(true)
	tween.tween_property(arc, "scale", Vector3.ONE * 1.15, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, duration).set_ease(Tween.EASE_IN)


## Pequenos arcos estalando em volta de um ponto (carregando um poder).
static func charge_crackle(parent: Node, center: Node3D, offset: Vector3, color: Color, duration: float,
		radius: float = 0.5, count: int = 6) -> void:
	for i: int in count:
		var delay := duration * float(i) / float(count)
		parent.get_tree().create_timer(delay, false).timeout.connect(func() -> void:
			if not is_instance_valid(center) or not center.is_inside_tree():
				return
			var origin := center.global_position + center.global_basis * offset
			var start := origin + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * radius
			LightningArc.spawn(parent, start, origin, color, 0.08, 0.6))


## Cinzas e brasas saindo do corpo (desintegração).
static func ash_burst(parent: Node, points: Array[Vector3], color: Color) -> void:
	for point: Vector3 in points:
		sparks(parent, point, color, 8, 2.5, 0.7, 1.5)
		sparks(parent, point, Color(0.12, 0.1, 0.1), 6, 1.5, 1.0, 0.8)


## Círculo de aviso no chão (poder de chefão): borda fixa + preenchimento que cresce até o impacto.
## Some sozinho ao fim de `duration`; para tirar antes, use Pools.release(nó).
static func ground_warning(parent: Node, at: Vector3, radius: float, duration: float,
		color: Color = Color(1.0, 0.2, 0.1)) -> Node3D:
	var root := _place(&"vfx_warning", _new_warning, parent, at + Vector3.UP * 0.06, duration) as Node3D
	var edge := root.get_child(0) as MeshInstance3D
	edge.scale = Vector3(radius, 1.0, radius)
	(edge.material_override as StandardMaterial3D).albedo_color = _energy_color(color, 2.5)
	var fill := root.get_child(1) as MeshInstance3D
	(fill.material_override as StandardMaterial3D).albedo_color = _energy_color(color, 1.2)
	fill.scale = Vector3(0.05, 1.0, 0.05)
	Pools.tween(root).tween_property(fill, "scale", Vector3(radius * 2.0, 1.0, radius * 2.0), duration)
	return root


# --- Internos -----------------------------------------------------------------

## Pega um nó do pool, posiciona e agenda a devolução.
static func _place(key: StringName, factory: Callable, parent: Node, at: Vector3, lifetime: float) -> Node3D:
	var node := Pools.acquire(key, factory, parent) as Node3D
	node.global_position = at
	Pools.release_after(node, lifetime)
	return node


static func _new_sparks() -> Node:
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.mesh = _get_spark_mesh()
	particles.particle_flag_align_y = true
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.6
	particles.scale_amount_curve = _fade_curve()
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles


static func _new_ring() -> Node:
	var ring := MeshInstance3D.new()
	ring.mesh = _get_ring_mesh()
	ring.material_override = _new_additive_material()
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return ring


static func _new_light() -> Node:
	var light := OmniLight3D.new()
	light.shadow_enabled = false
	return light


static func _new_scorch() -> Node:
	var mark := MeshInstance3D.new()
	mark.mesh = _get_disc_mesh()
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = _get_scorch_texture()
	mark.material_override = material
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var glow := MeshInstance3D.new()
	glow.mesh = _get_disc_mesh()
	var glow_material := _new_additive_material()
	glow_material.albedo_texture = _get_disc_texture()
	glow.material_override = glow_material
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.position.y = 0.01
	mark.add_child(glow)
	return mark


static func _new_slash() -> Node:
	var arc := MeshInstance3D.new()
	arc.material_override = _new_additive_material()
	arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return arc


static func _new_warning() -> Node:
	var root := Node3D.new()
	root.name = "GroundWarning"
	var edge := MeshInstance3D.new()
	edge.mesh = _get_ring_mesh()
	edge.material_override = _new_additive_material()
	edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(edge)
	var fill := MeshInstance3D.new()
	fill.mesh = _get_disc_mesh()
	var fill_material := _new_additive_material()
	fill_material.albedo_texture = _get_disc_texture()
	fill.material_override = fill_material
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(fill)
	return root


## Material aditivo próprio do nó (a cor muda a cada uso).
static func _new_additive_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	return material


static func _energy_color(color: Color, energy: float) -> Color:
	return Color(color.r * energy * 0.5, color.g * energy * 0.5, color.b * energy * 0.5, 1.0)


static func _additive(color: Color, energy: float) -> StandardMaterial3D:
	var key := "%s|%.2f" % [color.to_html(), energy]
	if _additive_cache.has(key):
		return _additive_cache[key]
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = _energy_color(color, energy)
	_additive_cache[key] = material
	return material


static func _fade_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	return curve


static func _get_spark_mesh() -> QuadMesh:
	if _spark_mesh == null:
		_spark_mesh = QuadMesh.new()
		_spark_mesh.size = Vector2(SPARK_SIZE, SPARK_SIZE * 4.0)
	return _spark_mesh


static func _get_disc_mesh() -> QuadMesh:
	if _disc_mesh == null:
		_disc_mesh = QuadMesh.new()
		_disc_mesh.size = Vector2.ONE
		_disc_mesh.orientation = PlaneMesh.FACE_Y
	return _disc_mesh


## Anel plano de raio 1 (escalado depois), com borda que some nas pontas (cor por vértice).
static func _get_ring_mesh() -> Mesh:
	if _ring_mesh != null:
		return _ring_mesh
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inner := 0.86
	for i: int in RING_SEGMENTS:
		var a0 := TAU * i / RING_SEGMENTS
		var a1 := TAU * (i + 1) / RING_SEGMENTS
		var o0 := Vector3(cos(a0), 0, sin(a0))
		var o1 := Vector3(cos(a1), 0, sin(a1))
		var quad := [o0 * inner, o0, o1, o0 * inner, o1, o1 * inner]
		var colors := [Color(1, 1, 1, 0), Color.WHITE, Color.WHITE, Color(1, 1, 1, 0), Color.WHITE, Color(1, 1, 1, 0)]
		for k: int in 6:
			surface.set_color(colors[k])
			surface.add_vertex(quad[k])
	_ring_mesh = surface.commit()
	return _ring_mesh


## Meia-lua no plano XY, aberta para -Z (frente), mais grossa no meio.
static func _crescent_mesh(radius: float) -> Mesh:
	var key := snappedf(radius, 0.1)
	if _crescent_cache.has(key):
		return _crescent_cache[key]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 18
	var sweep := PI * 0.9
	for i: int in segments:
		var t0 := float(i) / segments
		var t1 := float(i + 1) / segments
		var a0 := -sweep * 0.5 + sweep * t0
		var a1 := -sweep * 0.5 + sweep * t1
		var w0 := sin(t0 * PI) * 0.35
		var w1 := sin(t1 * PI) * 0.35
		var outer0 := Vector3(sin(a0), 0.0, -cos(a0)) * radius
		var outer1 := Vector3(sin(a1), 0.0, -cos(a1)) * radius
		var inner0 := outer0 * (1.0 - w0)
		var inner1 := outer1 * (1.0 - w1)
		var alpha0 := sin(t0 * PI)
		var alpha1 := sin(t1 * PI)
		var verts := [inner0, outer0, outer1, inner0, outer1, inner1]
		var alphas := [0.0, alpha0, alpha1, 0.0, alpha1, 0.0]
		for k: int in 6:
			surface.set_color(Color(1, 1, 1, alphas[k]))
			surface.add_vertex(verts[k])
	var mesh := surface.commit()
	_crescent_cache[key] = mesh
	return mesh


static func _get_scorch_texture() -> GradientTexture2D:
	if _scorch_texture == null:
		_scorch_texture = _radial_texture(Color(1, 1, 1, 1), Color(1, 1, 1, 0))
	return _scorch_texture


static func _get_disc_texture() -> GradientTexture2D:
	if _disc_texture == null:
		_disc_texture = _radial_texture(Color(1, 1, 1, 0.9), Color(1, 1, 1, 0))
	return _disc_texture


static func _radial_texture(center: Color, edge: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, center)
	gradient.set_color(1, edge)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture
