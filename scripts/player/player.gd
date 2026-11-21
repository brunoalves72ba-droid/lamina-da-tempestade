class_name Player
extends CharacterBody3D
## Herói conjurador de raios: movimento livre em 3ª pessoa (relativo à câmera), combo, parry,
## bloqueio, esquiva, Dardo de Raio, Passo Relâmpago e poderes.
## Os estados pedem um movimento por frame (locomote/push); este script aplica aceleração,
## gravidade e o giro do corpo.

signal parry_succeeded(attacker: Node3D)
signal hit_taken(info: DamageInfo, parry_was_early: bool)
signal bolt_fired(target: Enemy)
signal dash_started(from: Vector3, to: Vector3)
signal power_denied(slot: int)
## Um golpe de espada começou (os inimigos com escudo podem erguer a guarda).
signal swing_started
signal died

const PARRY_FLASH_COLOR := Color(0.55, 0.85, 1.0)
const HURT_FLASH_COLOR := Color(1.0, 0.25, 0.2)
## Animações do combo (biblioteca da Mixamo), uma por golpe.
const ATTACK_ANIMATIONS: Array[StringName] = [&"attack_1", &"attack_2", &"attack_3"]
const POWER_ANIMATIONS: Dictionary = {
	PowerData.Kind.VOLTAIC_BLADE: &"voltaic_blade",
	PowerData.Kind.CHAIN_LIGHTNING: &"cast_chain",
	PowerData.Kind.STORM_FURY: &"cast_storm",
}
const PARRY_ANIMATION_SPEED: float = 1.8
const HURT_ANIMATION_SPEED: float = 1.4
## Golpes e magias: o resto da animação depois do impacto corre mais rápido (ritmo de ação).
const ACTION_SPEED: float = 1.4
const DODGE_TURN_BACK_TIME: float = 0.1
const DODGE_ANIMATION_SPEED: float = 1.8
## Imagens residuais na esquiva e no Passo Relâmpago (velocidade do herói).
const AFTERIMAGES: int = 3
const AFTERIMAGE_TIME: float = 0.28
## Malha da espada no modelo do Paladino (os nomes das malhas vêm trocados no arquivo da Mixamo).
const SWORD_MESH := "Paladin_J_Nordstrom"
const HERO_RIM_COLOR := Color(0.55, 0.65, 0.85)
const HERO_RIM_INTENSITY: float = 0.6
const BLADE_GLOW: float = 1.6
## Eletrocutado causado pelos poderes e pelo Dardo (s) e bônus de dano dos raios na tempestade.
const POWER_SHOCK_TIME: float = 2.0
const BOLT_SHOCK_TIME: float = 1.2
const STORM_POWER_BONUS: float = 0.3
const BLADE_GLOW_CAST: float = 6.0
## Altura de onde sai o Dardo e para onde ele mira no alvo.
const BOLT_ORIGIN_HEIGHT: float = 1.3
const TARGET_AIM_HEIGHT: float = 1.1
## Arcos elétricos em volta do herói quando a Carga está cheia.
const AURA_INTERVAL: float = 0.12
const AURA_RADIUS: float = 0.55
const AURA_MIN_HEIGHT: float = 0.3
const AURA_MAX_HEIGHT: float = 1.9
const AURA_ARC_TIME: float = 0.1

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
## Rotação horizontal da câmera (rad). WASD é relativo a ela; a câmera escreve aqui todo frame.
var view_yaw: float = 0.0
## Testes e cenas automáticas podem dirigir o herói sem teclado.
var use_scripted_input: bool = false
var scripted_move_input: Vector2 = Vector2.ZERO

var _clock: float = 0.0
var _move_intent: Vector3 = Vector3.ZERO
var _last_dodge_end_time: float = -INF
var _aura_timer: float = 0.0
var _last_hit_index: int = -1
var _last_hit_end_time: float = -INF
var _dodge_turn_tween: Tween

@onready var health: HealthComponent = %HealthComponent
@onready var hurtbox: Hurtbox = %Hurtbox
@onready var hitbox: Hitbox = %Hitbox
@onready var input_buffer: InputBuffer = %InputBuffer
@onready var state_machine: StateMachine = %StateMachine
@onready var targeting: Targeting = %Targeting
@onready var bolt_cooldown: Cooldown = %BoltCooldown
@onready var charge: StaticCharge = %StaticCharge
@onready var powers: PowerCaster = %PowerCaster
@onready var body: AnimatedBody = %Body
@onready var _model: Node3D = %Model

## Contorno da lâmina (malha da espada do Paladino): brilha na cor do elemento.
var _blade_glow: ShaderMaterial
var _blade_glow_tween: Tween
## Base e ponta da lâmina (presas à mão direita): origem dos raios e do rastro.
var blade_base: Marker3D
var blade_tip: Marker3D
var _trail: WeaponTrail


func _ready() -> void:
	assert(data != null and weapon != null, "Player precisa de PlayerData e WeaponData")
	_setup_blade()
	_update_glow()
	# Armadura escura do Paladino: contorno suave para o herói não sumir na noite.
	body.set_rim(HERO_RIM_COLOR, HERO_RIM_INTENSITY)
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
	if not health.is_dead:
		_update_facing(delta)
		if charge.is_full:
			_update_charge_aura(delta)
	_apply_motion(delta)
	if not health.is_dead:
		body.update_locomotion(global_basis.inverse() * velocity, targeting.locked, state_machine.is_in(&"Block"))


# --- Movimento livre ----------------------------------------------------------

## Entrada de movimento (x = lado, y = frente/trás; -y é para frente), de 0 a 1.
func move_input() -> Vector2:
	if use_scripted_input:
		return scripted_move_input.limit_length(1.0)
	return Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")


## Direção no mundo correspondente à entrada, relativa à câmera.
func move_direction() -> Vector3:
	var input := move_input()
	return Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, view_yaw)


func wants_to_sprint() -> bool:
	return not use_scripted_input and Input.is_action_pressed(&"sprint") and not targeting.locked


## Estados chamam todo frame: anda na direção da entrada com a velocidade dada.
func locomote(speed: float) -> void:
	_move_intent = move_direction() * speed


## Estados chamam todo frame: movimento horizontal forçado (avanço do golpe, esquiva, empurrão).
func push(horizontal_velocity: Vector3) -> void:
	horizontal_velocity.y = 0.0
	_move_intent = horizontal_velocity


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func forward() -> Vector3:
	var f := -global_basis.z
	f.y = 0.0
	return f.normalized()


## Botão de defesa segurado (parry que vira bloqueio). Testes usam scripted_defend_held.
var scripted_defend_held: bool = false


func is_defend_held() -> bool:
	if use_scripted_input:
		return scripted_defend_held
	return Input.is_action_pressed(&"parry")


func can_dodge() -> bool:
	return _clock - _last_dodge_end_time >= data.dodge_cooldown


func mark_dodge_finished() -> void:
	_last_dodge_end_time = _clock


func _apply_motion(delta: float) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var accelerating := _move_intent.length() > horizontal.length()
	var rate := data.acceleration if accelerating else data.deceleration
	# Movimentos forçados (esquiva, empurrão) respondem na hora.
	if not _move_intent.is_zero_approx() and not state_machine.is_in(&"Idle") and not state_machine.is_in(&"Block"):
		rate = INF
	horizontal = horizontal.move_toward(_move_intent, rate * delta) if rate != INF else _move_intent
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= data.gravity * delta
	move_and_slide()
	_move_intent = Vector3.ZERO


## Para onde o corpo olha: alvo travado > alvo próximo durante ações de combate > direção do movimento.
func _update_facing(delta: float) -> void:
	var combat_action := not (state_machine.is_in(&"Idle") or state_machine.is_in(&"Dodge"))
	var free_aim := targeting.is_free_aim() and not targeting.locked
	var face_target := not free_aim and target != null \
			and (targeting.locked or (combat_action and is_target_in_soft_range()))
	var desired := Vector3.ZERO
	if face_target:
		desired = target.global_position - global_position
	elif free_aim and combat_action:
		# Mira livre: golpes e magias saem para onde a câmera aponta.
		desired = Vector3.FORWARD.rotated(Vector3.UP, view_yaw)
	elif not _move_intent.is_zero_approx() and not state_machine.is_in(&"Attack"):
		desired = _move_intent
	desired.y = 0.0
	if desired.length_squared() < 0.0001:
		return
	var target_yaw := atan2(-desired.x, -desired.z)
	var step := INF if combat_action and (face_target or free_aim) else data.turn_speed * delta
	rotation.y = target_yaw if step == INF else rotate_toward(rotation.y, target_yaw, step)


func is_target_in_soft_range() -> bool:
	return distance_to_target() <= data.soft_aim_range


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
	body.rotation = Vector3.ZERO
	body.stop_action()
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


## Espada do próprio modelo: contorno brilhante, marcadores de base/ponta e rastro do golpe.
func _setup_blade() -> void:
	_blade_glow = ShaderMaterial.new()
	_blade_glow.shader = preload("res://shaders/rim_overlay.gdshader")
	_blade_glow.set_shader_parameter(&"power", 1.2)
	var sword := body.find_mesh(SWORD_MESH)
	if sword != null:
		sword.material_overlay = _blade_glow
	var points := body.weapon_points(SWORD_MESH, &"mixamorig_RightHand")
	if points.is_empty():
		points = [Vector3(0.1, 0, 0), Vector3(0.95, 0, 0)]
	var holder := Node3D.new()
	holder.name = "BladePoints"
	body.attach(&"mixamorig_RightHand", holder)
	blade_base = Marker3D.new()
	blade_base.name = "BladeBase"
	blade_base.position = points[0].lerp(points[1], 0.2)
	holder.add_child(blade_base)
	blade_tip = Marker3D.new()
	blade_tip.name = "BladeTip"
	blade_tip.position = points[1]
	holder.add_child(blade_tip)
	_trail = WeaponTrail.new()
	_trail.name = "WeaponTrail"
	_trail.base_marker = blade_base
	_trail.tip_marker = blade_tip
	add_child(_trail)


func _update_glow() -> void:
	var color := lightning_color()
	_blade_glow.set_shader_parameter(&"rim_color", color)
	_blade_glow.set_shader_parameter(&"intensity", BLADE_GLOW)
	if _trail != null:
		_trail.color = color


## Lâmina brilha forte por um instante (lançando um poder).
func pulse_blade(duration: float = 0.4) -> void:
	if _blade_glow_tween != null:
		_blade_glow_tween.kill()
	_blade_glow.set_shader_parameter(&"intensity", BLADE_GLOW_CAST)
	_blade_glow_tween = create_tween()
	_blade_glow_tween.tween_method(func(v: float) -> void: _blade_glow.set_shader_parameter(&"intensity", v),
			BLADE_GLOW_CAST, BLADE_GLOW, duration)


func blade_tip_position() -> Vector3:
	return blade_tip.global_position if blade_tip != null else global_position + Vector3.UP * BOLT_ORIGIN_HEIGHT


func lightning_color() -> Color:
	return Element.color(element)


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
## Com tempestade (Weather) os raios ficam até 30% mais fortes e eletrocutam por mais tempo.
func build_power_info(multiplier: float, heavy: bool, shock_time: float = POWER_SHOCK_TIME) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = base_damage * multiplier * storm_multiplier()
	info.element = element
	info.is_heavy = heavy
	info.is_power = true
	info.shock_time = shock_time * (1.0 + GameState.storm_intensity * 0.5)
	info.counter_multiplier = data.counter_multiplier
	info.source = self
	return info


func storm_multiplier() -> float:
	return 1.0 + GameState.storm_intensity * STORM_POWER_BONUS


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


## Estado de ataque a usar a partir do Idle. Dardo/Passo Relâmpago só com alvo travado e distante
## (até o alcance do Passo); sem travar, o golpe sai onde o herói está.
func choose_attack_state() -> StringName:
	if target == null or is_target_in_melee_range() or not targeting.locked:
		return &"Attack"
	if distance_to_target() > data.dash_max_distance + data.dash_stop_distance:
		return &"Attack"
	return &"Bolt" if bolt_cooldown.is_ready else &"Dash"


func fire_bolt() -> void:
	var bolt_target := target
	if bolt_target == null:
		return
	bolt_cooldown.start(data.bolt_cooldown)
	var info := build_power_info(data.bolt_damage_multiplier, false, BOLT_SHOCK_TIME)
	var from := blade_tip_position()
	var to := bolt_target.global_position + Vector3.UP * TARGET_AIM_HEIGHT
	var color := lightning_color()
	LightningArc.spawn(get_parent(), from, to, color, 0.22, 1.4, 0.0)
	LightningArc.spawn(get_parent(), from, to, color.lightened(0.5), 0.12, 0.6, 0.0)
	Vfx.sparks(get_parent(), to, color, 28, 7.0)
	Vfx.shockwave(get_parent(), bolt_target.global_position, 1.2, color, 0.25)
	Vfx.flash_light(get_parent(), to, color, 3.0, 6.0, 0.15)
	pulse_blade(0.25)
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
	var color := lightning_color()
	LightningArc.spawn(get_parent(), from + height, to + height, color, data.dash_duration + 0.15, 1.6)
	LightningArc.spawn(get_parent(), from + Vector3.UP * 0.3, to + Vector3.UP * 0.3, color, data.dash_duration + 0.1, 0.8)
	Vfx.sparks(get_parent(), from + Vector3.UP * 0.5, color, 20, 5.0)
	Vfx.shockwave(get_parent(), from, 1.4, color, 0.25)
	_spawn_afterimages(data.dash_duration)
	pulse_blade(data.dash_duration + 0.2)
	SfxLibrary.play(self, &"dash")
	dash_started.emit(from, to)


## Chegada do Passo Relâmpago: estalo no chão.
func end_dash() -> void:
	var color := lightning_color()
	Vfx.sparks(get_parent(), global_position + Vector3.UP * 0.4, color, 24, 6.0)
	Vfx.shockwave(get_parent(), global_position, 1.8, color, 0.3)


## Cópias brilhantes da pose deixadas para trás durante `duration` (velocidade de raio).
func _spawn_afterimages(duration: float) -> void:
	var color := lightning_color()
	body.afterimage(color, AFTERIMAGE_TIME, get_parent())
	for i: int in range(1, AFTERIMAGES):
		get_tree().create_timer(duration * float(i) / AFTERIMAGES, false).timeout.connect(func() -> void:
			if is_inside_tree():
				body.afterimage(color, AFTERIMAGE_TIME, get_parent()))


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


## Golpe recebido com o escudo erguido (estado Block): dano reduzido, sem cambalear.
func take_blocked_hit(info: DamageInfo) -> void:
	info.amount *= (1.0 - data.block_reduction) * (1.0 - damage_reduction)
	health.take_damage(info.amount)
	Events.damage_taken.emit(self, info)
	flash(PARRY_FLASH_COLOR)
	body.play_action(&"block_hit")
	SfxLibrary.play(self, &"block")
	if health.is_dead:
		state_machine.transition_to(&"Dead")
		died.emit()
		Events.entity_died.emit(self)


## Direção do empurrão ao tomar um golpe: para longe de quem bateu.
func knockback_direction(info: DamageInfo) -> Vector3:
	if info.source == null or not is_instance_valid(info.source):
		return -forward()
	var away := global_position - info.source.global_position
	away.y = 0.0
	return away.normalized() if away.length_squared() > 0.0001 else -forward()


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
		state_machine.transition_to(&"Hurt", {"knockback": knockback_direction(info)})


# --- Visual (animações da Mixamo) -------------------------------------------

## Golpe do combo: o impacto da animação coincide com o fim da preparação + meio da fase ativa.
func begin_swing(hit_index: int) -> void:
	var anim := ATTACK_ANIMATIONS[hit_index % ATTACK_ANIMATIONS.size()]
	body.play_action_hit_at(anim, weapon.hit_windup + weapon.hit_active * 0.5, ACTION_SPEED)
	_trail.emit_for(weapon.hit_windup + weapon.hit_active + 0.08)
	SfxLibrary.play(self, &"swing")
	swing_started.emit()


func set_pose_rest() -> void:
	body.stop_action()


func set_pose_guard() -> void:
	body.play_action(&"parry", PARRY_ANIMATION_SPEED)
	_trail.emit_for(0.1)


## Dardo de Raio: lança na hora (a animação começa no instante do lançamento).
func set_pose_cast() -> void:
	body.play_action_hit_at(&"cast_bolt", data.bolt_cast_time, ACTION_SPEED)
	Vfx.charge_crackle(get_parent(), blade_tip, Vector3.ZERO, lightning_color(), data.bolt_cast_time, 0.35, 3)


func play_power_cast(power: PowerData) -> void:
	body.play_action_hit_at(POWER_ANIMATIONS.get(power.kind, &"cast_chain"), power.cast_time, ACTION_SPEED)
	pulse_blade(power.cast_time + 0.3)
	SfxLibrary.play(self, &"cast")
	var color := lightning_color()
	Vfx.charge_crackle(get_parent(), blade_tip, Vector3.ZERO, color, power.cast_time, 0.5, 5)
	if power.kind == PowerData.Kind.STORM_FURY:
		Vfx.charge_crackle(get_parent(), self, Vector3.UP * 1.0, color, power.cast_time, 1.2, 8)
		Vfx.shockwave(get_parent(), global_position, 2.5, color, power.cast_time)
	elif power.kind == PowerData.Kind.VOLTAIC_BLADE:
		_trail.emit_for(power.cast_time + 0.15)


func set_pose_whiff() -> void:
	body.stop_action()
	SfxLibrary.play(self, &"whiff")


func play_hurt() -> void:
	body.play_action(&"hurt", HURT_ANIMATION_SPEED)


## Esquiva relâmpago: o corpo vira para a direção da esquiva e dispara correndo, deixando
## imagens residuais e um rastro elétrico no chão (o herói é rápido como um raio).
func play_dodge(direction: Vector3, duration: float) -> void:
	var local_direction := global_basis.inverse() * direction
	if _dodge_turn_tween != null:
		_dodge_turn_tween.kill()
	body.rotation.y = atan2(-local_direction.x, -local_direction.z)
	body.play_action(&"sprint", DODGE_ANIMATION_SPEED)
	var color := lightning_color()
	body.flash(color, 2.0)
	var start := global_position + Vector3.UP * 0.25
	var end := start + direction * data.dodge_distance
	LightningArc.spawn(get_parent(), start, end, color, duration + 0.1, 0.7)
	Vfx.sparks(get_parent(), start, color, 14, 4.0)
	_spawn_afterimages(duration)
	SfxLibrary.play(self, &"dash")


func end_dodge() -> void:
	body.stop_action()
	_dodge_turn_tween = create_tween()
	_dodge_turn_tween.tween_property(body, "rotation:y", 0.0, DODGE_TURN_BACK_TIME)


func play_death() -> void:
	body.play_action(&"death", 1.0, 0.0, true)


func flash(color: Color) -> void:
	body.flash(color)


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
