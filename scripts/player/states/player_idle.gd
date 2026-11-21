extends PlayerState
## Parado, pronto para agir. Prioridade: parry > poderes (1/2/3) > ataque.
## O ataque depende da distância do alvo: perto = combo; longe = Dardo de Raio
## (se pronto) seguido do Passo Relâmpago (GDD §6.4).


func enter(_msg: Dictionary = {}) -> void:
	player.set_pose_rest()


func physics_update(_delta: float) -> void:
	if player.input_buffer.consume(&"parry"):
		machine.transition_to(&"Parry")
	elif try_start_power():
		return
	elif player.input_buffer.consume(&"attack"):
		var next_state := player.choose_attack_state()
		if next_state == &"Attack":
			machine.transition_to(&"Attack", {"hit_index": player.next_combo_index()})
		else:
			machine.transition_to(next_state)
