class_name SfxLibrary
extends RefCounted
## Tabela dos efeitos sonoros (CC0, créditos no GDD §16). Cada nome tem variações sorteadas,
## volume, limite de cópias simultâneas e prioridade; quem toca é o AudioManager (canais limitados
## e voice stealing). Arquivos em assets/audio/sfx/.
## Para conectar sons novos depois (ex.: trovões e choques próprios), basta acrescentar uma linha.

const DIR := "res://assets/audio/sfx/"
const PITCH_VARIATION: float = 0.08
## nome -> [arquivos (sem .ogg), volume em dB, cópias simultâneas, prioridade (maior = mais importante)]
const SOUNDS: Dictionary = {
	&"swing": [["blade_01", "blade_02", "blade_03"], -6.0, 3, 3],
	&"hit": [["creature_hurt_01", "creature_hurt_02", "creature_monster_01", "creature_monster_02"], -4.0, 4, 4],
	&"hit_heavy": [["ground_hit", "creature_hurt_03"], 0.0, 3, 6],
	&"telegraph": [["creature_grunt_01", "creature_grunt_02", "creature_grunt_03", "creature_grunt_04"], -3.0, 2, 9],
	&"parry": [["metal_01", "metal_02", "metal_03"], 0.0, 2, 9],
	&"block": [["shield_block"], -2.0, 2, 7],
	&"player_hurt": [["creature_hurt_03", "stones_01"], -2.0, 2, 8],
	&"whiff": [["blade_02"], -10.0, 2, 1],
	&"zap": [["zap", "electric_impact"], -3.0, 4, 5],
	&"dash": [["electric_dash"], -4.0, 2, 5],
	&"bolt_fire": [["spell_01", "spell_02"], -4.0, 3, 6],
	&"thunder": [["thunder"], 2.0, 2, 7],
	&"charge_full": [["charge"], -6.0, 1, 6],
	&"cast": [["zap_cast"], -6.0, 2, 4],
	&"interrupt": [["metal_03", "zap_heavy"], -2.0, 2, 7],
	&"roar": [["creature_roar_02", "creature_roar_03", "creature_troll_01"], 2.0, 2, 8],
	&"enemy_die": [["creature_die_01", "creature_monster_03", "creature_monster_05"], -3.0, 3, 4],
	&"disintegrate": [["boom"], -8.0, 2, 2],
	&"impact_heavy": [["stones_02", "ground_hit"], 2.0, 2, 7],
	&"level_up": [["level_up"], -3.0, 1, 10],
	&"coins": [["item_coins_01"], -6.0, 2, 2],
}

static var _cache: Dictionary[String, AudioStream] = {}


## Pede um som "dispara e esquece". `_source` fica para quando houver áudio posicional.
static func play(_source: Node, sfx_name: StringName) -> void:
	AudioManager.play(sfx_name)


## Uma das variações do som (sorteada); null se o nome não existir.
static func get_stream(sfx_name: StringName) -> AudioStream:
	var entry: Array = SOUNDS.get(sfx_name, [])
	if entry.is_empty():
		return null
	var file: String = (entry[0] as Array).pick_random()
	if not _cache.has(file):
		_cache[file] = load(DIR + file + ".ogg") as AudioStream
	return _cache[file]
