extends Node
## Estado da campanha (autoload "GameState"): ouro, nível, upgrades, inventário de espadas,
## reputação, progresso da história, posição salva, modo de mira e New Game+.
## O SaveManager grava/carrega este estado em JSON (GDD §11).

signal gold_changed(gold: int)
signal upgrades_changed
signal xp_changed(xp: int, xp_needed: int, level: int)
signal leveled_up(level: int)
signal reputation_changed(faction: StringName, value: int)
signal inventory_changed

## Mira (GDD §6.4): Assistida = destaca e segue o alvo prioritário (pode girar a câmera e trocar à
## vontade); Livre = golpes e poderes vão exatamente para onde a lâmina/mira apontar.
enum AimMode { ASSISTED, FREE }

## Ordens, guildas e vilarejos (GDD §10.2). Reputação vai de -100 a 100.
const FACTIONS: Dictionary = {
	&"ordem_grifo": "Ordem do Grifo de Prata",
	&"guilda_mercadores": "Guilda dos Mercadores",
	&"vilarejo_cinzas": "Vilarejo de Pedra-Cinza",
}
const REPUTATION_LIMIT: int = 100
const STARTING_SWORD := &"paladin"

const PROGRESSION_PATH := "res://data/progression/progression.tres"

var gold: int = 0
var sword_element: Element.Type = Element.Type.NONE
## Nível e experiência do herói (persistem entre partidas).
var level: int = 1
var xp: int = 0
## Qualidade gráfica escolhida (GraphicsSettings.Quality).
var graphics_quality: int = 1
var aim_mode: AimMode = AimMode.ASSISTED
## História: arco atual e objetivos já cumpridos (ids).
var story_arc: int = 0
var completed_objectives: Array[StringName] = []
var game_completed: bool = false
## Quantas vezes o jogo foi zerado e recomeçado mantendo equipamento (inimigos mais fortes).
var new_game_plus: int = 0
## Ponto do percurso (metros) da última fogueira acesa; 0 = começo.
var checkpoint_progress: float = 0.0
## Espadas: ids das que o herói tem e a equipada (SwordItem.id).
var owned_swords: Array[StringName] = [STARTING_SWORD]
var equipped_sword: StringName = STARTING_SWORD
var reputation: Dictionary[StringName, int] = {}
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
	_reset_campaign()
	new_game_plus = 0
	owned_swords = [STARTING_SWORD]
	equipped_sword = STARTING_SWORD
	reputation.clear()
	inventory_changed.emit()
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


## Soma dos níveis de todos os equipamentos comprados.
func equipment_levels() -> int:
	var total := 0
	for id: StringName in _upgrade_levels:
		total += _upgrade_levels[id]
	return total


## Nível de ameaça dos inimigos: sobe com o nível do herói, o equipamento comprado e o New Game+.
func threat_level() -> float:
	return progression.threat_level(level, equipment_levels()) + new_game_plus * progression.new_game_plus_threat


# --- História, New Game+ e posição ---------------------------------------------

func has_progress() -> bool:
	return story_arc > 0 or not completed_objectives.is_empty() or checkpoint_progress > 0.0 or level > 1


func complete_objective(id: StringName) -> bool:
	if id in completed_objectives:
		return false
	completed_objectives.append(id)
	return true


func is_objective_done(id: StringName) -> bool:
	return id in completed_objectives


## Zerou o jogo e quer recomeçar mais forte: mantém nível, ouro, espadas e upgrades;
## a história volta ao começo e os inimigos sobem de ameaça.
func start_new_game_plus() -> void:
	new_game_plus += 1
	_reset_campaign()


func _reset_campaign() -> void:
	story_arc = 0
	completed_objectives.clear()
	game_completed = false
	checkpoint_progress = 0.0


# --- Reputação --------------------------------------------------------------------

func reputation_of(faction: StringName) -> int:
	return reputation.get(faction, 0)


func change_reputation(faction: StringName, amount: int) -> void:
	assert(FACTIONS.has(faction), "Facção desconhecida: %s" % faction)
	var value := clampi(reputation_of(faction) + amount, -REPUTATION_LIMIT, REPUTATION_LIMIT)
	reputation[faction] = value
	reputation_changed.emit(faction, value)


## Desconto/acréscimo de preço pela reputação com a Guilda dos Mercadores (-15% a +15%).
func price_multiplier() -> float:
	return 1.0 - 0.15 * reputation_of(&"guilda_mercadores") / float(REPUTATION_LIMIT)


# --- Espadas ----------------------------------------------------------------------

func owns_sword(id: StringName) -> bool:
	return id in owned_swords


func grant_sword(id: StringName) -> bool:
	if owns_sword(id):
		return false
	owned_swords.append(id)
	inventory_changed.emit()
	return true


func equip_sword(id: StringName) -> void:
	if owns_sword(id) and equipped_sword != id:
		equipped_sword = id
		inventory_changed.emit()


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
	var rep := {}
	for faction: StringName in reputation:
		rep[String(faction)] = reputation[faction]
	return {"gold": gold, "sword_element": int(sword_element), "upgrades": levels,
			"level": level, "xp": xp, "graphics_quality": graphics_quality, "aim_mode": int(aim_mode),
			"story_arc": story_arc, "completed_objectives": completed_objectives.map(func(id: StringName) -> String: return String(id)),
			"game_completed": game_completed, "new_game_plus": new_game_plus,
			"checkpoint_progress": checkpoint_progress,
			"owned_swords": owned_swords.map(func(id: StringName) -> String: return String(id)),
			"equipped_sword": String(equipped_sword), "reputation": rep}


func from_dict(data: Dictionary) -> void:
	gold = int(data.get("gold", 0))
	sword_element = int(data.get("sword_element", 0)) as Element.Type
	level = maxi(1, int(data.get("level", 1)))
	xp = int(data.get("xp", 0))
	graphics_quality = int(data.get("graphics_quality", default_graphics_quality()))
	aim_mode = int(data.get("aim_mode", AimMode.ASSISTED)) as AimMode
	story_arc = int(data.get("story_arc", 0))
	completed_objectives.clear()
	for id: Variant in data.get("completed_objectives", []):
		completed_objectives.append(StringName(str(id)))
	game_completed = bool(data.get("game_completed", false))
	new_game_plus = int(data.get("new_game_plus", 0))
	checkpoint_progress = float(data.get("checkpoint_progress", 0.0))
	owned_swords.clear()
	for id: Variant in data.get("owned_swords", [String(STARTING_SWORD)]):
		owned_swords.append(StringName(str(id)))
	if not STARTING_SWORD in owned_swords:
		owned_swords.insert(0, STARTING_SWORD)
	equipped_sword = StringName(str(data.get("equipped_sword", STARTING_SWORD)))
	if not equipped_sword in owned_swords:
		equipped_sword = STARTING_SWORD
	reputation.clear()
	var rep: Dictionary = data.get("reputation", {})
	for faction: String in rep:
		if FACTIONS.has(StringName(faction)):
			reputation[StringName(faction)] = clampi(int(rep[faction]), -REPUTATION_LIMIT, REPUTATION_LIMIT)
	_upgrade_levels.clear()
	var levels: Dictionary = data.get("upgrades", {})
	for id: String in levels:
		_upgrade_levels[StringName(id)] = int(levels[id])
	gold_changed.emit(gold)
	upgrades_changed.emit()
	xp_changed.emit(xp, xp_needed(), level)
	inventory_changed.emit()
