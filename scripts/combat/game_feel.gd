class_name GameFeel
extends Node
## Peso do combate (GDD §6.7), reagindo aos eventos globais:
## hitstop nos golpes, Descarga visual no parry, tremor de câmera e câmera lenta no finisher.
## Funciona com qualquer Camera3D ativa (usa h_offset/v_offset e fov).

## Altura do peito (onde saem as faíscas do impacto), em metros, para escala 1.
const IMPACT_HEIGHT: float = 1.2
const PLAYER_HIT_COLOR := Color(1.0, 0.35, 0.2)
const BLOOD_COLOR := Color(0.35, 0.02, 0.02)

@export var data: GameFeelData

var _trauma: float = 0.0
var _fov_tween: Tween
var _base_fov: float = 0.0


func _ready() -> void:
	assert(data != null, "GameFeel precisa de GameFeelData")
	Hitstop.reset()
	Events.damage_taken.connect(_on_damage_taken)
	Events.parry_succeeded.connect(_on_parry_succeeded)
	Events.wave_finisher.connect(_on_wave_finisher)
	Events.power_unleashed.connect(_on_power_unleashed)
	Events.shake_requested.connect(add_shake)


func _exit_tree() -> void:
	Hitstop.reset()


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var real_delta := delta / maxf(Engine.time_scale, 0.01)
	_trauma = maxf(0.0, _trauma - data.shake_decay * real_delta)
	var amount := _trauma * _trauma * data.shake_max_offset
	camera.h_offset = randf_range(-amount, amount)
	camera.v_offset = randf_range(-amount, amount)


func add_shake(amount: float) -> void:
	_trauma = minf(1.0, _trauma + amount)


func _on_damage_taken(target: Node3D, info: DamageInfo) -> void:
	var chest := target.global_position + Vector3.UP * IMPACT_HEIGHT * target.scale.y
	if target is Player:
		add_shake(data.shake_player_hurt)
		Hitstop.apply(get_tree(), data.hitstop_time_scale, data.hitstop_normal)
		Vfx.sparks(target.get_parent(), chest, PLAYER_HIT_COLOR, 16, 4.0)
		return
	if info.source is Player:
		var heavy := info.is_heavy
		var hero := info.source as Player
		var color := hero.lightning_color()
		var enemy := target as Enemy
		if enemy != null:
			chest = enemy.global_position + Vector3.UP * IMPACT_HEIGHT * enemy.data.body_scale
		Vfx.sparks(target.get_parent(), chest, color, 26 if heavy else 14, 7.0 if heavy else 5.0)
		Vfx.sparks(target.get_parent(), chest, BLOOD_COLOR, 8, 3.0, 0.4, -14.0)
		if heavy:
			Vfx.shockwave(target.get_parent(), target.global_position, 1.6, color, 0.25)
		Hitstop.apply(get_tree(), data.hitstop_time_scale, data.hitstop_heavy if heavy else data.hitstop_normal)
		if heavy:
			add_shake(data.shake_heavy)


## Descarga (GDD §6.2): arco elétrico do herói até o atacante, com flash de luz.
func _on_parry_succeeded(defender: Node3D, attacker: Node3D) -> void:
	Hitstop.apply(get_tree(), data.hitstop_time_scale, data.hitstop_parry)
	var hero := defender as Player
	if hero == null or attacker == null or not is_instance_valid(attacker):
		return
	var height := Vector3.UP * 1.2
	LightningArc.spawn(hero.get_parent(), hero.global_position + height, attacker.global_position + height,
			hero.lightning_color(), 0.25, 1.4, data.flash_energy)


## Último inimigo da onda morto por golpe forte: câmera lenta + aproximação (GDD §6.7).
func _on_wave_finisher(_enemy: Node3D) -> void:
	Hitstop.apply(get_tree(), data.finisher_time_scale, data.finisher_duration)
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	if _fov_tween != null and _fov_tween.is_running():
		_fov_tween.kill()
	else:
		_base_fov = camera.fov
	camera.fov = _base_fov
	_fov_tween = create_tween().set_ignore_time_scale(true)
	_fov_tween.tween_property(camera, "fov", _base_fov * data.finisher_fov_factor, data.finisher_duration * 0.3) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_fov_tween.tween_property(camera, "fov", _base_fov, data.finisher_duration * 0.7) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _on_power_unleashed(kind: int, _at_position: Vector3, _color: Color) -> void:
	if kind == PowerData.Kind.STORM_FURY:
		add_shake(data.shake_storm)
