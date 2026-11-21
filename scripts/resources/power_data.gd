class_name PowerData
extends Resource
## Um poder de raio (GDD §6.5). Valores em data/powers/*.tres.

enum Kind { VOLTAIC_BLADE, CHAIN_LIGHTNING, STORM_FURY }

@export var kind: Kind = Kind.VOLTAIC_BLADE
@export var display_name: String = "Lâmina Voltaica"
@export var cooldown: float = 6.0
## Carga Estática necessária (e consumida inteira) para usar. 0 = só cooldown.
@export var charge_cost: float = 0.0
@export var cast_time: float = 0.15
@export var recovery_time: float = 0.25
## Precisa estar ao alcance da espada (senão faz o Passo Relâmpago antes).
@export var requires_melee: bool = false
@export var is_heavy: bool = false

@export_group("Dano")
@export var damage_multiplier: float = 2.5
## Corrente em Cadeia: multiplicador de cada alvo, em ordem (o 1º é o alvo atual).
@export var chain_multipliers: Array[float] = []
@export var chain_range: float = 6.0
## Fúria da Tempestade: dano nos outros inimigos dentro do raio.
@export var area_multiplier: float = 0.0
@export var area_radius: float = 0.0
