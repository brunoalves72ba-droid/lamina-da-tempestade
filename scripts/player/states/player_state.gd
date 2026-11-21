class_name PlayerState
extends State
## Base dos estados do herói.

const SKILL_ACTIONS: Array[StringName] = [&"skill_1", &"skill_2", &"skill_3"]

var player: Player


func _ready() -> void:
	player = owner as Player
	assert(player != null, "PlayerState precisa estar dentro de player.tscn")


## Retorna true se o estado tratou o golpe sozinho (ex.: parry); senão o herói toma dano.
func handle_hit(_info: DamageInfo) -> bool:
	return false


## Se uma tecla de poder (1/2/3) está no buffer, tenta lançar. Retorna true se trocou de estado.
func try_start_power() -> bool:
	for slot: int in mini(SKILL_ACTIONS.size(), player.powers.count()):
		if not player.input_buffer.consume(SKILL_ACTIONS[slot]):
			continue
		var transition := player.power_transition(slot)
		if transition.is_empty():
			continue
		machine.transition_to(transition["state"], transition["msg"])
		return true
	return false
