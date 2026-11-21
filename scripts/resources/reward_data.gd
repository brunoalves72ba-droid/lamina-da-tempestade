class_name RewardData
extends Resource
## Regras de ouro da fase (GDD §4, §9). Valores em data/combat/rewards.tres.

## Ouro extra ao vencer a fase.
@export var completion_bonus: int = 50
## Fração do ouro coletado que o herói mantém ao morrer.
@export_range(0.0, 1.0) var death_keep_fraction: float = 0.5
