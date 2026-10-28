"""Corre tools/bench_gpu.gd para todos los perfiles y escenarios (ventana 1440x900, V-Sync apagado).
python tools/bench_gpu_matrix.py --godot <Godot.exe> --out evidence/fase2/render/gpu_fplus [--renderer gl_compatibility]"""
import argparse,os,pathlib,subprocess,json
p=argparse.ArgumentParser();p.add_argument("--godot",required=True);p.add_argument("--out",required=True);p.add_argument("--renderer",default="");p.add_argument("--repeat",type=int,default=2)
a=p.parse_args()
root=pathlib.Path(__file__).resolve().parents[1];out=pathlib.Path(a.out).resolve();out.mkdir(parents=True,exist_ok=True)
env=os.environ.copy();ad=out/"_appdata";ad.mkdir(exist_ok=True);env["APPDATA"]=str(ad)
rows=[]
for sc in ["justine","norte"]:
 for q in ["baja","media","alta"]:
  res=[]
  for r in range(a.repeat):
   f=out/(sc+"-"+q+"-r"+str(r+1)+".json")
   cmd=[a.godot,"--path",str(root),"--disable-vsync","--resolution","1440x900","--audio-driver","Dummy"]
   if a.renderer:cmd+=["--rendering-method",a.renderer]
   cmd+=["--script","tools/bench_gpu.gd","--","--scenario="+sc,"--quality="+q,"--out="+str(f)]
   subprocess.run(cmd,env=env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=300)
   res.append(json.loads(f.read_text()))
  m=lambda k:round(sum(x[k] for x in res)/len(res),3)
  row={"scenario":sc,"quality":q,"method":res[0]["rendering_method"],"mean_fps":round(m("mean_fps"),1),"gpu_ms":m("gpu_ms_median"),"wall_ms":m("wall_ms_median"),"wall_p99":m("wall_ms_p99"),"draw_calls":res[0]["draw_calls"],"primitives":res[0]["primitives"]}
  print(json.dumps(row),flush=True);rows.append(row)
(out/"resumen.json").write_text(json.dumps(rows,indent=2))
