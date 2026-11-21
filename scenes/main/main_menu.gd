class_name MainMenu
extends Control
## Tela título (GDD §11): cenário 3D sombrio ao fundo (o herói sob a tempestade, com raios e
## chuva), e Continuar, Novo Jogo, New Game+, Arena de Hordas, Ferreiro, Configurações e Sair.

## Título provisório (GDD §14): trocar quando o nome do jogo for decidido.
const GAME_TITLE := "LÂMINA DA TEMPESTADE"
const SUBTITLE := "A Mácula tomou Valdren. Resta um cavaleiro."
const HERO_MODEL := preload("res://assets/characters/hero/paladin.fbx")
const LIBRARY := preload("res://assets/characters/animations/combat_library.res")

@export var shop_scene: PackedScene
@export var sword_upgrade: UpgradeData
@export var armor_upgrade: UpgradeData

var _progress_label: Label
var _first_button: Button
var _buttons: VBoxContainer
var _backdrop: Node3D
var _strike_timer: float = 1.0
var _confirm: ConfirmationDialog


func _ready() -> void:
	Music.play_track(&"explore")
	Hitstop.reset()
	get_tree().paused = false
	_build_backdrop()
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	column.offset_left = 80.0
	column.offset_right = 520.0
	column.offset_top = -300.0
	column.offset_bottom = 320.0
	column.add_theme_constant_override(&"separation", MenuKit.SPACING)
	add_child(column)
	var title := MenuKit.label(GAME_TITLE, 52, Color(0.72, 0.88, 1.0))
	title.add_theme_constant_override(&"outline_size", 10)
	title.add_theme_color_override(&"font_outline_color", Color(0.05, 0.08, 0.15))
	column.add_child(title)
	column.add_child(MenuKit.label(SUBTITLE, 16, MenuKit.MUTED_COLOR))
	_progress_label = MenuKit.label("", 16, MenuKit.GOLD_COLOR)
	column.add_child(_progress_label)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override(&"separation", 10)
	column.add_child(_buttons)
	_build_buttons()
	_refresh_progress()


func _process(delta: float) -> void:
	_strike_timer -= delta
	if _strike_timer <= 0.0 and _backdrop != null:
		_strike_timer = randf_range(2.0, 5.0)
		var spot := Vector3(randf_range(-14.0, 14.0), 0.0, randf_range(-30.0, -14.0))
		Vfx.lightning_strike(_backdrop, spot, Color(0.65, 0.85, 1.0), 2.5, true)


func _build_buttons() -> void:
	for child: Node in _buttons.get_children():
		child.queue_free()
	_first_button = null
	var has_save := SaveManager.has_save() and GameState.has_progress()
	if has_save:
		_add_button("Continuar", _continue)
	_add_button("Novo Jogo", _new_game)
	if GameState.game_completed:
		_add_button("New Game+ (inimigos mais fortes)", _new_game_plus)
	_add_button("Arena de Hordas", _arena)
	_add_button("Ferreiro e Mestre Arcano", _open_shop)
	_add_button("Configurações", _open_settings)
	_add_button("Sair", func() -> void: get_tree().quit())
	_first_button.grab_focus()


func _add_button(text: String, action: Callable) -> void:
	var button := MenuKit.button(text, action)
	_buttons.add_child(button)
	if _first_button == null:
		_first_button = button


func _continue() -> void:
	GameState.launch_mode = &"story"
	GameState.play_intro = false
	LoadingScreen.go(get_tree(), Scenes.TRAIL)


## Novo Jogo apaga a campanha (pede confirmação se houver progresso).
func _new_game() -> void:
	if GameState.has_progress() or GameState.gold > 0:
		_ask("Começar do zero? O progresso salvo (nível, ouro, espadas e história) será apagado.", func() -> void:
			GameState.reset()
			_start_story())
	else:
		_start_story()


func _start_story() -> void:
	GameState.launch_mode = &"story"
	GameState.play_intro = true
	SaveManager.save_game()
	LoadingScreen.go(get_tree(), Scenes.TRAIL)


func _new_game_plus() -> void:
	GameState.start_new_game_plus()
	_start_story()


func _arena() -> void:
	GameState.launch_mode = &"arena"
	GameState.play_intro = false
	LoadingScreen.go(get_tree(), Scenes.TRAIL)


func _open_shop() -> void:
	var shop := shop_scene.instantiate() as UpgradeShop
	add_child(shop)
	shop.closed.connect(func() -> void:
		_refresh_progress()
		_first_button.grab_focus())


func _open_settings() -> void:
	var settings := SettingsMenu.new()
	add_child(settings)
	settings.closed.connect(func() -> void: _first_button.grab_focus())


func _ask(question: String, on_yes: Callable) -> void:
	if _confirm != null:
		_confirm.queue_free()
	_confirm = ConfirmationDialog.new()
	_confirm.dialog_text = question
	_confirm.ok_button_text = "Sim, começar"
	_confirm.cancel_button_text = "Cancelar"
	add_child(_confirm)
	_confirm.confirmed.connect(on_yes)
	_confirm.popup_centered()


func _refresh_progress() -> void:
	var sword := SwordItem.find(GameState.equipped_sword)
	var parts: Array[String] = ["Nível %d" % GameState.level, "Ouro %d" % GameState.gold]
	if sword != null:
		parts.append(sword.display_name)
	if GameState.new_game_plus > 0:
		parts.append("New Game+ %d" % GameState.new_game_plus)
	if GameState.arena_best > 0:
		parts.append("Arena: %d ondas" % GameState.arena_best)
	_progress_label.text = "   ·   ".join(parts)


## Fundo: o herói parado sob a tempestade, com neblina, chuva e raios caindo ao longe.
func _build_backdrop() -> void:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	container.add_child(viewport)
	_backdrop = Node3D.new()
	viewport.add_child(_backdrop)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.02, 0.025, 0.04)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.25, 0.3, 0.42)
	environment.ambient_light_energy = 0.6
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.08, 0.1, 0.16)
	environment.fog_density = 0.03
	environment.glow_enabled = true
	environment.glow_intensity = 0.8
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_backdrop.add_child(world_environment)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-35.0, 150.0, 0.0)
	moon.light_color = Color(0.6, 0.7, 0.95)
	moon.light_energy = 1.2
	_backdrop.add_child(moon)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120, 120)
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.05, 0.05, 0.06)
	ground_material.roughness = 0.2
	ground_material.metallic = 0.4
	plane.material = ground_material
	ground.mesh = plane
	_backdrop.add_child(ground)
	var hero := AnimatedBody.new()
	hero.model_scene = HERO_MODEL
	hero.library = LIBRARY
	_backdrop.add_child(hero)
	hero.position = Vector3(2.6, 0.0, -4.8)
	hero.rotation.y = deg_to_rad(215.0)
	hero.set_rim(Color(0.55, 0.75, 1.0), 0.9)
	var camera := Camera3D.new()
	camera.fov = 50.0
	_backdrop.add_child(camera)
	camera.position = Vector3(0.0, 1.5, 0.5)
	camera.look_at(Vector3(0.9, 1.2, -6.0), Vector3.UP)
	var rain := GPUParticles3D.new()
	rain.amount = 600
	rain.lifetime = 0.9
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(12.0, 1.0, 10.0)
	process.direction = Vector3(0.1, -1.0, 0.0)
	process.initial_velocity_min = 20.0
	process.initial_velocity_max = 26.0
	rain.process_material = process
	var drop := QuadMesh.new()
	drop.size = Vector2(0.012, 0.5)
	var drop_material := StandardMaterial3D.new()
	drop_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_material.albedo_color = Color(0.7, 0.75, 0.85, 0.3)
	drop_material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	drop.material = drop_material
	rain.draw_pass_1 = drop
	rain.position = Vector3(0.0, 12.0, -8.0)
	_backdrop.add_child(rain)
