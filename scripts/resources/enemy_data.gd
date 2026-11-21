class_name EnemyData
extends Resource
## Status, tempos e comportamento de um tipo de inimigo (GDD §8). Valores em data/enemies/*.tres.

enum AttackKind { MELEE, RANGED }
## Papel do inimigo: Soldado (espada e escudo; é o que aparece de extra nas ondas),
## Conjuradora (ataque à distância), Elite (garras, dois golpes), Chefão (poderes do BossData).
enum ModelVariant { SOLDIER, CROSSBOWMAN, ELITE, BOSS }

@export var display_name: String = "Soldado"
@export var max_health: float = 40.0
@export var attack_damage: float = 12.0
## Personagem da Mixamo (texturizado, esqueleto `mixamorig_*`).
@export var model: PackedScene
## Escala do modelo; colisão, área de dano e alcance do golpe acompanham.
@export var body_scale: float = 1.0
@export var model_variant: ModelVariant = ModelVariant.SOLDIER
## Animação do golpe corpo a corpo (biblioteca de combate).
@export var strike_animation: StringName = &"enemy_strike"
## Poderes de chefão; vazio para inimigos comuns.
@export var boss: BossData
## Espada que o chefão deixa ao ser derrotado pela primeira vez.
@export var sword_drop: SwordItem

@export_group("Visual demoníaco")
## Força da corrupção (veias e rachaduras de brasa) sobre o modelo, 0..1.
@export_range(0.0, 1.0) var corruption: float = 0.55
@export var corruption_color: Color = Color(1.0, 0.28, 0.06)
@export var eye_color: Color = Color(1.0, 0.2, 0.05)
## Posição de um olho no espaço do osso da cabeça (o outro é espelhado em x); zero = sem olhos.
@export var eye_offset: Vector3 = Vector3(0.032, 0.075, 0.095)
@export var aura_color: Color = Color(0.12, 0.02, 0.08)

@export_group("IA")
## Investida: avança correndo e golpeia de longe (0 = não faz).
@export var charge_chance: float = 0.0
@export var charge_min_distance: float = 4.0
@export var charge_speed: float = 9.0
## Defesa: chance de erguer a guarda quando o herói ataca (só com escudo), e de contra-atacar
## logo depois de defender.
@export var block_chance: float = 0.0
@export var counter_chance: float = 0.0
## Flanqueia: em grupo, se espalha em volta do herói em vez de ficar todo na frente.
@export var flanks: bool = true
## Ouro e experiência ganhos ao derrotar (GDD §8).
@export var gold_reward: int = 10
@export var xp_reward: int = 20

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
@export var projectile_color: Color = Color(1.0, 0.45, 0.1)

@export_group("Movimento")
## Distância que o inimigo mantém do herói enquanto está em guarda.
@export var engage_distance: float = 2.0
@export var position_tolerance: float = 0.5
@export var move_speed: float = 2.5
@export var separation_radius: float = 1.4

@export_group("Movimento livre")
## Percebe o herói a esta distância (ou ao ser atingido).
@export var aggro_range: float = 14.0
## Correndo para alcançar o herói (longe da distância de guarda).
@export var run_speed: float = 3.8
## Andando de lado em volta do herói enquanto espera a vez de atacar.
@export var strafe_speed: float = 1.3
@export var strafe_switch_min: float = 1.5
@export var strafe_switch_max: float = 3.5
## Alcance real do golpe corpo a corpo: durante o aviso, avança se estiver mais longe.
@export var attack_reach: float = 2.1
@export var acceleration: float = 10.0
@export var turn_speed: float = 8.0
@export var gravity: float = 24.0

@export_group("Reações")
@export var stun_time: float = 1.5
## Com postura (Elite), golpes fortes não fazem cambalear.
@export var has_poise: bool = false
@export var stagger_time: float = 0.35
@export var knockback_speed: float = 3.5
## Animação de entrada; o inimigo não ataca nem recebe dano nesse tempo (GDD §5).
@export var spawn_time: float = 1.0
