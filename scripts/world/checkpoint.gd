class_name Checkpoint
extends Node3D
## Fogueira de pedra: ao chegar perto, acende, cura o herói, guarda o ouro e salva.
## Morrendo depois disso, o herói volta para a última fogueira acesa.

signal lit(checkpoint: Checkpoint)

@export var fire_pit_scene: PackedScene
## Distância ao longo da trilha (m) onde fica a fogueira (ao lado da trilha).
@export var route_progress: float = 50.0
@export var activation_radius: float = 3.5
## Passando por ela na trilha, acende mesmo sem encostar (dentro deste raio).
@export var pass_radius: float = 14.0
@export var light_energy: float = 3.0
@export var flicker_amount: float = 0.6

var is_lit: bool = false

var _light: OmniLight3D
var _flicker_time: float = 0.0


func setup(terrain: TrailTerrain) -> void:
	global_position = terrain.ground_point(global_position)
	if fire_pit_scene != null:
		add_child(fire_pit_scene.instantiate())
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.55, 0.22)
	_light.omni_range = 9.0
	_light.shadow_enabled = false
	_light.position = Vector3.UP * 0.8
	_light.light_energy = 0.0
	add_child(_light)


func respawn_point() -> Vector3:
	return global_position + global_basis.z * 2.0 + Vector3.UP * 0.2


## Acende se o herói chegou perto, ou se já passou por ela na trilha (hero_progress) sem se afastar demais.
func try_activate(hero_position: Vector3, hero_progress: float = -INF) -> bool:
	if is_lit:
		return false
	var near := hero_position.distance_to(global_position) <= activation_radius
	var passed := hero_progress >= route_progress and hero_position.distance_to(global_position) <= pass_radius
	if not near and not passed:
		return false
	is_lit = true
	_light.shadow_enabled = true
	lit.emit(self)
	return true


## Já acesa num save anterior (Continuar): acende sem avisar ninguém.
func restore_lit() -> void:
	is_lit = true
	_light.shadow_enabled = true


func _process(delta: float) -> void:
	if _light == null or not is_lit:
		return
	_flicker_time += delta
	_light.light_energy = light_energy + sin(_flicker_time * 11.0) * flicker_amount * 0.5 \
			+ sin(_flicker_time * 23.0) * flicker_amount * 0.3
