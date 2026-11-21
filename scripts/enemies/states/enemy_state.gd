class_name EnemyState
extends State
## Base dos estados de inimigo.

var enemy: Enemy


func _ready() -> void:
	enemy = owner as Enemy
	assert(enemy != null, "EnemyState precisa estar dentro de uma cena de Enemy")
