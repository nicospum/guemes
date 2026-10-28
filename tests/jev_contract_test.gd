extends SceneTree
## Offline contract and failure tests. No live TypeSafe decision is claimed.
const Client = preload("res://scripts/jev_client.gd")
var failures: Array = []
var checks: int = 0
var replies: Array = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)

func _run() -> void:
	var choices := {"protect_supply": "Proteger los víveres conocidos", "regroup": "Reagrupar fuerzas agotadas"}
	var valid := {"model": "fixture-not-live", "answers": {"intent": {"type": "choice", "choice": "protect_supply", "confidence": 0.7, "probabilities": {"protect_supply": 0.8, "regroup": 0.2}}}}
	check(Client.validate_response(valid, choices).get("ok", false), "legal typed response accepted")
	var invalid: Dictionary = valid.duplicate(true)
	invalid["answers"]["intent"]["choice"] = "invented_artillery"
	check(not Client.validate_response(invalid, choices).get("ok", false), "invented action rejected")
	invalid = valid.duplicate(true)
	invalid["answers"]["intent"]["probabilities"] = {"protect_supply": 0.8, "hidden_action": 0.2}
	check(not Client.validate_response(invalid, choices).get("ok", false), "wrong probability option rejected")
	invalid = valid.duplicate(true)
	invalid["answers"]["intent"]["probabilities"] = {"protect_supply": 1.0, "regroup": 1.0}
	check(not Client.validate_response(invalid, choices).get("ok", false), "invalid distribution rejected")
	check(not Client.validate_response(null, choices).get("ok", false), "malformed JSON rejected")
	var client = Client.new()
	client.force_local = true
	root.add_child(client)
	client.decision_ready.connect(func(d: Dictionary): replies.append(d))
	var context := {"game_id": "test-match", "round": 2, "state_version": 8}
	var observation := {"actor": "realistas", "self_supplies": 40, "visible_enemies": [], "hidden_player_orders": ["ambush"]}
	client.request_intent(observation, choices, "regroup", context)
	await process_frame
	check(replies.size() == 1, "offline yields exactly one reply")
	if replies.size() > 0:
		var d: Dictionary = replies[-1]
		check(d["source"] == "local_fallback" and d["choice"] == "regroup", "offline is explicitly local")
		check(not d["request_payload"]["state"].has("hidden_player_orders"), "unapproved state fields excluded")
		check(client.mark_applied(d, context), "fresh choice applied once")
		check(not client.mark_applied(d, context), "duplicate application rejected")
	client.request_intent(observation, choices, "regroup", context)
	await process_frame
	var before_reset: Dictionary = replies[-1]
	client.invalidate()
	check(not client.mark_applied(before_reset, context), "restart invalidates ready result")
	var count_before: int = replies.size()
	client.request_intent(observation, choices, "regroup", context)
	var old_ticket: int = client._serial
	var old_generation: int = client._generation
	client.invalidate()
	client._on_response(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(valid).to_utf8_buffer(), old_ticket, old_generation)
	await process_frame
	check(replies.size() == count_before, "late result after restart discarded")
	client.request_intent(observation, choices, "regroup", context)
	client._on_response(HTTPRequest.RESULT_TIMEOUT, 0, PackedStringArray(), PackedByteArray(), client._serial, client._generation)
	await process_frame
	check(replies[-1]["reason"] == "timeout" and replies[-1]["source"] == "local_fallback", "simulated timeout yields local choice")
	client.request_intent(observation, choices, "regroup", context)
	client._on_response(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), "{}".to_utf8_buffer(), client._serial, client._generation)
	await process_frame
	check(replies[-1]["reason"] == "invalid_response", "simulated bad response yields local choice")
	client.request_intent(observation, choices, "regroup", context)
	await process_frame
	var changed_context: Dictionary = context.duplicate(true)
	changed_context["state_version"] += 1
	check(not client.mark_applied(replies[-1], changed_context), "changed round state cannot consume stale choice")
	print(JSON.stringify({"suite": "jev_contract_offline", "checks": checks, "failures": failures, "live_api_tested": false, "failure_transport": "simulated", "offline_latency_ms": replies[0].get("latency_ms", -1)}))
	client.queue_free()
	quit(0 if failures.is_empty() else 1)
