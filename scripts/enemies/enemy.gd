class_name Enemy
extends CharacterBody3D
## Inimigo base: Soldado, Besteiro e Elite mudam só pelo EnemyData.
## Em guarda mantém distância do herói; só ataca quando o AttackTokenManager concede o token (GDD §6.3).

signal attack_telegraphed(time_to_impact: float)
signal attack_finished
signal parried
signal died

const GROUP := &"enemies"
const HIT_FLASH_COLOR := Color(1.0, 0.95, 0.85)
## Amarelo elétrico: lê como "eletrocutado pela Descarga" e não se confunde com o azul do herói.
const STUN_COLOR := Color(0.95, 0.82, 0.25)
const FLASH_TIME: float = 0.2
const POSE_BLEND_TIME: float = 0.2
const SPAWN_START_SCALE: float = 0.05
const DEATH_REMOVE_DELAY: float = 1.5
const PROJECTILE_ORIGIN_HEIGHT: float = 1.3
## Poses da arma (rotação do pivô, em graus).
const REST_POSE := Vector3(-20.0, 0.0, 0.0)
const WINDUP_POSE := Vector3(80.0, 0.0, 0.0)
const AIM_POSE := Vector3(0.0, 0.0, 0.0)
const STRIKE_POSE := Vector3(-60.0, 0.0, 0.0)
const STUNNED_POSE := Vector3(-75.0, 0.0, 25.0)
const DEAD_TILT := Vector3(85.0, 0.0, 0.0)
## Fração do aviso usada para levantar a arma (o resto é a pausa antes do golpe).
const WINDUP_FRACTION: float = 0.6
## Inimigos em guarda do lado da câmera (produto escalar acima disto) contornam o herói
## para a frente, para não taparem a visão.
const CAMERA_SIDE_THRESHOLD: float = 0.2
## Inimigo colado na câmera fica invisível (o anel de aviso no chão continua aparecendo).
const CAMERA_HIDE_DISTANCE: float = 2.2
const CAMERA_HIDE_HEIGHT: float = 1.0

@export var data: EnemyData
@export var projectile_scene: PackedScene
## Desligue para testar sem ser atacado.
@export var auto_attack: bool = true
## Inimigos de onda somem da cena depois de mortos; o do sandbox fica para renascer.
@export var remove_after_death: bool = false

var element: Element.Type = Element.Type.NONE
var target: Node3D
## Marcado por _on_parried durante o golpe; o estado Strike lê e vai para Stunned.
var strike_was_parried: bool = false
## Último golpe recebido (o WaveSpawner usa para decidir o finisher).
var last_hit: DamageInfo

var _strikes_left: int = 0
var _show_stun_label: bool = false
var _target_health: HealthComponent
var _target_hurtbox: Hurtbox
var _counter_consumed: bool = false
var _body_material: StandardMaterial3D
var _pose_tween: Tween
var _flash_tween: Tween

@onready var health: HealthComponent = %HealthComponent
@onready var hurtbox: Hurtbox = %Hurtbox
@onready var hitbox: Hitbox = %Hitbox
@onready var state_machine: StateMachine = %StateMachine
@onready var telegraph: TelegraphIndicator = %TelegraphIndicator
@onready var _model: Node3D = %Model
@onready var _body_mesh: MeshInstance3D = %BodyMesh
@onready var _weapon_pivot: Node3D = %WeaponPivot
@onready var _stun_label: Label3D = %StunLabel
@onready var _helmet: MeshInstance3D = %Helmet
@onready var _blade: MeshInstance3D = %WeaponMesh
@onready var _crossbow: Node3D = %Crossbow
@onready var _shield: Node3D = %Shield
@onready var _horns: Node3D = %Horns


func _ready() -> void:
	assert(data != null, "Enemy precisa de EnemyData")
	add_to_group(GROUP)
	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = data.body_color
	_body_mesh.material_override = _body_material
	_model.scale = Vector3.ONE * data.body_scale
	_apply_model_variant()
	_weapon_pivot.rotation_degrees = REST_POSE
	_show_stun_label = false
	set_element(element)
	health.reset(data.max_health)
	hurtbox.hit_received.connect(_on_hit_received)


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var near_camera := camera != null and \
			camera.global_position.distance_to(global_position + Vector3.UP * CAMERA_HIDE_HEIGHT) < CAMERA_HIDE_DISTANCE
	_model.visible = not near_camera
	_stun_label.visible = _show_stun_label and not near_camera


func _physics_process(_delta: float) -> void:
	if health.is_dead:
		return
	_face_target()
	if state_machine.is_in(&"Idle"):
		_update_guard_movement()


func _apply_model_variant() -> void:
	var variant := data.model_variant
	var is_crossbowman := variant == EnemyData.ModelVariant.CROSSBOWMAN
	_crossbow.visible = is_crossbowman
	_blade.visible = not is_crossbowman
	_shield.visible = not is_crossbowman
	_horns.visible = variant == EnemyData.ModelVariant.ELITE


## Afinidade elemental (GDD §7). O elmo brilha na cor do elemento; neutro mantém o ferro.
func set_element(new_element: Element.Type) -> void:
	element = new_element
	if element == Element.Type.NONE:
		_helmet.material_override = null
		return
	var material := StandardMaterial3D.new()
	var color := Element.color(element)
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.2
	_helmet.material_override = material


func set_target(new_target: Node3D) -> void:
	target = new_target
	_target_health = new_target.get_node_or_null(^"HealthComponent") as HealthComponent
	_target_hurtbox = new_target.get_node_or_null(^"Hurtbox") as Hurtbox


func is_ranged() -> bool:
	return data.attack_kind == EnemyData.AttackKind.RANGED


func is_stunned() -> bool:
	return state_machine.is_in(&"Stunned")


func can_attack() -> bool:
	return auto_attack and _target_health != null and not _target_health.is_dead


func distance_to_target() -> float:
	if target == null:
		return INF
	var offset := target.global_position - global_position
	offset.y = 0.0
	return offset.length()


## Corpo a corpo: perto o bastante para acertar. À distância: longe o bastante do herói.
func is_in_attack_position() -> bool:
	var distance := distance_to_target()
	if is_ranged():
		return distance >= data.engage_distance - data.position_tolerance
	return distance <= data.engage_distance + data.position_tolerance


func can_receive_token() -> bool:
	return state_machine.is_in(&"Idle") and can_attack() and is_in_attack_position()


func grant_attack_token() -> void:
	_strikes_left = data.strikes_per_attack
	state_machine.transition_to(&"Telegraph")


func is_telegraphing() -> bool:
	return state_machine.is_in(&"Telegraph")


## Golpe seguinte do mesmo ataque (Elite). Consome um golpe e retorna true se ainda houver.
func take_followup_strike() -> bool:
	_strikes_left -= 1
	return _strikes_left > 0


## Lâmina Voltaica quebra a guarda: cancela o aviso e o ataque inteiro (GDD §6.5).
func interrupt_attack() -> void:
	if not is_telegraphing():
		return
	_strikes_left = 0
	SfxLibrary.play(self, &"interrupt")
	state_machine.transition_to(&"Recover")


func reset_state() -> void:
	health.reset(data.max_health)
	hitbox.disarm()
	telegraph.stop()
	hurtbox.invulnerable = false
	_model.scale = Vector3.ONE * data.body_scale
	_model.rotation_degrees = Vector3.ZERO
	state_machine.transition_to(&"Idle")
	attack_finished.emit()


# --- Ciclo de ataque (chamado pelos estados) --------------------------------

func begin_telegraph() -> void:
	telegraph.play(data.telegraph_time)
	var pose := AIM_POSE if is_ranged() else WINDUP_POSE
	_tween_pose(pose, data.telegraph_time * WINDUP_FRACTION)
	SfxLibrary.play(self, &"telegraph")
	attack_telegraphed.emit(data.telegraph_time)


## Besteiro: o virote voa data.projectile_flight_time e chega quando o aviso termina.
func launch_projectile() -> void:
	if projectile_scene == null or _target_hurtbox == null:
		return
	var projectile := projectile_scene.instantiate() as EnemyProjectile
	get_parent().add_child(projectile)
	var origin := global_position + Vector3.UP * PROJECTILE_ORIGIN_HEIGHT
	projectile.launch(origin, _target_hurtbox, _build_attack_info(), data.projectile_flight_time)
	SfxLibrary.play(self, &"bolt_fire")


func begin_strike() -> void:
	telegraph.stop()
	strike_was_parried = false
	_tween_pose(STRIKE_POSE, data.strike_active_time)
	if not is_ranged():
		hitbox.arm(_build_attack_info())


func end_strike() -> void:
	hitbox.disarm()


func finish_attack() -> void:
	attack_finished.emit()


func set_pose_rest(duration: float = POSE_BLEND_TIME) -> void:
	_tween_pose(REST_POSE, duration)


func play_spawn() -> void:
	hurtbox.invulnerable = true
	_model.scale = Vector3.ONE * data.body_scale * SPAWN_START_SCALE
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(_model, "scale", Vector3.ONE * data.body_scale, data.spawn_time) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func end_spawn() -> void:
	hurtbox.invulnerable = false


func begin_stun() -> void:
	_counter_consumed = false
	_show_stun_label = true
	_body_material.albedo_color = STUN_COLOR
	_tween_pose(STUNNED_POSE, POSE_BLEND_TIME)


func end_stun() -> void:
	_show_stun_label = false
	_body_material.albedo_color = data.body_color


func play_death() -> void:
	hitbox.disarm()
	telegraph.stop()
	_show_stun_label = false
	var tween := create_tween()
	tween.tween_property(_model, "rotation_degrees", DEAD_TILT, POSE_BLEND_TIME * 2.0)
	if remove_after_death:
		get_tree().create_timer(DEATH_REMOVE_DELAY, false, true).timeout.connect(queue_free)


# --- Dano -------------------------------------------------------------------

func _build_attack_info() -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = data.attack_damage
	info.element = element
	info.can_be_parried = true
	info.source = self
	info.on_parried = _on_parried
	return info


func _on_parried() -> void:
	strike_was_parried = true
	hitbox.disarm()
	parried.emit()


func _on_hit_received(info: DamageInfo) -> void:
	if health.is_dead:
		return
	info.element_multiplier = Element.multiplier(info.element, element)
	info.amount *= info.element_multiplier
	# Contra-ataque: só o primeiro golpe recebido em cada atordoamento (GDD §6.2).
	if is_stunned() and not _counter_consumed and info.counter_multiplier > 1.0:
		info.amount *= info.counter_multiplier
		info.is_counter = true
		info.is_heavy = true
		_counter_consumed = true
	last_hit = info
	health.take_damage(info.amount)
	Events.damage_taken.emit(self, info)
	SfxLibrary.play(self, &"hit_heavy" if info.is_heavy else &"hit")
	_flash()
	if health.is_dead:
		state_machine.transition_to(&"Dead")
		died.emit()
		Events.entity_died.emit(self)


# --- Movimento em guarda ----------------------------------------------------

## Aproxima/afasta até engage_distance, sai da frente da câmera e se afasta de outros inimigos.
func _update_guard_movement() -> void:
	if target == null:
		return
	var direction := Vector3.ZERO
	var to_target := target.global_position - global_position
	to_target.y = 0.0
	var distance := to_target.length()
	if distance > 0.001:
		var half_tolerance := data.position_tolerance * 0.5
		if distance > data.engage_distance + half_tolerance:
			direction += to_target / distance
		elif distance < data.engage_distance - half_tolerance:
			direction -= to_target / distance
		direction += _away_from_camera_side(-to_target / distance)
	for node: Node in get_tree().get_nodes_in_group(GROUP):
		var other := node as Enemy
		if other == null or other == self or other.health.is_dead:
			continue
		var away := global_position - other.global_position
		away.y = 0.0
		var gap := away.length()
		if gap > 0.001 and gap < data.separation_radius:
			direction += away / gap * (1.0 - gap / data.separation_radius)
	velocity = direction.limit_length(1.0) * data.move_speed
	move_and_slide()


## Empurrão tangencial (em volta do herói) para quem está entre a câmera e o herói.
func _away_from_camera_side(from_target: Vector3) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3.ZERO
	var to_camera := camera.global_position - target.global_position
	to_camera.y = 0.0
	if to_camera.length_squared() < 0.0001:
		return Vector3.ZERO
	to_camera = to_camera.normalized()
	var camera_side := from_target.dot(to_camera)
	if camera_side <= CAMERA_SIDE_THRESHOLD:
		return Vector3.ZERO
	var tangent := Vector3.UP.cross(from_target)
	if tangent.dot(to_camera) > 0.0:
		tangent = -tangent
	return tangent * camera_side


func _flash() -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	var base_color := STUN_COLOR if is_stunned() else data.body_color
	_body_material.albedo_color = HIT_FLASH_COLOR
	_flash_tween = create_tween()
	_flash_tween.tween_property(_body_material, "albedo_color", base_color, FLASH_TIME)


func _tween_pose(pose: Vector3, duration: float) -> void:
	if _pose_tween != null:
		_pose_tween.kill()
	_pose_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_pose_tween.tween_property(_weapon_pivot, "rotation_degrees", pose, duration)


func _face_target() -> void:
	if target == null or not is_instance_valid(target):
		return
	var look_point := target.global_position
	look_point.y = global_position.y
	if global_position.distance_squared_to(look_point) > 0.01:
		look_at(look_point, Vector3.UP)
