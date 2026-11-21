extends PlayerState
## Dardo de Raio (GDD §6.4): raio instantâneo no alvo distante; depois faz o Passo Relâmpago.

var _timer: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	_timer = player.data.bolt_cast_time
	player.set_pose_cast()
	player.fire_bolt()


func physics_update(delta: float) -> void:
	if player.input_buffer.consume(&"parry"):
		machine.transition_to(&"Parry")
		return
	_timer -= delta
	if _timer > 0.0:
		return
	if player.target != null and not player.is_target_in_melee_range():
		machine.transition_to(&"Dash")
	else:
		machine.transition_to(&"Idle")
