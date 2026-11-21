class_name UpgradeShop
extends CanvasLayer
## Loja de upgrades (GDD §10): Espada e Armadura, 5 níveis cada. Salva a cada compra.

signal closed

const MAX_COLOR := Color(0.55, 0.9, 0.55)

@export var upgrades: Array[UpgradeData] = []

var _gold_label: Label
var _rows: VBoxContainer
var _back_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var column := MenuKit.overlay(self)
	column.add_child(MenuKit.label("FERREIRO", 34))
	_gold_label = MenuKit.label("", 22, MenuKit.GOLD_COLOR)
	column.add_child(_gold_label)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 20)
	column.add_child(_rows)
	_back_button = MenuKit.button("Voltar", _close)
	column.add_child(_back_button)
	GameState.gold_changed.connect(_on_state_changed)
	GameState.upgrades_changed.connect(_refresh)
	_refresh()
	_back_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	closed.emit()
	queue_free()


func _on_state_changed(_gold: int) -> void:
	_refresh()


func _refresh() -> void:
	_gold_label.text = "Ouro: %d" % GameState.gold
	for child: Node in _rows.get_children():
		child.queue_free()
	for upgrade: UpgradeData in upgrades:
		_rows.add_child(_build_row(upgrade))


func _build_row(upgrade: UpgradeData) -> Control:
	var level := GameState.level_of(upgrade)
	var row := VBoxContainer.new()
	row.add_child(MenuKit.label("%s — nível %d / %d" % [upgrade.display_name, level, upgrade.max_level()], 22))
	var is_max := level >= upgrade.max_level()
	row.add_child(MenuKit.label(_stat_text(upgrade, level, is_max), 16, MenuKit.MUTED_COLOR))
	var cost := upgrade.cost_for_next(level)
	var button_text := "Nível máximo" if is_max else "Melhorar — %d de ouro" % cost
	var buy_button := MenuKit.button(button_text, _buy.bind(upgrade))
	buy_button.disabled = not GameState.can_buy(upgrade)
	if is_max:
		buy_button.add_theme_color_override(&"font_disabled_color", MAX_COLOR)
	row.add_child(buy_button)
	return row


func _stat_text(upgrade: UpgradeData, level: int, is_max: bool) -> String:
	var now := "%s %d" % [upgrade.stat_label, roundi(upgrade.value_at(level))]
	if upgrade.has_secondary():
		now += " · %s %d%%" % [upgrade.secondary_label, roundi(upgrade.secondary_at(level) * 100.0)]
	if is_max:
		return now
	var next := "%s %d" % [upgrade.stat_label, roundi(upgrade.value_at(level + 1))]
	if upgrade.has_secondary():
		next += " · %s %d%%" % [upgrade.secondary_label, roundi(upgrade.secondary_at(level + 1) * 100.0)]
	return "%s  →  %s" % [now, next]


func _buy(upgrade: UpgradeData) -> void:
	if GameState.try_buy(upgrade):
		SfxLibrary.play(self, &"charge_full")
		SaveManager.save_game()
