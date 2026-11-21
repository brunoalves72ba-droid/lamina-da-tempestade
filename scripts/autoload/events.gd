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
## Um chefão percebeu o herói (rugido): o HUD mostra a barra de vida dele.
@warning_ignore("unused_signal")
signal boss_engaged(boss: Node3D)
## Pedido de tremor de câmera (impactos de chefão), de 0 a 1.
@warning_ignore("unused_signal")
signal shake_requested(amount: float)
## Pedido de efeito sonoro (nome da tabela SfxLibrary.SOUNDS); o AudioManager decide o canal.
@warning_ignore("unused_signal")
signal sfx_requested(sound: StringName)
## História (StoryDirector): objetivo atual mudou, fala de narração, arco concluído.
@warning_ignore("unused_signal")
signal objective_changed(arc_title: String, objective_text: String)
@warning_ignore("unused_signal")
signal narration_requested(speaker: String, text: String, duration: float)
@warning_ignore("unused_signal")
signal arc_completed(arc_index: int)
## Momentos que a história escuta: clareira vencida, fogueira acesa, chefão derrotado, santuário.
@warning_ignore("unused_signal")
signal zone_cleared(zone_name: String)
@warning_ignore("unused_signal")
signal checkpoint_reached(route_progress: float)
@warning_ignore("unused_signal")
signal boss_defeated(boss_id: StringName)
@warning_ignore("unused_signal")
signal shrine_reached
## Modo de mira trocado (GameState.AimMode).
@warning_ignore("unused_signal")
signal aim_mode_changed(mode: int)
## Um poder de raio foi solto (kind = PowerData.Kind) na posição do alvo.
@warning_ignore("unused_signal")
signal power_unleashed(kind: int, at_position: Vector3, color: Color)
