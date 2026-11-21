class_name PropEntry
extends Resource
## Um tipo de objeto de cenário espalhado ao longo da trilha (rocha, tronco, samambaia...).

@export var scene: PackedScene
@export var weight: float = 1.0
@export var scale_min: float = 0.8
@export var scale_max: float = 1.3
## Distância da linha central da trilha (m), em cada lado.
@export var side_distance_min: float = 6.0
@export var side_distance_max: float = 12.0
## Raio de colisão (escala 1). 0 = sem colisão (plantas).
@export var collision_radius: float = 0.0
## Quanto afundar no chão (m), para não flutuar em encostas.
@export var sink: float = 0.1
