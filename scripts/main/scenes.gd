class_name Scenes
extends RefCounted
## Caminhos das telas e troca de cena (menu principal ↔ fases).

const MAIN_MENU := "res://scenes/main/main_menu.tscn"
## Percurso com movimento livre (fase principal).
const TRAIL := "res://scenes/levels/trail_01.tscn"


static func go(tree: SceneTree, path: String) -> void:
	tree.paused = false
	Hitstop.reset()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	tree.change_scene_to_file(path)
