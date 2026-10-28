"""Benchmark reproducible del juego (Linux exportado bajo xvfb, o Windows/Linux con ventana real).

Linux (como en 0.1.0):
  python tools/benchmark.py --binary guemes.x86_64 --output salida
Windows con GPU (fuente del proyecto, ventana 1440x900, V-Sync apagado, repeticiones):
  python tools/benchmark.py --binary Godot_v4.7.2-stable_win64_console.exe --project . --output salida \
      --profiles baja,media,alta --repeat 3 --renderer forward_plus
Aísla user:// con APPDATA/XDG propios. Cada corrida usa el --benchmark= de main.gd (30 cuadros de calentamiento y 180 medidos);
se informa media, mediana y desvío entre repeticiones.
"""
import argparse,os,pathlib,subprocess,time,json,shutil,hashlib,datetime,statistics,sys
p=argparse.ArgumentParser()
p.add_argument("--binary",required=True);p.add_argument("--output",required=True)
p.add_argument("--profiles",default="baja,media");p.add_argument("--scenarios",default="justine,norte")
p.add_argument("--project",default="",help="Si se indica, se usa --path <project> (binario del editor/motor).")
p.add_argument("--renderer",default="",help="forward_plus | mobile | gl_compatibility (opcional).")
p.add_argument("--repeat",type=int,default=1);p.add_argument("--no-vsync",action="store_true",default=None)
p.add_argument("--vsync",action="store_true",help="Dejar V-Sync activo (por defecto se desactiva en Windows).")
args=p.parse_args()
root=pathlib.Path(__file__).resolve().parents[1];out=pathlib.Path(args.output).resolve();out.mkdir(parents=True,exist_ok=True)
binary=pathlib.Path(args.binary).resolve(strict=True)
binary_hash=hashlib.sha256(binary.read_bytes()).hexdigest()
windows=sys.platform.startswith("win")
env=os.environ.copy()
runtime=root.parent/".runtime"
if windows:
 d=out/"_appdata";d.mkdir(parents=True,exist_ok=True);env["APPDATA"]=str(d)
else:
 for k,n in [("XDG_DATA_HOME","benchmark-data"),("XDG_CONFIG_HOME","benchmark-config"),("XDG_CACHE_HOME","cache")]:
  d=runtime/n;d.mkdir(parents=True,exist_ok=True);env[k]=str(d)
env["GODOT_SILENCE_ROOT_WARNING"]="1"
summary=[]
for scenario in args.scenarios.split(","):
 for quality in args.profiles.split(","):
  runs=[]
  for rep in range(args.repeat):
   tag=scenario+"-"+quality+("" if args.repeat==1 else "-r"+str(rep+1))
   rep_dir=out/tag;rep_dir.mkdir(parents=True,exist_ok=True)
   cmd=[str(binary)]
   if args.project:cmd+=["--path",args.project]
   if args.renderer:cmd+=["--rendering-method",{"forward_plus":"forward_plus","mobile":"mobile","gl_compatibility":"gl_compatibility"}[args.renderer]]
   cmd+=["--resolution","1440x900","--audio-driver","Dummy"]
   if windows and not args.vsync:cmd+=["--disable-vsync"]
   cmd+=["--","--benchmark="+scenario,"--quality="+quality,"--qa-path="+str(rep_dir)]
   if not windows:
    cmd=["xvfb-run","-a","-s","-screen 0 1440x900x24"]+cmd
   print("Benchmark",tag,flush=True)
   started=datetime.datetime.now(datetime.timezone.utc).isoformat()
   with open(out/(tag+".log"),"w",encoding="utf-8",errors="replace") as log:
    process=subprocess.Popen(cmd,env=env,stdout=log,stderr=subprocess.STDOUT)
    process.wait()
   report_path=rep_dir/(scenario+"-"+quality+"-benchmark.json")
   if process.returncode or not report_path.exists():raise SystemExit("Benchmark failed "+str(process.returncode))
   report=json.loads(report_path.read_text(encoding="utf-8"))
   report.update(binary_sha256=binary_hash,binary_bytes=binary.stat().st_size,run_started_utc=started,run_finished_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),renderer_requested=args.renderer or "proyecto",vsync=bool(args.vsync or not windows))
   report_path.write_text(json.dumps(report,indent=2),encoding="utf-8")
   runs.append(report)
  fps=[r["mean_fps"] for r in runs]
  row={"scenario":scenario,"quality":quality,"repeat":len(runs),"mean_fps_mean":round(statistics.mean(fps),1),"mean_fps_min":round(min(fps),1),"mean_fps_max":round(max(fps),1),"frame_ms_median_mean":round(statistics.mean(r["frame_ms_median"] for r in runs),3),"frame_ms_p95_mean":round(statistics.mean(r["frame_ms_p95"] for r in runs),3),"scene_build_ms_mean":round(statistics.mean(r["scene_build_ms"] for r in runs),1),"renderer":runs[0]["renderer"],"viewport":runs[0]["viewport"]}
  print(json.dumps(row),flush=True);summary.append(row)
(out/"resumen.json").write_text(json.dumps(summary,indent=2),encoding="utf-8")
