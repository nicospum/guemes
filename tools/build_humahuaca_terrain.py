#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Genera data/humahuaca_height.json (el relieve del nivel «Humahuaca») con la fuente elegida (CONTRATO 2.1). Dueña: relieve_mapa.

Uso (Git Bash; el tif y el csv viven FUERA del repo, se pasan con ruta absoluta):

  # Plan A, EN USO desde el 2-nov-2026: la tesela Copernicus DEM GLO-30 (modelo de superficie de 30 m, ±5 m; el .tif no entra nunca a Git:
  # *.tif está en .gitignore). --update-map escribe en el mapa el residuo del domo; --expect-sha256 corta si la tesela no es la autorizada (A-02).
  python -I -X utf8 tools/build_humahuaca_terrain.py --source copernicus --tif <Copernicus_DSM_COG_10_S24_00_W066_00_DEM.tif> \
      --expect-sha256 1b38c9054683f2ea927915ffc9f81e664f919cf13a6cbb4e93a1bd637301f97f --update-map [--smooth-m 45] [--check-lamina <03_relieve_actual.png>]

  # Plan B, el de R1: relieve reconstruido de la lámina 03 (475 nodos de 150 m, ±10 m); sigue siendo la referencia de los 41 puntos (R02)
  python -I -X utf8 tools/build_humahuaca_terrain.py --source lamina03 --csv <01b_relieve_lamina03_nodos_25x19.csv> \
      [--check-lamina <03_relieve_actual.png>] [--out <archivo temporal>]

  # Comparar dos o más archivos de relieve (los 41 puntos de R02, las referencias de R05, la curva de 2 960 m y las pendientes): es la verificación
  # «DEM contra SRTM» del diseño (§4: error medio < 12 m) y la tabla de docs/humahuaca/RELIEVE_COPERNICUS.md
  python -I -X utf8 tools/build_humahuaca_terrain.py --compare data/humahuaca_height.json <otro_relieve.json> [...]

  # Medir la traza del Río Grande en la lámina 03 (imprime los puntos del juego; los lleva a data/humahuaca_map.json quien los revisa)
  python -I -X utf8 tools/build_humahuaca_terrain.py --measure-river <03_relieve_actual.png>

Qué hace (siempre el mismo esquema de salida, cambie o no la fuente):
  1. Arma UNA superficie continua del relieve actual S(E, N) (metros sobre el nivel del mar): con la lámina, la interpolación bilineal de los 475
     nodos (como se dibujó la lámina) suavizada con un gaussiano de radio `--smooth-m`/2; con Copernicus, la tesela recortada, con mediana de 5 × 5
     píxeles (sin techos ni árboles) y gaussiano de `--smooth-m`.
  2. La muestrea en la VENTANA de juego (91 × 66 a 10 m, origen en la esquina noroeste) y en el CONTEXTO (121 × 91 a 30 m, origen (−1350, −1025)),
     las dos desde la misma superficie, y las pasa a decímetros enteros sobre el cero local de 2 940 m: value_dm = round((cota − 2940) · 10).
  3. FUERZA que los nodos del borde de la ventana igualen la interpolación bilineal del contexto a ≤ 0,5 dm (V7 del contrato pide ≤ 1 dm).
  4. Escribe humahuaca_height.json (UTF-8 sin BOM, fin de línea LF) con `meta`, `window`, `context` y `stats`, sin fechas: es determinista.
  5. (opcional) `--check-lamina` mide, con la misma lógica del QA (anexo A1), los 41 puntos (R02) y el acuerdo de bandas de color (R03).
  6. (opcional) `--update-map` recalcula el residuo del domo `delta_m` de `cerro_bateria` y lo escribe en el mapa (la clase lo vuelve a resolver al
     cargar con cualquier fuente: este valor es el último calculado y una prueba exige que coincida).

Marco de la lámina: E metros al este y N al norte del ancla; juego: x = E + 450, z = 325 − N. Nodo (i, j) del CSV: E = −1800 + 150·i, N = −1350 + 150·j
(j = 0 es el SUR: se invierte al escribir «filas norte → sur»).
"""
import argparse
import csv
import json
import math
import pathlib
import re
import sys

import numpy as np
from scipy.ndimage import gaussian_filter, map_coordinates, median_filter

ROOT = pathlib.Path(__file__).resolve().parents[1]
DATUM = 2940.0
WIN = {"nx": 91, "nz": 66, "cell_m": 10.0, "origin_x": 0.0, "origin_z": 0.0}
CTX = {"nx": 121, "nz": 91, "cell_m": 30.0, "origin_x": -1350.0, "origin_z": -1025.0}
OFF_X, OFF_Z = 450.0, 325.0  # x = E + 450 ; z = 325 − N
CREDITS_REF = "docs/humahuaca/CREDITOS_RELIEVE.md"
LAT, LON = -23.2041, -65.3492  # ancla de la iglesia (lámina 03)

# Los 41 puntos de la tabla d.7 del dossier (E, N), con (cota mínima de la banda, cota máxima, estimación en m s. n. m.). El QA (anexo A1) usa los mismos.
PTS41 = [["P01", 0, 0], ["P02", -111, -35], ["P03", -143, 3], ["P04", -450, 325], ["P05", 450, 325], ["P06", -450, -325], ["P07", 450, -325],
         ["P08", -450, 0], ["P09", 450, 0], ["P10", 0, 325], ["P11", 0, -325], ["P12", -225, 162], ["P13", 225, 162], ["P14", -225, -162],
         ["P15", 225, -162], ["P16", 122, 325], ["P17", 297, 200], ["P18", 409, 0], ["P19", 450, -81], ["P20", 596, -271], ["P21", 460, -700],
         ["P22", -279, 1000], ["P23", 435, -1345], ["P24", -180, 325], ["P25", -84, 0], ["P26", -70, -325], ["P27", -1800, 0], ["P28", -1500, 0],
         ["P29", -1000, 0], ["P30", -750, 0], ["P31", 750, 0], ["P32", 1000, 0], ["P33", 1250, 0], ["P34", 1500, 0], ["P35", 1800, 0],
         ["P36", -1800, 1350], ["P37", 1800, 1350], ["P38", -1800, -1350], ["P39", 1800, -1350], ["P40", 350, -1250], ["P41", 1800, -750]]
T41 = {"P01": (2940, 2960, 2957), "P02": (2960, 2980, 2961), "P03": (2960, 2980, 2962), "P04": (2960, 2980, 2971), "P05": (2940, 2960, 2954),
       "P06": (2960, 2980, 2969), "P07": (2940, 2960, 2946), "P08": (2960, 2980, 2970), "P09": (2940, 2960, 2952), "P10": (2940, 2960, 2955),
       "P11": (2940, 2960, 2958), "P12": (2960, 2980, 2964), "P13": (2940, 2960, 2953), "P14": (2960, 2980, 2965), "P15": (2940, 2960, 2952),
       "P16": (2940, 2960, 2954), "P17": (2940, 2960, 2953), "P18": (2940, 2960, 2952), "P19": (2940, 2960, 2951), "P20": (2940, 2960, 2948),
       "P21": (None, 2940, 2939), "P22": (2940, 2960, 2958), "P23": (None, 2940, 2932), "P24": (2960, 2960, 2960), "P25": (2960, 2960, 2960),
       "P26": (2960, 2960, 2960), "P27": (3000, 3020, 3014), "P28": (3000, 3020, 3004), "P29": (2980, 3000, 2990), "P30": (2960, 2980, 2977),
       "P31": (2940, 2960, 2956), "P32": (2960, 2980, 2973), "P33": (2980, 3000, 2992), "P34": (3020, 3040, 3024), "P35": (3080, 3100, 3088),
       "P36": (3020, 3040, 3025), "P37": (3060, 3080, 3065), "P38": (3000, 3020, 3003), "P39": (3100, 3120, 3116), "P40": (None, 2940, 2932),
       "P41": (3120, None, 3137)}

# Lámina 03 (2755 × 2223 px): píxel de E = 0 / N = 0 y píxeles por metro (verificado con el marco rojo y la traza del río, QA anexo A1)
LAM_X0, LAM_Y0, LAM_S = 1018.5, 1122.5, 0.4743
TINTS = ["#ECE3CE", "#E5D9C0", "#DED1B3", "#D7C8A6", "#D0BE9A", "#C9B590", "#C2AD86", "#BAA37C", "#B29A74", "#A9916F", "#9F886A"]  # <2940, 2940-2960, ..., >=3120


# ---------------------------------------------------------------------------------------------------------------------
# Fuentes: devuelven una función f(E, N) → metros sobre el nivel del mar (arreglos de numpy)

def lamina_surface(csv_path, smooth_m):
    """Bilineal sobre los 475 nodos de 150 m, suavizada con un gaussiano de σ = smooth_m / 2."""
    g = np.zeros((19, 25))
    n = 0
    with open(csv_path, encoding="utf-8") as fh:
        for r in csv.DictReader(fh):
            g[int(r["j"]), int(r["i"])] = float(r["cota_estimada_m"])
            n += 1
    if n != 475:
        raise SystemExit("el CSV de la lámina 03 debe traer 475 nodos y trae %d" % n)

    def bilinear(e, nn):
        fi = (np.asarray(e, float) + 1800.0) / 150.0
        fj = (np.asarray(nn, float) + 1350.0) / 150.0
        return map_coordinates(g, [fj, fi], order=1, mode="nearest")

    if smooth_m <= 0:
        return bilinear, {"nodos": n}
    step = 5.0
    ea = np.arange(-1800 - 120, 1800 + 121, step)
    na = np.arange(-1350 - 120, 1350 + 121, step)
    ee, nn = np.meshgrid(ea, na)
    s = gaussian_filter(bilinear(ee, nn), (smooth_m / 2.0) / step, mode="nearest")

    def smooth(e, nn_):
        return map_coordinates(s, [(np.asarray(nn_, float) - na[0]) / step, (np.asarray(e, float) - ea[0]) / step], order=1, mode="nearest")

    return smooth, {"nodos": n}


def file_digests(path):
    """Tamaño, SHA-256 y MD5 de un archivo (la tesela se identifica por sus hashes en meta.source_detail y en CREDITOS_RELIEVE.md)."""
    import hashlib

    sha, md5 = hashlib.sha256(), hashlib.md5()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            sha.update(chunk)
            md5.update(chunk)
    return pathlib.Path(path).stat().st_size, sha.hexdigest(), md5.hexdigest()


def copernicus_surface(tif_path, smooth_m):
    """Tesela Copernicus GLO-30 (GeoTIFF float32, Deflate + predictor 3; solo Pillow, tifffile no sirve sin imagecodecs).
    Georreferencia (etiquetas del GeoTIFF, verificadas el 2-nov-2026): WGS 84, 1 arcosegundo, GTRasterType = PixelIsPoint, punto de amarre
    (−66,0; −23,0) en el CENTRO del píxel (0, 0): el píxel (fila r, columna c) está centrado en lon = −66 + c/3600, lat = −23 − r/3600, así que
    las coordenadas continuas de abajo van directo a map_coordinates (sin corrimiento de medio píxel). El ancla cae en la fila 734,76 y la
    columna 2342,88; un píxel mide 30,76 m de norte a sur y 28,44 m de oeste a este a esta latitud.
    Modelo de SUPERFICIE: mediana de 5 × 5 píxeles (≈ 140 m: se van techos y árboles aislados) y gaussiano de σ = smooth_m / 2."""
    from PIL import Image

    a = np.asarray(Image.open(tif_path), dtype=np.float32)
    if a.shape != (3600, 3600):
        raise SystemExit("la tesela GLO-30 debe ser de 3600 × 3600 y es %s" % (a.shape,))
    lat0, lon0 = math.floor(LAT) + 1, math.floor(LON)  # esquina noroeste de la tesela
    f = math.radians(LAT)
    m_lat = 111132.92 - 559.82 * math.cos(2 * f) + 1.175 * math.cos(4 * f)
    m_lon = 111412.84 * math.cos(f) - 93.5 * math.cos(3 * f) + 0.118 * math.cos(5 * f)
    r_c, c_c = (lat0 - LAT) * 3600.0, (LON - lon0) * 3600.0
    rad = 120  # px alrededor del ancla (≈ 3,7 km): cubre el dominio de 3,6 × 2,7 km
    r0, c0 = int(r_c) - rad, int(c_c) - rad
    sub = a[r0:r0 + 2 * rad, c0:c0 + 2 * rad].astype(np.float64)
    if np.isnan(sub).any():
        raise SystemExit("la tesela trae NaN dentro del recorte")
    sub = median_filter(sub, size=5, mode="nearest")
    if smooth_m > 0:
        sub = gaussian_filter(sub, (smooth_m / 2.0) / 30.9, mode="nearest")

    def surf(e, nn):
        r = (r_c - np.asarray(nn, float) / m_lat * 3600.0) - r0
        c = (c_c + np.asarray(e, float) / m_lon * 3600.0) - c0
        return map_coordinates(sub, [r, c], order=3, mode="nearest")

    return surf, {"tesela": pathlib.Path(tif_path).name}


# ---------------------------------------------------------------------------------------------------------------------
# Muestreo, decímetros y borde

def node_coords(grid):
    x = grid["origin_x"] + grid["cell_m"] * np.arange(grid["nx"])
    z = grid["origin_z"] + grid["cell_m"] * np.arange(grid["nz"])
    return np.meshgrid(x, z)  # [fila j (norte→sur), columna i (oeste→este)]


def sample_dm(surf, grid):
    xx, zz = node_coords(grid)
    cota = surf(xx - OFF_X, OFF_Z - zz)
    return np.round((cota - DATUM) * 10.0).astype(np.int64)


def bilinear_dm(grid_h, grid, x, z):
    """La misma interpolación bilineal que usa V7 (tests/hx_validators.gd, _bilinear)."""
    nx, nz = grid["nx"], grid["nz"]
    fx = (x - grid["origin_x"]) / grid["cell_m"]
    fz = (z - grid["origin_z"]) / grid["cell_m"]
    i0 = int(min(max(math.floor(fx), 0), nx - 2))
    j0 = int(min(max(math.floor(fz), 0), nz - 2))
    tx, tz = fx - i0, fz - j0
    a, b = grid_h[j0, i0], grid_h[j0, i0 + 1]
    c, d = grid_h[j0 + 1, i0], grid_h[j0 + 1, i0 + 1]
    return (a + (b - a) * tx) * (1 - tz) + (c + (d - c) * tx) * tz


def force_window_border(win, ctx):
    """Los nodos del borde de la ventana valen la interpolación bilineal del contexto, redondeada (V7: ≤ 1 dm; acá, ≤ 0,5 dm)."""
    out = win.copy()
    changed = 0
    for j in range(WIN["nz"]):
        for i in range(WIN["nx"]):
            if 0 < i < WIN["nx"] - 1 and 0 < j < WIN["nz"] - 1:
                continue
            v = int(round(bilinear_dm(ctx, CTX, WIN["origin_x"] + WIN["cell_m"] * i, WIN["origin_z"] + WIN["cell_m"] * j)))
            if v != out[j, i]:
                changed += 1
            out[j, i] = v
    return out, changed


def fmt_list(values):
    return "[" + ",".join(str(int(v)) for v in values) + "]"


def write_height(path, meta, win, ctx):
    stats = {"window": {"min": int(win.min()), "max": int(win.max())}, "context": {"min": int(ctx.min()), "max": int(ctx.max())}}
    lines = ["{", '\t"contract": 1,', '\t"map_version": %d,' % meta.pop("_map_version"), '\t"meta": {']
    keys = list(meta.keys())
    for n, k in enumerate(keys):
        lines.append("\t\t%s: %s%s" % (json.dumps(k), json.dumps(meta[k], ensure_ascii=False), "," if n < len(keys) - 1 else ""))
    lines.append("\t},")
    for name, grid, arr in (("window", WIN, win), ("context", CTX, ctx)):
        lines.append('\t"%s": {"nx": %d, "nz": %d, "cell_m": %s, "origin_x": %s, "origin_z": %s, "h": %s},' % (
            name, grid["nx"], grid["nz"], repr(float(grid["cell_m"])), repr(float(grid["origin_x"])), repr(float(grid["origin_z"])), fmt_list(arr.ravel())))
    lines.append('\t"stats": {"window": {"min": %d, "max": %d}, "context": {"min": %d, "max": %d}}' % (
        stats["window"]["min"], stats["window"]["max"], stats["context"]["min"], stats["context"]["max"]))
    lines.append("}")
    text = "\n".join(lines) + "\n"
    pathlib.Path(path).write_bytes(text.encode("utf-8"))
    return stats


# ---------------------------------------------------------------------------------------------------------------------
# Verificación contra la lámina 03 (la misma lógica de qa_relieve.py, anexo A1 de docs/QA_NIVEL2.md)

def check_lamina(png, win, ctx, label):
    from PIL import Image

    im = np.asarray(Image.open(png).convert("RGB")).astype(np.int16)
    wm = win / 10.0 + DATUM
    cm = ctx / 10.0 + DATUM
    errs, inb = [], []
    for k, e, n in PTS41:
        gx, gz = e + OFF_X, OFF_Z - n
        if 0 <= gx <= 900 and 0 <= gz <= 650:
            v = float(map_coordinates(wm, [[gz / 10.0], [gx / 10.0]], order=1)[0])
        else:
            v = float(map_coordinates(cm, [[(gz - CTX["origin_z"]) / 30.0], [(gx - CTX["origin_x"]) / 30.0]], order=1, mode="nearest")[0])
        lo, hi, est = T41[k]
        errs.append(abs(v - est))
        inb.append((lo is None or v >= lo - 8) and (hi is None or v <= hi + 8))
    x_lo, x_hi = int(round(LAM_X0 - 1800 * LAM_S)) + 3, int(round(LAM_X0 + 1800 * LAM_S)) - 3
    y_lo, y_hi = int(round(LAM_Y0 - 1350 * LAM_S)) + 3, int(round(LAM_Y0 + 1350 * LAM_S)) - 3
    sub = im[y_lo:y_hi, x_lo:x_hi]
    best = np.full(sub.shape[:2], 999, np.int16)
    cls = np.zeros(sub.shape[:2], np.int8)
    for k, h in enumerate(TINTS):
        t = np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], np.int16)
        dd = np.abs(sub - t).sum(axis=2).astype(np.int16)
        m = dd < best
        best[m] = dd[m]
        cls[m] = k
    valid = best <= 6
    ys, xs = np.mgrid[y_lo:y_hi, x_lo:x_hi]
    ee, nn = (xs - LAM_X0) / LAM_S, (LAM_Y0 - ys) / LAM_S
    zc = map_coordinates(cm, [(OFF_Z - nn - CTX["origin_z"]) / 30.0, (ee + OFF_X - CTX["origin_x"]) / 30.0], order=1, mode="nearest")
    zw = map_coordinates(wm, [(OFF_Z - nn) / 10.0, (ee + OFF_X) / 10.0], order=1, mode="nearest")
    inwin = (np.abs(ee) <= 450) & (np.abs(nn) <= 325)
    z = np.where(inwin, zw, zc)
    band = np.where(z < 2940, 0, np.clip(np.floor((z - 2940) / 20) + 1, 0, 10)).astype(np.int8)
    ag_w = float(((band == cls) & valid & inwin).sum() / (valid & inwin).sum() * 100)
    ag_t = float(((band == cls) & valid).sum() / valid.sum() * 100)
    res = {"fuente": label, "R02_a_12m": int(sum(e <= 12 for e in errs)), "R02_max_err_m": round(max(errs), 2), "R02_en_banda": int(sum(inb)),
           "R03_ventana_pct": round(ag_w, 2), "R03_dominio_pct": round(ag_t, 2)}
    print("CHECK", json.dumps(res, ensure_ascii=False))
    return res


# ---------------------------------------------------------------------------------------------------------------------
# Comparación de archivos de relieve (A/B de fuentes): los 41 puntos de R02, las referencias de R05, la curva de 2 960 m y las pendientes

def load_height(path):
    d = json.loads(pathlib.Path(path).read_text(encoding="utf-8"))
    win = np.array(d["window"]["h"], float).reshape(WIN["nz"], WIN["nx"])
    ctx = np.array(d["context"]["h"], float).reshape(CTX["nz"], CTX["nx"])
    return d["meta"], win, ctx


def height_m(win, ctx, x, z):
    """Cota (m s. n. m.) en (x, z) del juego: bilineal de la ventana adentro y del contexto afuera (la lectura del QA, anexo A1, y de V7)."""
    if 0.0 <= x <= 900.0 and 0.0 <= z <= 650.0:
        return bilinear_dm(win, WIN, x, z) / 10.0 + DATUM
    return bilinear_dm(ctx, CTX, x, z) / 10.0 + DATUM


def compare_heights(paths, map_data):
    """Imprime, para cada archivo, los 41 puntos (R02), las referencias (R05), la curva de 2 960 m y las pendientes: la verificación
    «DEM contra SRTM» del diseño (§4, error medio < 12 m) y la tabla de docs/humahuaca/RELIEVE_COPERNICUS.md. Solo lectura."""
    pts = map_data.get("relief", {}).get("lamina_points") or [
        {"id": k, "E": e, "N": n, "banda_min_m": T41[k][0], "banda_max_m": T41[k][1], "est_m": T41[k][2]} for k, e, n in PTS41]
    grids = [(pathlib.Path(p).name,) + load_height(p) for p in paths]
    print("id       E      N   est  banda       | " + " | ".join("%-19s" % g[0][:19] for g in grids))
    summ = [{"ok12": 0, "max": 0.0, "band": 0, "sum": 0.0} for _ in grids]
    for p in pts:
        x, z = p["E"] + OFF_X, OFF_Z - p["N"]
        lo, hi, est = p.get("banda_min_m"), p.get("banda_max_m"), p["est_m"]
        row = "%-4s %6d %6d %5d [%4s,%4s] |" % (p["id"], p["E"], p["N"], est, lo if lo is not None else "-", hi if hi is not None else "-")
        for k, (_, _, win, ctx) in enumerate(grids):
            v = height_m(win, ctx, x, z)
            err = abs(v - est)
            inb = (lo is None or v >= lo - 8) and (hi is None or v <= hi + 8)
            s = summ[k]
            s["ok12"] += err <= 12
            s["max"] = max(s["max"], err)
            s["band"] += inb
            s["sum"] += err
            row += " %7.1f %5.1f %-3s |" % (v, err, "si" if inb else "NO")
        print(row)
    for k, g in enumerate(grids):
        s = summ[k]
        print("R02 %-32s %d de 41 a <= 12 m | peor %.1f m | en banda %d/41 | error medio %.2f m" % (g[0], s["ok12"], s["max"], s["band"], s["sum"] / len(pts)))
    refs = [("templo", 450, 325), ("cauce z=325", 859, 325), ("partida", 70, 470), ("plaza", 450, 392), ("sitio de la bateria", 318, 350),
            ("cuartel", 418, 335), ("posta", 590, 300), ("oeste z=325", 40, 325), ("este z=325", 860, 325)]
    for name, meta, win, ctx in grids:
        def h(x, z, _w=win, _c=ctx):
            return height_m(_w, _c, x, z) - DATUM
        ring = sum(h(305 + 135 * math.cos(2 * math.pi * k / 16), 345 + 135 * math.sin(2 * math.pi * k / 16)) for k in range(16)) / 16.0
        print("%s (%s, suavizado %s m): " % (name, meta.get("source", "?"), meta.get("smooth_m", "?")) + "; ".join("%s %+.1f" % (n, h(x, z)) for n, x, z in refs))
        print("   DEM solo, m sobre el cero local: anillo de 135 m %.2f; bateria − anillo %.2f; bateria − plaza %.2f; oeste − este %.2f; templo − cauce %.2f" % (
            ring, h(318, 350) - ring, h(318, 350) - h(450, 392), h(40, 325) - h(860, 325), h(450, 325) - h(859, 325)))
        out = []
        for z, ref in ((0.0, 270.0), (325.0, 366.0), (650.0, 380.0)):
            vals = [h(float(x), z) + DATUM - 2960.0 for x in range(0, 901)]
            cross = [float(x) for x in range(1, 901) if vals[x - 1] * vals[x] <= 0]
            best = min(cross, key=lambda c: abs(c - ref)) if cross else None
            out.append("z=%d x=%s (lámina %d)" % (z, "%.0f" % best if best is not None else "ninguno", ref))
        gz, gx = np.gradient(win / 10.0, WIN["cell_m"])
        slope = np.degrees(np.arctan(np.hypot(gx, gz)))
        print("   curva de 2 960 m: " + "; ".join(out) + " | pendiente a 10 m: media %.2f°, p95 %.2f°, máx %.2f°, celdas ≥ 8°: %.1f %%" % (
            slope.mean(), np.percentile(slope, 95), slope.max(), (slope >= 8).mean() * 100))
    if len(grids) >= 2:
        for name, _, win, ctx in grids[1:]:
            dw = (win - grids[0][2]) / 10.0
            dc = (ctx - grids[0][3]) / 10.0
            print("%s − %s: ventana media %+.2f m (|d| media %.2f, mín %+.1f, máx %+.1f); contexto media %+.2f m (|d| media %.2f)" % (
                name, grids[0][0], dw.mean(), np.abs(dw).mean(), dw.min(), dw.max(), dc.mean(), np.abs(dc).mean()))


# ---------------------------------------------------------------------------------------------------------------------
# Traza del Río Grande medida en la lámina 03 (fila por fila, como lo hace el QA en R04)

def measure_river(png):
    from PIL import Image

    im = np.asarray(Image.open(png).convert("RGB")).astype(np.int16)
    blue = np.abs(im - np.array([0x32, 0x6F, 0x8A], np.int16)).sum(axis=2) < 30
    c0, c1 = int(LAM_X0 - 450 * LAM_S), int(LAM_X0 + 900 * LAM_S)
    rows = []
    for py in range(int(round(LAM_Y0 - 332 * LAM_S)), int(round(LAM_Y0 + 100 * LAM_S))):
        cols = np.nonzero(blue[py, c0:c1])[0] + c0
        if len(cols) == 0:
            continue
        run = [cols[0]]
        for cc in cols[1:]:
            if cc - run[-1] > 2:
                break
            run.append(cc)
        rows.append(((LAM_Y0 - py) / LAM_S, (np.mean(run) - LAM_X0) / LAM_S))  # (N, E)
    rows = np.array(rows)
    z = OFF_Z - rows[:, 0]
    x = rows[:, 1] + OFF_X
    ok = (z >= -4) & (x <= 904)
    z, x = z[ok], x[ok]
    # suavizado de ±3 filas (≈ ±6 m) y muestreo cada ≈ 30 m de arco, de la entrada por el norte (z = 0) a la salida por el este (x = 900)
    k = 3
    xs = np.array([x[max(0, n - k):n + k + 1].mean() for n in range(len(x))])
    zs = z.copy()
    zz = np.arange(0.0, 406.0, 1.0)
    xx = np.interp(zz, zs, xs)
    out = [(float(np.interp(0.0, zs, xs)), 0.0)]
    acc = 0.0
    for n in range(1, len(zz)):
        acc += math.hypot(xx[n] - xx[n - 1], zz[n] - zz[n - 1])
        if acc >= 30.0:
            out.append((float(xx[n]), float(zz[n])))
            acc = 0.0
    xe = float(np.interp(404.5, zs, xs))
    out.append((900.0, 405.0) if abs(xe - 900.0) < 3.0 else (xe, 404.5))
    print("RIO %d puntos (x, z del juego), medidos de la lámina 03:" % len(out))
    print("[" + ", ".join('{"x": %.1f, "z": %.1f}' % p for p in out) + "]")
    return out


# ---------------------------------------------------------------------------------------------------------------------
# Residuo del domo de la batería (réplica en numpy de lo que resuelve HumahuacaTerrain al cargar; ver docs/humahuaca/RELIEVE.md)

MICRO_BASE_LAMBDA = [36.0, 44.0, 55.0, 70.0, 90.0]  # × (longitud de onda mínima / 25 m) × (0,9 a 1,1)
MICRO_WEIGHTS = [0.30, 0.25, 0.20, 0.15, 0.10]  # suman 1: |micro| <= amp
WARP_A = [10.0, 6.0, 9.0, 5.0]  # amplitudes (m) del desplazamiento que tuerce las ondas


def micro_params(seed, wavelength):
    """Cinco ondas planas deterministas (LCG de 31 bits, tres sorteos por onda y cinco más para el desplazamiento y la modulación):
    la MISMA definición que Relief.micro_params de scripts/humahuaca/terrain/terrain_relief.gd."""
    s = int(seed) & 0x7FFFFFFF
    comps = []
    for k in range(5):
        vals = []
        for _ in range(3):
            s = (s * 1103515245 + 12345) & 0x7FFFFFFF
            vals.append(s / 2147483648.0)
        comps.append({"ang": (vals[0] - 0.5) * 2.618, "lam": wavelength / 25.0 * MICRO_BASE_LAMBDA[k] * (0.9 + 0.2 * vals[1]),
                      "phase": vals[2] * 2 * math.pi, "weight": MICRO_WEIGHTS[k]})
    warp = []
    for _ in range(5):
        s = (s * 1103515245 + 12345) & 0x7FFFFFFF
        warp.append(s / 2147483648.0 * 2 * math.pi)
    return {"comps": comps, "warp": warp[:4], "mod_phase": warp[4]}


def micro_at(x, z, params, amp, fade=1.0):
    w = params["warp"]
    tau = 2.0 * math.pi
    wx = WARP_A[0] * math.sin(tau * z / 190.0 + w[0]) + WARP_A[1] * math.sin(tau * (x - z) / 310.0 + w[1])
    wz = WARP_A[2] * math.sin(tau * x / 170.0 + w[2]) + WARP_A[3] * math.sin(tau * (x + z) / 260.0 + w[3])
    mod = 0.8 + 0.2 * math.sin(tau * (x * 0.8 + z * 0.6) / 420.0 + params["mod_phase"])
    total = 0.0
    for c in params["comps"]:
        total += c["weight"] * math.sin(tau * ((x + wx) * math.cos(c["ang"]) + (z + wz) * math.sin(c["ang"])) / c["lam"] + c["phase"])
    return amp * mod * total * fade


def catmull(p0, p1, p2, p3, t):
    t2, t3 = t * t, t * t * t
    return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)


def cr_sample(win_m, x, z):
    fx, fz = x / 10.0, z / 10.0
    i0, j0 = int(math.floor(fx)), int(math.floor(fz))
    tx, tz = fx - i0, fz - j0

    def w(i, j):
        return win_m[min(max(j, 0), win_m.shape[0] - 1), min(max(i, 0), win_m.shape[1] - 1)]

    rows = [catmull(w(i0 - 1, j0 + dj), w(i0, j0 + dj), w(i0 + 1, j0 + dj), w(i0 + 2, j0 + dj), tx) for dj in (-1, 0, 1, 2)]
    return catmull(rows[0], rows[1], rows[2], rows[3], tz)


def dome_profile(r, core, support):
    if r <= core:
        return 1.0
    if r >= support:
        return 0.0
    return 0.5 * (1.0 + math.cos(math.pi * (r - core) / (support - core)))


def edge_fade(x, z, fade_m):
    d = min(x, 900.0 - x, z, 650.0 - z)
    t = min(max(d / fade_m, 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def dome_delta(map_data, win_dm):
    rel = map_data["relief"]
    layers = {l["id"]: l for l in rel["design_layers"]}
    dome, plat = layers["cerro_bateria"], layers["plataforma_bateria"]
    win_m = win_dm / 10.0
    micro = rel.get("micro", {})
    amp, lam, seed, fade_m = float(micro.get("amp_m", 0.5)), float(micro.get("wavelength_m", 25.0)), int(micro.get("seed", 1817)), float(micro.get("edge_fade_m", 40.0))
    params = micro_params(seed, lam)
    cx, cz = dome["center"]["x"], dome["center"]["z"]
    ring = 0.0
    for k in range(16):
        ang = 2.0 * math.pi * k / 16.0
        x, z = cx + 135.0 * math.cos(ang), cz + 135.0 * math.sin(ang)
        ring += cr_sample(win_m, x, z) + micro_at(x, z, params, amp, edge_fade(x, z, fade_m))
    ring /= 16.0
    px, pz = plat["center"]["x"], plat["center"]["z"]
    level = ring + float(dome["prominence_target_m"])
    f_p = dome_profile(math.hypot(px - cx, pz - cz), float(dome.get("core_m", 16.0)), float(dome["radius_m"]))
    return (level - cr_sample(win_m, px, pz)) / f_p, ring, level


def update_map_delta(map_path, delta):
    text = pathlib.Path(map_path).read_text(encoding="utf-8")
    new, n = re.subn(r'("id": "cerro_bateria"[^\n]*?"delta_m": )(-?[0-9.]+)', lambda m: m.group(1) + ("%.2f" % delta), text, count=1)
    if n != 1:
        raise SystemExit("no encuentro «delta_m» de cerro_bateria en %s" % map_path)
    pathlib.Path(map_path).write_bytes(new.encode("utf-8"))


# ---------------------------------------------------------------------------------------------------------------------

def main():
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--source", choices=["lamina03", "copernicus"], default="lamina03")
    ap.add_argument("--csv", help="01b_relieve_lamina03_nodos_25x19.csv (con --source lamina03)")
    ap.add_argument("--tif", help="Copernicus_DSM_COG_10_S24_00_W066_00_DEM.tif (con --source copernicus; nunca entra al repo)")
    ap.add_argument("--out", default=str(ROOT / "data" / "humahuaca_height.json"))
    ap.add_argument("--map", default=str(ROOT / "data" / "humahuaca_map.json"))
    ap.add_argument("--smooth-m", type=float, default=None, help="radio del suavizado (lámina 30 m; Copernicus 45 m)")
    ap.add_argument("--check-lamina", help="03_relieve_actual.png: mide R02 y R03 con la lógica del QA")
    ap.add_argument("--measure-river", help="03_relieve_actual.png: imprime la traza del Río Grande medida en la lámina (no escribe nada)")
    ap.add_argument("--update-map", action="store_true", help="escribe en el mapa el residuo del domo (delta_m de cerro_bateria)")
    ap.add_argument("--expect-sha256", help="con --source copernicus: corta si el SHA-256 de la tesela no es este (la autorizada en ADDENDA A-02)")
    ap.add_argument("--compare", nargs="+", metavar="HEIGHT_JSON", help="compara dos o más archivos de relieve (R02, R05, curva de 2 960 m, pendientes) y no escribe nada")
    a = ap.parse_args()

    map_data = json.loads(pathlib.Path(a.map).read_text(encoding="utf-8")) if pathlib.Path(a.map).exists() else {}
    if a.measure_river:
        measure_river(a.measure_river)
        return 0
    if a.compare:
        compare_heights(a.compare, map_data)
        return 0
    smooth = a.smooth_m if a.smooth_m is not None else (30.0 if a.source == "lamina03" else 45.0)
    map_version = int(map_data.get("map_version", 1))
    if a.source == "lamina03":
        if not a.csv:
            raise SystemExit("--source lamina03 pide --csv con ruta absoluta (el csv vive fuera del repo)")
        surf, info = lamina_surface(a.csv, smooth)
        meta = {
            "source": "lamina03_reconstruida",
            "source_detail": "475 nodos de la lámina 03 (SRTM v3 de 90 m, NASA/USGS; reconstrucción propia a ±10 m), bilineal y suavizada a %d m" % smooth,
            "datum_asl_m": DATUM, "unit": "dm", "order": "filas norte->sur, columnas oeste->este; índice = fila * nx + columna",
            "tag": "razonado", "uncertainty_m": 10.0, "modified": True, "smooth_m": smooth, "credits_ref": CREDITS_REF,
            "builder": "tools/build_humahuaca_terrain.py --source lamina03"}
    else:
        if not a.tif:
            raise SystemExit("--source copernicus pide --tif con ruta absoluta (la tesela vive fuera del repo)")
        size, sha256, md5 = file_digests(a.tif)
        if a.expect_sha256 and sha256.lower() != a.expect_sha256.lower():
            raise SystemExit("la tesela %s tiene SHA-256 %s y se esperaba %s: no es la autorizada" % (a.tif, sha256, a.expect_sha256))
        print("TESELA %s | %d B | SHA-256 %s | MD5 %s" % (pathlib.Path(a.tif).name, size, sha256, md5))
        surf, info = copernicus_surface(a.tif, smooth)
        meta = {
            "source": "copernicus_glo30",
            "source_detail": "%s (%d B, SHA-256 %s, MD5 %s; bucket AWS copernicus-dem-30m), mediana 5x5 px y gaussiano de %d m; modificado: remuestreo, suavizado y recorte" % (
                info["tesela"], size, sha256, md5, smooth),
            "datum_asl_m": DATUM, "unit": "dm", "order": "filas norte->sur, columnas oeste->este; índice = fila * nx + columna",
            "tag": "razonado", "uncertainty_m": 5.0, "modified": True, "smooth_m": smooth, "credits_ref": CREDITS_REF,
            "builder": "tools/build_humahuaca_terrain.py --source copernicus"}
    ctx = sample_dm(surf, CTX)
    win = sample_dm(surf, WIN)
    win, changed = force_window_border(win, ctx)
    meta["_map_version"] = map_version
    stats = write_height(a.out, meta, win, ctx)
    print("OK %s | ventana %dx%d (dm %d..%d) | contexto %dx%d (dm %d..%d) | borde forzado en %d nodos" % (
        a.out, WIN["nx"], WIN["nz"], stats["window"]["min"], stats["window"]["max"], CTX["nx"], CTX["nz"], stats["context"]["min"], stats["context"]["max"], changed))
    if a.check_lamina:
        check_lamina(a.check_lamina, win, ctx, meta["source"])
    if map_data.get("relief", {}).get("design_layers"):
        delta, ring, level = dome_delta(map_data, win)
        print("DOMO delta_m = %.2f m (anillo de 135 m: media %.2f m sobre el cero local; nivel de la plataforma %.2f m)" % (delta, ring, level))
        if a.update_map:
            update_map_delta(a.map, delta)
            print("mapa actualizado: %s" % a.map)
    return 0


if __name__ == "__main__":
    sys.exit(main())
