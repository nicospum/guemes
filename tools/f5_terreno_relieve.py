#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""F5 parte C · relieve real (Copernicus DEM) para el horizonte de «Humahuaca» y para el mapa del Norte (B-028). Dueña: pista visual (visual/r1).

NO reemplaza data/humahuaca_height.json (ventana y contexto, que ya salen de Copernicus GLO-30 con tools/build_humahuaca_terrain.py desde el
2-nov-2026) ni toca código del juego: escribe archivos NUEVOS en assets/terrain/ para que la integración decida si los usa.

Uso (Linux o Git Bash; Python con numpy, scipy y Pillow; las teselas van FUERA del repo, nunca a Git: *.tif está en .gitignore):

  python -I -X utf8 tools/f5_terreno_relieve.py --tiles-dir <carpeta_fuera_del_repo> --download          # baja lo que falte (HTTPS, AWS)
  python -I -X utf8 tools/f5_terreno_relieve.py --tiles-dir <carpeta> --humahuaca --norte [--preview-dir ../qa-visual-r1/f5_terreno_preview]

Fuentes (bucket público de AWS «Copernicus DEM», administrado por Sinergise; readme https://copernicus-dem-30m.s3.amazonaws.com/readme.html):
  · GLO-30 (1″, ≈ 30 m): https://copernicus-dem-30m.s3.amazonaws.com/Copernicus_DSM_COG_10_<N>_<E>_DEM/Copernicus_DSM_COG_10_<N>_<E>_DEM.tif
  · GLO-90 (3″, ≈ 90 m): https://copernicus-dem-90m.s3.amazonaws.com/Copernicus_DSM_COG_30_<N>_<E>_DEM/Copernicus_DSM_COG_30_<N>_<E>_DEM.tif
  La tesela S24_00_W066_00 de GLO-30 es la misma que autorizó ADDENDA A-02 (sha256 1b38c905…301f97f): el script corta si no coincide.
  Licencias GLO-30-F y GLO-90-F («Full, Free & Open», Artículos 4 y 6; PDF oficial en dataspace.copernicus.eu, cotejado el 9-nov-2026):
  reproducción, distribución, comunicación al público y modificación permitidas, gratis, con el aviso del Artículo 6 (b) y la frase de
  no responsabilidad del 6 (c). Los avisos literales van en NOTICE_* y en docs/CREDITOS.md.

Georreferencia (la misma de build_humahuaca_terrain.py, verificada en las etiquetas del GeoTIFF): WGS 84, PixelIsPoint, el píxel (fila r,
columna c) de la tesela «S<lat>_00_W<lon>_00» está centrado en lon = −lon + c·d, lat = −lat + 1 − r·d (d = 1/3600 en GLO-30 y 1/1200 en GLO-90).
Datum vertical EGM2008. Es un modelo de SUPERFICIE (techos y árboles actuales), no el suelo de 1817.

Salidas:
  assets/terrain/humahuaca/hx_horizonte_copernicus.json   anillo del horizonte: grilla de 60 m, ±9 km alrededor del ancla, decímetros sobre
                                                          2 940 m, mismo esquema y misma receta (mediana 5 × 5 px + gaussiano de 45 m) que el
                                                          `context` de data/humahuaca_height.json, con el que empalma
  assets/terrain/humahuaca/hx_horizonte_copernicus_16bit.png   lo mismo en PNG gris de 16 bits: cota = 2500 + valor / 10 (m)
  assets/terrain/norte/norte_relieve_copernicus90.json    alturas reales (m) en la grilla del mapa del Norte (x −55..55, z −45..45, paso
                                                          0,5): el mapa es ESQUEMÁTICO, así que cada sector se ancla a su pueblo real con una
                                                          spline de placa delgada (error 0 en los 8 sectores, deformación entre ellos)
  assets/terrain/norte/norte_relieve_copernicus90_16bit.png    cota en metros enteros (PNG gris de 16 bits)
  assets/terrain/terrain_relief_manifest.json             teselas usadas (URL, bytes, SHA-256), avisos, parámetros y cifras
"""
import argparse
import hashlib
import json
import math
import pathlib
import sys
import urllib.error
import urllib.request

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "terrain"
MANIFEST = OUT / "terrain_relief_manifest.json"
UA = {"User-Agent": "patria-guemes-f5-terreno/1.0 (+https://github.com/nicospum/guemes)"}

# Humahuaca: ancla, convención y receta de tools/build_humahuaca_terrain.py (no se importa para no depender de su CLI)
LAT, LON = -23.2041, -65.3492
OFF_X, OFF_Z = 450.0, 325.0  # x = E + 450 ; z = 325 − N
DATUM = 2940.0
CTX = {"nx": 121, "nz": 91, "cell_m": 30.0, "origin_x": -1350.0, "origin_z": -1025.0}
HX_SMOOTH_M = 45.0
HX_EXPECT_SHA = "1b38c9054683f2ea927915ffc9f81e664f919cf13a6cbb4e93a1bd637301f97f"  # ADDENDA A-02
HOR_HALF_M, HOR_CELL_M = 9000.0, 60.0
FAR_HALF_M, FAR_CELL_M = 30000.0, 250.0  # «lejano»: la silueta de los cerros a 10-30 km (Hornocal, Aguilar, Zenta), de GLO-90
PNG_BASE_M = 2500.0

# Norte: sectores de scripts/game_rules.gd (_setup_norte, x/z del juego) y su pueblo real (lon, lat; centro del pueblo actual, razonado:
# «Quebrada» = Tilcara, centro de la quebrada; «Valle de Lerma» = Cerrillos)
NORTE_SECTORS = [
    ("humahuaca", 5, -27, -65.3500, -23.2050, "Humahuaca"),
    ("quebrada", -1, -21, -65.3960, -23.5770, "Tilcara (centro de la Quebrada)"),
    ("jujuy", 1, -13, -65.2995, -24.1858, "San Salvador de Jujuy"),
    ("salta", 0, 8, -65.4232, -24.7829, "Salta"),
    ("lerma", -7, 6, -65.4867, -24.8966, "Cerrillos (Valle de Lerma)"),
    ("chicoana", -9, 18, -65.5340, -25.1006, "Chicoana"),
    ("oran", 23, -12, -64.3260, -23.1371, "San Ramón de la Nueva Orán"),
    ("rosario", 8, 22, -64.9706, -25.7970, "Rosario de la Frontera"),
]
NORTE_GRID = {"x0": -55.0, "x1": 55.0, "z0": -45.0, "z1": 45.0, "step": 0.5}  # la malla de _ground() en world_view.gd cubre −55..54,2 × −45..45

NOTICE_30 = ('produced using Copernicus WorldDEM-30 © DLR e.V. 2010-2014 and © Airbus Defence and Space GmbH 2014-2018 provided under '
             'COPERNICUS by the European Union and ESA; all rights reserved')
NOTICE_90 = ('produced using Copernicus WorldDEM™-90 © DLR e.V. 2010-2014 and © Airbus Defence and Space GmbH 2014-2018 provided under '
             'COPERNICUS by the European Union and ESA; all rights reserved')
DISCLAIMER_30 = "The organisations in charge of the Copernicus programme by law or by delegation do not incur any liability for any use of the Copernicus WorldDEM-30"
DISCLAIMER_90 = "The organisations in charge of the Copernicus programme by law or by delegation do not incur any liability for any use of the Copernicus WorldDEM™-90"
LICENSE_PDF = "https://dataspace.copernicus.eu/sites/default/files/media/files/2025-06/copernicus_contributing_mission_data_access_v2_cop_dem_licenses.pdf"


def tile_name(lat_s, lon_w, glo):
    res = "10" if glo == 30 else "30"
    return "Copernicus_DSM_COG_%s_S%02d_00_W%03d_00_DEM" % (res, lat_s, lon_w)


def tile_url(lat_s, lon_w, glo):
    n = tile_name(lat_s, lon_w, glo)
    return "https://copernicus-dem-%dm.s3.amazonaws.com/%s/%s.tif" % (glo, n, n)


def sha256_file(p):
    h = hashlib.sha256()
    with open(p, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def fetch_tile(tiles_dir, lat_s, lon_w, glo, download):
    p = tiles_dir / (tile_name(lat_s, lon_w, glo) + ".tif")
    if not p.exists():
        if not download:
            raise SystemExit("falta %s (correr con --download)" % p.name)
        url = tile_url(lat_s, lon_w, glo)
        print("bajando", url, file=sys.stderr)
        req = urllib.request.Request(url, headers=UA)
        try:
            with urllib.request.urlopen(req, timeout=300) as r:
                data = r.read()
        except urllib.error.HTTPError as e:
            raise SystemExit("no se pudo bajar %s: %s" % (url, e))
        tmp = p.with_suffix(".part")
        tmp.write_bytes(data)
        tmp.rename(p)
    return p


def read_tile(p, n):
    from PIL import Image

    a = np.asarray(Image.open(p), dtype=np.float32)
    if a.shape != (n, n):
        raise SystemExit("%s mide %s y se esperaba %d × %d" % (p.name, a.shape, n, n))
    return a


def tile_record(p, lat_s, lon_w, glo):
    return {"file": p.name, "url": tile_url(lat_s, lon_w, glo), "bytes": p.stat().st_size, "sha256": sha256_file(p),
            "dataset": "COP-DEM GLO-%d (AWS copernicus-dem-%dm, release 2021)" % (glo, glo)}


def m_per_deg(lat):
    f = math.radians(lat)
    m_lat = 111132.92 - 559.82 * math.cos(2 * f) + 1.175 * math.cos(4 * f)
    m_lon = 111412.84 * math.cos(f) - 93.5 * math.cos(3 * f) + 0.118 * math.cos(5 * f)
    return m_lat, m_lon


def ss(e0, e1, x):
    t = np.clip((np.asarray(x, float) - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


# ---------------------------------------------------------------------------------------------------------------------
# Humahuaca: horizonte

def humahuaca(tiles_dir, download):
    from scipy.ndimage import gaussian_filter, map_coordinates, median_filter

    p = fetch_tile(tiles_dir, 24, 66, 30, download)
    rec = tile_record(p, 24, 66, 30)
    if rec["sha256"] != HX_EXPECT_SHA:
        raise SystemExit("la tesela GLO-30 S24 W066 no es la autorizada en A-02 (%s)" % rec["sha256"])
    a = read_tile(p, 3600)
    m_lat, m_lon = m_per_deg(LAT)
    r_c, c_c = (-23.0 - LAT) * 3600.0, (LON + 66.0) * 3600.0
    rad_r = int(math.ceil((HOR_HALF_M + 600) / m_lat * 3600))
    rad_c = int(math.ceil((HOR_HALF_M + 600) / m_lon * 3600))
    r0, c0 = int(r_c) - rad_r, int(c_c) - rad_c
    if r0 < 0 or c0 < 0 or r0 + 2 * rad_r > 3600 or c0 + 2 * rad_c > 3600:
        raise SystemExit("el recorte se sale de la tesela")
    sub = a[r0:r0 + 2 * rad_r, c0:c0 + 2 * rad_c].astype(np.float64)
    if np.isnan(sub).any():
        raise SystemExit("NaN en el recorte")
    sub = median_filter(sub, size=5, mode="nearest")
    sub = gaussian_filter(sub, (HX_SMOOTH_M / 2.0) / 30.9, mode="nearest")

    def surf(e, n):
        r = (r_c - np.asarray(n, float) / m_lat * 3600.0) - r0
        c = (c_c + np.asarray(e, float) / m_lon * 3600.0) - c0
        return map_coordinates(sub, [r, c], order=3, mode="nearest")

    # 1) control: la misma receta sobre los nodos del contexto tiene que dar el contexto del juego
    cur = json.loads((ROOT / "data" / "humahuaca_height.json").read_text(encoding="utf-8"))
    cx = CTX["origin_x"] + CTX["cell_m"] * np.arange(CTX["nx"])
    cz = CTX["origin_z"] + CTX["cell_m"] * np.arange(CTX["nz"])
    xx, zz = np.meshgrid(cx, cz)
    mine = np.round((surf(xx - OFF_X, OFF_Z - zz) - DATUM) * 10.0).astype(np.int64)
    theirs = np.asarray(cur["context"]["h"], dtype=np.int64).reshape(CTX["nz"], CTX["nx"])
    d = mine - theirs
    ctrl = {"nodes": int(d.size), "max_abs_dm": int(np.abs(d).max()), "mean_abs_dm": round(float(np.abs(d).mean()), 3),
            "equal_nodes": int((d == 0).sum())}

    # 2) la grilla del horizonte
    n = int(round(2 * HOR_HALF_M / HOR_CELL_M)) + 1
    ox, oz = OFF_X - HOR_HALF_M, OFF_Z - HOR_HALF_M
    gx = ox + HOR_CELL_M * np.arange(n)
    gz = oz + HOR_CELL_M * np.arange(n)
    hx, hz = np.meshgrid(gx, gz)
    cota = surf(hx - OFF_X, OFF_Z - hz)
    dm = np.round((cota - DATUM) * 10.0).astype(np.int64)
    grid = {"nx": n, "nz": n, "cell_m": HOR_CELL_M, "origin_x": ox, "origin_z": oz}
    out = {"contract": "f5_horizonte", "version": 1,
           "meta": {"source": "copernicus_glo30", "source_detail": "%s (%d B, SHA-256 %s), mediana 5x5 px y gaussiano de %g m; modificado: "
                    "remuestreo, suavizado y recorte" % (rec["file"], rec["bytes"], rec["sha256"], HX_SMOOTH_M),
                    "notice": NOTICE_30, "disclaimer": DISCLAIMER_30, "datum_asl_m": DATUM, "unit": "dm",
                    "order": "filas norte->sur, columnas oeste->este; índice = fila * nx + columna",
                    "frame": "x = E + 450, z = 325 - N (metros desde el ancla 23,2041 S 65,3492 O); el mismo de data/humahuaca_height.json",
                    "tag": "documentado", "tag_note": "dato medido actual (DSM 2011-2015, ±5 m); como suelo de 1817 vale «razonado», igual que el contexto",
                    "uncertainty_m": 5.0, "smooth_m": HX_SMOOTH_M, "modified": True, "builder": "tools/f5_terreno_relieve.py --humahuaca",
                    "seam_check_vs_context": ctrl},
           "grid": grid, "h": [int(v) for v in dm.ravel()],
           "stats": {"min_dm": int(dm.min()), "max_dm": int(dm.max()), "min_m": round(float(cota.min()), 1), "max_m": round(float(cota.max()), 1)}}
    (OUT / "humahuaca").mkdir(parents=True, exist_ok=True)
    jp = OUT / "humahuaca" / "hx_horizonte_copernicus.json"
    jp.write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8", newline="\n")
    from PIL import Image

    v16 = np.clip(np.round((cota - PNG_BASE_M) * 10.0), 0, 65535).astype(np.uint16)
    pp = OUT / "humahuaca" / "hx_horizonte_copernicus_16bit.png"
    Image.fromarray(v16).save(pp, optimize=True)

    # 3) cifras para comparar con el anillo procedural (ring_height de humahuaca_gfx.gd, con ruidos en su valor medio 0,5)
    ctx_x0, ctx_x1 = CTX["origin_x"], CTX["origin_x"] + CTX["cell_m"] * (CTX["nx"] - 1)
    ctx_z0, ctx_z1 = CTX["origin_z"], CTX["origin_z"] + CTX["cell_m"] * (CTX["nz"] - 1)
    rise = {}
    for name, dx, dz in [("oeste", -1, 0), ("este", 1, 0), ("norte", 0, -1), ("sur", 0, 1)]:
        if dx:
            ex = np.full(31, ctx_x0 if dx < 0 else ctx_x1)
            ez = np.linspace(ctx_z0, ctx_z1, 31)
        else:
            ez = np.full(31, ctx_z0 if dz < 0 else ctx_z1)
            ex = np.linspace(ctx_x0, ctx_x1, 31)
        base = surf(ex - OFF_X, OFF_Z - ez)
        row = {}
        for dist in (500, 1000, 2000, 4000, 6800):
            px, pz = ex + dx * dist, ez + dz * dist
            dem = float(np.mean(surf(px - OFF_X, OFF_Z - pz) - base))
            o = float(dist)
            if dx:
                proc = float(820.0 * ss(0, 1900, o) * 1.0 + 190.0 * ss(120, 1600, o) * 0.5)
            else:
                proc = float(230.0 * ss(0, 5200, o) * 1.0 + 90.0 * ss(0, 2400, o) * 0.5)
            row[str(dist)] = {"dem_m": round(dem, 1), "procedural_medio_m": round(proc, 1)}
        rise[name] = row
    info = {"tile": rec, "seam_check_vs_context": ctrl, "rise_from_context_edge": rise, "files": []}
    for f in (jp, pp):
        info["files"].append({"path": f.relative_to(ROOT).as_posix(), "bytes": f.stat().st_size, "sha256": sha256_file(f)})
    info["grid"] = grid
    info["range_m"] = [round(float(cota.min()), 1), round(float(cota.max()), 1)]
    far = humahuaca_far(tiles_dir, download)
    info["lejano"] = far[0]
    return info, (cota, grid, surf, far[1])


def humahuaca_far(tiles_dir, download):
    """Silueta lejana (±30 km, 250 m) desde GLO-90: más allá de los 9 km del horizonte, para un anillo o un fondo de cerros."""
    from scipy.ndimage import gaussian_filter, map_coordinates
    from PIL import Image

    recs, rows = [], []
    for ks in (23, 24):
        p = fetch_tile(tiles_dir, ks, 66, 90, download)
        recs.append(tile_record(p, ks, 66, 90))
        rows.append(read_tile(p, 1200))
    mos = np.vstack(rows).astype(np.float64)  # filas: −22,0 (arriba) .. −24,0
    if np.isnan(mos).any():
        raise SystemExit("NaN en GLO-90")
    mos = gaussian_filter(mos, (FAR_CELL_M / 2.0) / 92.0, mode="nearest")
    m_lat, m_lon = m_per_deg(LAT)
    n = int(round(2 * FAR_HALF_M / FAR_CELL_M)) + 1
    ox, oz = OFF_X - FAR_HALF_M, OFF_Z - FAR_HALF_M
    gx, gz = np.meshgrid(ox + FAR_CELL_M * np.arange(n), oz + FAR_CELL_M * np.arange(n))
    lat = LAT + (OFF_Z - gz) / m_lat
    lon = LON + (gx - OFF_X) / m_lon
    r = (-22.0 - lat) * 1200.0
    c = (lon + 66.0) * 1200.0
    if r.min() < 0 or r.max() > 2399 or c.min() < 0 or c.max() > 1199:
        raise SystemExit("el lejano se sale de las teselas S23/S24 W066")
    cota = map_coordinates(mos, [r, c], order=1, mode="nearest")
    dm = np.round((cota - DATUM) * 10.0).astype(np.int64)
    grid = {"nx": n, "nz": n, "cell_m": FAR_CELL_M, "origin_x": ox, "origin_z": oz}
    out = {"contract": "f5_horizonte_lejano", "version": 1,
           "meta": {"source": "copernicus_glo90", "source_detail": ", ".join("%s (%d B, SHA-256 %s)" % (t["file"], t["bytes"], t["sha256"]) for t in recs)
                    + "; gaussiano de %g m, bilineal; modificado: mosaico, remuestreo, suavizado y recorte" % (FAR_CELL_M / 2.0),
                    "notice": NOTICE_90, "disclaimer": DISCLAIMER_90, "datum_asl_m": DATUM, "unit": "dm",
                    "order": "filas norte->sur, columnas oeste->este; índice = fila * nx + columna",
                    "frame": "x = E + 450, z = 325 - N; el mismo de data/humahuaca_height.json", "tag": "documentado",
                    "tag_note": "dato medido actual (DSM); suavizado a 250 m: sirve para silueta, no para jugar", "modified": True,
                    "builder": "tools/f5_terreno_relieve.py --humahuaca"},
           "grid": grid, "h": [int(v) for v in dm.ravel()],
           "stats": {"min_m": round(float(cota.min()), 1), "max_m": round(float(cota.max()), 1)}}
    jp = OUT / "humahuaca" / "hx_lejano_copernicus90.json"
    jp.write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8", newline="\n")
    pp = OUT / "humahuaca" / "hx_lejano_copernicus90_16bit.png"
    Image.fromarray(np.clip(np.round((cota - PNG_BASE_M) * 10.0), 0, 65535).astype(np.uint16)).save(pp, optimize=True)
    info = {"tiles": recs, "grid": grid, "range_m": out["stats"], "files": []}
    for f in (jp, pp):
        info["files"].append({"path": f.relative_to(ROOT).as_posix(), "bytes": f.stat().st_size, "sha256": sha256_file(f)})
    return info, (cota, grid)


# ---------------------------------------------------------------------------------------------------------------------
# Norte: mapa esquemático anclado a los pueblos reales

def norte_warp():
    from scipy.interpolate import RBFInterpolator

    g = np.array([[s[1], s[2]] for s in NORTE_SECTORS], float)
    ll = np.array([[s[3], s[4]] for s in NORTE_SECTORS], float)
    tps = RBFInterpolator(g, ll, kernel="thin_plate_spline", smoothing=0.0, degree=1)
    X = np.c_[g, np.ones(len(g))]
    A, *_ = np.linalg.lstsq(X, ll, rcond=None)
    m_lat, m_lon = m_per_deg(-24.5)
    res = []
    for s, e in zip(NORTE_SECTORS, X @ A - ll):
        res.append({"sector": s[0], "pueblo": s[5], "affine_err_km": round(math.hypot(e[0] * m_lon, e[1] * m_lat) / 1000.0, 1)})
    return tps, res


def norte(tiles_dir, download):
    from scipy.ndimage import gaussian_filter, map_coordinates
    from PIL import Image

    tps, affine_res = norte_warp()
    G = NORTE_GRID
    xs = np.arange(G["x0"], G["x1"] + 1e-6, G["step"])
    zs = np.arange(G["z0"], G["z1"] + 1e-6, G["step"])
    gx, gz = np.meshgrid(xs, zs)
    ll = tps(np.c_[gx.ravel(), gz.ravel()])
    lon, lat = ll[:, 0].reshape(gx.shape), ll[:, 1].reshape(gx.shape)
    lat_s = range(int(math.floor(-lat.max())) + 1, int(math.floor(-lat.min())) + 2)  # tesela S<k> cubre −k .. −k+1
    lon_w = range(int(math.floor(-lon.max())) + 1, int(math.floor(-lon.min())) + 2)
    lat_s = [k for k in lat_s if -k < lat.max() and -k + 1 > lat.min()]
    lon_w = [k for k in lon_w if -k < lon.max() and -k + 1 > lon.min()]
    top, left = -min(lat_s) + 1, -max(lon_w)
    nrow, ncol = len(lat_s) * 1200, len(lon_w) * 1200
    mos = np.zeros((nrow, ncol), np.float32)
    recs = []
    for i, ks in enumerate(sorted(lat_s)):
        for j, kw in enumerate(sorted(lon_w, reverse=True)):
            p = fetch_tile(tiles_dir, ks, kw, 90, download)
            recs.append(tile_record(p, ks, kw, 90))
            mos[i * 1200:(i + 1) * 1200, j * 1200:(j + 1) * 1200] = read_tile(p, 1200)
    if np.isnan(mos).any():
        raise SystemExit("NaN en el mosaico GLO-90")
    # la grilla del juego tiene ≈ 2,4 km de paso: se promedia a bloques de 8 px (≈ 0,7 km) y se suaviza con σ ≈ 1,2 km antes de muestrear
    blk = 8
    small = mos.reshape(nrow // blk, blk, ncol // blk, blk).mean(axis=(1, 3)).astype(np.float64)
    small = gaussian_filter(small, 1.2 / (0.0926 * blk), mode="nearest")
    d = 1.0 / 1200.0 * blk
    r = (top - lat) / d - 0.5 + 0.5 / blk  # centro del bloque
    c = (lon - left) / d - 0.5 + 0.5 / blk
    h = map_coordinates(small, [r, c], order=1, mode="nearest")
    hm = np.round(h).astype(np.int64)
    sect = []
    for s in NORTE_SECTORS:
        jj, ii = int(round((s[2] - G["z0"]) / G["step"])), int(round((s[1] - G["x0"]) / G["step"]))
        sect.append({"sector": s[0], "pueblo": s[5], "x": s[1], "z": s[2], "lon": s[3], "lat": s[4], "h_m": int(hm[jj, ii])})
    out = {"contract": "f5_norte_relieve", "version": 1,
           "meta": {"source": "copernicus_glo90", "notice": NOTICE_90, "disclaimer": DISCLAIMER_90, "unit": "m",
                    "order": "filas z0->z1 (norte->sur), columnas x0->x1 (oeste->este); índice = fila * nx + columna",
                    "tag": "razonado", "tag_note": "alturas medidas (documentado) puestas sobre un mapa esquemático con una deformación de diseño: "
                    "cada sector cae sobre su pueblo real (spline de placa delgada por 8 puntos); entre ellos la geografía se estira",
                    "warp": "thin_plate_spline (x, z) -> (lon, lat), exacta en los 8 sectores; afín de referencia con error de hasta %.0f km"
                    % max(a["affine_err_km"] for a in affine_res),
                    "prefilter": "bloques de 8 px GLO-90 (≈ 0,74 km) y gaussiano σ ≈ 1,2 km; muestreo bilineal",
                    "suggested_game_height": "h_juego = 0.4 + 16.6 * pow(clamp((h_m - 300) / 4700, 0, 1), 0.65) (rango actual 0,4..17); "
                    "luego el aplanado de sectores de world_view.terrain_height", "modified": True,
                    "builder": "tools/f5_terreno_relieve.py --norte"},
           "grid": {"nx": len(xs), "nz": len(zs), "x0": G["x0"], "z0": G["z0"], "step": G["step"]},
           "sectors": sect, "affine_residuals": affine_res, "h": [int(v) for v in hm.ravel()],
           "stats": {"min_m": int(hm.min()), "max_m": int(hm.max()),
                     "geo_bbox": [round(float(lon.min()), 3), round(float(lat.min()), 3), round(float(lon.max()), 3), round(float(lat.max()), 3)]}}
    (OUT / "norte").mkdir(parents=True, exist_ok=True)
    jp = OUT / "norte" / "norte_relieve_copernicus90.json"
    jp.write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8", newline="\n")
    pp = OUT / "norte" / "norte_relieve_copernicus90_16bit.png"
    Image.fromarray(np.clip(hm, 0, 65535).astype(np.uint16)).save(pp, optimize=True)
    info = {"tiles": recs, "sectors": sect, "affine_residuals": affine_res, "range_m": [int(hm.min()), int(hm.max())],
            "geo_bbox": out["stats"]["geo_bbox"], "grid": out["grid"], "files": []}
    for f in (jp, pp):
        info["files"].append({"path": f.relative_to(ROOT).as_posix(), "bytes": f.stat().st_size, "sha256": sha256_file(f)})
    return info, (hm.astype(float), xs, zs, lon, lat)


# ---------------------------------------------------------------------------------------------------------------------
# Vistas previas

def hillshade(z, cell, az=315.0, alt=40.0, zf=1.0):
    gy, gx = np.gradient(z * zf, cell)
    slope = np.arctan(np.hypot(gx, gy))
    aspect = np.arctan2(-gx, gy)
    a, b = math.radians(360 - az + 90), math.radians(alt)
    return np.clip(np.sin(b) * np.cos(slope) + np.cos(b) * np.sin(slope) * np.cos(a - aspect), 0, 1)


def tint(z, lo, hi):
    stops = [(0.0, (88, 112, 70)), (0.25, (150, 140, 96)), (0.5, (176, 150, 112)), (0.75, (150, 120, 100)), (1.0, (236, 232, 228))]
    t = np.clip((z - lo) / max(hi - lo, 1e-6), 0, 1)
    out = np.zeros(z.shape + (3,))
    for (t0, c0), (t1, c1) in zip(stops[:-1], stops[1:]):
        m = (t >= t0) & (t <= t1)
        k = ((t - t0) / (t1 - t0))[m][:, None]
        out[m] = np.array(c0) * (1 - k) + np.array(c1) * k
    return out


def previews(prev, hx, nt):
    from PIL import Image, ImageDraw

    prev.mkdir(parents=True, exist_ok=True)
    if hx:
        cota, grid, surf, (fcota, fgrid) = hx
        hs2 = hillshade(fcota, fgrid["cell_m"])
        rgb2 = tint(fcota, 2900, 5000) * (0.35 + 0.75 * hs2[..., None])
        im2 = Image.fromarray(np.clip(rgb2, 0, 255).astype(np.uint8)).resize((900, 900), Image.LANCZOS)
        d3 = ImageDraw.Draw(im2)
        s2 = 900 / (fgrid["nx"] * fgrid["cell_m"])
        q = lambda x, z: ((x - fgrid["origin_x"]) * s2, (z - fgrid["origin_z"]) * s2)
        d3.rectangle([q(OFF_X - HOR_HALF_M, OFF_Z - HOR_HALF_M), q(OFF_X + HOR_HALF_M, OFF_Z + HOR_HALF_M)], outline=(120, 200, 255), width=2)
        d3.rectangle([q(CTX["origin_x"], CTX["origin_z"]), q(CTX["origin_x"] + 3600, CTX["origin_z"] + 2700)], outline=(255, 230, 120), width=2)
        d3.text((8, 8), "Humahuaca lejano: Copernicus GLO-90, ±30 km (celeste: horizonte ±9 km; amarillo: contexto)", fill=(255, 255, 255))
        d3.text((8, 880), "produced using Copernicus WorldDEM-90 © DLR e.V. 2010-2014 and © Airbus DS GmbH 2014-2018", fill=(255, 255, 255))
        im2.save(prev / "22_hx_lejano_dem_hillshade.png")
        hs = hillshade(cota, grid["cell_m"])
        rgb = tint(cota, 2900, 4300) * (0.35 + 0.75 * hs[..., None])
        im = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).resize((900, 900), Image.LANCZOS)
        dr = ImageDraw.Draw(im)
        sc = 900 / (grid["nx"] * grid["cell_m"])

        def px(x, z):
            return ((x - grid["origin_x"]) * sc, (z - grid["origin_z"]) * sc)

        dr.rectangle([px(CTX["origin_x"], CTX["origin_z"]), px(CTX["origin_x"] + 3600, CTX["origin_z"] + 2700)], outline=(255, 230, 120), width=2)
        dr.rectangle([px(0, 0), px(900, 652)], outline=(255, 80, 60), width=2)
        dr.text((8, 8), "Humahuaca: Copernicus GLO-30, ±9 km (rojo: ventana jugable, amarillo: contexto 30 m; fuera: hoy procedural)", fill=(255, 255, 255))
        dr.text((8, 880), "produced using Copernicus WorldDEM-30 © DLR e.V. 2010-2014 and © Airbus DS GmbH 2014-2018", fill=(255, 255, 255))
        im.save(prev / "20_hx_horizonte_dem_hillshade.png")
        # perfil oeste-este por el ancla: DEM contra el anillo procedural en su valor medio
        W, H = 1000, 420
        pi = Image.new("RGB", (W, H), (250, 248, 242))
        d2 = ImageDraw.Draw(pi)
        e = np.linspace(-8500, 8500, 600)
        dem = surf(e, np.zeros_like(e))
        ctx_e0, ctx_e1 = CTX["origin_x"] - OFF_X, CTX["origin_x"] + 3600 - OFF_X
        base_w, base_e = float(surf(np.array([ctx_e0]), np.zeros(1))[0]), float(surf(np.array([ctx_e1]), np.zeros(1))[0])
        proc = dem.copy()
        ow = np.clip(ctx_e0 - e, 0, None)
        oe = np.clip(e - ctx_e1, 0, None)
        wall = lambda o: 820.0 * ss(0, 1900, o) + 95.0 * ss(120, 1600, o)
        proc = np.where(e < ctx_e0, base_w + wall(ow) * ss(0, 260, ow), proc)
        proc = np.where(e > ctx_e1, base_e + wall(oe) * ss(0, 260, oe), proc)
        lo, hi = 2850, 4300
        Y = lambda v: H - 30 - (v - lo) / (hi - lo) * (H - 60)
        X = lambda v: 40 + (v + 8500) / 17000 * (W - 60)
        for v in range(3000, 4301, 250):
            d2.line([(40, Y(v)), (W - 20, Y(v))], fill=(225, 220, 210))
            d2.text((2, Y(v) - 6), str(v), fill=(90, 90, 90))
        for xv in (ctx_e0, ctx_e1):
            d2.line([(X(xv), 20), (X(xv), H - 30)], fill=(230, 190, 90))
        d2.line(list(zip(X(e), Y(proc))), fill=(200, 90, 60), width=2)
        d2.line(list(zip(X(e), Y(dem))), fill=(40, 70, 120), width=2)
        d2.text((48, 6), "Perfil O-E por el ancla (m s. n. m.). Azul: Copernicus. Rojo: anillo procedural actual (ruidos en su valor medio). Amarillo: borde del contexto", fill=(30, 30, 30))
        pi.save(prev / "21_hx_perfil_oeste_este.png")
    if nt:
        hm, xs, zs, lon, lat = nt
        hs = hillshade(hm, 2400.0, zf=1.0)
        rgb = tint(hm, 300, 5000) * (0.35 + 0.75 * hs[..., None])
        im = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).resize((len(xs) * 4, len(zs) * 4), Image.LANCZOS)
        dr = ImageDraw.Draw(im)
        for s in NORTE_SECTORS:
            cx, cz = (s[1] - xs[0]) / 0.5 * 4, (s[2] - zs[0]) / 0.5 * 4
            dr.ellipse([cx - 5, cz - 5, cx + 5, cz + 5], outline=(255, 255, 255), width=2)
            dr.text((cx + 8, cz - 6), s[0], fill=(255, 255, 255))
        dr.text((8, 8), "Norte: Copernicus GLO-90 sobre la grilla del mapa (x -55..55, z -45..45), sectores anclados a su pueblo real", fill=(255, 255, 255))
        im.save(prev / "30_norte_dem_hillshade.png")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--tiles-dir", required=True)
    ap.add_argument("--download", action="store_true")
    ap.add_argument("--humahuaca", action="store_true")
    ap.add_argument("--norte", action="store_true")
    ap.add_argument("--preview-dir")
    a = ap.parse_args()
    td = pathlib.Path(a.tiles_dir).resolve()
    if ROOT in td.parents or td == ROOT:
        ap.error("las teselas van fuera del repo")
    td.mkdir(parents=True, exist_ok=True)
    man = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() else {}
    man.update({"contract": "f5_terreno_relieve", "version": 1, "builder": "tools/f5_terreno_relieve.py",
                "license": {"glo30": "Licence for Copernicus DEM instance COP-DEM-GLO-30-F Global 30m Full, Free & Open (Art. 4 y 6)",
                            "glo90": "Licence for COP-DEM-GLO-90-F Global 90m Full, Free & Open (Art. 4 y 6)", "pdf": LICENSE_PDF,
                            "pdf_sha256": "bb4a01dcd7f61acefa81c9ccd76af975e12096158169acf0d7b5c44c26c8701f", "checked": "2026-11-09",
                            "notice_glo30": NOTICE_30, "notice_glo90": NOTICE_90, "disclaimer_glo30": DISCLAIMER_30, "disclaimer_glo90": DISCLAIMER_90},
                "credits_ref": "docs/CREDITOS.md (visual/r1 F5 · terreno)"})
    hx = nt = None
    if a.humahuaca or a.download:
        info, hx = humahuaca(td, a.download)
        man["humahuaca_horizonte"] = info
        print(json.dumps({k: info[k] for k in ("seam_check_vs_context", "range_m", "grid")}, ensure_ascii=False))
        print(json.dumps(info["rise_from_context_edge"], ensure_ascii=False))
        print(json.dumps(info["lejano"]["range_m"], ensure_ascii=False))
    if a.norte or a.download:
        info, nt = norte(td, a.download)
        man["norte"] = info
        print(json.dumps({k: info[k] for k in ("range_m", "geo_bbox", "grid")}, ensure_ascii=False))
        print(json.dumps(info["sectors"], ensure_ascii=False))
        print(json.dumps(info["affine_residuals"], ensure_ascii=False))
        print("teselas GLO-90:", len(info["tiles"]))
    OUT.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(json.dumps(man, ensure_ascii=False, indent=1) + "\n", encoding="utf-8", newline="\n")
    if a.preview_dir:
        previews(pathlib.Path(a.preview_dir), hx, nt)


if __name__ == "__main__":
    main()
