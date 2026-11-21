extends PlayerState
## Lança um poder de raio (GDD §6.5): preparação (parry cancela) → efeito → recuperação.
## A recarga só começa quando o efeito sai.

var _slot: int = 0
var _timer: float = 0.0
var _released: bool = false


func enter(msg: Dictionary = {}) -> void:
	_slot = msg.get("slot", 0)
	_timer = player.powers.power(_slot).cast_time
	_released = false
	player.play_power_cast(player.powers.power(_slot))


func physics_update(delta: float) -> void:
	if not _released and player.input_buffer.consume(&"parry"):
		machine.transition_to(&"Parry")
		return
	_timer -= delta
	if _timer > 0.0:
		return
	if not _released:
		_released = true
		player.powers.execute(_slot)
		_timer = player.powers.power(_slot).recovery_time
		return
	machine.transition_to(&"Idle")
