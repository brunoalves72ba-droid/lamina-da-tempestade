extends Node
## Signal bus global (autoload "Events").
## Só para eventos que cruzam sistemas desacoplados; eventos locais usam sinais do próprio nó.

@warning_ignore("unused_signal")
signal damage_taken(target: Node3D, info: DamageInfo)
@warning_ignore("unused_signal")
signal parry_succeeded(defender: Node3D, attacker: Node3D)
@warning_ignore("unused_signal")
signal entity_died(entity: Node3D)
## Último inimigo de uma onda morto por golpe forte (GDD §6.7).
@warning_ignore("unused_signal")
signal wave_finisher(enemy: Node3D)
## Um poder de raio foi solto (kind = PowerData.Kind) na posição do alvo.
@warning_ignore("unused_signal")
signal power_unleashed(kind: int, at_position: Vector3, color: Color)
