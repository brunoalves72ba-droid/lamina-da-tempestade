class_name PowerCaster
extends Node
## Os 3 poderes de raio do herói (GDD §6.5): recargas, custo de Carga e execução de cada efeito.
## Os estados do herói (Idle/Attack/Dash/Power) decidem quando lançar; aqui fica o "o quê".

signal power_used(slot: int)

const AIM_HEIGHT: float = 1.1
const CAST_HEIGHT: float = 1.3
const STORM_SKY_HEIGHT: float = 14.0
const STORM_BOLTS: int = 3
const STORM_SPREAD: float = 0.6

@export var powers: Array[PowerData] = []

var player: Player

var _cooldowns: Array[Cooldown] = []


func _ready() -> void:
	player = owner as Player
	for power: PowerData in powers:
		var cooldown := Cooldown.new()
		cooldown.duration = power.cooldown
		add_child(cooldown)
		_cooldowns.append(cooldown)


func count() -> int:
	return powers.size()


func power(slot: int) -> PowerData:
	return powers[slot]


func cooldown(slot: int) -> Cooldown:
	return _cooldowns[slot]


## Pronto = recarga zerada e Carga suficiente (não olha o alvo).
func is_ready(slot: int) -> bool:
	if slot < 0 or slot >= powers.size():
		return false
	return _cooldowns[slot].is_ready and player.charge.value >= powers[slot].charge_cost


func can_use(slot: int) -> bool:
	return is_ready(slot) and player.target != null


func reset() -> void:
	for cooldown_node: Cooldown in _cooldowns:
		cooldown_node.reset()


func execute(slot: int) -> void:
	var data := powers[slot]
	var target := player.target
	if target == null:
		return
	_cooldowns[slot].start(data.cooldown)
	if data.charge_cost > 0.0:
		player.charge.consume_all()
	match data.kind:
		PowerData.Kind.VOLTAIC_BLADE:
			_voltaic_blade(data, target)
		PowerData.Kind.CHAIN_LIGHTNING:
			_chain_lightning(data, target)
		PowerData.Kind.STORM_FURY:
			_storm_fury(data, target)
	Events.power_unleashed.emit(data.kind, target.global_position, player.lightning_color())
	power_used.emit(slot)


## Corte eletrificado no alvo; interrompe o aviso dele (quebra a guarda).
func _voltaic_blade(data: PowerData, target: Enemy) -> void:
	var color := player.lightning_color()
	var from := player.global_position + Vector3.UP * CAST_HEIGHT
	var to := _aim(target)
	LightningArc.spawn(_vfx_parent(), from, to, color, 0.22, 1.6, 2.5)
	SfxLibrary.play(player, &"zap")
	if target.is_telegraphing():
		target.interrupt_attack()
	target.hurtbox.receive_hit(player.build_power_info(data.damage_multiplier, data.is_heavy))
	player.charge.add(player.data.charge_power_hit)


## Raio que sai do alvo e salta para os inimigos mais próximos ainda não atingidos.
func _chain_lightning(data: PowerData, target: Enemy) -> void:
	var color := player.lightning_color()
	var hit: Array[Enemy] = []
	var from := player.global_position + Vector3.UP * CAST_HEIGHT
	var current := target
	for multiplier: float in data.chain_multipliers:
		if current == null:
			break
		LightningArc.spawn(_vfx_parent(), from, _aim(current), color, 0.25, 1.2, 1.5)
		current.hurtbox.receive_hit(player.build_power_info(multiplier, data.is_heavy))
		hit.append(current)
		from = _aim(current)
		current = _nearest_unhit(from, hit, data.chain_range)
	SfxLibrary.play(player, &"zap")
	if not hit.is_empty():
		player.charge.add(player.data.charge_power_hit)


## Raio do céu no alvo + choque em área ao redor.
func _storm_fury(data: PowerData, target: Enemy) -> void:
	var color := player.lightning_color()
	var ground := target.global_position
	for i: int in STORM_BOLTS:
		var jitter := Vector3(randf_range(-STORM_SPREAD, STORM_SPREAD), 0.0, randf_range(-STORM_SPREAD, STORM_SPREAD))
		var flash := 6.0 if i == 0 else 0.0
		LightningArc.spawn(_vfx_parent(), ground + jitter + Vector3.UP * STORM_SKY_HEIGHT, ground + Vector3.UP * 0.2,
				color, 0.45, 4.0, flash)
	SfxLibrary.play(player, &"thunder")
	var others: Array[Enemy] = []
	for enemy: Enemy in player.targeting.candidates():
		if enemy != target and enemy.global_position.distance_to(ground) <= data.area_radius:
			others.append(enemy)
	target.hurtbox.receive_hit(player.build_power_info(data.damage_multiplier, data.is_heavy))
	for enemy: Enemy in others:
		LightningArc.spawn(_vfx_parent(), ground + Vector3.UP * 0.3, _aim(enemy), color, 0.3, 1.2)
		enemy.hurtbox.receive_hit(player.build_power_info(data.area_multiplier, false))


func _nearest_unhit(origin: Vector3, hit: Array[Enemy], max_range: float) -> Enemy:
	var best: Enemy = null
	var best_distance := max_range
	for enemy: Enemy in player.targeting.candidates():
		if enemy in hit:
			continue
		var distance := origin.distance_to(_aim(enemy))
		if distance <= best_distance:
			best_distance = distance
			best = enemy
	return best


func _aim(enemy: Enemy) -> Vector3:
	return enemy.global_position + Vector3.UP * AIM_HEIGHT


func _vfx_parent() -> Node:
	return player.get_parent()
