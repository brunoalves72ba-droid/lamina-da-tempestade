class_name ProgressionData
extends Resource
## Experiência, níveis e como os inimigos escalam com o poder do herói.
## "Nível de ameaça" = nível do herói + equipment_threat × níveis de equipamento comprados
## (GameState.threat_level): quanto mais forte o herói fica, mais fortes e numerosos os inimigos.
## Valores em data/progression/progression.tres.

@export_group("Níveis do herói")
@export var max_level: int = 30
## XP para ir do nível 1 ao 2; cada nível seguinte pede xp_growth vezes mais.
@export var xp_base: float = 60.0
@export var xp_growth: float = 1.3
@export var health_per_level: float = 8.0
@export var damage_per_level: float = 1.0

@export_group("Escala dos inimigos")
## Cada nível de equipamento comprado (espada, armadura) vale isto em nível de ameaça.
@export var equipment_threat: float = 0.5
## Cada New Game+ soma isto ao nível de ameaça.
@export var new_game_plus_threat: float = 6.0
## Inimigos extras por onda a cada nível de ameaça (arredonda para baixo).
@export var extra_enemies_per_level: float = 0.5
@export var max_extra_enemies: int = 6
## Aumento de vida/dano dos inimigos por nível de ameaça (0.06 = +6% por nível).
@export var enemy_health_per_level: float = 0.06
@export var enemy_damage_per_level: float = 0.04


func xp_to_next(level: int) -> int:
	return roundi(xp_base * pow(xp_growth, level - 1))


func threat_level(hero_level: int, equipment_levels: int) -> float:
	return float(hero_level) + equipment_threat * float(equipment_levels)


func extra_enemies(threat: float) -> int:
	return mini(floori((threat - 1.0) * extra_enemies_per_level), max_extra_enemies)


func enemy_health_scale(threat: float) -> float:
	return 1.0 + (threat - 1.0) * enemy_health_per_level


func enemy_damage_scale(threat: float) -> float:
	return 1.0 + (threat - 1.0) * enemy_damage_per_level
