extends EnemyState
## Poder de chefão (BossBrain): aviso no chão → impacto → recuperação. msg "power" = BossData.Power
## (ou BossBrain.ROAR). Ao terminar vai para Recover, que devolve o token de ataque.


func enter(msg: Dictionary = {}) -> void:
	enemy.telegraph.stop()
	enemy.boss_brain.begin(msg.get("power", BossBrain.ROAR))


func exit() -> void:
	enemy.boss_brain.cancel()


func physics_update(delta: float) -> void:
	if enemy.boss_brain.update(delta):
		machine.transition_to(&"Recover")
