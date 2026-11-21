class_name Cooldown
extends Node
## Recarga simples no relógio de física (respeita hitstop e --fixed-fps).

signal became_ready

@export var duration: float = 1.0

var remaining: float = 0.0
var is_ready: bool:
	get:
		return remaining <= 0.0


func start(new_duration: float = -1.0) -> void:
	remaining = duration if new_duration < 0.0 else new_duration


func reset() -> void:
	remaining = 0.0


func _physics_process(delta: float) -> void:
	if remaining <= 0.0:
		return
	remaining = maxf(0.0, remaining - delta)
	if remaining <= 0.0:
		became_ready.emit()
