extends Node
## Trilha sonora (autoload "Music"): exploração, combate e chefão, com transição suave.
## Músicas CC0 em assets/audio/music/ (créditos no GDD §16).
## Uso: Music.play_track(&"explore"); o chefão troca sozinho (Events.boss_engaged).

const TRACKS: Dictionary = {
	&"explore": ["res://assets/audio/music/dark_shrine_loop.ogg", -10.0],
	&"combat": ["res://assets/audio/music/determined_pursuit_loop.ogg", -12.0],
	&"boss": ["res://assets/audio/music/boss_battle_metal_loop.ogg", -10.0],
}
## O tema do chefão começa pela introdução e depois repete o trecho em loop.
const BOSS_OPENING := "res://assets/audio/music/boss_battle_metal_opening.ogg"
const FADE_TIME: float = 1.2
const SILENT_DB: float = -40.0

var current: StringName = &""

var _players: Array[AudioStreamPlayer] = []
var _active: int = 0
var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i: int in 2:
		var player := AudioStreamPlayer.new()
		player.volume_db = SILENT_DB
		add_child(player)
		_players.append(player)
	Events.boss_engaged.connect(func(_boss: Node3D) -> void: play_track(&"boss"))


func play_track(track: StringName) -> void:
	if track == current or not TRACKS.has(track):
		return
	current = track
	var info: Array = TRACKS[track]
	var incoming := _players[1 - _active]
	var outgoing := _players[_active]
	_active = 1 - _active
	var stream := load(info[0]) as AudioStreamOggVorbis
	stream.loop = true
	if track == &"boss":
		var opening := load(BOSS_OPENING) as AudioStreamOggVorbis
		opening.loop = false
		incoming.stream = opening
		if not incoming.finished.is_connected(_on_opening_finished):
			incoming.finished.connect(_on_opening_finished.bind(incoming, stream), CONNECT_ONE_SHOT)
	else:
		incoming.stream = stream
	incoming.volume_db = SILENT_DB
	incoming.play()
	_fade(incoming, outgoing, info[1])


func stop() -> void:
	current = &""
	_fade(null, _players[_active], 0.0)


func _fade(incoming: AudioStreamPlayer, outgoing: AudioStreamPlayer, volume: float) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	if incoming != null:
		_tween.tween_property(incoming, "volume_db", volume, FADE_TIME)
	if outgoing != null and outgoing.playing:
		_tween.tween_property(outgoing, "volume_db", SILENT_DB, FADE_TIME)
		_tween.chain().tween_callback(outgoing.stop)


func _on_opening_finished(player: AudioStreamPlayer, loop_stream: AudioStream) -> void:
	if current == &"boss":
		player.stream = loop_stream
		player.play()
