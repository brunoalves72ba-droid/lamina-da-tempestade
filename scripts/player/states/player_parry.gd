extends PlayerState
## Parry (GDD §6.2): janela ativa curta; se um golpe chegar nela, vira Descarga.
## Se a janela fechar com o botão ainda segurado, vira Bloqueio. Se fechar com o botão solto,
## o herói fica em recuperação sem poder defender (anti-spam).

enum Phase { ACTIVE, RECOVERY }

var _phase: Phase = Phase.ACTIVE
var _timer: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	_phase = Phase.ACTIVE
	_timer = player.data.parry_window
	player.input_buffer.clear(&"parry")
	player.set_pose_guard()


func physics_update(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	if _phase == Phase.ACTIVE:
		if player.is_defend_held():
			machine.transition_to(&"Block")
			return
		_phase = Phase.RECOVERY
		_timer = player.data.parry_recovery
		player.set_pose_whiff()
	else:
		# Apertos de parry durante a recuperação não valem.
		player.input_buffer.clear(&"parry")
		machine.transition_to(&"Idle")


func handle_hit(info: DamageInfo) -> bool:
	if _phase != Phase.ACTIVE or not info.can_be_parried:
		return false
	player.resolve_parry(info)
	machine.transition_to(&"Idle")
	return true
