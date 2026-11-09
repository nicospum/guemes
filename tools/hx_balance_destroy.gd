extends SceneTree
## Balance de «destruir en cadena» (QA ronda 2, Q-203). Juega experto, obediente y pasivo por la API pública (humahuaca_policies.play) en un rango de semillas,
## con la cadena de destruir prendida y apagada (transport.destroy_chain), y cuenta las órdenes de destruir que dio cada política.
## Uso: godot --headless --path . --script tools/hx_balance_destroy.gd [-- --desde=2001 --hasta=2020 --out=<archivo.json>]
## Imprime una línea «HX_BALANCE {json}» por modo con los promedios, y escribe todo en --out si se pide.

const D = preload("res://scripts/humahuaca/rules/humahuaca_data.gd")
const RULES := preload("res://scripts/humahuaca/rules/humahuaca_rules.gd")
const POL := preload("res://scripts/humahuaca/rules/humahuaca_policies.gd")
const POLICIES := ["experto", "obediente", "pasivo"]


func _initialize() -> void:
	var desde := 2001
	var hasta := 2020
	var out_path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--desde="):
			desde = int(a.trim_prefix("--desde="))
		elif a.begins_with("--hasta="):
			hasta = int(a.trim_prefix("--hasta="))
		elif a.begins_with("--out="):
			out_path = a.trim_prefix("--out=")
	var report := {"semillas": [desde, hasta], "modos": {}}
	for chain in [false, true]:
		(D.rules().transport as Dictionary)["destroy_chain"] = chain
		var mode := "cadena" if chain else "sin_cadena"
		var rows: Array = []
		var agg := {}
		for pol in POLICIES:
			agg[pol] = {"partidas": 0, "victorias": 0, "golpe": 0.0, "ordenes": 0, "ordenes_destruir": 0, "max_destruir": 0, "medallas": {}}
		for sd in range(desde, hasta + 1):
			for pol in POLICIES:
				var r: RefCounted = RULES.new()
				r.call("new_game", sd, 1, {})
				var rec: Dictionary = POL.play(r, pol, {})
				var n_orders := 0
				var n_destroy := 0
				var by_unit := {}
				for o in r.state.orders:
					n_orders += 1
					if str(o.action) == "destroy":
						n_destroy += 1
						by_unit[str(o.unit)] = int(by_unit.get(str(o.unit), 0)) + 1
				var a: Dictionary = agg[pol]
				a.partidas += 1
				a.victorias += 1 if str(rec.status) == "victory" else 0
				a.golpe += float(rec.golpe)
				a.ordenes += n_orders
				a.ordenes_destruir += n_destroy
				a.max_destruir = maxi(int(a.max_destruir), n_destroy)
				var m := str(rec.get("medal", ""))
				(a.medallas as Dictionary)[m] = int((a.medallas as Dictionary).get(m, 0)) + 1
				rows.append({"semilla": sd, "politica": pol, "estado": str(rec.status), "causa": str(rec.cause_id), "golpe": snappedf(float(rec.golpe), 0.1), "medalla": m,
					"ordenes": n_orders, "ordenes_destruir": n_destroy, "destruir_por_partida": by_unit, "bajas_pct": snappedf(float(rec.loss_pct), 0.1)})
		var summary := {}
		for pol in POLICIES:
			var a: Dictionary = agg[pol]
			var n := maxf(float(a.partidas), 1.0)
			summary[pol] = {"partidas": a.partidas, "victorias": a.victorias, "golpe_medio": snappedf(float(a.golpe) / n, 0.01), "ordenes_medias": snappedf(float(a.ordenes) / n, 0.1),
				"destruir_medias": snappedf(float(a.ordenes_destruir) / n, 0.1), "destruir_max": a.max_destruir, "medallas": a.medallas}
		(report.modos as Dictionary)[mode] = {"resumen": summary, "partidas": rows}
		print("HX_BALANCE ", JSON.stringify({"modo": mode, "resumen": summary}))
	(D.rules().transport as Dictionary).erase("destroy_chain")
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(report, "\t"))
			f.close()
	quit(0)
