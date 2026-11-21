class_name GameFeelData
extends Resource
## Impacto e "peso" do combate (GDD §6.7). Tempos em segundos reais. Valores em data/combat/game_feel.tres.

@export_group("Hitstop")
@export var hitstop_time_scale: float = 0.05
@export var hitstop_normal: float = 0.05
@export var hitstop_heavy: float = 0.1
@export var hitstop_parry: float = 0.08

@export_group("Finisher")
@export var finisher_time_scale: float = 0.2
@export var finisher_duration: float = 0.6
## FOV da câmera é multiplicado por isto durante o finisher (aproxima).
@export var finisher_fov_factor: float = 0.75

@export_group("Tremor de câmera")
@export var shake_heavy: float = 0.35
@export var shake_player_hurt: float = 0.5
@export var shake_storm: float = 0.9
@export var shake_max_offset: float = 0.3
@export var shake_decay: float = 2.5

@export_group("Flash de luz")
@export var flash_energy: float = 3.0
@export var flash_range: float = 7.0
