class_name StormSky
extends DirectionalLight3D
## Relâmpagos distantes (GDD §9): clarões de tempos em tempos, mais frequentes com a Carga cheia
## e imediatos quando a Fúria da Tempestade cai.

@export var player: Player
@export var flash_energy: float = 1.6
@export var calm_interval_min: float = 6.0
@export var calm_interval_max: float = 12.0
@export var charged_interval_min: float = 1.5
@export var charged_interval_max: float = 3.0
@export var flash_time: float = 0.35

var _timer: float = 0.0
var _tween: Tween


func _ready() -> void:
	light_energy = 0.0
	_timer = randf_range(calm_interval_min, calm_interval_max)
	Events.power_unleashed.connect(_on_power_unleashed)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	var charged := player != null and player.charge.is_full
	_timer = randf_range(charged_interval_min, charged_interval_max) if charged \
			else randf_range(calm_interval_min, calm_interval_max)
	flash(flash_energy)


func flash(energy: float) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "light_energy", energy, flash_time * 0.1)
	_tween.tween_property(self, "light_energy", energy * 0.2, flash_time * 0.2)
	_tween.tween_property(self, "light_energy", energy * 0.8, flash_time * 0.1)
	_tween.tween_property(self, "light_energy", 0.0, flash_time * 0.6)


func _on_power_unleashed(kind: int, _at_position: Vector3, _color: Color) -> void:
	if kind == PowerData.Kind.STORM_FURY:
		flash(flash_energy * 2.0)
