class_name SandboxCombat
extends Node3D
## Sandbox de combate (GDD §12, M1): herói parado contra um inimigo de treino.
## F6 no editor. R reinicia; o inimigo renasce sozinho depois de derrotado.

@export var respawn_delay: float = 2.0
@export var camera_focus: Vector3 = Vector3(0.0, 0.9, -1.4)
@export var enemy_scene: PackedScene

var _extra_enemies: Array[Enemy] = []
var _player_start: Transform3D
var _enemy_start: Transform3D

@onready var player: Player = %Player
@onready var enemy: Enemy = %Enemy
@onready var tokens: AttackTokenManager = %AttackTokenManager
@onready var _hud: GameHUD = %HUD
@onready var _camera: Camera3D = %Camera


func _ready() -> void:
	_player_start = player.global_transform
	_enemy_start = enemy.global_transform
	enemy.set_target(player)
	tokens.register(enemy)
	_hud.bind_player(player)
	_camera.look_at(camera_focus, Vector3.UP)
	enemy.died.connect(_on_enemy_died)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_reset"):
		reset()


func reset() -> void:
	for extra: Enemy in _extra_enemies:
		if is_instance_valid(extra):
			extra.queue_free()
	_extra_enemies.clear()
	player.global_transform = _player_start
	enemy.global_transform = _enemy_start
	player.reset_state()
	enemy.reset_state()
	# Morto, ele saiu da fila de ataques; ao reviver precisa voltar.
	tokens.register(enemy)


## Cria um inimigo extra (usado pelos testes automáticos). reset() remove.
func spawn_extra_enemy(data: EnemyData, at_position: Vector3) -> Enemy:
	var extra := enemy_scene.instantiate() as Enemy
	extra.data = data
	add_child(extra)
	extra.global_position = at_position
	extra.set_target(player)
	tokens.register(extra)
	_extra_enemies.append(extra)
	return extra


func _on_enemy_died() -> void:
	await get_tree().create_timer(respawn_delay).timeout
	if enemy.health.is_dead:
		enemy.reset_state()
		tokens.register(enemy)
