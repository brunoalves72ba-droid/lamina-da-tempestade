extends SceneTree
## Monta assets/characters/animations/combat_library.res a partir dos .fbx da Mixamo.
## - Renomeia cada animação para o nome lógico usado pelo jogo (idle, run, attack_1...).
## - Remove o deslocamento horizontal do quadril (root motion): quem move o personagem é o código.
## - Marca as animações de locomoção como loop.
## Rodar (depois de importar o projeto):
##   godot --headless --path . --script res://tools/build_animation_library.gd

const SOURCE_DIR := "res://assets/characters/animations/"
const OUTPUT := "res://assets/characters/animations/combat_library.res"
const HIPS_TRACK := "Skeleton3D:mixamorig_Hips"
const LOOPS: Array[String] = ["idle", "walk", "walk_back", "run", "run_back", "sprint", "strafe_left", "strafe_right",
		"strafe_left_run", "strafe_right_run", "block_idle"]
## Animações que reaproveitam o arquivo de outra.
const ALIASES: Dictionary = {"enemy_strike": "attack_1"}
## Animações que terminam deitadas/caídas: mantém a altura final do quadril.
const KEEP_HEIGHT: Array[String] = ["death"]


func _initialize() -> void:
	var library := AnimationLibrary.new()
	var names: Array[String] = []
	for file: String in DirAccess.get_files_at(SOURCE_DIR):
		if file.ends_with(".fbx"):
			names.append(file.get_basename())
	for alias: String in ALIASES:
		names.append(alias)
	names.sort()
	for logical: String in names:
		var file_name: String = ALIASES.get(logical, logical)
		var scene := load(SOURCE_DIR + file_name + ".fbx") as PackedScene
		var root := scene.instantiate()
		var player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var source := player.get_animation(player.get_animation_list()[0])
		var animation := source.duplicate(true) as Animation
		_strip_root_motion(animation)
		animation.loop_mode = Animation.LOOP_LINEAR if logical in LOOPS else Animation.LOOP_NONE
		library.add_animation(logical, animation)
		root.free()
		print("  %-18s %.2fs%s" % [logical, animation.length, "  (loop)" if logical in LOOPS else ""])
	var err := ResourceSaver.save(library, OUTPUT)
	print("Biblioteca salva (%d animações): %s" % [names.size(), error_string(err)])
	quit(0 if err == OK else 1)


## Zera o movimento horizontal do quadril (x/z ficam no valor do primeiro quadro).
func _strip_root_motion(animation: Animation) -> void:
	var track := animation.find_track(NodePath(HIPS_TRACK), Animation.TYPE_POSITION_3D)
	if track == -1:
		push_warning("Sem trilha de posição do quadril")
		return
	var first: Vector3 = animation.track_get_key_value(track, 0)
	for i: int in animation.track_get_key_count(track):
		var value: Vector3 = animation.track_get_key_value(track, i)
		animation.track_set_key_value(track, i, Vector3(first.x, value.y, first.z))
