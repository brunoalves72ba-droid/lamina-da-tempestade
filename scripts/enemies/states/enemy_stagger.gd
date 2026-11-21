extends EnemyState
## Cambaleando após um golpe forte: é empurrado para trás e não ataca por stagger_time.
## Se tinha o token de ataque, devolve ao terminar.

var _timer: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	_timer = enemy.data.stagger_time
	enemy.begin_stagger()


func exit() -> void:
	enemy.end_stagger()


func physics_update(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		machine.transition_to(&"Idle")
		enemy.finish_attack()
