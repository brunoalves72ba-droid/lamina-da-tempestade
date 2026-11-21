class_name BossData
extends Resource
## Poderes especiais de um chefão (GDD §8.1). Fica dentro do EnemyData do chefão (campo `boss`).
## Cada poder tem aviso no chão (círculo vermelho) e não pode ser aparado: saia do círculo,
## esquive na hora do impacto ou bloqueie (reduz o dano). Rajada: as esferas podem ser aparadas.

enum Power {
	## Golpe no chão: onda de choque em volta do chefão.
	SLAM,
	## Salto: cai onde o herói estava, com onda de choque na aterrissagem.
	LEAP,
	## Rajada: várias esferas de energia, uma após a outra.
	VOLLEY,
}

## Nome mostrado na barra de vida do chefão.
@export var title: String = "Chefão"
@export var powers: Array[Power] = [Power.SLAM]
## Cor dos efeitos dos poderes (onda, esferas, contorno em fúria).
@export var power_color: Color = Color(1.0, 0.35, 0.1)
## Tempo entre poderes (o chefão também ataca normalmente entre eles).
@export var power_cooldown: float = 7.0
## Espera antes do primeiro poder depois de perceber o herói.
@export var first_power_delay: float = 3.0
## Abaixo desta fração de vida o chefão entra em fúria: ruge, brilha e usa poderes mais rápido.
@export var rage_health_fraction: float = 0.5
@export var rage_cooldown_multiplier: float = 0.6

@export_group("Golpe no chão")
@export var slam_radius: float = 4.5
@export var slam_damage: float = 30.0
## Aviso antes do impacto (a animação é sincronizada com ele).
@export var slam_windup: float = 1.3
@export var slam_recovery: float = 0.6

@export_group("Salto")
@export var leap_radius: float = 3.5
@export var leap_damage: float = 34.0
## Agachar antes de saltar.
@export var leap_windup: float = 0.5
@export var leap_air_time: float = 0.85
@export var leap_height: float = 4.0
@export var leap_max_distance: float = 14.0
@export var leap_recovery: float = 0.7

@export_group("Rajada")
@export var volley_count: int = 5
@export var volley_interval: float = 0.28
@export var volley_damage: float = 12.0
@export var volley_flight_time: float = 0.7
@export var volley_windup: float = 0.8
@export var volley_recovery: float = 0.5
