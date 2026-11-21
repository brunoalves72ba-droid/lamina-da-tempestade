class_name AttackTokenManager
extends Node
## Só um inimigo ataca por vez (GDD §6.3). Concede o token a um inimigo em guarda e em posição;
## quando ele termina (ou morre), espera um intervalo aleatório e concede ao próximo.

@export var data: AttackTokenData

var _enemies: Array[Enemy] = []
var _holder: Enemy
var _cooldown: float = 0.0


func _ready() -> void:
	assert(data != null, "AttackTokenManager precisa de AttackTokenData")
	_cooldown = _random_interval()


func register(enemy: Enemy) -> void:
	if enemy in _enemies:
		return
	_enemies.append(enemy)
	enemy.attack_finished.connect(_on_attack_finished.bind(enemy))
	enemy.died.connect(_unregister.bind(enemy))
	enemy.tree_exiting.connect(_unregister.bind(enemy))


func _physics_process(delta: float) -> void:
	if _holder != null:
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var eligible: Array[Enemy] = []
	for enemy: Enemy in _enemies:
		if is_instance_valid(enemy) and enemy.can_receive_token():
			eligible.append(enemy)
	if eligible.is_empty():
		return
	_holder = eligible.pick_random()
	_holder.grant_attack_token()


func _on_attack_finished(enemy: Enemy) -> void:
	if enemy == _holder:
		_release()


func _unregister(enemy: Enemy) -> void:
	_enemies.erase(enemy)
	if enemy == _holder:
		_release()


func _release() -> void:
	_holder = null
	_cooldown = _random_interval()


func _random_interval() -> float:
	return randf_range(data.interval_min, data.interval_max)
