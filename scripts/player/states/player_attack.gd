extends PlayerState
## Um golpe do combo: preparação → ativo (hitbox armada) → recuperação (janela para encadear).
## Na preparação o herói avança um pouco (se o alvo não estiver colado).
## Parry interrompe em qualquer fase; esquiva cancela a recuperação (GDD §6.1).

enum Phase { WINDUP, ACTIVE, RECOVERY }

var _phase: Phase = Phase.WINDUP
var _timer: float = 0.0
var _hit_index: int = 0
var _lunge: bool = false


func enter(msg: Dictionary = {}) -> void:
	_hit_index = msg.get("hit_index", 0)
	_phase = Phase.WINDUP
	_timer = player.weapon.hit_windup
	_lunge = player.target == null or player.distance_to_target() > player.data.lunge_min_target_distance
	player.begin_swing(_hit_index)


func exit() -> void:
	player.hitbox.disarm()


func physics_update(delta: float) -> void:
	if player.input_buffer.consume(&"parry"):
		machine.transition_to(&"Parry")
		return
	_timer -= delta
	match _phase:
		Phase.WINDUP:
			_apply_lunge()
			if _timer <= 0.0:
				_phase = Phase.ACTIVE
				_timer = player.weapon.hit_active
				player.hitbox.arm(player.build_attack_info(_hit_index))
		Phase.ACTIVE:
			_apply_lunge()
			if _timer <= 0.0:
				player.hitbox.disarm()
				player.mark_hit_finished(_hit_index)
				_phase = Phase.RECOVERY
				_timer = player.recovery_time(_hit_index)
		Phase.RECOVERY:
			if player.can_dodge() and player.input_buffer.consume(&"dodge"):
				machine.transition_to(&"Dodge")
			elif try_start_power():
				return
			elif player.can_chain(_hit_index) and player.input_buffer.consume(&"attack"):
				machine.transition_to(&"Attack", {"hit_index": _hit_index + 1})
			elif _timer <= 0.0:
				machine.transition_to(&"Idle")


func _apply_lunge() -> void:
	if not _lunge:
		return
	var duration := player.weapon.hit_windup + player.weapon.hit_active
	player.push(player.forward() * player.data.attack_lunge_distance / duration)
