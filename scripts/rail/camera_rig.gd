class_name CameraRig
extends Camera3D
## Câmera em terceira pessoa (GDD §5). Na viagem fica atrás do herói olhando adiante;
## no combate enquadra herói + alvo atual. Movimento com suavização exponencial.

@export var player: Player
@export var look_height: float = 1.0
@export var follow_sharpness: float = 5.0

@export_group("Viagem")
@export var travel_distance: float = 4.0
@export var travel_height: float = 2.0
@export var travel_look_ahead: float = 4.0

@export_group("Combate")
@export var combat_distance: float = 4.8
@export var combat_height: float = 3.3
@export var combat_side_offset: float = 1.3

@export_group("Colisão com o cenário")
## Camadas que bloqueiam a câmera (1 = world).
@export_flags_3d_physics var obstacle_mask: int = 1
## Distância mantida da parede quando ela está entre o herói e a câmera.
@export var wall_margin: float = 0.4
## Suavização mais rápida quando a câmera precisa sair de trás de uma parede.
@export var blocked_sharpness_multiplier: float = 4.0

var _goal_position: Vector3 = Vector3.ZERO
var _goal_look: Vector3 = Vector3.ZERO
var _look_point: Vector3 = Vector3.ZERO


## Pula direto para a posição ideal (início da fase).
func snap() -> void:
	_update_goal()
	_avoid_walls()
	global_position = _goal_position
	_look_point = _goal_look
	_apply_look()


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_update_goal()
	var blocked := _avoid_walls()
	var sharpness := follow_sharpness * (blocked_sharpness_multiplier if blocked else 1.0)
	var weight := 1.0 - exp(-sharpness * delta)
	global_position = global_position.lerp(_goal_position, weight)
	_look_point = _look_point.lerp(_goal_look, weight)
	_apply_look()


func _update_goal() -> void:
	var origin := player.global_position
	var target := player.target
	if player.is_traveling() or target == null:
		var forward := -player.global_basis.z
		forward.y = 0.0
		forward = forward.normalized()
		_goal_position = origin - forward * travel_distance + Vector3.UP * travel_height
		_goal_look = origin + forward * travel_look_ahead + Vector3.UP * look_height
		return
	var to_target := target.global_position - origin
	to_target.y = 0.0
	var direction := to_target.normalized() if to_target.length() > 0.01 else -player.global_basis.z
	var right := direction.cross(Vector3.UP)
	_goal_position = origin - direction * combat_distance + Vector3.UP * combat_height + right * combat_side_offset
	_goal_look = origin.lerp(target.global_position, 0.5) + Vector3.UP * look_height


## "Braço de mola": se o cenário está entre o herói e a posição ideal, aproxima a câmera
## até antes da parede. Retorna true se estava bloqueada.
func _avoid_walls() -> bool:
	var origin := player.global_position + Vector3.UP * look_height
	var query := PhysicsRayQueryParameters3D.create(origin, _goal_position, obstacle_mask)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var hit_point: Vector3 = hit["position"]
	var direction := (_goal_position - origin).normalized()
	_goal_position = hit_point - direction * wall_margin
	return true


func _apply_look() -> void:
	if global_position.distance_squared_to(_look_point) > 0.01:
		look_at(_look_point, Vector3.UP)
