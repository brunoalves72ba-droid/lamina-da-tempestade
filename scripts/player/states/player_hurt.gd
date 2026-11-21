extends PlayerState
## Atingido: cambaleia para trás (empurrão que desacelera) e fica hurt_time sem agir.
## Inputs feitos aqui ficam no buffer.

var _timer: float = 0.0
var _knockback: Vector3 = Vector3.ZERO


func enter(msg: Dictionary = {}) -> void:
	_timer = player.data.hurt_time
	_knockback = msg.get("knockback", Vector3.ZERO)
	player.play_hurt()


func physics_update(delta: float) -> void:
	var t := 1.0 - clampf(_timer / player.data.hurt_time, 0.0, 1.0)
	player.push(_knockback * player.data.hurt_knockback_speed * (1.0 - t))
	_timer -= delta
	if _timer <= 0.0:
		machine.transition_to(&"Idle")
