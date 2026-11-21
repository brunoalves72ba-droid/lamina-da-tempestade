class_name UpgradeShop
extends CanvasLayer
## Loja unificada (GDD §10): o Ferreiro e Mestre Arcano. Num lugar só o herói compra e equipa
## espadas, melhora a lâmina e a armadura, e evolui os poderes de raio. Preços mudam com a
## reputação na Guilda dos Mercadores. Salva a cada compra/troca. Abre no menu principal, na tela de
## resultado e nas fogueiras acesas (tecla E).

signal closed

const MAX_COLOR := Color(0.55, 0.9, 0.55)
const EQUIPPED_COLOR := Color(0.6, 0.88, 1.0)
const POWER_UPGRADES: Array[String] = [
	"res://data/upgrades/power_voltaic.tres", "res://data/upgrades/power_chain.tres", "res://data/upgrades/power_storm.tres",
]
const TAB_NAMES: Array[String] = ["Espadas", "Equipamento", "Poderes"]

@export var upgrades: Array[UpgradeData] = []

var _gold_label: Label
var _price_label: Label
var _tabs: TabContainer
var _pages: Array[VBoxContainer] = []
var _back_button: Button
var _power_upgrades: Array[UpgradeData] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for path: String in POWER_UPGRADES:
		_power_upgrades.append(load(path) as UpgradeData)
	var column := MenuKit.overlay(self)
	column.add_child(MenuKit.label("FERREIRO E MESTRE ARCANO", 32))
	_gold_label = MenuKit.label("", 22, MenuKit.GOLD_COLOR)
	column.add_child(_gold_label)
	_price_label = MenuKit.label("", 14, MenuKit.MUTED_COLOR)
	column.add_child(_price_label)
	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(620, 420)
	column.add_child(_tabs)
	for tab_name: String in TAB_NAMES:
		var scroll := ScrollContainer.new()
		scroll.name = tab_name
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_tabs.add_child(scroll)
		var page := VBoxContainer.new()
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.add_theme_constant_override(&"separation", 16)
		scroll.add_child(page)
		_pages.append(page)
	_back_button = MenuKit.button("Voltar", _close)
	column.add_child(_back_button)
	GameState.gold_changed.connect(_on_state_changed)
	GameState.upgrades_changed.connect(_refresh)
	GameState.inventory_changed.connect(_refresh)
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
	var multiplier := GameState.price_multiplier()
	_price_label.text = "Preços %s (reputação com a Guilda: %d)" % [
			"normais" if is_equal_approx(multiplier, 1.0) else ("%+d%%" % roundi((multiplier - 1.0) * 100.0)),
			GameState.reputation_of(&"guilda_mercadores")]
	for page: VBoxContainer in _pages:
		for child: Node in page.get_children():
			child.queue_free()
	for item: SwordItem in SwordItem.all():
		_pages[0].add_child(_sword_row(item))
	for upgrade: UpgradeData in upgrades:
		_pages[1].add_child(_upgrade_row(upgrade))
	for upgrade: UpgradeData in _power_upgrades:
		_pages[2].add_child(_upgrade_row(upgrade))


# --- Espadas -----------------------------------------------------------------------

func _sword_row(item: SwordItem) -> Control:
	var row := VBoxContainer.new()
	var owned := GameState.owns_sword(item.id)
	var equipped := GameState.equipped_sword == item.id
	var title := "%s — ATK %d" % [item.display_name, roundi(item.attack)]
	row.add_child(MenuKit.label(title, 22, EQUIPPED_COLOR if equipped else Color.WHITE))
	row.add_child(MenuKit.label(item.description, 15, MenuKit.MUTED_COLOR))
	var button: Button
	if equipped:
		button = MenuKit.button("Equipada", func() -> void: pass)
		button.disabled = true
		button.add_theme_color_override(&"font_disabled_color", EQUIPPED_COLOR)
	elif owned:
		button = MenuKit.button("Equipar", _equip.bind(item))
	elif item.price > 0:
		var price := sword_price(item)
		button = MenuKit.button("Comprar — %d de ouro" % price, _buy_sword.bind(item))
		button.disabled = GameState.gold < price
	else:
		button = MenuKit.button("Derrote um chefão para obter", func() -> void: pass)
		button.disabled = true
	row.add_child(button)
	return row


static func sword_price(item: SwordItem) -> int:
	return roundi(item.price * GameState.price_multiplier())


func _buy_sword(item: SwordItem) -> void:
	var price := sword_price(item)
	if GameState.gold < price or GameState.owns_sword(item.id):
		return
	GameState.gold -= price
	GameState.gold_changed.emit(GameState.gold)
	GameState.grant_sword(item.id)
	GameState.equip_sword(item.id)
	SfxLibrary.play(self, &"coins")
	SaveManager.save_game()


func _equip(item: SwordItem) -> void:
	GameState.equip_sword(item.id)
	SfxLibrary.play(self, &"parry")
	SaveManager.save_game()


# --- Melhorias (lâmina, armadura, poderes) ------------------------------------------

func _upgrade_row(upgrade: UpgradeData) -> Control:
	var level := GameState.level_of(upgrade)
	var row := VBoxContainer.new()
	row.add_child(MenuKit.label("%s — nível %d / %d" % [upgrade.display_name, level, upgrade.max_level()], 22))
	var is_max := level >= upgrade.max_level()
	row.add_child(MenuKit.label(_stat_text(upgrade, level, is_max), 16, MenuKit.MUTED_COLOR))
	var cost := GameState.price_of(upgrade)
	var button_text := "Nível máximo" if is_max else "Melhorar — %d de ouro" % cost
	var buy_button := MenuKit.button(button_text, _buy.bind(upgrade))
	buy_button.disabled = not GameState.can_buy(upgrade)
	if is_max:
		buy_button.add_theme_color_override(&"font_disabled_color", MAX_COLOR)
	row.add_child(buy_button)
	return row


func _stat_text(upgrade: UpgradeData, level: int, is_max: bool) -> String:
	var now := _describe(upgrade, level)
	return now if is_max else "%s  →  %s" % [now, _describe(upgrade, level + 1)]


func _describe(upgrade: UpgradeData, level: int) -> String:
	if String(upgrade.id).begins_with("power_"):
		return "Dano ×%.2f · Recarga ×%.2f" % [upgrade.value_at(level), upgrade.secondary_at(level)]
	var text := "%s %d" % [upgrade.stat_label, roundi(upgrade.value_at(level))]
	if upgrade.has_secondary():
		text += " · %s %d%%" % [upgrade.secondary_label, roundi(upgrade.secondary_at(level) * 100.0)]
	return text


func _buy(upgrade: UpgradeData) -> void:
	if GameState.try_buy(upgrade):
		SfxLibrary.play(self, &"charge_full")
		SaveManager.save_game()
