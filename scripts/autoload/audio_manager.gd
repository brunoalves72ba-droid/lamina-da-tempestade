extends Node
## Mixer de efeitos sonoros (autoload "AudioManager"), desacoplado de quem pede o som.
## - Número fixo de canais (MAX_VOICES): nada de criar um AudioStreamPlayer por som.
## - Cada som tem limite de cópias simultâneas e prioridade (tabela SfxLibrary.SOUNDS).
## - Voice stealing: canais cheios → o som novo toma o canal mais antigo de prioridade menor ou
##   igual; se todos forem mais importantes, o som novo é descartado.
## - Também atende o sinal Events.sfx_requested (para sistemas que não querem depender daqui).
## Assim trovões, choques e impactos em sequência não saturam a mixagem.

const MAX_VOICES: int = 20
const DEFAULT_MAX_INSTANCES: int = 4
const DEFAULT_PRIORITY: int = 5
## Mesmo som repetido em menos tempo que isso é ignorado (evita "metralhadora" no mesmo quadro).
const MIN_REPEAT_INTERVAL: float = 0.03

var _voices: Array[AudioStreamPlayer] = []
var _voice_sound: Array[StringName] = []
var _voice_priority: Array[int] = []
var _voice_started: Array[float] = []
var _last_played: Dictionary = {}  # StringName -> segundos
var _dropped: int = 0
var _stolen: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i: int in MAX_VOICES:
		var voice := AudioStreamPlayer.new()
		voice.name = "Voice%d" % i
		add_child(voice)
		_voices.append(voice)
		_voice_sound.append(&"")
		_voice_priority.append(0)
		_voice_started.append(0.0)
	Events.sfx_requested.connect(play)


## Toca um som da tabela SfxLibrary.SOUNDS. Retorna false se foi descartado.
func play(sound: StringName) -> bool:
	var entry: Array = SfxLibrary.SOUNDS.get(sound, [])
	if entry.is_empty():
		push_warning("SFX desconhecido: %s" % sound)
		return false
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(sound, -1.0)) < MIN_REPEAT_INTERVAL:
		return false
	var max_instances: int = entry[2] if entry.size() > 2 else DEFAULT_MAX_INSTANCES
	var priority: int = entry[3] if entry.size() > 3 else DEFAULT_PRIORITY
	var index := _pick_voice(sound, max_instances, priority)
	if index == -1:
		_dropped += 1
		return false
	var stream := SfxLibrary.get_stream(sound)
	if stream == null:
		return false
	var voice := _voices[index]
	voice.stop()
	voice.stream = stream
	voice.volume_db = entry[1]
	voice.pitch_scale = 1.0 + randf_range(-SfxLibrary.PITCH_VARIATION, SfxLibrary.PITCH_VARIATION)
	voice.play()
	_voice_sound[index] = sound
	_voice_priority[index] = priority
	_voice_started[index] = now
	_last_played[sound] = now
	return true


func active_voices() -> int:
	var count := 0
	for voice: AudioStreamPlayer in _voices:
		if voice.playing:
			count += 1
	return count


## [descartados, roubados] desde o início — para medir saturação.
func stats() -> Array[int]:
	return [_dropped, _stolen]


func stop_all() -> void:
	for voice: AudioStreamPlayer in _voices:
		voice.stop()


## Canal para o som: respeita o limite de cópias (rouba a mais antiga do mesmo som), usa um
## canal livre ou rouba o mais antigo de prioridade menor ou igual. -1 = descartar.
func _pick_voice(sound: StringName, max_instances: int, priority: int) -> int:
	var same: Array[int] = []
	var free := -1
	for i: int in MAX_VOICES:
		if not _voices[i].playing:
			if free == -1:
				free = i
		elif _voice_sound[i] == sound:
			same.append(i)
	if same.size() >= max_instances:
		_stolen += 1
		return _oldest(same)
	if free != -1:
		return free
	var candidates: Array[int] = []
	for i: int in MAX_VOICES:
		if _voice_priority[i] <= priority:
			candidates.append(i)
	if candidates.is_empty():
		return -1
	_stolen += 1
	return _oldest(candidates)


func _oldest(indices: Array[int]) -> int:
	var best := indices[0]
	for i: int in indices:
		if _voice_started[i] < _voice_started[best]:
			best = i
	return best
