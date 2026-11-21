class_name StaticCharge
extends Node
## Carga Estática (GDD §6.6): sobe jogando bem (golpes, parry, contra-ataque, poderes),
## cai ao tomar dano e é consumida inteira pela Fúria da Tempestade.

signal changed(value: float, maximum: float)
signal filled

@export var maximum: float = 100.0

var value: float = 0.0
var is_full: bool:
	get:
		return value >= maximum


func add(amount: float) -> void:
	if amount <= 0.0:
		return
	var was_full := is_full
	value = minf(maximum, value + amount)
	changed.emit(value, maximum)
	if is_full and not was_full:
		filled.emit()


func remove(amount: float) -> void:
	if amount <= 0.0 or value <= 0.0:
		return
	value = maxf(0.0, value - amount)
	changed.emit(value, maximum)


func consume_all() -> void:
	value = 0.0
	changed.emit(value, maximum)
