extends Node
## Save em JSON (autoload "SaveManager", GDD §11). Carrega ao iniciar o jogo.
## Auto-save: fogueiras (checkpoints), compras, objetivos/arcos concluídos e fim de partida.
## Grava num arquivo temporário e troca no fim (um save corrompido no meio não apaga o anterior).
## Versão 1 (antes da história) é aceita: os campos novos começam no padrão.

signal saved

const SAVE_VERSION: int = 2
const COMPATIBLE_VERSIONS: Array[int] = [1, 2]
## Entre dois auto-saves pedidos em sequência (ex.: objetivo + arco no mesmo instante), espera isto.
const AUTOSAVE_COALESCE: float = 0.25
const DEFAULT_PATH := "user://save.json"

var save_path: String = DEFAULT_PATH
## Testes automáticos desligam para não mexer no save do jogador.
var persist: bool = true
var _autosave_pending: bool = false


func _ready() -> void:
	load_game()


func save_game() -> bool:
	if not persist:
		return false
	var temp_path := save_path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("Não foi possível salvar em %s: %s" % [temp_path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify({"version": SAVE_VERSION, "state": GameState.to_dict()}, "\t"))
	file.close()
	var error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(save_path))
	if error != OK:
		push_error("Não foi possível trocar o save: %s" % error_string(error))
		return false
	saved.emit()
	return true


## Auto-save: junta pedidos feitos no mesmo instante num único arquivo gravado.
func autosave() -> void:
	if not persist or _autosave_pending:
		return
	_autosave_pending = true
	get_tree().create_timer(AUTOSAVE_COALESCE, true, false, true).timeout.connect(func() -> void:
		_autosave_pending = false
		save_game())


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func load_game() -> bool:
	if not persist or not FileAccess.file_exists(save_path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not parsed is Dictionary:
		push_warning("Save inválido em %s; começando do zero." % save_path)
		return false
	var data: Dictionary = parsed
	if not int(data.get("version", 0)) in COMPATIBLE_VERSIONS:
		push_warning("Versão de save desconhecida (%s); começando do zero." % data.get("version"))
		return false
	GameState.from_dict(data.get("state", {}))
	return true


func delete_save() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
