extends EnemyState
## Entrada em cena (GDD §5): cresce do chão, sem atacar nem receber dano.

var _timer: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	_timer = enemy.data.spawn_time
	enemy.play_spawn()


func exit() -> void:
	enemy.end_spawn()


func physics_update(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		machine.transition_to(&"Idle")
