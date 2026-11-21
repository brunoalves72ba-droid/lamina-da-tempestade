class_name Hitstop
extends RefCounted
## Único lugar que mexe em Engine.time_scale (CLAUDE.md › Tempo).
## Vários efeitos podem se sobrepor; vale sempre a menor escala ativa.
## Durações em segundos reais (timers que ignoram a escala de tempo).

static var _active: Dictionary[int, float] = {}
static var _next_id: int = 0


## Congela/desacelera o jogo por `duration` segundos reais. Use sem await.
static func apply(tree: SceneTree, time_scale: float, duration: float) -> void:
	if duration <= 0.0:
		return
	_next_id += 1
	var id := _next_id
	_active[id] = time_scale
	_refresh()
	await tree.create_timer(duration, true, false, true).timeout
	_active.erase(id)
	_refresh()


## Volta tudo ao normal (início de fase, reload de cena).
static func reset() -> void:
	_active.clear()
	Engine.time_scale = 1.0


static func _refresh() -> void:
	var scale := 1.0
	for value: float in _active.values():
		scale = minf(scale, value)
	Engine.time_scale = scale
