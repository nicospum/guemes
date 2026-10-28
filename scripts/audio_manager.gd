extends Node
## Original project WAVs. Mix stays quiet enough for tactical information.
## One player per effect bounds simultaneous voices and avoids hoof/cannon spam.

const EFFECTS := {
	"order": {"path": "res://assets/audio/order.wav", "gain_db": -7.0, "cooldown_ms": 100},
	"error": {"path": "res://assets/audio/error.wav", "gain_db": -7.0, "cooldown_ms": 200},
	"cannon": {"path": "res://assets/audio/cannon.wav", "gain_db": -15.0, "cooldown_ms": 900},
	"hoof": {"path": "res://assets/audio/hoof.wav", "gain_db": -13.0, "cooldown_ms": 220},
	"victory": {"path": "res://assets/audio/victory.wav", "gain_db": -7.0, "cooldown_ms": 2500}
}
const AMBIENTS := {"justine": "res://assets/audio/river.wav", "norte": "res://assets/audio/wind.wav"}
const AMBIENT_GAIN_DB := -15.0

var _volume: float = 0.65
var _muted: bool = false
var _players: Dictionary = {}
var _last_play_ms: Dictionary = {}
var _ambient: AudioStreamPlayer
var _scenario: String = ""
var _initialized: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_initialize_audio()
	if not _scenario.is_empty():
		_start_environment()


func _initialize_audio() -> void:
	if _initialized:
		return
	_initialized = true
	for sound in EFFECTS:
		var player := AudioStreamPlayer.new()
		player.name = "Sfx_" + str(sound)
		player.max_polyphony = 1
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		player.stream = load(str(EFFECTS[sound]["path"])) as AudioStream
		add_child(player)
		_players[sound] = player
	_ambient = AudioStreamPlayer.new()
	_ambient.name = "Ambiente"
	_ambient.max_polyphony = 1
	_ambient.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ambient)
	_apply_volume()


func play(sound: String) -> void:
	if not EFFECTS.has(sound) or _muted or _volume <= 0.0 or not is_inside_tree():
		return
	_initialize_audio()
	var now: int = Time.get_ticks_msec()
	if now - int(_last_play_ms.get(sound, -100000)) < int(EFFECTS[sound]["cooldown_ms"]):
		return
	var player: AudioStreamPlayer = _players[sound]
	if player.stream == null:
		return
	# Let a cannon decay completely; hoof beats never overlap themselves.
	if (sound == "cannon" or sound == "hoof" or sound == "victory") and player.playing:
		return
	_last_play_ms[sound] = now
	player.play()


func set_environment(scenario: String) -> void:
	var next_scenario: String = scenario if AMBIENTS.has(scenario) else ""
	if next_scenario == _scenario and is_instance_valid(_ambient) and _ambient.playing:
		return
	_scenario = next_scenario
	if is_inside_tree():
		_initialize_audio()
		_start_environment()


func _start_environment() -> void:
	_ambient.stop()
	if _scenario.is_empty():
		_ambient.stream = null
		return
	var original: AudioStreamWAV = load(str(AMBIENTS[_scenario])) as AudioStreamWAV
	if original == null:
		return
	var loop: AudioStreamWAV = original.duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = maxi(1, roundi(loop.get_length() * float(loop.mix_rate)))
	_ambient.stream = loop
	_apply_volume()
	_ambient.play()


func set_volume(volume: float) -> void:
	_volume = clampf(volume, 0.0, 1.0) if is_finite(volume) else 0.0
	_apply_volume()


func set_muted(muted: bool) -> void:
	_muted = muted
	_apply_volume()
	if muted:
		for sound in _players:
			(_players[sound] as AudioStreamPlayer).stop()


func _apply_volume() -> void:
	var adjustment: float = -80.0 if _muted or _volume <= 0.0 else linear_to_db(_volume)
	for sound in _players:
		(_players[sound] as AudioStreamPlayer).volume_db = maxf(-80.0, float(EFFECTS[sound]["gain_db"]) + adjustment)
	if is_instance_valid(_ambient):
		_ambient.volume_db = maxf(-80.0, AMBIENT_GAIN_DB + adjustment)
		_ambient.stream_paused = _muted or _volume <= 0.0
