class_name SpawnEntry
extends Resource
## Um inimigo de uma onda: qual cena, quais dados, elemento e em qual ponto do Encounter surge.

@export var enemy_scene: PackedScene
@export var enemy_data: EnemyData
@export var element: Element.Type = Element.Type.NONE
## Índice do Marker3D filho do Encounter.
@export var spawn_point: int = 0
