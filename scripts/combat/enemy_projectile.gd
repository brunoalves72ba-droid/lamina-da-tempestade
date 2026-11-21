class_name EnemyProjectile
extends Node3D
## Esfera de energia da Conjuradora e da rajada dos chefões (GDD §6.2). Persegue o hurtbox do alvo e acerta exatamente ao fim do voo,
## que coincide com o fim do aviso. Pode ser anulado com parry (não atordoa o atirador).

const AIM_HEIGHT: float = 1.0

var _target: Hurtbox
var _info: DamageInfo
var _start: Vector3 = Vector3.ZERO
var _flight_time: float = 0.35
var _elapsed: float = 0.0
var _done: bool = false


## Pega um projétil do Object Pooling (um pool por cena de projétil).
static func spawn(scene: PackedScene, parent: Node) -> EnemyProjectile:
	return Pools.acquire(StringName("projectile:" + scene.resource_path), scene.instantiate, parent) as EnemyProjectile


func set_color(color: Color) -> void:
	var mesh := $Mesh as MeshInstance3D
	var material := (mesh.mesh.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
	material.albedo_color = color
	material.emission = color
	mesh.material_override = material


func launch(start: Vector3, target_hurtbox: Hurtbox, info: DamageInfo, flight_time: float) -> void:
	global_position = start
	_start = start
	_target = target_hurtbox
	_info = info
	_info.on_parried = _on_parried
	_flight_time = maxf(flight_time, 0.01)
	_elapsed = 0.0
	_done = false


func _physics_process(delta: float) -> void:
	if _done:
		return
	if _target == null or not is_instance_valid(_target):
		Pools.release(self)
		return
	_elapsed += delta
	var aim := _target.global_position + Vector3.UP * AIM_HEIGHT
	var t := minf(_elapsed / _flight_time, 1.0)
	var next := _start.lerp(aim, t)
	if next.distance_squared_to(global_position) > 0.0001:
		look_at(next, Vector3.UP)
	global_position = next
	if t >= 1.0:
		_done = true
		_target.receive_hit(_info)
		Pools.release(self)


func _on_parried() -> void:
	_done = true
	Pools.release(self)
