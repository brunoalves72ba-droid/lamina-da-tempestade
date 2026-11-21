class_name ArenaDirector
extends Node
## Arena de Hordas (GDD §4.3): ondas sem fim numa clareira fechada para testar combos.
## Cada onda tem mais inimigos e mais variados; a cada 5 ondas vem um chefão. Termina quando o
## herói cai; o recorde de ondas fica salvo (GameState.arena_best).

signal wave_started(number: int)
signal arena_over(waves_survived: int)

const BOSSES: Array[String] = ["res://data/enemies/boss_warrok.tres", "res://data/enemies/boss_mutant.tres", "res://data/enemies/boss_maw.tres"]
const BREAK_TIME: float = 2.5

var level: WorldLevel
var zone: CombatZone
var wave: int = 0
var running: bool = false

var _soldier: EnemyData = preload("res://data/enemies/soldier.tres")
var _caster: EnemyData = preload("res://data/enemies/crossbowman.tres")
var _elite: EnemyData = preload("res://data/enemies/elite.tres")
var _scene: PackedScene = preload("res://scenes/enemies/enemy_base.tscn")


func start() -> void:
	running = true
	while running and is_inside_tree():
		wave += 1
		wave_started.emit(wave)
		await level.spawner.run_wave(_build_wave(wave), zone)
		if not running:
			return
		level.player.heal(level.player.health.max_health * 0.25)
		await get_tree().create_timer(BREAK_TIME, false).timeout


func stop() -> void:
	if not running:
		return
	running = false
	var survived := maxi(wave - 1, 0)
	if survived > GameState.arena_best:
		GameState.arena_best = survived
	arena_over.emit(survived)


func _build_wave(number: int) -> WaveData:
	var data := WaveData.new()
	var spawns: Array[SpawnEntry] = []
	if number % 5 == 0:
		spawns.append(_entry(load(BOSSES[(number / 5 - 1) % BOSSES.size()]) as EnemyData, 0))
	var count := 2 + number
	for i: int in mini(count, 9):
		var kind := _soldier
		if i % 4 == 3:
			kind = _caster
		elif number >= 3 and i % 5 == 4:
			kind = _elite
		spawns.append(_entry(kind, (i + 1) % 10))
	data.spawns = spawns
	return data


func _entry(enemy_data: EnemyData, point: int) -> SpawnEntry:
	var entry := SpawnEntry.new()
	entry.enemy_scene = _scene
	entry.enemy_data = enemy_data
	entry.element = (randi() % 3 + 1) as Element.Type
	entry.spawn_point = point
	return entry
