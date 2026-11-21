class_name InputBuffer
extends Node
## Guarda apertos de ações por uma janela curta, para que um input feito
## alguns frames cedo não seja perdido (CLAUDE.md › Entrada).
## O relógio avança no physics process, então respeita hitstop e --fixed-fps.

@export var actions: Array[StringName] = [&"attack", &"parry", &"skill_1", &"skill_2", &"skill_3"]
@export var buffer_time: float = 0.2

var enabled: bool = true

var _clock: float = 0.0
var _press_times: Dictionary[StringName, float] = {}


func _physics_process(delta: float) -> void:
	_clock += delta


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	for action: StringName in actions:
		if event.is_action_pressed(action):
			press(action)


## Registra um aperto. Também usado por testes automáticos.
func press(action: StringName) -> void:
	if enabled:
		_press_times[action] = _clock


func is_buffered(action: StringName) -> bool:
	if not _press_times.has(action):
		return false
	return _clock - _press_times[action] <= buffer_time


func consume(action: StringName) -> bool:
	if not is_buffered(action):
		return false
	_press_times.erase(action)
	return true


func clear(action: StringName = &"") -> void:
	if action == &"":
		_press_times.clear()
	else:
		_press_times.erase(action)
