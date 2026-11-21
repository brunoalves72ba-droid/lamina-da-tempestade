extends EnemyState
## Guarda erguida (inimigos com escudo, GDD §8.3): golpes leves de espada causam 25% do dano;
## golpe forte quebra a guarda. Ao baixar a guarda pode contra-atacar na hora.

const BLOCK_TIME: float = 0.8

var _timer: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	_timer = BLOCK_TIME
	enemy.begin_block()


func exit() -> void:
	enemy.end_block()


func physics_update(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	if not enemy.try_counter_attack():
		machine.transition_to(&"Idle")
