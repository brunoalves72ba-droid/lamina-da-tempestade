class_name DamageInfo
extends RefCounted
## Pacote de dano trocado entre atacante e Hurtbox. Cada alvo recebe a sua cópia.

var amount: float = 0.0
var element: Element.Type = Element.Type.NONE
var is_heavy: bool = false
## Marcado pelo defensor quando o golpe vira contra-ataque (GDD §6.2).
var is_counter: bool = false
## Multiplicador que o defensor aplica se estiver atordoado.
var counter_multiplier: float = 1.0
## Preenchido pelo defensor: vantagem (>1), neutro (1) ou desvantagem (<1) elemental (GDD §7).
var element_multiplier: float = 1.0
var can_be_parried: bool = false
var source: Node3D
## Chamado pelo defensor quando este golpe é aparado.
var on_parried: Callable
## Poder de raio (não é golpe físico de espada).
var is_power: bool = false
## Segundos de Eletrocutado que o golpe causa (0 = nenhum).
var shock_time: float = 0.0
## Marcado pelo defensor: golpe físico num alvo eletrocutado vira crítico.
var is_critical: bool = false


func copy() -> DamageInfo:
	var clone := DamageInfo.new()
	clone.amount = amount
	clone.element = element
	clone.is_heavy = is_heavy
	clone.is_counter = is_counter
	clone.counter_multiplier = counter_multiplier
	clone.element_multiplier = element_multiplier
	clone.can_be_parried = can_be_parried
	clone.source = source
	clone.on_parried = on_parried
	clone.is_power = is_power
	clone.shock_time = shock_time
	clone.is_critical = is_critical
	return clone
