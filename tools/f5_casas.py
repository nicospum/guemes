"""visual/r1 F5 (parte B, solo assets) - kit de edificios del territorio. Blender 4.4.x en línea de comandos.

    blender -b --disable-autoexec --factory-startup --python tools/f5_casas.py -- [--only casa_rancho_a,capilla_b]
        [--out assets/models] [--no-lod]
    blender -b --disable-autoexec --factory-startup --python tools/f5_casas.py -- --preview [--prev-dir ../qa-visual-r1/f5_casas_preview]

Obra propia del proyecto (geometría procedural y color por vértice calculado acá); no se descarga ni se usa material de
terceros. Sin texturas: COLOR_0 lineal con el color final (adobe, cal, torta, paja, teja, madera, piedra), con variación
por cara (adobes, piedras, hiladas de teja, descascarado de la cal), suciedad al pie de los muros y oclusión ambiental
calculada con rayos contra la propia malla y el suelo.

Convenciones (las de tools/create_models.py y tools/f4_caballos.py): metros; Blender +Y = frente (Godot -Z); Z arriba
(Godot +Y); origen en el suelo, en el centro de la caja del modelo. Primera primitiva: la esfera de 2 mm «F5 | ancla»
(defecto del importador de Godot 4.7.2 con COLOR_0, ver docs/ASSETS.md). Pocas superficies por modelo (una por material).

Salidas en assets/models/: casa_<tipo>_<variante>.glb, ..._lod.glb y f5_casas_manifest.json (triángulos, materiales,
cotas, puertas, sha256, etiqueta y nota). Base histórica y etiquetas de cada tipo: docs/historia/CASAS_F5.md.
"""
import bpy
import math
import json
import struct
import hashlib
import sys
import numpy as np
from pathlib import Path
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[1]
ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def _arg(name, default=None):
    return ARGV[ARGV.index(name) + 1] if name in ARGV else default


OUT = Path(_arg("--out", str(ROOT / "assets" / "models")))
PREV = Path(_arg("--prev-dir", str(ROOT.parent / "qa-visual-r1" / "f5_casas_preview")))
ONLY = _arg("--only").split(",") if _arg("--only") else None
LOD = "--no-lod" not in ARGV
REPORT = {}


# --------------------------------------------------------------------------------------
# Paleta (sRGB). Etiqueta «diseño»: tonos de lectura, no mediciones de un edificio. Los tonos de tierra van más cálidos que
# la lámina 06 (la luna fría los volvía gris verdoso, ver hx_models_sin_blender.py) y separados del suelo seco (#B99A72,
# L* ≈ 65): muros encalados más claros (L* ≈ 86) y adobe sin revocar y techos de torta más oscuros (L* ≈ 47 y 36), para
# el contraste edificio–suelo de B-062 (c). La teja es pardo-terracota apagada: en el Norte el rojo es solo del enemigo.
# --------------------------------------------------------------------------------------
HEX = {
    "adobe": "#94714F", "adobe_claro": "#A88560", "adobe_oscuro": "#7A5B40", "revoque": "#9C7B58",
    "cal": "#EAE4D6", "cal_sucia": "#D6CCB6", "cal_ba": "#EDE8DC", "ladrillo": "#8F5E46",
    "torta": "#66503B", "torta_seca": "#80684F", "cana": "#B19D72",
    "paja": "#8F7A58", "paja_oscura": "#6E5B42", "paja_clara": "#A68F68",
    "teja": "#85634E", "teja_oscura": "#6A4E3E", "teja_liquen": "#6F6A58",
    "madera": "#59432E", "madera_gris": "#74685A", "cardon": "#8D7E66", "algarrobo": "#4E3B2A",
    "piedra": "#8E8A80", "piedra_osc": "#6F685E", "piedra_ocre": "#9A8670", "piedra_clara": "#A39B8B", "piedra_rojiza": "#8A6B57",
    "sedimento": "#5E4B37", "hierro": "#3B3A37", "bronce": "#6A5634", "sombra": "#1C1814",
    "suelo": "#B99A72",
}


def lin(h):
    h = h.lstrip("#")
    c = np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


P = {k: lin(v) for k, v in HEX.items()}

# Material (superficie) -> rugosidad. El color va todo por vértice; el material da la respuesta a la luz.
MATS = {"ancla": .9, "muro": .93, "techo": .96, "teja": .78, "madera": .82, "piedra": .9, "hierro": .55, "sombra": 1.0}


def lstar(rgb_lin):
    y = float(np.dot(rgb_lin, [0.2126, 0.7152, 0.0722]))
    return 116 * (y ** (1 / 3)) - 16 if y > 0.008856 else 903.3 * y


# --------------------------------------------------------------------------------------
# Ruido determinista (por posición): variación por cara y por vértice
# --------------------------------------------------------------------------------------
def h3(x, y, z, s=0):
    v = math.sin(x * 127.1 + y * 311.7 + z * 74.7 + s * 19.19) * 43758.5453
    return v - math.floor(v)


def vnoise(p, f=1.0, s=0):
    x, y, z = p[0] * f, p[1] * f, p[2] * f
    xi, yi, zi = math.floor(x), math.floor(y), math.floor(z)
    xf, yf, zf = x - xi, y - yi, z - zi
    u, v, w = (t * t * (3 - 2 * t) for t in (xf, yf, zf))
    acc = 0.0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                wt = (u if dx else 1 - u) * (v if dy else 1 - v) * (w if dz else 1 - w)
                acc += wt * h3(xi + dx, yi + dy, zi + dz, s)
    return acc


def fbm(p, f=1.0, s=0):
    return .6 * vnoise(p, f, s) + .3 * vnoise(p, f * 2.3, s + 7) + .1 * vnoise(p, f * 5.1, s + 13)


def sstep(e0, e1, x):
    t = min(1.0, max(0.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


# --------------------------------------------------------------------------------------
# Constructor de mallas propio: caras con vértices propios (sombreado plano), color base por cara y «clase» de color
# --------------------------------------------------------------------------------------
def newell(pts):
    n = Vector((0, 0, 0))
    for i, a in enumerate(pts):
        b = pts[(i + 1) % len(pts)]
        n.x += (a.y - b.y) * (a.z + b.z)
        n.y += (a.z - b.z) * (a.x + b.x)
        n.z += (a.x - b.x) * (a.y + b.y)
    return n


class Kit:
    def __init__(self, name, seed=1):
        self.name = name
        self.seed = seed
        self.V, self.F, self.fm, self.fc, self.fk = [], [], [], [], []
        self.doors = []          # centros de puertas (Blender), para la lumbre de la integración
        self.ground_extra = []   # nada por ahora

    # ---- caras
    def poly(self, pts, mat, col, kind="", out=None):
        pts = [Vector(p) for p in pts]
        clean = []
        for p in pts:
            if not clean or (p - clean[-1]).length > 1e-6:
                clean.append(p)
        if len(clean) > 2 and (clean[0] - clean[-1]).length < 1e-6:
            clean.pop()
        if len(clean) < 3:
            return
        n = newell(clean)
        if n.length < 1e-7:
            return
        if out is not None and n.dot(Vector(out)) < 0:
            clean.reverse()
        i = len(self.V)
        self.V += clean
        self.F.append(tuple(range(i, i + len(clean))))
        self.fm.append(mat)
        self.fc.append(np.array(P[col] if isinstance(col, str) else col, float))
        self.fk.append(kind)

    def grid(self, p0, p1, p2, p3, mat, col, kind="", cell=0.6, out=None, jit=0.0, cellv=None):
        P0, P1, P2, P3 = (Vector(p) for p in (p0, p1, p2, p3))
        if out is not None and newell([P0, P1, P2, P3]).dot(Vector(out)) < 0:
            P1, P3 = P3, P1
        nrm = newell([P0, P1, P2, P3])
        if nrm.length < 1e-9:
            return
        nrm.normalize()
        lu = max((P1 - P0).length, (P2 - P3).length)
        lv = max((P3 - P0).length, (P2 - P1).length)
        nu = max(1, math.ceil(lu / cell - 1e-6))
        nv = max(1, math.ceil(lv / (cellv or cell) - 1e-6))

        def at(i, j):
            u, v = i / nu, j / nv
            p = P0.lerp(P1, u).lerp(P3.lerp(P2, u), v)
            if jit and 0 < i < nu and 0 < j < nv:
                p = p + nrm * (jit * (h3(round(p.x, 3), round(p.y, 3), round(p.z, 3), 5) - .5) * 2)
            return p
        for i in range(nu):
            for j in range(nv):
                self.poly([at(i, j), at(i + 1, j), at(i + 1, j + 1), at(i, j + 1)], mat, col, kind, out=nrm)

    HEXA_FACES = {"-z": (0, 1, 2, 3), "+z": (4, 5, 6, 7), "-y": (0, 1, 5, 4), "+x": (1, 2, 6, 5), "+y": (2, 3, 7, 6), "-x": (3, 0, 4, 7)}

    def hexa(self, c8, mat, col, kind="", cell=0.6, skip=("-z",), fcols=None, fkinds=None, jit=0.0, fmats=None, cellv=None, fcells=None):
        c = [Vector(p) for p in c8]
        ctr = sum(c, Vector()) / 8
        for key, (a, b, cc, d) in self.HEXA_FACES.items():
            if key in skip:
                continue
            fc = (c[a] + c[b] + c[cc] + c[d]) / 4
            colf = (fcols or {}).get(key, col)
            kf = (fkinds or {}).get(key, kind)
            mf = (fmats or {}).get(key, mat)
            cf = (fcells or {}).get(key, cell)
            self.grid(c[a], c[b], c[cc], c[d], mf, colf, kf, cf, out=fc - ctr, jit=jit if key == "+z" else 0.0, cellv=cellv if cf == cell else cf)

    def box(self, x0, x1, y0, y1, z0, z1, mat, col, kind="", cell=0.6, skip=("-z",), **kw):
        self.hexa([(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
                   (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], mat, col, kind, cell, skip, **kw)

    def rbox(self, ctr, size, yaw, mat, col, kind="", cell=0.6, skip=("-z",), pitch=0.0, **kw):
        """Caja girada (yaw alrededor de Z, luego pitch alrededor de X local)."""
        sx, sy, sz = (s / 2 for s in size)
        m = Matrix.Translation(Vector(ctr)) @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Rotation(pitch, 4, "X")
        pts = [m @ Vector(p) for p in [(-sx, -sy, -sz), (sx, -sy, -sz), (sx, sy, -sz), (-sx, sy, -sz),
                                        (-sx, -sy, sz), (sx, -sy, sz), (sx, sy, sz), (-sx, sy, sz)]]
        self.hexa(pts, mat, col, kind, cell, skip, **kw)

    def cyl(self, a, b, r, mat, col, kind="", sides=6, r2=None, caps=(False, True), segs=1, rot=0.0):
        a, b = Vector(a), Vector(b)
        ax = b - a
        if ax.length < 1e-6:
            return
        d = ax.normalized()
        ref = Vector((0, 0, 1)) if abs(d.z) < .9 else Vector((1, 0, 0))
        u = d.cross(ref).normalized()
        w = d.cross(u).normalized()
        r2 = r if r2 is None else r2
        rings = []
        for s in range(segs + 1):
            t = s / segs
            ctr = a.lerp(b, t)
            rr = r + (r2 - r) * t
            rings.append([ctr + (u * math.cos(rot + 2 * math.pi * k / sides) + w * math.sin(rot + 2 * math.pi * k / sides)) * rr
                          for k in range(sides)])
        for s in range(segs):
            ctr = a.lerp(b, (s + .5) / segs)
            for k in range(sides):
                q = [rings[s][k], rings[s][(k + 1) % sides], rings[s + 1][(k + 1) % sides], rings[s + 1][k]]
                self.poly(q, mat, col, kind, out=(q[0] + q[1]) / 2 - ctr)
        if caps[0]:
            self.poly(rings[0], mat, col, kind, out=-d)
        if caps[1] and r2 > 1e-4:
            self.poly(rings[-1], mat, col, kind, out=d)

    # ---- muros con vanos
    def wall(self, axis, a0, a1, c0, c1, z0, z1, ops, col, kind, cell=0.9, inner=None, ends=(True, True), mat="muro", top=True, cellv=.7):
        """Muro recto a lo largo de X (axis 'x', espesor en Y entre c0 y c1) o de Y, con vanos [(a, b, za, zb)]. Sin la cara
        de abajo ni la de adentro (`inner`, p. ej. '-y'); `ends` dice si se dibujan las cabezas del muro."""
        al = ("-x", "+x") if axis == "x" else ("-y", "+y")
        base_skip = ["-z"] + ([inner] if inner else [])
        tsk = [] if top else ["+z"]

        def B(p0, p1, q0, q1, sk, kd=kind):
            if p1 - p0 < 1e-3 or q1 - q0 < 1e-3:
                return
            cl = max(cell, .9)
            if axis == "x":
                self.box(p0, p1, c0, c1, q0, q1, mat, col, kd, cl, skip=tuple(sk), cellv=cellv)
            else:
                self.box(c0, c1, p0, p1, q0, q1, mat, col, kd, cl, skip=tuple(sk), cellv=cellv)
        cur, first = a0, True
        for oa, ob, za, zb in sorted(ops):
            sk = list(base_skip)
            if first and not ends[0]:
                sk.append(al[0])
            B(cur, oa, z0, z1, sk + tsk)
            if za > z0 + 1e-3:
                B(oa, ob, z0, za, base_skip + list(al))
            if zb < z1 - 1e-3:
                B(oa, ob, zb, z1, [s for s in base_skip if s != "-z"] + list(al) + tsk)
            cur, first = ob, False
        sk = list(base_skip)
        if not ends[1]:
            sk.append(al[1])
        if first and not ends[0]:
            sk.append(al[0])
        B(cur, a1, z0, z1, sk + tsk)


# --------------------------------------------------------------------------------------
# Piezas de oficio: puertas, ventanas, horcones, rollizos, techos
# --------------------------------------------------------------------------------------
def door(k, axis, x, face, outdir, w, h, z0, t, ajar=0.0, style="tablas", lintel=True):
    """Puerta en el vano de un muro. `face`: coordenada del plano exterior del muro; `outdir` = +1/-1 hacia afuera.
    Hoja de tablas retirada, fondo oscuro, dintel de madera (adobe) o nada (ladrillo revocado con `lintel=False`)."""
    s = outdir
    inner = face - s * t
    if axis == "x":
        k.poly([(x - w / 2, inner + s * .02, z0), (x + w / 2, inner + s * .02, z0), (x + w / 2, inner + s * .02, z0 + h),
                (x - w / 2, inner + s * .02, z0 + h)], "sombra", "sombra", "sombra", out=(0, s, 0))
        yl = face - s * t * .55
        if ajar > 0:
            hx = x - w / 2 + .02
            L = w - .04
            cx = hx + L / 2 * math.cos(ajar)
            cy = yl - s * L / 2 * math.sin(ajar)
            k.rbox((cx, cy, z0 + h / 2), (L, .05, h - .02), -s * ajar, "madera", "madera", "madera", .45, skip=())
        else:
            for i in range(3 if w > 1.0 else 2):
                nn = 3 if w > 1.0 else 2
                xa = x - w / 2 + .01 + i * (w - .02) / nn
                k.box(xa, xa + (w - .02) / nn - .012, min(yl, yl + s * .05), max(yl, yl + s * .05), z0, z0 + h - .01,
                      "madera", "madera", "madera", .5, skip=("-z",))
        k.doors.append((x, face + s * .05, z0 + h * .5))
        if lintel:
            ya, yb = sorted((face - s * .06, face + s * .04))
            k.box(x - w / 2 - .22, x + w / 2 + .22, ya, yb, z0 + h, z0 + h + .15, "madera", "madera", "madera", .6, skip=("-z",))
    else:
        k.poly([(inner + s * .02, x - w / 2, z0), (inner + s * .02, x + w / 2, z0), (inner + s * .02, x + w / 2, z0 + h),
                (inner + s * .02, x - w / 2, z0 + h)], "sombra", "sombra", "sombra", out=(s, 0, 0))
        xl = face - s * t * .55
        k.box(min(xl, xl + s * .05), max(xl, xl + s * .05), x - w / 2 + .01, x + w / 2 - .01, z0, z0 + h - .01,
              "madera", "madera", "madera", .5)
        k.doors.append((face + s * .05, x, z0 + h * .5))
        if lintel:
            xa, xb = sorted((face - s * .06, face + s * .04))
            k.box(xa, xb, x - w / 2 - .22, x + w / 2 + .22, z0 + h, z0 + h + .15, "madera", "madera", "madera", .6)


def window(k, x, face, outdir, w, za, zb, t, reja="madera", postigo=True, lintel=True):
    """Ventana en un muro a lo largo de X: fondo oscuro, reja (barrotes de madera o de hierro) y postigo abierto."""
    s = outdir
    inner = face - s * t
    k.poly([(x - w / 2, inner + s * .02, za), (x + w / 2, inner + s * .02, za), (x + w / 2, inner + s * .02, zb),
            (x - w / 2, inner + s * .02, zb)], "sombra", "sombra", "sombra", out=(0, s, 0))
    yb = face - s * .12
    if reja:
        n = max(2, int(w / .14))
        for i in range(1, n):
            xx = x - w / 2 + i * w / n
            if reja == "hierro":
                k.cyl((xx, yb, za), (xx, yb, zb), .014, "hierro", "hierro", "hierro", sides=4, caps=(False, False))
            else:
                k.cyl((xx, yb, za), (xx, yb, zb), .03, "madera", "madera", "madera", sides=5, caps=(False, False))
        if reja == "hierro":
            for zz in (za + .12, zb - .12):
                k.box(x - w / 2, x + w / 2, min(yb, yb + s * .02) - .01, max(yb, yb + s * .02) + .01, zz - .015, zz + .015,
                      "hierro", "hierro", "hierro", 2.0, skip=())
    if postigo:
        # una hoja abierta contra el muro, del lado derecho
        ya, yb2 = sorted((face + s * .01, face + s * .05))
        k.box(x + w / 2 + .02, x + w / 2 + .02 + w * .5, ya, yb2, za, zb, "madera", "madera", "madera", .5, skip=())
    if lintel:
        ya, yb2 = sorted((face - s * .06, face + s * .04))
        k.box(x - w / 2 - .18, x + w / 2 + .18, ya, yb2, zb, zb + .12, "madera", "madera", "madera", .6, skip=("-z",))
    # alféizar de barro
    ya, yb2 = sorted((face - s * .02, face + s * .06))
    k.box(x - w / 2 - .04, x + w / 2 + .04, ya, yb2, za - .06, za, "muro", "revoque", "adobe", .6, skip=("-z",))


def horcon(k, x, y, h, r=.09, along="x", col="algarrobo", fork=True, base_stone=True):
    """Horcón: tronco con horqueta arriba (dos brazos cortos) donde apoya la viga."""
    lean = (h3(x, y, 1) - .5) * .06
    top = (x + lean, y + (h3(x, y, 2) - .5) * .05, h - .18)
    k.cyl((x, y, 0), top, r, "madera", col, "madera", sides=6, r2=r * .85, caps=(False, False), segs=2)
    if fork:
        for sgn in (-1, 1):
            d = Vector((sgn * .16, 0, .26)) if along == "x" else Vector((0, sgn * .16, .26))
            k.cyl(top, Vector(top) + d, r * .7, "madera", col, "madera", sides=5, r2=r * .5, caps=(False, True))
    else:
        k.cyl(top, (top[0], top[1], h), r * .85, "madera", col, "madera", sides=6, caps=(False, True))
    if base_stone:
        k.rbox((x, y, .06), (r * 3.2, r * 3.0, .14), h3(x, y, 3) * 3, "piedra", "piedra_osc", "piedra", 1.0)


def poste(k, x, y, h, s=.15, col="madera"):
    """Pilar escuadrado de madera (corredor de la quinta, casa de Salta) con zapata."""
    k.box(x - s / 2, x + s / 2, y - s / 2, y + s / 2, 0, h, "madera", col, "madera", .9, skip=("-z",))
    k.box(x - s, x + s, y - s / 2 - .02, y + s / 2 + .02, h - .12, h, "madera", col, "madera", .9, skip=())
    k.box(x - s * .8, x + s * .8, y - s * .8, y + s * .8, 0, .12, "piedra", "piedra_clara", "piedra", .9)


def plinth(k, x0, x1, y0, y1, h=.32, col="piedra", over=.05):
    """Cimiento/sobrecimiento de piedra asomado, un poco más ancho que el muro (solo los costados y el reborde de arriba)."""
    a0, a1, b0, b1 = x0 - over, x1 + over, y0 - over, y1 + over
    k.box(a0, a1, b0, b1, 0, h, "piedra", col, "piedra", .55, skip=("-z", "+z"), cellv=1.0)
    for (p, q, r, s_) in (((a0, b0), (a1, b0), (x1, y0), (x0, y0)), ((a1, b0), (a1, b1), (x1, y1), (x1, y0)),
                          ((a1, b1), (a0, b1), (x0, y1), (x1, y1)), ((a0, b1), (a0, b0), (x0, y0), (x0, y1))):
        k.poly([(p[0], p[1], h), (q[0], q[1], h), (r[0], r[1], h), (s_[0], s_[1], h)], "piedra", col, "piedra", out=(0, 0, 1))


def rollizos(k, x0, x1, y_in, y_out, z_in, z_out, step=.55, r=.065, col="algarrobo"):
    n = max(2, int((x1 - x0) / step))
    for i in range(n + 1):
        x = x0 + (x1 - x0) * i / n
        j = (h3(x, y_out, 4) - .5) * .12
        k.cyl((x, y_in, z_in), (x, y_out + j, z_out), r, "madera", col, "madera", sides=5, caps=(False, True))


def roof_flat(k, x0, x1, y0, y1, z_back, z_front, th=.2, col="torta", under="cana", cell=.9, jit=.025):
    """Techo de torta casi plano: losa de barro sobre cañizo, cayendo de atrás (y0) hacia el frente (y1)."""
    zt = lambda y: z_back + (z_front - z_back) * (y - y0) / (y1 - y0)
    k.hexa([(x0, y0, zt(y0) - th), (x1, y0, zt(y0) - th), (x1, y1, zt(y1) - th), (x0, y1, zt(y1) - th),
            (x0, y0, zt(y0)), (x1, y0, zt(y0)), (x1, y1, zt(y1)), (x0, y1, zt(y1))],
           "techo", col, "torta", cell, skip=(), fcols={"-z": under}, fkinds={"-z": "cana"}, jit=jit, fcells={"-z": 1.6})
    return zt


def gable_slabs(k, x0, x1, half, z_eave, z_ridge, th, col, kind, mat="techo", cell=.8, jit=0.0, under=None, ukind=None, axis="x"):
    """Dos faldones de un techo a dos aguas con cumbrera a lo largo de X (o de Y); `half` = semiancho hasta el alero."""
    for s in (-1, 1):
        if axis == "x":
            e0, e1 = (x0, s * half, z_eave), (x1, s * half, z_eave)
            r0, r1 = (x0, 0, z_ridge), (x1, 0, z_ridge)
        else:
            e0, e1 = (s * half, x0, z_eave), (s * half, x1, z_eave)
            r0, r1 = (0, x0, z_ridge), (0, x1, z_ridge)
        bot = [Vector(p) - Vector((0, 0, th)) for p in (e0, e1, r1, r0)]
        top = [Vector(p) for p in (e0, e1, r1, r0)]
        k.hexa(bot + top, mat, col, kind, cell, skip=(), jit=jit,
               fcols={"-z": under} if under else None, fkinds={"-z": ukind} if ukind else None, fcells={"-z": 1.8})


def thatch_roof(k, x0, x1, half, z_eave, z_ridge, axis="x", layers=2, th=.26, col="paja", cap="torta"):
    """Paja a dos aguas en capas escalonadas (el borde grueso del alero se ve), con caballete de barro."""
    for L in range(layers):
        t0 = L / layers
        t1 = min(1.0, (L + 1) / layers + .12)
        for s in (-1, 1):
            def pt(x, t, dz=0.0):
                y = s * half * (1 - t)
                z = z_eave + (z_ridge - z_eave) * t + dz + L * .05
                return (x, y, z) if axis == "x" else (y, x, z)
            ox = .06 * L
            bot = [pt(x0 - ox, t0, -th), pt(x1 + ox, t0, -th), pt(x1 + ox, t1, -th), pt(x0 - ox, t1, -th)]
            top = [pt(x0 - ox, t0), pt(x1 + ox, t0), pt(x1 + ox, t1), pt(x0 - ox, t1)]
            k.hexa(bot + top, "techo", col, "paja", .4, skip=(), jit=.05, fcols={"-z": "paja_oscura"}, cellv=1.1,
                   fcells={"-z": 1.8, "-y": 1.0, "+y": 1.0})
    # caballete de barro
    zr = z_ridge + (layers - 1) * .05
    if axis == "x":
        k.hexa([(x0 - .1, -.28, zr - .12), (x1 + .1, -.28, zr - .12), (x1 + .1, .28, zr - .12), (x0 - .1, .28, zr - .12),
                (x0 - .1, -.06, zr + .14), (x1 + .1, -.06, zr + .14), (x1 + .1, .06, zr + .14), (x0 - .1, .06, zr + .14)],
               "techo", cap, "torta", .8, skip=("-z",))
    else:
        k.hexa([(-.28, x0 - .1, zr - .12), (.28, x0 - .1, zr - .12), (.28, x1 + .1, zr - .12), (-.28, x1 + .1, zr - .12),
                (-.06, x0 - .1, zr + .14), (.06, x0 - .1, zr + .14), (.06, x1 + .1, zr + .14), (-.06, x1 + .1, zr + .14)],
               "techo", cap, "torta", .8, skip=("-z",))


def tile_roof(k, x0, x1, half, z_eave, z_ridge, courses=2, pitch=.3, amp=.075, axis="x", ridge=True):
    """Teja colonial a dos aguas: faldón de base, canales y cobijas (onda) por hiladas, cumbrera de tejas."""
    th = .1
    gable_slabs(k, x0, x1, half, z_eave, z_ridge, th, "teja_oscura", "teja", mat="teja", cell=4.0, axis=axis)
    n = max(2, int(round((x1 - x0) / pitch)))
    for s in (-1, 1):
        def pt(u, v, hgt):
            x = x0 + (x1 - x0) * u
            y = s * half * (1 - v)
            z = z_eave + (z_ridge - z_eave) * v + hgt + .005
            # la normal del faldón (hacia arriba): la onda sale del plano
            ny, nz = s * (z_ridge - z_eave), half
            ln = math.hypot(ny, nz)
            y += hgt * ny / ln - hgt * 0
            z += hgt * (nz / ln - 1)
            return (x, y, z) if axis == "x" else (y, x, z)
        for c in range(courses):
            v0, v1 = c / courses, (c + 1) / courses
            for i in range(n):
                ha = amp if i % 2 else 0.0
                hb_ = 0.0 if i % 2 else amp
                lift = .03  # el borde de abajo de cada hilada asoma sobre la de abajo
                q = [pt(i / n, v0, ha + lift), pt((i + 1) / n, v0, hb_ + lift), pt((i + 1) / n, v1, hb_), pt(i / n, v1, ha)]
                up = (0, 0, 1)
                k.poly(q, "teja", "teja", "teja", out=up)
                if c == 0:   # cierre del alero: la boca de las tejas
                    k.poly([pt(i / n, 0, 0), pt((i + 1) / n, 0, 0), pt((i + 1) / n, 0, hb_ + lift), pt(i / n, 0, ha + lift)],
                           "teja", "teja_oscura", "teja", out=(0, s, 0) if axis == "x" else (s, 0, 0))
    if ridge:
        zr = z_ridge + .05
        nseg = max(2, int((x1 - x0) / .45))
        for i in range(nseg):
            a = x0 + (x1 - x0) * i / nseg
            b = x0 + (x1 - x0) * (i + 1) / nseg + .03
            pa, pb = ((a, 0, zr), (b, 0, zr)) if axis == "x" else ((0, a, zr), (0, b, zr))
            k.cyl(pa, pb, .13, "teja", "teja", "teja", sides=6, caps=(False, False), rot=0)


def gable_wall(k, axis, pos, half, z0, z1, t, col, kind, outdir, cell=.5):
    """Hastial (triángulo de muro) sobre un muro testero: a lo largo de Y en x=pos (axis 'x' = cumbrera en X)."""
    a, b = (pos - t, pos) if outdir > 0 else (pos, pos + t)
    if axis == "x":
        c8 = [(a, -half, z0), (b, -half, z0), (b, half, z0), (a, half, z0), (a, 0, z1), (b, 0, z1), (b, 0, z1), (a, 0, z1)]
        # caras: usamos poly directo (prisma triangular)
        k.grid((b, -half, z0), (b, half, z0), (b, 0, z1), (b, 0, z1), "muro", col, kind, cell, out=(1, 0, 0))
        k.grid((a, half, z0), (a, -half, z0), (a, 0, z1), (a, 0, z1), "muro", col, kind, cell, out=(-1, 0, 0))
    else:
        k.grid((-half, b, z0), (half, b, z0), (0, b, z1), (0, b, z1), "muro", col, kind, cell, out=(0, 1, 0))
        k.grid((half, a, z0), (-half, a, z0), (0, a, z1), (0, a, z1), "muro", col, kind, cell, out=(0, -1, 0))


def walls_rect(k, W, D, H, t, col, kind, doors_front=(), wins_front=(), doors_back=(), wins_back=(), zb=0.3,
               side_ops=None, cell=.5, Hl=None, Hr=None):
    """Cuatro muros de una pieza rectangular (frente +Y). Devuelve nada; vanos en frente/fondo por (x, w, h) / (x, w, za, zb)."""
    ops_f = [(x - w / 2, x + w / 2, zb, zb + h) for x, w, h in doors_front] + [(x - w / 2, x + w / 2, zb + za, zb + zz) for x, w, za, zz in wins_front]
    ops_b = [(x - w / 2, x + w / 2, zb, zb + h) for x, w, h in doors_back] + [(x - w / 2, x + w / 2, zb + za, zb + zz) for x, w, za, zz in wins_back]
    k.wall("x", -W / 2, W / 2, D / 2 - t, D / 2, zb, H, ops_f, col, kind, cell, inner="-y")
    k.wall("x", -W / 2, W / 2, -D / 2, -D / 2 + t, zb, H, ops_b, col, kind, cell, inner="+y")
    so = side_ops or {}
    k.wall("y", -D / 2 + t, D / 2 - t, -W / 2, -W / 2 + t, zb, Hl or H, so.get("l", []), col, kind, cell, inner="+x", ends=(False, False))
    k.wall("y", -D / 2 + t, D / 2 - t, W / 2 - t, W / 2, zb, Hr or H, so.get("r", []), col, kind, cell, inner="-x", ends=(False, False))
    # tapa interior (nadie la ve, pero cierra la caja si el techo vuela)
    for x, w, h in doors_front:
        door(k, "x", x, D / 2, 1, w, h, zb, t)
    for x, w, za, zz in wins_front:
        window(k, x, D / 2, 1, w, zb + za, zb + zz, t)
    for x, w, h in doors_back:
        door(k, "x", x, -D / 2, -1, w, h, zb, t)
    for x, w, za, zz in wins_back:
        window(k, x, -D / 2, -1, w, zb + za, zb + zz, t)


def palenque(k, x0, x1, y, h=1.05):
    for x in (x0, x1):
        k.cyl((x, y, 0), (x, y, h + .1), .08, "madera", "algarrobo", "madera", sides=6, caps=(False, True))
    k.cyl((x0 - .15, y, h), (x1 + .15, y, h), .055, "madera", "madera_gris", "madera", sides=5, caps=(True, True))


def tranquera(k, x0, x1, y, h=1.35, axis="x"):
    """Tranquera de palos: dos postes y cuatro trancas horizontales."""
    def p(a, b, z):
        return (a, b, z) if axis == "x" else (b, a, z)
    for x in (x0, x1):
        k.cyl(p(x, y, 0), p(x, y, h + .15), .085, "madera", "algarrobo", "madera", sides=6, caps=(False, True))
    for i in range(4):
        z = .35 + i * (h - .35) / 3
        k.cyl(p(x0, y + .1, z), p(x1, y + .1, z + (h3(x0, i, 1) - .5) * .06), .04, "madera", "madera_gris", "madera", sides=5, caps=(True, True))


# --------------------------------------------------------------------------------------
# Muros de piedra seca (pirca) y tapias
# --------------------------------------------------------------------------------------
STONES = ["piedra", "piedra_osc", "piedra_ocre", "piedra_rojiza", "piedra_ocre"]


def pirca_run(k, a, b, h=1.15, t=.6, cap=True, seed=0):
    """Pirca: piedras sin mortero en hiladas trabadas, el muro se angosta hacia arriba (talud); piedras sueltas encima."""
    a, b = Vector((a[0], a[1], 0)), Vector((b[0], b[1], 0))
    d = b - a
    L = d.length
    if L < .05:
        return
    dx = d.normalized()
    nx = Vector((-dx.y, dx.x, 0))
    yaw0 = math.atan2(dx.y, dx.x)
    rows = max(2, round(h / .4))
    rh = h / rows
    for r in range(rows):
        z0 = r * rh
        thick = t * (1 - .38 * r / rows)
        pos = -h3(r, seed, L) * .35
        while pos < L:
            ln = .45 + .4 * h3(round(pos, 2), r, seed)
            s0, s1 = max(pos, 0.0), min(pos + ln, L)
            pos += ln
            if s1 - s0 < .14:
                continue
            p = a + dx * ((s0 + s1) / 2)
            q = h3(p.x, p.y, r + seed)
            hh = rh * (.95 + .3 * q)
            off = (h3(p.x, p.y, 7) - .5) * .06
            col = STONES[int(h3(p.x, p.y, r * 3 + 1) * 4.999)]
            k.rbox((p.x + nx.x * off, p.y + nx.y * off, z0 + hh / 2 - .02), (s1 - s0 - .025, thick * (.92 + .12 * q), hh),
                   yaw0 + (q - .5) * .14, "piedra", col, "piedra_s", 3.0, skip=("-z",), pitch=(h3(p.x, p.y, 9) - .5) * .12)
    if cap:
        m = max(2, int(L / .8))
        for i in range(m):
            p = a + dx * (L * (i + .5) / m)
            sz = .2 + .14 * h3(p.x, p.y, seed + 1)
            k.rbox((p.x + nx.x * (h3(p.x, p.y, 9) - .5) * .12, p.y + nx.y * (h3(p.x, p.y, 9) - .5) * .12, h + sz * .25),
                   (sz * 1.5, sz * 1.1, sz * .6), yaw0 + (h3(p.x, p.y, 3) - .5) * .9,
                   "piedra", STONES[int(h3(p.x, p.y, 4) * 4.999)], "piedra_s", 3.0, pitch=(h3(p.x, p.y, 5) - .5) * .4)


def escalera(k, x, y, z_top, dy=.7, w=.42):
    """Escalera de palo apoyada contra el muro (subir al techo de torta)."""
    for sx in (-1, 1):
        k.cyl((x + sx * w / 2, y + dy, 0), (x + sx * w / 2 * .9, y, z_top), .035, "madera", "madera_gris", "madera", sides=5, caps=(False, True))
    n = int(z_top / .38)
    for i in range(1, n):
        t = i / n
        k.cyl((x - w / 2, y + dy * (1 - t), z_top * t), (x + w / 2, y + dy * (1 - t), z_top * t), .022, "madera", "madera", "madera", sides=4, caps=(False, False))


def lena(k, x, y, n=9, along="x"):
    """Pila de leña (churqui, algarrobo): troncos cortos apilados."""
    for i in range(n):
        row = 0 if i < 4 else (1 if i < 7 else 2)
        j = i - (0 if row == 0 else (4 if row == 1 else 7))
        off = (j - (1.5 if row == 0 else (1.0 if row == 1 else .5))) * .2
        z = .09 + row * .16
        L = .9 + .3 * h3(x, i, 1)
        if along == "x":
            k.cyl((x - L / 2, y + off, z), (x + L / 2, y + off + (h3(i, x, 2) - .5) * .1, z), .08, "madera", "algarrobo", "madera", sides=5, caps=(True, True))
        else:
            k.cyl((x + off, y - L / 2, z), (x + off, y + L / 2, z), .08, "madera", "algarrobo", "madera", sides=5, caps=(True, True))


def cantaro(k, x, y, s=1.0):
    """Cántaro de barro cocido (agua)."""
    rings = [(.1, 0), (.2, .12), (.23, .3), (.17, .5), (.08, .6), (.1, .66)]
    for (r0, h0), (r1, h1) in zip(rings, rings[1:]):
        k.cyl((x, y, h0 * s), (x, y, h1 * s), r0 * s, "muro", "ladrillo", "ladrillo", sides=7, r2=r1 * s, caps=(False, False))
    k.poly([(x + .1 * s * math.cos(a * 2 * math.pi / 7), y + .1 * s * math.sin(a * 2 * math.pi / 7), .66 * s) for a in range(7)],
           "sombra", "sombra", "sombra", out=(0, 0, 1))


def tapia_run(k, a, b, h=2.0, t=.45, col="adobe", kind="adobe", cap="torta", capkind="torta", tongadas=False):
    """Tapia de adobe (o encalada) con cumbrera de barro o de teja."""
    a, b = Vector((a[0], a[1], 0)), Vector((b[0], b[1], 0))
    d = b - a
    L = d.length
    dx = d.normalized()
    nx = Vector((-dx.y, dx.x, 0))
    p = [a - nx * t / 2, b - nx * t / 2, b + nx * t / 2, a + nx * t / 2]
    c8 = [Vector((q.x, q.y, .25)) for q in p] + [Vector((q.x, q.y, h)) for q in p]
    k.hexa(c8, "muro", col, kind, .9, skip=("-z",), cellv=.65)
    pf = [a - nx * (t / 2 + .04), b - nx * (t / 2 + .04), b + nx * (t / 2 + .04), a + nx * (t / 2 + .04)]
    k.hexa([Vector((q.x, q.y, 0)) for q in pf] + [Vector((q.x, q.y, .25)) for q in pf], "piedra", "piedra", "piedra", .7, skip=("-z",), cellv=1.0)
    # remate a dos aguas que vuela unos cm
    o = .08
    q = [a - dx * .02 - nx * (t / 2 + o), b + dx * .02 - nx * (t / 2 + o), b + dx * .02 + nx * (t / 2 + o), a - dx * .02 + nx * (t / 2 + o)]
    lo = [Vector((v.x, v.y, h - .04)) for v in q]
    ridge = [a - dx * .02, b + dx * .02]
    hi = [Vector((ridge[0].x, ridge[0].y, h + .2)), Vector((ridge[1].x, ridge[1].y, h + .2)),
          Vector((ridge[1].x, ridge[1].y, h + .2)), Vector((ridge[0].x, ridge[0].y, h + .2))]
    # dos faldones (como polígonos) y las cabezas triangulares
    mat = "teja" if cap.startswith("teja") else "techo"
    k.grid(lo[0], lo[1], hi[1], hi[0], mat, cap, capkind, .45, out=-nx + Vector((0, 0, 1)))
    k.grid(lo[2], lo[3], hi[3], hi[2], mat, cap, capkind, .45, out=nx + Vector((0, 0, 1)))
    k.poly([lo[0], lo[3], hi[0]], mat, cap, capkind, out=-dx)
    k.poly([lo[1], lo[2], hi[1]], mat, cap, capkind, out=dx)
    k.poly(lo, mat, cap, capkind, out=(0, 0, -1))


# --------------------------------------------------------------------------------------
# Tipos de edificio
# --------------------------------------------------------------------------------------
def casa_torta(k, W, D, Hf, Hb, doors_, wins, t=.55, wall_col="adobe", wall_kind="adobe", gal=None, ov=.4, pretil=.28,
               gargolas=2, x_off=0.0, y_off=0.0, front_cal=False):
    """Casa de la quebrada: cimiento de piedra, muros de adobe, techo de torta de barro sobre cañizo y rollizos, que cae
    hacia el frente (+Y); pretil en el fondo y los costados; gárgolas de madera. `gal` = (fondo, alto, [x de horcones])."""
    zb = .3
    kk = k
    plinth(kk, -W / 2 + x_off, W / 2 + x_off, -D / 2 + y_off, D / 2 + y_off, zb)
    zt_b, zt_f = Hb, Hf
    zt = lambda y: zt_b + (zt_f - zt_b) * (y - (-D / 2)) / D
    th = .2
    # muros: frente hasta la losa; fondo y costados hasta el pretil
    fcol = "cal" if front_cal else wall_col
    fkind = "cal" if front_cal else wall_kind
    ops_f = [(x - w / 2 + x_off, x + w / 2 + x_off, zb, zb + h) for x, w, h in doors_] + \
            [(x - w / 2 + x_off, x + w / 2 + x_off, zb + za, zb + zz) for x, w, za, zz in wins]
    X = lambda x: x + x_off
    Y = lambda y: y + y_off
    kk.wall("x", X(-W / 2), X(W / 2), Y(D / 2 - t), Y(D / 2), zb, Hf - th, ops_f, fcol, fkind, .5, inner="-y", top=False)
    kk.wall("x", X(-W / 2), X(W / 2), Y(-D / 2), Y(-D / 2 + t), zb, Hb + pretil, [], wall_col, wall_kind, .5, inner="+y")
    for sx in (-1, 1):
        xa, xb = (X(-W / 2), X(-W / 2 + t)) if sx < 0 else (X(W / 2 - t), X(W / 2))
        ya, yb = Y(-D / 2 + t), Y(D / 2)
        za_, zb_ = zt(-D / 2 + t) + pretil, zt(D / 2) + pretil
        kk.hexa([(xa, ya, zb), (xb, ya, zb), (xb, yb, zb), (xa, yb, zb), (xa, ya, za_), (xb, ya, za_), (xb, yb, zb_), (xa, yb, zb_)],
                "muro", wall_col, wall_kind, .5, skip=("-z", "+x" if sx < 0 else "-x", "-y"))
    # losa entre pretiles, volando al frente
    yf = D / 2 + (0.0 if gal else ov)
    roof_flat(kk, X(-W / 2 + t), X(W / 2 - t), Y(-D / 2 + t), Y(yf), zt(-D / 2 + t), zt(yf), th)
    # la losa también vuela por delante de los costados (sin pretil adelante)
    if not gal:
        rollizos(kk, X(-W / 2 + t + .25), X(W / 2 - t - .25), Y(D / 2 - .3), Y(D / 2 + ov + .08), zt(D / 2 - .3) - th - .06, zt(D / 2 + ov) - th - .07)
    for i in range(gargolas):
        gx = X(-W / 2 + t + .5 + (W - 2 * t - 1.0) * (i + .5) / gargolas) if gargolas else 0
        kk.box(gx - .09, gx + .09, Y(yf - .2), Y(yf + .55), zt(yf) - .08, zt(yf) + .02, "madera", "madera_gris", "madera", .8, skip=())
    for x, w, h in doors_:
        door(kk, "x", X(x), Y(D / 2), 1, w, h, zb, t)
    for x, w, za, zz in wins:
        window(kk, X(x), Y(D / 2), 1, w, zb + za, zb + zz, t)
    if gal:
        gd, gh, xs = gal
        y1 = D / 2 + gd
        for x in xs:
            horcon(kk, X(x), Y(y1), gh + .05)
        kk.cyl((X(-W / 2 - .1), Y(y1), gh + .05), (X(W / 2 + .1), Y(y1), gh + .05), .1, "madera", "algarrobo", "madera", sides=6, caps=(True, True))
        z_in = Hf - th - .05
        g0 = lambda y: z_in + (gh + .2 - z_in) * (y - D / 2) / gd
        roof_flat(kk, X(-W / 2), X(W / 2), Y(D / 2 - .05), Y(y1 + .35), g0(D / 2 - .05) + .14, g0(y1 + .35) + .14, .14, jit=.02)
        rollizos(kk, X(-W / 2 + .2), X(W / 2 - .2), Y(D / 2 - .05), Y(y1 + .2), z_in - .02, gh + .12, step=.7)
    return zt


def casa_gable(k, W, D, H, rise, roof, doors_, wins, t=.5, wall_col="adobe", wall_kind="adobe", ov=.45, gal=None,
               reja="madera", lintel=True, zb=.3, back_doors=(), plinth_col="piedra"):
    """Casa de muros de adobe (o ladrillo revocado) con techo a dos aguas de paja o de teja, cumbrera a lo largo de X,
    hastiales en los testeros. `gal` = (fondo, alto, [x de postes], 'horcon'|'poste')."""
    plinth(k, -W / 2, W / 2, -D / 2, D / 2, zb, col=plinth_col)
    ops_f = [(x - w / 2, x + w / 2, zb, zb + h) for x, w, h in doors_] + [(x - w / 2, x + w / 2, zb + za, zb + zz) for x, w, za, zz in wins]
    ops_b = [(x - w / 2, x + w / 2, zb, zb + h) for x, w, h in back_doors]
    k.wall("x", -W / 2, W / 2, D / 2 - t, D / 2, zb, H, ops_f, wall_col, wall_kind, .5, inner="-y", top=False)
    k.wall("x", -W / 2, W / 2, -D / 2, -D / 2 + t, zb, H, ops_b, wall_col, wall_kind, .5, inner="+y", top=False)
    k.wall("y", -D / 2 + t, D / 2 - t, -W / 2, -W / 2 + t, zb, H, [], wall_col, wall_kind, .5, inner="+x", ends=(False, False), top=False)
    k.wall("y", -D / 2 + t, D / 2 - t, W / 2 - t, W / 2, zb, H, [], wall_col, wall_kind, .5, inner="-x", ends=(False, False), top=False)
    half_w = D / 2
    for sx in (-1, 1):
        gable_wall(k, "x", sx * W / 2, half_w, H, H + rise, t, wall_col, wall_kind, sx)
    for x, w, h in doors_:
        door(k, "x", x, D / 2, 1, w, h, zb, t, lintel=lintel)
    for x, w, h in back_doors:
        door(k, "x", x, -D / 2, -1, w, h, zb, t, lintel=lintel)
    for x, w, za, zz in wins:
        window(k, x, D / 2, 1, w, zb + za, zb + zz, t, reja=reja, lintel=lintel)
    slope = rise / half_w
    half = half_w + ov
    z_eave = H - ov * slope + .05
    z_ridge = H + rise + .12
    ox = .3 if roof == "paja" else .2
    if roof == "paja":
        thatch_roof(k, -W / 2 - ox, W / 2 + ox, half, z_eave, z_ridge)
    elif roof == "teja":
        tile_roof(k, -W / 2 - ox, W / 2 + ox, half, z_eave, z_ridge)
    else:
        gable_slabs(k, -W / 2 - ox, W / 2 + ox, half, z_eave, z_ridge, .2, "torta", "torta", jit=.02, under="cana", ukind="cana")
    if gal:
        gd, gh, xs, kind = gal
        y1 = D / 2 + gd
        for x in xs:
            if kind == "horcon":
                horcon(k, x, y1, gh)
            else:
                poste(k, x, y1, gh)
        k.cyl((-W / 2 - ox, y1, gh + .02), (W / 2 + ox, y1, gh + .02), .1, "madera", "algarrobo" if kind == "horcon" else "madera",
              "madera", sides=6 if kind == "horcon" else 4, caps=(True, True), rot=math.pi / 4)
        # faldón del corredor: sigue el alero con menos pendiente
        za = H - .05
        zbg = gh + .18
        if roof == "teja":
            # medio faldón de teja apoyado en el muro y la viga
            tile_roof_lean(k, -W / 2 - ox, W / 2 + ox, D / 2 - .05, y1 + .4, za + .1, zbg - (za - zbg) * .4 / gd)
        else:
            col = "paja" if roof == "paja" else "torta"
            kind_ = "paja" if roof == "paja" else "torta"
            zf = zbg - (za - zbg) * .4 / gd
            k.hexa([(-W / 2 - ox, D / 2 - .05, za - .2), (W / 2 + ox, D / 2 - .05, za - .2), (W / 2 + ox, y1 + .4, zf - .2), (-W / 2 - ox, y1 + .4, zf - .2),
                    (-W / 2 - ox, D / 2 - .05, za + .05), (W / 2 + ox, D / 2 - .05, za + .05), (W / 2 + ox, y1 + .4, zf + .05), (-W / 2 - ox, y1 + .4, zf + .05)],
                   "techo", col, kind_, .4 if roof == "paja" else .9, skip=(), jit=.03, fcols={"-z": "cana"}, fkinds={"-z": "cana"},
                   cellv=1.2, fcells={"-z": 1.8, "-x": 1.0, "+x": 1.0, "-y": 1.0, "+y": 1.0})
    return z_eave, z_ridge


def tile_roof_lean(k, x0, x1, y0, y1, z0, z1, pitch=.3, amp=.075, courses=2):
    """Faldón de teja a un agua (corredor): de (y0, z0) junto al muro a (y1, z1) en el alero."""
    th = .08
    k.hexa([(x0, y0, z0 - th), (x1, y0, z0 - th), (x1, y1, z1 - th), (x0, y1, z1 - th),
            (x0, y0, z0), (x1, y0, z0), (x1, y1, z1), (x0, y1, z1)], "teja", "teja_oscura", "teja", 4.0, skip=(),
           fcols={"-z": "cana"}, fkinds={"-z": "cana"}, fmats={"-z": "techo"})
    n = max(2, int(round((x1 - x0) / pitch)))
    for c in range(courses):
        v0, v1 = c / courses, (c + 1) / courses
        for i in range(n):
            ha = amp if i % 2 else 0.0
            hb_ = 0.0 if i % 2 else amp

            def pt(u, v, hh):
                return (x0 + (x1 - x0) * u, y1 + (y0 - y1) * v, z1 + (z0 - z1) * v + hh + .005)
            lift = .03
            k.poly([pt(i / n, v0, ha + lift), pt((i + 1) / n, v0, hb_ + lift), pt((i + 1) / n, v1, hb_), pt(i / n, v1, ha)],
                   "teja", "teja", "teja", out=(0, 0, 1))
            if c == 0:
                k.poly([pt(i / n, 0, 0), pt((i + 1) / n, 0, 0), pt((i + 1) / n, 0, hb_ + lift), pt(i / n, 0, ha + lift)],
                       "teja", "teja_oscura", "teja", out=(0, 1, 0))


def capilla(k, W, D, H, rise, t=1.0, espadana=True, torre=False, atrio=False, roof="torta", esp_h=1.9):
    """Capilla andina: nave única de adobe encalado, techo a dos aguas, contrafuertes, portada con arco de medio punto
    al frente (+Y), espadaña de dos campanas sobre el hastial (o torre a un costado), atrio con pirca y cruz."""
    zb = .35
    plinth(k, -W / 2, W / 2, -D / 2, D / 2, zb, col="piedra")
    fy = D / 2
    dw, dh = 1.7, 2.7
    k.wall("x", -W / 2, W / 2, fy - t, fy, zb, H, [(-dw / 2, dw / 2, zb, zb + dh + .55)], "cal", "cal", .6, inner="-y", top=False)
    k.wall("x", -W / 2, W / 2, -D / 2, -D / 2 + t, zb, H, [], "cal", "cal", .7, inner="+y", top=False)
    wins_side = [(-D / 4, -D / 4 + .7, 2.6, 3.4), (D / 8, D / 8 + .7, 2.6, 3.4)]
    k.wall("y", -D / 2 + t, D / 2 - t, -W / 2, -W / 2 + t, zb, H, wins_side, "cal", "cal", .7, inner="+x", ends=(False, False), top=False)
    k.wall("y", -D / 2 + t, D / 2 - t, W / 2 - t, W / 2, zb, H, wins_side, "cal", "cal", .7, inner="-x", ends=(False, False), top=False)
    for sx in (-1, 1):
        for y0, y1, za, zz in wins_side:
            face = sx * W / 2
            inner = face - sx * t
            k.poly([(inner + sx * .02, y0, za), (inner + sx * .02, y1, za), (inner + sx * .02, y1, zz), (inner + sx * .02, y0, zz)],
                   "sombra", "sombra", "sombra", out=(sx, 0, 0))
    # hastiales (cumbrera a lo largo de Y)
    for sy in (-1, 1):
        gable_wall(k, "y", sy * D / 2, W / 2, H, H + rise, t, "cal", "cal", sy)
    # techo: torta a dos aguas sobre cañizo, alero corto
    ov = .35
    half = W / 2 + ov
    slope = rise / (W / 2)
    z_eave = H - ov * slope + .05
    z_ridge = H + rise + .15
    if roof == "torta":
        gable_slabs(k, -D / 2 - .25, D / 2 + .05, half, z_eave, z_ridge, .22, "torta", "torta", cell=.9, jit=.03,
                    under="cana", ukind="cana", axis="y")
    else:
        tile_roof(k, -D / 2 - .25, D / 2 + .05, half, z_eave, z_ridge, axis="y")
    # contrafuertes ataludados: dos por costado y dos en las esquinas del frente
    for sx in (-1, 1):
        for yy in (-D / 2 + .9, -D / 6, D / 6, D / 2 - .6):
            x_in = sx * W / 2
            x_out = sx * (W / 2 + .9)
            x_top = sx * (W / 2 + .35)
            ya, yb = yy - .4, yy + .4
            xa_b, xb_b = sorted((x_in, x_out))
            xa_t, xb_t = sorted((x_in, x_top))
            k.hexa([(xa_b, ya, 0), (xb_b, ya, 0), (xb_b, yb, 0), (xa_b, yb, 0),
                    (xa_t, ya, H - .7), (xb_t, ya, H - .7), (xb_t, yb, H - .7), (xa_t, yb, H - .7)],
                   "muro", "cal_sucia", "cal", 1.3, skip=("-z", "-x" if sx > 0 else "+x"))
    # portada: pilastras, arco de medio punto (polígono), cornisa, puerta de dos hojas, ventana del coro
    pw = .38
    r_arc = dw / 2
    zs = zb + dh  # arranque del arco
    for sx in (-1, 1):
        k.box(sx * (dw / 2) - (pw if sx < 0 else 0), sx * (dw / 2) + (0 if sx < 0 else pw), fy, fy + .22, zb, zs + r_arc + .35,
              "muro", "cal", "cal", 1.2, skip=("-z",))
    nseg = 7
    for i in range(nseg):
        a0 = math.pi * i / nseg
        a1 = math.pi * (i + 1) / nseg
        ri, ro = r_arc, r_arc + pw
        p = [(math.cos(a0) * ri, math.sin(a0) * ri), (math.cos(a1) * ri, math.sin(a1) * ri), (math.cos(a1) * ro, math.sin(a1) * ro), (math.cos(a0) * ro, math.sin(a0) * ro)]
        c8 = [(x, fy, zs + z) for x, z in p] + [(x, fy + .22, zs + z) for x, z in p]
        c8 = [c8[0], c8[1], c8[5], c8[4], c8[3], c8[2], c8[6], c8[7]]
        k.hexa([(x, y, z) for x, y, z in c8], "muro", "cal", "cal", 2.0, skip=())
        # tímpano oscuro (vano del arco)
        k.poly([(0, fy - .25, zs), (math.cos(a0) * ri, fy - .25, zs + math.sin(a0) * ri), (math.cos(a1) * ri, fy - .25, zs + math.sin(a1) * ri)],
               "sombra", "sombra", "sombra", out=(0, 1, 0))
    k.box(-dw / 2 - pw - .1, dw / 2 + pw + .1, fy - .02, fy + .3, zs + r_arc + .35, zs + r_arc + .5, "muro", "cal", "cal", .5, skip=())
    # el vano de la puerta (rectángulo hasta el arranque) + hojas
    k.poly([(-dw / 2, fy - t + .02, zb), (dw / 2, fy - t + .02, zb), (dw / 2, fy - t + .02, zs + .55), (-dw / 2, fy - t + .02, zs + .55)],
           "sombra", "sombra", "sombra", out=(0, 1, 0))
    for sx in (-1, 1):
        x0_, x1_ = sorted((0, sx * (dw / 2 - .02)))
        k.box(x0_ + .01, x1_ - .01, fy - .32, fy - .26, zb, zs, "madera", "madera", "madera", .5)
    k.doors.append((0, fy + .05, zb + 1.3))
    k.box(-.3, .3, fy - .02, fy + .02, zs + r_arc + .7, zs + r_arc + 1.25, "sombra", "sombra", "sombra", .6, skip=("-z",))
    top_front = H + rise
    if espadana:
        # espadaña: muro sobre el hastial del frente, con dos vanos de campana y remate escalonado + cruz
        ew, eh = 3.0, esp_h
        z0 = top_front - .55
        y0, y1 = fy - .5, fy
        k.wall("x", -ew / 2, ew / 2, y0, y1, z0, z0 + eh, [(-1.05, -.25, z0 + .55, z0 + 1.45), (.25, 1.05, z0 + .55, z0 + 1.45)],
               "cal", "cal", .45)
        k.box(-ew / 2 - .1, ew / 2 + .1, y0 - .06, y1 + .06, z0 + eh, z0 + eh + .14, "muro", "cal_sucia", "cal", .6, skip=())
        k.box(-.7, .7, y0, y1, z0 + eh + .14, z0 + eh + .6, "muro", "cal", "cal", .5, skip=("-z",))
        k.box(-.75, .75, y0 - .05, y1 + .05, z0 + eh + .6, z0 + eh + .7, "muro", "cal_sucia", "cal", .6, skip=())
        for xb in (-.65, .65):
            ztop = z0 + 1.45
            k.cyl((xb - .35, (y0 + y1) / 2, ztop - .08), (xb + .35, (y0 + y1) / 2, ztop - .08), .05, "madera", "madera", "madera", sides=5, caps=(True, True))
            k.cyl((xb, (y0 + y1) / 2, ztop - .12), (xb, (y0 + y1) / 2, ztop - .62), .12, "hierro", "bronce", "hierro", sides=8, r2=.24, caps=(True, True))
        zc = z0 + eh + .7
        k.box(-.04, .04, (y0 + y1) / 2 - .04, (y0 + y1) / 2 + .04, zc, zc + .5, "madera", "madera", "madera", 1.0)
        k.box(-.17, .17, (y0 + y1) / 2 - .04, (y0 + y1) / 2 + .04, zc + .3, zc + .37, "madera", "madera", "madera", 1.0)
    if torre:
        # torre de planta cuadrada pegada a la esquina del frente, campanario abierto y cupulín
        s = 2.8
        tx0, tx1 = W / 2 - .2, W / 2 + s - .2
        ty0, ty1 = fy - s, fy
        Ht = H + rise + 1.4
        plinth(k, tx0, tx1, ty0, ty1, zb)
        k.box(tx0, tx1, ty0, ty1, zb, Ht, "muro", "cal", "cal", 1.0, skip=("-z", "-x"), cellv=1.0)
        k.box(tx0 - .12, tx1 + .12, ty0 - .12, ty1 + .12, Ht, Ht + .18, "muro", "cal_sucia", "cal", .7, skip=())
        zb2 = Ht + .18
        hb_ = 2.2
        for cx, cy in ((tx0, ty0), (tx1, ty0), (tx1, ty1), (tx0, ty1)):
            xa, xb = sorted((cx, cx + (.55 if cx == tx0 else -.55)))
            ya, yb = sorted((cy, cy + (.55 if cy == ty0 else -.55)))
            k.box(xa, xb, ya, yb, zb2, zb2 + hb_, "muro", "cal", "cal", 1.2, skip=("-z",))
        k.box(tx0, tx1, ty0, ty1, zb2 + hb_ - .45, zb2 + hb_, "muro", "cal", "cal", 1.5, skip=())
        cx, cy = (tx0 + tx1) / 2, (ty0 + ty1) / 2
        k.cyl((cx, cy, zb2 + .1), (cx, cy, zb2 + 1.5), .3, "hierro", "bronce", "hierro", sides=8, r2=.5, caps=(True, True))
        # cupulín: octógono que se cierra
        zc = zb2 + hb_
        rings = [(1.25, 0), (1.15, .35), (.9, .7), (.5, .95), (.12, 1.05)]
        for (r0, h0), (r1, h1) in zip(rings, rings[1:]):
            k.cyl((cx, cy, zc + h0), (cx, cy, zc + h1), r0, "muro", "cal", "cal", sides=8, r2=r1, caps=(False, False), rot=math.pi / 8)
        k.box(cx - .04, cx + .04, cy - .04, cy + .04, zc + 1.05, zc + 1.7, "hierro", "hierro", "hierro", 1.0)
        k.box(cx - .2, cx + .2, cy - .04, cy + .04, zc + 1.45, zc + 1.52, "hierro", "hierro", "hierro", 1.0)
    if atrio:
        ay = fy + 6.5
        ax = W / 2 + 2.0
        gate = 1.4
        pirca_run(k, (-ax, fy - 1.0), (-ax, ay), h=1.0, t=.55, seed=1)
        pirca_run(k, (ax, fy - 1.0), (ax, ay), h=1.0, t=.55, seed=2)
        pirca_run(k, (-ax, ay), (-gate, ay), h=1.0, t=.55, seed=3)
        pirca_run(k, (gate, ay), (ax, ay), h=1.0, t=.55, seed=4)
        # portada del atrio: dos pilares de adobe encalado con remate
        for sx in (-1, 1):
            k.box(sx * gate - .3, sx * gate + .3, ay - .3, ay + .3, 0, 2.1, "muro", "cal", "cal", .5, skip=("-z",))
            k.box(sx * gate - .38, sx * gate + .38, ay - .38, ay + .38, 2.1, 2.25, "muro", "cal_sucia", "cal", .6, skip=())
        # cruz de madera en el atrio sobre una grada de piedra
        cy = fy + 3.6
        k.box(-.6, .6, cy - .6, cy + .6, 0, .35, "piedra", "piedra", "piedra", .6)
        k.box(-.08, .08, cy - .08, cy + .08, .35, 3.1, "madera", "madera", "madera", 1.0)
        k.box(-.6, .6, cy - .07, cy + .07, 2.3, 2.45, "madera", "madera", "madera", 1.0)


# --------------------------------------------------------------------------------------
# Catálogo: cada entrada arma un modelo
# --------------------------------------------------------------------------------------
def m_casa_rancho_a(k):
    """Rancho de adobe con techo de paja a dos aguas: una pieza, una puerta y un ventanuco."""
    casa_gable(k, 5.0, 3.6, 2.25, 1.35, "paja", [(-.6, .85, 1.75)], [(1.25, .45, .95, 1.4)], t=.45, wall_col="adobe", wall_kind="adobe")
    cantaro(k, .35, 2.3)
    lena(k, -3.1, -.4, n=7, along="y")


def m_casa_rancho_b(k):
    """Rancho de adobe con paja y ramada al frente sobre horcones (sombra de trabajo)."""
    casa_gable(k, 6.0, 3.8, 2.3, 1.4, "paja", [(-1.2, .85, 1.75)], [(1.2, .5, .95, 1.45)], t=.45, wall_col="revoque", wall_kind="adobe",
               gal=(2.4, 2.05, [-2.9, 0.0, 2.9], "horcon"))


def m_casa_rancho_c(k):
    """Rancho de la quebrada con techo de torta a un agua (barro sobre cañizo), sin pretil, rollizos al frente."""
    casa_torta(k, 4.6, 3.6, 2.15, 2.55, [(.4, .82, 1.7)], [], t=.45, pretil=0.02, gargolas=1, ov=.45)
    # un poyo de adobe junto a la puerta
    k.box(-1.7, -.6, 1.8, 2.25, 0, .45, "muro", "adobe", "adobe", .5)


def m_casa_torta_a(k):
    """Casa de adobe de la quebrada (mejora de hx_casa_adobe): 6 x 4 m, torta al frente, pretil, rollizos, gárgolas."""
    casa_torta(k, 6.0, 4.0, 2.45, 2.8, [(-1.0, .9, 1.8)], [(1.35, .6, 1.0, 1.55)], t=.55, front_cal=False)
    cantaro(k, -.1, 2.35)
    cantaro(k, .25, 2.5, .85)


def m_casa_torta_b(k):
    """Casa encalada de la quebrada en dos cuerpos: pieza principal y un cuarto más bajo al costado."""
    casa_torta(k, 6.4, 4.2, 2.55, 2.95, [(-1.4, .9, 1.85)], [(1.0, .6, 1.0, 1.55)], t=.55, front_cal=True, x_off=-1.6, wall_col="cal",
               wall_kind="cal")
    casa_torta(k, 3.4, 3.6, 2.15, 2.45, [(.2, .8, 1.7)], [], t=.5, x_off=3.3, y_off=-.3, pretil=.2, gargolas=1)
    lena(k, 5.6, -.6, along="y")
    escalera(k, -2.6, -2.15, 3.2, dy=-.8)   # contra el muro del fondo: se sube al techo de torta


def m_casa_galeria_a(k):
    """Casa de adobe con galería de horcones y techo de torta (quebrada)."""
    casa_torta(k, 8.0, 4.2, 2.6, 2.95, [(-2.2, .9, 1.85), (1.4, .9, 1.85)], [(-.4, .6, 1.0, 1.55)], t=.55,
               gal=(2.3, 2.1, [-3.9, -1.3, 1.3, 3.9]), front_cal=True)
    for x in (-.9, -.55):
        cantaro(k, x, 2.6)
    k.cyl((2.4, 2.75, .42), (3.6, 2.75, .42), .1, "madera", "algarrobo", "madera", sides=5, caps=(True, True))


def m_casa_galeria_b(k):
    """Casa de adobe encalada con galería de horcones y techo de teja (pueblos del Valle de Lerma y Jujuy)."""
    casa_gable(k, 9.0, 5.0, 2.8, 1.5, "teja", [(-2.5, 1.0, 2.0), (1.8, 1.0, 2.0)], [(-.4, .7, 1.0, 1.7), (3.4, .7, 1.0, 1.7)],
               t=.6, wall_col="cal", wall_kind="cal", gal=(2.4, 2.25, [-4.5, -1.5, 1.5, 4.5], "horcon"), reja="madera")


def m_casa_patio_a(k):
    """Casa de patio de la quebrada: cuartos en L con torta, patio cerrado por tapia con portón de madera."""
    # ala del fondo
    casa_torta(k, 11.0, 4.2, 2.5, 2.85, [(-3.0, .9, 1.8), (1.0, .9, 1.8)], [(3.6, .6, 1.0, 1.5)], t=.55, y_off=-4.2, gargolas=3)
    # ala del costado (mira al patio = +X): se arma girada como una casa más chica
    side = Kit("side")
    casa_torta(side, 6.0, 3.8, 2.4, 2.7, [(.5, .85, 1.75)], [(-1.8, .55, 1.0, 1.45)], t=.5, gargolas=1)
    merge_rot(k, side, -math.pi / 2, (-3.6, 1.7))
    # tapia del frente con portón y la del costado este
    tapia_run(k, (-1.7, 5.7), (1.4, 5.7), h=2.1, t=.5)
    tapia_run(k, (3.4, 5.7), (5.5, 5.7), h=2.1, t=.5)
    tapia_run(k, (5.5, 5.7), (5.5, -2.1), h=2.1, t=.5)
    for x in (1.4, 3.4):
        k.box(x - .3, x + .3, 5.4, 6.0, 0, 2.6, "muro", "adobe", "adobe", .5, skip=("-z",))
        k.box(x - .36, x + .36, 5.34, 6.06, 2.6, 2.72, "techo", "torta", "torta", .6, skip=())
    k.box(1.1, 3.7, 5.42, 5.98, 2.4, 2.6, "madera", "algarrobo", "madera", .8, skip=())
    k.rbox((1.9, 5.55, 1.1), (1.0, .07, 2.2), .25, "madera", "madera", "madera", .5, skip=())
    k.rbox((2.9, 5.55, 1.1), (1.0, .07, 2.2), -.25, "madera", "madera", "madera", .5, skip=())
    k.poly([(1.7, 5.98, 0), (3.1, 5.98, 0), (3.1, 5.98, 2.3), (1.7, 5.98, 2.3)], "sombra", "suelo", "suelo", out=(0, -1, 0))
    k.doors.append((2.4, 6.05, 1.2))
    # horno de barro en el patio
    horno(k, 3.3, 0.5)


def horno(k, x, y, r=.75):
    rings = [(r, .25), (r * .95, .55), (r * .75, .85), (r * .4, 1.05), (.06, 1.12)]
    k.cyl((x, y, 0), (x, y, .25), r * 1.08, "piedra", "piedra", "piedra", sides=8, caps=(False, False))
    for (r0, h0), (r1, h1) in zip(rings, rings[1:]):
        k.cyl((x, y, h0), (x, y, h1), r0, "muro", "revoque", "adobe", sides=8, r2=r1, caps=(False, False))
    k.poly([(x - .2, y + r * .98, .25), (x + .2, y + r * .98, .25), (x + .15, y + r * .9, .6), (x - .15, y + r * .9, .6)],
           "sombra", "sombra", "sombra", out=(0, 1, 0))


def merge_rot(k, sub, yaw, off):
    m = Matrix.Translation(Vector((off[0], off[1], 0))) @ Matrix.Rotation(yaw, 4, "Z")
    base = len(k.V)
    k.V += [m @ v for v in sub.V]
    k.F += [tuple(i + base for i in f) for f in sub.F]
    k.fm += sub.fm
    k.fc += sub.fc
    k.fk += sub.fk
    k.doors += [tuple(m @ Vector(d)) for d in sub.doors]


def m_casa_patio_b(k):
    """Casa de patio de ciudad (Salta, Jujuy): frente encalado con zaguán, techo de teja, ala lateral con corredor."""
    sub = Kit("frente")
    casa_gable(sub, 12.0, 5.0, 3.1, 1.7, "teja", [(0.0, 1.5, 2.4)], [(-3.6, .9, .9, 2.0), (3.6, .9, .9, 2.0)], t=.7,
               wall_col="cal", wall_kind="cal", reja="hierro", lintel=False, back_doors=[(0.0, 1.4, 2.3)])
    merge_rot(k, sub, 0.0, (0, 3.5))
    side = Kit("ala")
    casa_gable(side, 8.0, 4.4, 2.9, 1.5, "teja", [(-2.0, 1.0, 2.1), (2.0, 1.0, 2.1)], [], t=.6, wall_col="cal", wall_kind="cal",
               gal=(2.0, 2.4, [-4.0, -1.3, 1.3, 4.0], "poste"), lintel=False)
    merge_rot(k, side, -math.pi / 2, (-3.8, -4.2))
    tapia_run(k, (-1.4, -8.4), (6.0, -8.4), h=2.4, t=.55, col="cal", kind="cal", cap="teja", capkind="teja")
    tapia_run(k, (6.0, -8.4), (6.0, 1.0), h=2.4, t=.55, col="cal", kind="cal", cap="teja", capkind="teja")
    # aljibe: brocal de ladrillo revocado con arco de hierro (diseño)
    k.cyl((2.4, -3.2, 0), (2.4, -3.2, .85), .6, "muro", "cal_sucia", "cal", sides=8, caps=(False, True))
    k.poly([(2.4 + .45 * math.cos(a * math.pi / 4), -3.2 + .45 * math.sin(a * math.pi / 4), .86) for a in range(8)], "sombra", "sombra", "sombra", out=(0, 0, 1))
    for sx in (-1, 1):
        k.cyl((2.4 + sx * .55, -3.2, .85), (2.4 + sx * .45, -3.2, 2.0), .025, "hierro", "hierro", "hierro", sides=4)
    k.cyl((1.95, -3.2, 2.0), (2.85, -3.2, 2.0), .025, "hierro", "hierro", "hierro", sides=4)


def m_capilla_a(k):
    """Capilla de la quebrada con espadaña, sin atrio (reemplazo directo de hx_capilla, ≤ 8 m de alto)."""
    capilla(k, 6.6, 13.0, 4.0, 1.45, t=1.0, espadana=True, esp_h=1.8)


def m_capilla_b(k):
    """Capilla con espadaña y atrio cerrado por pirca, portada de atrio y cruz."""
    capilla(k, 6.0, 11.5, 4.0, 1.45, t=.95, espadana=True, atrio=True)


def m_capilla_c(k):
    """Iglesia de pueblo con torre a un costado del frente, cupulín y techo de teja (Salta, Jujuy; sirve de silueta en Buenos Aires)."""
    capilla(k, 7.2, 16.0, 4.8, 1.7, t=1.1, espadana=False, torre=True, roof="teja")


def m_corral_pirca_a(k):
    """Corral redondo de pirca (~10 m) con abertura y tranquera de palos."""
    R = 5.0
    n = 16
    gap = (math.radians(80), math.radians(100))
    pts = []
    for i in range(n + 1):
        a = 2 * math.pi * i / n
        pts.append(a)
    for i in range(n):
        a0, a1 = pts[i], pts[i + 1]
        if a1 <= gap[0] or a0 >= gap[1]:
            pass
        else:
            a0, a1 = (a0, gap[0]) if a0 < gap[0] else (gap[1], a1)
            if a1 - a0 < .02:
                continue
        rr0 = R * (1 + (h3(a0, 0, 1) - .5) * .06)
        rr1 = R * (1 + (h3(a1, 0, 1) - .5) * .06)
        pirca_run(k, (rr0 * math.cos(a0), rr0 * math.sin(a0)), (rr1 * math.cos(a1), rr1 * math.sin(a1)), h=1.2, t=.65, seed=i)
    tranquera(k, R * math.cos(gap[0]), R * math.cos(gap[1]), R, h=1.3)


def m_corral_pirca_b(k):
    """Corral rectangular de pirca (12 x 9 m) con tranquera y un brete de palos adentro."""
    W, D = 12.0, 9.0
    c = [(-W / 2, -D / 2), (W / 2, -D / 2), (W / 2, D / 2), (-W / 2, D / 2)]
    pirca_run(k, c[0], c[1], h=1.25, seed=1)
    pirca_run(k, c[1], c[2], h=1.25, seed=2)
    pirca_run(k, c[2], (1.0, D / 2), h=1.25, seed=3)
    pirca_run(k, (-1.4, D / 2), c[3], h=1.25, seed=4)
    pirca_run(k, c[3], c[0], h=1.25, seed=5)
    tranquera(k, -1.3, .9, D / 2, h=1.35)
    for i in range(5):
        x = 2.0 + i * .7
        k.cyl((x, -D / 2 + .5, 0), (x, -D / 2 + .5, 1.5), .07, "madera", "algarrobo", "madera", sides=5, caps=(False, True))
    k.cyl((1.8, -D / 2 + .5, 1.3), (5.0, -D / 2 + .5, 1.3), .045, "madera", "madera_gris", "madera", sides=5, caps=(True, True))


def m_corral_palos_c(k):
    """Corral de palo a pique (Buenos Aires y llanura): palos hincados juntos, tranquera."""
    W, D = 11.0, 8.0
    step = .32

    def run(a, b, skip=None):
        a, b = Vector(a), Vector(b)
        L = (b - a).length
        n = int(L / step)
        for i in range(n + 1):
            p = a.lerp(b, i / max(n, 1))
            if skip and skip[0] <= p.x <= skip[1] and abs(p.y - D / 2) < .1:
                continue
            hh = 1.55 + (h3(p.x, p.y, 2) - .5) * .3
            k.cyl((p.x, p.y, 0), (p.x + (h3(p.x, p.y, 3) - .5) * .06, p.y, hh), .06, "madera", "madera_gris", "madera", sides=4,
                  caps=(False, True), rot=h3(p.x, p.y, 4))
    run((-W / 2, -D / 2), (W / 2, -D / 2))
    run((W / 2, -D / 2), (W / 2, D / 2))
    run((W / 2, D / 2), (-W / 2, D / 2), skip=(-1.3, 1.3))
    run((-W / 2, D / 2), (-W / 2, -D / 2))
    tranquera(k, -1.25, 1.25, D / 2, h=1.4)


def m_tapia_adobe_a(k):
    """Módulo de tapia de adobe de 4 m con cumbrera de barro (reemplazo de hx_tapia)."""
    tapia_run(k, (-2.0, 0), (2.0, 0), h=2.0, t=.5)


def m_tapia_cal_b(k):
    """Módulo de tapia encalada de 4 m con cumbrera de teja (ciudades: Salta, Jujuy, Buenos Aires)."""
    tapia_run(k, (-2.0, 0), (2.0, 0), h=2.2, t=.5, col="cal", kind="cal", cap="teja", capkind="teja")


def m_tapia_pirca_c(k):
    """Módulo de pirca de 4 m (reemplazo de hx_pirca)."""
    pirca_run(k, (-2.0, 0), (2.0, 0), h=1.2, t=.65, seed=7)


def m_pulperia_a(k):
    """Pulpería de campaña: rancho de adobe con paja, despacho con reja de madera, ramada y palenque."""
    casa_gable(k, 7.0, 4.4, 2.4, 1.45, "paja", [(-2.0, .9, 1.8)], [(1.1, 1.1, .85, 1.6)], t=.5, wall_col="revoque", wall_kind="adobe",
               gal=(2.6, 2.1, [-3.5, -.2, 3.5], "horcon"))
    palenque(k, -2.8, 2.6, 2.2 + 2.6 + 1.6)
    # mostrador visible tras la reja y un banco de palo
    k.box(.5, 1.7, 1.5, 1.85, .3, 1.15, "madera", "madera", "madera", .6)
    k.cyl((-1.0, 3.9, .45), (.6, 3.9, .45), .09, "madera", "algarrobo", "madera", sides=5, caps=(True, True))
    for x in (-.9, .5):
        k.cyl((x, 3.9, 0), (x, 3.9, .45), .05, "madera", "algarrobo", "madera", sides=4, caps=(False, False))


def m_pulperia_b(k):
    """Pulpería de la quebrada: casa de torta con despacho enrejado, galería de horcones y palenque."""
    casa_torta(k, 7.0, 4.4, 2.5, 2.85, [(-2.0, .9, 1.8)], [(1.1, 1.1, .85, 1.6)], t=.55, gal=(2.4, 2.1, [-3.4, 0.0, 3.4]), front_cal=False)
    palenque(k, -2.6, 2.6, 2.2 + 2.4 + 1.6)
    k.box(.5, 1.7, 1.45, 1.75, .3, 1.15, "madera", "madera", "madera", .6)


def m_posta_a(k):
    """Casa de posta de la quebrada: cuerpo largo de cuatro cuartos con galería de horcones y torta."""
    casa_torta(k, 15.0, 5.0, 2.6, 3.0, [(-5.4, .9, 1.85), (-1.8, .9, 1.85), (1.8, .9, 1.85), (5.4, .9, 1.85)],
               [(-3.6, .55, 1.0, 1.5), (3.6, .55, 1.0, 1.5)], t=.6, gal=(2.6, 2.15, [-7.4, -4.4, -1.5, 1.5, 4.4, 7.4]), gargolas=0)
    palenque(k, -6.5, -2.5, 2.5 + 2.6 + 1.5)


def m_posta_b(k):
    """Posta de camino real con techo de paja: cuerpo largo, galería de horcones, palenque y bebedero."""
    casa_gable(k, 13.0, 4.8, 2.5, 1.5, "paja", [(-4.5, .9, 1.85), (-.8, .9, 1.85), (3.2, .9, 1.85)], [(-2.6, .55, 1.0, 1.5), (5.2, .55, 1.0, 1.5)],
               t=.55, wall_col="revoque", wall_kind="adobe", gal=(2.6, 2.15, [-6.4, -3.2, 0.0, 3.2, 6.4], "horcon"))
    palenque(k, 1.5, 5.5, 2.4 + 2.6 + 1.6)
    # bebedero: tronco ahuecado
    k.box(-6.0, -3.6, 5.6, 6.2, 0, .5, "madera", "algarrobo", "madera", .6, skip=("-z",))
    k.poly([(-5.85, 5.7, .51), (-3.75, 5.7, .51), (-3.75, 6.1, .51), (-5.85, 6.1, .51)], "sombra", "sombra", "sombra", out=(0, 0, 1))


def m_casa_ba_a(k):
    """Casa de Buenos Aires (1806): ladrillo revocado y blanqueado, techo de teja a dos aguas, rejas de hierro."""
    casa_gable(k, 8.0, 5.6, 3.3, 1.75, "teja", [(-1.6, 1.15, 2.35)], [(1.3, .95, .85, 2.15), (3.0, .95, .85, 2.15)], t=.55,
               wall_col="cal_ba", wall_kind="cal_ba", reja="hierro", lintel=False, zb=.2, plinth_col="piedra_clara")


def m_casa_ba_b(k):
    """Casa de azotea de Buenos Aires (1806): techo plano tras pretil con cornisa, gárgolas, rejas de hierro."""
    W, D, H, t, zb = 9.0, 6.4, 3.6, .55, .2
    plinth(k, -W / 2, W / 2, -D / 2, D / 2, zb, col="piedra_clara", over=.03)
    ops = [(-2.8 - .6, -2.8 + .6, zb, zb + 2.5), (.2 - .5, .2 + .5, zb + .8, zb + 2.3), (2.6 - .5, 2.6 + .5, zb + .8, zb + 2.3)]
    Ht = H + .8
    k.wall("x", -W / 2, W / 2, D / 2 - t, D / 2, zb, Ht, ops, "cal_ba", "cal_ba", .5, inner="-y")
    k.wall("x", -W / 2, W / 2, -D / 2, -D / 2 + t, zb, Ht, [], "cal_ba", "cal_ba", .5, inner="+y")
    k.wall("y", -D / 2 + t, D / 2 - t, -W / 2, -W / 2 + t, zb, Ht, [], "cal_ba", "cal_ba", .5, inner="+x", ends=(False, False))
    k.wall("y", -D / 2 + t, D / 2 - t, W / 2 - t, W / 2, zb, Ht, [], "cal_ba", "cal_ba", .5, inner="-x", ends=(False, False))
    # azotea: el piso de ladrillo entre pretiles, un poco hundido
    k.box(-W / 2 + t, W / 2 - t, -D / 2 + t, D / 2 - t, H - .2, H, "teja", "teja_oscura", "teja", .9, skip=("-z", "-x", "+x", "-y", "+y"))
    # cara interior del pretil
    for (x0, x1, y0, y1, o) in ((-W / 2 + t, W / 2 - t, D / 2 - t, D / 2 - t, (0, -1, 0)), (-W / 2 + t, W / 2 - t, -D / 2 + t, -D / 2 + t, (0, 1, 0))):
        k.grid((x0, y0, H), (x1, y0, H), (x1, y0, Ht), (x0, y0, Ht), "muro", "cal_sucia", "cal_ba", .6, out=o)
    for (x, o) in ((-W / 2 + t, (1, 0, 0)), (W / 2 - t, (-1, 0, 0))):
        k.grid((x, -D / 2 + t, H), (x, D / 2 - t, H), (x, D / 2 - t, Ht), (x, -D / 2 + t, Ht), "muro", "cal_sucia", "cal_ba", .6, out=o)
    # cornisa a la altura de la azotea y remate del pretil
    k.box(-W / 2 - .1, W / 2 + .1, D / 2 - .1, D / 2 + .12, H - .05, H + .12, "muro", "cal_sucia", "cal_ba", 1.0, skip=())
    k.box(-W / 2 - .05, W / 2 + .05, D / 2 - t - .03, D / 2 + .06, Ht, Ht + .1, "muro", "cal_sucia", "cal_ba", 1.0, skip=())
    for x in (-3.6, 3.8):
        k.box(x - .09, x + .09, D / 2, D / 2 + .55, H + .02, H + .18, "teja", "teja_oscura", "teja", .8, skip=())
    door(k, "x", -2.8, D / 2, 1, 1.2, 2.5, zb, t, lintel=False)
    for x in (.2, 2.6):
        window(k, x, D / 2, 1, 1.0, zb + .8, zb + 2.3, t, reja="hierro", lintel=False)
    # buñas: marco revocado alrededor de la puerta (moldura en relieve)
    k.box(-2.8 - .78, -2.8 + .78, D / 2, D / 2 + .05, zb + 2.5, zb + 2.72, "muro", "cal_sucia", "cal_ba", .8, skip=("-z",))


def m_quinta_ba_a(k):
    """Casa de quinta (Retiro, 1806): encalada, techo de teja y corredor de pilares de madera al frente."""
    casa_gable(k, 11.0, 5.4, 3.0, 1.6, "teja", [(-2.0, 1.1, 2.2), (2.6, 1.0, 2.1)], [(-4.2, .9, .8, 1.9), (.3, .9, .8, 1.9), (4.4, .9, .8, 1.9)],
               t=.55, wall_col="cal_ba", wall_kind="cal_ba", reja="hierro", lintel=False, zb=.2,
               gal=(2.4, 2.35, [-5.5, -2.75, 0.0, 2.75, 5.5], "poste"), plinth_col="piedra_clara")


def m_quinta_ba_b(k):
    """Quinta con casa de teja, tapia baja de adobe alrededor del frente y pozo de balde."""
    sub = Kit("q")
    casa_gable(sub, 9.0, 5.0, 2.9, 1.55, "teja", [(-1.2, 1.05, 2.1)], [(1.5, .85, .8, 1.8), (3.2, .85, .8, 1.8)], t=.55,
               wall_col="cal_ba", wall_kind="cal_ba", reja="madera", lintel=False, zb=.2, plinth_col="piedra_clara")
    merge_rot(k, sub, 0.0, (0, -3.5))
    hw, y0, y1 = 9.5, -1.0, 9.0
    tapia_run(k, (-hw, y0), (-hw, y1), h=1.6, t=.45, col="cal_sucia", kind="cal")
    tapia_run(k, (hw, y0), (hw, y1), h=1.6, t=.45, col="cal_sucia", kind="cal")
    tapia_run(k, (-hw, y1), (-1.3, y1), h=1.6, t=.45, col="cal_sucia", kind="cal")
    tapia_run(k, (1.3, y1), (hw, y1), h=1.6, t=.45, col="cal_sucia", kind="cal")
    for sx in (-1, 1):
        k.box(sx * 1.3 - .28, sx * 1.3 + .28, y1 - .28, y1 + .28, 0, 2.1, "muro", "cal_ba", "cal_ba", .5, skip=("-z",))
    # pozo de balde: brocal de ladrillo, horquetas y travesaño
    px, py = 5.0, 3.5
    k.cyl((px, py, 0), (px, py, .8), .7, "muro", "ladrillo", "ladrillo", sides=8, caps=(False, True))
    k.poly([(px + .52 * math.cos(a * math.pi / 4), py + .52 * math.sin(a * math.pi / 4), .81) for a in range(8)], "sombra", "sombra", "sombra", out=(0, 0, 1))
    for sx in (-1, 1):
        horcon(k, px + sx * .9, py, 2.0, r=.07, base_stone=False)
    k.cyl((px - 1.0, py, 1.95), (px + 1.0, py, 1.95), .06, "madera", "madera_gris", "madera", sides=5, caps=(True, True))
    k.cyl((px, py, 1.9), (px, py, 1.2), .012, "hierro", "madera_gris", "madera", sides=3)
    k.cyl((px, py, 1.2), (px, py, .95), .14, "madera", "madera", "madera", sides=6, r2=.11, caps=(True, True))


CATALOG = {
    # nombre: (constructor, nivel/es, etiqueta, nota corta)
    "casa_rancho_a": (m_casa_rancho_a, "norte, justina", "razonado"),
    "casa_rancho_b": (m_casa_rancho_b, "norte, justina", "razonado"),
    "casa_rancho_c": (m_casa_rancho_c, "humahuaca, norte", "razonado"),
    "casa_torta_a": (m_casa_torta_a, "humahuaca, norte", "razonado"),
    "casa_torta_b": (m_casa_torta_b, "humahuaca, norte", "razonado"),
    "casa_galeria_a": (m_casa_galeria_a, "humahuaca, norte", "razonado"),
    "casa_galeria_b": (m_casa_galeria_b, "norte", "razonado"),
    "casa_patio_a": (m_casa_patio_a, "humahuaca, norte", "razonado"),
    "casa_patio_b": (m_casa_patio_b, "norte", "razonado"),
    "casa_capilla_a": (m_capilla_a, "humahuaca, norte", "razonado"),
    "casa_capilla_b": (m_capilla_b, "humahuaca, norte", "razonado"),
    "casa_capilla_c": (m_capilla_c, "norte, justina", "diseno"),
    "casa_corral_pirca_a": (m_corral_pirca_a, "humahuaca, norte", "razonado"),
    "casa_corral_pirca_b": (m_corral_pirca_b, "humahuaca, norte", "razonado"),
    "casa_corral_palos_c": (m_corral_palos_c, "justina", "diseno"),
    "casa_tapia_adobe_a": (m_tapia_adobe_a, "humahuaca, norte, justina", "razonado"),
    "casa_tapia_cal_b": (m_tapia_cal_b, "norte, justina", "razonado"),
    "casa_tapia_pirca_c": (m_tapia_pirca_c, "humahuaca, norte", "razonado"),
    "casa_pulperia_a": (m_pulperia_a, "norte, justina", "diseno"),
    "casa_pulperia_b": (m_pulperia_b, "humahuaca, norte", "diseno"),
    "casa_posta_a": (m_posta_a, "humahuaca, norte", "diseno"),
    "casa_posta_b": (m_posta_b, "norte", "diseno"),
    "casa_ba_a": (m_casa_ba_a, "justina", "razonado"),
    "casa_ba_b": (m_casa_ba_b, "justina", "razonado"),
    "casa_quinta_a": (m_quinta_ba_a, "justina", "razonado"),
    "casa_quinta_b": (m_quinta_ba_b, "justina", "razonado"),
}


# --------------------------------------------------------------------------------------
# Color final por vértice: variación por cara + suciedad al pie + oclusión por rayos
# --------------------------------------------------------------------------------------
def face_color(kind, base, c, vertex=False):
    x, y, z = c
    hs = .5 if vertex else h3(round(x, 2), round(y, 2), round(z, 2), 11)
    hs2 = .5 if vertex else h3(round(x, 2), round(y, 2), round(z, 2), 23)
    if kind == "adobe":
        t = fbm(c, .7, 3)
        col = base * (1 - .5 * t) + P["adobe_claro"] * .5 * t
        col = col * (.95 + .1 * hs)
    elif kind in ("cal", "cal_ba"):
        # descascarado: deja ver el adobe (o el ladrillo en Buenos Aires) en manchas, más cerca del pie y de las aristas
        n = fbm(c, 1.1, 7)
        thr = .68 - .1 * (1 - sstep(.2, 1.1, z))
        m = sstep(thr, thr + .08, n) * .55
        under = P["ladrillo"] if kind == "cal_ba" else P["revoque"]
        col = base * (.97 + .05 * hs) * (1 - .07 * sstep(.45, .65, fbm(c, .5, 9)))
        col = col * (1 - m) + under * m
    elif kind == "torta":
        col = base * (1 - .5 * fbm(c, .8, 4)) + P["torta_seca"] * .5 * fbm(c, .8, 4)
        col = col * (.9 + .2 * hs)
    elif kind == "paja":
        # mazos de paja: franjas en la dirección de la pendiente (ruido rápido en planta, lento en altura)
        t = fbm((x * 2.6, y * 2.6, z * .35), 1.0, 5)
        col = base * (1 - t) + P["paja_oscura"] * t * .75 + P["paja_clara"] * t * .25
        col = col * (.93 + .12 * hs)
    elif kind == "teja":
        t = hs
        col = base if t < .6 else (P["teja_oscura"] if t < .93 else P["teja_liquen"])
        col = col * (.9 + .2 * hs2)
    elif kind == "piedra":
        col = [P["piedra"], P["piedra_osc"], P["piedra_ocre"], P["piedra_clara"]][int(hs * 3.999)] * (.85 + .3 * hs2)
        col = base * .3 + col * .7
    elif kind == "piedra_s":   # una piedra de pirca: su color ya viene elegido; apenas varía por cara
        col = base * (.9 + .16 * hs)
    elif kind == "madera":
        col = base * (.85 + .3 * hs)
        if hs2 > .7:
            col = col * .6 + P["madera_gris"] * .4
    elif kind == "cana":
        col = base * (.82 + .3 * hs)
    elif kind == "hierro":
        col = base * (.9 + .2 * hs)
    elif kind == "ladrillo":
        col = base * (.85 + .3 * hs)
    else:
        col = base
    return np.clip(col, 0, 1)


GRIME = {"adobe", "cal", "cal_ba", "piedra", "ladrillo", "piedra_s"}
SMOOTH = {"paja", "torta", "cana", "adobe", "cal", "cal_ba"}   # color evaluado en cada vértice (degradés), no por cara


def bake_colors(k):
    V = k.V
    bvh = BVHTree.FromPolygons([tuple(v) for v in V] + [(-80, -80, -.005), (80, -80, -.005), (80, 80, -.005), (-80, 80, -.005)],
                               list(k.F) + [(len(V), len(V) + 1, len(V) + 2, len(V) + 3)], epsilon=0.0)
    # 14 direcciones del hemisferio (fijas, coseno)
    rng = np.random.default_rng(7)
    dirs = []
    for i in range(14):
        u, v = (i + .5) / 14, rng.random()
        r = math.sqrt(u)
        th = 2 * math.pi * (v + i * .618)
        dirs.append((r * math.cos(th), r * math.sin(th), math.sqrt(1 - u)))
    loop_cols = []
    sed = P["sedimento"]
    for fi, f in enumerate(k.F):
        pts = [V[i] for i in f]
        c = sum(pts, Vector()) / len(pts)
        n = newell(pts).normalized()
        kind = k.fk[fi]
        base = face_color(kind, k.fc[fi], c)
        if kind == "sombra":
            loop_cols.append([base] * len(f))
            continue
        t1 = n.orthogonal().normalized()
        t2 = n.cross(t1)
        cols = []
        for p in pts:
            col = face_color(kind, k.fc[fi], p, vertex=True) if kind in SMOOTH else base.copy()
            if kind in GRIME:
                g = 1 - sstep(0.0, .6, p.z)
                col = col * (1 - .55 * g) + sed * .55 * g
                # chorreado bajo el alero (muros): franjas verticales tenues
            o = p + (c - p) * .02 + n * .03
            occ = 0.0
            for dx, dy, dz in dirs:
                d = t1 * dx + t2 * dy + n * dz
                hit = bvh.ray_cast(o, d, 1.6)
                if hit[0] is not None:
                    occ += 1 - hit[3] / 1.6
            occ /= len(dirs)
            col = col * (1 - (.5 if kind in ("cal", "cal_ba") else .62) * occ)
            cols.append(col)
        loop_cols.append(cols)
    return loop_cols


# --------------------------------------------------------------------------------------
# Escena, materiales, exportación
# --------------------------------------------------------------------------------------
def reset():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for b in list(coll):
            coll.remove(b)


def vc_material(name, rough):
    m = bpy.data.materials.get("F5 | " + name)
    if m:
        return m
    m = bpy.data.materials.new("F5 | " + name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes.get("Principled BSDF")
    ca = nt.nodes.new("ShaderNodeVertexColor")
    ca.layer_name = "Col"
    nt.links.new(ca.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = 0.0
    return m


def to_object(k, loop_cols):
    """Ancla de 2 mm primero, después una superficie por material en orden fijo."""
    order = ["ancla"] + [m for m in MATS if m != "ancla" and m in set(k.fm)]
    # ancla
    av, af = [], []
    for i in range(6):
        for j in range(4):
            pass
    import bmesh
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=6, v_segments=4, radius=.001)
    for v in bm.verts:
        v.co.z += .002
    anc_v = [tuple(v.co) for v in bm.verts]
    anc_f = [tuple(v.index for v in f.verts) for f in bm.faces]
    bm.free()
    verts = list(anc_v)
    faces, fmat, fcols = [], [], []
    for f in anc_f:
        faces.append(f)
        fmat.append(0)
        fcols.append([P["piedra"]] * len(f))
    for mi, mname in enumerate(order):
        if mname == "ancla":
            continue
        for fi, f in enumerate(k.F):
            if k.fm[fi] != mname:
                continue
            base = len(verts)
            verts += [tuple(k.V[i]) for i in f]
            faces.append(tuple(range(base, base + len(f))))
            fmat.append(mi)
            fcols.append(loop_cols[fi])
    me = bpy.data.meshes.new(k.name)
    me.from_pydata(verts, [], faces)
    me.update()
    for mname in order:
        me.materials.append(vc_material(mname, MATS[mname]))
    me.polygons.foreach_set("material_index", fmat)
    a = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    me.color_attributes.active_color = a
    flat = []
    for cols in fcols:
        for c in cols:
            flat += [float(c[0]), float(c[1]), float(c[2]), 1.0]
    a.data.foreach_set("color", flat)
    for p in me.polygons:
        p.use_smooth = False
    o = bpy.data.objects.new(k.name, me)
    bpy.context.collection.objects.link(o)
    return o


def tri_count(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def make_lod(o, target):
    """LOD: se sueldan los vértices (el color queda por esquina), se disuelven las caras coplanares y, si hace falta,
    se colapsa hasta ~target triángulos. El ancla se conserva (material 0)."""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(o.data)
    anc = [f for f in bm.faces if f.material_index == 0]
    rest_v = {v for f in bm.faces if f.material_index != 0 for v in f.verts}
    bmesh.ops.remove_doubles(bm, verts=list(rest_v), dist=.002)
    bm.to_mesh(o.data)
    bm.free()
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    d = o.modifiers.new("plana", "DECIMATE")
    d.decimate_type = "DISSOLVE"
    d.angle_limit = math.radians(6)
    d.delimit = {"MATERIAL"}
    bpy.ops.object.modifier_apply(modifier="plana")
    tri = bpy.context.object.modifiers.new("tri", "TRIANGULATE")
    bpy.ops.object.modifier_apply(modifier="tri")
    if tri_count(o) > target:
        c = o.modifiers.new("col", "DECIMATE")
        c.decimate_type = "COLLAPSE"
        c.ratio = target / tri_count(o)
        bpy.ops.object.modifier_apply(modifier="col")
    for p in o.data.polygons:
        p.use_smooth = False


def export(name, o, note, extra):
    target = OUT / (name + ".glb")
    bpy.ops.object.select_all(action="DESELECT")
    kw = dict(filepath=str(target), export_format="GLB", export_yup=True, export_apply=False, export_animations=False,
              export_materials="EXPORT", export_cameras=False, export_lights=False, export_tangents=False,
              export_texcoords=False, use_selection=False)
    props = bpy.ops.export_scene.gltf.get_rna_type().properties
    if "export_vertex_color" in props:
        kw["export_vertex_color"] = "ACTIVE"
    bpy.ops.export_scene.gltf(**kw)
    data = target.read_bytes()
    js, _ = struct.unpack_from("<I4s", data, 12)
    g = json.loads(data[20:20 + js])
    pts = [o.matrix_world @ Vector(c) for c in o.bound_box]
    mn = [min(p[i] for p in pts) for i in range(3)]
    mx = [max(p[i] for p in pts) for i in range(3)]
    rep = {
        "file": target.name, "bytes": target.stat().st_size, "triangles": tri_count(o),
        "meshes": len(g.get("meshes", [])), "surfaces": sum(len(m["primitives"]) for m in g.get("meshes", [])),
        "materials": [m.get("name", "") for m in g.get("materials", [])], "textures": len(g.get("textures", [])),
        "vertex_colors": all("COLOR_0" in p["attributes"] for m in g.get("meshes", []) for p in m["primitives"]),
        "godot_bounds": {"min": [round(mn[0], 3), round(mn[2], 3), round(-mx[1], 3)], "max": [round(mx[0], 3), round(mx[2], 3), round(-mn[1], 3)]},
        "size_m": [round(mx[0] - mn[0], 2), round(mx[2] - mn[2], 2), round(mx[1] - mn[1], 2)],
        "front": "Godot -Z (Blender +Y)", "origin": "suelo, centro de la caja",
        "sha256": hashlib.sha256(data).hexdigest(), "note": note,
    }
    rep.update(extra)
    REPORT[name] = rep
    print("ASSET_READY " + json.dumps({k_: rep[k_] for k_ in ("file", "triangles", "bytes", "size_m")}, ensure_ascii=False))


def center(k):
    xs = [v.x for v in k.V]
    ys = [v.y for v in k.V]
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    for v in k.V:
        v.x -= cx
        v.y -= cy
        if v.z < 0:
            v.z = 0.0
    k.doors = [(d[0] - cx, d[1] - cy, d[2]) for d in k.doors]


def wall_roof_lstar(k, loop_cols):
    """L* medio (albedo, con oclusión y suciedad) de lo que se ve desde arriba (techos) y de los muros, ponderado por área."""
    acc = {"techo": [0.0, np.zeros(3)], "muro": [0.0, np.zeros(3)]}
    for fi, f in enumerate(k.F):
        pts = [k.V[i] for i in f]
        n = newell(pts)
        area = n.length / 2
        if area < 1e-6:
            continue
        nz = n.z / n.length
        key = "techo" if nz > .35 else ("muro" if abs(nz) < .3 else None)
        if key is None or k.fk[fi] == "sombra":
            continue
        c = np.mean(loop_cols[fi], axis=0)
        acc[key][0] += area
        acc[key][1] += c * area
    out = {}
    for key, (a, s) in acc.items():
        if a > 0:
            out[key] = round(lstar(s / a), 1)
    return out


def build(name):
    fn, levels, tag = CATALOG[name]
    reset()
    k = Kit(name, seed=sum(map(ord, name)))
    fn(k)
    center(k)
    if "--stats" in ARGV:
        st = {}
        for fi, f in enumerate(k.F):
            st[k.fm[fi] + "/" + k.fk[fi]] = st.get(k.fm[fi] + "/" + k.fk[fi], 0) + len(f) - 2
        print("STATS", name, sorted(st.items(), key=lambda t: -t[1]))
    cols = bake_colors(k)
    ls = wall_roof_lstar(k, cols)
    o = to_object(k, cols)
    ground_l = lstar(P["suelo"])
    extra = {"levels": levels, "tag": tag,
             "doors_godot": [[round(d[0], 2), round(d[2], 2), round(-d[1], 2)] for d in k.doors],
             "lstar_albedo": {**ls, "suelo_seco": round(ground_l, 1),
                              "delta_techo": round(ls.get("techo", ground_l) - ground_l, 1) if "techo" in ls else None,
                              "delta_muro": round(ls.get("muro", ground_l) - ground_l, 1) if "muro" in ls else None}}
    note = (fn.__doc__ or "").strip()
    export(name, o, note, extra)
    full_tris = tri_count(o)
    if LOD and not name.startswith("casa_tapia"):
        make_lod(o, max(250, int(full_tris * .3)))
        lname = name + "_lod"
        export(lname, o, note + " LOD lejano: caras coplanares disueltas y colapso.", {"levels": levels, "tag": tag, "lod_of": name})
        REPORT[name]["lod"] = lname + ".glb"


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    names = ONLY or list(CATALOG)
    for n in names:
        build(n)
    man = OUT / "f5_casas_manifest.json"
    old = json.loads(man.read_text(encoding="utf-8")) if man.is_file() else {}
    old.update(REPORT)
    old["_convenciones"] = {"unidad": "metro", "frente": "Godot -Z (Blender +Y)", "arriba": "Godot +Y", "origen": "suelo, centro de la caja",
                            "color": "COLOR_0 lineal, sin texturas", "ancla": "primera primitiva, material «F5 | ancla» (Godot 4.7.2)",
                            "paleta_srgb": HEX, "fuente": "tools/f5_casas.py (obra propia)", "historia": "docs/historia/CASAS_F5.md"}
    man.write_text(json.dumps(dict(sorted(old.items())), ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print("F5_CASAS_LISTAS", len(names))


# --------------------------------------------------------------------------------------
# Vistas previas (Workbench, color por vértice): cada modelo con una persona de 1,70 m y el caballo criollo, y un pueblo
# --------------------------------------------------------------------------------------
def import_glb(path, loc=(0, 0, 0), rot=0.0):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    new = [o for o in bpy.data.objects if o not in before]
    root = bpy.data.objects.new("raiz_" + path.stem, None)
    bpy.context.collection.objects.link(root)
    for o in new:
        if o.parent is None:
            o.parent = root
        if o.type == "MESH" and o.data.color_attributes:
            o.data.color_attributes.active_color = o.data.color_attributes[0]
    root.location = loc
    root.rotation_euler = (0, 0, rot)
    return root


def person(loc, yaw=0.0, col=(.12, .07, .04)):
    """Figura de escala: 1,70 m (cabeza, torso, piernas)."""
    k = Kit("persona")
    x, y = loc
    k.cyl((x - .1, y, 0), (x - .1, y, .82), .075, "madera", np.array(col) * .7, "", sides=6, caps=(False, True))
    k.cyl((x + .1, y, 0), (x + .1, y, .82), .075, "madera", np.array(col) * .7, "", sides=6, caps=(False, True))
    k.cyl((x, y, .8), (x, y, 1.45), .2, "madera", np.array(col), "", sides=8, r2=.22, caps=(True, True))
    k.cyl((x, y, 1.46), (x, y, 1.70), .1, "madera", np.array((.55, .42, .32)), "", sides=8, caps=(True, True))
    cols = [[k.fc[i]] * len(f) for i, f in enumerate(k.F)]
    o = to_object(k, cols)
    return o


def preview():
    PREV.mkdir(parents=True, exist_ok=True)
    man = json.loads((OUT / "f5_casas_manifest.json").read_text(encoding="utf-8"))
    names = ONLY or [n for n in CATALOG if (OUT / (n + ".glb")).is_file()]
    horse = ROOT / "assets" / "models" / "caballo_criollo_zaino_lod.glb"

    def setup_scene(day=True):
        """EEVEE: sol cálido de media tarde (o luna fría y baja de noche), cielo uniforme, sombras y oclusión."""
        sc = bpy.context.scene
        sc.render.engine = "BLENDER_EEVEE_NEXT"
        sc.render.resolution_x, sc.render.resolution_y = 1280, 800
        sc.view_settings.view_transform = "AgX" if day else "Standard"
        sc.view_settings.look = "AgX - Base Contrast" if day else "None"
        sc.view_settings.exposure = 0.0
        ee = sc.eevee
        for attr, val in (("use_shadows", True), ("taa_render_samples", 32), ("use_gtao", True), ("gtao_distance", 1.5)):
            if hasattr(ee, attr):
                setattr(ee, attr, val)
        w = bpy.data.worlds.new("cielo")
        sc.world = w
        w.use_nodes = True
        bg = w.node_tree.nodes["Background"]
        bg.inputs[0].default_value = (.55, .62, .75, 1) if day else (.03, .045, .09, 1)
        bg.inputs[1].default_value = 1.0 if day else .6
        sd = bpy.data.lights.new("sol", "SUN")
        sd.energy = 4.2 if day else .9
        sd.color = (1.0, .93, .82) if day else (.62, .74, 1.0)
        sd.angle = math.radians(1.5)
        so = bpy.data.objects.new("sol", sd)
        bpy.context.collection.objects.link(so)
        so.rotation_euler = (math.radians(52), 0, math.radians(35)) if day else (math.radians(38), 0, math.radians(115))

    def ground(size=80, col="suelo"):
        k = Kit("suelo")
        k.poly([(-size, -size, 0), (size, -size, 0), (size, size, 0), (-size, size, 0)], "muro", col, "", out=(0, 0, 1))
        cols = [[k.fc[0]] * 4]
        return to_object(k, cols)

    def cam(target, dist, elev, az, lens=35):
        cam_d = bpy.data.cameras.new("cam")
        cam_d.lens = lens
        c = bpy.data.objects.new("cam", cam_d)
        bpy.context.collection.objects.link(c)
        t = Vector(target)
        d = Vector((math.cos(elev) * math.sin(az), math.cos(elev) * math.cos(az), math.sin(elev)))
        c.location = t + d * dist
        c.rotation_euler = (t - c.location).to_track_quat("-Z", "Y").to_euler()
        bpy.context.scene.camera = c

    def render(path):
        bpy.context.scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        print("PREVIEW", path)

    # 1) cada modelo: tres cuartos de frente, persona y caballo al costado
    for n in names:
        if n.endswith("_lod"):
            continue
        reset()
        setup_scene()
        ground()
        r = import_glb(OUT / (n + ".glb"))
        b = man[n]["godot_bounds"]
        sx = b["max"][0] - b["min"][0]
        sz = b["max"][2] - b["min"][2]
        hy = b["max"][1]
        front_y = -b["min"][2]  # Godot -Z = Blender +Y
        person((b["min"][0] - .9, front_y - .6))
        import_glb(horse, (b["min"][0] - 2.2, front_y - 4.5, 0), rot=math.pi / 2)
        big = max(sx, sz, hy * 1.6)
        cam((0, 0, hy * .38), big * 1.55 + 4, math.radians(24), math.radians(-32), lens=40)
        render(PREV / f"{n}.png")
        # LOD al lado
        if (OUT / (n + "_lod.glb")).is_file() and n in ("casa_capilla_c", "casa_patio_b", "casa_posta_a", "casa_galeria_b"):
            reset()
            setup_scene()
            ground()
            import_glb(OUT / (n + ".glb"), (-sx * .6 - 1, 0, 0))
            import_glb(OUT / (n + "_lod.glb"), (sx * .6 + 1, 0, 0))
            cam((0, 0, hy * .3), big * 2.4 + 6, math.radians(28), math.radians(-25), lens=40)
            render(PREV / f"{n}__lod_comparado.png")
    # 2) pueblo de la quebrada y caserío de Buenos Aires (vista de juego alta y vista cercana)
    if ONLY is None:
        for layout, fname in ((LAYOUT_QUEBRADA, "pueblo_quebrada"), (LAYOUT_NORTE, "pueblo_valle_lerma"), (LAYOUT_BA, "ribera_retiro_1806")):
            for view, (dist, elev, az, lens) in {"alto": (95, 50, -25, 35), "cerca": (40, 20, -35, 30)}.items():
                reset()
                setup_scene()
                ground(160)
                for (mn, x, y, yaw) in layout:
                    if (OUT / (mn + ".glb")).is_file():
                        import_glb(OUT / (mn + ".glb"), (x, y, 0), yaw)
                for i, (px, py) in enumerate([(2, 8), (3.2, 7.5), (-6, 3)]):
                    person((px, py), col=(.3, .22, .15) if i % 2 else (.18, .2, .25))
                import_glb(horse, (5, 9, 0), rot=.6)
                cam((0, 0, 1.5), dist, math.radians(elev), math.radians(az), lens)
                render(PREV / f"{fname}_{view}.png")
        # 3) contraste de noche: luz baja y fría, suelo seco (lectura de B-062 c)
        reset()
        setup_scene(day=False)
        sc = bpy.context.scene
        ground(160)
        for (mn, x, y, yaw) in LAYOUT_QUEBRADA:
            if (OUT / (mn + ".glb")).is_file():
                import_glb(OUT / (mn + ".glb"), (x, y, 0), yaw)
        cam((0, 0, 1.5), 95, math.radians(50), math.radians(-25), 35)
        render(PREV / "pueblo_quebrada_plano_oscuro.png")


# Disposición de los pueblos de prueba (solo para la vista previa; diseño)
LAYOUT_QUEBRADA = [
    ("casa_capilla_b", 0, -14, 0), ("casa_torta_a", -12, 4, 0), ("casa_torta_b", -12, 14, math.pi), ("casa_galeria_a", 12, 4, 0),
    ("casa_patio_a", 14, 18, math.pi), ("casa_rancho_c", -2, 12, math.pi), ("casa_pulperia_b", 2, 22, math.pi),
    ("casa_corral_pirca_a", -26, 0, 0), ("casa_tapia_adobe_a", -4, 4.5, 0), ("casa_tapia_adobe_a", -.2, 4.5, 0),
    ("casa_tapia_pirca_c", 4, 4.5, 0), ("casa_posta_a", 30, -6, math.pi / 2), ("casa_corral_pirca_b", 30, 16, 0),
]
LAYOUT_NORTE = [
    ("casa_capilla_c", 0, -16, 0), ("casa_patio_b", -16, 6, 0), ("casa_galeria_b", 14, 4, 0), ("casa_rancho_a", -2, 14, math.pi),
    ("casa_rancho_b", 12, 18, math.pi), ("casa_pulperia_a", -18, 24, math.pi), ("casa_posta_b", 30, -4, math.pi / 2),
    ("casa_tapia_cal_b", 4, 7, 0), ("casa_tapia_cal_b", 0, 7, 0), ("casa_corral_pirca_a", -32, -4, 0),
]
LAYOUT_BA = [
    ("casa_ba_a", -10, 0, 0), ("casa_ba_b", 0, 0, 0), ("casa_ba_a", 10, 0, 0), ("casa_quinta_a", -12, 16, math.pi),
    ("casa_quinta_b", 12, 18, math.pi), ("casa_rancho_a", 0, 16, math.pi), ("casa_corral_palos_c", 28, 4, 0),
    ("casa_tapia_cal_b", -4, 6, 0), ("casa_tapia_cal_b", 4, 6, 0),
]

if "--preview" in ARGV:
    preview()
else:
    main()
