extends EnemyState
## Derrotado. Fica parado até reset_state().


func enter(_msg: Dictionary = {}) -> void:
	enemy.play_death()
