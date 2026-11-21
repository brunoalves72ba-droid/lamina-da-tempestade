class_name HealthComponent
extends Node
## Vida de uma entidade. Quem é dono decide redução de dano antes de chamar take_damage().

signal health_changed(current: float, maximum: float)
signal died

@export var max_health: float = 100.0

var current_health: float = 0.0
var is_dead: bool:
	get:
		return current_health <= 0.0


func reset(new_max_health: float) -> void:
	max_health = new_max_health
	current_health = max_health
	health_changed.emit(current_health, max_health)


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current_health = minf(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)


## Retorna o dano efetivamente aplicado.
func take_damage(amount: float) -> float:
	if is_dead or amount <= 0.0:
		return 0.0
	var applied := minf(amount, current_health)
	current_health -= applied
	health_changed.emit(current_health, max_health)
	if is_dead:
		died.emit()
	return applied
