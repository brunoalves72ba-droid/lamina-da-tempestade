class_name ThirdPersonCamera
extends Node3D
## Câmera em 3ª pessoa por cima do ombro (movimento livre).
## Mouse gira (yaw/pitch); um SpringArm3D aproxima a câmera quando há parede no caminho.
## Com alvo travado, gira sozinha para manter herói e alvo na tela.
## A cada frame informa ao herói a rotação horizontal (WASD é relativo a ela).

@export var player: Player
@export var mouse_sensitivity: float = 0.0025
@export_range(-89.0, 0.0) var pitch_min_degrees: float = -55.0
@export_range(0.0, 89.0) var pitch_max_degrees: float = 35.0
@export var default_pitch_degrees: float = -12.0
@export var arm_length: float = 3.6
## Ponto de mira em relação aos pés do herói (x = deslocamento para o ombro direito).
@export var shoulder_offset: Vector3 = Vector3(0.6, 1.6, 0.0)
@export var follow_sharpness: float = 16.0
@export var lock_turn_sharpness: float = 7.0
@export var locked_pitch_degrees: float = -14.0
## Camadas que encurtam o braço da câmera (1 = world).
@export_flags_3d_physics var obstacle_mask: int = 1

var yaw: float = 0.0
var pitch: float = 0.0

@onready var _pitch_pivot: Node3D = $PitchPivot
@onready var _spring_arm: SpringArm3D = $PitchPivot/SpringArm
@onready var camera: Camera3D = $PitchPivot/SpringArm/Camera


func _ready() -> void:
	top_level = true
	_spring_arm.spring_length = arm_length
	_spring_arm.collision_mask = obstacle_mask
	pitch = deg_to_rad(default_pitch_degrees)
	if player != null:
		_spring_arm.add_excluded_object(player.get_rid())
		yaw = player.rotation.y
		snap()


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion == null or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if player != null and player.targeting.locked:
		return
	yaw -= motion.relative.x * mouse_sensitivity
	pitch = clampf(pitch - motion.relative.y * mouse_sensitivity,
			deg_to_rad(pitch_min_degrees), deg_to_rad(pitch_max_degrees))


func snap() -> void:
	global_position = _focus_point()
	_apply_rotation()


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var weight := 1.0 - exp(-follow_sharpness * delta)
	global_position = global_position.lerp(_focus_point(), weight)
	_update_lock_rotation(delta)
	_apply_rotation()
	player.view_yaw = yaw


func _focus_point() -> Vector3:
	return player.global_position + Vector3.UP * shoulder_offset.y


func _update_lock_rotation(delta: float) -> void:
	var target := player.target
	if not player.targeting.locked or target == null:
		return
	var to_target := target.global_position - player.global_position
	to_target.y = 0.0
	if to_target.length_squared() < 0.01:
		return
	var desired_yaw := atan2(-to_target.x, -to_target.z)
	var weight := 1.0 - exp(-lock_turn_sharpness * delta)
	yaw = lerp_angle(yaw, desired_yaw, weight)
	pitch = lerpf(pitch, deg_to_rad(locked_pitch_degrees), weight)


func _apply_rotation() -> void:
	rotation = Vector3(0.0, yaw, 0.0)
	_pitch_pivot.rotation = Vector3(pitch, 0.0, 0.0)
	_pitch_pivot.position = Vector3(shoulder_offset.x, 0.0, 0.0)
