extends EnemyState
## Impacto: hitbox armada por data.strike_active_time. Se for aparado, vai para Stunned.
## Elite (strikes_per_attack > 1): emenda outro aviso + golpe em vez de recuperar.

var _timer: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	_timer = enemy.data.strike_active_time
	enemy.begin_strike()


func exit() -> void:
	enemy.end_strike()


func physics_update(delta: float) -> void:
	if enemy.strike_was_parried:
		machine.transition_to(&"Stunned")
		return
	_timer -= delta
	if _timer > 0.0:
		return
	if enemy.take_followup_strike():
		machine.transition_to(&"Telegraph")
	else:
		machine.transition_to(&"Recover")
