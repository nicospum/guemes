"""Empaqueta el EXE, las fuentes y la evidencia de una revisión Git ya guardada.

No exporta ni ejecuta el juego. Requiere el EXE y su identidad REA ya verificados.
Uso: python tools/package_release.py --output /ruta/entrega
"""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_zip(target, entries, extras):
    with zipfile.ZipFile(target, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for source, name in entries:
            archive.write(source, name)
        for name, value in extras.items():
            archive.writestr(name, value)
    with zipfile.ZipFile(target) as archive:
        bad = archive.testzip()
        if bad:
            raise RuntimeError("ZIP inválido: " + bad)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    output = Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    status = subprocess.check_output(["git", "status", "--porcelain"], cwd=root, text=True)
    if status.strip():
        raise RuntimeError("Guardá todos los cambios de la entrega en Git antes de empaquetar.")
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
    binary = root / "builds/windows/PatriaGuemes.exe"
    identity = json.loads((root / "evidence/rea/PatriaGuemes-file-identity.json").read_text())
    if binary.stat().st_size != identity["bytes"] or sha256(binary) != identity["sha256"]:
        raise RuntimeError("El EXE no coincide con la evidencia REA de la entrega.")
    wine = json.loads((root / "evidence/windows-wine11/windows-wine-summary.json").read_text())
    if wine["binary_sha256"] != identity["sha256"] or {item["scenario"] for item in wine["scenarios"] if item["passed"]} != {"justine", "norte"}:
        raise RuntimeError("Los dos recorridos Wine no corresponden al EXE de la entrega.")
    version = {
        "project": "Güemes — Juegos de la Patria", "version": "0.1.0", "status": "playable_alpha",
        "source_snapshot_commit": revision, "runtime_source_commit": identity["source_commit"],
        "windows_executable": binary.name, "windows_bytes": binary.stat().st_size,
        "windows_sha256": identity["sha256"], "engine": "Godot 4.7.2 stable ed1daf0bf",
        "native_windows_tested": False, "jev_live_tested": False,
        "windows_wine_version": wine["wine_version"],
        "windows_wine_scenarios_passed": [item["scenario"] for item in wine["scenarios"] if item["passed"]],
        "verification": "docs/VERIFICACION.md",
    }
    version_text = json.dumps(version, ensure_ascii=False, indent=2) + "\n"
    quickstart = """GÜEMES — JUEGOS DE LA PATRIA · ALFA 0.1.0

1. Extraé toda esta carpeta en una ubicación propia.
2. Abrí PatriaGuemes.exe. No hace falta instalar el editor Godot.
3. Elegí Justine (tiempo real con pausa) o Sostener el norte (rondas).

JUSTINE: tecla 4 selecciona todas las agrupaciones. Elegí Banco directo
o Rodeo sur y pulsá Espacio para avanzar. El agua determina cuándo cruzar.
NORTE: seleccioná una agrupación, un sector y una orden. Resolver ronda
aplica las órdenes; proteger víveres y hostigar debilita la invasión.

CÁMARA: WASD/flechas, rueda, Q/E y botón central. 1/2/3 selecciona grupos.
F5 guarda, F9 carga, X cancela la orden, R reinicia, F1 muestra controles.
Ajustes permite cambiar detalle, ayudas y sonido. F11 cambia pantalla completa.

Los dos escenarios se completan sin una cuenta de TypeSafe. Para configurar
una clave propia sin ponerla en el código, consultá docs/CONFIGURAR_JEV_WINDOWS.md.

ESTADO: alfa 3D estilizada. La fidelidad cinematográfica y una decisión viva
de Jev siguen pendientes. No se verificó Windows nativo en la PC destino.
El resultado concreto del intento con Wine está en docs/VERIFICACION.md.
La meta de 30/60 FPS no se alcanzó en el servidor remoto sin GPU; sus cifras no
representan tu PC. El audio no fue evaluado auditivamente en ese servidor.

README.md amplía las instrucciones. docs/VERIFICACION.md detalla pruebas,
errores conocidos y límites. VERSION.json identifica el código y el EXE.
Las licencias del juego, Godot y tipografías acompañan esta carpeta.
"""
    win_prefix = "Guemes_0.1.0_Windows/"
    windows_entries = [(binary, win_prefix + binary.name), (root / "README.md", win_prefix + "README.md"),
                       (root / "LICENSE", win_prefix + "LICENSE"),
                       (root / "tools/configurar_jev.ps1", win_prefix + "tools/configurar_jev.ps1")]
    for relative in ["docs", "licenses"]:
        windows_entries.extend((path, win_prefix + str(path.relative_to(root)).replace("\\", "/"))
                               for path in sorted((root / relative).rglob("*")) if path.is_file() and path.name != ".gdignore")
    for name in ["Cinzel-OFL.txt", "Inter-OFL.txt"]:
        windows_entries.append((root / "assets/fonts" / name, win_prefix + "licenses/" + name))
    windows_zip = output / "Guemes_0.1.0_Windows.zip"
    write_zip(windows_zip, windows_entries, {win_prefix + "LEEME.txt": quickstart,
                                            win_prefix + "VERSION.json": version_text})

    source_prefix = "patria-guemes/"
    tracked = subprocess.check_output(["git", "ls-files", "-z"], cwd=root).decode().split("\0")
    source_entries = [(root / name, source_prefix + name) for name in tracked if name]
    source_zip = output / "Guemes_0.1.0_Codigo_y_Pruebas.zip"
    with tempfile.TemporaryDirectory(prefix="guemes-bundle-") as temporary:
        bundle = Path(temporary) / "historial.bundle"
        subprocess.run(["git", "bundle", "create", str(bundle), "--all"], cwd=root, check=True)
        subprocess.run(["git", "bundle", "verify", str(bundle)], cwd=root, check=True, capture_output=True)
        source_entries.append((bundle, source_prefix + "historial.bundle"))
        git_readme = """El árbol fuente está listo para abrir project.godot con Godot 4.7.2.
No requiere restaurar Git para ejecutar o reconstruir el juego.

Para recuperar los commits en otra carpeta:
    git clone historial.bundle patria-guemes-con-historial

El bundle contiene únicamente el repositorio local de este proyecto.
No hay un remoto externo, plantillas del motor ni claves incluidas.
"""
        write_zip(source_zip, source_entries, {source_prefix + "VERSION.json": version_text,
                                               source_prefix + "LEEME_GIT.txt": git_readme})

    report = output / "Guemes_0.1.0_Verificacion.md"
    shutil.copy2(root / "docs/VERIFICACION.md", report)
    previews = []
    for scenario, name in [("justine", "Guemes_Justine.png"), ("norte", "Guemes_Norte.png")]:
        preview = output / name
        shutil.copy2(root / "evidence/release-benchmarks" / (scenario + "-media.png"), preview)
        previews.append(preview)
    files = [windows_zip, source_zip, report, *previews]
    manifest = {**version, "created_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
                "files": [{"name": path.name, "bytes": path.stat().st_size, "sha256": sha256(path)} for path in files]}
    manifest_path = output / "Guemes_0.1.0_Manifiesto.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"output": str(output), "files": manifest["files"], "manifest": manifest_path.name}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
