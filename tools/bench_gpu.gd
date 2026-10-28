extends SceneTree
## Medición con tiempos de GPU y CPU del propio motor (600 cuadros, 60 de calentamiento).
## Uso: godot --path . --disable-vsync --resolution 1440x900 --script tools/bench_gpu.gd -- --scenario=justine --quality=media --out=ruta.json
func _initialize():
 var scenario="justine";var quality="media";var out=""
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--scenario="):scenario=a.trim_prefix("--scenario=")
  if a.begins_with("--quality="):quality=a.trim_prefix("--quality=")
  if a.begins_with("--out="):out=a.trim_prefix("--out=")
 var main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 await process_frame
 main.settings.quality=quality
 main._start_game(scenario)
 if scenario=="justine":
  for unit in main.rules.state.units:main.rules.issue_order(str(unit.id),"flank")
  for i in range(170):main.rules.tick(1.0)
  main.paused=false
 var vp=root.get_viewport().get_viewport_rid()
 RenderingServer.viewport_set_measure_render_time(vp,true)
 for i in range(60):await process_frame
 var wall=[];var gpu=[];var cpu=[]
 var t0=Time.get_ticks_usec()
 for i in range(600):
  var b=Time.get_ticks_usec()
  await process_frame
  wall.append((Time.get_ticks_usec()-b)/1000.0)
  gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
  cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp))
 var total=(Time.get_ticks_usec()-t0)/1e6
 wall.sort();gpu.sort();cpu.sort()
 var info={"scenario":scenario,"quality":quality,"rendering_method":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"viewport":str(root.get_visible_rect().size),"frames":600,"seconds":total,"mean_fps":600.0/total,"wall_ms_median":wall[300],"wall_ms_p99":wall[594],"gpu_ms_median":gpu[300],"gpu_ms_p99":gpu[594],"cpu_ms_median":cpu[300],"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)}
 print(JSON.stringify(info))
 if out!="":
  var f=FileAccess.open(out,FileAccess.WRITE);f.store_string(JSON.stringify(info,"\t"));f.close()
 quit()
