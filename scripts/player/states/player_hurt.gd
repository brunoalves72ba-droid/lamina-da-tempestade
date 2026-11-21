extends PlayerState
## Atordoamento curto ao tomar dano. Inputs feitos aqui ficam no buffer.

var _timer: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	_timer = player.data.hurt_time
	player.set_pose_rest()


func physics_update(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		machine.transition_to(&"Idle")
