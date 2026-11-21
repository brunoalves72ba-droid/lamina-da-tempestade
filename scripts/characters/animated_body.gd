class_name AnimatedBody
extends Node3D
## Corpo animado (modelo e animações da Mixamo). Herói e inimigos usam este componente.
## - Locomoção: escolhe parado/andar/correr/sprint/andar de lado conforme a velocidade local e
##   ajusta a velocidade da animação à velocidade real (os pés não deslizam).
## - Ações (golpes, magias, defesa, morte): play_action_*; sincroniza o instante de impacto.
## - Equipamentos presos aos ossos (attach) e brilho de contorno (flash, set_rim).
## Qualquer personagem da Mixamo serve (mesmos nomes de ossos `mixamorig_*`).

const OVERLAY_SHADER := preload("res://shaders/rim_overlay.gdshader")
## Velocidade (m/s) em que cada animação de locomoção foi gravada (medida do deslocamento original).
const NATURAL_SPEED: Dictionary = {
	&"walk": 1.5, &"walk_back": 1.13, &"run": 4.14, &"run_back": 4.4, &"sprint": 5.6,
	&"strafe_left": 1.08, &"strafe_right": 1.23, &"strafe_left_run": 3.46, &"strafe_right_run": 3.4,
}
## Instante (s) do impacto/lançamento em cada ação (pico de velocidade da mão, medido).
const IMPACT_TIME: Dictionary = {
	&"attack_1": 0.60, &"attack_2": 0.43, &"attack_3": 0.75, &"enemy_strike": 0.60, &"elite_strike": 0.55,
	&"shoot": 0.82, &"cast_bolt": 0.49, &"cast_chain": 0.58, &"cast_storm": 1.25, &"voltaic_blade": 1.32,
}
const LOCOMOTION_BLEND: float = 0.2
const ACTION_BLEND: float = 0.08
const IDLE_SPEED: float = 0.25
const RUN_SPEED: float = 2.8
const SPRINT_SPEED: float = 5.4
const MIN_SPEED_SCALE: float = 0.6
const MAX_SPEED_SCALE: float = 1.7
const FLASH_TIME: float = 0.25

@export var model_scene: PackedScene
@export var library: AnimationLibrary
@export var body_color: Color = Color(0.35, 0.45, 0.6)
@export var joints_color: Color = Color(0.08, 0.08, 0.1)
@export var metallic: float = 0.55
@export var roughness: float = 0.4

var skeleton: Skeleton3D
var animator: AnimationPlayer

var _model: Node3D
var _surface_material: StandardMaterial3D
var _joints_material: StandardMaterial3D
var _overlay: ShaderMaterial
var _action: StringName = &""
var _action_active: bool = false
var _hold_action: bool = false
var _base_rim: Color = Color.BLACK
var _base_rim_intensity: float = 0.0
var _flash_tween: Tween


func _ready() -> void:
	_model = model_scene.instantiate() as Node3D
	_model.rotation.y = PI  # modelos da Mixamo olham para +Z; no Godot, frente é -Z
	add_child(_model)
	skeleton = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	_surface_material = _make_material(body_color)
	_joints_material = _make_material(joints_color)
	_overlay = ShaderMaterial.new()
	_overlay.shader = OVERLAY_SHADER
	for node: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.material_override = _joints_material if String(mesh.name).to_lower().contains("joint") else _surface_material
		mesh.material_overlay = _overlay
	animator = AnimationPlayer.new()
	animator.name = "Animator"
	_model.add_child(animator)
	animator.add_animation_library(&"", library)
	animator.animation_finished.connect(_on_animation_finished)
	animator.play(&"idle")


func set_body_color(color: Color) -> void:
	body_color = color
	_surface_material.albedo_color = color


## Prende um nó a um osso (espada na mão, escudo no antebraço...).
func attach(bone_name: StringName, node: Node3D, offset: Transform3D = Transform3D.IDENTITY) -> BoneAttachment3D:
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = bone_name
	skeleton.add_child(attachment)
	attachment.add_child(node)
	node.transform = offset
	return attachment


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


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material
