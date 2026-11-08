extends Node
## Sonido del nivel «humahuaca» (pista visual; CONTRATO 1.2: assets/audio/humahuaca/** es de visual). Reproduce con AudioStreamPlayer PROPIOS los WAV
## originales de assets/audio/humahuaca/ según el mapeo de data/humahuaca_audio.json, sobre los buses que crea scripts/audio_manager.gd (Ambiente, Efectos,
## UI; Master si no existen) y respetando main.settings.volume y main.settings.muted (lo mismo que obedece el audio_manager, que NO se toca).
##
## Qué escucha (sin cambiar ninguna otra capa):
##   · render_state(): la fase (aproximacion → ataque → extraccion → epilogo), el ambiente (noche / alba / dia y la lluvia: capas ambientales en lazo),
##     la torre (cada vez que su cuenta de recarga vuelve a empezar, acaba de descargar) y la textura del mundo (cascos de las montadas, pasos, carga del
##     arreo, tiros y choques en los frentes asaltados, el tambor de la columna realista).
##   · state.log de las reglas: los eventos que ya emite tick() (señal, alarma, captura, mensajero, refuerzo, carga, destrucción, vado…). Si el controlador
##     los reenvía con on_events(), se deja de leer el registro.
##   · hud_state(): una decisión nueva.
##   · state.status: victoria o derrota.
## Qué NO duplica: los eventos que el controlador ya hace sonar con un nombre que audio_manager conoce (humahuaca_ui.json: toasts.kinds[*].sound) los
## sigue sonando el controlador; este nodo calla en esos casos. Si el controlador enruta su play_sound() por play_ui(), los nombres viejos ("order",
## "cannon", "alert"…) se traducen por «aliases» a los sonidos del nivel y los eventos con sonido del controlador quedan todos a su cargo.
##
## Enganche (una línea en humahuaca_ui.gd::start(), pista ui_feel; ver docs/humahuaca/SONIDO.md):
##   load("res://scripts/humahuaca/view/humahuaca_audio.gd").attach_to(self)
## Sin ese gancho el nodo no se crea y el nivel suena como hasta ahora (solo los avisos del controlador, con los .wav de la Justina a otro tono).

const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")
const R = preload("res://scripts/humahuaca/rules/vocab_rules.gd")  # vista → reglas: hacia abajo (V19)
const VV = preload("res://scripts/humahuaca/view/vocab_view.gd")

const AUDIO_PATH := "res://data/humahuaca_audio.json"
const SELF_PATH := "res://scripts/humahuaca/view/humahuaca_audio.gd"
const NODE_NAME := "HumahuacaAudio"
const DEFAULT_MAX_VOICES := 8
const SILENT_DB := -80.0
const LOG_KEEP := 64

var data: Dictionary = {}
var main: Node = null  ## main.gd: settings (volume, muted) y audio_manager (buses y su ambiente)
var host: Node = null  ## el controlador, si se enganchó con attach_to(): de él se leen rules, paused y mode en cada cuadro
var rules: RefCounted = null
var enabled := true
var missing: Array = []  ## rutas de WAV que no cargaron
var stats := {"requested": 0, "played": 0, "cooldown": 0, "capped": 0, "silenced": 0, "unknown": 0, "skipped_covered": 0}
var played_log: Array = []  ## los últimos sonidos reproducidos: [{sound, via}] (lo leen las pruebas)

var _players: Dictionary = {}  ## id de sonido → AudioStreamPlayer
var _streams: Dictionary = {}  ## ruta → AudioStreamWAV
var _last_ms: Dictionary = {}
var _ambient: Array = []  ## [{player, sound, cfg}]
var _ambient_phase := ""
var _rain := -1.0
var _volume := 1.0
var _muted := false
var _rng := RandomNumberGenerator.new()
var _poll := {"render": 0.0, "hud": 0.0, "settings": 0.0}
var _seen := {}
var _world_timers: Dictionary = {}
var _external_events := false  ## alguien llama on_events(): el registro de las reglas ya no se lee
var _ui_routed := false  ## el controlador enruta play_sound() por play_ui(): todo evento con sonido del controlador queda a su cargo
var _manager_sounds: Array = []  ## nombres que audio_manager.EFFECTS conoce (los que el controlador ya hace sonar)
var _ui_sounds: Dictionary = {}  ## kind de evento → nombre que el controlador pide (humahuaca_ui.json: toasts.kinds)


# ---------------------------------------------------------------------------------------------------------------------
# Enganche

## El gancho de una línea para el controlador: crea el nodo como hijo suyo (se libera con él, sin huérfanos) y le toma main y rules. Idempotente.
static func attach_to(controller: Node) -> Node:
	if controller == null or not is_instance_valid(controller):
		return null
	var existing := controller.get_node_or_null(NODE_NAME)
	if existing != null:
		return existing
	var node: Node = load(SELF_PATH).new()
	node.name = NODE_NAME
	controller.add_child(node)
	var m: Variant = controller.get("main")
	var r: Variant = controller.get("rules")
	node.call("attach", m if m is Node else null, r if r is RefCounted else null, controller)
	return node


## Prepara reproductores y capas; `host_node` es opcional (el controlador): si está, rules se relee de él en cada cuadro (cambia en cada reintento).
func attach(main_node: Node, rules_ref: RefCounted, host_node: Node = null) -> void:
	main = main_node
	host = host_node
	rules = rules_ref
	_rng.randomize()
	data = V.load_json(AUDIO_PATH)
	_reset_tracking()
	_build_players()
	_read_controller_sounds()
	_read_settings()
	if rules != null:
		_poll_render(true)
	set_process(true)


## Detiene y libera lo propio. Se puede llamar más de una vez.
func detach() -> void:
	set_process(false)
	_clear_ambient()
	for id in _players:
		var player: AudioStreamPlayer = _players[id]
		if is_instance_valid(player):
			player.stop()
			player.stream = null
			player.queue_free()
	_players.clear()
	_streams.clear()
	_ambient_phase = ""
	rules = null
	host = null
	main = null


func _exit_tree() -> void:
	detach()


func _reset_tracking() -> void:
	_seen = {"phase": "", "status": "", "env_phase": "", "tower_next": -1.0, "tower_firing": false, "decision": "", "log_t": -1.0, "log_same": 0}
	_world_timers = {}
	_rain = -1.0
	_external_events = false


# ---------------------------------------------------------------------------------------------------------------------
# Reproductores y buses

func _bus_for(key: String) -> String:
	var buses: Dictionary = data.get("buses", {})
	var wanted := str(buses.get(key, ""))
	if wanted != "" and AudioServer.get_bus_index(wanted) >= 0:
		return wanted
	var fallback := str(buses.get("fallback", "Master"))
	return fallback if AudioServer.get_bus_index(fallback) >= 0 else "Master"


func _build_players() -> void:
	var sounds: Dictionary = data.get("sounds", {})
	var dir := str(data.get("dir", "res://assets/audio/humahuaca/"))
	for id in sounds:
		var def: Dictionary = sounds[id]
		for f in def.get("files", []):
			var path := dir + str(f)
			if not _streams.has(path):
				var stream: AudioStream = load(path) as AudioStream if ResourceLoader.exists(path) else null
				if stream == null:
					missing.append(path)
				else:
					_streams[path] = stream
		if str(def.get("kind", "oneshot")) == "loop":
			continue  # las capas ambientales tienen su reproductor propio al activarse
		var player := AudioStreamPlayer.new()
		player.name = "Sfx_" + str(id)
		player.bus = _bus_for(str(def.get("bus", "sfx")))
		player.max_polyphony = maxi(1, int(def.get("poly", 1)))
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_players[id] = player


func _manager() -> Node:
	if main == null or not is_instance_valid(main):
		return null
	var am: Variant = main.get("audio_manager")
	return am if am is Node and is_instance_valid(am) else null


## Qué nombres conoce audio_manager (sus EFFECTS) y qué nombre pide el controlador por cada evento (humahuaca_ui.json): con eso se evita duplicar.
func _read_controller_sounds() -> void:
	_manager_sounds = []
	var am := _manager()
	if am != null and am.get_script() != null:
		var consts: Dictionary = (am.get_script() as Script).get_script_constant_map()
		var effects: Variant = consts.get("EFFECTS", {})
		if effects is Dictionary:
			for k in effects:
				_manager_sounds.append(str(k))
	_ui_sounds = {}
	var ui := V.load_json(V.UI_PATH)
	var kinds: Variant = (ui.get("toasts", {}) as Dictionary).get("kinds", {})
	if kinds is Dictionary:
		for kind in kinds:
			var cfg: Variant = kinds[kind]
			if cfg is Dictionary and str((cfg as Dictionary).get("sound", "")) != "":
				_ui_sounds[str(kind)] = str((cfg as Dictionary).get("sound", ""))


## ¿Ese evento ya lo hace sonar el controlador? Hoy, si pide un nombre que audio_manager conoce; con play_sound() enrutado por acá, si pide cualquier nombre.
func covered_by_controller(kind: String) -> bool:
	var name_text := str(_ui_sounds.get(kind, ""))
	if name_text == "":
		return false
	return _ui_routed or _manager_sounds.has(name_text)


func _covered_name(name_text: String) -> bool:
	return _ui_routed or _manager_sounds.has(name_text)


# ---------------------------------------------------------------------------------------------------------------------
# Volumen y silencio (los de main.settings, que son los que obedece el audio_manager)

## Relee settings.volume y settings.muted ya mismo (el sondeo lo hace cada 0,25 s).
func sync_settings() -> void:
	_read_settings()


func _read_settings() -> void:
	var volume := 1.0
	var muted := false
	if main != null and is_instance_valid(main):
		var s: Variant = main.get("settings")
		if s is Dictionary:
			var v: Variant = (s as Dictionary).get("volume", 1.0)
			volume = clampf(float(v), 0.0, 1.0) if (v is float or v is int) and is_finite(float(v)) else 0.0
			muted = bool((s as Dictionary).get("muted", false))
	if volume != _volume or muted != _muted:
		_volume = volume
		_muted = muted
		_apply_volume()


func _silent() -> bool:
	return _muted or _volume <= 0.0


func _apply_volume() -> void:
	var adjust: float = SILENT_DB if _silent() else linear_to_db(_volume)
	var sounds: Dictionary = data.get("sounds", {})
	for id in _players:
		var player: AudioStreamPlayer = _players[id]
		if not is_instance_valid(player):
			continue
		player.volume_db = maxf(SILENT_DB, float((sounds.get(id, {}) as Dictionary).get("gain_db", -6.0)) + adjust)
		if _silent() and player.playing:
			player.stop()
	for layer in _ambient:
		var player: AudioStreamPlayer = layer.player
		if is_instance_valid(player):
			player.volume_db = maxf(SILENT_DB, _layer_gain(layer) + adjust)
			player.stream_paused = _silent()


# ---------------------------------------------------------------------------------------------------------------------
# Reproducción

## Nombre del nivel o nombre viejo del controlador (aliases). "" si no existe.
func resolve(name_text: String) -> String:
	var sounds: Dictionary = data.get("sounds", {})
	if sounds.has(name_text):
		return name_text
	var aliases: Dictionary = data.get("aliases", {})
	var target := str(aliases.get(name_text, ""))
	return target if sounds.has(target) else ""


func play(name_text: String, via: String = "api") -> bool:
	stats.requested += 1
	var id := resolve(name_text)
	if id == "":
		stats.unknown += 1
		return false
	return _play_id(id, via)


## Entrada para el play_sound() del controlador: desde la primera llamada, todo evento con sonido del controlador queda a su cargo (no se duplica).
func play_ui(name_text: String) -> bool:
	_ui_routed = true
	return play(name_text, "ui")


func on_order(result: Dictionary) -> void:
	var ui: Dictionary = data.get("ui", {})
	play(str(ui.get("orden_ok" if bool(result.get("ok", false)) else "orden_rechazada", "")), "order")


func on_fx(kind: String, _pos: Vector2 = Vector2.ZERO) -> void:
	var fx: Dictionary = data.get("fx", {})
	if fx.has(kind):
		play(str(fx[kind]), "fx:" + kind)


## Eventos de rules.tick() reenviados por el controlador (el gancho opcional): desde la primera llamada no se lee más state.log.
func on_events(events: Array) -> void:
	_external_events = true
	for e in events:
		if e is Dictionary:
			_event(e)


func _event(e: Dictionary) -> void:
	var kind := str(e.get("kind", "info"))
	if covered_by_controller(kind):
		stats.skipped_covered += 1
		return
	var id := str((data.get("events", {}) as Dictionary).get(kind, ""))
	if id != "":
		play(id, "event:" + kind)


func _active_voices() -> int:
	var n := 0
	for id in _players:
		if is_instance_valid(_players[id]) and (_players[id] as AudioStreamPlayer).playing:
			n += 1
	return n


## Al tope de voces, un sonido desplaza al que esté sonando con menor prioridad que la suya (los de prioridad 0 no desplazan a nadie).
func _steal_voice(prio: int) -> bool:
	var sounds: Dictionary = data.get("sounds", {})
	var victim := ""
	var victim_prio := prio
	for id in _players:
		var player: AudioStreamPlayer = _players[id]
		if not is_instance_valid(player) or not player.playing:
			continue
		var p := int((sounds.get(id, {}) as Dictionary).get("prio", 1))
		if p < victim_prio:
			victim = str(id)
			victim_prio = p
	if victim == "":
		return false
	(_players[victim] as AudioStreamPlayer).stop()
	stats.capped += 1
	return true


func _pick_stream(def: Dictionary) -> AudioStream:
	var files: Array = def.get("files", [])
	if files.is_empty():
		return null
	var dir := str(data.get("dir", "res://assets/audio/humahuaca/"))
	var path := dir + str(files[_rng.randi_range(0, files.size() - 1)])
	return _streams.get(path, null)


func _play_id(id: String, via: String) -> bool:
	var def: Dictionary = (data.get("sounds", {}) as Dictionary).get(id, {})
	var player: AudioStreamPlayer = _players.get(id, null)
	if def.is_empty() or player == null or not is_instance_valid(player) or not is_inside_tree():
		stats.unknown += 1
		return false
	if _silent() or not enabled:
		stats.silenced += 1
		return false
	var now := Time.get_ticks_msec()
	if now - int(_last_ms.get(id, -100000)) < int(def.get("cooldown_ms", 0)):
		stats.cooldown += 1
		return false
	if player.playing and not bool(def.get("retrigger", true)):
		stats.cooldown += 1
		return false
	var max_voices := int(data.get("max_voices", DEFAULT_MAX_VOICES))
	if not player.playing and _active_voices() >= max_voices and not _steal_voice(int(def.get("prio", 1))):
		stats.capped += 1
		return false
	var stream := _pick_stream(def)
	if stream == null:
		stats.unknown += 1
		return false
	if player.stream != stream and not player.playing:  # asignar el mismo stream detiene las voces activas (polifonía)
		player.stream = stream
	var pitch: Array = def.get("pitch", [1.0, 1.0])
	player.pitch_scale = _rng.randf_range(float(pitch[0]), float(pitch[1])) if pitch.size() >= 2 else 1.0
	player.volume_db = maxf(SILENT_DB, float(def.get("gain_db", -6.0)) + linear_to_db(_volume))
	player.play()
	_last_ms[id] = now
	stats.played += 1
	played_log.append({"sound": id, "via": via})
	while played_log.size() > LOG_KEEP:
		played_log.remove_at(0)
	return true


# ---------------------------------------------------------------------------------------------------------------------
# Capas ambientales (lazos periódicos; una copia del recurso con loop_mode, como hace el audio_manager)

func _manager_env() -> String:
	var am := _manager()
	if am == null:
		return ""
	var env: Variant = am.get("_scenario")
	return str(env) if env != null else ""


func _layer_gain(layer: Dictionary) -> float:
	var cfg: Dictionary = layer.cfg
	var def: Dictionary = (data.get("sounds", {}) as Dictionary).get(str(layer.sound), {})
	var curve: Dictionary = data.get("rain_curve", {})
	var rain := clampf(_rain, 0.0, 1.0) if _rain >= 0.0 else 0.5
	var g := float(def.get("gain_db", -12.0)) + float(cfg.get("gain_db", 0.0))
	if bool(cfg.get("rain_scaled", false)):
		g += lerpf(float(curve.get("scaled_min_db", -28.0)), 0.0, rain)
	if bool(cfg.get("rain_inverse", false)):
		g += lerpf(0.0, float(curve.get("inverse_min_db", -16.0)), rain)
	return g


func set_environment_phase(env_phase: String, force: bool = false) -> void:
	var ambient: Dictionary = data.get("ambient", {})
	if not ambient.has(env_phase):
		return
	if env_phase == _ambient_phase and not force:
		return
	_clear_ambient()
	_ambient_phase = env_phase
	if not is_inside_tree():
		return
	var manager_env := _manager_env()
	for cfg in ambient[env_phase]:
		if not (cfg is Dictionary):
			continue
		var skip := str((cfg as Dictionary).get("skip_if_manager_env", ""))
		if skip != "" and skip == manager_env:
			continue  # el audio_manager ya sopla ese viento: no se duplica
		var sound := str((cfg as Dictionary).get("sound", ""))
		var def: Dictionary = (data.get("sounds", {}) as Dictionary).get(sound, {})
		var original := _pick_stream(def) as AudioStreamWAV
		if original == null:
			continue
		var loop: AudioStreamWAV = original.duplicate() as AudioStreamWAV
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_begin = 0
		loop.loop_end = maxi(1, roundi(loop.get_length() * float(loop.mix_rate)))
		var player := AudioStreamPlayer.new()
		player.name = "Ambiente_" + sound
		player.bus = _bus_for(str(def.get("bus", "ambient")))
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		player.stream = loop
		add_child(player)
		_ambient.append({"player": player, "sound": sound, "cfg": cfg})
	_apply_volume()
	for layer in _ambient:
		var player: AudioStreamPlayer = layer.player
		player.play(_rng.randf() * player.stream.get_length())  # arranque al azar: las capas no coinciden siempre igual
		player.stream_paused = _silent()


func _clear_ambient() -> void:
	for layer in _ambient:
		var player: AudioStreamPlayer = layer.player
		if is_instance_valid(player):
			player.stop()
			player.stream = null
			player.queue_free()
	_ambient.clear()


# ---------------------------------------------------------------------------------------------------------------------
# Cada cuadro: sondeos baratos de las reglas

func _process(delta: float) -> void:
	if not enabled:
		return
	if host != null:
		if not is_instance_valid(host) or host.get("main") == null:
			detach()  # el controlador se detuvo
			return
		var r: Variant = host.get("rules")
		if r != rules:
			rules = r if r is RefCounted else null
			_reset_tracking()
	_poll.settings -= delta
	if _poll.settings <= 0.0:
		_poll.settings = float((data.get("poll_s", {}) as Dictionary).get("settings", 0.25))
		_read_settings()
	if rules == null or not is_instance_valid(rules):
		return
	_poll.render -= delta
	if _poll.render <= 0.0:
		_poll.render = float((data.get("poll_s", {}) as Dictionary).get("render", 0.1))
		_poll_render(false)
		_poll_log()
		_poll_status()
	_poll.hud -= delta
	if _poll.hud <= 0.0:
		_poll.hud = float((data.get("poll_s", {}) as Dictionary).get("hud", 0.5))
		_poll_hud()
	if _running():
		_world_tick(delta)


## ¿El reloj del nivel corre? (sin controlador se asume que sí)
func _running() -> bool:
	if host == null or not is_instance_valid(host):
		return true
	var paused: Variant = host.get("paused")
	var mode: Variant = host.get("mode")
	return not (paused is bool and bool(paused)) and (mode == null or str(mode) == "play")


func _state() -> Dictionary:
	if rules == null or not is_instance_valid(rules):
		return {}
	var st: Variant = rules.get("state")
	return st if st is Dictionary else {}


var _last_render: Dictionary = {}


func _poll_render(first: bool) -> void:
	if rules == null or not rules.has_method("render_state"):
		return
	var rs: Variant = rules.call("render_state")
	if not (rs is Dictionary) or (rs as Dictionary).is_empty():
		return
	_last_render = rs
	on_render_state(rs, first)


## Lee lo que dibuja la vista: fase, ambiente y torre. Público para las pruebas (y para quien quiera alimentarlo sin sondeo).
func on_render_state(rs: Dictionary, first: bool = false) -> void:
	var phase := str(rs.get("phase", ""))
	if not first and _seen.phase != "" and phase != _seen.phase and phase != "":
		var stinger := str((data.get("phases", {}) as Dictionary).get(phase, ""))
		if stinger != "":
			play(stinger, "phase:" + phase)
	_seen.phase = phase
	var env: Variant = rs.get("env", {})
	if env is Dictionary:
		var rain := float((env as Dictionary).get("rain", 0.0))
		var env_phase := str((env as Dictionary).get("phase", "noche"))
		var rain_changed := absf(rain - _rain) > 0.02
		_rain = rain
		set_environment_phase(env_phase, first)
		if rain_changed:
			_apply_volume()
	var tw: Variant = rs.get("tower", {})
	if tw is Dictionary and not (tw as Dictionary).is_empty():
		var firing := bool((tw as Dictionary).get("firing", false))
		var nxt := float((tw as Dictionary).get("next_volley_in_s", 0.0))
		if firing and bool(_seen.tower_firing) and nxt > float(_seen.tower_next) + 0.5 and not first:
			var rule: Dictionary = (data.get("world", {}) as Dictionary).get("tower_volley", {})
			play(str(rule.get("sound", "descarga_torre")), "world:tower_volley")
		_seen.tower_firing = firing
		_seen.tower_next = nxt
	else:
		_seen.tower_firing = false
		_seen.tower_next = -1.0


func _poll_status() -> void:
	var st := _state()
	if st.is_empty():
		return
	var status := str(st.get("status", "playing"))
	if _seen.status == "":
		_seen.status = status
		return
	if status != _seen.status:
		_seen.status = status
		if status != "playing":
			var name_text := str((data.get("status", {}) as Dictionary).get(status, ""))
			if name_text != "" and not _covered_name(status):  # el controlador ya pide play_sound("victory"|"defeat")
				play(name_text, "status:" + status)


func _poll_hud() -> void:
	if rules == null or not rules.has_method("hud_state"):
		return
	var hs: Variant = rules.call("hud_state")
	if not (hs is Dictionary):
		return
	var decision: Variant = (hs as Dictionary).get("decision", {})
	var id := str((decision as Dictionary).get("id", "")) if decision is Dictionary else ""
	if id != "" and id != str(_seen.decision):
		play(str((data.get("ui", {}) as Dictionary).get("decision", "")), "ui:decision")
	_seen.decision = id


## Los eventos que tick() dejó en state.log (si nadie los reenvía con on_events). Se sigue por el tiempo de cada evento, así el recorte del tope
## del registro y los eventos del mismo paso no confunden; una partida nueva (el reloj vuelve atrás) reinicia el seguimiento sin repetir historia.
func _poll_log() -> void:
	if _external_events:
		return
	var st := _state()
	var log: Variant = st.get("log", null)
	if not (log is Array):
		return
	var elapsed := float(st.get("elapsed", 0.0))
	if float(_seen.log_t) < 0.0 or elapsed + 1e-6 < float(_seen.log_t):
		_seen.log_t = elapsed
		_seen.log_same = _count_at(log, elapsed)
		return
	var tail: Array = []
	for i in range((log as Array).size() - 1, -1, -1):
		var e: Variant = (log as Array)[i]
		if not (e is Dictionary):
			continue
		if float((e as Dictionary).get("time", 0.0)) < float(_seen.log_t) - 1e-6:
			break
		tail.push_front(e)
	var same_skipped := 0
	var last_t := float(_seen.log_t)
	var last_same := int(_seen.log_same)
	for e in tail:
		var tm := float((e as Dictionary).get("time", 0.0))
		if absf(tm - float(_seen.log_t)) <= 1e-6:
			same_skipped += 1
			if same_skipped <= int(_seen.log_same):
				continue
		_event(e)
		if tm > last_t + 1e-6:
			last_t = tm
			last_same = 1
		else:
			last_same += 1
	_seen.log_t = last_t
	_seen.log_same = last_same if not tail.is_empty() else int(_seen.log_same)


func _count_at(log: Array, t: float) -> int:
	var n := 0
	for i in range(log.size() - 1, -1, -1):
		var e: Variant = log[i]
		if e is Dictionary and absf(float((e as Dictionary).get("time", 0.0)) - t) <= 1e-6:
			n += 1
		elif e is Dictionary and float((e as Dictionary).get("time", 0.0)) < t:
			break
	return n


# ---------------------------------------------------------------------------------------------------------------------
# Textura del mundo (lo que se ve en render_state y no es un evento): cascos, pasos, carga, tiros, choques, el tambor lejano

func _world_conditions(rs: Dictionary) -> Dictionary:
	var out := {"mounted_moving": false, "foot_moving": false, "loading": false, "under_fire": false, "melee": false, "reinforcement_column": false}
	for u in rs.get("units", []):
		if not (u is Dictionary):
			continue
		var stage := str(u.get("stage", ""))
		if stage == "moving":
			if bool(u.get("mounted", false)):
				out.mounted_moving = true
			elif str(u.get("noise_state", "silencio")) != "silencio":
				out.foot_moving = true
		elif stage == "loading":
			out.loading = true
	for o in rs.get("objectives", []):
		if o is Dictionary:
			if bool(o.get("under_fire", false)):
				out.under_fire = true
			if str(o.get("state", "")) == "asaltado":
				out.melee = true
	for e in rs.get("enemies", []):
		if e is Dictionary:
			var kind := str(e.get("kind", ""))
			if kind == "refuerzo":
				out.reinforcement_column = true
			elif kind != "torre" and bool(e.get("firing", false)):
				out.under_fire = true
	return out


func _world_tick(delta: float) -> void:
	if _last_render.is_empty():
		return
	var world: Dictionary = data.get("world", {})
	var active := _world_conditions(_last_render)
	for id in active:
		var rule: Variant = world.get(id, null)
		if not (rule is Dictionary) or not (rule as Dictionary).has("every_s"):
			continue
		if not bool(active[id]):
			_world_timers.erase(id)
			continue
		var every: Array = (rule as Dictionary).get("every_s", [2.0, 4.0])
		if not _world_timers.has(id):
			_world_timers[id] = _rng.randf_range(0.2, float(every[0]))  # la primera vez suena pronto, no de golpe
		_world_timers[id] = float(_world_timers[id]) - delta
		if float(_world_timers[id]) <= 0.0:
			play(str((rule as Dictionary).get("sound", "")), "world:" + str(id))
			_world_timers[id] = _rng.randf_range(float(every[0]), float(every[1]))


# ---------------------------------------------------------------------------------------------------------------------
# Informe (pruebas y QA)

func report() -> Dictionary:
	var layers: Array = []
	for layer in _ambient:
		layers.append(str(layer.sound))
	return {"sounds": (data.get("sounds", {}) as Dictionary).size(), "players": _players.size(), "streams": _streams.size(), "missing": missing.duplicate(),
		"ambient_phase": _ambient_phase, "ambient_layers": layers, "rain": _rain, "volume": _volume, "muted": _muted, "stats": stats.duplicate(),
		"ui_routed": _ui_routed, "external_events": _external_events, "manager_sounds": _manager_sounds.duplicate(), "played": played_log.duplicate(true),
		"covered_kinds": R.EVENT_KINDS.filter(func(k): return covered_by_controller(str(k)))}
