extends SceneTree
## Comprueba que el VERSION.json embebido en un EXE/PCK corresponde a esta construccion.
## Uso (con el editor Godot, no con el EXE):
##   godot --headless --path . --script tools/verify_embedded_version.gd -- --pack=builds/windows/PatriaGuemes.exe --commit=<hash completo>
## Lee res://VERSION.json desde el paquete y verifica: version = config/version del paquete,
## commit exacto, arbol limpio (salvo --allow-dirty), embebido sin hash ni tamano del EXE.
## Sale con 0 si todo coincide y 1 si algo no corresponde. No ejecuta el juego.


func _initialize() -> void:
	var pack := ""
	var commit := ""
	var allow_dirty := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pack="):
			pack = arg.trim_prefix("--pack=")
		elif arg.begins_with("--commit="):
			commit = arg.trim_prefix("--commit=")
		elif arg == "--allow-dirty":
			allow_dirty = true
	var problems: Array = []
	if pack.is_empty() or not FileAccess.file_exists(pack):
		print("VERIFICACION_EMBEBIDA falla: no se encontro el paquete (%s)" % pack)
		quit(1)
		return
	if not ProjectSettings.load_resource_pack(ProjectSettings.globalize_path(pack) if pack.begins_with("res://") else pack):
		print("VERIFICACION_EMBEBIDA falla: no se pudo abrir el paquete")
		quit(1)
		return
	var resource := ResourceLoader.load("res://VERSION.json")
	var data: Variant = (resource as JSON).data if resource is JSON else null
	if not data is Dictionary:
		print("VERIFICACION_EMBEBIDA falla: res://VERSION.json no esta en el paquete o no es un objeto")
		quit(1)
		return
	var d: Dictionary = data
	var pack_version := str(ProjectSettings.get_setting("application/config/version", ""))
	if str(d.get("version", "")) != pack_version:
		problems.append("version %s != config/version %s" % [d.get("version"), pack_version])
	if not bool(d.get("embedded_in_build", false)):
		problems.append("el archivo no esta marcado como embebido en la construccion")
	if commit != "" and str(d.get("runtime_source_commit", "")) != commit:
		problems.append("commit embebido %s != %s" % [d.get("runtime_source_commit"), commit])
	if bool(d.get("build_tree_dirty", true)) and not allow_dirty:
		problems.append("la construccion se hizo con cambios sin commitear (build_tree_dirty)")
	for key in ["windows_sha256", "windows_bytes", "windows_exe_smoke_test"]:
		if d.has(key):
			problems.append("el embebido no puede traer %s (describiria otra construccion)" % key)
	print("VERSION embebida: ", JSON.stringify(d))
	print("VERIFICACION_EMBEBIDA ", "OK" if problems.is_empty() else "FALLA: " + "; ".join(problems))
	quit(0 if problems.is_empty() else 1)
