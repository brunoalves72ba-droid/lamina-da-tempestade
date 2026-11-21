class_name Targeting
extends Node
## Seleção de alvo (GDD §6.4). A/D ou roda do mouse percorrem os inimigos vivos
## da esquerda para a direita na tela. O primeiro alvo de um encontro é o mais perto
## do centro da tela; quando o alvo morre, passa para o inimigo vivo mais perto do herói.

signal target_changed(target: Enemy)

@export var marker: Node3D
@export var marker_height: float = 0.04

var current: Enemy
var enabled: bool = true

var _lost_target: bool = false


func _ready() -> void:
	if marker != null:
		marker.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event.is_action_pressed(&"target_next"):
		cycle(1)
	elif event.is_action_pressed(&"target_prev"):
		cycle(-1)


func _physics_process(_delta: float) -> void:
	if current != null and not _is_valid(current):
		_lost_target = true
		set_target(null)
	if current == null:
		var list := candidates()
		if list.is_empty():
			_lost_target = false
		else:
			set_target(_nearest_to_hero(list) if _lost_target else _nearest_to_screen_center(list))
	_update_marker()


func candidates() -> Array[Enemy]:
	var result: Array[Enemy] = []
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy != null and _is_valid(enemy):
			result.append(enemy)
	return result


func cycle(step: int) -> void:
	var list := candidates()
	if list.is_empty():
		return
	list.sort_custom(func(a: Enemy, b: Enemy) -> bool: return _screen_x(a) < _screen_x(b))
	var index := list.find(current)
	var next_index := 0 if index == -1 else posmod(index + step, list.size())
	set_target(list[next_index])


func set_target(enemy: Enemy) -> void:
	if enemy == current:
		return
	current = enemy
	target_changed.emit(enemy)


func _is_valid(enemy: Enemy) -> bool:
	return is_instance_valid(enemy) and enemy.is_inside_tree() and not enemy.health.is_dead


func _hero_position() -> Vector3:
	var hero := owner as Node3D
	return hero.global_position if hero != null else Vector3.ZERO


func _nearest_to_hero(list: Array[Enemy]) -> Enemy:
	var origin := _hero_position()
	var best: Enemy = list[0]
	for enemy: Enemy in list:
		if origin.distance_squared_to(enemy.global_position) < origin.distance_squared_to(best.global_position):
			best = enemy
	return best


func _nearest_to_screen_center(list: Array[Enemy]) -> Enemy:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return _nearest_to_hero(list)
	var center := get_viewport().get_visible_rect().size * 0.5
	var best: Enemy = list[0]
	var best_distance := INF
	for enemy: Enemy in list:
		var distance := camera.unproject_position(enemy.global_position).distance_squared_to(center)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best


func _screen_x(enemy: Enemy) -> float:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return enemy.global_position.x
	return camera.unproject_position(enemy.global_position).x


func _update_marker() -> void:
	if marker == null:
		return
	marker.visible = current != null
	if current != null:
		marker.global_position = current.global_position + Vector3.UP * marker_height
