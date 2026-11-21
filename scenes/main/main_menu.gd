class_name MainMenu
extends Control
## Menu principal (GDD §11): Jogar, Ferreiro (loja) e Sair, com o progresso salvo à vista.

## Título provisório (GDD §14): trocar quando o nome do jogo for decidido.
const GAME_TITLE := "Lâmina da Tempestade"
const SUBTITLE := "título provisório"

@export var shop_scene: PackedScene
@export var sword_upgrade: UpgradeData
@export var armor_upgrade: UpgradeData

var _progress_label: Label
var _play_button: Button


func _ready() -> void:
	Hitstop.reset()
	get_tree().paused = false
	var background := ColorRect.new()
	background.color = Color(0.03, 0.035, 0.05)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", MenuKit.SPACING)
	center.add_child(column)
	column.add_child(MenuKit.label(GAME_TITLE, 54, Color(0.7, 0.88, 1.0)))
	column.add_child(MenuKit.label(SUBTITLE, 14, MenuKit.MUTED_COLOR))
	_progress_label = MenuKit.label("", 18, MenuKit.GOLD_COLOR)
	column.add_child(_progress_label)
	_play_button = MenuKit.button("Jogar", func() -> void: Scenes.go(get_tree(), Scenes.ARENA))
	column.add_child(_play_button)
	column.add_child(MenuKit.button("Ferreiro (loja)", _open_shop))
	column.add_child(MenuKit.button("Sair", func() -> void: get_tree().quit()))
	_refresh_progress()
	_play_button.grab_focus()


func _open_shop() -> void:
	var shop := shop_scene.instantiate() as UpgradeShop
	add_child(shop)
	shop.closed.connect(func() -> void:
		_refresh_progress()
		_play_button.grab_focus())


func _refresh_progress() -> void:
	var text := "Ouro: %d" % GameState.gold
	if sword_upgrade != null and armor_upgrade != null:
		text += "   ·   Espada nv %d   ·   Armadura nv %d" % [GameState.level_of(sword_upgrade), GameState.level_of(armor_upgrade)]
	_progress_label.text = text
