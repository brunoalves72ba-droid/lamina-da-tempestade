class_name SfxLibrary
extends RefCounted
## Efeitos sonoros gravados (CC0, créditos no GDD §16). Cada nome tem variações sorteadas e um leve
## desvio de tom, para golpes repetidos não soarem iguais. Arquivos em assets/audio/sfx/.

const DIR := "res://assets/audio/sfx/"
const PITCH_VARIATION: float = 0.08
## nome -> [arquivos (sem .ogg), volume em dB]
const SOUNDS: Dictionary = {
	&"swing": [["blade_01", "blade_02", "blade_03"], -6.0],
	&"hit": [["creature_hurt_01", "creature_hurt_02", "creature_monster_01", "creature_monster_02"], -4.0],
	&"hit_heavy": [["ground_hit", "creature_hurt_03"], 0.0],
	&"telegraph": [["creature_grunt_01", "creature_grunt_02", "creature_grunt_03", "creature_grunt_04"], -3.0],
	&"parry": [["metal_01", "metal_02", "metal_03"], 0.0],
	&"block": [["shield_block"], -2.0],
	&"player_hurt": [["creature_hurt_03", "stones_01"], -2.0],
	&"whiff": [["blade_02"], -10.0],
	&"zap": [["zap", "electric_impact"], -3.0],
	&"dash": [["electric_dash"], -4.0],
	&"bolt_fire": [["spell_01", "spell_02"], -4.0],
	&"thunder": [["thunder"], 2.0],
	&"charge_full": [["charge"], -6.0],
	&"cast": [["zap_cast"], -6.0],
	&"interrupt": [["metal_03", "zap_heavy"], -2.0],
	&"roar": [["creature_roar_02", "creature_roar_03", "creature_troll_01"], 2.0],
	&"enemy_die": [["creature_die_01", "creature_monster_03", "creature_monster_05"], -3.0],
	&"disintegrate": [["boom"], -8.0],
	&"impact_heavy": [["stones_02", "ground_hit"], 2.0],
	&"level_up": [["level_up"], -3.0],
	&"coins": [["item_coins_01"], -6.0],
}

static var _cache: Dictionary[String, AudioStream] = {}


## Toca um som "dispara e esquece" como filho de `parent`.
static func play(parent: Node, sfx_name: StringName) -> void:
	var stream := get_stream(sfx_name)
	if stream == null or not parent.is_inside_tree():
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = SOUNDS[sfx_name][1]
	player.pitch_scale = 1.0 + randf_range(-PITCH_VARIATION, PITCH_VARIATION)
	parent.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


## Uma das variações do som (sorteada); null se o nome não existir.
static func get_stream(sfx_name: StringName) -> AudioStream:
	var entry: Array = SOUNDS.get(sfx_name, [])
	if entry.is_empty():
		push_warning("SFX desconhecido: %s" % sfx_name)
		return null
	var file: String = (entry[0] as Array).pick_random()
	if not _cache.has(file):
		_cache[file] = load(DIR + file + ".ogg") as AudioStream
	return _cache[file]
