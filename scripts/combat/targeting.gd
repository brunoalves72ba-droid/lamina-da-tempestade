class_name Targeting
extends Node
## Seleção de alvo (GDD §6.4, movimento livre).
## - Travado (Q / botão do meio): a câmera e o herói ficam no alvo; Tab/roda trocam (esquerda→direita na tela).
##   Se o alvo travado morre, trava no próximo inimigo mais perto; longe demais, destrava.
## - Sem travar: o alvo é o inimigo vivo mais perto do herói dentro de acquire_range (mira suave).

signal target_changed(target: Enemy)
signal lock_changed(locked: bool)

const SOFT_COLOR := Color(0.45, 0.85, 1.0)
const LOCKED_COLOR := Color(1.0, 0.35, 0.25)
## Mira livre: raio do círculo da mira (fração da altura da tela) e altura do peito do inimigo.
const FREE_AIM_SCREEN_RADIUS: float = 0.08
const FREE_AIM_HEIGHT: float = 1.1

@export var marker: MeshInstance3D
@export var marker_height: float = 0.04
## Sem travar: alcance para escolher o alvo automaticamente.
@export var acquire_range: float = 10.0
## Alcance máximo para travar e manter travado.
@export var lock_range: float = 20.0

var current: Enemy
var locked: bool = false
var enabled: bool = true

var _soft_material: StandardMaterial3D
var _locked_material: StandardMaterial3D


func _ready() -> void:
	_soft_material = _make_material(SOFT_COLOR)
	_locked_material = _make_material(LOCKED_COLOR)
	if marker != null:
		marker.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event.is_action_pressed(&"toggle_aim"):
		toggle_aim_mode()
	elif event.is_action_pressed(&"lock_on"):
		toggle_lock()
	elif locked and event.is_action_pressed(&"target_next"):
		cycle(1)
	elif locked and event.is_action_pressed(&"target_prev"):
		cycle(-1)


func _physics_process(_delta: float) -> void:
	if current != null and not _is_valid(current):
		set_target(null, locked)
	var list := candidates()
	if locked:
		if current != null and _distance(current) > lock_range:
			_set_locked(false)
		elif current == null:
			var next := _nearest_to_hero(list, lock_range)
			if next != null:
				set_target(next, true)
			else:
				_set_locked(false)
	if not locked:
		var nearest := _under_crosshair(list) if is_free_aim() else _nearest_to_hero(list, acquire_range)
		if nearest != current:
			set_target(nearest, false)
	_update_marker()


# --- Mira híbrida (GDD §6.4) ---------------------------------------------------

## Mira livre: só vale o inimigo que está na mira (centro da tela); nada é escolhido por proximidade
## e o herói não gira sozinho para o alvo. Travar (Q) continua disponível nos dois modos.
func is_free_aim() -> bool:
	return GameState.aim_mode == GameState.AimMode.FREE


func toggle_aim_mode() -> void:
	set_aim_mode(GameState.AimMode.ASSISTED if is_free_aim() else GameState.AimMode.FREE)


func set_aim_mode(mode: GameState.AimMode) -> void:
	if GameState.aim_mode == mode:
		return
	GameState.aim_mode = mode
	if mode == GameState.AimMode.FREE and not locked:
		set_target(null, false)
	Events.aim_mode_changed.emit(mode)
	SaveManager.autosave()


## Inimigo mais perto do centro da tela, dentro do círculo da mira e do alcance de travar.
func _under_crosshair(list: Array[Enemy]) -> Enemy:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var size := get_viewport().get_visible_rect().size
	var center := size * 0.5
	var radius := size.y * FREE_AIM_SCREEN_RADIUS
	var best: Enemy = null
	var best_distance := radius * radius
	for enemy: Enemy in list:
		if _distance(enemy) > lock_range:
			continue
		var chest := enemy.global_position + Vector3.UP * FREE_AIM_HEIGHT * enemy.data.body_scale
		if camera.is_position_behind(chest):
			continue
		var distance := camera.unproject_position(chest).distance_squared_to(center)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best


func candidates() -> Array[Enemy]:
	var result: Array[Enemy] = []
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy != null and _is_valid(enemy):
			result.append(enemy)
	return result


func toggle_lock() -> void:
	if locked:
		_set_locked(false)
		return
	var list := candidates().filter(func(e: Enemy) -> bool: return _distance(e) <= lock_range)
	if list.is_empty():
		return
	set_target(_nearest_to_screen_center(list), true)


## Troca o alvo travado (esquerda/direita na tela). Também trava, se não estava.
func cycle(step: int) -> void:
	var list := candidates().filter(func(e: Enemy) -> bool: return _distance(e) <= lock_range)
	if list.is_empty():
		return
	list.sort_custom(func(a: Enemy, b: Enemy) -> bool: return _screen_x(a) < _screen_x(b))
	var index := list.find(current)
	var next_index := 0 if index == -1 else posmod(index + step, list.size())
	set_target(list[next_index], true)


## Define o alvo. Por padrão trava nele (escolha explícita do jogador ou de um teste).
func set_target(enemy: Enemy, lock: bool = true) -> void:
	_set_locked(lock and enemy != null)
	if enemy == current:
		return
	current = enemy
	target_changed.emit(enemy)


func _set_locked(value: bool) -> void:
	if value == locked:
		return
	locked = value
	lock_changed.emit(locked)


func _is_valid(enemy: Enemy) -> bool:
	return is_instance_valid(enemy) and enemy.is_inside_tree() and not enemy.health.is_dead


func _hero_position() -> Vector3:
	var hero := owner as Node3D
	return hero.global_position if hero != null else Vector3.ZERO


func _distance(enemy: Enemy) -> float:
	return _hero_position().distance_to(enemy.global_position)


func _nearest_to_hero(list: Array[Enemy], max_range: float) -> Enemy:
	var best: Enemy = null
	var best_distance := max_range
	for enemy: Enemy in list:
		var distance := _distance(enemy)
		if distance <= best_distance:
			best_distance = distance
			best = enemy
	return best


func _nearest_to_screen_center(list: Array) -> Enemy:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return _nearest_to_hero(Array(list, TYPE_OBJECT, &"CharacterBody3D", Enemy), lock_range)
	var center := get_viewport().get_visible_rect().size * 0.5
	var best: Enemy = list[0]
	var best_distance := INF
	for enemy: Enemy in list:
		if camera.is_position_behind(enemy.global_position):
			continue
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
		marker.material_override = _locked_material if locked else _soft_material


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material
