class_name BossBrain
extends Node
## Poderes especiais do chefão (BossData). O Enemy cria este nó quando `data.boss` existe.
## O estado "Power" do inimigo chama begin()/update(); aqui fica a linha do tempo de cada poder:
## aviso no chão + animação → impacto (dano em área, efeitos) → recuperação.
## Também cuida do rugido de entrada (aparece a barra de vida) e da fúria com pouca vida.

enum Phase { WINDUP, AIRBORNE, ACTIVE, RECOVERY, DONE }

const ROAR := -1
const ROAR_TIME: float = 1.4
const PROJECTILE_ORIGIN_HEIGHT: float = 2.0
const RAGE_RIM_INTENSITY: float = 1.4

var enemy: Enemy
var data: BossData
var is_enraged: bool = false

var _cooldown: float = 0.0
var _engaged: bool = false
var _power: int = ROAR
var _phase: Phase = Phase.DONE
var _timer: float = 0.0
var _shots_left: int = 0
var _leap_from: Vector3 = Vector3.ZERO
var _leap_to: Vector3 = Vector3.ZERO
var _leap_elapsed: float = 0.0
var _warning: Node3D
var _next_power_index: int = 0
var _rage_pending: bool = false


func _init(owner_enemy: Enemy, boss_data: BossData) -> void:
	enemy = owner_enemy
	data = boss_data
	name = "BossBrain"
	_cooldown = data.first_power_delay


func reset() -> void:
	_cooldown = data.first_power_delay
	_engaged = false
	is_enraged = false
	_rage_pending = false
	_phase = Phase.DONE
	_clear_warning()


func _physics_process(delta: float) -> void:
	if enemy.health.is_dead:
		return
	if enemy.is_aware and not _engaged and enemy.state_machine.is_in(&"Idle"):
		_engaged = true
		Events.boss_engaged.emit(enemy)
		enemy.state_machine.transition_to(&"Power", {"power": ROAR})
		return
	if _engaged and not enemy.state_machine.is_in(&"Power"):
		_cooldown -= delta
	if not is_enraged and enemy.health.current_health <= enemy.health.max_health * data.rage_health_fraction:
		is_enraged = true
		_rage_pending = true
	if _rage_pending and enemy.state_machine.is_in(&"Idle"):
		_rage_pending = false
		enemy.state_machine.transition_to(&"Power", {"power": ROAR})


## Quando recebe o token de ataque: usa um poder se a recarga acabou (senão, golpe normal).
func wants_power() -> bool:
	return _engaged and _cooldown <= 0.0 and not data.powers.is_empty()


func next_power() -> int:
	var power: int = data.powers[_next_power_index % data.powers.size()]
	_next_power_index += 1
	return power


func is_airborne() -> bool:
	return _phase == Phase.AIRBORNE and enemy.state_machine.is_in(&"Power")


# --- Linha do tempo -------------------------------------------------------------

func begin(power: int) -> void:
	_power = power
	_phase = Phase.WINDUP
	match power:
		ROAR:
			_timer = ROAR_TIME
			enemy.body.play_action_for(&"boss_roar", ROAR_TIME)
			_roar_effects()
		BossData.Power.SLAM:
			_timer = data.slam_windup
			enemy.body.play_action_hit_at(&"boss_slam", data.slam_windup)
			_warning = Vfx.ground_warning(_vfx_parent(), enemy.global_position, data.slam_radius, data.slam_windup)
			SfxLibrary.play(enemy, &"telegraph")
		BossData.Power.LEAP:
			_timer = data.leap_windup
			_leap_from = enemy.global_position
			_leap_to = _landing_point()
			var total := data.leap_windup + data.leap_air_time
			enemy.body.play_action_hit_at(&"boss_leap", total)
			_warning = Vfx.ground_warning(_vfx_parent(), _leap_to, data.leap_radius, total)
			SfxLibrary.play(enemy, &"telegraph")
		BossData.Power.VOLLEY:
			_timer = data.volley_windup
			_shots_left = data.volley_count
			enemy.body.play_action_hit_at(&"boss_volley", data.volley_windup)
			Vfx.charge_crackle(_vfx_parent(), enemy, Vector3.UP * PROJECTILE_ORIGIN_HEIGHT, data.power_color,
					data.volley_windup, 0.8, 6)
			SfxLibrary.play(enemy, &"telegraph")
	if power != ROAR:
		var multiplier := data.rage_cooldown_multiplier if is_enraged else 1.0
		_cooldown = data.power_cooldown * multiplier


## Retorna true quando o poder terminou (o estado vai para Recover).
func update(delta: float) -> bool:
	_timer -= delta
	match _phase:
		Phase.WINDUP:
			if _timer <= 0.0:
				_release()
		Phase.AIRBORNE:
			_update_leap(delta)
		Phase.ACTIVE:
			if _power == BossData.Power.VOLLEY and _timer <= 0.0:
				_fire_orb()
		Phase.RECOVERY:
			if _timer <= 0.0:
				_phase = Phase.DONE
	return _phase == Phase.DONE


## Interrompido (morreu, cambaleou): some com o aviso e devolve o controle do movimento.
func cancel() -> void:
	_clear_warning()
	_phase = Phase.DONE


func _release() -> void:
	match _power:
		ROAR:
			_phase = Phase.DONE
		BossData.Power.SLAM:
			_slam_impact()
			_phase = Phase.RECOVERY
			_timer = data.slam_recovery
		BossData.Power.LEAP:
			_phase = Phase.AIRBORNE
			_leap_elapsed = 0.0
			Vfx.shockwave(_vfx_parent(), enemy.global_position, 2.0, data.power_color.darkened(0.3), 0.3)
			Vfx.sparks(_vfx_parent(), enemy.global_position + Vector3.UP * 0.2, Color(0.45, 0.35, 0.25), 20, 5.0, 0.5)
		BossData.Power.VOLLEY:
			_phase = Phase.ACTIVE
			_timer = 0.0


func _update_leap(delta: float) -> void:
	_leap_elapsed += delta
	var t := minf(_leap_elapsed / data.leap_air_time, 1.0)
	var position := _leap_from.lerp(_leap_to, t)
	position.y += sin(t * PI) * data.leap_height
	enemy.global_position = position
	enemy.velocity = Vector3.ZERO
	if t >= 1.0:
		enemy.global_position = _leap_to
		_area_impact(_leap_to, data.leap_radius, data.leap_damage)
		_phase = Phase.RECOVERY
		_timer = data.leap_recovery


func _slam_impact() -> void:
	_area_impact(enemy.global_position, data.slam_radius, data.slam_damage)


## Impacto em área: onda de choque, poeira, rachadura, tremor; dano se o herói estiver dentro.
func _area_impact(center: Vector3, radius: float, damage: float) -> void:
	_clear_warning()
	var parent := _vfx_parent()
	Vfx.shockwave(parent, center, radius * 1.15, data.power_color, 0.45)
	Vfx.shockwave(parent, center, radius * 0.7, Color(1.0, 0.85, 0.6), 0.3)
	Vfx.sparks(parent, center + Vector3.UP * 0.3, Color(0.5, 0.4, 0.3), 46, 9.0, 0.7, -18.0)
	Vfx.sparks(parent, center + Vector3.UP * 0.3, data.power_color, 30, 7.0, 0.5)
	Vfx.scorch(parent, center, radius * 0.7, data.power_color, 3.0)
	Vfx.flash_light(parent, center + Vector3.UP * 1.5, data.power_color, 5.0, radius * 3.0, 0.3)
	SfxLibrary.play(enemy, &"impact_heavy")
	SfxLibrary.play(enemy, &"thunder")
	Events.shake_requested.emit(0.8)
	var target := enemy.target
	if target == null or not is_instance_valid(target):
		return
	var offset := target.global_position - center
	offset.y = 0.0
	if offset.length() <= radius:
		_hit_target(damage)


func _hit_target(damage: float) -> void:
	var hurtbox := enemy.target.get_node_or_null(^"Hurtbox") as Hurtbox
	if hurtbox == null:
		return
	var info := DamageInfo.new()
	info.amount = damage * enemy.damage_scale
	info.element = enemy.element
	info.is_heavy = true
	info.can_be_parried = false
	info.source = enemy
	hurtbox.receive_hit(info)


func _fire_orb() -> void:
	if _shots_left <= 0:
		_phase = Phase.RECOVERY
		_timer = data.volley_recovery
		return
	_shots_left -= 1
	_timer = data.volley_interval
	var hurtbox := enemy.target.get_node_or_null(^"Hurtbox") as Hurtbox if enemy.target != null else null
	if hurtbox == null or enemy.projectile_scene == null:
		return
	var projectile := EnemyProjectile.spawn(enemy.projectile_scene, _vfx_parent())
	var side := enemy.global_basis.x * randf_range(-0.8, 0.8)
	var origin := enemy.global_position + Vector3.UP * PROJECTILE_ORIGIN_HEIGHT * enemy.data.body_scale + side
	var info := DamageInfo.new()
	info.amount = data.volley_damage * enemy.damage_scale
	info.element = enemy.element
	info.can_be_parried = true
	info.source = enemy
	projectile.set_color(data.power_color)
	projectile.launch(origin, hurtbox, info, data.volley_flight_time)
	SfxLibrary.play(enemy, &"bolt_fire")


func _roar_effects() -> void:
	var parent := _vfx_parent()
	Vfx.shockwave(parent, enemy.global_position, 6.0, data.power_color, 0.8)
	Vfx.sparks(parent, enemy.global_position + Vector3.UP * 0.2, Color(0.45, 0.35, 0.25), 30, 6.0, 0.6)
	Events.shake_requested.emit(0.5)
	SfxLibrary.play(enemy, &"roar")
	if is_enraged:
		enemy.body.set_rim(data.power_color, RAGE_RIM_INTENSITY)


## Onde o salto cai: na posição do herói, limitado à distância máxima.
func _landing_point() -> Vector3:
	var target := enemy.target
	if target == null:
		return enemy.global_position
	var offset := target.global_position - enemy.global_position
	offset.y = 0.0
	if offset.length() > data.leap_max_distance:
		offset = offset.normalized() * data.leap_max_distance
	var landing := enemy.global_position + offset
	landing.y = target.global_position.y
	return landing


func _clear_warning() -> void:
	if _warning != null and is_instance_valid(_warning):
		Pools.release(_warning)
	_warning = null


func _vfx_parent() -> Node:
	return enemy.get_parent()
