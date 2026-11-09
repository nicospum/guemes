#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""F5 parte C · texturas PBR de suelo (CC0, Poly Haven) para los tres lugares del juego. Dueña: pista visual (visual/r1).

Uso (Linux o Git Bash; Python con numpy y Pillow; la carpeta de descarga va FUERA del repo y vacía):

  python -I -X utf8 tools/f5_terreno_texturas.py --download-dir <carpeta_vacia_fuera_del_repo> [--res 1k] [--quality 88] [--only hx_suelo_grava,...]
  python -I -X utf8 tools/f5_terreno_texturas.py --verify      # recalcula los sha256 de assets/terrain/** contra el manifiesto
  python -I -X utf8 tools/f5_terreno_texturas.py --preview <carpeta>   # hoja de vista previa: cada material iluminado con su normal y su
                                                                       # oclusión, de cerca (2 × 2 repeticiones) y de lejos (8 × 8)

Qué hace:
  1. Por cada material de MATERIALS pide a la API pública de Poly Haven (https://api.polyhaven.com/files/<id>) la lista de archivos y baja,
     a la resolución pedida, el color (Diffuse), la normal en convención OpenGL (nor_gl: la de Godot), el empaquetado ARM (R = oclusión,
     G = rugosidad, B = metal: el mismo orden ORM de Godot) y el desplazamiento (Displacement), todos en JPG salvo el desplazamiento (PNG).
  2. Verifica el MD5 que publica la API (corta si no coincide), calcula el SHA-256 del original y lo anota.
  3. Re-codifica a JPG (calidad --quality, sin metadatos; el desplazamiento a gris de 8 bits) en assets/terrain/<lugar>/<id_juego>_<mapa>.jpg:
     `albedo`, `normal`, `orm`, `height`. Es la única modificación (CC0 la permite; se declara igual).
  4. Escribe assets/terrain/terrain_textures_manifest.json (determinista, sin fechas): fuente, autores, licencia, URL, MD5 y SHA-256 del
     original y SHA-256 y tamaño de cada archivo del repo.

Licencia de la fuente: todos los assets de Poly Haven son CC0 1.0 (https://polyhaven.com/license, verificado el 9-nov-2026). No exige crédito;
se acredita igual en docs/CREDITOS.md (sección «visual/r1 F5 · terreno»).
"""
import argparse
import hashlib
import io
import json
import pathlib
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "terrain"
MANIFEST = OUT / "terrain_textures_manifest.json"
API = "https://api.polyhaven.com"
UA = {"User-Agent": "patria-guemes-f5-terreno/1.0 (+https://github.com/nicospum/guemes)"}

# id_juego, lugar, id Poly Haven, papel en el suelo (por qué se eligió). Las fotos son de otros lugares del mundo: lo que se toma es el
# MATERIAL (grano, piedra, aridez), no una vista de Humahuaca, Salta o el Retiro. Etiqueta de uso: «razonado» (analogía de material).
MATERIALS = [
    # Quebrada de Humahuaca, 2 940 m: prepuna árida, suelo de grava y arena gruesa, ladera pedregosa, cauce de cantos rodados, churqui y andenes
    ("hx_suelo_grava", "humahuaca", "gravelly_sand", "suelo seco base: arena gruesa con grava dispersa (Namaqualand, semidesierto)"),
    ("hx_ladera_grava", "humahuaca", "rock_ground_02", "ladera y conos de deyección: suelo pedregoso gris pardo con plantas ralas"),
    ("hx_cauce_cantos", "humahuaca", "dry_river_pebbles", "lecho seco del Río Grande: cantos rodados"),
    ("hx_roca_ladera", "humahuaca", "cliff_side", "barrancas y pendientes fuertes: roca sedimentaria estratificada (Namaqualand)"),
    ("hx_pasto_seco", "humahuaca", "grass_ground", "churqui / pasto seco sobre tierra: matorral bajo y sus claros"),
    ("hx_andenes_tierra", "humahuaca", "farm_soil", "rastrojos y andenes de cultivo irrigados: tierra arada"),
    # Valle de Lerma / Salta (Norte): más verde, caminos de tierra
    ("norte_pasto", "norte", "sparse_grass", "pasto ralo verde del valle templado"),
    ("norte_camino_pasto", "norte", "grass_path_2", "huella rural entre pasto"),
    ("norte_camino_tierra", "norte", "brown_mud_02", "camino de tierra compactada con piedras"),
    # Retiro, ribera del Río de la Plata, 1806: arena, barro y pasto de bañado
    ("jn_arena_humeda", "justina", "damp_sand", "playa de arena húmeda de la ribera"),
    ("jn_barro", "justina", "brown_mud_03", "barro de la costa y del bajo (pisadas, sin huellas de ruedas)"),
    ("jn_pasto_ribera", "justina", "leafy_grass", "pasto de la barranca y del bajo"),
]
MAPS = [("Diffuse", "jpg", "albedo"), ("nor_gl", "jpg", "normal"), ("arm", "jpg", "orm"), ("Displacement", "png", "height")]


def fetch(url):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read()


def sha256(b):
    return hashlib.sha256(b).hexdigest()


def reencode(raw, kind, quality):
    from PIL import Image

    im = Image.open(io.BytesIO(raw))
    if kind == "height":
        if im.mode in ("I;16", "I;16B", "I"):
            import numpy as np

            a = np.asarray(im, dtype=np.float64)
            lo, hi = float(a.min()), float(a.max())
            a = (a - lo) / max(hi - lo, 1.0) * 255.0
            im = Image.fromarray(np.clip(np.round(a), 0, 255).astype("uint8"), "L")
        else:
            im = im.convert("L")
    else:
        im = im.convert("RGB")
    buf = io.BytesIO()
    # sin EXIF/ICC; 4:4:4 en normal y ORM (el submuestreo de croma ensucia los canales que no son color)
    q = min(quality, 80) if kind == "normal" else quality  # la normal pesa el doble a igual calidad; 80 no deja bloques visibles a 1K
    im.save(buf, "JPEG", quality=q, optimize=True, subsampling=0 if kind in ("normal", "orm") else 2)
    return buf.getvalue(), im.size


def preview(dst):
    """Ilumina cada material sobre un plano (lambert con la normal OpenGL y la oclusión del ORM, sol a 40° desde el noroeste)."""
    import numpy as np
    from PIL import Image, ImageDraw

    man = json.loads(MANIFEST.read_text(encoding="utf-8"))
    T = 300
    L = np.array([-0.55, 0.55, 0.63])
    L = L / np.linalg.norm(L)
    cols = 2
    sheet = Image.new("RGB", (cols * 2 * T + (cols - 1) * 12, ((len(man["materials"]) + cols - 1) // cols) * (T + 22)), (24, 22, 20))
    dr = ImageDraw.Draw(sheet)
    for k, m in enumerate(man["materials"]):
        f = {x["map"]: ROOT / x["path"] for x in m["files"]}
        alb = np.asarray(Image.open(f["albedo"]).convert("RGB"), np.float64) / 255.0
        nor = np.asarray(Image.open(f["normal"]).convert("RGB"), np.float64) / 255.0 * 2.0 - 1.0
        orm = np.asarray(Image.open(f["orm"]).convert("RGB"), np.float64) / 255.0
        n = nor / np.maximum(np.linalg.norm(nor, axis=2, keepdims=True), 1e-6)
        lin = alb ** 2.2
        lit = lin * (0.22 + 0.95 * np.clip(n @ L, 0, 1))[..., None] * (0.35 + 0.65 * orm[..., 0:1])
        img = Image.fromarray(np.clip(lit ** (1 / 2.2) * 255.0, 0, 255).astype(np.uint8))
        near = Image.new("RGB", (img.width * 2, img.height * 2))
        far = Image.new("RGB", (img.width * 8, img.height * 8))
        for i in range(8):
            for j in range(8):
                if i < 2 and j < 2:
                    near.paste(img, (i * img.width, j * img.height))
                far.paste(img, (i * img.width, j * img.height))
        x0 = (k % cols) * (2 * T + 12)
        y0 = (k // cols) * (T + 22)
        sheet.paste(near.resize((T, T), Image.LANCZOS), (x0, y0 + 20))
        sheet.paste(far.resize((T, T), Image.LANCZOS), (x0 + T, y0 + 20))
        dr.text((x0 + 4, y0 + 4), "%s · %s (%s)  cerca 2x2 | lejos 8x8" % (m["place"], m["id"], m["source_id"]), fill=(240, 236, 226))
    dst.mkdir(parents=True, exist_ok=True)
    sheet.save(dst / "10_texturas_iluminadas.png")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--download-dir", help="carpeta vacía FUERA del repo donde quedan los originales tal cual se bajaron")
    ap.add_argument("--res", default="1k", choices=["1k", "2k"])
    ap.add_argument("--quality", type=int, default=88)
    ap.add_argument("--only", default="", help="ids de juego separados por coma")
    ap.add_argument("--verify", action="store_true")
    ap.add_argument("--preview")
    a = ap.parse_args()

    if a.preview:
        preview(pathlib.Path(a.preview))
        return

    if a.verify:
        man = json.loads(MANIFEST.read_text(encoding="utf-8"))
        bad = 0
        for m in man["materials"]:
            for f in m["files"]:
                p = ROOT / f["path"]
                ok = p.exists() and sha256(p.read_bytes()) == f["sha256"]
                bad += 0 if ok else 1
                print(("ok   " if ok else "MAL  ") + f["path"])
        sys.exit(1 if bad else 0)

    if not a.download_dir:
        ap.error("falta --download-dir")
    dl = pathlib.Path(a.download_dir).resolve()
    if ROOT in dl.parents or dl == ROOT:
        ap.error("la carpeta de descarga tiene que estar fuera del repo")
    dl.mkdir(parents=True, exist_ok=True)
    only = set(x for x in a.only.split(",") if x)

    old = {}
    if MANIFEST.exists():
        old = {m["id"]: m for m in json.loads(MANIFEST.read_text(encoding="utf-8"))["materials"]}
    out = []
    for gid, place, ph, role in MATERIALS:
        if only and gid not in only:
            if gid in old:
                out.append(old[gid])
            continue
        info = json.loads(fetch("%s/info/%s" % (API, ph)))
        files = json.loads(fetch("%s/files/%s" % (API, ph)))
        entry = {"id": gid, "place": place, "role": role, "source": "Poly Haven", "source_id": ph, "name": info.get("name", ph),
                 "authors": info.get("authors", {}), "page": "https://polyhaven.com/a/%s" % ph, "license": "CC0 1.0",
                 "license_url": "https://polyhaven.com/license", "real_size_cm": info.get("dimensions"), "resolution": a.res,
                 "tag": "razonado", "modification": "re-codificado a JPG calidad %d (normal %d) sin metadatos; desplazamiento a gris de 8 bits" % (a.quality, min(a.quality, 80)),
                 "files": []}
        (OUT / place).mkdir(parents=True, exist_ok=True)
        for key, fmt, kind in MAPS:
            meta = files[key][a.res][fmt]
            raw = fetch(meta["url"])
            md5 = hashlib.md5(raw).hexdigest()
            if md5 != meta["md5"]:
                raise SystemExit("MD5 no coincide para %s (%s != %s)" % (meta["url"], md5, meta["md5"]))
            (dl / pathlib.Path(meta["url"]).name).write_bytes(raw)
            data, size = reencode(raw, kind, a.quality)
            rel = "assets/terrain/%s/%s_%s.jpg" % (place, gid, kind)
            (ROOT / rel).write_bytes(data)
            entry["files"].append({"map": kind, "path": rel, "bytes": len(data), "sha256": sha256(data), "pixels": list(size),
                                   "source_url": meta["url"], "source_bytes": len(raw), "source_md5": md5, "source_sha256": sha256(raw)})
            print("%-22s %-7s %7d B  <- %s" % (gid, kind, len(data), meta["url"]))
        out.append(entry)
    order = [m[0] for m in MATERIALS]
    out.sort(key=lambda e: order.index(e["id"]))
    man = {"contract": "f5_terreno_texturas", "version": 1, "builder": "tools/f5_terreno_texturas.py",
           "credits_ref": "docs/CREDITOS.md (visual/r1 F5 · terreno)",
           "godot_notes": "albedo sRGB; normal OpenGL (+Y, la de Godot); orm = R oclusión, G rugosidad, B metal (ORM de Godot); height gris 0..1 "
                          "relativo (no metros), para mezclar capas por altura",
           "materials": out}
    MANIFEST.write_text(json.dumps(man, ensure_ascii=False, indent=1) + "\n", encoding="utf-8", newline="\n")
    total = sum(f["bytes"] for m in out for f in m["files"])
    print("total en el repo: %.2f MB en %d archivos" % (total / 1e6, sum(len(m["files"]) for m in out)))


if __name__ == "__main__":
    main()
