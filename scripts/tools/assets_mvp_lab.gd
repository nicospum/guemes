extends Node3D
## Escena aislada para validar assets antes de tocarlos en los tres capítulos.

const FOOT_SCENE := "res://assets/lab/UAL1_Standard.glb"
const MOUNTED_SCENE := "res://assets/models/rider_1817.glb"
const WEAPON_SCENE := "res://assets/models/arma_carabina.glb"

const COLORS := {
	"ground": Color("#3e352b"),
	"label": Color("#f4d58d"),
}

func _ready() -> void:
	_build_stage()
	var valid := true
	valid = _add_candidate(FOOT_SCENE, Vector3(-3.0, 0.0, 0.0), "Candidato gratuito · UAL CC0", "idle", 1.0) and valid
	valid = _add_candidate(MOUNTED_SCENE, Vector3(0.0, 0.0, 0.0), "Montado · jinete 1817", "trot", 1.0) and valid
	valid = _add_candidate(WEAPON_SCENE, Vector3(3.0, 0.0, 0.0), "Baseline propio · carabina", "", 0.65) and valid
	if not valid:
		get_tree().quit(1)

func _build_stage() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#17151a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#cdbb9b")
	environment.ambient_light_energy = 0.75
	world_environment.environment = environment
	add_child(world_environment)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	key.light_color = Color("#ffe0ae")
	key.light_energy = 2.0
	key.shadow_enabled = true
	add_child(key)

	var floor := MeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(14.0, 0.2, 8.0)
	floor.mesh = floor_mesh
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = COLORS.ground
	floor_material.roughness = 1.0
	floor.material_override = floor_material
	floor.position.y = -0.1
	add_child(floor)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 3.0, 11.0)
	camera.look_at_from_position(camera.position, Vector3(0.0, 1.2, 0.0), Vector3.UP)
	camera.current = true
	add_child(camera)

	var title := Label3D.new()
	title.text = "MVP · assets gratuitos"
	title.font_size = 48
	title.modulate = COLORS.label
	title.position = Vector3(0.0, 3.4, 0.0)
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(title)

func _add_candidate(scene_path: String, position: Vector3, label: String, animation_name: String, scale_factor: float) -> bool:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("No se pudo cargar el candidato: %s" % scene_path)
		return false
	var instance := packed.instantiate()
	instance.position = position
	instance.scale = Vector3.ONE * scale_factor
	add_child(instance)
	_add_label(instance, label)
	if animation_name != "":
		if not _play_animation(instance, animation_name):
			push_error("No se encontró la animación solicitada '%s' en %s" % [animation_name, scene_path])
			return false
	return true

func _add_label(parent: Node3D, text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 24
	label.modulate = COLORS.label
	label.position = Vector3(0.0, 2.8, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)

func _play_animation(root: Node, wanted: String) -> bool:
	for child in root.get_children():
		if child is AnimationPlayer:
			var player := child as AnimationPlayer
			var chosen := _find_animation(player, wanted)
			if chosen != "":
				var animation := player.get_animation(chosen)
				animation.loop_mode = Animation.LOOP_LINEAR
				player.play(chosen)
				return true
		if _play_animation(child, wanted):
			return true
	return false

func _find_animation(player: AnimationPlayer, wanted: String) -> String:
	for name in player.get_animation_list():
		if name.to_lower().contains(wanted.to_lower()):
			return name
	return ""
