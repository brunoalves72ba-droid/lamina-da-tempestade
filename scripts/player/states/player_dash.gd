extends PlayerState
## Passo Relâmpago (GDD §6.4): avanço rápido até perto do alvo. Termina no 1º golpe do combo
## ou, se veio de um poder corpo a corpo (msg "then_power"), lança esse poder.

var _from: Vector3 = Vector3.ZERO
var _to: Vector3 = Vector3.ZERO
var _elapsed: float = 0.0
var _then_power: int = -1


func enter(msg: Dictionary = {}) -> void:
	_from = player.global_position
	_to = player.dash_destination()
	_elapsed = 0.0
	_then_power = msg.get("then_power", -1)
	player.begin_dash(_from, _to)


func physics_update(delta: float) -> void:
	_elapsed += delta
	var t := minf(_elapsed / player.data.dash_duration, 1.0)
	var eased := 1.0 - pow(1.0 - t, 2.0)
	player.global_position = _from.lerp(_to, eased)
	if t < 1.0:
		return
	player.end_dash()
	if player.target == null or not player.is_target_in_melee_range():
		machine.transition_to(&"Idle")
	elif _then_power >= 0:
		machine.transition_to(&"Power", {"slot": _then_power})
	else:
		machine.transition_to(&"Attack", {"hit_index": 0})
