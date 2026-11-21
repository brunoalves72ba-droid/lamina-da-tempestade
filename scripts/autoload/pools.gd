extends Node
## Object Pooling (autoload "Pools"): reaproveita nós criados com frequência (raios, faíscas,
## ondas de choque, marcas no chão, luzes, projéteis, números de dano) em vez de criar e destruir
## a cada golpe. Evita picos de instanciação e de limpeza de memória no meio do combate.
##
## Uso:
##   var arc := Pools.acquire(&"lightning_arc", func() -> Node: return SCENE.instantiate(), parent)
##   ...
##   Pools.release(arc)                # devolve na hora
##   Pools.release_after(arc, 0.4)     # devolve depois de um tempo (tempo de jogo)
## O nó devolvido sai da cena e fica guardado; se tiver `_pool_reset()`, ele é chamado ao reutilizar.
## Tweens criados com `Pools.tween(node)` são encerrados ao devolver.

## Quantos nós livres guardar por tipo (o excedente é liberado da memória).
const MAX_FREE_PER_KEY: int = 64

var _free: Dictionary = {}  # StringName -> Array[Node]
var _stats: Dictionary = {}  # StringName -> [criados, reutilizados]
var _storage: Node


func _ready() -> void:
	_storage = Node.new()
	_storage.name = "Storage"
	add_child(_storage)


## Pega um nó do tipo `key` (reutilizado ou novo, via `factory`) e coloca em `parent`.
func acquire(key: StringName, factory: Callable, parent: Node) -> Node:
	var list: Array = _free.get(key, [])
	var node: Node = null
	while not list.is_empty() and node == null:
		var candidate: Node = list.pop_back()
		if is_instance_valid(candidate):
			node = candidate
	var stats: Array = _stats.get(key, [0, 0])
	if node == null:
		node = factory.call()
		node.set_meta(&"pool_key", key)
		stats[0] += 1
	else:
		_storage.remove_child(node)
		stats[1] += 1
	_stats[key] = stats
	node.set_meta(&"pool_active", true)
	node.set_meta(&"pool_serial", int(node.get_meta(&"pool_serial", 0)) + 1)
	parent.add_child(node)
	if node is Node3D:
		(node as Node3D).visible = true
	if node.has_method(&"_pool_reset"):
		node.call(&"_pool_reset")
	return node


## Devolve o nó ao pool (sai da cena). Nós que não vieram de um pool são liberados.
func release(node: Node) -> void:
	if node == null or not is_instance_valid(node) or not node.get_meta(&"pool_active", false):
		return
	node.set_meta(&"pool_active", false)
	_kill_tweens(node)
	var key: StringName = node.get_meta(&"pool_key", &"")
	if key == &"":
		node.queue_free()
		return
	var list: Array = _free.get(key, [])
	if list.size() >= MAX_FREE_PER_KEY:
		node.queue_free()
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	_storage.add_child(node)
	if node is Node3D:
		(node as Node3D).visible = false
	list.append(node)
	_free[key] = list


## Devolve depois de `seconds` (respeita pausa e câmera lenta).
func release_after(node: Node, seconds: float) -> void:
	var serial: int = node.get_meta(&"pool_serial", 0)
	var id := node.get_instance_id()
	get_tree().create_timer(seconds, false).timeout.connect(func() -> void:
		# Só devolve se o nó ainda existe e ninguém o reutilizou nesse meio-tempo.
		var current := instance_from_id(id) as Node
		if current != null and current.get_meta(&"pool_serial", 0) == serial:
			release(current))


## Tween ligado ao nó que é encerrado quando o nó volta ao pool.
func tween(node: Node) -> Tween:
	var created := node.create_tween()
	var list: Array = node.get_meta(&"pool_tweens", [])
	list.append(created)
	node.set_meta(&"pool_tweens", list)
	return created


## [criados, reutilizados] por tipo — para medir se o pool está funcionando.
func stats() -> Dictionary:
	return _stats.duplicate(true)


func free_count(key: StringName) -> int:
	return (_free.get(key, []) as Array).size()


func _kill_tweens(node: Node) -> void:
	for created: Tween in node.get_meta(&"pool_tweens", []):
		if created != null and created.is_valid():
			created.kill()
	node.set_meta(&"pool_tweens", [])
