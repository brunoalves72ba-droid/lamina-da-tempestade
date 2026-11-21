class_name State
extends Node
## Estado base de uma StateMachine. Subclasses sobrescrevem os ganchos.

var machine: StateMachine


func enter(_msg: Dictionary = {}) -> void:
	pass


func exit() -> void:
	pass


func physics_update(_delta: float) -> void:
	pass
