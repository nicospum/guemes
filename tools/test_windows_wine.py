"""Prueba el EXE de Windows en Wine, sin presentar Wine como Windows nativo.

Uso: xvfb-run -a -s '-screen 0 1440x900x24' python tools/test_windows_wine.py
  --binary builds/windows/PatriaGuemes.exe --prefix /ruta/prefix-aislado
  --output evidence/windows-wine

Requiere Wine 64-bit y una pantalla gráfica. No instala componentes.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", required=True)
    parser.add_argument("--prefix", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--wine", default="/usr/lib/wine/wine64")
    parser.add_argument("--scenarios", default="justine,norte")
    args = parser.parse_args()
    binary = Path(args.binary).resolve(strict=True)
    prefix = Path(args.prefix).resolve()
    output = Path(args.output).resolve()
    prefix.mkdir(parents=True, exist_ok=True)
    output.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env.update(WINEPREFIX=str(prefix), WINEARCH="win64", WINEDEBUG="-all",
               WINEDLLOVERRIDES="mscoree,mshtml=", GODOT_SILENCE_ROOT_WARNING="1")
    env.pop("TYPESAFE_API_KEY", None)
    started = utc_now()
    probe = subprocess.run([args.wine, "cmd", "/c", "set", "APPDATA"],
                           env=env, capture_output=True, text=True, timeout=120)
    (output / "wine-initialization.log").write_text(probe.stdout + probe.stderr, encoding="utf-8")
    appdata = next((line.split("=", 1)[1].strip() for line in probe.stdout.splitlines()
                   if line.upper().startswith("APPDATA=")), "")
    if probe.returncode or not appdata.lower().startswith("c:\\"):
        raise RuntimeError("No se pudo obtener APPDATA dentro del prefijo aislado de Wine.")
    data = prefix / "drive_c" / Path(appdata[3:].replace("\\", "/")) / "Godot" / "app_userdata" / "Güemes — Juegos de la Patria"
    data.mkdir(parents=True, exist_ok=True)
    (data / "settings.cfg").write_text('[preferences]\nquality="baja"\nmuted=true\njev_local=true\n', encoding="utf-8")
    summary = {"scope": "Windows x64 executable run under Wine on Linux; not native Windows",
               "binary": binary.name, "binary_bytes": binary.stat().st_size,
               "binary_sha256": hashlib.sha256(binary.read_bytes()).hexdigest(),
               "wine_version": subprocess.check_output([args.wine, "--version"], env=env, text=True).strip(),
               "started_at_utc": started, "native_windows_tested": False,
               "resolution": "1440x900", "quality": "baja", "audio_driver": "Dummy",
               "input": "automated scene methods; OS input tested separately on Linux",
               "scenarios": []}
    for scenario in args.scenarios.split(","):
        if scenario not in ("justine", "norte"):
            raise ValueError("Escenario desconocido: " + scenario)
        target = output / scenario
        target.mkdir(parents=True, exist_ok=True)
        wine_target = "Z:" + str(target).replace("/", "\\")
        command = [args.wine, str(binary), "--resolution", "1440x900", "--audio-driver", "Dummy",
                   "--", "--qa=" + scenario, "--qa-path=" + wine_target]
        print("Windows/Wine QA:", scenario, flush=True)
        start = time.monotonic()
        with (target / "execution.log").open("w", encoding="utf-8") as log:
            result = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=360)
        report_path = target / (scenario + "-render-report.json")
        report = json.loads(report_path.read_text(encoding="utf-8")) if report_path.exists() else {}
        item = {"scenario": scenario, "exit_code": result.returncode,
                "wall_seconds": round(time.monotonic() - start, 3),
                "report_present": report_path.exists(), "status": report.get("status"),
                "os_reported_by_engine": report.get("os"), "quality": report.get("quality"),
                "passed": result.returncode == 0 and report.get("status") == "victory"}
        summary["scenarios"].append(item)
        print(json.dumps(item, ensure_ascii=False), flush=True)
        summary["finished_at_utc"] = utc_now()
        (output / "windows-wine-summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    return 0 if all(item["passed"] for item in summary["scenarios"]) else 2


if __name__ == "__main__":
    sys.exit(main())
