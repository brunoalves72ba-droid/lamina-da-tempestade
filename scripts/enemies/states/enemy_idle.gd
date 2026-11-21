extends EnemyState
## Em guarda: corre até o herói, depois o circula (Enemy._guard_velocity) e espera o token de ataque.


func enter(_msg: Dictionary = {}) -> void:
	enemy.set_pose_rest()
