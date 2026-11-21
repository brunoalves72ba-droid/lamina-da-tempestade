extends PlayerState
## Bloqueio: segurando o botão de defesa depois da janela de parry. Anda devagar e reduz o dano
## (block_reduction) sem cambalear. Soltar volta ao Livre; esquiva também sai do bloqueio.


## O escudo erguido vem da locomoção (block_idle), não de uma ação.
func enter(_msg: Dictionary = {}) -> void:
	player.set_pose_rest()


func physics_update(_delta: float) -> void:
	if not player.is_defend_held():
		machine.transition_to(&"Idle")
		return
	if player.can_dodge() and player.input_buffer.consume(&"dodge"):
		machine.transition_to(&"Dodge")
		return
	player.locomote(player.data.block_move_speed)


func handle_hit(info: DamageInfo) -> bool:
	player.take_blocked_hit(info)
	return true
