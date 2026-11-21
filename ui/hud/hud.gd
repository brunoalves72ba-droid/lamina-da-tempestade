class_name GameHUD
extends CanvasLayer
## HUD: vida do herói e do alvo atual, recarga do Dardo de Raio, encontro atual e feedback de combate.

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
	&"Travel": "Avançando",
	&"Power": "Poder de raio",
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

var _power_slots: Array[PowerSlot] = []


func _ready() -> void:
	_feedback.modulate.a = 0.0
	_target_panel.visible = false
	_encounter_label.text = ""
	_gold_label.text = ""
	Events.damage_taken.connect(_on_damage_taken)


func show_gold(amount: int) -> void:
	_gold_label.text = "Ouro: %d" % amount


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


func bind_player(player: Player) -> void:
	_player = player
	player.health.health_changed.connect(_on_player_health_changed)
	player.parry_succeeded.connect(_on_player_parried)
	player.hit_taken.connect(_on_player_hit_taken)
	player.died.connect(_on_player_died)
	player.state_machine.state_changed.connect(_on_player_state_changed)
	player.targeting.target_changed.connect(_on_target_changed)
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
