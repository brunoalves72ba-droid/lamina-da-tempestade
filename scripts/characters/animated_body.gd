class_name AnimatedBody
extends Node3D
## Corpo animado (personagens e animações da Mixamo). Herói, inimigos e chefões usam este componente.
## - Modelo texturizado: `model_scene` (no .tscn) ou `setup(cena)` em código (inimigos escolhem pelo EnemyData).
## - Locomoção: escolhe parado/andar/correr/sprint/andar de lado conforme a velocidade local e
##   ajusta a velocidade da animação à velocidade real (os pés não deslizam).
## - Ações (golpes, magias, defesa, morte): play_action_*; sincroniza o instante de impacto.
## - Equipamentos presos aos ossos (attach), brilho de contorno (flash, set_rim),
##   imagens residuais (afterimage) e desintegração (disintegrate).
## Qualquer personagem da Mixamo serve (mesmos nomes de ossos `mixamorig_*`).

const OVERLAY_SHADER := preload("res://shaders/rim_overlay.gdshader")
const CORRUPTION_SHADER := preload("res://shaders/corruption.gdshader")
## Velocidade (m/s) em que cada animação de locomoção foi gravada (medida do deslocamento original).
const NATURAL_SPEED: Dictionary = {
	&"walk": 1.5, &"walk_back": 1.13, &"run": 4.14, &"run_back": 4.4, &"sprint": 5.6,
	&"strafe_left": 1.08, &"strafe_right": 1.23, &"strafe_left_run": 3.46, &"strafe_right_run": 3.4,
}
## Instante (s) do impacto/lançamento em cada ação (pico de velocidade da mão, medido).
const IMPACT_TIME: Dictionary = {
	&"attack_1": 0.60, &"attack_2": 0.43, &"attack_3": 0.75, &"enemy_strike": 0.60, &"elite_strike": 0.55,
	&"shoot": 0.82, &"cast_bolt": 0.49, &"cast_chain": 0.58, &"cast_storm": 1.25, &"voltaic_blade": 1.32,
	&"boss_slam": 1.68, &"boss_roar": 0.5, &"boss_volley": 1.14, &"boss_leap": 1.38,
}
const LOCOMOTION_BLEND: float = 0.15
const ACTION_BLEND: float = 0.06
const IDLE_SPEED: float = 0.25
const RUN_SPEED: float = 2.8
const SPRINT_SPEED: float = 6.4
const MIN_SPEED_SCALE: float = 0.6
const MAX_SPEED_SCALE: float = 1.8
const FLASH_TIME: float = 0.25
const DISINTEGRATE_BONES: Array[StringName] = [
	&"mixamorig_Hips", &"mixamorig_Spine2", &"mixamorig_Head", &"mixamorig_LeftHand", &"mixamorig_RightHand",
	&"mixamorig_LeftForeArm", &"mixamorig_RightForeArm", &"mixamorig_LeftLeg", &"mixamorig_RightLeg",
	&"mixamorig_LeftFoot", &"mixamorig_RightFoot",
]

@export var model_scene: PackedScene
@export var library: AnimationLibrary

var skeleton: Skeleton3D
var animator: AnimationPlayer
var meshes: Array[MeshInstance3D] = []

var _model: Node3D
var _overlay: ShaderMaterial
var _action: StringName = &""
var _action_active: bool = false
var _hold_action: bool = false
var _base_rim: Color = Color.BLACK
var _base_rim_intensity: float = 0.0
var _flash_tween: Tween
var _ghost_material: StandardMaterial3D
var _corruption: ShaderMaterial


func _ready() -> void:
	if model_scene != null and _model == null:
		setup(model_scene)


## Instancia o modelo (olhando para -Z), liga o contorno e a biblioteca de animações.
func setup(scene: PackedScene) -> void:
	assert(_model == null, "AnimatedBody.setup só pode ser chamado uma vez")
	model_scene = scene
	_model = scene.instantiate() as Node3D
	_model.rotation.y = PI  # modelos da Mixamo olham para +Z; no Godot, frente é -Z
	add_child(_model)
	skeleton = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	_overlay = ShaderMaterial.new()
	_overlay.shader = OVERLAY_SHADER
	for node: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.material_overlay = _overlay
		meshes.append(mesh)
	animator = AnimationPlayer.new()
	animator.name = "Animator"
	_model.add_child(animator)
	animator.add_animation_library(&"", library)
	animator.animation_finished.connect(_on_animation_finished)
	animator.play(&"idle")


func is_ready() -> bool:
	return _model != null


## Malha do modelo com esse nome exato; null se não houver.
## (Atenção: no Paladino da Mixamo os nomes vêm trocados — a espada é "Paladin_J_Nordstrom".)
func find_mesh(mesh_name: String) -> MeshInstance3D:
	for mesh: MeshInstance3D in meshes:
		if String(mesh.name) == mesh_name:
			return mesh
	return null


## Prende um nó a um osso (espada na mão, escudo no antebraço...).
func attach(bone_name: StringName, node: Node3D, offset: Transform3D = Transform3D.IDENTITY) -> BoneAttachment3D:
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = bone_name
	skeleton.add_child(attachment)
	attachment.add_child(node)
	node.transform = offset
	return attachment


## Ponta e base de uma arma que faz parte da malha do modelo (espada do Paladino), no espaço do osso
## que a segura: o vértice mais distante do osso na pose de descanso é a ponta.
## Retorna [base, ponta] (Vector3) ou [] se a malha não existir.
func weapon_points(mesh_name: String, bone_name: StringName) -> Array[Vector3]:
	var mesh := find_mesh(mesh_name)
	var bone := skeleton.find_bone(bone_name)
	if mesh == null or bone == -1:
		return []
	var bone_rest := skeleton.get_bone_global_rest(bone)
	var to_skeleton := skeleton.global_transform.affine_inverse() * mesh.global_transform
	var tip := Vector3.ZERO
	var base := Vector3.ZERO
	var far := -1.0
	var near := INF
	for vertex: Vector3 in mesh.mesh.get_faces():
		var point := to_skeleton * vertex
		var distance := point.distance_to(bone_rest.origin)
		if distance > far:
			far = distance
			tip = point
		if distance < near:
			near = distance
			base = point
	var inverse := bone_rest.affine_inverse()
	return [inverse * base, inverse * tip]


# --- Locomoção ----------------------------------------------------------------

## Chamado todo frame. local_velocity: velocidade no espaço do personagem (frente = -Z).
## strafing: andando de lado/costas sem virar (alvo travado). blocking: escudo erguido.
func update_locomotion(local_velocity: Vector3, strafing: bool, blocking: bool) -> void:
	if is_action_active():
		return
	var horizontal := Vector2(local_velocity.x, local_velocity.z)
	var speed := horizontal.length()
	var anim: StringName = &"idle"
	if blocking:
		anim = &"block_idle"
	elif speed > IDLE_SPEED:
		var running := speed > RUN_SPEED
		var forward := -local_velocity.z
		var side := local_velocity.x
		if not strafing or absf(forward) >= absf(side):
			if forward >= -0.1 or not strafing:
				anim = &"sprint" if speed > SPRINT_SPEED else (&"run" if running else &"walk")
			else:
				anim = &"run_back" if running else &"walk_back"
		elif side > 0.0:
			anim = &"strafe_right_run" if running else &"strafe_right"
		else:
			anim = &"strafe_left_run" if running else &"strafe_left"
	if animator.current_animation != anim:
		animator.play(anim, LOCOMOTION_BLEND)
	var natural: float = NATURAL_SPEED.get(anim, 0.0)
	animator.speed_scale = clampf(speed / natural, MIN_SPEED_SCALE, MAX_SPEED_SCALE) if natural > 0.0 else 1.0


# --- Ações --------------------------------------------------------------------

## Toca uma ação do início com velocidade fixa. hold = fica no último quadro (morte).
func play_action(anim: StringName, speed: float = 1.0, from_time: float = 0.0, hold: bool = false) -> void:
	_action = anim
	_action_active = true
	_hold_action = hold
	animator.play(anim, ACTION_BLEND)
	animator.speed_scale = speed
	if from_time > 0.0:
		animator.seek(from_time, true)


## Toca uma ação esticando/comprimindo para durar `duration` segundos.
func play_action_for(anim: StringName, duration: float) -> void:
	var length := animator.get_animation(anim).length
	play_action(anim, clampf(length / maxf(duration, 0.01), 0.3, 4.0))


## Toca uma ação de golpe/magia para que o impacto (IMPACT_TIME) aconteça daqui a `time_to_impact` s.
## Se o impacto da animação vem depois disso, pula o começo; se vem antes, desacelera.
## `speed` acelera o resto da animação depois do impacto (ritmo de ação).
func play_action_hit_at(anim: StringName, time_to_impact: float, speed: float = 1.0) -> void:
	var impact: float = IMPACT_TIME.get(anim, 0.0)
	time_to_impact = maxf(time_to_impact, 0.01)
	if impact >= time_to_impact * speed:
		play_action(anim, speed, impact - time_to_impact * speed)
	else:
		play_action(anim, impact / time_to_impact)


func stop_action() -> void:
	_action_active = false
	_hold_action = false


func is_action_active() -> bool:
	if not _action_active:
		return false
	if _hold_action:
		return true
	return animator.is_playing() and animator.current_animation == _action


func _on_animation_finished(anim: StringName) -> void:
	if anim == _action and not _hold_action:
		_action_active = false


# --- Brilho de contorno -------------------------------------------------------

## Contorno persistente (cor do elemento, atordoado). intensity 0 = nenhum.
func set_rim(color: Color, intensity: float) -> void:
	_base_rim = color
	_base_rim_intensity = intensity
	if _flash_tween == null or not _flash_tween.is_running():
		_apply_rim(color, intensity)


## Flash rápido (dano, parry) que volta ao contorno persistente.
func flash(color: Color, intensity: float = 2.5) -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	_apply_rim(color, intensity)
	_flash_tween = create_tween()
	_flash_tween.tween_method(func(t: float) -> void:
		_apply_rim(color.lerp(_base_rim, t), lerpf(intensity, _base_rim_intensity, t)), 0.0, 1.0, FLASH_TIME)


func _apply_rim(color: Color, intensity: float) -> void:
	_overlay.set_shader_parameter(&"rim_color", color)
	_overlay.set_shader_parameter(&"intensity", intensity)


# --- Efeitos de velocidade e destruição ---------------------------------------

## Imagem residual: cópia congelada da pose atual, brilhando na cor dada e sumindo (velocidade).
func afterimage(color: Color, duration: float = 0.3, parent: Node = null) -> void:
	if DisplayServer.get_name() == "headless":
		return  # sem GPU não dá para copiar a pose (testes automáticos)
	if parent == null:
		parent = get_tree().current_scene
	if _ghost_material == null:
		_ghost_material = StandardMaterial3D.new()
		_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ghost_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_ghost_material.no_depth_test = false
	var material := _ghost_material.duplicate() as StandardMaterial3D
	material.albedo_color = Color(color.r, color.g, color.b, 0.55)
	var ghost := Node3D.new()
	ghost.name = "Afterimage"
	parent.add_child(ghost)
	ghost.global_transform = global_transform
	for mesh: MeshInstance3D in meshes:
		if not mesh.is_visible_in_tree():
			continue
		var copy := MeshInstance3D.new()
		copy.mesh = mesh.bake_mesh_from_current_skeleton_pose()
		copy.material_override = material
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ghost.add_child(copy)
		copy.global_transform = mesh.global_transform
	var tween := ghost.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, duration)
	tween.tween_callback(ghost.queue_free)


## Posições atuais (mundo) de alguns ossos espalhados pelo corpo (faíscas, cinzas).
func body_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for bone_name: StringName in DISINTEGRATE_BONES:
		var bone := skeleton.find_bone(bone_name)
		if bone != -1:
			points.append(skeleton.global_transform * skeleton.get_bone_global_pose(bone).origin)
	return points


## Desintegração: o corpo brilha, vira cinzas/faíscas e some (morte por raio).
func disintegrate(color: Color, duration: float = 0.6) -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	_apply_rim(color, 4.0)
	Vfx.ash_burst(get_tree().current_scene, body_points(), color)
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void: _apply_rim(color, lerpf(4.0, 8.0, t)), 0.0, 1.0, duration * 0.5)
	tween.tween_property(_model, "scale", Vector3(1.0, 0.02, 1.0), duration * 0.5) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: _model.visible = false)


## Corrupção demoníaca (veias escuras e rachaduras de brasa pulsando) por cima do modelo.
func set_corruption(amount: float, glow: Color) -> void:
	if _corruption == null:
		_corruption = ShaderMaterial.new()
		_corruption.shader = CORRUPTION_SHADER
		_overlay.next_pass = _corruption
	_corruption.set_shader_parameter(&"corruption", amount)
	_corruption.set_shader_parameter(&"glow_color", glow)


## Olhos brilhando presos à cabeça (offset no espaço do osso; x é espelhado para o outro olho).
func add_glowing_eyes(color: Color, offset: Vector3, size: float = 0.013) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(color.r * 2.2, color.g * 1.2, color.b * 1.2)
	var sphere := SphereMesh.new()
	sphere.radius = size
	sphere.height = size * 1.4
	sphere.radial_segments = 8
	sphere.rings = 4
	sphere.material = material
	for side: float in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		eye.name = "Eye"
		eye.mesh = sphere
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		attach(&"mixamorig_Head", eye, Transform3D(Basis.IDENTITY, Vector3(offset.x * side, offset.y, offset.z)))


## Aura sombria: fiapos escuros subindo em volta do corpo.
func add_dark_aura(color: Color, radius: float = 0.5, amount: int = 10) -> void:
	var particles := CPUParticles3D.new()
	particles.name = "DarkAura"
	particles.amount = amount
	particles.lifetime = 1.6
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	particles.emission_ring_axis = Vector3.UP
	particles.emission_ring_radius = radius
	particles.emission_ring_inner_radius = radius * 0.5
	particles.emission_ring_height = 0.1
	particles.direction = Vector3.UP
	particles.spread = 15.0
	particles.gravity = Vector3(0.0, 0.8, 0.0)
	particles.initial_velocity_min = 0.2
	particles.initial_velocity_max = 0.6
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.2
	var quad := QuadMesh.new()
	quad.size = Vector2(0.35, 0.6)
	particles.mesh = quad
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	var gradient_texture := GradientTexture2D.new()
	var soft := Gradient.new()
	soft.set_color(0, Color(1, 1, 1, 1))
	soft.set_color(1, Color(1, 1, 1, 0))
	gradient_texture.gradient = soft
	gradient_texture.fill = GradientTexture2D.FILL_RADIAL
	gradient_texture.fill_from = Vector2(0.5, 0.5)
	gradient_texture.fill_to = Vector2(1.0, 0.5)
	gradient_texture.width = 32
	gradient_texture.height = 32
	material.albedo_texture = gradient_texture
	particles.material_override = material
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color.r, color.g, color.b, 0.0))
	ramp.add_point(0.3, Color(color.r, color.g, color.b, 0.45))
	ramp.set_color(ramp.get_point_count() - 1, Color(color.r, color.g, color.b, 0.0))
	particles.color_ramp = ramp
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)


## Volta ao normal depois de uma desintegração (inimigo do sandbox que renasce).
func restore() -> void:
	_model.visible = true
	_model.scale = Vector3.ONE
	_apply_rim(_base_rim, _base_rim_intensity)
