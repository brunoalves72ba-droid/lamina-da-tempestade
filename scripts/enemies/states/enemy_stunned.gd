extends EnemyState
## Atordoado pela Descarga do parry (GDD §6.2). Não ataca; o primeiro golpe recebido é contra-ataque.
## Ao terminar, devolve o token de ataque.

var _timer: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	_timer = enemy.data.stun_time
	enemy.begin_stun()


func exit() -> void:
	enemy.end_stun()


func physics_update(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		machine.transition_to(&"Idle")
		enemy.finish_attack()
