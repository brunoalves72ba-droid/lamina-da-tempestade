class_name Level
extends Node3D
## Fase sobre trilhos (GDD §4, §5, §9): escolha de elemento → viaja até cada Encounter,
## roda as ondas, cura ao limpar → fim do trilho. Conta o ouro, mostra o resultado e salva.

signal encounter_started(index: int, total: int)
signal encounter_cleared(index: int)
signal completed
## Fim da partida (vitória ou morte), já com o ouro creditado no GameState.
signal finished(victory: bool, gold_earned: int)

const CLEAR_COLOR := Color(0.95, 0.9, 0.7)

@export var start_delay: float = 0.6
## Tempo (real) entre a morte do herói e a tela de resultado.
@export var defeat_delay: float = 1.5
## Mostra a escolha de elemento antes de começar (testes automáticos desligam).
@export var show_element_select: bool = true
@export var element_select_scene: PackedScene
@export var result_scene: PackedScene
@export var pause_scene: PackedScene
@export var rewards: RewardData
@export var sword_upgrade: UpgradeData
@export var armor_upgrade: UpgradeData

var encounters: Array[Encounter] = []
var is_complete: bool = false
## Ouro coletado nesta partida (antes da regra de morte e do bônus).
var run_gold: int = 0
## Ouro efetivamente creditado ao fim da partida.
var gold_earned: int = 0

var _finished: bool = false
var _pause_menu: PauseMenu

@onready var player: Player = %Player
@onready var rail: RailController = %RailController
@onready var spawner: WaveSpawner = %WaveSpawner
@onready var _camera: CameraRig = %CameraRig
@onready var _hud: GameHUD = %HUD
@onready var _encounters_root: Node3D = %Encounters
@onready var _ruins: Node3D = %Ruins


func _ready() -> void:
	for child: Node in _encounters_root.get_children():
		var encounter := child as Encounter
		if encounter != null:
			encounters.append(encounter)
	_add_ruin_collisions()
	_apply_upgrades()
	spawner.target = player
	spawner.enemy_spawned.connect(_on_enemy_spawned)
	player.died.connect(_on_player_died)
	_hud.bind_player(player)
	_hud.show_gold(run_gold)
	rail.place_at(player, 0.0)
	_camera.snap()
	_run()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and not _finished and pause_scene != null and _pause_menu == null:
		get_viewport().set_input_as_handled()
		_pause_menu = pause_scene.instantiate() as PauseMenu
		add_child(_pause_menu)
		_pause_menu.restart_requested.connect(_restart)
		_pause_menu.tree_exited.connect(func() -> void: _pause_menu = null)


func _run() -> void:
	if show_element_select and element_select_scene != null:
		var menu := element_select_scene.instantiate() as ElementSelect
		add_child(menu)
		var chosen: int = await menu.element_chosen
		menu.queue_free()
		GameState.sword_element = chosen as Element.Type
	player.set_element(GameState.sword_element)
	_hud.show_element(GameState.sword_element)
	await get_tree().create_timer(start_delay, false, true).timeout
	for i: int in encounters.size():
		var encounter := encounters[i]
		await rail.travel_to(player, rail.progress_of(encounter))
		encounter_started.emit(i, encounters.size())
		_hud.show_encounter(i + 1, encounters.size())
		for wave: WaveData in encounter.waves:
			await spawner.run_wave(wave, encounter)
		if player.health.is_dead:
			return
		player.heal(player.health.max_health * player.data.encounter_heal_fraction)
		_hud.show_feedback("ENCONTRO VENCIDO", CLEAR_COLOR)
		encounter_cleared.emit(i)
	await rail.travel_to(player, rail.length())
	is_complete = true
	_hud.show_feedback("ARENA CONCLUÍDA", CLEAR_COLOR)
	completed.emit()
	_finish(true)


## Status do herói conforme os níveis comprados na loja (GDD §10).
func _apply_upgrades() -> void:
	if sword_upgrade == null or armor_upgrade == null:
		return
	var sword_level := GameState.level_of(sword_upgrade)
	var armor_level := GameState.level_of(armor_upgrade)
	player.apply_stats(sword_upgrade.value_at(sword_level), armor_upgrade.value_at(armor_level),
			armor_upgrade.secondary_at(armor_level))


func _on_enemy_spawned(enemy: Enemy) -> void:
	enemy.died.connect(_on_enemy_killed.bind(enemy))


func _on_enemy_killed(enemy: Enemy) -> void:
	run_gold += enemy.data.gold_reward
	_hud.show_gold(run_gold)


func _on_player_died() -> void:
	await get_tree().create_timer(defeat_delay, true, false, true).timeout
	_finish(false)


## Credita o ouro (bônus na vitória; só uma fração na derrota), salva e mostra o resultado.
func _finish(victory: bool) -> void:
	if _finished:
		return
	_finished = true
	if victory:
		gold_earned = run_gold + (rewards.completion_bonus if rewards != null else 0)
	else:
		gold_earned = floori(run_gold * (rewards.death_keep_fraction if rewards != null else 1.0))
	GameState.add_gold(gold_earned)
	SaveManager.save_game()
	if result_scene != null:
		var screen := result_scene.instantiate() as ResultScreen
		add_child(screen)
		screen.show_result(victory, run_gold, gold_earned)
		screen.replay_requested.connect(_restart)
	finished.emit(victory, gold_earned)


func _restart() -> void:
	Scenes.go(get_tree(), Scenes.ARENA)


## Cenário com colisão: inimigos não atravessam ruínas e a câmera desvia delas.
func _add_ruin_collisions() -> void:
	for node: Node in _ruins.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).create_convex_collision()
