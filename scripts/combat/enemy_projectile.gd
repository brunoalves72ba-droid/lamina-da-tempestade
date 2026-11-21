class_name EnemyProjectile
extends Node3D
## Virote do Besteiro (GDD §6.2). Persegue o hurtbox do alvo e acerta exatamente ao fim do voo,
## que coincide com o fim do aviso. Pode ser anulado com parry (não atordoa o atirador).

const AIM_HEIGHT: float = 1.0

var _target: Hurtbox
var _info: DamageInfo
var _start: Vector3 = Vector3.ZERO
var _flight_time: float = 0.35
var _elapsed: float = 0.0
var _done: bool = false


func launch(start: Vector3, target_hurtbox: Hurtbox, info: DamageInfo, flight_time: float) -> void:
	global_position = start
	_start = start
	_target = target_hurtbox
	_info = info
	_info.on_parried = _on_parried
	_flight_time = maxf(flight_time, 0.01)


func _physics_process(delta: float) -> void:
	if _done:
		return
	if _target == null or not is_instance_valid(_target):
		queue_free()
		return
	_elapsed += delta
	var aim := _target.global_position + Vector3.UP * AIM_HEIGHT
	var t := minf(_elapsed / _flight_time, 1.0)
	var next := _start.lerp(aim, t)
	if next.distance_squared_to(global_position) > 0.0001:
		look_at(next, Vector3.UP)
	global_position = next
	if t >= 1.0:
		_done = true
		_target.receive_hit(_info)
		queue_free()


func _on_parried() -> void:
	_done = true
	queue_free()
