class_name AttackTokenManager
extends Node
## Poucos inimigos atacam ao mesmo tempo (GDD §6.3). Concede o token a um inimigo em guarda e em
## posição; quando ele termina (ou morre), espera um intervalo aleatório e concede ao próximo.
## Hordas (GDD §8.3): nos arcos avançados e no New Game+ mais inimigos atacam juntos.

@export var data: AttackTokenData

var _enemies: Array[Enemy] = []
var _holders: Array[Enemy] = []
var _cooldown: float = 0.0


func _ready() -> void:
	assert(data != null, "AttackTokenManager precisa de AttackTokenData")
	_cooldown = _random_interval()


## Inscreve o inimigo na fila de ataques. Pode ser chamado de novo para um inimigo que
## morreu e foi revivido (os sinais só são ligados uma vez).
func register(enemy: Enemy) -> void:
	if enemy in _enemies:
		return
	_enemies.append(enemy)
	var on_finished := _on_attack_finished.bind(enemy)
	var on_gone := _unregister.bind(enemy)
	if not enemy.attack_finished.is_connected(on_finished):
		enemy.attack_finished.connect(on_finished)
	if not enemy.died.is_connected(on_gone):
		enemy.died.connect(on_gone)
	if not enemy.tree_exiting.is_connected(on_gone):
		enemy.tree_exiting.connect(on_gone)


## Atacantes simultâneos: 1 no começo, +1 a partir do 3º arco, +1 no New Game+ (máx. 3).
static func max_attackers() -> int:
	return mini(1 + (1 if GameState.story_arc >= 2 else 0) + mini(GameState.new_game_plus, 1), 3)


## Quem está com o token agora (o primeiro, para quem só precisa de um).
var _holder: Enemy:
	get:
		return _holders[0] if not _holders.is_empty() else null


func _physics_process(delta: float) -> void:
	_holders = _holders.filter(func(enemy: Enemy) -> bool: return is_instance_valid(enemy))
	if _holders.size() >= max_attackers():
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var eligible: Array[Enemy] = []
	for enemy: Enemy in _enemies:
		if is_instance_valid(enemy) and enemy.can_receive_token() and not enemy in _holders:
			eligible.append(enemy)
	if eligible.is_empty():
		return
	var chosen: Enemy = eligible.pick_random()
	_holders.append(chosen)
	_cooldown = _random_interval() * 0.5 if _holders.size() < max_attackers() else _cooldown
	chosen.grant_attack_token()


func _on_attack_finished(enemy: Enemy) -> void:
	if enemy in _holders:
		_release(enemy)


func _unregister(enemy: Enemy) -> void:
	_enemies.erase(enemy)
	if enemy in _holders:
		_release(enemy)


func _release(enemy: Enemy) -> void:
	_holders.erase(enemy)
	_cooldown = _random_interval()


## À noite os inimigos se revezam mais rápido (até 35% menos espera).
func _random_interval() -> float:
	return randf_range(data.interval_min, data.interval_max) * (1.0 - 0.35 * GameState.night_factor)
