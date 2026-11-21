class_name WaveSpawner
extends Node
## Cria os inimigos de uma onda nos pontos do Encounter e espera todos morrerem (GDD §9).

signal enemy_spawned(enemy: Enemy)
signal wave_cleared

@export var enemies_root: Node3D
@export var token_manager: AttackTokenManager

var target: Node3D

var _alive: int = 0


## Use com await: retorna quando todos os inimigos da onda morrerem.
func run_wave(wave: WaveData, encounter: Encounter) -> void:
	_alive = 0
	for entry: SpawnEntry in wave.spawns:
		_spawn(entry, encounter)
	if _alive > 0:
		await wave_cleared


func _spawn(entry: SpawnEntry, encounter: Encounter) -> void:
	var enemy := entry.enemy_scene.instantiate() as Enemy
	assert(enemy != null, "SpawnEntry.enemy_scene precisa ter um Enemy na raiz")
	if entry.enemy_data != null:
		enemy.data = entry.enemy_data
	enemy.element = entry.element
	enemy.remove_after_death = true
	enemies_root.add_child(enemy)
	enemy.global_position = encounter.spawn_position(entry.spawn_point)
	enemy.set_target(target)
	enemy.died.connect(_on_enemy_died.bind(enemy))
	token_manager.register(enemy)
	_alive += 1
	enemy_spawned.emit(enemy)


func _on_enemy_died(enemy: Enemy) -> void:
	_alive -= 1
	if _alive > 0:
		return
	# Finisher (GDD §6.7): o último inimigo da onda caiu com um golpe forte.
	if enemy.last_hit != null and enemy.last_hit.is_heavy:
		Events.wave_finisher.emit(enemy)
	wave_cleared.emit()
