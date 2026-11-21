class_name Hurtbox
extends Area3D
## Área que recebe golpes. Só repassa o DamageInfo; o dono decide (parry, dano, contra-ataque).

signal hit_received(info: DamageInfo)

var invulnerable: bool = false


func _ready() -> void:
	monitoring = false
	monitorable = true


func receive_hit(info: DamageInfo) -> void:
	if invulnerable:
		return
	hit_received.emit(info)
