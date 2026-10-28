"""Ejecuta el QA renderizado real. Requiere Godot 4.7.2 y, en Linux sin pantalla, Xvfb."""
import argparse,os,sys,subprocess,pathlib,shutil
p=argparse.ArgumentParser();p.add_argument("--engine",default=os.environ.get("GODOT_BIN","godot"));p.add_argument("--scenario",choices=["justine","norte"],default="justine");p.add_argument("--output");p.add_argument("--size",default="1440x900");args=p.parse_args()
root=pathlib.Path(__file__).resolve().parents[1];out=pathlib.Path(args.output).resolve() if args.output else root/"evidence"/args.scenario;out.mkdir(parents=True,exist_ok=True)
env=os.environ.copy();env["GODOT_SILENCE_ROOT_WARNING"]="1"
if sys.platform.startswith("linux"):
 runtime=root.parent/".runtime"
 for k,n in [("XDG_DATA_HOME","data"),("XDG_CONFIG_HOME","config"),("XDG_CACHE_HOME","cache")]:
  d=runtime/n;d.mkdir(parents=True,exist_ok=True);env[k]=str(d)
cmd=[args.engine,"--path",str(root),"--resolution",args.size,"--audio-driver","Dummy","--","--qa="+args.scenario,"--qa-path="+str(out)]
if sys.platform.startswith("linux") and not env.get("DISPLAY"):
 cmd=["xvfb-run","-a","-s","-screen 0 "+args.size+"x24"]+cmd
with open(out/"execution.log","w") as log:
 result=subprocess.run(cmd,env=env,stdout=log,stderr=subprocess.STDOUT)
print("QA exit",result.returncode,"evidence",out);sys.exit(result.returncode)
