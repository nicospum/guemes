extends SceneTree
## Demo reproducible para --write-movie:
## menú inicial → Norte → reconocimiento → resolución de rondas.

var game: Node

func _initialize() -> void:
	call_deferred("_run")

func _frames(count: int) -> void:
	for _i in range(count):
		await process_frame

func _run() -> void:
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.opening_pan = false
	game.jev.force_local = true

	# El menú aparece primero para que la demo tenga contexto.
	await _frames(90)

	# Capítulo III: se muestran mapa, tropas, objetivo y la primera decisión.
	game._start_game("norte")
	await _frames(75)

	# Primera ronda: Arias reconoce la Quebrada.
	game._select_ids(["arias"])
	game.sector = "quebrada"
	game.world.selected_sector = "quebrada"
	game._refresh_actions()
	game._campaign_order("scout")
	await _frames(45)
	game._resolve_round()
	await _frames(180)

	# Segunda ronda: Güemes protege el Valle de Lerma.
	game._select_ids(["guemes"])
	game.sector = "lerma"
	game.world.selected_sector = "lerma"
	game._refresh_actions()
	game._campaign_order("protect")
	await _frames(45)
	game._resolve_round()
	await _frames(210)

	quit(0)
