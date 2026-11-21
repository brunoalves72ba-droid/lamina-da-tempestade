class_name SfxLibrary
extends RefCounted
## Sons placeholder gerados por síntese (sem arquivos de áudio). Troca por áudio real no M4.

const MIX_RATE: int = 22050
const ATTACK_SHARPNESS: float = 50.0
## nome -> [freq. inicial (Hz), freq. final (Hz), duração (s), volume, mistura de ruído]
const PRESETS: Dictionary = {
	&"swing": [320.0, 120.0, 0.12, 0.22, 0.85],
	&"hit": [190.0, 70.0, 0.14, 0.6, 0.35],
	&"hit_heavy": [140.0, 45.0, 0.25, 0.8, 0.4],
	&"telegraph": [620.0, 980.0, 0.2, 0.45, 0.0],
	&"parry": [2200.0, 500.0, 0.3, 0.6, 0.45],
	&"player_hurt": [240.0, 90.0, 0.22, 0.6, 0.5],
	&"whiff": [500.0, 350.0, 0.08, 0.2, 0.6],
	&"zap": [3200.0, 700.0, 0.18, 0.5, 0.7],
	&"dash": [900.0, 2400.0, 0.2, 0.3, 0.6],
	&"bolt_fire": [400.0, 260.0, 0.1, 0.35, 0.7],
	&"thunder": [90.0, 30.0, 0.9, 0.9, 0.85],
	&"charge_full": [500.0, 1500.0, 0.35, 0.35, 0.3],
	&"interrupt": [1400.0, 300.0, 0.2, 0.5, 0.5],
}

static var _cache: Dictionary[StringName, AudioStreamWAV] = {}


## Toca um som "dispara e esquece" como filho de `parent`.
static func play(parent: Node, sfx_name: StringName) -> void:
	var stream := get_stream(sfx_name)
	if stream == null or not parent.is_inside_tree():
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	parent.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


static func get_stream(sfx_name: StringName) -> AudioStreamWAV:
	if _cache.has(sfx_name):
		return _cache[sfx_name]
	var preset: Array = PRESETS.get(sfx_name, [])
	if preset.is_empty():
		push_warning("SFX desconhecido: %s" % sfx_name)
		return null
	var stream := _synth(preset[0], preset[1], preset[2], preset[3], preset[4])
	_cache[sfx_name] = stream
	return stream


static func _synth(freq_start: float, freq_end: float, duration: float, volume: float, noise: float) -> AudioStreamWAV:
	var sample_count := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var phase := 0.0
	for i: int in sample_count:
		var t := float(i) / float(sample_count)
		phase += TAU * lerpf(freq_start, freq_end, t) / MIX_RATE
		var envelope := minf(1.0, t * ATTACK_SHARPNESS) * pow(1.0 - t, 2.0)
		var sample := sin(phase) * (1.0 - noise) + randf_range(-1.0, 1.0) * noise
		data.encode_s16(i * 2, int(clampf(sample * envelope * volume, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.data = data
	return wav
