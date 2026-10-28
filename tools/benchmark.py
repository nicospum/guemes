"""Medición reproducible de la exportación Linux; sin cargas gráficas concurrentes."""
import argparse,os,pathlib,subprocess,time,json,shutil,hashlib,datetime
p=argparse.ArgumentParser();p.add_argument("--binary",required=True);p.add_argument("--output",required=True);p.add_argument("--profiles",default="baja,media");p.add_argument("--scenarios",default="justine,norte");args=p.parse_args()
root=pathlib.Path(__file__).resolve().parents[1];out=pathlib.Path(args.output).resolve();out.mkdir(parents=True,exist_ok=True)
binary=pathlib.Path(args.binary).resolve(strict=True)
binary_hash=hashlib.sha256(binary.read_bytes()).hexdigest()
env=os.environ.copy()
for k,n in [("XDG_DATA_HOME","benchmark-data"),("XDG_CONFIG_HOME","benchmark-config"),("XDG_CACHE_HOME","cache")]:
 d=root.parent/".runtime"/n;d.mkdir(parents=True,exist_ok=True);env[k]=str(d)
env["GODOT_SILENCE_ROOT_WARNING"]="1"
for scenario in args.scenarios.split(","):
 for quality in args.profiles.split(","):
  cmd=["xvfb-run","-a","-s","-screen 0 1440x900x24",str(binary),"--resolution","1440x900","--audio-driver","Dummy","--","--benchmark="+scenario,"--quality="+quality,"--qa-path="+str(out)]
  timing_path=out/(scenario+"-"+quality+"-time.txt")
  if shutil.which("time"):cmd[4:4]=[shutil.which("time"),"-v","-o",str(timing_path)]
  print("Benchmark",scenario,quality,flush=True)
  started=datetime.datetime.now(datetime.timezone.utc).isoformat()
  peak=0
  with open(out/(scenario+"-"+quality+".log"),"w") as log:
   process=subprocess.Popen(cmd,env=env,stdout=log,stderr=subprocess.STDOUT)
   while process.poll() is None:
    pending=[process.pid]
    while pending:
     pid=pending.pop()
     try:
      base=pathlib.Path("/proc")/str(pid)
      pending.extend(int(x) for x in (base/"task"/str(pid)/"children").read_text().split())
      if "Xvfb" not in (base/"comm").read_text() and "xvfb" not in (base/"comm").read_text():
       for line in (base/"status").read_text().splitlines():
        if line.startswith("VmRSS:"):peak=max(peak,int(line.split()[1])*1024)
     except (OSError,ValueError):pass
    time.sleep(.25)
  report_path=out/(scenario+"-"+quality+"-benchmark.json")
  if process.returncode or not report_path.exists():raise SystemExit("Benchmark failed "+str(process.returncode))
  if timing_path.exists():
   for line in timing_path.read_text().splitlines():
    if "Maximum resident set size (kbytes):" in line:peak=int(line.split(":")[-1].strip())*1024
  report=json.loads(report_path.read_text());report["observed_process_peak_rss_bytes"]=peak
  report.update(binary_sha256=binary_hash,binary_bytes=binary.stat().st_size,run_started_utc=started,run_finished_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
  report_path.write_text(json.dumps(report,indent=2))
  print(json.dumps({k:report[k] for k in ["scenario","quality","mean_fps","frame_ms_median","frame_ms_p95","observed_process_peak_rss_bytes","scene_build_ms"]}),flush=True)
