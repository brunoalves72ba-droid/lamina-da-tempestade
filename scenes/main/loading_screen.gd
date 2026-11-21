class_name LoadingScreen
extends Control
## Tela de carregamento (GDD §11): carrega a fase em segundo plano (ResourceLoader com thread),
## mostra o progresso real e dicas de combate/história, e troca de cena quando termina.
## Uso: LoadingScreen.go(get_tree(), Scenes.TRAIL)

const SCENE_PATH := "res://scenes/main/loading_screen.tscn"
const MIN_TIME: float = 1.2
const TIP_TIME: float = 3.5
const TIPS: Array[String] = [
	"Aparar no último instante atordoa o inimigo — o primeiro golpe depois disso causa o dobro.",
	"Um inimigo eletrocutado sofre críticos de espada. Raio primeiro, lâmina depois.",
	"Raios que caem em poças d'água atingem todos que estiverem pisando nelas.",
	"Na tempestade seus poderes ficam 30% mais fortes. À noite, a Mácula também.",
	"O Esqueleto ergue o escudo quando você golpeia. Um golpe forte quebra a guarda.",
	"Círculo vermelho no chão: saia dele ou esquive na hora exata do impacto.",
	"Nas fogueiras acesas (tecla E) o Ferreiro vende espadas e o Mestre Arcano evolui seus poderes.",
	"Salvar viajantes melhora sua reputação: a Guilda dos Mercadores dá descontos a quem ajuda.",
	"T alterna a mira: assistida destaca o alvo mais próximo; livre acerta onde você apontar.",
	"Kael é o último cavaleiro da Ordem do Grifo de Prata. A tempestade escolheu a espada dele.",
]

static var _target_path: String = ""

var _bar: ProgressBar
var _tip: Label
var _elapsed: float = 0.0
var _tip_timer: float = 0.0
var _requested: bool = false


static func go(tree: SceneTree, path: String) -> void:
	_target_path = path
	tree.paused = false
	Hitstop.reset()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	tree.change_scene_to_file(SCENE_PATH)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.02, 0.02, 0.03)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	column.offset_left = -420.0
	column.offset_right = 420.0
	column.offset_top = -190.0
	column.offset_bottom = -60.0
	column.add_theme_constant_override(&"separation", 14)
	add_child(column)
	column.add_child(MenuKit.label("CARREGANDO", 26, Color(0.7, 0.85, 1.0)))
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 10)
	_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.55, 0.8, 1.0)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.1, 0.1, 0.13)
	_bar.add_theme_stylebox_override(&"fill", fill)
	_bar.add_theme_stylebox_override(&"background", back)
	column.add_child(_bar)
	_tip = MenuKit.label("", 18, MenuKit.MUTED_COLOR)
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_tip)
	_next_tip()
	if _target_path != "":
		_requested = ResourceLoader.load_threaded_request(_target_path) == OK


func _process(delta: float) -> void:
	_elapsed += delta
	_tip_timer -= delta
	if _tip_timer <= 0.0:
		_next_tip()
	if not _requested:
		return
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(_target_path, progress)
	if not progress.is_empty():
		_bar.value = lerpf(_bar.value, float(progress[0]) * 100.0, 0.25)
	if status == ResourceLoader.THREAD_LOAD_LOADED and _elapsed >= MIN_TIME:
		_bar.value = 100.0
		var scene := ResourceLoader.load_threaded_get(_target_path) as PackedScene
		_requested = false
		get_tree().change_scene_to_packed(scene)
	elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_requested = false
		push_error("Falha ao carregar %s" % _target_path)
		get_tree().change_scene_to_file(Scenes.MAIN_MENU)


func _next_tip() -> void:
	_tip_timer = TIP_TIME
	_tip.text = TIPS.pick_random()
