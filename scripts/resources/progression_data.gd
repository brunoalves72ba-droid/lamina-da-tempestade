class_name ProgressionData
extends Resource
## Experiência, níveis e como os inimigos escalam com o nível do herói.
## Valores em data/progression/progression.tres.

@export_group("Níveis do herói")
@export var max_level: int = 30
## XP para ir do nível 1 ao 2; cada nível seguinte pede xp_growth vezes mais.
@export var xp_base: float = 60.0
@export var xp_growth: float = 1.3
@export var health_per_level: float = 8.0
@export var damage_per_level: float = 1.0

@export_group("Escala dos inimigos")
## Inimigos extras por onda a cada nível do herói (arredonda para baixo).
@export var extra_enemies_per_level: float = 0.5
@export var max_extra_enemies: int = 6
## Aumento de vida/dano dos inimigos por nível do herói (0.06 = +6% por nível).
@export var enemy_health_per_level: float = 0.06
@export var enemy_damage_per_level: float = 0.04


func xp_to_next(level: int) -> int:
	return roundi(xp_base * pow(xp_growth, level - 1))


func extra_enemies(level: int) -> int:
	return mini(floori((level - 1) * extra_enemies_per_level), max_extra_enemies)


func enemy_health_scale(level: int) -> float:
	return 1.0 + (level - 1) * enemy_health_per_level


func enemy_damage_scale(level: int) -> float:
	return 1.0 + (level - 1) * enemy_damage_per_level
