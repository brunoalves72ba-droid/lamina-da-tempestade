extends Node
## Estado da campanha (autoload "GameState"): ouro, níveis de upgrade e elemento escolhido.
## O SaveManager grava/carrega este estado em JSON (GDD §11).

signal gold_changed(gold: int)
signal upgrades_changed
signal xp_changed(xp: int, xp_needed: int, level: int)
signal leveled_up(level: int)

const PROGRESSION_PATH := "res://data/progression/progression.tres"

var gold: int = 0
var sword_element: Element.Type = Element.Type.NONE
## Nível e experiência do herói (persistem entre partidas).
var level: int = 1
var xp: int = 0
## Qualidade gráfica escolhida (GraphicsSettings.Quality).
var graphics_quality: int = 1
var progression: ProgressionData = preload(PROGRESSION_PATH)

var _upgrade_levels: Dictionary[StringName, int] = {}


func _ready() -> void:
	graphics_quality = default_graphics_quality()


## Primeira vez (sem save): GPU integrada começa no Baixo; dedicada no Médio.
static func default_graphics_quality() -> int:
	return GraphicsSettings.Quality.LOW if is_integrated_gpu() else GraphicsSettings.Quality.MEDIUM


## O driver D3D12 do Godot informa algumas GPUs integradas (ex.: Intel Iris Xe) como dedicadas,
## então o nome também conta: Intel que não seja Arc, ou AMD "Radeon Graphics" sem "RX".
static func is_integrated_gpu() -> bool:
	if RenderingServer.get_video_adapter_type() == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU:
		return true
	var adapter_name := RenderingServer.get_video_adapter_name().to_lower()
	if adapter_name.contains("intel") and not adapter_name.contains("arc"):
		return true
	return adapter_name.contains("radeon") and adapter_name.ends_with("graphics") and not adapter_name.contains("rx")


func reset() -> void:
	gold = 0
	sword_element = Element.Type.NONE
	level = 1
	xp = 0
	_upgrade_levels.clear()
	gold_changed.emit(gold)
	upgrades_changed.emit()
	xp_changed.emit(xp, xp_needed(), level)


func xp_needed() -> int:
	return progression.xp_to_next(level)


## Soma XP e sobe de nível quantas vezes couber. Retorna quantos níveis subiu.
func add_xp(amount: int) -> int:
	if amount <= 0 or level >= progression.max_level:
		return 0
	xp += amount
	var gained := 0
	while level < progression.max_level and xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		gained += 1
		leveled_up.emit(level)
	if level >= progression.max_level:
		xp = 0
	xp_changed.emit(xp, xp_needed(), level)
	return gained


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
	return {"gold": gold, "sword_element": int(sword_element), "upgrades": levels,
			"level": level, "xp": xp, "graphics_quality": graphics_quality}


func from_dict(data: Dictionary) -> void:
	gold = int(data.get("gold", 0))
	sword_element = int(data.get("sword_element", 0)) as Element.Type
	level = maxi(1, int(data.get("level", 1)))
	xp = int(data.get("xp", 0))
	graphics_quality = int(data.get("graphics_quality", default_graphics_quality()))
	_upgrade_levels.clear()
	var levels: Dictionary = data.get("upgrades", {})
	for id: String in levels:
		_upgrade_levels[StringName(id)] = int(levels[id])
	gold_changed.emit(gold)
	upgrades_changed.emit()
	xp_changed.emit(xp, xp_needed(), level)
