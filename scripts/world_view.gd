extends Node3D
## Presentación: las posiciones y la profundidad siempre vienen de GameRules.

var rules
var scenario = "justine"
var terrain_noise = FastNoiseLite.new()
var decoration_rng = RandomNumberGenerator.new()
var water: MeshInstance3D
var sun: DirectionalLight3D
var environment: WorldEnvironment
var unit_nodes: Dictionary = {}
var unit_labels: Dictionary = {}
var selected_rings: Dictionary = {}
var sector_nodes: Dictionary = {}
var route_root: Node3D
var ship: Node3D
var enemy_marker: Node3D
var selected = "guemes"
var selected_sector = ""
var elapsed_visual = 0.0
var quality = "media"
var material_cache = {}
var show_paths = true
var model_cache = {}
var fire_flash: OmniLight3D
var last_path_signature = ""
var path_timer = 0.0
var parked_horses = {}
# Lotes instanciados: casas, árboles y caminos se dibujan con pocos MultiMesh (menos draw calls y nodos).
var batches = {}
var unit_meshes = {}
var batch_material: StandardMaterial3D
var path_instances: MultiMeshInstance3D
var advanced_renderer = false
## Tamaño en pantalla de las etiquetas 3D (fixed_size): constante, no depende de la distancia.
const LABEL_PIXEL_SIZE = 0.0006

func build(game_rules, quality_name = "media"):
 rules = game_rules
 quality = quality_name
 advanced_renderer = RenderingServer.get_current_rendering_method() != "gl_compatibility"
 scenario = str(rules.state.scenario)
 terrain_noise.seed = 1817
 terrain_noise.frequency = 0.052
 terrain_noise.fractal_octaves = 4
 decoration_rng.seed = 12081806
 _lighting()
 _ground()
 if scenario == "justine":
  _coast()
 else:
  _north()
 _flush_batches()
 route_root = Node3D.new()
 add_child(route_root)
 for u in rules.state.units:
  _create_group(u)
 update_state(0.01)

func _mat(color: Color, rough = 0.8, emissive = false):
 var key = color.to_html() + str(rough) + str(emissive)
 if material_cache.has(key): return material_cache[key]
 var m = StandardMaterial3D.new()
 m.albedo_color = color
 m.roughness = rough
 if color.a < 0.99:
  m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 if emissive:
  m.emission_enabled = true
  m.emission = color * 0.48
 material_cache[key] = m
 return m

func _mesh(mesh: Mesh, pos: Vector3, color: Color, parent: Node3D = self):
 var instance = MeshInstance3D.new()
 instance.mesh = mesh
 instance.position = pos
 instance.material_override = _mat(color)
 parent.add_child(instance)
 return instance

func _box(pos, size_v, color, parent: Node3D = self):
 var m = BoxMesh.new()
 m.size = size_v
 return _mesh(m, pos, color, parent)

func _cylinder(pos, radius, height_v, color, parent: Node3D = self):
 var m = CylinderMesh.new()
 m.top_radius = radius
 m.bottom_radius = radius
 m.height = height_v
 m.radial_segments = 12
 return _mesh(m, pos, color, parent)

func _unit_mesh(kind:String)->Mesh:
 if unit_meshes.has(kind):return unit_meshes[kind]
 var m:Mesh
 match kind:
  "box":
   var b=BoxMesh.new();b.size=Vector3.ONE;m=b
  "prism":
   var pr=PrismMesh.new();pr.size=Vector3.ONE;m=pr
  "cyl8":
   var c=CylinderMesh.new();c.top_radius=0.5;c.bottom_radius=0.5;c.height=1.0;c.radial_segments=8;m=c
  "cyl12":
   var c2=CylinderMesh.new();c2.top_radius=0.5;c2.bottom_radius=0.5;c2.height=1.0;c2.radial_segments=12;m=c2
  "sphere":
   var sp=SphereMesh.new();sp.radius=0.5;sp.height=1.0;sp.radial_segments=10;sp.rings=6;m=sp
 unit_meshes[kind]=m
 return m

func _inst(kind:String,pos:Vector3,size_v:Vector3,color:Color):
 if not batches.has(kind):batches[kind]={"xf":[],"col":[]}
 batches[kind].xf.append(Transform3D(Basis.from_scale(size_v),pos))
 batches[kind].col.append(color)

func _flush_batches():
 if batch_material==null:
  batch_material=StandardMaterial3D.new()
  batch_material.vertex_color_use_as_albedo=true
  batch_material.vertex_color_is_srgb=true
  batch_material.roughness=0.8
 for kind in batches:
  var data=batches[kind]
  var mm=MultiMesh.new()
  mm.transform_format=MultiMesh.TRANSFORM_3D
  mm.use_colors=true
  mm.mesh=_unit_mesh(kind)
  mm.instance_count=data.xf.size()
  for i in range(data.xf.size()):
   mm.set_instance_transform(i,data.xf[i])
   mm.set_instance_color(i,data.col[i])
  var mmi=MultiMeshInstance3D.new()
  mmi.name="Lote_"+kind
  mmi.multimesh=mm
  mmi.material_override=batch_material
  add_child(mmi)
 batches.clear()

func _lighting():
 environment = WorldEnvironment.new()
 var env = Environment.new()
 env.background_mode = Environment.BG_SKY
 var sky = Sky.new()
 var sky_material = ProceduralSkyMaterial.new()
 sky_material.sky_top_color = Color("435c70") if scenario == "justine" else Color("4d7188")
 sky_material.sky_horizon_color = Color("bdc3bb") if scenario == "justine" else Color("c8d0c6")
 sky_material.ground_bottom_color = Color("343b35")
 sky_material.ground_horizon_color = sky_material.sky_horizon_color
 sky_material.sun_angle_max = 12.0
 sky_material.sun_curve = 0.05
 sky.sky_material = sky_material
 env.sky = sky
 env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color = Color("b9c7cb")
 env.ambient_light_energy = 0.5
 env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
 env.tonemap_exposure = 1.0
 env.fog_enabled = true
 env.fog_light_color = Color("9baeb0") if scenario == "justine" else Color("bccad0")
 env.fog_light_energy = 0.3
 env.fog_density = 0.0018
 if advanced_renderer and quality != "baja":
  # Solo Forward+/Mobile: oclusión ambiental y brillo suave. El perfil alto agrega niebla volumétrica leve.
  env.glow_enabled = true
  env.glow_intensity = 0.5
  env.glow_hdr_threshold = 1.1
  env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
  env.ssao_enabled = true
  env.ssao_radius = 1.4
  env.ssao_intensity = 1.5
  env.ssao_power = 1.6
  env.adjustment_enabled = true
  env.adjustment_saturation = 1.06
  env.adjustment_contrast = 1.04
  if quality == "alta":
   env.volumetric_fog_enabled = true
   env.volumetric_fog_density = 0.0035
   env.volumetric_fog_albedo = Color("c9d4d2")
   env.volumetric_fog_emission = Color("2c3a3d")
   env.volumetric_fog_emission_energy = 0.4
   env.volumetric_fog_length = 120.0
   env.volumetric_fog_anisotropy = 0.35
 environment.environment = env
 add_child(environment)
 sun = DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-32, -42, 0)
 sun.light_color = Color("ffddb2")
 sun.light_energy = 0.96
 sun.shadow_enabled = quality != "baja"
 sun.directional_shadow_max_distance = 130
 sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if (advanced_renderer and quality == "alta") else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
 sun.shadow_blur = 1.4
 if advanced_renderer and quality == "alta":sun.light_volumetric_fog_energy = 1.0
 add_child(sun)

func terrain_height(x: float, z: float) -> float:
 if scenario == "justine": return rules.terrain_height_at(x,z)
 var ridge = abs(terrain_noise.get_noise_2d(x*0.8,z*0.7))
 var h = 0.4 + pow(ridge,1.4)*17.0
 h += maxf(0.0, absf(x)-28.0)*0.19
 for s in rules.state.get("sectors",[]):
  var d = Vector2(x,z).distance_to(Vector2(float(s.x),float(s.z)))
  h = lerpf(0.45,h,smoothstep(2.8,7.0,d))
 return h

func _ground():
 var st = SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var step = 1.2 if quality != "baja" else 1.8
 var nx = int(110.0/step)
 var nz = int(90.0/step)
 for ix in range(nx):
  for iz in range(nz):
   var x = -55.0+ix*step
   var z = -45.0+iz*step
   for offset in [Vector2(0,0),Vector2(0,step),Vector2(step,0),Vector2(step,0),Vector2(0,step),Vector2(step,step)]:
    var xx = x+offset.x
    var zz = z+offset.y
    var h = terrain_height(xx,zz)
    var color = Color("7c7652")
    if scenario == "justine":
     color = Color("8e8468") if xx > -10 else Color("696d43")
     if h < 0.3: color = Color("887d66")
     if xx < -22: color = Color("59613c")
    else:
     color = Color("596440").lerp(Color("8a8069"),clampf(h/7.5,0,1))
     if h > 8.0: color=color.lerp(Color("b8b29c"),clampf((h-8)/4.0,0,0.7))
    st.set_color(color)
    st.set_uv(Vector2(xx,zz)*0.14)
    st.add_vertex(Vector3(xx,h,zz))
 st.index()
 st.generate_normals()
 var m = MeshInstance3D.new()
 m.mesh = st.commit()
 var mat = ShaderMaterial.new()
 mat.shader = load("res://assets/terrain.gdshader")
 mat.set_shader_parameter("color_gamma",2.6 if advanced_renderer else 1.9)
 m.material_override = mat
 add_child(m)
 m.create_trimesh_collision()
 # El plano físico también se usa para dar órdenes con el mouse.

func _coast():
 water = MeshInstance3D.new()
 var plane = PlaneMesh.new()
 plane.size = Vector2(210,190)
 plane.subdivide_width = 70
 plane.subdivide_depth = 60
 water.mesh = plane
 water.position = Vector3(35,float(rules.state.get("water_level",0.95)),0)
 var wm = ShaderMaterial.new()
 wm.shader = load("res://assets/water.gdshader")
 water.material_override = wm
 add_child(water)
 for o in rules.state.get("obstacles",[]):
  var center = Vector2(float(o.get("x",0)),float(o.get("z",0)))
  _house(Vector3(center.x,terrain_height(center.x,center.y),center.y),float(o.get("w",5)),float(o.get("d",5)))
 # Casas de la ribera, fuera de las rutas tácticas.
 for i in range(10):
  var p = Vector2(-43.0+(i%2)*4.7,-25.0+i*5.0)
  _house(Vector3(p.x,terrain_height(p.x,p.y),p.y),3.2,3.4, i%3==0)
 for i in range(38):
  var p = Vector2(decoration_rng.randf_range(-53,-38),decoration_rng.randf_range(-40,40))
  _tree(Vector3(p.x,terrain_height(p.x,p.y),p.y),decoration_rng.randf_range(0.8,1.6))
 _rocks_and_reeds(90 if quality=="baja" else 180)
 ship = _model("justine",Vector3(16,0,0))
 ship.rotation.y = 0.12
 fire_flash = OmniLight3D.new()
 fire_flash.position = Vector3(12,3,0)
 fire_flash.light_color = Color("ffb85c")
 fire_flash.omni_range = 13
 fire_flash.light_energy = 0
 add_child(fire_flash)
 for i in range(4):
  var sailor = _model("infantry",Vector3(-1.4+(i%2)*2.6,3.35,-2.5+(i/2)*4.0),ship)
  sailor.rotation.y = -PI/2.0
 _world_label("JUSTINE",Vector3(16,11,0),Color("edc693"),34)
 _world_label("BANCO CENTRAL",Vector3(0,0.35,-4.2),Color("d9d3b2"),26)
 _world_label("RODEO SUR",Vector3(1,0.35,18.0),Color("d9d3b2"),26)
 _world_label("RIBERA DE BUENOS AIRES · 1806",Vector3(-31,2.5,-27),Color("d1cdb8"),25)

func _north():
 for s in rules.state.sectors:
  var point = Vector3(float(s.x),terrain_height(float(s.x),float(s.z)),float(s.z))
  var root = Node3D.new()
  root.position = point
  add_child(root)
  var ring = _ring(3.2,Color("c1ad7a"),root)
  ring.position.y = 0.18
  var label = _world_label(str(s.name).to_upper(),Vector3(0,3.6,0),Color("f1e2c2"),35,root)
  sector_nodes[str(s.id)] = {"root":root,"ring":ring,"label":label}
  for j in range(4):
   _house(point+Vector3((j%2)*1.8-0.9,0,(j/2)*1.9-0.9),1.15,1.45,j==0)
  if str(s.id)=="salta":
   _house(point+Vector3(0,0,-2.0),2.5,1.8,true)
   _inst("cyl12",point+Vector3(-1.2,2.2,-1.7),Vector3(0.7,3.7,0.7),Color("d3c4a3"))
  for t in range(2):
   _tree(point+Vector3(3.2,0,float(t)*2.0-1),0.6)
 var sectors = rules.state.sectors
 # Las líneas muestran conectividad simplificada, no caminos topográficos de época.
 var drawn = {}
 for s in sectors:
  for sid in s.get("neighbors",[]):
   var other = {}
   for candidate in sectors:
    if str(candidate.id)==str(sid): other=candidate;break
   if other.is_empty(): continue
   var pair_key = str(s.id)+str(sid)
   if drawn.has(str(sid)+str(s.id)):continue
   drawn[pair_key]=true
   var a=Vector2(float(s.x),float(s.z))
   var b=Vector2(float(other.x),float(other.z))
   _road(a,b)
 for i in range(70):
  var p=Vector2(decoration_rng.randf_range(-43,43),decoration_rng.randf_range(-34,34))
  if terrain_height(p.x,p.y)<3.8: _tree(Vector3(p.x,terrain_height(p.x,p.y),p.y),decoration_rng.randf_range(0.6,1.3))
 _rocks_and_reeds(70 if quality=="baja" else 140)
 enemy_marker=Node3D.new()
 add_child(enemy_marker)
 _cylinder(Vector3(0,2,0),0.08,4,Color("625141"),enemy_marker)
 var flag=_box(Vector3(0.7,3.6,0),Vector3(1.5,0.8,0.07),Color("8f4134"),enemy_marker)
 flag.rotation.z=-0.08
 _world_label("◆ REALISTAS",Vector3(0,5.4,0),Color("efac90"),28,enemy_marker)
 for i in range(3):
  var troop=_model("royalist_1817",Vector3(i*0.8-0.8,0,0.6),enemy_marker)
  troop.scale=Vector3.ONE*0.85

func _road(a:Vector2,b:Vector2):
 var count=int(a.distance_to(b)/0.9)
 for i in range(1,count):
  var p=a.lerp(b,float(i)/maxi(1,count))
  _inst("cyl8",Vector3(p.x,terrain_height(p.x,p.y)+0.06,p.y),Vector3(0.56,0.045,0.56),Color("b2a17c"))

func _house(pos:Vector3,w:float,d:float,church=false):
 var h=1.8 if not church else 2.5
 _inst("box",pos+Vector3(0,h/2,0),Vector3(w,h,d),Color("bcb298"))
 _inst("prism",pos+Vector3(0,h+0.38,0),Vector3(w+0.35,0.9,d+0.35),Color("714d3b"))
 for side in [-1,1]:
  _inst("box",pos+Vector3(side*w*0.5,h*0.55,0),Vector3(0.04,0.65,0.45),Color("393b31"))
 _inst("box",pos+Vector3(0,0.62,d*0.5+0.02),Vector3(0.6,1.23,0.035),Color("534b37"))
 if church:
  _inst("box",pos+Vector3(w*0.32,h+0.5,d*0.25),Vector3(0.55,1.2,0.55),Color("bfb69b"))
  _inst("box",pos+Vector3(w*0.32,h+1.4,d*0.25),Vector3(0.07,0.6,0.07),Color("5d5442"))
  _inst("box",pos+Vector3(w*0.32,h+1.48,d*0.25),Vector3(0.36,0.07,0.07),Color("5d5442"))

func _tree(pos:Vector3,scale_v:float):
 _inst("cyl8",pos+Vector3(0,1.45*scale_v,0),Vector3(0.26*scale_v,2.9*scale_v,0.26*scale_v),Color("655642"))
 _inst("sphere",pos+Vector3(0,3.0*scale_v,0),Vector3(2.4*scale_v,2.5*scale_v,2.4*scale_v),Color("4f5d38"))

func _rocks_and_reeds(count:int):
 var rock_mesh=SphereMesh.new();rock_mesh.radius=0.5;rock_mesh.height=0.64;rock_mesh.radial_segments=7;rock_mesh.rings=4
 var multimesh=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_3D;multimesh.mesh=rock_mesh;multimesh.instance_count=count
 for i in range(count):
  var x=decoration_rng.randf_range(-52,48)
  if scenario=="justine":x=decoration_rng.randf_range(-52,-11)
  var z=decoration_rng.randf_range(-40,40)
  var tr=Transform3D(Basis.from_euler(Vector3(0,decoration_rng.randf()*TAU,0)),Vector3(x,terrain_height(x,z)+0.08,z))
  var size_v=decoration_rng.randf_range(0.35,1.5)
  tr.basis=tr.basis.scaled(Vector3(size_v,size_v*0.6,size_v))
  multimesh.set_instance_transform(i,tr)
 var rocks=MultiMeshInstance3D.new();rocks.multimesh=multimesh;rocks.material_override=_mat(Color("807b66"));add_child(rocks)
 # Hierba de geometría real: agrupaciones pequeñas e instanciadas.
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for a in [0.0,1.0472,2.0944]:
  var dir=Vector3(cos(a)*0.12,0,sin(a)*0.12)
  st.add_vertex(-dir);st.add_vertex(dir);st.add_vertex(Vector3(0.13,0.5,0.04))
 st.generate_normals()
 var grass=MultiMesh.new();grass.transform_format=MultiMesh.TRANSFORM_3D;grass.mesh=st.commit();grass.instance_count=count*4
 for i in range(count*4):
  var x=decoration_rng.randf_range(-50,-12) if scenario=="justine" else decoration_rng.randf_range(-45,43)
  var z=decoration_rng.randf_range(-38,38)
  var tr=Transform3D(Basis.from_euler(Vector3(0,decoration_rng.randf()*TAU,0)),Vector3(x,terrain_height(x,z),z))
  grass.set_instance_transform(i,tr)
 var gi=MultiMeshInstance3D.new();gi.multimesh=grass
 var gm=_mat(Color("727548"));gm.cull_mode=BaseMaterial3D.CULL_DISABLED
 gi.material_override=gm;add_child(gi)

func _model(model_name:String,pos:Vector3,parent:Node3D=self)->Node3D:
 var path="res://assets/models/"+model_name+".glb"
 var root:Node3D
 if ResourceLoader.exists(path):
  if not model_cache.has(path):model_cache[path]=load(path)
  root=model_cache[path].instantiate()
 else:
  root=Node3D.new()
  var mesh=CapsuleMesh.new();mesh.radius=0.35;mesh.height=1.8
  _mesh(mesh,Vector3(0,0.9,0),Color("514333"),root)
 parent.add_child(root)
 root.position=pos
 return root

func _ring(radius:float,color:Color,parent:Node3D):
 var m=TorusMesh.new();m.inner_radius=radius-0.085;m.outer_radius=radius+0.085;m.rings=32;m.ring_segments=6
 var n=_mesh(m,Vector3(0,0.07,0),color,parent)
 n.material_override=_mat(color,0.55,true)
 return n

func _world_label(text_value:String,pos:Vector3,color:Color,font_size=32,parent:Node3D=self):
 var label=Label3D.new()
 label.text=text_value;label.position=pos
 label.font_size=font_size;label.pixel_size=LABEL_PIXEL_SIZE;label.fixed_size=true
 label.modulate=color;label.outline_size=8;label.outline_modulate=Color(0.07,0.10,0.09,0.9)
 label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 label.no_depth_test=true
 parent.add_child(label)
 return label

func _create_group(unit:Dictionary):
 var root=Node3D.new();add_child(root)
 root.position=Vector3(float(unit.x),terrain_height(float(unit.x),float(unit.z)),float(unit.z))
 var figures=Node3D.new();figures.name="Figures";root.add_child(figures)
 var mounted=bool(unit.get("mounted",true))
 var file="rider_1806" if scenario=="justine" else "rider_1817"
 if not mounted:file="dismounted_1806"
 var anims=[]
 for i in range(2 if quality=="baja" else 4):
  var p=Vector3((i%2)*1.3-0.65,0,(i/2)*1.7-0.85)
  var fig=_model(file,p,figures)
  var ap=fig.find_children("*","AnimationPlayer",true,false)
  for player in ap:
   var list=player.get_animation_list()
   for anim in list:
    if "trot" in anim or "walk" in anim:
     player.get_animation(anim).loop_mode=Animation.LOOP_LINEAR
     player.play(anim);player.seek(float(i)*0.14,true);player.pause();player.speed_scale=0.75;anims.append(player);break
 var ring=_ring(2.65,Color("e2bc72"),root)
 selected_rings[str(unit.id)]=ring
 var label=_world_label(str(unit.name),Vector3(0,4.0,0),Color("e9d4aa"),30,root)
 unit_labels[str(unit.id)]=label
 unit_nodes[str(unit.id)]={"root":root,"figures":figures,"mounted":mounted,"anims":anims,"last":root.position}

func update_state(delta:float):
 elapsed_visual+=delta
 path_timer+=delta
 if path_timer>0.5 and is_instance_valid(route_root):
  var signature=selected+str(show_paths)
  for unit in rules.state.units:signature+=str(unit.path.hash())+str(unit.stage)
  if signature!=last_path_signature:
   last_path_signature=signature;refresh_paths()
  path_timer=0.0
 if is_instance_valid(water):
  water.position.y=float(rules.state.water_level)
  water.material_override.set_shader_parameter("water_level",float(rules.state.water_level))
 if is_instance_valid(fire_flash):fire_flash.light_energy=move_toward(fire_flash.light_energy,0,delta*13)
 for u in rules.state.units:
  var id=str(u.id)
  if not unit_nodes.has(id):continue
  var entry=unit_nodes[id]
  if entry.mounted!=bool(u.get("mounted",true)):
   if not bool(u.get("mounted",true)) and not parked_horses.has(id):
    var stable=Node3D.new();add_child(stable)
    stable.position=Vector3(10.0,terrain_height(10,float(u.z)),float(rules.state.units.find(u)-1)*2.7)
    for h_index in range(2):_model("horse_only",Vector3(-1.2-h_index*1.2,0,0),stable)
    parked_horses[id]=stable
   var old=entry.root;remove_child(old);old.queue_free();unit_nodes.erase(id);_create_group(u);entry=unit_nodes[id]
  var root:Node3D=entry.root
  var h=terrain_height(float(u.x),float(u.z))
  # Solo soldados desmontados representan el abordaje; los caballos quedan en el banco.
  if str(u.get("stage","")) in ["boarding","capturing","captured"]:h=maxf(h,0.2)
  var goal=Vector3(float(u.x),h,float(u.z))
  if scenario=="norte":
   goal.x-=3.3;goal.z+=2.8;goal.y=terrain_height(goal.x,goal.z)
  if scenario=="justine" and str(u.stage) in ["boarding","dismounting"]:
   goal.z+=float(rules.state.units.find(u)-1)*2.7
  var nearby=false
  if scenario=="justine" and str(u.stage) not in ["boarding","dismounting"]:
   for other in rules.state.units:
    if str(other.id)!=id and Vector2(float(u.x),float(u.z)).distance_to(Vector2(float(other.x),float(other.z)))<4.5:nearby=true
   if nearby:
    var index=rules.state.units.find(u)
    var formation=Vector2(goal.x-float(index)*1.8,goal.z+float(index-1)*1.8)
    if rules.is_walkable(formation.x,formation.y):
     goal.x=formation.x;goal.z=formation.y;goal.y=terrain_height(goal.x,goal.z)
  var dist=root.position.distance_to(goal)
  root.position=root.position.lerp(goal,minf(1.0,delta*4.2)) if scenario=="norte" else goal
  if scenario=="norte":root.position.y=terrain_height(root.position.x,root.position.z)
  var movement=goal-Vector3(entry.last)
  var moving=movement.length()>0.002
  if moving:
    entry.figures.rotation.y=lerp_angle(entry.figures.rotation.y,atan2(-movement.x,-movement.z),minf(1,delta*5))
  var animating=(str(u.stage)=="moving" and not u.path.is_empty()) if scenario=="justine" else dist>0.05
  if entry.get("animating",false)!=animating:
   entry["animating"]=animating
   for ap in entry.anims:
    ap.speed_scale=0.75
    if animating:ap.play()
    else:ap.pause()
  entry.last=goal
  root.visible=float(u.strength)>0.0
  selected_rings[id].visible=id==selected or selected=="all"
  var marker="● " if id==selected or selected=="all" else ""
  var index=rules.state.units.find(u)
  var short_name="Güemes" if id=="guemes" else ("Voluntarios" if id=="arias" else "Reserva")
  if scenario=="norte":short_name="Güemes" if id=="guemes" else ("Arias" if id=="arias" else "Partida del valle")
  var label_text=marker+str(index+1)+" · "+(short_name+" · " if id==selected else "")+str(int(u.strength))+"%"
  if unit_labels[id].text!=label_text:unit_labels[id].text=label_text
  if unit_labels[id].font_size!=26:unit_labels[id].font_size=26
  unit_labels[id].position.y=4.0+(float(index)*2.1 if nearby else 0.0)
  unit_labels[id].modulate=Color("f1d290") if id==selected else Color("ddd7bf")
 if scenario=="norte":
  for sector in rules.state.sectors:
   var entry=sector_nodes.get(str(sector.id),{})
   if entry.is_empty():continue
   entry.ring.visible=str(sector.id)==selected_sector or int(sector.get("intel_until",0))>=int(rules.state.round)
   entry.label.modulate=Color("f6d794") if str(sector.id)==selected_sector else (Color("dfd8bf") if bool(sector.get("known",false)) else Color("7c8d8d"))
   var sector_text=str(sector.name).to_upper()+(" · ?" if not bool(sector.get("known",false)) else (" · ◇" if int(sector.get("intel_until",0))>=int(rules.state.round) else ""))
   if entry.label.text!=sector_text:entry.label.text=sector_text
  if is_instance_valid(enemy_marker):
   var position_id=str(rules.state.enemy.get("position","jujuy"))
   if sector_nodes.has(position_id):
    var target:Vector3=sector_nodes[position_id].root.position+Vector3(4,0,0)
    target.y=terrain_height(target.x,target.z)
    enemy_marker.position=enemy_marker.position.lerp(target,minf(1,delta*3))

func refresh_paths():
 if not is_instance_valid(route_root):return
 if path_instances==null:
  var mm0=MultiMesh.new();mm0.transform_format=MultiMesh.TRANSFORM_3D
  var disc=CylinderMesh.new();disc.top_radius=0.16;disc.bottom_radius=0.16;disc.height=0.06;disc.radial_segments=8
  mm0.mesh=disc
  path_instances=MultiMeshInstance3D.new();path_instances.multimesh=mm0
  path_instances.material_override=_mat(Color("e9c678"))
  route_root.add_child(path_instances)
 var xf=[]
 if show_paths:
  for u in rules.state.units:
   if str(u.id)!=selected and selected!="all":continue
   var points=u.get("path",[])
   for i in range(points.size()):
    if i%3!=0 and i!=points.size()-1:continue
    var p=points[i]
    var x=float(p[0]) if p is Array else float(p.get("x",0))
    var z=float(p[1]) if p is Array else float(p.get("z",0))
    xf.append(Transform3D(Basis.IDENTITY,Vector3(x,maxf(terrain_height(x,z),float(rules.state.get("water_level",0)))+0.12,z)))
 var mm:MultiMesh=path_instances.multimesh
 mm.instance_count=xf.size()
 for i in range(xf.size()):mm.set_instance_transform(i,xf[i])

func cannon_effect():
 if is_instance_valid(fire_flash):fire_flash.light_energy=4.0

func pick_ground(camera:Camera3D,mouse_pos:Vector2)->Variant:
 var from=camera.project_ray_origin(mouse_pos)
 var to=from+camera.project_ray_normal(mouse_pos)*500
 var query=PhysicsRayQueryParameters3D.create(from,to,1)
 var hit=get_world_3d().direct_space_state.intersect_ray(query)
 if hit.is_empty():return null
 return hit.position

func pick_unit(camera:Camera3D,mouse_pos:Vector2)->String:
 var best="";var nearest=55.0
 for id in unit_nodes:
  var p:Vector3=unit_nodes[id].root.global_position+Vector3(0,1.8,0)
  if camera.is_position_behind(p):continue
  var d=camera.unproject_position(p).distance_to(mouse_pos)
  if d<nearest:nearest=d;best=id
 return best

func pick_sector(camera:Camera3D,mouse_pos:Vector2)->String:
 var best="";var nearest=70.0
 for id in sector_nodes:
  var p:Vector3=sector_nodes[id].root.global_position+Vector3(0,1,0)
  if camera.is_position_behind(p):continue
  var d=camera.unproject_position(p).distance_to(mouse_pos)
  if d<nearest:nearest=d;best=id
 return best
