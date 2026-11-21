class_name StoryObjective
extends Resource
## Um objetivo de arco (GDD §4.1): texto mostrado na HUD e o evento que o cumpre.

enum Trigger {
	## Clareira vencida (param = nome da clareira, ex.: "Ponte de Pedra").
	ZONE_CLEARED,
	## Fogueira acesa (param = metro da trilha, ex.: "105").
	CHECKPOINT,
	## Chefão derrotado (param = nome do arquivo do EnemyData, ex.: "boss_warrok").
	BOSS_DEFEATED,
	## Chegou ao santuário no fim da trilha.
	SHRINE,
}

@export var id: StringName = &""
@export var text: String = ""
@export var trigger: Trigger = Trigger.ZONE_CLEARED
@export var param: String = ""
