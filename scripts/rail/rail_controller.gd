class_name RailController
extends Node
## Move o herói pelo trilho (Path3D) entre os encontros (GDD §5).
## Amostra a curva diretamente e acelera/freia suavemente até o ponto de parada.

signal arrived

@export var path: Path3D
@export var max_speed: float = 6.0
@export var acceleration: float = 8.0
@export var min_speed: float = 0.6
## Tempo para voltar ao trilho depois de o herói ter saído dele (Passo Relâmpago).
@export var return_to_rail_time: float = 0.4
## Distância à frente usada para calcular a direção do trilho.
@export var look_ahead: float = 1.0

var progress: float = 0.0

var _player: Player
var _target_progress: float = 0.0
var _speed: float = 0.0
var _moving: bool = false


func _ready() -> void:
	assert(path != null and path.curve != null, "RailController precisa de um Path3D com curva")


func length() -> float:
	return path.curve.get_baked_length()


func progress_of(node: Node3D) -> float:
	return path.curve.get_closest_offset(path.to_local(node.global_position))


func position_at(at_progress: float) -> Vector3:
	return path.to_global(path.curve.sample_baked(clampf(at_progress, 0.0, length()), true))


func direction_at(at_progress: float) -> Vector3:
	var start := clampf(at_progress, 0.0, maxf(0.0, length() - look_ahead))
	return (position_at(start + look_ahead) - position_at(start)).normalized()


func place_at(player: Player, at_progress: float) -> void:
	_player = player
	progress = at_progress
	_apply()


## Volta o herói ao trilho (se saiu dele) e avança até target_progress. Use com await.
func travel_to(player: Player, target_progress: float) -> void:
	_player = player
	player.begin_travel()
	var rail_point := position_at(progress)
	if player.global_position.distance_to(rail_point) > 0.05:
		var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		tween.tween_property(player, "global_position", rail_point, return_to_rail_time) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tween.finished
	_target_progress = clampf(target_progress, progress, length())
	_speed = 0.0
	_moving = true
	await arrived
	player.end_travel()


func _physics_process(delta: float) -> void:
	if not _moving:
		return
	var remaining := _target_progress - progress
	if remaining <= 0.01:
		progress = _target_progress
		_moving = false
		_apply()
		arrived.emit()
		return
	var braking_speed := sqrt(2.0 * acceleration * remaining)
	_speed = clampf(minf(_speed + acceleration * delta, braking_speed), min_speed, max_speed)
	progress = minf(progress + _speed * delta, _target_progress)
	_apply()


func _apply() -> void:
	_player.global_position = position_at(progress)
	_player.face_direction(direction_at(progress))
