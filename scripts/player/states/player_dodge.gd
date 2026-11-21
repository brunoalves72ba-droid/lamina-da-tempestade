extends PlayerState
## Esquiva (rolamento): desloca dodge_distance na direção da entrada (ou para trás, sem entrada),
## com invencibilidade no começo. Velocidade decrescente para parecer um impulso.

var _direction: Vector3 = Vector3.ZERO
var _elapsed: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	_direction = player.move_direction()
	if _direction.length_squared() < 0.01:
		_direction = -player.forward()
	_direction = _direction.normalized()
	_elapsed = 0.0
	player.hurtbox.invulnerable = true
	player.hitbox.disarm()
	player.play_dodge(_direction, player.data.dodge_duration)


func exit() -> void:
	player.hurtbox.invulnerable = false
	player.mark_dodge_finished()
	player.end_dodge()


func physics_update(delta: float) -> void:
	_elapsed += delta
	var t := minf(_elapsed / player.data.dodge_duration, 1.0)
	# Integral de (2 * d / T) * (1 - t) em [0, T] = d: percorre exatamente dodge_distance.
	var speed := 2.0 * player.data.dodge_distance / player.data.dodge_duration * (1.0 - t)
	player.push(_direction * speed)
	if _elapsed >= player.data.dodge_invulnerable_time:
		player.hurtbox.invulnerable = false
	if t >= 1.0:
		machine.transition_to(&"Idle")


func handle_hit(_info: DamageInfo) -> bool:
	return player.hurtbox.invulnerable
