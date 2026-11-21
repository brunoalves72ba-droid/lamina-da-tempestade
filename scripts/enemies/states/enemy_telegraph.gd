extends EnemyState
## Aviso de ataque: dura data.telegraph_time e termina no impacto (estado Strike).
## Besteiro: dispara o virote faltando projectile_flight_time, para ele chegar junto com o fim do aviso.

var _timer: float = 0.0
var _launched: bool = false


func enter(_msg: Dictionary = {}) -> void:
	_timer = enemy.telegraph_duration()
	_launched = false
	enemy.begin_telegraph()


func exit() -> void:
	enemy.telegraph.stop()


func physics_update(delta: float) -> void:
	_timer -= delta
	if enemy.is_ranged() and not _launched and _timer <= enemy.data.projectile_flight_time:
		_launched = true
		enemy.launch_projectile()
	if _timer <= 0.0:
		machine.transition_to(&"Strike")
