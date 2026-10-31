extends Node3D
## Orquestación de escena, interfaz e input. GameRules conserva la autoridad.
const Rules = preload("res://scripts/game_rules.gd")
const World = preload("res://scripts/world_view.gd")
const Jev = preload("res://scripts/jev_client.gd")
const GOLD = Color("d9b576")
const INK = Color("101e24")
const PAPER = Color("e9e3d4")
const MUTED = Color("aab7b5")
const RED = Color("d48f79")
const GREEN = Color("9ac4ab")
const ACTION_NAMES = {"move":"Mover", "scout":"Reconocer", "protect":"Proteger víveres", "raid":"Hostigar", "rest":"Reponer fuerzas", "withdraw":"Replegarse", "assault":"Operar en Humahuaca"}
const ACTION_HINTS = {"move":"Traslada la agrupación a un sector vecino. Fatiga +7; suministros −4.","scout":"Revela el sector y sus vecinos. El reconocimiento reduce las pérdidas del hostigamiento durante tres rondas.","protect":"Resguarda víveres y animales del sector propio. Reservas +18, apoyo +9; limita el abastecimiento enemigo.","raid":"Corta abastecimiento y comunicaciones. Requiere conocimiento del sector y fuerzas en condiciones.","rest":"En un sector propio: suministros +27, fatiga −34, fuerza +9. Consume 8 reservas.","withdraw":"Vuelve a un sector vecino propio y reduce 16 de fatiga.","assault":"Arias coordina Humahuaca desde marzo: afecta artillería, cuartel, depósito de pólvora y comunicaciones."}

var rules: Variant = Rules.new()
var world: Node3D
var camera: Camera3D
var jev: Node
var audio_manager: Node
var ui: Control
var layer: CanvasLayer
var theme_main: Theme
var title_font: Font
var mode = "menu"
var paused = true
var speed = 1.0
var selected = "guemes"
var sector = "lerma"
var camera_target = Vector3(-4,0,0)
var camera_distance = 78.0
var camera_yaw = -0.17
var camera_pitch = 0.91
var orbiting = false
var panning = false
var settings = {"quality":"media","volume":0.55,"muted":false,"tutorial":true,"fullscreen":false,"camera_speed":1.0,"invert_orbit":false,"jev_local":false,"last_save":"norte","auto_pause":true}
var pending_round = false
var resolution_remaining = 0.0
var outcome_shown = false
var modal: Control
var modal_paused = false
var title_label: Label
var objective_label: RichTextLabel
var phase_label: Label
var info_label: RichTextLabel
var enemy_label: RichTextLabel
var status_label: Label
var tutorial_label: Label
var log_label: RichTextLabel
var toast_label: Label
var toast_timer = 0.0
var unit_buttons = {}
var action_buttons = {}
var action_box: VBoxContainer
var pause_button: Button
var speed_button: Button
var selected_label: Label
var sector_option: OptionButton
var round_button: Button
var jev_label: Label
var capture_bar: ProgressBar
var update_timer = 0.0
var history_data = {}
var qa_mode = false
var qa_path = ""
var qa_size = Vector2i.ZERO
var qa_metrics = {}
var frame_samples: Array = []
var start_msec = 0
var hoof_timer = 0.0
var scene_build_ms = 0
var benchmark_mode = false
var benchmark_quality = "media"
const UNIT_COLORS = {"guemes":Color("e2bc72"),"arias":Color("7fd0c4"),"zavala":Color("e0a3bd"),"scout_1":Color("d8d2c0"),"scout_2":Color("c9d8d2")}
const UNIT_GLYPHS = {"guemes":"◆","arias":"▲","zavala":"●","scout_1":"◈","scout_2":"◈"}
const STAGE_TEXT = {"ready":["○","A la espera"],"moving":["▶","En marcha"],"waiting_tide":["≈","Espera la bajante"],"dismounting":["▼","Desmonta"],"boarding":["■","Resuelve la captura"],"blocked":["✕","Ruta interrumpida"],"rally":["↺","Reagrupa"],"ordered":["◇","Orden preparada"],"routed":["✕","Dispersa"],"working":["…","Trabaja"],"stumbling":["!","Tropezó"],"idle":["○","Libre"],"probing":["◈","Sondea"],"marking":["◈","Marca el vado"],"lost":["✕","Perdido"]}
# ---- Justina (contrato v1): estado de interfaz ----
const GROUP_IDS = ["guemes","arias","zavala"]
const SCOUT_IDS = ["scout_1","scout_2"]
const ALL_ACTORS = ["guemes","arias","zavala","scout_1","scout_2"]
const ACTION_KEYS = {"move":KEY_V,"board":KEY_N,"muster":KEY_U,"resupply":KEY_J,"signal_liniers":KEY_K,"withdraw":KEY_L,"rally":KEY_Y,"cancel":KEY_X,"probe":KEY_Z,"mark_ford":KEY_H,"recall":KEY_I,"distract_fire":KEY_O,"repel":KEY_COMMA,"evacuate":KEY_PERIOD}
const KEY_LABELS = {"repel":",","evacuate":".","probe_careful":"Mayús+Z","undo":"Ctrl+Z"}
# Tabla única de teclas de Justina (fuente de verdad; docs/CONTROLES.md la repite y tests/test_integration.gd la contrasta:
# sin teclas repetidas entre filas ni con ACTION_KEYS, y cada etiqueta debe figurar en el documento).
const J_KEY_TABLE = [
 {"label":"WASD","keys":[KEY_W,KEY_A,KEY_S,KEY_D,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT],"desc":"mover la cámara (también flechas y borde de pantalla; Mayús = más rápido)"},
 {"label":"Q / E","keys":[KEY_Q,KEY_E],"desc":"girar la cámara"},
 {"label":"RePág / AvPág","keys":[KEY_PAGEUP,KEY_PAGEDOWN],"desc":"inclinar la cámara"},
 {"label":"1-5","keys":[KEY_1,KEY_2,KEY_3,KEY_4,KEY_5],"desc":"seleccionar grupos (1-3) y exploradores (4-5)"},
 {"label":"Tab","keys":[KEY_TAB],"desc":"ciclar la selección"},
 {"label":"Espacio","keys":[KEY_SPACE],"desc":"iniciar, pausar o reanudar el tiempo"},
 {"label":"Inicio","keys":[KEY_HOME,KEY_F],"desc":"centrar la cámara en la selección (también F)"},
 {"label":"B","keys":[KEY_B],"desc":"ir al buque"},
 {"label":"0","keys":[KEY_0,KEY_KP_0],"desc":"ver todo el mapa"},
 {"label":"M","keys":[KEY_M],"desc":"minimapa grande o normal"},
 {"label":"P","keys":[KEY_P],"desc":"parte de campaña"},
 {"label":"G / T / C","keys":[KEY_G,KEY_T,KEY_C],"desc":"ritmo: galope, trote, paso"},
 {"label":"Enter","keys":[KEY_ENTER,KEY_KP_ENTER],"desc":"confirmar la orden o la ruta en curso"},
 {"label":"+ / -","keys":[KEY_EQUAL,KEY_KP_ADD,KEY_MINUS,KEY_KP_SUBTRACT],"desc":"velocidad del tiempo (x1, x2, x4)"},
 {"label":"R","keys":[KEY_R],"desc":"reiniciar la partida (pide confirmación)"},
 {"label":"F1","keys":[KEY_F1],"desc":"ayuda, controles y briefing (también la tecla ?)"},
 {"label":"F2 / F3 / F4","keys":[KEY_F2,KEY_F3,KEY_F4],"desc":"velocidad del tiempo real: x1, x2, x4"},
 {"label":"F5","keys":[KEY_F5],"desc":"guardar"},
 {"label":"F9","keys":[KEY_F9],"desc":"cargar"},
 {"label":"F11","keys":[KEY_F11],"desc":"pantalla completa"},
 {"label":"Esc","keys":[KEY_ESCAPE],"desc":"cancelar la orden, soltar el foco o cerrar el panel"},
]
const ACTION_FALLBACK = {"board_own":{"label":"Cargar sin orden","tag":"diseno","effect":"Carga contra el buque sin esperar el permiso de Liniers. Riesgo: la captura va un 20 % más lenta y no hay medalla de oro."},"undo":{"label":"Deshacer","tag":"diseno","effect":"Deshace la última orden dada: devuelve a cada grupo a lo que hacía o la cancela, y a los exploradores a la playa. No recupera recursos ya gastados (señales, munición, balizas)."},"recall":{"label":"Volver","tag":"diseno","effect":"El explorador vuelve a la playa seca."},"retreat_all":{"label":"Retirada general","tag":"diseno","effect":"Termina la partida como derrota ordenada."}}
const RISK_COLORS = {"bajo":Color("a6e3b8"),"medio":Color("e0bf81"),"alto":Color("f4a58d"),"desconocido":Color("aab7b5")}
const KIND_ICON = {"shot_warning":"✸","counter_warning":"⚔","last_effort":"✸","choice":"✉","choice_done":"✉","reinforce":"+","assist":"+","mission":"◎","liniers":"◆","hint":"i","counter":"⚔","objective":"◎","tide":"≈","warning":"!","shot":"✸","boarding":"■","recon":"◈","ford":"≈","stumble":"!","muster":"+","ammo":"•","signal":"◆","fire_support":"✸","victory":"★","defeat":"✕","load":"↻","info":"i"}
const KIND_COLOR = {"shot_warning":Color("f4a58d"),"counter_warning":Color("f4a58d"),"last_effort":Color("f4a58d"),"choice":Color("e0bf81"),"reinforce":Color("a6e3b8"),"counter":Color("f4a58d"),"warning":Color("f4a58d"),"stumble":Color("f4a58d"),"defeat":Color("f4a58d"),"victory":Color("a6e3b8"),"tide":Color("8fb4d9"),"ford":Color("8fb4d9"),"recon":Color("6fb8a6"),"signal":Color("d9b576"),"muster":Color("a6e3b8"),"ammo":Color("e0bf81")}
const PITCH_MIN = 0.436
const PITCH_MAX = 1.396
var world_script = World
var sel_ids: Array = ["guemes"]
var pace = "trot"
var aim = ""
var aim_pts: Array = []
var wp_list: Array = []
var pending_pt = null
var lmb_down = false
var lmb_start = Vector2.ZERO
var box_active = false
var box_rect = Rect2()
var rmb_down = false
var rmb_start = Vector2.ZERO
var rmb_drag = false
var mmb_down = false
var mmb_start = Vector2.ZERO
var grab_anchor = null
var mm_dragging = false
var mm_big = false
var mm_tex: Texture2D
var map_widget: Control
var place_panel: PanelContainer
var place_label: Label
var river_ctl: Control
var time_ctl: Control
var res_label: RichTextLabel
var moral_bar: ProgressBar
var roster_buttons = {}
var pace_buttons = {}
var sel_info: RichTextLabel
var notice_label: Label
var toast_pos = null
var toast_view: Button
var hover_plan_key = ""
var preview_timer = 0.0
var last_hover_pt = null
var qa_keys = {}
var qa_focus_override = -1
var tut_step = 0
var cam_cfg = {}
var action_cache = []
var overlay: Control
var overlay_top: Control
var hint_timer = 0.0
var last_hint_text = ""
var bottom_panel: PanelContainer
var hover_mouse = Vector2(-1,-1)
var overlay_labels: Array = []
var hud_panels: Array = []
var left_panel: PanelContainer
var right_panel: PanelContainer
var journal_panel: PanelContainer
var hint_panel: PanelContainer
var left_body: Control
var right_body: Control
var journal_toggle: Button
var journal_last: Label
var reason_label: Label
var stat_bars = {}
var style_cache = {}
var info_open = true
var journal_open = false
var shelf_open = true
var select_flash = 0.0
var hover_info = {}
var hover_timer = 0.0
var cam_goal_active = false
var cam_goal_target = Vector3.ZERO
var cam_goal_distance = 78.0
var confirm_action = ""
var confirm_timer = 0.0
var dec_regex: RegEx
var log_regex: RegEx
var last_overlay_rects: Array = []
const GROUP_ROLE = {
 "guemes":{"kind":"Caballería","role":"Vanguardia (rol de juego, no dato histórico): abre el paso y aborda primero."},
 "arias":{"kind":"Voluntarios","role":"Apoyo: sostiene la orilla y refuerza el abordaje."},
 "zavala":{"kind":"Caballería de reserva","role":"Reserva: entra cuando el paso ya está abierto."},
 "scout_1":{"kind":"Explorador","role":"Sondea el fondo con la lanza y marca el vado."},
 "scout_2":{"kind":"Explorador","role":"Sondea el fondo con la lanza y marca el vado."}}
const TUT_STEPS = [
 "1/4 · Sondeá el agua: tocá al explorador 4 (el aro dorado), apretá Z y hacé clic en el agua. Espacio inicia el reloj.",
 "2/4 · Esperá a que el vado ceda (la barra de la derecha) y mientras tanto abastecé munición (J).",
 "3/4 · ¡El vado cede! Elegí un grupo (1-3) y pedí la carga a Liniers (K). Si no llega, «Cargar sin orden» (con riesgo).",
 "4/4 · A cargar: clic derecho sobre el buque o «Cargar y abordar» (N).",
 "Abordaje: cuando el buque contraataque, rechazalo (coma) a tiempo."]
var mode_label: Label
var ring_labels: Array = []
var moral_label: RichTextLabel
var speed_buttons = {}
var top_stack: VBoxContainer
var pause_banner: Label
var alert_panel: PanelContainer
var alert_label: Label
var alert_btn: Button
var alert_ids_seen = {}
var alert_current = {}
var pause_reason = ""
var left_foot: RichTextLabel
var mm_bar: PanelContainer
var autopause_button: Button
var tut_skip_btn: Button
var tut_close_btn: Button
var tut_cam0 = Vector3.ZERO
var tut_dist0 = 0.0
var order_log: Array = []
var eta_cache = {}
var goal_label: RichTextLabel
var tide_label: RichTextLabel
var risk_label: RichTextLabel
var deploy_btn: Button
var roster_panel: PanelContainer

func _ready():
 start_msec = Time.get_ticks_msec()
 log_regex=RegEx.new();log_regex.compile("[0-9]+([.,][0-9]+)?")
 dec_regex=RegEx.new();dec_regex.compile("([0-9])\\.([0-9])")
 # La base de diseño es 1440x900; con "expand" la ventana más ancha o más alta gana espacio
 # (las anclas lo reparten) en lugar de barras negras.
 get_window().content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 get_window().size_changed.connect(_fit_ui_scale)
 _load_settings()
 _progress_load()
 _make_theme()
 if FileAccess.file_exists("res://data/history.json"):
  var data=JSON.parse_string(FileAccess.get_file_as_string("res://data/history.json"))
  if data is Dictionary:history_data=data
 jev=Jev.new();add_child(jev)
 jev.force_local=bool(settings.jev_local)
 jev.decision_ready.connect(_on_intent)
 if ResourceLoader.exists("res://scripts/audio_manager.gd"):
  audio_manager=load("res://scripts/audio_manager.gd").new();add_child(audio_manager)
  audio_manager.set_volume(float(settings.volume));audio_manager.set_muted(bool(settings.muted))
 camera=Camera3D.new();camera.fov=46;camera.far=4000;add_child(camera)
 camera.current=true
 layer=CanvasLayer.new();add_child(layer)
 _menu()
 var auto_scenario=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--qa="):qa_mode=true;auto_scenario=arg.trim_prefix("--qa=")
  if arg.begins_with("--qa-path="):qa_path=arg.trim_prefix("--qa-path=")
  if arg.begins_with("--qa-size="):
   var wh=arg.trim_prefix("--qa-size=").split("x")
   if wh.size()==2:qa_size=Vector2i(int(wh[0]),int(wh[1]))
  if arg.begins_with("--scenario="):auto_scenario=arg.trim_prefix("--scenario=")
  if arg.begins_with("--benchmark="):benchmark_mode=true;auto_scenario=arg.trim_prefix("--benchmark=")
  if arg.begins_with("--quality="):benchmark_quality=arg.trim_prefix("--quality=")
 if benchmark_mode:
  call_deferred("_benchmark_run",auto_scenario)
 elif qa_mode:
  call_deferred("_qa_run",auto_scenario)
 elif not auto_scenario.is_empty():
  _start_game(auto_scenario)

func _make_theme():
 theme_main=Theme.new()
 if ResourceLoader.exists("res://assets/fonts/Inter.ttf"):theme_main.default_font=load("res://assets/fonts/Inter.ttf")
 if ResourceLoader.exists("res://assets/fonts/Cinzel.ttf"):title_font=load("res://assets/fonts/Cinzel.ttf")
 theme_main.default_font_size=16
 theme_main.set_color("font_color","Label",PAPER)
 theme_main.set_color("default_color","RichTextLabel",PAPER)
 for state_name in ["normal","hover","pressed","disabled","focus"]:
  var c=Color("1a3037")
  if state_name=="hover":c=Color("29454c")
  if state_name=="pressed":c=Color("406064")
  if state_name=="disabled":c=Color("19272b")
  if state_name=="focus":c=Color("27434a")
  var border=Color("455753")
  var border_width=1
  if state_name=="hover":border=GOLD
  if state_name=="focus":border=Color("fff0b8");border_width=3
  var s=_style(c,border,border_width,5,14)
  s.content_margin_top=5;s.content_margin_bottom=5
  theme_main.set_stylebox(state_name,"Button",s)
  theme_main.set_stylebox(state_name,"OptionButton",s)
 theme_main.set_color("font_color","Button",PAPER)
 theme_main.set_color("font_hover_color","Button",Color.WHITE)
 theme_main.set_color("font_disabled_color","Button",Color("8a9896"))
 theme_main.set_color("font_color","OptionButton",PAPER)
 theme_main.set_stylebox("panel","PopupMenu",_style(INK,Color("65756c"),1,5,12))
 theme_main.set_color("font_color","PopupMenu",PAPER)
 theme_main.set_stylebox("background","ProgressBar",_style(Color("31433e"),Color.TRANSPARENT,0,3,0))
 theme_main.set_stylebox("fill","ProgressBar",_style(GOLD,Color.TRANSPARENT,0,3,0))

func _style(color:Color,border:Color=Color.TRANSPARENT,width=0,radius=0,padding=0):
 var style=StyleBoxFlat.new()
 style.bg_color=color;style.border_color=border
 style.set_border_width_all(width);style.set_corner_radius_all(radius)
 style.content_margin_left=padding;style.content_margin_right=padding
 style.content_margin_top=padding;style.content_margin_bottom=padding
 return style

func _new_ui():
 if is_instance_valid(ui):layer.remove_child(ui);ui.queue_free()
 modal=null
 ui=Control.new();ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 ui.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.theme=theme_main;layer.add_child(ui)

func _panel(parent:Control,pos:Vector2,size_v:Vector2,bg=Color(0.055,0.105,0.12,0.94),border=Color("394c49"),pad=18):
 var panel=PanelContainer.new();panel.position=pos;panel.size=size_v
 panel.add_theme_stylebox_override("panel",_style(bg,border,1,7,pad))
 parent.add_child(panel);return panel

func _anchor(c:Control,a_left:float,a_top:float,a_right:float,a_bottom:float,o_left:float,o_top:float,o_right:float,o_bottom:float):
 # Interfaz responsiva: la posición se expresa como ancla (fracción de la ventana) más un margen fijo.
 c.anchor_left=a_left;c.anchor_top=a_top;c.anchor_right=a_right;c.anchor_bottom=a_bottom
 c.offset_left=o_left;c.offset_top=o_top;c.offset_right=o_right;c.offset_bottom=o_bottom

func _label(parent:Node,text_value:String,font_size=16,color:Color=PAPER,serif=false)->Label:
 var label=Label.new();label.text=text_value
 label.add_theme_font_size_override("font_size",font_size);label.add_theme_color_override("font_color",color)
 if serif and title_font:label.add_theme_font_override("font",title_font)
 parent.add_child(label);return label

func _rich(parent:Node,text_value:String,font_size=16,min_height=0)->RichTextLabel:
 var label=RichTextLabel.new();label.bbcode_enabled=true;label.text=text_value
 label.fit_content=true;label.scroll_active=false;label.custom_minimum_size.y=min_height
 label.add_theme_font_size_override("normal_font_size",font_size)
 label.add_theme_font_size_override("bold_font_size",font_size)
 parent.add_child(label);return label

func _button(parent:Node,text_value:String,fn:Callable,min_height=42)->Button:
 var button=Button.new();button.text=text_value;button.custom_minimum_size.y=min_height
 button.pressed.connect(fn);parent.add_child(button);button.focus_mode=Control.FOCUS_ALL
 button.pressed.connect(_blur_after_click)
 return button

func _vbox(parent:Node,sep=10):
 var box=VBoxContainer.new();box.add_theme_constant_override("separation",sep);parent.add_child(box);return box

func _hbox(parent:Node,sep=10):
 var box=HBoxContainer.new();box.add_theme_constant_override("separation",sep);parent.add_child(box);return box

func _spacer(parent:Node,h=10):
 var c=Control.new();c.custom_minimum_size.y=h;parent.add_child(c)

func _rebuild_world():
 if is_instance_valid(world):remove_child(world);world.queue_free()
 world=world_script.new();add_child(world);world.build(rules,str(settings.quality))
 world.selected=selected;world.selected_sector=sector
 if _is_j() and world.has_method("set_selected_ids"):
  if world.has_signal("minimap_changed"):world.minimap_changed.connect(_refresh_minimap)
  world.set_selected_ids(sel_ids)
 # Las etiquetas 3D tienen tamaño fijo en el mundo (AUDITORIA UI-3/4): se ocultan y la
 # interfaz las dibuja en pantalla con tamaño constante y sin solaparse.
 overlay_labels=[]
 var skip={}
 for entry in world.sector_nodes.values():skip[entry.label]=true
 for label_3d in world.unit_labels.values():skip[label_3d]=true
 if _is_j() and world.has_method("set_layer_visible"):
  # Justina: la interfaz dibuja sus propios rótulos (hitos y fichas). La capa 'labels' de la vista se apaga
  # para no duplicarlos; los rótulos de unidades (cuelgan de cada figura) se mantienen ocultos en _process.
  world.set_layer_visible("labels",false)
  for label_3d in world.unit_labels.values():label_3d.visible=false
 else:
  for label_3d in world.find_children("*","Label3D",true,false):
   label_3d.visible=false
   if not skip.has(label_3d):overlay_labels.append(label_3d)
 if audio_manager:audio_manager.set_environment(str(rules.state.scenario))
 get_viewport().msaa_3d=Viewport.MSAA_DISABLED if settings.quality=="baja" else (Viewport.MSAA_4X if settings.quality=="alta" else Viewport.MSAA_2X)
 get_viewport().scaling_3d_scale=0.5 if settings.quality=="baja" else 1.0

var forced_seed:int=-1 # -1: fondo del río distinto en cada partida; las pruebas fijan una semilla

# En ventanas menores que la base 1440x900 la interfaz de Justina no se encoge por debajo de 1:1 (a 720p el texto quedaba en ~9 px).
func _fit_ui_scale():
 var w=get_window()
 var f:=1.0
 if mode=="play" and _is_j():
  var sz=Vector2(w.size)
  var s0=minf(sz.x/1440.0,sz.y/900.0)
  if s0>0.0 and s0<1.0 and sz.x>=1200.0 and sz.y>=680.0:f=1.0/s0
 if not is_equal_approx(w.content_scale_factor,f):
  w.content_scale_factor=f
  if is_instance_valid(map_widget) and _is_j():_layout_j()

func _menu():
 get_window().content_scale_factor=1.0
 jev.invalidate();pending_round=false;mode="menu";paused=true;outcome_shown=false;shake=0.0;flash_alpha=0.0
 rules.new_game("justine",1806)
 selected="guemes";_rebuild_world();_new_ui()
 camera_target=Vector3(3,1,0);camera_distance=42;camera_pitch=0.43;camera_yaw=-0.55
 if _is_j() and rules.state.has("map_id"):
  camera_target=Vector3(300,0,264);camera_distance=240;camera_pitch=0.5;camera_yaw=-0.4
 for label_3d in world.find_children("*","Label3D",true,false):label_3d.visible=false
 var tint=ColorRect.new();tint.color=Color(0.025,0.05,0.055,0.80);ui.add_child(tint);_anchor(tint,0,0,0,1,0,0,655,0)
 var box=VBoxContainer.new();box.add_theme_constant_override("separation",12);ui.add_child(box);_anchor(box,0,0,0,1,64,66,574,-84)
 _label(box,"J U E G O S   D E   L A   P A T R I A",17,GOLD)
 _spacer(box,24)
 _label(box,"GÜEMES",78,PAPER,true)
 _label(box,"EL TERRENO. EL MOMENTO. LA GENTE.",16,GOLD)
 _spacer(box,12)
 _rich(box,"Dos momentos de una historia. Elegí dónde actuar, cuidá a tus hombres y convertí el territorio en una ventaja.",19)
 _spacer(box,18)
 var a=_button(box,"I   ·   EL RÍO OFRECE UNA OPORTUNIDAD\nTomar la Justina  ·  Buenos Aires, 1806",func():_start_game("justine"),82)
 a.alignment=HORIZONTAL_ALIGNMENT_LEFT
 a.tooltip_text="Tres grupos y dos exploradores. Tiempo real con pausa. El fondo del río es turbio: hay que reconocerlo."
 if int(progress.intentos)>0 and not bool(progress.justina_ganada):a.text="I   ·   EL RÍO OFRECE UNA OPORTUNIDAD\nTomar la Justina  ·  intento %d, mismo río" % (int(progress.intentos)+1)
 var unlocked=bool(progress.justina_ganada)
 var b=_button(box,"II  ·   SOSTENER EL NORTE\n"+("La campaña contra La Serna  ·  1816–1817" if unlocked else "Ganá la Justina para abrirlo"),func():_start_game("norte"),82)
 b.alignment=HORIZONTAL_ALIGNMENT_LEFT;b.disabled=not unlocked
 b.tooltip_text="Campaña por rondas. Reconocimiento, víveres, hostigamiento y la operación de Arias en Humahuaca." if unlocked else "Se abre cuando tomes el buque Justina (aunque sea con medalla de bronce)."
 var options=_hbox(box)
 var continue_button=_button(options,"Continuar",func():_load_game(str(settings.last_save)))
 continue_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 continue_button.disabled=not FileAccess.file_exists(_save_path(str(settings.last_save)))
 _button(options,"Diario",_diary_dialog)
 _button(options,"Ajustes",_settings_dialog)
 _button(options,"Historia",_history_dialog)
 _spacer(box,6)
 _rich(box,"[color=#aab7b5]Reconstrucción jugable con diseño propio, no una crónica: el juego distingue lo documentado, la tradición, la reconstrucción y el diseño (en «Historia» y en cada etiqueta). Que Güemes mandara en la Justina es una tradición no probada.[/color]",13)
 _label(box,"VERSIÓN "+str(ProjectSettings.get_setting("application/config/version","?")).to_upper()+"  ·  3D LOCAL  ·  SE PUEDE JUGAR SIN CONEXIÓN",11,MUTED)
 var credit=_label(ui,"RÍO DE LA PLATA\n12 DE AGOSTO DE 1806",16,Color("e6ceb0"),true)
 _anchor(credit,1,1,1,1,-400,-200,-20,-100)
 var quit_button=_button(ui,"Salir",func():get_tree().quit());_anchor(quit_button,1,0,1,0,-160,28,-36,70)

func _button_at(parent,text_value,pos,size_v,fn):
 var b=_button(parent,text_value,fn);b.position=pos;b.size=size_v;return b

func _start_game(scenario_name:String):
 var build_start=Time.get_ticks_msec()
 jev.invalidate();pending_round=false;resolution_remaining=0;outcome_shown=false
 attempt_logged=false;shake=0.0;flash_alpha=0.0;toast_prio=0;volley_warned=-1.0;toast_timer=0.0;details_open=false;auto_start_pending=false
 rules.new_game(scenario_name,_justina_seed() if scenario_name=="justine" else 1817)
 intro_assists=[];last_result={}
 if scenario_name=="justine":campaign.begin_attempt(rules);_progress_sync()
 selected="guemes";sector="lerma";mode="play";paused=scenario_name=="justine";speed=1
 sel_ids=["guemes"];pace="trot";aim="";aim_pts=[];wp_list=[];pending_pt=null;tut_step=0;mm_big=false
 camera_target=Vector3(-6,0,0) if scenario_name=="justine" else Vector3(1,0,4)
 camera_distance=81 if scenario_name=="justine" else 96;camera_pitch=0.91;camera_yaw=-0.17
 camera.far=400.0
 _fit_ui_scale()
 if scenario_name=="justine":
  _reset_camera_j()
  # Después del primer intento el panel de objetivo arranca plegado: ya se sabe qué hay que hacer y la vista queda más libre.
  info_open=int(progress.intentos)<=1
 _rebuild_world();_build_hud();_update_hud()
 if scenario_name=="justine":
  _refresh_minimap();_apply_camera()
  if not qa_mode and not benchmark_mode:_intro_card()
 else:_toast("Elegí tu primera orden. Podés explorar la cámara antes de avanzar.",7)
 scene_build_ms=Time.get_ticks_msec()-build_start

func _build_hud():
 if _is_j():_build_hud_j();return
 _new_ui();unit_buttons={};action_buttons={};stat_bars={};hud_panels=[]
 cam_goal_active=false;select_flash=0.0;hover_info={};confirm_action="";confirm_timer=0.0
 overlay=Control.new();overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(overlay);overlay.draw.connect(_draw_overlay)
 # Cabecera de una sola línea: el control de tiempo vive aquí, siempre visible.
 var header=_panel(ui,Vector2(20,10),Vector2(1400,0),Color(0.055,0.105,0.12,0.94),Color("394c49"),8);hud_panels.append(header);_anchor(header,0,0,1,0,20,10,-20,10)
 var hv=_hbox(header,10)
 var mark=_vbox(hv,0);mark.custom_minimum_size.x=150
 _label(mark,"JUEGOS DE LA PATRIA",10,GOLD)
 _label(mark,"GÜEMES",22,PAPER,true)
 var heading=_vbox(hv,2);heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 title_label=_label(heading,"",19,PAPER,true)
 phase_label=_label(heading,"",12,MUTED)
 pause_button=_button(hv,"▶  Iniciar",_toggle_pause,36);pause_button.custom_minimum_size.x=128
 pause_button.tooltip_text="Espacio. En la Justina pausa o reanuda el tiempo; en el norte resuelve la ronda."
 speed_button=_button(hv,"1×",_cycle_speed,36);speed_button.custom_minimum_size.x=48
 speed_button.tooltip_text="T. Alterna velocidad normal y acelerada."
 _button(hv,"Guardar · F5",func():_save_game(),36)
 _button(hv,"Objetivo · O",_focus_objective,36)
 _button(hv,"Fuentes",_history_dialog,36)
 _button(hv,"Ajustes",_settings_dialog,36)
 _button(hv,"? · F1",_controls_dialog,36)
 _button(hv,"Menú",_return_menu,36)
 # Columna izquierda: objetivo e información, plegable (tecla I).
 left_panel=_panel(ui,Vector2(20,70),Vector2(272,0),Color(0.055,0.105,0.12,0.92),Color("394c49"),12);hud_panels.append(left_panel)
 var lv=_vbox(left_panel,6)
 var lh=_hbox(lv,4)
 var lt=_label(lh,"OBJETIVO  ·  I",12,GOLD);lt.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var lbtn=_button(lh,"▾",_toggle_info,24);lbtn.custom_minimum_size.x=30;lbtn.tooltip_text="Plegar o desplegar la información (I)"
 left_body=_vbox(lv,8)
 objective_label=_rich(left_body,"",15)
 capture_bar=ProgressBar.new();capture_bar.custom_minimum_size.y=8;capture_bar.show_percentage=false;left_body.add_child(capture_bar)
 info_label=_rich(left_body,"",14)
 # Columna derecha: situación y parte, apiladas por un contenedor para no pisarse.
 var column=_vbox(ui,6);column.custom_minimum_size.x=252;_anchor(column,1,0,1,0,-272,70,-20,70)
 column.mouse_filter=Control.MOUSE_FILTER_IGNORE
 right_panel=_panel(column,Vector2.ZERO,Vector2(252,0),Color(0.055,0.105,0.12,0.92),Color("394c49"),12);hud_panels.append(right_panel)
 var rv=_vbox(right_panel,6)
 var rh=_hbox(rv,4)
 var rt=_label(rh,"SITUACIÓN",12,GOLD);rt.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var rbtn=_button(rh,"▾",_toggle_info,24);rbtn.custom_minimum_size.x=30;rbtn.tooltip_text="Plegar o desplegar la información (I)"
 right_body=_vbox(rv,6)
 enemy_label=_rich(right_body,"",14)
 jev_label=_label(right_body,"",11,MUTED)
 jev_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 journal_panel=_panel(column,Vector2.ZERO,Vector2(252,0),Color(0.055,0.105,0.12,0.92),Color("394c49"),10);hud_panels.append(journal_panel)
 var jv=_vbox(journal_panel,5)
 var jh=_hbox(jv,4)
 var jt=_label(jh,"PARTE DE SITUACIÓN  ·  P",12,GOLD);jt.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 journal_toggle=_button(jh,"▸",_toggle_journal,24);journal_toggle.custom_minimum_size.x=30;journal_toggle.tooltip_text="Abrir o cerrar el parte (P)"
 journal_last=_label(jv,"",12,MUTED);journal_last.clip_text=true;journal_last.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;journal_last.custom_minimum_size.x=226
 log_label=RichTextLabel.new();log_label.bbcode_enabled=true;log_label.custom_minimum_size=Vector2(226,170);log_label.scroll_following=true;log_label.add_theme_font_size_override("normal_font_size",13);jv.add_child(log_label)
 # Panel inferior: agrupaciones, estado con barras y bandeja de órdenes.
 var bottom=_panel(ui,Vector2(100,890),Vector2(1240,0),Color(0.055,0.105,0.12,0.94),Color("394c49"),10);hud_panels.append(bottom)
 bottom.grow_vertical=Control.GROW_DIRECTION_BEGIN;bottom_panel=bottom;_anchor(bottom,0.5,1,0.5,1,-620,-10,620,-10)
 var br=_hbox(bottom,16)
 var groups=_vbox(br,3);groups.custom_minimum_size.x=262
 _label(groups,"AGRUPACIONES  ·  TECLAS 1 / 2 / 3",11,GOLD)
 for i in range(rules.state.units.size()):
  var u=rules.state.units[i]
  var id=str(u.id)
  var button=_button(groups,"",func():_select_unit(id),27)
  button.add_theme_font_size_override("font_size",13)
  button.alignment=HORIZONTAL_ALIGNMENT_LEFT
  unit_buttons[id]=button
 if rules.state.scenario=="justine":
  _button(groups,"Seleccionar todas",func():_select_unit("all"),25)
 var middle=_vbox(br,4);middle.custom_minimum_size.x=330
 selected_label=_label(middle,"",17,PAPER)
 status_label=_label(middle,"",13,MUTED);status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 var stats=_hbox(middle,8)
 _stat_cell(stats,"strength","FUERZA");_stat_cell(stats,"fatigue","FATIGA");_stat_cell(stats,"supply","SUMINISTROS")
 if rules.state.scenario=="norte":
  sector_option=OptionButton.new();sector_option.custom_minimum_size.y=32
  for s in rules.state.sectors:sector_option.add_item(str(s.name));sector_option.set_item_metadata(sector_option.item_count-1,str(s.id))
  sector_option.item_selected.connect(func(index):sector=str(sector_option.get_item_metadata(index));world.selected_sector=sector;_refresh_actions();_update_hud();call_deferred("_release_focus"))
  sector_option.tooltip_text="Sector sobre el que se prepara la orden. Enter abre la lista; flechas eligen; Enter confirma. También [ y ]."
  middle.add_child(sector_option)
 else:
  var tip=_label(middle,"Clic derecho en el terreno: mover  ·  F: enfocar selección",11,MUTED)
  tip.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 action_box=_vbox(br,6);action_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 _refresh_actions()
 # Ayuda contextual: franja con fondo propio, anclada sobre el panel inferior.
 hint_panel=_panel(ui,Vector2(310,722),Vector2(840,0),Color(0.035,0.075,0.09,0.93),Color("7c7653"),9)
 hint_panel.grow_vertical=Control.GROW_DIRECTION_BEGIN;_anchor(hint_panel,0.5,1,0.5,1,-410,-178,430,-178)
 tutorial_label=_label(hint_panel,"",14,Color("f4e9c8"))
 tutorial_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;tutorial_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 toast_label=_label(ui,"",16,PAPER);_anchor(toast_label,0.5,0,0.5,0,-410,70,430,126)
 toast_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;toast_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;toast_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 toast_label.add_theme_stylebox_override("normal",_style(Color(0.04,0.09,0.11,0.94),Color("7c7653"),1,5,13))
 overlay_top=Control.new();overlay_top.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 overlay_top.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(overlay_top);overlay_top.draw.connect(_draw_top_overlay)
 _apply_panel_state()

func _refresh_actions():
 if not is_instance_valid(action_box):return
 for child in action_box.get_children():action_box.remove_child(child);child.queue_free()
 action_buttons={}
 reason_label=null
 if _is_j():_refresh_actions_j();return
 if true:
  _label(action_box,"ORDEN PARA EL SECTOR ELEGIDO",12,GOLD)
  var grid=GridContainer.new();grid.columns=4;grid.add_theme_constant_override("h_separation",6);grid.add_theme_constant_override("v_separation",6);action_box.add_child(grid)
  var legal=rules.legal_campaign_actions(selected,sector)
  for action in ["move","scout","protect","raid","rest","withdraw","assault"]:
   var b=_button(grid,str(ACTION_NAMES[action]),func():_campaign_order(action),30)
   b.add_theme_font_size_override("font_size",13);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
   b.disabled=not legal.has(action) or pending_round
   b.tooltip_text=str(ACTION_HINTS[action])+"\n"+rules.campaign_order_reason(selected,action,sector)
   b.mouse_entered.connect(func():_show_campaign_reason(action))
   b.focus_entered.connect(func():_show_campaign_reason(action))
   b.mouse_exited.connect(func():_show_campaign_reason(""))
   action_buttons[action]=b
  _button(grid,"Cancelar · X",_cancel_order,30)
  var rr=_hbox(action_box,8)
  round_button=_button(rr,"Resolver ronda  →",_resolve_round,33);round_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  round_button.disabled=pending_round or resolution_remaining>0
  round_button.add_theme_color_override("font_color",GOLD)
  _button(rr,"Ver consecuencias",_round_report,33)
  reason_label=_label(action_box,"",12,MUTED);reason_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  _show_campaign_reason("")

func _select_unit(id:String):
 if _is_j():_select_ids(GROUP_IDS.duplicate() if id=="all" else [id]);return
 selected=id;world.selected=id;select_flash=0.5
 if rules.state.scenario=="norte":
  sector=str(rules.get_unit(id).sector_id);world.selected_sector=sector
 _refresh_actions();_update_hud();world.refresh_paths();_sound("order")

func _selected_ids()->Array:
 if _is_j():return sel_ids
 if selected=="all":return ["guemes","arias","zavala"]
 return [selected]

func _campaign_order(action:String):
 if pending_round:return
 var result=rules.issue_campaign_order(selected,action,sector)
 _toast(str(result.reason),4,bool(result.ok));_sound("order" if result.ok else "error")
 _refresh_actions();_update_hud()

func _cancel_order():
 if _is_j():_do_action("cancel");return
 if pending_round:return
 for id in _selected_ids():rules.cancel_order(id)
 world.refresh_paths();_toast("Orden cancelada.",3);_refresh_actions();_update_hud()

func _context()->Dictionary:
 return {"game_id":rules.state.game_id,"round":rules.state.round,"state_version":rules.state.state_version}

func _resolve_round():
 if pending_round or resolution_remaining>0 or rules.state.status!="playing" or rules.state.scenario!="norte":return
 pending_round=true
 _refresh_actions();_toast("Las agrupaciones preparan sus órdenes…",3)
 jev.request_intent(rules.enemy_observation(),rules.enemy_choices(),rules.enemy_fallback(),_context())

func _on_intent(decision:Dictionary):
 if not pending_round or mode!="play" or rules.state.scenario!="norte":return
 if not jev.mark_applied(decision,_context()):
  pending_round=false;_toast("La situación cambió. Volvé a resolver la ronda.",4,false);_refresh_actions();return
 if not rules.record_external_decision(decision):pending_round=false;_refresh_actions();return
 var events=rules.resolve_round(str(decision.choice))
 pending_round=false;resolution_remaining=0.75/speed
 _handle_events(events);_sound("bell");_refresh_actions();_update_hud()
 _save_game(false)
 if rules.state.status=="playing":_toast("Ronda resuelta. Revisá el parte y prepará el siguiente movimiento.",4)

func _update_hud():
 if mode!="play" or not is_instance_valid(title_label):return
 if _is_j():_update_hud_j();return
 var state=rules.state
 title_label.text="II  ·  SOSTENER EL NORTE"
 if true:
  phase_label.text="%s     /     RONDA %d DE 14" % [str(state.date).to_upper(),int(state.round)]
  objective_label.text="[b]Volvé insostenible la invasión.[/b]\nCortá abastecimientos y comunicaciones. Sostené a la población."
  capture_bar.value=100.0-float(state.enemy.supply)
  info_label.text="Apoyo de la población: [b]%d %%[/b]\nReservas propias: [b]%d[/b]\nHumahuaca: %s" % [int(state.population),int(state.stores),"recuperada por Arias" if state.humahuaca else "operación desde marzo"]
  enemy_label.text="[b]CAPACIDAD REALISTA[/b]\nAbastecimiento: %d\nCohesión: %d\nComunicaciones: %d\n\n%s" % [int(state.enemy.supply),int(state.enemy.cohesion),int(state.enemy.communications),"Salta está ocupada.\nLa campaña sigue abierta." if state.enemy.occupied_salta else "El ejército avanza desde el norte."]
  var jev_text=str(jev.status_text)
  jev_label.text=jev_text if jev_text.begins_with("Jev") else "Jev: "+jev_text
  pause_button.text="Resolver  →";speed_button.text=str(int(speed))+"×"
  if is_instance_valid(round_button):round_button.disabled=pending_round or resolution_remaining>0 or state.status!="playing"
  tutorial_label.text=_campaign_tip() if bool(settings.tutorial) else ""
  for i in range(sector_option.item_count):
   if str(sector_option.get_item_metadata(i))==sector and sector_option.selected!=i:sector_option.select(i)
 if is_instance_valid(hint_panel):
  if tutorial_label.text!=last_hint_text:
   last_hint_text=tutorial_label.text;hint_timer=18.0
  hint_panel.visible=not tutorial_label.text.is_empty() and hint_timer>0
  if is_instance_valid(bottom_panel):
   var hint_bottom=bottom_panel.get_global_rect().position.y-8.0-get_viewport().get_visible_rect().size.y
   hint_panel.offset_bottom=hint_bottom;hint_panel.offset_top=hint_bottom
 for u in state.units:
  var id=str(u.id)
  if not unit_buttons.has(id):continue
  var number=state.units.find(u)+1
  var is_selected=selected==id or selected=="all"
  var button:Button=unit_buttons[id]
  button.text=("▸ " if is_selected else "   ")+str(UNIT_GLYPHS[id])+" "+str(number)+" · "+_short_name(id)+"     "+str(int(u.strength))+"%"
  button.add_theme_color_override("font_color",UNIT_COLORS[id])
  button.add_theme_color_override("font_hover_color",UNIT_COLORS[id])
  if is_selected:
   var sel_style=_cached_style("sel"+str(id),Color("29454c"),UNIT_COLORS[id],3,5);sel_style.content_margin_left=14;sel_style.content_margin_right=14;sel_style.content_margin_top=2;sel_style.content_margin_bottom=2
   button.add_theme_stylebox_override("normal",sel_style)
  else:
   button.remove_theme_stylebox_override("normal")
 var ids=_selected_ids()
 var sum_strength=0.0;var sum_fatigue=0.0;var sum_supply=0.0;var count=0
 for id in ids:
  var unit=rules.get_unit(id)
  if unit.is_empty():continue
  sum_strength+=float(unit.strength);sum_fatigue+=float(unit.fatigue);sum_supply+=float(unit.supply);count+=1
 if count>0:
  _set_stat("strength",sum_strength/count,true);_set_stat("fatigue",sum_fatigue/count,false);_set_stat("supply",sum_supply/count,true)
 if selected=="all":
  selected_label.text="Las tres agrupaciones"
  var moving=0;var waiting=0
  for u in state.units:
   if u.stage=="moving":moving+=1
   if u.stage=="waiting_tide":waiting+=1
  status_label.text="%d en marcha · %d esperando la bajante\nLa orden se aplica a cada grupo con su propia ruta." % [moving,waiting]
 else:
  var unit=rules.get_unit(selected)
  selected_label.text=str(UNIT_GLYPHS[selected])+" "+str(unit.name)
  selected_label.add_theme_color_override("font_color",UNIT_COLORS[selected])
  selected_label.add_theme_font_size_override("font_size",15 if str(unit.name).length()>20 else 17)
  var action=str(unit.order.get("action",""))
  var badge=_stage_badge(str(unit.stage))
  status_label.text="%s%s" % [badge,(" · "+str(ACTION_NAMES.get(action,action))) if not action.is_empty() else ""]
 var grouped=_grouped_log(5)
 var lines=[]
 for entry in grouped:
  lines.append("[color=#d9b576]•[/color] "+str(entry.text)+(" [color=#aab7b5](×%d)[/color]" % int(entry.count) if int(entry.count)>1 else ""))
 log_label.text="\n\n".join(lines)
 if is_instance_valid(journal_last):
  journal_last.text="• "+(str(grouped[-1].text) if not grouped.is_empty() else "Sin novedades.")

func _clock(seconds:float)->String:
 return "%02d:%02d" % [int(seconds)/60,int(seconds)%60]

func _process(delta):
 if not is_instance_valid(camera):return
 if qa_mode and mode=="play" and frame_samples.size()<240:frame_samples.append(delta*1000)
 if mode=="play" and not is_instance_valid(modal):_camera_keys(delta)
 _camera_goal_step(delta)
 _apply_camera()
 if mode=="play" and rules.state.status=="playing" and rules.state.scenario=="justine" and not paused and not is_instance_valid(modal):
  _handle_events(rules.tick(delta*speed))
  if rules.state.scenario=="justine":campaign.checkpoint_tick(rules)
 if is_instance_valid(world):world.update_state(delta);_fit_world_labels()
 if mode!="play":return
 if is_instance_valid(world):
  # world.update_state o el cambio de figura pueden recrear etiquetas 3D: se mantienen ocultas.
  for label_3d in world.unit_labels.values():
   if is_instance_valid(label_3d):label_3d.visible=false
 select_flash=maxf(0.0,select_flash-delta)
 shake=maxf(0.0,shake-delta*2.4)
 if flash_alpha>0.0:
  flash_alpha=maxf(0.0,flash_alpha-delta*0.9)
  if is_instance_valid(flash_rect):flash_rect.color=Color(flash_color.r,flash_color.g,flash_color.b,flash_alpha)
 if confirm_timer>0:
  confirm_timer-=delta
  if confirm_timer<=0:confirm_action=""
 _update_hover(delta)
 if _is_j():
  preview_timer-=delta
  if is_instance_valid(map_widget):map_widget.queue_redraw()
  if is_instance_valid(time_ctl):time_ctl.queue_redraw()
 if is_instance_valid(overlay):overlay.queue_redraw()
 if is_instance_valid(overlay_top):overlay_top.queue_redraw()
 if hint_timer>0:hint_timer-=delta
 if resolution_remaining>0:
  resolution_remaining=maxf(0,resolution_remaining-delta)
  if resolution_remaining==0:_refresh_actions()
 update_timer+=delta
 if update_timer>0.25:
  _update_hud();update_timer=0
 if toast_timer>0:toast_timer-=delta
 var alert_on=is_instance_valid(alert_panel) and alert_panel.visible
 if is_instance_valid(toast_label):toast_label.visible=toast_timer>0 and not alert_on
 if is_instance_valid(toast_view):toast_view.visible=toast_timer>0 and toast_pos!=null and not alert_on
 hoof_timer-=delta
 if not paused and hoof_timer<=0 and rules.state.scenario=="justine":
  for u in rules.state.units:
   if u.stage=="moving":_sound("hoof");break
  hoof_timer=0.62/speed
 if rules.state.status!="playing" and not outcome_shown:
  outcome_shown=true;jev.invalidate();pending_round=false;_outcome_dialog()

func _camera_keys(delta):
 if _is_j():_camera_keys_j(delta);return
 var direction=Vector3.ZERO
 var forward=Vector3(-sin(camera_yaw),0,-cos(camera_yaw))
 var right=Vector3(cos(camera_yaw),0,-sin(camera_yaw))
 # Con un control de la interfaz enfocado (p. ej. el desplegable de sectores) las flechas
 # navegan la interfaz y no mueven la cámara; WASD sigue disponible.
 var ui_focus=get_viewport().gui_get_focus_owner()!=null
 if Input.is_physical_key_pressed(KEY_W) or (not ui_focus and Input.is_physical_key_pressed(KEY_UP)):direction+=forward
 if Input.is_physical_key_pressed(KEY_S) or (not ui_focus and Input.is_physical_key_pressed(KEY_DOWN)):direction-=forward
 if Input.is_physical_key_pressed(KEY_A) or (not ui_focus and Input.is_physical_key_pressed(KEY_LEFT)):direction-=right
 if Input.is_physical_key_pressed(KEY_D) or (not ui_focus and Input.is_physical_key_pressed(KEY_RIGHT)):direction+=right
 if direction!=Vector3.ZERO:cam_goal_active=false
 camera_target+=direction*delta*camera_distance*0.32*float(settings.camera_speed)
 camera_target.x=clampf(camera_target.x,-40,40);camera_target.z=clampf(camera_target.z,-32,32)
 if Input.is_physical_key_pressed(KEY_Q):camera_yaw+=delta*0.8
 if Input.is_physical_key_pressed(KEY_E):camera_yaw-=delta*0.8

func _input(event):
 if event is InputEventMouseMotion:hover_mouse=event.position
 elif event is InputEventMouseButton and not event.pressed and mode=="play" and is_instance_valid(world) and _is_j():_j_release(event)

func _unhandled_input(event):
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode==KEY_ESCAPE:
   if is_instance_valid(modal):_close_modal()
   elif get_viewport().gui_get_focus_owner()!=null:_release_focus()
   elif mode=="play" and _is_j():
    if aim!="" or not wp_list.is_empty():_cancel_aim()
    else:_pause_menu()
   elif mode=="play":_controls_dialog()
   return
  if event.keycode==KEY_F11:
   settings.fullscreen=not settings.fullscreen;_apply_fullscreen();_save_settings();return
  if event.keycode==KEY_TAB and get_viewport().gui_get_focus_owner()==null and not (mode=="play" and _is_j()):
   _focus_hud();return
 if mode!="play" or is_instance_valid(modal):return
 if _is_j():_j_input(event);return
 if event is InputEventKey and event.pressed and not event.echo:
  match event.physical_keycode:
   KEY_1:_select_unit("guemes")
   KEY_2:_select_unit("arias")
   KEY_3:_select_unit("zavala")
   KEY_SPACE:_toggle_pause()
   KEY_T:_cycle_speed()
   KEY_X:_cancel_order()
   KEY_O:_focus_objective()
   KEY_F:_focus_selected()
   KEY_I:_toggle_info()
   KEY_P:_toggle_journal()
   KEY_BRACKETLEFT:_step_sector(-1)
   KEY_BRACKETRIGHT:_step_sector(1)
   KEY_F1:_controls_dialog()
   KEY_F5:_save_game()
   KEY_F9:_load_game(str(rules.state.scenario))
   KEY_R:_confirm_restart()
   KEY_H:_history_dialog()
 if event is InputEventMouseButton:
  if event.button_index==MOUSE_BUTTON_WHEEL_UP and event.pressed:
   camera_distance=maxf(18,camera_distance*0.90);cam_goal_active=false
   _zoom_toward_cursor(event.position)
  if event.button_index==MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
   camera_distance=minf(125,camera_distance*1.11);cam_goal_active=false
  if event.button_index==MOUSE_BUTTON_MIDDLE:orbiting=event.pressed
  if event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
   var id=world.pick_unit(camera,event.position)
   if not id.is_empty():_select_unit(id)
   elif rules.state.scenario=="norte":
    var sid=world.pick_sector(camera,event.position)
    if not sid.is_empty():sector=sid;world.selected_sector=sid;_refresh_actions();_update_hud();_sound("order")
  if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
   var sid=world.pick_sector(camera,event.position)
   if not sid.is_empty():sector=sid;world.selected_sector=sid;_campaign_order("move")
 if event is InputEventMouseMotion and orbiting:
  camera_yaw-=event.relative.x*0.006
  camera_pitch=clampf(camera_pitch+event.relative.y*0.004*(-1.0 if settings.invert_orbit else 1.0),0.24,1.35)

func _toggle_pause():
 if rules.state.scenario=="norte":_resolve_round();return
 paused=not paused;auto_start_pending=false
 if not paused:pause_reason=""
 _update_hud();_sound("order")

func _cycle_speed():
 if _is_j():_step_speed(1,true);return
 speed=3.0 if speed==1.0 else 1.0;_update_hud()

func _focus_objective():
 if _is_j():_center_ship();return
 _focus_to(Vector3(1,0,4),96)
 camera_pitch=0.85;camera_yaw=-0.17

func _handle_events(events:Array):
 if _is_j():_handle_events_j(events);return
 for event in events:
  match str(event.get("kind","")):
   "shot":world.cannon_effect();_sound("cannon")
   "victory":_sound("victory")
   "defeat":_sound("error")
   "warning":_sound("alert")
   "boarding":_sound("dismount")
   "tide","humahuaca","occupation","history":_toast(str(event.text),7)

# Un solo cartel transitorio a la vez: el nuevo reemplaza al anterior. Los de prioridad 0 (acuses menores) no pisan
# a uno importante (prioridad >=2) que todavía tiene más de 1,5 s en pantalla.
func _toast(message:String,duration=4.0,good=true,prio:int=1):
 if not is_instance_valid(toast_label):return
 if prio<=0 and toast_timer>1.5 and toast_prio>=2:return
 toast_pos=null;toast_prio=prio
 if _is_j():message=dec_regex.sub(_plain(message),"$1,$2",true)
 toast_label.text=message;toast_label.modulate=Color.WHITE if good else Color("efb69b");toast_timer=duration;toast_label.visible=true

func _toggle_details():
 details_open=not details_open;_apply_details()

func _apply_details():
 for c in detail_ctls:
  if is_instance_valid(c):c.visible=details_open
 if is_instance_valid(details_btn):details_btn.text="Detalles ▾ (munición, avisos, río)" if details_open else "Detalles ▸ (munición, avisos, río)"

func _sound(sound_name):
 if is_instance_valid(audio_manager):audio_manager.play(sound_name)

func _save_path(scenario_name:String)->String:
 return "user://"+("qa_" if qa_mode else "")+"save_"+scenario_name+".json"

func _save_game(notify_user=true):
 if mode!="play":return
 if not notify_user and str(rules.state.status)!="playing":return
 if pending_round:
  if notify_user:_toast("Esperá la resolución de la ronda para guardar.",3)
  return
 var error=rules.save_game(_save_path(str(rules.state.scenario)))
 if error==OK:
  settings.last_save=str(rules.state.scenario);_save_settings()
  if notify_user:_toast("Partida guardada. F9 permite continuar desde este punto.",4)
 elif notify_user:_toast("No se pudo guardar la partida ("+str(error)+").",4,false)

func _load_game(scenario_name:String):
 jev.invalidate();pending_round=false
 var result=rules.load_game(_save_path(scenario_name))
 if not result.ok:
  if scenario_name=="justine":_load_rejected_dialog(str(result.reason))
  elif mode=="play":_toast(str(result.reason),5,false);_refresh_actions()
  else:_simple_dialog("No se pudo continuar",str(result.reason))
  return
 mode="play";outcome_shown=false;paused=true;selected="guemes";sector=str(rules.get_unit("guemes").sector_id)
 sel_ids=["guemes"];aim="";aim_pts=[];wp_list=[];pending_pt=null
 camera_target=Vector3(-6,0,0) if rules.state.scenario=="justine" else Vector3(1,0,4)
 camera_distance=82 if rules.state.scenario=="justine" else 96;camera_pitch=0.91;camera_yaw=-0.17
 camera.far=4000.0 if rules.state.scenario=="justine" else 400.0
 if rules.state.scenario=="justine":_reset_camera_j()
 _rebuild_world();_build_hud();_update_hud();_toast("Partida recuperada. Las órdenes pendientes conservan su estado.",5)
 if rules.state.scenario=="justine":_refresh_minimap()

func _return_menu():
 # El autoguardado al salir no pisa un guardado manual con una partida sin avances ni con una ya terminada.
 if not pending_round and _has_progress():_save_game(false)
 _menu()

func _has_progress()->bool:
 if rules.state.is_empty() or str(rules.state.status)!="playing":return false
 return float(rules.state.elapsed)>0.0 or int(rules.state.round)>1 or not rules.state.orders.is_empty()

func _do_restart():
 var sc=str(rules.state.scenario);_close_modal();_start_game(sc)

func _confirm_restart():
 if mode!="play":return
 var box=_open_modal("¿Reiniciar el escenario?",640,300)
 _rich(box,"Se descarta el progreso actual y el escenario vuelve a empezar. El guardado hecho con F5 no se borra hasta que guardes de nuevo (o termine un autoguardado).",17)
 var row=_hbox(box)
 _button(row,"Sí, reiniciar",_do_restart,40)
 _button(row,"No, seguir jugando",_close_modal,40)

# Altura útil de un área desplazable dentro de un diálogo: no pasa de la deseada y deja lugar a título, botones y márgenes en pantallas bajas.
func _scroll_h(want:float,reserve:float=230.0)->float:
 return clampf(get_viewport().get_visible_rect().size.y-reserve,110.0,want)

func _open_modal(title:String,width=800,height=600)->VBoxContainer:
 if is_instance_valid(modal):_close_modal()
 var vs=get_viewport().get_visible_rect().size
 width=minf(float(width),vs.x-16.0);height=minf(float(height),vs.y-16.0)
 modal_paused=paused;paused=true
 modal=Control.new();modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ui.add_child(modal)
 var shade=ColorRect.new();shade.color=Color(0.015,0.03,0.035,0.985 if _is_j() else 0.94);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);modal.add_child(shade)
 var panel=_panel(modal,Vector2.ZERO,Vector2(width,height),Color("101f25"),Color("887750"))
 _anchor(panel,0.5,0.5,0.5,0.5,-width/2.0,-height/2.0,width/2.0,height/2.0)
 var box=_vbox(panel,14)
 var header=_hbox(box);var label=_label(header,title,27,GOLD,true);label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 _button(header,"Cerrar · Esc",_close_modal,36)
 return box

func _close_modal():
 if is_instance_valid(modal):modal.queue_free()
 modal=null;paused=modal_paused
 if _is_j():hover_info={};hover_mouse=Vector2(-1,-1)  # el cursor que quedó sobre el botón del diálogo no dispara una vista previa (ni un rechazo) hasta que se mueva
 if mode=="play":_update_hud()

func _simple_dialog(title:String,text_value:String):
 var box=_open_modal(title,780,400);_rich(box,text_value,17)

func _controls_dialog():
 var box=_open_modal("Cómo jugar",840,650)
 _rich(box,"[b]Cámara[/b]   WASD o flechas desplazan. Q/E giran. La rueda acerca hacia el cursor. Botón central gira e inclina. O enfoca el objetivo y F la selección. I pliega la información, P abre el parte.\n\n[b]Agrupaciones[/b]   Clic sobre un grupo, o teclas 1, 2 y 3. En la Justina, 4 y 5 seleccionan a los exploradores, y Mayús+clic o un recuadro suman agrupaciones. Clic derecho ordena mover. X cancela la orden pendiente.\n\n[b]Justina[/b]   Tiene su propia ayuda (botón «Ayuda · F1» dentro de la partida) y su tabla de teclas en docs/CONTROLES.md.

[b]Norte[/b]   Elegí grupo y sector con el mapa o el selector. Prepará una orden por grupo; luego resolvé la ronda. Las órdenes se pueden cambiar antes de resolver. Los botones deshabilitados explican el motivo debajo de la bandeja. [ y ] cambian de sector.

[b]Teclado[/b]   Tab entra a la interfaz; Tab y Mayús+Tab recorren los controles; Enter o Espacio activan; Esc suelta el foco.\n\n[b]Continuidad[/b]   F5 guarda. F9 carga. R reinicia el escenario. Cada ronda se guarda automáticamente. H abre las fuentes. F11 alterna pantalla completa.\n\n[b]Consejo[/b]   Explorá antes de hostigar y alterná acciones de presión con protección de recursos y descanso. Esperar pasivamente permite sostener la invasión.",16)
 var check=CheckButton.new();check.text="Mostrar ayudas contextuales";check.button_pressed=bool(settings.tutorial)
 check.toggled.connect(func(on):settings.tutorial=on;_save_settings());box.add_child(check)

func _history_dialog():
 var box=_open_modal("Historia y reconstrucción",1000,746)
 var scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.custom_minimum_size.y=620;box.add_child(scroll)
 var content=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(content)
 var text_value="[b]Cómo leer esta recreación[/b]\n"+str(history_data.get("general_notice","Fuentes documentales, tradición y adaptación jugable se distinguen por separado."))+"\n\n"
 for id in ["justine","norte"]:
  var sc=history_data.get("scenarios",{}).get(id,{})
  text_value+="[color=#d9b576][b]"+str(sc.get("title",id)).to_upper()+"[/b][/color]\n"
  text_value+=str(sc.get("context",""))+"\n\n"+str(sc.get("notice",""))+"\n"+str(sc.get("art_note",""))+"\n\n"
 text_value+="[b]Fuentes de consulta[/b]\n"
 for source in history_data.get("sources",[]):
  text_value+="• "+str(source.get("title",""))+"\n[url="+str(source.get("url",""))+"]"+str(source.get("url",""))+"[/url]\n\n"
 text_value+="[b]Adaptación jugable[/b]\nRutas, posiciones, escalas, agrupaciones, recursos, tiempos, diálogos y resultados alternativos son decisiones de diseño. La morfología del buque, la ropa y las poblaciones son reconstrucciones artísticas. No se incorporaron recursos de Civilization.\n"
 var body=_rich(content,text_value,15);body.custom_minimum_size.x=920
 body.meta_clicked.connect(func(meta):OS.shell_open(str(meta)))

func _settings_dialog():
 var box=_open_modal("Ajustes",740,640)
 _label(box,"GRÁFICOS",12,GOLD)
 var quality_row=_hbox(box);_label(quality_row,"Detalle y sombras",16).size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var quality_select=OptionButton.new();quality_select.custom_minimum_size=Vector2(240,40)
 for q in ["Baja · sin sombras","Media · sombras y 2× MSAA","Alta · sombras y 4× MSAA"]:quality_select.add_item(q)
 quality_select.select(["baja","media","alta"].find(str(settings.quality)))
 quality_select.item_selected.connect(func(i):settings.quality=["baja","media","alta"][i];_rebuild_world();_save_settings())
 quality_row.add_child(quality_select)
 var fullscreen=CheckButton.new();fullscreen.text="Pantalla completa · F11";fullscreen.button_pressed=bool(settings.fullscreen)
 fullscreen.toggled.connect(func(on):settings.fullscreen=on;_apply_fullscreen();_save_settings());box.add_child(fullscreen)
 _label(box,"SONIDO",12,GOLD)
 var volume=HSlider.new();volume.min_value=0;volume.max_value=1;volume.step=0.01;volume.value=float(settings.volume);volume.custom_minimum_size.y=24
 volume.value_changed.connect(func(v):settings.volume=v;if_audio_volume(v));box.add_child(volume)
 var mute=CheckButton.new();mute.text="Silenciar";mute.button_pressed=bool(settings.muted)
 mute.toggled.connect(_set_muted)
 box.add_child(mute)
 _label(box,"CÁMARA Y AYUDAS",12,GOLD)
 var help=CheckButton.new();help.text="Ayudas contextuales";help.button_pressed=bool(settings.tutorial);help.toggled.connect(func(on):settings.tutorial=on;_save_settings());box.add_child(help)
 var ap=CheckButton.new();ap.text="Pausa automática en avisos críticos (Justina)";ap.button_pressed=bool(settings.auto_pause);ap.toggled.connect(func(on):settings.auto_pause=on;_save_settings());box.add_child(ap)
 var invert=CheckButton.new();invert.text="Invertir inclinación de cámara";invert.button_pressed=bool(settings.invert_orbit);invert.toggled.connect(func(on):settings.invert_orbit=on;_save_settings());box.add_child(invert)
 var local=CheckButton.new();local.text="Usar siempre el mando local";local.button_pressed=bool(settings.jev_local)
 local.toggled.connect(func(on):settings.jev_local=on;jev.force_local=on;_save_settings());box.add_child(local)
 _rich(box,"El juego funciona sin conexión. Jev puede elegir intenciones del adversario si configurás una clave fuera del juego. Su respuesta siempre se valida con las reglas.",13)

func if_audio_volume(v):
 if audio_manager:audio_manager.set_volume(float(v))
 _save_settings()

func _set_muted(on):
 settings.muted=on
 if audio_manager:audio_manager.set_muted(on)
 _save_settings()

func _apply_fullscreen():
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if bool(settings.fullscreen) else DisplayServer.WINDOW_MODE_WINDOWED)

func _load_settings():
 var cfg=ConfigFile.new()
 if cfg.load("user://settings.cfg")==OK:
  for key in settings:
   settings[key]=cfg.get_value("preferences",key,settings[key])
 settings.volume=clampf(float(settings.volume),0,1)
 if str(settings.quality) not in ["baja","media","alta"]:settings.quality="media"
 _apply_fullscreen()

func _save_settings():
 var cfg=ConfigFile.new()
 for key in settings:cfg.set_value("preferences",key,settings[key])
 cfg.save("user://settings.cfg")

func _round_report():
 var box=_open_modal("Consecuencias de la ronda",850,580)
 var results=rules.state.get("last_results",[])
 if results.is_empty():_rich(box,"Todavía no se resolvió una ronda. Prepará las órdenes de tus agrupaciones y avanzá.",17);return
 for result in results:
  var difference=float(result.after)-float(result.before)
  _label(box,"%s    %.0f → %.0f    (%+.0f)" % [str(result.label),float(result.before),float(result.after),difference],18,PAPER)
 _spacer(box,8)
 _rich(box,"El parte de situación explica las acciones que produjeron estos cambios. La ocupación temporal de Salta es distinta de la capacidad de sostener la invasión.",16)

func _outcome_dialog():
 if _is_j():
  var rj=rules.campaign_report()
  last_report=rj
  _record_attempt(rj)
  if str(rules.state.status)=="victory":_victory_dialog(rj)
  else:_defeat_dialog(rj)
  return
 var won=rules.state.status=="victory"
 var box=_open_modal("Victoria" if won else "La defensa no alcanzó",850,565)
 _rich(box,str(rules.state.reason),22)
 _spacer(box,10)
 var strength=0.0
 for unit in rules.state.units:strength+=float(unit.strength)
 var details="Fuerza conservada: %.0f de 300\n" % strength
 if rules.state.scenario=="justine":details+="Tiempo de simulación: "+_clock(float(rules.state.elapsed))+"\nCaptura: "+str(int(rules.state.capture))+"%"
 else:details+="Ronda %d · %s\nApoyo de la población: %d%%\nHumahuaca: %s" % [int(rules.state.round),str(rules.state.date),int(rules.state.population),"operación de Arias completada" if rules.state.humahuaca else "sin recuperar"]
 _rich(box,details,17)
 _rich(box,"[color=#aab7b5]El resultado de tu partida es una simulación. Consultá las fuentes para distinguirlo del desenlace histórico.[/color]",14)
 _spacer(box,8)
 var row=_hbox(box)
 _button(row,"Volver a jugar",func():_start_game(str(rules.state.scenario)),47)
 if rules.state.scenario=="justine":_button(row,"Ir a la campaña del norte",func():_start_game("norte"),47)
 _button(row,"Elegir escenario",_menu,47)
 _button(row,"Ver fuentes",_history_dialog,47)

func _qa_capture(name_value:String):
 if qa_path.is_empty():return
 await RenderingServer.frame_post_draw
 var image=get_viewport().get_texture().get_image()
 image.save_png(qa_path.path_join(name_value+".png"))

func _finish_automation(exit_code:int=0):
 # Captures resume inside frame_post_draw. Drain renderer/audio ownership before
 # asking SceneTree to quit; this teardown is only used by QA and benchmarks.
 paused=true;pending_round=false
 set_process(false);set_process_unhandled_input(false)
 if is_instance_valid(jev):jev.invalidate()
 if is_instance_valid(audio_manager):
  audio_manager.shutdown()
 if is_instance_valid(world):world.queue_free()
 if is_instance_valid(layer):layer.queue_free()
 world=null;layer=null;ui=null;modal=null;theme_main=null;title_font=null
 await get_tree().process_frame
 await RenderingServer.frame_post_draw
 await get_tree().create_timer(0.12).timeout
 get_tree().quit(exit_code)

func _qa_run(scenario_name:String):
 # QA automática ejecutada sobre la escena real; no representa una partida humana.
 if qa_path.is_empty():qa_path=OS.get_user_data_dir().path_join("qa")
 DirAccess.make_dir_recursive_absolute(qa_path)
 for i in range(20):await get_tree().process_frame
 if qa_size!=Vector2i.ZERO:
  # Ventana sin bordes cuyo tamaño se fija tras el arranque: el SO no la recorta a la altura útil del monitor.
  var w=get_window();w.mode=Window.MODE_WINDOWED;w.borderless=true;w.size=qa_size;w.position=Vector2i.ZERO
  for i in range(12):await get_tree().process_frame
 await _qa_capture("menu")
 _start_game(scenario_name if scenario_name in ["justine","norte"] else "justine")
 var first_frame_start=Time.get_ticks_msec()
 await RenderingServer.frame_post_draw
 var render_first_ms=Time.get_ticks_msec()-first_frame_start
 paused=true;jev.force_local=true;frame_samples=[]
 for i in range(90):await get_tree().process_frame
 await _qa_capture(str(rules.state.scenario)+"-inicio")
 qa_metrics={"engine":Engine.get_version_info().string,"os":OS.get_name(),"renderer":RenderingServer.get_video_adapter_name(),"resolution":str(get_viewport().get_visible_rect().size),"quality":settings.quality,"scenario":rules.state.scenario,"scene_build_ms":scene_build_ms,"first_frame_ms":render_first_ms,"kind":"automated_render_and_simulation"}
 if rules.state.scenario=="justine":
  await _qa_justina()
 else:
  for round_index in range(14):
   if rules.state.status!="playing":break
   _qa_campaign_orders()
   _resolve_round()
   for i in range(60):await get_tree().process_frame
   resolution_remaining=0
   if int(rules.state.round)==8:await _qa_capture("norte-humahuaca")
  for i in range(35):await get_tree().process_frame
  await _qa_capture("norte-desenlace")
 qa_metrics.status=rules.state.status;qa_metrics.simulated_seconds=rules.state.elapsed;qa_metrics.round=rules.state.round
 qa_metrics.external_decisions=rules.state.external_decisions
 qa_metrics.static_memory_bytes=OS.get_static_memory_usage()
 frame_samples.sort()
 if not frame_samples.is_empty():
  qa_metrics.frame_ms_median=frame_samples[int(frame_samples.size()*0.5)]
  qa_metrics.frame_ms_p95=frame_samples[mini(frame_samples.size()-1,int(frame_samples.size()*0.95))]
  qa_metrics.sample_count=frame_samples.size()
 var output=FileAccess.open(qa_path.path_join(str(rules.state.scenario)+"-render-report.json"),FileAccess.WRITE)
 if output:output.store_string(JSON.stringify(qa_metrics,"\t"));output.close()
 print("QA_RENDER_REPORT "+JSON.stringify(qa_metrics))
 await _finish_automation(0 if (rules.state.status=="victory" or rules.state.scenario=="justine") else 2)

func _qa_campaign_orders():
 var a=rules.get_unit("arias");var g=rules.get_unit("guemes");var support=rules.get_unit("zavala")
 var r=int(rules.state.round)
 if r==1:rules.issue_campaign_order("arias","scout","quebrada")
 elif r==2:rules.issue_campaign_order("arias","move","quebrada")
 elif r>=7 and not rules.state.humahuaca and float(a.supply)>=18 and float(a.strength)>=45 and float(a.fatigue)<=78:rules.issue_campaign_order("arias","assault","humahuaca")
 elif r<=6:rules.issue_campaign_order("arias","scout","humahuaca")
 elif float(a.fatigue)<=65 and float(a.supply)>20:rules.issue_campaign_order("arias","raid","quebrada")
 if float(g.fatigue)>55 or float(g.supply)<25:
  rules.issue_campaign_order("guemes","withdraw" if g.sector_id!="lerma" else "rest","lerma")
 elif r==1 or r%3==0:rules.issue_campaign_order("guemes","scout","jujuy")
 else:rules.issue_campaign_order("guemes","raid","jujuy")
 var s=rules.get_sector(str(support.sector_id))
 if int(s.crates)>0:rules.issue_campaign_order("zavala","protect",str(support.sector_id))
 else:
  var destination="rosario" if support.sector_id=="chicoana" else "lerma"
  rules.issue_campaign_order("zavala","move" if destination!=support.sector_id else "rest",destination)

func _benchmark_run(scenario_name:String):
 if benchmark_quality not in ["baja","media","alta"]:benchmark_quality="media"
 settings.quality=benchmark_quality
 if qa_path.is_empty():qa_path=OS.get_user_data_dir().path_join("benchmark")
 DirAccess.make_dir_recursive_absolute(qa_path)
 _start_game(scenario_name)
 if scenario_name=="justine":
  rules.issue_scout("scout_1","probe",[Vector2(200,264),Vector2(330,264)])
  for i in range(170):rules.tick(1.0)
  paused=false
 for i in range(30):await get_tree().process_frame
 var samples=[]
 var measure_start=Time.get_ticks_usec()
 for i in range(180):
  var before=Time.get_ticks_usec()
  await get_tree().process_frame
  samples.append((Time.get_ticks_usec()-before)/1000.0)
 var measured_sec=(Time.get_ticks_usec()-measure_start)/1000000.0
 samples.sort()
 var report={"scenario":scenario_name,"quality":benchmark_quality,"engine":Engine.get_version_info().string,"os":OS.get_name(),"renderer":RenderingServer.get_video_adapter_name(),"viewport":str(get_viewport().get_visible_rect().size),"render_3d_scale":get_viewport().scaling_3d_scale,"frames":180,"measurement_seconds":measured_sec,"mean_fps":180.0/measured_sec,"frame_ms_median":samples[90],"frame_ms_p95":samples[171],"engine_static_memory_bytes":OS.get_static_memory_usage(),"scene_build_ms":scene_build_ms,"pid":OS.get_process_id(),"scope":"isolated automated local rendering; not the user PC"}
 await _qa_capture(scenario_name+"-"+benchmark_quality)
 var f=FileAccess.open(qa_path.path_join(scenario_name+"-"+benchmark_quality+"-benchmark.json"),FileAccess.WRITE)
 if f:f.store_string(JSON.stringify(report,"\t"));f.close()
 print(JSON.stringify(report))
 await _finish_automation()

func _stat_cell(parent:Node,key:String,title:String):
 var box=_vbox(parent,2);box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var text_label=_label(box,title,11,MUTED)
 var bar=ProgressBar.new();bar.custom_minimum_size=Vector2(80,8);bar.show_percentage=false;bar.min_value=0;bar.max_value=100;box.add_child(bar)
 stat_bars[key]={"bar":bar,"label":text_label,"title":title}

func _set_stat(key:String,value:float,good_high:bool):
 var entry=stat_bars.get(key)
 if entry==null:return
 var v=clampf(value,0,100)
 entry.bar.value=v
 var quality=v if good_high else 100.0-v
 var word="bien" if quality>=60 else ("justa" if quality>=35 else "crítica")
 var color=GREEN if quality>=60 else (GOLD if quality>=35 else RED)
 entry.label.text="%s %d · %s" % [str(entry.title),int(round(v)),word]
 entry.label.add_theme_color_override("font_color",color)
 entry.bar.add_theme_stylebox_override("fill",_cached_style("fill"+color.to_html(),color,Color.TRANSPARENT,0,3))

func _cached_style(key:String,color:Color,border:Color,width:int,radius:int)->StyleBoxFlat:
 if not style_cache.has(key):style_cache[key]=_style(color,border,width,radius,0)
 return style_cache[key]

func _apply_panel_state():
 if is_instance_valid(left_body):left_body.visible=info_open
 if is_instance_valid(right_body):right_body.visible=info_open
 if is_instance_valid(log_label):log_label.visible=journal_open
 if is_instance_valid(journal_last):journal_last.visible=not journal_open
 if is_instance_valid(journal_toggle):journal_toggle.text="▾" if journal_open else "▸"
 for panel in [left_panel,right_panel,journal_panel]:
  if is_instance_valid(panel):panel.set_deferred("size",Vector2(panel.size.x,0))

func _toggle_info():
 info_open=not info_open;_apply_panel_state()

func _toggle_journal():
 journal_open=not journal_open;_apply_panel_state()

func _blur_after_click():
 # Un clic de mouse no debe dejar el foco en el botón: Espacio y las teclas 1-4 siguen
 # siendo atajos de juego. Con Espacio/Enter (teclado) el foco se conserva.
 if Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_KP_ENTER):return
 call_deferred("_release_focus")

func _release_focus():
 var vp=get_viewport()
 if vp:vp.gui_release_focus()

func _focus_hud():
 var root:Node=modal if is_instance_valid(modal) else ui
 if not is_instance_valid(root):return
 if mode=="play" and not is_instance_valid(modal) and selected!="all" and unit_buttons.has(selected):
  unit_buttons[selected].grab_focus();return
 for b in root.find_children("*","Button",true,false):
  if b is Button and not b.disabled and b.is_visible_in_tree() and b.focus_mode==Control.FOCUS_ALL:
   b.grab_focus();return

func _toggle_shelf():
 shelf_open=not shelf_open;_refresh_actions()

func _show_campaign_reason(action:String):
 if not is_instance_valid(reason_label):return
 if action.is_empty():
  var legal=rules.legal_campaign_actions(selected,sector)
  var sname=str(rules.get_sector(sector).get("name",sector))
  reason_label.text="%d de 7 órdenes disponibles en %s. Pasá el mouse o Tab sobre una orden para ver su efecto o por qué está bloqueada." % [legal.size(),sname]
  return
 var legal_now=rules.legal_campaign_actions(selected,sector).has(action)
 var text=str(ACTION_HINTS[action])+"\n"
 if legal_now:
  text+=_readiness_text(action)
 else:
  text+="Bloqueada: "+rules.campaign_order_reason(selected,action,sector)
 reason_label.text=text

func _readiness_text(action:String)->String:
 # Estimación de interfaz: usa las mismas cuentas que game_rules._resolve_raid, sin ejecutar nada.
 var u=rules.get_unit(selected)
 if action=="assault":return "Disponible. Resultado fijo: la acción recupera Humahuaca; cuesta 10 de fuerza, 18 de suministros y 22 de fatiga, sin azar."
 if action!="raid" or u.is_empty():return "Disponible."
 var s=rules.get_sector(sector)
 var informed=int(s.get("intel_until",0))>=int(rules.state.round)
 var effectiveness=maxf(0.45,(float(u.strength)/100.0)*(1.0-float(u.fatigue)*0.003))
 var low=4 if informed else 8
 var high=low+4+(3 if str(s.id)==str(rules.state.enemy.position) else 0)
 var verdict="Favorable" if informed and effectiveness>=0.6 else ("Parejo" if informed or effectiveness>=0.7 else "Desfavorable")
 return "Disponible. Previsión: %s (%s; eficacia %d %%). Pérdidas esperadas: %d a %d efectivos." % [verdict,"con reconocimiento reciente" if informed else "sin reconocimiento reciente",int(effectiveness*100),low,high]

func _step_sector(direction:int):
 if rules.state.scenario!="norte" or pending_round:return
 var ids=[]
 for s in rules.state.sectors:ids.append(str(s.id))
 var index=ids.find(sector)
 sector=ids[posmod(index+direction,ids.size())]
 world.selected_sector=sector;_refresh_actions();_update_hud();_sound("order")

func _short_name(id:String)->String:
 if rules.state.scenario=="norte":return "Güemes" if id=="guemes" else ("Arias" if id=="arias" else "Partida del valle")
 if id in SCOUT_IDS:return "Explorador "+id.right(1)
 return "Güemes y jinetes (trad.)" if id=="guemes" else ("Voluntarios" if id=="arias" else "Reserva")

func _stage_badge(stage_id:String)->String:
 var pair=STAGE_TEXT.get(stage_id,["·",stage_id])
 return str(pair[0])+" "+str(pair[1])

func _grouped_log(limit:int)->Array:
 # Las líneas consecutivas casi idénticas (p. ej. descargas de artillería) se resumen con un contador.
 var n=rules.state.log.size()
 var out=[]
 for i in range(maxi(0,n-16),n):
  var text=str(rules.state.log[i].text)
  var key=log_regex.sub(text,"#",true)
  if not out.is_empty() and out[-1].key==key:
   out[-1].count+=1;out[-1].text=text
  else:
   out.append({"key":key,"text":text,"count":1,"kind":str(rules.state.log[i].get("kind","info")),"pos":rules.state.log[i].get("pos",null)})
 return out.slice(maxi(0,out.size()-limit))

func _campaign_tip()->String:
 var ordered=0
 for u in rules.state.units:
  if not u.order.is_empty():ordered+=1
 if ordered==0:
  return "Paso 1 de 3 · Elegí una agrupación (1, 2, 3) y un sector (clic en el mapa, lista o [ y ]). Paso 2: tocá una orden. Paso 3: «Resolver ronda» (Espacio)."
 if ordered<3:
  return "%d de 3 agrupaciones con orden. Podés dar una orden por grupo y cambiarla antes de resolver. «Reconocer» antes de «Hostigar» reduce las pérdidas." % ordered
 return "Las tres agrupaciones tienen orden. Pulsá «Resolver ronda» o Espacio; después revisá «Ver consecuencias» para saber qué cambió."

func _camera_goal_step(delta):
 if not cam_goal_active:return
 var k=1.0-exp(-delta*6.0)
 camera_target=camera_target.lerp(cam_goal_target,k)
 camera_distance=lerpf(camera_distance,cam_goal_distance,k)
 if _is_j():camera_target=world.clamp_camera_target(camera_target)
 else:camera_target.x=clampf(camera_target.x,-40,40);camera_target.z=clampf(camera_target.z,-32,32)
 if camera_target.distance_to(cam_goal_target)<0.05 and absf(camera_distance-cam_goal_distance)<0.1:cam_goal_active=false

func _focus_to(target:Vector3,distance:float):
 if _is_j():
  cam_goal_target=world.clamp_camera_target(target)
  cam_goal_distance=clampf(distance,float(cam_cfg.get("min_distance_m",25)),float(cam_cfg.get("max_distance_m",900)));cam_goal_active=true
  return
 cam_goal_target=Vector3(clampf(target.x,-40,40),target.y,clampf(target.z,-32,32))
 cam_goal_distance=clampf(distance,18,125);cam_goal_active=true

func _focus_selected():
 if _is_j():_center_selection();return
 if not is_instance_valid(world):return
 var total=Vector3.ZERO;var n=0
 for id in _selected_ids():
  if world.unit_nodes.has(id):
   total+=world.unit_nodes[id].root.global_position;n+=1
 if n==0:return
 _focus_to(total/n,minf(camera_distance,70.0))
 _toast("Cámara enfocada en la selección. Cualquier desplazamiento manual la suelta.",2.5)

func _ground_point(mouse_pos:Vector2)->Variant:
 # El terreno tiene colisión solo donde hay tierra; si el rayo cae sobre el agua se usa el plano del río,
 # para poder explicar por qué ese destino no es válido en lugar de ignorar el clic.
 var p=world.pick_ground(camera,mouse_pos)
 if p!=null:return p
 return Plane(Vector3.UP,0.0).intersects_ray(camera.project_ray_origin(mouse_pos),camera.project_ray_normal(mouse_pos))

func _zoom_toward_cursor(mouse_pos:Vector2):
 if mode!="play" or not is_instance_valid(world):return
 var p=world.pick_ground(camera,mouse_pos)
 if p==null:return
 camera_target=camera_target.lerp(Vector3(p.x,camera_target.y,p.z),0.18)
 camera_target.x=clampf(camera_target.x,-40,40);camera_target.z=clampf(camera_target.z,-32,32)

func _is_selected(id:String)->bool:
 if _is_j():return sel_ids.has(id)
 return selected==id or selected=="all"

func _blocked_rects()->Array:
 var rects=[]
 for panel in hud_panels:
  if is_instance_valid(panel) and panel.is_visible_in_tree():rects.append(panel.get_global_rect().grow(4.0))
 if _is_j():
  for extra in [pause_banner,alert_panel,hint_panel,toast_label]:
   if is_instance_valid(extra) and extra.is_visible_in_tree():rects.append(extra.get_global_rect().grow(4.0))
 elif is_instance_valid(hint_panel) and hint_panel.visible:rects.append(hint_panel.get_global_rect().grow(4.0))
 return rects

# ---------- Despliegue previo ----------

func _overlaps_any(rect:Rect2,list:Array)->bool:
 for r in list:
  if rect.intersects(r):return true
 return false

func _update_hover(delta):
 # Anticipación de órdenes (Civ VII: modo -> vista previa en hover -> confirmación).
 if _is_j():_update_hover_j(delta);return
 hover_timer-=delta
 if hover_timer>0:return
 hover_timer=0.08
 hover_info={}
 if mode!="play" or is_instance_valid(modal) or not is_instance_valid(world) or rules.state.status!="playing":return
 var mp=hover_mouse
 if not get_viewport().get_visible_rect().has_point(mp):return
 for r in _blocked_rects():
  if r.has_point(mp):return
 if true:
  var sid=world.pick_sector(camera,mp)
  if sid.is_empty():return
  var legal=rules.legal_campaign_actions(selected,sid).has("move")
  hover_info={"kind":"sector","sector":sid,"ok":legal,"text":("Clic derecho: preparar Mover a %s" % str(rules.get_sector(sid).get("name",sid))) if legal else ("Mover no disponible: "+rules.campaign_order_reason(selected,"move",sid))}

func _font()->Font:
 if theme_main!=null and theme_main.default_font!=null:return theme_main.default_font
 return ThemeDB.fallback_font

func _project(p:Vector3)->Variant:
 if camera.is_position_behind(p):return null
 return camera.unproject_position(p)

func _ground_circle(center:Vector3,radius:float,steps:int=40)->PackedVector2Array:
 var pts=PackedVector2Array()
 for i in range(steps+1):
  var a=TAU*float(i)/float(steps)
  var q=center+Vector3(cos(a)*radius,0.2,sin(a)*radius)
  if camera.is_position_behind(q):return PackedVector2Array()
  pts.append(camera.unproject_position(q))
 return pts

func _path_points(u:Dictionary,start:Vector3)->PackedVector2Array:
 var pts=PackedVector2Array()
 var s=_project(start+Vector3(0,0.3,0))
 if s==null:return pts
 pts.append(s)
 for node in u.get("path",[]):
  var x=float(node[0]) if node is Array else float(node.get("x",0))
  var z=float(node[1]) if node is Array else float(node.get("z",0))
  var q=_project(Vector3(x,_ground_y(x,z)+0.25,z))
  if q==null:break
  pts.append(q)
 return pts

func _draw_overlay():
 if mode!="play" or not is_instance_valid(world) or not is_instance_valid(camera):return
 var font=_font()
 var blocked=_blocked_rects()
 var placed=[]
 if _is_j():_draw_overlay_j(font,blocked,placed);last_overlay_rects=placed;return
 _draw_routes()
 _draw_hover(font)
 _draw_rings()
 _draw_chips(font,placed)
 _draw_map_labels(font,blocked,placed)
 last_overlay_rects=placed

func _draw_routes():
 if not world.show_paths:return
 for u in rules.state.units:
  var id=str(u.id)
  if float(u.strength)<=0.0 or u.path.is_empty() or not world.unit_nodes.has(id):continue
  var pts=_path_points(u,world.unit_nodes[id].root.global_position)
  if pts.size()<2:continue
  var c:Color=UNIT_COLORS[id]
  if _is_selected(id):
   overlay.draw_polyline(pts,Color(0.03,0.06,0.07,0.75),6.0,true)
   overlay.draw_polyline(pts,c,3.0,true)
  else:
   for i in range(pts.size()-1):overlay.draw_dashed_line(pts[i],pts[i+1],Color(c.r,c.g,c.b,0.55),2.0,9.0)
  var end=pts[pts.size()-1]
  overlay.draw_circle(end,8.0,Color(0.03,0.06,0.07,0.85))
  overlay.draw_circle(end,5.0,c)
  var font=_font()
  overlay.draw_string(font,end+Vector2(-4,5),str(UNIT_GLYPHS[id]),HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color(0.03,0.06,0.07))

func _draw_hover(font):
 if hover_info.is_empty():return
 var mp=hover_mouse
 var ok=bool(hover_info.ok)
 var c=Color("a6e3b8") if ok else Color("f4a58d")
 var view=get_viewport().get_visible_rect().size
 if str(hover_info.kind)=="ground":
  var u=rules.get_unit(_selected_ids()[0])
  if world.unit_nodes.has(str(u.id)) and ok:
   var pts=PackedVector2Array()
   var start=_project(world.unit_nodes[str(u.id)].root.global_position+Vector3(0,0.3,0))
   if start!=null:pts.append(start)
   for node in hover_info.path:
    var q=_project(Vector3(float(node.x),maxf(world.terrain_height(float(node.x),float(node.z)),float(rules.state.get("water_level",0)))+0.25,float(node.z)))
    if q!=null:pts.append(q)
   for i in range(pts.size()-1):overlay.draw_dashed_line(pts[i],pts[i+1],Color(0.97,0.95,0.85,0.95),2.5,10.0)
  var tp=_project(hover_info.point+Vector3(0,0.2,0))
  if tp!=null:
   var ring=_ground_circle(hover_info.point,1.3,24)
   if ring.size()>1:overlay.draw_polyline(ring,c,3.0,true)
   var mark="✓" if ok else "✕"
   overlay.draw_string(font,tp+Vector2(-6,6),mark,HORIZONTAL_ALIGNMENT_LEFT,-1,18,c)
 else:
  var sector_node=world.sector_nodes.get(str(hover_info.sector),{})
  var origin_node=world.sector_nodes.get(str(rules.get_unit(selected).sector_id),{})
  if not sector_node.is_empty() and not origin_node.is_empty():
   var a=_project(origin_node.root.global_position+Vector3(0,0.5,0));var b=_project(sector_node.root.global_position+Vector3(0,0.5,0))
   if a!=null and b!=null:
    overlay.draw_dashed_line(a,b,Color(c.r,c.g,c.b,0.95),3.0,10.0)

func _draw_top_overlay():
 if _is_j():_draw_top_j();return
 if mode!="play" or hover_info.is_empty() or not is_instance_valid(world):return
 var ok=bool(hover_info.ok)
 var c=Color("a6e3b8") if ok else Color("f4a58d")
 _tip_box(_font(),("✓ " if ok else "✕ ")+str(hover_info.text),hover_mouse+Vector2(18,22),c,get_viewport().get_visible_rect().size)

func _tip_box(font,text_value:String,pos:Vector2,accent:Color,view:Vector2):
 var width=300.0
 var size_text=font.get_multiline_string_size(text_value,HORIZONTAL_ALIGNMENT_LEFT,width,13)
 var rect=Rect2(pos,size_text+Vector2(16,12))
 rect.position.x=minf(rect.position.x,view.x-rect.size.x-6);rect.position.y=minf(rect.position.y,view.y-rect.size.y-6)
 overlay_top.draw_style_box(_cached_style("tip"+accent.to_html(),Color(0.03,0.07,0.09,0.94),accent,2,5),rect)
 overlay_top.draw_multiline_string(font,rect.position+Vector2(8,19),text_value,HORIZONTAL_ALIGNMENT_LEFT,width,13,-1,Color("f4efe0"))

func _draw_rings():
 for u in rules.state.units:
  var id=str(u.id)
  if float(u.strength)<=0.0 or not world.unit_nodes.has(id):continue
  var pos:Vector3=world.unit_nodes[id].root.global_position
  var c:Color=UNIT_COLORS[id]
  if _is_selected(id):
   var pts=_ground_circle(pos,3.4)
   if pts.size()>1:
    overlay.draw_polyline(pts,Color(0.03,0.06,0.07,0.7),6.0,true)
    overlay.draw_polyline(pts,c,3.5,true)
   for k in range(4):
    var a=float(k)*PI*0.5+PI*0.25
    var p1=_project(pos+Vector3(cos(a)*3.0,0.2,sin(a)*3.0));var p2=_project(pos+Vector3(cos(a)*4.1,0.2,sin(a)*4.1))
    if p1!=null and p2!=null:overlay.draw_line(p1,p2,c,3.5,true)
   if select_flash>0:
    var t=select_flash/0.5
    var wave=_ground_circle(pos,3.4+(1.0-t)*4.5)
    if wave.size()>1:overlay.draw_polyline(wave,Color(1,1,1,t*0.9),3.0,true)
  else:
   var faint=_ground_circle(pos,2.7,28)
   if faint.size()>1:overlay.draw_polyline(faint,Color(c.r,c.g,c.b,0.5),1.5,true)

func _draw_chips(font,placed:Array):
 var view=get_viewport().get_visible_rect().size
 var order=[]
 for u in rules.state.units:
  if _is_selected(str(u.id)):order.push_front(u)
  else:order.push_back(u)
 for u in order:
  var id=str(u.id)
  if float(u.strength)<=0.0 or not world.unit_nodes.has(id):continue
  var anchor=_project(world.unit_nodes[id].root.global_position+Vector3(0,3.2,0))
  if anchor==null or not Rect2(Vector2(10,10),view-Vector2(20,20)).has_point(anchor):continue
  var is_sel=_is_selected(id)
  var c:Color=UNIT_COLORS[id]
  var chip=Vector2(168,54) if is_sel else Vector2(112,24)
  var rect=Rect2(anchor-Vector2(chip.x*0.5,chip.y+6),chip)
  var tries=0
  while tries<6 and _overlaps_any(rect.grow(2),placed):
   rect.position.y-=chip.y+4.0;tries+=1
  rect.position.x=clampf(rect.position.x,4.0,view.x-chip.x-4.0);rect.position.y=clampf(rect.position.y,60.0,view.y-chip.y-4.0)
  placed.append(rect)
  if rect.end.y<anchor.y-8.0 or tries>0:overlay.draw_line(Vector2(rect.position.x+chip.x*0.5,rect.end.y),anchor,Color(c.r,c.g,c.b,0.8),1.5,true)
  overlay.draw_style_box(_cached_style("chip"+str(is_sel)+c.to_html(),Color(0.035,0.075,0.09,0.9),c if is_sel else Color(c.r,c.g,c.b,0.6),3 if is_sel else 1,5),rect)
  var strength=float(u.strength)
  var bar_color=GREEN if strength>=60 else (GOLD if strength>=35 else RED)
  var title=str(UNIT_GLYPHS[id])+" "+str(rules.state.units.find(u)+1)+" "+_short_name(id)
  if is_sel:
   overlay.draw_string(font,rect.position+Vector2(8,17),title,HORIZONTAL_ALIGNMENT_LEFT,100,13,c)
   overlay.draw_string(font,rect.position+Vector2(chip.x-60,17),"%d %%" % int(strength),HORIZONTAL_ALIGNMENT_RIGHT,52,13,Color("f4efe0"))
   overlay.draw_rect(Rect2(rect.position+Vector2(8,23),Vector2(chip.x-16,6)),Color("31433e"))
   overlay.draw_rect(Rect2(rect.position+Vector2(8,23),Vector2((chip.x-16)*clampf(strength/100.0,0,1),6)),bar_color)
   overlay.draw_rect(Rect2(rect.position+Vector2(8,30),Vector2((chip.x-16)*clampf(float(u.fatigue)/100.0,0,1),2)),Color("c9b6a0"))
   var state_text=_stage_badge(str(u.stage))
   overlay.draw_string(font,rect.position+Vector2(8,46),state_text,HORIZONTAL_ALIGNMENT_LEFT,chip.x-14,11,Color("e9e3d4"))
  else:
   overlay.draw_string(font,rect.position+Vector2(7,16),str(UNIT_GLYPHS[id])+" "+str(rules.state.units.find(u)+1)+"  %d %%" % int(strength),HORIZONTAL_ALIGNMENT_LEFT,chip.x-10,12,c)
   overlay.draw_rect(Rect2(rect.position+Vector2(6,19),Vector2(chip.x-12,3)),Color("31433e"))
   overlay.draw_rect(Rect2(rect.position+Vector2(6,19),Vector2((chip.x-12)*clampf(strength/100.0,0,1),3)),bar_color)

func _draw_map_labels(font,blocked:Array,placed:Array):
 var view=get_viewport().get_visible_rect().size
 var items=[]
 if rules.state.scenario=="norte":
  for sid in world.sector_nodes:
   var entry=world.sector_nodes[sid]
   if not is_instance_valid(entry.label):continue
   var priority=10 if sid==sector else (5 if bool(rules.get_sector(sid).get("known",false)) else 3)
   items.append({"text":str(entry.label.text),"pos":entry.root.global_position+Vector3(0,2.6,0),"prio":priority,"color":entry.label.modulate,"size":15 if sid==sector else 13})
 for label_3d in overlay_labels:
  if not is_instance_valid(label_3d):continue
  var text_value=str(label_3d.text)
  var priority=2
  if text_value.begins_with("JUSTINE") or text_value.begins_with("◆"):priority=8
  elif text_value.begins_with("BANCO") or text_value.begins_with("RODEO"):priority=6
  items.append({"text":text_value,"pos":label_3d.global_position,"prio":priority,"color":label_3d.modulate,"size":13})
 items.sort_custom(func(a,b):return int(a.prio)>int(b.prio))
 for item in items:
  var p=_project(item.pos)
  if p==null:continue
  var text_size=font.get_string_size(str(item.text),HORIZONTAL_ALIGNMENT_LEFT,-1,int(item.size))
  var rect=Rect2(p-Vector2(text_size.x*0.5+6,text_size.y*0.5+3),text_size+Vector2(12,6))
  if not Rect2(Vector2.ZERO,view).encloses(rect):continue
  if _overlaps_any(rect,blocked) or _overlaps_any(rect,placed):continue
  placed.append(rect)
  var color:Color=item.color
  overlay.draw_style_box(_cached_style("lab",Color(0.03,0.07,0.09,0.72),Color.TRANSPARENT,0,4),rect)
  overlay.draw_string(font,rect.position+Vector2(6,text_size.y*0.5+rect.size.y*0.5-4),str(item.text),HORIZONTAL_ALIGNMENT_LEFT,-1,int(item.size),Color(color.r,color.g,color.b,1.0))

# =====================================================================================
# JUSTINA (contrato v1). La interfaz solo LEE el estado y escribe mediante métodos de Reglas.
# =====================================================================================
const J_NICE = [2,5,10,20,30,50,100,200,300,500,1000]
var hover_action = ""
var hover_stamp = 0
var ford_cache = []
var last_report = {}
var clock_label: Label
var state_label: RichTextLabel

# Glifo de la unidad en Justina: el del tag de fuente (source_tags), nunca una tabla fija.
func _ujg(id:String)->String:
 var a=_actor(id)
 return _tag_glyph(str(a.get("tag","diseno"))) if not a.is_empty() else "▲"

func _is_j()->bool:
 return str(rules.state.get("scenario",""))=="justine"

func _jmap()->Dictionary:
 return rules.map_data()

func _tag_info(tag:String)->Dictionary:
 return _jmap().get("source_tags",{}).get(tag,{})

func _tag_glyph(tag:String)->String:
 return str(_tag_info(tag).get("glyph","·"))

func _tag_color(tag:String)->Color:
 return Color(str(_tag_info(tag).get("color","#aab7b5")))

func _tag_label(tag:String)->String:
 return str(_tag_info(tag).get("label",tag))

func _ground_y(x:float,z:float)->float:
 if _is_j():return maxf(rules.terrain_height_at(x,z),rules.water_level_m())
 return maxf(world.terrain_height(x,z),float(rules.state.get("water_level",0)))

func _actor(id:String)->Dictionary:
 if id in SCOUT_IDS:
  for s in rules.scouts():
   if str(s.id)==id:return s
  return {}
 return rules.get_unit(id)

func _actor_pos(id:String)->Vector2:
 var a=_actor(id)
 if a.is_empty():return Vector2.ZERO
 return Vector2(float(a.x),float(a.z))

func _actor_number(id:String)->int:
 return ALL_ACTORS.find(id)+1

func _sel_groups()->Array:
 var out=[]
 for id in sel_ids:
  if id in GROUP_IDS:out.append(id)
 return out

func _sel_scouts()->Array:
 var out=[]
 for id in sel_ids:
  if id in SCOUT_IDS:out.append(id)
 return out

func _reset_camera_j():
 cam_cfg=_jmap().get("camera",{})
 camera_pitch=deg_to_rad(float(cam_cfg.get("pitch_deg_default",55.0)))
 camera_yaw=0.0
 camera.far=float(cam_cfg.get("far_m",4000.0))
 # Vista inicial con contexto: grupos, barranca, orilla y buque en el mismo cuadro.
 var pts=[]
 for g in _jmap().get("groups",[]):pts.append(Vector2(float(g.x),float(g.z)))
 var sp=rules.ship_position();pts.append(sp)
 var r=Rect2(pts[0],Vector2.ZERO)
 for q in pts:r=r.expand(q)
 _fit_rect(r.grow(46.0),false)
 cam_goal_active=false

# Encuadra un rectángulo del mundo (centro, distancia y inclinación) de modo que sus cuatro esquinas entren
# en la pantalla, sin pasar el máximo de zoom. Con smooth=true el movimiento es suave.
func _fit_rect(r:Rect2,smooth:bool,pitch_deg:float=-1.0,full:bool=false):
 if pitch_deg>0:camera_pitch=deg_to_rad(pitch_deg)
 var c=r.get_center()
 var tgt=Vector3(c.x,0,c.y)
 var view=get_viewport().get_visible_rect().size
 var inner=Rect2(Vector2(24,64),view-Vector2(48,64+120))
 # Con la interfaz de Justina, el encuadre usa solo el hueco libre entre el panel de agrupaciones, el de río y el panel inferior.
 if _is_j() and not full:inner=Rect2(Vector2(268,70),Vector2(maxf(300.0,view.x-268.0-296.0),maxf(300.0,view.y-70.0-160.0)))
 var save_t=camera_target;var save_d=camera_distance
 var d=float(cam_cfg.get("min_distance_m",25.0))
 var maxd=float(cam_cfg.get("max_distance_m",900.0))
 camera_target=tgt
 while d<maxd:
  camera_distance=d;_apply_camera()
  var ok=true
  for corner in [r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)]:
   var wp=Vector3(corner.x,_ground_y(corner.x,corner.y),corner.y)
   if camera.is_position_behind(wp) or not inner.has_point(camera.unproject_position(wp)):ok=false;break
  if ok:break
  d*=1.06
 d=minf(d,maxd)
 camera_target=save_t;camera_distance=save_d
 if smooth:_focus_to(tgt,d)
 else:
  camera_target=tgt;camera_distance=d;cam_goal_active=false;_apply_camera()

func _view_all():
 var sz=rules.map_size()
 _fit_rect(Rect2(Vector2.ZERO,sz),true,62.0,true)

func _apply_camera():
 var offset=Vector3(sin(camera_yaw)*cos(camera_pitch),sin(camera_pitch),cos(camera_yaw)*cos(camera_pitch))*camera_distance
 camera.position=camera_target+offset
 if _is_j() and rules.state.has("map_id"):
  var floor_y=_ground_y(camera.position.x,camera.position.z)+3.0
  if camera.position.y<floor_y:camera.position.y=floor_y
 var look=camera_target
 if shake>0.01 and not qa_mode:
  var amp=shake*camera_distance*0.006
  var jit=Vector3(randf_range(-1,1),randf_range(-0.6,0.6),randf_range(-1,1))*amp
  camera.position+=jit;look+=jit*0.4
 camera.look_at(look)

func _key_down(code:int)->bool:
 return Input.is_physical_key_pressed(code) or bool(qa_keys.get(code,false))

func _window_focused()->bool:
 if qa_focus_override>=0:return qa_focus_override==1
 return get_window().has_focus()

func _pan_dir()->Vector2:
 var d=Vector2.ZERO
 var ui_focus=get_viewport().gui_get_focus_owner()!=null
 if _key_down(KEY_W) or (not ui_focus and _key_down(KEY_UP)):d.y+=1
 if _key_down(KEY_S) or (not ui_focus and _key_down(KEY_DOWN)):d.y-=1
 if _key_down(KEY_A) or (not ui_focus and _key_down(KEY_LEFT)):d.x-=1
 if _key_down(KEY_D) or (not ui_focus and _key_down(KEY_RIGHT)):d.x+=1
 return d

func drag_active()->bool:
 return (rmb_down or mmb_down) and rmb_drag

func _edge_dir()->Vector2:
 # Paneo por borde: solo con ventana enfocada, el ratón dentro, sin modal ni arrastre/caja activos.
 if not _window_focused() or is_instance_valid(modal) or drag_active() or box_active or lmb_down:return Vector2.ZERO
 var mp=hover_mouse
 var view=get_viewport().get_visible_rect().size
 if mp.x<0 or mp.y<0 or mp.x>view.x or mp.y>view.y:return Vector2.ZERO
 for r in _blocked_rects():
  if r.has_point(mp):return Vector2.ZERO
 var e=float(cam_cfg.get("edge_pan_px",14))
 var d=Vector2.ZERO
 if mp.x<=e:d.x-=1
 if mp.x>=view.x-e:d.x+=1
 if mp.y<=e:d.y+=1
 if mp.y>=view.y-e:d.y-=1
 return d

func _camera_keys_j(delta):
 var d=_pan_dir()+_edge_dir()
 if d!=Vector2.ZERO:
  cam_goal_active=false
  var fwd=Vector3(-sin(camera_yaw),0,-cos(camera_yaw))
  var right=Vector3(cos(camera_yaw),0,-sin(camera_yaw))
  var dir3=(right*d.x+fwd*d.y)
  if dir3.length()>1.0:dir3=dir3.normalized()
  var spd=float(cam_cfg.get("pan_speed_mps_at_100m",120.0))*camera_distance/100.0*float(settings.camera_speed)
  if _key_down(KEY_SHIFT):spd*=3.0
  camera_target+=dir3*spd*delta
 if _key_down(KEY_Q):camera_yaw+=delta*0.8
 if _key_down(KEY_E):camera_yaw-=delta*0.8
 if _key_down(KEY_PAGEUP):camera_pitch=minf(PITCH_MAX,camera_pitch+delta*0.7)
 if _key_down(KEY_PAGEDOWN):camera_pitch=maxf(PITCH_MIN,camera_pitch-delta*0.7)
 camera_target=world.clamp_camera_target(camera_target)

func _clamp_zoom():
 camera_distance=clampf(camera_distance,float(cam_cfg.get("min_distance_m",25.0)),float(cam_cfg.get("max_distance_m",900.0)))

func _zoom_at(pos:Vector2,zoom_in:bool):
 var before=world.ground_xz_from_screen(camera,pos)
 camera_distance*=0.88 if zoom_in else 1.14
 _clamp_zoom();cam_goal_active=false
 _apply_camera()
 var after=world.ground_xz_from_screen(camera,pos)
 if before!=null and after!=null:
  camera_target+=Vector3(before.x-after.x,0,before.y-after.y)
 camera_target=world.clamp_camera_target(camera_target)
 _apply_camera()

func _center_on(p:Vector2,dist:float=-1.0):
 var t=world.clamp_camera_target(Vector3(p.x,0,p.y))
 if dist>0:_focus_to(t,dist)
 else:
  camera_target=t;cam_goal_active=false;_apply_camera()

func _center_selection():
 var pts=[]
 for id in sel_ids:pts.append(_actor_pos(id))
 if pts.is_empty():
  var f=cam_cfg.get("focus_start",[140,265]);_focus_to(Vector3(float(f[0]),0,float(f[1])),camera_distance);return
 var c=Vector2.ZERO
 for q in pts:c+=q
 c/=pts.size()
 _focus_to(Vector3(c.x,0,c.y),camera_distance)

func _center_ship():
 var s=rules.ship_position()
 _focus_to(Vector3(s.x,0,s.y),minf(camera_distance,160.0))

func _toggle_minimap():
 mm_big=not mm_big;_layout_j();_refresh_minimap()

func _step_speed(dir:int,wrap:bool=false):
 var steps=[1.0,2.0,4.0]
 var i=steps.find(speed)
 if i<0:i=0
 var n=i+dir
 if wrap:n=posmod(n,steps.size())
 speed=steps[clampi(n,0,steps.size()-1)]
 _update_hud()

# ---------- Interfaz de Justina ----------
func _cm_style(key:String,color:Color,border:Color,width:int,mh:int,mv:int)->StyleBoxFlat:
 if not style_cache.has(key):
  var s=_style(color,border,width,4,mh)
  s.content_margin_top=mv;s.content_margin_bottom=mv
  style_cache[key]=s
 return style_cache[key]

func _compact(b:Button,pad_h:int=6,pad_v:int=3):
 var spec={"normal":["1a3037","455753"],"hover":["29454c","d9b576"],"pressed":["406064","455753"],"disabled":["19272b","2c3a38"],"focus":["27434a","fff0b8"]}
 for state_name in spec:
  b.add_theme_stylebox_override(state_name,_cm_style("cm%s%d%d" % [state_name,pad_h,pad_v],Color(str(spec[state_name][0])),Color(str(spec[state_name][1])),1,pad_h,pad_v))

func _mm_size()->Vector2:
 var m=_jmap().get("minimap",{})
 var a=m.get("large_size_px" if mm_big else "default_size_px",[260,150])
 # Más grande que el mínimo del JSON: 300x173 lógicos (360 px a 1080p); 600x347 al ampliar, con la proporción del mapa 900x520.
 var mine=Vector2(520,300) if mm_big else Vector2(300,173)
 if get_viewport().get_visible_rect().size.y<800.0:
  mine=Vector2(440,254) if mm_big else Vector2(260,150)
  return mine
 return Vector2(maxf(float(a[0]),mine.x),maxf(float(a[1]),mine.y))

func _build_hud_j():
 _new_ui();unit_buttons={};action_buttons={};stat_bars={};hud_panels=[];roster_buttons={};pace_buttons={};speed_buttons={}
 left_panel=null;journal_panel=null;journal_last=null;roster_panel=null
 alert_current={};alert_ids_seen={};pause_reason="";order_log=[];eta_cache={}
 tut_cam0=camera_target;tut_dist0=camera_distance
 cam_goal_active=false;select_flash=0.0;hover_info={};confirm_action="";confirm_timer=0.0
 aim="";aim_pts=[];wp_list=[];pending_pt=null;box_active=false;lmb_down=false;rmb_down=false;mmb_down=false;rmb_drag=false
 overlay=Control.new();overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(overlay);overlay.draw.connect(_draw_overlay)
 # Cabecera: título, indicador permanente de tiempo real / pausa, reloj, pausa, velocidades y menús
 var header=_panel(ui,Vector2(20,8),Vector2(1400,0),Color(0.055,0.105,0.12,0.94),Color("394c49"),3);hud_panels.append(header);_anchor(header,0,0,1,0,12,6,-12,6)
 var hv=_hbox(header,6)
 var heading=_vbox(hv,0);heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 heading.custom_minimum_size.x=60;heading.clip_contents=true
 title_label=_label(heading,"",15,PAPER,true);title_label.clip_text=true;title_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 phase_label=_label(heading,"",10,MUTED);phase_label.clip_text=true;phase_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 mode_label=_label(hv,"",13,GREEN);mode_label.custom_minimum_size.x=176;mode_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;mode_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 mode_label.tooltip_text="La Justina es TIEMPO REAL: el reloj avanza solo. Podés pausar con Espacio y dar órdenes con el tiempo detenido (pausa activa: lo recomendado). Velocidades ×1, ×2, ×4."
 mode_label.mouse_filter=Control.MOUSE_FILTER_PASS
 clock_label=_label(hv,"",19,GOLD,true);clock_label.custom_minimum_size.x=120;clock_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 clock_label.tooltip_text="Tiempo que queda hasta el plazo de la misión.";clock_label.mouse_filter=Control.MOUSE_FILTER_PASS
 pause_button=_button(hv,"▶  Iniciar",_toggle_pause,26);pause_button.custom_minimum_size.x=122;pause_button.clip_text=true;_compact(pause_button)
 pause_button.tooltip_text="Espacio. Pausa o reanuda el tiempo real. Con el tiempo detenido podés seguir dando órdenes."
 for sp in [1,2,4]:
  var spv=sp
  var sb=_button(hv,"×%d" % spv,func():_set_speed(float(spv)),26);sb.custom_minimum_size.x=36;sb.toggle_mode=true;_compact(sb,4,3)
  sb.tooltip_text="Velocidad ×%d del tiempo real (F%d; también + y −). El juego corre %d veces más rápido, con sus riesgos." % [spv,[1,2,4].find(spv)+2,spv]
  speed_buttons[spv]=sb
 speed_button=speed_buttons[1]
 autopause_button=_button(hv,"",_toggle_autopause,26);_compact(autopause_button,5,3);autopause_button.add_theme_font_size_override("font_size",12)
 autopause_button.tooltip_text="Pausa automática: el juego se detiene solo cuando aparece un aviso crítico (contraataque, vencimiento de la señal de Liniers, subida del agua) para que decidas con calma."
 for spec in [["Diario",_diary_dialog,"Lo que descubriste y sufriste en este río. Se marca tenue en el mapa del próximo intento."],["Ayuda",_briefing_dialog,"F1 o ?. Controles, tiempo real, tutorial y fuentes."],["☰ Menú",_pause_menu,"Esc. Pausa: guardar, ajustes, parte, reiniciar, volver al menú o abandonar. Lo que corta el intento está acá, aparte de las órdenes."]]:
  var hb=_button(hv,str(spec[0]),spec[1],26);hb.add_theme_font_size_override("font_size",13);_compact(hb);hb.tooltip_text=str(spec[2])
 # Nombre del paraje (arriba a la izquierda, sin fondo)
 place_label=_label(ui,"",13,PAPER);place_label.clip_text=true;place_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 place_label.add_theme_color_override("font_outline_color",Color(0.02,0.04,0.05,0.95));place_label.add_theme_constant_override("outline_size",6)
 _anchor(place_label,0,0,0,0,16,54,340,74)
 # Pila central: pausa, avisos críticos y tutorial (se apilan sin pisarse)
 top_stack=VBoxContainer.new();top_stack.add_theme_constant_override("separation",4);top_stack.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(top_stack)
 _anchor(top_stack,0.5,0,0.5,0,-330,54,330,54)
 pause_banner=_label(top_stack,"",13,Color("f6e2a8"));pause_banner.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;pause_banner.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;pause_banner.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 pause_banner.add_theme_stylebox_override("normal",_cm_style("banner",Color(0.2,0.15,0.04,0.96),Color("e0bf81"),2,10,5));pause_banner.mouse_filter=Control.MOUSE_FILTER_IGNORE;pause_banner.visible=false
 alert_panel=_panel(top_stack,Vector2.ZERO,Vector2(660,0),Color(0.22,0.07,0.06,0.97),Color("f08c78"),8)
 var ah=_hbox(alert_panel,10)
 alert_label=_label(ah,"",14,Color("ffe3d8"));alert_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;alert_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 alert_btn=_button(ah,"",_alert_click,36);alert_btn.custom_minimum_size.x=150;alert_btn.visible=false
 alert_panel.visible=false
 hint_panel=_panel(top_stack,Vector2.ZERO,Vector2(660,0),Color(0.035,0.075,0.09,0.93),Color("7c7653"),7)
 var tv=_vbox(hint_panel,4)
 tutorial_label=_label(tv,"",13,Color("f4e9c8"));tutorial_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 var tb=_hbox(tv,6)
 tut_skip_btn=_button(tb,"Saltar paso ▸",_tut_skip,24);_compact(tut_skip_btn,6,2);tut_skip_btn.add_theme_font_size_override("font_size",12)
 tut_close_btn=_button(tb,"Cerrar tutorial",_tut_close,24);_compact(tut_close_btn,6,2);tut_close_btn.add_theme_font_size_override("font_size",12)
 var tl=_label(tb,"F1 o ? abre la ayuda completa",11,MUTED);tl.size_flags_vertical=Control.SIZE_SHRINK_CENTER
 hint_panel.visible=false
 # Panel de la derecha: objetivo, captura, río, tiempos, recursos y riesgo del sondeo
 right_panel=_panel(ui,Vector2.ZERO,Vector2(272,0),Color(0.055,0.105,0.12,0.92),Color("394c49"),8);hud_panels.append(right_panel);_anchor(right_panel,1,0,1,0,-284,54,-12,54)
 var rv=_vbox(right_panel,3)
 var rh=_hbox(rv,4)
 var rt=_label(rh,"OBJETIVO Y ESTADO  (tecla I)",11,GOLD);rt.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var rbtn=_button(rh,"▾",_toggle_info,20);rbtn.custom_minimum_size.x=26;_compact(rbtn,4,0);rbtn.tooltip_text="Plegar o desplegar (I)"
 right_body=_vbox(rv,3)
 goal_label=_rich(right_body,"",12)
 info_label=_rich(right_body,"",12)
 capture_bar=ProgressBar.new();capture_bar.custom_minimum_size.y=7;capture_bar.show_percentage=false;right_body.add_child(capture_bar)
 moral_label=_rich(right_body,"",1);moral_label.visible=false
 moral_bar=ProgressBar.new();moral_bar.custom_minimum_size.y=7;moral_bar.show_percentage=false
 moral_bar.add_theme_stylebox_override("fill",_style(Color("c98f6f"),Color.TRANSPARENT,0,3,0));right_body.add_child(moral_bar)
 state_label=_rich(right_body,"",12)
 river_ctl=Control.new();river_ctl.custom_minimum_size=Vector2(254,34);river_ctl.mouse_filter=Control.MOUSE_FILTER_IGNORE;right_body.add_child(river_ctl);river_ctl.draw.connect(_draw_river)
 time_ctl=Control.new();time_ctl.custom_minimum_size=Vector2(254,54);time_ctl.mouse_filter=Control.MOUSE_FILTER_IGNORE;right_body.add_child(time_ctl);time_ctl.draw.connect(_draw_timeline)
 tide_label=_rich(right_body,"",12)
 res_label=_rich(right_body,"",12)
 risk_label=_rich(right_body,"",12)
 log_label=_rich(right_body,"",11)
 detail_ctls=[tide_label,res_label,risk_label,river_ctl]
 details_btn=_button(right_body,"",_toggle_details,22);_compact(details_btn,6,1);details_btn.add_theme_font_size_override("font_size",11)
 details_btn.tooltip_text="Muestra u oculta el detalle: munición, avisos a Liniers, estacas, estado del río y riesgo del sondeo."
 _apply_details()
 # Panel lateral de agrupaciones (siempre visible): una ficha por agrupación
 roster_panel=_panel(ui,Vector2.ZERO,Vector2(240,0),Color(0.055,0.105,0.12,0.94),Color("394c49"),6);hud_panels.append(roster_panel)
 var lv=_vbox(roster_panel,3)
 var lt=_label(lv,"AGRUPACIONES  ·  clic o teclas 1-5",11,GOLD);lt.tooltip_text="Cinco agrupaciones: tres grupos (1-3) y dos exploradores (4-5). Clic selecciona; Mayús suma; Ctrl alterna."
 for id in ALL_ACTORS:
  var aid=id
  var rb=_button(lv,"",func():_roster_click(aid),68);rb.add_theme_font_size_override("font_size",11);rb.alignment=HORIZONTAL_ALIGNMENT_LEFT;_compact(rb,8,3);rb.clip_text=true
  rb.draw.connect(func():_draw_card(aid,rb))
  roster_buttons[id]=rb
 left_foot=_rich(lv,"",11)
 deploy_btn=_button(lv,"Ajustar tropas ▸",_deploy_dialog,24);_compact(deploy_btn,6,2);deploy_btn.add_theme_font_size_override("font_size",12)
 deploy_btn.tooltip_text="Composición, rol y punto de partida de las cinco agrupaciones. Antes de empezar se puede reasignar fuerza entre los tres grupos."
 # Minimapa y su barra de cámara
 map_widget=Control.new();map_widget.mouse_filter=Control.MOUSE_FILTER_STOP;ui.add_child(map_widget)
 map_widget.draw.connect(_draw_map_widget);map_widget.gui_input.connect(_map_gui_input);hud_panels.append(map_widget)
 mm_bar=_panel(ui,Vector2.ZERO,Vector2(300,0),Color(0.055,0.105,0.12,0.94),Color("394c49"),3);hud_panels.append(mm_bar)
 var mb=_hbox(mm_bar,3)
 for spec in [["Selec. F",_center_selection,"F o Inicio. Centra la cámara en lo seleccionado."],["Buque B",_center_ship,"B. Lleva la cámara al Buque Justina."],["Todo 0",_view_all,"0. Encuadra el mapa entero."],["Ampliar M",_toggle_minimap,"M. Minimapa grande o normal. En el minimapa: clic o arrastre mueve la cámara; clic derecho ordena mover."]]:
  var bb=_button(mb,str(spec[0]),spec[1],22);bb.add_theme_font_size_override("font_size",11);_compact(bb,3,1);bb.size_flags_horizontal=Control.SIZE_EXPAND_FILL;bb.tooltip_text=str(spec[2])
 # Panel inferior: selección, ritmo y acciones contextuales
 var bottom=_panel(ui,Vector2.ZERO,Vector2(900,0),Color(0.055,0.105,0.12,0.94),Color("394c49"),7);hud_panels.append(bottom)
 bottom.grow_vertical=Control.GROW_DIRECTION_BEGIN;bottom_panel=bottom
 var right_col=_vbox(bottom,3)
 var info_row=_hbox(right_col,4)
 sel_info=_rich(info_row,"",12,34);sel_info.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var pl=_label(info_row,"Ritmo",11,MUTED);pl.size_flags_vertical=Control.SIZE_SHRINK_CENTER
 for spec in [["walk","C · Paso"],["trot","T · Trote"],["gallop","G · Galope"]]:
  var pid=str(spec[0])
  var pb=_button(info_row,str(spec[1]),func():_set_pace(pid),24);pb.toggle_mode=true;pb.add_theme_font_size_override("font_size",11);_compact(pb,5,2)
  pb.tooltip_text="Ritmo de marcha de los grupos seleccionados. El galope solo vale en terreno firme."
  pace_buttons[pid]=pb
 action_box=_vbox(right_col,3)
 toast_label=_label(ui,"",15,PAPER);_anchor(toast_label,0.5,1,0.5,1,-330,-250,330,-184)
 toast_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;toast_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;toast_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 toast_label.add_theme_stylebox_override("normal",_style(Color(0.04,0.09,0.11,0.94),Color("7c7653"),1,5,10))
 toast_view=_button(ui,"ver",func():_toast_view_click(),26);_compact(toast_view,8,2);_anchor(toast_view,0.5,1,0.5,1,336,-232,396,-206);toast_view.visible=false
 overlay_top=Control.new();overlay_top.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 overlay_top.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(overlay_top);overlay_top.draw.connect(_draw_top_overlay)
 flash_rect=ColorRect.new();flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);flash_rect.mouse_filter=Control.MOUSE_FILTER_IGNORE;flash_rect.color=Color(1,1,1,0);ui.add_child(flash_rect)
 _layout_j()
 _refresh_actions()
 _apply_panel_state()

func _layout_j():
 if not is_instance_valid(map_widget):return
 var sz=_mm_size()
 map_widget.custom_minimum_size=Vector2(sz.x,sz.y)
 _anchor(map_widget,0,1,0,1,12,-(sz.y+10),12+sz.x,-10)
 map_widget.queue_redraw()
 if is_instance_valid(mm_bar):_anchor(mm_bar,0,1,0,1,12,-(sz.y+10+32),12+sz.x,-(sz.y+14))
 if is_instance_valid(roster_panel):_anchor(roster_panel,0,0,0,0,12,80,252,80)
 if is_instance_valid(bottom_panel):_anchor(bottom_panel,0,1,0,1,12+sz.x+8,-10,12+sz.x+8+900,-10)

func _set_speed(v:float):
 speed=v;_update_hud()
 _toast("Velocidad ×%d del tiempo real." % int(v),2.5,true,0)

func _toggle_autopause():
 settings.auto_pause=not bool(settings.auto_pause);_save_settings();_update_hud()
 _toast("Pausa automática en avisos críticos: "+("ACTIVADA." if bool(settings.auto_pause) else "desactivada. Ojo: un contraataque no espera."),4.0)

# ---------- Modo tiempo real, avisos y siguiente paso ----------

func _mode_info()->Dictionary:
 if str(rules.state.status)!="playing":return {"text":"PARTIDA TERMINADA","kind":"end"}
 if paused:return {"text":"‖ EN PAUSA","kind":"pause"}
 return {"text":"TIEMPO REAL · ▶ ×%d" % int(speed),"kind":"live"}

func _update_mode_ui():
 var mi=_mode_info()
 mode_label.text=str(mi.text)
 match str(mi.kind):
  "live":
   mode_label.add_theme_stylebox_override("normal",_cm_style("mode_live",Color(0.07,0.2,0.17),Color("6fb8a6"),1,8,3));mode_label.add_theme_color_override("font_color",Color("a6e3b8"))
  "pause":
   mode_label.add_theme_stylebox_override("normal",_cm_style("mode_pause",Color(0.27,0.19,0.04),Color("e0bf81"),2,8,3));mode_label.add_theme_color_override("font_color",Color("f6e2a8"))
  _:
   mode_label.add_theme_stylebox_override("normal",_cm_style("mode_end",Color(0.12,0.14,0.15),Color("65756c"),1,8,3));mode_label.add_theme_color_override("font_color",MUTED)
 var st=rules.state
 var txt=""
 if str(st.status)=="playing" and paused:
  if not pause_reason.is_empty():txt="‖ PAUSA AUTOMÁTICA — %s  Espacio sigue." % pause_reason
 pause_banner.text=txt;pause_banner.visible=not txt.is_empty() and not (is_instance_valid(alert_panel) and alert_panel.visible)
 pause_button.text="▶  Reanudar" if paused else "‖  Pausar"
 if float(st.elapsed)<0.5 and paused:pause_button.text="▶  Iniciar"
 for sp in speed_buttons:speed_buttons[sp].set_pressed_no_signal(int(speed)==int(sp))
 autopause_button.text=("☑ " if bool(settings.auto_pause) else "☐ ")+"Pausa auto"
 autopause_button.add_theme_stylebox_override("normal",_cm_style("ap_on",Color(0.07,0.2,0.17),Color("6fb8a6"),1,5,3) if bool(settings.auto_pause) else _cm_style("ap_off",Color(0.14,0.15,0.15),Color("65756c"),1,5,3))

func _compute_alerts()->Array:
 var out=[]
 var st=rules.state
 if str(st.status)!="playing":return out
 var t=float(st.elapsed)
 var cap=_jmap().get("ship",{}).get("capture",{}).get("counter",{})
 var c=st.counter
 if bool(c.active) and not bool(c.answered):
  var rem=maxf(0.0,float(c.until)-t)
  var anyb=_anyone_boarding()
  out.append({"id":"counter%d" % int(c.count),"level":"crit" if anyb else "warn","nopause":not anyb,"short":"contraataque de la dotación: tenés %d s para rechazarlo." % int(float(cap.get("window_s",14))),"text":"⚔ ¡CONTRAATAQUE! Quedan %d s: «Rechazar» (coma) con un grupo que aborda cuesta %d de munición; si no, perdés fuerza y captura.%s" % [ceili(rem),int(cap.get("repel_ammo",3)),"" if anyb else " Ningún grupo aborda: mandá uno con «Cargar y abordar» (N)."],"btn":"Rechazar ahora (,)","fn":"repel"})
 var le=st.get("last_effort",{})
 if float(le.get("until",-1.0))>=0.0 and not bool(le.get("used",false)):
  var left_le=maxf(0.0,float(le.until)-t)
  out.append({"id":"lasteffort","level":"crit","nopause":true,"short":"todos los grupos están quebrados: queda el último esfuerzo.","text":"✸ ¡TODOS LOS GRUPOS QUEBRADOS! Quedan %d s para lanzar el ÚLTIMO ESFUERZO con los voluntarios de reserva, o la toma se pierde." % ceili(left_le),"btn":"¡Último esfuerzo!","fn":"last_effort"})
 if t>=float(st.get("no_return_s",9999.0)) and not rules._has_advanced() and not bool(st.get("last_effort",{}).get("used",false)):
  out.append({"id":"lost_cause","level":"warn","nopause":true,"short":"ya no hay tiempo de alcanzar el buque.","text":"≈ Pasó el punto sin retorno y nadie cargó: el río ya no te deja llegar. Reintentá ahora y no pierdas más tiempo.","btn":"Reintentar ya","fn":"retry_now"})
 var res=rules.resources()
 var marching=false
 for id in GROUP_IDS:
  var u=rules.get_unit(id)
  if not u.is_empty() and str(u.stage)=="moving" and str(u.get("order",{}).get("action",""))=="board":marching=true
 if marching and bool(res.advance_authorized) and float(res.advance_remaining_s)>0.0 and float(res.advance_remaining_s)<=45.0:
  out.append({"id":"adv%d" % int(res.signals_left),"level":"warn","short":"la orden de avance de Liniers está por vencer.","text":"⚠ El permiso de carga vence en %d s y un grupo marcha hacia el buque. Quedan %d avisos: volvé a pedirlo (K) o llegá antes." % [ceili(float(res.advance_remaining_s)),int(res.signals_left)]})
 var fo=_ford_opens_at()
 if fo>=0.0 and t>=fo and t<fo+25.0 and not bool(res.advance_authorized):
  out.append({"id":"ford_open","level":"warn","short":"el vado cede: ya se puede cruzar.","text":"≈ EL VADO CEDE. Elegí un grupo y «Pedir carga a Liniers» (K), después «Cargar y abordar» (N).","btn":"Pedir carga (K)","fn":"signal_liniers"})
 var tm=rules.tide_marks()
 if t>=float(tm.low_hold_end)-45.0 and t<float(tm.deadline):
  if t<float(tm.low_hold_end):
   out.append({"id":"rise_soon","level":"warn","short":"el río va a subir pronto.","text":"≈ EL RÍO VA A SUBIR en %d s. Quien esté en el agua tiene que llegar ya o volver a la orilla." % ceili(float(tm.low_hold_end)-t)})
  else:
   out.append({"id":"rise_now","level":"warn","short":"el río está subiendo.","text":"≈ EL RÍO SUBE: los pasos se cierran. Quedan %s. Quien siga en el agua pierde caballos." % _clock(float(tm.deadline)-t)})
 out.sort_custom(func(a,b):return (0 if str(a.level)=="crit" else 1)<(0 if str(b.level)=="crit" else 1))
 return out

func _update_alerts():
 var list=_compute_alerts()
 for a in list:
  if not alert_ids_seen.has(str(a.id)):
   alert_ids_seen[str(a.id)]=true
   if bool(settings.auto_pause) and not bool(a.get("nopause",false)) and not paused and not is_instance_valid(modal) and mode=="play":
    paused=true;pause_reason=str(a.short);_sound("alert")
 if list.is_empty():
  alert_current={};alert_panel.visible=false;return
 var top=list[0]
 alert_current=top
 alert_label.text=str(top.text)
 alert_panel.add_theme_stylebox_override("panel",_cm_style("alert"+str(top.level),Color(0.22,0.07,0.06,0.97) if str(top.level)=="crit" else Color(0.2,0.14,0.04,0.97),Color("f08c78") if str(top.level)=="crit" else Color("e0bf81"),2,9,6))
 alert_btn.visible=top.has("btn")
 if top.has("btn"):
  alert_btn.text=str(top.btn)
  var av=_avail(str(top.get("fn","")))
  alert_btn.disabled=not bool(av.get("ok",false))
  alert_btn.tooltip_text="" if not alert_btn.disabled else "No disponible ahora: "+str(av.get("reason",""))
  if alert_btn.disabled:alert_label.text+="
✕ "+str(av.get("reason",""))
 alert_panel.visible=true
 _update_mode_ui()

func _alert_click():
 var fn=str(alert_current.get("fn",""))
 if fn=="repel":_do_boarding_action("repel")
 elif not fn.is_empty():
  if fn=="signal_liniers" and _sel_groups().is_empty():_select_ids(["guemes"])
  _do_action(fn)

func _next_step()->Dictionary:
 var st=rules.state
 if str(st.status)!="playing":return {"action":"","text":"El intento terminó: mirá el parte."}
 if bool(st.counter.active) and not bool(st.counter.answered):return {"action":"repel","text":"¡Contraataque! Apretá «Rechazar» (coma) con un grupo que aborda."}
 var res=rules.resources()
 if rules.probes().is_empty():
  return {"action":"probe","text":"Mandá un explorador (tecla 4) a medir el agua: Z y clic en el agua."}
 var boarding=false
 for id in GROUP_IDS:
  if str(rules.get_unit(id).get("stage","")) in ["boarding","dismounting"]:boarding=true
 if boarding:return {"action":"evacuate","text":"Estás abordando: rechazá los contraataques y evacuá a los heridos (punto)."}
 if not bool(res.advance_authorized):
  if not _ford_soon():
   var o=_ford_opens_at()
   return {"action":"resupply","text":"Esperá a que el vado ceda%s. Mientras, abastecé munición (J)." % ((" (en unos %s)" % _clock(maxf(0.0,o-float(st.elapsed)))) if o>=0.0 else "")}
  return {"action":"signal_liniers","text":"El vado ya cede: elegí un grupo (1-3) y «Pedir carga a Liniers» (K). Vale %d s." % int(float(_jmap().get("actions",{}).get("signal_liniers",{}).get("valid_s",420)))}
 var bp0=rules.board_point()
 var gs0=_sel_groups()
 var probe_first=false
 if not gs0.is_empty():
  var pl0=rules.plan_route(gs0[0],bp0,pace,{})
  if not bool(pl0.get("ok",false)) and _friendly_reason("board",str(pl0.get("reason",""))).begins_with("El camino hasta el buque"):probe_first=true
 if probe_first:return {"action":"probe","text":"Tenés permiso de carga (%s), pero falta medir el agua cerca del buque: explorador, Z y clic en el agua; después «Cargar y abordar» (N)." % _clock(float(res.advance_remaining_s))}
 return {"action":"board","text":"¡Cargá ya! El permiso de Liniers dura %s: «Cargar y abordar» (N) o clic derecho en el buque." % _clock(float(res.advance_remaining_s))}

func _friendly_reason(a:String,why:String)->String:
 if a=="board" and why.begins_with("Falta la orden de avance"):
  return "Primero «Pedir carga a Liniers» (K) con un grupo: sin su permiso no se puede «Cargar y abordar» (N)."
 if a=="board" and (why.find("fondo estimado")>=0 or why.find("sin reconocer")>=0 or why.find("camino hasta")>=0 or why.find("transitable")>=0):
  return "El camino hasta el buque no está reconocido: mandá un explorador (4 o 5), «Sondear el agua» (Z) y hacé clic en el agua cerca del buque; después «Cargar y abordar» (N)."
 if a=="signal_liniers" and why.find("ya fue concedida")>=0:
  return "Ya tenés el permiso de Liniers (vigente %s más): ahora «Cargar y abordar» (N)." % _clock(float(rules.resources().advance_remaining_s))
 return why

# ---------- Tutorial interactivo ----------

func _tut_done(i:int)->bool:
 var st=rules.state
 match i:
  0:return not rules.probes().is_empty()
  1:return bool(rules.resources().advance_authorized) or int(rules.resources().signals_left)<int(_jmap().get("resources",{}).get("signals_max",2)) or _ford_soon()
  2:return bool(rules.resources().advance_authorized) or int(rules.resources().signals_left)<int(_jmap().get("resources",{}).get("signals_max",2))
  3:
   for id in GROUP_IDS:
    if str(rules.get_unit(id).get("stage","")) in ["moving","waiting_tide","dismounting","boarding"]:return true
   return false
  4:return int(st.counter.count)>0 or str(st.status)!="playing"
 return true

func _tut_update():
 if not bool(settings.tutorial):return
 # Si el jugador ya hizo un paso posterior (sondeó, pidió la carga, marchó), se salta lo que quedó atrás.
 for j in range(3,maxi(tut_step,0)-1,-1):
  if _tut_done(j) and j+1>tut_step:
   tut_step=j+1;tut_cam0=camera_target;tut_dist0=camera_distance;break
 var guard=0
 while tut_step<TUT_STEPS.size() and _tut_done(tut_step) and guard<6:
  tut_step+=1;guard+=1;tut_cam0=camera_target;tut_dist0=camera_distance

func _tut_skip():
 tut_step=mini(tut_step+1,TUT_STEPS.size());tut_cam0=camera_target;tut_dist0=camera_distance;_update_hud()

func _tut_close():
 settings.tutorial=false;_save_settings();_update_hud()
 _toast("Tutorial cerrado. F1 o ? lo reabre; «Repetir tutorial» en la ayuda.",4,true,0)

# ---------- Fichas de agrupaciones ----------

func _path_len(start:Vector2,path:Array)->float:
 var total=0.0;var prev=start
 for n in path:
  var q=Vector2(float(n.x),float(n.z))
  total+=prev.distance_to(q);prev=q
 return total

func _scout_chain_eta(start:Vector2,pts:Array)->float:
 var info=rules.action_info("probe")
 var sw=float(info.get("speed_mps_water",1.0));var sd=float(info.get("speed_mps_dry",3.0))
 var secs=0.0;var prev=start
 for q in pts:
  var seg=prev.distance_to(q)
  var steps=maxi(1,int(seg/5.0))
  for k in range(steps):
   var m=prev.lerp(q,(float(k)+0.5)/float(steps))
   var wet=rules.perceived_depth_at(m.x,m.y)>0.0
   secs+=(seg/float(steps))/(sw if wet else sd)
  prev=q
 return secs

func _eta_s(id:String)->float:
 var a=_actor(id)
 if a.is_empty():return -1.0
 var stage=str(a.stage)
 var sig="%s|%s|%d" % [stage,str(a.get("order",{}).get("action","")),a.get("path",[]).size()]
 var now=Time.get_ticks_msec()
 var c=eta_cache.get(id,null)
 if c!=null and now-int(c.t)<700 and str(c.sig)==sig:return float(c.eta)
 var eta=-1.0
 var pos=Vector2(float(a.x),float(a.z))
 if id in SCOUT_IDS:
  var pts=[]
  for n in a.get("path",[]):pts.append(Vector2(float(n.x),float(n.z)))
  if stage in ["moving","probing","marking"] and not pts.is_empty():eta=_scout_chain_eta(pos,pts)
  if float(a.get("work_remaining",0.0))>0.0:eta=maxf(eta,0.0)+float(a.work_remaining)
 else:
  match stage:
   "moving":
    var o=a.get("order",{})
    var dest=Vector2(float(o.get("x",a.x)),float(o.get("z",a.z)))
    var rem=_path_len(pos,a.get("path",[]))
    var plan=rules.plan_route(id,dest,str(a.get("pace","trot")),{})
    if bool(plan.get("ok",false)) and float(plan.length_m)>1.0:eta=rem*float(plan.eta_s)/float(plan.length_m)
    else:eta=rem/3.0
   "working":eta=float(a.get("work",{}).get("remaining",0.0))
   "dismounting":eta=float(a.get("dismount_remaining",0.0))
   "stumbling":eta=float(a.get("stumble_remaining",0.0))
 eta_cache[id]={"t":now,"sig":sig,"eta":eta}
 return eta

func _order_text(id:String)->String:
 var a=_actor(id)
 if a.is_empty():return ""
 var stage=str(a.stage)
 var act=str(a.get("order",{}).get("action",""))
 var e=_eta_s(id)
 var eta=(" · ETA "+_clock(e)) if e>=0.0 else ""
 if id in SCOUT_IDS:
  if stage=="lost":return "Abatido"
  if stage=="idle":return "Esperando órdenes"
  var nm="Volver a la playa"
  if act=="mark_ford":nm="Marcar vado"
  elif act=="probe":nm="Sondeo cauteloso" if bool(a.get("cautious",false)) else "Reconocer fondo"
  return nm+eta
 if act.is_empty():
  if stage=="routed":return "¡Dispersa! Reagrupá (Y)"
  return "Esperando órdenes"
 if act=="signal_liniers":return "Ir a pedir la orden a Liniers"+eta
 return _action_label(act)+eta

func _card_text(id:String)->String:
 var a=_actor(id)
 if a.is_empty():return ""
 var mark="▸ " if sel_ids.has(id) else ""
 var role=GROUP_ROLE[id]
 var stage_t=str(STAGE_TEXT.get(str(a.stage),["·",str(a.stage)])[1])
 if id in SCOUT_IDS:
  var hp_max=int(_jmap().get("resources",{}).get("scout_hp",4))
  if not sel_ids.has(id):return "◈ %d %s   ♥ %d/%d\n%s" % [_actor_number(id),_short_name(id),int(a.hp),hp_max,_order_text(id)]
  return "%s◈ %d %s   ♥ %d/%d\nExplorador a pie · lanza\n%s\n%s" % [mark,_actor_number(id),_short_name(id),int(a.hp),hp_max,stage_t,_order_text(id)]
 if not sel_ids.has(id):
  return "%s %d %s      %d %%\nmunición %d · %s" % [_ujg(id),_actor_number(id),_short_name(id),int(a.strength),int(rules.resources().ammo),_order_text(id)]
 var tired="" if int(a.fatigue)<=0 else " · cansado %d %%" % int(a.fatigue)
 return "%s%s %d %s      %d %%\n%s · munición %d\n%s%s\n%s" % [mark,_ujg(id),_actor_number(id),_short_name(id),int(a.strength),str(role.kind),int(rules.resources().ammo),stage_t,tired,_order_text(id)]

func _card_tip(id:String)->String:
 var a=_actor(id)
 if a.is_empty():return ""
 var tg=str(a.get("tag","diseno"))
 var role=GROUP_ROLE[id]
 var t="%s\nTipo: %s%s. Rol (diseño): %s\nFuente: %s %s" % [str(a.name),str(role.kind),(" · "+("a caballo" if bool(a.get("mounted",false)) else "a pie")) if not (id in SCOUT_IDS) else "",str(role.role),_tag_glyph(tg),_tag_label(tg)]
 for g in _jmap().get("groups",[]):
  var note=str(g.get("note","")).split(". ")[0]
  if str(g.id)==id and not note.begins_with("Identificador interno"):t+="\n"+note+"."
 return t+"\nClic: seleccionar · Mayús: sumar · Ctrl: alternar · doble clic en el mapa: centrar."

func _draw_card(id:String,b:Button):
 var a=_actor(id)
 if a.is_empty() or not is_instance_valid(b):return
 var c:Color=UNIT_COLORS[id]
 b.draw_rect(Rect2(0,5,3,b.size.y-10),c)
 var frac=0.0;var col=GREEN
 if id in SCOUT_IDS:
  frac=clampf(float(a.hp)/float(maxi(1,int(_jmap().get("resources",{}).get("scout_hp",4)))),0.0,1.0)
 else:
  frac=clampf(float(a.strength)/100.0,0.0,1.0)
  col=GREEN if float(a.strength)>=60 else (GOLD if float(a.strength)>=35 else RED)
 var y=b.size.y-6.0
 b.draw_rect(Rect2(10,y,b.size.x-20,3),Color("31433e"))
 b.draw_rect(Rect2(10,y,(b.size.x-20)*frac,3),col)

# ---------- Deshacer ----------

func _log_order(ids:Array):
 var prev={}
 for id in ids:
  if id in SCOUT_IDS:prev[id]={"kind":"scout"}
  else:
   var u=rules.get_unit(id)
   var o=u.get("order",{})
   prev[id]={"kind":"group","action":str(o.get("action","")),"x":float(o.get("x",0.0)),"z":float(o.get("z",0.0)),"moving":str(u.get("stage",""))=="moving","pace":str(u.get("pace","trot"))}
 order_log.append({"prev":prev})
 if order_log.size()>12:order_log.pop_front()

func _drop_log_if_failed(results:Array):
 for r in results:
  if bool(r.get("ok",false)):return
 if not order_log.is_empty():order_log.pop_back()

func _undo_order():
 if mode!="play" or str(rules.state.status)!="playing":return
 if order_log.is_empty():_toast("No hay órdenes recientes para deshacer.",3,false);_sound("error");return
 var e=order_log.pop_back()
 var done=0;var msg=""
 for id in e.prev:
  var p=e.prev[id]
  var r={}
  if str(p.kind)=="scout":r=rules.issue_scout(id,"recall",[])
  elif bool(p.moving) and str(p.action) in ["move","board","withdraw"]:r=rules.issue_order(id,str(p.action),Vector2(float(p.x),float(p.z)),{"pace":str(p.pace)})
  else:r=rules.cancel_order(id)
  if bool(r.get("ok",false)):done+=1
  else:msg=str(r.get("reason",""))
 if done>0:_toast("Orden deshecha. No se recuperan señales, munición ni balizas ya gastadas.",4.0);_sound("order")
 else:_toast("No se pudo deshacer: "+msg,4.5,false);_sound("error")
 if is_instance_valid(world):world.refresh_paths()
 _refresh_actions();_update_hud()

func _do_boarding_action(action:String):
 var cand=[]
 for id in _sel_groups():
  if str(rules.get_unit(id).get("stage",""))=="boarding":cand.append(id)
 if cand.is_empty():
  for id in GROUP_IDS:
   if str(rules.get_unit(id).get("stage",""))=="boarding":cand.append(id)
 if cand.is_empty():_toast("Solo un grupo que ya está abordando el buque puede hacerlo: todavía no hay ninguno.",4.5,false);_sound("error");return
 var results=[]
 for id in cand:
  var r=rules.issue_order(id,action,Vector2.ZERO,{"pace":pace})
  results.append(r)
  if action=="repel" and bool(r.get("ok",false)):break
 _report_orders(results,1 if action=="repel" else cand.size())
 if is_instance_valid(world):world.refresh_paths()
 _refresh_actions();_update_hud()

# ---------- Acciones contextuales ----------

func _blocked_click(ev:InputEvent,b:Button):
 if ev is InputEventMouseButton and ev.pressed and ev.button_index==MOUSE_BUTTON_LEFT and is_instance_valid(b) and b.disabled:
  _toast("No disponible: "+str(b.get_meta("why","")),5,false);_sound("error")

func _key_text(a:String)->String:
 if KEY_LABELS.has(a):return str(KEY_LABELS[a])
 if ACTION_KEYS.has(a):return OS.get_keycode_string(ACTION_KEYS[a])
 return ""

# Rótulos de pozos, vados y diseño: si no entran enteros en pantalla se ocultan (antes se veían cortados en el borde).
# Corre cada cuadro, después de world.update_state, que es quien los muestra.
var fit_cache:Array=[]
var fit_frame=0
func _fit_world_labels():
 if not is_instance_valid(world) or not is_instance_valid(camera):return
 fit_frame+=1
 if fit_frame%20==1:
  fit_cache=[]
  for ch in world.find_children("*","Label3D",true,false):
   if str(ch.text).begins_with("▲"):fit_cache.append(ch)
 var vr=Rect2(Vector2(6,56),get_viewport().get_visible_rect().size-Vector2(12,62))
 for kl in fit_cache:
  if not is_instance_valid(kl) or not kl.is_inside_tree():continue
  var mine=bool(kl.get_meta("fit_hidden",false))
  if not kl.visible and not mine:continue
  var ksp=camera.unproject_position(kl.global_position)
  var tw=float(str(kl.text).length())*0.52*float(kl.font_size)*kl.pixel_size  # ancho del texto en unidades de Label3D
  var kw=0.0
  if kl.fixed_size:kw=maxf(40.0,tw*get_viewport().get_visible_rect().size.y/(2.0*tan(deg_to_rad(camera.fov*0.5)))*0.5)
  else:kw=maxf(40.0,(camera.unproject_position(kl.global_position+camera.global_transform.basis.x*tw*kl.global_transform.basis.x.length()*0.5)-ksp).x)
  var ok=not camera.is_position_behind(kl.global_position) and vr.encloses(Rect2(ksp-Vector2(kw,14),Vector2(kw*2.0,28)))
  kl.set_meta("fit_hidden",not ok)
  kl.visible=ok

func _declutter_world_labels():
 # Los rótulos 3D de referencia (Línea de agua, Pie de la barranca, Escala) se ocultan si caen bajo un panel o un rótulo de la interfaz.
 if not is_instance_valid(world) or not is_instance_valid(camera) or not ("ref_labels" in world):return
 var blocked=_blocked_rects()
 var avoid=blocked.duplicate()
 for r in last_overlay_rects:avoid.append(r)
 var labels=[]
 for k in world.ref_labels:labels.append(world.ref_labels[k])
 if is_instance_valid(world.scale_root):
  for ch in world.scale_root.find_children("*","Label3D",true,false):labels.append(ch)
 if ring_labels.is_empty():
  for ch in world.find_children("*","Label3D",true,false):
   if str(ch.text).begins_with("Alcance del fuego"):ring_labels.append(ch)
 for rl in ring_labels:
  if is_instance_valid(rl):labels.append(rl)
 for l in labels:
  if not is_instance_valid(l) or not l.is_inside_tree():continue
  if str(l.name)=="Rotulo_escala":
   l.visible=false  # la escala de 100 m se lee en la barra del minimapa; el rótulo 3D flotaba sobre rutas y rótulos
   continue
  var p=l.global_position
  if camera.is_position_behind(p):continue
  var sp=camera.unproject_position(p)
  var half=Vector2(150,20) if l in ring_labels else Vector2(95,18)
  var rect=Rect2(sp-half,half*2.0)
  # El rótulo del anillo de fuego (diseño) se ancla al borde visible: si se sale de la pantalla o cae bajo un panel, se oculta.
  l.visible=not _overlaps_any(rect,avoid) and (not (l in ring_labels) or Rect2(Vector2.ZERO,get_viewport().get_visible_rect().size).encloses(rect))

# Etiqueta del río derivada del reloj y de las marcas de marea (no de una fase cacheada).
func _river_word()->String:
 var t=float(rules.state.elapsed);var m=rules.tide_marks()
 if t<float(m.drop_start):return "alta"
 if t<float(m.drop_end):return "bajando"
 if t<float(m.low_hold_end):return "en su mínimo"
 return "subiendo"

func _tide_label()->String:
 var id=rules.tide_variant_id()
 for v in rules.map_data().get("time",{}).get("variants",[]):
  if str(v.id)==id:return str(v.get("label",id))
 return id

func _tide_text()->String:
 var t=float(rules.state.elapsed);var m=rules.tide_marks()
 if str(rules.state.status)!="playing":return ""
 if t<float(m.drop_start):return "Río (%s): la [b]bajante empieza en %s[/b]" % [_tide_label().to_lower(),_clock(float(m.drop_start)-t)]
 if t<float(m.drop_end):return "Río [b]BAJANDO[/b]: mínimo en %s · sube recién en %s" % [_clock(float(m.drop_end)-t),_clock(float(m.low_hold_end)-t)]
 if t<float(m.low_hold_end):return "Río en su mínimo: [color=#e0bf81][b]SUBE en %s[/b][/color]" % _clock(float(m.low_hold_end)-t)
 return "[color=#f4a58d][b]EL RÍO SUBE[/b][/color]: el plazo vence en %s" % _clock(float(m.deadline)-t)

func _probe_risk_text()->String:
 if str(hover_info.get("kind",""))=="scout" and not str(hover_info.get("risk_text","")).is_empty():
  return "Riesgo del sondeo (vista previa): "+str(hover_info.risk_text)
 var lines=[]
 for s in rules.scouts():
  if str(s.stage) in ["probing","moving","marking"] and rules.exposure_at(float(s.x),float(s.z))>0.0:
   lines.append("%s está [color=#f4a58d][b]expuesto al fuego[/b][/color] (♥ %d)" % [str(s.name),int(s.hp)])
 if not lines.is_empty():return "Sondeo: "+"; ".join(lines)
 return "Riesgo del sondeo: elegí un explorador + «Reconocer fondo» (Z) y mirá el aviso antes de confirmar."

func _deploy_dialog():
 if not _is_j():return
 var started=float(rules.state.elapsed)>0.0 or not rules.state.orders.is_empty()
 var box=_open_modal("Despliegue previo · tus 5 agrupaciones",1060,700)
 var intro="[b]Tus tropas.[/b] La fuerza va de 0 a 100 (no es un número de hombres). Hay tres grupos (1-3) y dos exploradores (4-5)."
 if started:intro+="\n[color=#f4a58d]La partida ya empezó: el despliegue quedó fijo.[/color]"
 else:intro+="\nTodavía estás a tiempo: podés pasar fuerza de un grupo a otro (hasta ±%d) y mover los puntos de partida." % int(rules.DEPLOY_MARGIN)
 var introrow=_hbox(box,12)
 var introcol=_vbox(introrow,6);introcol.custom_minimum_size.x=640;introcol.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var intro_rt=_rich(introcol,intro,13);intro_rt.custom_minimum_size.x=640
 var dmap=Control.new();dmap.custom_minimum_size=Vector2(340,180);dmap.size_flags_vertical=Control.SIZE_SHRINK_BEGIN;introrow.add_child(dmap)
 dmap.draw.connect(func():_draw_deploy_map(dmap))
 dmap.tooltip_text="Puntos de partida de las cinco agrupaciones sobre el mapa del escenario. Se mueven al elegir una dirección."
 var scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.custom_minimum_size=Vector2(1000,_scroll_h(250.0,555.0));box.add_child(scroll)
 var grid=GridContainer.new();grid.columns=5;grid.add_theme_constant_override("h_separation",16);grid.add_theme_constant_override("v_separation",8);scroll.add_child(grid)
 for h in ["Nº","Agrupación","Composición","Rol","Punto de partida"]:_label(grid,h,12,GOLD)
 for id in ALL_ACTORS:
  var a=_actor(id)
  if a.is_empty():continue
  var role=GROUP_ROLE[id]
  var c:Color=UNIT_COLORS[id]
  _label(grid,"%s %d" % [_ujg(id),_actor_number(id)],15,c)
  var nm=_label(grid,str(a.name),14,PAPER);nm.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;nm.custom_minimum_size.x=170
  var comp=""
  if id in SCOUT_IDS:comp="Explorador a pie con lanza · salud %d" % int(_jmap().get("resources",{}).get("scout_hp",4))
  else:comp="%s · fuerza %d/100 · %s · cansancio %d" % [str(role.kind),int(a.strength),"a caballo" if bool(a.get("mounted",false)) else "a pie",int(a.fatigue)]
  var cl=_label(grid,comp,13,PAPER);cl.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;cl.custom_minimum_size.x=210
  var rl=_label(grid,str(role.role),13,MUTED);rl.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;rl.custom_minimum_size.x=220
  var p0=_actor_pos(id)
  var pl=_label(grid,"x %d · z %d\n%s" % [int(p0.x),int(p0.y),_place_name(p0)],13,PAPER);pl.custom_minimum_size.x=120
 var cons=_rich(introcol,_deploy_consequences(),12);cons.custom_minimum_size.x=640
 var apb=CheckButton.new();apb.text="Pausa automática en avisos críticos (recomendada: el contraataque dura 14 s)";apb.button_pressed=bool(settings.auto_pause)
 apb.toggled.connect(func(on):settings.auto_pause=on;_save_settings();_update_hud());box.add_child(apb)
 var row=_hbox(box,8)
 _label(row,"Pasar %d de fuerza de" % int(rules.DEPLOY_STEP),14,PAPER)
 var from_o=OptionButton.new();var to_o=OptionButton.new()
 for gid in GROUP_IDS:
  from_o.add_item(_short_name(gid));to_o.add_item(_short_name(gid))
 to_o.select(1)
 row.add_child(from_o);_label(row,"a",14,PAPER);row.add_child(to_o)
 var go=_button(row,"Pasar fuerza",func():_deploy_transfer(from_o.selected,to_o.selected),34)
 go.disabled=started
 var row2=_hbox(box,8)
 _label(row2,"Mover punto de partida de",14,PAPER)
 var who_o=OptionButton.new()
 for aid in ALL_ACTORS:who_o.add_item("%d %s" % [_actor_number(aid),str(_actor(aid).get("name",aid))])
 row2.add_child(who_o)
 for d in [["▲ Norte",Vector2(0,-7)],["▼ Sur",Vector2(0,7)],["◀ Oeste",Vector2(-5,0)],["▶ Este",Vector2(5,0)]]:
  var dv:Vector2=d[1]
  var mb=_button(row2,str(d[0]),func():_deploy_nudge(who_o.selected,dv),34);mb.disabled=started
 var small_h=get_viewport().get_visible_rect().size.y<800.0
 var note=_rich(box,"Límites: ±%d de fuerza por grupo (tope 100), %d m de movimiento del punto, solo en tierra firme. El equilibrio se midió con el despliegue por defecto." % [int(rules.DEPLOY_MARGIN),int(rules.DEPLOY_MOVE_M)] if small_h else "Cada grupo puede variar hasta ±%d de fuerza y cada punto de partida moverse hasta %d m, solo en tierra firme. El juego se equilibró con el despliegue por defecto." % [int(rules.DEPLOY_MARGIN),int(rules.DEPLOY_MOVE_M)],12)
 note.custom_minimum_size.x=1000
 var brow=_hbox(box,8)
 var start=_button(brow,"Empezar a ordenar (en pausa)",_close_modal,42);start.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 _button(brow,"Ver todo el mapa",func():_close_modal();_view_all(),42)

func _draw_deploy_map(c:Control):
 var sz=c.custom_minimum_size
 var r=Rect2(Vector2.ZERO,sz)
 var size=rules.map_data().get("size",{"w":900.0,"h":520.0})
 var ship=rules.ship_state()
 # Zona de interés: de las agrupaciones al buque, con margen, y proporción del cuadro.
 var lo=Vector2(float(ship.x),float(ship.z));var hi=lo
 for id in ALL_ACTORS:
  var p=_actor_pos(id);lo=Vector2(minf(lo.x,p.x),minf(lo.y,p.y));hi=Vector2(maxf(hi.x,p.x),maxf(hi.y,p.y))
 lo-=Vector2(35,35);hi+=Vector2(35,35)
 var ctr=(lo+hi)*0.5;var ext=hi-lo
 var asp=sz.x/sz.y
 if ext.x/ext.y<asp:ext.x=ext.y*asp
 else:ext.y=ext.x/asp
 var org=Vector2(clampf(ctr.x-ext.x*0.5,0.0,maxf(0.0,float(size.w)-ext.x)),clampf(ctr.y-ext.y*0.5,0.0,maxf(0.0,float(size.h)-ext.y)))
 if mm_tex!=null:
  var ts=mm_tex.get_size()
  c.draw_texture_rect_region(mm_tex,r,Rect2(Vector2(org.x/float(size.w)*ts.x,org.y/float(size.h)*ts.y),Vector2(ext.x/float(size.w)*ts.x,ext.y/float(size.h)*ts.y)))
 else:c.draw_rect(r,Color("4a5d63"))
 c.draw_rect(r,Color("887750"),false,1.5)
 var k=sz.x/ext.x
 var font=_font()
 c.draw_rect(Rect2(0,0,sz.x,18),Color(0.03,0.06,0.07,0.7))
 c.draw_string(font,Vector2(6,13),"N ▲ · puntos de partida · %d m de ancho" % int(ext.x),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("f4efe0"))
 var sp=(Vector2(float(ship.x),float(ship.z))-org)*k
 c.draw_circle(sp,5.0,Color("e9e3d4"));c.draw_string(font,sp+Vector2(-18,-9),"Buque",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("f4efe0"))
 for id in ALL_ACTORS:
  var p=_actor_pos(id)
  var q=(p-org)*k
  c.draw_circle(q,8.0,UNIT_COLORS[id]);c.draw_arc(q,8.0,0,TAU,18,Color(0.03,0.06,0.07),1.5)
  c.draw_string(font,q+Vector2(-4,4),str(_actor_number(id)),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(0.03,0.06,0.07))

# Qué cambia en el juego con la fuerza de cada grupo# Qué cambia en el juego con la fuerza de cada grupo (cuentas simples, las mismas del motor: fuerza = potencia de abordaje y de captura).
func _deploy_consequences()->String:
 var tot=0.0;var parts=[]
 for id in GROUP_IDS:
  var a=_actor(id)
  if a.is_empty():continue
  tot+=float(a.strength)
  parts.append("%s %d" % [_short_name(id),int(a.strength)])
 var shares=[]
 for id in GROUP_IDS:
  var a2=_actor(id)
  if not a2.is_empty() and tot>0.0:shares.append("%s %d %%" % [_short_name(id),roundi(100.0*float(a2.strength)/tot)])
 return "[b]Consecuencias.[/b] Fuerza total del abordaje: [b]%d[/b] (%s). Reparto de la captura: %s. Un grupo con más fuerza aporta más potencia de abordaje (la captura sube y la moral de la dotación baja más rápido) y tarda más en dispersarse. La marcha depende del ritmo y del terreno, no de la fuerza." % [int(tot),", ".join(parts),", ".join(shares)]

func _deploy_nudge(i:int,d:Vector2):
 var id=str(ALL_ACTORS[i])
 var p=_actor_pos(id)
 var r=rules.deploy_place(id,p.x+d.x,p.y+d.y)
 _deploy_dialog()
 _toast(str(r.get("reason","")),4.5,bool(r.get("ok",false)));_sound("order" if bool(r.get("ok",false)) else "error")
 _update_hud()

func _deploy_transfer(from_i:int,to_i:int):
 var r=rules.deploy_transfer(GROUP_IDS[from_i],GROUP_IDS[to_i],rules.DEPLOY_STEP)
 var msg=str(r.get("reason",""))
 _deploy_dialog()
 _toast(msg,4.5,bool(r.get("ok",false)));_sound("order" if bool(r.get("ok",false)) else "error")
 _update_hud()

# ---------- Ayuda ----------

func _dest_name(id:String,dest:Vector2)->String:
 var key="%s|%d|%d" % [id,int(dest.x/4.0),int(dest.y/4.0)]
 var c=eta_cache.get("dn_"+id,null)
 if c!=null and str(c.key)==key:return str(c.name)
 var nm=_place_name(dest)
 if nm.length()>22:nm=nm.substr(0,21)+"…"
 eta_cache["dn_"+id]={"key":key,"name":nm}
 return nm

func _route_label(font,id:String,pts:PackedVector2Array,blocked:Array,placed:Array,is_sel:bool):
 var e=_eta_s(id)
 if e<0.0 or pts.size()<2:return
 var a=_actor(id)
 var dest=Vector2.ZERO
 if a.get("path",[]).is_empty():return
 var last=a.path[a.path.size()-1]
 dest=Vector2(float(last.x),float(last.z))
 var txt="%d → %s · %s" % [_actor_number(id),_dest_name(id,dest),_clock(e)] if is_sel else "%d · %s" % [_actor_number(id),_clock(e)]
 var fs=12 if is_sel else 11
 var ts=font.get_string_size(txt,HORIZONTAL_ALIGNMENT_LEFT,-1,fs)
 var end=pts[pts.size()-1]
 var rect=Rect2(end+Vector2(10,-ts.y-8),ts+Vector2(12,6))
 var view=get_viewport().get_visible_rect().size
 if rect.end.x>view.x-6:rect.position.x=end.x-rect.size.x-10
 if _overlaps_any(rect.grow(2),placed) or _overlaps_any(rect,blocked) or not Rect2(Vector2.ZERO,view).encloses(rect):return
 placed.append(rect)
 var c:Color=UNIT_COLORS[id]
 overlay.draw_style_box(_cached_style("etab"+str(is_sel)+c.to_html(),Color(0.03,0.07,0.09,0.88),c,2 if is_sel else 1,4),rect)
 overlay.draw_string(font,rect.position+Vector2(6,ts.y*0.5+rect.size.y*0.5-4),txt,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,c)

func minimap_rect()->Rect2:
 return Rect2(map_widget.get_global_rect().position,_mm_size())

func compass_rect()->Rect2:
 var r=minimap_rect()
 return Rect2(r.end.x-56,r.position.y+4,52,52)

func scale_rect()->Rect2:
 var r=minimap_rect()
 var info=_scale_info()
 return Rect2(r.end.x-8-float(info.px),r.end.y-34,float(info.px),12)

func _scale_info()->Dictionary:
 var mpp=maxf(0.0001,world.meters_per_pixel(camera))
 var best=J_NICE[0];var best_px=float(best)/mpp
 var found=false
 for m in J_NICE:
  var px=float(m)/mpp
  if px>=80.0 and px<=160.0:best=m;best_px=px;found=true;break
 if not found:
  var score=1e9
  for m in J_NICE:
   var px=float(m)/mpp
   var sc=absf(log(px/120.0))
   if sc<score:score=sc;best=m;best_px=px
 return {"m":best,"px":best_px,"mpp":mpp}

func _m2px(p:Vector2)->Vector2:
 return world.world_to_map(p)*_mm_size()

func _refresh_minimap():
 if not is_instance_valid(world) or not _is_j():return
 mm_tex=world.get_minimap_texture(Vector2i(_mm_size()))
 if is_instance_valid(map_widget):map_widget.queue_redraw()

func _draw_map_widget():
 var w=map_widget
 if not is_instance_valid(w) or not is_instance_valid(world) or not is_instance_valid(camera) or not _is_j():return
 var font=_font()
 var msz=_mm_size()
 var r=Rect2(Vector2.ZERO,msz)
 w.draw_rect(Rect2(Vector2.ZERO,w.size),Color(0.04,0.08,0.1,0.95))
 if mm_tex!=null:w.draw_texture_rect(mm_tex,r,false)
 else:w.draw_rect(r,Color("4a5d63"))
 w.draw_rect(r,Color("887750"),false,1.5)
 # trayectos previstos
 for id in ALL_ACTORS:
  var a=_actor(id)
  if a.is_empty() or a.get("path",[]).is_empty():continue
  var pts=PackedVector2Array([_m2px(Vector2(float(a.x),float(a.z)))])
  for node in a.path:pts.append(_m2px(Vector2(float(node.x),float(node.z))))
  var uc:Color=UNIT_COLORS[id]
  w.draw_polyline(pts,Color(uc.r,uc.g,uc.b,0.8),1.5)
 # cuadro de la cámara
 var fr=world.camera_frustum_on_ground(camera)
 if fr.size()>=3:
  var fp=PackedVector2Array()
  for q in fr:fp.append(_m2px(q).clamp(Vector2.ZERO,msz))
  fp.append(fp[0])
  w.draw_polyline(fp,Color(1,1,1,0.95),1.6)
 # buque
 var ss=rules.ship_state()
 var sp=_m2px(Vector2(float(ss.x),float(ss.z)))
 w.draw_circle(sp,5.0,Color("e9e3d4"));w.draw_arc(sp,7.5,0,TAU,20,Color(0.03,0.06,0.07),1.6)
 w.draw_string(font,sp+Vector2(-16,-11),"Buque",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("f4efe0"))
 # leyenda del minimapa
 var lg=[[Color("5e5a45"),"barranca"],[Color("c8b88a"),"orilla"],[Color("4a5d63"),"agua"],[Color("6fb8a6"),"medido"],[Color("e8a0a0"),"sin medir"]]
 var lx=6.0;var ly=msz.y-16.0
 w.draw_rect(Rect2(0,ly-3,msz.x,19),Color(0.03,0.06,0.07,0.6))
 for e in lg:
  w.draw_rect(Rect2(lx,ly+2,9,9),e[0]);w.draw_rect(Rect2(lx,ly+2,9,9),Color(0,0,0,0.5),false,1.0)
  var tw=font.get_string_size(str(e[1]),HORIZONTAL_ALIGNMENT_LEFT,-1,10).x
  w.draw_string(font,Vector2(lx+12,ly+11),str(e[1]),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("e9e3d4"))
  lx+=tw+17.0
 # grupos y exploradores
 for id in ALL_ACTORS:
  var a=_actor(id)
  if a.is_empty():continue
  var pos=_m2px(Vector2(float(a.x),float(a.z)))
  var c:Color=UNIT_COLORS[id]
  if id in SCOUT_IDS:
   if str(a.stage)=="lost":c=Color("7a7a78")
   w.draw_colored_polygon(PackedVector2Array([pos+Vector2(0,-4.5),pos+Vector2(4.5,0),pos+Vector2(0,4.5),pos+Vector2(-4.5,0)]),c)
  else:
   if float(a.strength)<=0.0:continue
   w.draw_rect(Rect2(pos-Vector2(3.5,3.5),Vector2(7,7)),c);w.draw_rect(Rect2(pos-Vector2(3.5,3.5),Vector2(7,7)),Color(0.03,0.06,0.07),false,1.0)
  if sel_ids.has(id):w.draw_arc(pos,8.0,0,TAU,20,Color.WHITE,1.6)
 # N fija y brújula que gira con la guiñada (N hacia -z, E hacia +x)
 w.draw_string(font,Vector2(6,13),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("f4efe0"))
 w.draw_string(font,Vector2(20,13),"MINIMAPA · clic mueve la vista",HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color(0.96,0.94,0.88,0.9))
 var cr=compass_rect();var cc=cr.position-minimap_rect().position+cr.size*0.5
 w.draw_circle(cc,25.0,Color(0.03,0.07,0.09,0.78));w.draw_arc(cc,25.0,0,TAU,28,Color("887750"),1.2)
 var nd=Vector2(sin(camera_yaw),-cos(camera_yaw));var ed=Vector2(cos(camera_yaw),sin(camera_yaw))
 w.draw_line(cc-nd*10,cc+nd*15,Color("e9e3d4"),2.0,true)
 w.draw_colored_polygon(PackedVector2Array([cc+nd*21,cc+nd*12+ed*4.5,cc+nd*12-ed*4.5]),Color("f08c78"))
 w.draw_line(cc,cc+ed*14,Color("8fb4d9"),1.4,true)
 w.draw_string(font,cc+nd*10-Vector2(4,-4),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("f4efe0"))
 w.draw_string(font,cc+ed*17-Vector2(3,-4),"E",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("8fb4d9"))
 # escala gráfica
 var si=_scale_info()
 var y=msz.y-28.0
 var x0=msz.x-8.0-float(si.px)
 w.draw_rect(Rect2(x0-4,y-9,float(si.px)+8,20),Color(0.03,0.06,0.07,0.6))
 w.draw_line(Vector2(x0,y+4),Vector2(x0+float(si.px),y+4),PAPER,2.0)
 w.draw_line(Vector2(x0,y),Vector2(x0,y+8),PAPER,2.0);w.draw_line(Vector2(x0+float(si.px),y),Vector2(x0+float(si.px),y+8),PAPER,2.0)
 w.draw_string(font,Vector2(x0,y-1),"%d m" % int(si.m),HORIZONTAL_ALIGNMENT_LEFT,-1,11,PAPER)

func _map_gui_input(event):
 if mode!="play" or not _is_j() or not is_instance_valid(world):return
 var msz=_mm_size()
 if event is InputEventMouseButton:
  var p=event.position
  if event.button_index==MOUSE_BUTTON_LEFT:
   if event.pressed and p.y<=msz.y:mm_dragging=true;_map_center(p)
   elif not event.pressed:mm_dragging=false
  elif event.button_index==MOUSE_BUTTON_RIGHT and event.pressed and p.y<=msz.y:
   var wp=world.map_to_world(Vector2(clampf(p.x/msz.x,0,1),clampf(p.y/msz.y,0,1)))
   if aim!="":_aim_click(wp,event.shift_pressed)
   else:_right_click_world(wp,event.shift_pressed)
   map_widget.accept_event()
 elif event is InputEventMouseMotion:
  var p2=event.position
  if mm_dragging and (event.button_mask&MOUSE_BUTTON_MASK_LEFT)!=0 and p2.y<=msz.y:_map_center(p2)
  elif p2.y<=msz.y and p2.x>=0 and p2.x<=msz.x:
   _set_preview_point(world.map_to_world(Vector2(p2.x/msz.x,p2.y/msz.y)),false)

func _map_center(p:Vector2):
 var msz=_mm_size()
 _center_on(world.map_to_world(Vector2(clampf(p.x/msz.x,0,1),clampf(p.y/msz.y,0,1))))

# ---------- Selección ----------
func _select_ids(ids:Array,how:String="set"):
 if mode=="play":_sound("select")
 var out=[]
 if how=="set":out=ids.duplicate()
 else:
  out=sel_ids.duplicate()
  for i in ids:
   if how=="add":
    if not out.has(i):out.append(i)
   elif how=="toggle":
    if out.has(i):out.erase(i)
    else:out.append(i)
 sel_ids=[]
 for a in ALL_ACTORS:
  if out.has(a):sel_ids.append(a)
 selected=str(sel_ids[0]) if not sel_ids.is_empty() else ""
 if is_instance_valid(world):
  world.selected=selected;world.set_selected_ids(sel_ids)
  world.set_layer_visible("exposure",not _sel_groups().is_empty())
 if (aim=="move" and _sel_groups().is_empty()) or (aim in ["probe","probe_careful","mark_ford"] and _sel_scouts().is_empty()):aim="";aim_pts=[]
 pending_pt=null;wp_list=[];hover_plan_key="";hover_info={}
 select_flash=0.5
 _refresh_actions();_update_hud()
 if is_instance_valid(world):world.refresh_paths()
 _sound("order")

func _mods_how(shift:bool,ctrl:bool)->String:
 if ctrl:return "toggle"
 if shift:return "add"
 return "set"

var _last_roster_id=""
var _last_roster_ms=0
func _roster_click(id:String):
 _select_ids([id],_mods_how(Input.is_key_pressed(KEY_SHIFT),Input.is_key_pressed(KEY_CTRL)))
 # Doble clic en una ficha: la cámara va a esa tropa (selección y órdenes rápidas).
 var now=Time.get_ticks_msec()
 if id==_last_roster_id and now-_last_roster_ms<450:_center_selection()
 _last_roster_id=id;_last_roster_ms=now

func _cycle_selection():
 var i=ALL_ACTORS.find(sel_ids[0]) if not sel_ids.is_empty() else -1
 _select_ids([ALL_ACTORS[(i+1)%ALL_ACTORS.size()]])

func _set_pace(p:String):
 pace=p
 for id in _sel_groups():
  var u=rules.get_unit(id)
  if str(u.get("stage",""))=="moving" and str(u.get("order",{}).get("action",""))=="move":
   rules.issue_order(id,"move",Vector2(float(u.order.x),float(u.order.z)),{"pace":pace})
 _toast({"walk":"Ritmo: caminar.","trot":"Ritmo: trote.","gallop":"Ritmo: galope. Solo rinde en terreno firme; en barro y agua se limita al trote."}[p],3.5)
 _update_hud()

# ---------- Acciones ----------
func _action_info(a:String)->Dictionary:
 var info=rules.action_info(a)
 if info.is_empty():info=ACTION_FALLBACK.get(a,{})
 return info

const LABEL_SHORT = {"board_own":"Cargar sin orden","withdraw":"Retirar","repel":"Rechazar ataque","distract_fire":"Distraer con fuego","retreat_all":"Retirada general","signal_liniers":"Pedir carga a Liniers","probe":"Sondear el agua"}
func _action_label(a:String)->String:
 if LABEL_SHORT.has(a):return str(LABEL_SHORT[a])
 return str(_action_info(a).get("label",a))

func _action_tag(a:String)->String:
 return str(_action_info(a).get("tag","diseno"))

func _action_effect(a:String)->String:
 return str(_action_info(a).get("effect",""))

func _action_kind(a:String)->String:
 if a in ["probe","probe_careful","mark_ford","recall"]:return "scout"
 if a in ["distract_fire","retreat_all"]:return "global"
 return "group"

func _refresh_actions_j():
 for child in action_box.get_children():action_box.remove_child(child);child.queue_free()
 var kind="none"
 if not _sel_groups().is_empty():kind="group"
 elif not _sel_scouts().is_empty():kind="scout"
 var ids=[]
 if kind!="none":ids=rules.list_actions(kind)
 ids=ids+rules.list_actions("global")
 if kind=="group" and not bool(rules.state.advance_authorized):
  var bi=ids.find("board")
  ids.insert(bi+1 if bi>=0 else ids.size(),"board_own")
 ids.append("undo")
 # Lo riesgoso va al final y con otro color: no queda pegado a lo de uso común.
 var calm=[];var risky=[]
 for a0 in ids:
  if str(a0) in ["withdraw","distract_fire","retreat_all","board_own"]:risky.append(a0)
  else:calm.append(a0)
 ids=calm+risky
 var grid=GridContainer.new();grid.columns=6;grid.add_theme_constant_override("h_separation",4);grid.add_theme_constant_override("v_separation",4);action_box.add_child(grid)
 var grid2_holder=_vbox(action_box,0)
 var risk_row:HBoxContainer=null
 for a in ids:
  var act=str(a)
  var is_risky=act in ["withdraw","distract_fire","retreat_all","board_own"]
  if is_risky and risk_row==null:
   _spacer(grid2_holder,6)
   risk_row=_hbox(grid2_holder,4)
   var rl=_label(risk_row,"CON RIESGO ▸",10,Color("d98a5c"));rl.size_flags_vertical=Control.SIZE_SHRINK_CENTER
  var b=_button(risk_row if is_risky else grid,"",func():_do_action(act),34)
  b.add_theme_font_size_override("font_size",10);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  b.custom_minimum_size.x=122
  b.clip_text=true;_compact(b,3,2)
  b.mouse_entered.connect(func():_show_action_info(act))
  b.focus_entered.connect(func():_show_action_info(act))
  b.mouse_exited.connect(func():_show_action_info(""))
  b.gui_input.connect(_blocked_click.bind(b))
  action_buttons[act]=b
 reason_label=_label(action_box,"",11,MUTED);reason_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 reason_label.custom_minimum_size=Vector2(860,30);reason_label.max_lines_visible=2;reason_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 # Altura fija: si el texto de ayuda creciera al pasar el mouse, los botones se moverían bajo el cursor y el clic fallaría.
 hover_action=""
 _update_action_states()

func _avail(action:String)->Dictionary:
 if action=="retry_now":return {"ok":true,"reason":"Disponible.","cost_text":"","tag":"diseno"}
 if action=="board_own":
  var gs=_sel_groups()
  if gs.is_empty():return {"ok":false,"reason":"Seleccioná un grupo (1, 2, 3).","cost_text":"","tag":"diseno"}
  var fail_o={}
  for gid in gs:
   var ao=rules.on_own_charge_check(gid)
   if bool(ao.get("ok",false)):return {"ok":true,"reason":"Disponible.","cost_text":"−20 % captura, sin oro","tag":"diseno"}
   if fail_o.is_empty():fail_o=ao.duplicate()
  fail_o["cost_text"]="−20 % captura, sin oro";fail_o["tag"]="diseno"
  return fail_o
 if action=="last_effort":
  var le_ok=rules.last_effort_available()
  return {"ok":bool(le_ok.get("ok",false)),"reason":str(le_ok.get("reason","")),"cost_text":"voluntarios de reserva","tag":"diseno"}
 if action=="undo":
  var okk=not order_log.is_empty() and str(rules.state.status)=="playing"
  return {"ok":okk,"reason":"" if okk else "Todavía no diste ninguna orden que se pueda deshacer.","cost_text":"última orden","tag":"diseno"}
 var kind=_action_kind(action)
 var actors=[]
 if kind=="global":actors=[sel_ids[0] if not sel_ids.is_empty() else "guemes"]
 elif kind=="scout":actors=_sel_scouts()
 else:actors=_sel_groups()
 if action in ["repel","evacuate"]:
  var bd=[]
  for id in GROUP_IDS:
   if str(rules.get_unit(id).get("stage",""))=="boarding":bd.append(id)
  if not bd.is_empty():actors=bd
 if actors.is_empty():return {"ok":false,"reason":"Seleccioná un explorador (4, 5)." if kind=="scout" else "Seleccioná un grupo (1, 2, 3).","cost_text":"","tag":_action_tag(action)}
 if action=="recall":
  for id in actors:
   var s=_actor(id)
   if not s.is_empty() and str(s.stage)!="lost" and int(s.hp)>0:return {"ok":true,"reason":"Disponible.","cost_text":"vuelve a la playa","tag":"diseno"}
  return {"ok":false,"reason":"El explorador fue abatido y no recibe órdenes.","cost_text":"vuelve a la playa","tag":"diseno"}
 var fail={}
 for id in actors:
  var target=Vector2.ZERO
  if action=="board":target=rules.board_point()
  elif action in ["move","probe","probe_careful","mark_ford"]:target=_actor_pos(id)
  var av=rules.action_availability(id,action,target)
  if bool(av.get("ok",false)):return av
  if fail.is_empty():fail=av
 return fail

func _update_action_states():
 if not is_instance_valid(action_box):return
 var playing=str(rules.state.status)=="playing"
 var rec=_next_step()
 var nblocked=0
 var blocked_note=""
 for a in action_buttons:
  var b:Button=action_buttons[a]
  if not is_instance_valid(b):continue
  var av=_avail(a)
  var ok=bool(av.get("ok",false)) and playing
  var tag=str(av.get("tag",_action_tag(a)))
  var kt=_key_text(a)
  var cost_parts=str(av.get("cost_text","")).split(" · ")
  var cost=" · ".join(cost_parts.slice(0,2)).replace(" puntos"," pts").replace("hasta ","≤ ")
  b.text=_tag_glyph(tag)+" "+_action_label(a)+"\n"+(("["+kt+"] ") if kt!="" else "")+cost
  b.disabled=not ok
  # Solo se muestra lo que se puede usar ahora (más la recomendada); lo demás se explica en una línea.
  b.visible=ok or str(rec.action)==a
  if str(rec.action)!=a:b.add_theme_font_size_override("font_size",10);b.remove_theme_color_override("font_color")
  # Acciones de abordaje: solo se muestran cuando hay un grupo abordando o un contraataque en curso (menos botones en gris).
  if a in ["repel","evacuate"]:
   b.visible=_anyone_boarding()
  if a=="retreat_all":b.visible=false  # acción peligrosa: se llega por ☰ Menú > Abandonar, con confirmación
  var why="" if ok else _friendly_reason(a,str(av.get("reason","")) if playing else "La partida ya terminó.")
  b.tooltip_text=_action_effect(a)+"\nTecla: "+(kt if kt!="" else "—")+"  ·  Fuente: "+_tag_glyph(tag)+" "+_tag_label(tag)+(("\nNo disponible ahora: "+why) if not ok else "")
  b.set_meta("why",why)
  if a=="retreat_all":
   b.add_theme_stylebox_override("normal",_cm_style("act_danger" if ok else "act_danger_off",Color("3a1613") if ok else Color("221615"),Color("e0705c") if ok else Color("4a2e2a"),2,3,2))
   b.add_theme_color_override("font_color",Color("ffc6b8"));b.add_theme_color_override("font_disabled_color",Color("8a6a64"))
   b.tooltip_text+="
PELIGRO: pide confirmación y termina la partida. No es lo mismo que «Retirar» (L), que solo manda a los grupos elegidos de vuelta a la playa."
  elif ok and str(rec.action)==a:
   b.add_theme_stylebox_override("normal",_cm_style("act_rec",Color("4a421c"),Color("f6dc92"),3,3,2))
   b.add_theme_font_size_override("font_size",12);b.add_theme_color_override("font_color",Color("fff0c4"))
  elif ok and a in ["withdraw","distract_fire","board_own"]:
   b.add_theme_stylebox_override("normal",_cm_style("act_risky",Color("3a2616"),Color("d98a5c"),1,3,2))
   b.add_theme_font_size_override("font_size",10)
  elif ok:
   b.add_theme_stylebox_override("normal",_cm_style("act_ok",Color("1f3b42"),Color("6fb8a6"),1,3,2))
  else:
   b.add_theme_stylebox_override("normal",_cm_style("act_no",Color("172326"),Color("2c3a38"),1,3,2))
  if not ok:
   nblocked+=1
   if blocked_note.is_empty() or (str(rec.action)==a):
    var wshort=why.split(". ")[0].rstrip(".")
    blocked_note=_action_label(a)+": "+(wshort if wshort.length()<=120 else wshort.substr(0,117)+"…")
 if is_instance_valid(reason_label) and hover_action.is_empty():
  reason_label.add_theme_color_override("font_color",Color("f0d27a"))
  var tut_on=bool(settings.tutorial) and tut_step<TUT_STEPS.size() and str(rules.state.status)=="playing" and not _tutorial_j().is_empty() and not (is_instance_valid(alert_panel) and alert_panel.visible)
  if tut_on:
   # Un solo mensaje guía a la vez: mientras el tutorial está en pantalla, esta línea solo explica cómo leer los botones.
   reason_label.add_theme_color_override("font_color",MUTED)
   reason_label.text="Seguí la guía de arriba. Solo ves los botones que podés usar ahora."
  else:
   reason_label.text="AHORA ▸ "+str(rec.text)

func _show_action_info(a:String):
 hover_action=a
 if not is_instance_valid(reason_label):return
 if a.is_empty():_update_action_states();return
 var b:Button=action_buttons.get(a)
 var why=str(b.get_meta("why","")) if is_instance_valid(b) else ""
 reason_label.add_theme_color_override("font_color",MUTED)
 reason_label.text=_action_label(a)+": "+_action_effect(a)+(("\nNo disponible ahora — "+why) if not why.is_empty() else "")

func _do_action(action:String):
 if mode!="play" or str(rules.state.status)!="playing":return
 match action:
  "undo":_undo_order();return
  "retry_now":
   if campaign.has_checkpoint():_retry_checkpoint()
   else:_retry(false)
   return
  "last_effort":
   var lr=rules.last_effort()
   _toast(str(lr.get("reason","")),5,bool(lr.get("ok",false)),3);_sound("order" if bool(lr.get("ok",false)) else "error");_juice("counter")
  "distract_fire":
   var r=rules.call_fire_support()
   _toast(str(r.get("reason","")),4,bool(r.get("ok",false)));_sound("order" if bool(r.get("ok",false)) else "error")
  "retreat_all":_retreat_dialog()
  "move","probe","probe_careful","mark_ford":_enter_aim(action)
  "recall":
   var sc=_sel_scouts()
   _log_order(sc)
   var done=0;var msg=""
   for id in sc:
    var r2=rules.issue_scout(id,"recall",[])
    if bool(r2.get("ok",false)):done+=1
    msg=str(r2.get("reason",""))
   if done==0 and not order_log.is_empty():order_log.pop_back()
   _toast(msg if done==0 else "Exploradores de vuelta a la playa seca.",3.5,done>0)
  "board":_board_action()
  "board_own":
   if not (confirm_action=="board_own" and confirm_timer>0):
    confirm_action="board_own";confirm_timer=5.0
    _toast("Cargar sin orden: la captura va un 20 % más lenta y se pierde el oro. Tocá de nuevo para confirmar.",5,false,2);_sound("alert");return
   confirm_action="";confirm_timer=0.0
   _board_action()
  "repel","evacuate":_do_boarding_action(action);return
  _:
   var groups=_sel_groups()
   if groups.is_empty():_toast("Seleccioná un grupo (1, 2, 3).",3,false);_sound("error");return
   _log_order(groups)
   var results=[]
   for id in groups:results.append(rules.issue_order(id,action,Vector2.ZERO,{"pace":pace}))
   _drop_log_if_failed(results)
   _report_orders(results,groups.size())
   if action=="signal_liniers":
    for r3 in results:
     if bool(r3.get("ok",false)):
      _toast("El grupo va a buscar el permiso de Liniers y no hace otra cosa hasta volver. Con el permiso podés «Cargar y abordar».",6,true);break
 if is_instance_valid(world):world.refresh_paths()
 _refresh_actions();_update_hud()

func _report_orders(results:Array,total:int):
 var ok=0;var msg=""
 for r in results:
  if bool(r.get("ok",false)):ok+=1
  msg=str(r.get("reason",msg))
 if ok==0:_toast(msg,4.5,false);_sound("error")
 else:_toast((("%d de %d órdenes dadas. " % [ok,total]) if total>1 else "")+msg,4,true);_sound("order")

func _board_action():
 var groups=_sel_groups()
 if groups.is_empty():_toast("Seleccioná un grupo (1, 2, 3).",3,false);return
 var bp=rules.board_point()
 var plan=rules.plan_route(groups[0],bp,pace,{})
 if not bool(plan.get("ok",false)):
  var fr=_friendly_reason("board",str(plan.get("reason","Sin ruta al buque.")))
  _sound("error")
  if fr.begins_with("El camino hasta el buque"):
   var alive=_sel_scouts()
   if alive.is_empty():
    for sid in SCOUT_IDS:
     var sa=_actor(sid)
     if not sa.is_empty() and str(sa.stage)!="lost" and int(sa.hp)>0:alive=[sid];break
    if not alive.is_empty():_select_ids(alive)
   if not _sel_scouts().is_empty():
    _enter_aim("probe")
    _toast("Antes de abordar hay que reconocer el fondo. Pasé la selección a un explorador (tu grupo no recibió ninguna orden): un clic en el agua cerca del buque sondea; después volvé a elegir el grupo (1-3) y N.",8,false);return
  _toast(fr,5,false);return
 if float(plan.get("unknown_m",0))>0.0 and not (confirm_action=="board" and confirm_timer>0):
  confirm_action="board";confirm_timer=5.0
  hover_info={"kind":"route","ok":true,"plan":plan,"point":Vector3(bp.x,_ground_y(bp.x,bp.y),bp.y),"text":_plan_text(plan),"risk":str(plan.get("risk","alto"))}
  _toast("Cargar y abordar: "+_plan_text(plan)+". Volvé a pulsar para confirmar.",5,false);return
 confirm_action="";confirm_timer=0.0
 _log_order(groups)
 var results=[]
 for id in groups:results.append(rules.issue_order(id,"board",bp,{"pace":pace}))
 _drop_log_if_failed(results)
 for r in results:
  if not bool(r.get("ok",false)):r["reason"]=_friendly_reason("board",str(r.get("reason","")))
 _report_orders(results,groups.size())

func _enter_aim(action:String):
 var kind=_action_kind(action)
 if kind=="scout" and _sel_scouts().is_empty():_toast("Seleccioná un explorador (4, 5).",3,false);return
 if kind=="group" and _sel_groups().is_empty():_toast("Seleccioná un grupo (1, 2, 3).",3,false);return
 aim=action;aim_pts=[];wp_list=[];pending_pt=null;hover_plan_key=""
 var text={"move":"Mover: clic en el terreno o en el minimapa. Shift agrega waypoints (hasta 4), Enter confirma, Esc cancela.","probe_careful":"Sondeo cauteloso: clic en el punto a sondear (más lento donde hay fuego, pero recibe la mitad de impactos). Shift agrega hasta 3 puntos, Enter confirma, Esc cancela.","probe":"Reconocer fondo: clic en el punto a sondear. Shift agrega hasta 3 puntos, Enter confirma, Esc cancela.","mark_ford":"Marcar vado: clic sobre un tramo ya sondeado (1 o 2 puntos con Shift). Enter confirma, Esc cancela."}[action]
 _toast(text,6)

func _cancel_aim():
 var had=aim!="" or not wp_list.is_empty() or pending_pt!=null
 aim="";aim_pts=[];wp_list=[];pending_pt=null;hover_info={};hover_plan_key=""
 if had:_toast("Cancelado.",2)

func _aim_click(p:Vector2,shift:bool):
 if aim=="move":
  if shift:_add_waypoint(p)
  else:_commit_move(p)
  return
 if aim in ["probe","probe_careful","mark_ford"]:
  var cap=3 if aim!="mark_ford" else 2
  if aim_pts.size()<cap:aim_pts.append(p)
  else:aim_pts[cap-1]=p
  if shift and aim_pts.size()<cap:
   _toast("Punto %d. Shift suma otro; Enter confirma." % aim_pts.size(),2.5);return
  _confirm_aim()

func _confirm_aim():
 if aim_pts.is_empty():return
 var scouts=_sel_scouts()
 if scouts.is_empty():return
 var ok=0;var msg=""
 _log_order(scouts)
 for id in scouts:
  var r=rules.issue_scout(id,aim,aim_pts)
  if bool(r.get("ok",false)):ok+=1
  msg=str(r.get("reason",msg))
 if ok==0 and not order_log.is_empty():order_log.pop_back()
 if ok==0 and msg.find("transitable")>=0:
  msg="Ese punto queda demasiado adentro del agua para el explorador: solo sondea donde puede llegar caminando o vadeando. Elegí un punto más cerca de la playa, entre la orilla y el buque. (%s)" % msg.split(": ")[-1].rstrip(".")
 if ok>0:
  _toast(msg if not msg.is_empty() else "Orden dada al explorador.",3.5);_sound("order");aim="";aim_pts=[];hover_info={}
 else:
  _toast(msg,4.5,false);_sound("error");aim_pts=[]
 _refresh_actions();_update_hud()

func _add_waypoint(p:Vector2):
 if wp_list.size()>=4:_toast("Máximo 4 waypoints.",2.5,false);return
 wp_list.append(p);hover_plan_key=""
 _toast("Waypoint %d. Clic derecho (sin Shift) o Enter terminan la ruta." % wp_list.size(),2.5)

func _confirm_key():
 if aim in ["probe","probe_careful","mark_ford"]:_confirm_aim();return
 if not wp_list.is_empty():
  var last=wp_list.pop_back() as Vector2
  _commit_move(last,true);return
 if pending_pt!=null:_commit_move(pending_pt,true)

func _right_click_world(p:Vector2,shift:bool):
 if _sel_groups().is_empty():
  _toast("Seleccioná un grupo (1, 2, 3) para ordenar mover." if _sel_scouts().is_empty() else "Los exploradores usan «Reconocer fondo» y «Marcar vado».",3.5,false);return
 if shift:_add_waypoint(p);return
 _commit_move(p)

func _plan_for(id:String,p:Vector2,wps:Array)->Dictionary:
 var opts={}
 if not wps.is_empty():opts["waypoints"]=wps.duplicate()
 return rules.plan_route(id,p,pace,opts)

func _plan_text(pl:Dictionary)->String:
 if not bool(pl.get("ok",false)):return _reason_with_help(str(pl.get("reason","Sin ruta.")))
 var t="%d m · %s" % [int(float(pl.length_m)),_clock(float(pl.eta_s))]
 if float(pl.get("unknown_m",0))>0.0:t+=" · %d m sin reconocer" % int(float(pl.unknown_m))
 t+=" · riesgo "+str(pl.get("risk","?"))
 if float(pl.get("exposed_s",0))>0.5:t+=" · expuesto %d s" % int(float(pl.exposed_s))
 return t

# Cada rechazo dice la causa y qué hacer: dónde sí se puede y cómo conseguir el dato que falta.
func _reason_with_help(why:String)->String:
 if why.find("fondo estimado")>=0:
  return why+" Es una estimación sin reconocer (no el nivel real del río): mandá un explorador (4 o 5, Z) a sondear o elegí un punto más cerca de la playa."
 if why.find("barranca solo se sube")>=0:
  return why+" Bajá por el Camino de la barranca (diseño) o quedate en la playa."
 if why.find("Agua demasiado honda")>=0:
  return why+" Buscá el vado junto al buque (se marca en el mapa) o esperá la bajante."
 return why

func _spread_targets(groups:Array,p:Vector2)->Array:
 var c=Vector2.ZERO
 for id in groups:c+=_actor_pos(id)
 c/=maxf(1.0,groups.size())
 var dir=(p-c)
 dir=dir.normalized() if dir.length()>0.1 else Vector2(1,0)
 var perp=Vector2(-dir.y,dir.x)
 var out=[]
 for i in range(groups.size()):out.append(p+perp*18.0*(float(i)-(groups.size()-1)*0.5))
 return out

func _commit_move(p:Vector2,force:bool=false):
 var groups=_sel_groups()
 if groups.is_empty():_toast("Seleccioná un grupo (1, 2, 3).",3,false);return
 var wps=wp_list.duplicate()
 var plan=_plan_for(groups[0],p,wps)
 if not bool(plan.get("ok",false)):
  _toast(str(plan.get("reason","Sin ruta.")),4.5,false);_sound("error");pending_pt=null;return
 if float(plan.get("unknown_m",0))>0.0 and not force and not (pending_pt!=null and (pending_pt as Vector2).distance_to(p)<10.0):
  pending_pt=p
  hover_info={"kind":"route","ok":true,"plan":plan,"point":Vector3(p.x,_ground_y(p.x,p.y),p.y),"text":_plan_text(plan),"risk":str(plan.get("risk","alto"))}
  _toast(_plan_text(plan)+".\nHay tramo sin reconocer: repetí el clic derecho o pulsá Enter para confirmar.",6,false);return
 pending_pt=null
 var dests=_spread_targets(groups,p)
 var results=[]
 _log_order(groups)
 for i in range(groups.size()):
  var opts={"pace":pace}
  if not wps.is_empty():opts["waypoints"]=wps.duplicate()
  results.append(rules.issue_order(groups[i],"move",dests[i],opts))
 _drop_log_if_failed(results)
 wp_list=[]
 if aim=="move":aim=""
 _report_orders(results,groups.size())
 if is_instance_valid(world):world.refresh_paths()
 _update_hud()

func _retreat_dialog():
 var box=_open_modal("¿Terminar la partida con una retirada general?",640,300)
 _rich(box,"Todos los grupos vuelven y la partida termina como derrota ordenada. Se muestra el parte de campaña.",17)
 var row=_hbox(box)
 _button(row,"Sí, terminar la partida",func():_close_modal();rules.retreat_all();_update_hud(),42)
 _rich(box,"Distinta de «Retirar» (L): esa orden solo manda de vuelta a la playa a los grupos elegidos y la partida sigue.",14)
 _button(row,"No, seguir",_close_modal,42)

# ---------- Vista previa de ruta ----------
func _update_hover_j(delta):
 hover_timer-=delta
 if hover_timer>0:return
 hover_timer=0.1
 if mode!="play" or is_instance_valid(modal) or not is_instance_valid(world) or str(rules.state.status)!="playing":
  hover_info={};return
 _update_place()
 var mp=hover_mouse
 if not get_viewport().get_visible_rect().has_point(mp):hover_info={};return
 for r in _blocked_rects():
  if r.has_point(mp):
   hover_info={}  # sobre un panel o el minimapa no queda ningún cartel de ruta/error colgado
   return
 if rmb_down or lmb_down:return
 var g=world.ground_xz_from_screen(camera,mp)
 if g==null:hover_info={};return
 _set_preview_point(g,false)

func _set_preview_point(g:Vector2,force:bool):
 var key="%s|%s|%d|%d|%d" % [aim,pace,wp_list.size(),aim_pts.size(),sel_ids.size()]
 if not force and last_hover_pt!=null and (last_hover_pt as Vector2).distance_to(g)<1.5 and key==hover_plan_key and Time.get_ticks_msec()-hover_stamp<1000:return
 last_hover_pt=g;hover_plan_key=key;hover_stamp=Time.get_ticks_msec()
 if aim in ["probe","probe_careful","mark_ford"]:
  var scouts=_sel_scouts()
  if scouts.is_empty():hover_info={};return
  var pts=aim_pts.duplicate();pts.append(g)
  var rtxt=""
  if aim in ["probe","probe_careful"]:rtxt=str(rules.scout_risk(scouts[0],pts,aim=="probe_careful").get("text",""))
  hover_info={"kind":"scout","ok":true,"pts":pts,"point":Vector3(g.x,_ground_y(g.x,g.y),g.y),"text":_scout_summary(aim,scouts[0],pts)+((" · "+rtxt) if rtxt!="" else ""),"risk":"bajo","risk_text":rtxt}
 elif aim=="" or aim=="move":
  var groups=_sel_groups()
  if groups.is_empty():hover_info={};return
  var plan=_plan_for(groups[0],g,wp_list)
  var ok=bool(plan.get("ok",false))
  hover_info={"kind":"route","ok":ok,"plan":plan,"point":Vector3(g.x,_ground_y(g.x,g.y),g.y),"text":_plan_text(plan),"risk":str(plan.get("risk","desconocido")) if ok else "alto"}
 else:hover_info={}

func _scout_summary(action:String,scout_id:String,pts:Array)->String:
 var info=rules.action_info(action)
 var sw=float(info.get("speed_mps_water",1.0));var sd=float(info.get("speed_mps_dry",3.0))
 var chain=[]
 if action=="mark_ford":chain=pts.duplicate()
 else:
  chain=[_actor_pos(scout_id)]
  chain.append_array(pts)
 var total=0.0;var secs=0.0
 for i in range(chain.size()-1):
  var a=chain[i] as Vector2;var b=chain[i+1] as Vector2
  var seg=a.distance_to(b)
  var steps=maxi(1,int(seg/5.0))
  for k in range(steps):
   var q=a.lerp(b,(float(k)+0.5)/float(steps))
   var wet=rules.perceived_depth_at(q.x,q.y)>0.0
   secs+=(seg/steps)/(sw if wet else sd)
  total+=seg
 if action=="mark_ford":
  var work=float(info.get("work_mps",1.0))
  return "marcado de %d m · %d balizas · ≈ %s" % [int(total),int(ceil(total/10.0)),_clock(total/work)]
 return "sondeo de %d m · ≈ %s" % [int(total),_clock(secs)]

func _update_place():
 if not is_instance_valid(place_label):return
 var p=Vector2(camera_target.x,camera_target.z)
 var pre="Centro de la vista: "
 if is_instance_valid(world) and is_instance_valid(camera) and mode=="play":
  var gc=world.ground_xz_from_screen(camera,get_viewport().get_visible_rect().size*0.5)
  if gc!=null:p=gc as Vector2
 if is_instance_valid(world) and is_instance_valid(camera) and mode=="play" and get_viewport().get_visible_rect().has_point(hover_mouse):
  var over_ui=false
  for r in _blocked_rects():
   if r.has_point(hover_mouse):over_ui=true;break
  if not over_ui:
   var g=world.ground_xz_from_screen(camera,hover_mouse)
   if g!=null:p=g as Vector2;pre="Bajo el cursor: "
 place_label.text="%s%s" % [pre,_place_name(p)]

func _dist_polyline(p:Vector2,pts:Array)->float:
 var best=1e9
 for i in range(pts.size()-1):
  var a=Vector2(float(pts[i][0]),float(pts[i][1]));var b=Vector2(float(pts[i+1][0]),float(pts[i+1][1]))
  var cp=Geometry2D.get_closest_point_to_segment(p,a,b)
  best=minf(best,p.distance_to(cp))
 return best

func _place_name(p:Vector2)->String:
 var m=_jmap()
 var ship=rules.ship_position()
 if p.distance_to(ship)<130.0:return "Frente al buque"
 for lm in m.get("landmarks",[]):
  var lt=str(lm.get("type",""))
  if lt=="road":
   if _dist_polyline(p,lm.polyline)<22.0:return str(lm.name)
   continue
  if lt=="ship":continue
  var rad=float(lm.get("radius_m",maxf(float(lm.get("w",20)),float(lm.get("d",20)))))+30.0
  if p.distance_to(Vector2(float(lm.x),float(lm.z)))<rad:return str(lm.name)
 for ob in m.get("obstacles",[]):
  if absf(p.x-float(ob.x))<float(ob.w)*0.5+10.0 and absf(p.y-float(ob.z))<float(ob.d)*0.5+10.0:return "Cañaveral" if str(ob.kind)=="vegetacion" else "Carretas varadas"
 var kind=rules.terrain_kind_at(p.x,p.y)
 match kind:
  "meseta":return "Meseta del Retiro"
  "barranca":return "Barranca del Retiro"
  "bajada":return "Bajada de la barranca"
  "firme":return "Playa alta"
  "barro":return "Barro"
 # Un banco solo se nombra si el jugador lo conoce o lo ve emerger (no se filtra el fondo oculto).
 var emerged=rules.water_depth_at(p.x,p.y)<0.0
 var known=rules.knowledge_at(p.x,p.y)!="unknown"
 for b in m.get("banks",[]):
  if (known or emerged) and _dist_polyline(p,b.centerline)<=float(b.half_width_m)+float(b.blend_m)*0.5:
   return str(b.name)+("" if known else " (sin reconocer)")
 return "Agua turbia" if known else "Agua turbia (sin reconocer)"

# ---------- Entrada de Justina ----------
func _j_input(event):
 if event is InputEventKey and event.pressed and not event.echo:
  var k=event.physical_keycode
  var shift=event.shift_pressed;var ctrl=event.ctrl_pressed
  if event.keycode==KEY_QUESTION or (k==KEY_SLASH and shift):_briefing_dialog();return
  if ctrl and k==KEY_Z:_undo_order();return
  if event.keycode in [KEY_PLUS,KEY_EQUAL,KEY_KP_ADD] and not ctrl:_step_speed(1);return
  if event.keycode in [KEY_MINUS,KEY_KP_SUBTRACT] and not ctrl:_step_speed(-1);return
  match k:
   KEY_1,KEY_2,KEY_3,KEY_4,KEY_5:_select_ids([ALL_ACTORS[k-KEY_1]],_mods_how(shift,ctrl))
   KEY_QUOTELEFT:_select_ids(GROUP_IDS.duplicate(),"set")
   KEY_TAB:_cycle_selection()
   KEY_SPACE:_toggle_pause()
   KEY_HOME,KEY_F:_center_selection()
   KEY_R:_confirm_restart()
   KEY_0,KEY_KP_0:_view_all()
   KEY_B:_center_ship()
   KEY_M:_toggle_minimap()
   KEY_P:_toggle_report()
   KEY_F1:_briefing_dialog()
   KEY_F2:_set_speed(1.0)
   KEY_F3:_set_speed(2.0)
   KEY_F4:_set_speed(4.0)
   KEY_G:_set_pace("gallop")
   KEY_T:_set_pace("trot")
   KEY_C:_set_pace("walk")
   KEY_ENTER,KEY_KP_ENTER:_confirm_key()
   KEY_F5:_save_game()
   KEY_F9:_load_game("justine")
   _:
    for action in ACTION_KEYS:
     if ACTION_KEYS[action]==k:
      var act=str(action)
      if act=="probe" and shift:act="probe_careful"
      if act=="recall" and _sel_scouts().is_empty():_toggle_info()
      else:_do_action(act)
      break
  return
 if event is InputEventMouseButton:
  var bi=event.button_index
  if not event.pressed:return
  if bi==MOUSE_BUTTON_WHEEL_UP:_zoom_at(event.position,true);return
  if bi==MOUSE_BUTTON_WHEEL_DOWN:_zoom_at(event.position,false);return
  if bi==MOUSE_BUTTON_LEFT:
   lmb_down=true;lmb_start=event.position;box_active=false
   if event.double_click:
    var uid=world.pick_unit(camera,event.position)
    if not uid.is_empty():lmb_down=false;_select_ids([uid]);_center_on(_actor_pos(uid),minf(camera_distance,60.0))
  elif bi==MOUSE_BUTTON_RIGHT:
   rmb_down=true;rmb_start=event.position;rmb_drag=false;grab_anchor=world.ground_xz_from_screen(camera,event.position)
  elif bi==MOUSE_BUTTON_MIDDLE:
   mmb_down=true;mmb_start=event.position;rmb_drag=false;grab_anchor=world.ground_xz_from_screen(camera,event.position)
  return
 if event is InputEventMouseMotion:
  hover_mouse=event.position
  if mmb_down and event.alt_pressed:
   camera_yaw-=event.relative.x*0.006
   camera_pitch=clampf(camera_pitch+event.relative.y*0.004*(-1.0 if settings.invert_orbit else 1.0),PITCH_MIN,PITCH_MAX)
   return
  if rmb_down or mmb_down:
   var start=rmb_start if rmb_down else mmb_start
   if not rmb_drag and event.position.distance_to(start)>6.0:rmb_drag=true
   if rmb_drag and grab_anchor!=null:
    var cur=world.ground_xz_from_screen(camera,event.position)
    if cur!=null:
     camera_target+=Vector3(grab_anchor.x-cur.x,0,grab_anchor.y-cur.y)
     camera_target=world.clamp_camera_target(camera_target);cam_goal_active=false
     _apply_camera()
   return
  if lmb_down:
   if not box_active and event.position.distance_to(lmb_start)>6.0 and aim=="":box_active=true
   if box_active:box_rect=Rect2(lmb_start,Vector2.ZERO).expand(event.position)

func _j_release(event):
 # Las soltadas llegan por _input para no quedar atascadas si ocurren sobre un panel.
 var bi=event.button_index
 if bi==MOUSE_BUTTON_LEFT:
  if not lmb_down:return
  lmb_down=false
  if box_active:
   box_active=false
   var ids=world.pick_units_in_rect(camera,box_rect)
   if ids.is_empty() and not (event.shift_pressed or event.ctrl_pressed):_select_ids([])
   else:_select_ids(ids,_mods_how(event.shift_pressed,event.ctrl_pressed))
   return
  _left_click(event.position,event.shift_pressed,event.ctrl_pressed)
 elif bi==MOUSE_BUTTON_RIGHT:
  if not rmb_down:return
  rmb_down=false
  var was_drag=rmb_drag;rmb_drag=false
  if was_drag:return
  var g=world.ground_xz_from_screen(camera,event.position)
  if g==null:return
  if aim!="":_aim_click(g,event.shift_pressed)
  else:_right_click_world(g,event.shift_pressed)
 elif bi==MOUSE_BUTTON_MIDDLE:
  mmb_down=false;rmb_drag=false

func _left_click(pos:Vector2,shift:bool,ctrl:bool):
 if aim!="":
  var g=world.ground_xz_from_screen(camera,pos)
  if g!=null:_aim_click(g,shift)
  return
 var id=world.pick_unit(camera,pos)
 if not id.is_empty():_select_ids([id],_mods_how(shift,ctrl));return
 var lm=world.pick_landmark(camera,pos)
 if not lm.is_empty():
  var info=world.get_landmark_info(lm)
  _toast("%s %s — %s" % [_tag_glyph(str(info.get("tag","diseno"))),str(info.get("name",lm)),str(info.get("source",""))],8)
  return
 if not shift and not ctrl:_select_ids([])

# ---------- Estado y paneles ----------
func _update_hud_j():
 var st=rules.state
 title_label.text="JUSTINA  ·  RETIRO"
 var left=maxf(0.0,float(st.deadline)-float(st.elapsed))
 phase_label.text="12 AGO 1806 · río %s" % _river_word()
 clock_label.text="Quedan "+_clock(left)+" min"
 clock_label.add_theme_color_override("font_color",RED if left<180.0 else GOLD)
 _update_fords()
 state_label.text=_state_text(left)
 var res=rules.resources()
 var ss=rules.ship_state()
 goal_label.text="[b]OBJETIVO[/b] Tomar el buque Justina antes de que suba el río. Si perdés, volvés a probar con lo que anotaste."
 info_label.text="[b]Captura del buque %d %%[/b] (al 100 ganás)
Moral de la dotación [b]%d %%[/b]" % [int(st.capture),int(ss.crew_morale)]
 moral_label.text="Moral de la dotación"
 capture_bar.value=float(st.capture);moral_bar.value=float(ss.crew_morale)
 tide_label.text=_tide_text()
 var adv="[color=#f4a58d]sin pedir[/color] (Pedir carga a Liniers · K)"
 if bool(res.advance_authorized):adv="[color=#a6e3b8]VIGENTE %s más[/color]" % _clock(float(res.advance_remaining_s))
 res_label.text="Munición [b]%d/%d[/b] · de reserva [b]%d[/b]
Avisos a Liniers [b]%d[/b] · Estacas [b]%d[/b] · Voluntarios [b]%d[/b]
Permiso de carga: %s
Buque: próxima descarga en [b]%d s[/b]" % [int(res.ammo),int(res.ammo_max),int(res.ammo_reserve),int(res.signals_left),int(res.balizas),int(res.volunteers_pool),adv,int(ceil(float(ss.next_volley_in)))]
 risk_label.text=_probe_risk_text()
 if is_instance_valid(river_ctl):river_ctl.queue_redraw()
 if is_instance_valid(time_ctl):time_ctl.queue_redraw()
 for id in ALL_ACTORS:
  var b:Button=roster_buttons.get(id)
  if not is_instance_valid(b):continue
  b.text=_card_text(id);b.tooltip_text=_card_tip(id)
  b.custom_minimum_size.y=70.0 if sel_ids.has(id) else 40.0
  b.add_theme_color_override("font_color",UNIT_COLORS[id]);b.add_theme_color_override("font_hover_color",UNIT_COLORS[id])
  if sel_ids.has(id):
   b.add_theme_stylebox_override("normal",_cm_style("rosel"+id,Color("29454c"),UNIT_COLORS[id],2,8,3))
  else:
   b.add_theme_stylebox_override("normal",_cm_style("cmnormal83",Color("1a3037"),Color("455753"),1,8,3))
  b.queue_redraw()
 left_foot.text="Munición [b]%d/%d[/b] (de reserva %d)" % [int(res.ammo),int(res.ammo_max),int(res.ammo_reserve)]
 if is_instance_valid(deploy_btn):deploy_btn.visible=float(st.elapsed)<0.5 and rules.state.orders.is_empty()
 _auto_start_check()
 for pid in pace_buttons:
  pace_buttons[pid].set_pressed_no_signal(pid==pace)
 sel_info.text=_selection_text()
 _update_mode_ui()
 _update_alerts()
 _update_action_states()
 _declutter_world_labels()
 # Primer paso del tutorial: se atenúa lo que no hace falta (panel de estado y minimapa) para que se vea una sola cosa que hacer.
 var tut_focus=bool(settings.tutorial) and tut_step==0 and str(st.status)=="playing" and float(st.elapsed)<1.0 and not is_instance_valid(modal) and int(progress.intentos)<=1
 for dim_c in [right_panel,map_widget,mm_bar]:
  if is_instance_valid(dim_c):dim_c.modulate.a=0.4 if tut_focus else 1.0
 var grouped=_grouped_log(1)
 if is_instance_valid(journal_last):
  journal_last.text="• "+(str(grouped[-1].text) if not grouped.is_empty() else "Sin novedades.")
 log_label.text=""
 _tut_update()
 tutorial_label.text=_tutorial_j() if bool(settings.tutorial) else ""
 last_hint_text=tutorial_label.text
 # Un solo mensaje a la vez: el aviso crítico manda; un cartel importante tapa la guía mientras dura.
 if is_instance_valid(hint_panel):hint_panel.visible=str(st.status)=="playing" and not tutorial_label.text.is_empty() and not (is_instance_valid(alert_panel) and alert_panel.visible) and not (toast_timer>0.0 and toast_prio>=2) and rules.state.get("pending_shot",{}).is_empty()

# La primera orden del intento arranca el reloj solo (tras «Empezar»): menos pasos antes de la acción.
func _auto_start_check():
 if not auto_start_pending or not paused or is_instance_valid(modal) or str(rules.state.status)!="playing":return
 var started=not rules.state.orders.is_empty()
 for sc in rules.scouts():
  if str(sc.stage) in ["probing","moving","marking"]:started=true
 if not started:return
 auto_start_pending=false;paused=false;pause_reason=""
 _toast("El reloj corre. Espacio lo pausa: con el tiempo detenido podés ordenar con calma.",5,true,1)

func _selection_text()->String:
 var groups=_sel_groups();var scouts=_sel_scouts()
 if groups.is_empty() and scouts.is_empty():
  return "Nada seleccionado. Clic en una ficha de la izquierda o en el mapa, arrastrá una caja, o teclas 1-5."
 var t=""
 if groups.size()==1 and scouts.is_empty():
  var u=rules.get_unit(groups[0])
  t="[b]%s[/b]   fuerza %d · cansancio %d · %s\nOrden: %s" % [str(u.name),int(u.strength),int(u.fatigue),str(STAGE_TEXT.get(str(u.stage),["",str(u.stage)])[1]),_order_text(groups[0])]
  var tag=str(u.get("tag","diseno"))
  if tag!="diseno":t+="   ·   [color=%s]%s %s[/color]" % [str(_tag_info(tag).get("color","#aab7b5")),_tag_glyph(tag),_tag_label(tag)]
 elif groups.size()>=1:
  var s=0.0
  for id in groups:s+=float(rules.get_unit(id).strength)
  t="[b]%d grupos[/b] seleccionados · fuerza media %d\nLa acción se aplica a los %d grupos seleccionados." % [groups.size(),int(s/groups.size()),groups.size()]
  if not scouts.is_empty():t+=" Los exploradores no reciben órdenes de grupo."
 else:
  var a=_actor(scouts[0])
  t="[b]%s[/b]   ♥ %d · %s\nOrden: %s" % [str(a.name),int(a.hp),str(STAGE_TEXT.get(str(a.stage),["",str(a.stage)])[1]),_order_text(scouts[0])]
  if scouts.size()>1:t+="  ·  la acción se aplica a los %d exploradores" % scouts.size()
 return t

func _anyone_boarding()->bool:
 for id in GROUP_IDS:
  if str(rules.get_unit(id).get("stage","")) in ["boarding","dismounting"]:return true
 return false

func _tutorial_j()->String:
 if tut_step>=TUT_STEPS.size():return ""
 # El último paso (abordaje) solo se muestra cuando hay un grupo abordando o un contraataque en curso.
 if tut_step==4 and not _anyone_boarding() and not (bool(rules.state.counter.active) and not bool(rules.state.counter.answered)):return ""
 return str(TUT_STEPS[tut_step])

# Estado de la partida: cuenta regresiva, ventanas de vado y riesgo actual (texto, junto a la barra de tiempo).
func _risk_now()->Dictionary:
 var ids=_sel_groups()
 if ids.is_empty():ids=GROUP_IDS
 var best=0.0
 for id in ids:
  var u=rules.get_unit(id)
  if u.is_empty() or float(u.strength)<=0.0:continue
  best=maxf(best,rules.exposure_for(u))
 var lvl="bajo" if best<0.15 else ("medio" if best<0.5 else "alto")
 return {"level":lvl,"exposure":best}

# Un solo reloj a la vista (el de arriba, «Quedan»): acá el vado se dice con palabras; las horas exactas viven en Detalles.
func _ford_line(f:Dictionary,t:float)->String:
 var w:Dictionary=f.win
 var nm=str(f.name).split(" (")[0]
 var est="" if bool(w.certain) else " [color=#e0bf81](hay que sondear)[/color]"
 var opens=float(w.opens_at);var closes=float(w.closes_at)
 var hh=func(x:float)->String:return (" · "+_clock(x)) if details_open else ""
 if opens<0.0:return "• %s: [color=#f4a58d]no abre con este nivel[/color]" % nm
 if t<opens:return "• %s: [color=#e0bf81]todavía cerrado[/color]%s%s" % [nm,hh.call(opens-t),est]
 if t<=closes:
  var rest=closes-t
  return "• %s: [color=%s][b]ABIERTO[/b][/color]%s%s" % [nm,"#f4a58d" if rest<60.0 else "#a6e3b8",hh.call(rest),est]
 return "• %s: [color=#f4a58d]cerrado[/color]" % nm

func _state_text(left:float)->String:
 var st=rules.state
 var t=float(st.elapsed)
 var lines=[]
 var status=str(st.status)
 if status!="playing":lines.append("[b]Partida terminada[/b]: "+("victoria" if status=="victory" else "derrota"))
 if ford_cache.is_empty():lines.append("Vado: todavía no medido. Mandá un explorador.")
 else:
  for f in ford_cache:lines.append(_ford_line(f,t))
 var cmod=rules.capture_modifier()
 if float(cmod.mult)<0.99:lines.append("[color=#f4a58d]Captura frenada[/color] (%d s)" % ceili(float(cmod.seconds_left)))
 elif float(cmod.mult)>1.01:lines.append("[color=#a6e3b8]Captura acelerada[/color] (%d s)" % ceili(float(cmod.seconds_left)))
 if int(st.stats.counter_hits)>0 and status=="playing":
  var mu=int(_jmap().ship.capture.counter.get("max_unanswered",3))
  lines.append("[color=#f4a58d]Contraataques sin contestar: %d de %d[/color]" % [int(st.stats.counter_hits),mu])
 var rk=_risk_now()
 var col={"bajo":"#a6e3b8","medio":"#e0bf81","alto":"#f4a58d"}[str(rk.level)]
 lines.append("Peligro de fuego: [b][color=%s]%s[/color][/b]" % [col,str(rk.level).to_upper()])
 return "
".join(lines)

func _update_fords():
 ford_cache=[]
 var m=_jmap()
 var found=rules.state.get("fords_found",[])
 for f in m.get("fords",[]):
  if bool(f.get("hidden",false)) and not found.has(str(f.id)):continue
  var c=Vector2.ZERO
  if f.has("center"):c=Vector2(float(f.center[0]),float(f.center[1]))
  else:c=(Vector2(float(f.centerline[0][0]),float(f.centerline[0][1]))+Vector2(float(f.centerline[1][0]),float(f.centerline[1][1])))*0.5
  ford_cache.append({"id":str(f.id),"name":str(f.name),"win":rules.ford_window(c.x,c.y,true)})

func _draw_river():
 var c=river_ctl
 if not is_instance_valid(c) or not _is_j():return
 var font=_font()
 var w=c.size.x-8.0
 var maxv=1.8
 var level=rules.water_level_m()
 var y0=14.0;var h=9.0
 c.draw_rect(Rect2(4,y0,w,h),Color("31433e"))
 c.draw_rect(Rect2(4,y0,w*clampf(level/maxv,0,1),h),Color("5e7f8c"))
 c.draw_rect(Rect2(4,y0,w,h),Color("65756c"),false,1.0)
 for tick_m in [0.0,0.5,1.0,1.5]:
  var x=4.0+w*tick_m/maxv
  c.draw_line(Vector2(x,y0+h),Vector2(x,y0+h+3),PAPER,1.0)
  c.draw_string(font,Vector2(x-7,y0+h+13),("%.1f" % tick_m).replace(".",","),HORIZONTAL_ALIGNMENT_LEFT,-1,10,MUTED)
 var xh=4.0+w*1.3/maxv;var xf=4.0+w*1.2/maxv
 c.draw_line(Vector2(xh,y0-3),Vector2(xh,y0+h),Color("f08c78"),2.0)
 c.draw_line(Vector2(xf,y0-3),Vector2(xf,y0+h),Color("e0bf81"),1.5)
 c.draw_string(font,Vector2(xh+3,y0-3),"caballo 1,3",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("f08c78"))
 c.draw_string(font,Vector2(xf-48,y0-3),"a pie 1,2",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("e0bf81"))
 c.draw_string(font,Vector2(4,10),"Río %s m" % ("%.2f" % level).replace(".",","),HORIZONTAL_ALIGNMENT_LEFT,-1,11,PAPER)

func _draw_timeline():
 var c=time_ctl
 if not is_instance_valid(c) or not _is_j():return
 var font=_font()
 var marks=rules.tide_marks()
 var w=c.size.x-8.0
 var dl=float(marks.deadline)
 var by=17.0;var bh=10.0
 var segs=[[0.0,float(marks.drop_start),Color("46606b")],[float(marks.drop_start),float(marks.drop_end),Color("3c7a8c")],[float(marks.drop_end),float(marks.low_hold_end),Color("2f5a52")],[float(marks.low_hold_end),float(marks.rise_end),Color("7a6a46")],[float(marks.rise_end),dl,Color("46606b")]]
 for s in segs:
  c.draw_rect(Rect2(4.0+w*float(s[0])/dl,by,w*(float(s[1])-float(s[0]))/dl,bh),s[2])
 c.draw_rect(Rect2(4,by,w,bh),Color("65756c"),false,1.0)
 # Ventanas de vados: sólidas si se conocen; punteadas con «?» si son una estimación.
 var row=0
 var legend=[]
 for f in ford_cache:
  var win:Dictionary=f.win
  var y=2.0+float(row)*7.0
  var opens=float(win.opens_at);var closes=float(win.closes_at)
  var short=str(f.name).split(" (")[0].replace("Vado ","").replace("de la ","").replace("junto al ","")
  if opens>=0.0:
   var x1=4.0+w*opens/dl;var x2=4.0+w*minf(closes,dl)/dl
   if bool(win.certain):
    c.draw_rect(Rect2(x1,y,x2-x1,5),Color("a6e3b8"))
   else:
    var x=x1
    while x<x2:
     c.draw_rect(Rect2(x,y,minf(4.0,x2-x),5),Color("e0bf81"));x+=7.0
    c.draw_string(font,Vector2(x2+2,y+6),"?",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("e0bf81"))
   legend.append(short+("" if bool(win.certain) else " ?"))
  else:legend.append(short+" (no abre)")
  row+=1
 var nr=float(rules.state.get("no_return_s",-1.0))
 if nr>0.0 and nr<dl:
  var rx=4.0+w*nr/dl
  c.draw_line(Vector2(rx,by-4),Vector2(rx,by+bh+4),Color("f4705c"),2.0)
  c.draw_string(font,Vector2(minf(rx-30,w-96),by+bh+24),"sin retorno "+_clock(nr),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("f4a58d"))
 var nx=4.0+w*clampf(float(rules.state.elapsed)/dl,0,1)
 c.draw_line(Vector2(nx,by-3),Vector2(nx,by+bh+3),Color.WHITE,2.0)
 for tm in [0,5,10,15]:
  c.draw_string(font,Vector2(minf(4.0+w*float(tm*60)/dl-8,w-26),by+bh+12),"%d min" % tm if tm>0 else "0",HORIZONTAL_ALIGNMENT_LEFT,-1,10,MUTED)

func _toggle_report():
 if is_instance_valid(modal):_close_modal()
 else:_report_dialog(false)

# ---------- Dibujo sobre la vista 3D ----------
func _risk_color(risk:String)->Color:
 return RISK_COLORS.get(risk,Color("aab7b5"))

func _world_pts(pts:Array,start:Variant=null)->PackedVector2Array:
 var out=PackedVector2Array()
 if start!=null:
  var s=_project(start)
  if s!=null:out.append(s)
 for q in pts:
  var x=float(q.x) if q is Vector2 else float(q.get("x",0))
  var z=float(q.y) if q is Vector2 else float(q.get("z",0))
  var pr=_project(Vector3(x,_ground_y(x,z)+0.4,z))
  if pr==null:break
  out.append(pr)
 return out

func _draw_overlay_j(font,blocked:Array,placed:Array):
 if world.show_paths:
  for id in ALL_ACTORS:
   var a=_actor(id)
   if a.is_empty() or a.get("path",[]).is_empty() or not world.unit_nodes.has(id):continue
   if not (id in SCOUT_IDS) and float(a.strength)<=0.0:continue
   var pts=_world_pts(a.path,world.unit_nodes[id].root.global_position+Vector3(0,0.4,0))
   if pts.size()<2:continue
   var col:Color=UNIT_COLORS[id]
   if _is_selected(id):
    overlay.draw_polyline(pts,Color(0.03,0.06,0.07,0.75),5.0,true);overlay.draw_polyline(pts,col,2.5,true)
   else:
    for i in range(pts.size()-1):overlay.draw_dashed_line(pts[i],pts[i+1],Color(col.r,col.g,col.b,0.55),2.0,9.0)
   overlay.draw_circle(pts[pts.size()-1],6.0,Color(0.03,0.06,0.07,0.85));overlay.draw_circle(pts[pts.size()-1],4.0,col)
   _route_label(font,id,pts,blocked,placed,_is_selected(id))
 if not hover_info.is_empty():
  var rc=_risk_color(str(hover_info.get("risk","bajo")))
  if str(hover_info.kind)=="route" and hover_info.has("plan"):
   var pl:Dictionary=hover_info.plan
   var g0=_sel_groups()
   if not g0.is_empty() and world.unit_nodes.has(g0[0]):
    var pts2=_world_pts(pl.get("path",[]),world.unit_nodes[g0[0]].root.global_position+Vector3(0,0.4,0))
    if pts2.size()>=2:
     overlay.draw_polyline(pts2,Color(0.03,0.06,0.07,0.7),5.0,true)
     for i in range(pts2.size()-1):overlay.draw_dashed_line(pts2[i],pts2[i+1],rc,3.0,10.0)
  elif str(hover_info.kind)=="scout" and not _sel_scouts().is_empty() and world.unit_nodes.has(_sel_scouts()[0]):
   var st3=world.unit_nodes[_sel_scouts()[0]].root.global_position+Vector3(0,0.4,0) if aim in ["probe","probe_careful"] else null
   var pts3=_world_pts(hover_info.pts,st3)
   for i in range(pts3.size()-1):overlay.draw_dashed_line(pts3[i],pts3[i+1],Color("6fb8a6"),3.0,8.0)
  var tp=_project(hover_info.point+Vector3(0,0.3,0))
  if tp!=null:overlay.draw_arc(tp,9.0,0,TAU,20,rc,2.5)
 var marks=wp_list.duplicate();marks.append_array(aim_pts)
 for i in range(marks.size()):
  var q=marks[i] as Vector2
  var pm=_project(Vector3(q.x,_ground_y(q.x,q.y)+0.5,q.y))
  if pm!=null:
   overlay.draw_circle(pm,8.0,Color(0.03,0.06,0.07,0.9));overlay.draw_circle(pm,6.0,Color("e9e3d4"))
   overlay.draw_string(font,pm+Vector2(-3,4),str(i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color(0.03,0.06,0.07))
 _draw_diary_marks(font)
 _draw_marks_j()
 _draw_chips_j(font,placed,blocked)
 _draw_landmarks_j(font,blocked,placed)

func _draw_marks_j():
 var gdisp=_group_disp()
 for id in ALL_ACTORS:
  var a=_actor(id)
  if a.is_empty() or not world.unit_nodes.has(id):continue
  var pr=_project(world.unit_nodes[id].root.global_position+Vector3(0,1.0,0))
  if pr==null:continue
  var c:Color=UNIT_COLORS[id]
  if _is_selected(id):
   overlay.draw_arc(pr,17.0,0,TAU,28,Color(0.03,0.06,0.07,0.7),5.0)
   overlay.draw_arc(pr,17.0,0,TAU,28,c,3.0)
   if select_flash>0:
    var t=select_flash/0.5
    overlay.draw_arc(pr,17.0+(1.0-t)*26.0,0,TAU,28,Color(1,1,1,t*0.9),3.0)
  else:
   overlay.draw_arc(pr,10.0,0,TAU,20,Color(c.r,c.g,c.b,0.55),1.5)
  if not (id in SCOUT_IDS) and float(a.strength)>0.0 and gdisp.has(id):
   var gp:Vector2=gdisp[id].disp
   if gp.distance_to(gdisp[id].real)>6.0:overlay.draw_line(gdisp[id].real,gp,Color(c.r,c.g,c.b,0.8),2.0,true)
   _draw_silhouette(gp+Vector2(0,6),id,c)
   if _is_selected(id):overlay.draw_arc(gp,_sil_k()*0.8,0,TAU,28,c,3.0)

# Silueta de jinete o infante con tamaño mínimo en pantalla: la tropa se lee como tropa aunque el zoom esté lejos.
# Posición en pantalla de cada grupo para dibujar su silueta: si dos quedan casi encimados se abren en abanico hacia la tierra, así se cuentan de un vistazo.
func _group_disp()->Dictionary:
 var out={}
 var k=_sil_k()
 var placed=[]
 for id in GROUP_IDS:
  var a=_actor(id)
  if a.is_empty() or float(a.strength)<=0.0 or not world.unit_nodes.has(id):continue
  var pr=_project(world.unit_nodes[id].root.global_position+Vector3(0,1.0,0))
  if pr==null:continue
  var q:Vector2=pr
  var tries=0
  while tries<4:
   var hit=false
   for o in placed:
    if absf(q.x-o.x)<k*1.1 and absf(q.y-o.y)<k*1.7:hit=true
   if not hit:break
   q+=Vector2(-k*1.15,0.0);tries+=1
  placed.append(q)
  out[id]={"real":pr,"disp":q}
 return out

func _sil_k()->float:
 return clampf(3400.0/maxf(camera_distance,20.0),30.0,54.0)

# Piezas convexas (cuerpo elíptico, cuello, cabeza, torso) más patas como líneas: sin polígonos cóncavos que fallen al triangular.
func _ellipse_pts(at:Vector2,rx:float,ry:float,n:int=14)->PackedVector2Array:
 var out=PackedVector2Array()
 for i in range(n):
  var a=TAU*float(i)/float(n)
  out.append(at+Vector2(cos(a)*rx,sin(a)*ry))
 return out

func _quad(at:Vector2,k:float,pts:Array,grow:float=1.0)->PackedVector2Array:
 var out=PackedVector2Array()
 for q in pts:out.append(at+Vector2(float(q[0]),float(q[1]))*k*grow)
 return out

# Dibuja un polígono solo si es válido (área > 0 y coordenadas finitas): evita errores de triangulación del motor.
func _safe_poly(pts:PackedVector2Array,col:Color):
 var area=0.0
 for i in range(pts.size()):
  var q=pts[i];var r=pts[(i+1)%pts.size()]
  if not (is_finite(q.x) and is_finite(q.y)):return
  area+=q.x*r.y-r.x*q.y
 if absf(area)<2.0:return
 overlay.draw_colored_polygon(pts,col)

func _draw_silhouette(at:Vector2,id:String,c:Color):
 var vs=get_viewport().get_visible_rect().size
 if at.x<-150.0 or at.y<-150.0 or at.x>vs.x+150.0 or at.y>vs.y+150.0:return  # fuera de cuadro: no se dibuja (evita coordenadas enormes)
 var k=_sil_k()
 var dark=Color(0.03,0.05,0.06,0.92)
 var body=Color(c.r*0.78,c.g*0.78,c.b*0.78,1.0)
 var lance_a:Vector2;var lance_b:Vector2
 for pass_i in [0,1]:
  var d=pass_i==0
  var col_b=dark if d else body
  var col_r=dark if d else c.lightened(0.1)
  var g=1.28 if d else 1.0
  var lw=5.0 if d else 3.0
  if id=="arias":
   _safe_poly(_quad(at,k,[[-0.2,-0.62],[0.2,-0.62],[0.17,0.0],[-0.17,0.0]],g),col_r)
   overlay.draw_line(at+Vector2(-0.08,0.0)*k,at+Vector2(-0.12,0.5)*k,col_b,lw*1.2)
   overlay.draw_line(at+Vector2(0.08,0.0)*k,at+Vector2(0.12,0.5)*k,col_b,lw*1.2)
   overlay.draw_circle(at+Vector2(0.0,-0.8)*k,k*0.17*g,dark if d else c.lightened(0.3))
   lance_a=at+Vector2(0.22,0.25)*k;lance_b=at+Vector2(0.4,-1.0)*k
  else:
   _safe_poly(_ellipse_pts(at+Vector2(0,0.0)*k,k*0.52*g,k*0.24*g),col_b)
   _safe_poly(_quad(at,k,[[0.3,-0.12],[0.5,-0.5],[0.66,-0.42],[0.5,0.0]],g),col_b)
   for lx in [-0.38,-0.2,0.2,0.38]:
    overlay.draw_line(at+Vector2(lx,0.1)*k,at+Vector2(lx+0.02,0.5)*k,col_b,lw)
   _safe_poly(_quad(at,k,[[-0.1,-0.1],[0.14,-0.1],[0.12,-0.62],[-0.08,-0.62]],g),col_r)
   overlay.draw_circle(at+Vector2(0.02,-0.78)*k,k*0.16*g,dark if d else c.lightened(0.3))
   lance_a=at+Vector2(0.16,-0.3)*k;lance_b=at+Vector2(0.62,-1.2)*k
  overlay.draw_line(lance_a,lance_b,dark if d else Color("d8d2c0"),lw*0.8)
 # Banderín del bando sobre la lanza.
 _safe_poly(PackedVector2Array([lance_b,lance_b+Vector2(k*0.4,k*0.1),lance_b+Vector2(0,k*0.24)]),c)

func _draw_chips_j(font,placed:Array,blocked:Array=[]):
 var gd=_group_disp()
 var view=get_viewport().get_visible_rect().size
 var order=[]
 var items=[]
 for id in ALL_ACTORS:
  if _is_selected(id):order.push_front(id)
  else:order.push_back(id)
 for id in order:
  var u=_actor(id)
  if u.is_empty() or not world.unit_nodes.has(id):continue
  var is_scout=id in SCOUT_IDS
  if not is_scout and float(u.strength)<=0.0:continue
  var anchor=_project(world.unit_nodes[id].root.global_position+Vector3(0,4.0,0))
  # La ficha va sobre la silueta (alto = silueta + banderín), nunca encima de la tropa.
  if anchor!=null and is_scout:anchor+=Vector2(54,-6)  # los exploradores rotulan hacia el agua, lejos de la tropa
  if anchor!=null and not is_scout and gd.has(id):anchor=Vector2(gd[id].disp)+Vector2(0,-_sil_k()*1.55)
  if anchor==null or not Rect2(Vector2(10,10),view-Vector2(20,20)).has_point(anchor):continue
  var is_sel=_is_selected(id)
  var c:Color=UNIT_COLORS[id]
  var chip=(Vector2(104,22) if is_sel else Vector2(56,20)) if is_scout else (Vector2(224,54) if is_sel else Vector2(66,20))
  var rect=Rect2(anchor-Vector2(chip.x*0.5,chip.y+6),chip)
  rect.position.x=clampf(rect.position.x,4.0,view.x-chip.x-4.0)
  var base_y=rect.position.y
  var tries=0
  # Desplazamientos verticales alternados (arriba, abajo, más arriba...) hasta no pisar nada ya colocado.
  for k in range(0,14):
   var step=(k+1)/2
   var off=-float(step) if k%2==1 else float(step)
   rect.position.y=clampf(base_y+off*(chip.y+4.0),60.0,view.y-chip.y-4.0)
   tries=k
   if not _overlaps_any(rect.grow(2),placed) and not _overlaps_any(rect,blocked):break
  placed.append(rect)
  items.append({"id":id,"rect":rect,"anchor":anchor,"line":rect.end.y<anchor.y-8.0 or tries>0})
 # Primero todas las líneas de unión y después las fichas: ninguna línea cruza el texto de otra ficha.
 for it in items:
  var lc:Color=UNIT_COLORS[it.id];var lr:Rect2=it.rect
  if bool(it.line):overlay.draw_line(Vector2(lr.position.x+lr.size.x*0.5,lr.end.y),it.anchor,Color(lc.r,lc.g,lc.b,0.7),1.5,true)
 for it in items:
  var id=it.id;var rect:Rect2=it.rect
  var u=_actor(id);var is_scout=id in SCOUT_IDS;var is_sel=_is_selected(id);var c:Color=UNIT_COLORS[id]
  var chip=rect.size
  overlay.draw_style_box(_cached_style("chipj"+str(is_sel)+c.to_html(),Color(0.035,0.075,0.09,0.9),c if is_sel else Color(c.r,c.g,c.b,0.6),3 if is_sel else 1,5),rect)
  if is_scout:
   if is_sel:overlay.draw_string(font,rect.position+Vector2(6,15),"◈ %d  ♥%d  %s" % [_actor_number(id),int(u.hp),str(STAGE_TEXT.get(str(u.stage),["",""])[1])],HORIZONTAL_ALIGNMENT_LEFT,chip.x-8,11,c)
   else:overlay.draw_string(font,rect.position+Vector2(6,15),"◈%d ♥%d" % [_actor_number(id),int(u.hp)],HORIZONTAL_ALIGNMENT_LEFT,chip.x-8,12,c)
   continue
  var strength=float(u.strength)
  var bar_color=GREEN if strength>=60 else (GOLD if strength>=35 else RED)
  var title=_ujg(id)+" "+str(_actor_number(id))+" "+("Güemes (trad.)" if id=="guemes" else _short_name(id))
  var tg_mark=_tag_glyph(str(u.get("tag","diseno")))
  if id!="guemes":title+=" "+tg_mark
  if is_sel:
   overlay.draw_string(font,rect.position+Vector2(8,17),title,HORIZONTAL_ALIGNMENT_LEFT,chip.x-70,13,c)
   overlay.draw_string(font,rect.position+Vector2(chip.x-60,17),"%d %%" % int(strength),HORIZONTAL_ALIGNMENT_RIGHT,52,13,Color("f4efe0"))
   overlay.draw_rect(Rect2(rect.position+Vector2(8,23),Vector2(chip.x-16,6)),Color("31433e"))
   overlay.draw_rect(Rect2(rect.position+Vector2(8,23),Vector2((chip.x-16)*clampf(strength/100.0,0,1),6)),bar_color)
   overlay.draw_rect(Rect2(rect.position+Vector2(8,30),Vector2((chip.x-16)*clampf(float(u.fatigue)/100.0,0,1),2)),Color("c9b6a0"))
   overlay.draw_string(font,rect.position+Vector2(8,46),_stage_badge(str(u.stage)),HORIZONTAL_ALIGNMENT_LEFT,chip.x-14,11,Color("e9e3d4"))
  else:
   overlay.draw_string(font,rect.position+Vector2(5,14),str(_actor_number(id))+" %d%%" % int(strength),HORIZONTAL_ALIGNMENT_LEFT,chip.x-8,12,c)
   overlay.draw_rect(Rect2(rect.position+Vector2(5,16),Vector2(chip.x-10,3)),Color("31433e"))
   overlay.draw_rect(Rect2(rect.position+Vector2(5,16),Vector2((chip.x-10)*clampf(strength/100.0,0,1),3)),bar_color)

# El rótulo del mapa dice el nombre del lugar; las etiquetas de fuente ((diseño), (ubicación hipotética)...) van en la ayuda.
func _clean_label(t:String)->String:
 for tail in [" (ubicación hipotética)"," (diseño)"," (tradición)"," (trad.)"," (hipotética)"]:t=t.replace(tail,"")
 return t

func _draw_landmarks_j(font,blocked:Array,placed:Array):
 var view=get_viewport().get_visible_rect().size
 var zoomed_in=camera_distance<=62.0
 for item in world.landmark_labels(camera):
  if bool(item.get("behind",false)):continue
  var tag=str(item.get("tag","diseno"))
  var nm=_clean_label(str(item.name))
  var is_ship=str(item.get("id",""))=="justina" or nm.begins_with("Buque")
  # Los lugares menores aparecen al acercar la cámara; el buque, siempre.
  var minor=not is_ship and not (nm.begins_with("Pozo") or nm.begins_with("Fuerte") or nm.begins_with("Vado"))
  if minor and not zoomed_in:continue
  var text_value=_tag_glyph(tag)+" "+nm
  var text_size=font.get_string_size(text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,13)
  var p:Vector2=item.screen
  if is_ship:p+=Vector2(text_size.x*0.5+78.0,-70.0)  # a un costado del casco, nunca encima
  var rect=Rect2(p-Vector2(text_size.x*0.5+6,text_size.y*0.5+3),text_size+Vector2(12,6))
  if not Rect2(Vector2.ZERO,view).encloses(rect):continue
  if _overlaps_any(rect,blocked) or _overlaps_any(rect,placed):continue
  placed.append(rect)
  overlay.draw_style_box(_cached_style("lab2",Color(0.03,0.06,0.08,0.9),Color(0.62,0.58,0.4,0.85),1,4),rect)
  overlay.draw_string(font,rect.position+Vector2(6,text_size.y*0.5+rect.size.y*0.5-4),text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,13,_tag_color(tag).lightened(0.25))

func _draw_top_j():
 if mode!="play" or not is_instance_valid(world):return
 _draw_pause_frame();_draw_volley_warning();_draw_guides()
 if box_active:
  overlay_top.draw_rect(box_rect,Color(1,1,1,0.10))
  overlay_top.draw_rect(box_rect,Color(1,1,1,0.9),false,1.5)
 if hover_info.is_empty():return
 var rc=_risk_color(str(hover_info.get("risk","bajo")))
 var prefix="" if str(hover_info.kind)=="scout" else ("✓ " if bool(hover_info.ok) else "✕ ")
 _tip_box(_font(),prefix+str(hover_info.text),hover_mouse+Vector2(18,22),rc,get_viewport().get_visible_rect().size)

# ---------- Eventos ----------
const KIND_PRIO = {"shot_warning":3,"counter_warning":3,"last_effort":3,"choice":2,"choice_done":1,"reinforce":2,"assist":2,"mission":1,"liniers":2,"hint":2,"warning":3,"stumble":3,"counter":3,"victory":3,"defeat":3,"boarding":2,"ford":2,"signal":2,"tide":2,"recon":1,"muster":1,"ammo":1,"fire_support":1,"blocked":1}
func _handle_events_j(events:Array):
 var best=null;var best_prio=-1
 for event in events:
  var kind=str(event.get("kind","info"))
  match kind:
   "shot":world.cannon_effect();_sound("cannon");_juice("shot")
   "victory":_sound("victory")
   "defeat":_sound("defeat")
   "warning":
    _sound("alert")
    if str(event.get("text","")).find("se dispersa")>=0:_flash(Color(0.85,0.2,0.15),0.22);shake=maxf(shake,0.5)
   "stumble":_juice("stumble")
   "shot_warning":_sound("volley_warn");_flash(Color(0.95,0.5,0.25),0.08)
   "counter_warning":_sound("alert");_flash(Color(0.9,0.25,0.2),0.1)
   "choice":
    _sound("messenger")
    if not is_instance_valid(modal) and mode=="play":choice_text=str(event.get("text",""));call_deferred("_choice_dialog")
   "counter":_juice("counter")
   "ford":_juice("ford")
   "boarding":_sound("dismount")
   "signal":_sound("order")
  # Los avisos de campo no dejan seguir a ×2/×4: se vuelve a ×1 para poder reaccionar (C19).
  if event.has("field_event") and speed>1.0:
   speed=1.0
  if kind in ["shot","info","load","objective"]:continue
  var pr=int(KIND_PRIO.get(kind,1))
  if pr>=best_prio:best_prio=pr;best=event
  # Pausa en los hitos que piden una decisión: tropiezo en un pozo y grupo disperso.
  if bool(settings.auto_pause) and not paused and not is_instance_valid(modal) and mode=="play":
   var tx=str(event.get("text",""))
   if kind=="stumble" or (kind=="warning" and tx.find("se dispersa")>=0):
    paused=true;pause_reason=_short_msg(tx)
    # La cámara se desliza hasta el hecho para ver qué pasó antes de decidir (no se mueve sola en el resto de los avisos).
    if event.get("pos",null) is Dictionary:
     var ep=Vector2(float(event.pos.x),float(event.pos.z))
     _focus_to(Vector3(ep.x,0.0,ep.y),minf(camera_distance,64.0))
 if best==null:return
 var kind2=str(best.get("kind","info"))
 var pos=null
 if best.get("pos",null) is Dictionary:pos=Vector2(float(best.pos.x),float(best.pos.z))
 var text=str(KIND_ICON.get(kind2,"•"))+" "+_short_msg(str(best.text))
 if best.has("tag"):text=_tag_glyph(str(best.tag))+" "+text
 _toast(text,6,true,best_prio)
 if is_instance_valid(toast_label):toast_label.modulate=KIND_COLOR.get(kind2,Color.WHITE)
 toast_pos=pos  # el botón «ver» del cartel lleva la cámara al hecho; no se mueve sola para no pisar la orden del jugador

func _choice_dialog():
 var pc=rules.state.get("pending_choice",{})
 if pc.is_empty() or is_instance_valid(modal) or str(rules.state.status)!="playing":return
 var ttl=str(pc.get("title","")).strip_edges()
 var box=_open_modal(ttl if not ttl.is_empty() else "Un mensajero",760,_scroll_h(330.0,40.0))
 var tx=choice_text
 var cut=tx.find(" (Se toma")
 if cut>0:tx=tx.substr(0,cut)
 _rich(box,"[font_size=20]%s[/font_size]" % _plain(tx),20).custom_minimum_size.x=700
 _rich(box,"[color=#aab7b5]El reloj está detenido mientras elegís.[/color]",14).custom_minimum_size.x=700
 for o in pc.options:
  var oid=str(o.id)
  var b=_button(box,str(o.label),func():_choice_pick(oid),50);b.add_theme_font_size_override("font_size",18)

func _choice_pick(oid:String):
 var r=rules.resolve_choice(oid)
 _close_modal()
 _toast(str(r.get("reason","")) if bool(r.get("ok",false)) else "No se pudo elegir.",4,bool(r.get("ok",false)),2)
 _sound("order");_update_hud()

func _toast_view_click():
 if toast_pos!=null:_center_on(toast_pos as Vector2,minf(camera_distance,80.0))

# ---------- Diálogos ----------
# Las notas de producción («decisión pendiente tuya/del usuario») no son texto del jugador: se quitan de lo que se muestra.
func _player_text(t:String)->String:
 var rx=RegEx.new();rx.compile("[;,]?[ ]*[^.;]*decisi[oó]n pendiente[^.]*[.]")
 return rx.sub(t,".",true)

func _briefing_dialog():
 var m=_jmap()
 var box=_open_modal(str(m.get("texts",{}).get("title","Justina")),940,680)
 var scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.custom_minimum_size=Vector2(880,500);box.add_child(scroll)
 var content=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",10);scroll.add_child(content)
 var text="[font_size=20][b]TIEMPO REAL con pausa[/b][/font_size]
El reloj corre solo (×1, ×2, ×4); no es por turnos. [b]Espacio[/b] pausa, y [b]con el tiempo detenido podés dar órdenes[/b]: es la forma recomendada de jugar. El juego se pausa solo ante avisos críticos («Pausa auto»).

"
 text+="[font_size=20][b]Qué hacer, en 4 pasos[/b][/font_size]
"
 text+="[font_size=18][color=#f0d27a][b]1.[/b][/color] Mirá a la izquierda tus [b]5 agrupaciones[/b] (teclas [color=#f0d27a][b]1-5[/b][/color]).
[color=#f0d27a][b]2.[/b][/color] Elegí un explorador ([color=#f0d27a][b]4[/b][/color] o [color=#f0d27a][b]5[/b][/color]) y [color=#f0d27a][b]Z[/b][/color] «Reconocer fondo», y clic en el agua.
[color=#f0d27a][b]3.[/b][/color] Elegí un grupo ([color=#f0d27a][b]1-3[/b][/color]) y [color=#f0d27a][b]K[/b][/color] «Señalar a Liniers» (hay solo dos señales).
[color=#f0d27a][b]4.[/b][/color] [color=#f0d27a][b]Clic derecho[/b][/color] traza la ruta (muestra riesgo y tiempo) o [color=#f0d27a][b]N[/b][/color] «Cargar y abordar». [color=#f0d27a][b]Ctrl+Z[/b][/color] deshace.[/font_size]

El panel de abajo te dice siempre el SIGUIENTE paso. Perdido: [b]F1[/b] o [b]?[/b] abre esta ayuda; [b]0[/b] muestra todo el mapa; [b]B[/b] va al buque.
"
 var text_g="[b]Palabras del juego[/b]
• [b]Baliza[/b]: estaca que marcás en un vado reconocido para no sondearlo de nuevo.
• [b]Pólvora de reserva[/b]: munición extra que se reparte con «Abastecer munición»; los grupos no la usan solos.
• [b]Quedan 18:00 min[/b]: minutos y segundos hasta el plazo, no una hora del día.
• [b]Retirar (L)[/b]: manda de vuelta a la playa a los grupos elegidos. [b]Retirada general[/b]: termina la partida (pide confirmación).

"
 var text_f="[b]Una advertencia sobre la fuente[/b]
Gillespie escribe que el buque quedó «en seco» (left dry) y que lo abordó la caballería. Este juego elige, por jugabilidad, un casco apoyado con agua alrededor, vados de poca profundidad y un río que baja y sube: es [color=#e8a98f]▲ diseño[/color], no testimonio. Gillespie también dice que ningún buque fondea con seguridad a menos de cuatro millas; los 390 m del juego son una distancia de diseño en tensión con eso. Que Güemes estuviera en la acción es [color=#e0bf81]tradición[/color] (por eso «Güemes (trad.)»).

"
 var jtx=m.get("texts",{})
 text_f+=_player_text(str(rules.state.get("briefing",jtx.get("briefing",""))))+"\n\n"
 if str(jtx.get("briefing_long",""))!="":text_f+="[b]En detalle[/b]\n"+_player_text(str(jtx.briefing_long))+"\n\n"
 if str(jtx.get("tradition_context",""))!="":text_f+="[b]Sobre Güemes[/b]\n"+_player_text(str(jtx.tradition_context))+"\n\n"
 if str(jtx.get("sources_detail",""))!="":text_f+="[b]Qué se tomó de dónde[/b]\n"+_player_text(str(jtx.sources_detail))+"\n\n"
 var md_items:Array=jtx.get("map_decisions",{}).get("items",[])
 if not md_items.is_empty():
  text_f+="[b]Decisiones del mapa[/b]
"
  for it in md_items:
   var ti=str(it.get("tag","diseno"))
   text_f+="• [b]%s[/b] (%s): %s
" % [_player_text(str(it.get("title",""))),str(m.get("source_tags",{}).get(ti,{}).get("label",ti)),_player_text(str(it.get("text","")))]
  text_f+="
"
 for k in ["historical_note","result_contrast"]:
  if str(jtx.get(k,""))!="":text_f+=_player_text(str(jtx[k]))+"

"
 text_f+="[b]Cómo leer las etiquetas[/b]\n"
 for t in ["documentado","tradicion","reconstruccion","diseno"]:
  var info=m.get("source_tags",{}).get(t,{})
  text_f+="[color=%s]%s %s[/color] — %s\n" % [str(info.get("color","#fff")),str(info.get("glyph","")),str(info.get("label","")),str(info.get("meaning",""))]
 text_g+="\n[b]Consejos[/b]\n"
 var tips=m.get("texts",{}).get("tips",[])
 for i in range(mini(3,tips.size())):text_g+="• "+str(tips[i])+"\n"
 var text_k="\n[b]Controles[/b]\n• Cámara: WASD/flechas y borde de pantalla mueven · rueda zoom · botón derecho arrastrado agarra el mapa · Q/E giran · RePág/AvPág inclinan · el minimapa (clic o arrastre) mueve la vista; el cuadro blanco es lo que ves.\n• Cámara rápida: F centra la selección · B va al buque · 0 muestra todo el mapa · M agranda el minimapa.\n• Selección: clic en una ficha o en el mapa · 1-5 · Tab cicla · caja con arrastre izquierdo · Mayús suma · Ctrl alterna.\n• Órdenes: clic derecho mueve · V Mover · N Cargar y abordar · K Señalar a Liniers · Z Reconocer (Mayús+Z cauteloso) · H Marcar vado · I Volver · O Distraer con fuego · [b]coma[/b] Rechazar contraataque · [b]punto[/b] Evacuar heridos · X cancelar · [b]Ctrl+Z deshacer[/b] la última orden · G/T/C ritmo.\n• Tiempo: Espacio pausa/reanuda · F2/F3/F4 o +/− velocidad ×1/×2/×4 · P parte · F5 guardar · F9 cargar · R reiniciar · F1 o ? esta ayuda."
 scroll.queue_free()
 var tabs=TabContainer.new();tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL;tabs.custom_minimum_size=Vector2(880,_scroll_h(500.0));box.add_child(tabs);box.move_child(tabs,1)
 for pair in [["Cómo jugar",text],["Teclas",text_k],["Palabras y consejos",text_g],["Fuentes",text_f]]:
  var sc=ScrollContainer.new();sc.name=str(pair[0]);sc.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tabs.add_child(sc)
  var rt=_rich(sc,str(pair[1]),15);rt.custom_minimum_size.x=840
 var row=_hbox(box)
 var fresh=float(rules.state.elapsed)<0.5 and str(rules.state.status)=="playing"
 var go=_button(row,"Jugar (empieza en pausa)" if fresh else "Volver a la partida",_close_modal,42);go.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 if fresh:_button(row,"Ver el despliegue",_deploy_dialog,42)
 _button(row,"Repetir tutorial",func():settings.tutorial=true;tut_step=0;_save_settings();_close_modal();_update_hud(),42)
 _button(row,"Fuentes e historia",_history_dialog,42)

# ---------- Rutas con destino y ETA, minimapa ----------

func _load_rejected_dialog(reason:String):
 var box=_open_modal("No se pudo continuar",720,320)
 _rich(box,reason,17)
 var row=_hbox(box)
 _button(row,"Nueva partida",func():_close_modal();_start_game("justine"),42)
 _button(row,"Cerrar",_close_modal,42)

func _report_dialog(final:bool=false):
 var r=rules.campaign_report()
 last_report=r
 var box=_open_modal(str(r.get("outcome_title","Parte de campaña")) if final else "Parte de campaña (parcial)",940,700)
 var scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.custom_minimum_size=Vector2(880,_scroll_h(500.0));box.add_child(scroll)
 var content=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",8);scroll.add_child(content)
 var head=str(r.get("reason",""))
 _rich(content,"[b]%s[/b]\nTiempo: %s%s" % [head,_clock(float(r.get("elapsed",0))),"" if final else "   ·   la partida sigue en curso"],17).custom_minimum_size.x=860
 var grid=GridContainer.new();grid.columns=5;grid.add_theme_constant_override("h_separation",18);content.add_child(grid)
 for h in ["Grupo","Fuente","Fuerza inicial","Fuerza final","Bajas"]:_label(grid,h,12,GOLD)
 for g in r.get("groups",[]):
  _label(grid,str(g.name),14,PAPER)
  var tg=str(g.get("tag","diseno"))
  _label(grid,_tag_glyph(tg)+" "+_tag_label(tg),14,_tag_color(tg))
  _label(grid,"%d" % int(g.start_strength),14);_label(grid,"%d" % int(g.end_strength),14);_label(grid,"%d %%" % int(g.loss_pct),14)
 var route_text="[b]Ruta:[/b] %s" % str(r.get("route","ninguna"))
 for n in r.get("route_notes",[]):route_text+="\n• "+str(n)
 _rich(content,route_text,15).custom_minimum_size.x=860
 var ex=r.get("exposure_s",{})
 var stats="[b]Sondeo[/b] %d m · [b]marcado[/b] %d m · [b]tropiezos[/b] %d · [b]munición[/b] %d · [b]balizas[/b] %d · [b]apoyos de fuego[/b] %d · [b]exploradores perdidos[/b] %d\n[b]Descargas recibidas[/b] %d (daño %d) · [b]exposición[/b] banco central %d s, sur %d s, otra %d s" % [int(r.get("probe_m",0)),int(r.get("marked_m",0)),int(r.get("stumbles",0)),int(r.get("ammo_used",0)),int(r.get("balizas_used",0)),int(r.get("fire_support_uses",0)),int(r.get("scouts_lost",0)),int(r.get("shots_taken",0)),int(r.get("damage_taken",0)),int(ex.get("central",0)),int(ex.get("sur",0)),int(ex.get("otra",0))]
 if float(r.get("boarded_at",-1))>=0.0:stats+="\n[b]Abordaje[/b] a los %s con el río a %s m" % [_clock(float(r.boarded_at)),("%.2f" % float(r.level_at_boarding)).replace(".",",")]
 _rich(content,stats,14).custom_minimum_size.x=860
 var hist="[b]Qué fue historia[/b]\n"
 for hline in r.get("history",[]):
  var ht=str(hline.get("tag","diseno"))
  hist+="[color=%s]%s %s[/color]  %s\n" % [str(_tag_info(ht).get("color","#aab7b5")),_tag_glyph(ht),_tag_label(ht),str(hline.get("text",""))]
 _rich(content,hist,14).custom_minimum_size.x=860
 if rules.state.scenario=="justine":
  var jrt=_jmap().get("texts",{})
  var contrast=str(jrt.get("result_contrast","")) if final else str(jrt.get("result_contrast_short",""))
  if contrast!="":_rich(content,"[b]Gillespie y la tradición[/b]\n"+_player_text(contrast),14).custom_minimum_size.x=860
 var row=_hbox(box)
 if final:
  if str(rules.state.status)=="victory":
   _button(row,"Ir a la campaña del norte",func():_start_game("norte"),44)
   _button(row,"Rejugar · río nuevo",func():_retry(true),44)
  else:
   _button(row,"Reintentar · mismo río",func():_retry(false),44)
   _button(row,"Río nuevo",func():_retry(true),44)
  _button(row,"Elegir escenario",_menu,44)
  _button(row,"Ver fuentes",_history_dialog,44)
 else:
  _button(row,"Seguir jugando",_close_modal,44)

# ---------- Progreso, diario, intro y partes (ronda de diversión R1: ui_feel) ----------
# El progreso vive en user://justina_progress.json, separado de la partida: el mismo río hasta ganar,
# lo aprendido (diario) y el candado del Norte. forced_seed>=0 (pruebas) manda sobre la semilla guardada.
const MEDAL_COLOR={"bronce":Color("d49a64"),"plata":Color("cfd8dc"),"oro":Color("f0d27a")}
const JARGON_BLACKLIST=["ZOC","halted_by_expiry","defeat_cause","stumble_at","exposure_s"]
var progress:Dictionary={"seed":-1,"diario":[],"intentos":0,"derrotas_seguidas":0,"mejor_medalla":"","justina_ganada":false,"intro_vista":false}
var choice_text=""
var campaign:CampaignProgress=CampaignProgress.new()
var last_result:Dictionary={}
var intro_assists:Array=[]
var last_learned:Array=[]
var last_medal=""
var last_first_win=false
var last_attempt_report:Dictionary={}
var shake=0.0
var flash_alpha=0.0
var flash_color=Color(1,1,1)
var flash_rect:ColorRect
var toast_prio=0
var volley_warned=-1.0
var details_open=false
var auto_start_pending=false
var beat_enabled=true
var outcome_beat:Label
var details_btn:Button
var detail_ctls:Array=[]
var attempt_logged=false

func _progress_load():
 campaign.load_progress();_progress_sync()

# `progress` es una vista de lo que guarda CampaignProgress (scripts/campaign.gd, user://campaign.json).
func _progress_sync():
 var d=campaign.data
 progress.seed=int(d.world_seed);progress.intentos=int(d.attempts);progress.derrotas_seguidas=int(d.defeats_in_row)
 progress.mejor_medalla=str(d.best_medal);progress.justina_ganada=campaign.north_unlocked();progress.intro_vista=not campaign.tutorial_pending()
 progress.diario=[]
 for e in campaign.diary_entries():progress.diario.append(_diary_view(e))

func _diary_view(e:Dictionary)->Dictionary:
 return {"id":str(e.key),"kind":str(e.kind),"text":str(e.text),"pos":[float(e.x),float(e.z)],"n":int(e.get("n",1))}

func _progress_save():
 campaign.save_progress()

func _justina_seed()->int:
 if forced_seed>=0:return forced_seed
 var sd=campaign.world_seed();_progress_sync()
 return sd

func _new_river():
 campaign.new_world();_progress_sync()

func _retry(fresh_river:bool=false):
 if fresh_river:_new_river()
 if is_instance_valid(modal):modal.queue_free()
 modal=null;paused=true
 _sound("order");_start_game("justine")

func _deadline_s()->float:
 return float(rules.tide_marks().deadline)

# «Desde el cruce»: restaura el punto de control (reconocimiento incluido) y devuelve el mando enseguida.
func _retry_checkpoint():
 if is_instance_valid(modal):modal.queue_free()
 modal=null
 var res=campaign.restore_checkpoint(rules)
 if not bool(res.get("ok",false)):_retry(false);return
 jev.invalidate();pending_round=false;outcome_shown=false;attempt_logged=false;shake=0.0;flash_alpha=0.0;toast_prio=0;volley_warned=-1.0;details_open=false
 mode="play";selected="guemes";sel_ids=["guemes"];aim="";aim_pts=[];wp_list=[];pending_pt=null;intro_assists=[];last_result={}
 _rebuild_world();_build_hud();_reset_camera_j();_refresh_minimap();_progress_sync();_update_hud()
 paused=false;pause_reason="";auto_start_pending=false
 _sound("order");_toast(str(res.get("reason","Desde el cruce.")),5,true,2)

func _record_attempt(r:Dictionary):
 if attempt_logged:return
 attempt_logged=true
 last_attempt_report=r
 last_result=campaign.record_result(rules)
 last_medal=str(last_result.get("medal",""));last_first_win=bool(last_result.get("unlocked_north",false))
 last_learned=[]
 for e in last_result.get("new_diary",[]):last_learned.append(_diary_view(e))
 _progress_sync()

func _defeat_text(r:Dictionary)->Dictionary:
 var d={"cause":str(last_result.get("cause","El intento terminó sin tomar el buque.")),"advice":str(last_result.get("advice","Mirá lo aprendido y probá otra ruta."))}
 var story=_defeat_story(r)
 if not story.is_empty():
  if not str(story.get("cause","")).is_empty():d.cause=str(story.cause)
  if not str(story.get("advice","")).is_empty():d.advice=str(story.advice)
 return d

# Causa con momento y lugar, y un consejo que cambia según lo que le pasó a ESTE intento (nunca el «probá de nuevo» genérico).
func _defeat_story(r:Dictionary)->Dictionary:
 var cid=str(rules.state.get("defeat_cause",""))
 var t=_clock(float(r.get("elapsed",0.0)))
 var cap=int(float(rules.state.get("capture",0.0)))
 var worst=""
 var worst_n=0
 var sa:Dictionary=rules.state.stats.get("stumble_at",{})
 for hid in sa:
  if int(sa[hid])>worst_n:
   worst_n=int(sa[hid])
   for hz in _jmap().get("hazards",[]):
    if str(hz.id)==str(hid):worst=str(hz.name).split(" (")[0]
 var cause=""
 match cid:
  "plazo":cause="Se acabó el tiempo a los %s: el río subió y el buque seguía en pie (captura %d %%)." % [t,cap]
  "inaccion":cause="Pasaron %s y nadie cargó: ya no había tiempo de llegar al buque." % t
  "dispersos":cause="A los %s tus grupos se quebraron antes de rendir al buque (captura %d %%)." % [t,cap]
  "retirada":cause="Ordenaste la retirada general a los %s." % t
 if cause.is_empty():cause="El intento terminó a los %s sin tomar el buque (captura %d %%)." % [t,cap]
 if cid=="plazo" and worst_n>0 and not worst.is_empty():cause="Se acabó el tiempo a los %s. %s te hizo perder el paso %d %s." % [t,worst,worst_n,"vez" if worst_n==1 else "veces"]
 # Consejos candidatos, del más específico al más general; cada intento elige uno distinto para que no se repita el mismo texto.
 var tips=[]
 if worst_n>0 and not worst.is_empty():tips.append("Mandá un explorador a sondear cerca de %s antes de pasar, o rodealo por el otro lado." % worst.to_lower())
 if int(r.get("counter_hits",0))>0:tips.append("Rechazá los contraataques con la coma, con un grupo que esté abordando: cada uno que dejás pasar te baja la captura.")
 if int(r.get("shots_taken",0))>=4 and cid!="retirada":tips.append("El buque te pegó %d veces: movete cuando aparezca el aro rojo, o usá «Distraer con fuego» antes de cargar." % int(r.get("shots_taken",0)))
 if rules.probes().is_empty():tips.append("No sondeaste el agua: mandá un explorador (tecla 4), Z y clic en el agua. Así sabés por dónde pasar.")
 if cid=="plazo" or cid=="inaccion":tips.append("Pedí la carga a Liniers apenas el vado ceda y no esperes al final: el río no perdona.")
 if cid=="dispersos":tips.append("Reuní a los grupos antes de cruzar y no mandes a todos por el mismo lado.")
 if tips.is_empty():tips.append(str(last_result.get("advice","Probá otra ruta: el sur es más lento pero más seguro.")))
 return {"cause":cause,"advice":_plain(str(tips[(maxi(int(progress.intentos),1)-1)%tips.size()]))}

func _aprendido_hint()->String:
 if last_result.has("hint"):return str(last_result.hint)
 return campaign.pista(rules)

func _stat_chip(parent:Node,title:String,value:String,col:Color=PAPER):
 var p=_panel(parent,Vector2.ZERO,Vector2(0,0),Color(0.07,0.13,0.15,1),Color("394c49"),8)
 p.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var v=_vbox(p,0)
 _label(v,title,12,MUTED);_label(v,value,22,col,true)

func _learned_block(parent:Node,limit:int=5):
 var box=_vbox(parent,4)
 _label(box,"LO APRENDIDO",12,GOLD)
 var items=last_learned
 if items.is_empty():
  _rich(box,"[color=#aab7b5]Esta vez no anotaste nada nuevo. Medir el agua con un explorador (Z) llena el diario.[/color]",15)
 else:
  var t=""
  var shown=0
  for i in range(items.size()):
   if str(items[i].text).begins_with("Hoy:") or shown>=limit:continue
   shown+=1;t+="• "+_plain(str(items[i].text))+"\n"
  if items.size()>limit:t+="• …y %d más en el diario.\n" % (items.size()-limit)
  _rich(box,t.strip_edges(),16)
 var hint=_aprendido_hint() if int(progress.derrotas_seguidas)>=2 else ""
 if not hint.is_empty():_rich(box,"[color=#f0d27a]Pista: [/color]"+_plain(hint),15)

func _history_toggle(parent:Node,r:Dictionary):
 var holder=_vbox(parent,4)
 var tb=_button(holder,"Qué fue historia ▸",func():pass,30);tb.alignment=HORIZONTAL_ALIGNMENT_LEFT
 var body=ScrollContainer.new();body.custom_minimum_size=Vector2(840,_scroll_h(160.0,460.0));body.visible=false;holder.add_child(body)
 var hist=""
 for hline in r.get("history",[]):
  var ht=str(hline.get("tag","diseno"))
  hist+="[color=%s]%s %s[/color]  %s\n" % [str(_tag_info(ht).get("color","#aab7b5")),_tag_glyph(ht),_tag_label(ht),str(hline.get("text",""))]
 var rt=_rich(body,hist,14);rt.custom_minimum_size.x=820
 tb.pressed.connect(func():body.visible=not body.visible;tb.text="Qué fue historia ▾" if body.visible else "Qué fue historia ▸")

func _primary_style(btn:Button):
 btn.add_theme_stylebox_override("normal",_cm_style("retry_main",Color("40391a"),Color("f0d27a"),2,14,8))
 btn.add_theme_stylebox_override("hover",_cm_style("retry_main_h",Color("55491f"),Color("ffe9a0"),2,14,8))

# Fila de «Más»: lo secundario queda plegado para que el botón principal sea lo único que pese.
func _more_row(parent:Node,specs:Array,r:Dictionary):
 var holder=_vbox(parent,6)
 var tb=_button(holder,"Más opciones ▸",func():pass,30);tb.alignment=HORIZONTAL_ALIGNMENT_LEFT
 var body=_vbox(holder,6);body.visible=false
 var row=_hbox(body,8)
 for sp in specs:_button(row,str(sp[0]),sp[1],34)
 _history_toggle(body,r)
 tb.pressed.connect(func():body.visible=not body.visible;tb.text="Más opciones ▾" if body.visible else "Más opciones ▸")

func _defeat_dialog(r:Dictionary):
 var d=_defeat_text(r)
 var box=_open_modal("Esta vez no pudo ser",820,_scroll_h(430.0,40.0))
 _rich(box,"[b]%s[/b]" % _plain(str(d.cause)),20).custom_minimum_size.x=760
 _rich(box,"[color=#f0d27a]Probá esto:[/color] "+_plain(str(d.advice)),17).custom_minimum_size.x=760
 # Solo cifras que dicen algo: un 0 % no enseña nada, así que se reemplaza por lo que sí pasó.
 var chips=_hbox(box,10)
 var cap=float(rules.state.get("capture",0.0))
 var shown=0
 if cap>=1.0:_stat_chip(chips,"Captura del buque","%d %%" % int(cap),GREEN if cap>=50.0 else PAPER);shown+=1
 var lp=float(r.get("loss_total_pct",0.0))
 if lp>=1.0:_stat_chip(chips,"Bajas","%d %%" % int(lp));shown+=1
 if int(r.get("stumbles",0))>0 and shown<2:_stat_chip(chips,"Tropiezos en pozos","%d" % int(r.stumbles),RED);shown+=1
 if int(r.get("shots_taken",0))>0 and shown<2:_stat_chip(chips,"Descargas recibidas","%d" % int(r.shots_taken));shown+=1
 if shown<2:_stat_chip(chips,"Agua sondeada","%d m" % int(float(r.get("probe_m",0.0))));shown+=1
 _stat_chip(chips,"Duró",_clock(float(r.get("elapsed",0.0))))
 var row=_hbox(box,10)
 var retry_btn:Button
 if campaign.has_checkpoint():
  var cp_btn=_button(row,"Reintentar desde el cruce (%s)" % _clock(campaign.checkpoint_time()),_retry_checkpoint,58);cp_btn.size_flags_horizontal=Control.SIZE_EXPAND_FILL;cp_btn.add_theme_font_size_override("font_size",19)
  _primary_style(cp_btn)
  cp_btn.tooltip_text="Vuelve al momento justo antes del vado, con lo que ya sondeaste. Son segundos, no minutos."
  retry_btn=_button(row,"Reintentar (mismo mapa)",func():_retry(false),58);retry_btn.size_flags_horizontal=Control.SIZE_EXPAND_FILL;retry_btn.add_theme_font_size_override("font_size",16)
 else:
  retry_btn=_button(row,"Reintentar (mismo mapa)",func():_retry(false),58);retry_btn.size_flags_horizontal=Control.SIZE_EXPAND_FILL;retry_btn.add_theme_font_size_override("font_size",20)
  _primary_style(retry_btn)
 retry_btn.tooltip_text="Vuelve a empezar con el mismo fondo del río: los pozos y vados están donde los anotaste."
 _learned_block(box,3)
 # «Mapa distinto» borra el diario: queda como acción chica y aparte, sin competir con Reintentar.
 var fresh_btn=_button(box,"Mapa distinto (borra el diario)",func():_retry(true),28);fresh_btn.add_theme_font_size_override("font_size",12);fresh_btn.alignment=HORIZONTAL_ALIGNMENT_LEFT
 fresh_btn.tooltip_text="Sortea otro fondo del río y borra el diario."
 _more_row(box,[["Abrir el diario",_diary_dialog],["Parte completo",func():_report_dialog(true)],["Ver fuentes",_history_dialog],["Menú",_menu]],r)
 _juice("defeat");_sound("defeat")

func _victory_dialog(r:Dictionary):
 var box=_open_modal("¡Buque tomado!",900,_scroll_h(540.0,40.0))
 var med=last_medal if not last_medal.is_empty() else "bronce"
 var ml=_label(box,"MEDALLA DE "+med.to_upper(),30,MEDAL_COLOR.get(med,GOLD),true);ml.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 var best=str(progress.mejor_medalla)
 var sub="Esta vez."
 if not best.is_empty() and best!=med:sub="Esta vez. Tu mejor sigue siendo la de %s." % best
 elif best==med and not last_first_win:sub="Esta vez. Igualaste tu mejor medalla."
 var sl=_label(box,sub,14,MUTED);sl.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 var why=""
 var n=0
 for ln in last_result.get("lines",[]):
  if str(ln).begins_with("Se desbloqueó") or str(ln).find("ventaja")>=0:continue
  if n>=3:break
  n+=1;why+="• "+str(ln)+"\n"
 _rich(box,why.strip_edges(),18).custom_minimum_size.x=840
 if last_first_win:
  var un=_label(box,"Se desbloqueó el escenario 2: Sostener el Norte",20,GREEN,true);un.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 var chips=_hbox(box,10)
 _stat_chip(chips,"Tiempo",_clock(float(r.get("elapsed",0.0))),GOLD)
 _stat_chip(chips,"Bajas","%d %%" % int(float(r.get("loss_total_pct",0.0))))
 _stat_chip(chips,"Tu mejor medalla",best.capitalize(),MEDAL_COLOR.get(best,PAPER))
 var row=_hbox(box,10)
 var go=_button(row,"Ir a Sostener el Norte (escenario 2)",func():_start_game("norte"),58);go.size_flags_horizontal=Control.SIZE_EXPAND_FILL;go.add_theme_font_size_override("font_size",20)
 _primary_style(go)
 _button(row,"Rejugar · mapa distinto",func():_retry(true),58)
 _more_row(box,[["Parte completo",func():_report_dialog(true)],["Ver fuentes",_history_dialog],["Menú",_menu]],r)
 _juice("victory")
 _victory_beat()

# Cierre breve de la captura: la cámara va al buque, banner y destello antes de mostrar el resultado.
func _victory_beat():
 if qa_mode or benchmark_mode or not beat_enabled or not is_instance_valid(modal):return
 _center_ship()
 modal.modulate.a=0.0
 if is_instance_valid(outcome_beat):outcome_beat.queue_free()
 outcome_beat=_label(ui,"¡BUQUE JUSTINA TOMADO!",44,Color("f6dc92"),true)
 outcome_beat.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;outcome_beat.mouse_filter=Control.MOUSE_FILTER_IGNORE
 outcome_beat.add_theme_color_override("font_outline_color",Color(0.05,0.03,0.0,0.95));outcome_beat.add_theme_constant_override("outline_size",10)
 _anchor(outcome_beat,0,0.5,1,0.5,0,-60,0,20)
 var tw=create_tween()
 tw.tween_interval(2.0)
 tw.tween_callback(func():
  if is_instance_valid(outcome_beat):outcome_beat.queue_free()
  if is_instance_valid(modal):create_tween().tween_property(modal,"modulate:a",1.0,0.35))

func _diary_dialog():
 var box=_open_modal("Diario del Bañado",860,_scroll_h(600.0,40.0))
 var intro="Lo que descubriste o sufriste en este río queda anotado y se marca tenue en el mapa del próximo intento (no cuenta como confirmado: hay que volver a medir)."
 _rich(box,"[color=#aab7b5]"+intro+"[/color]",15).custom_minimum_size.x=800
 var sc=ScrollContainer.new();sc.size_flags_vertical=Control.SIZE_EXPAND_FILL;sc.custom_minimum_size=Vector2(800,_scroll_h(330.0,330.0));box.add_child(sc)
 var cont=_vbox(sc,6);cont.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 if progress.diario.is_empty():
  _rich(cont,"Todavía no anotaste nada. Mandá un explorador a medir el agua (Z) y volvé acá.",17).custom_minimum_size.x=780
 else:
  for e in progress.diario:
   var ico={"pozo":"▲","vado":"≈","fuego":"✸","tiempo":"◔"}.get(str(e.kind),"•")
   var col={"pozo":"#f4a58d","vado":"#8fb4d9","fuego":"#e0bf81","tiempo":"#e0bf81"}.get(str(e.kind),"#e9e3d4")
   _rich(cont,"[color=%s]%s[/color]  %s" % [col,ico,_plain(str(e.text))],17).custom_minimum_size.x=780
 var stats="Intentos %d · derrotas seguidas %d · mejor medalla: %s" % [int(progress.intentos),int(progress.derrotas_seguidas),str(progress.mejor_medalla) if not str(progress.mejor_medalla).is_empty() else "ninguna"]
 _label(box,stats,13,MUTED)
 var row=_hbox(box,8)
 _button(row,"Cerrar",_close_modal,40)
 var nr=_button(row,"Río nuevo (borra el diario)",_diary_new_river,40)
 nr.tooltip_text="Sortea otro fondo del río y empieza de cero."

func _diary_new_river():
 _new_river()
 if mode=="play" and _is_j():_retry(false)
 else:_close_modal()

func _intro_card():
 var box=_open_modal("Justina · Buenos Aires, 12 de agosto de 1806",760,_scroll_h(440.0,40.0))
 _rich(box,"[font_size=22][b]Objetivo:[/b] tomar el buque Justina, varado en el río, antes de que suba la marea.[/font_size]",22).custom_minimum_size.x=700
 _rich(box,"[font_size=18]Perder no es grave: volvés a jugar con [b]el mismo río[/b] y con lo que anotaste en el diario.[/font_size]",18).custom_minimum_size.x=700
 var n=int(progress.intentos)
 if n>1:
  var line="Intento %d · anotaste %d %s" % [n,progress.diario.size(),"cosa" if progress.diario.size()==1 else "cosas"]
  var hint=_aprendido_hint() if int(progress.derrotas_seguidas)>=2 else ""
  if not hint.is_empty():line+="\n[color=#f0d27a]Pista:[/color] "+_plain(hint)
  _rich(box,"[color=#aab7b5]"+line+"[/color]",15).custom_minimum_size.x=700
 var offered=campaign.offered_assists(rules)
 if not offered.is_empty():_label(box,"AYUDAS OPCIONALES (sin ellas se puede ganar oro)",12,GOLD)
 for o in offered:
  var oid=str(o.id)
  var label_text="%s: %s" % [str(o.label),str(o.text)]
  var cb=Button.new();cb.toggle_mode=true;cb.text="☐  "+label_text;cb.alignment=HORIZONTAL_ALIGNMENT_LEFT;cb.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  cb.add_theme_font_size_override("font_size",14);cb.custom_minimum_size=Vector2(700,44);cb.focus_mode=Control.FOCUS_NONE
  cb.add_theme_stylebox_override("normal",_cm_style("assist_off",Color("172326"),Color("65756c"),1,10,5))
  cb.add_theme_stylebox_override("hover",_cm_style("assist_off_h",Color("1f3036"),Color("aab7b5"),1,10,5))
  cb.add_theme_stylebox_override("pressed",_cm_style("assist_on",Color("40391a"),Color("f0d27a"),3,10,5))
  cb.add_theme_stylebox_override("hover_pressed",_cm_style("assist_on",Color("40391a"),Color("f0d27a"),3,10,5))
  cb.tooltip_text="Ayuda opcional: queda anotada en el parte y con ella no hay medalla de oro."
  cb.toggled.connect(func(on):
   cb.text=("☑  " if on else "☐  ")+label_text
   if on and not intro_assists.has(oid):intro_assists.append(oid)
   elif not on:intro_assists.erase(oid))
  box.add_child(cb)
 _rich(box,"[color=#aab7b5]Cómo se juega: medí el agua con un explorador, esperá a que el vado ceda, pedí carga a Liniers y abordá. El reloj arranca con tu primera orden.[/color]",15).custom_minimum_size.x=700
 var row=_hbox(box,10)
 var go=_button(row,"Empezar",_intro_close,56);go.size_flags_horizontal=Control.SIZE_EXPAND_FILL;go.add_theme_font_size_override("font_size",20)
 _primary_style(go)
 _button(row,"Cómo se juega",_briefing_dialog,56)
 var tk=_button(row,"Saltar tutorial",_intro_skip_tutorial,56)
 tk.tooltip_text="Sin los carteles guía. Se reabre con «Repetir tutorial» en la ayuda."

func _intro_skip_tutorial():
 settings.tutorial=false;_save_settings();_intro_close()

func _intro_close():
 campaign.mark_tutorial_seen()
 auto_start_pending=paused and float(rules.state.elapsed)<0.5
 if bool(settings.tutorial) and rules.probes().is_empty():_select_ids(["scout_1"])
 var ap=campaign.apply_assists(rules,intro_assists)
 if not ap.is_empty():_toast("Ayuda en uso: "+", ".join(ap)+". La medalla de oro queda fuera.",6)
 _progress_sync()
 _close_modal();_update_hud()

func _pause_menu():
 var box=_open_modal("Pausa",560,_scroll_h(560.0,40.0))
 var go=_button(box,"Seguir jugando",_close_modal,46);go.add_theme_font_size_override("font_size",18)
 for spec in [["Diario del Bañado",_diary_dialog],["Parte de campaña (P)",_partial_report],["Guardar (F5)",_save_game],["Ajustes",_settings_dialog],["Ayuda (F1)",_briefing_dialog]]:
  _button(box,str(spec[0]),spec[1],40)
 _spacer(box,10)
 _label(box,"ACCIONES QUE CORTAN EL INTENTO",11,Color("e0705c"))
 _button(box,"Reiniciar este intento",_confirm_restart,38)
 _button(box,"Volver al menú",_return_menu,38)
 var ab=_button(box,"Abandonar: retirada general",_abandon,38)
 ab.add_theme_stylebox_override("normal",_cm_style("act_danger",Color("3a1613"),Color("e0705c"),2,10,4));ab.add_theme_color_override("font_color",Color("ffc6b8"))
 ab.tooltip_text="Pide confirmación y termina el intento como derrota."

func _partial_report():
 _report_dialog(false)

func _abandon():
 _close_modal();_do_action("retreat_all")

# ---------- Lenguaje claro, destellos y mensajes ----------
const PLAIN_SWAPS=[["Orden de avance","Permiso de carga"],["orden de avance","permiso de carga"],["Señales de Liniers","Avisos a Liniers"],["Señalar a Liniers","Pedir carga a Liniers"],["señales","avisos"],["Señales","Avisos"],["Balizas","Estacas"],["balizas","estacas"],["baliza","estaca"],["Pólvora de reserva","Munición de reserva"],["pólvora de reserva","munición de reserva"],["Reconocer fondo","Sondear el agua"]]
func _plain(t:String)->String:
 for p in PLAIN_SWAPS:t=t.replace(str(p[0]),str(p[1]))
 t=t.replace(" 1 pozo(s)"," 1 pozo").replace("pozo(s)","pozos")
 return t

# Una frase corta para el cartel transitorio: sin explicaciones de diseño ni notas largas.
func _short_msg(t:String)->String:
 var cut=t.find(" Regla del juego")
 if cut>0:t=t.substr(0,cut)
 var s=t.split(". ")
 var first=str(s[0])
 if not first.ends_with(".") and not first.ends_with("!") and not first.ends_with("?"):first+="."
 if first.length()>130:first=first.substr(0,127)+"…"
 return _plain(first)

func _flash(col:Color,amount:float=0.3):
 flash_color=col;flash_alpha=maxf(flash_alpha,amount)

func _juice(kind:String):
 match kind:
  "shot":shake=maxf(shake,0.9);_flash(Color(0.95,0.45,0.2),0.16)
  "stumble":shake=maxf(shake,0.6);_flash(Color(0.9,0.5,0.15),0.2);_sound("stumble")
  "ford":_flash(Color(0.45,0.75,0.9),0.14);_sound("ford")
  "counter":_flash(Color(0.9,0.25,0.2),0.2);shake=maxf(shake,0.5)
  "victory":_flash(Color(0.95,0.8,0.35),0.4)
  "defeat":_flash(Color(0.4,0.05,0.04),0.35)

func _ford_opens_at()->float:
 for f in ford_cache:
  if str(f.id)=="vado_buque":return float(f.win.opens_at)
 return -1.0

# El vado del buque abre en 60 s o menos (o ya abrió): recién ahí tiene sentido pedir la carga.
func _ford_soon()->bool:
 var o=_ford_opens_at()
 return o>=0.0 and float(rules.state.elapsed)>=o-60.0

# Cuenta regresiva de la descarga del buque sobre el propio buque (presión visible y avisada).
func _draw_volley_warning():
 if str(rules.state.status)!="playing":return
 var ps=rules.state.get("pending_shot",{})
 if ps.is_empty():return
 var left=maxf(0.0,float(ps.at)-float(rules.state.elapsed))
 var strong=bool(ps.strong)
 var ax=float(ps.ax);var az=float(ps.az);var rad=float(ps.radius)
 var pulse=0.5+0.5*sin(Time.get_ticks_msec()*0.014)
 var base=Color(0.95,0.18,0.12) if strong else Color(0.98,0.55,0.2)
 var ring=_ground_circle(Vector3(ax,_ground_y(ax,az)+0.4,az),rad,40)
 if ring.size()>=2:
  for i in range(0,ring.size()-1,2):overlay_top.draw_line(ring[i],ring[i+1],Color(base.r,base.g,base.b,0.6+0.35*pulse),4.0 if strong else 3.0)
 var pc=_project(Vector3(ax,_ground_y(ax,az)+3.0,az))
 var font=_font()
 var txt=("¡ANDANADA FUERTE %d!" if strong else "¡DESCARGA %d!") % ceili(left)
 var sz=font.get_string_size(txt,HORIZONTAL_ALIGNMENT_LEFT,-1,22)
 var view=get_viewport().get_visible_rect().size
 # El cartel va fijo arriba al centro (no tapa a las tropas); una flecha corta lo une con el círculo.
 var rc=Rect2(Vector2(view.x*0.5-(sz.x+32.0)*0.5,58.0),Vector2(sz.x+32.0,sz.y+34.0))
 overlay_top.draw_rect(rc,Color(0.3,0.05,0.04,0.95));overlay_top.draw_rect(rc,Color(base.r,base.g,base.b,1.0),false,3.0)
 overlay_top.draw_string(font,rc.position+Vector2(16,sz.y),txt,HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("ffe3d8"))
 overlay_top.draw_string(font,rc.position+Vector2(16,sz.y+22),"Sacá al grupo del círculo" if left>0.6 else "",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("ffd9cf"))
 if pc!=null:
  var pr=Rect2(Vector2(8,60),view-Vector2(16,70))
  if pr.has_point(pc):
   overlay_top.draw_line(Vector2(rc.position.x+rc.size.x*0.5,rc.end.y),pc+Vector2(0,-6),Color(base.r,base.g,base.b,0.55+0.3*pulse),2.0,true)
   overlay_top.draw_circle(pc+Vector2(0,-6),5.0,Color(base.r,base.g,base.b,0.9))
 var sp=rules.ship_position()
 var p=_project(Vector3(sp.x,_ground_y(sp.x,sp.y)+6.0,sp.y))
 if p!=null:overlay_top.draw_arc(p,26.0+pulse*8.0,0,TAU,32,Color(base.r,base.g,base.b,0.55+0.3*pulse),3.0)

# Flecha que rebota sobre lo que hay que tocar y anillo dorado de objetivo sobre el buque.
func _guide_arrow(p:Vector2,text_value:String):
 var bob=sin(Time.get_ticks_msec()*0.006)*6.0
 var tip=p+Vector2(0,-12.0+bob)
 var col=Color("f0d27a")
 overlay_top.draw_colored_polygon(PackedVector2Array([tip,tip+Vector2(-13,-22),tip+Vector2(13,-22)]),col)
 overlay_top.draw_rect(Rect2(tip+Vector2(-5,-44),Vector2(10,22)),col)
 if text_value.is_empty():return
 var font=_font()
 var sz=font.get_string_size(text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,15)
 var view=get_viewport().get_visible_rect().size
 var rc=Rect2(tip+Vector2(-sz.x*0.5-8,-76),sz+Vector2(16,8))
 rc.position.x=clampf(rc.position.x,6.0,view.x-rc.size.x-6.0);rc.position.y=maxf(rc.position.y,60.0)
 overlay_top.draw_rect(rc,Color(0.13,0.1,0.02,0.94));overlay_top.draw_rect(rc,col,false,2.0)
 overlay_top.draw_string(font,rc.position+Vector2(8,sz.y-2),text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("fff0c4"))

# Indicador de borde: cuando el buque queda fuera del cuadro, una flecha en el borde dice hacia dónde está.
func _edge_pointer(world_pos:Vector3,text_value:String):
 var view=get_viewport().get_visible_rect().size
 var center=view*0.5
 var scr=center
 if camera.is_position_behind(world_pos):
  scr=center+Vector2(0,view.y)
 else:
  scr=camera.unproject_position(world_pos)
  if Rect2(Vector2(20,70),view-Vector2(40,90)).has_point(scr):return
 var dir=(scr-center)
 if dir.length()<1.0:dir=Vector2(0,1)
 dir=dir.normalized()
 var tx=(view.x*0.5-60.0)/maxf(absf(dir.x),0.001)
 var ty=(view.y*0.5-110.0)/maxf(absf(dir.y),0.001)
 var pos=center+dir*minf(tx,ty)
 pos.y=maxf(pos.y,100.0)
 var pulse=0.5+0.5*sin(Time.get_ticks_msec()*0.006)
 var col=Color("f0d27a")
 var perp=Vector2(-dir.y,dir.x)
 var tip=pos+dir*22.0
 overlay_top.draw_colored_polygon(PackedVector2Array([tip+dir*3.0,pos+perp*16.0,pos-perp*16.0]),Color(0.05,0.04,0.0,0.9))
 overlay_top.draw_colored_polygon(PackedVector2Array([tip,pos+perp*13.0+dir*2.0,pos-perp*13.0+dir*2.0]),Color(col.r,col.g,col.b,0.75+0.25*pulse))
 var font=_font()
 var sz=font.get_string_size(text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,14)
 var rc=Rect2(pos-dir*34.0-sz*0.5-Vector2(8,4),sz+Vector2(16,8))
 rc.position.x=clampf(rc.position.x,6.0,view.x-rc.size.x-6.0)
 rc.position.y=clampf(rc.position.y,64.0,view.y-rc.size.y-6.0)
 overlay_top.draw_rect(rc,Color(0.05,0.04,0.0,0.9));overlay_top.draw_rect(rc,col,false,2.0)
 overlay_top.draw_string(font,rc.position+Vector2(8,sz.y-1),text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("fff0c4"))

func _draw_guides():
 if mode!="play" or str(rules.state.status)!="playing" or not is_instance_valid(world) or is_instance_valid(modal):return
 var sp=rules.ship_position()
 _edge_pointer(Vector3(sp.x,_ground_y(sp.x,sp.y)+6.0,sp.y),"Buque ▸")
 var pship=_project(Vector3(sp.x,_ground_y(sp.x,sp.y)+6.0,sp.y))
 if pship!=null and rules.state.get("pending_shot",{}).is_empty():
  var pulse=0.5+0.5*sin(Time.get_ticks_msec()*0.005)
  overlay_top.draw_arc(pship,30.0+pulse*5.0,0,TAU,40,Color(0.94,0.82,0.48,0.35+0.3*pulse),3.0)
  if float(rules.state.elapsed)<0.5 and bool(settings.tutorial):
   var ft=get_viewport().get_visible_rect().size
   if Rect2(Vector2(10,60),ft-Vector2(20,70)).has_point(pship):_guide_arrow(pship+Vector2(0,-30),"Objetivo: el buque")
 if not bool(settings.tutorial):return
 if tut_step==0 and world.unit_nodes.has("scout_1"):
  var ps=_project(world.unit_nodes["scout_1"].root.global_position+Vector3(0,4.0,0))
  var pg=_project(world.unit_nodes["scout_1"].root.global_position+Vector3(0,0.8,0))
  if pg!=null and not (is_instance_valid(alert_panel) and alert_panel.visible):
   var pl=0.5+0.5*sin(Time.get_ticks_msec()*0.007)
   overlay_top.draw_arc(pg,26.0+pl*7.0,0,TAU,40,Color(0.96,0.82,0.42,0.95),4.0)
   overlay_top.draw_arc(pg,40.0+pl*9.0,0,TAU,40,Color(0.96,0.82,0.42,0.4),2.0)
 elif tut_step==3 and pship!=null and not (is_instance_valid(alert_panel) and alert_panel.visible):_guide_arrow(pship+Vector2(0,-30),"Cargá contra el buque")

# Marco ámbar mientras el tiempo está detenido: se ve de un vistazo si el reloj corre.
func _draw_pause_frame():
 if str(rules.state.status)!="playing" or not paused or is_instance_valid(modal):return
 var sz=get_viewport().get_visible_rect().size
 var col=Color(0.88,0.75,0.4,0.55)
 overlay_top.draw_rect(Rect2(Vector2(3,3),sz-Vector2(6,6)),col,false,6.0)

# Marcas «anotado» del diario: tenues, sobre los sitios que el intento anterior descubrió o sufrió.
func _draw_diary_marks(font):
 var marks:Array=rules.diary_marks
 if marks.is_empty() or not is_instance_valid(world):return
 var found=rules.state.get("hazards_found",[])
 var fords=rules.state.get("fords_found",[])
 var radii={}
 for hz in _jmap().get("hazards",[]):radii[str(hz.id)]=float(hz.get("radius_m",10.0))
 for e in marks:
  var ide=str(e.key)
  var kind=str(e.kind)
  if kind=="pozo" and found.has(ide.trim_prefix("pozo:")):continue
  if kind=="vado" and fords.has(ide.trim_prefix("vado:")):continue
  var c=Vector2(float(e.x),float(e.z))
  var rad=float(radii.get(ide.trim_prefix("pozo:"),12.0))
  var ring=_ground_circle(Vector3(c.x,_ground_y(c.x,c.y)+0.3,c.y),rad,36)
  var col=Color(0.96,0.65,0.55,0.55) if kind=="pozo" else (Color(0.56,0.74,0.9,0.55) if kind=="vado" else Color(0.9,0.75,0.45,0.45))
  if ring.size()>=2:
   for i in range(0,ring.size()-1,2):overlay.draw_line(ring[i],ring[i+1],col,2.0)
  var pc=_project(Vector3(c.x,_ground_y(c.x,c.y)+0.6,c.y))
  if pc!=null:overlay.draw_string(font,pc+Vector2(-26,5),"anotado",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(col.r,col.g,col.b,0.85))

# ---------- Automatización (no es una partida humana) ----------
func _qa_justina():
 rules.issue_scout("scout_1","probe",[Vector2(200,264),Vector2(330,264)])
 rules.issue_scout("scout_2","probe",[Vector2(270,400),Vector2(340,404)])
 rules.issue_order("guemes","signal_liniers",Vector2.ZERO)
 for second in range(160):rules.tick(1.0)
 _update_hud()
 for i in range(30):await get_tree().process_frame
 await _qa_capture("justina-bajante")
 _save_game(false)
 var before=rules.state.elapsed
 var loaded=rules.load_game(_save_path("justine"))
 qa_metrics.save_load={"ok":loaded.ok,"elapsed_before":before,"elapsed_after":rules.state.elapsed}
 for second in range(700):
  if rules.state.status!="playing":break
  rules.tick(1.0)
 for i in range(35):await get_tree().process_frame
 await _qa_capture("justina-cierre")
