class_name PlayerData
extends Resource
## Status e tempos do herói (GDD §6.1, §6.2, §6.4, §6.8). Valores reais ficam em data/player/*.tres.

@export_group("Status")
@export var max_health: float = 100.0
@export_range(0.0, 0.9) var damage_reduction: float = 0.0
## Fração da vida máxima recuperada ao limpar um encontro.
@export var encounter_heal_fraction: float = 0.2

@export_group("Combo")
@export var input_buffer_time: float = 0.2
@export var combo_reset_time: float = 0.6
@export var melee_range: float = 2.5

@export_group("Parry")
@export var parry_window: float = 0.25
@export var parry_recovery: float = 0.4
@export var counter_multiplier: float = 2.0

@export_group("Dardo de Raio e Passo Relâmpago")
@export var bolt_damage_multiplier: float = 0.5
@export var bolt_cooldown: float = 1.5
@export var bolt_cast_time: float = 0.12
@export var dash_duration: float = 0.3
@export var dash_max_distance: float = 12.0
## Distância do alvo em que o Passo Relâmpago termina.
@export var dash_stop_distance: float = 1.8

@export_group("Carga Estática")
@export var charge_max: float = 100.0
@export var charge_combo_hit: float = 4.0
@export var charge_parry: float = 20.0
@export var charge_counter: float = 10.0
@export var charge_power_hit: float = 5.0
@export var charge_damage_loss: float = 10.0

@export_group("Movimento livre")
@export var move_speed: float = 4.2
@export var sprint_speed: float = 6.8
@export var acceleration: float = 18.0
@export var deceleration: float = 24.0
## Giro em rad/s ao andar; nas ações de combate o giro é instantâneo.
@export var turn_speed: float = 12.0
@export var gravity: float = 24.0
@export var attack_lunge_distance: float = 0.6
## Distância do alvo abaixo da qual o golpe não avança (evita empurrar o inimigo).
@export var lunge_min_target_distance: float = 1.7
## Alcance da "mira suave": sem travar, os golpes viram para o inimigo mais perto daqui.
@export var soft_aim_range: float = 3.5

@export_group("Esquiva e bloqueio")
@export var dodge_distance: float = 4.0
@export var dodge_duration: float = 0.42
@export var dodge_invulnerable_time: float = 0.3
@export var dodge_cooldown: float = 0.15
@export_range(0.0, 1.0) var block_reduction: float = 0.7
@export var block_move_speed: float = 1.8

@export_group("Reações")
@export var hurt_time: float = 0.3
@export var hurt_knockback_speed: float = 4.0
