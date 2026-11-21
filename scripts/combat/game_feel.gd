class_name GameFeel
extends Node
## Peso do combate (GDD §6.7), reagindo aos eventos globais:
## hitstop nos golpes, Descarga visual no parry, tremor de câmera e câmera lenta no finisher.
## Funciona com qualquer Camera3D ativa (usa h_offset/v_offset e fov).

## Altura do peito (onde saem as faíscas do impacto), em metros, para escala 1.
const IMPACT_HEIGHT: float = 1.2
const PLAYER_HIT_COLOR := Color(1.0, 0.35, 0.2)
const CLASH_COLOR := Color(1.0, 0.75, 0.4)
const FLASH_TIME: float = 0.14

@export var data: GameFeelData

var _trauma: float = 0.0
var _fov_tween: Tween
var _base_fov: float = 0.0
var _flash_rect: ColorRect
var _flash_tween: Tween


func _ready() -> void:
	assert(data != null, "GameFeel precisa de GameFeelData")
	Hitstop.reset()
	Events.damage_taken.connect(_on_damage_taken)
	Events.parry_succeeded.connect(_on_parry_succeeded)
	Events.wave_finisher.connect(_on_wave_finisher)
	Events.power_unleashed.connect(_on_power_unleashed)
	Events.shake_requested.connect(add_shake)
	Events.screen_flash_requested.connect(flash_screen)
	_build_flash_layer()


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
		if not info.is_power:
			Gore.blood_hit(target.get_parent(), chest, target.global_position, heavy or info.is_critical)
		if heavy:
			Vfx.shockwave(target.get_parent(), target.global_position, 1.6, color, 0.25)
			flash_screen(color, 0.12)
		if info.is_critical:
			Vfx.sparks(target.get_parent(), chest, Color(1.0, 0.95, 0.6), 20, 8.0, 0.3)
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
	# Choque de lâminas: faíscas metálicas no ponto de contato e clarão.
	var contact := hero.blade_tip_position().lerp(attacker.global_position + height, 0.35)
	Vfx.sparks(hero.get_parent(), contact, CLASH_COLOR, 40, 9.0, 0.35, -9.0)
	Vfx.sparks(hero.get_parent(), contact, Color.WHITE, 14, 12.0, 0.18)
	Vfx.flash_light(hero.get_parent(), contact, CLASH_COLOR, 3.0, 5.0, 0.15)
	flash_screen(Color(0.75, 0.9, 1.0), 0.22)
	add_shake(0.25)
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


func _on_power_unleashed(kind: int, _at_position: Vector3, color: Color) -> void:
	if kind == PowerData.Kind.STORM_FURY:
		add_shake(data.shake_storm)
		flash_screen(color.lerp(Color.WHITE, 0.5), 0.4)
	else:
		flash_screen(color, 0.1)


## Clarão sutil na tela inteira (aditivo), some em FLASH_TIME.
func flash_screen(color: Color, strength: float) -> void:
	if _flash_rect == null:
		return
	if _flash_tween != null:
		_flash_tween.kill()
	_flash_rect.color = Color(color.r, color.g, color.b, clampf(strength, 0.0, 1.0) * 0.6)
	_flash_tween = create_tween().set_ignore_time_scale(true)
	_flash_tween.tween_property(_flash_rect, "color:a", 0.0, FLASH_TIME + strength * 0.2)


func _build_flash_layer() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_flash_rect = ColorRect.new()
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_rect.color = Color(1, 1, 1, 0)
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_flash_rect.material = material
	layer.add_child(_flash_rect)
