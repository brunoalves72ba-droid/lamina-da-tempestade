class_name Player
extends CharacterBody3D
## Herói conjurador de raios: combo, parry, Dardo de Raio e Passo Relâmpago.
## Nos trilhos, quem move o herói é o RailController (estado Travel).

signal parry_succeeded(attacker: Node3D)
signal hit_taken(info: DamageInfo, parry_was_early: bool)
signal bolt_fired(target: Enemy)
signal dash_started(from: Vector3, to: Vector3)
signal power_denied(slot: int)
signal died

const BODY_COLOR := Color(0.32, 0.42, 0.58)
const PARRY_FLASH_COLOR := Color(0.55, 0.85, 1.0)
const HURT_FLASH_COLOR := Color(1.0, 0.25, 0.2)
const FLASH_TIME: float = 0.25
const POSE_BLEND_TIME: float = 0.15
const GUARD_BLEND_TIME: float = 0.05
## Altura de onde sai o Dardo e para onde ele mira no alvo.
const BOLT_ORIGIN_HEIGHT: float = 1.3
const TARGET_AIM_HEIGHT: float = 1.1
## Poses da espada (rotação do pivô, em graus).
const REST_POSE := Vector3(-20.0, -35.0, 0.0)
const GUARD_POSE := Vector3(0.0, 90.0, 10.0)
const WHIFF_POSE := Vector3(-45.0, 60.0, 0.0)
const CAST_POSE := Vector3(60.0, -10.0, 0.0)
const SWING_FROM: Array[Vector3] = [Vector3(0.0, 80.0, 0.0), Vector3(0.0, -80.0, 0.0), Vector3(80.0, 0.0, 0.0)]
const SWING_TO: Array[Vector3] = [Vector3(0.0, -80.0, 0.0), Vector3(0.0, 80.0, 0.0), Vector3(-50.0, 0.0, 0.0)]
const DEAD_TILT := Vector3(-80.0, 0.0, 0.0)
## Arcos elétricos em volta do herói quando a Carga está cheia.
const AURA_INTERVAL: float = 0.12
const AURA_RADIUS: float = 0.55
const AURA_MIN_HEIGHT: float = 0.3
const AURA_MAX_HEIGHT: float = 1.9
const AURA_ARC_TIME: float = 0.1
const GLOW_ENERGY: float = 2.0

@export var data: PlayerData
@export var weapon: WeaponData

## Alvo atual, escolhido pelo componente Targeting.
var target: Enemy:
	get:
		return targeting.current if targeting != null else null
## Elemento da espada, escolhido antes da fase (GDD §7). Colore os raios.
var element: Element.Type = Element.Type.NONE
## ATK e redução de dano atuais (base dos dados + upgrades da loja, GDD §10).
var base_damage: float = 0.0
var damage_reduction: float = 0.0

var _clock: float = 0.0
var _aura_timer: float = 0.0
var _last_hit_index: int = -1
var _last_hit_end_time: float = -INF
var _body_material: StandardMaterial3D
var _pose_tween: Tween
var _flash_tween: Tween

@onready var health: HealthComponent = %HealthComponent
@onready var hurtbox: Hurtbox = %Hurtbox
@onready var hitbox: Hitbox = %Hitbox
@onready var input_buffer: InputBuffer = %InputBuffer
@onready var state_machine: StateMachine = %StateMachine
@onready var targeting: Targeting = %Targeting
@onready var bolt_cooldown: Cooldown = %BoltCooldown
@onready var charge: StaticCharge = %StaticCharge
@onready var powers: PowerCaster = %PowerCaster
@onready var _model: Node3D = %Model
@onready var _body_mesh: MeshInstance3D = %BodyMesh
@onready var _sword_pivot: Node3D = %SwordPivot
## Partes que brilham na cor do elemento: viseira, crista e lâmina.
@onready var _glow_parts: Array[MeshInstance3D] = [%Visor, %Crest, %SwordMesh]

var _glow_material: StandardMaterial3D


func _ready() -> void:
	assert(data != null and weapon != null, "Player precisa de PlayerData e WeaponData")
	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = BODY_COLOR
	_body_mesh.material_override = _body_material
	_glow_material = StandardMaterial3D.new()
	_glow_material.emission_enabled = true
	for part: MeshInstance3D in _glow_parts:
		part.material_override = _glow_material
	_update_glow()
	_sword_pivot.rotation_degrees = REST_POSE
	input_buffer.buffer_time = data.input_buffer_time
	bolt_cooldown.duration = data.bolt_cooldown
	charge.maximum = data.charge_max
	base_damage = weapon.base_damage
	damage_reduction = data.damage_reduction
	health.reset(data.max_health)
	hurtbox.hit_received.connect(_on_hit_received)
	hitbox.hit_landed.connect(_on_hitbox_hit_landed)
	charge.filled.connect(_on_charge_filled)


func _physics_process(delta: float) -> void:
	_clock += delta
	if health.is_dead:
		return
	if not is_traveling():
		_face_target()
	if charge.is_full:
		_update_charge_aura(delta)


func reset_state() -> void:
	health.reset(health.max_health)
	input_buffer.clear()
	hitbox.disarm()
	bolt_cooldown.reset()
	powers.reset()
	charge.consume_all()
	_last_hit_index = -1
	_last_hit_end_time = -INF
	_model.rotation_degrees = Vector3.ZERO
	state_machine.transition_to(&"Idle")


func heal(amount: float) -> void:
	health.heal(amount)


## Aplica os status vindos dos upgrades (chamado pela fase antes de começar).
func apply_stats(new_base_damage: float, new_max_health: float, new_damage_reduction: float) -> void:
	base_damage = new_base_damage
	damage_reduction = new_damage_reduction
	health.reset(new_max_health)


func set_element(new_element: Element.Type) -> void:
	element = new_element
	_update_glow()


func _update_glow() -> void:
	var color := lightning_color()
	_glow_material.albedo_color = color
	_glow_material.emission = color
	_glow_material.emission_energy_multiplier = GLOW_ENERGY


func lightning_color() -> Color:
	return Element.color(element)


# --- Trilho -----------------------------------------------------------------

func begin_travel() -> void:
	if not health.is_dead:
		state_machine.transition_to(&"Travel")


func end_travel() -> void:
	if is_traveling():
		state_machine.transition_to(&"Idle")


func is_traveling() -> bool:
	return state_machine.is_in(&"Travel")


func face_direction(direction: Vector3) -> void:
	direction.y = 0.0
	if direction.length_squared() > 0.000001:
		look_at(global_position + direction, Vector3.UP)


# --- Combo ------------------------------------------------------------------

func combo_length() -> int:
	return weapon.combo_multipliers.size()


## Próximo golpe ao atacar a partir do Idle: continua o combo se ainda estiver na janela.
func next_combo_index() -> int:
	var within_window := _clock - _last_hit_end_time <= data.combo_reset_time
	if within_window and _last_hit_index + 1 < combo_length():
		return _last_hit_index + 1
	return 0


func can_chain(hit_index: int) -> bool:
	return hit_index + 1 < combo_length()


func mark_hit_finished(hit_index: int) -> void:
	_last_hit_index = hit_index
	_last_hit_end_time = _clock


func recovery_time(hit_index: int) -> float:
	if hit_index == combo_length() - 1:
		return weapon.final_hit_recovery
	return weapon.hit_recovery


func build_attack_info(hit_index: int) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = base_damage * weapon.combo_multipliers[hit_index]
	info.element = element
	info.is_heavy = hit_index in weapon.heavy_hits
	info.counter_multiplier = data.counter_multiplier
	info.source = self
	return info


## Dano de um poder de raio: escala com o ATK da espada e usa o elemento dela (GDD §6.5).
func build_power_info(multiplier: float, heavy: bool) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = base_damage * multiplier
	info.element = element
	info.is_heavy = heavy
	info.counter_multiplier = data.counter_multiplier
	info.source = self
	return info


# --- Poderes de raio (GDD §6.5) ---------------------------------------------

## Estado e mensagem para lançar o poder do slot; vazio se não dá para usar agora.
func power_transition(slot: int) -> Dictionary:
	if not powers.can_use(slot):
		power_denied.emit(slot)
		return {}
	if powers.power(slot).requires_melee and not is_target_in_melee_range():
		return {"state": &"Dash", "msg": {"then_power": slot}}
	return {"state": &"Power", "msg": {"slot": slot}}


# --- Distância: Dardo de Raio e Passo Relâmpago (GDD §6.4) -------------------

func distance_to_target() -> float:
	if target == null:
		return INF
	var offset := target.global_position - global_position
	offset.y = 0.0
	return offset.length()


func is_target_in_melee_range() -> bool:
	return distance_to_target() <= data.melee_range


## Estado de ataque a usar a partir do Idle, conforme a distância do alvo.
func choose_attack_state() -> StringName:
	if target == null or is_target_in_melee_range():
		return &"Attack"
	return &"Bolt" if bolt_cooldown.is_ready else &"Dash"


func fire_bolt() -> void:
	var bolt_target := target
	if bolt_target == null:
		return
	bolt_cooldown.start(data.bolt_cooldown)
	var info := DamageInfo.new()
	info.amount = base_damage * data.bolt_damage_multiplier
	info.element = element
	info.source = self
	var from := global_position + Vector3.UP * BOLT_ORIGIN_HEIGHT
	var to := bolt_target.global_position + Vector3.UP * TARGET_AIM_HEIGHT
	LightningArc.spawn(get_parent(), from, to, lightning_color(), -1.0, 1.0, 1.5)
	SfxLibrary.play(self, &"zap")
	bolt_fired.emit(bolt_target)
	bolt_target.hurtbox.receive_hit(info)


func dash_destination() -> Vector3:
	if target == null:
		return global_position
	var offset := target.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance < 0.001:
		return global_position
	var travel := clampf(distance - data.dash_stop_distance, 0.0, data.dash_max_distance)
	return global_position + offset / distance * travel


func begin_dash(from: Vector3, to: Vector3) -> void:
	var height := Vector3.UP * BOLT_ORIGIN_HEIGHT
	LightningArc.spawn(get_parent(), from + height, to + height, lightning_color(), data.dash_duration)
	SfxLibrary.play(self, &"dash")
	dash_started.emit(from, to)


# --- Defesa e dano ----------------------------------------------------------

func resolve_parry(info: DamageInfo) -> void:
	if info.on_parried.is_valid():
		info.on_parried.call()
	SfxLibrary.play(self, &"parry")
	flash(PARRY_FLASH_COLOR)
	charge.add(data.charge_parry)
	parry_succeeded.emit(info.source)
	Events.parry_succeeded.emit(self, info.source)


func _on_hit_received(info: DamageInfo) -> void:
	if health.is_dead:
		return
	var state := state_machine.current_state as PlayerState
	if state != null and state.handle_hit(info):
		return
	_take_hit(info)


func _take_hit(info: DamageInfo) -> void:
	# Ainda em Parry aqui = janela já fechou, está na recuperação (parry cedo).
	var parry_was_early := state_machine.is_in(&"Parry")
	info.amount *= 1.0 - damage_reduction
	health.take_damage(info.amount)
	charge.remove(data.charge_damage_loss)
	hit_taken.emit(info, parry_was_early)
	Events.damage_taken.emit(self, info)
	SfxLibrary.play(self, &"player_hurt")
	flash(HURT_FLASH_COLOR)
	if health.is_dead:
		state_machine.transition_to(&"Dead")
		died.emit()
		Events.entity_died.emit(self)
	else:
		state_machine.transition_to(&"Hurt")


# --- Visual (placeholder) ---------------------------------------------------

func begin_swing(hit_index: int) -> void:
	var pose_index := hit_index % SWING_FROM.size()
	_sword_pivot.rotation_degrees = SWING_FROM[pose_index]
	_tween_pose(SWING_TO[pose_index], weapon.hit_windup + weapon.hit_active)
	SfxLibrary.play(self, &"swing")


func set_pose_rest() -> void:
	_tween_pose(REST_POSE, POSE_BLEND_TIME)


func set_pose_guard() -> void:
	_tween_pose(GUARD_POSE, GUARD_BLEND_TIME)


func set_pose_cast() -> void:
	_tween_pose(CAST_POSE, GUARD_BLEND_TIME)


func set_pose_whiff() -> void:
	_tween_pose(WHIFF_POSE, POSE_BLEND_TIME)
	SfxLibrary.play(self, &"whiff")


func play_death() -> void:
	var tween := create_tween()
	tween.tween_property(_model, "rotation_degrees", DEAD_TILT, POSE_BLEND_TIME * 3.0)


func flash(color: Color) -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	_body_material.albedo_color = color
	_flash_tween = create_tween()
	_flash_tween.tween_property(_body_material, "albedo_color", BODY_COLOR, FLASH_TIME)


func _tween_pose(pose: Vector3, duration: float) -> void:
	if _pose_tween != null:
		_pose_tween.kill()
	_pose_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_pose_tween.tween_property(_sword_pivot, "rotation_degrees", pose, duration)


func _face_target() -> void:
	if target == null:
		return
	face_direction(target.global_position - global_position)


func _on_hitbox_hit_landed(_hurtbox: Hurtbox, info: DamageInfo) -> void:
	charge.add(data.charge_counter if info.is_counter else data.charge_combo_hit)


func _on_charge_filled() -> void:
	SfxLibrary.play(self, &"charge_full")


## Carga cheia: pequenos arcos elétricos estalando em volta do corpo (GDD §6.6).
func _update_charge_aura(delta: float) -> void:
	_aura_timer -= delta
	if _aura_timer > 0.0:
		return
	_aura_timer = AURA_INTERVAL
	var angle := randf() * TAU
	var start := global_position + Vector3(cos(angle), 0.0, sin(angle)) * AURA_RADIUS \
			+ Vector3.UP * randf_range(AURA_MIN_HEIGHT, AURA_MAX_HEIGHT)
	var end := start + Vector3(randf_range(-0.3, 0.3), randf_range(-0.4, 0.4), randf_range(-0.3, 0.3))
	LightningArc.spawn(get_parent(), start, end, lightning_color(), AURA_ARC_TIME, 0.6)
