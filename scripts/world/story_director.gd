class_name StoryDirector
extends Node
## Conduz a campanha (GDD §4.1): arco atual, objetivo atual na HUD, narração e recompensas.
## Escuta os eventos do mundo (clareira vencida, fogueira, chefão, santuário). Cumprir um
## objetivo salva o jogo; concluir o último objetivo do arco narra o encerramento, dá as
## recompensas e passa para o próximo arco. Fica dentro da fase (WorldLevel cria).

signal story_finished

const CAMPAIGN_DIR := "res://data/story/"
const NARRATOR := "Narrador"
## Tempo de leitura por caractere e mínimo por fala (s).
const SECONDS_PER_CHAR: float = 0.055
const MIN_LINE_TIME: float = 2.5

var arcs: Array[StoryArc] = []


func _ready() -> void:
	arcs = load_campaign()
	Events.zone_cleared.connect(func(zone_name: String) -> void:
		_on_trigger(StoryObjective.Trigger.ZONE_CLEARED, zone_name))
	Events.checkpoint_reached.connect(func(progress: float) -> void:
		_on_trigger(StoryObjective.Trigger.CHECKPOINT, str(roundi(progress))))
	Events.boss_defeated.connect(func(boss_id: StringName) -> void:
		_on_trigger(StoryObjective.Trigger.BOSS_DEFEATED, String(boss_id)))
	Events.shrine_reached.connect(func() -> void:
		_on_trigger(StoryObjective.Trigger.SHRINE, ""))


## Arcos em ordem: data/story/arc_1.tres, arc_2.tres...
static func load_campaign() -> Array[StoryArc]:
	var result: Array[StoryArc] = []
	var index := 1
	while ResourceLoader.exists(CAMPAIGN_DIR + "arc_%d.tres" % index):
		result.append(load(CAMPAIGN_DIR + "arc_%d.tres" % index) as StoryArc)
		index += 1
	return result


## Começa (ou retoma) o arco salvo: narra a abertura só se nada dele foi cumprido ainda.
func begin() -> void:
	var arc := current_arc()
	if arc == null:
		_publish_objective()
		return
	if _done_count(arc) == 0:
		narrate_lines(arc.intro_lines)
	_publish_objective()


func current_arc() -> StoryArc:
	if GameState.story_arc < 0 or GameState.story_arc >= arcs.size():
		return null
	return arcs[GameState.story_arc]


func current_objective() -> StoryObjective:
	var arc := current_arc()
	if arc == null:
		return null
	for objective: StoryObjective in arc.objectives:
		if not GameState.is_objective_done(objective.id):
			return objective
	return null


## Enfileira falas na HUD ("Quem|Texto" ou só o texto do narrador).
func narrate_lines(lines: Array[String]) -> void:
	for line: String in lines:
		var parts := line.split("|", true, 1)
		var speaker := NARRATOR if parts.size() == 1 else parts[0]
		var text := parts[0] if parts.size() == 1 else parts[1]
		Events.narration_requested.emit(speaker, text, maxf(MIN_LINE_TIME, text.length() * SECONDS_PER_CHAR))


func _on_trigger(trigger: StoryObjective.Trigger, param: String) -> void:
	var arc := current_arc()
	if arc == null:
		return
	var changed := false
	for objective: StoryObjective in arc.objectives:
		if objective.trigger == trigger and (objective.param == "" or objective.param == param):
			changed = GameState.complete_objective(objective.id) or changed
	if not changed:
		return
	if current_objective() == null:
		_complete_arc(arc)
	else:
		_publish_objective()
		SaveManager.autosave()


func _complete_arc(arc: StoryArc) -> void:
	narrate_lines(arc.outro_lines)
	for faction: StringName in arc.reputation_rewards:
		GameState.change_reputation(faction, arc.reputation_rewards[faction])
	GameState.add_gold(arc.gold_reward)
	var finished_index := GameState.story_arc
	GameState.story_arc += 1
	Events.arc_completed.emit(finished_index)
	if GameState.story_arc >= arcs.size():
		GameState.game_completed = true
		story_finished.emit()
	else:
		narrate_lines(current_arc().intro_lines)
	_publish_objective()
	SaveManager.autosave()


func _publish_objective() -> void:
	var arc := current_arc()
	var objective := current_objective()
	if arc == null:
		Events.objective_changed.emit("Campanha concluída", "Explore, enfrente a Arena ou comece o New Game+")
		return
	Events.objective_changed.emit("Arco %d — %s" % [GameState.story_arc + 1, arc.title],
			objective.text if objective != null else "")


func _done_count(arc: StoryArc) -> int:
	var count := 0
	for objective: StoryObjective in arc.objectives:
		if GameState.is_objective_done(objective.id):
			count += 1
	return count
