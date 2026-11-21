class_name WorldNpc
extends CharacterBody3D
## Civil/aliado de evento (GDD §9.3): cavaleiro da Ordem cercado, mercador da Guilda atacado.
## Tem vida e Hurtbox próprios, então os inimigos podem mirar nele (Enemy.set_target). Fica
## acuado no lugar, com o nome por cima; morre se ninguém ajudar a tempo.

signal died

const GROUP := &"world_npcs"

var display_name: String = "Viajante"
var faction: StringName = &""
var rim_color: Color = Color(1.0, 0.85, 0.4)

var health: HealthComponent
var hurtbox: Hurtbox
var body: AnimatedBody
var _label: Label3D


## Monta o NPC (chame antes de pôr na cena).
func setup(model: PackedScene, library: AnimationLibrary, npc_name: String, npc_faction: StringName,
		color: Color, max_health: float) -> void:
	display_name = npc_name
	faction = npc_faction
	rim_color = color
	name = "Npc"
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	var holder := Node3D.new()
	holder.name = "Model"
	add_child(holder)
	body = AnimatedBody.new()
	body.name = "Body"
	body.model_scene = model
	body.library = library
	holder.add_child(body)
	health = HealthComponent.new()
	health.name = "HealthComponent"
	add_child(health)
	hurtbox = Hurtbox.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = 2  # mesma camada do herói: as áreas de golpe inimigas acertam
	hurtbox.collision_mask = 0
	var hurt_shape := CollisionShape3D.new()
	var hurt_capsule := CapsuleShape3D.new()
	hurt_capsule.radius = 0.45
	hurt_capsule.height = 1.9
	hurt_shape.shape = hurt_capsule
	hurt_shape.position.y = 0.95
	hurtbox.add_child(hurt_shape)
	add_child(hurtbox)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 48
	_label.outline_size = 10
	_label.position.y = 2.4
	_label.modulate = color
	add_child(_label)
	health.max_health = max_health


func _ready() -> void:
	add_to_group(GROUP)
	health.reset(health.max_health)
	hurtbox.hit_received.connect(_on_hit)
	body.set_rim(rim_color, 0.5)
	body.play_action(&"block_idle", 1.0, 0.0, true)
	_refresh_label()


func _physics_process(delta: float) -> void:
	velocity.y = -0.5 if is_on_floor() else velocity.y - 24.0 * delta
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()


func is_alive() -> bool:
	return not health.is_dead


func face(point: Vector3) -> void:
	var direction := point - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.01:
		look_at(global_position + direction, Vector3.UP)


func _on_hit(info: DamageInfo) -> void:
	if health.is_dead:
		return
	health.take_damage(info.amount)
	body.flash(Color(1.0, 0.3, 0.25))
	_refresh_label()
	if health.is_dead:
		body.play_action(&"death", 1.0, 0.0, true)
		SfxLibrary.play(self, &"player_hurt")
		died.emit()
	else:
		body.play_action(&"block_hit", 1.2)
		get_tree().create_timer(0.4, false).timeout.connect(func() -> void:
			if is_instance_valid(self) and not health.is_dead:
				body.play_action(&"block_idle", 1.0, 0.0, true))


func _refresh_label() -> void:
	var fraction := health.current_health / maxf(health.max_health, 1.0)
	_label.text = "%s  %d%%" % [display_name, roundi(fraction * 100.0)] if not health.is_dead else display_name + " (caído)"
