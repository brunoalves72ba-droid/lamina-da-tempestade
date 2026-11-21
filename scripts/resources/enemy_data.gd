class_name EnemyData
extends Resource
## Status, tempos e comportamento de um tipo de inimigo (GDD §8). Valores em data/enemies/*.tres.

enum AttackKind { MELEE, RANGED }
## Visual do modelo: Soldado (espada e escudo), Besteiro (besta), Elite (espada, escudo e chifres).
enum ModelVariant { SOLDIER, CROSSBOWMAN, ELITE }

@export var display_name: String = "Soldado"
@export var max_health: float = 40.0
@export var attack_damage: float = 12.0
@export var body_color: Color = Color(0.42, 0.13, 0.12)
@export var body_scale: float = 1.0
@export var model_variant: ModelVariant = ModelVariant.SOLDIER
## Ouro ganho ao derrotar (GDD §8).
@export var gold_reward: int = 10

@export_group("Ataque")
@export var attack_kind: AttackKind = AttackKind.MELEE
## Duração do aviso antes do impacto (GDD §6.2).
@export var telegraph_time: float = 0.8
@export var strike_active_time: float = 0.1
@export var recover_time: float = 0.6
## Golpes seguidos por ataque (Elite = 2): cada um tem o seu aviso e pode ser aparado.
@export var strikes_per_attack: int = 1
## Só para RANGED: o virote sai este tempo antes do impacto e chega quando o aviso termina.
@export var projectile_flight_time: float = 0.35

@export_group("Movimento")
## Distância que o inimigo mantém do herói enquanto está em guarda.
@export var engage_distance: float = 2.0
@export var position_tolerance: float = 0.5
@export var move_speed: float = 2.5
@export var separation_radius: float = 1.4

@export_group("Reações")
@export var stun_time: float = 1.5
## Animação de entrada; o inimigo não ataca nem recebe dano nesse tempo (GDD §5).
@export var spawn_time: float = 1.0
