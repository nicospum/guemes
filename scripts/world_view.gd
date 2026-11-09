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
## Props GLB (casa, iglesia, algarrobo, cardón, rocas): se instancian con MultiMesh; si el GLB no carga se usa la geometría simple de antes.
const USE_GLB_PROPS = true
const GLB_TINT = {"tree_algarrobo":Color(0.64,0.70,0.52),"rock_cluster":Color(0.86,0.82,0.74)}
var glb_parts_cache = {}
var glb_batches = {}
## Tamaño en pantalla de las etiquetas 3D (fixed_size): constante, no depende de la distancia.
const LABEL_PIXEL_SIZE = 0.0006
var batch_parent: Node3D = null
## Justina (escala real, 1 unidad = 1 m). Todas las cifras vienen de rules.map_data().
var justina = false
signal minimap_changed
var selected_ids: Array = []
## Looks de luz y color (pista P1, contrato con P4): set_look("menu"|"justina"|"norte"). build() aplica el que corresponde solo.
const Looks = preload("res://scripts/looks/world_looks.gd")
var look := ""
var look_base_env: Environment = null
var look_base_sun: Dictionary = {}
## En el look "menu" se ocultan balizas, zona de fuego, rótulos, fichas y aros: el fondo es un cuadro, no un tablero.
var look_hide_overlays := false
## Viñeta del look (capa 0, debajo de la interfaz). Si la interfaz pone su propia viñeta, poner en false ANTES de set_look.
var look_vignette_enabled := true
var look_vignette: CanvasLayer = null
var north_terrain_mat: ShaderMaterial = null
var north_map_rect := Rect2()
## visual/r1 F5: relieve real del Norte (Copernicus GLO-90 sobre el mapa esquemático: cada sector sobre su pueblo, etiqueta razonado; docs/humahuaca/F5_TERRENO.md 3.2).
## Con NORTE_RELIEVE_REAL en false vuelve el relieve de ruido de siempre. Solo vista: las reglas del Norte no leen alturas.
const NORTE_RELIEVE_REAL := true
const NORTE_RELIEF_JSON := "res://assets/terrain/norte/norte_relieve_copernicus90.json"
var norte_relief: Dictionary = {}  ## {nx, nz, x0, z0, step, h (unidades de juego, ya con el mapeo vertical)}; vacío = relieve de ruido
var norte_sector_h: Dictionary = {}  ## id de sector → altura a la que se aplana su pueblo

func build(game_rules, quality_name = "media"):
 rules = game_rules
 quality = quality_name
 advanced_renderer = RenderingServer.get_current_rendering_method() != "gl_compatibility"
 scenario = str(rules.state.scenario)
 terrain_noise.seed = 1817
 terrain_noise.frequency = 0.052
 terrain_noise.fractal_octaves = 4
 decoration_rng.seed = 12081806
 norte_relief = _norte_relief_load() if scenario == "norte" and NORTE_RELIEVE_REAL else {}
 norte_sector_h.clear()
 # visual/r1 F5: lotes de casas por celda y distancia del cambio a _lod (Justina: 200 m, celdas de 128 m; Norte: 70 m, un lote por pueblo).
 norte_bldg.clear()
 casa_celda = 12.0 if scenario == "norte" else 128.0
 casa_lod_m = 70.0 if scenario == "norte" else 200.0
 # Justina a escala real: solo si Reglas ya expone el mapa del contrato (map_data). Si no, queda el escenario anterior.
 justina = scenario == "justine" and rules.has_method("map_data") and not rules.map_data().is_empty()
 _lighting()
 if justina:
  _build_justina()
  batch_parent = landmarks_root
  _flush_batches()
  batch_parent = self
 else:
  _ground()
  if scenario == "justine":
   _coast()
  else:
   _north()
  _flush_batches()
 route_root = Node3D.new()
 add_child(route_root)
 for u in rules.state.units:
  if justina:
   _create_group_j(u)
  else:
   _create_group(u)
 if justina:
  _create_scouts_j()
 update_state(0.01)
 set_look(_auto_look_name())

# ---------------------------------------------------------------- looks (contrato P1 ↔ P4)
## El look que corresponde sin que nadie lo pida: Norte → "norte"; mundo del I armado para el menú (main.mode == "menu") → "menu"; si no, "justina".
func _auto_look_name()->String:
 if scenario=="norte":return "norte"
 var p=get_parent()
 if p!=null and str(p.get("mode"))=="menu":return "menu"
 return "justina"

## Cambia la luz, el cielo, la niebla, el grading y la viñeta del mundo. Idempotente: pedir el look vigente no hace nada.
## Cada cambio parte de una copia nueva del Environment base y del sol base (nada se acumula ni queda colgado).
## "menu" y "justina" valen para el mundo del I; "norte" para el del III (pedir uno de otro escenario se ignora).
func set_look(nombre:String)->void:
 nombre={"juego":"justina","heroico":"menu","justine":"justina"}.get(nombre,nombre)
 if not (nombre in Looks.LOOKS) or nombre==look:return
 if not is_instance_valid(environment) or not is_instance_valid(sun):return
 if (nombre=="norte")!=(scenario=="norte"):return
 if look_base_env==null:
  look_base_env=environment.environment
  look_base_sun={"color":sun.light_color,"energy":sun.light_energy,"rot":sun.rotation_degrees}
 var env:Environment=Looks.env_copy(look_base_env)
 sun.light_color=look_base_sun.color;sun.light_energy=look_base_sun.energy;sun.rotation_degrees=look_base_sun.rot
 Looks.apply(nombre,env,sun,advanced_renderer and quality!="baja")
 environment.environment=env
 look=nombre
 north_fog_d=-1.0
 if north_terrain_mat!=null:north_terrain_mat.set_shader_parameter("northern",nombre=="norte")
 _apply_water_look(nombre)
 _set_overlays_hidden(nombre=="menu")
 if is_instance_valid(look_vignette):look_vignette.queue_free()
 look_vignette=null
 var vs=Looks.vignette_strength(nombre)
 if look_vignette_enabled and vs>0.0:
  look_vignette=Looks.make_vignette(vs);add_child(look_vignette)

var look_base_water:Dictionary={}
func _apply_water_look(nombre:String)->void:
 if water_mat==null or water_mat.shader==null:return
 if look_base_water.is_empty():
  for k in ["sky_horizon","sky_zenith","sun_dir"]:
   var v=water_mat.get_shader_parameter(k)
   if v==null:v=RenderingServer.shader_get_parameter_default(water_mat.shader.get_rid(),k)
   look_base_water[k]=v
 for k in look_base_water:water_mat.set_shader_parameter(k,look_base_water[k])
 var wp=Looks.water_params(nombre)
 if wp.is_empty():return
 for k in wp:water_mat.set_shader_parameter(k,wp[k])
 # Dirección hacia el sol del look (la luz direccional ilumina hacia -Z: el sol está en +Z de su base).
 water_mat.set_shader_parameter("sun_dir",Basis.from_euler(sun.rotation).z.normalized())

## Pose de cámara del fondo heroico del menú (la del prototipo de arte, proto/m3_menu_proto_hud.png). La fija main.gd (P4):
## camera_target = buque + (-60, 18, -45), distancia 230, inclinación 0,16 rad, rumbo -1,25 rad. Vacío si el mundo no es el del I.
func menu_camera_pose()->Dictionary:
 if not justina:return {}
 var s=M.get("ship",{})
 var ship_p=Vector3(float(s.get("x",580.0)),0.0,float(s.get("z",262.0)))
 return {"target":ship_p+Vector3(-60,18,-45),"distance":230.0,"pitch":0.16,"yaw":-1.25}

func _set_overlays_hidden(on:bool)->void:
 look_hide_overlays=on
 if not justina:return
 if is_instance_valid(labels_root):labels_root.visible=bool(layer_state.labels) and not on
 var tok=get_node_or_null("Ficha_buque")
 if tok!=null:tok.visible=not on
 for g in group_markers:
  if is_instance_valid(g.ring):g.ring.visible=not on
  for c in (g.root as Node3D).get_children():
   if str(c.name).begins_with("Ficha_"):c.visible=not on
 for id in scout_nodes:
  if unit_nodes.has(id):
   for c in (unit_nodes[id].root as Node3D).get_children():
    if str(c.name).begins_with("Ficha_"):c.visible=not on
 if on:
  for b in beacons:b.root.visible=false
  if is_instance_valid(exposure_root):exposure_root.visible=false
  for id in selected_rings:
   if is_instance_valid(selected_rings[id]):selected_rings[id].visible=false

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

var props_mat: ShaderMaterial
func _props_mat()->ShaderMaterial:
 if props_mat==null:
  props_mat=ShaderMaterial.new();props_mat.shader=load("res://shaders/justina_props.gdshader")
 return props_mat

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
  mmi.material_override=_props_mat() if justina else batch_material
  (batch_parent if batch_parent!=null else self).add_child(mmi)
 batches.clear()
 _flush_glb_batches()

## Extrae (una vez) las mallas del GLB con su transformación relativa a la raíz. Vacío si no carga.
func _glb_parts(model_name:String)->Array:
 if glb_parts_cache.has(model_name):return glb_parts_cache[model_name]
 var parts:Array=[]
 var path="res://assets/models/"+model_name+".glb"
 if USE_GLB_PROPS and ResourceLoader.exists(path):
  var packed=load(path)
  if packed is PackedScene:
   var root=packed.instantiate()
   if root!=null:
    var nodes:Array=[root]
    nodes.append_array(root.find_children("*","MeshInstance3D",true,false))
    for n in nodes:
     if not (n is MeshInstance3D) or n.mesh==null:continue
     var xf:Transform3D=Transform3D.IDENTITY
     var cur:Node=n
     while cur!=null and cur!=root:
      if cur is Node3D:xf=cur.transform*xf
      cur=cur.get_parent()
     var mesh:Mesh=n.mesh
     # Defecto de Godot 4.7.2: el color de vértice (COLOR_0) no se aplica al albedo en la primera primitiva; se fuerza en todas las superficies.
     for si in range(mesh.get_surface_count()):
      var m=mesh.surface_get_material(si)
      if m is BaseMaterial3D:
       m.vertex_color_use_as_albedo=true
       if GLB_TINT.has(model_name):
        # Invierno nublado (ronda 4): el follaje del GLB es muy claro; se oscurece sin tocar el archivo.
        var m2:BaseMaterial3D=m.duplicate()
        m2.albedo_color=GLB_TINT[model_name]
        mesh.surface_set_material(si,m2)
     parts.append({"mesh":mesh,"xf":xf})
    root.free()
 glb_parts_cache[model_name]=parts
 return parts

func _glb_ok(model_name:String)->bool:
 return not _glb_parts(model_name).is_empty()

func _inst_glb(model_name:String,xf:Transform3D):
 if not glb_batches.has(model_name):glb_batches[model_name]=[]
 glb_batches[model_name].append(xf)
 # visual/r1 F3b: en el Norte, árboles y rocas (solo decoración, sin significado de mapa) quedan anotados para poder apartarlos
 # de la huella de una tropa (_update_norte_deco). Casas, iglesia y caminos no se tocan.
 if scenario=="norte" and model_name in NORTE_DECO_MODELS:
  norte_deco.append({"m":model_name,"i":glb_batches[model_name].size()-1,"p":Vector2(xf.origin.x,xf.origin.z)})

# Variacion de color por instancia (ronda 2): paredes de lino/cal con distinta edad, techos de teja apagada; evita "cubos blancos con techo rojo identicos".
func _glb_variation(model_name:String,pos:Vector3)->Color:
 var h1=fposmod(sin(pos.x*12.9898+pos.z*78.233)*43758.5453,1.0)
 var h2=fposmod(sin(pos.x*39.3468+pos.z*11.135)*24634.6345,1.0)
 if model_name=="house_colonial" or model_name=="church_colonial":
  var wall=Color("d8cfb8").lerp(Color("c9b996"),h1)   # lino crudo -> arena (paleta del paquete)
  var k=0.66+0.22*h2
  return Color(wall.r*k*1.02,wall.g*k*0.97,wall.b*k*0.90)
 if model_name.begins_with("casa_"):
  # visual/r1 F5: el kit ya trae su color (cal, adobe, teja, torta); solo una edad leve por casa (±6 % de valor, apenas más cálida o fría).
  var vk=0.94+0.12*h1
  return Color(vk*(0.99+0.02*h2),vk,vk*(1.01-0.03*h2))
 var v=0.88+0.2*h1
 return Color(v,v*(0.97+0.06*h2),v*0.94)

## visual/r1 F5: kit de casas del territorio (assets/models/casa_*.glb, docs/historia/CASAS_F5.md). Cada casa entra en un lote
## MultiMesh por modelo y por celda de casa_celda m (128 m en la Justina; 12 m en el Norte, un pueblo): de cerca el GLB completo y desde casa_lod_m su _lod (rango de visibilidad de
## cada lote, que Godot mide al centro de la caja del lote; por eso las celdas). Lo muy lejano del tablero va directo al _lod, sin
## sombra. Las superficies se unen en una sola (_merge_surfaces: todo es color de vértice mate) y quedan 1 o 2 dibujos por lote.
var casa_celda := 128.0
var casa_lod_m := 200.0
var glb_batch_info: Dictionary = {}
## visual/r1 F5: huellas de las casas del Norte (x, z, radio) para que norte_camp no acampe encima.
var norte_bldg: Array = []

## Pone la casa `model` (frente −Z del GLB; origen en el suelo, centro de la caja). only_lod: solo la versión liviana (lejos del
## tablero). tint: valor que multiplica el color del lote (contraste con el suelo donde hace falta; 1 = como viene). Devuelve false si
## el GLB no carga (el que llama arma su respaldo procedural).
func _casa(model:String,xf:Transform3D,only_lod:bool=false,tint:float=1.0)->bool:
 if not _glb_ok(model):return false
 var lod=model+"_lod"
 var has_lod=ResourceLoader.exists("res://assets/models/"+lod+".glb")
 var cell="%d_%d" % [int(floor(xf.origin.x/casa_celda)),int(floor(xf.origin.z/casa_celda))]+("" if is_equal_approx(tint,1.0) else "~%d" % roundi(tint*100.0))
 if only_lod or not has_lod:
  var k0=(lod if has_lod else model)+"@"+cell+("#lejos" if only_lod else "")
  if not glb_batches.has(k0):
   glb_batches[k0]=[]
   glb_batch_info[k0]={"model":(lod if has_lod else model),"begin":0.0,"end":0.0,"shadow":not only_lod,"merge":true,"tint":tint}
  glb_batches[k0].append(xf)
  return true
 var kn=model+"@"+cell;var kf=lod+"@"+cell
 if not glb_batches.has(kn):
  glb_batches[kn]=[];glb_batches[kf]=[]
  glb_batch_info[kn]={"model":model,"begin":0.0,"end":casa_lod_m,"shadow":true,"merge":true,"tint":tint}
  glb_batch_info[kf]={"model":lod,"begin":casa_lod_m,"end":0.0,"shadow":true,"merge":true,"tint":tint}
 glb_batches[kn].append(xf);glb_batches[kf].append(xf)
 return true

## visual/r1 F5: altura de apoyo de una casa en la Justina: la más baja entre el centro y las cuatro esquinas de su caja (el cimiento
## de piedra se entierra del lado alto, nunca queda flotando del lado bajo).
func _casa_base_j(x:float,z:float,yaw:float,hx:float,hz:float)->float:
 var y=_far_h(x,z)
 for c in [Vector2(-hx,-hz),Vector2(hx,-hz),Vector2(-hx,hz),Vector2(hx,hz)]:
  var p=c.rotated(-yaw)
  y=minf(y,_far_h(x+p.x,z+p.y))
 return y-0.05

func _flush_glb_batches():
 for key in glb_batches:
  var xfs:Array=glb_batches[key]
  var info:Dictionary=glb_batch_info.get(key,{})
  var model_name:String=str(info.get("model",key))
  if xfs.is_empty():continue
  for part in _glb_parts(model_name):
   var mm=MultiMesh.new()
   mm.transform_format=MultiMesh.TRANSFORM_3D
   mm.mesh=_merge_surfaces(part.mesh,false) if bool(info.get("merge",false)) else part.mesh
   mm.use_colors=true
   mm.instance_count=xfs.size()
   for i in range(xfs.size()):
    mm.set_instance_transform(i,xfs[i]*part.xf)
    var vc=_glb_variation(model_name,xfs[i].origin)
    var tk=float(info.get("tint",1.0))
    mm.set_instance_color(i,Color(vc.r*tk,vc.g*tk,vc.b*tk,vc.a))
   var mmi=MultiMeshInstance3D.new()
   mmi.name="LoteGLB_"+key.replace("@","_").replace("#","_").replace("~","_t")
   mmi.multimesh=mm
   if not info.is_empty():
    # visual/r1 F5: rango de visibilidad del lote (casa completa de cerca, _lod de lejos) con 12 m de margen para que no titile.
    mmi.visibility_range_begin=float(info.begin);mmi.visibility_range_end=float(info.end)
    if float(info.begin)>0.0:mmi.visibility_range_begin_margin=12.0
    if float(info.end)>0.0:mmi.visibility_range_end_margin=12.0
    if not bool(info.shadow):mmi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   (batch_parent if batch_parent!=null else self).add_child(mmi)
   if scenario=="norte" and model_name in NORTE_DECO_MODELS:
    if not glb_live.has(model_name):glb_live[model_name]={"xfs":xfs.duplicate(),"mms":[]}
    glb_live[model_name].mms.append({"mm":mm,"pxf":part.xf})
 glb_batches.clear()
 glb_batch_info.clear()

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
 if justina:
  # Cielo de invierno nublado (ronda 4): shader propio; el horizonte iguala la niebla para fundir agua y meseta lejanas.
  var sky_sh=ShaderMaterial.new()
  sky_sh.shader=load("res://shaders/justina_sky.gdshader")
  sky.sky_material=sky_sh
  env.fog_light_color=Color("d9ceae")
  env.fog_light_energy=1.0
  env.fog_sky_affect=0.0
  env.fog_mode=Environment.FOG_MODE_DEPTH
  env.fog_density=1.0
  env.fog_depth_begin=650.0
  env.fog_depth_end=4200.0
  env.fog_depth_curve=2.2
  env.ambient_light_energy=0.66;env.ambient_light_color=Color("d9cfb6")
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
 if justina:
  sun.light_color = Color("f4e7d0");sun.light_energy = 0.82
 sun.shadow_enabled = quality != "baja"
 sun.directional_shadow_max_distance = 380 if justina else 130
 sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if (advanced_renderer and quality == "alta") else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
 sun.shadow_blur = 1.4
 if advanced_renderer and quality == "alta":sun.light_volumetric_fog_energy = 1.0
 add_child(sun)

func terrain_height(x: float, z: float) -> float:
 if scenario == "justine": return rules.terrain_height_at(x,z)
 if not norte_relief.is_empty():
  # visual/r1 F5: relieve real; cada pueblo se aplana a su propia altura (antes a 0,45), con la misma transición de 2,8 a 7 m
  var hr = _norte_relief_h(x,z)
  for s in rules.state.get("sectors",[]):
   var d = Vector2(x,z).distance_to(Vector2(float(s.x),float(s.z)))
   if d < 7.0: hr = lerpf(_norte_sector_base(s),hr,smoothstep(2.8,7.0,d))
  return hr
 var ridge = abs(terrain_noise.get_noise_2d(x*0.8,z*0.7))
 var h = 0.4 + pow(ridge,1.4)*17.0
 h += maxf(0.0, absf(x)-28.0)*0.19
 for s in rules.state.get("sectors",[]):
  var d = Vector2(x,z).distance_to(Vector2(float(s.x),float(s.z)))
  h = lerpf(0.45,h,smoothstep(2.8,7.0,d))
 return h

## visual/r1 F5: lee la grilla del Norte (metros) y le aplica el mapeo vertical sugerido en su meta: 0,4 + 16,6·((h − 300)/4700)^0,65, el mismo rango
## de 0,4 a 17 del relieve de ruido. Vacío si el archivo falta o no tiene la forma esperada.
func _norte_relief_load() -> Dictionary:
 if not FileAccess.file_exists(NORTE_RELIEF_JSON): return {}
 var d = JSON.parse_string(FileAccess.get_file_as_string(NORTE_RELIEF_JSON))
 if not (d is Dictionary) or not (d.get("grid") is Dictionary) or not (d.get("h") is Array): return {}
 var g: Dictionary = d.grid
 var nx = int(g.get("nx",0)); var nz = int(g.get("nz",0))
 if nx < 2 or nz < 2 or (d.h as Array).size() != nx*nz: return {}
 var hs = PackedFloat32Array(d.h)
 for k in range(hs.size()):
  hs[k] = 0.4 + 16.6*pow(clampf((hs[k]-300.0)/4700.0,0.0,1.0),0.65)
 return {"nx":nx,"nz":nz,"x0":float(g.get("x0",-55.0)),"z0":float(g.get("z0",-45.0)),"step":float(g.get("step",0.5)),"h":hs}

func _norte_relief_h(x: float, z: float) -> float:
 var r = norte_relief
 var fx = clampf((x-float(r.x0))/float(r.step),0.0,float(r.nx-1))
 var fz = clampf((z-float(r.z0))/float(r.step),0.0,float(r.nz-1))
 var i = mini(int(fx),int(r.nx)-2); var j = mini(int(fz),int(r.nz)-2)
 var tx = fx-float(i); var tz = fz-float(j)
 var hs: PackedFloat32Array = r.h
 var k = j*int(r.nx)+i
 return lerpf(lerpf(hs[k],hs[k+1],tx),lerpf(hs[k+int(r.nx)],hs[k+int(r.nx)+1],tx),tz)

## visual/r1 F5: texturas fotográficas del suelo (Poly Haven, CC0; assets/terrain/terrain_textures_manifest.json) en dos arreglos: albedo (una capa por
## material) y datos (normales OpenGL y después ORM). [] en calidad baja o si falta algo: el shader sigue con su color procedural de siempre.
static var terrain_tex_cache: Dictionary = {}
func _terrain_tex_arrays(dir: String, ids: Array) -> Array:
 if quality == "baja": return []
 var key = dir+"|"+",".join(PackedStringArray(ids))
 if terrain_tex_cache.has(key): return terrain_tex_cache[key]
 var alb: Array = []; var dat: Array = []
 for id in ids: alb.append(dir+"%s_albedo.jpg" % id)
 for kind in ["normal","orm"]:
  for id in ids: dat.append(dir+"%s_%s.jpg" % [id,kind])
 var a = _texture_array(alb); var d = _texture_array(dat)
 var out: Array = [a,d] if a != null and d != null else []
 terrain_tex_cache[key] = out
 return out

static func _texture_array(paths: Array) -> Texture2DArray:
 var images: Array[Image] = []
 for path in paths:
  var tex: Texture2D = load(str(path)) as Texture2D if ResourceLoader.exists(str(path)) else null
  var img: Image = tex.get_image() if tex != null else null
  if img == null or img.is_empty(): return null
  if not images.is_empty() and (img.get_size() != images[0].get_size() or img.get_format() != images[0].get_format() or img.has_mipmaps() != images[0].has_mipmaps()): return null
  images.append(img)
 var arr := Texture2DArray.new()
 return arr if arr.create_from_images(images) == OK else null

func _apply_terrain_textures(mat: ShaderMaterial, dir: String, ids: Array) -> void:
 var t = _terrain_tex_arrays(dir,ids)
 mat.set_shader_parameter("tex_on",1.0 if t.size() == 2 else 0.0)
 if t.size() == 2:
  mat.set_shader_parameter("tex_albedo",t[0]);mat.set_shader_parameter("tex_data",t[1])

## visual/r1 F5: altura del llano de un pueblo: la media del relieve real en su círculo de 2,8 m (en caché).
func _norte_sector_base(s: Dictionary) -> float:
 var id = str(s.get("id",""))
 if norte_sector_h.has(id): return norte_sector_h[id]
 var c = Vector2(float(s.x),float(s.z))
 var acc = _norte_relief_h(c.x,c.y); var n = 1.0
 for k in range(12):
  var q = c+Vector2(cos(TAU*float(k)/12.0),sin(TAU*float(k)/12.0))*2.8
  acc += _norte_relief_h(q.x,q.y); n += 1.0
 norte_sector_h[id] = acc/n
 return norte_sector_h[id]

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
 if scenario=="norte":
  # C2 (P1): el look "norte" activa la rampa por altura y pendiente, las curvas de nivel y el borde que se funde a tinta.
  north_map_rect=Rect2(-55.0,-45.0,float(nx)*step,float(nz)*step)
  mat.set_shader_parameter("map_min",north_map_rect.position)
  mat.set_shader_parameter("map_max",north_map_rect.end)
  north_terrain_mat=mat
  # visual/r1 F5: pasto del Valle de Lerma, huella con pasto y camino de tierra (grano de cerca; el color sigue siendo la rampa del Norte)
  _apply_terrain_textures(mat,"res://assets/terrain/norte/",["norte_pasto","norte_camino_pasto","norte_camino_tierra"])
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
 # Casas de la ribera, fuera de las rutas tácticas. visual/r1 F5: ranchos de paja y una casa de teja de cada tres (kit casa_*,
 # a 0,5: esta ribera vieja es esquemática); ya no hay una iglesia cada tres casas (CASAS_F5.md, «Ribera: ninguna iglesia»).
 for i in range(10):
  var p = Vector2(-43.0+(i%2)*4.7,-25.0+i*5.0)
  var m_r = "casa_ba_a" if i%3==0 else ("casa_rancho_b" if i%2==0 else "casa_rancho_a")
  if not _casa(m_r,Transform3D(Basis.from_euler(Vector3(0,-PI*0.5,0)).scaled_local(Vector3.ONE*0.5),Vector3(p.x,terrain_height(p.x,p.y)-0.05,p.y))):
   _house(Vector3(p.x,terrain_height(p.x,p.y),p.y),3.2,3.4)
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
  _pueblo_n(s,point)
  # visual/r1 F5: dos árboles fuera de las casas y del puesto realista (+4 m al este del sector; antes en (3,2, ±1), donde ahora lo tapaban).
  _tree(point+Vector3(3.5,0,-2.7),0.6)
  _tree(point+Vector3(-3.5,0,1.6),0.6)
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
  if terrain_height(p.x,p.y)<3.8: _tree(Vector3(p.x,terrain_height(p.x,p.y),p.y),decoration_rng.randf_range(0.6,1.3),i%3==0)
 _rocks_and_reeds(70 if quality=="baja" else 140)
 enemy_marker=Node3D.new()
 add_child(enemy_marker)
 # Regla de color (P1): el rojo es SOLO del enemigo. Banderola 1,6 veces mayor en rojo realista y aro rojo con borde oscuro bajo la columna.
 _cylinder(Vector3(0,2.4,0),0.08,4.8,Color("625141"),enemy_marker)
 var flag=_box(Vector3(1.12,4.0,0),Vector3(2.4,1.28,0.07),Looks.ROJO_REALISTA,enemy_marker)
 flag.rotation.z=-0.08
 var enemy_ring=_ring(3.2,Looks.ROJO_REALISTA,enemy_marker);enemy_ring.name="AroRealista";enemy_ring.position.y=0.2
 var enemy_edge=_ring(3.42,Looks.ROJO_BORDE,enemy_marker);enemy_edge.position.y=0.19
 enemy_edge.material_override=_mat(Looks.ROJO_BORDE,0.9,false)
 _world_label("◆ REALISTAS",Vector3(0,6.0,0),Color("e58478"),28,enemy_marker)
 # visual/r1 F5: tres realistas de 1817 a pie (persona_realista_1817: chaqueta de bayeta, vueltas granate = código del enemigo, chacó;
 # vestuario de DISEÑO), animados: idle quietos, walk cuando el puesto cambia de sector (_update_royalists_n). Antes royalist_1817.
 royal_rigs.clear()
 for i in range(3):
  var rr=_foot_rig(enemy_marker,"persona_realista_1817","")
  var troop:Node3D=rr.node
  troop.name="Realista_%d" % i
  troop.position=Vector3(i*0.8-0.8,0,0.6+0.25*float(i%2))
  troop.scale=Vector3.ONE*0.85
  if rr.ap!=null and (rr.ap as AnimationPlayer).has_animation("idle"):(rr.ap as AnimationPlayer).seek(1.3*float(i),true)
  royal_rigs.append(rr)

## visual/r1 F5: pueblos del Norte con el kit de casas (CASAS_F5.md, «III · _north()»). El mapa del III es esquemático (Salta y el Valle
## de Lerma quedan a 7,3 m; cada pueblo se aplana en un radio de 2,8 m y la tropa acampa a 6–9 m), así que la escala real no entra:
## todas las casas van a UNA escala de maqueta, NORTE_CASA_ESCALA (1:4,2), sin estirar ninguna (antes cada casa se deformaba a una
## huella de 1,15 × 1,45 m y la iglesia de Salta iba a 0,5). Así se conservan las proporciones entre tipos (la iglesia con torre llega a
## 2,9 m, un rancho a 0,9 m) y el pueblo entra en su aro (3,2 m). La tropa va a NORTE_FIG_SCALE (0,6 desde F6) porque es la marca de juego, no una maqueta.
## Frente −Z del kit girado media vuelta: puertas y galerías miran al sur, a la cámara inicial. [modelo, dx, dz, giro extra, (aclarado)].
## visual/r1 F6: Chicoana y Orán (solo adobe oscuro y paja) no se distinguían a 60 m, sobre todo en la ladera en sombra: Chicoana suma
## una capilla encalada (casa_capilla_a) en lugar de un rancho, Orán una casa encalada con galería (casa_galeria_b) en lugar de otro, y
## el adobe que queda va un 22 % más claro (quinto valor: tinte del lote, como los ranchos de la ribera de la Justina). Diseño.
const NORTE_CASA_ESCALA := 0.24
const NORTE_PUEBLOS := {
 "salta":[["casa_capilla_c",-1.35,-0.8,0.0],["casa_patio_b",1.5,-0.55,0.0],["casa_galeria_b",0.15,2.3,0.0]],
 "jujuy":[["casa_capilla_c",1.35,-0.8,0.0],["casa_patio_b",-1.5,-0.55,0.0],["casa_galeria_b",-0.15,2.3,0.0]],
 "lerma":[["casa_capilla_a",0.0,-1.2,0.0],["casa_pulperia_a",-1.9,0.6,0.0],["casa_rancho_a",1.75,0.4,0.1],["casa_rancho_b",0.0,1.9,-0.08]],
 "chicoana":[["casa_posta_b",0.6,-1.2,0.0,1.22],["casa_capilla_a",-1.8,1.6,0.0],["casa_galeria_b",1.3,1.5,0.0]],
 "rosario":[["casa_capilla_a",-1.4,-0.8,0.0],["casa_pulperia_a",1.0,-0.9,0.0],["casa_galeria_b",0.9,1.5,0.0],["casa_rancho_a",-1.5,1.7,0.12]],
 "oran":[["casa_capilla_a",0.0,-1.3,0.0],["casa_galeria_b",-1.6,0.9,0.1],["casa_rancho_b",1.5,0.8,-0.1,1.22],["casa_rancho_a",0.1,2.0,0.0,1.22]],
 "quebrada":[["casa_capilla_b",-1.2,-0.6,0.0],["casa_torta_b",1.5,-1.2,0.0],["casa_torta_a",1.4,0.7,0.1],["casa_corral_pirca_a",1.3,2.8,0.0]],
 "humahuaca":[["casa_capilla_a",0.0,-1.3,0.0],["casa_torta_a",-1.6,0.6,-0.1],["casa_torta_b",1.3,0.9,0.0],["casa_rancho_c",-0.3,2.0,0.15]]}

func _pueblo_n(s:Dictionary,point:Vector3)->void:
 var lay:Array=NORTE_PUEBLOS.get(str(s.id),[["casa_rancho_a",-1.0,-0.6,0.0],["casa_rancho_b",1.0,0.4,0.0],["casa_capilla_a",0.0,-1.6,0.0]])
 var sc=NORTE_CASA_ESCALA
 for e in lay:
  var model=str(e[0]);var yaw=PI+float(e[3])
  var hs=_casa_size(model)*sc*0.5
  var c=Vector2(point.x+float(e[1]),point.z+float(e[2]))
  # De pie en el punto más bajo de su caja (el pueblo es plano hasta 2,8 m; más afuera la ladera sube y el cimiento se entierra).
  var y=terrain_height(c.x,c.y)
  for k in [Vector2(-hs.x,-hs.z),Vector2(hs.x,-hs.z),Vector2(-hs.x,hs.z),Vector2(hs.x,hs.z)]:
   var q=k.rotated(-yaw);y=minf(y,terrain_height(c.x+q.x,c.y+q.y))
  if _casa(model,Transform3D(Basis.from_euler(Vector3(0,yaw,0)).scaled_local(Vector3.ONE*sc),Vector3(c.x,y-0.03,c.y)),false,float(e[4]) if e.size()>4 else 1.0):
   norte_bldg.append(Vector3(c.x,c.y,maxf(hs.x,hs.z)))
  else:
   _house(Vector3(c.x,y,c.y),1.15,1.45,model.begins_with("casa_capilla"))

var royal_rigs:Array=[]

func _road(a:Vector2,b:Vector2):
 var count=int(a.distance_to(b)/0.9)
 for i in range(1,count):
  var p=a.lerp(b,float(i)/maxi(1,count))
  _inst("cyl8",Vector3(p.x,terrain_height(p.x,p.y)+0.06,p.y),Vector3(0.56,0.045,0.56),Looks.ORO_VIEJO if scenario=="norte" else Color("b2a17c"))

func _house(pos:Vector3,w:float,d:float,church=false):
 var glb_name="church_colonial" if church else "house_colonial"
 if _glb_ok(glb_name):
  var basis:Basis
  if church:
   basis=Basis.from_scale(Vector3.ONE*clampf(w*0.2,0.25,0.6))
  else:
   # Huella del GLB ~5.7 x 6.0 m ajustada a w x d; altura con la media para no aplastarla.
   var sx=w/5.7;var sz=d/6.0
   basis=Basis.from_scale(Vector3(sx,(sx+sz)*0.5,sz))
  _inst_glb(glb_name,Transform3D(basis,pos))
  return
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

func _tree(pos:Vector3,scale_v:float,cactus=false):
 var glb_name="tree_cardon" if cactus else "tree_algarrobo"
 if _glb_ok(glb_name):
  _inst_glb(glb_name,Transform3D(Basis.from_scale(Vector3.ONE*scale_v*(0.8 if cactus else 0.7)),pos))
  return
 _inst("cyl8",pos+Vector3(0,1.45*scale_v,0),Vector3(0.26*scale_v,2.9*scale_v,0.26*scale_v),Color("655642"))
 _inst("sphere",pos+Vector3(0,3.0*scale_v,0),Vector3(2.4*scale_v,2.5*scale_v,2.4*scale_v),Color("4f5d38"))

func _rocks_and_reeds(count:int):
 var rock_mesh=SphereMesh.new();rock_mesh.radius=0.5;rock_mesh.height=0.64;rock_mesh.radial_segments=7;rock_mesh.rings=4
 var use_glb_rocks=_glb_ok("rock_cluster")
 var multimesh=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_3D;multimesh.mesh=rock_mesh;multimesh.instance_count=0 if use_glb_rocks else count
 for i in range(count):
  var x=decoration_rng.randf_range(-52,48)
  if scenario=="justine":x=decoration_rng.randf_range(-52,-11)
  var z=decoration_rng.randf_range(-40,40)
  var tr=Transform3D(Basis.from_euler(Vector3(0,decoration_rng.randf()*TAU,0)),Vector3(x,terrain_height(x,z)+0.08,z))
  var size_v=decoration_rng.randf_range(0.35,1.5)
  if use_glb_rocks:
   tr.basis=tr.basis.scaled(Vector3.ONE*size_v*0.5)
   _inst_glb("rock_cluster",tr)
   continue
  tr.basis=tr.basis.scaled(Vector3(size_v,size_v*0.6,size_v))
  multimesh.set_instance_transform(i,tr)
 if not use_glb_rocks:
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
 label.modulate=color;label.outline_size=14;label.outline_modulate=Color(0.05,0.07,0.07,0.96)
 label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 label.no_depth_test=true
 parent.add_child(label)
 return label

func _create_group(unit:Dictionary):
 var root=Node3D.new();add_child(root)
 root.position=Vector3(float(unit.x),terrain_height(float(unit.x),float(unit.z)),float(unit.z))
 var figures=Node3D.new();figures.name="Figures";root.add_child(figures)
 var mounted=bool(unit.get("mounted",true))
 var anims=[]
 # visual/r1 F3: la tropa sale de los hombres de diseño (NORTE_MEN_DISENO, tope 24 figuras). El jefe es una figura animada del GLB
 # (con su trote) al frente y al centro; el resto va en un MultiMesh (un solo dibujo por pieza) formado en filas detrás de él.
 var n=_group_count(unit)
 var lead:Node3D
 var rig:Dictionary={}
 var parts:Array
 var gid=str(unit.id)
 if mounted:
  # visual/r1 F4: jefe = caballo criollo animado (andar según la marcha, _gait_step) con el jinete 1817 en la silla; Güemes conserva
  # el acento granate del poncho. La tropa (n−1) va en MultiMesh por pelaje + jinetes, a NORTE_FIG_SCALE.
  rig=_mount_rig(figures,str(HORSE_COATS[_coat_of(gid.hash(),-1)]),"1806" if scenario=="justine" else "1817",gid,gid=="guemes")
  lead=rig.node
  parts=_mount_parts(figures,"1806" if scenario=="justine" else "1817",maxi(n-1,1),"",gid.hash())
 else:
  # visual/r1 F5: a pie en el Norte, gaucho de 1817 (persona_gaucho_1817, antes el desmontado de 1806, de otra época): jefe animado
  # (idle/walk/run, _foot_step) con poncho pardo o, si es Güemes, el granate oscuro; tropa _lod en MultiMesh.
  rig=_foot_rig(figures,"persona_gaucho_1817","heroe" if gid=="guemes" else "poncho")
  lead=rig.node
  parts=_foot_parts(figures,"persona_gaucho_1817",maxi(n-1,1),"poncho")
 lead.scale=Vector3.ONE*NORTE_FIG_SCALE
 if scenario=="norte":
  # P1 ronda 2: realce de borde (luz de contorno celeste pálido + un piso mínimo de luz) para que las figuras propias no se pierdan
  # en los valles en sombra. Un pase extra sin luz; en F3 también sobre el MultiMesh de la tropa.
  for mi in lead.find_children("*","MeshInstance3D",true,false):(mi as MeshInstance3D).material_overlay=_rim_mat()
 for p in parts:
  # visual/r1 F3b (costo): la tropa usa una malla estática con niveles de detalle (_lod_mesh) y no proyecta sombra; el jefe sí.
  (p.mmi as GeometryInstance3D).cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  if scenario=="norte":(p.mmi as GeometryInstance3D).material_overlay=_rim_mat()
 var ring=_ring(2.65,Looks.ORO_VIEJO,root)
 if scenario=="norte":
  # visual/r1 F1: aro de aliado fino a escala real (cinta de ~0,16 m que copia el relieve, 0,18 m sobre el suelo) y CON prueba de
  # profundidad: una loma lo tapa como taparía a la tropa. Reemplaza el toro grueso dibujado encima de todo (P1 ronda 2).
  ring.mesh=null;ring.position.y=0.0;ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  # visual/r1 F3b: el aro deja de copiar el relieve (en las laderas del III se volvía una mancha deforme) y pasa a ser un anillo
  # plano a la altura media de la tropa (_norte_ring), que se lee como elipse limpia; lo que tapa una loma queda como fantasma.
  # visual/r1 F1: ficha de pantalla chica (14 px, la misma de la Justina; silueta por tipo) que aparece al alejar la cámara.
  _token_j(root,int(TOKEN_SHAPES.get(str(unit.id),0)),Looks.CELESTE,J_TOKEN_PX,40.0,80.0,1.0,false,0.0)
 selected_rings[str(unit.id)]=ring
 var label=_world_label(str(unit.name),Vector3(0,4.0,0),Color("e9d4aa"),30,root)
 unit_labels[str(unit.id)]=label
 var entry={"root":root,"figures":figures,"mounted":mounted,"anims":anims,"last":root.position,"lead":lead,"parts":parts,"n":n,"lod_far":false,"ring_r":2.3,"no_shadow":true,"rig":rig}
 unit_nodes[str(unit.id)]=entry
 _layout_group_n(entry,str(unit.id),false)

## visual/r1 F3: formación del Norte, en el marco local de `figures` (que ya gira hacia la marcha): jefe adelante y al centro, la tropa
## en línea detrás (mismo trazado que la Justina, GLB 1817 a NORTE_FIG_SCALE). visual/r1 F3b: el conjunto se centra en el punto de la
## vista (root), que ya es el campamento de la tropa (norte_camp): ficha, rótulo, aro y selección quedan sobre las figuras.
func _layout_group_n(entry:Dictionary,id:String,moving:bool)->void:
 var n:int=int(entry.n);var mounted:bool=bool(entry.mounted)
 var m=maxi(n-1,1)
 var sc=NORTE_FIG_SCALE   # visual/r1 F4: escala del modelo y de la separación (las separaciones del Norte salen de _gaps)
 var gz=_gaps(mounted).y*sc
 var ext=_form_extent(m,mounted,sc,0.0)
 var z0=-(ext.y+gz)*0.5   # el jefe va una fila por delante del bloque
 var gseed=id.hash()
 var t=elapsed_visual
 var far=bool(entry.get("lod_far",false))
 var fig:Node3D=entry.figures
 var base:Vector3=(entry.root as Node3D).position
 var lead:Node3D=entry.get("lead",null)
 var hsum=0.0
 if is_instance_valid(lead):
  var lw=base+Vector3(0,0,z0).rotated(Vector3.UP,fig.rotation.y)
  lead.position=Vector3(0.0,terrain_height(lw.x,lw.z)-base.y,z0)
  hsum+=lead.position.y
 for i in range(m):
  var f=_form_slot(i,m,mounted,sc,0.0,gseed,NORTE_JITTER)
  var lp=Vector3(f.x,0.0,z0+gz+f.y)
  # Cada figura apoya en su propio suelo (relieve quebrado): altura del terreno en su punto del mundo menos la del grupo.
  var wp=base+lp.rotated(Vector3.UP,fig.rotation.y)
  var gy=terrain_height(wp.x,wp.z)-base.y
  hsum+=gy
  var bob=0.07*absf(sin(t*7.0+float(i)*0.9)) if (moving and not far and (mounted or not (entry.parts[0] as Dictionary).has("poses"))) else 0.0   # visual/r1 F5: a pie con cuadros horneados, sin vaivén
  var xf=Transform3D(Basis.from_euler(Vector3(0.0,f.z,0.0)).scaled_local(Vector3.ONE*sc),Vector3(lp.x,gy+bob*sc,lp.z))
  _set_fig(entry.parts,i,xf)
 # Radio del aro: media diagonal de la huella (jefe incluido) + medio caballo y un margen.
 # visual/r1 F4: a caballo, medio caballo criollo (1,25 m) + 0,15 m (antes 2,1 con el caballo viejo).
 entry["ring_r"]=sqrt(ext.x*ext.x+pow((ext.y+gz)*0.5,2.0))+(1.4 if mounted else 1.0)*sc
 entry["ring_y"]=hsum/float(m+1)   # altura media de la tropa sobre el punto del grupo (para el aro plano)

## visual/r1 F4b: el realce era demasiado: con fuerza 0,62, exponente 2,2 y piso 0,035, visto de arriba casi toda la figura quedaba
## en el borde y la tropa se leía gris pálida y rosada (celeste sumado al alazán y al poncho). Ahora es un filo fino (exponente 4,5,
## fuerza 0,30, piso 0,008): el caballo conserva su pelaje y el jinete su poncho, y la silueta sigue despegada del valle en sombra.
## abs(): las caras de la malla de tropa unida pueden traer la normal invertida; así no se encienden enteras.
var rim_mat:ShaderMaterial=null
func _rim_mat()->ShaderMaterial:
 if rim_mat==null:
  var sh=Shader.new()
  sh.code="""shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;
uniform vec4 rim_color : source_color = vec4(0.66, 0.80, 0.90, 1.0);
uniform float strength = 0.30;
uniform float lift = 0.008;
void fragment(){
	float f = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 4.5);
	ALBEDO = rim_color.rgb * (lift + f * strength);
}"""
  rim_mat=ShaderMaterial.new();rim_mat.shader=sh
 return rim_mat

## visual/r1 F3b: aro plano del Norte. Una corona de 48 tramos en el plano horizontal (malla en caché por radio y ancho), puesta
## a la altura media de la tropa + 0,25 m: en pantalla es siempre una elipse limpia aunque la tropa esté en una ladera.
var flat_ring_cache:Dictionary={}
func _norte_ring(mi:MeshInstance3D,r:float,half_w:float,y:float)->void:
 var key="%.2f|%.3f" % [r,half_w]
 if str(mi.get_meta("flat_key",""))!=key:
  if not flat_ring_cache.has(key):
   var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
   for i in range(49):
    var a=TAU*float(i)/48.0;var dir=Vector3(cos(a),0.0,sin(a))
    st.add_vertex(dir*(r-half_w));st.add_vertex(dir*(r+half_w))
   flat_ring_cache[key]=st.commit()
  mi.mesh=flat_ring_cache[key];mi.set_meta("flat_key",key)
 mi.position=Vector3(0.0,y+0.25,0.0)

## visual/r1 F3b: campamento de la tropa en su sector (punto de la vista; las reglas siguen usando el sector). Entre 24 lugares
## alrededor del pueblo, a 6–9 m y más cerca de él que de otro pueblo, elige el de relieve más parejo dentro de la huella y menos tapado desde la cámara inicial
## (yaw −0,17, inclinación 0,91), lejos de las casas y rótulos de todos los sectores y del puesto realista (+4 m al este del
## sector). Si hay más de un grupo en el mismo sector, cada uno toma otro lugar (slot). Determinista y en caché.
const NORTE_CAMP_R = 4.6
var norte_camp_cache:Dictionary={}
func norte_camp(sector_id:String,slot:int)->Vector2:
 var key=sector_id+"|"+str(slot)
 if norte_camp_cache.has(key):return norte_camp_cache[key]
 var sec:Dictionary=rules.get_sector(sector_id) if rules.has_method("get_sector") else {}
 if sec.is_empty():return Vector2(INF,INF)
 var c0=Vector2(float(sec.x),float(sec.z))
 var taken:Array=[]
 for k in range(slot):taken.append(norte_camp(sector_id,k))
 var avoid:Array=[]
 for s2 in rules.state.get("sectors",[]):
  avoid.append(Vector2(float(s2.x),float(s2.z)));avoid.append(Vector2(float(s2.x)+4.0,float(s2.z)))
 var best=c0+Vector2(-3.3,2.8);var best_cost=INF
 # visual/r1 F5: primera pasada evitando también las casas; si ningún lugar sirve, la segunda las ignora (como antes de F5).
 for use_bldg in ([true,false] if not norte_bldg.is_empty() else [false]):
  if best_cost<INF:break
  for r in [6.0,7.0,8.0,9.0]:
   for ai in range(24):
    var a=TAU*float(ai)/24.0
    var c=c0+Vector2(cos(a),sin(a))*r
    if absf(c.x)>44.0 or absf(c.y)>34.0:continue
    var bad=false
    for q in avoid:
     if c.distance_to(q)<NORTE_CAMP_R+1.6:bad=true;break
    for t in taken:
     if c.distance_to(t)<NORTE_CAMP_R*2.0+0.8:bad=true;break
    # visual/r1 F5: tampoco encima de una casa del pueblo (huella de _pueblo_n): la tropa queda a NORTE_CAMP_R + media casa de cada una.
    if use_bldg:
     for b in norte_bldg:
      if c.distance_to(Vector2(b.x,b.y))<NORTE_CAMP_R+b.z*0.5+0.2:bad=true;break
    # Que se lea como parte de SU pueblo: más cerca de su sector que de cualquier otro (con 1,5 m de margen).
    for s3 in rules.state.get("sectors",[]):
     if str(s3.id)!=sector_id and c.distance_to(Vector2(float(s3.x),float(s3.z)))<c.distance_to(c0)+1.5:bad=true;break
    if bad:continue
    var hs:Array=[]
    for k in range(13):
     var q2=c if k==0 else c+Vector2(cos(TAU*float(k)/6.0),sin(TAU*float(k)/6.0))*(NORTE_CAMP_R*(0.5 if k<=6 else 1.0))
     hs.append(terrain_height(q2.x,q2.y))
    var hmin:float=hs.min();var hmax:float=hs.max()
    var occl=0
    var to_cam=Vector2(sin(-0.17),cos(-0.17));var rise=tan(0.91)
    for k in range(7):
     var q3=c if k==0 else c+Vector2(cos(TAU*float(k)/6.0),sin(TAU*float(k)/6.0))*NORTE_CAMP_R*0.7
     var h0=terrain_height(q3.x,q3.y)+0.8
     for step in range(1,26):
      var pp=q3+to_cam*float(step)
      if terrain_height(pp.x,pp.y)>h0+rise*float(step):occl+=1;break
    var cost=(hmax-hmin)+float(occl)*1.5+r*0.35
    # Lejos del lado de los otros pueblos, donde acampan sus tropas (sin esto Güemes en Lerma y Arias en Jujuy se pisaban los aros).
    for s4 in rules.state.get("sectors",[]):
     if str(s4.id)!=sector_id:cost+=0.6*maxf(0.0,16.0-c.distance_to(Vector2(float(s4.x),float(s4.z))))
    if cost<best_cost:best_cost=cost;best=c
 norte_camp_cache[key]=best
 return best

## Punto de la vista para un grupo del Norte (también lo usa main.gd para encuadrar): su campamento en el sector, según cuántos
## grupos anteriores comparten ese sector.
func norte_group_point(u:Dictionary)->Vector3:
 var sid=str(u.get("sector_id",""))
 var slot=0
 for o in rules.state.units:
  if o==u or str(o.id)==str(u.id):break
  if str(o.get("sector_id",""))==sid and float(o.get("strength",0.0))>0.0:slot+=1
 var c=norte_camp(sid,slot) if sid!="" else Vector2(INF,INF)
 if not is_finite(c.x):c=Vector2(float(u.x)-3.3,float(u.z)+2.8)
 return Vector3(c.x,terrain_height(c.x,c.y),c.y)

## visual/r1 F3b: árboles y rocas decorativos del Norte dentro de la huella de una tropa (+0,8 m) se apartan (escala ~0 en su lote)
## y vuelven cuando la tropa se va. Solo decoración: casas, caminos y marcas de sector no se tocan.
const NORTE_DECO_MODELS = ["tree_algarrobo","tree_cardon","rock_cluster"]
var norte_deco:Array=[]
var glb_live:Dictionary={}
var norte_deco_hidden:Dictionary={}
var norte_deco_sig:=""
func _update_norte_deco()->void:
 if norte_deco.is_empty():return
 var zones:Array=[]
 var sig=""
 for id in unit_nodes:
  var e:Dictionary=unit_nodes[id]
  var r:Node3D=e.root
  if not r.visible:continue
  zones.append(Vector3(r.position.x,r.position.z,float(e.get("ring_r",2.3))+0.8))
  sig+="%d,%d,%d;" % [roundi(r.position.x*4.0),roundi(r.position.z*4.0),roundi(float(e.get("ring_r",2.3))*4.0)]
 if sig==norte_deco_sig:return
 norte_deco_sig=sig
 var want:Dictionary={}
 for d in norte_deco:
  for z in zones:
   if (d.p as Vector2).distance_to(Vector2(z.x,z.y))<z.z:want[str(d.m)+"#"+str(d.i)]=d;break
 for k in norte_deco_hidden.keys():
  if not want.has(k):_deco_set(norte_deco_hidden[k],false);norte_deco_hidden.erase(k)
 for k in want:
  if not norte_deco_hidden.has(k):_deco_set(want[k],true);norte_deco_hidden[k]=want[k]

func _deco_set(d:Dictionary,hidden:bool)->void:
 var live:Dictionary=glb_live.get(str(d.m),{})
 if live.is_empty():return
 var xf:Transform3D=live.xfs[int(d.i)]
 if hidden:xf=Transform3D(Basis.from_scale(Vector3.ONE*0.001),xf.origin)
 for p in live.mms:(p.mm as MultiMesh).set_instance_transform(int(d.i),xf*p.pxf)

func _ring_mat_n(c:Color)->StandardMaterial3D:
 var key="ring_n"+c.to_html()
 if ring_mat_cache.has(key):return ring_mat_cache[key]
 var m=StandardMaterial3D.new();m.albedo_color=c;m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 # visual/r1 F1: el aro respeta la profundidad (antes no_depth_test=true y prioridad 2: se veía entero a través de las lomas).
 # En este relieve tan quebrado la parte tapada por una loma queda como un fantasma tenue (segunda pasada; F3b: 40 %, antes 22 %, para
# que el aro plano se siga leyendo entero donde la ladera lo corta), no a pleno.
 m.no_depth_test=false;m.disable_fog=true;m.cull_mode=BaseMaterial3D.CULL_DISABLED
 m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;m.albedo_color.a=0.92
 var ghost=StandardMaterial3D.new();ghost.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;ghost.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 ghost.albedo_color=Color(c.r,c.g,c.b,0.4);ghost.no_depth_test=true;ghost.disable_fog=true;ghost.cull_mode=BaseMaterial3D.CULL_DISABLED;ghost.render_priority=-1
 m.next_pass=ghost
 ring_mat_cache[key]=m
 return m

## visual/r1 F1: cinta circular a escala real que sigue el relieve (cada vértice a la altura del suelo, o del agua en la Justina,
## más unos centímetros), con prueba de profundidad. `center` es la posición del aro en coordenadas de la vista (mi.position.y = 0).
## Se rehace solo si el centro se mueve más de 5 cm o cambian radio o ancho; 48 tramos por aro, costo despreciable.
func _conform_ring(mi:MeshInstance3D,center:Vector3,r:float,half_w:float)->void:
 var last:Vector3=mi.get_meta("ring_c",Vector3(1e9,0,0))
 if last.distance_to(center)<0.05 and absf(float(mi.get_meta("ring_hw",-1.0))-half_w)<0.001 and absf(float(mi.get_meta("ring_rr",-1.0))-r)<0.02:return
 mi.set_meta("ring_c",center);mi.set_meta("ring_hw",half_w);mi.set_meta("ring_rr",r)
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
 var n=48
 for i in range(n+1):
  var a=TAU*float(i)/float(n);var dir=Vector3(cos(a),0.0,sin(a))
  for rr in [r-half_w,r+half_w]:
   var w=center+dir*rr
   var gy=maxf(_h(w.x,w.z),level_m)+0.22 if justina else terrain_height(w.x,w.z)+0.18
   st.add_vertex(Vector3(dir.x*rr,gy-center.y,dir.z*rr))
 mi.mesh=st.commit()

func _ring_ribbon(color:Color,parent:Node3D,name_s:String)->MeshInstance3D:
 var n=MeshInstance3D.new();n.name=name_s
 var mat=StandardMaterial3D.new();mat.albedo_color=color;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mat.disable_fog=true
 n.material_override=mat;n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;n.set_meta("ribbon",true)
 parent.add_child(n)
 return n

## Regla de color (P1, V-02): el poncho granate de rider_1817 se leía rojo a escala de juego (el rojo es del enemigo).
## Se reclasifica el color de vértice del GLB en carga (sin regenerar el modelo): poncho y faja → lana parda #705741 / ocre #8A7350.
## Solo la primera figura del grupo de Güemes conserva un granate oscuro (#5E1F1A) como acento de héroe (regla 4). Aspecto, no dato.
var poncho_cache:Dictionary={}
func _recolor_poncho(fig:Node3D,hero:bool)->void:
 for mi in fig.find_children("*","MeshInstance3D",true,false):
  if mi.mesh==null:continue
  mi.mesh=_poncho_mesh(mi.mesh,hero)

## visual/r1 F3b: copia estática de una malla del GLB (sin huesos: el MultiMesh la dibuja en pose de reposo) con niveles de detalle
## generados en tiempo de carga (ImporterMesh.generate_lods); el motor baja de detalle solo según el tamaño en pantalla. En caché.
var lod_mesh_cache:Dictionary={}
## visual/r1 F4: keep_bones conserva huesos y pesos (caballo animado del jefe, tras unir superficies con _merge_surfaces).
func _lod_mesh(src:Mesh,keep_bones:bool=false)->Mesh:
 var key=str(src.get_rid().get_id())+("|b" if keep_bones else "")
 if lod_mesh_cache.has(key):return lod_mesh_cache[key]
 var im=ImporterMesh.new()
 for si in range(src.get_surface_count()):
  var a=src.surface_get_arrays(si)
  if not keep_bones:a[Mesh.ARRAY_BONES]=null;a[Mesh.ARRAY_WEIGHTS]=null
  im.add_surface(Mesh.PRIMITIVE_TRIANGLES,a,[],{},src.surface_get_material(si))
 im.generate_lods(25.0,60.0,[])
 var out:Mesh=im.get_mesh()
 if out==null or out.get_surface_count()==0:out=src
 lod_mesh_cache[key]=out
 return out

## visual/r1 F3: la reclasificación del poncho, por malla (antes dentro de _recolor_poncho), para usarla también en el MultiMesh de la tropa.
func _poncho_mesh(src:Mesh,hero:bool)->Mesh:
 var brown=Color("705741").srgb_to_linear()
 var hero_c=Color("5e1f1a").srgb_to_linear()
 var sash=Color("8a7350").srgb_to_linear()
 var key=str(src.get_rid().get_id())+("|h" if hero else "|p")
 if not poncho_cache.has(key):
  var out=ArrayMesh.new()
  for si in range(src.get_surface_count()):
   var a=src.surface_get_arrays(si)
   var mat=src.surface_get_material(si)
   var nm=str(mat.resource_name) if mat!=null else ""
   # visual/r1 F4: jinete F4 sin textura: color normalizado (/0,62) para reconocer el granate y tinta de salida x0,62 (ver F4_ALBEDO).
   var nk=1.0/F4_ALBEDO if nm.begins_with("F4") else 1.0
   var ok=F4_ALBEDO if nm.begins_with("F4") else 1.0
   var role=_role_of(nm)
   if role!="" and a[Mesh.ARRAY_COLOR] is PackedColorArray:
    # visual/r1 F5: jinete F5 (y figuras F5 de a pie) con material por rol: el umbral de color de abajo dejaba sin teñir el 35 % del
    # poncho nuevo (más oscuro por la oclusión horneada: r normalizado 0,04–0,26) y lo teñía casi negro (factor r/0,5). Ahora se tiñe la
    # superficie entera del rol con la sombra relativa (_role_cols): poncho pardo de tropa, granate oscuro del héroe, faja ocre.
    if role=="poncho":a[Mesh.ARRAY_COLOR]=_role_cols(a[Mesh.ARRAY_COLOR],hero_c if hero else brown,ok)
    elif role=="panuelo":a[Mesh.ARRAY_COLOR]=_role_cols(a[Mesh.ARRAY_COLOR],sash,ok)
   elif a[Mesh.ARRAY_COLOR] is PackedColorArray and (nm.ends_with("wool") or nm.ends_with("linen")):
    var cols:PackedColorArray=a[Mesh.ARRAY_COLOR]
    for k in range(cols.size()):
     var c=Color(cols[k].r*nk,cols[k].g*nk,cols[k].b*nk,cols[k].a)
     if c.r>0.1 and c.r>c.g*2.5 and c.r>c.b*2.5:
      var t=(hero_c if hero else brown) if nm.ends_with("wool") else sash
      var f=clampf(c.r/0.5,0.2,1.15)*ok
      cols[k]=Color(t.r*f,t.g*f,t.b*f,c.a)
    a[Mesh.ARRAY_COLOR]=cols
   out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
   out.surface_set_material(si,mat)
  poncho_cache[key]=out
 return poncho_cache[key]

func update_state(delta:float):
 if justina:
  _update_justina(delta)
  return
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
    # visual/r1 F4: caballos criollos de tropa (antes horse_only, el caballo viejo), a la escala de las figuras del Norte.
    for h_index in range(2):_model("caballo_criollo_"+str(HORSE_COATS[h_index])+"_lod",Vector3(-1.2-h_index*1.2,0,0),stable).scale=Vector3.ONE*NORTE_FIG_SCALE
    parked_horses[id]=stable
   var old=entry.root;remove_child(old);old.queue_free();unit_nodes.erase(id);_create_group(u);entry=unit_nodes[id]
  var root:Node3D=entry.root
  var h=terrain_height(float(u.x),float(u.z))
  # Solo soldados desmontados representan el abordaje; los caballos quedan en el banco.
  if str(u.get("stage","")) in ["boarding","capturing","captured"]:h=maxf(h,0.2)
  var goal=Vector3(float(u.x),h,float(u.z))
  if scenario=="norte":
   # visual/r1 F3b: la vista lleva la tropa a su campamento en el sector (norte_group_point): el lugar más parejo y visible
   # cerca del pueblo, sin pisar casas ni rótulos (antes un corrimiento fijo -3,3 / +2,8 que caía en laderas y detrás de lomas).
   goal=norte_group_point(u)
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
  # visual/r1 F3: LOD de la tropa del Norte (misma regla que la Justina): de lejos, mitad de figuras, sin sombra ni trote del jefe.
  var far_n=false
  var cam_n=get_viewport().get_camera_3d()
  if cam_n!=null and entry.has("parts"):
   far_n=_lod_far_at(entry,cam_n.global_position.distance_to(root.global_position))
   if far_n!=bool(entry.get("lod_far",false)):
    entry["lod_far"]=far_n;_apply_fig_lod(entry);entry["relayout"]=true
  var anim_on=animating and not far_n
  if entry.get("animating",false)!=anim_on:
   entry["animating"]=anim_on
   for ap in entry.anims:
    ap.speed_scale=0.75
    if anim_on:ap.play()
    else:ap.pause()
  # visual/r1 F4: andar del jefe criollo según lo que avanza en pantalla (el III no tiene velocidades de juego: va de campamento a
  # campamento), escalado a NORTE_FIG_SCALE; quieto, idle.
  var rig_n:Dictionary=entry.get("rig",{})
  if not rig_n.is_empty():
   var v_n=Vector2(root.position.x-float(entry.get("vpos",root.position).x),root.position.z-float(entry.get("vpos",root.position).z)).length()/maxf(delta,0.0001)
   entry["vpos"]=root.position
   if bool(rig_n.get("foot",false)):
    _foot_step(rig_n,v_n if v_n<60.0 else 0.0,animating,NORTE_FIG_SCALE,delta,far_n or not root.visible)
    _foot_troop_anim(entry.parts,rig_n,far_n or not root.visible)
   else:_gait_step(rig_n,v_n if v_n<60.0 else 0.0,-1.0,animating,"",NORTE_FIG_SCALE,delta,far_n or not root.visible)
  if entry.has("parts"):
   # Bajas y refuerzos cambian la cantidad de figuras; en marcha se rehace la formación (suelo y vaivén) y una vez más al parar.
   var n_now=_group_count(u)
   if n_now!=int(entry.n):
    if entry.has("rig") and not (entry.rig as Dictionary).is_empty():_resize_parts(entry.parts,maxi(n_now-1,1),id.hash())
    else:
     for p in entry.parts:
      p.mm.visible_instance_count=-1;p.mm.instance_count=maxi(n_now-1,1)
    entry.n=n_now;_apply_fig_lod(entry);entry["relayout"]=true
   if animating or bool(entry.get("relayout",false)) or bool(entry.get("was_moving",false))!=animating:
    _layout_group_n(entry,id,animating)
    entry["relayout"]=false
   entry["was_moving"]=animating
  entry.last=goal
  root.visible=float(u.strength)>0.0
  if scenario=="norte":
   # Regla de color: aliado = aro celeste siempre visible; el elegido pasa a oro viejo.
   selected_rings[id].visible=true
   var sel_n=id==selected or selected=="all"
   # visual/r1 F3b: aro plano (elipse limpia en pantalla) del radio de la huella, a la altura media de la tropa.
   _norte_ring(selected_rings[id],float(entry.get("ring_r",2.3)),0.2 if sel_n else 0.07,float(entry.get("ring_y",0.0)))
   var rm=_ring_mat_n(Looks.ORO_VIEJO if sel_n else Looks.CELESTE)
   if selected_rings[id].material_override!=rm:selected_rings[id].material_override=rm
  else:
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
  _update_norte_deco()
  for sector in rules.state.sectors:
   var entry=sector_nodes.get(str(sector.id),{})
   if entry.is_empty():continue
   var sel_s=str(sector.id)==selected_sector
   entry.ring.visible=sel_s or int(sector.get("intel_until",0))>=int(rules.state.round)
   # Regla de color: sector elegido = oro viejo; reconocido (información) = violeta.
   var ring_m=_mat(Looks.ORO_VIEJO if sel_s else Looks.VIOLETA,0.55,true)
   if entry.ring.material_override!=ring_m:entry.ring.material_override=ring_m
   entry.label.modulate=Looks.ORO_LUZ if sel_s else (Color("dfd8bf") if bool(sector.get("known",false)) else Color("a79f92"))
   var sector_text=str(sector.name).to_upper()+(" · ?" if not bool(sector.get("known",false)) else (" · ◇" if int(sector.get("intel_until",0))>=int(rules.state.round) else ""))
   if entry.label.text!=sector_text:entry.label.text=sector_text
  if is_instance_valid(enemy_marker):
   var position_id=str(rules.state.enemy.get("position","jujuy"))
   if sector_nodes.has(position_id):
    var target:Vector3=sector_nodes[position_id].root.position+Vector3(4,0,0)
    target.y=terrain_height(target.x,target.z)
    var em_prev=enemy_marker.position
    enemy_marker.position=enemy_marker.position.lerp(target,minf(1,delta*3))
    # visual/r1 F5: los realistas caminan mientras el puesto se mueve y miran hacia donde van; quietos, idle.
    var em_v=Vector2(enemy_marker.position.x-em_prev.x,enemy_marker.position.z-em_prev.z)
    for rr in royal_rigs:
     if not is_instance_valid(rr.node):continue
     var mv=em_v.length()/maxf(delta,0.0001)
     if mv>0.15:(rr.node as Node3D).rotation.y=lerp_angle((rr.node as Node3D).rotation.y,atan2(-em_v.x,-em_v.y),minf(1.0,delta*6.0))
     _foot_step(rr,mv,mv>0.15,0.85,delta,false)
  if look=="norte":_update_north_fog()

## C1: la niebla de profundidad del Norte arranca un poco detrás del punto que mira la cámara (así el zoom no apaga el mapa)
## y llega a tinta 95 m después: lo cercano queda limpio y los bordes lejanos se funden en negro. Solo escribe si cambia > 2 m.
var north_fog_d := -1.0
func _update_north_fog()->void:
 var cam=get_viewport().get_camera_3d()
 if cam==null or not is_instance_valid(environment):return
 var o:Vector3=cam.global_position
 var f:Vector3=-cam.global_transform.basis.z
 var d=96.0
 if f.y<-0.05:d=clampf((o.y-2.0)/-f.y,30.0,400.0)
 if absf(d-north_fog_d)<2.0:return
 north_fog_d=d
 var env:Environment=environment.environment
 env.fog_depth_begin=d*1.08
 env.fog_depth_end=d*1.08+95.0

func refresh_paths():
 if justina:
  _refresh_paths_j()
  return
 if not is_instance_valid(route_root):return
 if path_instances==null:
  var mm0=MultiMesh.new();mm0.transform_format=MultiMesh.TRANSFORM_3D
  var disc=CylinderMesh.new();disc.top_radius=0.16;disc.bottom_radius=0.16;disc.height=0.06;disc.radial_segments=8
  mm0.mesh=disc
  path_instances=MultiMeshInstance3D.new();path_instances.multimesh=mm0
  # Ruta propia = violeta (regla de color); en el Norte, aclarada para leerse sobre el relieve en sombra.
  var pmat=_mat(Color("a58ae0") if scenario=="norte" else Color("e9c678"),0.6,true)
  path_instances.material_override=pmat
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

func cannon_effect(from:Vector2=Vector2.ZERO,to:Vector2=Vector2.ZERO)->void:
 if justina:
  _cannon_effect_j(from,to)
  return
 if is_instance_valid(fire_flash):fire_flash.light_energy=4.0

func pick_ground(camera:Camera3D,mouse_pos:Vector2)->Variant:
 if justina:
  var hit_j=_ray_surface(camera.project_ray_origin(mouse_pos),camera.project_ray_normal(mouse_pos))
  return hit_j
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

# =====================================================================================
# JUSTINA a escala real (1 unidad = 1 m, +x este/rio, +z sur, norte = -z).
# La geometria sale de rules.map_data(); la altura del suelo, de rules.terrain_height_at (UNA sola implementacion).
# Esta vista no calcula daño, nivel ni ordenes y no dibuja el fondo del agua que el jugador no conoce.
# =====================================================================================
var ship_hd_applied:float=-999.0
const J_CELL = 4.0
const SHIP_SCALE = 2.2
# Proporciones del casco (ronda 4): el GLB mide 16,8 x 6,6 m a escala 1 (eslora/manga 2,5). Un mercante de 26 canones tiene ~40 m de eslora y ~10 m de manga (eslora/manga ~4): se estira a lo largo y se afina a lo ancho. Reconstruccion estetica; sin dimensiones documentadas.
const SHIP_SX = 1.62
const SHIP_SY = 2.2
const SHIP_SZ = 2.4
const SHIP_KEEL = 1.58
## visual/r1 F4: el caballo criollo nuevo ya viene a escala real (1,45 m de cruz, ~2,51 m de largo): la Justina lo usa a escala 1
## (antes 0,82 sobre el caballo viejo de 3,39 m, que así medía ~2,8 m).
const RIDER_SCALE = 1.0
const FOOT_SCALE = 0.9
## visual/r1 F4: caballos criollos (tools/f4_caballos.py). Jefe animado (10 000 triángulos, idle/walk/trot/gallop en el lugar) y
## tropa estática de pocos triángulos (_lod: caballo 1 756 + jinete ~1 084). Mismo modelo en cuatro pelajes; la tropa los mezcla
## por grupo con un reparto fijo (mayoría zainos y alazanes, pocos tordillos y overos). Pelajes y reparto: diseño.
const HORSE_COATS = ["zaino","alazan","tordillo","overo"]
const HORSE_COAT_W = [0.46,0.34,0.12,0.08]
## Asiento del jinete sobre el caballo (hueso «silla», en reposo): la tropa pone al jinete ahí; el jefe lo cuelga del hueso.
const RIDER_SEAT = Vector3(0.0,1.5,0.0)
## visual/r1 F4: velocidad (m/s, a escala 1) a la que cada andar del jefe pisa sin patinar; el andar sale de la velocidad real del
## grupo (y del paso pedido: C/T/G) y speed_scale = velocidad en pantalla / la del andar. Umbrales con histéresis entre andares.
## visual/r1 F4b: medidas sobre los GLB con el tranco corregido (barrido del casco apoyado / tiempo de apoyo): paso 1,60, trote 3,30,
## galope 7,00 m/s. Antes las animaciones daban ~0,9 / 2 / 4 y con estos valores los cascos patinaban (iban al doble de su tranco).
const GAIT_MPS = {"walk":1.6,"trot":3.3,"gallop":7.0}
const GAIT_UP = {"walk":2.5,"trot":5.2}
const GAIT_DOWN = {"walk":2.1,"trot":4.6}
## Las tintas del jinete F4 vienen sin textura (create_models guardaba color/0,62 porque lo multiplicaba una textura de media
## ~0,62): para reclasificar se normalizan y la tinta de salida se multiplica por 0,62, así el color final queda como antes.
const F4_ALBEDO = 0.62
const GROUP_BAND = 14.0
## visual/r1 F3: tropa a escala real. Cada figura representa 3,5 hombres (regla 3–4) y un grupo muestra entre 6 y 24 figuras;
## de ahí las pérdidas restan figuras en proporción a la fuerza. Las cifras de hombres son de DISEÑO (ver _fig_men): nada se muestra.
const MEN_PER_FIGURE = 3.5
const FIG_MIN = 6
const FIG_MAX = 24
## visual/r1 F3: separación de la tropa a escala 1 (se multiplica por la escala del modelo). Caballería más abierta que la infantería;
## a pie ~1,0 m de frente y 1,3 m de fondo. Diseño de lectura, no reglamento de época.
## visual/r1 F4: con el caballo criollo (0,77 m de ancho, 2,51 m de largo; antes 1,07 y 3,39 m) la Justina pone ~1,5 m de hombro a
## hombro y una fila cada largo de caballo + 0,6 m (3,1 m): a escala 1 la huella queda casi igual a la de F3 (1,56 x 3,23 m a 0,82).
const CAV_GAP_X = 1.5
const CAV_GAP_Z = 3.1
## visual/r1 F4: el Norte cierra más las filas (0,43 m entre caballos de costado y 0,29 m de la cola a la cabeza, a escala 1).
const NORTE_GAP_X = 1.2
const NORTE_GAP_Z = 2.8
const FOOT_GAP_X = 1.0
const FOOT_GAP_Z = 1.3
## visual/r1 F3: LOD de figuras. Más allá de esta distancia de cámara (m, con ±20 m de histéresis) cada grupo dibuja la mitad de las
## figuras (repartidas en toda la huella, no las de atrás), sin sombra y sin el vaivén de la marcha: a esa distancia miden 1–2 px.
const FIG_LOD_FAR_M = 300.0
const FIG_LOD_KEEP = 0.5
## visual/r1 F3: hombres de DISEÑO del Norte (III). Son fuerzas de campaña abstractas (game_rules: «las agrupaciones, rutas y cifras
## son una abstracción») y el juego no tiene cifra de efectivos. Güemes y Arias: orden de cientos de hombres (diseño) → con la regla
## pasan de 24 figuras y se TOPAN en 24 (tope de lectura y rendimiento, no proporción real). Partida del valle: banda chica, 60 → 17.
const NORTE_MEN_DISENO = {"guemes":400.0,"arias":300.0,"zavala":60.0}
## visual/r1 F3: escala de las figuras del Norte. El III es un mapa de campaña (Salta–Jujuy, decenas de km, en ~21 m de mundo): ahí no
## hay escala real posible y la figura ya era un símbolo. A escala 1 una tropa de 24 jinetes ocupa ~13 x 12 m y tapa el sector vecino
## (Salta queda a ~10 m de Güemes y los grupos a ~12 m entre sí); a 0,55 y con filas cerradas (x0,88 la separación de la Justina, sin
## que los caballos se toquen) entra en un aro de menos de 6 m. Diseño de lectura.
## visual/r1 F4: con el caballo criollo (2,51 m de largo; el viejo medía 3,39) la escala real 1,0 no entra: 24 jinetes sin tocarse
## piden un aro de ~7,3 m y los campamentos (norte_camp) están pensados para ~5,9 m. La mayor que entra es 0,8, con línea de 8 de
## frente (_form_dims) y las separaciones NORTE_GAP_*: aro de ~5,9 m, como en F3b. El caballo mide así 2,0 m (antes 1,86).
## visual/r1 F6: 0,6. Con los pueblos del kit en maqueta (NORTE_CASA_ESCALA 0,24) un jinete a 0,8 (2 m de caballo) era tan alto
## como una casa y la tropa tapaba el pueblo vecino. A 0,6 (caballo de 1,5 m) sigue siendo la marca de juego, más grande que la maqueta
## a propósito, pero el aro baja de ~5,9 a ~4,4 m, entra holgado en el campamento (norte_camp, NORTE_CAMP_R 4,6) y deja ver el pueblo.
## Decidido con capturas (qa-visual-r1/f6_jn/vistas_08 contra vistas_06). Diseño de lectura.
const NORTE_FIG_SCALE = 0.6
## visual/r1 F4: desorden de la tropa del Norte (fracción del de la Justina): con filas tan cerradas, el entero haría tocarse caballos.
const NORTE_JITTER = 0.5
const DECK_Y = 3.9
const DECK_REACH = 70.0
const J_STAGE_TEXT = {"working":"trabaja","stumbling":"tropezó","dismounting":"desmonta","boarding":"aborda","routed":"dispersos","blocked":"bloqueado","rally":"reagrupa","lost":"perdido","waiting_tide":""}

var M: Dictionary = {}
var map_w = 900.0
var map_h = 520.0
var hf: PackedFloat32Array = PackedFloat32Array()
var hf_nx = 0
var hf_nz = 0
var level_m = 1.65
var level_applied = -99.0
var water_mat: ShaderMaterial
var terrain_mat: ShaderMaterial
var water_nodes: Array = []
var landmarks_root: Node3D
var labels_root: Node3D
var knowledge_root: Node3D
var exposure_root: Node3D
var exposure_forced = false
var exposure_user_on = false
var layer_state = {"paths":true,"probes":true,"exposure":true,"labels":true,"landmarks":true,"unit_labels":true}
var level_high_m = 1.65
## Recursos del conocimiento (sondas, balizas, boyas): se crean una vez y se reescriben; no se crean mallas ni materiales por baliza.
var kn_strips: MeshInstance3D
var kn_strips_mesh: ArrayMesh
var kn_posts: MultiMeshInstance3D
var kn_buoys_red: MultiMeshInstance3D
var kn_buoys_green: MultiMeshInstance3D
var kn_stakes: MultiMeshInstance3D
var kn_labels: Array = []
var kn_label_used = 0
var kn_rebuilds = 0
var beacons: Array = []
const BEACON_TYPES = ["ship","battery","bullring"]
var landmark_info: Dictionary = {}
var landmark_labels_3d: Dictionary = {}
var extra_labels: Array = []
var scout_nodes: Dictionary = {}
var state_version_seen = -1
var knowledge_sig = ""
var minimap_requested = false
var minimap_cache: Dictionary = {}
var minimap_version = 0
var minimap_sig = ""
var minimap_timer = 0.0
var minimap_last_size = Vector2i(260,150)
var ship_hull: Node3D
var ship_mud: MeshInstance3D
var ship_y0=0.0
var ship_gun_pos: Array = []
var smoke_pool: Array = []
var smoke_next = 0
var splash_pool: Array = []
var splash_next = 0
var flash_pool: Array = []
var flash_next = 0
var shot_queue: Array = []
var battery_pos = Vector3.ZERO
var battery_timer = 0.0
var parked_j: Dictionary = {}
var ring_mat_cache: Dictionary = {}
var extra_dirty_t = 0.0

# ---------------------------------------------------------------- utilidades
func _h(x:float,z:float)->float:
 if hf_nx<2:return 0.0
 var fx=clampf(x/J_CELL,0.0,float(hf_nx-1)-0.0001)
 var fz=clampf(z/J_CELL,0.0,float(hf_nz-1)-0.0001)
 var ix=int(fx);var iz=int(fz)
 var tx=fx-float(ix);var tz=fz-float(iz)
 var a=hf[iz*hf_nx+ix];var b=hf[iz*hf_nx+ix+1]
 var c=hf[(iz+1)*hf_nx+ix];var d=hf[(iz+1)*hf_nx+ix+1]
 return lerpf(lerpf(a,b,tx),lerpf(c,d,tx),tz)

func _surface_y(x:float,z:float)->float:
 return maxf(_h(x,z),level_m)

func _poly_x(poly:Array,z:float)->float:
 if poly.is_empty():return 0.0
 if z<=float(poly[0][1]):return float(poly[0][0])
 for i in range(poly.size()-1):
  var a=poly[i];var b=poly[i+1]
  if z<=float(b[1]):
   var t=(z-float(a[1]))/maxf(0.0001,float(b[1])-float(a[1]))
   return lerpf(float(a[0]),float(b[0]),t)
 return float(poly[poly.size()-1][0])

func _tag_color(tag:String)->Color:
 var t=M.get("source_tags",{}).get(tag,{})
 return Color(str(t.get("color","#d9d3b2")))

func _tag_glyph(tag:String)->String:
 return str(M.get("source_tags",{}).get(tag,{}).get("glyph",""))

func _pt(p)->Vector2:
 if p is Dictionary:return Vector2(float(p.get("x",0)),float(p.get("z",0)))
 if p is Array:return Vector2(float(p[0]),float(p[1]))
 if p is Vector2:return p
 return Vector2.ZERO

func _inst_t(kind:String,xf:Transform3D,color:Color):
 if not batches.has(kind):batches[kind]={"xf":[],"col":[]}
 batches[kind].xf.append(xf)
 batches[kind].col.append(color)

func _inst_r(kind:String,pos:Vector3,size_v:Vector3,yaw:float,color:Color,tilt:Vector3=Vector3.ZERO):
 var b=Basis.from_euler(Vector3(tilt.x,yaw,tilt.z)).scaled_local(size_v)
 _inst_t(kind,Transform3D(b,pos),color)

func _label_j(text_value:String,pos:Vector3,color:Color,font_size:int,parent:Node3D)->Label3D:
 var label=_world_label(text_value,pos,color,font_size,parent)
 label.outline_size=16
 return label

# ---------------------------------------------------------------- construccion
func _build_justina():
 M=rules.map_data()
 var sz=M.get("size",{"w":900.0,"h":520.0})
 map_w=float(sz.get("w",900.0));map_h=float(sz.get("h",520.0))
 level_m=float(rules.water_level_m())
 level_high_m=float(M.get("tide",{}).get("level_high_m",1.65))
 _sample_heightfield()
 _terrain_j()
 _horizon_j()
 _water_j()
 landmarks_root=Node3D.new();landmarks_root.name="Hitos";add_child(landmarks_root)
 labels_root=Node3D.new();labels_root.name="Rotulos";add_child(labels_root)
 knowledge_root=Node3D.new();knowledge_root.name="Conocimiento";add_child(knowledge_root)
 _knowledge_nodes_j()
 _landmarks_j()
 _ramp_paths_j()
 _scenery_j()
 _barranca_j()
 _meseta_town_j()
 _ribera_j()
 _scale_bar_j()
 _obstacles_j()
 _ship_j()
 _beacons_j()
 _ensign_j(M.get("ship",{}))
 _effects_j()
 _exposure_j()
 # visual/r1 F5: horneado previo de la tropa de a pie de cada grupo (piel por CPU, tinte y LOD: ~50 ms en total al cargar), así el
 # desmonte en pleno juego no da un tirón.
 for g in M.get("groups",[]):_foot_poses("persona_voluntario_1806",str(g.get("id","")))

func _sample_heightfield():
 hf_nx=int(round(map_w/J_CELL))+1
 hf_nz=int(round(map_h/J_CELL))+1
 hf.resize(hf_nx*hf_nz)
 for iz in range(hf_nz):
  for ix in range(hf_nx):
   hf[iz*hf_nx+ix]=float(rules.terrain_height_at(float(ix)*J_CELL,float(iz)*J_CELL))

func _base_bed(x:float)->float:
 var pts:Array=M.get("bed_profile",{}).get("points_x_elev",[])
 if pts.is_empty():return 0.0
 if x<=float(pts[0][0]):return float(pts[0][1])
 for i in range(pts.size()-1):
  var a=pts[i];var b=pts[i+1]
  if x<=float(b[0]):
   var t=(x-float(a[0]))/maxf(0.0001,float(b[0])-float(a[0]))
   return lerpf(float(a[1]),float(b[1]),t)
 return float(pts[pts.size()-1][1])

## Color de zona (rgb) y cuanto es campo/pasto (a). El sombreador agrega el detalle procedural.
func _ground_color(x:float,z:float,h:float,crest:float,toe:float,road_x:float)->Color:
 var n=terrain_noise.get_noise_2d(x*0.6,z*0.6)
 var grass=Color("6a6a3c").lerp(Color("86794a"),clampf(0.5+n*0.8,0,1))
 var ochre=Color("a98450")
 var sand=Color("b2a27b")
 var mud=Color("6f6247")
 var c:Color
 var veg=1.0
 if x<=crest:
  c=grass
  if absf(x-road_x)<3.4:c=c.lerp(Color("a58f62"),0.6)
 elif x<toe:
  var t=clampf((x-crest)/maxf(1.0,toe-crest),0.0,1.0)
  c=grass.lerp(ochre,smoothstep(0.0,0.25,t)).lerp(sand,smoothstep(0.75,1.0,t)*0.5)
  veg=1.0-smoothstep(0.55,1.0,t)*0.8
 else:
  c=mud.lerp(sand,smoothstep(0.1,level_high_m+0.05,h))
  if h>level_high_m:c=sand.lerp(Color("7f7d4e"),smoothstep(level_high_m+0.05,level_high_m+1.4,h)*0.35)
  veg=0.0
 c.a=veg
 return c

func _terrain_j():
 var barranca=M.get("barranca",{})
 var crest_poly:Array=barranca.get("crest",[])
 var toe_poly:Array=barranca.get("toe",[])
 var road_poly:Array=[]
 for lm in M.get("landmarks",[]):
  if str(lm.get("type",""))=="road":road_poly=lm.get("polyline",[])
 var nverts=hf_nx*hf_nz
 var verts=PackedVector3Array();verts.resize(nverts)
 var norms=PackedVector3Array();norms.resize(nverts)
 var cols=PackedColorArray();cols.resize(nverts)
 var crest_z=PackedFloat32Array();crest_z.resize(hf_nz)
 var toe_z=PackedFloat32Array();toe_z.resize(hf_nz)
 var road_z=PackedFloat32Array();road_z.resize(hf_nz)
 for iz in range(hf_nz):
  var z=float(iz)*J_CELL
  crest_z[iz]=_poly_x(crest_poly,z);toe_z[iz]=_poly_x(toe_poly,z);road_z[iz]=_poly_x(road_poly,z) if not road_poly.is_empty() else -999.0
 for iz in range(hf_nz):
  for ix in range(hf_nx):
   var i=iz*hf_nx+ix
   var x=float(ix)*J_CELL;var z=float(iz)*J_CELL
   var h=hf[i]
   verts[i]=Vector3(x,h,z)
   var hl=hf[iz*hf_nx+maxi(ix-1,0)];var hr=hf[iz*hf_nx+mini(ix+1,hf_nx-1)]
   var hu=hf[maxi(iz-1,0)*hf_nx+ix];var hd=hf[mini(iz+1,hf_nz-1)*hf_nx+ix]
   norms[i]=Vector3(hl-hr,2.0*J_CELL,hu-hd).normalized()
   cols[i]=_ground_color(x,z,h,crest_z[iz],toe_z[iz],road_z[iz])
 var idx=PackedInt32Array();idx.resize((hf_nx-1)*(hf_nz-1)*6)
 var k=0
 for iz in range(hf_nz-1):
  for ix in range(hf_nx-1):
   var a=iz*hf_nx+ix;var b=a+1;var c=a+hf_nx;var d=c+1
   idx[k]=a;idx[k+1]=b;idx[k+2]=c;idx[k+3]=b;idx[k+4]=d;idx[k+5]=c
   k+=6
 terrain_mat=ShaderMaterial.new()
 terrain_mat.shader=load("res://shaders/terrain_justina_r4.gdshader")
 terrain_mat.set_shader_parameter("color_gamma",2.6 if advanced_renderer else 1.9)
 terrain_mat.set_shader_parameter("water_level",level_m)
 terrain_mat.set_shader_parameter("level_high",level_high_m)
 # visual/r1 F5: arena húmeda, barro y pasto de ribera por zona (grano de cerca; la altura sigue siendo la de Reglas)
 _apply_terrain_textures(terrain_mat,"res://assets/terrain/justina/",["jn_arena_humeda","jn_barro","jn_pasto_ribera"])
 var arr=[];arr.resize(Mesh.ARRAY_MAX)
 arr[Mesh.ARRAY_VERTEX]=verts;arr[Mesh.ARRAY_NORMAL]=norms;arr[Mesh.ARRAY_COLOR]=cols;arr[Mesh.ARRAY_INDEX]=idx
 var mesh=ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr)
 var mi=MeshInstance3D.new();mi.name="Terreno";mi.mesh=mesh;mi.material_override=terrain_mat
 add_child(mi)

# ---- Terreno continuo hasta el horizonte (ronda 4). Fuera del mapa la costa serpentea suavemente y la meseta sube en lomadas bajas;
# dentro del mapa devuelve exactamente la altura de Reglas. Ningun dato de juego depende de esta funcion fuera de 0..w, 0..h.
var relief_noise = FastNoiseLite.new()
var grid_axes_cache:Array=[]
var grid_h_cache:PackedFloat32Array=PackedFloat32Array()

func _far_h(x:float,z:float)->float:
 var dx=maxf(-x,0.0)
 var dz=maxf(maxf(-z,z-map_h),0.0)
 var dist=sqrt(dx*dx+dz*dz)
 if dist<=0.0 and x<=map_w:return _h(x,z)
 var off=90.0*sin(z*0.0021+0.8)*smoothstep(0.0,500.0,dz)
 var h=_h(clampf(x-off,0.0,map_w),clampf(z,0.0,map_h))
 var land=smoothstep(1.5,5.0,h)
 var w=smoothstep(0.0,700.0,dist)
 h+=land*w*(relief_noise.get_noise_2d(x,z)*15.0+3.0)
 return h

func _axis_coords(extent:float,before:Array,after:Array)->Array:
 var out:Array=[]
 out.append_array(before)
 var n=int(round(extent/J_CELL))
 for i in range(n+1):out.append(float(i)*J_CELL)
 out.append_array(after)
 return out

func _grid_axes()->Array:
 var xs=_axis_coords(map_w,[-3000.0,-2000.0,-1200.0,-700.0,-400.0,-200.0,-100.0,-50.0,-20.0,-8.0],[map_w+8.0,map_w+20.0,map_w+50.0,map_w+100.0,map_w+200.0,map_w+500.0,map_w+1000.0,map_w+2000.0,4600.0])
 var zs=_axis_coords(map_h,[-3200.0,-2200.0,-1400.0,-800.0,-400.0,-200.0,-100.0,-50.0,-20.0,-8.0],[map_h+8.0,map_h+20.0,map_h+50.0,map_h+100.0,map_h+200.0,map_h+400.0,map_h+800.0,map_h+1400.0,map_h+2200.0,3800.0])
 return [xs,zs]

func _horizon_j():
 relief_noise.seed=4606;relief_noise.frequency=0.0011;relief_noise.fractal_octaves=3
 var ax=_grid_axes();var xs:Array=ax[0];var zs:Array=ax[1]
 var nx=xs.size();var nz=zs.size()
 var ix_in=0;var ix_end=0;var iz_in=0;var iz_end=0
 for i in range(nx):
  if absf(float(xs[i]))<0.001:ix_in=i
  if absf(float(xs[i])-map_w)<0.001:ix_end=i
 for j in range(nz):
  if absf(float(zs[j]))<0.001:iz_in=j
  if absf(float(zs[j])-map_h)<0.001:iz_end=j
 var hs=PackedFloat32Array();hs.resize(nx*nz)
 for j in range(nz):
  for i in range(nx):hs[j*nx+i]=_far_h(float(xs[i]),float(zs[j]))
 var verts=PackedVector3Array();verts.resize(nx*nz)
 var cols=PackedColorArray();cols.resize(nx*nz)
 var norms=PackedVector3Array();norms.resize(nx*nz)
 var barranca=M.get("barranca",{})
 for j in range(nz):
  var zz=float(zs[j])
  var zc=clampf(zz,0.0,map_h)
  var dz=maxf(maxf(-zz,zz-map_h),0.0)
  var off=90.0*sin(zz*0.0021+0.8)*smoothstep(0.0,500.0,dz)
  var crest=_poly_x(barranca.get("crest",[]),zc)+off;var toe=_poly_x(barranca.get("toe",[]),zc)+off
  for i in range(nx):
   var xx=float(xs[i])
   var h=hs[j*nx+i]
   verts[j*nx+i]=Vector3(xx,h,zz)
   cols[j*nx+i]=_ground_color(xx,zz,h,crest,toe,-999.0)
   var il=maxi(i-1,0);var ir=mini(i+1,nx-1);var ju=maxi(j-1,0);var jd=mini(j+1,nz-1)
   var gx=(hs[j*nx+ir]-hs[j*nx+il])/maxf(0.01,float(xs[ir])-float(xs[il]))
   var gz=(hs[jd*nx+i]-hs[ju*nx+i])/maxf(0.01,float(zs[jd])-float(zs[ju]))
   norms[j*nx+i]=Vector3(-gx,1.0,-gz).normalized()
 var idx=PackedInt32Array()
 for j in range(nz-1):
  for i in range(nx-1):
   # Se omite la zona del mapa (la malla fina de Terreno la cubre); los bordes comparten vertices cada 4 m: sin grietas.
   if i>=ix_in and i<ix_end and j>=iz_in and j<iz_end:continue
   var a=j*nx+i;var b=a+1;var c=a+nx;var d=c+1
   idx.append_array(PackedInt32Array([a,b,c,b,d,c]))
 var arr=[];arr.resize(Mesh.ARRAY_MAX)
 arr[Mesh.ARRAY_VERTEX]=verts;arr[Mesh.ARRAY_NORMAL]=norms;arr[Mesh.ARRAY_COLOR]=cols;arr[Mesh.ARRAY_INDEX]=idx
 var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr)
 var mi=MeshInstance3D.new();mi.name="Horizonte";mi.mesh=mesh;mi.material_override=terrain_mat;mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 mi.custom_aabb=AABB(Vector3(-3000,-10,-3200),Vector3(7700,60,7000))
 add_child(mi)
 grid_axes_cache=ax;grid_h_cache=hs

func _water_j():
 water_mat=ShaderMaterial.new()
 water_mat.shader=load("res://shaders/water_rio_plata.gdshader")
 water_mat.set_shader_parameter("water_level",level_m)
 water_mat.set_shader_parameter("visible_depth_m",float(M.get("knowledge",{}).get("visibility_depth_m",0.3)))
 # R6: el tono del agua sale de palette.water.turbid_* del JSON (antes no se leia).
 var wp:Dictionary=M.get("palette",{}).get("water",{})
 for pair in [["turbid_near","near_color"],["turbid_mid","mid_color"],["turbid_far","far_color"]]:
  if wp.has(pair[0]):water_mat.set_shader_parameter(pair[1],Color(str(wp[pair[0]])))
 var sh=M.get("ship",{});var hdg=deg_to_rad(float(sh.get("heading_deg",0.0)))
 water_mat.set_shader_parameter("ship_xz",Vector2(float(sh.get("x",580.0)),float(sh.get("z",262.0))))
 water_mat.set_shader_parameter("ship_fwd",Vector2(sin(hdg),-cos(hdg)))
 water_mat.set_shader_parameter("ship_half",Vector2(5.4,21.0)*ship_far_k)   # visual/r1 F1: en sintonía con la escala inicial del buque (antes x1,5 fijo)
 water_mat.set_shader_parameter("unc_radius",float(sh.get("uncertainty_radius_m",120.0)))
 # Una sola superficie plana a y = nivel, del pie de la barranca al horizonte. UV.x = altura real del suelo (halo de 0,3 m y espuma);
 # UV2.x = fondo base publico por x (solo degrada el color; no revela bancos ni pozo oculto).
 var toe_min=map_w
 for tp in M.get("barranca",{}).get("toe",[]):toe_min=minf(toe_min,float(tp[0]))
 var xs:Array=grid_axes_cache[0];var zs:Array=grid_axes_cache[1]
 var nxa=xs.size();var nz=zs.size()
 var i0=0
 for i in range(nxa):
  if float(xs[i])<=toe_min-24.0:i0=i
 var nx=nxa-i0
 var verts=PackedVector3Array();verts.resize(nx*nz)
 var uvs=PackedVector2Array();uvs.resize(nx*nz)
 var uv2=PackedVector2Array();uv2.resize(nx*nz)
 var norms=PackedVector3Array();norms.resize(nx*nz)
 for j in range(nz):
  for i in range(nx):
   var k=j*nx+i
   var xx=float(xs[i+i0])
   verts[k]=Vector3(xx,0.0,float(zs[j]))
   uvs[k]=Vector2(grid_h_cache[j*nxa+i+i0],0.0)
   uv2[k]=Vector2(_base_bed(xx),0.0)
   norms[k]=Vector3.UP
 var idx=PackedInt32Array();idx.resize((nx-1)*(nz-1)*6)
 var q=0
 for j in range(nz-1):
  for i in range(nx-1):
   var a=j*nx+i;var b=a+1;var c=a+nx;var d=c+1
   idx[q]=a;idx[q+1]=b;idx[q+2]=c;idx[q+3]=b;idx[q+4]=d;idx[q+5]=c
   q+=6
 var arr=[];arr.resize(Mesh.ARRAY_MAX)
 arr[Mesh.ARRAY_VERTEX]=verts;arr[Mesh.ARRAY_NORMAL]=norms;arr[Mesh.ARRAY_TEX_UV]=uvs;arr[Mesh.ARRAY_TEX_UV2]=uv2;arr[Mesh.ARRAY_INDEX]=idx
 var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr)
 var mi=MeshInstance3D.new();mi.name="Agua";mi.mesh=mesh;mi.material_override=water_mat;mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 mi.custom_aabb=AABB(Vector3(-100,-5,-3200),Vector3(4800,10,7000))
 add_child(mi);water_nodes.append(mi);water=mi
 for n in water_nodes:n.position.y=level_m
 water_mat.render_priority=0

# ---------------------------------------------------------------- hitos
func _lm_pos(lm:Dictionary)->Vector2:
 if lm.has("x"):return Vector2(float(lm.x),float(lm.z))
 var poly:Array=lm.get("polyline",[])
 if poly.is_empty():return Vector2.ZERO
 var mid=poly[poly.size()/2]
 return Vector2(float(mid[0]),float(mid[1]))

func _ramp_paths_j():
 # R6: barranca.ramps[].visual_path (Diseño): camino de tierra de ~95-100 m que se ve sobre la meseta; la pendiente de juego no cambia.
 for r in M.get("barranca",{}).get("ramps",[]):
  var vp:Dictionary=r.get("visual_path",{})
  var poly:Array=vp.get("polyline",[])
  if poly.size()<2:continue
  var verts=PackedVector3Array();var norms=PackedVector3Array();var idx=PackedInt32Array()
  var w=1.6
  for i in range(poly.size()):
   var p0=Vector2(float(poly[i][0]),float(poly[i][1]))
   var p1=Vector2(float(poly[mini(i+1,poly.size()-1)][0]),float(poly[mini(i+1,poly.size()-1)][1]))
   var p2=Vector2(float(poly[maxi(i-1,0)][0]),float(poly[maxi(i-1,0)][1]))
   var dir=(p1-p2).normalized();var nrm=Vector2(-dir.y,dir.x)
   for sd in [-1.0,1.0]:
    var q=p0+nrm*sd*w
    verts.append(Vector3(q.x,_h(q.x,q.y)+0.08,q.y));norms.append(Vector3.UP)
   if i>0:
    var a=(i-1)*2
    idx.append_array([a,a+1,a+2,a+1,a+3,a+2])
  var arr=[];arr.resize(Mesh.ARRAY_MAX)
  arr[Mesh.ARRAY_VERTEX]=verts;arr[Mesh.ARRAY_NORMAL]=norms;arr[Mesh.ARRAY_INDEX]=idx
  var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr)
  var mi=MeshInstance3D.new();mi.name="CaminoBajada_"+str(r.get("id","x"));mi.mesh=mesh;mi.material_override=_mat(Color("a58f68"),1.0)
  mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  add_child(mi)

func _landmarks_j():
 for lm in M.get("landmarks",[]):
  var id=str(lm.id);var p=_lm_pos(lm);var tag=str(lm.get("tag","diseno"))   # R6: un hito sin etiqueta NO se muestra como documentado
  # R6: sufijo visible para todo lo no documentado: marker_suffix del JSON, o (diseño)/(tradición) segun la etiqueta (history.json lo promete).
  var suf=str(lm.get("marker_suffix",""))
  if suf=="":suf=" (tradición)" if tag=="tradicion" else (" (diseño)" if tag=="diseno" else "")
  var base_name=str(lm.get("name",id)).replace(" (diseño)","").replace(" (tradición)","")
  landmark_info[id]={"id":id,"name":base_name+suf,"type":str(lm.get("type","")),"tag":tag,"source":str(lm.get("source","")),"x":p.x,"z":p.y}
  var top=_h(p.x,p.y)+6.0
  match str(lm.get("type","")):
   "bullring":
    _bullring_j(lm);top=_h(p.x,p.y)+8.0
   "battery":
    _battery_j(lm);top=_h(p.x,p.y)+7.0
   "road":
    _alameda_j(lm);top=_h(p.x,p.y)+10.0
   "camp":
    _camp_j(lm);top=_h(p.x,p.y)+6.0
   "command":
    _command_j(lm);top=_h(p.x,p.y)+7.0
   "ship":
    top=level_m+26.0
   "cliff":
    top=_h(p.x,p.y)+3.0
  var text=_tag_glyph(tag)+" "+base_name+suf
  var lab=_label_j(text,Vector3(p.x,top,p.y),_tag_color(tag).lerp(Color.WHITE,0.35),30,labels_root)
  lab.name="Rotulo_"+id
  if str(lm.get("type",""))=="ship":
   # R3-visual: el rotulo del buque va al costado de la ficha, no encima del casco.
   lab.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
   lab.offset=Vector2(52.0,-6.0)
  lab.visibility_range_end=900.0
  landmark_labels_3d[id]=lab
 var ei=0
 for e in M.get("labels_extra",[]):
  var tag2=str(e.get("tag","diseno"))
  var lab2=_label_j(_tag_glyph(tag2)+" "+str(e.text),Vector3(float(e.x),level_m+3.0,float(e.z)),_tag_color(tag2).lerp(Color.WHITE,0.35),28,labels_root)
  extra_labels.append({"id":"extra_"+str(ei),"label":lab2,"x":float(e.x),"z":float(e.z),"tag":tag2,"text":str(e.text),"cond":str(e.get("show_when",""))})
  ei+=1
 # Casas del Retiro sobre la meseta (decoracion; sin rotulo): el pueblo queda al oeste de la Alameda.
 # R4: agrupadas en manzanas de 2-3 casas con tapia (no cajas sueltas); reconstruccion, Vidal 1820 muestra caserio continuo.
 for hz in [20.0,64.0,110.0,152.0,372.0,408.0,452.0,496.0]:
  var crest_x=_poly_x(M.get("barranca",{}).get("crest",[]),hz)
  var hx=maxf(3.0,crest_x-14.0-decoration_rng.randf()*6.0)
  # visual/r1 F6: estas 16 casas de las manzanas R4 seguían con house_colonial (teja salmón clara, la que se veía anaranjada con la luz
  # cálida); pasan al kit del territorio como el resto de la Justina (_house_at "ciudad": azotea, teja o rancho; frente al este, a la
  # barranca; ≤ 8,4 m de frente, entran en los 9,5 m entre casas). Sin el kit, las de antes.
  if _glb_ok("casa_ba_a"):
   _house_at(hx,hz,7.5,8.5,-PI*0.5,"ciudad");_house_at(hx-1.0,hz+9.5,7.0,8.0,-PI*0.5,"ciudad")
  else:
   _house(Vector3(hx,_h(hx,hz),hz),7.5,8.5,false)
   _house(Vector3(hx-1.0,_h(hx-1.0,hz+9.5),hz+9.5),7.0,8.0,false)
  # R6: tapia cerrando un patio (4 lados cortos, alineados con las casas y asentados en el terreno); antes eran tablones sueltos que salian al aire.
  var tx0=hx-9.5;var tx1=hx+9.0;var tz0=hz-7.0;var tz1=hz+16.5
  for seg_i in range(4):
   var ax=[tx0,tx1,tx0,tx0][seg_i];var az=[tz1,tz0,tz0,tz0][seg_i]
   var bx=[tx1,tx1,tx1,tx0][seg_i];var bz=[tz1,tz1,tz0,tz1][seg_i]
   var segs=maxi(1,int(ceil(Vector2(bx-ax,bz-az).length()/4.0)))
   for si in range(segs):
    var f0=float(si)/float(segs);var f1=float(si+1)/float(segs)
    var mx=lerpf(ax,bx,(f0+f1)*0.5);var mz=lerpf(az,bz,(f0+f1)*0.5)
    var ln=Vector2(bx-ax,bz-az).length()/float(segs)
    var along_x=seg_i%2==0
    var wh=1.9-0.25*float(seg_i==3)
    if seg_i==0 and si==segs/2:continue   # portón
    _inst_r("box",Vector3(mx,_h(mx,mz)+wh*0.5-0.1,mz),Vector3(ln+0.05 if along_x else 0.5,wh,0.5 if along_x else ln+0.05),0.0,Color("bdb096"))

func _bullring_j(lm:Dictionary):
 var c=Vector2(float(lm.x),float(lm.z));var r=float(lm.get("radius_m",24.0))*0.50   # R-div1: huella visual 62 % (el fuerte dominaba la escena)
 var y0=_h(c.x,c.y)
 # Plaza de Toros (Boneo 1801, Vidal 1820 lamina 05; paquete F01): exterior OCTOGONAL (r = radio de vertices), ruedo circular
 # independiente, muro encalado, techo de teja en el anillo de gradas y 4 portales (Pillado: cuatro puertas, orientacion desconocida).
 # Medidas de diseño: la altura y el ruedo no son datos historicos.
 var ruedo=r*0.5
 _inst_t("cyl12",Transform3D(Basis.from_scale(Vector3(ruedo*1.0,0.3,ruedo*1.0)),Vector3(c.x,y0+0.1,c.y)),Color("a38d6b"))
 var apo=r*cos(PI/8.0);var side=2.0*r*sin(PI/8.0)
 var wall_h=clampf(r*0.2,4.0,9.0)
 for i in range(8):
  var a=TAU*(float(i)+0.5)/8.0
  var yaw=-a-PI/2.0
  var pw=Vector3(c.x+cos(a)*apo,0,c.y+sin(a)*apo)
  var gate=(i%2==0)
  if gate:
   # portal: dos tramos de muro a los lados de un vano oscuro
   var tang=Vector2(-sin(a),cos(a))
   for sg in [-1.0,1.0]:
    var q=Vector2(pw.x,pw.z)+tang*sg*side*0.34
    _inst_r("box",Vector3(q.x,y0+wall_h*0.5,q.y),Vector3(side*0.32,wall_h,2.2),yaw,Color("c3b690"))
   _inst_r("box",Vector3(pw.x,y0+wall_h*0.9,pw.z),Vector3(side*0.36,wall_h*0.22,2.2),yaw,Color("b8aa86"))
  else:
   var wc=[Color("cdbf9c"),Color("c4b58f"),Color("d3c7a8"),Color("bfae88")][i%4]
   _inst_r("box",Vector3(pw.x,y0+wall_h*0.5,pw.z),Vector3(side,wall_h,2.2),yaw,wc)
   # Aspilleras (visual R2): troneras oscuras en la cara exterior para que el muro no sea un bloque liso.
   var tg=Vector2(-sin(a),cos(a))
   for k2 in [-0.28,0.0,0.28]:
    var qa=Vector2(pw.x,pw.z)+tg*side*k2+Vector2(cos(a),sin(a))*1.15
    _inst_r("box",Vector3(qa.x,y0+wall_h*0.62,qa.y),Vector3(0.5,0.95,0.25),yaw,Color("3d3027"))
  # Zocalo desgastado (barro y humedad) y techo de teja rojiza del paquete.
  var pb=Vector3(c.x+cos(a)*(apo+0.25),0,c.y+sin(a)*(apo+0.25))
  _inst_r("box",Vector3(pb.x,y0+0.55,pb.z),Vector3(side*1.02,1.1,2.6),yaw,Color("9a8a6a"))
  # Contrafuerte en cada vertice.
  var av=TAU*float(i)/8.0
  _inst_r("box",Vector3(c.x+cos(av)*r,y0+wall_h*0.52,c.y+sin(av)*r),Vector3(1.3,wall_h*1.04,2.8),-av-PI/2.0,Color("b2a37f"))
  _inst_r("box",Vector3(pw.x,y0+wall_h+0.3,pw.z),Vector3(side*1.02,0.6,3.0),yaw,[Color("86614f"),Color("7b6350"),Color("8d6c57")][i%3])
  # gradas de madera (anillo interior, mas bajo)
  var pg=Vector3(c.x+cos(a)*(apo-r*0.16),0,c.y+sin(a)*(apo-r*0.16))
  _inst_r("box",Vector3(pg.x,y0+wall_h*0.32,pg.z),Vector3(side*0.86,wall_h*0.64,r*0.22),yaw,Color("9a8160"))
 # Dependencias bajas contra el costado oeste (almacen y cuarteles): Vidal muestra el Retiro como masa baja y continua (reconstruccion de volumen).
 for k in range(3):
  var ax=c.x-r*1.25-float(k)*0.0;var az=c.y+(float(k)-1.0)*r*0.62
  _inst_r("box",Vector3(ax,_h(ax,az)+2.0,az),Vector3(r*0.55,4.0,r*0.55),0.0,Color("cfc4a8"))
  _inst_r("box",Vector3(ax,_h(ax,az)+4.25,az),Vector3(r*0.6,0.5,r*0.6),0.0,Color("77604a"))
 # Bandera blanca con escudo español pintado: INFERENCIA (cuenta de 1803, Pillado; paquete H4). Sin escudo argentino.
 # R5: antes un cuadrado rojo sobre blanco (se leia como otra bandera). Ahora paño blanco con un escudo pintado (borde latón,
 # cuarteles rojo y crudo, corona): el escudo exacto NO tiene datos, es un esquema de lectura (Diseño). Asta fina de 8 m.
 var fp=Vector3(c.x,y0+wall_h,c.y)
 _cylinder(Vector3(fp.x,fp.y+4.0,fp.z),0.12,8.0,Color("4c372b"))
 var fz=fp.z;var fy=fp.y+6.7;var fx=fp.x+1.9
 _box(Vector3(fx,fy,fz),Vector3(3.8,2.4,0.06),Color("e9e3d2"))
 _box(Vector3(fx,fy-0.1,fz+0.04),Vector3(1.05,1.2,0.05),Color("a88943"))           # borde del escudo
 _box(Vector3(fx-0.25,fy+0.15,fz+0.08),Vector3(0.45,0.45,0.05),Color("983c3c"))
 _box(Vector3(fx+0.25,fy-0.35,fz+0.08),Vector3(0.45,0.45,0.05),Color("983c3c"))
 _box(Vector3(fx+0.25,fy+0.15,fz+0.08),Vector3(0.45,0.45,0.05),Color("d8cfb8"))
 _box(Vector3(fx-0.25,fy-0.35,fz+0.08),Vector3(0.45,0.45,0.05),Color("d8cfb8"))
 _box(Vector3(fx,fy+0.75,fz+0.06),Vector3(0.7,0.22,0.05),Color("a88943"))          # corona (esquema)

func _battery_j(lm:Dictionary):
 var c=Vector2(float(lm.x),float(lm.z));var w=float(lm.get("w",22.0));var d=float(lm.get("d",14.0))
 var top=_h(c.x,c.y)
 var low=minf(_h(c.x+w*0.5,c.y),_h(c.x+w*0.5,c.y-d*0.5))
 var thick=maxf(1.0,top-low+0.6)
 _inst_t("box",Transform3D(Basis.from_scale(Vector3(w,thick,d)),Vector3(c.x,top+0.1-thick*0.5,c.y)),Color("7d6c47"))
 # Parapeto de tierra del lado del rio con DOS piezas de a 18 (unica cifra con fuente: parte de Liniers del 11-ago, citado por L. Guemes; ronda 5).
 # Emplazamiento, parapeto y gaviones son DISEÑO (no hay plano ni descripcion); solo la existencia de las dos piezas tiene respaldo, y por cita.
 var px=c.x+w*0.5-1.6
 _inst_t("box",Transform3D(Basis.from_scale(Vector3(3.2,2.0,d)),Vector3(px,top+1.0,c.y)),Color("6e5f3e"))
 for i in range(2):
  var gz=c.y-d*0.5+d*(float(i)*2.0+1.0)/4.0
  _inst_t("box",Transform3D(Basis.from_scale(Vector3(3.0,0.5,1.2)),Vector3(px-2.8,top+0.4,gz)),Color("4d3d28"))
  var tr=Transform3D(Basis(Vector3(0,0,1),PI/2.0).scaled_local(Vector3(0.55,3.4,0.55)),Vector3(px-2.3,top+1.2,gz))
  _inst_t("cyl8",tr,Color("2f2f2c"))
 for g in range(5):
  _inst_t("cyl8",Transform3D(Basis.from_scale(Vector3(0.9,1.0,0.9)),Vector3(px+0.3,top+2.5,c.y-d*0.5+d*(float(g)+0.5)/5.0)),Color("8f7f58"))
 battery_pos=Vector3(px+0.5,top+1.3,c.y)

func _alameda_j(lm:Dictionary):
 # Paquete C: no extender una avenida ribereña uniforme. Arboleda IRREGULAR: separacion y lado variables, huecos y sauces/talas sueltos (Diseño).
 var poly:Array=lm.get("polyline",[])
 if poly.size()<2:return
 var rng=RandomNumberGenerator.new();rng.seed=1806
 var acc=0.0
 for i in range(poly.size()-1):
  var a=Vector2(float(poly[i][0]),float(poly[i][1]));var b=Vector2(float(poly[i+1][0]),float(poly[i+1][1]))
  var seg=a.distance_to(b);var dir=(b-a)/maxf(seg,0.001);var nrm=Vector2(-dir.y,dir.x)
  var t=acc
  while t<seg:
   var p=a+dir*t
   if rng.randf()<0.7:
    var side=-1.0 if rng.randf()<0.5 else 1.0
    var q=p+nrm*side*rng.randf_range(4.0,12.0)+dir*rng.randf_range(-4.0,4.0)
    _tree(Vector3(q.x,_h(q.x,q.y),q.y),rng.randf_range(1.1,2.0))
   t+=rng.randf_range(14.0,38.0)
  acc=t-seg

func _camp_j(lm:Dictionary):
 var c=Vector2(float(lm.x),float(lm.z));var r=float(lm.get("radius_m",20.0))
 for i in range(9):
  var a=TAU*float(i)/9.0+0.3
  var q=c+Vector2(cos(a),sin(a))*r*(0.45+0.3*float(i%2))
  _inst_r("prism",Vector3(q.x,_h(q.x,q.y)+1.1,q.y),Vector3(3.2,2.2,4.2),a+0.4,Color("c9bc9c"))
 _inst_t("cyl12",Transform3D(Basis.from_scale(Vector3(1.2,0.25,1.2)),Vector3(c.x,_h(c.x,c.y)+0.12,c.y)),Color("3b3128"))
 # visual/r1 F4: caballos del campamento = criollos de tropa a escala 1 con pelajes mezclados (antes horse_only a 0,9: ~3,05 m).
 if _glb_ok("caballo_criollo_zaino_lod"):
  for i in range(6):
   var q=c+Vector2(-r*0.9,-r*0.8+float(i)*2.2)
   var cm="caballo_criollo_"+str(HORSE_COATS[_coat_of(int(c.x*7.0+c.y*13.0),i)])+"_lod"
   _inst_glb(cm,Transform3D(Basis.from_euler(Vector3(0,PI/2.0,0)),Vector3(q.x,_h(q.x,q.y),q.y)))

func _command_j(lm:Dictionary):
 var c=Vector2(float(lm.x),float(lm.z))
 var y=_h(c.x,c.y)
 _inst_r("prism",Vector3(c.x,y+1.9,c.y),Vector3(6.0,3.8,8.0),0.2,Color("cfc19a"))
 for sx in [-1.0,1.0]:
  _inst_t("cyl8",Transform3D(Basis.from_scale(Vector3(0.2,4.6,0.2)),Vector3(c.x+sx*3.2,y+2.3,c.y)),Color("5d4a36"))

func _obstacles_j():
 for o in M.get("obstacles",[]):
  var cx=float(o.x);var cz=float(o.z);var w=float(o.w);var d=float(o.d)
  var kind=str(o.get("kind",""))
  if kind=="vegetacion":
   var count=int(w*d*0.9)
   for i in range(count):
    var px=cx+decoration_rng.randf_range(-w*0.5,w*0.5);var pz=cz+decoration_rng.randf_range(-d*0.5,d*0.5)
    var hh=decoration_rng.randf_range(1.8,3.2)
    var lean=Vector3(decoration_rng.randf_range(-0.12,0.12),0,decoration_rng.randf_range(-0.12,0.12))
    _inst_r("cyl8",Vector3(px,_h(px,pz)+hh*0.5,pz),Vector3(0.09,hh,0.09),0.0,Color("8c8a52").lerp(Color("a3a064"),decoration_rng.randf()),lean)
  elif kind=="carretas":
   for i in range(3):
    var px=cx-w*0.33+float(i)*w*0.33;var pz=cz+(float(i%2)-0.5)*1.5
    var y=_h(px,pz)
    var yaw=0.5+float(i)*0.7
    _inst_r("box",Vector3(px,y+1.1,pz),Vector3(3.4,0.25,1.7),yaw,Color("6b5236"))
    for s in [-1.0,1.0]:
     var off=Vector3(0,0,s*1.0).rotated(Vector3.UP,yaw)
     _inst_t("cyl12",Transform3D(Basis.from_euler(Vector3(0,yaw,0))*Basis(Vector3(1,0,0),PI/2.0).scaled_local(Vector3(1.9,0.14,1.9)),Vector3(px,y+0.95,pz)+off),Color("4d3a28"))
    _inst_r("box",Vector3(px,y+0.8,pz)+Vector3(-2.6,0,0).rotated(Vector3.UP,yaw),Vector3(3.0,0.12,0.14),yaw,Color("5a432c"))
  var top=_h(cx,cz)+2.0

# ---------------------------------------------------------------- paisaje (ronda 4)
# Reconstruccion estetica: toscas al pie de la barranca, juncales en la orilla, matorral de la meseta, quintas y la ciudad al sur
# (plano de Boneo 1801: cuadras de ~117 m). Ninguna de estas piezas tiene efecto en las reglas.
var scale_root: Node3D
var ref_labels: Dictionary = {}
const SCALE_X = 197.0
const SCALE_Z0 = 312.0

## visual/r1 F5: casas del kit (CASAS_F5.md, «I · _house_at»). ctx "quinta" (meseta del Retiro), "aislada" (quintas y ranchos sueltos del
## camino de Las Conchas) o "ciudad" (cuadras al sur y ciudad alta; más teja que azotea: es la orilla de la traza, y la azotea clara
## del kit casi no se despega del suelo visto desde arriba y de lejos). A escala real (el tablero de la Justina está en metros) con ±4 %
## de variación; w y d de quien llama ya no estiran la casa (las cajas del kit miden 6–20 m). Reconstrucción estética (Vidal, S24):
## azoteas y teja en la ciudad, quintas con corredor y tapia en la meseta, ranchos de paja en las afueras. Sin GLB, las cajas de R7.
const CASAS_J = {
 "quinta":[[0.22,"casa_ba_b"],[0.36,"casa_rancho_a"],[0.46,"casa_rancho_b"],[0.80,"casa_quinta_a"],[1.01,"casa_ba_a"]],
 "aislada":[[0.18,"casa_rancho_a"],[0.30,"casa_rancho_b"],[0.70,"casa_quinta_b"],[1.01,"casa_quinta_a"]],
 "ciudad":[[0.30,"casa_ba_b"],[0.88,"casa_ba_a"],[1.01,"casa_rancho_a"]]}
var casa_size_cache:Dictionary={}
## Tamaño (x, y, z) de la caja de un modelo del kit según f5_casas_manifest.json (godot_bounds); sin manifiesto, 6 × 4 × 6 m.
func _casa_size(model:String)->Vector3:
 if casa_size_cache.is_empty():
  casa_size_cache["_"]=true
  var mf=JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/f5_casas_manifest.json")) if FileAccess.file_exists("res://assets/models/f5_casas_manifest.json") else null
  if mf is Dictionary:
   for k in mf:
    var b=(mf[k] as Dictionary).get("godot_bounds",{}) if mf[k] is Dictionary else {}
    if b is Dictionary and b.has("min") and b.has("max"):
     casa_size_cache[k]=Vector3(float(b.max[0])-float(b.min[0]),float(b.max[1])-float(b.min[1]),float(b.max[2])-float(b.min[2]))
 return casa_size_cache.get(model,Vector3(6.0,4.0,6.0))

func _house_at(x:float,z:float,w:float,d:float,yaw:float,ctx:String="ciudad"):
 var hv=fposmod(sin(x*7.31+z*3.17)*9631.7,1.0)
 var model=""
 for e in CASAS_J.get(ctx,CASAS_J.ciudad):
  if hv<float(e[0]):model=str(e[1]);break
 var s=0.96+0.08*fposmod(sin(x*2.1+z*5.3)*777.7,1.0)
 var sz=_casa_size(model)*s
 # Lejos del tablero (más de 150 m afuera): solo la versión liviana y sin sombra.
 var out=maxf(maxf(-x,x-map_w),maxf(-z,z-map_h))
 var y=_casa_base_j(x,z,yaw,sz.x*0.5,sz.z*0.5)
 if _casa(model,Transform3D(Basis.from_euler(Vector3(0,yaw,0)).scaled_local(Vector3.ONE*s),Vector3(x,y,z)),out>150.0):return
 # Respaldo sin GLB (R7): casa de azotea, caja con parapeto. Reconstrucción.
 var hh=3.2+1.8*fposmod(sin(x*2.1+z*5.3)*777.7,1.0)
 var base=_far_h(x,z)
 var wall=Color("d8cfb8").lerp(Color("c2ae88"),fposmod(sin(x*4.3+z*1.9)*555.5,1.0)).darkened(0.12)
 _inst_r("box",Vector3(x,base+hh*0.5,z),Vector3(w,hh,d),yaw,wall)
 _inst_r("box",Vector3(x,base+hh+0.28,z),Vector3(w*1.02,0.56,d*1.02),yaw,wall.lightened(0.04))

func _scenery_j():
 var rng=RandomNumberGenerator.new();rng.seed=4606
 var barr=M.get("barranca",{})
 var toe:Array=barr.get("toe",[]);var crest:Array=barr.get("crest",[])
 var shore:Array=M.get("shore_high",{}).get("polyline",[])
 var road_poly:Array=[]
 for lm in M.get("landmarks",[]):
  if str(lm.get("type",""))=="road":road_poly=lm.get("polyline",[])
 # --- toscas (afloramientos) al pie de la barranca y sueltas en la playa alta
 if _glb_ok("rock_cluster"):
  var z=6.0
  while z<map_h:
   if rng.randf()<0.6:
    var rx=_poly_x(toe,z)+rng.randf_range(-7.0,10.0)
    var s=rng.randf_range(0.7,1.9)
    var b=Basis.from_euler(Vector3(0,rng.randf()*TAU,0)).scaled_local(Vector3(s,s*rng.randf_range(0.6,1.0),s))
    _inst_glb("rock_cluster",Transform3D(b,Vector3(rx,_h(rx,z)-0.25*s,z)))
   z+=rng.randf_range(6.0,15.0)
  for i in range(26):
   var z2=rng.randf_range(4.0,map_h-4.0)
   var rx2=_poly_x(shore,z2)+rng.randf_range(-12.0,3.0)
   var s2=rng.randf_range(0.5,1.2)
   var b2=Basis.from_euler(Vector3(0,rng.randf()*TAU,0)).scaled_local(Vector3.ONE*s2)
   _inst_glb("rock_cluster",Transform3D(b2,Vector3(rx2,_h(rx2,z2)-0.15,z2)))
 # --- juncales en la linea de agua alta (parches con ruido; tallos pajizos de invierno)
 var zj=0.0
 while zj<map_h:
  if terrain_noise.get_noise_2d(zj*0.03,7.0)>-0.12:
   var sx=_poly_x(shore,zj)+rng.randf_range(-3.0,7.0)
   for cI in range(rng.randi_range(1,3)):
    var cx=sx+rng.randf_range(-3.0,3.0);var cz=zj+rng.randf_range(-2.5,2.5)
    var hh=_h(cx,cz)
    if hh<1.2 or hh>2.9:continue
    for st in range(7):
     var sh=rng.randf_range(1.3,2.5)
     var ox=cx+rng.randf_range(-0.55,0.55);var oz=cz+rng.randf_range(-0.55,0.55)
     var lean=Vector3(rng.randf_range(-0.3,0.3),0,rng.randf_range(-0.3,0.3))
     var col=Color("8a8a4c").lerp(Color("b4a867"),rng.randf())
     _inst_r("cyl8",Vector3(ox,_h(ox,oz)+sh*0.5-0.05,oz),Vector3(0.07,sh,0.07),0.0,col,lean)
  zj+=rng.randf_range(3.0,6.0)
 # --- matorral dentro del mapa (meseta y playa alta), densidad con ruido
 var placed=0;var tries=0
 while placed<520 and tries<6000:
  tries+=1
  var x=rng.randf_range(2.0,262.0);var z3=rng.randf_range(2.0,map_h-2.0)
  var cxx=_poly_x(crest,z3);var txx=_poly_x(toe,z3)
  var ok=x<cxx-4.0 or (x>txx+6.0 and _h(x,z3)>level_high_m+0.7)
  if not ok:continue
  if absf(x-_poly_x(road_poly,z3))<5.0:continue
  if terrain_noise.get_noise_2d(x*0.045,z3*0.045+9.0)<-0.02:continue
  # Matas (ronda 3): no esferas verdes iguales; tamaños muy variados, achatadas o altas, tonos de pasto seco y matorral pardo (paleta de Vidal).
  # R6: matas de formas y tonos distintos (antes "huevos" oscuros iguales): mata baja, mata angulosa y mechones de paja; tonos del suelo del paquete
  # (vegetacion_baja #7C8159, arena_tierra #A38D6B, suelo_alto #C9BE98). Reconstruccion estetica; Vidal muestra campo pardo-dorado con poco arbolado.
  var kind=rng.randf()
  var tone=Color("6b6a3c").lerp(Color("a38d6b"),rng.randf()).lerp(Color("7c8159"),rng.randf()*0.5).lerp(Color("c9be98"),rng.randf()*0.25)
  if kind<0.5:
   var w=rng.randf_range(0.7,2.6)*(1.0+0.5*float(rng.randf()<0.1));var hgt=w*rng.randf_range(0.30,0.8)
   _inst_r("sphere",Vector3(x,_h(x,z3)+hgt*0.28,z3),Vector3(w,hgt,w*rng.randf_range(0.6,1.3)),rng.randf()*TAU,tone.darkened(0.12))
  elif kind<0.72:
   var w2=rng.randf_range(0.8,2.0);var h2=rng.randf_range(0.7,1.6)
   _inst_r("prism",Vector3(x,_h(x,z3)+h2*0.45,z3),Vector3(w2,h2,w2*rng.randf_range(0.7,1.2)),rng.randf()*TAU,tone.darkened(0.2),Vector3(rng.randf_range(-0.12,0.12),0,rng.randf_range(-0.12,0.12)))
  else:
   for st in range(6):
    var ox=x+rng.randf_range(-0.5,0.5);var oz=z3+rng.randf_range(-0.5,0.5);var sh2=rng.randf_range(0.5,1.25)
    _inst_r("cyl8",Vector3(ox,_h(ox,oz)+sh2*0.5-0.03,oz),Vector3(0.05,sh2,0.05),0.0,Color("a8996a").lerp(Color("c9be98"),rng.randf()),Vector3(rng.randf_range(-0.35,0.35),0,rng.randf_range(-0.35,0.35)))
  placed+=1
 # --- matorral de transicion alrededor del mapa (R4): el detalle del pasto sigue mas alla del tablero, sin corte
 placed=0;tries=0
 while placed<420 and tries<5000:
  tries+=1
  var xt=rng.randf_range(-260.0,262.0);var zt=rng.randf_range(-260.0,map_h+260.0)
  if zt>=0.0 and zt<=map_h and xt>=2.0:continue
  var ht=_far_h(xt,zt)
  if ht<3.0:continue
  if terrain_noise.get_noise_2d(xt*0.045,zt*0.045+9.0)<-0.02:continue
  var wt=rng.randf_range(0.9,3.0);var hgt2=wt*rng.randf_range(0.30,0.8)
  _inst_r("sphere",Vector3(xt,ht+hgt2*0.28,zt),Vector3(wt,hgt2,wt*rng.randf_range(0.6,1.3)),rng.randf()*TAU,Color("4d4a2a").lerp(Color("8a7a48"),rng.randf()).lerp(Color("5a5e32"),rng.randf()*0.4))
  placed+=1
 # --- campo lejano: matorral, algarrobos/talas, quintas al norte y la ciudad al sur
 var far_shr=0;tries=0
 while far_shr<700 and tries<9000:
  tries+=1
  var x4=rng.randf_range(-700.0,120.0);var z4=rng.randf_range(-700.0,1500.0)
  if x4>0.0 and z4>=0.0 and z4<=map_h:continue
  var h4=_far_h(x4,z4)
  if h4<4.0:continue
  if terrain_noise.get_noise_2d(x4*0.012,z4*0.012+3.0)<-0.05:continue
  var w4=rng.randf_range(1.6,4.2)
  _inst_r("sphere",Vector3(x4,h4+w4*0.2,z4),Vector3(w4*rng.randf_range(0.7,1.4),w4*rng.randf_range(0.35,0.7),w4),rng.randf()*TAU,Color("4d4a2a").lerp(Color("8a7a48"),rng.randf()))
  far_shr+=1
 if _glb_ok("tree_algarrobo"):
  var ft=0;tries=0
  while ft<90 and tries<4000:
   tries+=1
   var x5=rng.randf_range(-650.0,100.0);var z5=rng.randf_range(-650.0,1400.0)
   if x5>0.0 and z5>=0.0 and z5<=map_h:continue
   var h5=_far_h(x5,z5)
   if h5<4.0:continue
   var s5=rng.randf_range(1.7,3.2)
   _inst_glb("tree_algarrobo",Transform3D(Basis.from_euler(Vector3(0,rng.randf()*TAU,0)).scaled_local(Vector3.ONE*s5),Vector3(x5,h5-0.1,z5)))
   ft+=1
 # quintas y ranchos al norte (camino de Las Conchas) y alrededor del Retiro
 for i in range(14):
  var qx=rng.randf_range(-260.0,90.0);var qz=rng.randf_range(-520.0,-30.0)
  if _far_h(qx,qz)<4.0:continue
  _house_at(qx,qz,rng.randf_range(6.5,10.0),rng.randf_range(6.5,9.0),rng.randf()*TAU,"aislada")
 # ciudad al sur: cuadras de ~117 m (Boneo 1801), casas bajas de azotea; dos torres de iglesia
 var churches=0
 var bz=660.0
 while bz<1500.0:
  var bx=-420.0
  while bx<130.0:
   var shift=90.0*sin((bz+60.0)*0.0021+0.8)*smoothstep(0.0,500.0,bz-map_h)
   var cxe=_poly_x(crest,map_h)+shift
   if bx+60.0<cxe-30.0 and _far_h(bx,bz)>4.5:
    for k in range(7):
     var side=k%4;var t=rng.randf_range(-0.45,0.45)
     var hx=bx+(t*117.0 if side%2==0 else (-0.42 if side==1 else 0.42)*117.0)
     var hz=bz+((-0.42 if side==0 else 0.42)*117.0 if side%2==0 else t*117.0)
     # visual/r1 F5: el frente (−Z del kit) mira a la calle de su lado de la cuadra (lados 2 y 3: media vuelta).
     _house_at(hx,hz,rng.randf_range(8.0,12.0),rng.randf_range(9.0,13.0),(0.0 if side%2==0 else PI*0.5)+rng.randf_range(-0.04,0.04)+(PI if side>=2 else 0.0),"ciudad")
    if churches<4 and rng.randf()<0.16 and _glb_ok("casa_capilla_c"):
     churches+=1
     # visual/r1 F5: iglesia con torre y cupulín del kit (casa_capilla_c, 12 m) a escala 1, en lugar de church_colonial.
     _casa("casa_capilla_c",Transform3D(Basis.IDENTITY,Vector3(bx,_casa_base_j(bx,bz,0.0,5.4,8.3),bz)),true)
   bx+=117.0
  bz+=117.0

 # R5: ciudad alta tras la meseta (silueta de Vidal 1820: casas bajas de azotea con torres sobre campo ocre). Reconstruccion estetica:
 # solo se toma de Boneo 1801 el tamaño de cuadra y que la traza urbana sube hacia el oeste y el sur del Retiro; lotes y torres son Diseño.
 var rng2=RandomNumberGenerator.new();rng2.seed=1820
 var towers=0
 for ring_i in range(3):
  var x0=-110.0-float(ring_i)*190.0
  var bz2=-60.0
  while bz2<700.0:
   var dens=clampf(0.25+bz2/900.0,0.25,0.9)-float(ring_i)*0.12
   if rng2.randf()<dens:
    for k in range(5):
     var hx=x0+rng2.randf_range(-58.0,58.0);var hz=bz2+rng2.randf_range(-58.0,58.0)
     if _far_h(hx,hz)>3.0:_house_at(hx,hz,rng2.randf_range(8.0,12.0),rng2.randf_range(9.0,13.0),(0.0 if rng2.randf()<0.5 else PI*0.5))
    if towers<7 and ring_i<2 and rng2.randf()<0.10 and _glb_ok("casa_capilla_c"):
     towers+=1
     _casa("casa_capilla_c",Transform3D(Basis.from_euler(Vector3(0,PI*0.5,0)),Vector3(x0,_casa_base_j(x0,bz2,PI*0.5,5.4,8.3),bz2)),x0<-150.0)
   bz2+=117.0

# ---------------------------------------------------------------- barranca y caserío (P1, ronda 2)
# Lectura del lugar a distancia de juego: talas y ombúes en el borde de la barranca (sombras largas de la tarde sobre el talud),
# matas y cortaderas en la pared, y quintas con tapia y frutales sobre la meseta del Retiro. Reconstrucción estética (Vidal 1820
# muestra la barranca con pasto y árboles sueltos y caserío bajo); nada de esto toca reglas ni caminos de juego.
## true si (x,z) cae sobre un hito, una bajada, un obstáculo o el arranque de un grupo (margen m): ahí no se planta nada.
func _reserved_j(x:float,z:float,m:float,skip_road:bool=false)->bool:
 var p=Vector2(x,z)
 for lm in M.get("landmarks",[]):
  var c=_lm_pos(lm)
  match str(lm.get("type","")):
   "battery":
    if absf(x-c.x)<float(lm.get("w",22.0))*0.5+m+3.0 and absf(z-c.y)<float(lm.get("d",14.0))*0.5+m+3.0:return true
   "bullring":
    var r=float(lm.get("radius_m",24.0))*0.5
    if p.distance_to(c)<r*1.3+m or (x>c.x-r*1.7-m and x<c.x and absf(z-c.y)<r*1.3+m):return true
   "camp":
    if p.distance_to(c)<float(lm.get("radius_m",20.0))*1.2+m:return true
   "command":
    if p.distance_to(c)<9.0+m:return true
   "road":
    if skip_road:continue
    var poly:Array=lm.get("polyline",[])
    for i in range(poly.size()-1):
     if Geometry2D.get_closest_point_to_segment(p,_pt(poly[i]),_pt(poly[i+1])).distance_to(p)<9.0+m:return true
 for r2 in M.get("barranca",{}).get("ramps",[]):
  var vp:Array=r2.get("visual_path",{}).get("polyline",[])
  for i in range(vp.size()-1):
   if Geometry2D.get_closest_point_to_segment(p,_pt(vp[i]),_pt(vp[i+1])).distance_to(p)<6.0+m:return true
 for o in M.get("obstacles",[]):
  if absf(x-float(o.x))<float(o.w)*0.5+m and absf(z-float(o.z))<float(o.d)*0.5+m:return true
 for g in M.get("groups",[]):
  if p.distance_to(Vector2(float(g.x),float(g.z)))<14.0+m:return true
 return false

func _barranca_j():
 var rng=RandomNumberGenerator.new();rng.seed=18061208
 var barr=M.get("barranca",{})
 var crest:Array=barr.get("crest",[]);var toe:Array=barr.get("toe",[])
 if crest.is_empty() or toe.is_empty():return
 var glb_tree=_glb_ok("tree_algarrobo")
 # Talas y ombúes en el borde: grupos de 1 a 3, separados 8-18 m, apenas detrás del filo (su sombra cae por el talud hacia el río).
 var z=3.0
 while z<map_h-3.0:
  if rng.randf()<0.66:
   for k in range(rng.randi_range(1,3)):
    var zz=z+rng.randf_range(-4.0,4.0)
    var x=_poly_x(crest,zz)-rng.randf_range(1.0,11.0)
    if _reserved_j(x,zz,2.0,true):continue
    var s=rng.randf_range(1.25,2.3)
    if glb_tree:_inst_glb("tree_algarrobo",Transform3D(Basis.from_euler(Vector3(0,rng.randf()*TAU,0)).scaled_local(Vector3.ONE*s),Vector3(x,_h(x,zz)-0.15,zz)))
    else:_tree(Vector3(x,_h(x,zz),zz),s)
  z+=rng.randf_range(8.0,18.0)
 # Pared de la barranca: matas oscuras, cortaderas pajizas y algún arbusto; densidad con ruido (manchones, no alfombra).
 var z2=1.5
 while z2<map_h-1.5:
  var cx=_poly_x(crest,z2);var tx=_poly_x(toe,z2)
  for k in range(3):
   var t=rng.randf_range(0.1,0.95)
   var zz=z2+rng.randf_range(-1.6,1.6)
   var x=lerpf(cx,tx,t)+rng.randf_range(-1.0,1.0)
   if terrain_noise.get_noise_2d(x*0.05,zz*0.05+21.0)<-0.12:continue
   if _reserved_j(x,zz,0.0,true):continue
   var y=_h(x,zz)
   var kind=rng.randf()
   if kind<0.55:
    var w=rng.randf_range(1.6,4.0);var hh=w*rng.randf_range(0.35,0.6)
    var tone=Color("5c6236").lerp(Color("858049"),rng.randf()).lerp(Color("6a5a3c"),rng.randf()*0.3)
    _inst_r("sphere",Vector3(x,y+hh*0.25,zz),Vector3(w,hh,w*rng.randf_range(0.6,1.2)),rng.randf()*TAU,tone)
   elif kind<0.85:
    for st in range(8):
     var sh=rng.randf_range(1.1,2.2)
     var ox=x+rng.randf_range(-0.45,0.45);var oz=zz+rng.randf_range(-0.45,0.45)
     _inst_r("cyl8",Vector3(ox,_h(ox,oz)+sh*0.5-0.05,oz),Vector3(0.06,sh,0.06),0.0,Color("a8975f").lerp(Color("cbbd8a"),rng.randf()),Vector3(rng.randf_range(-0.45,0.45),0,rng.randf_range(-0.45,0.45)))
   elif glb_tree:
    var s2=rng.randf_range(0.55,0.95)
    _inst_glb("tree_algarrobo",Transform3D(Basis.from_euler(Vector3(0,rng.randf()*TAU,0)).scaled_local(Vector3.ONE*s2),Vector3(x,y-0.1,zz)))
  z2+=rng.randf_range(2.4,4.2)

## Quintas del Retiro sobre la meseta, al oeste de los hitos: casas bajas (azotea, rancho o teja), tapia y frutales. Dan escala humana.
func _meseta_town_j():
 var rng=RandomNumberGenerator.new();rng.seed=18060812
 var glb_tree=_glb_ok("tree_algarrobo")
 var zq=96.0
 while zq<map_h-30.0:
  var xq=rng.randf_range(22.0,62.0)
  if not _reserved_j(xq,zq,22.0):
   # 2-4 casas alineadas a la calle (frente al este), patio con tapia baja y 3-6 frutales detrás.
   # visual/r1 F5: casas del kit (_house_at "quinta") a 12 m entre centros (antes 9,5: la quinta con corredor mide 11,4 m de frente);
   # el frente −Z del kit gira −90° para mirar al este, a la calle. Tapia del patio con módulos de tapia encalada (casa_tapia_cal_b).
   var nh=rng.randi_range(2,4)
   for k in range(nh):
    var hz=zq-12.0+float(k)*12.0
    _house_at(xq+rng.randf_range(-1.0,1.0),hz,rng.randf_range(6.5,9.0),rng.randf_range(7.0,8.5),-PI*0.5+rng.randf_range(-0.05,0.05),"quinta")
   var px0=xq-26.0;var px1=xq-6.0;var pz0=zq-18.0;var pz1=zq-18.0+float(nh)*12.0+2.0
   var tapia_glb=_glb_ok("casa_tapia_cal_b")
   for seg in [[px0,pz0,px1,pz0],[px0,pz1,px1,pz1],[px0,pz0,px0,pz1]]:
    var a=Vector2(seg[0],seg[1]);var b=Vector2(seg[2],seg[3])
    var n=maxi(1,int(ceil(a.distance_to(b)/4.0)))
    for i in range(n):
     var m0=a.lerp(b,(float(i)+0.5)/float(n));var ln=a.distance_to(b)/float(n)
     var horiz=absf(b.x-a.x)>absf(b.y-a.y)
     var tc=Color("c8bb9c").darkened(rng.randf()*0.12)
     if tapia_glb:
      # Módulo de 4,04 m estirado al tramo y a 1,7 m de alto (la «tapia baja» de antes medía 1,6 m); de pie en el punto más bajo del tramo.
      var ty=minf(_h(m0.x,m0.y),minf(_h(m0.x-(ln*0.5 if horiz else 0.0),m0.y-(0.0 if horiz else ln*0.5)),_h(m0.x+(ln*0.5 if horiz else 0.0),m0.y+(0.0 if horiz else ln*0.5))))-0.08
      _casa("casa_tapia_cal_b",Transform3D(Basis.from_euler(Vector3(0,0.0 if horiz else PI*0.5,0)).scaled_local(Vector3((ln+0.05)/4.04,0.72,1.0)),Vector3(m0.x,ty,m0.y)))
     else:
      _inst_r("box",Vector3(m0.x,_h(m0.x,m0.y)+0.75,m0.y),Vector3(ln+0.05 if horiz else 0.45,1.6,0.45 if horiz else ln+0.05),0.0,tc)
   if glb_tree:
    for i in range(rng.randi_range(3,6)):
     var fx=rng.randf_range(px0+3.0,px1-3.0);var fz=rng.randf_range(pz0+3.0,pz1-3.0)
     _inst_glb("tree_algarrobo",Transform3D(Basis.from_euler(Vector3(0,rng.randf()*TAU,0)).scaled_local(Vector3.ONE*rng.randf_range(0.8,1.25)),Vector3(fx,_h(fx,fz)-0.1,fz)))
  zq+=rng.randf_range(52.0,78.0)

## visual/r1 F5: ranchos del bajo del Retiro, al pie de la barranca (CASAS_F5.md, «Ribera»: ranchos de paja y alguna casa de teja;
## ninguna iglesia). Vidal (S24) muestra ranchos de paja en las afueras; que hubiera ranchos de pescadores o lavanderas en el bajo es
## inferencia: Reconstrucción estética. Con el fondo contra el pie (lo de atrás se entierra en el talud y el frente sale 2–4 m a la playa,
## donde menos se camina), con el frente al río, sobre la marea alta y lejos de
## hitos, bajadas, grupos, carretas y la regla de escala. No cambian reglas, caminos ni lo que se puede pisar.
func _ribera_j():
 var toe:Array=M.get("barranca",{}).get("toe",[])
 if toe.is_empty():return
 var rng=RandomNumberGenerator.new();rng.seed=18060731
 var z=12.0;var placed=0
 while z<map_h-12.0 and placed<9:
  var model="casa_ba_a" if placed%4==3 else ("casa_rancho_b" if rng.randf()<0.4 else "casa_rancho_a")
  var sz=_casa_size(model)
  var x=_poly_x(toe,z)+sz.z*0.5-rng.randf_range(1.2,2.0)
  var yaw=-PI*0.5+rng.randf_range(-0.12,0.12)   # frente (−Z del kit) hacia el río (+X)
  var ok=not _reserved_j(x,z,sz.x*0.5+4.0) and absf(z-(SCALE_Z0+50.0))>62.0 and _h(x,z)>level_high_m+0.3
  # visual/r1 F6: los ranchos no son obstáculo en las reglas; para que la tropa no se vea atravesándolos, tampoco van a menos de 8 m
  # (más media casa) de los trazos de ruta del mapa (routes.items) ni en la playa de la reunión y la marcha al pie de la barranca
  # (z 175–330: los grupos arrancan en z 240–296 y caminan pegados al pie hasta la ruta central, z≈190). El de z≈188 quedaba a 2 m de la
  # ruta central y la reserva pasaba a 4,9 m de su borde; corrido solo por la ruta, cayó en z≈206, en plena marcha (f6_ribera_paths.gd,
  # 21 partidas por reglas y 3 por la interfaz).
  if z>175.0 and z<330.0:ok=false
  if ok:
   for it in M.get("routes",{}).get("items",[]):
    var pl:Array=it.get("polyline",[])
    for i in range(pl.size()-1):
     if Geometry2D.get_closest_point_to_segment(Vector2(x,z),_pt(pl[i]),_pt(pl[i+1])).distance_to(Vector2(x,z))<8.0+maxf(sz.x,sz.z)*0.5:ok=false
  # Los ranchos van 18 % más oscuros (adobe y paja ahumados): contra la arena clara de la playa alta el adobe del kit quedaba a ΔL* ≈ −10
  # (V06 pide 12); la casa de teja no lo necesita (cal clara y teja oscura).
  if ok and _casa(model,Transform3D(Basis.from_euler(Vector3(0,yaw,0)),Vector3(x,_casa_base_j(x,z,yaw,sz.x*0.5,sz.z*0.5),z)),false,1.0 if model=="casa_ba_a" else 0.82):
   placed+=1;z+=rng.randf_range(18.0,32.0)
  else:z+=6.0

# ---------------------------------------------------------------- escala y referencias
func _scale_bar_j():
 scale_root=Node3D.new();scale_root.name="Escala100m";add_child(scale_root)
 for i in range(10):
  var col=Color("efe6cc") if i%2==0 else Color("8c3f2e")
  for k in range(5):
   var zz=SCALE_Z0+float(i)*10.0+1.0+float(k)*2.0
   _inst_t("box",Transform3D(Basis.from_scale(Vector3(1.1,0.22,2.02)),Vector3(SCALE_X,_h(SCALE_X,zz)+0.14,zz)),col)
 for m in [0.0,50.0,100.0]:
  var zp=SCALE_Z0+m
  var y=_h(SCALE_X,zp)
  _inst_t("cyl8",Transform3D(Basis.from_scale(Vector3(0.22,3.4,0.22)),Vector3(SCALE_X,y+1.7,zp)),Color("5a3a2a"))
  _inst_t("box",Transform3D(Basis.from_scale(Vector3(0.9,0.9,0.08)),Vector3(SCALE_X,y+3.6,zp)),Color("efe6cc"))
 var lab=_label_j("100 m",Vector3(SCALE_X,_h(SCALE_X,SCALE_Z0+100.0)+4.6,SCALE_Z0+100.0),Color("f6ecd0"),22,scale_root)
 lab.name="Rotulo_escala";lab.visibility_range_end=260.0;lab.outline_size=18;lab.outline_modulate=Color(0.08,0.07,0.05,0.95)
 # Referencias de lectura: se reubican con el nivel del rio.
 ref_labels["agua"]=_label_j("Línea de agua",Vector3(210,level_m+1.0,100),Color("cfe3dc"),24,scale_root)
 var tx=_poly_x(M.get("barranca",{}).get("toe",[]),60.0)+3.0
 ref_labels["pie"]=_label_j("Pie de la barranca",Vector3(tx,_h(tx,60.0)+2.4,60.0),Color("e6d3a6"),22,scale_root)
 _inst_t("cyl8",Transform3D(Basis.from_scale(Vector3(0.12,2.2,0.12)),Vector3(tx,_h(tx,60.0)+1.1,60.0)),Color("5a3a2a"))
 for k in ref_labels:ref_labels[k].visibility_range_end=800.0
 _update_refs_j()

func _shore_x(z:float)->float:
 var x=150.0
 while x<map_w:
  if _h(x,z)<level_m:return x
  x+=1.0
 return map_w

func _update_refs_j():
 if not ref_labels.has("agua"):return
 var sx=_shore_x(100.0)
 ref_labels["agua"].position=Vector3(sx+6.0,level_m+1.4,100.0)

# ---------------------------------------------------------------- buque
func _ship_j():
 var s=M.get("ship",{})
 var sx=float(s.get("x",580.0));var sz=float(s.get("z",262.0));var heading=float(s.get("heading_deg",0.0))
 var bed=float(M.get("hull",{}).get("bed_m",-1.5))
 ship=_model("justine",Vector3(sx,bed+SHIP_KEEL*SHIP_SY-0.05,sz))
 ship.scale=Vector3(SHIP_SX,SHIP_SY,SHIP_SZ)
 ship.rotation=Vector3(0.012,-deg_to_rad(heading),0.045)
 ship_hull=ship;ship_y0=ship.position.y
 _strip_ladder(ship)
 # Ficha del objetivo: el buque se ve desde cualquier altura (tamaño fijo en pantalla, aro que late). Hija del mundo, no del casco escalado.
 var ship_tok=_token_j(self,4,Color("e6b04a"),18.0,260.0,620.0,10.0,true);ship_tok.name="Ficha_buque"   # visual/r1 F1: 18 px (antes 56)
 ship_tok.position=Vector3(sx,10.0,sz)
 # Anillo de fango y arena humeda alrededor del casco apoyado (Diseño: grounded_visual.mud_ring_radius_m).
 var mr:Array=M.get("ship",{}).get("grounded_visual",{}).get("mud_ring_radius_m",[22.0,34.0])
 var pm=PlaneMesh.new();pm.size=Vector2(float(mr[1])*2.2,float(mr[1])*2.2*1.3);pm.subdivide_width=1;pm.subdivide_depth=1
 var mm=ShaderMaterial.new();mm.shader=load("res://shaders/justina_mud.gdshader");mm.set_shader_parameter("half_size",Vector2(float(mr[1])*1.1,float(mr[1])*1.43))
 ship_mud=MeshInstance3D.new();ship_mud.mesh=pm;ship_mud.material_override=mm;ship_mud.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 ship_mud.position=Vector3(sx,level_m+0.04,sz);ship_mud.rotation.y=-deg_to_rad(heading);ship_mud.visible=false
 add_child(ship_mud)
 # Cañones: 13 portas por banda es DISEÑO (Gillespie da 26 cañones en total, no el reparto; el paquete pide no dibujar 13 idénticos). Posiciones locales de las portas de babor (oeste con proa al norte).
 ship_gun_pos.clear()
 for i in range(13):
  var gz=-(-5.55+float(i)*0.925)
  ship_gun_pos.append(Vector3(-3.3*SHIP_SX,2.4*SHIP_SY,gz*SHIP_SZ))
 _pennants_j()

# P1 ronda 2: gallardetes largos en el tope de cada palo (rojo realista: el buque es del bando enemigo). Ondean con el viento del
# sudeste. El tope sale de la malla del GLB (vértice más alto de cada palo); si no se encuentra, no se dibuja nada. Aspecto, no dato.
var pennants:Array=[]
func _pennants_j()->void:
 if not is_instance_valid(ship):return
 var tops:Dictionary={}
 for mi in ship.find_children("*","MeshInstance3D",true,false):
  if mi.mesh==null:continue
  var xf:Transform3D=Transform3D.IDENTITY
  var cur:Node=mi
  while cur!=null and cur!=ship:
   if cur is Node3D:xf=(cur as Node3D).transform*xf
   cur=cur.get_parent()
  for si in range(mi.mesh.get_surface_count()):
   var v=mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
   if not (v is PackedVector3Array):continue
   for q in v:
    var w:Vector3=xf*q
    var key="proa" if w.z<-2.0 else "popa"
    if not tops.has(key) or w.y>(tops[key] as Vector3).y:tops[key]=w
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 # Cinta larga y angosta (5 m x 0,36 m en escala del modelo), quebrada en 10 tramos para que ondee.
 for i in range(10):
  var u0=float(i)/10.0;var u1=float(i+1)/10.0
  var h0=0.18*(1.0-u0*0.8);var h1=0.18*(1.0-u1*0.8)
  for q in [Vector3(u0*5.0,h0,0),Vector3(u1*5.0,h1,0),Vector3(u0*5.0,-h0,0),Vector3(u1*5.0,h1,0),Vector3(u1*5.0,-h1,0),Vector3(u0*5.0,-h0,0)]:
   st.set_uv(Vector2(q.x/5.0,0.0));st.add_vertex(q)
 st.generate_normals()
 var mesh=st.commit()
 var mat=ShaderMaterial.new();mat.shader=_pennant_shader()
 mat.set_shader_parameter("tint",Looks.ROJO_REALISTA)
 for key in tops:
  var mi2=MeshInstance3D.new();mi2.name="Gallardete_"+key;mi2.mesh=mesh;mi2.material_override=mat
  mi2.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
  add_child(mi2)
  pennants.append({"node":mi2,"local":(tops[key] as Vector3)+Vector3(0,0.15,0)})
 _update_pennants_j()

var pennant_shader:Shader=null
func _pennant_shader()->Shader:
 if pennant_shader==null:
  pennant_shader=Shader.new()
  pennant_shader.code="""shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint : source_color = vec4(0.72, 0.26, 0.23, 1.0);
void vertex(){
	float u = UV.x;
	VERTEX.z += sin(TIME * 3.4 - u * 7.0) * 0.45 * u;
	VERTEX.y += sin(TIME * 2.1 - u * 4.0) * 0.18 * u - 0.35 * u * u;
}
void fragment(){ ALBEDO = tint.rgb; ROUGHNESS = 0.9; }"""
 return pennant_shader

func _update_pennants_j()->void:
 if pennants.is_empty() or not is_instance_valid(ship):return
 var wind=Vector2(-0.62,-0.78)   # hacia donde vuela el paño (viento del sudeste)
 var yaw=atan2(-wind.y,wind.x)
 var k=ship.scale.y/SHIP_SY
 for p in pennants:
  var n:Node3D=p.node
  n.position=ship.transform*(p.local as Vector3)   # buque y gallardetes son hijos directos del mundo
  n.rotation=Vector3(0,yaw,0)
  n.scale=Vector3.ONE*k*SHIP_SY*0.5


# Ronda 3: el GLB trae una escalera rigida colgada del costado de babor (modelo sin regenerar: no hay Blender en esta PC).
# Se quitan en carga los triangulos de la superficie "wood" que caen en la caja de la escalera (coordenadas del GLB). Aspecto, no reglas.
func _strip_ladder(root:Node3D)->void:
 for mi in root.find_children("*","MeshInstance3D",true,false):
  var m:Mesh=mi.mesh
  if m==null:continue
  var out=ArrayMesh.new()
  for si in range(m.get_surface_count()):
   var a=m.surface_get_arrays(si)
   var mat=m.surface_get_material(si)
   if mat!=null and str(mat.resource_name)=="PBR | wood" and a[Mesh.ARRAY_INDEX]!=null:
    var v:PackedVector3Array=a[Mesh.ARRAY_VERTEX];var ix:PackedInt32Array=a[Mesh.ARRAY_INDEX]
    var keep=PackedInt32Array()
    for t in range(ix.size()/3):
     var inside=true
     for k in range(3):
      var p=v[ix[t*3+k]]
      # escalera de babor (ronda 3) o pala del timon: en escala de juego se leia como una placa suelta saliente de la popa (R6)
      var in_ladder=p.x>-3.02 and p.x<-2.4 and p.z>2.2 and p.z<2.95 and p.y>-0.05 and p.y<3.8
      var in_rudder=absf(p.x)<0.25 and p.z>6.85 and p.z<7.4 and p.y>0.3 and p.y<4.1
      if not (in_ladder or in_rudder):inside=false
     if not inside:keep.append_array(PackedInt32Array([ix[t*3],ix[t*3+1],ix[t*3+2]]))
    a[Mesh.ARRAY_INDEX]=keep
   elif mat!=null and str(mat.resource_name)=="PBR | sail":
    # R7: velas recogidas (Gillespie: el buque fue «aligerado» y estaba varado; no navegaba): se comprimen hacia la verga. Aspecto, no dato.
    var v2:PackedVector3Array=a[Mesh.ARRAY_VERTEX]
    for vi in range(v2.size()):
     var q=v2[vi];var ytop=8.45 if q.z<-2.0 else 9.85
     v2[vi]=Vector3(q.x,ytop-(ytop-q.y)*0.34,q.z)
    a[Mesh.ARRAY_VERTEX]=v2
   out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
   # R5: sin brillo metalico quemado en madera, lona y casco (el GLB trae metallic=1 con mapa): se ve de madera mate, no de maqueta cromada.
   if mat is StandardMaterial3D and not str(mat.resource_name).ends_with("metal") and not str(mat.resource_name).ends_with("anchor"):
    var m2:StandardMaterial3D=mat.duplicate()
    m2.metallic=0.0;m2.metallic_texture=null;m2.roughness=0.88;m2.roughness_texture=null;m2.metallic_specular=0.12
    mat=m2
   out.surface_set_material(out.get_surface_count()-1,mat)
  mi.mesh=out

# ---------------------------------------------------------------- efectos
func _effects_j():
 fire_flash=OmniLight3D.new()
 fire_flash.light_color=Color("ffb85c");fire_flash.omni_range=70.0;fire_flash.light_energy=0.0;fire_flash.shadow_enabled=false
 add_child(fire_flash)
 var smoke_mat=StandardMaterial3D.new()
 smoke_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 smoke_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 smoke_mat.vertex_color_use_as_albedo=true
 smoke_mat.albedo_color=Color(0.86,0.85,0.8,0.55)
 var smoke_mesh=SphereMesh.new();smoke_mesh.radius=1.3;smoke_mesh.height=2.6;smoke_mesh.radial_segments=8;smoke_mesh.rings=4
 var ramp=Gradient.new();ramp.set_color(0,Color(0.95,0.93,0.88,0.85));ramp.set_color(1,Color(0.7,0.7,0.68,0.0))
 var grow=Curve.new();grow.add_point(Vector2(0,0.5));grow.add_point(Vector2(1,2.8))
 for i in range(16):
  var p=CPUParticles3D.new()
  p.one_shot=true;p.emitting=false;p.amount=16;p.lifetime=5.0;p.explosiveness=0.85
  p.mesh=smoke_mesh;p.material_override=smoke_mat
  p.emission_shape=CPUParticles3D.EMISSION_SHAPE_SPHERE;p.emission_sphere_radius=0.8
  p.spread=35.0;p.initial_velocity_min=2.5;p.initial_velocity_max=6.5;p.gravity=Vector3(0.6,0.9,0.0)
  p.damping_min=1.4;p.damping_max=2.2
  p.color_ramp=ramp;p.scale_amount_curve=grow;p.scale_amount_min=1.0;p.scale_amount_max=1.8
  p.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  add_child(p);smoke_pool.append(p)
 var splash_mat=StandardMaterial3D.new()
 splash_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;splash_mat.albedo_color=Color(0.92,0.92,0.88,0.85);splash_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 var drop=SphereMesh.new();drop.radius=0.22;drop.height=0.44;drop.radial_segments=6;drop.rings=3
 for i in range(8):
  var p=CPUParticles3D.new()
  p.one_shot=true;p.emitting=false;p.amount=26;p.lifetime=1.5;p.explosiveness=1.0
  p.mesh=drop;p.material_override=splash_mat
  p.emission_shape=CPUParticles3D.EMISSION_SHAPE_SPHERE;p.emission_sphere_radius=0.9
  p.direction=Vector3.UP;p.spread=22.0;p.initial_velocity_min=5.0;p.initial_velocity_max=11.0;p.gravity=Vector3(0,-9.8,0)
  p.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  add_child(p);splash_pool.append(p)
 var flash_mat=StandardMaterial3D.new()
 flash_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;flash_mat.albedo_color=Color("ffcf7a");flash_mat.emission_enabled=true;flash_mat.emission=Color("ff9a30")
 var fm=SphereMesh.new();fm.radius=1.0;fm.height=2.0;fm.radial_segments=8;fm.rings=4
 for i in range(14):
  var m=MeshInstance3D.new();m.mesh=fm;m.material_override=flash_mat;m.visible=false;m.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  add_child(m);flash_pool.append({"node":m,"life":0.0})

func _gun_world(i:int)->Vector3:
 var rot:Basis=ship.global_transform.basis.orthonormalized()
 return ship.global_position+rot*ship_gun_pos[i]

func _port_dir()->Vector3:
 return (ship.global_transform.basis.orthonormalized()*Vector3(-1,0.15,0)).normalized()

func _fire_smoke(pos:Vector3,dir:Vector3,big:bool=true):
 var p:CPUParticles3D=smoke_pool[smoke_next];smoke_next=(smoke_next+1)%smoke_pool.size()
 p.global_position=pos;p.direction=dir;p.restart();p.emitting=true
 var fl=flash_pool[flash_next];flash_next=(flash_next+1)%flash_pool.size()
 var n:MeshInstance3D=fl.node;n.global_position=pos+dir*0.8;n.scale=Vector3.ONE*(1.4 if big else 0.9);n.visible=true;fl.life=0.14

func _splash(pos:Vector3):
 var p:CPUParticles3D=splash_pool[splash_next];splash_next=(splash_next+1)%splash_pool.size()
 p.global_position=pos;p.restart();p.emitting=true

func _cannon_effect_j(from:Vector2,to:Vector2):
 if smoke_pool.is_empty():return
 if from!=Vector2.ZERO:
  var pos=Vector3(from.x,_h(from.x,from.y)+2.2,from.y)
  _fire_smoke(pos,Vector3(1,0.2,0).normalized(),false)
  if is_instance_valid(fire_flash):fire_flash.global_position=pos;fire_flash.light_energy=3.0
  if to!=Vector2.ZERO:shot_queue.append({"t":0.9,"kind":"splash","pos":Vector3(to.x,level_m,to.y)})
  return
 # Descarga de la banda de babor: 13 piezas escalonadas en ~1 s.
 for i in range(ship_gun_pos.size()):
  shot_queue.append({"t":randf()*1.0 if i>0 else 0.0,"kind":"gun","i":i})
 var tgt=to
 if tgt==Vector2.ZERO:
  tgt=_nearest_target_in_range()
 if tgt!=Vector2.ZERO:
  tgt+=Vector2(randf_range(-7,7),randf_range(-7,7))
  shot_queue.append({"t":0.9,"kind":"splash","pos":Vector3(tgt.x,level_m,tgt.y)})

func _nearest_target_in_range()->Vector2:
 var sp=Vector2(float(M.ship.x),float(M.ship.z));var best=Vector2.ZERO;var bd=float(M.ship.fire.range_m)
 for u in rules.state.units:
  var p=Vector2(float(u.x),float(u.z));var d=sp.distance_to(p)
  if float(u.strength)>0.0 and d<bd:bd=d;best=p
 return best

func _update_effects_j(delta:float):
 if is_instance_valid(fire_flash):
  fire_flash.light_energy=move_toward(fire_flash.light_energy,0.0,delta*14.0)
 for fl in flash_pool:
  if fl.life>0.0:
   fl.life-=delta
   fl.node.scale*=maxf(0.0,1.0-delta*6.0)
   if fl.life<=0.0:fl.node.visible=false
 var keep=[]
 for q in shot_queue:
  q.t-=delta
  if q.t>0.0:keep.append(q);continue
  if q.kind=="gun":
   var gp=_gun_world(int(q.i));_fire_smoke(gp,_port_dir())
   if is_instance_valid(fire_flash) and int(q.i)==6:fire_flash.global_position=gp;fire_flash.light_energy=4.5
  elif q.kind=="splash":_splash(q.pos)
 shot_queue=keep

# ---------------------------------------------------------------- alcance del buque
func _exposure_j():
 exposure_root=Node3D.new();exposure_root.name="Alcance";add_child(exposure_root)
 var f=M.get("ship",{}).get("fire",{})
 var rng=float(f.get("range_m",280.0));var af=f.get("arc_factors",{})
 var b_half=deg_to_rad(float(af.get("broadside_half_deg",40.0)));var q_half=deg_to_rad(float(af.get("quarter_half_deg",70.0)))
 var verts=PackedVector3Array();var cols=PackedColorArray();var idx=PackedInt32Array()
 var steps=72
 # Relleno <= 0,12 (palette.map_overlays); aqui 0,07 maximo y degradado desde el buque: el abanico es un contorno, no una mancha.
 # Regla de color (P1, A3): la zona de fuego es del enemigo -> rojo realista #B8433A (antes rosa salmón). El relleno queda bajo
 # (<= 0,065, degradado desde el buque) para no teñir el agua ni tapar las franjas del vado; lo que se lee es el aro al 55 %.
 var rr=Looks.ROJO_REALISTA
 var cs={1.0:Color(rr.r,rr.g,rr.b,0.065),0.5:Color(rr.r,rr.g,rr.b,0.045),0.25:Color(rr.r,rr.g,rr.b,0.03)}
 for k in range(steps):
  var a0=TAU*float(k)/float(steps);var a1=TAU*float(k+1)/float(steps);var am=(a0+a1)*0.5
  var ang=absf(wrapf(am,-PI,PI));if ang>PI*0.5:ang=PI-ang
  var fac=float(af.get("broadside",1.0)) if ang<=b_half else (float(af.get("quarter",0.5)) if ang<=q_half else float(af.get("chaser",0.25)))
  var col:Color=cs[1.0] if fac>=0.99 else (cs[0.5] if fac>=0.4 else cs[0.25])
  var base=verts.size()
  verts.append(Vector3.ZERO);verts.append(Vector3(cos(a0),0,sin(a0))*rng);verts.append(Vector3(cos(a1),0,sin(a1))*rng)
  cols.append(Color(col.r,col.g,col.b,col.a*0.1));cols.append(col);cols.append(col)
  idx.append_array(PackedInt32Array([base,base+2,base+1]))
  # Anillo del alcance.
  var rb=verts.size()
  var ring_col=Color(rr.r,rr.g,rr.b,0.55)   # R5: aro fino (1 m); P1: rojo realista al 55 %
  verts.append(Vector3(cos(a0),0,sin(a0))*(rng-0.5));verts.append(Vector3(cos(a0),0,sin(a0))*(rng+0.5))
  verts.append(Vector3(cos(a1),0,sin(a1))*(rng-0.5));verts.append(Vector3(cos(a1),0,sin(a1))*(rng+0.5))
  for _i in range(4):cols.append(ring_col)
  idx.append_array(PackedInt32Array([rb,rb+2,rb+1,rb+1,rb+2,rb+3]))
 var arr=[];arr.resize(Mesh.ARRAY_MAX);arr[Mesh.ARRAY_VERTEX]=verts;arr[Mesh.ARRAY_COLOR]=cols;arr[Mesh.ARRAY_INDEX]=idx
 var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr)
 var mi=MeshInstance3D.new();mi.mesh=mesh;mi.material_override=_overlay_mat();mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 mi.custom_aabb=AABB(Vector3(-rng,-1,-rng),Vector3(rng*2,2,rng*2))
 exposure_root.add_child(mi)
 # R6: segundo anillo, punteado y mas tenue, con ship.fire.cover_zone.range_m (420 m): hasta donde "batia" el buque segun Gillespie p. 94.
 # Las reglas NO lo usan (exposure_at sigue limitado a range_m); es DISEÑO.
 var cz:Dictionary=f.get("cover_zone",{})
 var crng=float(cz.get("range_m",0.0))
 if crng>rng:
  var cv=PackedVector3Array();var cc=PackedColorArray();var ci=PackedInt32Array()
  var seg=140
  for k in range(seg):
   if k%2==1:continue
   var a0=TAU*float(k)/float(seg);var a1=TAU*float(k+1)/float(seg)
   var b0=cv.size()
   cv.append(Vector3(cos(a0),0,sin(a0))*(crng-0.4));cv.append(Vector3(cos(a0),0,sin(a0))*(crng+0.4))
   cv.append(Vector3(cos(a1),0,sin(a1))*(crng-0.4));cv.append(Vector3(cos(a1),0,sin(a1))*(crng+0.4))
   for _i in range(4):cc.append(Color(rr.r,rr.g,rr.b,0.2))
   ci.append_array(PackedInt32Array([b0,b0+2,b0+1,b0+1,b0+2,b0+3]))
  var carr=[];carr.resize(Mesh.ARRAY_MAX);carr[Mesh.ARRAY_VERTEX]=cv;carr[Mesh.ARRAY_COLOR]=cc;carr[Mesh.ARRAY_INDEX]=ci
  var cm=ArrayMesh.new();cm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,carr)
  var cmi=MeshInstance3D.new();cmi.name="CoberturaGillespie";cmi.mesh=cm;cmi.material_override=_overlay_mat();cmi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  cmi.custom_aabb=AABB(Vector3(-crng,-1,-crng),Vector3(crng*2,2,crng*2))
  exposure_root.add_child(cmi)
  # R5: sin rotulo de diseño sobre el mapa ("Gillespie, no simulado" queda en la ayuda): era ruido ilegible para quien juega.
 var sx=float(M.ship.x);var sz=float(M.ship.z)
 exposure_root.position=Vector3(sx,level_m+0.18,sz)
 exposure_root.rotation.y=-deg_to_rad(float(M.ship.get("heading_deg",0.0)))
 exposure_root.visible=false
 # Rotulos de los anillos (ronda 3): el anillo rosa es el alcance de fuego del buque; el punteado, la zona de incertidumbre del encallamiento. Ambos de DISEÑO.
 var l1=_label_j("Zona de fuego",Vector3(rng*0.0,0.8,-rng),Color("e58478"),20,exposure_root)   # rojo realista aclarado para leerse sobre el agua
 l1.outline_size=8
 var unc=float(M.get("ship",{}).get("uncertainty_radius_m",120.0))
 var l2=_label_j("¿Dónde varó? (±%d m)"%int(unc),Vector3(sx+unc*0.2,level_m+1.2,sz+unc),Color("e3d8b0"),20,labels_root)
 l2.outline_size=8

func _overlay_mat()->StandardMaterial3D:
 if ring_mat_cache.has("overlay"):return ring_mat_cache["overlay"]
 var m=StandardMaterial3D.new()
 m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 m.vertex_color_use_as_albedo=true
 m.cull_mode=BaseMaterial3D.CULL_DISABLED
 m.render_priority=1
 m.no_depth_test=false
 ring_mat_cache["overlay"]=m
 return m

# ---------------------------------------------------------------- unidades
func _ring_j(radius:float,color:Color,parent:Node3D,half_w:float=0.11)->MeshInstance3D:
 var m=TorusMesh.new();m.inner_radius=radius-half_w;m.outer_radius=radius+half_w;m.rings=64;m.ring_segments=6
 var n=MeshInstance3D.new();n.mesh=m
 var mat=StandardMaterial3D.new();mat.albedo_color=color;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 n.material_override=mat;n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 parent.add_child(n)
 return n

## visual/r1 F3: figuras del grupo según sus hombres (antes 14 fijas a fuerza 100, sin relación con la tropa).
## base = hombres / 3,5 entre 6 y 24; luego en proporción a la fuerza actual sobre la inicial (bajas y refuerzos), mínimo 2.
func _group_count(u:Dictionary)->int:
 var base=clampi(roundi(_fig_men(u)/MEN_PER_FIGURE),FIG_MIN,FIG_MAX)
 var s0=maxf(_strength0(str(u.get("id",""))),1.0)
 var n=clampi(roundi(float(base)*float(u.get("strength",s0))/s0),2,FIG_MAX)
 if quality=="baja":n=maxi(2,n/2)
 return n

## visual/r1 F3: hombres de cada grupo. Justina: forces.groups[id].men_design de justina_map.json (etiqueta diseno: el paquete da
## «30, 50 o 60 jinetes» sin datos suficientes); si falta, headcount_hint × 3,5 o 35, también diseño. Norte: NORTE_MEN_DISENO.
func _fig_men(u:Dictionary)->float:
 var id=str(u.get("id",""))
 if justina:
  var fg:Dictionary=M.get("forces",{}).get("groups",{}).get(id,{})
  if fg.has("men_design"):return float(fg.men_design)
  if fg.has("headcount_hint"):return float(fg.headcount_hint)*MEN_PER_FIGURE
  return 10.0*MEN_PER_FIGURE
 return float(NORTE_MEN_DISENO.get(id,60.0))

## Fuerza con la que arranca el grupo (Justina: groups[].strength del mapa, 100/70/60; Norte: 100). Los hombres de diseño valen a esa fuerza.
func _strength0(id:String)->float:
 if justina:
  for g in M.get("groups",[]):
   if str(g.get("id",""))==id:return float(g.get("strength",100.0))
 return 100.0

## visual/r1 F3: orden de dibujo de las figuras. La instancia i ocupa el puesto _lod_slot(i): primero los puestos pares y después los
## impares, así el LOD (visible_instance_count = mitad) deja una tropa rala con la misma huella en vez de cortar las filas de atrás.
func _lod_slot(i:int,n:int)->int:
 var h=(n+1)/2
 return 2*i if i<h else 2*(i-h)+1

## Filas y columnas: quieta, en línea (frente ancho y poco fondo); en marcha, en columna (2–3 de frente a caballo, 3–4 a pie).
func _form_dims(n:int,mounted:bool,column:bool)->Vector2i:
 var lanes:int
 if column:lanes=(2 if n<=12 else 3) if mounted else (3 if n<=15 else 4)
 else:lanes=clampi(int(ceil(sqrt(float(n)*((2.8 if scenario=="norte" else 2.0) if mounted else 2.5)))),2,8 if mounted else 10)   # visual/r1 F4: el Norte forma más ancho y menos hondo (24 jinetes: 8 de frente), así entra en su aro
 lanes=mini(lanes,n)
 return Vector2i(lanes,int(ceil(float(n)/float(lanes))))

## visual/r1 F4: separación (de costado, de fondo) a escala 1 según el nivel y si van a caballo.
func _gaps(mounted:bool)->Vector2:
 if not mounted:return Vector2(FOOT_GAP_X,FOOT_GAP_Z)
 return Vector2(NORTE_GAP_X,NORTE_GAP_Z) if scenario=="norte" else Vector2(CAV_GAP_X,CAV_GAP_Z)

func _slot_xy(s:int,n:int,mounted:bool,sc:float,column:bool)->Vector2:
 var dims=_form_dims(n,mounted,column)
 var row=s/dims.x;var lane=s%dims.x
 var in_row=mini(dims.x,n-row*dims.x)   # la última fila, si queda corta, va centrada
 var g=_gaps(mounted)*sc
 return Vector2((float(lane)-float(in_row-1)*0.5)*g.x,float(row)*g.y)

## Puesto de la instancia i: (de costado, hacia atrás, giro) en metros y radianes, mezclando línea (form_k 0) y columna (1),
## con un leve desorden fijo por grupo (±0,2 m de costado, ±0,3 m de fondo, ±4°; por `jit`): tropa, no grilla.
func _form_slot(i:int,n:int,mounted:bool,sc:float,form_k:float,gseed:int,jit:float=1.0)->Vector3:
 var s=_lod_slot(i,n)
 var p=_slot_xy(s,n,mounted,sc,false).lerp(_slot_xy(s,n,mounted,sc,true),form_k)
 var h1=fposmod(sin(float(s)*12.9898+float(gseed%977)*0.731)*43758.5453,1.0)
 var h2=fposmod(sin(float(s)*78.233+float(gseed%613)*1.137)*24634.6345,1.0)
 var h3=fposmod(sin(float(s)*39.347+float(gseed%331)*2.011)*13579.2468,1.0)
 return Vector3(p.x+(h1-0.5)*0.4*sc*jit,p.y+(h2-0.5)*0.6*sc*jit,(h3-0.5)*0.14*jit)

## Huella de la formación: (semiancho, fondo) entre centros de figuras, ya mezclada entre línea y columna.
func _form_extent(n:int,mounted:bool,sc:float,form_k:float)->Vector2:
 var g=_gaps(mounted)*sc;var gx=g.x;var gz=g.y
 var a=_form_dims(n,mounted,false);var b=_form_dims(n,mounted,true)
 return Vector2(lerpf(float(a.x-1),float(b.x-1),form_k)*0.5*gx,lerpf(float(a.y-1),float(b.y-1),form_k)*gz)

## Aplica el LOD del grupo (entry.lod_far) a sus MultiMesh: mitad de figuras visibles y sin sombra a lo lejos.
func _apply_fig_lod(entry:Dictionary)->void:
 var far=bool(entry.get("lod_far",false))
 for p in entry.get("parts",[]):
  var mm:MultiMesh=p.mm
  mm.visible_instance_count=(int(ceil(float(mm.instance_count)*FIG_LOD_KEEP)) if far else -1)
  (p.mmi as GeometryInstance3D).cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if (far or bool(entry.get("no_shadow",false))) else GeometryInstance3D.SHADOW_CASTING_SETTING_ON

## Histéresis del LOD: devuelve true si el grupo debe pasar a «lejos» (o seguir lejos) a la distancia d.
func _lod_far_at(entry:Dictionary,d:float)->bool:
 return d>(FIG_LOD_FAR_M-20.0 if bool(entry.get("lod_far",false)) else FIG_LOD_FAR_M+20.0)

## R6: reparto cromatico de jinetes y caballos (palette.riders / palette.mounts del JSON, Diseño: no son uniformes ni colores de bando medidos).
## Reclasifica el color de vertice del GLB (indigo, grana, pantalon, sombrero, camisa, pelaje) hacia la paleta del paquete, por grupo.
const TINT_BASES = {
 "casaca":Color(0.035,0.075,0.12),"vueltas":Color(0.30,0.035,0.04),"poncho":Color(0.31,0.035,0.026),"calzon":Color(0.18,0.17,0.13),
 "sombrero":Color(0.021,0.023,0.021),"camisa":Color(0.61,0.58,0.45),"camisa2":Color(0.74,0.72,0.66),"pelaje":Color(0.205,0.082,0.033),
 "pelaje_sombra":Color(0.095,0.032,0.012)}
const GROUP_RIDERS = {"guemes":"guemes","arias":"voluntarios","zavala":"jinetes"}
const ROLE_KEYS = {"casaca":["casaca","chaqueta","chaleco"],"vueltas":["vueltas","botones","chaleco"],"poncho":["poncho","chaleco","chaqueta"],
 "calzon":["calzon","calzado"],"sombrero":["sombrero"],"camisa":["camisa"],"camisa2":["camisa"]}
var tint_cache:Dictionary={}
## visual/r1 F5: rol de la figura F5 → rol de TINT_BASES/ROLE_KEYS cuyo color de la paleta del grupo toma (los mismos que reconoce el
## jinete F4 de 1806: casaca, vueltas, sombrero y corbatín negros, calzón de lino como la camisa). Los demás roles quedan como vienen.
const F5_ROLE_TINT = {"casaca":"casaca","chaqueta":"casaca","vueltas":"vueltas","sombrero":"sombrero","corbatin":"sombrero","calzon":"camisa","camisa":"camisa"}

## visual/r1 F5: rol del material «<F4|F5> | <rol> | <clase>» (f5_personas_manifest: _convenciones.color); "" si no tiene ese formato.
func _role_of(nm:String)->String:
 var p=nm.split(" | ")
 return p[1] if p.size()>=3 and (p[0]=="F4" or p[0]=="F5") else ""

## visual/r1 F5: retinte de una superficie de un rol (manifiesto: «color nuevo = tinte × (COLOR_0 / color base del rol)»): la sombra de
## cada vértice es su luminancia sobre la del vértice más claro de la superficie (la oclusión horneada se conserva; tope abajo 0,15).
## out_k = F4_ALBEDO en los jinetes F4, 1 en las figuras F5.
func _role_cols(src:PackedColorArray,t:Color,out_k:float)->PackedColorArray:
 var cols:PackedColorArray=src.duplicate()
 var mx=0.0
 for c in cols:mx=maxf(mx,c.get_luminance())
 if mx<=0.00001:return cols
 for k in range(cols.size()):
  var sh=clampf(cols[k].get_luminance()/mx,0.15,1.0)*out_k
  cols[k]=Color(minf(t.r*sh,1.0),minf(t.g*sh,1.0),minf(t.b*sh,1.0),cols[k].a)
 return cols

func _tinted_mesh(src:Mesh,group_id:String)->Mesh:
 var key=str(src.get_rid().get_id())+"|"+group_id
 if tint_cache.has(key):return tint_cache[key]
 var pal:Dictionary=M.get("palette",{})
 var riders:Dictionary=pal.get("riders",{}).get(GROUP_RIDERS.get(group_id,"jinetes"),{})
 var mounts:Dictionary=pal.get("mounts",{})
 if riders.is_empty() or mounts.is_empty():
  tint_cache[key]=src;return src
 var target:Dictionary={}
 for role in ROLE_KEYS:
  for k in ROLE_KEYS[role]:
   if riders.has(k):target[role]=Color(str(riders[k])).srgb_to_linear();break
 var pel_keys=["tostado","alazan","bayo","tordillo","rosillo","zaino"]
 var pk:String=pel_keys[absi(group_id.hash())%pel_keys.size()]
 if group_id=="guemes":pk="tostado"
 elif group_id=="zavala":pk="alazan"
 var pelaje=Color(str(mounts.get(pk,"#8A5A3A"))).srgb_to_linear()
 target["pelaje"]=pelaje;target["pelaje_sombra"]=pelaje*0.45
 var out=ArrayMesh.new()
 for si in range(src.get_surface_count()):
  var a=src.surface_get_arrays(si)
  var mat=src.surface_get_material(si)
  var nm=str(mat.resource_name) if mat!=null else ""
  # visual/r1 F4: en los jinetes F4 («F4 | …», sin textura) el color se lee normalizado (/0,62) y la tinta sale x0,62; su «coat»
  # es pelo y barba del jinete, no pelaje: no se reclasifica (los caballos F4 traen su pelaje y no pasan por acá).
  var f4=nm.begins_with("F4")
  var f5=nm.begins_with("F5")
  var nk=1.0/F4_ALBEDO if f4 else 1.0
  var ok=F4_ALBEDO if f4 else 1.0
  if f5:
   # visual/r1 F5: figuras de a pie F5 (persona_*): retinte por rol, sin umbrales (con los de abajo la casaca azul oscura del voluntario
   # caía en «sombrero» y se volvía negra, el 70 % de las vueltas quedaba sin tocar y el pelo tomaba el pelaje de un caballo).
   var rk=str(F5_ROLE_TINT.get(_role_of(nm),""))
   if rk!="" and target.has(rk) and a[Mesh.ARRAY_COLOR] is PackedColorArray:a[Mesh.ARRAY_COLOR]=_role_cols(a[Mesh.ARRAY_COLOR],target[rk],1.0)
  elif a[Mesh.ARRAY_COLOR] is PackedColorArray and (nm.ends_with("wool") or nm.ends_with("linen") or (nm.ends_with("coat") and not f4)):
   var cols:PackedColorArray=a[Mesh.ARRAY_COLOR]
   var chg=0
   for i in range(cols.size()):
    var c0=cols[i];var c=Color(c0.r*nk,c0.g*nk,c0.b*nk,c0.a);var t=Color(0,0,0,0);var k=1.0
    if nm.ends_with("coat"):
     if c.r>c.g*1.6 and c.g>c.b*1.35 and c.r<0.5 and target.has("pelaje"):
      t=target["pelaje"];k=clampf(c.r/0.16,0.35,2.4)
     elif c.r<0.1 and c.g<0.07 and c.b<0.04 and c.r>c.b and target.has("pelaje_sombra"):
      t=target["pelaje_sombra"];k=clampf(c.r/0.06,0.7,1.4)
    elif nm.ends_with("wool"):
     if c.r>0.3 and c.g<0.12 and target.has("vueltas"):t=target["vueltas"];k=clampf(c.r/0.48,0.8,1.2)
     elif c.b>c.r*2.2 and c.b>0.1 and target.has("casaca"):t=target["casaca"];k=clampf(c.b/0.2,0.8,1.2)
     elif c.r<0.08 and c.g<0.08 and c.b<0.08 and target.has("sombrero"):t=target["sombrero"];k=clampf(c.r/0.04,0.8,1.3)
    elif nm.ends_with("linen") and c.r>0.6 and target.has("camisa"):
     t=target["camisa"];k=clampf(c.r/0.98,0.8,1.1)
    if t.a>0.0:chg+=1;cols[i]=Color(minf(t.r*k*ok,1.0),minf(t.g*k*ok,1.0),minf(t.b*k*ok,1.0),c.a)
   a[Mesh.ARRAY_COLOR]=cols
  out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
  # El mapa rugosidad/metal del GLB da un brillo plateado a telas y pelaje a escala de juego: se pasa a mate (aspecto, no color de fuente).
  if mat is BaseMaterial3D and not (nm.ends_with("metal") or nm.ends_with("gloss")):
   var m2:BaseMaterial3D=mat.duplicate()
   m2.metallic=0.0;m2.metallic_texture=null;m2.roughness=0.88;m2.roughness_texture=null;m2.metallic_specular=0.25
   m2.vertex_color_use_as_albedo=true
   out.surface_set_material(si,m2)
  else:
   out.surface_set_material(si,mat)
 tint_cache[key]=out
 return out

func _mm_parts(root:Node3D,model_name:String,count:int,group_id:String="")->Array:
 var out=[]
 for part in _glb_parts(model_name):
  var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=(_tinted_mesh(part.mesh,group_id) if group_id!="" else part.mesh);mm.instance_count=count
  var mmi=MultiMeshInstance3D.new();mmi.multimesh=mm;mmi.custom_aabb=AABB(Vector3(-30,-5,-30),Vector3(60,20,60))
  root.add_child(mmi)
  out.append({"mmi":mmi,"mm":mm,"xf":part.xf})
 if out.is_empty():
  # Sin GLB: una capsula por jinete (para que el juego siga siendo jugable).
  var mm2=MultiMesh.new();mm2.transform_format=MultiMesh.TRANSFORM_3D
  var cap=CapsuleMesh.new();cap.radius=0.4;cap.height=1.8;mm2.mesh=cap;mm2.instance_count=count
  var mmi2=MultiMeshInstance3D.new();mmi2.multimesh=mm2;mmi2.custom_aabb=AABB(Vector3(-30,-5,-30),Vector3(60,20,60));mmi2.material_override=_mat(Color("514333"))
  root.add_child(mmi2);out.append({"mmi":mmi2,"mm":mm2,"xf":Transform3D(Basis.IDENTITY,Vector3(0,0.9,0))})
 return out

## visual/r1 F4: pelaje fijo de la figura i del grupo (índice en HORSE_COATS), con los pesos de HORSE_COAT_W. i<0: el del jefe.
func _coat_of(gseed:int,i:int)->int:
 var h=fposmod(sin(float(i+3)*91.173+float(gseed%1009)*0.377)*43758.5453,1.0)
 var acc=0.0
 for c in range(HORSE_COATS.size()):
  acc+=float(HORSE_COAT_W[c])
  if h<acc:return c
 return 0

## visual/r1 F4: reparto de `count` figuras en un MultiMesh por pelaje: map[c][i] = instancia de la figura i en el lote c (o −1).
## Dentro de cada lote se respeta el orden de i, así el LOD (primera mitad visible) sigue raleando toda la huella.
func _coat_maps(count:int,gseed:int)->Array:
 var maps:Array=[];var nums:Array=[]
 for c in range(HORSE_COATS.size()):
  var pm=PackedInt32Array();pm.resize(count);pm.fill(-1);maps.append(pm);nums.append(0)
 for i in range(count):
  var c=_coat_of(gseed,i)
  var pm2:PackedInt32Array=maps[c];pm2[i]=int(nums[c]);maps[c]=pm2;nums[c]=int(nums[c])+1
 return [maps,nums]

## visual/r1 F4: tropa montada en MultiMesh: un lote por pelaje (caballo _lod, estático) y uno del jinete _lod puesto en el asiento
## (RIDER_SEAT). period "1806" (Justina: tinta por grupo) o "1817" (Norte: poncho pardo). Con rider=false, solo caballos
## (caballada de los desmontados). Las partes llevan "coat" y "map" (ver _set_fig y _resize_parts). Sin GLB: cápsulas de antes.
func _mount_parts(root:Node3D,period:String,count:int,group_id:String,gseed:int,rider:bool=true)->Array:
 var out=[]
 var cm=_coat_maps(count,gseed)
 for c in range(HORSE_COATS.size()):
  for part in _glb_parts("caballo_criollo_"+str(HORSE_COATS[c])+"_lod"):
   var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=_troop_mesh(part.mesh);mm.instance_count=int(cm[1][c])
   var mmi=MultiMeshInstance3D.new();mmi.name="Caballos_"+str(HORSE_COATS[c]);mmi.multimesh=mm;mmi.custom_aabb=AABB(Vector3(-30,-5,-30),Vector3(60,20,60))
   root.add_child(mmi)
   out.append({"mmi":mmi,"mm":mm,"xf":part.xf,"coat":c,"map":cm[0][c]})
 if out.is_empty():return _mm_parts(root,"rider_1806" if period=="1806" else "rider_1817",count,group_id)
 if rider:
  for part in _glb_parts("jinete_criollo_"+period+"_lod"):
   var mesh:Mesh=part.mesh
   if period=="1817":mesh=_poncho_mesh(mesh,false)
   elif group_id!="":mesh=_tinted_mesh(mesh,group_id)
   var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=_troop_mesh(mesh);mm.instance_count=count
   var mmi=MultiMeshInstance3D.new();mmi.name="Jinetes";mmi.multimesh=mm;mmi.custom_aabb=AABB(Vector3(-30,-5,-30),Vector3(60,20,60))
   root.add_child(mmi)
   out.append({"mmi":mmi,"mm":mm,"xf":Transform3D(Basis.IDENTITY,RIDER_SEAT)*part.xf})
 return out

## visual/r1 F4 (costo): une las superficies con color de vértice de una malla F4 bajo un material mate (y, con split_shiny, otro
## para metal y charol) y quita el «ancla» (esfera de 2 mm que solo esquiva un defecto de importación; acá el material ya fuerza el
## color de vértice). Conserva huesos y pesos (sirve para el caballo animado del jefe). Menos dibujos: 1–2 por malla en vez de 6 a 9.
var merged_mesh_cache:Dictionary={}
func _merge_surfaces(src:Mesh,split_shiny:bool)->Mesh:
 var key=str(src.get_rid().get_id())+("|s" if split_shiny else "|m")+("|tj" if scenario=="justine" else "")
 if merged_mesh_cache.has(key):return merged_mesh_cache[key]
 var groups:Array=[[],[]]   # [mate, brillante]
 var mats:Array=[null,null];var best:Array=[-1,-1]
 for si in range(src.get_surface_count()):
  var m=src.surface_get_material(si)
  var nm=str(m.resource_name) if m!=null else ""
  if nm.ends_with("ancla"):continue
  var g=1 if (split_shiny and (nm.ends_with("metal") or nm.ends_with("gloss"))) else 0
  groups[g].append(si)
  var nv=src.surface_get_array_len(si)
  if m is BaseMaterial3D and (g==1 or not (nm.ends_with("metal") or nm.ends_with("gloss"))) and nv>int(best[g]):best[g]=nv;mats[g]=m
 var out=ArrayMesh.new()
 for g in range(2):
  if (groups[g] as Array).is_empty():continue
  var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
  for si in groups[g]:
   var sm=src.surface_get_material(si)
   # visual/r1 F6: la teja del kit (#85634E) se leía anaranjada con la luz cálida de la Justina; se apaga en el color de vértice al
   # unir (en tiempo de ejecución, sin tocar el GLB). El Norte la deja como viene.
   if scenario=="justine" and sm!=null and str(sm.resource_name).ends_with("teja"):st.append_from(_teja_apagada(src,si),0,Transform3D.IDENTITY)
   else:st.append_from(src,si,Transform3D.IDENTITY)
  st.commit(out)
  var m2:BaseMaterial3D=(mats[g].duplicate() if mats[g]!=null else StandardMaterial3D.new())
  m2.vertex_color_use_as_albedo=true
  if g==0:m2.metallic=0.0;m2.roughness=0.88
  out.surface_set_material(out.get_surface_count()-1,m2)
 var res:Mesh=out if out.get_surface_count()>0 else src
 merged_mesh_cache[key]=res
 return res

## visual/r1 F6: copia de la superficie `si` con la teja apagada: 45 % hacia su gris (misma luminancia) y un 6 % más oscura. Con el
## sol bajo y cálido de la Justina la teja pardo-terracota se veía naranja; así queda parda, sin perder el contraste con la cal.
func _teja_apagada(src:Mesh,si:int)->ArrayMesh:
 var arr:Array=src.surface_get_arrays(si)
 var out=ArrayMesh.new()
 if arr[Mesh.ARRAY_COLOR]!=null and (arr[Mesh.ARRAY_COLOR] as PackedColorArray).size()>0:
  var cols:PackedColorArray=arr[Mesh.ARRAY_COLOR]
  for i in range(cols.size()):
   var c:Color=cols[i]
   var l=0.2126*c.r+0.7152*c.g+0.0722*c.b
   var d=Color(l,l,l,c.a).lerp(c,0.55)
   cols[i]=Color(d.r*0.94,d.g*0.94,d.b*0.94,c.a)
  arr[Mesh.ARRAY_COLOR]=cols
 out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr)
 out.surface_set_material(0,src.surface_get_material(si))
 return out

## visual/r1 F4 (costo): malla de tropa = una sola superficie mate (_merge_surfaces; los metales de la tropa quedan mates, a la
## distancia de juego no se distinguen) con niveles de detalle (_lod_mesh). Un dibujo por lote.
func _troop_mesh(src:Mesh)->Mesh:
 return _lod_mesh(_merge_surfaces(src,false))

## visual/r1 F4: pone la figura i (transformación del caballo en el marco del lote) en todas las partes que la dibujan.
func _set_fig(parts:Array,i:int,xf:Transform3D)->void:
 for p in parts:
  var k:int=i
  if p.has("map"):
   var pm:PackedInt32Array=p.map
   if i>=pm.size():continue
   k=pm[i]
   if k<0:continue
  if k<p.mm.instance_count:p.mm.set_instance_transform(k,xf*p.xf)

## visual/r1 F4: cambia la cantidad de figuras (bajas, refuerzos) rehaciendo el reparto por pelaje. Después hay que rehacer la formación.
func _resize_parts(parts:Array,count:int,gseed:int)->void:
 var cm=_coat_maps(count,gseed)
 for p in parts:
  p.mm.visible_instance_count=-1
  if p.has("coat"):
   p.map=cm[0][int(p.coat)];p.mm.instance_count=int(cm[1][int(p.coat)])
  elif p.has("phase"):
   # visual/r1 F5: tropa de a pie repartida en lotes por fase del ciclo (_foot_parts).
   var pm=_phase_maps(count)
   p.map=pm[0][int(p.phase)];p.mm.instance_count=int(pm[1][int(p.phase)])
  else:p.mm.instance_count=count

## visual/r1 F4: el jefe del grupo, animado: caballo criollo (Skeleton3D de 25 huesos, AnimationPlayer con idle/walk/trot/gallop)
## y el jinete colgado del hueso «silla» con un BoneAttachment3D (transformación identidad: el origen del jinete es el asiento).
## Devuelve {node, ap, gait, v}; el andar lo lleva _gait_step. Sin GLB, cápsula (como _model).
func _mount_rig(parent:Node3D,coat:String,period:String,group_id:String,hero:bool)->Dictionary:
 var horse=_model("caballo_criollo_"+coat,Vector3.ZERO,parent)
 horse.name="Jefe"
 _fix_vc(horse)
 for mi in horse.find_children("*","MeshInstance3D",true,false):
  if mi.mesh!=null:mi.mesh=_lod_mesh(_merge_surfaces(mi.mesh,true),true)   # visual/r1 F4: unir quita los LOD del importador; se rehacen
 var sks=horse.find_children("*","Skeleton3D",true,false)
 var seat:Node3D=horse
 if not sks.is_empty():
  var ba=BoneAttachment3D.new();ba.name="Silla";ba.bone_name="silla";(sks[0] as Skeleton3D).add_child(ba);seat=ba
 var rider=_model("jinete_criollo_"+period,Vector3.ZERO if seat!=horse else RIDER_SEAT,seat)
 rider.name="Jinete"
 _fix_vc(rider)
 for mi in rider.find_children("*","MeshInstance3D",true,false):
  if mi.mesh==null:continue
  if period=="1817":mi.mesh=_poncho_mesh(mi.mesh,hero)
  elif group_id!="":mi.mesh=_tinted_mesh(mi.mesh,group_id)
  mi.mesh=_lod_mesh(_merge_surfaces(mi.mesh,true))
 var ap:AnimationPlayer=null
 var aps=horse.find_children("*","AnimationPlayer",true,false)
 if not aps.is_empty():
  ap=aps[0]
  for an in ["idle","walk","trot","gallop"]:
   if ap.has_animation(an):ap.get_animation(an).loop_mode=Animation.LOOP_LINEAR
  if ap.has_animation("idle"):ap.play("idle")
 return {"node":horse,"ap":ap,"gait":"idle","v":0.0,"seat":seat}

## visual/r1 F5: jefe de a pie animado (persona_*.glb: Skeleton3D de 18 huesos, AnimationPlayer idle/walk/run en el lugar). tint: "" (como
## viene), un id de grupo de la Justina (_tinted_mesh) o "poncho"/"heroe" (Norte: _poncho_mesh, pardo de tropa o granate oscuro).
## Devuelve {node, ap, gait, v, foot}; el andar lo lleva _foot_step. Sin GLB, cápsula (como _model).
func _foot_rig(parent:Node3D,model:String,tint:String)->Dictionary:
 var fig=_model(model,Vector3.ZERO,parent)
 fig.name="Jefe"
 _fix_vc(fig)
 for mi in fig.find_children("*","MeshInstance3D",true,false):
  if mi.mesh==null or mi.mesh is PrimitiveMesh:continue
  var m:Mesh=mi.mesh
  if tint=="poncho" or tint=="heroe":m=_poncho_mesh(m,tint=="heroe")
  elif tint!="":m=_tinted_mesh(m,tint)
  mi.mesh=_lod_mesh(_merge_surfaces(m,true),true)
 var ap:AnimationPlayer=null
 var aps=fig.find_children("*","AnimationPlayer",true,false)
 if not aps.is_empty():
  ap=aps[0]
  for an in ["idle","walk","run"]:
   if ap.has_animation(an):ap.get_animation(an).loop_mode=Animation.LOOP_LINEAR
  if ap.has_animation("idle"):ap.play("idle")
 return {"node":fig,"ap":ap,"gait":"idle","v":0.0,"foot":true}

## visual/r1 F5: tropa de a pie que camina. El MultiMesh no anima huesos: se hornean una vez (en caché) cuadros del ciclo de la figura
## completa (`model`: idle, FOOT_PHASES de walk y de run; piel por CPU en _foot_raw_poses) y la tropa se reparte en FOOT_PHASES lotes,
## cada uno corrido una fase del ciclo: al andar, cada lote toma la malla del cuadro que le toca según el reloj del jefe
## (_foot_troop_anim; un cambio de recurso por lote y por cuadro, nada por figura). Cada malla va teñida como el jefe y unida en una
## superficie con niveles de detalle (_troop_mesh). Si la figura no trae esqueleto o animación: la versión _lod quieta, en un lote.
const FOOT_PHASES := 6
func _foot_parts(root:Node3D,model:String,count:int,tint:String)->Array:
 var poses:Dictionary=_foot_poses(model,tint)
 if poses.is_empty():
  var out0=_mm_parts(root,model+"_lod",count,"" if tint=="poncho" or tint=="heroe" else tint)
  for p in out0:
   var m:Mesh=p.mm.mesh
   if m is PrimitiveMesh:continue
   if tint=="poncho" or tint=="heroe":m=_poncho_mesh(m,tint=="heroe")
   p.mm.mesh=_troop_mesh(m)
   (p.mmi as Node).name="APie"
  return out0
 var out:Array=[]
 var pm=_phase_maps(count)
 for k in range(FOOT_PHASES):
  var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=poses.idle[0];mm.instance_count=int(pm[1][k])
  var mmi=MultiMeshInstance3D.new();mmi.name="APie_%d" % k;mmi.multimesh=mm;mmi.custom_aabb=AABB(Vector3(-30,-5,-30),Vector3(60,20,60))
  root.add_child(mmi)
  out.append({"mmi":mmi,"mm":mm,"xf":Transform3D.IDENTITY,"phase":k,"map":pm[0][k],"poses":poses})
 return out

## visual/r1 F5: reparto de `count` figuras de a pie en FOOT_PHASES lotes: figura i → lote i % FOOT_PHASES, instancia i / FOOT_PHASES.
func _phase_maps(count:int)->Array:
 var maps:Array=[];var nums:Array=[]
 for k in range(FOOT_PHASES):
  var pm=PackedInt32Array();pm.resize(count);pm.fill(-1);maps.append(pm);nums.append(0)
 for i in range(count):
  var k2=i%FOOT_PHASES
  var pm2:PackedInt32Array=maps[k2];pm2[i]=int(nums[k2]);maps[k2]=pm2;nums[k2]=int(nums[k2])+1
 return [maps,nums]

## visual/r1 F5: cuadro de la tropa de a pie: el andar del jefe (idle/walk/run) y la fase de su reloj; el lote k toma el cuadro
## (fase del jefe + k). De lejos (LOD) no cambia de malla.
func _foot_troop_anim(parts:Array,rig:Dictionary,far:bool)->void:
 if far or parts.is_empty() or not (parts[0] as Dictionary).has("poses"):return
 var poses:Dictionary=parts[0].poses
 var ap:AnimationPlayer=rig.get("ap",null)
 var g=str(rig.get("gait","idle")) if ap!=null else "idle"
 var arr:Array=poses.get(g,poses.idle)
 var base=0
 if arr.size()>1 and ap!=null and ap.current_animation_length>0.0:
  base=int(floor(fposmod(ap.current_animation_position,ap.current_animation_length)/ap.current_animation_length*float(arr.size())))
 for p in parts:
  var m:Mesh=arr[(base+int(p.phase))%arr.size()]
  if p.mm.mesh!=m:p.mm.mesh=m

## visual/r1 F5: cuadros horneados y teñidos de una figura de a pie (caché por modelo y tinte): {idle:[1], walk:[FOOT_PHASES], run:[…]}.
var foot_pose_cache:Dictionary={}
func _foot_poses(model:String,tint:String)->Dictionary:
 var key=model+"|"+tint
 if foot_pose_cache.has(key):return foot_pose_cache[key]
 var raw:Dictionary=_foot_raw_poses(model)
 var out:Dictionary={}
 for an in raw:
  var arr:Array=[]
  for m in raw[an]:
   var t:Mesh=m
   if tint=="poncho" or tint=="heroe":t=_poncho_mesh(t,tint=="heroe")
   elif tint!="":t=_tinted_mesh(t,tint)
   arr.append(_troop_mesh(t))
  out[an]=arr
 foot_pose_cache[key]=out
 return out

## visual/r1 F5: piel por CPU de la figura completa (persona_*.glb) en cuadros de sus ciclos: vértice = Σ peso · (pose global del hueso ·
## pose de enlace del Skin) · vértice, pasado al espacio de la raíz de la figura. Sin huesos ni pesos en la salida. Vacío si falta algo.
var foot_raw_cache:Dictionary={}
func _foot_raw_poses(model:String)->Dictionary:
 if foot_raw_cache.has(model):return foot_raw_cache[model]
 foot_raw_cache[model]={}
 var path="res://assets/models/"+model+".glb"
 if not ResourceLoader.exists(path):return {}
 var fig:Node3D=(load(path) as PackedScene).instantiate()
 add_child(fig);fig.visible=false
 var aps=fig.find_children("*","AnimationPlayer",true,false)
 var sks=fig.find_children("*","Skeleton3D",true,false)
 var mi:MeshInstance3D=null
 for n in fig.find_children("*","MeshInstance3D",true,false):
  if (n as MeshInstance3D).skin!=null and (n as MeshInstance3D).mesh!=null:mi=n;break
 if aps.is_empty() or sks.is_empty() or mi==null:
  fig.queue_free();return {}
 var ap:AnimationPlayer=aps[0];var sk:Skeleton3D=sks[0];var skin:Skin=mi.skin;var src:Mesh=mi.mesh
 var rel:Transform3D=fig.global_transform.affine_inverse()*sk.global_transform
 var binds:Array=[]
 for b in range(skin.get_bind_count()):
  var bone=skin.get_bind_bone(b)
  if bone<0:bone=sk.find_bone(str(skin.get_bind_name(b)))
  binds.append(bone)
 var res:Dictionary={}
 for an in ["idle","walk","run"]:
  if not ap.has_animation(an):continue
  var length=ap.get_animation(an).length
  var nf=1 if an=="idle" else FOOT_PHASES
  var arr:Array=[]
  for f in range(nf):
   ap.play(an);ap.seek(length*float(f)/float(nf),true)
   var bx:Array=[]
   for b in range(binds.size()):
    bx.append(rel*(sk.get_bone_global_pose(maxi(int(binds[b]),0))*skin.get_bind_pose(b)) if int(binds[b])>=0 else rel)
   var am=ArrayMesh.new()
   for si in range(src.get_surface_count()):
    var a=src.surface_get_arrays(si)
    var vs:PackedVector3Array=a[Mesh.ARRAY_VERTEX]
    var ns=a[Mesh.ARRAY_NORMAL]
    var bi=a[Mesh.ARRAY_BONES];var wi=a[Mesh.ARRAY_WEIGHTS]
    if bi is PackedInt32Array and wi is PackedFloat32Array and vs.size()>0:
     var per=int((wi as PackedFloat32Array).size()/vs.size())
     var has_n=ns is PackedVector3Array and (ns as PackedVector3Array).size()==vs.size()
     for v in range(vs.size()):
      var p0=vs[v];var acc=Vector3.ZERO;var nacc=Vector3.ZERO;var wsum=0.0
      for j in range(per):
       var w=float(wi[v*per+j])
       if w<=0.0:continue
       var t:Transform3D=bx[int(bi[v*per+j])]
       acc+=(t*p0)*w;wsum+=w
       if has_n:nacc+=(t.basis*ns[v])*w
      vs[v]=acc/wsum if wsum>0.0 else rel*p0
      if has_n:ns[v]=nacc.normalized() if nacc.length_squared()>0.0 else ns[v]
     a[Mesh.ARRAY_VERTEX]=vs
     if has_n:a[Mesh.ARRAY_NORMAL]=ns
    a[Mesh.ARRAY_BONES]=null;a[Mesh.ARRAY_WEIGHTS]=null;a[Mesh.ARRAY_TANGENT]=null
    am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
    am.surface_set_material(si,src.surface_get_material(si))
   arr.append(am)
  res[an]=arr
 fig.queue_free()
 if not res.has("idle") or not res.has("walk"):return {}
 if not res.has("run"):res["run"]=res.walk
 foot_raw_cache[model]=res
 return res

## visual/r1 F5: velocidades de diseño de los ciclos de a pie (f5_personas_manifest: anim.walk/run.design_mps; zancada 1,15 y 2,13 m).
const FOOT_MPS = {"walk":1.15,"run":3.2}
## visual/r1 F5: andar del jefe de a pie según su velocidad en pantalla v_vis (m/s reales): quieto, idle; al paso, walk; desde 2,3 m/s
## (a escala 1; vuelve al paso bajo 1,8), run. speed_scale = v_vis / (velocidad de diseño · sc), así el pie no patina.
func _foot_step(rig:Dictionary,v_vis:float,moving:bool,sc:float,delta:float,far:bool)->void:
 var ap:AnimationPlayer=rig.get("ap",null)
 if ap==null:return
 rig.v=lerpf(float(rig.v),v_vis,1.0-exp(-delta*6.0))
 if far:
  if ap.is_playing():ap.pause()
  return
 var g:String=str(rig.gait)
 var v=float(rig.v)/maxf(sc,0.05)
 if not moving or float(rig.v)<0.08:g="idle"
 else:
  if g=="idle":g="walk"
  if g=="walk" and v>2.3:g="run"
  elif g=="run" and v<1.8:g="walk"
 if g!=str(rig.gait) or not ap.is_playing() or str(ap.current_animation)!=g:
  if ap.has_animation(g):ap.play(g,0.25)
  rig.gait=g
 ap.speed_scale=1.0 if g=="idle" else clampf(float(rig.v)/(float(FOOT_MPS[g])*maxf(sc,0.05)),0.5,3.0)

## Defecto de Godot 4.7.2 (ver _glb_parts): el color de vértice no siempre se aplica al albedo; se fuerza en las mallas del nodo.
func _fix_vc(n:Node)->void:
 for mi in n.find_children("*","MeshInstance3D",true,false):
  if mi.mesh==null:continue
  for si in range(mi.mesh.get_surface_count()):
   var m=mi.mesh.surface_get_material(si)
   if m is BaseMaterial3D:m.vertex_color_use_as_albedo=true

## visual/r1 F4: velocidad en pantalla de algo que las reglas mueven a pasos fijos (exploradores): distancia del último salto / tiempo
## desde el salto anterior (tope 0,5 s); sin saltos durante 0,75 s (quieto o en pausa), 0.
func _step_speed(entry:Dictionary,cur:Vector2,prev:Vector2,delta:float)->float:
 var vt=float(entry.get("vt",0.0))+delta
 var d=cur.distance_to(prev)
 if d>0.0001:
  var v=d/minf(vt,0.5)
  entry["vv"]=v if v<60.0 else 0.0
  vt=0.0
 elif vt>0.75:entry["vv"]=0.0
 entry["vt"]=vt
 return float(entry.get("vv",0.0))

## visual/r1 F4: andar del jefe. v_vis = velocidad en pantalla (m/s reales, incluye la aceleración del tiempo); v_game = velocidad
## del juego (m/s de juego; <0 si no hay) para elegir el andar; pace = paso pedido (walk/trot/gallop o ""); sc = escala de la figura.
## Quieto: idle. En marcha con el reloj parado (pausa): queda congelado en su andar. speed_scale = v_vis / (GAIT_MPS · sc).
func _gait_step(rig:Dictionary,v_vis:float,v_game:float,moving:bool,pace:String,sc:float,delta:float,far:bool)->void:
 var ap:AnimationPlayer=rig.get("ap",null)
 if ap==null:return
 rig.v=lerpf(float(rig.v),v_vis,1.0-exp(-delta*6.0))
 if far:
  if ap.is_playing():ap.pause()
  return
 var g:String=str(rig.gait)
 var v_sel=(v_game if v_game>=0.0 else float(rig.v))/maxf(sc,0.05)
 var frozen=false
 if not moving:g="idle"
 elif float(rig.v)<0.05:
  frozen=true
  if g=="idle":g="walk"
 else:
  if g=="idle":g="walk"
  if g=="walk" and v_sel>float(GAIT_UP.walk):g="trot"
  if g=="trot" and v_sel>float(GAIT_UP.trot):g="gallop"
  if g=="gallop" and v_sel<float(GAIT_DOWN.trot):g="trot"
  if g=="trot" and v_sel<float(GAIT_DOWN.walk):g="walk"
  if pace=="walk":g="walk"
  elif pace=="trot" and g=="gallop":g="trot"
 if g!=str(rig.gait) or not ap.is_playing() or str(ap.current_animation)!=g:
  if ap.has_animation(g):ap.play(g,0.3)
  rig.gait=g
 if g=="idle":ap.speed_scale=1.0
 elif frozen:ap.speed_scale=0.0
 else:
  # Tope ×4,5 con velocidad de juego (Justina a ×4); sin ella (Norte: la vista arrima el grupo con un lerp que arranca muy rápido), ×2,5.
  ap.speed_scale=clampf(float(rig.v)/(float(GAIT_MPS[g])*maxf(sc,0.05)),0.45,4.5 if v_game>=0.0 else 2.5)

func _create_group_j(unit:Dictionary):
 var id=str(unit.id)
 var root=Node3D.new();root.name="Grupo_"+id;add_child(root)
 root.position=Vector3(float(unit.x),_h(float(unit.x),float(unit.z)),float(unit.z))
 var mounted=bool(unit.get("mounted",true))
 var n=_group_count(unit)
 # visual/r1 F4: a caballo, el jefe animado va en el punto del grupo y el resto (n−1) en MultiMesh por pelaje detrás de él.
 var rig:Dictionary={}
 var parts:Array
 if mounted:
  rig=_mount_rig(root,str(HORSE_COATS[_coat_of(id.hash(),-1)]),"1806",id,false)
  parts=_mount_parts(root,"1806",maxi(n-1,1),id,id.hash())
 else:
  # visual/r1 F5: a pie, voluntario de 1806 (persona_voluntario_1806): jefe animado en el punto del grupo y la tropa (n−1) detrás.
  rig=_foot_rig(root,"persona_voluntario_1806",id)
  parts=_foot_parts(root,"persona_voluntario_1806",maxi(n-1,1),id)
 var ring=_ring_ribbon(Looks.ORO_VIEJO,root,"Aro_sel")   # seleccionado = oro viejo (visual/r1 F1: cinta sobre el suelo, mismo radio que el ancla y más ancha)
 selected_rings[id]=ring
 var tag=str(unit.get("tag","diseno"))
 var label=_label_j(_tag_glyph(tag)+" "+str(unit.name),Vector3(0,7.0,0),Color("e9d4aa"),30,root)
 unit_labels[id]=label
 _group_marker_j(id,root)
 var guion:Node3D=group_markers[group_markers.size()-1].node
 unit_nodes[id]={"guion":guion,"root":root,"figures":root,"mounted":mounted,"anims":[],"last":root.position,"parts":parts,"n":n,"yaw":-PI/2.0,"kind":"group","dirty":true,"pos2":Vector2(float(unit.x),float(unit.z)),"moving":false,"stage":"","form_k":0.0,"lod_far":false,"foot":Vector2.ZERO,"rig":rig}

## Paleta del paquete (04_paleta_diseno). Guion de lectura de cada grupo: color de DISEÑO para distinguir, NO es un estandarte histórico.
const GROUP_PAL = {"guemes":["a88943","4c372b"],"arias":["d8cfb8","4c372b"],"zavala":["33475b","d8cfb8"]}
var group_markers: Array = []
var label_far:Dictionary={}
var label_d:Dictionary={}
var ship_far_k=1.0
## visual/r1 F1: radio del aro de grupo (m, a escala real: abarca la banda de 14 m de jinetes) y tamaño de la ficha de pantalla (px).
const J_RING_R = 8.0
const J_TOKEN_PX = 14.0
## visual/r1 F1: el guion (asta de ~3,7 m) queda a tamaño real y se apaga más allá de esta distancia de cámara (antes crecía hasta x5,5).
const J_GUION_FAR_M = 240.0
# visual/r1 F3: se quitó far_k (agrandaba las figuras hasta x4,4 con la distancia): las figuras quedan a tamaño real y de lejos
# manda la ficha de 14 px; el LOD (FIG_LOD_FAR_M) aliviana el dibujo en vez de agrandar.

## Ficha de lectura de tamaño fijo en pantalla (shaders/justina_token.gdshader). shape: 0 caballeria, 1 voluntarios, 2 reserva, 3 explorador, 4 buque.
func _token_j(parent:Node3D,shape:int,color:Color,px:float,fade_a:float,fade_b:float,y:float,pulse:bool=false,drop:float=0.0)->MeshInstance3D:
 var q=QuadMesh.new();q.size=Vector2(1,1)
 var mi=MeshInstance3D.new();mi.mesh=q;mi.name="Ficha_"+str(shape)
 var sm=ShaderMaterial.new();sm.shader=load("res://shaders/justina_token.gdshader")
 sm.set_shader_parameter("tint",color);sm.set_shader_parameter("size_px",px);sm.set_shader_parameter("shape",shape)
 sm.set_shader_parameter("fade_a",fade_a);sm.set_shader_parameter("fade_b",fade_b);sm.set_shader_parameter("pulse",1.0 if pulse else 0.0);sm.set_shader_parameter("drop_px",drop)
 sm.render_priority=20
 mi.material_override=sm;mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 mi.extra_cull_margin=16384.0
 mi.position=Vector3(0,y,0)
 parent.add_child(mi)
 return mi

## Regla de color (P1, A3): aliado = celeste patriota #8DB8D6 en todas las fichas propias; la identidad la da la silueta (glifo), no el tono.
## Antes amarillo, turquesa y rosa pastel. Los exploradores llevan el mismo celeste, apenas más claro.
const TOKEN_COLORS={"guemes":"8db8d6","arias":"8db8d6","zavala":"8db8d6","scout_1":"a9cbe2","scout_2":"a9cbe2"}
const TOKEN_SHAPES={"guemes":0,"arias":1,"zavala":2}

func _group_marker_j(id:String,root:Node3D)->void:
 var pal:Array=GROUP_PAL.get(id,["7b6953","d8cfb8"])
 # R6: colores del guion desde banners.group_markers del JSON (Diseño; antes fijos en el codigo). Evita el azul-blanco-azul que se leia como bandera.
 var bj:Dictionary=M.get("banners",{}).get("group_markers",{})
 var cj:Dictionary=bj.get("colors",{}).get(id,{})
 if cj.has("pennant") and cj.has("trim"):pal=[str(cj.pennant).trim_prefix("#"),str(cj.trim).trim_prefix("#")]
 # P1, regla de color: ningún distintivo propio en rojo (el encarnado del guion de Güemes pasa a oro viejo).
 for k in range(pal.size()):
  var pc=Color(pal[k])
  if pc.r>pc.g*1.8 and pc.r>pc.b*1.8:pal[k]=Looks.ORO_VIEJO.to_html(false)
 var pole_c=Color(str(bj.get("pole",{}).get("color","#4C372B")))
 var m=Node3D.new();m.name="Guion_"+id;root.add_child(m)
 _cylinder(Vector3(0,1.9,0),0.05,3.8,pole_c,m)
 # Silueta por tipo (no solo color): guemes = guion rectangular con franja; arias = banderin largo y bajo; zavala = cuadrado.
 var fw=1.5;var fh=0.9
 if id=="arias":fw=1.9;fh=0.5
 elif id=="zavala":fw=1.0;fh=1.0
 var top=3.7
 _box(Vector3(fw*0.5,top-fh*0.5,0),Vector3(fw,fh,0.04),Color(pal[0]),m)
 _box(Vector3(fw*0.5,top-fh*0.5,0.03),Vector3(fw,fh*0.3,0.04),Color(pal[1]),m)
 if id=="arias":_box(Vector3(fw+0.25,top-fh*0.5,0),Vector3(0.5,fh*0.45,0.04),Color(pal[0]),m)
 # visual/r1 F1 (revierte R5/R6/D4/R-div1 a propósito): marcadores sutiles. El ancla es un aro celeste FINO a escala real que rodea
 # la tropa (sin halo relleno ni borde, sin crecer con la distancia), apenas sobre el suelo y con prueba de profundidad. Al elegir el
 # grupo el ancla se apaga y queda el aro de selección oro viejo (selected_rings), más ancho.
 var ring=_ring_ribbon(Color(Looks.CELESTE.r,Looks.CELESTE.g,Looks.CELESTE.b,0.75),root,"Ancla")
 # Ficha de pantalla chica (14 px): ubica al grupo de lejos sin taparlo; de cerca se desvanece y mandan las figuras.
 _token_j(root,int(TOKEN_SHAPES.get(id,0)),Color(str(TOKEN_COLORS.get(id,"d8cfb8"))),J_TOKEN_PX,45.0,95.0,1.0,false,0.0)
 group_markers.append({"node":m,"ring":ring,"root":root})

func _update_markers_j(cam:Camera3D)->void:
 # R6: el buque (objetivo del juego) crece hasta x2,3 con la distancia de camara para no quedar en 25 px (tamaño minimo en pantalla; simbolico).
 if is_instance_valid(ship):
  var ds=cam.global_position.distance_to(ship.global_position)
  # visual/r1 F1: tamaño real hasta ~200 m de cámara y tope x2 a lo lejos (antes x1,5 a x5,6, D4); ship_half del agua sigue a ks.
  var ks=clampf(ds/200.0,1.0,2.0)
  if absf(ks-ship_far_k)>0.03:
   ship_far_k=ks
   ship.scale=Vector3(SHIP_SX,SHIP_SY,SHIP_SZ)*ks
   if water_mat!=null:water_mat.set_shader_parameter("ship_half",Vector2(5.4,21.0)*ks)
   var pv=get_node_or_null("Pabellon_hipotesis")
   if pv!=null:pv.scale=Vector3.ONE*ks
 _spread_tokens_j(cam)
 for g in group_markers:
  var r:Node3D=g.root
  var d=cam.global_position.distance_to(r.global_position)
  # visual/r1 F1: guion a tamaño real (~3,7 m), sin crecer con la distancia; de lejos se apaga (la ficha chica ya ubica al grupo).
  g.node.visible=d<J_GUION_FAR_M
  var gid=str(r.name).trim_prefix("Grupo_")
  var sel_g=gid in selected_ids or gid==selected or selected=="all"
  g.ring.visible=not sel_g and not look_hide_overlays
  # El aro se centra en la huella real de la formación (las filas salen hacia atrás desde el punto del grupo) y la abarca.
  # visual/r1 F3: radio = media diagonal de la huella real (entry.foot, que deja _layout_group_j) + medio cuerpo y un margen.
  if unit_nodes.has(gid):
   var e:Dictionary=unit_nodes[gid]
   var mounted:bool=bool(e.get("mounted",true))
   var ft:Vector2=e.get("foot",Vector2.ZERO)
   var off=Vector3(0,0,ft.y*0.5).rotated(Vector3.UP,float(e.get("yaw",0.0)))
   # visual/r1 F4: margen a caballo = medio caballo criollo (1,25 m) + 0,45 m (antes 1,9 con el caballo viejo de 3,39 m a 0,82).
   var rad=sqrt(ft.x*ft.x+ft.y*ft.y*0.25)+(1.7 if mounted else 1.0)
   var c=r.position+off
   for rg in [g.ring,selected_rings.get(gid,null)]:
    if rg==null or not (rg as Node3D).visible and rg!=g.ring:continue
    (rg as Node3D).position=Vector3(off.x,0.0,off.z)
    _conform_ring(rg,c,rad,0.07 if rg==g.ring else 0.2)
  label_far[gid]=d>230.0
  label_d[gid]=d
  # visual/r1 F3: LOD de figuras (antes far_k: las agrandaba con la distancia).
  if unit_nodes.has(gid):
   var e2:Dictionary=unit_nodes[gid]
   var far=_lod_far_at(e2,d)
   if far!=bool(e2.get("lod_far",false)):
    e2["lod_far"]=far;_apply_fig_lod(e2);e2.dirty=true

# R5: fichas de grupos que quedan juntos se abren en abanico en pantalla (separacion en pixeles, no en metros), para no apilarse en un manchon.
func _spread_tokens_j(cam:Camera3D)->void:
 var toks:Array=[]
 for g in group_markers:
  var r:Node3D=g.root
  if not r.visible:continue
  var tk:Node3D=null
  for c in r.get_children():
   if str(c.name).begins_with("Ficha_"):tk=c;break
  if tk!=null:toks.append({"root":r,"tok":tk})
 var used:Dictionary={}
 var vh=maxf(get_viewport().get_visible_rect().size.y,1.0)
 var right:Vector3=cam.global_transform.basis.x;right.y=0.0
 right=right.normalized()
 for i in range(toks.size()):
  var a=toks[i]
  if used.has(i):continue
  var cluster=[i]
  for j in range(i+1,toks.size()):
   if not used.has(j) and (toks[j].root as Node3D).global_position.distance_to((a.root as Node3D).global_position)<26.0:cluster.append(j)
  for k in cluster:used[k]=true
  var n=cluster.size()
  for slot in range(n):
   var e=toks[cluster[slot]]
   var rt:Node3D=e.root
   var d=cam.global_position.distance_to(rt.global_position)
   var mpp=d*2.0*tan(deg_to_rad(cam.fov)*0.5)/vh
   var off=right*((float(slot)-float(n-1)*0.5)*(J_TOKEN_PX+8.0)*mpp) if n>1 else Vector3.ZERO   # visual/r1 F1: abanico a la medida de la ficha chica
   (e.tok as Node3D).position=Vector3(off.x,1.0,off.z)

func _ensign_j(s:Dictionary)->void:
 # Red Ensign (H1, HIPÓTESIS/Reconstrucción: la bandera concreta del Justina no está identificada; Union posterior a 1801 en el cantón).
 var sx=float(s.get("x",580.0));var sz=float(s.get("z",262.0));var heading=deg_to_rad(float(s.get("heading_deg",0.0)))
 var root=Node3D.new();root.name="Pabellon_hipotesis";add_child(root)
 root.position=Vector3(sx,level_m,sz);root.rotation.y=-heading
 var px=0.0;var pz=15.5   # popa (+z local con proa al norte)
 _cylinder(Vector3(px,12.0,pz),0.12,8.0,Color("4c372b"),root)
 # Ronda 2: pabellon de 3,2 x 1,8 m (antes 4,6 x 2,6): ~1/12 de la eslora, en proporcion con un mercante de 40 m.
 var fy=14.55
 _box(Vector3(px,fy,pz-1.6),Vector3(0.05,1.8,3.2),Color("b6453e"),root)         # campo rojo
 var cx=pz-0.62;var cy=fy+0.45
 _box(Vector3(px,cy,cx),Vector3(0.06,0.9,1.24),Color("33475b"),root)             # canton Union 1801 (esquema: aspas + cruz)
 var ang=atan2(0.9,1.24);var dl=sqrt(0.9*0.9+1.24*1.24)
 for sgn in [-1.0,1.0]:
  var w=_box(Vector3(px,cy,cx),Vector3(0.07,0.20,dl),Color("d8cfb8"),root);w.rotation.x=ang*sgn   # San Andres (blanca)
  var r2=_box(Vector3(px,cy,cx),Vector3(0.08,0.07,dl),Color("983c3c"),root);r2.rotation.x=ang*sgn  # San Patricio (roja, fina)
 _box(Vector3(px,cy,cx),Vector3(0.09,0.30,1.24),Color("d8cfb8"),root)             # cruz de San Jorge: blanca ...
 _box(Vector3(px,cy,cx),Vector3(0.09,0.9,0.30),Color("d8cfb8"),root)
 _box(Vector3(px,cy,cx),Vector3(0.10,0.15,1.24),Color("983c3c"),root)             # ... y roja
 _box(Vector3(px,cy,cx),Vector3(0.10,0.9,0.15),Color("983c3c"),root)

func _create_scouts_j():
 for sc in rules.state.get("scouts",[]):
  var id=str(sc.id)
  var root=Node3D.new();root.name="Explorador_"+id;add_child(root)
  root.position=Vector3(float(sc.x),_h(float(sc.x),float(sc.z)),float(sc.z))
  var fig=Node3D.new();fig.name="Figura";root.add_child(fig)
  # visual/r1 F4: el explorador es un jinete criollo animado (mismo armado que el jefe de grupo) con su lanza en la silla.
  var rig=_mount_rig(fig,str(HORSE_COATS[_coat_of(id.hash(),-1)]),"1806",str(id),false)
  var lance=MeshInstance3D.new();var lm=CylinderMesh.new();lm.top_radius=0.03;lm.bottom_radius=0.05;lm.height=3.8;lm.radial_segments=6
  lance.mesh=lm;lance.material_override=_mat(Color("6f5a3c"));lance.position=Vector3(0.45,0.75,-0.3);lance.rotation=Vector3(0.15,0,-0.12);(rig.seat as Node3D).add_child(lance)
  var ring=_ring_j(2.6,Looks.ORO_VIEJO,root)
  selected_rings[id]=ring
  _token_j(root,3,Color(str(TOKEN_COLORS.get(id,"d8d2c0"))),12.0,60.0,130.0,1.0,false,0.0)   # visual/r1 F1: 12 px (antes 26)
  var label=_label_j("◇ "+str(sc.name),Vector3(0,5.0,0),Color("dcd8c0"),26,root)
  unit_labels[id]=label
  unit_nodes[id]={"root":root,"figures":fig,"mounted":true,"anims":[],"last":root.position,"kind":"scout","yaw":-PI/2.0,"pos2":Vector2(float(sc.x),float(sc.z)),"moving":false,"stage":"","rig":rig}
  scout_nodes[id]=true

func _dir_yaw(prev:Vector2,cur:Vector2,yaw:float,delta:float)->float:
 var mv=cur-prev
 if mv.length()>0.02:
  return lerp_angle(yaw,atan2(-mv.x,-mv.y),minf(1.0,delta*5.0))
 return yaw

func _ring_visible(id:String,stage:String)->bool:
 return id in selected_ids or id==selected or selected=="all" or stage=="stumbling" or stage=="working"

func _ring_color(id:String,stage:String)->Color:
 # Regla de color (P1): tropezó = aviso ámbar; trabajando = información violeta (aclarado para leerse en el barro); elegido = oro viejo.
 if stage=="stumbling":return Looks.AMBAR
 if stage=="working":return Color("9a80d4")
 return Looks.ORO_VIEJO

func _update_group_j(u:Dictionary,delta:float):
 var id=str(u.id)
 if not unit_nodes.has(id):return
 var entry=unit_nodes[id]
 var mounted=bool(u.get("mounted",true))
 var n=_group_count(u)
 if entry.mounted!=mounted:
  for p in entry.parts:p.mmi.queue_free()
  # visual/r1 F4: al desmontar se va el jefe a caballo (la caballada queda en el vado, _update_parked_j); al volver a montar, vuelve.
  var rig0:Dictionary=entry.get("rig",{})
  if not rig0.is_empty() and is_instance_valid(rig0.node):(rig0.node as Node).queue_free()
  entry.rig={}
  if mounted:
   entry.rig=_mount_rig(entry.root,str(HORSE_COATS[_coat_of(id.hash(),-1)]),"1806",id,false)
   entry.parts=_mount_parts(entry.root,"1806",maxi(n-1,1),id,id.hash())
  else:
   # visual/r1 F5: desmontan → voluntarios de a pie (jefe animado + tropa _lod); el jefe a caballo ya se fue arriba.
   entry.rig=_foot_rig(entry.root,"persona_voluntario_1806",id)
   entry.parts=_foot_parts(entry.root,"persona_voluntario_1806",maxi(n-1,1),id)
  entry.mounted=mounted;entry.dirty=true;entry.n=n
  _apply_fig_lod(entry)
 elif n!=entry.n:
  if mounted:_resize_parts(entry.parts,maxi(n-1,1),id.hash())
  else:_resize_parts(entry.parts,maxi(n-1,1),id.hash())   # visual/r1 F5: el jefe de a pie va aparte; la tropa, en lotes por fase
  entry.n=n;entry.dirty=true
  _apply_fig_lod(entry)
 var root:Node3D=entry.root
 var cur=Vector2(float(u.x),float(u.z))
 var stage=str(u.get("stage",""))
 var moving=stage=="moving" or stage=="stumbling"
 # visual/r1 F4: las reglas avanzan en pasos fijos de 0,25 s; en marcha la vista extrapola con la velocidad del último paso y el
 # resto del acumulador (como mucho un paso), así el grupo se desliza parejo y el andar del jefe no patina a saltos.
 if stage=="moving":
  cur+=Vector2(float(u.get("vx",0.0)),float(u.get("vz",0.0)))*clampf(float(rules.state.get("accumulator",0.0)),0.0,0.25)
 var prev:Vector2=entry.pos2
 var yaw=_dir_yaw(prev,cur,float(entry.yaw),delta)
 var changed=cur.distance_squared_to(prev)>0.0001 or absf(yaw-float(entry.yaw))>0.002
 entry.pos2=cur;entry.yaw=yaw
 root.position=Vector3(cur.x,_h(cur.x,cur.y),cur.y)
 root.visible=float(u.strength)>0.0
 # R5: al abordar, las figuras suben a la cubierta (transicion de ~2,5 s); las fichas y aros quedan en la arena para seguir leyendose.
 var bk_t=1.0 if (stage=="boarding" and is_instance_valid(ship) and cur.distance_to(Vector2(float(M.ship.x),float(M.ship.z)))<DECK_REACH) else 0.0
 var bk0=float(entry.get("board_k",0.0))
 if absf(bk_t-bk0)>0.001:
  entry["board_k"]=move_toward(bk0,bk_t,delta/2.5);entry.dirty=true
 # visual/r1 F3: en marcha la tropa se cierra en columna y al parar se abre en línea (~1,2 s de transición).
 var fk0=float(entry.get("form_k",0.0));var fk1=1.0 if moving else 0.0
 if absf(fk1-fk0)>0.001:
  entry["form_k"]=move_toward(fk0,fk1,delta/1.2);entry.dirty=true
 var far=bool(entry.get("lod_far",false))
 # visual/r1 F4: andar del jefe según su velocidad en pantalla (m/s reales) y la del juego (vx, vz) con el paso pedido.
 var rig:Dictionary=entry.get("rig",{})
 if not rig.is_empty():
  var v_vis=cur.distance_to(prev)/maxf(delta,0.0001)
  if v_vis>60.0:v_vis=0.0   # salto (carga de partida, reubicación): no es marcha
  if bool(rig.get("foot",false)):
   # visual/r1 F5: de a pie, el andar sale de lo que avanza el jefe en el mundo (incluye la subida a la cubierta al abordar).
   var bkf=float(entry.get("board_k",0.0))
   _foot_step(rig,float(entry.get("lead_v",0.0)),moving or (bkf>0.001 and bkf<0.999),FOOT_SCALE,delta,far or not root.visible)
   _foot_troop_anim(entry.parts,rig,far or not root.visible)
  else:
   _gait_step(rig,v_vis,Vector2(float(u.get("vx",0.0)),float(u.get("vz",0.0))).length(),moving,str(u.get("pace","trot")),RIDER_SCALE,delta,far or not root.visible)
 # De lejos (LOD) no hay vaivén: solo se rehace la formación si el grupo se movió, giró o cambió.
 if root.visible and (changed or entry.dirty or (moving and not far) or stage=="routed" or entry.moving!=moving):
  _layout_group_j(entry,u,moving,stage)
  entry.dirty=false
 if bool(rig.get("foot",false)) and is_instance_valid(rig.get("node",null)):
  var lgp:Vector3=(rig.node as Node3D).global_position
  var lpv:Vector3=entry.get("lead_gp",lgp)
  var lv=Vector2(lgp.x-lpv.x,lgp.z-lpv.z).length()/maxf(delta,0.0001)
  entry["lead_v"]=lv if lv<60.0 else 0.0
  entry["lead_gp"]=lgp
 entry.moving=moving;entry.stage=stage
 var id_s=id
 var ring:MeshInstance3D=selected_rings[id_s]
 ring.visible=_ring_visible(id_s,stage) and not look_hide_overlays
 if ring.visible:
  if not ring.has_meta("ribbon"):ring.position.y=maxf(0.0,level_m-root.position.y)+0.3
  (ring.material_override as StandardMaterial3D).albedo_color=_ring_color(id_s,stage)
 _update_label_j(id_s,u,stage,root,7.0)

func _layout_group_j(entry:Dictionary,u:Dictionary,moving:bool,stage:String):
 var n:int=entry.n
 var mounted:bool=entry.mounted
 # visual/r1 F3: formación de tropa a tamaño real (sin far_k): filas y columnas con leve desorden, de frente a la marcha
 # (las filas salen hacia atrás desde el punto del grupo), caballería más abierta que la gente a pie; dispersos = huella x2,4.
 var sc=RIDER_SCALE if mounted else FOOT_SCALE
 var form_k:float=float(entry.get("form_k",0.0))
 var spread=2.4 if stage=="routed" else 1.0
 var far=bool(entry.get("lod_far",false))
 var gseed=str(u.id).hash()
 var dims=_form_dims(n,mounted,form_k>0.5)
 var yaw:float=entry.yaw
 var rootpos:Vector3=entry.root.position
 var t=elapsed_visual
 var bk=float(entry.get("board_k",0.0))
 var gi=maxi(unit_nodes.keys().find(str(u.id)),0)
 # visual/r1 F4: a caballo, el jefe animado ocupa el punto del grupo y la tropa (n−1 figuras) forma una fila más atrás.
 var rig:Dictionary=entry.get("rig",{})
 var z_lead=0.0
 var gn0:Node3D=entry.get("guion",null)
 if is_instance_valid(gn0) and not mounted:gn0.position=Vector3.ZERO;gn0.rotation=Vector3.ZERO
 if mounted and not rig.is_empty() and is_instance_valid(rig.node):
  var lead:Node3D=rig.node
  lead.position=Vector3(0.0,_h(rootpos.x,rootpos.z)-rootpos.y,0.0)
  lead.rotation=Vector3(0.0,yaw,0.0)
  lead.scale=Vector3.ONE*sc
  # visual/r1 F4: el guion lo lleva el jefe: asta al costado derecho de su caballo (antes en el centro del grupo, ahora lo atravesaría)
  # y paño hacia atrás. Desmontados, vuelve al punto del grupo.
  var gn:Node3D=entry.get("guion",null)
  if is_instance_valid(gn):
   gn.position=lead.position+Vector3(0.45,0.55,0.15).rotated(Vector3.UP,yaw)
   gn.rotation=Vector3(0.0,yaw-PI*0.5,0.0)
  n=maxi(n-1,1)
  z_lead=_gaps(true).y*sc
  dims=_form_dims(n,mounted,form_k>0.5)
 elif not mounted and not rig.is_empty() and is_instance_valid(rig.node):
  # visual/r1 F5: a pie, el jefe animado (persona_voluntario_1806) va en el punto del grupo y la tropa (n−1) forma una fila más atrás;
  # al abordar sube a la cubierta con el mismo arco que la tropa, adelante de ella. El guion va a su derecha.
  var lead_f:Node3D=rig.node
  var loff=Vector3.ZERO;var lgy=_h(rootpos.x,rootpos.z)-rootpos.y
  if bk>0.0 and is_instance_valid(ship):
   var tw0:Vector3=ship.global_transform*Vector3(0.0,DECK_Y,(float(gi%3)-1.0)*2.3-0.6)
   var sm0=bk*bk*(3.0-2.0*bk)
   loff=Vector3(lerpf(0.0,tw0.x-rootpos.x,sm0),0.0,lerpf(0.0,tw0.z-rootpos.z,sm0))
   lgy=lerpf(lgy,tw0.y-rootpos.y,sm0)+0.9*sin(sm0*PI)
  lead_f.position=Vector3(loff.x,lgy,loff.z)
  lead_f.rotation=Vector3(0.0,yaw,0.0)
  lead_f.scale=Vector3.ONE*sc
  if is_instance_valid(gn0):
   gn0.position=lead_f.position+Vector3(0.42,0.0,0.1).rotated(Vector3.UP,yaw)
   gn0.rotation=Vector3(0.0,yaw-PI*0.5,0.0)
  n=maxi(n-1,1)
  z_lead=_gaps(false).y*sc
  dims=_form_dims(n,mounted,form_k>0.5)
 for i in range(n):
  var f=_form_slot(i,n,mounted,sc,form_k,gseed)
  f.y+=z_lead
  var off=Vector3(f.x*spread,0,f.y*spread).rotated(Vector3.UP,yaw)
  var wx=rootpos.x+off.x;var wz=rootpos.z+off.z
  var gy=_h(wx,wz)-rootpos.y
  if bk>0.0 and is_instance_valid(ship):
   var s=_lod_slot(i,n);var row=s/dims.x;var lane=s%dims.x
   var loc=Vector3((float(lane)-float(dims.x-1)*0.5)*0.30,DECK_Y,(float(gi%3)-1.0)*2.3+(float(row)-1.0)*0.28)
   var tw:Vector3=ship.global_transform*loc
   var smooth=bk*bk*(3.0-2.0*bk)
   off=Vector3(lerpf(off.x,tw.x-rootpos.x,smooth),0.0,lerpf(off.z,tw.z-rootpos.z,smooth))
   gy=lerpf(gy,tw.y-rootpos.y,smooth)+0.9*sin(smooth*PI)   # arco: trepan y saltan al casco
  var bob=0.0
  var pitch=0.0
  if moving and not far:
   # visual/r1 F5: la tropa de a pie con cuadros horneados ya sube y baja con su paso; el vaivén queda para los caballos.
   if mounted or not (entry.parts[0] as Dictionary).has("poses"):bob=0.07*absf(sin(t*7.0+float(i)*0.9))
   if stage=="stumbling":pitch=0.18*sin(t*9.0+float(i))
  var basis=Basis.from_euler(Vector3(pitch,yaw+f.z,0.0)).scaled_local(Vector3.ONE*sc)
  var xf=Transform3D(basis,Vector3(off.x,gy+bob,off.z))
  _set_fig(entry.parts,i,xf)
 entry["foot"]=(_form_extent(n,mounted,sc,form_k)+Vector2(0.0,z_lead))*spread

func _update_label_j(id:String,u,stage:String,root:Node3D,h:float):
 var label:Label3D=unit_labels[id]
 var txt:String
 # R7: rotulos apilados escalonados en altura segun la distancia de camara (las 5 fichas no se pisan); cerca vuelven a su altura.
 var rank=unit_nodes.keys().find(id)
 var far_stack=label_far.get(id,false) and not (id in selected_ids or id==selected) and rank>=0
 label.position.y=h+(float(rank)*float(label_d.get(id,0.0))*0.042 if far_stack else 0.0)
 if u.has("strength"):
  var tag=str(u.get("tag","diseno"))
  var short=str(u.name).split(" · ")[0]
  var sel=id in selected_ids or id==selected
  # Lo no probado (tradición) se marca siempre en el rótulo del mundo, con el nombre completo para que no parezca un hecho.
  var full=sel or tag=="tradicion"
  if label_far.get(id,false) and not sel:
   # Lejos: rotulo compacto (numero, marca de fuente y fuerza) para que 5 grupos no se tapen entre si.
   txt=_tag_glyph(tag)+" "+str(u.name).split(" ")[0]+" · "+str(int(round(float(u.strength))))+"%"
   var st0=str(J_STAGE_TEXT.get(stage,""))
   if st0!="":txt+=" · "+st0
   if label.text!=txt:label.text=txt
   label.modulate=Color("ddd7bf")
   return
  txt=_tag_glyph(tag)+" "+(str(u.name) if full else short)+(" (tradición)" if tag=="tradicion" else "")+" · "+str(int(round(float(u.strength))))+"%"
 else:
  txt="◇ "+str(u.name)+(" · "+str(int(u.get("hp",3)))+"/3" if true else "")
 var st=str(J_STAGE_TEXT.get(stage,""))
 if st!="":txt+=" · "+st
 if label.text!=txt:label.text=txt
 var sel2=id in selected_ids or id==selected
 label.modulate=Color("f1d290") if sel2 else Color("ddd7bf")
 if stage=="stumbling":label.modulate=Color("e8a85a")   # aviso = ámbar (el rojo es del enemigo)

func _update_scout_j(sc:Dictionary,delta:float):
 var id=str(sc.id)
 if not unit_nodes.has(id):return
 var entry=unit_nodes[id]
 var root:Node3D=entry.root
 var cur=Vector2(float(sc.x),float(sc.z))
 var stage=str(sc.get("stage","idle"))
 var moving=stage=="moving" or stage=="probing" or stage=="marking"
 var prev:Vector2=entry.pos2
 var yaw=_dir_yaw(prev,cur,float(entry.yaw),delta)
 entry.pos2=cur;entry.yaw=yaw
 root.position=Vector3(cur.x,_h(cur.x,cur.y),cur.y)
 var fig:Node3D=entry.figures
 fig.rotation=Vector3(0,yaw,0)
 fig.position.y=0.0
 # visual/r1 F4: el andar del caballo reemplaza el vaivén; el explorador perdido queda caído y quieto.
 var rig:Dictionary=entry.get("rig",{})
 if not rig.is_empty():
  _gait_step(rig,_step_speed(entry,cur,prev,delta),-1.0,moving and stage!="lost",str(sc.get("pace","")),RIDER_SCALE,delta,not root.visible)
 if stage=="lost":
  fig.rotation=Vector3(0,yaw,PI*0.5);fig.position.y=0.6
 elif moving and rig.is_empty():
  fig.position.y=0.06*absf(sin(elapsed_visual*7.0))
 var ring:MeshInstance3D=selected_rings[id]
 ring.visible=_ring_visible(id,stage) and stage!="lost" and not look_hide_overlays
 if ring.visible:ring.position.y=maxf(0.0,level_m-root.position.y)+0.3
 _update_label_j(id,sc,stage,root,5.0)

func _update_parked_j():
 # Caballos de los grupos desmontados: quedan estacionados en el vado del abordaje (board_point).
 var bp=Vector2.ZERO
 if rules.has_method("board_point"):bp=rules.board_point()
 else:
  var c=M.ship.capture.boarding_point;bp=Vector2(float(c[0]),float(c[1]))
 var gi=0
 for u in rules.state.units:
  var id=str(u.id)
  if not bool(u.get("mounted",true)) and float(u.strength)>0.0 and not parked_j.has(id):
   var n=_group_count(u)
   var holder=Node3D.new();holder.name="Caballos_"+id;add_child(holder)
   # visual/r1 F4: caballada de criollos sin jinete, con los pelajes de su grupo (antes horse_only, el caballo viejo de 3,39 m a 0,82).
   var parts=_mount_parts(holder,"1806",n,id,id.hash(),false)
   var lanes=clampi(int(ceil(sqrt(float(n)*0.9))),1,4)
   var base=bp+Vector2(-4.0,float(gi-1)*9.0)
   for i in range(n):
    var row=i/lanes;var lane=i%lanes
    var p=base+Vector2(-float(row)*2.9,(float(lane)-float(lanes-1)*0.5)*1.6)
    var basis=Basis.from_euler(Vector3(0,PI*0.5,0)).scaled_local(Vector3.ONE*RIDER_SCALE)
    var xf=Transform3D(basis,Vector3(p.x,_h(p.x,p.y),p.y))
    _set_fig(parts,i,xf)
   parked_j[id]=holder
  gi+=1
 var deep=false
 if rules.has_method("water_depth_at"):deep=float(rules.water_depth_at(bp.x,bp.y))>1.3
 for id in parked_j:parked_j[id].visible=not deep

# ---------------------------------------------------------------- conocimiento (sondas, balizas, boyas)
func _depth_color(depth:float,alpha:float)->Color:
 if depth<=0.6:return Color(0.30,0.85,0.45,alpha)
 if depth<=1.3:return Color(0.96,0.72,0.20,alpha)
 return Color(0.90,0.25,0.20,alpha)

func _kn_mmi(name_s:String,mesh:Mesh,mat:Material)->MultiMeshInstance3D:
 var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh;mm.instance_count=0
 var mmi=MultiMeshInstance3D.new();mmi.name=name_s;mmi.multimesh=mm;mmi.material_override=mat
 mmi.custom_aabb=AABB(Vector3(0,-6,0),Vector3(map_w,40,map_h));mmi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 knowledge_root.add_child(mmi)
 return mmi

## Crea una sola vez los recursos del conocimiento (malla de franjas, lotes de postes/boyas/estacas, material compartido).
func _knowledge_nodes_j():
 kn_strips_mesh=ArrayMesh.new()
 kn_strips=MeshInstance3D.new();kn_strips.name="Franjas";kn_strips.mesh=kn_strips_mesh;kn_strips.material_override=_overlay_mat()
 kn_strips.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;kn_strips.custom_aabb=AABB(Vector3(0,-1,0),Vector3(map_w,2,map_h))
 knowledge_root.add_child(kn_strips)
 var post=CylinderMesh.new();post.top_radius=0.07;post.bottom_radius=0.1;post.height=2.6;post.radial_segments=6
 var ball=SphereMesh.new();ball.radius=0.55;ball.height=1.1;ball.radial_segments=10;ball.rings=5
 var stake=CylinderMesh.new();stake.top_radius=0.04;stake.bottom_radius=0.04;stake.height=2.4;stake.radial_segments=5
 kn_posts=_kn_mmi("Balizas",post,_mat(Color("efe3b0"),0.7,true))
 kn_buoys_red=_kn_mmi("BoyasRojas",ball,_mat(Color("d4382a"),0.5,true))
 kn_buoys_green=_kn_mmi("BoyasVerdes",ball,_mat(Color("37b86a"),0.5,true))
 kn_stakes=_kn_mmi("Estacas",stake,_mat(Color("e9e2c6")))

func _kn_set(mmi:MultiMeshInstance3D,xf:Array)->void:
 var mm:MultiMesh=mmi.multimesh
 if mm.instance_count!=xf.size():mm.instance_count=xf.size()
 for i in range(xf.size()):mm.set_instance_transform(i,xf[i])

## Rótulo reutilizable (pool): no se crean Label3D nuevos si ya hay libres.
func _kn_label(text_value:String,pos:Vector3,color:Color)->void:
 var lab:Label3D
 if kn_label_used<kn_labels.size():lab=kn_labels[kn_label_used]
 else:
  lab=_label_j("",pos,color,28,knowledge_root);kn_labels.append(lab)
 kn_label_used+=1
 lab.text=text_value;lab.position=pos;lab.modulate=color;lab.visible=true

## visual/r1 F6: cajas aproximadas en pantalla (coordenadas de la interfaz) de los rótulos 3D de lo hallado (pozos y vados), para que
## la flecha «Buque ▸» del borde no los tape (a 2560×1440 caía sobre «▲ Pozo del banco»). Label3D de tamaño fijo: ~0,36 del cuerpo de letra
## por carácter de ancho y 0,8 de alto, más el contorno (medido en las capturas de f6_jn). view_scale: píxeles de ventana por píxel de interfaz.
func kn_label_screen_rects(camera:Camera3D,view_scale:float=1.0)->Array:
 var out:Array=[]
 if not is_instance_valid(knowledge_root) or not knowledge_root.is_visible_in_tree():return out
 for i in range(mini(kn_label_used,kn_labels.size())):
  var lab:Label3D=kn_labels[i]
  if not is_instance_valid(lab) or not lab.visible or camera.is_position_behind(lab.global_position):continue
  var sz=Vector2(float(lab.text.length())*float(lab.font_size)*0.36+12.0,float(lab.font_size)*0.8+8.0)
  var c=camera.unproject_position(lab.global_position)/maxf(view_scale,0.01)
  out.append(Rect2(c-sz*0.5,sz))
 return out

func _rebuild_knowledge_j():
 kn_rebuilds+=1
 kn_label_used=0
 var verts=PackedVector3Array();var cols=PackedColorArray();var idx=PackedInt32Array()
 var posts=[]
 var y=0.09
 for p in rules.state.get("probes",[]):
  var pts:Array=p.get("pts",[])
  if pts.size()<1:continue
  var marked=str(p.get("kind",""))=="marked"
  var half=float(p.get("width",6.0))*0.5
  var carry=0.0
  if pts.size()==1:
   pts=[pts[0],pts[0]]
  for i in range(pts.size()-1):
   var a=_pt(pts[i]);var b=_pt(pts[i+1])
   var seg=a.distance_to(b)
   if seg<0.001:continue
   var dir=(b-a)/seg;var nrm=Vector2(-dir.y,dir.x)
   var steps=maxi(1,int(ceil(seg/3.0)))
   for s in range(steps):
    var t0=float(s)/float(steps);var t1=float(s+1)/float(steps)
    var p0=a.lerp(b,t0);var p1=a.lerp(b,t1)
    var mid=a.lerp(b,(t0+t1)*0.5)
    var depth=level_m-_h(mid.x,mid.y)
    var col=_depth_color(depth,0.62 if marked else 0.55)
    var base=verts.size()
    verts.append(Vector3(p0.x+nrm.x*half,y,p0.y+nrm.y*half));verts.append(Vector3(p0.x-nrm.x*half,y,p0.y-nrm.y*half))
    verts.append(Vector3(p1.x+nrm.x*half,y,p1.y+nrm.y*half));verts.append(Vector3(p1.x-nrm.x*half,y,p1.y-nrm.y*half))
    for _k in range(4):cols.append(col)
    idx.append_array(PackedInt32Array([base,base+1,base+2,base+1,base+3,base+2]))
    if marked:
     # Borde claro a cada lado.
     for side in [1.0,-1.0]:
      var eb=verts.size()
      var o0=Vector2(p0.x+nrm.x*half*side,p0.y+nrm.y*half*side);var o1=Vector2(p1.x+nrm.x*half*side,p1.y+nrm.y*half*side)
      var inward=-nrm*side*0.5
      verts.append(Vector3(o0.x,y+0.01,o0.y));verts.append(Vector3(o0.x+inward.x,y+0.01,o0.y+inward.y))
      verts.append(Vector3(o1.x,y+0.01,o1.y));verts.append(Vector3(o1.x+inward.x,y+0.01,o1.y+inward.y))
      for _k in range(4):cols.append(Color(0.97,0.95,0.82,0.9))
      idx.append_array(PackedInt32Array([eb,eb+1,eb+2,eb+1,eb+3,eb+2]))
   if marked:
    var d=carry
    while d<=seg:
     posts.append(a+dir*d);d+=10.0
    carry=d-seg
 # La malla de franjas se reescribe en su lugar (misma ArrayMesh, mismo material).
 kn_strips_mesh.clear_surfaces()
 if verts.size()>0:
  var arr=[];arr.resize(Mesh.ARRAY_MAX);arr[Mesh.ARRAY_VERTEX]=verts;arr[Mesh.ARRAY_COLOR]=cols;arr[Mesh.ARRAY_INDEX]=idx
  kn_strips_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr)
 # Balizas (postes) cada 10 m de vado marcado.
 var post_xf=[]
 for q in posts:
  var top=maxf(_h(q.x,q.y),level_m)
  post_xf.append(Transform3D(Basis.IDENTITY,Vector3(q.x,1.3+(top-level_m),q.y)))
 _kn_set(kn_posts,post_xf)
 # Boyas: pozos hallados (rojas) y vados hallados (verdes), con rótulo.
 var red_xf=[];var green_xf=[];var stake_xf=[]
 for hz in M.get("hazards",[]):
  if not (str(hz.id) in rules.state.get("hazards_found",[])):continue
  var c=hz.center
  var pv=Vector2(float(c[0]),float(c[1]))
  red_xf.append(Transform3D(Basis.IDENTITY,Vector3(pv.x,0.3,pv.y)));stake_xf.append(Transform3D(Basis.IDENTITY,Vector3(pv.x,1.2,pv.y)))
  _kn_label("▲ "+str(hz.get("name","Pozo")),Vector3(pv.x,3.4,pv.y),Color("f2a99c"))
 for fd in M.get("fords",[]):
  if not (str(fd.id) in rules.state.get("fords_found",[])):continue
  var pts2:Array=[]
  if fd.has("centerline"):pts2=fd.centerline
  elif fd.has("center"):pts2=[fd.center]
  var mid2=Vector2.ZERO
  for q in pts2:
   var v=Vector2(float(q[0]),float(q[1]));mid2+=v
   green_xf.append(Transform3D(Basis.IDENTITY,Vector3(v.x,0.3,v.y)));stake_xf.append(Transform3D(Basis.IDENTITY,Vector3(v.x,1.2,v.y)))
  if pts2.size()>0:
   mid2/=float(pts2.size())
   _kn_label("▲ "+str(fd.get("name","Vado")),Vector3(mid2.x,3.4,mid2.y),Color("a6e6bd"))
 _kn_set(kn_buoys_red,red_xf);_kn_set(kn_buoys_green,green_xf);_kn_set(kn_stakes,stake_xf)
 for i in range(kn_label_used,kn_labels.size()):kn_labels[i].visible=false

func _knowledge_signature()->String:
 var s=str(snappedf(level_m,0.02))
 var total=0
 for p in rules.state.get("probes",[]):total+=int(p.get("pts",[]).size())*7+1
 s+="|"+str(rules.state.get("probes",[]).size())+"|"+str(total)
 s+="|"+str(rules.state.get("hazards_found",[]))+"|"+str(rules.state.get("fords_found",[]))
 return s

# ---------------------------------------------------------------- bucle por cuadro
func _apply_level_j(lv:float):
 level_applied=lv
 for n in water_nodes:n.position.y=lv
 water_mat.set_shader_parameter("water_level",lv)
 terrain_mat.set_shader_parameter("water_level",lv)
 _update_refs_j()
 knowledge_root.position.y=lv
 if is_instance_valid(exposure_root):exposure_root.position.y=lv+0.18

func _update_justina(delta:float):
 elapsed_visual+=delta
 level_m=float(rules.water_level_m())
 if absf(level_m-level_applied)>0.0004:_apply_level_j(level_m)
 var sv=int(rules.state.get("state_version",0))
 if sv!=state_version_seen:
  state_version_seen=sv
  var sig=_knowledge_signature()
  if sig!=knowledge_sig:
   knowledge_sig=sig;_rebuild_knowledge_j()
  _update_extra_labels_j()
  path_timer=1.0
 for u in rules.state.units:_update_group_j(u,delta)
 for sc in rules.state.get("scouts",[]):_update_scout_j(sc,delta)
 _update_parked_j()
 _update_ship_j(delta)
 _update_effects_j(delta)
 _update_beacons_j()
 _update_layers_j()
 path_timer+=delta
 if path_timer>0.5:
  var signature=selected+str(selected_ids)+str(show_paths)
  for unit in rules.state.units:signature+=str(unit.get("path",[]).size())+str(unit.stage)+("%d" % int(float(unit.x)))
  if signature!=last_path_signature:last_path_signature=signature;_refresh_paths_j()
  path_timer=0.0
 if minimap_requested:
  minimap_timer+=delta
  if minimap_timer>=float(M.get("minimap",{}).get("refresh_s",2.0)):
   minimap_timer=0.0;minimap_refresh(false)

func _update_ship_j(delta:float):
 if not is_instance_valid(ship):return
 var ss=rules.ship_state() if rules.has_method("ship_state") else {}
 var active=bool(ss.get("fire_support_active",false))
 if active and battery_pos!=Vector3.ZERO:
  battery_timer-=delta
  if battery_timer<=0.0:
   battery_timer=randf_range(1.0,1.8)
   var bp=Vector2(battery_pos.x,battery_pos.z+randf_range(-5.0,5.0))
   _cannon_effect_j(bp,Vector2(float(M.ship.x),float(M.ship.z))+Vector2(randf_range(-10,10),randf_range(-14,14)))
 else:
  battery_timer=0.0
 var hd=float(ss.get("heading_deg",M.ship.get("heading_deg",0.0)))
 ship.rotation.y=-deg_to_rad(hd)
 # R4: con la bajante el casco apoya en el banco: escora a babor y se asienta (aspecto; la regla del vado no cambia).
 # R5: consume ship.grounded_visual (apoyado bajo grounded_below_m, flota sobre floating_above_m): escora, asiento y anillo de fango.
 var gv:Dictionary=M.get("ship",{}).get("grounded_visual",{})
 var g_lo=float(gv.get("grounded_below_m",0.35));var g_hi=float(gv.get("floating_above_m",0.9))
 var gk=1.0-clampf((level_m-g_lo)/maxf(g_hi-g_lo,0.05),0.0,1.0)   # 1 = apoyado, 0 = flotando
 var heel:Array=gv.get("heel_deg",[4.0,7.0])
 ship.rotation.z=lerpf(0.045,deg_to_rad(float(heel[1])),gk);ship.rotation.x=lerpf(0.012,0.034,gk)
 ship.position.y=ship_y0-(float(gv.get("sink_m",0.6))+1.1+0.55*ship_far_k)*gk   # R7: +1,1 m: la quilla queda enterrada en el banco (antes se veia luz bajo el casco)
 _update_boarding_fx_j(delta)
 _update_pennants_j()
 if is_instance_valid(ship_mud):
  ship_mud.visible=gk>0.02
  ship_mud.position.y=level_m+0.04
  (ship_mud.material_override as ShaderMaterial).set_shader_parameter("strength",gk)
 if water_mat!=null and absf(hd-ship_hd_applied)>0.01:
  ship_hd_applied=hd
  water_mat.set_shader_parameter("ship_fwd",Vector2(sin(deg_to_rad(hd)),-cos(deg_to_rad(hd))))

# R5: el abordaje se ve: humo y fogonazos sobre cubierta mientras hay grupos a bordo y una bandera que sube con la captura.
var boarding_fx_t = 0.0
var capture_flag: Node3D
var capture_flag_cloth: Node3D
func _deck_world(lx:float,lz:float,ly:float=DECK_Y)->Vector3:
 return ship.global_transform*Vector3(lx,ly,lz)

func _make_capture_flag_j():
 capture_flag=Node3D.new();capture_flag.name="Bandera_captura";add_child(capture_flag)
 _cylinder(Vector3(0,5.0,0),0.14,10.0,Color("4c372b"),capture_flag)
 capture_flag_cloth=Node3D.new();capture_flag.add_child(capture_flag_cloth)
 # Señal de captura: paño ocre con franja oscura (color de diseño del bando criollo; NO es una bandera historica ni la argentina).
 _box(Vector3(0,0,-1.6),Vector3(0.06,1.6,3.2),Color("e2bc72"),capture_flag_cloth)
 _box(Vector3(0.04,0,-1.6),Vector3(0.06,0.5,3.2),Color("3b2a5c"),capture_flag_cloth)   # P1: franja violeta honda (antes bermellón: el rojo es del enemigo)
 capture_flag.visible=false

func _update_boarding_fx_j(delta:float)->void:
 var on_deck=0
 for u in rules.state.units:
  if str(u.get("stage",""))=="boarding" and float(u.strength)>0.0 and unit_nodes.has(str(u.id)) and float(unit_nodes[str(u.id)].get("board_k",0.0))>0.5:on_deck+=1
 if capture_flag==null:_make_capture_flag_j()
 var cap=clampf(float(rules.state.get("capture",0.0))/100.0,0.0,1.0)
 var ks=ship.scale.x/SHIP_SX
 capture_flag.visible=cap>0.02
 if capture_flag.visible:
  capture_flag.global_position=_deck_world(0.0,3.6);capture_flag.rotation.y=ship.rotation.y;capture_flag.scale=Vector3.ONE*ks
  capture_flag_cloth.position.y=1.2+cap*7.6
  capture_flag_cloth.rotation.y=sin(elapsed_visual*2.2)*0.18
 var ens=get_node_or_null("Pabellon_hipotesis")
 if ens!=null:ens.visible=cap<0.995
 if on_deck>0 and not smoke_pool.is_empty():
  boarding_fx_t-=delta
  if boarding_fx_t<=0.0:
   boarding_fx_t=randf_range(0.25,0.6)/float(mini(on_deck,3))
   var p=_deck_world(randf_range(-0.7,0.7),randf_range(-5.0,5.0)*0.45,DECK_Y+0.6)
   _fire_smoke(p,Vector3(randf_range(-0.4,0.4),1.0,randf_range(-0.4,0.4)).normalized(),false)
   if is_instance_valid(fire_flash) and randf()<0.5:fire_flash.global_position=p;fire_flash.light_energy=2.2

func _update_extra_labels_j():
 for e in extra_labels:
  var show=true
  if str(e.cond)=="known_or_emerged":
   var emerged=level_m-_h(e.x,e.z)<=0.0
   var known=false
   if rules.has_method("knowledge_at"):known=str(rules.knowledge_at(float(e.x),float(e.z)))!="unknown"
   show=emerged or known
  e.label.visible=show

func _update_layers_j():
 var want=exposure_user_on if exposure_forced else selected_ids.size()>0
 exposure_root.visible=bool(layer_state.exposure) and want and not look_hide_overlays
 if exposure_root.visible:
  var ss=rules.ship_state() if rules.has_method("ship_state") else {}
  exposure_root.scale=Vector3.ONE
  var mesh_inst=exposure_root.get_child(0) as MeshInstance3D
  if mesh_inst!=null:mesh_inst.transparency=0.45 if bool(ss.get("fire_support_active",false)) else 0.0

func _refresh_paths_j():
 if not is_instance_valid(route_root):return
 if path_instances==null:
  var mm0=MultiMesh.new();mm0.transform_format=MultiMesh.TRANSFORM_3D
  var disc=CylinderMesh.new();disc.top_radius=0.55;disc.bottom_radius=0.55;disc.height=0.12;disc.radial_segments=8
  mm0.mesh=disc
  path_instances=MultiMeshInstance3D.new();path_instances.multimesh=mm0;path_instances.custom_aabb=AABB(Vector3(0,-5,0),Vector3(map_w,30,map_h))
  var pm=_mat(Color("e9c678"),0.6,true);pm.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
  path_instances.material_override=pm;path_instances.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  route_root.add_child(path_instances)
 var xf=[]
 if show_paths and bool(layer_state.paths):
  for u in rules.state.units:
   var id=str(u.id)
   if not (id==selected or selected=="all" or id in selected_ids):continue
   var points:Array=u.get("path",[])
   for i in range(points.size()):
    if i%2!=0 and i!=points.size()-1:continue
    var v=_pt(points[i])
    xf.append(Transform3D(Basis.IDENTITY,Vector3(v.x,maxf(_h(v.x,v.y),level_m)+0.2,v.y)))
 var mm:MultiMesh=path_instances.multimesh
 mm.instance_count=xf.size()
 for i in range(xf.size()):mm.set_instance_transform(i,xf[i])

## Diagnóstico: máxima diferencia (m) entre la altura que dibuja la Vista (muestreo a J_CELL de rules.terrain_height_at) y la de Reglas en n puntos al azar.
func terrain_consistency_error(n:int=400)->float:
 if not justina:return 0.0
 var rng=RandomNumberGenerator.new();rng.seed=77
 var worst=0.0
 for i in range(n):
  var x=rng.randf_range(0.0,map_w);var z=rng.randf_range(0.0,map_h)
  worst=maxf(worst,absf(_h(x,z)-float(rules.terrain_height_at(x,z))))
 return worst

# ---------------------------------------------------------------- balizas de escala y encuadre
## Poste de señal de tamaño casi constante en pantalla sobre el buque, la batería y la Plaza de Toros: a 500 m se ve dónde están aunque el modelo mida pocos píxeles. No lleva bandera ni insignia.
func _beacons_j():
 for id in landmark_info:
  var info=landmark_info[id]
  if not (str(info.type) in BEACON_TYPES):continue
  var col=_tag_color(str(info.tag)).lerp(Color("f4efdc"),0.5)
  var root=Node3D.new();root.name="Baliza_"+id
  var base_y=level_m if str(info.type)=="ship" else _h(float(info.x),float(info.z))
  root.position=Vector3(float(info.x),base_y,float(info.z))
  var height=70.0 if str(info.type)=="ship" else 46.0
  var pole=CylinderMesh.new();pole.top_radius=0.5;pole.bottom_radius=0.5;pole.height=1.0;pole.radial_segments=6
  var pm=MeshInstance3D.new();pm.mesh=pole;pm.material_override=_beacon_mat(Color(col.r,col.g,col.b,0.45))
  pm.scale=Vector3(1.0,height,1.0);pm.position=Vector3(0,height*0.5,0);pm.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  root.add_child(pm)
  var tip=SphereMesh.new();tip.radius=1.0;tip.height=2.0;tip.radial_segments=4;tip.rings=2
  var tm=MeshInstance3D.new();tm.mesh=tip;tm.material_override=_beacon_mat(Color(col.r,col.g,col.b,0.95));tm.position=Vector3(0,height,0);tm.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  root.add_child(tm)
  landmarks_root.add_child(root)
  beacons.append({"root":root,"pole":pm,"tip":tm,"h":height})

## Material de baliza: sin sombreado y con prioridad de dibujo mayor que el agua, para que el poste no quede tapado por la superficie.
func _beacon_mat(c:Color)->StandardMaterial3D:
 var key="beacon"+c.to_html()
 if ring_mat_cache.has(key):return ring_mat_cache[key]
 var m=StandardMaterial3D.new();m.albedo_color=c;m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;m.render_priority=5;m.disable_fog=true
 ring_mat_cache[key]=m
 return m

func _update_beacons_j():
 var cam=get_viewport().get_camera_3d()
 if cam==null:return
 _update_markers_j(cam)
 for b in beacons:
  var r:Node3D=b.root
  var d=cam.global_position.distance_to(r.global_position)
  r.visible=d>140.0 and not look_hide_overlays
  if not r.visible:continue
  # Poste fino (~2 px) y rombo chico (~7 px): marca la posicion sin tapar el paisaje.
  var k=clampf(d*0.0035,0.25,4.0)
  b.pole.scale=Vector3(k,float(b.h),k)
  b.tip.scale=Vector3.ONE*clampf(d*0.0055,1.0,6.0)

## Encuadra una lista de puntos (x,z) con una cámara dada: devuelve {target:Vector3, distance, height, pitch_deg, fits}. La UI decide si lo usa; sirve para que el encuadre inicial no sea solo arena.
## Convención: cámara al sur del objetivo mirando al norte (norte arriba, como el minimapa).
func frame_view(camera:Camera3D,pts:Array,pitch_deg:float=52.0,margin:float=0.82)->Dictionary:
 if pts.is_empty():return {}
 var mn=Vector2(1e9,1e9);var mx=Vector2(-1e9,-1e9)
 for q in pts:
  var v=_pt(q);mn=Vector2(minf(mn.x,v.x),minf(mn.y,v.y));mx=Vector2(maxf(mx.x,v.x),maxf(mx.y,v.y))
 var c=(mn+mx)*0.5
 var target=Vector3(c.x,maxf(_h(c.x,c.y),level_m),c.y)
 var vs=camera.get_viewport().get_visible_rect().size
 var aspect=maxf(0.5,vs.x/maxf(1.0,vs.y))
 var half_v=tan(deg_to_rad(camera.fov)*0.5);var half_h=half_v*aspect
 if camera.keep_aspect==Camera3D.KEEP_WIDTH:
  half_h=tan(deg_to_rad(camera.fov)*0.5);half_v=half_h/aspect
 var p=deg_to_rad(pitch_deg)
 var f=Vector3(0,-sin(p),-cos(p));var up=Vector3(0,cos(p),-sin(p));var right=Vector3(1,0,0)
 var dist=40.0;var fits=false
 var maxd=float(M.get("camera",{}).get("max_distance_m",900.0))
 while dist<=maxd:
  var cam_pos=target-f*dist
  fits=true
  for q in pts:
   var v=_pt(q);var rel=Vector3(v.x,_surface_y(v.x,v.y),v.y)-cam_pos
   var z=rel.dot(f)
   if z<1.0:fits=false;break
   if absf(rel.dot(right)/(z*half_h))>margin or absf(rel.dot(up)/(z*half_v))>margin:fits=false;break
  if fits:break
  dist*=1.04
 return {"target":target,"distance":minf(dist,maxd),"height":minf(dist,maxd)*sin(p),"pitch_deg":pitch_deg,"fits":fits}

## Encuadre inicial sugerido: barranca/Plaza de Toros, batería, playa, río y buque a la vez.
func initial_frame(camera:Camera3D)->Dictionary:
 var pts=[]
 for id in ["plaza_toros","bateria_abascal","justina"]:
  if landmark_info.has(id):
   var info=landmark_info[id];pts.append(Vector2(float(info.x),float(info.z)))
 if landmark_info.has("justina"):
  var sh=landmark_info["justina"];pts.append(Vector2(float(sh.x)+18.0,float(sh.z)))
 var sc=M.get("camera",{}).get("focus_start",[140,265])
 pts.append(Vector2(float(sc[0]),float(sc[1])))
 return frame_view(camera,pts)

# ---------------------------------------------------------------- API publica: mundo, camara, picks
func map_size()->Vector2:
 return Vector2(map_w,map_h)

func world_to_map(p:Vector2)->Vector2:
 return Vector2(p.x/map_w,p.y/map_h)

func map_to_world(uv:Vector2)->Vector2:
 return Vector2(uv.x*map_w,uv.y*map_h)

func camera_bounds()->Rect2:
 var m=float(M.get("camera",{}).get("bounds_margin_m",60.0))
 return Rect2(-m,-m,map_w+2.0*m,map_h+2.0*m)

func clamp_camera_target(p:Vector3)->Vector3:
 var b=camera_bounds()
 var x=clampf(p.x,b.position.x,b.end.x);var z=clampf(p.z,b.position.y,b.end.y)
 return Vector3(x,maxf(_h(x,z),level_m),z)

func _ray_surface(origin:Vector3,dir:Vector3)->Variant:
 # Marcha por el campo de alturas: la superficie visible es la mas alta entre suelo y agua.
 var ymax=20.0
 var t=0.0
 if origin.y>ymax:
  if dir.y>=-0.0001:return null
  t=(ymax-origin.y)/dir.y
 var prev=t
 var hit=false
 while t<7000.0:
  var p=origin+dir*t
  if p.y<=maxf(_h(p.x,p.z),level_m):hit=true;break
  prev=t
  t+=maxf(1.0,t*0.008)
 if not hit:return null
 var lo=prev;var hi=t
 for i in range(14):
  var mid=(lo+hi)*0.5;var pm=origin+dir*mid
  if pm.y<=maxf(_h(pm.x,pm.z),level_m):hi=mid
  else:lo=mid
 return origin+dir*hi

func ground_xz_from_screen(camera:Camera3D,mouse_pos:Vector2)->Variant:
 var hit=_ray_surface(camera.project_ray_origin(mouse_pos),camera.project_ray_normal(mouse_pos))
 if hit==null:return null
 return Vector2(hit.x,hit.z)

func _plane_point(camera:Camera3D,screen:Vector2)->Vector2:
 var o=camera.project_ray_origin(screen);var d=camera.project_ray_normal(screen)
 if d.y<-0.002:
  var t=(level_m-o.y)/d.y
  if t>0.0 and t<8000.0:return Vector2(o.x+d.x*t,o.z+d.z*t)
 var h=Vector2(d.x,d.z)
 if h.length()<0.0001:h=Vector2(0,-1)
 return Vector2(o.x,o.z)+h.normalized()*6000.0

func camera_frustum_on_ground(camera:Camera3D)->PackedVector2Array:
 var vs=camera.get_viewport().get_visible_rect().size
 var b=camera_bounds()
 var out=PackedVector2Array()
 for s in [Vector2(0,0),Vector2(vs.x,0),Vector2(vs.x,vs.y),Vector2(0,vs.y)]:
  var p=_plane_point(camera,s)
  out.append(Vector2(clampf(p.x,b.position.x,b.end.x),clampf(p.y,b.position.y,b.end.y)))
 return out

func meters_per_pixel(camera:Camera3D,screen_pos:Vector2=Vector2(-1,-1))->float:
 var vs=camera.get_viewport().get_visible_rect().size
 var sp=screen_pos
 if sp.x<0.0 and sp.y<0.0:sp=vs*0.5
 var o=camera.project_ray_origin(sp);var d=camera.project_ray_normal(sp)
 if d.y<-0.02:
  var a=_plane_point(camera,sp);var b2=_plane_point(camera,sp+Vector2(1,0))
  # Se mide en horizontal de pantalla (donde la escala grafica se dibuja).
  var m=a.distance_to(b2)
  if m>0.0 and m<500.0:return m
 var dist=maxf(1.0,camera.global_position.distance_to(Vector3(o.x+d.x*50,o.y+d.y*50,o.z+d.z*50))/50.0*50.0)
 return 2.0*dist*tan(deg_to_rad(camera.fov)*0.5)/maxf(1.0,vs.y)

func _unit_ids_stable()->Array:
 var ids=[]
 for id in ["guemes","arias","zavala","scout_1","scout_2"]:
  if unit_nodes.has(id):ids.append(id)
 return ids

func pick_units_in_rect(camera:Camera3D,screen_rect:Rect2)->Array:
 var out=[]
 var r=screen_rect.abs()
 for id in _unit_ids_stable():
  var node:Node3D=unit_nodes[id].root
  if not node.visible:continue
  var p=node.global_position+Vector3(0,1.8,0)
  if camera.is_position_behind(p):continue
  if r.has_point(camera.unproject_position(p)):out.append(id)
 return out

func pick_landmark(camera:Camera3D,mouse_pos:Vector2)->String:
 var best="";var nearest=40.0
 for id in landmark_info:
  var info=landmark_info[id]
  var p=Vector3(float(info.x),_surface_y(float(info.x),float(info.z))+2.0,float(info.z))
  if camera.is_position_behind(p):continue
  var d=camera.unproject_position(p).distance_to(mouse_pos)
  if d<nearest:nearest=d;best=id
 return best

func get_landmark_info(id:String)->Dictionary:
 return landmark_info.get(id,{}).duplicate()

func landmark_labels(camera:Camera3D)->Array:
 var out=[]
 for id in landmark_info:
  var info=landmark_info[id]
  var p=Vector3(float(info.x),_surface_y(float(info.x),float(info.z))+6.0,float(info.z))
  out.append({"id":id,"name":info.name,"tag":info.tag,"screen":camera.unproject_position(p),"behind":camera.is_position_behind(p)})
 return out

## Estado de una capa ("paths"|"probes"|"exposure"|"labels"|"unit_labels"|"landmarks"). La UI lo consulta para no duplicar rótulos.
func layer_visible(layer:String)->bool:
 return bool(layer_state.get(layer,false))

## "labels" = rótulos 3D de hitos y extras (si la UI rotula los hitos con landmark_labels(), debe apagarla); "unit_labels" = rótulos de grupos y exploradores (solo se tocan al llamar set_layer_visible).
## Los rótulos de boyas y vados hallados dependen de la capa "probes" (la UI no los dibuja).
func _apply_label_layers()->void:
 if is_instance_valid(labels_root):labels_root.visible=bool(layer_state.labels) and not look_hide_overlays
 for id in unit_labels:
  if is_instance_valid(unit_labels[id]):unit_labels[id].visible=bool(layer_state.unit_labels)

func set_layer_visible(layer:String,on:bool)->void:
 if not layer_state.has(layer):return
 layer_state[layer]=on
 match layer:
  "labels","unit_labels":
   if justina:_apply_label_layers()
  "landmarks":
   if is_instance_valid(landmarks_root):landmarks_root.visible=on
  "probes":
   if is_instance_valid(knowledge_root):knowledge_root.visible=on
  "exposure":
   exposure_forced=true;exposure_user_on=on
  "paths":
   _refresh_paths_j()

func set_selected_ids(ids:Array)->void:
 selected_ids=ids.duplicate()
 selected=str(ids[0]) if ids.size()>0 else ""

# ---------------------------------------------------------------- minimapa (textura, sin unidades ni camara)
func _mm_color(key:String,fallback:String)->Color:
 return Color(str(M.get("minimap",{}).get("colors",{}).get(key,fallback)))

func _mm_prepare(sz:Vector2i)->Dictionary:
 var W=sz.x;var H=sz.y
 var land=PackedByteArray();land.resize(W*H*4)
 var hs=PackedFloat32Array();hs.resize(W*H)
 var shade=PackedFloat32Array();shade.resize(W*H)
 var bed=PackedInt32Array()
 var barranca=M.get("barranca",{})
 var crest_poly:Array=barranca.get("crest",[]);var toe_poly:Array=barranca.get("toe",[])
 var c_land=_mm_color("land","#8a7a58");var c_bar=_mm_color("barranca","#5e5a45")
 var Ls=Vector3(-0.5,0.8,-0.4).normalized()
 for py in range(H):
  var z=(float(py)+0.5)/float(H)*map_h
  var cx=_poly_x(crest_poly,z);var tx=_poly_x(toe_poly,z)
  for px in range(W):
   var x=(float(px)+0.5)/float(W)*map_w
   var k=py*W+px
   var h=_h(x,z)
   hs[k]=h
   var gx=(_h(x+J_CELL,z)-_h(x-J_CELL,z))/(2.0*J_CELL);var gz=(_h(x,z+J_CELL)-_h(x,z-J_CELL))/(2.0*J_CELL)
   var nrm=Vector3(-gx,1.0,-gz).normalized()
   var s=clampf(0.45+0.75*maxf(0.0,nrm.dot(Ls)),0.4,1.15)
   shade[k]=s
   var col=c_land
   if x<=cx:col=c_land
   elif x<tx:col=c_bar
   else:bed.append(k)
   if x<tx:
    col=Color(col.r*s,col.g*s,col.b*s)
    land[k*4]=int(clampf(col.r,0,1)*255.0);land[k*4+1]=int(clampf(col.g,0,1)*255.0);land[k*4+2]=int(clampf(col.b,0,1)*255.0);land[k*4+3]=255
 return {"w":W,"h":H,"land":land,"hs":hs,"shade":shade,"bed":bed,"version":-1,"img":null,"tex":null}

func _mm_render(e:Dictionary)->void:
 var W:int=e.w;var H:int=e.h
 var data:PackedByteArray=e.land.duplicate()
 var hs:PackedFloat32Array=e.hs;var shade:PackedFloat32Array=e.shade
 var c_em=_mm_color("emerged","#c8b88a");var c_wu=_mm_color("water_unknown","#4a5d63")
 var c_lane=_mm_color("probe_lane","#6fb8a6");var c_mark=_mm_color("marked","#e2c46b");var c_danger=_mm_color("danger","#d48f79")
 var c_high=_mm_color("land","#8a7a58").lerp(c_em,0.6)
 var vis=float(M.get("knowledge",{}).get("visibility_depth_m",0.3))
 var hi_level=float(M.get("tide",{}).get("level_high_m",1.65))
 for k in e.bed:
  var depth=level_m-hs[k]
  var c:Color
  if depth<=0.0:
   var s=shade[k]*0.35+0.65
   c=(c_high if hs[k]>hi_level else c_em)*s
  elif depth<=vis:
   c=c_em.lerp(c_wu,0.55)
  else:
   c=c_wu
   var px=k%W;var py=k/W
   if (px+py)%7<2:c=c.lightened(0.07)
  data[k*4]=int(clampf(c.r,0,1)*255.0);data[k*4+1]=int(clampf(c.g,0,1)*255.0);data[k*4+2]=int(clampf(c.b,0,1)*255.0);data[k*4+3]=255
 # Franjas de sondas por profundidad real (verde/ambar/rojo) y vados marcados.
 var mpp_x=map_w/float(W);var mpp_z=map_h/float(H)
 for p in rules.state.get("probes",[]):
  var pts:Array=p.get("pts",[]);var marked=str(p.get("kind",""))=="marked";var half=float(p.get("width",6.0))*0.5
  for i in range(pts.size()-1):
   _mm_strip(data,hs,W,H,_pt(pts[i]),_pt(pts[i+1]),half,marked,c_lane,c_mark,c_danger,mpp_x,mpp_z)
 for hz in M.get("hazards",[]):
  if str(hz.id) in rules.state.get("hazards_found",[]):_mm_disc(data,W,H,Vector2(float(hz.center[0]),float(hz.center[1])),float(hz.get("radius_m",10.0)),c_danger)
 for fd in M.get("fords",[]):
  if str(fd.id) in rules.state.get("fords_found",[]):
   if fd.has("centerline"):
    var cl:Array=fd.centerline
    for i in range(cl.size()-1):_mm_strip(data,hs,W,H,_pt(cl[i]),_pt(cl[i+1]),float(fd.get("half_width_m",8.0)),true,c_lane,Color("5fd08a"),c_danger,mpp_x,mpp_z)
   elif fd.has("center"):_mm_disc(data,W,H,_pt(fd.center),float(fd.get("radius_m",20.0)),Color("5fd08a"))
 for id in landmark_info:
  var info=landmark_info[id]
  var cc=_tag_color(str(info.tag))
  _mm_dot(data,W,H,Vector2(float(info.x),float(info.z)),2,cc)
 _mm_dot(data,W,H,Vector2(float(M.ship.x),float(M.ship.z)),3,Color("f4efdc"))
 var img=Image.create_from_data(W,H,false,Image.FORMAT_RGBA8,data)
 e.img=img
 if e.tex==null:e.tex=ImageTexture.create_from_image(img)
 else:(e.tex as ImageTexture).update(img)
 e.version=minimap_version

func _mm_set(data:PackedByteArray,W:int,H:int,px:int,py:int,c:Color)->void:
 if px<0 or py<0 or px>=W or py>=H:return
 var k=(py*W+px)*4
 data[k]=int(c.r*255.0);data[k+1]=int(c.g*255.0);data[k+2]=int(c.b*255.0);data[k+3]=255

func _mm_dot(data:PackedByteArray,W:int,H:int,p:Vector2,r:int,c:Color)->void:
 var cx=int(p.x/map_w*float(W));var cy=int(p.y/map_h*float(H))
 for dy in range(-r,r+1):
  for dx in range(-r,r+1):
   if dx*dx+dy*dy<=r*r+1:_mm_set(data,W,H,cx+dx,cy+dy,c)

func _mm_disc(data:PackedByteArray,W:int,H:int,p:Vector2,rm:float,c:Color)->void:
 var rx=int(ceil(rm/map_w*float(W)));var ry=int(ceil(rm/map_h*float(H)))
 var cx=int(p.x/map_w*float(W));var cy=int(p.y/map_h*float(H))
 for dy in range(-ry,ry+1):
  for dx in range(-rx,rx+1):
   var wx=(float(dx)/float(maxi(rx,1)));var wy=(float(dy)/float(maxi(ry,1)))
   if wx*wx+wy*wy<=1.0:_mm_set(data,W,H,cx+dx,cy+dy,c)

func _mm_strip(data:PackedByteArray,hs:PackedFloat32Array,W:int,H:int,a:Vector2,b:Vector2,half:float,marked:bool,c_lane:Color,c_mark:Color,c_danger:Color,mpp_x:float,mpp_z:float)->void:
 var x0=int(floor((minf(a.x,b.x)-half)/mpp_x));var x1=int(ceil((maxf(a.x,b.x)+half)/mpp_x))
 var y0=int(floor((minf(a.y,b.y)-half)/mpp_z));var y1=int(ceil((maxf(a.y,b.y)+half)/mpp_z))
 var ab=b-a;var l2=maxf(ab.length_squared(),0.0001)
 for py in range(maxi(y0,0),mini(y1,H-1)+1):
  for px in range(maxi(x0,0),mini(x1,W-1)+1):
   var wp=Vector2((float(px)+0.5)*mpp_x,(float(py)+0.5)*mpp_z)
   var t=clampf((wp-a).dot(ab)/l2,0.0,1.0)
   if wp.distance_to(a+ab*t)>half:continue
   var depth=level_m-hs[py*W+px]
   var c:Color
   if marked:c=c_mark
   elif depth<=0.6:c=c_lane
   elif depth<=1.3:c=Color("e0b24a")
   else:c=c_danger
   _mm_set(data,W,H,px,py,c)

func minimap_signature()->String:
 return _knowledge_signature()+"|"+str(snappedf(level_m,0.01))

func minimap_refresh(force:bool=false)->void:
 var sig=minimap_signature()
 if not force and sig==minimap_sig:return
 minimap_sig=sig;minimap_version+=1
 emit_signal("minimap_changed")

func get_minimap_texture(size:Vector2i)->Texture2D:
 minimap_requested=true
 minimap_last_size=size
 if not justina:return null
 if not minimap_cache.has(size):minimap_cache[size]=_mm_prepare(size)
 var e:Dictionary=minimap_cache[size]
 var sig_now=minimap_signature()
 if sig_now!=minimap_sig:
  minimap_sig=sig_now;minimap_version+=1
 if e.version!=minimap_version or e.tex==null:_mm_render(e)
 return e.tex
