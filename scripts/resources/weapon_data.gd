class_name WeaponData
extends Resource
## Arma do herói: dano, elemento e tempos do combo (GDD §6.1). Valores em data/weapons/*.tres.

@export var display_name: String = "Espada"
@export var base_damage: float = 10.0
@export var element: Element.Type = Element.Type.NONE

@export_group("Combo")
## Um multiplicador por golpe; o tamanho do array define o tamanho do combo.
@export var combo_multipliers: Array[float] = [1.0, 1.0, 1.6]
## Índices do combo que contam como golpe forte.
@export var heavy_hits: Array[int] = [2]
@export var hit_windup: float = 0.1
@export var hit_active: float = 0.1
@export var hit_recovery: float = 0.3
@export var final_hit_recovery: float = 0.45
