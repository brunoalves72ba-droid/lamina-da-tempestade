class_name Scenes
extends RefCounted
## Caminhos das telas e troca de cena (menu principal ↔ fase).

const MAIN_MENU := "res://scenes/main/main_menu.tscn"
const ARENA := "res://scenes/levels/arena_01.tscn"


static func go(tree: SceneTree, path: String) -> void:
	tree.paused = false
	Hitstop.reset()
	tree.change_scene_to_file(path)
