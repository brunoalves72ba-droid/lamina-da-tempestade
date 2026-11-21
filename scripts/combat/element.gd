class_name Element
extends RefCounted
## Afinidades elementais e ciclo de vantagem (GDD §7): Divino > Demoníaco > Heroico > Divino.
## Números e cores vêm de data/combat/elements.tres.

enum Type { NONE, DIVINE, DEMONIC, HEROIC }

const TABLE_PATH := "res://data/combat/elements.tres"
const NAMES: Dictionary = {
	Type.NONE: "Neutro",
	Type.DIVINE: "Divino",
	Type.DEMONIC: "Demoníaco",
	Type.HEROIC: "Heroico",
}

static var _table: ElementTable


static func table() -> ElementTable:
	if _table == null:
		_table = load(TABLE_PATH) as ElementTable
	return _table


static func beats(attacker: Type, defender: Type) -> bool:
	return (attacker == Type.DIVINE and defender == Type.DEMONIC) \
			or (attacker == Type.DEMONIC and defender == Type.HEROIC) \
			or (attacker == Type.HEROIC and defender == Type.DIVINE)


static func multiplier(attacker: Type, defender: Type) -> float:
	if attacker == Type.NONE or defender == Type.NONE or attacker == defender:
		return 1.0
	if beats(attacker, defender):
		return table().advantage_multiplier
	return table().disadvantage_multiplier


static func color(element: Type) -> Color:
	match element:
		Type.DIVINE:
			return table().divine_color
		Type.DEMONIC:
			return table().demonic_color
		Type.HEROIC:
			return table().heroic_color
	return table().neutral_color


static func display_name(element: Type) -> String:
	return NAMES.get(element, "?")
