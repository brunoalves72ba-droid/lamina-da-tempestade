class_name Conduction
extends RefCounted
## Física elemental do raio (GDD §6.9): a eletricidade se espalha por condutores.
## - Poças d'água (grupo "puddles", nó Puddle): um raio que cai numa poça eletrifica todos os
##   inimigos dentro dela.
## - Armas caídas (grupo "fallen_metal"): o metal no chão faz o raio saltar para inimigos perto dele.
## - Armadura de metal (Esqueleto com espada e escudo): a Corrente em Cadeia salta mais longe a
##   partir dele (Enemy.is_metal_armored).
## Cada inimigo é atingido no máximo uma vez por descarga.

const PUDDLE_GROUP := &"puddles"
const METAL_GROUP := &"fallen_metal"
const METAL_REACH: float = 3.0
const METAL_TOUCH: float = 2.5
## Fração do dano da descarga original que passa pelo condutor.
const CONDUCTED_FRACTION: float = 0.6


## Espalha uma descarga que tocou `point`. `make_info` cria o DamageInfo de cada alvo conduzido.
## `already_hit` evita atingir duas vezes. Retorna os inimigos atingidos pela condução.
static func discharge(tree: SceneTree, point: Vector3, color: Color, make_info: Callable,
		already_hit: Array[Enemy] = []) -> Array[Enemy]:
	var hit: Array[Enemy] = []
	var parent := tree.current_scene
	for node: Node in tree.get_nodes_in_group(PUDDLE_GROUP):
		var puddle := node as Puddle
		if puddle == null or not puddle.contains(point):
			continue
		puddle.electrify(color)
		for enemy: Enemy in _enemies(tree):
			if enemy in already_hit or enemy in hit or not puddle.contains(enemy.global_position):
				continue
			_conduct(parent, puddle.global_position + Vector3.UP * 0.1, enemy, color, make_info)
			hit.append(enemy)
	for node: Node in tree.get_nodes_in_group(METAL_GROUP):
		var metal := node as Node3D
		if metal.global_position.distance_to(point) > METAL_TOUCH:
			continue
		LightningArc.spawn(parent, point, metal.global_position + Vector3.UP * 0.1, color, 0.2, 0.8)
		for enemy: Enemy in _enemies(tree):
			if enemy in already_hit or enemy in hit:
				continue
			if enemy.global_position.distance_to(metal.global_position) <= METAL_REACH:
				_conduct(parent, metal.global_position + Vector3.UP * 0.1, enemy, color, make_info)
				hit.append(enemy)
	return hit


## Metal caído no chão por um tempo (espada do Esqueleto que morreu).
static func drop_metal(parent: Node, at: Vector3, lifetime: float = 12.0) -> void:
	var marker := Pools.acquire(&"fallen_metal", _new_metal, parent) as Node3D
	marker.global_position = at
	marker.rotation = Vector3(0.0, randf() * TAU, 0.0)
	marker.add_to_group(METAL_GROUP)
	Pools.release_after(marker, lifetime)


static func _conduct(parent: Node, from: Vector3, enemy: Enemy, color: Color, make_info: Callable) -> void:
	var aim := enemy.global_position + Vector3.UP * 1.0
	LightningArc.spawn(parent, from, aim, color, 0.25, 0.9)
	Vfx.sparks(parent, aim, color, 12, 4.0)
	var info: DamageInfo = make_info.call()
	info.amount *= CONDUCTED_FRACTION
	enemy.hurtbox.receive_hit(info)


static func _enemies(tree: SceneTree) -> Array[Enemy]:
	var result: Array[Enemy] = []
	for node: Node in tree.get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy != null and not enemy.health.is_dead:
			result.append(enemy)
	return result


## Espada largada no chão: lâmina de metal deitada (sai do grupo quando volta ao pool).
static func _new_metal() -> Node:
	var root := Node3D.new()
	root.name = "FallenMetal"
	var blade := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.9, 0.02, 0.07)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.55, 0.56, 0.6)
	material.metallic = 0.9
	material.roughness = 0.3
	box.material = material
	blade.mesh = box
	blade.position.y = 0.03
	root.add_child(blade)
	root.tree_exiting.connect(func() -> void:
		if root.is_in_group(METAL_GROUP):
			root.remove_from_group(METAL_GROUP))
	return root
