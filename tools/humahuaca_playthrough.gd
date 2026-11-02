extends SceneTree
## Recorrido automático del nivel «humahuaca» con la biblioteca ÚNICA de políticas (scripts/humahuaca/rules/humahuaca_policies.gd). Dueña: reglas_historia.
## Sale con 0 si el experto gana (≥ 90 % al primer intento) y el pasivo y «pausa y reanuda» pierden (todos por amanecio), sin excepciones; con 1 si no. Escribe un
## informe `hx_playthrough_v1` (el que lee qa_balance.py) con una fila por partida: política, familia, semilla, réplica, intento, resultado, causa y su texto, duración, golpe,
## bajas, frentes tomados, apertura, variante del mundo, ritmo de decisiones, alertas críticas, excepciones, `valid` y `snapshot_sha256` (misma entrada, mismo hash).
##
##   godot --headless --path . --script tools/humahuaca_playthrough.gd -- --level=rules --policies=experto,pasivo --seeds=3-23 --attempts=1 --replicas=1 --out=<json>
##   godot --path . --script tools/humahuaca_playthrough.gd -- --level=scene --policies=experto,pasivo --seeds=3,5 --out=<json> [--shots=<carpeta>]   (con ventana)
##
##   --level=rules|scene     «rules» no abre escena (corre sin ventana, rápido); «scene» arma main.tscn, entra al nivel y lleva el reloj por qa_step() del controlador
##   --policies=<lista>      nombres de la biblioteca o los alias: estrategias (las 8 est_*), extraccion (las 5 ext_*), todas. Una política que todavía no existe se anota en
##                           `skipped` con su motivo (no es un error). `barrido_senal` = el experto dando la señal en cada instante de --signal-from/--signal-to/--signal-step
##   --seeds=a-b | a,b,c | calibracion | compuerta | informe     (por defecto, las ocho de calibración: 3,5,7,11,13,17,19,23)
##   --attempts=N            hasta 5; solo repite el intento quien perdió, con el progreso (diario y marcas) de HumahuacaProgress entre un intento y otro
##   --replicas=N            semilla propia del bot (las que juegan al azar o con demoras)
##   --measure=decisions     mide las decisiones SIGNIFICATIVAS del experto por ramificación del estado (marca `decision_metric: "ramificacion"`): en cada orden que da se
##                           juega el resto con y sin ella (postergada 20 s) y cuenta si el resultado cambia ≥ 10 puntos o de victoria a derrota
##   --out=<json>            dónde escribir el informe (por defecto user://hx-playthrough.json)
##   --shots=<carpeta>       (solo scene) capturas reales JPEG de la primera partida: una por fase y la del cierre
##   --signal-at=<s>         fuerza el instante (en segundos de partida) en que quien juega con el plan del experto da la señal; sirve para reproducir una derrota por señal temprana
##   --quiet                 sin la tabla de resultados
## El nivel «scene» necesita que main.gd tenga el gancho H4 (`_start_humahuaca(opts)`) y que el controlador exponga `rules`, `qa_step` y `paused`; la política `interfaz` hace clic
## en el botón del «siguiente paso» si lo encuentra (nombre que contiene «siguiente»/«next» o el texto del paso) y, si no, se anota como omitida.
## Las semillas 9000-9999 son del QA: esta herramienta las acepta de quien la llama, pero ningún archivo de las pistas las nombra.

const V = preload("res://scripts/humahuaca/humahuaca_vocab.gd")
const R = preload("res://scripts/humahuaca/rules/vocab_rules.gd")
const D = preload("res://scripts/humahuaca/rules/humahuaca_data.gd")
const Pol = preload("res://scripts/humahuaca/rules/humahuaca_policies.gd")

const SEEDS_CALIBRATION := [3, 5, 7, 11, 13, 17, 19, 23]
const SEEDS_GATE := [29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 101, 103, 107, 109, 113, 127, 131, 137, 139, 149, 151, 157]
const RULES_PATH := "res://scripts/humahuaca/rules/humahuaca_rules.gd"
const PROGRESS_PATH := "res://scripts/humahuaca/rules/humahuaca_progress.gd"
const SCENE_PATH := "res://scenes/main.tscn"
const WIN_MIN := 0.9  # compuerta 1: el experto gana al menos el 90 % al primer intento
const SIGNIFICANT_POINTS := 10.0  # compuerta 9: una decisión es significativa si cambia ≥ 10 puntos de golpe o de bajas, o una victoria en derrota
const POSTPONE_S := 20.0

var level := "rules"
var policies: Array = []
var seeds: Array = SEEDS_CALIBRATION.duplicate()
var attempts := 1
var replicas := 1
var measure := ""
var out_path := "user://hx-playthrough.json"
var shots_dir := ""
var quiet := false
var signal_from := 120.0
var signal_to := 375.0
var signal_step := 15.0
var interfaz_unavailable := false  # el controlador no ofrece el botón del «siguiente paso»: la política `interfaz` se omite una sola vez
var signal_force := -1.0  # --signal-at: fuerza el instante de la señal de quien juega con el plan del experto (por defecto, el de cada política)
var games: Array = []
var skipped: Array = []
var game: Node = null
var shots_taken := 0
var ui_log: Array = []
var rules_script: Script = null
var progress_script: Script = null

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var arg := str(a)
		if arg.begins_with("--level="):
			level = arg.trim_prefix("--level=")
		elif arg.begins_with("--policies="):
			policies = _expand_policies(arg.trim_prefix("--policies="))
		elif arg.begins_with("--seeds="):
			seeds = _parse_seeds(arg.trim_prefix("--seeds="))
		elif arg.begins_with("--attempts="):
			attempts = clampi(int(arg.trim_prefix("--attempts=")), 1, 5)
		elif arg.begins_with("--replicas="):
			replicas = clampi(int(arg.trim_prefix("--replicas=")), 1, 20)
		elif arg.begins_with("--measure="):
			measure = arg.trim_prefix("--measure=")
		elif arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
		elif arg.begins_with("--shots="):
			shots_dir = arg.trim_prefix("--shots=")
		elif arg.begins_with("--signal-from="):
			signal_from = float(arg.trim_prefix("--signal-from="))
		elif arg.begins_with("--signal-to="):
			signal_to = float(arg.trim_prefix("--signal-to="))
		elif arg.begins_with("--signal-step="):
			signal_step = maxf(1.0, float(arg.trim_prefix("--signal-step=")))
		elif arg.begins_with("--signal-at="):
			signal_force = float(arg.trim_prefix("--signal-at="))
		elif arg == "--quiet":
			quiet = true
	if policies.is_empty():
		policies = ["experto", "pasivo"]
	call_deferred("_run")

# ---------------------------------------------------------------------------------------------------------------------
# Argumentos

func _expand_policies(text: String) -> Array:
	var out: Array = []
	for raw in text.split(",", false):
		var name := raw.strip_edges()
		match name:
			"estrategias":
				for fid in V.OBJECTIVES:
					for ap in R.APPROACHES[fid]:
						out.append("est_%s_%s" % [fid, ap])
			"extraccion":
				for rc in R.EXTRACTIONS:
					out.append("ext_" + str(rc))
			"todas":
				out.append_array(Pol.list())
			"parciales":
				pass
			_:
				if name != "":
					out.append(name)
	return out

static func _parse_seeds(text: String) -> Array:
	var out: Array = []
	for raw in text.split(",", false):
		var part := raw.strip_edges()
		if part == "calibracion":
			out.append_array(SEEDS_CALIBRATION)
		elif part == "compuerta":
			out.append_array(SEEDS_GATE)
		elif part == "informe":
			for sd in range(2001, 2121):
				out.append(sd)
		elif part.find("-") > 0:
			var bounds := part.split("-")
			for sd in range(int(bounds[0]), int(bounds[1]) + 1):
				out.append(sd)
		elif part != "":
			out.append(int(part))
	return out

# ---------------------------------------------------------------------------------------------------------------------
# Corrida

func _run() -> void:
	rules_script = load(RULES_PATH)
	progress_script = load(PROGRESS_PATH)
	if rules_script == null or not rules_script.can_instantiate():
		_finish({"error": "no carga la clase real de reglas (%s)" % RULES_PATH}, 2)
		return
	var runnable: Array = []
	for p in policies:
		var why := str(Pol.skip_reason(str(p)))
		if level == "scene" and str(p) == "interfaz":
			why = ""
		if why != "":
			skipped.append({"policy": p, "reason": why})
		else:
			runnable.append(p)
	var t_start := Time.get_ticks_msec()
	for p in runnable:
		if str(p) == "barrido_senal":
			await _run_sweep()
		else:
			await _run_policy(str(p))
	var summary := _summarize()
	summary["duration_ms"] = Time.get_ticks_msec() - t_start
	var doc := {"schema": "hx_playthrough_v1", "level": level, "engine": Engine.get_version_info().string, "active_dims": R.ACTIVE_DIMS, "games": games, "skipped": skipped,
		"summary": summary, "seeds": seeds, "attempts": attempts, "replicas": replicas, "ui_log": ui_log}
	_finish(doc, 0 if bool(summary.get("ok", false)) else 1)

func _finish(doc: Dictionary, code: int) -> void:
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(doc, "\t", true, true))
		f.close()
	if not quiet and doc.has("summary"):
		print(_table(doc))
	var slim := doc.duplicate()
	slim.erase("games")
	slim.erase("ui_log")
	print("HX_PLAYTHROUGH ", JSON.stringify(slim))
	quit(code)

func _run_policy(policy: String) -> void:
	for sd in seeds:
		if policy == "interfaz" and interfaz_unavailable:
			return  # ya se anotó por qué no hay botón que pulsar: no se repite semilla por semilla
		for rep in range(1, replicas + 1):
			var progress: RefCounted = null
			if attempts > 1 and progress_script != null:
				var base := "user://hx_playthrough_%s_%d_%d" % [policy, int(sd), rep]
				progress = progress_script.new(base + "_progress.json", base + "_checkpoint.json")
				progress.call("reset_all")
			for att in range(1, attempts + 1):
				var rec: Dictionary
				if level == "scene":
					rec = await _play_scene(policy, int(sd), rep, att, progress)
				else:
					rec = _play_rules(policy, int(sd), rep, att, progress)
				if rec.is_empty():
					break
				games.append(rec)
				if str(rec.status) != "defeat":
					break
			if progress != null:
				progress.call("reset_all")
				for suffix in ["_progress.json", "_checkpoint.json"]:
					var path := "user://hx_playthrough_%s_%d_%d%s" % [policy, int(sd), rep, suffix]
					if FileAccess.file_exists(path):
						DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _new_rules(sd: int, att: int) -> RefCounted:
	var r: RefCounted = rules_script.new()
	r.call("new_game", sd, att, {})
	return r

func _finish_record(rec: Dictionary, rules: RefCounted, sd: int, rep: int, att: int) -> Dictionary:
	rec["level"] = level
	rec["seed"] = sd
	rec["replicate"] = rep
	rec["attempt"] = att
	rec["snapshot_sha256"] = JSON.stringify(rules.call("snapshot"), "", true, true).sha256_text()
	return rec

func _play_rules(policy: String, sd: int, rep: int, att: int, progress: RefCounted) -> Dictionary:
	var rules := _new_rules(sd, att)
	if progress != null:
		progress.call("begin_attempt", rules)
	var opts := {"replicate": rep}
	if signal_force >= 0.0:
		opts["signal_s"] = signal_force
	var rec: Dictionary = Pol.play(rules, policy, opts)
	if measure == "decisions" and policy == "experto":
		rec = _measure_decisions(rec, sd, rep, att)
	if progress != null:
		progress.call("record_result", rules)
	return _finish_record(rec, rules, sd, rep, att)

func _run_sweep() -> void:
	var s := signal_from
	while s <= signal_to + 1e-6:
		for sd in seeds:
			var rules := _new_rules(int(sd), 1)
			var rec: Dictionary = Pol.play(rules, "barrido_senal", {"signal_s": s})
			rec["signal_at_s"] = s
			games.append(_finish_record(rec, rules, int(sd), 1, 1))
		s += signal_step
		await process_frame

# ---------------------------------------------------------------------------------------------------------------------
# Decisiones significativas por ramificación (diseño 10, compuerta 9)

## El puntaje continuo con que se comparan dos finales: golpe − 0,5 × bajas (y una derrota resta el golpe que no cuenta).
static func _score(rec: Dictionary) -> float:
	return float(rec.golpe) - 0.5 * float(rec.loss_pct)

## Juega la partida del experto una vez y, en cada segundo en que da órdenes, la bifurca: con la orden y con las órdenes postergadas POSTERGAR_S segundos. Una decisión es
## significativa si los dos finales difieren ≥ 10 puntos o uno gana y el otro pierde. Devuelve el registro con las tres cifras de ritmo medidas sobre ellas.
func _measure_decisions(rec: Dictionary, sd: int, rep: int, att: int) -> Dictionary:
	var rules := _new_rules(sd, att)
	var mem := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = sd * 1009 + rep * 7919 + att
	var points: Array = []  # [{t, phase, delta, flips}]
	var guard := 0
	while str(rules.state.status) == "playing" and guard < 1000:
		guard += 1
		var snap: Dictionary = rules.call("snapshot")
		var mem_before: Dictionary = mem.duplicate(true)
		var rng_state := rng.state
		var orders := Pol.step(rules, "experto", mem, rng, false)
		var worth := false
		for o in orders:
			if not (str(o.actor) == "arreo" and str(o.action) == "move"):  # caminar hasta el lote es parte de cargarlo, no una decisión
				worth = true
		if worth:
			var with_orders := _finish_branch(snap, mem_before, rng_state, sd, rep, att, 0.0)
			var postponed := _finish_branch(snap, mem_before, rng_state, sd, rep, att, POSTPONE_S)
			var delta := absf(_score(with_orders) - _score(postponed))
			var flips := str(with_orders.status) != str(postponed.status)
			points.append({"t": float(rules.state.elapsed), "phase": str(rules.state.phase), "delta": delta, "significant": delta >= SIGNIFICANT_POINTS or flips})
		rules.call("tick", Pol.STEP_S)
	var times: Array = []
	var attack_times: Array = []
	for p in points:
		if bool(p.significant):
			times.append(float(p.t))
			if str(p.phase) == "ataque":
				attack_times.append(float(p.t))
	var end_t := float(rules.state.elapsed)
	var first := float(times[0]) if not times.is_empty() else end_t
	var gap_max := _longest_gap(times, 0.0, end_t)
	var signal_at := float(rules.state.alarm.signal_at)
	var gap_attack := _longest_gap(attack_times, signal_at, end_t) if signal_at >= 0.0 else 0.0
	rec["first_decision_s"] = first
	rec["decision_gap_max_s"] = gap_max
	rec["decision_gap_attack_max_s"] = gap_attack
	rec["decision_metric"] = "ramificacion"
	rec["decisions_total"] = points.size()
	rec["decisions_significant"] = times.size()
	return rec

## Termina la partida desde `snap`: con las órdenes de ese segundo (postpone = 0) o sin ninguna durante `postpone` segundos, y después como el experto.
func _finish_branch(snap: Dictionary, mem_before: Dictionary, rng_state: int, sd: int, rep: int, att: int, postpone: float) -> Dictionary:
	var rules := _new_rules(sd, att)
	rules.call("restore_snapshot", snap)
	var mem: Dictionary = mem_before.duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = sd * 1009 + rep * 7919 + att
	rng.state = rng_state
	var t0 := float(rules.state.elapsed)
	var guard := 0
	while str(rules.state.status) == "playing" and guard < 1000:
		guard += 1
		if postpone > 0.0 and float(rules.state.elapsed) < t0 + postpone:
			rules.call("tick", Pol.STEP_S)
			continue
		Pol.step(rules, "experto", mem, rng)
	return Pol.record_of(rules, "experto", mem)

static func _longest_gap(times: Array, from_t: float, to_t: float) -> float:
	var prev := from_t
	var best := 0.0
	for t in times:
		best = maxf(best, float(t) - prev)
		prev = float(t)
	return maxf(best, to_t - prev)

# ---------------------------------------------------------------------------------------------------------------------
# La escena real (con ventana)

func _play_scene(policy: String, sd: int, rep: int, att: int, progress: RefCounted) -> Dictionary:
	var scene := load(SCENE_PATH) as PackedScene
	if scene == null:
		return {}
	game = scene.instantiate()
	root.add_child(game)
	await process_frame
	if "settings" in game and game.settings is Dictionary:
		game.settings["auto_pause"] = false
	if "jev" in game and game.jev != null and "force_local" in game.jev:
		game.jev.force_local = true
	if not game.has_method("_start_humahuaca"):
		skipped.append({"policy": policy, "reason": "main.gd no tiene el gancho H4 (_start_humahuaca)"})
		game.queue_free()
		await process_frame
		return {}
	game._start_humahuaca({"seed": sd, "attempt": att, "skip_intro": true, "qa": true})
	for i in range(3):
		await process_frame
	var hx: Node = game.hx
	if hx == null or not ("rules" in hx) or hx.rules == null:
		skipped.append({"policy": policy, "reason": "el controlador no expone `rules`"})
		game.queue_free()
		await process_frame
		return {}
	hx.paused = true
	var rules: RefCounted = hx.rules
	if progress != null:
		progress.call("begin_attempt", rules)
	var mem := {}
	if signal_force >= 0.0:
		mem["signal_override"] = signal_force
	var rng := RandomNumberGenerator.new()
	rng.seed = sd * 1009 + rep * 7919 + att
	var last_phase := ""
	var steps := 0
	while str(rules.state.status) == "playing" and float(rules.state.elapsed) < float(D.rules().time.deadline_s) + 5.0 and steps < 4000:
		steps += 1
		if policy == "interfaz":
			var found := await _click_next_step(hx, rules)
			mem["clicks"] = int(mem.get("clicks", 0)) + (1 if found else 0)
			if not found and float(rules.state.elapsed) >= 10.0 and int(mem.get("clicks", 0)) == 0:
				interfaz_unavailable = true
				skipped.append({"policy": "interfaz", "reason": "el controlador de esta versión no tiene un botón del «siguiente paso» que se pueda pulsar (ni qa_press_next)"})
				game.queue_free()
				await process_frame
				game = null
				return {}
		else:
			var view := Pol.make_view(rules, policy, mem)
			Pol.apply_orders(rules, Pol.decide(policy, view, rng))
		hx.qa_step(Pol.STEP_S)
		if steps % 5 == 0:
			await process_frame
		if str(rules.state.phase) != last_phase:
			last_phase = str(rules.state.phase)
			await _shoot("%02d_%s" % [shots_taken + 1, last_phase], sd, policy, att)
	await process_frame
	await process_frame
	await _shoot("%02d_cierre_%s" % [shots_taken + 1, str(rules.state.status)], sd, policy, att)
	var rec: Dictionary = Pol.record_of(rules, policy, mem)
	if policy == "interfaz":
		rec["clicks"] = int(mem.get("clicks", 0))
	if progress != null:
		progress.call("record_result", rules)
	rec = _finish_record(rec, rules, sd, rep, att)
	game.queue_free()
	await process_frame
	game = null
	return rec

## La política «interfaz»: hace clic en el botón del «siguiente paso». Si el controlador ofrece qa_press_next(), lo usa; si no, busca un botón visible cuyo nombre diga
## «siguiente»/«next» o cuyo texto sea el del paso, y le manda un clic real (movimiento, apretar y soltar) a su centro.
func _click_next_step(hx: Node, rules: RefCounted) -> bool:
	if hx.has_method("qa_press_next"):
		hx.call("qa_press_next")
		return true
	var hud: Dictionary = rules.call("hud_state")
	var nxt: Dictionary = hud.get("siguiente", {})
	var action := str(nxt.get("action", ""))
	if action == "" or action == "hold" or action == "cancel":
		return true  # no hay nada que pulsar: el botón puede existir y la partida estar esperando
	var text := str(nxt.get("texto", ""))
	var btn: Button = null
	for b in game.find_children("*", "Button", true, false):
		var button := b as Button
		if button == null or not button.is_visible_in_tree() or button.disabled:
			continue
		var name_l := str(button.name).to_lower()
		if name_l.find("siguiente") >= 0 or name_l.find("next") >= 0 or (text != "" and button.text.strip_edges().find(text.substr(0, mini(18, text.length()))) >= 0):
			btn = button
			break
	if btn == null:
		return false
	await _click_at(btn.get_global_rect().get_center())
	ui_log.append("%d s: clic en el botón del siguiente paso (%s)" % [int(rules.state.elapsed), action])
	return true

func _to_win(pos: Vector2) -> Vector2:
	return root.get_final_transform() * pos

func _mouse_event(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.position = _to_win(pos)
	e.global_position = e.position
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(e)

func _click_at(pos: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = _to_win(pos)
	m.global_position = m.position
	root.push_input(m)
	await process_frame
	_mouse_event(pos, true)
	await process_frame
	_mouse_event(pos, false)
	await process_frame

## Una captura real (la ventana, no un render aparte) de la primera partida, como JPEG de calidad media para que pese poco. Solo con --shots y solo en scene.
func _shoot(name: String, sd: int, policy: String, att: int) -> void:
	if shots_dir == "" or shots_taken >= 12 or level != "scene":
		return
	for i in range(2):
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img == null or img.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(shots_dir)
	var file := "%s/%s_%s_s%d_i%d.jpg" % [shots_dir, name, policy, sd, att]
	if img.get_width() > 1600:
		img.resize(1600, int(float(img.get_height()) * 1600.0 / float(img.get_width())), Image.INTERPOLATE_LANCZOS)
	if img.save_jpg(file, 0.8) == OK:
		shots_taken += 1

# ---------------------------------------------------------------------------------------------------------------------
# Resumen

static func _wilson(k: int, n: int) -> Array:
	if n == 0:
		return [0.0, 0.0]
	var z := 1.645
	var p := float(k) / float(n)
	var c := (p + z * z / (2.0 * n)) / (1.0 + z * z / n)
	var h := z * sqrt(p * (1.0 - p) / n + z * z / (4.0 * n * n)) / (1.0 + z * z / n)
	return [snappedf(maxf(0.0, c - h), 0.001), snappedf(minf(1.0, c + h), 0.001)]

## Tasas por política e intento (con Wilson al 90 %), causas, medianas y la salida de la herramienta: sale bien si el experto gana ≥ 90 % al primer intento, el pasivo y «pausa y
## reanuda» pierden todas por amanecio, y ninguna partida tuvo excepciones ni se cortó por tiempo.
func _summarize() -> Dictionary:
	var by_policy := {}
	var exceptions := 0
	var invalid := 0
	for g in games:
		if g.is_empty():
			continue
		var key := "%s/intento%d" % [str(g.policy), int(g.attempt)]
		if not by_policy.has(key):
			by_policy[key] = {"n": 0, "victorias": 0, "causas": {}, "elapsed": []}
		var e: Dictionary = by_policy[key]
		e.n = int(e.n) + 1
		if str(g.status) == "victory":
			e.victorias = int(e.victorias) + 1
		else:
			e.causas[str(g.cause_id)] = int(e.causas.get(str(g.cause_id), 0)) + 1
		(e.elapsed as Array).append(float(g.elapsed_s))
		exceptions += int(g.exceptions)
		invalid += 0 if bool(g.valid) else 1
	var rates := {}
	for key in by_policy:
		var e: Dictionary = by_policy[key]
		var times: Array = e.elapsed
		times.sort()
		rates[key] = {"n": e.n, "victorias": e.victorias, "tasa": snappedf(float(e.victorias) / float(maxi(1, int(e.n))), 0.001), "wilson90": _wilson(int(e.victorias), int(e.n)),
			"causas": e.causas, "mediana_s": float(times[times.size() / 2]) if not times.is_empty() else 0.0}
	var ok := exceptions == 0 and invalid == 0
	var notes: Array = []
	if rates.has("experto/intento1"):
		var ex: Dictionary = rates["experto/intento1"]
		if float(ex.tasa) < WIN_MIN:
			ok = false
			notes.append("el experto gana %.0f %% (se pide ≥ %.0f %%)" % [100.0 * float(ex.tasa), 100.0 * WIN_MIN])
	for passive in ["pasivo", "pausa_reanuda"]:
		var key2 := "%s/intento1" % passive
		if rates.has(key2):
			var pa: Dictionary = rates[key2]
			if int(pa.victorias) > 0 or int((pa.causas as Dictionary).get("amanecio", 0)) != int(pa.n):
				ok = false
				notes.append("%s no pierde siempre por amanecio: %s" % [passive, str(pa.causas)])
	if exceptions > 0:
		notes.append("%d excepciones" % exceptions)
	if invalid > 0:
		notes.append("%d partidas con estado inválido al final" % invalid)
	return {"ok": ok, "partidas": games.size(), "tasas": rates, "excepciones": exceptions, "invalidas": invalid, "notas": notes}

func _table(doc: Dictionary) -> String:
	var lines: Array = ["hx_playthrough_v1 · nivel %s · %d partidas" % [str(doc.level), (doc.games as Array).size()]]
	var rates: Dictionary = doc.summary.get("tasas", {})
	var keys := rates.keys()
	keys.sort()
	for key in keys:
		var e: Dictionary = rates[key]
		lines.append("  %-28s %2d/%-3d  %5.1f %%  [%.2f–%.2f]  mediana %4.0f s  %s" % [key, int(e.victorias), int(e.n), 100.0 * float(e.tasa), float(e.wilson90[0]), float(e.wilson90[1]), float(e.mediana_s), str(e.causas)])
	for s in doc.get("skipped", []):
		lines.append("  omitida %-20s %s" % [str(s.policy), str(s.reason)])
	for n in doc.summary.get("notas", []):
		lines.append("  ! " + str(n))
	lines.append("  resultado: " + ("PASA" if bool(doc.summary.get("ok", false)) else "FALLA"))
	return "\n".join(PackedStringArray(lines))
