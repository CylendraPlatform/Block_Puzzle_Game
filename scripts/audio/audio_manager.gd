extends Node
## Autoload "Audio" — plays original SFX and an optional ambient music loop,
## gated by the Settings autoload. Also fires device haptics.

const DIR := "res://assets/audio/"
const SFX_FILES := {
	"tap": "tap.wav",
	"slide": "slide.wav",
	"bump": "bump.wav",
	"exit": "exit.wav",
	"win": "win.wav",
}

var _sfx: Dictionary = {}          ## name -> AudioStream
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music_player: AudioStreamPlayer
var _music_stream: AudioStream

func _ready() -> void:
	for key in SFX_FILES:
		var s: AudioStream = load(DIR + SFX_FILES[key])
		if s:
			_sfx[key] = s
	for i in range(6):                      ## small voice pool for overlap
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	_music_player.volume_db = -6.0
	add_child(_music_player)
	_music_stream = load(DIR + "music_loop.wav")
	if _music_stream is AudioStreamWAV:
		_music_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		_music_stream.loop_begin = 0
	if Settings:
		Settings.changed.connect(_on_settings_changed)
	_apply_music()

func sfx(name: String) -> void:
	if not Settings or not Settings.sfx:
		return
	var s: AudioStream = _sfx.get(name)
	if s == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = s
	p.play()

func haptic(ms: int = 20) -> void:
	if Settings and Settings.haptics:
		Input.vibrate_handheld(ms)

func _on_settings_changed() -> void:
	_apply_music()

func _apply_music() -> void:
	if Settings and Settings.music:
		if _music_stream and not _music_player.playing:
			_music_player.stream = _music_stream
			_music_player.play()
	else:
		_music_player.stop()
