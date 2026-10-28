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
const ACTION_HINTS = {"move":"Traslada la agrupación a un sector vecino. Fatiga +7; suministros −4.","scout":"Revela el sector y sus vecinos. El reconocimiento reduce las pérdidas del hostigamiento durante tres rondas.","protect":"Resguarda víveres y animales del sector propio. Reservas +18, apoyo +9; limita el abastecimiento enemigo.","raid":"Corta abastecimiento y comunicaciones. Requiere conocimiento del sector y fuerzas en condiciones.","rest":"En un sector propio: suministros +27, fatiga −34, fuerza +9. Consume 8 reservas.","withdraw":"Vuelve a un sector vecino propio y reduce 16 de fatiga.","assault":"Arias coordina Humahuaca desde marzo: afecta artillería, cuartel, arsenal y comunicaciones."}

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

func _ready():
 start_msec = Time.get_ticks_msec()
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
  var s=_style(c,Color("455753") if state_name!="hover" else GOLD,1,5,14)
  s.content_margin_top=5;s.content_margin_bottom=5
  theme_main.set_stylebox(state_name,"Button",s)
  theme_main.set_stylebox(state_name,"OptionButton",s)
 theme_main.set_color("font_color","Button",PAPER)
 theme_main.set_color("font_hover_color","Button",Color.WHITE)
 theme_main.set_color("font_disabled_color","Button",Color("748482"))
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

func _panel(parent:Control,pos:Vector2,size_v:Vector2,bg=Color(0.055,0.105,0.12,0.94),border=Color("394c49")):
 var panel=PanelContainer.new();panel.position=pos;panel.size=size_v
 panel.add_theme_stylebox_override("panel",_style(bg,border,1,7,18))
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
 button.pressed.connect(fn);parent.add_child(button);button.focus_mode=Control.FOCUS_NONE
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
 _new_ui();unit_buttons={};action_buttons={}
 var header=_panel(ui,Vector2(20,18),Vector2(1400,83))
 var hv=_hbox(header,20)
 var mark=_vbox(hv,0);mark.custom_minimum_size.x=224
 _label(mark,"JUEGOS DE LA PATRIA",12,GOLD)
 _label(mark,"GÜEMES",27,PAPER,true)
 var heading=_vbox(hv,4);heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 title_label=_label(heading,"",23,PAPER,true)
 phase_label=_label(heading,"",13,MUTED)
 _button(hv,"Fuentes",_history_dialog,38)
 _button(hv,"Ajustes",_settings_dialog,38)
 _button(hv,"Menú",_return_menu,38)
 var left=_panel(ui,Vector2(20,116),Vector2(280,305))
 var lv=_vbox(left,11)
 _label(lv,"OBJETIVO",12,GOLD)
 objective_label=_rich(lv,"",17)
 capture_bar=ProgressBar.new();capture_bar.custom_minimum_size.y=8;capture_bar.show_percentage=false;lv.add_child(capture_bar)
 info_label=_rich(lv,"",14)
 var control_row=_hbox(lv,7)
 pause_button=_button(control_row,"▶  Iniciar",_toggle_pause,38);pause_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 speed_button=_button(control_row,"1×",_cycle_speed,38);speed_button.custom_minimum_size.x=49
 var saves=_hbox(lv,7)
 _button(saves,"Guardar · F5",func():_save_game(),34)
 _button(saves,"Objetivo · O",_focus_objective,34)
 var right=_panel(ui,Vector2(1158,116),Vector2(262,250))
 var rv=_vbox(right,9)
 _label(rv,"SITUACIÓN",12,GOLD)
 enemy_label=_rich(rv,"",15)
 jev_label=_label(rv,"",11,MUTED)
 jev_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 var journal=_panel(ui,Vector2(20,445),Vector2(280,245))
 var jv=_vbox(journal,8);_label(jv,"PARTE DE SITUACIÓN",12,GOLD)
 log_label=RichTextLabel.new();log_label.bbcode_enabled=true;log_label.custom_minimum_size=Vector2(242,186);log_label.scroll_following=true;log_label.add_theme_font_size_override("normal_font_size",13);jv.add_child(log_label)
 var bottom=_panel(ui,Vector2(20,701),Vector2(1400,178))
 var br=_hbox(bottom,18)
 var groups=_vbox(br,4);groups.custom_minimum_size.x=280
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
 var middle=_vbox(br,8);middle.custom_minimum_size.x=310
 selected_label=_label(middle,"",18,PAPER)
 status_label=_label(middle,"",13,MUTED);status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 if rules.state.scenario=="norte":
  sector_option=OptionButton.new();sector_option.custom_minimum_size.y=34
  for s in rules.state.sectors:sector_option.add_item(str(s.name));sector_option.set_item_metadata(sector_option.item_count-1,str(s.id))
  sector_option.item_selected.connect(func(index):sector=str(sector_option.get_item_metadata(index));world.selected_sector=sector;_refresh_actions();_update_hud())
  middle.add_child(sector_option)
 else:
  _label(middle,"Clic derecho en el terreno: mover\nEspacio: pausa · Rueda: acercar\nWASD: desplazar · Q/E: girar",12,MUTED)
 action_box=_vbox(br,7);action_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 _refresh_actions()
 tutorial_label=_label(ui,"",14,Color("eee1bd"));tutorial_label.position=Vector2(330,646);tutorial_label.size=Vector2(790,54)
 tutorial_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;tutorial_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 toast_label=_label(ui,"",16,PAPER);toast_label.position=Vector2(325,118);toast_label.size=Vector2(805,70)
 toast_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;toast_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 toast_label.add_theme_stylebox_override("normal",_style(Color(0.04,0.09,0.11,0.91),Color("7c7653"),1,5,13))
 _button_at(ui,"?  Controles · F1",Vector2(1223,662),Vector2(197,31),_controls_dialog)

func _refresh_actions():
 if not is_instance_valid(action_box):return
 for child in action_box.get_children():action_box.remove_child(child);child.queue_free()
 action_buttons={}
 if rules.state.scenario=="justine":
  _label(action_box,"ELEGÍ LA APROXIMACIÓN",12,GOLD)
  var row=_hbox(action_box,8)
  var direct=_button(row,"Banco directo\nMás corto · más expuesto",func():_tactical_order("direct"),49);direct.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  direct.tooltip_text="Prepara el cruce por el banco central. Si el agua está alta, espera en la ribera y avanza al habilitarse. Termina en desmontaje y captura."
  var flank=_button(row,"Rodeo sur\nMás largo · menor exposición",func():_tactical_order("flank"),49);flank.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  flank.tooltip_text="Aproxima por el banco sur. Reduce la exposición a la artillería y deja menos margen antes de la crecida."
  var row2=_hbox(action_box,8)
  _button(row2,"Reagrupar",func():_tactical_order("rally"),34)
  _button(row2,"Abordar",func():_tactical_order("board"),34)
  _button(row2,"Cancelar · X",_cancel_order,34)
  _button(row2,"Ver rutas",func():world.show_paths=not world.show_paths;world.refresh_paths(),34)
 else:
  _label(action_box,"ORDEN PARA EL SECTOR ELEGIDO",12,GOLD)
  var grid=GridContainer.new();grid.columns=4;grid.add_theme_constant_override("h_separation",6);grid.add_theme_constant_override("v_separation",6);action_box.add_child(grid)
  var legal=rules.legal_campaign_actions(selected,sector)
  for action in ["move","scout","protect","raid","rest","withdraw","assault"]:
   var b=_button(grid,str(ACTION_NAMES[action]),func():_campaign_order(action),32)
   b.add_theme_font_size_override("font_size",13);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
   b.disabled=not legal.has(action) or pending_round
   b.tooltip_text=str(ACTION_HINTS[action])+"\n"+rules.campaign_order_reason(selected,action,sector)
   action_buttons[action]=b
  _button(grid,"Cancelar · X",_cancel_order,32)
  var rr=_hbox(action_box,8)
  round_button=_button(rr,"Resolver ronda  →",_resolve_round,35);round_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  round_button.disabled=pending_round or resolution_remaining>0
  round_button.add_theme_color_override("font_color",GOLD)
  _button(rr,"Ver consecuencias",_round_report,35)

func _select_unit(id:String):
 selected=id;world.selected=id
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
 _handle_events(events);_refresh_actions();_update_hud()
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
  info_label.text="Río: [color=#e0bf81]"+str(state.tide_phase).capitalize()+"[/color]\nCaptura: [b]%d %%[/b]\nTiempo de misión: %s\nMargen restante: %s" % [int(state.capture),_clock(float(state.elapsed)),_clock(maxf(0,float(state.deadline)-float(state.elapsed)))]
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
  jev_label.text="Jev: "+str(jev.status_text)
  pause_button.text="Resolver  →";speed_button.text=str(int(speed))+"×"
  if is_instance_valid(round_button):round_button.disabled=pending_round or resolution_remaining>0 or state.status!="playing"
  tutorial_label.text="Seleccioná una agrupación y un sector. Prepará una orden por grupo y resolvé la ronda. Explorar antes de hostigar reduce las pérdidas." if bool(settings.tutorial) else ""
  for i in range(sector_option.item_count):
   if str(sector_option.get_item_metadata(i))==sector:sector_option.select(i)
 for u in state.units:
  var id=str(u.id)
  if not unit_buttons.has(id):continue
  var number=state.units.find(u)+1
  var short_name="Vanguardia" if id=="guemes" else ("Voluntarios" if id=="arias" else "Reserva")
  if state.scenario=="norte":short_name="Güemes" if id=="guemes" else ("Arias" if id=="arias" else "Partida del valle")
  unit_buttons[id].text=("● " if selected==id or selected=="all" else "")+str(number)+" · "+short_name+"     "+str(int(u.strength))+"%"
  unit_buttons[id].add_theme_color_override("font_color",GOLD if selected==id or selected=="all" else PAPER)
 if selected=="all":
  selected_label.text="Las tres agrupaciones"
  status_label.text="La orden se aplica a cada grupo.\nCada ruta conserva su validación."
 else:
  var unit=rules.get_unit(selected)
  selected_label.text=str(unit.name)
  selected_label.add_theme_font_size_override("font_size",16 if str(unit.name).length()>20 else 18)
  var action=str(unit.order.get("action",""))
  var stage_names={"ready":"A la espera","moving":"En movimiento","waiting_tide":"Espera la bajante","dismounting":"Desmontando","boarding":"Resolviendo la captura","blocked":"Ruta interrumpida","rally":"Reagrupando","ordered":"Orden preparada","routed":"Dispersa"}
  status_label.text="Fuerza %d%%  ·  Fatiga %d  ·  Suministros %d\n%s%s" % [int(unit.strength),int(unit.fatigue),int(unit.supply),str(stage_names.get(unit.stage,unit.stage)),(" · "+str(ACTION_NAMES.get(action,action))) if not action.is_empty() and state.scenario=="norte" else ""]
 var lines=[]
 var n=state.log.size()
 for i in range(maxi(0,n-5),n):
  lines.append("[color=#d9b576]•[/color] "+str(state.log[i].text))
 log_label.text="\n\n".join(lines)

func _tactical_tip()->String:
 if float(rules.state.first_order_at)<0:return "Primera decisión: banco directo o rodeo sur. La orden prepara el cruce y espera en la ribera si el agua está alta. Espacio inicia el tiempo."
 if float(rules.state.capture)>0:return "Los jinetes desmontaron junto al buque. La fuerza conservada acelera la rendición. Podés acelerar la resolución con 1× / 3×."
 if float(rules.state.water_level)>0.4:return "La bajante está cambiando la profundidad. Las agrupaciones esperan en tierra hasta que el banco de su ruta sea transitable."
 return "El banco ya permite el cruce. La ruta sur reduce la exposición; la artillería castiga la aproximación central. Podés pausar y cambiar órdenes."

func _clock(seconds:float)->String:
 return "%02d:%02d" % [int(seconds)/60,int(seconds)%60]

func _process(delta):
 if not is_instance_valid(camera):return
 if qa_mode and mode=="play" and frame_samples.size()<240:frame_samples.append(delta*1000)
 if mode=="play" and not is_instance_valid(modal):_camera_keys(delta)
 var offset=Vector3(sin(camera_yaw)*cos(camera_pitch),sin(camera_pitch),cos(camera_yaw)*cos(camera_pitch))*camera_distance
 camera.position=camera_target+offset;camera.look_at(camera_target)
 if mode=="play" and rules.state.status=="playing" and rules.state.scenario=="justine" and not paused and not is_instance_valid(modal):
  _handle_events(rules.tick(delta*speed))
 if is_instance_valid(world):world.update_state(delta)
 if mode!="play":return
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
 if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):direction+=forward
 if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):direction-=forward
 if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):direction-=right
 if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):direction+=right
 camera_target+=direction*delta*camera_distance*0.32*float(settings.camera_speed)
 camera_target.x=clampf(camera_target.x,-40,40);camera_target.z=clampf(camera_target.z,-32,32)
 if Input.is_physical_key_pressed(KEY_Q):camera_yaw+=delta*0.8
 if Input.is_physical_key_pressed(KEY_E):camera_yaw-=delta*0.8

func _unhandled_input(event):
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode==KEY_ESCAPE:
   if is_instance_valid(modal):_close_modal()
   elif mode=="play":_controls_dialog()
   return
  if event.keycode==KEY_F11:
   settings.fullscreen=not settings.fullscreen;_apply_fullscreen();_save_settings();return
 if mode!="play" or is_instance_valid(modal):return
 if event is InputEventKey and event.pressed and not event.echo:
  match event.physical_keycode:
   KEY_1:_select_unit("guemes")
   KEY_2:_select_unit("arias")
   KEY_3:_select_unit("zavala")
   KEY_4:
    if rules.state.scenario=="justine":_select_unit("all")
   KEY_SPACE:_toggle_pause()
   KEY_TAB:_cycle_speed()
   KEY_X:_cancel_order()
   KEY_O:_focus_objective()
   KEY_F1:_controls_dialog()
   KEY_F5:_save_game()
   KEY_F9:_load_game(str(rules.state.scenario))
   KEY_R:_start_game(str(rules.state.scenario))
   KEY_H:_history_dialog()
 if event is InputEventMouseButton:
  if event.button_index==MOUSE_BUTTON_WHEEL_UP and event.pressed:camera_distance=maxf(18,camera_distance*0.90)
  if event.button_index==MOUSE_BUTTON_WHEEL_DOWN and event.pressed:camera_distance=minf(125,camera_distance*1.11)
  if event.button_index==MOUSE_BUTTON_MIDDLE:orbiting=event.pressed
  if event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
   var id=world.pick_unit(camera,event.position)
   if not id.is_empty():_select_unit(id)
   elif rules.state.scenario=="norte":
    var sid=world.pick_sector(camera,event.position)
    if not sid.is_empty():sector=sid;world.selected_sector=sid;_refresh_actions();_update_hud();_sound("order")
  if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
   if rules.state.scenario=="justine":
    var p=world.pick_ground(camera,event.position)
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
 camera_target=Vector3(10,0,0) if rules.state.scenario=="justine" else Vector3(1,0,4)
 camera_distance=57 if rules.state.scenario=="justine" else 96
 camera_pitch=0.85;camera_yaw=-0.17

func _handle_events(events:Array):
 for event in events:
  match str(event.get("kind","")):
   "shot":world.cannon_effect();_sound("cannon")
   "victory":_sound("victory")
   "defeat":_sound("error")
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
 _rich(box,"[b]Cámara[/b]   WASD o flechas desplazan. Q/E giran. Rueda acerca y aleja. Arrastrar con botón central gira e inclina. O enfoca el objetivo.\n\n[b]Agrupaciones[/b]   Clic sobre un grupo, o teclas 1, 2 y 3. En el Justine, 4 selecciona a todos. Clic derecho ordena mover. X cancela la orden pendiente.\n\n[b]Justine[/b]   Elegí banco directo o rodeo sur. La agrupación espera la bajante si hace falta. Al llegar desmonta y resuelve la captura. Espacio pausa/reanuda; Tab alterna 1× / 3×.\n\n[b]Norte[/b]   Elegí grupo y sector con el mapa o el selector. Prepará una orden por grupo; luego resolvé la ronda. Las órdenes se pueden cambiar antes de resolver. Los botones deshabilitados explican el motivo al pasar el mouse.\n\n[b]Continuidad[/b]   F5 guarda. F9 carga. R reinicia el escenario. Cada ronda se guarda automáticamente. H abre las fuentes. F11 alterna pantalla completa.\n\n[b]Consejo[/b]   Explorá antes de hostigar y alterná acciones de presión con protección de recursos y descanso. Esperar pasivamente permite sostener la invasión.",16)
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
 get_tree().quit(0 if rules.state.status=="victory" else 2)

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
 get_tree().quit()
