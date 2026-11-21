extends PlayerState
## Avançando pelo trilho (GDD §5). O RailController move o herói; inputs de combate são ignorados.


func enter(_msg: Dictionary = {}) -> void:
	player.input_buffer.clear()
	player.input_buffer.enabled = false
	player.targeting.enabled = false
	player.hitbox.disarm()
	player.set_pose_rest()


func exit() -> void:
	player.input_buffer.enabled = true
	player.targeting.enabled = true


func handle_hit(_info: DamageInfo) -> bool:
	return true
