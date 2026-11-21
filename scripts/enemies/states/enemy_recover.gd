extends EnemyState
## Recuperação após um golpe que não foi aparado. Ao terminar, devolve o token de ataque.

var _timer: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	_timer = enemy.data.recover_time
	enemy.set_pose_rest(enemy.data.recover_time)


func physics_update(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		machine.transition_to(&"Idle")
		enemy.finish_attack()
