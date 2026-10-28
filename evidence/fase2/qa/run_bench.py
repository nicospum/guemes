"""Driver: lanza Godot con ventana, mide arranque (lanzamiento -> QA_READY), RSS maxima (psutil) y memoria GPU (nvidia-smi)."""
import subprocess,os,sys,time,json,pathlib,threading,psutil,statistics
root=pathlib.Path(__file__).resolve().parents[3]
godot=str(root/".tools/godot/Godot_v4.7.2-stable_win64_console.exe")
out=pathlib.Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
reps=int(sys.argv[2]) if len(sys.argv)>2 else 3
renderer=sys.argv[3] if len(sys.argv)>3 else ""
env=os.environ.copy();ad=out/"_appdata";ad.mkdir(exist_ok=True);env["APPDATA"]=str(ad)
rows=[]
for sc in ["justine","norte"]:
 for q in ["baja","media","alta"]:
  runs=[]
  for r in range(reps):
   f=out/f"{sc}-{q}-r{r+1}.json"
   cmd=[godot,"--path",str(root),"--disable-vsync","--resolution","1440x900","--audio-driver","Dummy"]
   if renderer:cmd+=["--rendering-method",renderer]
   cmd+=["--script","evidence/fase2/qa/bench_qa.gd","--","--scenario="+sc,"--quality="+q,"--out="+str(f)]
   t0=time.perf_counter()
   p=subprocess.Popen(cmd,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding="utf-8",errors="replace")
   ps=psutil.Process(p.pid);peak_ws=0;peak_priv=0;lines=[];t_ready=[None]
   def reader():
    for ln in p.stdout:
     lines.append(ln.rstrip())
     if "QA_READY" in ln and t_ready[0] is None:t_ready[0]=time.perf_counter()-t0
   th=threading.Thread(target=reader);th.start()
   gpu_peak=0;last_gpu=0
   while p.poll() is None:
    try:
     procs=[ps]+ps.children(recursive=True)
     ws=sum(x.memory_info().rss for x in procs);pv=sum(getattr(x.memory_full_info(),"uss",0) for x in procs)
     peak_ws=max(peak_ws,ws);peak_priv=max(peak_priv,pv)
    except Exception:pass
    if time.time()-last_gpu>3:
     last_gpu=time.time()
     try:
      o=subprocess.run(["nvidia-smi","--query-compute-apps=pid,used_memory","--format=csv,noheader,nounits"],capture_output=True,text=True,timeout=5).stdout
      for l in o.splitlines():
       a=l.split(",")
       if len(a)==2 and a[1].strip().isdigit():gpu_peak=max(gpu_peak,int(a[1]))
     except Exception:pass
    time.sleep(0.1)
   th.join();total=time.perf_counter()-t0
   (out/f"{sc}-{q}-r{r+1}.log").write_text("\n".join(lines),encoding="utf-8")
   if not f.exists():print("FALLO",sc,q,r,p.returncode);continue
   d=json.loads(f.read_text());d.update(exit_code=p.returncode,launch_to_ready_s=t_ready[0],process_total_s=total,peak_rss_mb=peak_ws/1048576,peak_uss_mb=peak_priv/1048576,gpu_mem_smi_mb_peak=gpu_peak,errors_in_log=[l for l in lines if "ERROR" in l or "SCRIPT ERROR" in l or "WARNING" in l][:10])
   f.write_text(json.dumps(d,indent=2));runs.append(d)
  if not runs:continue
  m=lambda k:round(statistics.mean(x[k] for x in runs),3)
  row={"scenario":sc,"quality":q,"n":len(runs),"method":runs[0]["rendering_method"],"fps_mean":m("mean_fps"),"fps_min":round(min(x["mean_fps"] for x in runs),1),"wall_med":m("wall_ms_median"),"p95":m("wall_ms_p95"),"p99":m("wall_ms_p99"),"max":m("wall_ms_max"),"gpu_med":m("gpu_ms_median"),"rss_mb":m("peak_rss_mb"),"uss_mb":m("peak_uss_mb"),"vram_smi_mb":m("gpu_mem_smi_mb_peak"),"vram_engine_mb":round(runs[0]["video_mem_bytes"]/1048576,1),"ready_s":m("launch_to_ready_s"),"build_ms":m("start_game_to_first_frame_ms"),"draws":runs[0]["draw_calls"],"prims":runs[0]["primitives"],"status_end":runs[0]["status_end"]}
  print(json.dumps(row),flush=True);rows.append(row)
(out/"resumen.json").write_text(json.dumps(rows,indent=2))
