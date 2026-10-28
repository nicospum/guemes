extends SceneTree
# Visor de modelos de la pista ARTE: renderiza cada GLB en ventana real y guarda PNG.
# Uso: Godot (con ventana) --path . --resolution 1280x800 --audio-driver Dummy --script res://evidence/fase2/arte/viewer.gd -- --out=<dir>
var out_dir := "res://evidence/fase2/arte"
var shots := [
 {"n":"jinete_1806","m":[["rider_1806",Vector3(0,0,0)]],"cam":Vector3(3.2,2.2,4.0),"look":Vector3(0,1.5,0)},
 {"n":"jinete_1806_perfil","m":[["rider_1806",Vector3(0,0,0)]],"cam":Vector3(5.2,1.8,0.2),"look":Vector3(0,1.4,0)},
 {"n":"jinete_1817","m":[["rider_1817",Vector3(0,0,0)]],"cam":Vector3(3.2,2.2,4.0),"look":Vector3(0,1.5,0)},
 {"n":"jinete_1817_perfil","m":[["rider_1817",Vector3(0,0,0)]],"cam":Vector3(5.2,1.8,0.2),"look":Vector3(0,1.4,0)},
 {"n":"detalle_1806","m":[["rider_1806",Vector3(0,0,0)]],"cam":Vector3(1.3,2.9,2.0),"look":Vector3(0,2.4,0)},
 {"n":"detalle_1817","m":[["rider_1817",Vector3(0,0,0)]],"cam":Vector3(1.3,2.9,2.0),"look":Vector3(0,2.4,0)},
 {"n":"caballo_solo","m":[["horse_only",Vector3(0,0,0)]],"cam":Vector3(3.0,1.6,3.0),"look":Vector3(0,1.2,0)},
 {"n":"infanteria","m":[["infantry",Vector3(-1.2,0,0)],["royalist_1817",Vector3(0,0,0)],["dismounted_1806",Vector3(1.2,0,0)]],"cam":Vector3(0.6,1.7,3.6),"look":Vector3(0,1.0,0)},
 {"n":"justine","m":[["justine",Vector3(0,0,0)]],"cam":Vector3(14,8,15),"look":Vector3(0,4,0),"water":true},
 {"n":"justine_popa","m":[["justine",Vector3(0,0,0)]],"cam":Vector3(5,6.5,-17),"look":Vector3(0,4,-4),"water":true},
 {"n":"casa_colonial","m":[["house_colonial",Vector3(0,0,0)],["rider_1817",Vector3(5,0,2)]],"cam":Vector3(5,3,10),"look":Vector3(1.5,1.6,0)},
 {"n":"iglesia_colonial","m":[["church_colonial",Vector3(0,0,0)],["rider_1817",Vector3(6,0,8)]],"cam":Vector3(12,5,19),"look":Vector3(0,4,0)},
 {"n":"vegetacion","m":[["tree_algarrobo",Vector3(-4,0,0)],["tree_cardon",Vector3(1,0,0)],["rock_cluster",Vector3(4.5,0,1)],["rider_1817",Vector3(-1.2,0,3)]],"cam":Vector3(1,3.2,13),"look":Vector3(0,2.5,0)},
 {"n":"contexto_norte","m":[["house_colonial",Vector3(-7,0,0)],["church_colonial",Vector3(9,0,-4)],["tree_algarrobo",Vector3(-1,0,-3)],["tree_cardon",Vector3(3,0,-1)],["rider_1817",Vector3(1,0,3)],["rider_1817",Vector3(-1.4,0,5)],["royalist_1817",Vector3(-3,0,2)],["rock_cluster",Vector3(5,0,2)]],"cam":Vector3(2,4,22),"look":Vector3(0,3,0)},
]
func _initialize():
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--out="):out_dir=a.trim_prefix("--out=")
 DirAccess.make_dir_recursive_absolute(out_dir)
 await process_frame
 for s in shots:await _shot(s)
 quit()

func _shot(s:Dictionary):
 var root:=Node3D.new();get_root().add_child(root)
 var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color(0.55,0.68,0.80)
 env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color(0.62,0.68,0.75);env.ambient_light_energy=0.7
 env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
 var we:=WorldEnvironment.new();we.environment=env;root.add_child(we)
 var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);sun.shadow_enabled=true;sun.light_energy=1.5;root.add_child(sun)
 var ground:=MeshInstance3D.new();var pm:=PlaneMesh.new();pm.size=Vector2(200,200);ground.mesh=pm
 var gm:=StandardMaterial3D.new();gm.albedo_color=Color(0.30,0.35,0.22) if not s.get("water",false) else Color(0.08,0.17,0.20);gm.roughness=0.9 if not s.get("water",false) else 0.15
 ground.material_override=gm;root.add_child(ground)
 for m in s.m:
  var inst=load("res://assets/models/"+m[0]+".glb").instantiate();root.add_child(inst);inst.position=m[1]
  for ap in inst.find_children("*","AnimationPlayer",true,false):
   for an in ap.get_animation_list():
    if an in ["trot","walk"]:
     ap.get_animation(an).loop_mode=Animation.LOOP_LINEAR;ap.play(an);ap.seek(0.3,true);ap.pause()
 var cam:=Camera3D.new();cam.fov=42;root.add_child(cam);cam.position=s.cam;cam.look_at(s.look);cam.current=true
 for i in 4:await process_frame
 await RenderingServer.frame_post_draw
 get_root().get_texture().get_image().save_png(out_dir.path_join(s.n+".png"))
 root.queue_free()
 await process_frame
