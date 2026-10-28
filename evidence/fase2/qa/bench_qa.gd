extends SceneTree
## QA de rendimiento (pista qa): 120 cuadros de calentamiento explicito y 900 medidos, ventana real.
## godot --path . --disable-vsync --resolution 1440x900 --audio-driver Dummy --script evidence/fase2/qa/bench_qa.gd -- --scenario=justine --quality=media --out=x.json
func _initialize():
	var scenario="justine";var quality="media";var out=""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scenario="):scenario=a.trim_prefix("--scenario=")
		if a.begins_with("--quality="):quality=a.trim_prefix("--quality=")
		if a.begins_with("--out="):out=a.trim_prefix("--out=")
	var t_script_ms:=Time.get_ticks_msec()
	var main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.settings.quality=quality
	var t_build0:=Time.get_ticks_msec()
	main._start_game(scenario)
	await process_frame
	var t_first_ms:=Time.get_ticks_msec()
	if scenario=="justine":
		for unit in main.rules.state.units:main.rules.issue_order(str(unit.id),"flank")
		for i in range(170):main.rules.tick(1.0)
		main.paused=false
	print("QA_READY engine_ms=",t_first_ms," script_start_ms=",t_script_ms," start_game_to_first_frame_ms=",t_first_ms-t_build0)
	var vp=root.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp,true)
	for i in range(120):await process_frame
	var wall=[];var gpu=[];var cpu=[]
	var t0=Time.get_ticks_usec()
	for i in range(900):
		var b=Time.get_ticks_usec()
		await process_frame
		wall.append((Time.get_ticks_usec()-b)/1000.0)
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp))
	var total=(Time.get_ticks_usec()-t0)/1e6
	var ws=wall.duplicate();ws.sort();var gs=gpu.duplicate();gs.sort();var cs=cpu.duplicate();cs.sort()
	var over33:=0;var over16:=0
	for w in wall:
		if w>33.4:over33+=1
		if w>16.7:over16+=1
	var info={"scenario":scenario,"quality":quality,"rendering_method":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"viewport":str(root.get_visible_rect().size),"scaling_3d":root.scaling_3d_scale,"warmup_frames":120,"frames":900,"seconds":total,"mean_fps":900.0/total,
		"wall_ms_median":ws[450],"wall_ms_p95":ws[855],"wall_ms_p99":ws[891],"wall_ms_max":ws[899],"frames_over_16_7ms":over16,"frames_over_33_4ms":over33,
		"gpu_ms_median":gs[450],"gpu_ms_p95":gs[855],"gpu_ms_p99":gs[891],"cpu_render_ms_median":cs[450],
		"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"static_mem_bytes":OS.get_static_memory_usage(),"video_mem_bytes":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED),"texture_mem_bytes":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED),
		"status_end":str(main.rules.state.status),"engine_ms_at_ready":t_first_ms,"start_game_to_first_frame_ms":t_first_ms-t_build0}
	print("QA_RESULT ",JSON.stringify(info))
	if out!="":
		var f=FileAccess.open(out,FileAccess.WRITE);f.store_string(JSON.stringify(info,"\t"));f.close()
	quit()
