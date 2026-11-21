extends EnemyState
## Em guarda: se posiciona (Enemy._update_guard_movement) e espera o token de ataque.


func enter(_msg: Dictionary = {}) -> void:
	enemy.set_pose_rest()
