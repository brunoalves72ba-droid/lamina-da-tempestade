extends PlayerState
## Livre: anda/corre com WASD (relativo à câmera). Prioridade das ações:
## esquiva > parry > poderes (1/2/3) > ataque. O ataque depende da distância do alvo travado:
## perto = combo; longe = Dardo de Raio (se pronto) seguido do Passo Relâmpago (GDD §6.4).


func enter(_msg: Dictionary = {}) -> void:
	player.set_pose_rest()


func physics_update(_delta: float) -> void:
	if player.can_dodge() and player.input_buffer.consume(&"dodge"):
		machine.transition_to(&"Dodge")
	elif player.input_buffer.consume(&"parry"):
		machine.transition_to(&"Parry")
	elif try_start_power():
		return
	elif player.input_buffer.consume(&"attack"):
		var next_state := player.choose_attack_state()
		if next_state == &"Attack":
			machine.transition_to(&"Attack", {"hit_index": player.next_combo_index()})
		else:
			machine.transition_to(next_state)
	else:
		player.locomote(player.data.sprint_speed if player.wants_to_sprint() else player.data.move_speed)
