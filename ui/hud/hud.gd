class_name GameHUD
extends CanvasLayer
## HUD: vida, Carga, nível e XP do herói; alvo atual (travado ou não); poderes; ouro; objetivo; feedback.

const PARRY_COLOR := Color(0.55, 0.85, 1.0)
const COUNTER_COLOR := Color(1.0, 0.85, 0.3)
const DANGER_COLOR := Color(1.0, 0.35, 0.3)
const READY_COLOR := Color(0.6, 0.88, 1.0)
const WAITING_COLOR := Color(0.6, 0.6, 0.65)
const CHARGE_FULL_COLOR := Color(1.0, 0.92, 0.45)
const POWER_SLOT_SIZE := Vector2(132, 118)
const STATE_NAMES: Dictionary = {
	&"Idle": "Pronto",
	&"Attack": "Atacando",
	&"Parry": "Defendendo",
	&"Hurt": "Atingido",
	&"Dead": "Caído",
	&"Bolt": "Dardo de Raio",
	&"Dash": "Passo Relâmpago",
	&"Power": "Poder de raio",
	&"Dodge": "Esquivando",
	&"Block": "Bloqueando",
}

@export var feedback_hold_time: float = 0.5
@export var feedback_fade_time: float = 0.4

var _player: Player
var _target_health: HealthComponent
var _feedback_tween: Tween
var _charge_full_style: StyleBoxFlat
var _charge_normal_style: StyleBox

@onready var _player_bar: ProgressBar = %PlayerHealthBar
@onready var _player_label: Label = %PlayerHealthLabel
@onready var _target_panel: Control = %TargetPanel
@onready var _target_name: Label = %TargetName
@onready var _target_bar: ProgressBar = %TargetHealthBar
@onready var _feedback: Label = %Feedback
@onready var _state_label: Label = %StateLabel
@onready var _bolt_label: Label = %BoltLabel
@onready var _encounter_label: Label = %EncounterLabel
@onready var _charge_bar: ProgressBar = %ChargeBar
@onready var _charge_label: Label = %ChargeLabel
@onready var _power_slots_root: HBoxContainer = %PowerSlots
@onready var _element_label: Label = %ElementLabel
@onready var _gold_label: Label = %GoldLabel
@onready var _xp_bar: ProgressBar = %XpBar
@onready var _level_label: Label = %LevelLabel

var _power_slots: Array[PowerSlot] = []


## Objetivo, narração e mira (StoryOverlay).
var story: StoryOverlay
var _boss_panel: VBoxContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var _boss: Enemy


func _ready() -> void:
	_feedback.modulate.a = 0.0
	_target_panel.visible = false
	_encounter_label.text = ""
	_gold_label.text = ""
	Events.damage_taken.connect(_on_damage_taken)
	Events.boss_engaged.connect(_on_boss_engaged)
	Events.aim_mode_changed.connect(func(mode: int) -> void:
		show_feedback("MIRA LIVRE" if mode == GameState.AimMode.FREE else "MIRA ASSISTIDA", READY_COLOR))
	_build_boss_panel()
	Events.reputation_feedback.connect(func(faction_name: String, amount: int, gold: int) -> void:
		var text := "%s %+d" % [faction_name.to_upper(), amount]
		if gold > 0:
			text += "   +%d OURO" % gold
		show_feedback(text, READY_COLOR if amount > 0 else DANGER_COLOR))
	story = StoryOverlay.new()
	story.name = "StoryOverlay"
	$Root.add_child(story)


## Barra de vida do chefão: larga, no alto e no centro (abaixo do alvo), com o nome dele.
func _build_boss_panel() -> void:
	_boss_panel = VBoxContainer.new()
	_boss_panel.name = "BossPanel"
	_boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_panel.offset_left = -270.0
	_boss_panel.offset_right = 270.0
	_boss_panel.offset_top = 96.0
	_boss_panel.offset_bottom = 154.0
	_boss_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_boss_panel.visible = false
	_boss_name = Label.new()
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name.add_theme_font_size_override(&"font_size", 26)
	_boss_name.add_theme_color_override(&"font_color", Color(1.0, 0.85, 0.55))
	_boss_name.add_theme_constant_override(&"outline_size", 8)
	_boss_name.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_boss_panel.add_child(_boss_name)
	_boss_bar = ProgressBar.new()
	_boss_bar.custom_minimum_size = Vector2(0, 18)
	_boss_bar.show_percentage = false
	_boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.05, 0.03, 0.03, 0.85)
	background.border_color = Color(0.6, 0.45, 0.25)
	background.set_border_width_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.75, 0.1, 0.08)
	_boss_bar.add_theme_stylebox_override(&"background", background)
	_boss_bar.add_theme_stylebox_override(&"fill", fill)
	_boss_panel.add_child(_boss_bar)
	$Root.add_child(_boss_panel)


func _on_boss_engaged(boss: Node3D) -> void:
	var enemy := boss as Enemy
	if enemy == null:
		return
	if _boss != null and is_instance_valid(_boss):
		if _boss.health.health_changed.is_connected(_on_boss_health_changed):
			_boss.health.health_changed.disconnect(_on_boss_health_changed)
	_boss = enemy
	_boss_name.text = enemy.data.boss.title
	_boss_bar.max_value = enemy.health.max_health
	_boss_bar.value = enemy.health.current_health
	_boss_panel.visible = true
	enemy.health.health_changed.connect(_on_boss_health_changed)
	enemy.tree_exiting.connect(func() -> void: _boss_panel.visible = false)
	show_feedback(enemy.data.boss.title.to_upper(), Color(1.0, 0.5, 0.3))


func _on_boss_health_changed(current: float, maximum: float) -> void:
	_boss_bar.max_value = maximum
	_boss_bar.value = current
	if current <= 0.0:
		get_tree().create_timer(1.5, false).timeout.connect(func() -> void: _boss_panel.visible = false)


func show_gold(amount: int) -> void:
	_gold_label.text = "Ouro: %d" % amount


## Texto livre no canto superior direito (objetivo, clareira atual).
func show_encounter_text(text: String) -> void:
	_encounter_label.text = text


## Liga a barra de XP e o nível ao GameState.
func bind_progression() -> void:
	if not GameState.xp_changed.is_connected(_on_xp_changed):
		GameState.xp_changed.connect(_on_xp_changed)
	_on_xp_changed(GameState.xp, GameState.xp_needed(), GameState.level)


func _on_xp_changed(xp: int, xp_needed: int, level: int) -> void:
	_xp_bar.max_value = maxi(xp_needed, 1)
	_xp_bar.value = xp
	_level_label.text = "Nível %d   ·   XP %d / %d" % [level, xp, xp_needed]


func _process(_delta: float) -> void:
	if _player == null:
		return
	var cooldown := _player.bolt_cooldown
	if cooldown.is_ready:
		_bolt_label.text = "Dardo de Raio: pronto"
		_bolt_label.modulate = READY_COLOR
	else:
		_bolt_label.text = "Dardo de Raio: %.1f s" % cooldown.remaining
		_bolt_label.modulate = WAITING_COLOR
	_update_powers()


## Modo cinema: esconde a HUD de jogo e deixa só a narração.
func set_cinematic(value: bool) -> void:
	for child: Node in $Root.get_children():
		if child is CanvasItem and child != story:
			(child as CanvasItem).visible = not value
	if story != null:
		story.set_cinematic(value)


func bind_player(player: Player) -> void:
	if story != null:
		story.hero = player
	_player = player
	player.health.health_changed.connect(_on_player_health_changed)
	player.parry_succeeded.connect(_on_player_parried)
	player.hit_taken.connect(_on_player_hit_taken)
	player.died.connect(_on_player_died)
	player.state_machine.state_changed.connect(_on_player_state_changed)
	player.targeting.target_changed.connect(_on_target_changed)
	player.targeting.lock_changed.connect(func(_locked: bool) -> void: _on_target_changed(player.target))
	player.charge.changed.connect(_on_charge_changed)
	player.power_denied.connect(_on_power_denied)
	_on_charge_changed(player.charge.value, player.charge.maximum)
	_on_player_health_changed(player.health.current_health, player.health.max_health)
	_on_target_changed(player.target)
	if player.state_machine.current_state != null:
		_on_player_state_changed(StringName(player.state_machine.current_state.name))


func show_element(element: Element.Type) -> void:
	_element_label.text = "Espada: %s" % Element.display_name(element)
	_element_label.modulate = Element.color(element)


func show_encounter(index: int, total: int) -> void:
	_encounter_label.text = "Encontro %d / %d" % [index, total]


func show_feedback(text: String, color: Color) -> void:
	_feedback.text = text
	_feedback.modulate = color
	if _feedback_tween != null:
		_feedback_tween.kill()
	_feedback_tween = create_tween()
	_feedback_tween.tween_interval(feedback_hold_time)
	_feedback_tween.tween_property(_feedback, "modulate:a", 0.0, feedback_fade_time)


func _on_target_changed(enemy: Enemy) -> void:
	if is_instance_valid(_target_health) and _target_health.health_changed.is_connected(_on_target_health_changed):
		_target_health.health_changed.disconnect(_on_target_health_changed)
	_target_health = null
	_target_panel.visible = enemy != null
	if enemy == null:
		return
	_target_name.text = enemy.data.display_name
	_target_health = enemy.health
	_target_health.health_changed.connect(_on_target_health_changed)
	_on_target_health_changed(_target_health.current_health, _target_health.max_health)


func _on_player_health_changed(current: float, maximum: float) -> void:
	_player_bar.max_value = maximum
	_player_bar.value = current
	_player_label.text = "%d / %d" % [roundi(current), roundi(maximum)]


func _on_target_health_changed(current: float, maximum: float) -> void:
	_target_bar.max_value = maximum
	_target_bar.value = current


func _on_player_parried(_attacker: Node3D) -> void:
	show_feedback("DESCARGA!", PARRY_COLOR)


func _on_player_hit_taken(_info: DamageInfo, parry_was_early: bool) -> void:
	show_feedback("CEDO DEMAIS" if parry_was_early else "SEM DEFESA", DANGER_COLOR)


func _on_player_died() -> void:
	show_feedback("VOCÊ CAIU", DANGER_COLOR)
	if _feedback_tween != null:
		_feedback_tween.kill()


func _on_damage_taken(_target: Node3D, info: DamageInfo) -> void:
	if info.is_counter:
		show_feedback("CONTRA-ATAQUE ×2", COUNTER_COLOR)


func _on_charge_changed(value: float, maximum: float) -> void:
	_charge_bar.max_value = maximum
	_charge_bar.value = value
	var full := value >= maximum
	if _charge_normal_style == null:
		_charge_normal_style = _charge_bar.get_theme_stylebox(&"fill")
		_charge_full_style = StyleBoxFlat.new()
		_charge_full_style.bg_color = CHARGE_FULL_COLOR
	_charge_bar.add_theme_stylebox_override(&"fill", _charge_full_style if full else _charge_normal_style)
	_charge_label.modulate = CHARGE_FULL_COLOR if full else Color.WHITE
	if full:
		_charge_label.text = "CARGA CHEIA — 3: Fúria da Tempestade"
	else:
		_charge_label.text = "Carga Estática %d / %d" % [roundi(value), roundi(maximum)]


func _on_power_denied(slot: int) -> void:
	var power := _player.powers.power(slot)
	if _player.charge.value < power.charge_cost:
		show_feedback("CARGA INSUFICIENTE", WAITING_COLOR)


func _update_powers() -> void:
	var powers := _player.powers
	while _power_slots.size() < powers.count():
		var slot_icon := PowerSlot.new()
		slot_icon.custom_minimum_size = POWER_SLOT_SIZE
		slot_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_icon.key_text = str(_power_slots.size() + 1)
		_power_slots_root.add_child(slot_icon)
		_power_slots.append(slot_icon)
	var accent := _player.lightning_color()
	for slot: int in powers.count():
		var power := powers.power(slot)
		var cooldown := powers.cooldown(slot)
		var fill := 1.0
		var status := "pronto"
		if _player.charge.value < power.charge_cost:
			fill = _player.charge.value / power.charge_cost
			status = "Carga %d%%" % roundi(fill * 100.0)
		elif not cooldown.is_ready:
			fill = 1.0 - cooldown.remaining / maxf(cooldown.duration, 0.001)
			status = "%.1f s" % cooldown.remaining
		_power_slots[slot].set_state(power.display_name, status, fill, accent)


func _on_player_state_changed(state_name: StringName) -> void:
	_state_label.text = "Herói: %s" % STATE_NAMES.get(state_name, str(state_name))
