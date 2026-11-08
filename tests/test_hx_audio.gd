extends SceneTree
## Pruebas del sonido del nivel «humahuaca» (pista visual; docs/humahuaca/SONIDO.md). Sin ventana y con cualquier driver de audio (Dummy incluido):
##   godot --headless --path . --audio-driver Dummy --script tests/test_hx_audio.gd
## Comprueba: que los WAV de assets/audio/humahuaca/ existan, carguen, sean mono de 44,1 kHz, duren lo esperado y pesen <= 300 KB; que los lazos enlacen
## sin salto; que el mapeo de data/humahuaca_audio.json apunte a archivos reales y no deje ningún evento (EVENT_KINDS), efecto (FX_KINDS), fase, estado ni
## nombre del controlador sin sonido; y que el nodo scripts/humahuaca/view/humahuaca_audio.gd arranque sobre las reglas mínimas, reaccione a eventos,
## órdenes, torre, fases y silencio, no duplique lo que el controlador ya hace sonar y se libere sin huérfanos. Con el driver Dummy no se mide señal:
## se cuenta lo que el nodo pidió reproducir (stats y played), no lo que salió por los parlantes.
const Fx = preload("res://tests/hx_fixtures.gd")
const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")

const AUDIO_JSON := "res://data/humahuaca_audio.json"
const NODE_PATH := "res://scripts/humahuaca/view/humahuaca_audio.gd"
const MANIFEST := "res://assets/audio/humahuaca/MANIFIESTO.md"
const SONIDO_DOC := "res://docs/humahuaca/SONIDO.md"
const MAX_BYTES := 300 * 1024
const MAX_S := 3.5
const REQUIRED_UI := ["orden_ok", "orden_rechazada", "alerta", "victoria", "derrota"]
const CONTROLLER_NAMES := ["order", "error", "select", "alert", "victory", "defeat"]  # los que humahuaca_ui_play.gd pide por nombre fijo
const FLOOR := 40

var suite := Fx.new()
var audio: Dictionary = {}
var sounds: Dictionary = {}
var fake_main: Node
var rules: RefCounted
var node: Node


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	suite.begin("hx_audio", OS.get_cmdline_user_args())
	suite.extra["driver"] = AudioServer.get_driver_name()
	_test_json()
	_test_files()
	_test_mapping()
	_test_docs()
	await _test_node()
	_ck(suite.elapsed_ms() < 20000, "test_hx_audio corre en poco tiempo (objetivo < 20 s): %d ms" % suite.elapsed_ms())
	suite.require_floor(FLOOR)
	suite.finish(self)


func _ck(condition: bool, description: String) -> bool:
	return suite.check(condition, description)


func _wait(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame


# ---------------------------------------------------------------------------------------------------------------------
# El JSON y los archivos

func _test_json() -> void:
	audio = V.load_json(AUDIO_JSON)
	if not _ck(not audio.is_empty(), "data/humahuaca_audio.json parsea y declara contract 1"):
		return
	for key in ["dir", "buses", "sounds", "ambient", "events", "fx", "phases", "status", "ui", "aliases", "world"]:
		_ck(audio.has(key), "humahuaca_audio.json trae la clave «%s»" % key)
	sounds = audio.get("sounds", {})
	_ck(sounds.size() >= 25, "la paleta tiene al menos 25 sonidos (%d)" % sounds.size())
	var raw := FileAccess.get_file_as_bytes(AUDIO_JSON)
	_ck(not raw.has(13) and not (raw.size() >= 3 and raw[0] == 0xEF), "humahuaca_audio.json es UTF-8 sin BOM y con LF")
	var buses: Dictionary = audio.get("buses", {})
	_ck(str(buses.get("ambient", "")) == "Ambiente" and str(buses.get("sfx", "")) == "Efectos" and str(buses.get("ui", "")) == "UI", "los buses son los del audio_manager (Ambiente, Efectos, UI)")


## Lee el WAV de disco (RIFF): {rate, channels, bits, samples}. El recurso importado puede venir comprimido (QOA, como los de la Justina).
func _wav_info(path: String) -> Dictionary:
	var out := {"rate": 0, "channels": 0, "bits": 0, "samples": PackedFloat32Array()}
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 44 or bytes.slice(0, 4).get_string_from_ascii() != "RIFF" or bytes.slice(8, 12).get_string_from_ascii() != "WAVE":
		return out
	var pos := 12
	while pos + 8 <= bytes.size():
		var id := bytes.slice(pos, pos + 4).get_string_from_ascii()
		var size := bytes.decode_u32(pos + 4)
		if id == "fmt ":
			out.channels = bytes.decode_u16(pos + 10)
			out.rate = bytes.decode_u32(pos + 12)
			out.bits = bytes.decode_u16(pos + 22)
		elif id == "data" and int(out.bits) == 16:
			var n := mini(size, bytes.size() - pos - 8) / 2
			var samples := PackedFloat32Array()
			samples.resize(n)
			for i in range(n):
				samples[i] = float(bytes.decode_s16(pos + 8 + i * 2)) / 32768.0
			out.samples = samples
		pos += 8 + size + (size % 2)
	return out


func _test_files() -> void:
	var dir := str(audio.get("dir", ""))
	_ck(dir.begins_with("res://assets/audio/humahuaca/"), "los archivos viven en assets/audio/humahuaca/ (propiedad de visual)")
	var da := DirAccess.open(dir)
	var on_disk: Array = []
	if da != null:
		for f in da.get_files():
			if f.ends_with(".wav"):
				on_disk.append(f)
	var referenced := {}
	var bad_files: Array = []
	var bad_meta: Array = []
	var bad_len: Array = []
	var bad_size: Array = []
	var bad_seam: Array = []
	var kinds_ok := true
	for id in sounds:
		var def: Dictionary = sounds[id]
		var kind := str(def.get("kind", ""))
		kinds_ok = kinds_ok and kind in ["loop", "oneshot"]
		var files: Array = def.get("files", [])
		if files.is_empty():
			bad_files.append(str(id) + ": sin archivos")
		for f in files:
			referenced[str(f)] = true
			var path := dir + str(f)
			if not FileAccess.file_exists(path):
				bad_files.append(path + ": no existe")
				continue
			var size := FileAccess.get_file_as_bytes(path).size()
			if size > MAX_BYTES:
				bad_size.append("%s: %d B" % [str(f), size])
			var stream: AudioStreamWAV = load(path) as AudioStreamWAV if ResourceLoader.exists(path) else null
			if stream == null:
				bad_files.append(path + ": no carga como AudioStreamWAV (¿falta --import?)")
				continue
			var info := _wav_info(path)
			if int(info.rate) != 44100 or int(info.channels) != 1 or int(info.bits) != 16 or stream.mix_rate != 44100 or stream.stereo:
				bad_meta.append("%s: %d Hz, %d canales, %d bits (importado: %d Hz, %s)" % [str(f), int(info.rate), int(info.channels), int(info.bits), stream.mix_rate, "estéreo" if stream.stereo else "mono"])
			var length := stream.get_length()
			var lo := 2.0 if kind == "loop" else 0.2
			if length < lo or length > MAX_S:
				bad_len.append("%s: %.2f s" % [str(f), length])
			if kind == "loop":
				var s: PackedFloat32Array = info.samples
				if s.size() > 1000:
					var seam := absf(s[0] - s[s.size() - 1])
					var typ := 0.0
					for i in range(1, s.size()):
						typ = maxf(typ, absf(s[i] - s[i - 1]))
					if seam > typ:
						bad_seam.append("%s: salto %.4f (máximo entre vecinas %.4f)" % [str(f), seam, typ])
	_ck(kinds_ok, "cada sonido es «loop» o «oneshot»")
	_ck(bad_files.is_empty(), "todos los archivos del mapeo existen y cargan%s" % ("" if bad_files.is_empty() else ": " + str(bad_files[0])))
	_ck(bad_meta.is_empty(), "todos los WAV de disco son 44,1 kHz, mono, 16 bits (y el importado, mono de 44,1 kHz)%s" % ("" if bad_meta.is_empty() else ": " + str(bad_meta[0])))
	_ck(bad_len.is_empty(), "todos duran lo esperado (lazos 2,0–3,5 s; disparos 0,2–3,5 s)%s" % ("" if bad_len.is_empty() else ": " + str(bad_len[0])))
	_ck(bad_size.is_empty(), "ningún archivo pasa de 300 KB%s" % ("" if bad_size.is_empty() else ": " + str(bad_size[0])))
	_ck(bad_seam.is_empty(), "los lazos enlazan sin salto en la costura%s" % ("" if bad_seam.is_empty() else ": " + str(bad_seam[0])))
	var orphans: Array = on_disk.filter(func(f): return not referenced.has(str(f)))
	_ck(orphans.is_empty(), "ningún WAV de la carpeta queda fuera del mapeo (%d archivos)%s" % [on_disk.size(), "" if orphans.is_empty() else ": " + str(orphans[0])])
	var without_import: Array = on_disk.filter(func(f): return not FileAccess.file_exists(dir + str(f) + ".import"))
	_ck(without_import.is_empty(), "cada WAV tiene su .import%s" % ("" if without_import.is_empty() else ": " + str(without_import[0])))
	var tags_ok := true
	for id in sounds:
		var def: Dictionary = sounds[id]
		tags_ok = tags_ok and V.TAGS.has(str(def.get("tag", ""))) and str(def.get("source", "")) != "" and str(def.get("source", "")).length() <= 160
		var gain := float(def.get("gain_db", 0.0))
		tags_ok = tags_ok and is_finite(gain) and gain <= 0.0 and gain >= -40.0
	_ck(tags_ok, "cada sonido lleva etiqueta de fuente válida, su fuente (≤ 160 caracteres) y una ganancia entre −40 y 0 dB")


# ---------------------------------------------------------------------------------------------------------------------
# El mapeo: ningún evento sin sonido

func _is_sound(name_text: String) -> bool:
	return sounds.has(name_text)


func _test_mapping() -> void:
	var vocab := Fx.load_script(Fx.VOCAB_PATHS["vocab_rules.gd"])
	var kinds: Array = vocab.get("EVENT_KINDS") if vocab != null else []
	_ck(kinds.size() >= 30, "vocab_rules.EVENT_KINDS se lee (%d tipos)" % kinds.size())
	var events: Dictionary = audio.get("events", {})
	var unmapped: Array = kinds.filter(func(k): return not _is_sound(str(events.get(k, ""))))
	_ck(unmapped.is_empty(), "ningún evento de EVENT_KINDS queda sin sonido real%s" % ("" if unmapped.is_empty() else ": " + str(unmapped[0])))
	var extra: Array = events.keys().filter(func(k): return not kinds.has(str(k)))
	_ck(extra.is_empty(), "el mapeo de eventos no inventa tipos fuera de EVENT_KINDS%s" % ("" if extra.is_empty() else ": " + str(extra[0])))
	var vview := Fx.load_script(Fx.VOCAB_PATHS["vocab_view.gd"])
	var fx_kinds: Array = vview.get("FX_KINDS") if vview != null else []
	var fx: Dictionary = audio.get("fx", {})
	var fx_missing: Array = fx_kinds.filter(func(k): return not _is_sound(str(fx.get(k, ""))))
	_ck(fx_kinds.size() >= 7 and fx_missing.is_empty(), "ningún efecto de FX_KINDS queda sin sonido%s" % ("" if fx_missing.is_empty() else ": " + str(fx_missing[0])))
	var phases: Array = vocab.get("PHASES") if vocab != null else []
	var ph: Dictionary = audio.get("phases", {})
	var ph_missing: Array = phases.filter(func(k): return not _is_sound(str(ph.get(k, ""))))
	_ck(phases.size() >= 5 and ph_missing.is_empty(), "cada fase tiene su sonido de entrada%s" % ("" if ph_missing.is_empty() else ": " + str(ph_missing[0])))
	var status: Dictionary = audio.get("status", {})
	_ck(_is_sound(str(status.get("victory", ""))) and _is_sound(str(status.get("defeat", ""))), "victoria y derrota tienen sonido")
	var ui: Dictionary = audio.get("ui", {})
	var ui_missing: Array = REQUIRED_UI.filter(func(k): return not _is_sound(str(ui.get(k, ""))))
	_ck(ui_missing.is_empty(), "los avisos de interfaz (orden aceptada, rechazada, alerta, victoria, derrota) tienen sonido%s" % ("" if ui_missing.is_empty() else ": " + str(ui_missing[0])))
	var ambient: Dictionary = audio.get("ambient", {})
	var env_phases: Array = vocab.get("ENV_PHASES") if vocab != null and vocab.get("ENV_PHASES") != null else ["noche", "alba", "dia"]
	var amb_bad: Array = []
	for env_phase in env_phases:
		var layers: Variant = ambient.get(env_phase, [])
		if not (layers is Array) or (layers as Array).is_empty():
			amb_bad.append(str(env_phase) + ": sin capas")
			continue
		for layer in layers:
			var sid := str((layer as Dictionary).get("sound", "")) if layer is Dictionary else ""
			if not _is_sound(sid) or str((sounds.get(sid, {}) as Dictionary).get("kind", "")) != "loop":
				amb_bad.append(str(env_phase) + ": " + sid)
	_ck(amb_bad.is_empty(), "noche, alba y día tienen capas ambientales en lazo%s" % ("" if amb_bad.is_empty() else ": " + str(amb_bad[0])))
	var night: Array = ambient.get("noche", [])
	var night_ids: Array = night.map(func(l): return str((l as Dictionary).get("sound", "")))
	_ck(night_ids.has("lluvia_noche") and night_ids.has("viento_quebrada") and night_ids.has("grillos"), "la noche lleva lluvia, viento de quebrada y grillos")
	_ck((ambient.get("alba", []) as Array).any(func(l): return str((l as Dictionary).get("sound", "")) == "alba_pajaros"), "el alba trae pájaros")
	var world: Dictionary = audio.get("world", {})
	var world_bad: Array = world.keys().filter(func(k): return not _is_sound(str((world[k] as Dictionary).get("sound", ""))))
	_ck(world.has("tower_volley") and world_bad.is_empty(), "la textura del mundo (descarga de la torre, cascos, carga, tiros…) apunta a sonidos reales%s" % ("" if world_bad.is_empty() else ": " + str(world_bad[0])))
	# Los nombres que el controlador ya pide (humahuaca_ui.json toasts.kinds[*].sound y los fijos de humahuaca_ui_play.gd) tienen traducción.
	var aliases: Dictionary = audio.get("aliases", {})
	var ui_json := V.load_json(V.UI_PATH)
	var ui_kinds: Dictionary = (ui_json.get("toasts", {}) as Dictionary).get("kinds", {})
	var controller_names := {}
	for k in ui_kinds:
		var snd := str((ui_kinds[k] as Dictionary).get("sound", "")) if ui_kinds[k] is Dictionary else ""
		if snd != "":
			controller_names[snd] = true
	for n in CONTROLLER_NAMES:
		controller_names[n] = true
	var untranslated: Array = controller_names.keys().filter(func(n): return not _is_sound(str(n)) and not _is_sound(str(aliases.get(n, ""))))
	_ck(controller_names.size() >= 10, "se leyeron los nombres de sonido que pide el controlador (%d)" % controller_names.size())
	_ck(untranslated.is_empty(), "cada nombre que pide el controlador se traduce a un sonido del nivel%s" % ("" if untranslated.is_empty() else ": " + str(untranslated[0])))
	_ck(str(aliases.get("order", "")) == "orden_ok" and str(aliases.get("error", "")) == "orden_rechazada", "order → orden_ok y error → orden_rechazada")
	var required_sounds := ["lluvia_noche", "viento_quebrada", "grillos", "descarga_torre", "disparo", "choque_armas", "cascos_mulas", "relincho_mula", "carga_bultos", "alba_pajaros"]
	var absent: Array = required_sounds.filter(func(s): return not _is_sound(str(s)))
	_ck(absent.is_empty(), "la paleta pedida está completa (lluvia, viento, grillos, descarga, disparos, choque, cascos, relincho, carga, alba)%s" % ("" if absent.is_empty() else ": " + str(absent[0])))
	var senal := str(events.get("signal", ""))
	_ck(senal == "descarga_senal" or senal == "corneta" or senal == "campana_alarma", "la señal suena a descarga, corneta o campana (%s)" % senal)


# ---------------------------------------------------------------------------------------------------------------------
# Documentos

func _test_docs() -> void:
	var manifest := Fx.read_text(MANIFEST)
	_ck(manifest.length() > 500, "assets/audio/humahuaca/MANIFIESTO.md existe")
	var undocumented: Array = []
	for id in sounds:
		for f in (sounds[id] as Dictionary).get("files", []):
			if manifest.find("`" + str(f) + "`") < 0:
				undocumented.append(str(f))
	_ck(undocumented.is_empty(), "el manifiesto dice cómo se generó cada archivo%s" % ("" if undocumented.is_empty() else ": falta " + str(undocumented[0])))
	_ck(manifest.find("material externo") >= 0 and manifest.find("generate_audio_humahuaca.py") >= 0, "el manifiesto declara que no hay material externo y cita el generador")
	var doc := Fx.read_text(SONIDO_DOC)
	_ck(doc.length() > 800, "docs/humahuaca/SONIDO.md existe")
	_ck(doc.find("attach_to") >= 0 and doc.find("humahuaca_ui.gd") >= 0, "SONIDO.md anota el gancho de una línea que falta en el controlador")
	_ck(doc.find("dBFS") >= 0, "SONIDO.md trae las cifras del análisis (picos y RMS)")
	var src := Fx.read_text(NODE_PATH)
	_ck(src.find("preload(\"res://scripts/humahuaca/ui/") < 0, "el nodo de audio no importa nada de la capa de interfaz (regla de dependencia hacia abajo)")
	_ck(src.find("randf()") < 0 or src.find("_rng.randf") >= 0, "el nodo usa su propio RandomNumberGenerator")
	_ck(FileAccess.file_exists("res://tools/generate_audio_humahuaca.py"), "existe tools/generate_audio_humahuaca.py (lo que el contrato asigna a visual)")
	var gen := Fx.read_text("res://tools/generate_audio.py")
	_ck(gen.find("--humahuaca") >= 0, "tools/generate_audio.py acepta --humahuaca")


# ---------------------------------------------------------------------------------------------------------------------
# El nodo, sobre las reglas mínimas y un main de mentira

func _test_node() -> void:
	var script := Fx.load_script(NODE_PATH)
	if not _ck(script != null, "scripts/humahuaca/view/humahuaca_audio.gd carga y parsea"):
		return
	for m in ["attach", "detach", "play", "play_ui", "on_events", "on_order", "on_fx", "on_render_state", "set_environment_phase", "report", "resolve", "covered_by_controller", "sync_settings"]:
		_ck(Fx.script_method_names(script).has(m), "el nodo expone %s()" % m)
	_ck(Fx.script_method_names(script).has("attach_to"), "el nodo expone attach_to(controlador): el gancho de una línea")
	var orphans_before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	fake_main = Node.new()
	fake_main.name = "MainDeMentira"
	fake_main.set_script(GDScript.new())
	var main_script := GDScript.new()
	main_script.source_code = "extends Node\nvar settings := {\"volume\": 0.7, \"muted\": false}\nvar audio_manager: Node = null\n"
	main_script.reload()
	fake_main.set_script(main_script)
	root.add_child(fake_main)
	var mgr_script := Fx.load_script("res://scripts/audio_manager.gd")
	var mgr: Node = null
	if mgr_script != null:
		mgr = mgr_script.new()
		fake_main.add_child(mgr)
		fake_main.set("audio_manager", mgr)
	await process_frame
	rules = Fx.rules_stub()
	if not _ck(rules != null, "las reglas mínimas (stub_rules) existen para alimentar al nodo"):
		return
	node = script.new()
	node.name = "HumahuacaAudio"
	root.add_child(node)
	node.call("attach", fake_main, rules, null)
	await process_frame
	var rep: Dictionary = node.call("report")
	_ck(int(rep.sounds) == sounds.size() and (rep.missing as Array).is_empty(), "el nodo cargó todos los WAV del mapeo (%d sonidos, %d sin cargar)" % [int(rep.sounds), (rep.missing as Array).size()])
	_ck(int(rep.players) >= 20, "un reproductor propio por sonido de una vez (%d)" % int(rep.players))
	_ck(str(rep.ambient_phase) == "noche" and (rep.ambient_layers as Array).size() >= 2, "al arrancar de noche suenan las capas ambientales (%s: %s)" % [str(rep.ambient_phase), str(rep.ambient_layers)])
	_ck(absf(float(rep.volume) - 0.7) < 1e-6 and not bool(rep.muted), "el nodo lee settings.volume y settings.muted de main")
	var bus_ok := true
	for child in node.get_children():
		if child is AudioStreamPlayer:
			bus_ok = bus_ok and (child as AudioStreamPlayer).bus in ["Ambiente", "Efectos", "UI", "Master"]
	_ck(bus_ok, "los reproductores salen por los buses del audio_manager (o Master si no existen)")
	if mgr != null:
		var covered: Array = rep.covered_kinds
		var known: Array = rep.manager_sounds
		var ui_json := V.load_json(V.UI_PATH)
		var ui_kinds: Dictionary = (ui_json.get("toasts", {}) as Dictionary).get("kinds", {})
		var expected: Array = []
		for k in ui_kinds:
			var snd := str((ui_kinds[k] as Dictionary).get("sound", "")) if ui_kinds[k] is Dictionary else ""
			if snd != "" and known.has(snd):
				expected.append(str(k))
		var mismatch: Array = expected.filter(func(k): return not covered.has(k)) + covered.filter(func(k): return not expected.has(k))
		_ck(known.size() >= 8 and covered.has("signal") and mismatch.is_empty(), "no duplica lo que el controlador ya hace sonar con nombres que audio_manager conoce (%d eventos tapados; discrepancias: %s)" % [covered.size(), str(mismatch)])
		_ck(not covered.has("shot") and not covered.has("melee") and not covered.has("load"), "los eventos sin sonido en el controlador (tiros, choques, carga) quedan a cargo del nodo")
	# Eventos: cada tipo pedido llega a un sonido; los tapados por el controlador se cuentan aparte.
	var vocab := Fx.load_script(Fx.VOCAB_PATHS["vocab_rules.gd"])
	var kinds: Array = vocab.get("EVENT_KINDS")
	var before: Dictionary = (node.call("report") as Dictionary).stats
	for k in kinds:
		node.call("on_events", [{"kind": str(k), "text": "prueba", "time": 1.0}])
	var after: Dictionary = (node.call("report") as Dictionary).stats
	var handled := int(after.played) - int(before.played) + int(after.cooldown) - int(before.cooldown) + int(after.skipped_covered) - int(before.skipped_covered) + int(after.capped) - int(before.capped)
	_ck(handled == kinds.size() and int(after.unknown) == int(before.unknown), "los %d tipos de evento se resuelven (reproducidos, en espera por cadencia, tapados o al tope): %d; desconocidos 0" % [kinds.size(), handled])
	_ck(int(after.played) > int(before.played), "al menos un evento se reprodujo de verdad (%d)" % (int(after.played) - int(before.played)))
	_ck(bool((node.call("report") as Dictionary).external_events), "con on_events() el nodo deja de leer state.log (no se duplican eventos)")
	# Órdenes y nombres del controlador
	node.call("on_order", {"ok": true})
	node.call("on_order", {"ok": false, "reason": "Falta llegar a 150 m del frente"})
	var played: Array = (node.call("report") as Dictionary).played
	var tail: Array = played.slice(maxi(0, played.size() - 2))
	_ck(tail.size() == 2 and str(tail[0].sound) == "orden_ok" and str(tail[1].sound) == "orden_rechazada", "orden aceptada → orden_ok y orden rechazada → orden_rechazada")
	_ck(str(node.call("resolve", "cannon")) == str(audio.aliases.get("cannon", "")) and str(node.call("resolve", "no_existe")) == "", "resolve() traduce los nombres viejos y rechaza los desconocidos")
	var stats0: Dictionary = (node.call("report") as Dictionary).stats
	node.call("play_ui", "ford")
	var stats1: Dictionary = (node.call("report") as Dictionary).stats
	played = (node.call("report") as Dictionary).played
	_ck(int(stats1.played) == int(stats0.played) + 1 and str(played[played.size() - 1].sound) == str(audio.aliases.get("ford", "")) and bool((node.call("report") as Dictionary).ui_routed), "play_ui(\"ford\") suena como %s y marca el enrutado del controlador" % str(audio.aliases.get("ford", "")))
	_ck(bool(node.call("covered_by_controller", "capture")), "enrutado el controlador, sus eventos con sonido (captura) quedan a su cargo")
	# La torre: el contador de recarga vuelve a subir → descarga
	var rs_a := {"phase": "ataque", "env": {"phase": "noche", "rain": 0.8}, "tower": {"x": 450.0, "z": 310.0, "next_volley_in_s": 0.4, "period_s": 7.5, "dead_angle_m": 12.0, "firing": true}}
	var rs_b := rs_a.duplicate(true)
	(rs_b.tower as Dictionary).next_volley_in_s = 7.4
	node.call("on_render_state", rs_a, false)
	var p0 := int(((node.call("report") as Dictionary).stats as Dictionary).played)
	node.call("on_render_state", rs_b, false)
	played = (node.call("report") as Dictionary).played
	_ck(int(((node.call("report") as Dictionary).stats as Dictionary).played) == p0 + 1 and str(played[played.size() - 1].sound) == "descarga_torre", "cada descarga de la torre suena (descarga_torre) cuando su cuenta de recarga vuelve a empezar")
	# Fases y ambiente (antes se deja que las voces de la tormenta de eventos se apaguen: el tope de voces es real)
	await _wait(3.6)
	node.call("on_render_state", {"phase": "extraccion", "env": {"phase": "alba", "rain": 0.3}, "tower": {}}, false)
	rep = node.call("report")
	played = rep.played
	_ck(str(rep.ambient_phase) == "alba" and (rep.ambient_layers as Array).has("alba_pajaros"), "al alba cambian las capas y entran los pájaros (%s)" % str(rep.ambient_layers))
	_ck(played.size() > 0 and str(played[played.size() - 1].via) == "phase:extraccion", "el cambio de fase a extracción dispara su sonido de entrada")
	node.call("set_environment_phase", "dia")
	rep = node.call("report")
	_ck(str(rep.ambient_phase) == "dia" and not (rep.ambient_layers as Array).has("lluvia_noche"), "de día la lluvia se calla")
	# Silencio y volumen cero: nada suena
	fake_main.set("settings", {"volume": 0.7, "muted": true})
	node.call("sync_settings")
	var s_before: Dictionary = (node.call("report") as Dictionary).stats
	node.call("play", "disparo")
	var s_after: Dictionary = (node.call("report") as Dictionary).stats
	_ck(bool((node.call("report") as Dictionary).muted) and int(s_after.silenced) == int(s_before.silenced) + 1 and int(s_after.played) == int(s_before.played), "con settings.muted el nodo no reproduce nada")
	var any_playing := false
	for child in node.get_children():
		if child is AudioStreamPlayer and (child as AudioStreamPlayer).playing and not (child as AudioStreamPlayer).stream_paused:
			any_playing = true
	_ck(not any_playing, "silenciado, los reproductores quedan detenidos o en pausa")
	fake_main.set("settings", {"volume": 0.0, "muted": false})
	node.call("sync_settings")
	s_before = (node.call("report") as Dictionary).stats
	node.call("play", "disparo")
	s_after = (node.call("report") as Dictionary).stats
	_ck(int(s_after.silenced) == int(s_before.silenced) + 1, "con volumen 0 tampoco")
	fake_main.set("settings", {"volume": 0.5, "muted": false})
	await _wait(0.4)  # el sondeo propio (cada 0,25 s) lo tiene que ver sin ayuda
	_ck(absf(float((node.call("report") as Dictionary).volume) - 0.5) < 1e-6, "al subir el volumen el nodo lo sigue")
	# El registro de las reglas: sin on_events, los eventos nuevos de state.log se leen una sola vez
	var node2: Node = script.new()
	node2.name = "HumahuacaAudio2"
	root.add_child(node2)
	var rules2: RefCounted = Fx.rules_stub()
	node2.call("attach", fake_main, rules2, null)
	await process_frame
	var played_before := int(((node2.call("report") as Dictionary).stats as Dictionary).played)
	rules2.call("tick", 2.0)
	var log_n := ((rules2.get("state") as Dictionary).get("log", []) as Array).size()
	await process_frame
	await process_frame
	var rep2: Dictionary = node2.call("report")
	_ck(not bool(rep2.external_events), "sin reenvío, el nodo sigue leyendo state.log")
	_ck(log_n >= 0 and int((rep2.stats as Dictionary).unknown) == 0, "leer state.log no produce sonidos desconocidos (%d eventos en el registro)" % log_n)
	suite.extra["log_eventos"] = log_n
	suite.extra["reproducidos_desde_log"] = int((rep2.stats as Dictionary).played) - played_before
	# Enganche de una línea sobre la cáscara del controlador
	var shell: Node = Fx.ui_shell()
	if shell != null:
		root.add_child(shell)
		shell.set("main", fake_main)
		var attached: Variant = script.call("attach_to", shell)
		_ck(attached is Node and (attached as Node).get_parent() == shell and (attached as Node).name == "HumahuacaAudio", "attach_to(controlador) crea el nodo como hijo del controlador")
		_ck(script.call("attach_to", shell) == attached, "attach_to() es idempotente (no crea un segundo nodo)")
		shell.queue_free()
	# Liberación: sin huérfanos. El audio_manager se apaga como lo hace main.gd al salir (drena las reproducciones detenidas).
	node.call("detach")
	node2.call("detach")
	if mgr != null:
		mgr.call("shutdown")
	node.queue_free()
	node2.queue_free()
	fake_main.queue_free()
	await process_frame
	await process_frame
	OS.delay_msec(200)  # la hebra de mezcla retira las reproducciones detenidas antes de salir (como DRAIN_MS del audio_manager)
	await process_frame
	var orphans_after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_ck(orphans_after <= orphans_before, "al liberar el nodo no quedan nodos huérfanos (%d → %d)" % [orphans_before, orphans_after])
