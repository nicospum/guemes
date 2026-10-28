extends Node
## TypeSafe System One integration. Rules retain authority over every action.
## The caller supplies ONLY the actor's observation and currently legal choices.
signal decision_ready(decision: Dictionary)

const API_URL := "https://api.typesafe.ai/v1/systemone"
const OBSERVATION_FIELDS := ["actor", "scenario", "round", "self_forces", "self_supplies", "self_cohesion", "known_sectors", "visible_enemies", "visible_resources", "public_events", "goal", "situation"]
const QUESTION := "¿Qué intención legal responde mejor a la situación observada de este actor para conservar su capacidad operativa?"

var request_budget_sec: float = 2.0
var minimum_interval_ms: int = 3000
var force_local: bool = false
var status_text: String = "Jev: sin consultar"
var last_source: String = "none"
var decision_log: Array = []
var _generation: int = 0
var _serial: int = 0
var _last_network_ms: int = -100000
var _pending: Dictionary = {}
var _ready_decisions: Dictionary = {}
var _context: Dictionary = {}
var _http: HTTPRequest


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func invalidate() -> void:
	## Call before restarting, loading, ending a match, or discarding a round.
	_generation += 1
	if is_instance_valid(_http):
		_http.cancel_request()
		_http.queue_free()
	_http = null
	_pending.clear()
	_ready_decisions.clear()
	_context.clear()


func has_credentials() -> bool:
	return not _api_key().is_empty()


func request_intent(observation: Dictionary, legal_choices: Dictionary, fallback_id: String, context: Dictionary) -> void:
	## Every request replaces the previous request. No request runs per frame.
	invalidate()
	_serial += 1
	_context = context.duplicate(true)
	var valid_choices: Dictionary = {}
	for key in legal_choices:
		if key is String and not str(key).is_empty() and legal_choices[key] is String:
			valid_choices[str(key)] = str(legal_choices[key])
	if valid_choices.is_empty() or not valid_choices.has(fallback_id) or not _context_is_valid(context):
		status_text = "Jev: contrato de reglas inválido; no se emitió una orden"
		return
	var visible: Dictionary = {}
	for field in OBSERVATION_FIELDS:
		if observation.has(field):
			visible[field] = observation[field]
	var payload: Dictionary = {
		"model": _model(),
		"state": visible.duplicate(true),
		"questions": {"intent": {"type": "choice", "instructions": QUESTION, "criteria": valid_choices.duplicate(true)}}
	}
	_pending = {
		"request_id": _serial,
		"generation": _generation,
		"context": _context.duplicate(true),
		"started_ms": Time.get_ticks_msec(),
		"choices": valid_choices,
		"fallback": fallback_id,
		"payload": payload,
		"payload_sha256": JSON.stringify(payload).sha256_text()
	}
	var ticket: int = _serial
	if force_local:
		call_deferred("_fallback", ticket, "offline_selected")
		return
	var key: String = _api_key()
	if key.is_empty():
		call_deferred("_fallback", ticket, "missing_api_key")
		return
	if Time.get_ticks_msec() - _last_network_ms < minimum_interval_ms:
		call_deferred("_fallback", ticket, "frequency_budget")
		return
	_http = HTTPRequest.new()
	_http.timeout = clampf(request_budget_sec, 0.1, 5.0)
	_http.body_size_limit = 65536
	_http.max_redirects = 0
	_http.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_http)
	_http.request_completed.connect(_on_response.bind(ticket, _generation))
	_last_network_ms = Time.get_ticks_msec()
	status_text = "Jev: consultando; alternativa local disponible"
	var err: Error = _http.request(API_URL, PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + key]), HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		call_deferred("_fallback", ticket, "request_start_error_" + str(err))


func _on_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, ticket: int, generation: int) -> void:
	if generation != _generation or _pending.is_empty() or ticket != int(_pending.get("request_id", -1)):
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		var reason: String = "timeout" if result == HTTPRequest.RESULT_TIMEOUT else "http_" + str(response_code) + "_transport_" + str(result)
		_fallback(ticket, reason)
		return
	var decoded: Variant = JSON.parse_string(body.get_string_from_utf8())
	var parsed: Dictionary = validate_response(decoded, _pending["choices"])
	if not bool(parsed.get("ok", false)):
		_fallback(ticket, "invalid_response")
		return
	_finish(ticket, str(parsed["choice"]), "live", "validated_choice", parsed)


static func validate_response(decoded: Variant, choices: Dictionary) -> Dictionary:
	if not decoded is Dictionary:
		return {"ok": false}
	var answers: Variant = decoded.get("answers")
	if not answers is Dictionary:
		return {"ok": false}
	var answer: Variant = answers.get("intent")
	if not answer is Dictionary or answer.get("type") != "choice":
		return {"ok": false}
	var choice: Variant = answer.get("choice")
	if not choice is String or not choices.has(choice):
		return {"ok": false}
	var probabilities: Variant = answer.get("probabilities")
	if not probabilities is Dictionary or probabilities.size() != choices.size():
		return {"ok": false}
	var total: float = 0.0
	for option in choices:
		var value: Variant = probabilities.get(option)
		if not (value is float or value is int) or not is_finite(float(value)) or float(value) < 0.0 or float(value) > 1.0:
			return {"ok": false}
		total += float(value)
	if absf(total - 1.0) > 0.025:
		return {"ok": false}
	var confidence: Variant = answer.get("confidence")
	if not (confidence is float or confidence is int) or not is_finite(float(confidence)) or float(confidence) < 0.0 or float(confidence) > 1.0:
		return {"ok": false}
	return {"ok": true, "choice": choice, "model": str(decoded.get("model", "unknown")), "confidence": float(confidence), "probabilities": probabilities.duplicate(true)}


func _fallback(ticket: int, reason: String) -> void:
	if _pending.is_empty() or ticket != int(_pending.get("request_id", -1)):
		return
	_finish(ticket, str(_pending["fallback"]), "local_fallback", reason, {})


func _finish(ticket: int, choice: String, source: String, reason: String, details: Dictionary) -> void:
	if _pending.is_empty() or ticket != int(_pending.get("request_id", -1)):
		return
	if not _pending["choices"].has(choice):
		return
	var decision: Dictionary = {
		"request_id": ticket,
		"generation": _generation,
		"context": _pending["context"].duplicate(true),
		"choice": choice,
		"source": source,
		"reason": reason,
		"latency_ms": Time.get_ticks_msec() - int(_pending["started_ms"]),
		"payload_sha256": _pending["payload_sha256"],
		"request_payload": _pending["payload"].duplicate(true),
		"model": details.get("model", "local-rules-v1"),
		"confidence": details.get("confidence", null),
		"probabilities": details.get("probabilities", {})
	}
	_pending.clear()
	if is_instance_valid(_http):
		_http.cancel_request()
		_http.queue_free()
	_http = null
	_ready_decisions[ticket] = decision.duplicate(true)
	last_source = source
	status_text = "Jev: decisión en vivo" if source == "live" else "Jev: alternativa local (" + reason + ")"
	decision_ready.emit(decision)


func mark_applied(decision: Dictionary, current_context: Dictionary = {}) -> bool:
	## Call at the point rules accept the intention. Revalidate legality there too.
	var ticket: int = int(decision.get("request_id", -1))
	if not _ready_decisions.has(ticket):
		return false
	var original: Dictionary = _ready_decisions[ticket]
	var expected: Dictionary = _context if current_context.is_empty() else current_context
	if int(original.get("generation", -1)) != _generation or original["context"] != expected:
		_ready_decisions.erase(ticket)
		return false
	if decision.get("choice") != original.get("choice") or decision.get("source") != original.get("source"):
		return false
	_ready_decisions.erase(ticket)
	var record: Dictionary = original.duplicate(true)
	record["applied"] = true
	record["utc"] = Time.get_datetime_string_from_system(true)
	decision_log.append(record)
	if decision_log.size() > 256:
		decision_log.pop_front()
	var path: String = "user://jev_decisions.jsonl"
	var mode: int = FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE
	var file: FileAccess = FileAccess.open(path, mode)
	if file != null:
		file.seek_end()
		file.store_line(JSON.stringify(record))
	return true


static func _context_is_valid(context: Dictionary) -> bool:
	return context.has("game_id") and context.has("round") and context.has("state_version")


func _api_key() -> String:
	var key: String = OS.get_environment("TYPESAFE_API_KEY").strip_edges()
	if not key.is_empty():
		return key
	var config := ConfigFile.new()
	if config.load("user://jev.cfg") == OK:
		return str(config.get_value("typesafe", "api_key", "")).strip_edges()
	return ""


func _model() -> String:
	var model: String = OS.get_environment("TYPESAFE_MODEL").strip_edges()
	return "jev-latest" if model.is_empty() else model
