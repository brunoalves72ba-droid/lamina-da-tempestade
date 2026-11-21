class_name WaveSpawner
extends Node
## Cria os inimigos de uma onda nos pontos do Encounter e espera todos morrerem (GDD §9).
## Escala com o nível do herói: inimigos extras por onda e vida/dano maiores (ProgressionData).

signal enemy_spawned(enemy: Enemy)
signal wave_cleared

@export var enemies_root: Node3D
@export var token_manager: AttackTokenManager

var target: Node3D
## Nível usado para escalar (a fase define com o nível do herói; 1 = sem escala).
var scaling_level: int = 1
var progression: ProgressionData

var _alive: int = 0
var _wave_enemies: Array[Enemy] = []


## Use com await: retorna quando todos os inimigos da onda morrerem.
func run_wave(wave: WaveData, encounter: Encounter) -> void:
	_alive = 0
	_wave_enemies.clear()
	var point := 0
	for entry: SpawnEntry in wave.spawns:
		_spawn_counted(entry, encounter.spawn_position(entry.spawn_point))
		point = maxi(point, entry.spawn_point + 1)
	var melee := _melee_entries(wave)
	for i: int in _extra_count():
		if melee.is_empty():
			break
		_spawn_counted(melee[i % melee.size()], encounter.spawn_position(point + i))
	if _alive > 0:
		await wave_cleared


## Remove os inimigos da onda em andamento (herói morreu e a zona recomeça).
## Libera quem está esperando run_wave; quem chamou deve conferir se a zona ainda vale.
func abort_wave() -> void:
	for enemy: Enemy in _wave_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_wave_enemies.clear()
	var was_running := _alive > 0
	_alive = 0
	if was_running:
		wave_cleared.emit()


## Cria um inimigo avulso (patrulha); não conta para ondas.
func spawn_enemy(entry: SpawnEntry, at_position: Vector3) -> Enemy:
	var enemy := entry.enemy_scene.instantiate() as Enemy
	assert(enemy != null, "SpawnEntry.enemy_scene precisa ter um Enemy na raiz")
	if entry.enemy_data != null:
		enemy.data = entry.enemy_data
	enemy.element = entry.element
	enemy.remove_after_death = true
	if progression != null:
		enemy.health_scale = progression.enemy_health_scale(scaling_level)
		enemy.damage_scale = progression.enemy_damage_scale(scaling_level)
	enemies_root.add_child(enemy)
	enemy.global_position = at_position
	enemy.set_target(target)
	token_manager.register(enemy)
	enemy_spawned.emit(enemy)
	return enemy


func _spawn_counted(entry: SpawnEntry, at_position: Vector3) -> void:
	var enemy := spawn_enemy(entry, at_position)
	enemy.died.connect(_on_enemy_died.bind(enemy))
	_wave_enemies.append(enemy)
	_alive += 1


func _extra_count() -> int:
	return progression.extra_enemies(scaling_level) if progression != null else 0


func _melee_entries(wave: WaveData) -> Array[SpawnEntry]:
	var result: Array[SpawnEntry] = []
	for entry: SpawnEntry in wave.spawns:
		if entry.enemy_data != null and entry.enemy_data.attack_kind == EnemyData.AttackKind.MELEE \
				and entry.enemy_data.model_variant == EnemyData.ModelVariant.SOLDIER:
			result.append(entry)
	return result


func _on_enemy_died(enemy: Enemy) -> void:
	_alive -= 1
	_wave_enemies.erase(enemy)
	if _alive > 0:
		return
	# Finisher (GDD §6.7): o último inimigo da onda caiu com um golpe forte.
	if enemy.last_hit != null and enemy.last_hit.is_heavy:
		Events.wave_finisher.emit(enemy)
	wave_cleared.emit()
