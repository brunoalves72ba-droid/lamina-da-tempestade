class_name Enemy
extends CharacterBody3D
## Inimigo base: comuns e chefões mudam só pelo EnemyData (modelo, status, poderes do BossData).
## Em guarda mantém distância do herói; só ataca quando o AttackTokenManager concede o token (GDD §6.3).

signal attack_telegraphed(time_to_impact: float)
signal attack_finished
signal parried
signal died

const GROUP := &"enemies"
const HIT_FLASH_COLOR := Color(1.0, 0.95, 0.85)
## Amarelo elétrico: lê como "eletrocutado pela Descarga" e não se confunde com o azul do herói.
const STUN_COLOR := Color(0.95, 0.82, 0.25)
const STUN_RIM_INTENSITY: float = 2.0
const ELEMENT_RIM_INTENSITY: float = 0.7
const DEATH_REMOVE_DELAY: float = 2.2
## Depois de cair, o corpo se desintegra em cinzas e brasas.
const DISINTEGRATE_DELAY: float = 1.1
const DISINTEGRATE_COLOR := Color(1.0, 0.55, 0.2)
## Chance de desmembrar numa morte por golpe normal de espada (forte/crítico: sempre).
const DISMEMBER_CHANCE: float = 0.35
const SHOCK_SLOW: float = 0.45
const SHOCK_CRIT_MULTIPLIER: float = 1.5
const SHOCK_ARC_INTERVAL: float = 0.09
const SHOCK_TWITCH_DEGREES: float = 7.0
const SHOCK_COLOR := Color(0.7, 0.9, 1.0)
const PROJECTILE_ORIGIN_HEIGHT: float = 1.3
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
## Multiplicadores de vida e dano conforme o nível do herói (definidos por quem cria o inimigo).
var health_scale: float = 1.0
var damage_scale: float = 1.0
var target: Node3D
## Marcado por _on_parried durante o golpe; o estado Strike lê e vai para Stunned.
var strike_was_parried: bool = false
## Último golpe recebido (o WaveSpawner usa para decidir o finisher).
var last_hit: DamageInfo

var _strikes_left: int = 0
## Percebeu o herói (por distância ou por ter sido atingido).
var is_aware: bool = false
var _strafe_sign: float = 1.0
var _strafe_timer: float = 0.0
var _knockback: Vector3 = Vector3.ZERO
var _show_stun_label: bool = false
var _target_health: HealthComponent
var _target_hurtbox: Hurtbox
var _counter_consumed: bool = false
## Poderes de chefão (só existe se data.boss != null).
var boss_brain: BossBrain
## Eletrocutado (GDD §6.9): segundos restantes. Fica mais lento, treme com arcos no corpo e
## golpes físicos de espada viram críticos.
var shock_remaining: float = 0.0
var _shock_arc_timer: float = 0.0
var _death_timer: SceneTreeTimer
var _death_by_power: bool = false

@onready var health: HealthComponent = %HealthComponent
@onready var hurtbox: Hurtbox = %Hurtbox
@onready var hitbox: Hitbox = %Hitbox
@onready var state_machine: StateMachine = %StateMachine
@onready var telegraph: TelegraphIndicator = %TelegraphIndicator
@onready var body: AnimatedBody = %Body
@onready var _model: Node3D = %Model
@onready var _stun_label: Label3D = %StunLabel


func _ready() -> void:
	assert(data != null, "Enemy precisa de EnemyData")
	add_to_group(GROUP)
	body.setup(data.model)
	_model.scale = Vector3.ONE * data.body_scale
	_apply_body_scale()
	_equip()
	if data.boss != null:
		boss_brain = BossBrain.new(self, data.boss)
		add_child(boss_brain)
	_show_stun_label = false
	set_element(element)
	health.reset(data.max_health * health_scale)
	hurtbox.hit_received.connect(_on_hit_received)


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var near_camera := camera != null and \
			camera.global_position.distance_to(global_position + Vector3.UP * CAMERA_HIDE_HEIGHT) < CAMERA_HIDE_DISTANCE
	_model.visible = not near_camera
	_stun_label.visible = _show_stun_label and not near_camera


func _physics_process(delta: float) -> void:
	var desired := Vector3.ZERO
	if not health.is_dead:
		_update_awareness()
		desired = _desired_velocity(delta)
		if not state_machine.is_in(&"Strike") and not state_machine.is_in(&"Stagger"):
			_turn_toward_target(delta)
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	horizontal = horizontal.move_toward(desired, data.acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = -0.5 if is_on_floor() else velocity.y - data.gravity * delta
	if boss_brain != null and boss_brain.is_airborne():
		return
	if shock_remaining > 0.0:
		_update_shock(delta)
		velocity.x *= SHOCK_SLOW
		velocity.z *= SHOCK_SLOW
	move_and_slide()
	if shock_remaining > 0.0:
		velocity.x /= SHOCK_SLOW
		velocity.z /= SHOCK_SLOW
	if not health.is_dead:
		body.update_locomotion(global_basis.inverse() * velocity, is_aware, false)


## Só o Soldado carrega armas (espada e escudo); os outros lutam com garras e magia.
func _equip() -> void:
	if data.model_variant != EnemyData.ModelVariant.SOLDIER:
		return
	var blade := StandardMaterial3D.new()
	blade.albedo_color = Equipment.STEEL.darkened(0.3)
	blade.metallic = 0.85
	blade.roughness = 0.35
	body.attach(&"mixamorig_RightHand", Equipment.sword(blade, 0.75))
	body.attach(&"mixamorig_LeftForeArm", Equipment.round_shield(), Equipment.round_shield_offset())


## Personagens maiores (chefões): colisão, área de dano, área do golpe e rótulo acompanham a escala.
func _apply_body_scale() -> void:
	var s := data.body_scale
	if is_equal_approx(s, 1.0):
		return
	for shape_node: CollisionShape3D in [$CollisionShape3D, $Hurtbox/CollisionShape3D] as Array[CollisionShape3D]:
		var capsule := (shape_node.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
		capsule.radius *= s
		capsule.height *= s
		shape_node.shape = capsule
		shape_node.position *= s
	var hit_shape := $Hitbox/CollisionShape3D as CollisionShape3D
	var box := (hit_shape.shape as BoxShape3D).duplicate() as BoxShape3D
	box.size *= s
	hit_shape.shape = box
	hit_shape.position *= s
	_stun_label.position.y *= s


## Afinidade elemental (GDD §7): contorno na cor do elemento; neutro sem contorno.
func set_element(new_element: Element.Type) -> void:
	element = new_element
	if boss_brain != null and boss_brain.is_enraged:
		body.set_rim(data.boss.power_color, BossBrain.RAGE_RIM_INTENSITY)
	elif element == Element.Type.NONE:
		body.set_rim(Color.BLACK, 0.0)
	else:
		body.set_rim(Element.color(element), ELEMENT_RIM_INTENSITY)


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
	if boss_brain != null and boss_brain.wants_power():
		state_machine.transition_to(&"Power", {"power": boss_brain.next_power()})
		return
	_strikes_left = data.strikes_per_attack
	state_machine.transition_to(&"Telegraph")


func is_boss() -> bool:
	return data.boss != null


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
	health.reset(data.max_health * health_scale)
	hitbox.disarm()
	telegraph.stop()
	hurtbox.invulnerable = false
	_model.scale = Vector3.ONE * data.body_scale
	_model.rotation_degrees = Vector3.ZERO
	shock_remaining = 0.0
	if _death_timer != null and _death_timer.timeout.is_connected(_disintegrate):
		_death_timer.timeout.disconnect(_disintegrate)
	body.restore()
	Gore.restore(self)
	body.stop_action()
	if boss_brain != null:
		boss_brain.reset()
	set_element(element)
	state_machine.transition_to(&"Idle")
	attack_finished.emit()


# --- Ciclo de ataque (chamado pelos estados) --------------------------------

func begin_telegraph() -> void:
	telegraph.play(data.telegraph_time)
	if is_ranged():
		body.play_action_hit_at(&"shoot", data.telegraph_time - data.projectile_flight_time)
	else:
		body.play_action_hit_at(data.strike_animation, data.telegraph_time)
	SfxLibrary.play(self, &"telegraph")
	attack_telegraphed.emit(data.telegraph_time)


## Besteiro: o virote voa data.projectile_flight_time e chega quando o aviso termina.
func launch_projectile() -> void:
	if projectile_scene == null or _target_hurtbox == null:
		return
	var projectile := EnemyProjectile.spawn(projectile_scene, get_parent())
	projectile.set_color(data.projectile_color)
	var origin := global_position + Vector3.UP * PROJECTILE_ORIGIN_HEIGHT * data.body_scale
	projectile.launch(origin, _target_hurtbox, _build_attack_info(), data.projectile_flight_time)
	SfxLibrary.play(self, &"bolt_fire")


func begin_strike() -> void:
	telegraph.stop()
	strike_was_parried = false
	if not is_ranged():
		hitbox.arm(_build_attack_info())


func end_strike() -> void:
	hitbox.disarm()


func finish_attack() -> void:
	attack_finished.emit()


func set_pose_rest(_duration: float = 0.0) -> void:
	body.stop_action()


func play_spawn() -> void:
	hurtbox.invulnerable = true
	body.play_action_for(&"spawn", data.spawn_time)


func end_spawn() -> void:
	hurtbox.invulnerable = false


func begin_stun() -> void:
	_counter_consumed = false
	_show_stun_label = true
	body.set_rim(STUN_COLOR, STUN_RIM_INTENSITY)
	body.play_action_for(&"stunned", data.stun_time)


func end_stun() -> void:
	_show_stun_label = false
	body.stop_action()
	set_element(element)


func play_death() -> void:
	hitbox.disarm()
	telegraph.stop()
	_show_stun_label = false
	body.play_action(&"death", 1.0, 0.0, true)
	SfxLibrary.play(self, &"roar" if is_boss() else &"enemy_die")
	_death_by_power = last_hit != null and last_hit.is_power
	if not _death_by_power and last_hit != null and last_hit.source is Player and not is_boss():
		# Morte por espada: sangue e, em golpe forte, desmembramento.
		if last_hit.is_heavy or last_hit.is_critical or randf() < DISMEMBER_CHANCE:
			Gore.dismember(self, _away_from(last_hit.source))
		else:
			Gore.blood_pool(get_parent(), global_position, 0.9)
	if is_metal_armored():
		Conduction.drop_metal(get_parent(), global_position + global_basis.x * 0.6)
	if boss_brain != null:
		boss_brain.cancel()
	_death_timer = get_tree().create_timer(DISINTEGRATE_DELAY, false, true)
	_death_timer.timeout.connect(_disintegrate)
	if remove_after_death:
		get_tree().create_timer(DEATH_REMOVE_DELAY, false, true).timeout.connect(queue_free)


func _disintegrate() -> void:
	if not health.is_dead:
		return
	# Morte por espada com gore ligado: o corpo fica (sangue) em vez de virar cinzas.
	if Gore.enabled() and not _death_by_power and not is_boss():
		return
	var color := Element.color(element) if element != Element.Type.NONE else DISINTEGRATE_COLOR
	body.disintegrate(color)
	SfxLibrary.play(self, &"disintegrate")


# --- Dano -------------------------------------------------------------------

func _build_attack_info() -> DamageInfo:
	var info := DamageInfo.new()
	# À noite a Mácula fica mais forte (até +15% de dano).
	info.amount = data.attack_damage * damage_scale * (1.0 + 0.15 * GameState.night_factor)
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
	is_aware = true
	info.element_multiplier = Element.multiplier(info.element, element)
	info.amount *= info.element_multiplier
	# Contra-ataque: só o primeiro golpe recebido em cada atordoamento (GDD §6.2).
	if is_stunned() and not _counter_consumed and info.counter_multiplier > 1.0:
		info.amount *= info.counter_multiplier
		info.is_counter = true
		info.is_heavy = true
		_counter_consumed = true
	if is_shocked() and not info.is_power and info.source is Player:
		info.amount *= SHOCK_CRIT_MULTIPLIER
		info.is_critical = true
	if info.shock_time > 0.0:
		apply_shock(info.shock_time)
	last_hit = info
	health.take_damage(info.amount)
	Events.damage_taken.emit(self, info)
	SfxLibrary.play(self, &"hit_heavy" if info.is_heavy else &"hit")
	body.flash(HIT_FLASH_COLOR)
	if health.is_dead:
		state_machine.transition_to(&"Dead")
		died.emit()
		Events.entity_died.emit(self)
	elif info.is_heavy and can_be_staggered():
		_knockback = _away_from(info.source)
		state_machine.transition_to(&"Stagger")


# --- Eletrocutado ------------------------------------------------------------

func is_shocked() -> bool:
	return shock_remaining > 0.0 and not health.is_dead


func apply_shock(duration: float) -> void:
	if health.is_dead:
		return
	shock_remaining = maxf(shock_remaining, duration)


## Esqueleto (espada e escudo de metal) conduz melhor o raio da Corrente em Cadeia.
func is_metal_armored() -> bool:
	return data.model_variant == EnemyData.ModelVariant.SOLDIER


func _update_shock(delta: float) -> void:
	shock_remaining -= delta
	if shock_remaining <= 0.0 or health.is_dead:
		shock_remaining = 0.0
		_model.rotation_degrees = Vector3.ZERO
		return
	# Espasmos: pequenos trancos no corpo e arcos estalando entre partes do corpo.
	_model.rotation_degrees = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * SHOCK_TWITCH_DEGREES
	_shock_arc_timer -= delta
	if _shock_arc_timer <= 0.0 and _model.visible:
		_shock_arc_timer = SHOCK_ARC_INTERVAL
		var points := body.body_points()
		if points.size() >= 2:
			var a: Vector3 = points.pick_random()
			var b: Vector3 = points.pick_random()
			LightningArc.spawn(get_parent(), a, b, SHOCK_COLOR, 0.07, 0.45)
		body.flash(SHOCK_COLOR, 1.2)


## Golpes fortes fazem cambalear quem não tem postura e não está no meio do próprio ataque.
func can_be_staggered() -> bool:
	return not data.has_poise and (state_machine.is_in(&"Idle") or state_machine.is_in(&"Recover"))


func begin_stagger() -> void:
	body.play_action_for(&"stagger", data.stagger_time)


func end_stagger() -> void:
	_knockback = Vector3.ZERO
	set_pose_rest()


func _away_from(source: Node3D) -> Vector3:
	if source == null or not is_instance_valid(source):
		return global_basis.z
	var away := global_position - source.global_position
	away.y = 0.0
	return away.normalized() if away.length_squared() > 0.0001 else global_basis.z


# --- Movimento livre -------------------------------------------------------

func _update_awareness() -> void:
	if not is_aware and target != null and distance_to_target() <= data.aggro_range:
		is_aware = true


## Velocidade desejada conforme o estado: em guarda corre até o herói e depois o circula;
## no aviso corpo a corpo avança se o herói saiu do alcance; cambaleando, é empurrado.
func _desired_velocity(delta: float) -> Vector3:
	if target == null:
		return Vector3.ZERO
	if state_machine.is_in(&"Stagger"):
		return _knockback * data.knockback_speed
	if state_machine.is_in(&"Telegraph") and not is_ranged() and distance_to_target() > data.attack_reach:
		return _flat_direction_to_target() * data.move_speed
	if not state_machine.is_in(&"Idle") or not is_aware:
		return Vector3.ZERO
	return _guard_velocity(delta)


func _guard_velocity(delta: float) -> Vector3:
	var to_target := _flat_direction_to_target()
	var distance := distance_to_target()
	var half_tolerance := data.position_tolerance * 0.5
	var direction := Vector3.ZERO
	var speed := data.strafe_speed
	if distance > data.engage_distance + data.position_tolerance * 2.0:
		direction = to_target
		speed = data.run_speed
	else:
		if distance > data.engage_distance + half_tolerance:
			direction += to_target
		elif distance < data.engage_distance - half_tolerance:
			direction -= to_target
		_strafe_timer -= delta
		if _strafe_timer <= 0.0:
			_strafe_timer = randf_range(data.strafe_switch_min, data.strafe_switch_max)
			_strafe_sign = -_strafe_sign if randf() < 0.6 else _strafe_sign
		direction += Vector3.UP.cross(to_target) * _strafe_sign * 0.8
		direction += _away_from_camera_side(-to_target)
	for node: Node in get_tree().get_nodes_in_group(GROUP):
		var other := node as Enemy
		if other == null or other == self or other.health.is_dead:
			continue
		var away := global_position - other.global_position
		away.y = 0.0
		var gap := away.length()
		if gap > 0.001 and gap < data.separation_radius:
			direction += away / gap * (1.0 - gap / data.separation_radius) * 1.5
	return direction.limit_length(1.0) * speed


func _flat_direction_to_target() -> Vector3:
	var to_target := target.global_position - global_position
	to_target.y = 0.0
	return to_target.normalized() if to_target.length_squared() > 0.0001 else Vector3.ZERO


func _turn_toward_target(delta: float) -> void:
	if target == null or not is_instance_valid(target) or not is_aware:
		return
	var direction := _flat_direction_to_target()
	if direction.is_zero_approx():
		return
	var target_yaw := atan2(-direction.x, -direction.z)
	rotation.y = rotate_toward(rotation.y, target_yaw, data.turn_speed * delta)


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
