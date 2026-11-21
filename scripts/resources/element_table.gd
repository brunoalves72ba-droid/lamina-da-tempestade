class_name ElementTable
extends Resource
## Multiplicadores e cores do ciclo elemental (GDD §7). Valores em data/combat/elements.tres.

@export var advantage_multiplier: float = 1.5
@export var disadvantage_multiplier: float = 0.75

@export_group("Cores")
@export var neutral_color: Color = Color(0.6, 0.85, 1.0)
@export var divine_color: Color = Color(1.0, 0.82, 0.35)
@export var demonic_color: Color = Color(0.78, 0.16, 0.48)
@export var heroic_color: Color = Color(0.38, 0.62, 0.98)
