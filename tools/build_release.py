#!/usr/bin/env python3
"""Import and export Patria Guemes with Godot 4.7.2. Python stdlib only.

This script never downloads tools, installs packages, or starts the exported game.
Existing export presets are restored byte-for-byte after temporary template paths.
"""
from __future__ import annotations

import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
PRESETS = ROOT / "export_presets.cfg"
VERSION_FILE = ROOT / "VERSION.json"
PROJECT_FILE = ROOT / "project.godot"
# Campos de VERSION.json que describen el EXE ya construido. Un archivo embebido en el EXE
# no puede contener el hash ni el tamano de su propio contenedor, y cualquier valor previo
# seria de otra construccion: se omiten y constan solo en el VERSION.json de la entrega.
BUILD_RESULT_KEYS = ("windows_bytes", "windows_sha256", "windows_exe_smoke_test")
REQUIRED_VERSION = "4.7.2"
TARGETS = {
    "windows": {
        "platforms": {"Windows Desktop"},
        "output": "PatriaGuemes.exe",
        "release": "windows_release_x86_64.exe",
        "debug": "windows_debug_x86_64.exe",
        "magic": b"MZ",
    },
    "linux": {
        "platforms": {"Linux", "Linux/X11"},
        "output": "PatriaGuemes.x86_64",
        "release": "linux_release.x86_64",
        "debug": "linux_debug.x86_64",
        "magic": b"\x7fELF",
    },
}


class BuildError(Exception):
    pass


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def executable_path(value: str | None) -> Path:
    if value:
        expanded = os.path.expandvars(os.path.expanduser(value))
        candidate = Path(expanded)
        if candidate.is_file():
            return candidate.resolve()
        found = shutil.which(expanded)
        if found:
            return Path(found).resolve()
        raise BuildError(
            f"No se encontró el ejecutable de Godot: {value!r}. "
            "Pasá solo la ruta del editor con --godot; no agregues flags dentro de ella."
        )
    for name in (
        "godot", "godot4", "Godot_v4.7.2-stable_win64_console.exe",
        "Godot_v4.7.2-stable_win64.exe",
    ):
        found = shutil.which(name)
        if found:
            return Path(found).resolve()
    raise BuildError(
        "No se encontró Godot. Indicá --godot <ruta> o la variable GODOT_BIN. "
        "Se requiere el editor 4.7.2 estable, no una plantilla de exportación."
    )


def capture(args: list[str]) -> str:
    try:
        result = subprocess.run(
            args, cwd=ROOT, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace",
            check=False, timeout=30,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise BuildError(f"No se pudo consultar Godot: {exc}") from exc
    if result.returncode:
        raise BuildError(f"Godot devolvió {result.returncode}:\n{result.stdout.strip()}")
    return result.stdout


def check_editor(godot: Path) -> str:
    output = capture([str(godot), "--version"])
    match = re.search(r"(?m)^(4\.7\.2\.stable(?:\.[^\r\n]*)?)\s*$", output)
    if not match:
        raise BuildError(
            f"Esta versión del proyecto requiere Godot {REQUIRED_VERSION} estable. "
            f"El ejecutable informó: {output.strip()!r}. No se modificó el proyecto."
        )
    help_text = capture([str(godot), "--help"])
    if "--export-release" not in help_text or "--import" not in help_text:
        raise BuildError(
            "El ejecutable tiene la versión esperada pero no expone las herramientas "
            "de exportación del editor. Usá el editor Godot, no el runtime del juego."
        )
    return match.group(1).strip()


def sections(text: str):
    matches = list(re.finditer(r"(?m)^\[([^\]\r\n]+)\][ \t]*\r?$", text))
    for index, match in enumerate(matches):
        end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        yield match.group(1), match.start(), match.end(), end


def config_string(body: str, key: str) -> str:
    match = re.search(r"(?m)^" + re.escape(key) + r"[ \t]*=[ \t]*(\"[^\r\n]*\")[ \t]*\r?$", body)
    if not match:
        raise BuildError(f"Falta una propiedad de texto válida {key!r} en export_presets.cfg.")
    try:
        value = json.loads(match.group(1))
    except json.JSONDecodeError as exc:
        raise BuildError(f"No se pudo leer {key!r} en export_presets.cfg: {exc}") from exc
    if not isinstance(value, str):
        raise BuildError(f"La propiedad {key!r} debe ser texto.")
    return value


def choose_presets(text: str, targets: list[str]) -> dict[str, dict[str, str]]:
    candidates = []
    for section, start, body_start, end in sections(text):
        if re.fullmatch(r"preset\.\d+", section):
            body = text[body_start:end]
            candidates.append({
                "section": section, "name": config_string(body, "name"),
                "platform": config_string(body, "platform"),
            })
    chosen = {}
    for target in targets:
        matches = [item for item in candidates if item["platform"] in TARGETS[target]["platforms"]]
        if len(matches) != 1:
            names = ", ".join(item["name"] for item in matches) or "ninguno"
            raise BuildError(
                f"Se necesita un único preset para {target}; encontrados: {names}. "
                "Revisá export_presets.cfg antes de exportar."
            )
        chosen[target] = matches[0]
    return chosen


def templates_directory(value: str, targets: list[str]) -> Path:
    base = Path(os.path.expandvars(os.path.expanduser(value))).resolve()
    candidates = [base, base / "templates", base / "4.7.2.stable"]
    folder = next((p for p in candidates if p.is_dir() and
                   all((p / TARGETS[t]["release"]).is_file() for t in targets)), None)
    if folder is None:
        expected = ", ".join(TARGETS[t]["release"] for t in targets)
        raise BuildError(
            f"No se encontraron las plantillas release en {base}. Se necesitan: {expected}. "
            "--templates recibe una carpeta extraída, no un archivo .tpz."
        )
    version_file = folder / "version.txt"
    if not version_file.is_file():
        raise BuildError(
            f"Falta {version_file}. Usá la carpeta de plantillas oficiales extraída "
            "completa, incluido su version.txt, para comprobar la versión."
        )
    version = version_file.read_text(encoding="utf-8-sig").strip()
    if version != "4.7.2.stable":
        raise BuildError(f"Plantillas incompatibles: {version!r}; se requiere '4.7.2.stable'.")
    return folder


def patch_options(text: str, section: str, values: dict[str, str]) -> str:
    newline = "\r\n" if "\r\n" in text else "\n"
    found = next((s for s in sections(text) if s[0] == section), None)
    if found is None:
        tail = newline.join(f"{key}={json.dumps(value, ensure_ascii=False)}" for key, value in values.items())
        return text.rstrip("\r\n") + newline * 2 + f"[{section}]" + newline + tail + newline
    _, start, body_start, end = found
    body = text[body_start:end]
    for key, value in values.items():
        assignment = f"{key}={json.dumps(value, ensure_ascii=False)}"
        pattern = r"(?m)^" + re.escape(key) + r"[ \t]*=[^\r\n]*"
        if re.search(pattern, body):
            body = re.sub(pattern, lambda match: assignment, body, count=1)
        else:
            body = body.rstrip("\r\n") + newline + assignment + newline * 2
    return text[:body_start] + body + text[end:]


def project_version() -> str:
    match = re.search(r'(?m)^config/version="([^"\r\n]+)"', PROJECT_FILE.read_text(encoding="utf-8-sig"))
    if not match:
        raise BuildError("project.godot no declara config/version.")
    return match.group(1)


def vcs_output(*args: str) -> str:
    try:
        result = subprocess.run(["git", *args], cwd=ROOT, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, text=True, encoding="utf-8", errors="replace",
                                check=False, timeout=30)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise BuildError(f"No se pudo consultar el control de versiones: {exc}") from exc
    if result.returncode:
        raise BuildError(f"git {' '.join(args)} fallo: {result.stderr.strip()}")
    return result.stdout.strip()


def embedded_version(godot_version: str, targets: list[str]) -> dict:
    """VERSION.json que viaja dentro del EXE: describe esta construccion, no una anterior.

    Parte del VERSION.json versionado (estado, banderas de verificacion, motor) y lo
    corrige con lo que este proceso comprueba: la version de project.godot, el commit
    exacto desde el que se exporta y si el arbol tenia cambios sin commitear.
    """
    base = json.loads(VERSION_FILE.read_text(encoding="utf-8-sig")) if VERSION_FILE.is_file() else {}
    for key in BUILD_RESULT_KEYS:
        base.pop(key, None)
    declared = base.get("version")
    actual = project_version()
    if declared is not None and declared != actual:
        raise BuildError(
            f"VERSION.json declara {declared!r} pero project.godot declara {actual!r}. "
            "Corregí la incoherencia antes de construir."
        )
    commit = vcs_output("rev-parse", "HEAD")
    dirty = bool(vcs_output("status", "--porcelain", "--untracked-files=no"))
    base.update({
        "version": actual,
        "runtime_source_commit": commit,
        "runtime_source_commit_short": commit[:7],
        "build_tree_dirty": dirty,
        "engine_build": godot_version,
        "build_targets": targets,
        "built_utc": utc_now(),
        "embedded_in_build": True,
        "embedded_note": "Describe esta construccion. El tamano y el SHA-256 del ejecutable no pueden "
                         "estar dentro de si mismo: constan en el VERSION.json de la entrega.",
    })
    return base


@contextmanager
def temporary_version(content: dict):
    """Sustituye VERSION.json durante la exportacion y restaura sus bytes originales."""
    replacement = (json.dumps(content, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    original = VERSION_FILE.read_bytes() if VERSION_FILE.is_file() else None
    backup = VERSION_FILE.with_name(VERSION_FILE.name + ".build_release.bak")
    if original is not None:
        try:
            with backup.open("xb") as file:
                file.write(original)
        except FileExistsError as exc:
            raise BuildError(
                f"Ya existe {backup.name}, posiblemente por una interrupcion anterior. "
                "Recuperá VERSION.json desde esa copia antes de reintentar."
            ) from exc
    try:
        VERSION_FILE.write_bytes(replacement)
        yield
    finally:
        if original is None:
            VERSION_FILE.unlink(missing_ok=True)
        else:
            VERSION_FILE.write_bytes(original)
            backup.unlink()
        print("VERSION.json restaurado a sus bytes originales.", flush=True)


@contextmanager
def temporary_presets(original: bytes, replacement: bytes):
    if replacement == original:
        yield
        return
    backup = PRESETS.with_name(PRESETS.name + ".build_release.bak")
    try:
        with backup.open("xb") as file:
            file.write(original)
    except FileExistsError as exc:
        raise BuildError(
            f"Ya existe {backup.name}, posiblemente por una interrupción anterior. "
            "Compará esa copia con export_presets.cfg y recuperá el original antes de reintentar."
        ) from exc
    try:
        PRESETS.write_bytes(replacement)
        yield
    finally:
        # Preserve an unexpected concurrent edit as well as the original config.
        current = PRESETS.read_bytes() if PRESETS.exists() else None
        if current not in (None, replacement, original):
            stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
            concurrent = PRESETS.with_name(PRESETS.name + f".concurrent-{stamp}.bak")
            concurrent.write_bytes(current)
            print(f"Se conservó también una edición concurrente en {concurrent.name}.", file=sys.stderr)
        PRESETS.write_bytes(original)
        backup.unlink()
        print("export_presets.cfg restaurado a sus bytes originales.", flush=True)


def run_logged(args: list[str], log_path: Path) -> None:
    print("Ejecutando: " + subprocess.list2cmdline(args), flush=True)
    fatal = False
    proc = None
    with log_path.open("w", encoding="utf-8", newline="\n") as log:
        log.write("# " + json.dumps(args, ensure_ascii=False) + "\n")
        log.flush()
        try:
            proc = subprocess.Popen(
                args, cwd=ROOT, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace",
                bufsize=1,
            )
            assert proc.stdout is not None
            for line in proc.stdout:
                print(line, end="", flush=True)
                log.write(line)
                if re.match(r"\s*(?:SCRIPT ERROR:|ERROR:|Parse Error:)", line):
                    fatal = True
            returncode = proc.wait()
        finally:
            if proc is not None and proc.poll() is None:
                proc.terminate()
                try:
                    proc.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.wait()
    if returncode != 0 or fatal:
        raise BuildError(
            f"Godot no completó este paso (código {returncode}, errores registrados: {fatal}). "
            f"Revisá {log_path.relative_to(ROOT)}."
        )


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as file:
        for block in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Importar y exportar Güemes con Godot 4.7.2 estable.")
    parser.add_argument("--godot", help="Ruta al editor Godot; alternativa: variable GODOT_BIN o PATH.")
    parser.add_argument("--templates", help="Carpeta extraída de las plantillas oficiales 4.7.2.stable, con version.txt.")
    parser.add_argument("--target", choices=("windows", "linux", "all"), default="windows",
                        help="Destino de exportación (por defecto: windows).")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not (ROOT / "project.godot").is_file() or not PRESETS.is_file():
        raise BuildError("No se encontró project.godot o export_presets.cfg junto al proyecto.")
    godot = executable_path(args.godot or os.environ.get("GODOT_BIN"))
    version = check_editor(godot)
    targets = ["windows", "linux"] if args.target == "all" else [args.target]
    original = PRESETS.read_bytes()
    text = original.decode("utf-8-sig")
    chosen = choose_presets(text, targets)
    folder = templates_directory(args.templates, targets) if args.templates else None
    if folder:
        for target in targets:
            release = folder / TARGETS[target]["release"]
            debug = folder / TARGETS[target]["debug"]
            text = patch_options(text, chosen[target]["section"] + ".options", {
                "custom_template/release": release.as_posix(),
                "custom_template/debug": debug.as_posix() if debug.is_file() else "",
            })
    replacement = text.encode("utf-8") if folder else original
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    logs = ROOT / "builds" / "logs" / stamp
    logs.mkdir(parents=True, exist_ok=False)
    embedded = embedded_version(version, targets)
    report = {
        "embedded_version": {key: embedded[key] for key in
                             ("version", "runtime_source_commit", "build_tree_dirty")},
        "started_utc": utc_now(), "godot_version": version, "godot_executable": str(godot),
        "templates": str(folder) if folder else "preset o ubicación estándar de Godot",
        "host": sys.platform, "requested_targets": targets, "status": "running", "exports": [],
        "native_execution_tested": False,
        "note": "Este proceso importa y exporta. No ejecuta ni mide los juegos resultantes.",
    }
    report_path = logs / "build-report.json"
    print(f"Godot {version}; destino: {', '.join(targets)}", flush=True)
    try:
        with temporary_presets(original, replacement), temporary_version(embedded):
            run_logged([str(godot), "--headless", "--path", str(ROOT), "--editor", "--import"], logs / "import.log")
            for target in targets:
                output = ROOT / "builds" / target / TARGETS[target]["output"]
                output.parent.mkdir(parents=True, exist_ok=True)
                run_logged([str(godot), "--headless", "--path", str(ROOT), "--export-release",
                            chosen[target]["name"], str(output)], logs / f"export-{target}.log")
                if not output.is_file() or output.stat().st_size == 0:
                    raise BuildError(f"Godot finalizó pero falta el archivo esperado: {output}")
                with output.open("rb") as file:
                    if not file.read(4).startswith(TARGETS[target]["magic"]):
                        raise BuildError(f"El archivo exportado no tiene la cabecera esperada para {target}: {output}")
                if target == "linux" and os.name != "nt":
                    output.chmod(output.stat().st_mode | 0o111)
                report["exports"].append({
                    "target": target, "preset": chosen[target]["name"],
                    "output": output.relative_to(ROOT).as_posix(),
                    "bytes": output.stat().st_size, "sha256": sha256(output), "status": "exported",
                })
                print(f"Exportado: {output.relative_to(ROOT)} ({output.stat().st_size:,} bytes)", flush=True)
        report["status"] = "exported"
    except BaseException as exc:
        report["status"] = "interrupted" if isinstance(exc, (KeyboardInterrupt, SystemExit)) else "failed"
        report["error"] = str(exc) or type(exc).__name__
        raise
    finally:
        report["finished_utc"] = utc_now()
        report["presets_restored"] = PRESETS.read_bytes() == original if PRESETS.exists() else False
        report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"Registro: {report_path.relative_to(ROOT)}", flush=True)
    return 0


def terminate_requested(signum, frame):
    raise KeyboardInterrupt("Interrupción solicitada; se restaurará la configuración de exportación.")


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, terminate_requested)
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("Exportación interrumpida.", file=sys.stderr)
        sys.exit(130)
    except (BuildError, OSError, UnicodeError) as error:
        print(f"Error de construcción: {error}", file=sys.stderr)
        sys.exit(1)
