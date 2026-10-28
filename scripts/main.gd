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

var rules = Rules.new()
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
var settings = {"quality":"media","volume":0.55,"muted":false,"tutorial":true,"fullscreen":false,"camera_speed":1.0,"invert_orbit":false,"jev_local":false,"last_save":"norte"}
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
var qa_metrics = {}
var frame_samples: Array = []
var start_msec = 0
var hoof_timer = 0.0
var scene_build_ms = 0
var benchmark_mode = false
var benchmark_quality = "media"
const UNIT_COLORS = {"guemes":Color("e2bc72"),"arias":Color("7fd0c4"),"zavala":Color("e0a3bd")}
const UNIT_GLYPHS = {"guemes":"◆","arias":"▲","zavala":"●"}
const STAGE_TEXT = {"ready":["○","A la espera"],"moving":["▶","En marcha"],"waiting_tide":["≈","Espera la bajante"],"dismounting":["▼","Desmonta"],"boarding":["■","Resuelve la captura"],"blocked":["✕","Ruta interrumpida"],"rally":["↺","Reagrupa"],"ordered":["◇","Orden preparada"],"routed":["✕","Dispersa"]}
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
var log_regex: RegEx
var last_overlay_rects: Array = []

func _ready():
 start_msec = Time.get_ticks_msec()
 log_regex=RegEx.new();log_regex.compile("[0-9]+([.,][0-9]+)?")
 _load_settings()
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
 camera=Camera3D.new();camera.fov=46;camera.far=400;add_child(camera)
 camera.current=true
 layer=CanvasLayer.new();add_child(layer)
 _menu()
 var auto_scenario=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--qa="):qa_mode=true;auto_scenario=arg.trim_prefix("--qa=")
  if arg.begins_with("--qa-path="):qa_path=arg.trim_prefix("--qa-path=")
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
 world=World.new();add_child(world);world.build(rules,str(settings.quality))
 world.selected=selected;world.selected_sector=sector
 # Las etiquetas 3D tienen tamaño fijo en el mundo (AUDITORIA UI-3/4): se ocultan y la
 # interfaz las dibuja en pantalla con tamaño constante y sin solaparse.
 overlay_labels=[]
 var skip={}
 for entry in world.sector_nodes.values():skip[entry.label]=true
 for label_3d in world.unit_labels.values():skip[label_3d]=true
 for label_3d in world.find_children("*","Label3D",true,false):
  label_3d.visible=false
  if not skip.has(label_3d):overlay_labels.append(label_3d)
 if audio_manager:audio_manager.set_environment(str(rules.state.scenario))
 get_viewport().msaa_3d=Viewport.MSAA_DISABLED if settings.quality=="baja" else (Viewport.MSAA_4X if settings.quality=="alta" else Viewport.MSAA_2X)
 get_viewport().scaling_3d_scale=0.5 if settings.quality=="baja" else 1.0

func _menu():
 jev.invalidate();pending_round=false;mode="menu";paused=true;outcome_shown=false
 rules.new_game("justine",1806)
 selected="guemes";_rebuild_world();_new_ui()
 camera_target=Vector3(3,1,0);camera_distance=42;camera_pitch=0.43;camera_yaw=-0.55
 for label_3d in world.find_children("*","Label3D",true,false):label_3d.visible=false
 var tint=ColorRect.new();tint.color=Color(0.025,0.05,0.055,0.80);tint.position=Vector2(0,0);tint.size=Vector2(655,900);ui.add_child(tint)
 var box=VBoxContainer.new();box.position=Vector2(64,66);box.size=Vector2(510,750);box.add_theme_constant_override("separation",12);ui.add_child(box)
 _label(box,"J U E G O S   D E   L A   P A T R I A",17,GOLD)
 _spacer(box,24)
 _label(box,"GÜEMES",78,PAPER,true)
 _label(box,"EL TERRENO. EL MOMENTO. LA GENTE.",16,GOLD)
 _spacer(box,12)
 _rich(box,"Dos momentos de una historia. Elegí dónde actuar, cuidá a tus hombres y convertí el territorio en una ventaja.",19)
 _spacer(box,18)
 var a=_button(box,"I   ·   EL RÍO OFRECE UNA OPORTUNIDAD\nTomar el Justine  ·  Buenos Aires, 1806",func():_start_game("justine"),82)
 a.alignment=HORIZONTAL_ALIGNMENT_LEFT
 a.tooltip_text="Tres agrupaciones. Tiempo real con pausa. La bajante abre dos rutas hasta el buque."
 var b=_button(box,"II  ·   SOSTENER EL NORTE\nLa campaña contra La Serna  ·  1816–1817",func():_start_game("norte"),82)
 b.alignment=HORIZONTAL_ALIGNMENT_LEFT
 b.tooltip_text="Campaña por rondas. Reconocimiento, víveres, hostigamiento y la operación de Arias en Humahuaca."
 var options=_hbox(box)
 var continue_button=_button(options,"Continuar",func():_load_game(str(settings.last_save)))
 continue_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 continue_button.disabled=not FileAccess.file_exists(_save_path(str(settings.last_save)))
 _button(options,"Ajustes",_settings_dialog)
 _button(options,"Historia",_history_dialog)
 _spacer(box,6)
 _rich(box,"[color=#aab7b5]Recreación histórica documentada. La intervención personal de Güemes en el Justine pertenece a una tradición no probada.[/color]",13)
 _label(box,"VERSIÓN 0.1  ·  3D LOCAL  ·  SE PUEDE JUGAR SIN CONEXIÓN",11,MUTED)
 var credit=_label(ui,"RÍO DE LA PLATA\n12 DE AGOSTO DE 1806",16,Color("e6ceb0"),true)
 credit.position=Vector2(1040,700)
 _button_at(ui,"Salir",Vector2(1280,28),Vector2(124,42),func():get_tree().quit())

func _button_at(parent,text_value,pos,size_v,fn):
 var b=_button(parent,text_value,fn);b.position=pos;b.size=size_v;return b

func _start_game(scenario_name:String):
 var build_start=Time.get_ticks_msec()
 jev.invalidate();pending_round=false;resolution_remaining=0;outcome_shown=false
 rules.new_game(scenario_name,1806 if scenario_name=="justine" else 1817)
 selected="guemes";sector="lerma";mode="play";paused=scenario_name=="justine";speed=1
 camera_target=Vector3(-6,0,0) if scenario_name=="justine" else Vector3(1,0,4)
 camera_distance=81 if scenario_name=="justine" else 96;camera_pitch=0.91;camera_yaw=-0.17
 _rebuild_world();_build_hud();_update_hud()
 _toast("Elegí tu primera orden. Podés explorar la cámara antes de avanzar.",7)
 scene_build_ms=Time.get_ticks_msec()-build_start

func _build_hud():
 _new_ui();unit_buttons={};action_buttons={};stat_bars={};hud_panels=[]
 cam_goal_active=false;select_flash=0.0;hover_info={};confirm_action="";confirm_timer=0.0
 overlay=Control.new();overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(overlay);overlay.draw.connect(_draw_overlay)
 # Cabecera de una sola línea: el control de tiempo vive aquí, siempre visible.
 var header=_panel(ui,Vector2(20,10),Vector2(1400,0),Color(0.055,0.105,0.12,0.94),Color("394c49"),8);hud_panels.append(header)
 var hv=_hbox(header,10)
 var mark=_vbox(hv,0);mark.custom_minimum_size.x=150
 _label(mark,"JUEGOS DE LA PATRIA",10,GOLD)
 _label(mark,"GÜEMES",22,PAPER,true)
 var heading=_vbox(hv,2);heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 title_label=_label(heading,"",19,PAPER,true)
 phase_label=_label(heading,"",12,MUTED)
 pause_button=_button(hv,"▶  Iniciar",_toggle_pause,36);pause_button.custom_minimum_size.x=128
 pause_button.tooltip_text="Espacio. En el Justine pausa o reanuda el tiempo; en el norte resuelve la ronda."
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
 var column=_vbox(ui,6);column.position=Vector2(1168,70);column.custom_minimum_size.x=252;column.size=Vector2(252,0)
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
 bottom.grow_vertical=Control.GROW_DIRECTION_BEGIN;bottom_panel=bottom
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
  _button(groups,"4 · Seleccionar todas",func():_select_unit("all"),25)
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
 tutorial_label=_label(hint_panel,"",14,Color("f4e9c8"))
 tutorial_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;tutorial_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 toast_label=_label(ui,"",16,PAPER);toast_label.position=Vector2(310,70);toast_label.size=Vector2(840,56)
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
 if rules.state.scenario=="justine":
  _label(action_box,"ELEGÍ LA APROXIMACIÓN",12,GOLD)
  var row=_hbox(action_box,8)
  var direct=_button(row,"Banco directo\nMás corto · más expuesto",func():_tactical_order("direct"),46);direct.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  direct.tooltip_text="Prepara el cruce por el banco central. Si el agua está alta, espera en la ribera y avanza al habilitarse (banco central, agua ≤ 0,39). Termina en desmontaje y captura."
  var flank=_button(row,"Rodeo sur\nMás largo · menor exposición",func():_tactical_order("flank"),46);flank.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  flank.tooltip_text="Aproxima por el banco sur (agua ≤ 0,28). Reduce la exposición a la artillería y deja menos margen antes de la crecida."
  action_buttons["direct"]=direct;action_buttons["flank"]=flank
  var row2=_hbox(action_box,8)
  var cancel=_button(row2,"Cancelar · X",_cancel_order,30);action_buttons["cancel"]=cancel
  var shelf=_button(row2,"Más órdenes ▾" if shelf_open else "Más órdenes ▸",_toggle_shelf,30)
  shelf.tooltip_text="Reagrupar, Abordar y la vista de rutas. Se recuerda durante la sesión."
  if shelf_open:
   var rally=_button(row2,"Reagrupar",func():_confirm_tactical("rally"),30);action_buttons["rally"]=rally
   var board=_button(row2,"Abordar",func():_confirm_tactical("board"),30);action_buttons["board"]=board
   var paths=_button(row2,"Ver rutas",func():world.show_paths=not world.show_paths;world.refresh_paths(),30);action_buttons["paths"]=paths
   rally.tooltip_text="Detiene el avance, descarta la ruta y recupera fatiga. En la ribera oeste también repone fuerza y suministros. Pide segundo clic."
   board.tooltip_text="Ordena la aproximación final al buque si el acceso ya es transitable. Pide segundo clic."
   paths.tooltip_text="Muestra u oculta las rutas de las agrupaciones."
  reason_label=_label(action_box,"",12,MUTED);reason_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  _refresh_tactical_buttons()
 else:
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
 selected=id;world.selected=id;select_flash=0.5
 if rules.state.scenario=="norte":
  sector=str(rules.get_unit(id).sector_id);world.selected_sector=sector
 _refresh_actions();_update_hud();world.refresh_paths();_sound("order")

func _selected_ids()->Array:
 if selected=="all":return ["guemes","arias","zavala"]
 return [selected]

func _tactical_order(action:String,target:Vector2=Vector2.ZERO):
 if mode!="play" or rules.state.status!="playing":return
 var ok=0;var message=""
 for id in _selected_ids():
  var result=rules.issue_order(id,action,target)
  if result.ok:ok+=1
  message=str(result.reason)
 _toast(message,4,ok>0);_sound("order" if ok>0 else "error")
 world.refresh_paths();_update_hud()

func _campaign_order(action:String):
 if pending_round:return
 var result=rules.issue_campaign_order(selected,action,sector)
 _toast(str(result.reason),4,bool(result.ok));_sound("order" if result.ok else "error")
 _refresh_actions();_update_hud()

func _cancel_order():
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
 var state=rules.state
 title_label.text="I  ·  TOMAR EL JUSTINE" if state.scenario=="justine" else "II  ·  SOSTENER EL NORTE"
 if state.scenario=="justine":
  phase_label.text="BUENOS AIRES · 12 AGO 1806     /     "+("REUNIR  →  APROXIMAR  →  CAPTURAR")
  objective_label.text="[b]Capturá el mercante armado.[/b]\nConservá tus agrupaciones y cruzá cuando el río lo permita."
  capture_bar.value=float(state.capture)
  info_label.text="Río: [color=#e0bf81]"+str(state.tide_phase).capitalize()+"[/color]  (nivel %.2f)\nCaptura: [b]%d %%[/b]\nTiempo de misión: %s\nMargen restante: %s" % [float(state.water_level),int(state.capture),_clock(float(state.elapsed)),_clock(maxf(0,float(state.deadline)-float(state.elapsed)))]
  enemy_label.text="[b]JUSTINE[/b]\nArtillería de la dotación\n\nBanco central: exposición alta\nBanco sur: exposición reducida\n\nMoral de la dotación: [b]%d %%[/b]" % int(state.crew_morale)
  jev_label.text="Captura y navegación: reglas locales"
  pause_button.text="▶  Reanudar" if paused else "Ⅱ  Pausar"
  speed_button.text=str(int(speed))+"×"
  tutorial_label.text=_tactical_tip() if bool(settings.tutorial) else ""
 else:
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
  if is_instance_valid(bottom_panel):hint_panel.position.y=bottom_panel.get_global_rect().position.y-8.0-hint_panel.size.y
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
  var wait=_wait_seconds(unit)
  status_label.text="%s%s%s" % [badge,(" · "+str(ACTION_NAMES.get(action,action))) if not action.is_empty() and state.scenario=="norte" else "",(" · estimado %s hasta poder cruzar" % _clock(wait)) if wait>=0 else ""]
 var grouped=_grouped_log(5)
 var lines=[]
 for entry in grouped:
  lines.append("[color=#d9b576]•[/color] "+str(entry.text)+(" [color=#aab7b5](×%d)[/color]" % int(entry.count) if int(entry.count)>1 else ""))
 log_label.text="\n\n".join(lines)
 if is_instance_valid(journal_last):
  journal_last.text="• "+(str(grouped[-1].text) if not grouped.is_empty() else "Sin novedades.")
 if state.scenario=="justine":_refresh_tactical_buttons()

func _tactical_tip()->String:
 var any_order=false
 for u in rules.state.units:
  if not u.order.is_empty():any_order=true
 if float(rules.state.first_order_at)<0 and not any_order:
  return "Paso 1 de 3 · Elegí cómo cruzar. «Banco directo» es corto pero muy expuesto; «Rodeo sur» es largo y más seguro. Con 1, 2, 3 o 4 elegís a quién dar la orden."
 if paused and float(rules.state.elapsed)<1.0:
  return "Paso 2 de 3 · Orden preparada. Pulsá Espacio para iniciar el tiempo: el agua baja sola y tus grupos esperan en la ribera hasta poder cruzar."
 if float(rules.state.capture)>0:
  return "Paso 3 de 3 · Los jinetes desmontaron junto al buque y la captura avanza. Cuidá la fuerza restante para rendirlo antes del plazo. T acelera."
 if float(rules.state.water_level)>0.4:
  return "Paso 2 de 3 · El agua todavía cubre los bancos. Las agrupaciones esperan en tierra (el tiempo estimado está bajo cada una). Podés cambiar la ruta o acelerar con T."
 return "Paso 3 de 3 · El banco ya permite cruzar. La ruta sur expone menos a la artillería. Podés pausar con Espacio y cambiar las órdenes."

func _clock(seconds:float)->String:
 return "%02d:%02d" % [int(seconds)/60,int(seconds)%60]

func _process(delta):
 if not is_instance_valid(camera):return
 if qa_mode and mode=="play" and frame_samples.size()<240:frame_samples.append(delta*1000)
 if mode=="play" and not is_instance_valid(modal):_camera_keys(delta)
 _camera_goal_step(delta)
 var offset=Vector3(sin(camera_yaw)*cos(camera_pitch),sin(camera_pitch),cos(camera_yaw)*cos(camera_pitch))*camera_distance
 camera.position=camera_target+offset;camera.look_at(camera_target)
 if mode=="play" and rules.state.status=="playing" and rules.state.scenario=="justine" and not paused and not is_instance_valid(modal):
  _handle_events(rules.tick(delta*speed))
 if is_instance_valid(world):world.update_state(delta)
 if mode!="play":return
 if is_instance_valid(world):
  # world.update_state o el cambio de figura pueden recrear etiquetas 3D: se mantienen ocultas.
  for label_3d in world.unit_labels.values():
   if is_instance_valid(label_3d):label_3d.visible=false
 select_flash=maxf(0.0,select_flash-delta)
 if confirm_timer>0:
  confirm_timer-=delta
  if confirm_timer<=0:confirm_action="";_refresh_tactical_buttons()
 _update_hover(delta)
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
 if is_instance_valid(toast_label):toast_label.visible=toast_timer>0
 hoof_timer-=delta
 if not paused and hoof_timer<=0 and rules.state.scenario=="justine":
  for u in rules.state.units:
   if u.stage=="moving":_sound("hoof");break
  hoof_timer=0.62/speed
 if rules.state.status!="playing" and not outcome_shown:
  outcome_shown=true;jev.invalidate();pending_round=false;_outcome_dialog()

func _camera_keys(delta):
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

func _unhandled_input(event):
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode==KEY_ESCAPE:
   if is_instance_valid(modal):_close_modal()
   elif get_viewport().gui_get_focus_owner()!=null:_release_focus()
   elif mode=="play":_controls_dialog()
   return
  if event.keycode==KEY_F11:
   settings.fullscreen=not settings.fullscreen;_apply_fullscreen();_save_settings();return
  if event.keycode==KEY_TAB and get_viewport().gui_get_focus_owner()==null:
   _focus_hud();return
 if mode!="play" or is_instance_valid(modal):return
 if event is InputEventKey and event.pressed and not event.echo:
  match event.physical_keycode:
   KEY_1:_select_unit("guemes")
   KEY_2:_select_unit("arias")
   KEY_3:_select_unit("zavala")
   KEY_4:
    if rules.state.scenario=="justine":_select_unit("all")
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
   KEY_R:_start_game(str(rules.state.scenario))
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
   if rules.state.scenario=="justine":
    var p=_ground_point(event.position)
    if p!=null:_tactical_order("move",Vector2(p.x,p.z))
   else:
    var sid=world.pick_sector(camera,event.position)
    if not sid.is_empty():sector=sid;world.selected_sector=sid;_campaign_order("move")
 if event is InputEventMouseMotion and orbiting:
  camera_yaw-=event.relative.x*0.006
  camera_pitch=clampf(camera_pitch+event.relative.y*0.004*(-1.0 if settings.invert_orbit else 1.0),0.24,1.35)

func _toggle_pause():
 if rules.state.scenario=="norte":_resolve_round();return
 paused=not paused;_update_hud();_sound("order")

func _cycle_speed():
 speed=3.0 if speed==1.0 else 1.0;_update_hud()

func _focus_objective():
 _focus_to(Vector3(10,0,0) if rules.state.scenario=="justine" else Vector3(1,0,4),57 if rules.state.scenario=="justine" else 96)
 camera_pitch=0.85;camera_yaw=-0.17

func _handle_events(events:Array):
 for event in events:
  match str(event.get("kind","")):
   "shot":world.cannon_effect();_sound("cannon")
   "victory":_sound("victory")
   "defeat":_sound("error")
   "warning":_sound("alert")
   "boarding":_sound("dismount")
   "tide","humahuaca","occupation","history":_toast(str(event.text),7)

func _toast(message:String,duration=4.0,good=true):
 if not is_instance_valid(toast_label):return
 toast_label.text=message;toast_label.modulate=Color.WHITE if good else Color("efb69b");toast_timer=duration;toast_label.visible=true

func _sound(sound_name):
 if is_instance_valid(audio_manager):audio_manager.play(sound_name)

func _save_path(scenario_name:String)->String:
 return "user://"+("qa_" if qa_mode else "")+"save_"+scenario_name+".json"

func _save_game(notify_user=true):
 if mode!="play":return
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
  if mode=="play":_toast(str(result.reason),5,false);_refresh_actions()
  else:_simple_dialog("No se pudo continuar",str(result.reason))
  return
 mode="play";outcome_shown=false;paused=true;selected="guemes";sector=str(rules.get_unit("guemes").sector_id)
 camera_target=Vector3(-6,0,0) if rules.state.scenario=="justine" else Vector3(1,0,4)
 camera_distance=82 if rules.state.scenario=="justine" else 96;camera_pitch=0.91;camera_yaw=-0.17
 _rebuild_world();_build_hud();_update_hud();_toast("Partida recuperada. Las órdenes pendientes conservan su estado.",5)

func _return_menu():
 if not pending_round:_save_game(false)
 _menu()

func _open_modal(title:String,width=800,height=600)->VBoxContainer:
 if is_instance_valid(modal):_close_modal()
 modal_paused=paused;paused=true
 modal=Control.new();modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ui.add_child(modal)
 var shade=ColorRect.new();shade.color=Color(0.015,0.03,0.035,0.82);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);modal.add_child(shade)
 var panel=_panel(modal,Vector2((1440-width)/2.0,(900-height)/2.0),Vector2(width,height),Color("101f25"),Color("887750"))
 var box=_vbox(panel,14)
 var header=_hbox(box);var label=_label(header,title,27,GOLD,true);label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 _button(header,"Cerrar · Esc",_close_modal,36)
 return box

func _close_modal():
 if is_instance_valid(modal):modal.queue_free()
 modal=null;paused=modal_paused
 if mode=="play":_update_hud()

func _simple_dialog(title:String,text_value:String):
 var box=_open_modal(title,780,400);_rich(box,text_value,17)

func _controls_dialog():
 var box=_open_modal("Cómo jugar",840,650)
 _rich(box,"[b]Cámara[/b]   WASD o flechas desplazan. Q/E giran. La rueda acerca hacia el cursor. Botón central gira e inclina. O enfoca el objetivo y F la selección. I pliega la información, P abre el parte.\n\n[b]Agrupaciones[/b]   Clic sobre un grupo, o teclas 1, 2 y 3. En el Justine, 4 selecciona a todos. Clic derecho ordena mover. X cancela la orden pendiente.\n\n[b]Justine[/b]   Elegí banco directo o rodeo sur. La agrupación espera la bajante si hace falta. Al llegar desmonta y resuelve la captura. Espacio pausa/reanuda; T alterna 1× / 3×. «Reagrupar» y «Abordar» piden un segundo clic.\n\n[b]Norte[/b]   Elegí grupo y sector con el mapa o el selector. Prepará una orden por grupo; luego resolvé la ronda. Las órdenes se pueden cambiar antes de resolver. Los botones deshabilitados explican el motivo debajo de la bandeja. [ y ] cambian de sector.

[b]Teclado[/b]   Tab entra a la interfaz; Tab y Mayús+Tab recorren los controles; Enter o Espacio activan; Esc suelta el foco.\n\n[b]Continuidad[/b]   F5 guarda. F9 carga. R reinicia el escenario. Cada ronda se guarda automáticamente. H abre las fuentes. F11 alterna pantalla completa.\n\n[b]Consejo[/b]   Explorá antes de hostigar y alterná acciones de presión con protección de recursos y descanso. Esperar pasivamente permite sostener la invasión.",16)
 var check=CheckButton.new();check.text="Mostrar ayudas contextuales";check.button_pressed=bool(settings.tutorial)
 check.toggled.connect(func(on):settings.tutorial=on;_save_settings());box.add_child(check)

func _history_dialog():
 var box=_open_modal("Historia y recreación",1000,746)
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
 var box=_open_modal("Ajustes",740,590)
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
  _select_unit("all");_tactical_order("direct")
  for second in range(280):rules.tick(1.0)
  _update_hud()
  for i in range(40):await get_tree().process_frame
  await _qa_capture("justine-bajante")
  _save_game(false)
  var before=rules.state.elapsed
  var loaded=rules.load_game(_save_path("justine"))
  qa_metrics.save_load={"ok":loaded.ok,"elapsed_before":before,"elapsed_after":rules.state.elapsed}
  for second in range(700):
   if rules.state.status!="playing":break
   rules.tick(1.0)
  for i in range(35):await get_tree().process_frame
  await _qa_capture("justine-victoria")
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
 await _finish_automation(0 if rules.state.status=="victory" else 2)

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
  for unit in rules.state.units:rules.issue_order(str(unit.id),"flank")
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
 if action not in ["raid","assault"] or u.is_empty():return "Disponible."
 var s=rules.get_sector(sector)
 var informed=int(s.get("intel_until",0))>=int(rules.state.round)
 var effectiveness=maxf(0.45,(float(u.strength)/100.0)*(1.0-float(u.fatigue)*0.003))
 var low=4 if informed else 8
 var high=low+4+(3 if str(s.id)==str(rules.state.enemy.position) else 0)
 var verdict="Favorable" if informed and effectiveness>=0.6 else ("Parejo" if informed or effectiveness>=0.7 else "Desfavorable")
 return "Disponible. Previsión: %s (%s; eficacia %d %%). Pérdidas esperadas: %d a %d efectivos." % [verdict,"con reconocimiento reciente" if informed else "sin reconocimiento reciente",int(effectiveness*100),low,high]

func _tactical_block_reason(action:String)->String:
 if rules.state.status!="playing":return "La partida ya terminó."
 var any_alive=false
 var any_order=false
 for id in _selected_ids():
  var u=rules.get_unit(id)
  if not u.is_empty() and float(u.strength)>5.0:any_alive=true
  if not u.is_empty() and not u.order.is_empty():any_order=true
 if not any_alive:return "la agrupación ya no puede recibir órdenes."
 if action=="board" and not rules.is_walkable(Rules.BOARD_POINT.x,Rules.BOARD_POINT.y):
  return "el agua aún cubre el acceso al buque (nivel %.2f). Esperá la bajante; las aproximaciones esperan por vos." % float(rules.state.water_level)
 if action=="cancel" and not any_order:return "no hay órdenes para cancelar."
 return ""

func _refresh_tactical_buttons():
 if rules.state.scenario!="justine" or not is_instance_valid(reason_label):return
 var notes=[]
 for action in ["direct","flank","cancel","rally","board"]:
  if not action_buttons.has(action) or not is_instance_valid(action_buttons[action]):continue
  var why=_tactical_block_reason(action)
  var b:Button=action_buttons[action]
  b.disabled=not why.is_empty()
  if action in ["rally","board"]:
   b.text=("¿Confirmar? " if confirm_action==action and confirm_timer>0 else "")+("Reagrupar" if action=="rally" else "Abordar")
  if not why.is_empty():notes.append(("Cancelar" if action=="cancel" else ("Reagrupar" if action=="rally" else ("Abordar" if action=="board" else str(action))))+": "+why)
 reason_label.text="\n".join(notes) if not notes.is_empty() else "Todas las órdenes están disponibles. Reagrupar y Abordar piden un segundo clic."

func _confirm_tactical(action:String):
 if confirm_action==action and confirm_timer>0:
  confirm_action="";confirm_timer=0.0
  _tactical_order(action);_refresh_tactical_buttons();return
 var why=_tactical_block_reason(action)
 if not why.is_empty():
  _toast(action.capitalize()+": "+why,4,false);_sound("error");return
 confirm_action=action;confirm_timer=4.0
 var preview="Reagrupar descarta la ruta y recupera fatiga; la agrupación deja de avanzar." if action=="rally" else "Abordar ordena la aproximación final al buque."
 _toast("Segundo clic en 4 s para confirmar. "+preview,4)
 _refresh_tactical_buttons()

func _step_sector(direction:int):
 if rules.state.scenario!="norte" or pending_round:return
 var ids=[]
 for s in rules.state.sectors:ids.append(str(s.id))
 var index=ids.find(sector)
 sector=ids[posmod(index+direction,ids.size())]
 world.selected_sector=sector;_refresh_actions();_update_hud();_sound("order")

func _short_name(id:String)->String:
 if rules.state.scenario=="norte":return "Güemes" if id=="guemes" else ("Arias" if id=="arias" else "Partida del valle")
 return "Vanguardia" if id=="guemes" else ("Voluntarios" if id=="arias" else "Reserva")

func _stage_badge(stage_id:String)->String:
 var pair=STAGE_TEXT.get(stage_id,["·",stage_id])
 return str(pair[0])+" "+str(pair[1])

func _wait_seconds(u:Dictionary)->float:
 # Estimación del tiempo hasta que el nivel del río llegue al umbral de cruce de game_rules
 # (0,39 banco central, 0,28 rodeo sur). Solo lectura; -1 si no aplica.
 if str(u.get("stage",""))!="waiting_tide":return -1.0
 var need=0.28 if str(u.order.get("action","direct"))=="flank" else 0.39
 if float(rules.state.water_level)<=need or str(rules.state.tide_phase) not in ["alta","bajando"]:return -1.0
 return maxf(0.0,40.0+170.0*(0.95-need)/0.9-float(rules.state.elapsed))

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
   out.append({"key":key,"text":text,"count":1})
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
 camera_target.x=clampf(camera_target.x,-40,40);camera_target.z=clampf(camera_target.z,-32,32)
 if camera_target.distance_to(cam_goal_target)<0.05 and absf(camera_distance-cam_goal_distance)<0.1:cam_goal_active=false

func _focus_to(target:Vector3,distance:float):
 cam_goal_target=Vector3(clampf(target.x,-40,40),target.y,clampf(target.z,-32,32))
 cam_goal_distance=clampf(distance,18,125);cam_goal_active=true

func _focus_selected():
 if not is_instance_valid(world):return
 var total=Vector3.ZERO;var n=0
 for id in _selected_ids():
  if world.unit_nodes.has(id):
   total+=world.unit_nodes[id].root.global_position;n+=1
 if n==0:return
 _focus_to(total/n,minf(camera_distance,48.0 if rules.state.scenario=="justine" else 70.0))
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
 return selected==id or selected=="all"

func _blocked_rects()->Array:
 var rects=[]
 for panel in hud_panels:
  if is_instance_valid(panel) and panel.is_visible_in_tree():rects.append(panel.get_global_rect().grow(4.0))
 if is_instance_valid(hint_panel) and hint_panel.visible:rects.append(hint_panel.get_global_rect().grow(4.0))
 return rects

func _overlaps_any(rect:Rect2,list:Array)->bool:
 for r in list:
  if rect.intersects(r):return true
 return false

func _update_hover(delta):
 # Anticipación de órdenes (Civ VII: modo -> vista previa en hover -> confirmación).
 hover_timer-=delta
 if hover_timer>0:return
 hover_timer=0.08
 hover_info={}
 if mode!="play" or is_instance_valid(modal) or not is_instance_valid(world) or rules.state.status!="playing":return
 var mp=hover_mouse
 if not get_viewport().get_visible_rect().has_point(mp):return
 for r in _blocked_rects():
  if r.has_point(mp):return
 if rules.state.scenario=="justine":
  var u=rules.get_unit(_selected_ids()[0])
  if u.is_empty() or float(u.strength)<=5.0:return
  var p=_ground_point(mp)
  if p==null:return
  var origin=Vector2(float(u.x),float(u.z))
  var target=Vector2(p.x,p.z)
  var info={"kind":"ground","point":p,"ok":false,"path":[],"seconds":0.0,"text":""}
  if not rules.is_walkable(target.x,target.y):
   info.text="No se puede ordenar mover aquí: agua demasiado profunda u obstáculo con el nivel actual."
  else:
   var path=rules._route(origin,target)
   if path.is_empty() and origin.distance_to(target)>0.5:
    info.text="Sin ruta transitable hasta ese punto con el nivel actual del río."
   else:
    var length=0.0;var last=origin
    for node in path:
     var q=Vector2(float(node.x),float(node.z));length+=last.distance_to(q);last=q
    var speed_units=(0.24 if bool(u.mounted) else 0.18)*maxf(0.55,1.0-float(u.fatigue)*0.004)
    var exposure=rules.exposure_for({"x":target.x,"z":target.y,"strength":100.0,"stage":"moving"})
    info.ok=true;info.path=path;info.seconds=length/speed_units
    info.text="Mover aquí · ≈ %s · %s" % [_clock(length/speed_units),"exposición alta a la artillería" if exposure>=0.9 else ("exposición reducida" if exposure>0.1 else "fuera del alcance de la artillería")]
  hover_info=info
 else:
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
  var q=_project(Vector3(x,maxf(world.terrain_height(x,z),float(rules.state.get("water_level",0)))+0.25,z))
  if q==null:break
  pts.append(q)
 return pts

func _draw_overlay():
 if mode!="play" or not is_instance_valid(world) or not is_instance_valid(camera):return
 var font=_font()
 var blocked=_blocked_rects()
 var placed=[]
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
   var wait=_wait_seconds(u)
   if wait>=0:state_text+=" ≈"+_clock(wait)
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
