extends PlayerState
## Herói caído. Ignora golpes e inputs até reset_state().


func enter(_msg: Dictionary = {}) -> void:
	player.input_buffer.clear()
	player.input_buffer.enabled = false
	player.play_death()


func exit() -> void:
	player.input_buffer.enabled = true


func handle_hit(_info: DamageInfo) -> bool:
	return true
