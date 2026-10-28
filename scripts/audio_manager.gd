extends Node
## Audio original del proyecto (WAV sintetizados con tools/generate_audio.py).
## Mezcla por bus (Musica, Ambiente, Efectos, UI) con limitador en Master,
## variacion de tono por reproduccion, variantes de muestra, polifonia por efecto
## y un tope global de voces para que el campo de batalla no sature la mezcla.

const BUS_MUSIC := "Musica"
const BUS_AMBIENT := "Ambiente"
const BUS_SFX := "Efectos"
const BUS_UI := "UI"
## Niveles de bus en dB (Master lleva un limitador a -1 dB).
const BUS_LEVELS := {"Musica": -6.0, "Ambiente": -3.0, "Efectos": 0.0, "UI": -2.0}

## variants: archivos alternativos al azar. pitch: [min, max] de pitch_scale.
## poly: voces simultaneas de ese efecto. retrigger=false impide reiniciarlo mientras suena.
## prio: 2 aviso/resultado (nunca se descarta), 1 normal, 0 ambiental/repetitivo.
const EFFECTS := {
	"order": {"variants": ["res://assets/audio/order.wav"], "bus": "UI", "gain_db": -4.0, "cooldown_ms": 100, "pitch": [0.97, 1.05], "poly": 2, "retrigger": true, "prio": 1},
	"error": {"variants": ["res://assets/audio/error.wav"], "bus": "UI", "gain_db": -4.0, "cooldown_ms": 200, "pitch": [0.96, 1.03], "poly": 1, "retrigger": true, "prio": 2},
	"alert": {"variants": ["res://assets/audio/alert.wav"], "bus": "UI", "gain_db": -5.0, "cooldown_ms": 1500, "pitch": [1.0, 1.0], "poly": 1, "retrigger": false, "prio": 2},
	"bell": {"variants": ["res://assets/audio/bell.wav"], "bus": "UI", "gain_db": -9.0, "cooldown_ms": 2500, "pitch": [0.99, 1.01], "poly": 1, "retrigger": false, "prio": 2},
	"cannon": {"variants": ["res://assets/audio/cannon.wav"], "bus": "Efectos", "gain_db": -13.0, "cooldown_ms": 900, "pitch": [0.9, 1.08], "poly": 2, "retrigger": true, "prio": 1},
	"hoof": {"variants": ["res://assets/audio/hoof.wav", "res://assets/audio/hoof2.wav", "res://assets/audio/hoof3.wav"], "bus": "Efectos", "gain_db": -10.0, "cooldown_ms": 220, "pitch": [0.92, 1.1], "poly": 1, "retrigger": false, "prio": 0},
	"dismount": {"variants": ["res://assets/audio/dismount.wav"], "bus": "Efectos", "gain_db": -9.0, "cooldown_ms": 1500, "pitch": [0.96, 1.04], "poly": 1, "retrigger": false, "prio": 1},
	"victory": {"variants": ["res://assets/audio/victory.wav"], "bus": "UI", "gain_db": -7.0, "cooldown_ms": 2500, "pitch": [1.0, 1.0], "poly": 1, "retrigger": false, "prio": 2}
}
## Cada escenario superpone capas ambientales de duraciones distintas (no se repiten a la vez).
const AMBIENTS := {
	"justine": [
		{"path": "res://assets/audio/river.wav", "gain_db": -13.0},
		{"path": "res://assets/audio/ribera.wav", "gain_db": -17.0}
	],
	"norte": [
		{"path": "res://assets/audio/wind.wav", "gain_db": -14.0},
		{"path": "res://assets/audio/wind_north.wav", "gain_db": -16.0}
	]
}
const MAX_VOICES := 6
## Espera al salir para que la hebra de audio retire las reproducciones detenidas.
const DRAIN_MS := 150

var _volume: float = 0.65
var _muted: bool = false
var _players: Dictionary = {}
var _last_play_ms: Dictionary = {}
## sound -> instantes (ms) en que termina cada voz activa; su suma es el conteo real de voces.
var _voice_ends: Dictionary = {}
var _ambient_players: Array = []
var _scenario: String = ""
var _initialized: bool = false
var _rng := RandomNumberGenerator.new()
var dropped_count: int = 0
var _drained: bool = false


func shutdown() -> void:
	## Libera reproductores y referencias en toda salida, incluido el cierre de ventana.
	## Detener un reproductor solo marca su reproduccion para borrado: la hebra de mezcla
	## la retira en su proximo paso. Si el proceso termina antes, el AudioStreamWAV y su
	## AudioStreamPlaybackWAV quedan vivos (ObjectDB filtrados al salir). Por eso se espera
	## a que la mezcla drene lo detenido antes de devolver el control.
	var had_audio := false
	for player in _players.values():
		if is_instance_valid(player) and player.playing:
			had_audio = true
	for player in _ambient_players:
		if is_instance_valid(player):
			had_audio = true
	for player in _players.values():
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	_players.clear()
	_voice_ends.clear()
	for player in _ambient_players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	_ambient_players.clear()
	_variant_cache.clear()
	_scenario = ""
	if had_audio and not _drained:
		_drained = true
		OS.delay_msec(DRAIN_MS)


var _variant_cache: Dictionary = {}


func _exit_tree() -> void:
	shutdown()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_initialize_audio()
	if not _scenario.is_empty():
		_start_environment()


static func ensure_buses() -> void:
	## Crea los buses una sola vez (idempotente) y un limitador en Master.
	for bus_name in BUS_LEVELS:
		var idx: int = AudioServer.get_bus_index(bus_name)
		if idx < 0:
			AudioServer.add_bus()
			idx = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
		AudioServer.set_bus_volume_db(idx, float(BUS_LEVELS[bus_name]))
	var master: int = AudioServer.get_bus_index("Master")
	var has_limiter := false
	for i in AudioServer.get_bus_effect_count(master):
		if AudioServer.get_bus_effect(master, i) is AudioEffectHardLimiter:
			has_limiter = true
	if not has_limiter:
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = -1.0
		limiter.pre_gain_db = 0.0
		AudioServer.add_bus_effect(master, limiter)


func _initialize_audio() -> void:
	if _initialized:
		return
	_initialized = true
	_rng.randomize()
	ensure_buses()
	for sound in EFFECTS:
		var def: Dictionary = EFFECTS[sound]
		var player := AudioStreamPlayer.new()
		player.name = "Sfx_" + str(sound)
		player.bus = str(def["bus"])
		player.max_polyphony = int(def["poly"])
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_players[sound] = player
		_voice_ends[sound] = []
	_apply_volume()


func _stream_for(sound: String) -> AudioStream:
	var paths: Array = EFFECTS[sound]["variants"]
	var path: String = str(paths[_rng.randi_range(0, paths.size() - 1)])
	if not _variant_cache.has(path):
		_variant_cache[path] = load(path) as AudioStream
	return _variant_cache[path]


func _prune_voices(now: int) -> void:
	## Descarta voces cuya reproduccion ya termino (o cuyo reproductor se detuvo).
	for sound in _voice_ends:
		var ends: Array = _voice_ends[sound]
		var player: AudioStreamPlayer = _players[sound]
		if not player.playing:
			ends.clear()
			continue
		var i := 0
		while i < ends.size():
			if int(ends[i]) <= now:
				ends.remove_at(i)
			else:
				i += 1


func _active_voices() -> int:
	## Voces reales: cada reproduccion simultanea de un efecto cuenta una (no un reproductor).
	_prune_voices(Time.get_ticks_msec())
	var count := 0
	for sound in _voice_ends:
		count += (_voice_ends[sound] as Array).size()
	return count


func _steal_voice(min_prio: int) -> bool:
	## Libera lugar para un aviso (prio 2) deteniendo el efecto activo de menor prioridad.
	var victim := ""
	var victim_prio := min_prio
	for sound in _voice_ends:
		if (_voice_ends[sound] as Array).is_empty():
			continue
		var prio: int = int(EFFECTS[sound]["prio"])
		if prio < victim_prio:
			victim = str(sound)
			victim_prio = prio
	if victim.is_empty():
		return false
	(_players[victim] as AudioStreamPlayer).stop()
	(_voice_ends[victim] as Array).clear()
	dropped_count += 1
	return true


func play(sound: String) -> void:
	if not EFFECTS.has(sound) or _muted or _volume <= 0.0 or not is_inside_tree():
		return
	_initialize_audio()
	var def: Dictionary = EFFECTS[sound]
	var now: int = Time.get_ticks_msec()
	if now - int(_last_play_ms.get(sound, -100000)) < int(def["cooldown_ms"]):
		return
	var player: AudioStreamPlayer = _players[sound]
	if player.playing and not bool(def["retrigger"]):
		return
	# Tope global real de voces: bajo presion se descartan los sonidos de baja prioridad y
	# un aviso (prio 2) desplaza al efecto activo de menor prioridad. Reiniciar un efecto
	# no retrigerable de una sola voz no suma una voz nueva.
	var ends: Array = _voice_ends[sound]
	var reuses_slot: bool = player.playing and ends.size() >= int(def["poly"])
	if not reuses_slot and _active_voices() >= MAX_VOICES:
		if int(def["prio"]) < 2:
			dropped_count += 1
			return
		if not _steal_voice(2):
			dropped_count += 1
			return
	var stream: AudioStream = _stream_for(sound)
	if stream == null:
		return
	# Asignar el mismo stream detiene las voces activas y anularia la polifonia.
	if player.stream != stream and not player.playing:
		player.stream = stream
	var range_pitch: Array = def["pitch"]
	player.pitch_scale = _rng.randf_range(float(range_pitch[0]), float(range_pitch[1]))
	_last_play_ms[sound] = now
	player.play()
	ends.append(now + int(stream.get_length() * 1000.0 / maxf(0.01, player.pitch_scale)))
	while ends.size() > int(def["poly"]):
		ends.remove_at(0)


func set_environment(scenario: String) -> void:
	var next_scenario: String = scenario if AMBIENTS.has(scenario) else ""
	if next_scenario == _scenario and not _ambient_players.is_empty() and (_ambient_players[0] as AudioStreamPlayer).playing:
		return
	_scenario = next_scenario
	if is_inside_tree():
		_initialize_audio()
		_start_environment()


func _clear_ambient() -> void:
	for player in _ambient_players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
			player.queue_free()
	_ambient_players.clear()


func _start_environment() -> void:
	_clear_ambient()
	if _scenario.is_empty():
		return
	for layer in AMBIENTS[_scenario]:
		var original: AudioStreamWAV = load(str(layer["path"])) as AudioStreamWAV
		if original == null:
			continue
		var loop: AudioStreamWAV = original.duplicate() as AudioStreamWAV
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_begin = 0
		loop.loop_end = maxi(1, roundi(loop.get_length() * float(loop.mix_rate)))
		var player := AudioStreamPlayer.new()
		player.name = "Ambiente_" + str(layer["path"]).get_file().get_basename()
		player.bus = BUS_AMBIENT
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		player.stream = loop
		player.set_meta("gain_db", float(layer["gain_db"]))
		add_child(player)
		_ambient_players.append(player)
	_apply_volume()
	for player in _ambient_players:
		# Arranque en un punto al azar: las capas no coinciden siempre igual.
		(player as AudioStreamPlayer).play(_rng.randf() * (player as AudioStreamPlayer).stream.get_length())


func set_volume(volume: float) -> void:
	_volume = clampf(volume, 0.0, 1.0) if is_finite(volume) else 0.0
	_apply_volume()


func set_muted(muted: bool) -> void:
	_muted = muted
	_apply_volume()
	if muted:
		for sound in _players:
			(_players[sound] as AudioStreamPlayer).stop()
			(_voice_ends[sound] as Array).clear()


func _apply_volume() -> void:
	var adjustment: float = -80.0 if _muted or _volume <= 0.0 else linear_to_db(_volume)
	for sound in _players:
		(_players[sound] as AudioStreamPlayer).volume_db = maxf(-80.0, float(EFFECTS[sound]["gain_db"]) + adjustment)
	for player in _ambient_players:
		if is_instance_valid(player):
			(player as AudioStreamPlayer).volume_db = maxf(-80.0, float(player.get_meta("gain_db", -15.0)) + adjustment)
			(player as AudioStreamPlayer).stream_paused = _muted or _volume <= 0.0
