class_name UpgradeData
extends Resource
## Um upgrade linear da loja (GDD §10). Valores em data/upgrades/*.tres.

@export var id: StringName = &"sword"
@export var display_name: String = "Espada"
@export var stat_label: String = "ATK"
## Custo para subir do nível i para i+1. O tamanho define o nível máximo.
@export var costs: Array[int] = [50, 100, 175, 275, 400]
## Valor principal em cada nível (0..máximo).
@export var values: Array[float] = []
## Valor secundário opcional (armadura: redução de dano, 0..1).
@export var secondary_label: String = ""
@export var secondary_values: Array[float] = []


func max_level() -> int:
	return costs.size()


## Custo do próximo nível, ou -1 se já está no máximo.
func cost_for_next(level: int) -> int:
	return costs[level] if level < max_level() else -1


func value_at(level: int) -> float:
	return values[clampi(level, 0, values.size() - 1)]


func has_secondary() -> bool:
	return not secondary_values.is_empty()


func secondary_at(level: int) -> float:
	if not has_secondary():
		return 0.0
	return secondary_values[clampi(level, 0, secondary_values.size() - 1)]
