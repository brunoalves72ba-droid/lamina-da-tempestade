class_name ResultScreen
extends CanvasLayer
## Tela de resultado (GDD §4): ouro coletado, bônus ou regra de morte, total. Loja, jogar de novo ou menu.

signal replay_requested

const VICTORY_COLOR := Color(0.95, 0.9, 0.7)
const DEFEAT_COLOR := Color(1.0, 0.4, 0.35)

@export var shop_scene: PackedScene

var _total_label: Label
var _first_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20


func show_result(victory: bool, collected: int, earned: int, victory_title: String = "ARENA CONCLUÍDA") -> void:
	var column := MenuKit.overlay(self)
	column.add_child(MenuKit.label(victory_title if victory else "VOCÊ CAIU", 36,
			VICTORY_COLOR if victory else DEFEAT_COLOR))
	column.add_child(MenuKit.label("Ouro coletado: %d" % collected, 18, MenuKit.MUTED_COLOR))
	if victory:
		column.add_child(MenuKit.label("Bônus de conclusão: +%d" % (earned - collected), 18, MenuKit.MUTED_COLOR))
	else:
		column.add_child(MenuKit.label("Na derrota você mantém %d de %d" % [earned, collected], 18, MenuKit.MUTED_COLOR))
	column.add_child(MenuKit.label("Ouro ganho: +%d" % earned, 24, MenuKit.GOLD_COLOR))
	_total_label = MenuKit.label("", 18)
	column.add_child(_total_label)
	_first_button = MenuKit.button("Ferreiro (loja)", _open_shop)
	column.add_child(_first_button)
	column.add_child(MenuKit.button("Jogar de novo", func() -> void: replay_requested.emit()))
	column.add_child(MenuKit.button("Menu principal", func() -> void: Scenes.go(get_tree(), Scenes.MAIN_MENU)))
	_refresh_total()
	_first_button.grab_focus()


func _open_shop() -> void:
	if shop_scene == null:
		return
	var shop := shop_scene.instantiate() as UpgradeShop
	add_child(shop)
	shop.closed.connect(_on_shop_closed)


func _on_shop_closed() -> void:
	_refresh_total()
	_first_button.grab_focus()


func _refresh_total() -> void:
	_total_label.text = "Ouro total: %d" % GameState.gold
