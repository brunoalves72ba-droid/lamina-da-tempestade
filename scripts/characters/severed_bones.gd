class_name SeveredBones
extends SkeletonModifier3D
## Desmembramento (GDD §6.7): depois da animação, encolhe a zero os ossos cortados, então a parte
## do corpo presa a eles some (cabeça, antebraço...). Fica como filho do Skeleton3D.

var _bones: PackedInt32Array = PackedInt32Array()


func sever(bone: int) -> void:
	if bone >= 0 and not bone in _bones:
		_bones.append(bone)


func clear() -> void:
	_bones.clear()


func has_severed() -> bool:
	return not _bones.is_empty()


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	for bone: int in _bones:
		skeleton.set_bone_pose_scale(bone, Vector3.ONE * 0.001)
