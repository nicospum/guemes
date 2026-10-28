extends SceneTree
## Recorridos completos (pista qa) contra la escena main real, con ventana y GPU. No es una partida humana:
## las ordenes se emiten por metodos/botones de la UI y el tiempo tactico se acelera con _process(dt).
var game:Node
var log_rows:Array=[]
var outdir:="res://evidence/fase2/qa/journeys"

func _initialize():
	call_deferred("_run")

func rec(name:String,ok:bool,detail:Dictionary):
	detail["journey"]=name;detail["ok"]=ok
	log_rows.append(detail)
	print("JOURNEY ",JSON.stringify(detail))

func shot(n:String):
	await RenderingServer.frame_post_draw
	var img=root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(outdir))
	img.save_png(ProjectSettings.globalize_path(outdir)+"/"+n+".png")

func find_button(part:String,node:Node=null)->Button:
	if node==null:node=game
	if node is Button and part in (node as Button).text:return node
	for c in node.get_children():
		var r=find_button(part,c)
		if r:return r
	return null

func press(part:String)->bool:
	var b=find_button(part)
	if b==null or b.disabled:return false
	b.pressed.emit();return true

func key(code:Key):
	var e=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=true
	Input.parse_input_event(e);game._input(e)

func fresh(sc:String):
	game._start_game(sc);game.jev.force_local=true
	await process_frame

func justine(name:String,route:String,t0:float,dt:float=4.0):
	await fresh("justine")
	game._select_unit("all")
	game.paused=false
	var frames=0;var samples=[];var issued=false;var wall0=Time.get_ticks_msec()
	while game.rules.state.status=="playing" and frames<2000:
		if not issued and float(game.rules.state.elapsed)>=t0:
			issued=true
			if route!="":game._tactical_order(route)
		var b=Time.get_ticks_usec()
		game._process(dt)
		await process_frame
		samples.append((Time.get_ticks_usec()-b)/1000.0);frames+=1
	game._process(0.0);await process_frame;await process_frame
	samples.sort()
	var st=str(game.rules.state.status)
	var modal_ok=game.outcome_shown and is_instance_valid(game.modal)
	await shot("justine-"+name)
	rec(name,true,{"scenario":"justine","route":route,"order_at_sim_s":t0,"status":st,"capture":snapped(float(game.rules.state.capture),0.1),"sim_elapsed_s":float(game.rules.state.elapsed),"frames":frames,"wall_s":(Time.get_ticks_msec()-wall0)/1000.0,"frame_ms_median":samples[samples.size()/2],"frame_ms_p95":samples[int(samples.size()*0.95)],"frame_ms_max":samples[-1],"outcome_ui":modal_ok,"has_replay_button":find_button("Volver a jugar")!=null,"has_north_button":find_button("Ir a la campaña del norte")!=null,"reason":str(game.rules.state.reason)})

func norte(name:String,passive:bool):
	await fresh("norte")
	var wall0=Time.get_ticks_msec();var samples=[];var rounds=0
	while game.rules.state.status=="playing" and rounds<20:
		if not passive:game._qa_campaign_orders()
		game._resolve_round()
		for i in range(8):
			var b=Time.get_ticks_usec()
			game._process(0.25)
			await process_frame
			samples.append((Time.get_ticks_usec()-b)/1000.0)
		game.resolution_remaining=0
		rounds+=1
	game._process(0.0);await process_frame;await process_frame
	samples.sort()
	await shot("norte-"+name)
	rec(name,true,{"scenario":"norte","passive":passive,"status":str(game.rules.state.status),"round":int(game.rules.state.round),"rounds_resolved":rounds,"decisions":game.rules.state.external_decisions.size(),"decision_sources":game.rules.state.external_decisions.map(func(d):return d.source).slice(0,2),"wall_s":(Time.get_ticks_msec()-wall0)/1000.0,"frame_ms_median":samples[samples.size()/2],"frame_ms_p95":samples[int(samples.size()*0.95)],"outcome_ui":game.outcome_shown and is_instance_valid(game.modal),"has_replay_button":find_button("Volver a jugar")!=null,"reason":str(game.rules.state.reason)})

func pos_snapshot()->Array:
	var a=[]
	for u in game.rules.state.units:a.append([snapped(float(u.x),0.001),snapped(float(u.z),0.001),snapped(float(u.strength),0.001)])
	return a

func play_rounds(n:int):
	for r in range(n):
		if game.rules.state.status!="playing":break
		game._qa_campaign_orders();game._resolve_round()
		for i in range(8):
			game._process(0.25);await process_frame
		game.resolution_remaining=0

func saveload():
	await fresh("justine");game._select_unit("all");game._tactical_order("direct");game.paused=false
	for i in range(40):
		game._process(4.0);await process_frame
	var el0=float(game.rules.state.elapsed);var cap0=float(game.rules.state.capture);var pos0=pos_snapshot()
	key(KEY_F5);await process_frame
	var saved=FileAccess.file_exists(game._save_path("justine"))
	for i in range(30):
		game._process(4.0);await process_frame
	var el1=float(game.rules.state.elapsed)
	key(KEY_F9);await process_frame;await process_frame
	var pos1=pos_snapshot()
	var same=(pos0==pos1) and is_equal_approx(float(game.rules.state.elapsed),el0) and is_equal_approx(float(game.rules.state.capture),cap0)
	game.paused=false
	var f=0
	while game.rules.state.status=="playing" and f<1500:
		game._process(4.0);await process_frame;f+=1
	var st_after=str(game.rules.state.status)
	var rbtn=press("Volver a jugar");await process_frame;await process_frame
	var reset=rbtn and game.rules.state.status=="playing" and float(game.rules.state.capture)==0.0 and float(game.rules.state.elapsed)==0.0
	rec("justine-guardar-cargar-reiniciar",saved and same and reset,{"saved_file":saved,"elapsed_saved":el0,"elapsed_before_load":el1,"state_restored_equal":same,"outcome_after_load":st_after,"restart_R_clean":reset})
	await fresh("norte")
	await play_rounds(3)
	var round_saved=int(game.rules.state.round);var sup0=float(game.rules.get_unit("arias").supply)
	game._save_game(false)
	game._qa_campaign_orders()
	game.rules.get_unit("arias").supply=1.0
	var round_before=int(game.rules.state.round)
	key(KEY_F9);await process_frame;await process_frame
	var round_after=int(game.rules.state.round)
	var ok_n=round_after==round_saved and not is_equal_approx(1.0,float(game.rules.get_unit("arias").supply)) and is_equal_approx(float(game.rules.get_unit("arias").supply),sup0)
	await play_rounds(20)
	game._process(0.0);await process_frame;await process_frame
	var final_status=str(game.rules.state.status)
	var btn=press("Volver a jugar");await process_frame
	var reset_n=btn and game.rules.state.status=="playing" and int(game.rules.state.round)==1
	rec("norte-guardar-cargar-reiniciar",ok_n and reset_n,{"round_saved":round_saved,"round_before_load":round_before,"round_after_load":round_after,"state_restored":ok_n,"outcome_after_load":final_status,"replay_button_resets":reset_n})

func _run():
	var scene=load("res://scenes/main.tscn") as PackedScene
	game=scene.instantiate();root.add_child(game)
	await process_frame;await process_frame
	var t0=Time.get_ticks_msec()
	await justine("direct-victoria","direct",0.0)
	await justine("flank-victoria","flank",0.0)
	await justine("pasivo-derrota","",0.0)
	for t in [400.0,600.0,700.0,800.0]:
		await justine("direct-tarde-%d"%int(t),"direct",t)
		await justine("flank-tarde-%d"%int(t),"flank",t)
	await norte("victoria-ordenes-QA",false)
	await norte("derrota-pasividad",true)
	await saveload()
	var f=FileAccess.open(ProjectSettings.globalize_path(outdir)+"/journeys.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(log_rows,"\t"));f.close()
	print("JOURNEYS_DONE total_s=",(Time.get_ticks_msec()-t0)/1000.0)
	game.queue_free();await process_frame
	quit()
