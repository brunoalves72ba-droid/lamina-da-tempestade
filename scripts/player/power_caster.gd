class_name PowerCaster
extends Node
## Os 3 poderes de raio do herói (GDD §6.5): recargas, custo de Carga e execução de cada efeito.
## Os estados do herói (Idle/Attack/Dash/Power) decidem quando lançar; aqui fica o "o quê".

signal power_used(slot: int)

const AIM_HEIGHT: float = 1.1
## Salto da Corrente em Cadeia a partir de inimigo com armadura de metal (×alcance).
const METAL_CHAIN_BONUS: float = 1.6
const STORM_SHOCK_TIME: float = 3.0
## Raios extras caindo em volta do alvo na Fúria da Tempestade.
const STORM_BOLTS: int = 4

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
	var from := player.blade_tip_position()
	var to := _aim(target)
	var parent := _vfx_parent()
	LightningArc.spawn(parent, from, to, color, 0.25, 1.8, 0.0)
	var facing := target.global_position - player.global_position
	Vfx.slash_arc(parent, to, facing, color, 1.8, 0.25, 0.5)
	Vfx.slash_arc(parent, to + Vector3.UP * 0.2, facing, color.lightened(0.4), 1.4, 0.2, -0.4)
	Vfx.sparks(parent, to, color, 40, 8.0, 0.45)
	Vfx.shockwave(parent, target.global_position, 2.2, color, 0.3)
	Vfx.flash_light(parent, to, color, 5.0, 7.0, 0.2)
	SfxLibrary.play(player, &"zap")
	if target.is_telegraphing():
		target.interrupt_attack()
	target.hurtbox.receive_hit(player.build_power_info(data.damage_multiplier, data.is_heavy))
	Conduction.discharge(get_tree(), target.global_position, color,
			player.build_power_info.bind(data.damage_multiplier * 0.5, false), [target])
	player.charge.add(player.data.charge_power_hit)


## Raio que sai do alvo e salta para os inimigos mais próximos ainda não atingidos.
func _chain_lightning(data: PowerData, target: Enemy) -> void:
	var color := player.lightning_color()
	var hit: Array[Enemy] = []
	var from := player.blade_tip_position()
	var current := target
	var parent := _vfx_parent()
	Vfx.flash_light(parent, from, color, 3.0, 6.0, 0.2)
	for multiplier: float in data.chain_multipliers:
		if current == null:
			break
		LightningArc.spawn(parent, from, _aim(current), color, 0.35, 1.4, 0.0)
		LightningArc.spawn(parent, from, _aim(current), color.lightened(0.5), 0.2, 0.5, 0.0)
		Vfx.sparks(parent, _aim(current), color, 22, 6.0)
		Vfx.shockwave(parent, current.global_position, 1.3, color, 0.25)
		current.hurtbox.receive_hit(player.build_power_info(multiplier, data.is_heavy))
		hit.append(current)
		hit.append_array(Conduction.discharge(get_tree(), current.global_position, color,
				player.build_power_info.bind(multiplier, false), hit))
		from = _aim(current)
		# Armadura de metal conduz: o próximo salto alcança mais longe.
		var reach := data.chain_range * (METAL_CHAIN_BONUS if current.is_metal_armored() else 1.0)
		current = _nearest_unhit(from, hit, reach)
	SfxLibrary.play(player, &"zap")
	if not hit.is_empty():
		player.charge.add(player.data.charge_power_hit)


## Raio do céu no alvo + choque em área ao redor.
func _storm_fury(data: PowerData, target: Enemy) -> void:
	var color := player.lightning_color()
	var ground := target.global_position
	var parent := _vfx_parent()
	Vfx.lightning_strike(parent, ground, color, data.area_radius, true)
	for i: int in range(1, STORM_BOLTS + 2):
		var angle := TAU * i / (STORM_BOLTS + 1) + randf() * 0.5
		var spot := ground + Vector3(cos(angle), 0.0, sin(angle)) * data.area_radius * randf_range(0.5, 0.9)
		get_tree().create_timer(0.06 * i, false).timeout.connect(func() -> void:
			Vfx.lightning_strike(parent, spot, color, 1.4, false))
	Vfx.shockwave(parent, ground, data.area_radius * 1.6, color, 0.5)
	Vfx.shockwave(parent, ground, data.area_radius * 0.9, Color.WHITE, 0.3)
	SfxLibrary.play(player, &"thunder")
	var others: Array[Enemy] = []
	for enemy: Enemy in player.targeting.candidates():
		if enemy != target and enemy.global_position.distance_to(ground) <= data.area_radius:
			others.append(enemy)
	target.hurtbox.receive_hit(player.build_power_info(data.damage_multiplier, data.is_heavy, STORM_SHOCK_TIME))
	var struck: Array[Enemy] = [target]
	struck.append_array(others)
	Conduction.discharge(get_tree(), ground, color, player.build_power_info.bind(data.area_multiplier, false), struck)
	for enemy: Enemy in others:
		LightningArc.spawn(parent, ground + Vector3.UP * 0.3, _aim(enemy), color, 0.3, 1.2)
		Vfx.sparks(parent, _aim(enemy), color, 16, 5.0)
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
