extends Node
## Estado da campanha (autoload "GameState"): ouro, níveis de upgrade e elemento escolhido.
## O SaveManager grava/carrega este estado em JSON (GDD §11).

signal gold_changed(gold: int)
signal upgrades_changed

var gold: int = 0
var sword_element: Element.Type = Element.Type.NONE

var _upgrade_levels: Dictionary[StringName, int] = {}


func reset() -> void:
	gold = 0
	sword_element = Element.Type.NONE
	_upgrade_levels.clear()
	gold_changed.emit(gold)
	upgrades_changed.emit()


func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	gold_changed.emit(gold)


func level_of(upgrade: UpgradeData) -> int:
	return _upgrade_levels.get(upgrade.id, 0)


func can_buy(upgrade: UpgradeData) -> bool:
	var cost := upgrade.cost_for_next(level_of(upgrade))
	return cost >= 0 and gold >= cost


## Compra o próximo nível se houver ouro. Retorna true se comprou.
func try_buy(upgrade: UpgradeData) -> bool:
	if not can_buy(upgrade):
		return false
	gold -= upgrade.cost_for_next(level_of(upgrade))
	_upgrade_levels[upgrade.id] = level_of(upgrade) + 1
	gold_changed.emit(gold)
	upgrades_changed.emit()
	return true


func to_dict() -> Dictionary:
	var levels := {}
	for id: StringName in _upgrade_levels:
		levels[String(id)] = _upgrade_levels[id]
	return {"gold": gold, "sword_element": int(sword_element), "upgrades": levels}


func from_dict(data: Dictionary) -> void:
	gold = int(data.get("gold", 0))
	sword_element = int(data.get("sword_element", 0)) as Element.Type
	_upgrade_levels.clear()
	var levels: Dictionary = data.get("upgrades", {})
	for id: String in levels:
		_upgrade_levels[StringName(id)] = int(levels[id])
	gold_changed.emit(gold)
	upgrades_changed.emit()
