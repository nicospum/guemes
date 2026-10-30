class_name CampaignProgress
extends RefCounted
## Ciclo de campaña de la Justina (ronda 9, C1-C3 y C12): perder -> reintentar con conocimiento -> pasar.
## Guarda el PROGRESO (no la partida): semilla del mundo fija hasta ganar, diario del Bañado, intentos, racha de derrotas,
## mejor medalla y desbloqueo del Norte. Es lógica pura (sin nodos ni UI): la interfaz (main.gd) solo la llama y muestra lo que devuelve.
## Contrato de uso en docs/CONTRATO_JUSTINA.md, sección «Ciclo de campaña».

const VERSION := 1
const DEFAULT_PATH := "user://campaign.json"
const MAX_DIARY := 40
const MEDAL_RANK := {"": 0, "bronce": 1, "plata": 2, "oro": 3}

var path := DEFAULT_PATH
var data: Dictionary = {}
var load_note := ""  ## vacío si cargó bien; si no, por qué se empezó de cero (para mostrar un aviso, nunca para bloquear)

func _init(save_path: String = DEFAULT_PATH) -> void:
	path = save_path
	data = fresh()

static func fresh() -> Dictionary:
	return {"version": VERSION, "world_seed": 0, "diary": [], "attempts": 0, "wins": 0, "defeats_in_row": 0, "defeats_total": 0,
		"best_medal": "", "justina_won": false, "north_unlocked": false, "tutorial_seen": false, "last_cause": "", "worlds": 0, "checkpoint": {}}

# ---------------------------------------------------------------------------
# Persistencia

## Carga el progreso. Si el archivo no existe o está dañado, empieza de cero (nunca bloquea al jugador) y deja una nota.
func load_progress() -> bool:
	load_note = ""
	if not FileAccess.file_exists(path):
		data = fresh()
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		data = fresh()
		load_note = "No se pudo abrir el progreso: se empieza de cero."
		return false
	var text := f.get_as_text()
	f.close()
	var jp := JSON.new()  ## JSON.new().parse no escribe errores en la consola cuando el archivo está dañado
	var parsed: Variant = jp.data if jp.parse(text) == OK else null
	var clean := _validate(parsed)
	if clean.is_empty():
		data = fresh()
		load_note = "El progreso guardado estaba dañado: se empieza de cero."
		return false
	data = clean
	return true

## Guardado atómico: escribe a un temporal y lo renombra, así un corte no deja el archivo a medias.
func save_progress() -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		return false
	if dir.rename(tmp.get_file(), path.get_file()) == OK:
		return true
	## En algunas plataformas rename no pisa un archivo existente: respaldo, reemplazo y limpieza (nunca queda sin progreso).
	if FileAccess.file_exists(path):
		var bak := path.get_file() + ".bak"
		dir.rename(path.get_file(), bak)
		var ok := dir.rename(tmp.get_file(), path.get_file()) == OK
		if ok:
			dir.remove(bak)
		else:
			dir.rename(bak, path.get_file())
		return ok
	return false

func reset_all() -> void:
	data = fresh()
	save_progress()

static func _validate(v: Variant) -> Dictionary:
	if not v is Dictionary:
		return {}
	var d: Dictionary = fresh()
	var src: Dictionary = v
	if int(src.get("version", 0)) != VERSION:
		return {}
	for k in ["world_seed", "attempts", "wins", "defeats_in_row", "defeats_total", "worlds"]:
		var n: Variant = src.get(k, 0)
		if not (n is float or n is int) or float(n) < 0.0 or float(n) > 1.0e9:
			return {}
		d[k] = int(n)
	for k2 in ["justina_won", "north_unlocked", "tutorial_seen"]:
		if not src.get(k2, false) is bool:
			return {}
		d[k2] = src.get(k2, false)
	var medal: Variant = src.get("best_medal", "")
	if not medal is String or not MEDAL_RANK.has(medal):
		return {}
	d.best_medal = medal
	d.last_cause = str(src.get("last_cause", ""))
	var cpv: Variant = src.get("checkpoint", {})
	if cpv is Dictionary and (cpv as Dictionary).has_all(["world_seed", "t"]):
		d.checkpoint = {"world_seed": int(cpv.world_seed), "t": float(cpv.t)}
	var diary: Variant = src.get("diary", [])
	if not diary is Array or diary.size() > MAX_DIARY * 2:
		return {}
	for e in diary:
		if not e is Dictionary or not e.has_all(["key", "kind", "text", "x", "z"]) or not (e.x is float or e.x is int) or not (e.z is float or e.z is int):
			return {}
		d.diary.append({"key": str(e.key), "kind": str(e.kind), "text": str(e.text), "x": float(e.x), "z": float(e.z), "n": int(e.get("n", 1))})
	return d

# ---------------------------------------------------------------------------
# Mundo fijo hasta ganar (C1)

## Semilla del mundo. Se sortea una sola vez (o tras ganar / «Río nuevo») y se conserva entre intentos y entre sesiones.
## `candidate` permite a las pruebas fijar el sorteo; en el juego se deja en -1 (usa el reloj).
func world_seed(candidate: int = -1) -> int:
	if int(data.world_seed) <= 0:
		data.world_seed = _pick_seed(candidate)
		data.worlds = int(data.worlds) + 1
		save_progress()
	return int(data.world_seed)

## «Río nuevo»: cambia el mundo (pozos, vado y variante de misión) y borra las marcas del diario, que ya no valen.
func new_world(candidate: int = -1) -> int:
	var old := int(data.world_seed)
	var s := _pick_seed(candidate)
	var guard := 0
	while s == old and guard < 8:
		s = _pick_seed(-1 if candidate < 0 else candidate + 7919 * (guard + 1))
		guard += 1
	data.world_seed = s
	data.worlds = int(data.worlds) + 1
	data.diary = []
	data.checkpoint = {}
	data.defeats_in_row = 0
	save_progress()
	return s

static func _pick_seed(candidate: int) -> int:
	if candidate > 0:
		return candidate % 1000003 + 1
	return int(Time.get_ticks_usec() % 1000003) + 1

# ---------------------------------------------------------------------------
# Intento y resultado

## Marcar el comienzo de un intento: cuenta, y entrega al reglamento las marcas «anotado» del diario (no son conocimiento confirmado).
func begin_attempt(rules: RefCounted) -> void:
	data.attempts = int(data.attempts) + 1
	rules.set_diary_marks(diary_marks())
	rules.set_mercy(int(data.defeats_in_row))  ## ventaja de la experiencia: visible en el aviso del segundo 0 y en el parte
	save_progress()

## Ayudas que se OFRECEN hoy (nunca se imponen). Cada una exige una racha de derrotas (map_data().campaign.assist_after_defeats).
func offered_assists(rules: RefCounted) -> Array:
	var cfg: Dictionary = rules.map_data().get("campaign", {})
	var need: Dictionary = cfg.get("assist_after_defeats", {})
	var out: Array = []
	var streak := int(data.defeats_in_row)
	if streak >= int(need.get("baqueano", 3)):
		out.append({"id": "baqueano", "label": str(cfg.assists.baqueano.label), "text": str(cfg.assists.baqueano.text)})
	if streak >= int(need.get("bajante_generosa", 5)):
		out.append({"id": "bajante_generosa", "label": str(cfg.assists.bajante_generosa.label), "text": str(cfg.assists.bajante_generosa.text)})
	return out

## Aplica las ayudas ELEGIDAS por el jugador (solo las ofrecidas). Devuelve las aplicadas.
func apply_assists(rules: RefCounted, chosen: Array) -> Array:
	var offered_ids: Array = []
	for o in offered_assists(rules):
		offered_ids.append(str(o.id))
	var applied: Array = []
	for a in chosen:
		if str(a) in offered_ids and bool(rules.apply_assist(str(a)).ok):
			applied.append(str(a))
	return applied

## Registra el desenlace de la partida terminada y devuelve lo que la interfaz muestra: causa, consejo, datos, medalla, desbloqueo.
func record_result(rules: RefCounted) -> Dictionary:
	var rep: Dictionary = rules.campaign_report()
	var won: bool = str(rep.status) == "victory"
	var new_entries := _learn(rules, rep)
	var out := {"won": won, "medal": str(rep.medal), "assists_used": rep.assists_used, "new_diary": new_entries, "unlocked_north": false, "new_best_medal": false,
		"facts": _facts(rep)}
	if won:
		data.wins = int(data.wins) + 1
		data.defeats_in_row = 0
		data.last_cause = ""
		if not bool(data.justina_won):
			data.justina_won = true
			out.unlocked_north = true
		data.north_unlocked = true
		if int(MEDAL_RANK[str(rep.medal)]) > int(MEDAL_RANK[str(data.best_medal)]):
			data.best_medal = str(rep.medal)
			out.new_best_medal = true
		out.medal_label = medal_label(str(rep.medal))
		out.best_medal = str(data.best_medal)
		out.record_line = "Esta vez: %s · Tu mejor: %s" % [str(rep.medal).capitalize(), str(data.best_medal).capitalize()]
		out.lines = _victory_lines(rules, rep, bool(out.unlocked_north))
		data.checkpoint = {}
		data.world_seed = 0  ## después de ganar, «Rejugar» sortea un mundo nuevo para mejorar la medalla
		data.diary = []
	else:
		data.defeats_total = int(data.defeats_total) + 1
		data.defeats_in_row = int(data.defeats_in_row) + 1
		data.last_cause = str(rules.state.get("defeat_cause", ""))
		var txt := defeat_text(rules, rep)
		out.cause = txt.cause
		out.advice = txt.advice
		out.hint = pista(rules)
	out.offered_assists = offered_assists(rules)
	out.defeats_in_row = int(data.defeats_in_row)
	save_progress()
	return out

func _facts(rep: Dictionary) -> Dictionary:
	return {"capture_pct": snappedf(float(rep.capture_pct), 0.1), "loss_pct": snappedf(float(rep.loss_total_pct), 0.1), "time_mmss": _mmss(float(rep.elapsed))}

static func _mmss(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]

func _victory_lines(rules: RefCounted, rep: Dictionary, was_first_win: bool) -> Array:
	var med: Dictionary = rules.map_data().outcome.medals
	var loss := roundi(float(rep.loss_total_pct))
	var lines: Array = ["Capturaste el buque en %s con %d %% de bajas." % [_mmss(float(rep.elapsed)), loss]]
	var marked_ok: bool = float(rules.state.stats.marked_m) >= float(med.silver.ford_marked_min_m)
	var assisted: bool = not (rep.assists_used as Array).is_empty()
	match str(rep.medal):
		"oro":
			lines.append("Oro: sin ayudas, pocas bajas y rápido. No se puede mejorar.")
		"plata":
			lines.append("Plata. Para el oro te falta: %s." % ", ".join(_missing_gold(med, rep, assisted, bool(rep.get("on_own_charge", false)))))
		_:
			var miss: Array = []
			if not marked_ok:
				miss.append("marcar el vado con balizas")
			if float(rep.loss_total_pct) >= float(med.silver.loss_pct_below):
				miss.append("terminar con menos de %d %% de bajas" % roundi(float(med.silver.loss_pct_below)))
			lines.append("Bronce. Para la plata te falta: %s." % ", ".join(miss))
	if assisted:
		lines.append("Usaste ayuda (%s): el oro queda fuera en esta partida." % ", ".join(rep.assists_used))
	if int(rep.get("mercy_level", 0)) > 0:
		lines.append("Ganaste con la ventaja de la experiencia (nivel %d)." % int(rep.mercy_level))
	lines.append("Se desbloqueó el escenario 2: Sostener el Norte." if was_first_win else "Sostener el Norte sigue abierto.")
	return lines

func _missing_gold(med: Dictionary, rep: Dictionary, assisted: bool, rules_on_own: bool = false) -> Array:
	var miss: Array = []
	if float(rep.loss_total_pct) >= float(med.gold.loss_pct_below):
		miss.append("bajas menores a %d %%" % roundi(float(med.gold.loss_pct_below)))
	if float(rep.elapsed) >= float(med.gold.time_below_s):
		miss.append("capturar antes de las %s" % _mmss(float(med.gold.time_below_s)))
	if assisted:
		miss.append("jugar sin ayudas")
	if bool(rules_on_own):
		miss.append("esperar la orden de Liniers")
	if miss.is_empty():
		miss.append("repetir con la misma mano")
	return miss

static func medal_label(medal: String) -> String:
	return {"oro": "Medalla de oro", "plata": "Medalla de plata", "bronce": "Medalla de bronce"}.get(medal, "")

## Causa y consejo de la derrota en lenguaje de jugador (≤ 140 caracteres la causa; sin jerga). Todas las causas del JSON tienen texto.
func defeat_text(rules: RefCounted, rep: Dictionary) -> Dictionary:
	var cfg: Dictionary = rules.map_data().get("campaign", {})
	var cause_id := str(rules.state.get("defeat_cause", ""))
	var base: Dictionary = cfg.get("defeat_causes", {}).get(cause_id, {"cause": "La toma no prosperó.", "advice": "Probá de nuevo con lo que anotaste."})
	var advice := str(base.advice)
	var extra := ""
	if int(rep.stumbles) > 0:
		extra = str(cfg.get("stumble_advice_one", cfg.stumble_advice)) if int(rep.stumbles) == 1 else str(cfg.stumble_advice).replace("{n}", str(int(rep.stumbles)))
	elif int(rep.counter_hits) > 0:
		extra = str(cfg.get("counter_advice_one", cfg.counter_advice)) if int(rep.counter_hits) == 1 else str(cfg.counter_advice).replace("{n}", str(int(rep.counter_hits)))
	elif int(rules.state.ammo) <= 0 and int(rep.ammo_used) > 0:
		extra = str(cfg.ammo_advice)
	if extra != "":
		advice = extra
	var cause_text := str(base.cause)
	if bool(rep.get("last_effort_used", false)) == false and cause_id == "dispersos" and float(rep.capture_pct) >= 70.0:
		cause_text = "Estuviste a un paso: la captura llegó a %d %%, pero tus grupos quedaron quebrados." % roundi(float(rep.capture_pct))
	return {"cause": cause_text, "advice": advice, "cause_id": cause_id}

## Pista concreta del diario a partir de la 2.ª derrota seguida (la escalera de ayuda empieza por información, no por ventajas).
func pista(rules: RefCounted) -> String:
	var need := int(rules.map_data().get("campaign", {}).get("assist_after_defeats", {}).get("pista", 2))
	if int(data.defeats_in_row) < need:
		return ""
	var best: Dictionary = {}
	for e in data.diary:
		if str(e.kind) == "pozo" and (best.is_empty() or int(e.n) > int(best.n)):
			best = e
	if best.is_empty():
		return ""
	return "%s (anotado %d %s)." % [str(best.text).trim_suffix("."), int(best.n), "vez" if int(best.n) == 1 else "veces"]

# ---------------------------------------------------------------------------
# Diario del Bañado (C2)

## Marcas tenues para el mapa del próximo intento. NO son conocimiento confirmado: `confirmed` es siempre false y el reglamento las ignora.
func diary_marks() -> Array:
	var out: Array = []
	for e in data.diary:
		if str(e.kind) in ["pozo", "vado", "fuego"]:
			out.append({"key": str(e.key), "kind": str(e.kind), "text": str(e.text), "x": float(e.x), "z": float(e.z), "confirmed": false})
	return out

func diary_entries() -> Array:
	return (data.diary as Array).duplicate(true)

func _add(key: String, kind: String, text: String, x: float, z: float) -> Dictionary:
	for e in data.diary:
		if str(e.key) == key:
			e.n = int(e.n) + 1
			return {}
	var entry := {"key": key, "kind": kind, "text": text, "x": x, "z": z, "n": 1}
	(data.diary as Array).append(entry)
	if data.diary.size() > MAX_DIARY:
		data.diary = (data.diary as Array).slice(data.diary.size() - MAX_DIARY)
	return entry

## Convierte lo que pasó en la partida en entradas del diario. Devuelve las NUEVAS (para el globo «anotamos lo que descubriste»).
func _learn(rules: RefCounted, rep: Dictionary) -> Array:
	var cfg: Dictionary = rules.map_data().get("campaign", {})
	var kinds: Dictionary = cfg.get("diary_kinds", {})
	var added: Array = []
	var hazards: Dictionary = {}
	for hz in rules.map_data().hazards:
		hazards[str(hz.id)] = hz
	var seen: Array = []
	var stumble_at: Dictionary = rules.state.stats.get("stumble_at", {})
	for id in stumble_at:
		seen.append(str(id))
		if hazards.has(str(id)):
			var hz: Dictionary = hazards[str(id)]
			var e := _add("pozo:" + str(id), "pozo", _pozo_text(kinds, str(id), str(hz.name)), float(hz.center[0]), float(hz.center[1]))
			if not e.is_empty():
				added.append(e)
			else:
				_bump(str(id), int(stumble_at[id]) - 1)
	for id2 in rules.state.hazards_found:
		if str(id2) in seen or not hazards.has(str(id2)):
			continue
		var hz2: Dictionary = hazards[str(id2)]
		var e2 := _add("pozo:" + str(id2), "pozo", _pozo_text(kinds, str(id2), str(hz2.name)), float(hz2.center[0]), float(hz2.center[1]))
		if not e2.is_empty():
			added.append(e2)
	for fid in rules.state.fords_found:
		for fd in rules.map_data().fords:
			if str(fd.id) == str(fid) and fd.has("centerline"):
				var a: Array = fd.centerline[0]
				var b: Array = fd.centerline[1]
				var e3 := _add("vado:" + str(fid), "vado", str(kinds.get("vado", "Vado en {where}")).replace("{where}", "la ribera sur"), (float(a[0]) + float(b[0])) * 0.5, (float(a[1]) + float(b[1])) * 0.5)
				if not e3.is_empty():
					added.append(e3)
	if int(rules.state.stats.shots_taken) >= 6:
		var ship: Vector2 = rules.ship_position()
		var e4 := _add("fuego:costado", "fuego", str(kinds.get("fuego", "Zona de fuego del costado")), ship.x - 120.0, ship.y)
		if not e4.is_empty():
			added.append(e4)
	if str(rules.state.get("defeat_cause", "")) == "plazo":
		var e5 := _add("plazo", "plazo", str(kinds.get("plazo", "Llegaste tarde: el río subió a las {mmss}")).replace("{mmss}", _mmss(float(rep.deadline_s))), 0.0, 0.0)
		if not e5.is_empty():
			added.append(e5)
	var mid := str(rep.mission_id)
	if mid != "":
		var e6 := _add("mision:" + mid, "mision", str(kinds.get("mision", "Hoy: {label}")).replace("{label}", str(rep.mission_label)), 0.0, 0.0)
		if not e6.is_empty():
			added.append(e6)
	if (data.diary as Array).size() > MAX_DIARY:
		data.diary = (data.diary as Array).slice(data.diary.size() - MAX_DIARY)
	return added

func _bump(id: String, extra: int) -> void:
	for e in data.diary:
		if str(e.key) == "pozo:" + id:
			e.n = int(e.n) + maxi(0, extra)

func _pozo_text(kinds: Dictionary, id: String, hz_name: String) -> String:
	var tpl := str(kinds.get("pozo", "Pozo del flanco {where}"))
	match id:
		"pozo_flanco_norte":
			return tpl.replace("{where}", "norte")
		"pozo_flanco_sur":
			return tpl.replace("{where}", "sur")
	return hz_name

# ---------------------------------------------------------------------------
# «Desde el cruce» (C4): punto de control automático poco antes de que ceda el vado. Reintentar desde ahí cuesta segundos y
# conserva el reconocimiento ya hecho (sondeos, balizas). La UI llama checkpoint_tick() cada cuadro (es barato) y ofrece
# restore_checkpoint() en el parte de derrota si has_checkpoint().

const CHECKPOINT_PATH := "user://campaign_checkpoint.json"
var checkpoint_path := CHECKPOINT_PATH
var _cp_taken_attempt := -1

## Guarda el punto de control una vez por intento, cuando el reloj pasa de campaign.checkpoint_s y nadie cargó todavía.
func checkpoint_tick(rules: RefCounted) -> bool:
	if _cp_taken_attempt == int(data.attempts) or str(rules.state.get("status", "")) != "playing":
		return false
	var at := float(rules.map_data().get("campaign", {}).get("checkpoint_s", 200.0))
	if float(rules.state.elapsed) < at or float(rules.state.stats.boarded_at) >= 0.0:
		return false
	for u in rules.state.units:
		if str(u.stage) in ["dismounting", "boarding"] or str(u.order.get("action", "")) == "board":
			return false
	_cp_taken_attempt = int(data.attempts)
	if rules.save_game(checkpoint_path) != OK:
		return false
	data.checkpoint = {"world_seed": int(data.world_seed), "t": float(rules.state.elapsed)}
	save_progress()
	return true

## ¿Hay un punto de control válido para el mundo actual?
func has_checkpoint() -> bool:
	var cp: Variant = data.get("checkpoint", null)
	return cp is Dictionary and int(cp.get("world_seed", -1)) == int(data.world_seed) and int(data.world_seed) > 0 and FileAccess.file_exists(checkpoint_path)

func checkpoint_time() -> float:
	return float(data.get("checkpoint", {}).get("t", 0.0)) if has_checkpoint() else 0.0

## Reanuda desde el punto de control: el reconocimiento ya hecho se conserva; el intento cuenta, y la ventaja de la experiencia y las marcas del diario se actualizan.
func restore_checkpoint(rules: RefCounted) -> Dictionary:
	if not has_checkpoint():
		return {"ok": false, "reason": "No hay punto de control para este mundo."}
	var res: Dictionary = rules.load_game(checkpoint_path)
	if not bool(res.get("ok", false)):
		return res
	data.attempts = int(data.attempts) + 1
	rules.set_diary_marks(diary_marks())
	rules.apply_mercy_now(int(data.defeats_in_row))
	_cp_taken_attempt = int(data.attempts)  ## no pisar el punto de control con el mismo tramo
	save_progress()
	return {"ok": true, "reason": "Desde el cruce: el reconocimiento se conserva (%d:%02d)." % [int(rules.state.elapsed) / 60, int(rules.state.elapsed) % 60]}

# ---------------------------------------------------------------------------
# Tutorial una vez por perfil (C6): la UI pregunta y marca.

func tutorial_pending() -> bool:
	return not bool(data.tutorial_seen)

func mark_tutorial_seen() -> void:
	data.tutorial_seen = true
	save_progress()

func north_unlocked() -> bool:
	return bool(data.north_unlocked)
