class_name StateMachine
extends Node
## Máquina de estados: cada filho State é um estado, endereçado pelo nome do nó.

signal state_changed(state_name: StringName)

@export var initial_state: State

var current_state: State

var _states: Dictionary[StringName, State] = {}


func _ready() -> void:
	for child: Node in get_children():
		var state := child as State
		if state != null:
			state.machine = self
			_states[StringName(state.name)] = state
	# Os estados usam nós do dono; espera ele ficar pronto antes de entrar no estado inicial.
	await owner.ready
	assert(initial_state != null, "StateMachine sem initial_state em %s" % owner.name)
	current_state = initial_state
	state_changed.emit(StringName(current_state.name))
	current_state.enter()


func _physics_process(delta: float) -> void:
	if current_state != null:
		current_state.physics_update(delta)


func transition_to(state_name: StringName, msg: Dictionary = {}) -> void:
	assert(_states.has(state_name), "Estado inexistente: %s" % state_name)
	if current_state != null:
		current_state.exit()
	current_state = _states[state_name]
	# Emite antes do enter() para que transições encadeadas saiam na ordem certa.
	state_changed.emit(state_name)
	current_state.enter(msg)


func is_in(state_name: StringName) -> bool:
	return current_state != null and StringName(current_state.name) == state_name
