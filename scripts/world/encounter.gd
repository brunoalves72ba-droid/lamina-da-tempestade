class_name Encounter
extends Node3D
## Ponto de encontro (GDD §5, §9). O herói para no ponto do trilho mais próximo deste nó.
## Os filhos Marker3D são os pontos de surgimento; SpawnEntry.spawn_point indexa essa lista.

@export var waves: Array[WaveData] = []


func spawn_position(index: int) -> Vector3:
	var markers: Array[Marker3D] = []
	for child: Node in get_children():
		var marker := child as Marker3D
		if marker != null:
			markers.append(marker)
	if markers.is_empty():
		return global_position
	return markers[index % markers.size()].global_position
