class_name Weather
extends Node
## Ciclo dia/noite e clima dinâmico (GDD §9.1). A WorldLevel cria e chama setup().
## - Hora do dia avança continuamente: sol/lua giram, cor e força da luz, céu e ambiente mudam.
##   À noite (GameState.night_factor) os inimigos atacam mais rápido e mais forte.
## - Clima alterna sozinho entre Limpo, Chuva e Tempestade, com transição suave. Chuva cai em volta
##   da câmera; na Tempestade caem raios distantes e GameState.storm_intensity sobe: os poderes de
##   raio do herói ficam mais fortes e eletrocutam por mais tempo.

signal weather_changed(state: Condition)

enum Condition { CLEAR, RAIN, STORM }

const NAMES: Array[String] = ["Céu limpo", "Chuva", "Tempestade"]
const MOON_COLOR := Color(0.6, 0.68, 0.92)
const SUN_COLOR := Color(1.0, 0.86, 0.7)
const DUSK_COLOR := Color(1.0, 0.55, 0.35)
const RAIN_AREA: float = 34.0
const RAIN_DROPS: int = 1400
const TRANSITION_SPEED: float = 0.12

## Duração de um dia inteiro (s de jogo).
@export var day_length: float = 600.0
@export var start_hour: float = 20.5
@export var weather_change_min: float = 70.0
@export var weather_change_max: float = 150.0
## Chance de cada clima quando muda (limpo, chuva, tempestade).
@export var weights: Array[float] = [0.35, 0.3, 0.35]
@export var distant_strike_min: float = 3.5
@export var distant_strike_max: float = 8.0

var hour: float = 20.5
var state: Condition = Condition.CLEAR
## 0..1, com transição suave até o alvo do clima atual.
var rain: float = 0.0
var storm: float = 0.0
var daylight: float = 0.0

var _environment: Environment
var _sky: PanoramaSkyMaterial
var _sun: DirectionalLight3D
var _storm_sky: StormSky
var _terrain: TrailTerrain
var _player: Node3D
var _rain_particles: GPUParticles3D
var _change_timer: float = 0.0
var _strike_timer: float = 0.0
var _base_sky_energy: float = 1.0
var _base_ambient: float = 0.7
var _base_fog_density: float = 0.02


func setup(environment: Environment, sun: DirectionalLight3D, storm_sky: StormSky, terrain: TrailTerrain,
		player: Node3D) -> void:
	_environment = environment
	_sky = environment.sky.sky_material as PanoramaSkyMaterial if environment.sky != null else null
	_sun = sun
	_storm_sky = storm_sky
	_terrain = terrain
	_player = player
	_base_sky_energy = _sky.energy_multiplier if _sky != null else 1.0
	_base_ambient = environment.ambient_light_energy
	_base_fog_density = environment.volumetric_fog_density
	hour = start_hour
	_change_timer = randf_range(weather_change_min * 0.5, weather_change_max * 0.5)
	_build_rain()
	set_state(Condition.CLEAR, true)
	_apply()


## Força um clima (testes, eventos de história).
func set_state(new_state: Condition, instant: bool = false) -> void:
	state = new_state
	if instant:
		rain = _rain_target()
		storm = _storm_target()
	weather_changed.emit(state)
	Events.weather_changed.emit(NAMES[state], state == Condition.STORM)


func is_night() -> bool:
	return daylight < 0.5


func clock_text() -> String:
	return "%02d:%02d" % [int(hour) % 24, int(fmod(hour, 1.0) * 60.0)]


func _process(delta: float) -> void:
	if _environment == null:
		return
	hour = fmod(hour + delta * 24.0 / day_length, 24.0)
	_change_timer -= delta
	if _change_timer <= 0.0:
		_change_timer = randf_range(weather_change_min, weather_change_max)
		set_state(_pick_state())
	rain = move_toward(rain, _rain_target(), TRANSITION_SPEED * delta)
	storm = move_toward(storm, _storm_target(), TRANSITION_SPEED * delta)
	_apply()
	_follow_camera()
	if storm > 0.5:
		_strike_timer -= delta
		if _strike_timer <= 0.0:
			_strike_timer = randf_range(distant_strike_min, distant_strike_max)
			_distant_strike()


func _apply() -> void:
	# Luz do dia: 0 à noite, 1 de dia; amanhecer 5h–7h e anoitecer 18h–20h.
	daylight = smoothstep(5.0, 7.0, hour) * (1.0 - smoothstep(18.0, 20.0, hour))
	var dusk := (1.0 - absf(daylight - 0.5) * 2.0) * 0.8
	var gloom := 1.0 - rain * 0.55
	if _sky != null:
		_sky.energy_multiplier = lerpf(_base_sky_energy, 1.1, daylight) * gloom
	_environment.ambient_light_energy = lerpf(_base_ambient, 1.0, daylight) * lerpf(1.0, 0.7, rain)
	_environment.volumetric_fog_density = _base_fog_density * lerpf(1.0, 2.2, rain)
	_environment.fog_density = 0.014 * lerpf(1.0, 2.0, rain)
	if _sun != null:
		var color := MOON_COLOR.lerp(SUN_COLOR, daylight).lerp(DUSK_COLOR, dusk * 0.6)
		_sun.light_color = color
		_sun.light_energy = lerpf(0.9, 1.7, daylight) * gloom
		# Sol (ou lua) gira pelo céu conforme a hora.
		var elevation := deg_to_rad(lerpf(55.0, 25.0, absf(fmod(hour + 6.0, 12.0) - 6.0) / 6.0))
		_sun.rotation = Vector3(-elevation, deg_to_rad(hour * 15.0), 0.0)
	if _rain_particles != null:
		_rain_particles.amount_ratio = rain
		_rain_particles.emitting = rain > 0.02
	if _storm_sky != null:
		_storm_sky.calm_interval_min = lerpf(6.0, 1.2, storm)
		_storm_sky.calm_interval_max = lerpf(12.0, 3.5, storm)
	GameState.night_factor = 1.0 - daylight
	GameState.storm_intensity = storm


func _pick_state() -> Condition:
	var total := 0.0
	for weight: float in weights:
		total += weight
	var roll := randf() * total
	for i: int in weights.size():
		roll -= weights[i]
		if roll <= 0.0:
			return i as Condition
	return Condition.CLEAR


func _rain_target() -> float:
	return 0.0 if state == Condition.CLEAR else (0.6 if state == Condition.RAIN else 1.0)


func _storm_target() -> float:
	return 1.0 if state == Condition.STORM else 0.0


## Raio caindo longe do herói (só visual + trovão atrasado pela distância).
func _distant_strike() -> void:
	if _player == null or _terrain == null:
		return
	var angle := randf() * TAU
	var distance := randf_range(22.0, 45.0)
	var spot := _player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * distance
	spot = _terrain.ground_point(spot)
	Vfx.lightning_strike(get_parent(), spot, Color(0.75, 0.85, 1.0), 3.0, false)
	if _storm_sky != null:
		_storm_sky.flash(_storm_sky.flash_energy * 1.4)
	get_tree().create_timer(distance / 120.0, false).timeout.connect(func() -> void:
		SfxLibrary.play(self, &"thunder"))


func _follow_camera() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera != null and _rain_particles != null:
		_rain_particles.global_position = camera.global_position + Vector3.UP * 12.0


## Chuva: gotas finas e esticadas caindo numa caixa que acompanha a câmera.
func _build_rain() -> void:
	_rain_particles = GPUParticles3D.new()
	_rain_particles.name = "Rain"
	_rain_particles.amount = RAIN_DROPS
	_rain_particles.lifetime = 0.9
	_rain_particles.visibility_aabb = AABB(Vector3(-RAIN_AREA, -30.0, -RAIN_AREA), Vector3(RAIN_AREA * 2.0, 40.0, RAIN_AREA * 2.0))
	_rain_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(RAIN_AREA * 0.5, 1.0, RAIN_AREA * 0.5)
	process.direction = Vector3(0.08, -1.0, 0.04)
	process.spread = 2.0
	process.initial_velocity_min = 22.0
	process.initial_velocity_max = 28.0
	process.gravity = Vector3(0.0, -10.0, 0.0)
	_rain_particles.process_material = process
	var drop := QuadMesh.new()
	drop.size = Vector2(0.015, 0.55)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.7, 0.75, 0.85, 0.28)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	drop.material = material
	_rain_particles.draw_pass_1 = drop
	_rain_particles.emitting = false
	add_child(_rain_particles)
