extends Node
## Save em JSON (autoload "SaveManager", GDD §11). Carrega ao iniciar o jogo;
## grava ao fim de cada fase e a cada compra na loja.

const SAVE_VERSION: int = 1
const DEFAULT_PATH := "user://save.json"

var save_path: String = DEFAULT_PATH
## Testes automáticos desligam para não mexer no save do jogador.
var persist: bool = true


func _ready() -> void:
	load_game()


func save_game() -> bool:
	if not persist:
		return false
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("Não foi possível salvar em %s: %s" % [save_path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify({"version": SAVE_VERSION, "state": GameState.to_dict()}, "\t"))
	return true


func load_game() -> bool:
	if not persist or not FileAccess.file_exists(save_path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not parsed is Dictionary:
		push_warning("Save inválido em %s; começando do zero." % save_path)
		return false
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != SAVE_VERSION:
		push_warning("Versão de save desconhecida (%s); começando do zero." % data.get("version"))
		return false
	GameState.from_dict(data.get("state", {}))
	return true


func delete_save() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
