extends Node
## SfxPlayer — autoload that owns every sound in the game.
##
## Two jobs:
##   1. `play("hit")` fires one of five short effects. A small voice pool means
##      a chop and a coin can overlap instead of cutting each other off.
##   2. A dedicated BGM player loops the cozy background track from the moment
##      the game boots, at a quiet -14 dB.
##
## The BGM player is PROCESS_MODE_ALWAYS so the music keeps going while the
## pause menu has the tree paused. The effects keep the default mode and go
## silent with the rest of the game.

const AUDIO_DIR := "res://assets/audio/"

## The five effects, keyed by the name callers use.
const SOUNDS := {
	"hit": "hit.wav",
	"water": "water.wav",
	"coin": "coin.wav",
	"catch": "catch.wav",
	"pet": "pet.wav",
}

## First file that exists wins, so swapping bgm.mp3 for an .ogg is a drop-in.
const BGM_CANDIDATES := ["bgm.mp3", "bgm.ogg", "bgm.wav"]
const BGM_VOLUME_DB := -14.0

## Enough voices for a tool swing, a coin and a pet at the same time.
const VOICE_COUNT := 6

var bgm: AudioStreamPlayer

var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0


func _ready() -> void:
	# Music must survive get_tree().paused (pause menu, quest-complete screen).
	process_mode = Node.PROCESS_MODE_ALWAYS

	for key in SOUNDS.keys():
		var stream := _load_audio(AUDIO_DIR + String(SOUNDS[key]))
		if stream != null:
			_streams[key] = stream

	for i in VOICE_COUNT:
		var voice := AudioStreamPlayer.new()
		voice.name = "Voice%d" % i
		add_child(voice)
		_voices.append(voice)

	_start_bgm()


## Play a short effect. Unknown names are ignored, so a missing asset can never
## break gameplay. `volume_db` lets a caller soften a frequent sound.
func play(sound: String, volume_db := 0.0) -> void:
	if _voices.is_empty():
		return
	var stream: AudioStream = _streams.get(sound)
	if stream == null:
		return
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = stream
	voice.volume_db = volume_db
	voice.play()


func stop_bgm() -> void:
	if bgm != null:
		bgm.stop()


func is_bgm_playing() -> bool:
	return bgm != null and bgm.playing


# ------------------------------------------------------------------ internals

func _start_bgm() -> void:
	for file in BGM_CANDIDATES:
		var stream := _load_audio(AUDIO_DIR + String(file))
		if stream == null:
			continue
		bgm = AudioStreamPlayer.new()
		bgm.name = "BGM"
		bgm.stream = stream
		bgm.volume_db = BGM_VOLUME_DB
		bgm.process_mode = Node.PROCESS_MODE_ALWAYS
		bgm.finished.connect(_on_bgm_finished)
		add_child(bgm)
		bgm.play()
		return
	push_warning("SfxPlayer: tidak ada file BGM di %s" % AUDIO_DIR)


## Seamless loop: restart the track when it reaches the end.
func _on_bgm_finished() -> void:
	if bgm != null:
		bgm.play()


func _load_audio(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream
