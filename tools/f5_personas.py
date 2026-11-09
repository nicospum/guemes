"""visual/r1 F5 (parte A) - personas: jinetes y figuras a pie. Blender 4.4.x en linea de comandos. OBRA PROPIA.

    blender -b --disable-autoexec --factory-startup --python tools/f5_personas.py -- \
        [--only jinete_1817,jinete_1806,gaucho_1817,gaucho_1817_carabina,voluntario_1806,realista_1817,arriero_1817,armas]
        [--out assets/models] [--preview ../qa-visual-r1/f5_personas_preview]

Todo sale de este script, sin mallas, texturas ni capturas de terceros: geometria por primitivas propias (tubos por
secciones, tornos, elipsoides, cajas), ponchos colgados con una simulacion de tela propia (dinamica por posiciones con
gravedad y choque contra el cuerpo y, en el jinete, contra el caballo criollo de tools/f4_caballos.py), color por vertice con
oclusion calculada aca, esqueleto propio y ciclos idle/walk/run por formula (cinematica inversa de dos huesos; diseno, NO
captura de movimiento). Con --preview no construye: importa los GLB de --out y hace las vistas de control (Workbench).

Convenciones (las de f4_caballos.py): metros, Blender +Y = frente (Godot -Z), Z arriba (Godot Y); sin texturas, COLOR_0
lineal = albedo final; primera primitiva = esfera «ancla» de 2 mm (defecto de Godot 4.7.2, ver docs/ASSETS.md).
Materiales «<F4|F5> | <rol> | <clase>»: la clase (wool, linen, coat, skin, leather, metal, gloss, wood) es la que leen
world_view.gd y humahuaca_units.gd con ends_with(); el rol (poncho, sombrero, chaqueta, vueltas, ...) permite retintar por
pieza sin heuristicas de color.
Salidas en assets/models/:
  jinete_criollo_<1817|1806>.glb y _lod.glb   jinete sentado, sin esqueleto, origen = asiento (hueso «silla» del caballo).
      Mismos nombres que los de F4 (reemplazo directo). Tonos de lana/lino que el juego reconoce: los de create_models
      (poncho granate 0,31/0,035/0,026 x 0,62 en 1817; casaca indigo, vueltas rojas, calzon blanco, sombrero negro en 1806).
  persona_<tipo>.glb      jefe: esqueleto de 18 huesos + idle/walk/run en el lugar; origen en el suelo, entre los pies.
  persona_<tipo>_lod.glb  tropa: malla estatica en la pose de reposo, pocos triangulos.
  arma_<tacuara|carabina|fusil>.glb   armas sueltas, origen en el punto de agarre de la mano.
  f5_personas_manifest.json
"""
import bpy
import bmesh
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
ALL = ["jinete_1817", "jinete_1806", "gaucho_1817", "gaucho_1817_carabina", "voluntario_1806", "realista_1817",
       "arriero_1817", "armas"]
ONLY = (_arg("--only") or ",".join(ALL)).split(",")
PREVIEW = _arg("--preview")
DEBUG = "--debug" in ARGV
FPS = 24
SEAT = np.array((0.0, 0.0, 1.50))      # asiento del caballo criollo (hueso «silla»), igual que f4_caballos.SEAT
F4_ALBEDO = 0.62                         # world_view.F4_ALBEDO: el juego normaliza los tonos de los jinetes F4 con este factor
HORSE_GLB = ROOT / "assets" / "models" / "caballo_criollo_zaino.glb"
REPORT = {}


def lin(h):
    h = h.lstrip("#")
    c = np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def NT(r, g, b):
    """Tono «normalizado» de create_models.palette() -> albedo final (x0,62): los que el juego reconoce y retinta."""
    return np.array((r, g, b)) * F4_ALBEDO


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


# --------------------------------------------------------------------------------------
# Paletas (albedo lineal). Etiqueta: DISEÑO (aproximaciones de lectura, no colores medidos de ninguna unidad).
# --------------------------------------------------------------------------------------
P = {
    "piel": lin("#9A6B4C"), "piel2": lin("#A8785A"), "piel3": lin("#8A5E42"),
    "pelo": lin("#241A13"), "ojo": lin("#120D0A"),
    "lino": lin("#D9D0B9"), "lino_blanco": lin("#E4DFD2"),
    "lana_parda": lin("#6C5440"), "lana_parda_osc": lin("#3E3127"), "chiripa": lin("#4B4038"),
    "azul_elegido": lin("#2E455A"), "verde_elegido": lin("#4F5E4C"),
    "cuero": lin("#4C372B"), "cuero_claro": lin("#745034"), "potro": lin("#C9AE8C"), "potro_osc": lin("#8C6A4C"),
    "fieltro": lin("#2F2A25"), "paja": lin("#A99470"),
    "hierro": lin("#4B4B47"), "laton": lin("#A88943"), "madera": lin("#59432E"), "cana": lin("#A08C5C"),
    "negro": lin("#2A2926"),
    # realista 1817 (enemigo: puede llevar el rojo de código de bando en vueltas y borla; DISEÑO)
    "bayeta": lin("#BAB3A1"), "borgona": lin("#983F36"), "pantalon_gris": lin("#7E7B72"), "correaje": lin("#E8E1D0"),
    "manta_gris": lin("#6E675C"), "ropa_civil": lin("#7B6953"),
}
# Jinetes F4 (tonos que world_view._poncho_mesh / _tinted_mesh y humahuaca_units._rider_color reconocen).
PJ = {
    "poncho": NT(.31, .035, .026), "guarda": NT(.085, .026, .019), "panuelo": NT(.34, .05, .035),
    "casaca": NT(.04, .085, .15), "vueltas": NT(.42, .045, .05), "sombrero": NT(.03, .029, .027),
    "calzon_blanco": NT(.80, .78, .72), "correaje": NT(.66, .62, .48), "bota_negra": NT(.034, .024, .015),
}

# rol -> clase de material (la clase es lo que leen los scripts del juego)
ROLE_CLASS = {
    "piel": "skin", "pelo": "coat", "ojos": "gloss",
    "camisa": "linen", "calzoncillo": "linen", "panuelo": "linen", "correaje": "linen", "calzon": "linen",
    "poncho": "wool", "chiripa": "wool", "sombrero": "wool", "chaqueta": "wool", "casaca": "wool", "vueltas": "wool",
    "faja": "wool", "pantalon": "wool", "corbatin": "wool", "manta": "wool", "borla": "wool",
    "botas": "leather", "cuero": "leather", "tirador": "leather", "calzado": "leather",
    "metal": "metal", "laton": "metal", "madera": "wood", "cana": "wood",
}


# --------------------------------------------------------------------------------------
# Geometría propia (numpy): cada pieza = vértices, caras, color por vértice, rol y pesos
# --------------------------------------------------------------------------------------
class Part:
    def __init__(self, name, v, f, role, color, smooth=True, bone=None, chain=None, weights=None, ao=1.0, noise=.05):
        self.name, self.role, self.smooth = name, role, smooth
        self.v = np.asarray(v, float).reshape(-1, 3)
        self.f = [tuple(int(i) for i in x) for x in f]
        c = np.asarray(color, float)
        self.c = np.tile(c, (len(self.v), 1)) if c.ndim == 1 else c.copy()
        self.bone, self.chain, self.weights, self.ao, self.noise = bone, chain, weights, ao, noise


def _bm_to_vf(bm):
    bm.verts.index_update()
    v = np.array([x.co[:] for x in bm.verts])
    f = [[x.index for x in face.verts] for face in bm.faces]
    bm.free()
    return v, f


def fix_normals(v, f):
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in v]
    for face in f:
        try:
            bm.faces.new([vs[i] for i in face])
        except ValueError:
            pass
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _bm_to_vf(bm)


def ellipsoid(c, r, seg=10, rings=7, rot=None):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1.0)
    v, f = _bm_to_vf(bm)
    v = v * np.asarray(r, float)
    if rot is not None:
        v = v @ np.asarray(rot).T
    return v + np.asarray(c, float), f


def cube(c, s, rot=None):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    v, f = _bm_to_vf(bm)
    v = v * np.asarray(s, float)
    if rot is not None:
        v = v @ np.asarray(rot).T
    return v + np.asarray(c, float), f


def rot_between(a, b):
    """Matriz 3x3 que lleva el eje a sobre el eje b."""
    a, b = Vector(a).normalized(), Vector(b).normalized()
    return np.array(a.rotation_difference(b).to_matrix())


def frame(t, hint):
    t = t / np.linalg.norm(t)
    h = np.asarray(hint, float)
    a = h - (h @ t) * t
    if np.linalg.norm(a) < 1e-4:
        h = np.array((0, 1.0, 0)) if abs(t[1]) < .9 else np.array((0, 0, 1.0))
        a = h - (h @ t) * t
    a /= np.linalg.norm(a)
    return a, np.cross(t, a)


def loft(pts, rx, ry=None, sides=8, hint=(1, 0, 0), caps=True, phase=0.0, profile=None, closed=False):
    """Tubo por secciones elípticas a lo largo de una polilínea. rx/ry escalar o lista. profile(i, k) -> factor radial.
    closed: la polilínea es un lazo (bandoleras, poncho arrollado)."""
    pts = np.asarray(pts, float)
    n = len(pts)
    rx = list(rx) if isinstance(rx, (list, tuple, np.ndarray)) else [rx] * n
    ry = rx if ry is None else (list(ry) if isinstance(ry, (list, tuple, np.ndarray)) else [ry] * n)
    verts = []
    for i in range(n):
        t = (pts[(i + 1) % n] - pts[i - 1]) if closed else (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)])
        a, b = frame(t, hint)
        for k in range(sides):
            ang = 2 * math.pi * k / sides + phase
            pf = profile(i, k) if profile else 1.0
            verts.append(pts[i] + (a * math.cos(ang) * rx[i] + b * math.sin(ang) * ry[i]) * pf)
    faces = []
    for i in range(n if closed else n - 1):
        j = (i + 1) % n
        for k in range(sides):
            a0, a1 = i * sides + k, i * sides + (k + 1) % sides
            faces.append((a0, a1, j * sides + (k + 1) % sides, j * sides + k))
    if caps and not closed:
        faces.append(tuple(reversed(range(sides))))
        faces.append(tuple(range((n - 1) * sides, n * sides)))
    return np.array(verts), faces


def lathe(profile, sides=12, c=(0, 0, 0), sx=1.0, sy=1.0, rot=None):
    """Torno vertical: profile = [(r, z), ...] de arriba hacia abajo; r=0 en los extremos cierra con polo."""
    verts, rings = [], []
    for r, z in profile:
        if r < 1e-6:
            rings.append([len(verts)])
            verts.append((0, 0, z))
        else:
            ring = []
            for k in range(sides):
                a = 2 * math.pi * k / sides
                ring.append(len(verts))
                verts.append((r * math.cos(a) * sx, r * math.sin(a) * sy, z))
            rings.append(ring)
    faces = []
    for A, B in zip(rings[:-1], rings[1:]):
        if len(A) == 1 and len(B) > 1:
            faces += [(A[0], B[k], B[(k + 1) % sides]) for k in range(sides)]
        elif len(B) == 1 and len(A) > 1:
            faces += [(A[k], A[(k + 1) % sides], B[0]) for k in range(sides)]
        else:
            faces += [(A[k], A[(k + 1) % sides], B[(k + 1) % sides], B[k]) for k in range(sides)]
    v = np.array(verts, float)
    if rot is not None:
        v = v @ np.asarray(rot).T
    v, faces = fix_normals(v + np.asarray(c, float), faces)
    return v, faces


def sheet(grid):
    """Lámina de una grilla [filas][cols] de puntos."""
    g = np.asarray(grid, float)
    nr, nc = g.shape[:2]
    f = [(i * nc + j, i * nc + j + 1, (i + 1) * nc + j + 1, (i + 1) * nc + j) for i in range(nr - 1) for j in range(nc - 1)]
    return g.reshape(-1, 3), f


def merge(*vfs):
    V, F, o = [], [], 0
    for v, f in vfs:
        V.append(np.asarray(v, float))
        F += [tuple(i + o for i in x) for x in f]
        o += len(v)
    return np.vstack(V), F


# --------------------------------------------------------------------------------------
# Esqueleto de persona (18 huesos, nombres en castellano). L = izquierda de la figura = -X.
# --------------------------------------------------------------------------------------
BONES = ["raiz", "cadera", "columna", "pecho", "cuello", "cabeza",
         "brazo_L", "antebrazo_L", "mano_L", "brazo_R", "antebrazo_R", "mano_R",
         "muslo_L", "pierna_L", "pie_L", "muslo_R", "pierna_R", "pie_R"]


def V3(*a):
    return np.array(a, float)


def standing_joints(arms):
    """Articulaciones de pie (m). Piernas exactamente verticales (la IK del andar es plana). arms: {lado: (codo, muñeca, mano)}."""
    J = {}
    for s, x in (("L", -.10), ("R", .10)):
        J["hip_" + s] = V3(x, 0, .93)
        J["knee_" + s] = V3(x, 0, .50)
        J["ankle_" + s] = V3(x, 0, .085)
        J["toe_" + s] = V3(x * 1.05, .17, .03)
        J["shoulder_" + s] = V3(x * 1.85, -.01, 1.43)
    J.update({"pelvis": V3(0, 0, .93), "waist": V3(0, 0, 1.06), "chest": V3(0, -.005, 1.24), "neck": V3(0, -.01, 1.47),
              "head": V3(0, .0, 1.60), "top": V3(0, .0, 1.715)})
    for s, (e, w, h) in arms.items():
        J["elbow_" + s], J["wrist_" + s], J["hand_" + s] = V3(*e), V3(*w), V3(*h)
    return J


def bones_from_joints(J):
    B = {"raiz": (V3(0, 0, 0), V3(0, .15, 0)),
         "cadera": (J["pelvis"], J["waist"]), "columna": (J["waist"], J["chest"]), "pecho": (J["chest"], J["neck"]),
         "cuello": (J["neck"], J["neck"] + V3(0, .01, .07)), "cabeza": (J["neck"] + V3(0, .01, .07), J["top"])}
    for s in "LR":
        B["brazo_" + s] = (J["shoulder_" + s], J["elbow_" + s])
        B["antebrazo_" + s] = (J["elbow_" + s], J["wrist_" + s])
        B["mano_" + s] = (J["wrist_" + s], J["hand_" + s] + (J["hand_" + s] - J["wrist_" + s]) * .6)
        B["muslo_" + s] = (J["hip_" + s], J["knee_" + s])
        B["pierna_" + s] = (J["knee_" + s], J["ankle_" + s])
        B["pie_" + s] = (J["ankle_" + s], J["toe_" + s])
    return B


PARENT = {"cadera": "raiz", "columna": "cadera", "pecho": "columna", "cuello": "pecho", "cabeza": "cuello",
          "brazo_L": "pecho", "antebrazo_L": "brazo_L", "mano_L": "antebrazo_L",
          "brazo_R": "pecho", "antebrazo_R": "brazo_R", "mano_R": "antebrazo_R",
          "muslo_L": "cadera", "pierna_L": "muslo_L", "pie_L": "pierna_L",
          "muslo_R": "cadera", "pierna_R": "muslo_R", "pie_R": "pierna_R"}


def seg_dist(Pt, a, b):
    ab = b - a
    t = np.clip(((Pt - a) @ ab) / max(ab @ ab, 1e-9), 0, 1)
    return np.linalg.norm(Pt - (a + t[:, None] * ab), axis=1)


def chain_weights(Pt, bones, B, power=8, keep=2):
    D = np.stack([seg_dist(Pt, *B[b]) for b in bones], 1)
    W = 1.0 / (D + .012) ** power
    if len(bones) > keep:
        thr = -np.sort(-W, axis=1)[:, keep - 1:keep]
        W = np.where(W >= thr, W, 0.0)
    W /= W.sum(1, keepdims=True)
    return {b: W[:, i] for i, b in enumerate(bones)}


# --------------------------------------------------------------------------------------
# Piezas del cuerpo y la ropa
# --------------------------------------------------------------------------------------
class Q:
    """Calidad: jefe (hi) o tropa (lo)."""
    def __init__(self, hi):
        self.hi = hi
        self.limb = 8 if hi else 5
        self.torso = 12 if hi else 6
        self.head = (12, 9) if hi else (7, 5)
        self.hat = 16 if hi else 8
        self.small = 6 if hi else 4


def head_parts(J, q, beard=False, hair_long=True, queue=False, skin="piel", mustache=False):
    """Cabeza estilizada: cráneo, mandíbula más angosta, nariz, orejas y ojos (jefe), pelo, barba."""
    c = J["head"]
    out = []
    v, f = ellipsoid((0, 0, 0), (.088, .102, .118), *q.head)
    z = v[:, 2]
    v[:, 0] *= np.where(z < 0, 1 - .28 * (-z / .118), 1.0)          # mandíbula más angosta
    v[:, 1] += np.where((z < -.02) & (v[:, 1] > 0), .012, 0)         # mentón
    v[:, 1] *= np.where(v[:, 1] < 0, 1.06, .96)                       # nuca llena, cara plana
    out.append(Part("cabeza", v + c, f, "piel", P[skin], bone="cabeza"))
    nv, nf = cube((0, 0, 0), (.026, .03, .052), rot=Matrix.Rotation(-.25, 3, "X"))
    out.append(Part("nariz", nv + c + V3(0, .1, -.005), nf, "piel", P[skin] * .95, smooth=False, bone="cabeza"))
    if q.hi:
        for s in (-1, 1):
            ev, ef = ellipsoid(c + V3(s * .034, .089, .018), (.011, .006, .008), 6, 4)
            out.append(Part("ojo", ev, ef, "ojos", P["ojo"], bone="cabeza", noise=0))
            ov, of = ellipsoid(c + V3(s * .088, -.005, .0), (.012, .024, .032), 6, 4)
            out.append(Part("oreja", ov, of, "piel", P[skin] * .92, bone="cabeza"))
            bv, bf = cube(c + V3(s * .035, .094, .036), (.034, .012, .010))
            out.append(Part("ceja", bv, bf, "pelo", P["pelo"], smooth=False, bone="cabeza", noise=0))
    # pelo: casquete detrás y arriba; melena hasta la nuca (gaucho) o recogido con coleta (1806)
    hv, hf = ellipsoid((0, 0, 0), (.094, .108, .118), *q.head)
    cen = np.array([hv[list(x)].mean(0) for x in hf])
    keepf = (cen[:, 1] < .03) & (cen[:, 2] > (-.075 if hair_long else -.03) - .06 * (cen[:, 1] < -.04))
    hf = [x for x, k in zip(hf, keepf) if k]
    if hair_long:
        hv[:, 2] -= np.where(hv[:, 1] < -.03, .045 * smoothstep(.0, -.1, hv[:, 2]), 0)
    out.append(Part("pelo", hv + c + V3(0, -.004, .006), hf, "pelo", P["pelo"], bone="cabeza"))
    if queue:
        qv, qf = loft([c + V3(0, -.10, -.05), c + V3(0, -.115, -.13), c + V3(0, -.11, -.20)], [.018, .016, .01], sides=q.small)
        out.append(Part("coleta", qv, qf, "pelo", P["pelo"], bone="cabeza"))
    if beard:
        bv, bf = ellipsoid((0, 0, 0), (.072, .062, .058), q.head[0] if q.hi else 5, q.head[1] if q.hi else 4)
        sel = bv[:, 1] > -.01
        bv[:, 2] = np.where(sel, bv[:, 2], bv[:, 2] * .5)
        out.append(Part("barba", bv + c + V3(0, .035, -.07), bf, "pelo", P["pelo"] * 1.1, bone="cabeza"))
    if mustache:
        mv, mf = cube(c + V3(0, .1, -.045), (.06, .014, .014))
        out.append(Part("bigote", mv, mf, "pelo", P["pelo"], smooth=False, bone="cabeza", noise=0))
    nv, nf = loft([J["neck"] - V3(0, 0, .02), J["neck"] + V3(0, .01, .085)], [.052, .05], sides=q.limb)
    out.append(Part("cuello", nv, nf, "piel", P[skin] * .93, chain=["pecho", "cuello"]))
    return out


def hat_gaucho(J, q, role="sombrero", color=None, brim=.205, crown_h=.105, tilt=-.06):
    """Sombrero de fieltro de ala mediana y copa baja (diseño de época plausible)."""
    c = J["top"] + V3(0, .0, -.035)
    col = P["fieltro"] if color is None else color
    prof = [(0, crown_h), (.07, crown_h), (.092, crown_h - .012), (.098, .03), (.10, .012), (brim * .92, .006),
            (brim, -.008), (brim * .97, -.016), (.098, -.004), (.0, -.004)]
    if not q.hi:
        prof = [(0, crown_h), (.09, crown_h - .006), (.10, .012), (brim, -.006), (.098, -.012), (0, -.012)]
    v, f = lathe(prof, q.hat, (0, 0, 0), 1.0, 1.08, rot=np.array(Matrix.Rotation(tilt, 3, "X")))
    out = [Part("sombrero", v + c, f, role, col, bone="cabeza")]
    if not q.hi:
        return out
    bv, bf = lathe([(0, .036), (.1, .036), (.102, .012), (0, .012)], q.hat, (0, 0, 0), 1.01, 1.09,
                   rot=np.array(Matrix.Rotation(tilt, 3, "X")))
    out.append(Part("cinta", bv + c, bf, "cuero", P["cuero"], bone="cabeza", noise=0))
    return out


def bicorne(J, q, cockade=True, role="sombrero", col=None, cock_col=None, cock_role="vueltas"):
    """Bicornio llevado de través (1806), negro, con escarapela roja lisa (sin escarapela celeste y blanca)."""
    c = J["top"] + V3(0, -.005, -.045)
    col = PJ["sombrero"] if col is None else col
    n = 9 if q.hi else 5
    secs = []
    for i in range(n):
        x = -.215 + .43 * i / (n - 1)
        u = x / .215
        h = .035 + .13 * math.sqrt(max(0.0, 1 - u * u))
        w = .12 * (1 - .35 * u * u)
        secs.append([(x, -w, 0), (x, -.012, h), (x, .012, h), (x, w, 0)])
    verts = [p for s in secs for p in s]
    faces = [(i * 4 + k, i * 4 + (k + 1) % 4, (i + 1) * 4 + (k + 1) % 4, (i + 1) * 4 + k) for i in range(n - 1) for k in range(4)]
    faces += [(0, 1, 2, 3), tuple((n - 1) * 4 + k for k in (3, 2, 1, 0))]
    v, f = fix_normals(np.array(verts), faces)
    out = [Part("bicornio", v + c, f, role, col, smooth=False, bone="cabeza")]
    cv, cf = ellipsoid((0, 0, 0), (.013, .040, .040), 8 if q.hi else 5, 5 if q.hi else 4)
    out.append(Part("copa", *ellipsoid(c + V3(0, 0, .0), (.095, .1, .05), q.head[0], 5), role, col, bone="cabeza"))
    if cockade:
        out.append(Part("escarapela", cv + c + V3(-.13, .075, .085), cf, cock_role, PJ["vueltas"] if cock_col is None else cock_col,
                        bone="cabeza", noise=0))
    return out


def shako(J, q, plate=True):
    """Chacó de fieltro negro con visera, chapa lisa de latón y borla (diseño: sin insignia de cuerpo)."""
    c = J["top"] + V3(0, .0, -.05)
    rot = np.array(Matrix.Rotation(-.05, 3, "X"))
    v, f = lathe([(0, .215), (.108, .215), (.108, .205), (.1, .0), (0, .0)], q.hat, (0, 0, 0), 1.0, 1.1, rot=rot)
    out = [Part("chaco", v + c, f, "sombrero", P["negro"], bone="cabeza")]
    vv = [(-.09, .085, .012), (.09, .085, .012), (.07, .175, -.01), (-.07, .175, -.01)]
    sv, sf = fix_normals(np.array(vv + [(p[0], p[1], p[2] - .008) for p in vv]),
                         [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)])
    out.append(Part("visera", sv + c, sf, "cuero", P["negro"] * .8, smooth=False, bone="cabeza", noise=0))
    if plate:
        pv, pf = cube(c + V3(0, .118, .085), (.07, .008, .08))
        out.append(Part("chapa", pv, pf, "laton", P["laton"], smooth=False, bone="cabeza", noise=0))
    bv, bf = ellipsoid(c + V3(0, .02, .245), (.03, .03, .035), q.small + 2, q.small)
    out.append(Part("borla", bv, bf, "borla", P["borgona"], bone="cabeza", noise=0))
    return out


def arm_parts(J, s, q, sleeve_col, role, cuff=None, cuff_role=None, skin="piel", sleeve_r=(.062, .05, .042), fist=True):
    sh, el, wr, ha = J["shoulder_" + s], J["elbow_" + s], J["wrist_" + s], J["hand_" + s]
    out = []
    pts = [sh, (sh + el) / 2, el, (el + wr) / 2, wr]
    r = [sleeve_r[0], sleeve_r[0] * .95, sleeve_r[1], (sleeve_r[1] + sleeve_r[2]) / 2, sleeve_r[2]]
    v, f = loft(pts, r, sides=q.limb, hint=(0, 1, 0))
    out.append(Part("manga", v, f, role, sleeve_col, chain=["pecho", "brazo_" + s, "antebrazo_" + s]))
    if q.hi:
        v, f = ellipsoid(sh + V3(0, 0, -.015), (.06, .06, .06), q.limb, q.small)
        out.append(Part("hombro", v, f, role, sleeve_col, chain=["pecho", "brazo_" + s]))
    if cuff is not None:
        d = (wr - el) / np.linalg.norm(wr - el)
        v, f = loft([wr - d * .075, wr - d * .005], [sleeve_r[2] + .009] * 2, sides=q.limb, hint=(0, 1, 0))
        out.append(Part("puño", v, f, cuff_role, cuff, bone="antebrazo_" + s))
    d = (ha - wr) / np.linalg.norm(ha - wr)
    R = rot_between((0, 0, 1), d)
    v, f = ellipsoid(ha - d * .01, (.042, .036, .058), q.limb if q.hi else 4, q.small if q.hi else 3, rot=R)
    out.append(Part("mano", v, f, "piel", P[skin] * .97, bone="mano_" + s))
    if q.hi:
        v, f = ellipsoid(ha + R @ V3(-.03 if s == "R" else .03, .02, .0), (.014, .014, .028), 5, 4, rot=R)
        out.append(Part("pulgar", v, f, "piel", P[skin] * .97, bone="mano_" + s))
    return out


def torso_loft(J, q, col, role, rx=(.135, .16, .145, .168, .175, .075), ry=(.105, .118, .10, .118, .10, .062), lower=None,
               chain=("cadera", "columna", "pecho")):
    p, w, ch, nk = J["pelvis"], J["waist"], J["chest"], J["neck"]
    sh_z = (J["shoulder_L"][2] + J["shoulder_R"][2]) / 2
    pts = [p + V3(0, 0, -.07) if lower is None else lower, p + V3(0, 0, .02), w, ch, V3(ch[0], ch[1], sh_z - .01), nk + V3(0, 0, .015)]
    v, f = loft(pts, list(rx), list(ry), sides=q.torso, hint=(1, 0, 0))
    return Part("torso", v, f, role, col, chain=list(chain))


def leg_tube(J, s, q, z0, z1, r0, r1, col, role, bulge=0.0, sides=None, chain=None, name="pierna", flare_hem=None):
    """Tubo sobre la pierna entre dos alturas relativas (0 = cadera, 1 = muslo hasta rodilla, 2 = tobillo)."""
    def at(u):
        if u <= 1:
            return J["hip_" + s] + (J["knee_" + s] - J["hip_" + s]) * u
        return J["knee_" + s] + (J["ankle_" + s] - J["knee_" + s]) * (u - 1)
    n = 4
    us = np.linspace(z0, z1, n)
    pts = [at(u) for u in us]
    rr = [r0 + (r1 - r0) * i / (n - 1) + bulge * math.sin(math.pi * i / (n - 1)) for i in range(n)]
    prof = None
    if flare_hem:   # ruedo con flecos (calzoncillo cribado): dientes alternos en el último anillo
        def prof(i, k):
            return 1.0 + (flare_hem if (i == n - 1 and k % 2 == 0) else 0.0)
    v, f = loft(pts, rr, sides=sides or q.limb, hint=(1, 0, 0), profile=prof)
    if flare_hem:
        sd = sides or q.limb
        v[(n - 1) * sd:(n - 1) * sd + sd:2, 2] -= .03
    ch = chain or (["cadera", "muslo_" + s, "pierna_" + s] if z0 < 1 else ["muslo_" + s, "pierna_" + s, "pie_" + s])
    return Part(name, v, f, role, col, chain=ch)


def foot_boot_potro(J, s, q):
    """Bota de potro: cuero crudo de la pata del potro, del garrón a la rodilla, punta abierta: asoman los dedos."""
    out = []
    a, t = J["ankle_" + s], J["toe_" + s]
    out.append(leg_tube(J, s, q, 1.12, 1.96, .062, .05, P["potro"], "botas", name="bota"))
    v, f = loft([J["knee_" + s] + (J["ankle_" + s] - J["knee_" + s]) * .1, J["knee_" + s] + (J["ankle_" + s] - J["knee_" + s]) * .2],
                [.066, .064], sides=q.limb, hint=(1, 0, 0))
    if q.hi:
        out.append(Part("bota_ruedo", v, f, "botas", P["potro_osc"], chain=["pierna_" + s]))
    fwd = (t - a) * V3(1, 1, 0)
    pts = [a + V3(0, -.05, -.03), a + V3(0, .0, -.04), a + fwd * .55 + V3(0, 0, -.05), a + fwd * .78 + V3(0, 0, -.06)]
    v, f = loft(pts, [.035, .046, .045, .04], [.04, .05, .03, .022], sides=q.limb, hint=(1, 0, 0))
    out.append(Part("pie_bota", v, f, "botas", P["potro"] * .92, chain=["pierna_" + s, "pie_" + s]))
    if q.hi:   # asoman los dedos (a la distancia de la tropa no se ven)
        v, f = ellipsoid(a + fwd * .93 + V3(0, 0, -.064), (.04, .035, .018), q.small + 1, 4)
        out.append(Part("dedos", v, f, "piel", P["piel3"], bone="pie_" + s))
    return out


def foot_shoe(J, s, q, col, role="calzado", h=.05, name="zapato", gaiter=None, gaiter_top=1.62, sole_col=None):
    out = []
    a, t = J["ankle_" + s], J["toe_" + s]
    fwd = (t - a) * V3(1, 1, 0)
    pts = [a + V3(0, -.055, -.035), a + V3(0, 0, -.03), a + fwd * .6 + V3(0, 0, -.05), a + fwd * 1.0 + V3(0, 0, -.06)]
    v, f = loft(pts, [.04, .05, .048, .035], [.045, .055, .034, .022], sides=q.limb, hint=(1, 0, 0))
    out.append(Part(name, v, f, role, col, chain=["pierna_" + s, "pie_" + s]))
    if gaiter is not None:
        out.append(leg_tube(J, s, q, gaiter_top, 1.98, .055, .052, gaiter, role, name="polaina"))
    return out


def foot_ojota(J, s, q):
    out = []
    a, t = J["ankle_" + s], J["toe_" + s]
    fwd = (t - a) * V3(1, 1, 0)
    pts = [a + V3(0, -.05, -.035), a + V3(0, 0, -.035), a + fwd * .6 + V3(0, 0, -.05), a + fwd * 1.0 + V3(0, 0, -.06)]
    v, f = loft(pts, [.036, .044, .043, .034], [.04, .05, .03, .02], sides=q.limb, hint=(1, 0, 0))
    out.append(Part("pie", v, f, "piel", P["piel3"], chain=["pierna_" + s, "pie_" + s]))
    sv, sf = cube(a + fwd * .45 + V3(0, 0, -.078), (.095, .29, .016))
    out.append(Part("suela", sv, sf, "calzado", P["cuero"], smooth=False, bone="pie_" + s, noise=0))
    if q.hi:
        v, f = loft([a + fwd * .55 + V3(-.045, 0, -.075), a + fwd * .55 + V3(0, .0, -.03), a + fwd * .55 + V3(.045, 0, -.075)],
                    .007, sides=4, caps=False)
        out.append(Part("tira", v, f, "calzado", P["cuero"], bone="pie_" + s, noise=0))
    return out


def belt(J, q, col, role, z=None, r=(.168, .128), h=.07, name="cinto"):
    w = J["waist"]
    z = w[2] - .02 if z is None else z
    v, f = loft([V3(w[0], w[1], z - h / 2), V3(w[0], w[1], z + h / 2)], [r[0]] * 2, [r[1]] * 2, sides=12 if q.hi else 6)
    return Part(name, v, f, role, col, chain=["cadera", "columna"])


def chiripa(J, q, col, role="chiripa", crotch=.70, knee_u=.78):
    """Chiripá: paño de lana pasado entre las piernas, holgado como un calzón ancho hasta arriba de la rodilla."""
    out = []
    p = J["pelvis"]
    v, f = loft([V3(0, 0, crotch), V3(0, .0, crotch + .1), V3(0, .005, p[2] - .03), V3(0, 0, J["waist"][2] - .01)],
                [.12, .175, .19, .17], [.09, .125, .132, .125], sides=q.torso, hint=(1, 0, 0))
    out.append(Part("chiripa", v, f, role, col, chain=["cadera", "muslo_L", "muslo_R"]))
    for s in "LR":
        out.append(leg_tube(J, s, q, .12, knee_u, .115, .103, col, role, bulge=.012, name="chiripa_pierna",
                            chain=["cadera", "muslo_" + s]))
    return out


def facon(J, q, chain=("cadera",)):
    w = J["waist"]
    v, f = loft([w + V3(.14, -.12, .02), w + V3(.05, -.16, -.03)], [.016, .014], sides=q.small)
    h = Part("facon_vaina", v, f, "cuero", P["cuero"], chain=list(chain), noise=0)
    v, f = loft([w + V3(.16, -.11, .03), w + V3(.20, -.10, .05)], .012, sides=q.small)
    return [h, Part("facon_cabo", v, f, "laton", P["laton"], chain=list(chain), noise=0)]


# --------------------------------------------------------------------------------------
# Tela propia: dinámica por posiciones (gravedad + largos de la lámina) y choque contra el cuerpo (BVH)
# --------------------------------------------------------------------------------------
def poncho_layout(W, L, nr, n_per, neck_rx, neck_ry):
    """Rectángulo W (ancho, hombro a hombro) x L (largo, adelante-atrás) con boca en el centro; grilla polar:
    anillo 0 = boca (cuello), último = ruedo, columnas = puntos del perímetro repartidos parejo (con las esquinas)."""
    per = []
    corners = [(W / 2, L / 2), (-W / 2, L / 2), (-W / 2, -L / 2), (W / 2, -L / 2)]
    sides_len = [W, L, W, L]
    tot = 2 * (W + L)
    for i in range(4):
        a, b = np.array(corners[i - 1]), np.array(corners[i])
        k = max(2, int(round(n_per * sides_len[i - 1] / tot)))
        for j in range(k):
            per.append(a + (b - a) * j / k)
    per = np.array(per)
    ang = np.arctan2(per[:, 1], per[:, 0])
    neck = np.stack([neck_rx * np.cos(ang), neck_ry * np.sin(ang)], 1)
    ts = list(np.linspace(0, 1, nr - 1) * .94) + [1.0]      # el último anillo cierra la guarda (6 % del largo)
    rings = [neck + (per - neck) * t for t in ts]
    flat = np.array(rings)                     # (nr, n, 2)
    return flat


def drape_poncho(flat, z0, center, colliders_bvh, pin_ring, steps=260, iters=30, thick=.014, ground=.03, seed=3,
                 pre=None, friction=.0, bend=.25, substeps=1):
    nr, n = flat.shape[:2]
    idx = lambda i, j: i * n + (j % n)
    X = np.zeros((nr * n, 3))
    X[:, :2] = flat.reshape(-1, 2) + center[:2]
    X[:, 2] = z0
    if pre is not None:
        X = pre(X)
    rest_flat = np.zeros_like(X)
    rest_flat[:, :2] = flat.reshape(-1, 2)
    E = []
    for i in range(nr):
        for j in range(n):
            E.append((idx(i, j), idx(i, j + 1), 1.0))
            if i < nr - 1:
                E.append((idx(i, j), idx(i + 1, j), 1.0))
                E.append((idx(i, j), idx(i + 1, j + 1), .7))
                E.append((idx(i, j + 1), idx(i + 1, j), .7))
            if i < nr - 2:
                E.append((idx(i, j), idx(i + 2, j), bend))
            E.append((idx(i, j), idx(i, j + 2), bend))
    E = np.array(E)
    a, b, k = E[:, 0].astype(int), E[:, 1].astype(int), E[:, 2]
    rest = np.linalg.norm(rest_flat[a] - rest_flat[b], axis=1)
    inv = np.ones(len(X))
    pins = pin_ring.reshape(-1, 3)
    inv[:n] = 0.0
    X[:n] = pins
    prev = X.copy()
    dt = 1 / 60 / substeps
    g = np.array((0, 0, -9.8)) * dt * dt
    for st in range(steps):
        vel = (X - prev) * .985
        prev = X.copy()
        X = X + (vel + g) * inv[:, None]
        for it in range(iters):
            if substeps > 1 and it % 10 == 9:      # choque también entre iteraciones: la tela no atraviesa los brazos
                X = collide(X, colliders_bvh, thick, inv)
            d = X[b] - X[a]
            ln = np.linalg.norm(d, axis=1) + 1e-9
            c = ((ln - rest) / ln)[:, None] * d * .5 * k[:, None]
            # tela: estira poco, se arruga libre (las compresiones pesan menos)
            c = np.where((ln < rest)[:, None], c * .65, c)
            acc = np.zeros_like(X)
            cnt = np.zeros(len(X))
            np.add.at(acc, a, c)
            np.add.at(acc, b, -c)
            np.add.at(cnt, a, k)
            np.add.at(cnt, b, k)
            X = X + acc / np.maximum(cnt, 1)[:, None] * 1.6 * inv[:, None]
        X[:, 2] = np.maximum(X[:, 2], ground)
        X, hit = collide(X, colliders_bvh, thick, inv, report=True)
        # rozamiento: la tela apoyada casi no resbala (sin esto el poncho se escurre de los hombros)
        prev[hit] = X[hit] - (X[hit] - prev[hit]) * friction
        if DEBUG and st % 20 == 0:
            h = X.reshape(nr, n, 3)[-1]
            print("DRAPE", st, "hem z %.2f..%.2f y %.2f..%.2f x %.2f..%.2f" % (h[:, 2].min(), h[:, 2].max(), h[:, 1].min(), h[:, 1].max(),
                                                                         h[:, 0].min(), h[:, 0].max()), "contact", int(hit.sum()))
    return X, nr, n


class Collider:
    """Un sólido para la tela: su BVH y su caja (los puntos lejos de la caja ni se consultan)."""
    def __init__(self, v, f, pad=.08):
        self.bvh = BVHTree.FromPolygons([tuple(x) for x in v], [list(x) for x in f])
        self.lo, self.hi = np.asarray(v).min(0) - pad, np.asarray(v).max(0) + pad


def collide(X, cols, thick, inv=None, report=False):
    """Empuja afuera de cada sólido (uno por pieza: así una pieza metida en otra no confunde el adentro y el afuera)."""
    touched = np.zeros(len(X), bool)
    for c in cols:
        m = np.all((X > c.lo) & (X < c.hi), axis=1)
        if inv is not None:
            m &= inv > 0
        for i in np.nonzero(m)[0]:
            hit = c.bvh.find_nearest(Vector(X[i]), .3)
            if hit[0] is None:
                continue
            loc, nrm = np.array(hit[0]), np.array(hit[1])
            dd = (X[i] - loc) @ nrm
            if dd < thick:
                X[i] = loc + nrm * thick
            if dd < thick * 1.6:
                touched[i] = True
    return (X, touched) if report else X


def drape_analytic(flat, ring, cols, thick=.03, ds=.012, flare=.10, ground=.03):
    """Caída de la tela por rayos (obra propia, determinista): desde la boca, cada columna de la grilla avanza por su
    rayo del paño plano; mientras haya apoyo debajo, se desliza sobre él (hombros, brazos, muslos, lomo); al pasar un
    borde cuelga a plomo (con un leve vuelo hacia afuera) hasta que encuentra otro apoyo o se le acaba el largo. El largo
    recorrido es el del paño plano, así que nada se estira."""
    nr, n = flat.shape[:2]

    def support(x, y):
        best = ground
        o = Vector((x, y, 3.2))
        for c in cols:
            if not (c.lo[0] < x < c.hi[0] and c.lo[1] < y < c.hi[1]):
                continue
            loc = c.bvh.ray_cast(o, Vector((0, 0, -1)), 4.0)[0]
            if loc is not None and loc.z > best:
                best = loc.z
        return best
    X = np.zeros((nr, n, 3))
    X[0] = ring
    for j in range(n):
        e, b = flat[0, j], flat[-1, j]
        d2 = (b - e) / np.linalg.norm(b - e)
        total = np.linalg.norm(b - e)
        targets = [np.linalg.norm(flat[k, j] - e) for k in range(nr)]
        p = ring[j].copy()
        s, k = 0.0, 1
        while k < nr:
            zs = support(p[0], p[1]) + thick
            if p[2] - ds > zs:                       # cuelga
                p[2] -= ds
                p[:2] += d2 * ds * flare
            else:                                    # se desliza sobre el apoyo
                q = p[:2] + d2 * ds
                zq = support(q[0], q[1]) + thick
                if zq > p[2] + ds:                   # pared: sube apenas (la tela se apoya y la sigue)
                    p[2] += ds * .7
                    p[:2] += d2 * ds * .3
                else:
                    p[:2] = q
                    p[2] = max(zq, p[2] - ds * .5)
            s += ds
            while k < nr and s >= targets[k]:
                X[k, j] = p
                k += 1
    return X.reshape(-1, 3), nr, n


def smooth_grid(X, nr, n, it=2, keep_first=True):
    G = X.reshape(nr, n, 3)
    for _ in range(it):
        S = G.copy()
        S[1:-1] = (G[:-2] + G[2:] + np.roll(G, 1, 1)[1:-1] + np.roll(G, -1, 1)[1:-1] + 4 * G[1:-1]) / 8
        S[-1] = (np.roll(G, 1, 1)[-1] + np.roll(G, -1, 1)[-1] + 2 * G[-1] + G[-2] * 0) / 4
        if keep_first:
            S[0] = G[0]
        G = S
    return G.reshape(-1, 3)


def bvh_of_parts(parts, extra=None):
    V, F = merge(*[(p.v, p.f) for p in parts]) if parts else (np.zeros((0, 3)), [])
    if extra is not None:
        V, F = merge((V, F), extra)
    return BVHTree.FromPolygons([tuple(x) for x in V], [list(x) for x in F])


def poncho_part(X, nr, n, flat, W, L, base, border, stripe=None, role="poncho", name="poncho", weights=None, hi=True):
    faces = [(i * n + j, i * n + (j + 1) % n, (i + 1) * n + (j + 1) % n, (i + 1) * n + j) for i in range(nr - 1) for j in range(n)]
    fl = flat.reshape(-1, 2)
    dx = W / 2 - np.abs(fl[:, 0])
    dy = L / 2 - np.abs(fl[:, 1])
    edge = np.minimum(dx, dy)
    col = np.tile(base, (len(X), 1))
    ring = np.repeat(np.arange(nr), n)
    if border is not None:
        col = np.where((ring >= nr - 2)[:, None], border, col)
    if stripe is not None and hi:      # una lista angosta de acento, un anillo adentro de la guarda (≤ 15 % de la figura)
        col = np.where((ring == nr - 3)[:, None], col * .55 + stripe * .45, col)
    return Part(name, X, faces, role, col, weights=weights, noise=.04)


def collar(center, q, col, role, r=(.085, .075), h=.05, z=None):
    v, f = loft([center + V3(0, 0, -h / 2), center + V3(0, 0, h / 2)], [r[0], r[0] * .9], [r[1], r[1] * .9], sides=q.limb + 2)
    return Part("cuello_poncho", v, f, role, col, chain=["pecho", "cuello"])


# --------------------------------------------------------------------------------------
# Armado de la malla Blender: materiales por rol, color con oclusión, pesos
# --------------------------------------------------------------------------------------
_MATS = {}


def vc_material(name, rough=0.85, metal=0.0):
    if name in _MATS and _MATS[name].name in bpy.data.materials:
        return _MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes.get("Principled BSDF")
    ca = nt.nodes.new("ShaderNodeVertexColor")
    ca.layer_name = "Col"
    nt.links.new(ca.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    _MATS[name] = m
    return m


def reset():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.armatures, bpy.data.actions, bpy.data.materials, bpy.data.images):
        for b in list(coll):
            coll.remove(b)
    _MATS.clear()
    bpy.context.scene.render.fps = FPS


def vnoise(p, seed=1.0):
    return (np.sin(p[:, 0] * 37.1 + seed) * np.sin(p[:, 1] * 29.3 - seed * 1.7) * np.sin(p[:, 2] * 41.7 + seed * .3))


def anchor_part(bone=None):
    v, f = ellipsoid((0, 0, .002), (.001, .001, .001), 4, 3)
    return Part("ancla", v, f, "ancla", np.full(3, .5), bone=bone, noise=0)


def build_mesh(name, parts, prefix, B=None, occluders=None, ao_strength=.55, ao_rays=20):
    """Une las piezas en una malla: superficie por rol (ancla primero), COLOR_0 = color x (1 - k (1 - oclusión)), pesos."""
    V, F, C, R, SM, PI = [], [], [], [], [], []
    off = 0
    roles = []
    for p in parts:
        if p.role not in roles:
            roles.append(p.role)
    for pi, p in enumerate(parts):
        V.append(p.v)
        F += [tuple(i + off for i in f) for f in p.f]
        c = p.c * (1 + p.noise * vnoise(p.v, pi * .37))[:, None]
        C.append(c)
        R += [roles.index(p.role)] * len(p.f)
        SM += [p.smooth] * len(p.f)
        PI.append(np.full(len(p.v), pi))
        off += len(p.v)
    V, C, PI = np.vstack(V), np.vstack(C), np.concatenate(PI)
    if DEBUG:
        tc = {}
        for p in parts:
            tc[p.name] = tc.get(p.name, 0) + sum(len(x) - 2 for x in p.f)
        print("TRIS", name, sorted(tc.items(), key=lambda kv: -kv[1]))
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(x) for x in V], [], F)
    me.update()
    for r in roles:
        cls = "ancla" if r == "ancla" else ROLE_CLASS[r]
        nm = f"{prefix} | ancla" if r == "ancla" else f"{prefix} | {r} | {cls}"
        rough = .45 if cls in ("metal", "gloss") else (.7 if cls == "leather" else .88)
        me.materials.append(vc_material(nm, rough, .6 if cls == "metal" else 0.0))
    me.polygons.foreach_set("material_index", R)
    me.polygons.foreach_set("use_smooth", SM)
    me.update()
    # oclusión ambiental propia (rayos al hemisferio de la normal contra todas las piezas y los oclusores extra)
    nrm = np.empty(len(V) * 3)
    me.vertices.foreach_get("normal", nrm)
    nrm = nrm.reshape(-1, 3)
    occ = [(V, F)] + (occluders or [])
    Vo, Fo = merge(*occ)
    bvh = BVHTree.FromPolygons([tuple(x) for x in Vo], [list(x) for x in Fo])
    rng = np.random.default_rng(11)
    D = rng.normal(size=(ao_rays, 3))
    D /= np.linalg.norm(D, axis=1)[:, None]
    ao = np.ones(len(V))
    for i in range(len(V)):
        n = nrm[i]
        o = Vector(V[i] + n * .004)
        hits, tot = 0.0, 0.0
        for d in D:
            dd = d if d @ n > 0 else -d
            w = dd @ n
            tot += w
            if bvh.ray_cast(o, Vector(dd), .30)[0] is not None:
                hits += w
        ao[i] = 1 - hits / max(tot, 1e-6)
    k = np.array([parts[i].ao for i in PI]) * ao_strength
    C = C * (1 - k * (1 - ao))[:, None]
    C = np.clip(C, 0, 1)
    a = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    me.color_attributes.active_color = a
    vi = np.empty(len(me.loops), np.int32)
    me.loops.foreach_get("vertex_index", vi)
    rgba = np.ones((len(me.loops), 4), np.float32)
    rgba[:, :3] = C[vi]
    a.data.foreach_set("color", rgba.ravel())
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    if B is not None:
        groups = {b: o.vertex_groups.new(name=b) for b in BONES if b != "raiz"}
        for pi, p in enumerate(parts):
            ids = np.nonzero(PI == pi)[0]
            if p.weights is not None:
                W = p.weights
            elif p.chain is not None:
                W = chain_weights(p.v, p.chain, B)
            else:
                W = {p.bone or "cadera": np.ones(len(p.v))}
            for b, w in W.items():
                for vid, ww in zip(ids, w):
                    if ww > 1e-3:
                        groups[b].add([int(vid)], float(ww), "ADD")
    return o


def tri_count(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


# --------------------------------------------------------------------------------------
# Esqueleto y ciclos (claves propias por fórmula)
# --------------------------------------------------------------------------------------
def build_armature(B):
    data = bpy.data.armatures.new("esqueleto_persona")
    rig = bpy.data.objects.new("esqueleto_persona", data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for nm in BONES:
        h, t = B[nm]
        eb = data.edit_bones.new(nm)
        eb.head, eb.tail = Vector(h), Vector(t)
        eb.use_deform = nm != "raiz"
        d = (eb.tail - eb.head).normalized()
        if d.z < -.6:
            eb.align_roll(Vector((0, 1, 0)))     # hacia abajo: X local = +X del mundo, Z local adelante
        elif d.z > .6:
            eb.align_roll(Vector((0, -1, 0)))    # hacia arriba: X local = +X
        else:
            eb.align_roll(Vector((0, 0, 1)))
    for nm in BONES:
        if nm in PARENT:
            data.edit_bones[nm].parent = data.edit_bones[PARENT[nm]]
            data.edit_bones[nm].use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in rig.pose.bones:
        pb.rotation_mode = "XYZ"
    return rig


def key(rig, bone, frame, rot=None, loc=None):
    pb = rig.pose.bones[bone]
    if rot is not None:
        pb.rotation_euler = rot
        pb.keyframe_insert("rotation_euler", frame=frame, group=bone)
    if loc is not None:
        pb.location = loc
        pb.keyframe_insert("location", frame=frame, group=bone)


def new_action(rig, name):
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    rig.animation_data.action = act
    return act


def finish_action(act, last, bezier):
    for fc in act.fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = "BEZIER" if bezier else "LINEAR"
    act.frame_range = (0, last)
    act.use_frame_range = True


def leg_ik(dy, dz, L1, L2):
    """Ángulos (muslo, rodilla) en el plano sagital para llevar el tobillo a (dy, dz) desde la cadera (dz < 0).
    Rotación positiva en X = hacia adelante; la rodilla flexiona con ángulo negativo."""
    D = math.hypot(dy, dz)
    D = min(D, L1 + L2 - 1e-4)
    k = math.acos(max(-1, min(1, (L1 * L1 + L2 * L2 - D * D) / (2 * L1 * L2))))
    al = math.acos(max(-1, min(1, (L1 * L1 + D * D - L2 * L2) / (2 * L1 * D))))
    phi = math.atan2(dy, -dz)
    return phi + al, -(math.pi - k)


GAITS = {
    # cuadros, velocidad de diseño (m/s), apoyo, alzada del pie, sube-baja, baja media, inclinación del tronco, braceo, codo
    "walk": dict(n=24, v=1.15, duty=.60, lift=.11, bob=.022, drop=.028, lean=-.03, arm=.32, elbow=.12, center=-.065, kick=.0),
    "run":  dict(n=16, v=3.2, duty=.36, lift=.20, bob=.035, drop=.07, lean=-.20, arm=.62, elbow=.95, center=-.08, kick=.22),
}
ANIM_REPORT = {}
CROUCH_DROP = .40   # visual/r1 F6: cuánto baja la cadera al agacharse (m)


def animate(rig, J, carry):
    """carry: {'L'|'R': factor de braceo} para el brazo que lleva el arma (0 = quieto)."""
    rig.animation_data_create()
    hipz = J["hip_L"][2]
    L1 = float(np.linalg.norm(J["hip_L"] - J["knee_L"]))
    L2 = float(np.linalg.norm(J["knee_L"] - J["ankle_L"]))
    a_z = J["ankle_L"][2]
    ball = .12
    for name, G in GAITS.items():
        act = new_action(rig, name)
        n, v, duty = G["n"], G["v"], G["duty"]
        T = n / FPS
        sweep = v * duty * T
        worst = {"ankle_err_m": 0.0}
        for f in range(n + 1):
            g = (f % n) / n
            w = 2 * math.pi * g
            # sube-baja: dos por ciclo; más bajo en el doble apoyo (paso) o en el aterrizaje (carrera)
            # paso: lo más bajo en el doble apoyo (fase 0 y 0,5); carrera: lo más bajo a mitad del apoyo
            bob = -G["drop"] + G["bob"] * (-math.cos(2 * w) if name == "walk" else math.cos(2 * w - 2 * math.pi * duty))
            key(rig, "cadera", f, loc=(0, bob, 0), rot=(0, .05 * math.sin(w) * (1 if name == "walk" else 1.4), 0))
            for s, off in (("L", 0.0), ("R", .5)):
                ph = (g + off) % 1.0
                if ph < duty:    # apoyo: el pie retrocede pegado al suelo; al final despega el talón
                    t = ph / duty
                    y = G["center"] + sweep * (.5 - t)
                    roll = -.75 * smoothstep(.62, 1.0, t) if name == "walk" else -.55 * smoothstep(.4, 1.0, t)
                    heel = -.12 * (1 - smoothstep(0, .18, t)) * (name == "walk")   # punta arriba al pisar
                    z = a_z + ball * math.sin(-roll) + .02 * math.sin(-heel)
                    y = y + ball * (1 - math.cos(roll)) if roll < 0 else y
                    pitch = roll + heel
                else:            # vuelo: vuelve adelante alzándose
                    t = (ph - duty) / (1 - duty)
                    e = smoothstep(0, 1, t)
                    y = G["center"] + sweep * (-.5 + e)
                    z = a_z + G["lift"] * math.sin(math.pi * t) + G["kick"] * math.sin(math.pi * min(1, t * 1.6)) * (t < .62)
                    y -= G["kick"] * .9 * math.sin(math.pi * min(1, t * 1.6)) * (t < .62)
                    pitch = -.55 * (1 - smoothstep(0, .4, t)) + .18 * smoothstep(.6, 1, t)
                dz = z - (hipz + bob)
                a1, a2 = leg_ik(y, dz, L1, L2)
                ky = L1 * math.sin(a1) + L2 * math.sin(a1 + a2)
                kz = -L1 * math.cos(a1) - L2 * math.cos(a1 + a2)
                worst["ankle_err_m"] = max(worst["ankle_err_m"], math.hypot(ky - y, kz - dz) if ph < duty else 0)
                key(rig, "muslo_" + s, f, rot=(a1, 0, 0))
                key(rig, "pierna_" + s, f, rot=(a2, 0, 0))
                key(rig, "pie_" + s, f, rot=(-(a1 + a2) + pitch, 0, 0))
                # braceo opuesto a la pierna del mismo lado
                k = carry.get(s, 1.0)
                swing = G["arm"] * k * math.cos(2 * math.pi * (ph - duty))   # mano adelante cuando su pie despega atrás
                key(rig, "brazo_" + s, f, rot=(swing, 0, (.04 if s == "R" else -.04) * (name == "run")))
                key(rig, "antebrazo_" + s, f, rot=(G["elbow"] * (k > .3) + .25 * max(0, swing), 0, 0))
                key(rig, "mano_" + s, f, rot=(0, 0, 0))
            key(rig, "columna", f, rot=(G["lean"] * .5, -.06 * math.sin(w), 0))
            key(rig, "pecho", f, rot=(G["lean"] * .5, -.10 * math.sin(w), 0))
            key(rig, "cuello", f, rot=(-G["lean"] * .4, .08 * math.sin(w), 0))
            key(rig, "cabeza", f, rot=(-G["lean"] * .4, .05 * math.sin(w), 0))
        finish_action(act, n, False)
        ANIM_REPORT[name] = {"frames": n, "seconds": round(n / FPS, 3), "design_mps": v, "stride_m": round(v * T, 3),
                             **{k2: round(x, 4) for k2, x in worst.items()}}
    # idle: respira, mira alrededor, cambia apenas el peso (los pies no se mueven)
    n = 96
    act = new_action(rig, "idle")
    for f in range(0, n + 1, 4):
        w = 2 * math.pi * f / n
        key(rig, "cadera", f, loc=(0, .004 * math.sin(2 * w), 0), rot=(0, .025 * math.sin(w), 0))
        key(rig, "columna", f, rot=(.012 * math.sin(4 * w), .03 * math.sin(w + .4), -.015 * math.sin(w)))
        key(rig, "pecho", f, rot=(.018 * math.sin(4 * w), .03 * math.sin(w + .6), 0))
        key(rig, "cuello", f, rot=(.02 * math.sin(2 * w), .12 * math.sin(w + 1.0), 0))
        key(rig, "cabeza", f, rot=(.03 * math.sin(2 * w + .5), .18 * math.sin(w + 1.3) * (.5 + .5 * math.sin(w)), 0))
        for s in "LR":
            k = carry.get(s, 1.0)
            key(rig, "brazo_" + s, f, rot=(.03 * math.sin(4 * w + (s == "R")) * k, 0, 0))
            key(rig, "antebrazo_" + s, f, rot=(.03 * math.sin(4 * w + .5) * k, 0, 0))
            key(rig, "mano_" + s, f, rot=(0, 0, 0))
            for b in ("muslo_", "pierna_", "pie_"):
                key(rig, b + s, f, rot=(0, 0, 0))
    finish_action(act, n, True)
    ANIM_REPORT["idle"] = {"frames": n, "seconds": n / FPS, "design_mps": 0.0}
    # visual/r1 F6 (BACKLOG B-049): agachado en el lugar (el reconocedor que mira de cerca). La cadera baja CROUCH_DROP m, los pies quedan apoyados donde
    # estaban (cinemática inversa de dos huesos, el izquierdo un poco adelante), el tronco se inclina y la cabeza mira al frente; respira apenas. Diseño, no captura.
    n = 48
    act = new_action(rig, "crouch")
    worst = 0.0
    for f in range(0, n + 1, 8):
        w = 2 * math.pi * f / n
        b = .006 * math.sin(w)
        key(rig, "cadera", f, loc=(0, -CROUCH_DROP + b, 0), rot=(0, 0, 0))
        for s, dy in (("L", .16), ("R", -.05)):
            dz = a_z - (hipz - CROUCH_DROP + b)
            a1, a2 = leg_ik(dy, dz, L1, L2)
            ky = L1 * math.sin(a1) + L2 * math.sin(a1 + a2)
            kz = -L1 * math.cos(a1) - L2 * math.cos(a1 + a2)
            worst = max(worst, math.hypot(ky - dy, kz - dz))
            key(rig, "muslo_" + s, f, rot=(a1, 0, 0))
            key(rig, "pierna_" + s, f, rot=(a2, 0, 0))
            key(rig, "pie_" + s, f, rot=(-(a1 + a2), 0, 0))
            k = carry.get(s, 1.0)
            key(rig, "brazo_" + s, f, rot=(.30 * k, 0, 0))
            key(rig, "antebrazo_" + s, f, rot=(.45 * k, 0, 0))
            key(rig, "mano_" + s, f, rot=(0, 0, 0))
        key(rig, "columna", f, rot=(-.30 + .01 * math.sin(w), 0, 0))
        key(rig, "pecho", f, rot=(-.20, .02 * math.sin(w), 0))
        key(rig, "cuello", f, rot=(.26, 0, 0))
        key(rig, "cabeza", f, rot=(.18, .10 * math.sin(.5 * w), 0))
    finish_action(act, n, True)
    ANIM_REPORT["crouch"] = {"frames": n, "seconds": n / FPS, "design_mps": 0.0, "hip_drop_m": CROUCH_DROP, "ankle_err_m": round(worst, 4)}
    rig.animation_data.action = bpy.data.actions["idle"]


# --------------------------------------------------------------------------------------
# Exportación (igual que f4_caballos.export)
# --------------------------------------------------------------------------------------
def export(name, note, kind, anims=(), extra=None):
    target = OUT / (name + ".glb")
    kw = dict(filepath=str(target), export_format="GLB", export_yup=True, export_apply=False,
              export_animations=bool(anims), export_force_sampling=True, export_materials="EXPORT",
              export_cameras=False, export_lights=False, export_def_bones=False, export_tangents=False,
              export_skins=True, export_texcoords=False, use_selection=False)
    props = bpy.ops.export_scene.gltf.get_rna_type().properties
    if "export_animation_mode" in props:
        kw["export_animation_mode"] = "ACTIONS"
    if "export_vertex_color" in props:
        kw["export_vertex_color"] = "ACTIVE"
    if "export_nla_strips" in props:
        kw["export_nla_strips"] = False
    if "export_optimize_animation_size" in props:
        kw["export_optimize_animation_size"] = False
    bpy.ops.export_scene.gltf(**kw)
    data = target.read_bytes()
    js, _ = struct.unpack_from("<I4s", data, 12)
    g = json.loads(data[20:20 + js])
    pts, tris = [], 0
    for ob in bpy.context.scene.objects:
        if ob.type == "MESH":
            pts += [ob.matrix_world @ Vector(c) for c in ob.bound_box]
            tris += tri_count(ob)
    mn = [min(p[i] for p in pts) for i in range(3)]
    mx = [max(p[i] for p in pts) for i in range(3)]
    acc = g.get("accessors", [])
    anim_info = {}
    for a in g.get("animations", []):
        t = [acc[s["input"]]["max"][0] for s in a["samplers"] if "max" in acc[s["input"]]]
        anim_info[a.get("name", "")] = round(max(t), 3) if t else None
    REPORT[name] = {
        "file": target.name, "bytes": target.stat().st_size, "triangles": tris,
        "animations": anim_info, "meshes": len(g.get("meshes", [])),
        "surfaces": sum(len(m["primitives"]) for m in g.get("meshes", [])),
        "materials": [m.get("name", "") for m in g.get("materials", [])],
        "textures": len(g.get("textures", [])),
        "bones": [n["name"] for s in g.get("skins", []) for n in [g["nodes"][j] for j in s["joints"]]],
        "vertex_colors": all("COLOR_0" in p["attributes"] for m in g.get("meshes", []) for p in m["primitives"]),
        "godot_bounds": {"min": [round(mn[0], 3), round(mn[2], 3), round(-mx[1], 3)], "max": [round(mx[0], 3), round(mx[2], 3), round(-mn[1], 3)]},
        "front": "Godot -Z", "origin": {"jinete": "asiento (hueso silla del caballo)", "persona": "suelo, entre los pies",
                                        "arma": "punto de agarre de la mano"}[kind],
        "sha256": hashlib.sha256(data).hexdigest(), "note": note,
    }
    if extra:
        REPORT[name].update(extra)
    print("ASSET_READY " + json.dumps({k: REPORT[name][k] for k in ("file", "triangles", "surfaces", "animations")}, ensure_ascii=False))


def godot(p):
    p = np.asarray(p, float)
    return [round(float(p[0]), 3), round(float(p[2]), 3), round(float(-p[1]), 3)]


# --------------------------------------------------------------------------------------
# Armas (propias). Todas se arman sobre el punto de agarre `grip` y el eje `ax` (de la culata o regatón a la punta).
# --------------------------------------------------------------------------------------
def _ax(ax):
    ax = np.asarray(ax, float)
    return ax / np.linalg.norm(ax)


def tacuara(grip, ax, q, bone=None, below=1.05, above=2.25):
    """Tacuara: caña con nudos y una hoja de cuchillo atada con tientos de cuero crudo (lanza de montonera; diseño)."""
    ax = _ax(ax)
    g = np.asarray(grip, float)
    a, b = g - ax * below, g + ax * above
    out = []
    v, f = loft([a, (a + b) / 2, b], [.017, .016, .014], sides=q.small, hint=(1, 0, 0))
    out.append(Part("tacuara", v, f, "cana", P["cana"], bone=bone, noise=.08))
    if q.hi:
        for t in np.arange(.35, below + above - .2, .42):
            p = a + ax * t
            v, f = loft([p - ax * .012, p + ax * .012], .02, sides=q.small, hint=(1, 0, 0))
            out.append(Part("nudo", v, f, "cana", P["cana"] * .75, bone=bone, noise=0))
    v, f = loft([b - ax * .02, b + ax * .09], [.02, .019], sides=q.small, hint=(1, 0, 0))
    out.append(Part("atadura", v, f, "cuero", P["potro"], bone=bone, noise=0))
    R = rot_between((0, 0, 1), ax)
    v, f = ellipsoid((0, 0, 0), (.022, .005, .15), q.small + 1, 5)
    v[:, 0] *= np.clip(1.2 - (v[:, 2] / .15) ** 2, .05, 1)    # hoja en punta
    out.append(Part("hoja", v @ R.T + b + ax * .17, f, "metal", P["hierro"] * 1.4, bone=bone, noise=0))
    return out


def carabina(grip, ax, q, bone=None, length=.98):
    """Carabina (tercerola) de chispa: caja de nogal, cañón, llave y abrazaderas de latón. grip = garganta de la caja."""
    ax = _ax(ax)
    g = np.asarray(grip, float)
    side = np.cross(ax, (0, 0, 1.0))
    side = side / np.linalg.norm(side) if np.linalg.norm(side) > 1e-3 else np.array((1.0, 0, 0))
    up = np.cross(side, ax)
    out = []
    butt = g - ax * .30
    v, f = loft([butt, butt + ax * .1, g, g + ax * .08, g + ax * (length - .32)], [.03, .028, .018, .022, .016],
                [.055, .045, .022, .026, .018], sides=q.small, hint=up)
    out.append(Part("caja", v, f, "madera", P["madera"], bone=bone))
    v, f = loft([g + ax * .02 + up * .012, g + ax * (length - .30) + up * .012], .011, sides=q.small, hint=side)
    out.append(Part("canon", v, f, "metal", P["hierro"], bone=bone, noise=0))
    v, f = cube(g + ax * .06 + side * .02 + up * .01, (.012, .02, .06), rot=rot_between((0, 0, 1), ax))
    out.append(Part("llave", v, f, "metal", P["hierro"] * 1.2, smooth=False, bone=bone, noise=0))
    if q.hi:
        for t in (.3, .5):
            v, f = loft([g + ax * t - ax * .01, g + ax * t + ax * .01], .022, sides=q.small, hint=side)
            out.append(Part("abrazadera", v, f, "laton", P["laton"], bone=bone, noise=0))
    return out


def fusil(grip, ax, q, bone=None, bayonet=True):
    """Fusil de chispa con bayoneta de cubo. grip = talón de la culata (la mano por debajo, «arma al hombro»)."""
    ax = _ax(ax)
    g = np.asarray(grip, float)
    side = np.cross(ax, (0, 1.0, 0))
    side = side / np.linalg.norm(side) if np.linalg.norm(side) > 1e-3 else np.array((1.0, 0, 0))
    up = np.cross(side, ax)
    out = []
    v, f = loft([g, g + ax * .14, g + ax * .30, g + ax * .40, g + ax * 1.2], [.025, .024, .016, .02, .015],
                [.06, .05, .022, .025, .018], sides=q.small, hint=side)
    out.append(Part("caja", v, f, "madera", P["madera"] * 1.1, bone=bone))
    v, f = loft([g + ax * .34 - up * .01, g + ax * 1.46 - up * .01], .011, sides=q.small, hint=side)
    out.append(Part("canon", v, f, "metal", P["hierro"], bone=bone, noise=0))
    if bayonet:
        tip = g + ax * 1.46 - up * .01
        v, f = loft([tip - ax * .05 + up * .02, tip + ax * .02 + up * .03, tip + ax * .40 + up * .03], [.012, .008, .002], sides=4, hint=side)
        out.append(Part("bayoneta", v, f, "metal", P["hierro"] * 1.5, bone=bone, noise=0))
    if q.hi:
        v, f = cube(g + ax * .36 + side * .02, (.012, .02, .07), rot=rot_between((0, 0, 1), ax))
        out.append(Part("llave", v, f, "metal", P["hierro"] * 1.2, smooth=False, bone=bone, noise=0))
        for t in (.6, .9, 1.2):
            v, f = loft([g + ax * t - ax * .008, g + ax * t + ax * .008], .021, sides=q.small, hint=side)
            out.append(Part("abrazadera", v, f, "metal", P["hierro"] * 1.3, bone=bone, noise=0))
    return out


def rebenque(hand, q, bone=None):
    h = np.asarray(hand, float)
    v, f = loft([h + V3(0, -.02, .06), h + V3(.01, .1, -.16)], [.016, .013], sides=q.small)
    out = [Part("rebenque", v, f, "cuero", P["cuero"], bone=bone, noise=0)]
    v, f = loft([h + V3(.01, .1, -.16), h + V3(.02, .13, -.3), h + V3(.02, .12, -.45)], [.022, .02, .01], [.006, .006, .005],
                sides=4, hint=(1, 0, 0))
    out.append(Part("lonja", v, f, "cuero", P["cuero_claro"], bone=bone, noise=0))
    return out


def sable(J, q, bone="cadera", side=-1):
    """Sable en su vaina, colgado del lado izquierdo (diseño)."""
    w = J["waist"]
    a = w + V3(side * .19, .04, -.07)
    out = []
    v, f = loft([a, a + V3(side * .05, -.12, -.3), a + V3(side * .07, -.25, -.62)], [.022, .02, .016], [.01, .009, .008],
                sides=q.small, hint=(1, 0, 0))
    out.append(Part("vaina", v, f, "cuero", P["negro"], chain=[bone], noise=0))
    v, f = loft([a + V3(0, .02, .01), a + V3(side * -.02, .07, .13)], .014, sides=q.small)
    out.append(Part("empunadura", v, f, "cuero", P["cuero"], chain=[bone], noise=0))
    v, f = loft([a + V3(0, .0, .02), a + V3(side * -.03, .09, .05), a + V3(side * -.025, .08, .15)], .007, sides=4, caps=False)
    out.append(Part("guarnicion", v, f, "laton", P["laton"], chain=[bone], noise=0))
    return out


# --------------------------------------------------------------------------------------
# Figuras
# --------------------------------------------------------------------------------------
def arm_pose(shoulder, elbow, hand, wrist_back=.065):
    d = (np.asarray(hand) - np.asarray(elbow))
    d /= np.linalg.norm(d)
    return (elbow, tuple(np.asarray(hand) - d * wrist_back), hand)


def sash_ring(c, rx, ry, z_low, z_high, x_shoulder, n=16, mirror=False):
    """Lazo diagonal alrededor del torso, del hombro izquierdo (alto) a la cadera derecha (bajo); mirror invierte."""
    pts = []
    for k in range(n):
        t = 2 * math.pi * k / n
        cx = math.cos(t)
        x = rx * cx if cx > 0 else x_shoulder * cx
        y = ry * math.sin(t)
        z = (z_low + z_high) / 2 - (z_high - z_low) / 2 * cx
        pts.append(c + V3(-x if mirror else x, y, z))
    return np.array(pts)


PONCHO_CACHE = {}
NO_SUPPORT = ("cuello", "panuelo", "nudo", "mano", "pulgar", "tacuara", "caja", "canon", "facon_vaina", "facon_cabo")


def poncho_on(parts, J, q, W, L, base, border, stripe, extra_colliders=(), horse=None, B=None, cache_key=None):
    """Cuelga un poncho de W x L sobre las piezas (y el caballo). El de tropa no se simula aparte: es el del jefe
    remuestreado (uno de cada tres puntos del ruedo y menos anillos) y vuelto a apoyar sobre el cuerpo de tropa."""
    col_parts = [p for p in parts if p.bone != "cabeza" and p.name not in ("ancla",) and len(p.v) > 8] + list(extra_colliders)
    cols = [Collider(p.v, p.f) for p in col_parts]
    if DEBUG:
        for p, c in zip(col_parts, cols):
            bad = 0
            ctr = p.v.mean(0)
            for d in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)):
                q0 = ctr + np.array(d) * (np.abs(p.v - ctr).max() + .05)
                hit = c.bvh.find_nearest(Vector(q0), 2)
                if hit[0] is not None and (q0 - np.array(hit[0])) @ np.array(hit[1]) < 0:
                    bad += 1
            if bad:
                print("NORMALES_AL_REVES", p.name, bad)
    # canesú invisible: un elipsoide liso de hombro a hombro donde se apoya el poncho (con la grilla de 5-6 cm la tela
    # se colaba entre las bolitas de los hombros)
    shc = (J["shoulder_L"] + J["shoulder_R"]) / 2
    yv, yf = ellipsoid(shc + V3(0, 0, -.035), (np.linalg.norm(J["shoulder_L"] - J["shoulder_R"]) / 2 + .085, .145, .10), 16, 10)
    cols.append(Collider(yv, yf))
    if horse is not None:
        # regazo invisible: la envolvente convexa de muslos, chiripá y tirador, para que el poncho cruce de un muslo al
        # otro (sin esto la punta de adelante cae entre las piernas y deja los muslos al aire)
        lap = [p for p in parts if p.name in ("chiripa_pierna", "chiripa", "cinto", "calzon_pierna", "calzon")]
        if lap:
            bm = bmesh.new()
            for p in lap:
                for x in p.v:
                    bm.verts.new(x)
            bmesh.ops.convex_hull(bm, input=bm.verts)
            for vv in [vv for vv in bm.verts if not vv.link_faces]:
                bm.verts.remove(vv)
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            lv, lf = _bm_to_vf(bm)
            cols.append(Collider(lv, lf))
    if horse is not None:
        cols += [Collider(v, f) for v, f in components(horse[0], horse[1])]
    if q.hi or cache_key not in PONCHO_CACHE:
        nk = J["neck"]
        flat = poncho_layout(W, L, 15, 84, .085, .078)
        n = flat.shape[1]
        ang = np.arctan2(flat[0, :, 1], flat[0, :, 0])
        ring = np.stack([nk[0] + .088 * np.cos(ang), nk[1] + .082 * np.sin(ang), np.full(n, nk[2] - .015)], 1)
        pre = None
        if horse is not None and "--pre" in ARGV:
            def pre(X0):
                """Jinete: la lámina arranca ya apoyada (rayos desde arriba sobre el cuerpo y el caballo, con el ancho
                encogido un 15 %); si cae libre desde los hombros se escurre por los flancos y deja los muslos al aire."""
                X1 = X0.copy()
                X1[:, :2] = nk[:2] + (X0[:, :2] - nk[:2]) * .85
                for i in range(len(X1)):
                    best = None
                    for c in cols:
                        hit = c.bvh.ray_cast(Vector((X1[i, 0], X1[i, 1], 2.6)), Vector((0, 0, -1)), 3.0)
                        if hit[0] is not None and (best is None or hit[0].z > best):
                            best = hit[0].z
                    X1[i, 2] = (best if best is not None else 1.2) + .03
                return X1
        # a pie: simulación por posiciones (pliegues naturales sobre brazos colgando); jinete: caída por rayos (la
        # simulación se escurría entre los muslos y los brazos adelantados y armaba una bolsa)
        if horse is None:
            X, nr, n = drape_poncho(flat, J["shoulder_L"][2] + .07, nk, cols, ring, steps=260, friction=.12, pre=pre)
        else:
            sup = [c for c, p in zip(cols, col_parts + [None] * len(cols)) if p is None or p.name not in NO_SUPPORT]
            X, nr, n = drape_analytic(flat, ring, sup)
        X = smooth_grid(X, nr, n, it=3)
        X = collide(X, cols, .022 if horse is not None else .012)
        PONCHO_CACHE[cache_key] = (X, nr, n, flat)
    X, nr, n, flat = PONCHO_CACHE[cache_key]
    if not q.hi:
        G = X.reshape(nr, n, 3)
        rings = [0, 4, 9, 13, 14]
        colsel = list(range(0, n, 4))
        G = G[rings][:, colsel]
        flat = flat[rings][:, colsel]
        nr, n = G.shape[:2]
        X = collide(G.reshape(-1, 3).copy(), cols, .02)
    w = None
    if B is not None:
        w = chain_weights(X, ["pecho", "columna", "cadera", "brazo_L", "brazo_R", "muslo_L", "muslo_R"], B, power=4, keep=3)
    pp = poncho_part(X, nr, n, flat, W, L, base, border, stripe, weights=w, hi=q.hi)
    return pp


def figure_gaucho(q, weapon="tacuara", B_only=False):
    """Paisano de las milicias gauchas de Salta y Jujuy, 1817, a pie (DISEÑO sobre las fuentes del juego: poncho, chiripá,
    calzoncillo cribado, botas de potro, sombrero; tacuara o carabina). Sin divisas ni uniforme."""
    if weapon == "tacuara":
        rh = (.30, .15, .98)
        arms = {"R": arm_pose(None, (.26, -.03, 1.17), rh), "L": arm_pose(None, (-.235, -.04, 1.16), (-.255, .07, .87))}
        wax = (.10, .07, 1.0)
    else:
        rh = (.29, .14, 1.0)
        arms = {"R": arm_pose(None, (.26, -.04, 1.18), rh), "L": arm_pose(None, (-.235, -.04, 1.16), (-.255, .07, .87))}
        wax = (.20, .16, 1.0)
    J = standing_joints(arms)
    B = bones_from_joints(J)
    parts = [anchor_part("cadera")]
    parts += head_parts(J, q, beard=True, hair_long=True)
    parts += hat_gaucho(J, q)
    parts.append(torso_loft(J, q, P["lino"], "camisa"))
    for s in "LR":
        parts += arm_parts(J, s, q, P["lino"], "camisa", sleeve_r=(.066, .058, .048))
    parts += chiripa(J, q, P["chiripa"])
    parts.append(belt(J, q, P["cuero"], "tirador", h=.085, r=(.182, .138)))
    for s in "LR":
        parts.append(leg_tube(J, s, q, .74, 1.42, .088, .098, P["lino_blanco"], "calzoncillo", name="calzoncillo",
                              flare_hem=.12 if q.hi else None))
        parts += foot_boot_potro(J, s, q)
    if q.hi:
        parts += facon(J, q)
    below = (rh[2] - .06) / (np.asarray(wax) / np.linalg.norm(wax))[2]     # el regatón queda 6 cm sobre el suelo
    wpn = tacuara(rh, wax, q, bone="mano_R", below=below) if weapon == "tacuara" else carabina(rh, wax, q, bone="mano_R")
    parts += wpn
    pp = poncho_on(parts, J, q, 1.12, 1.52, P["lana_parda"], P["lana_parda_osc"], P["azul_elegido"],
                   extra_colliders=[p for p in wpn if p.name in ("tacuara", "caja", "canon")], B=B, cache_key="gaucho_" + weapon)
    parts.append(pp)
    parts.append(collar(J["neck"] + V3(0, 0, .0), q, P["lana_parda"] * .9, "poncho", r=(.095, .088)))
    v, f = loft([J["neck"] + V3(0, .0, .03), J["neck"] + V3(0, .0, .065)], [.062, .06], sides=q.limb)
    parts.append(Part("panuelo", v, f, "panuelo", P["azul_elegido"], chain=["cuello"]))
    if q.hi:
        v, f = ellipsoid(J["neck"] + V3(0, .065, .035), (.03, .02, .028), 6, 4)
        parts.append(Part("nudo", v, f, "panuelo", P["azul_elegido"], bone="cuello"))
    carry = {"R": .15, "L": 1.0}
    return parts, J, B, carry


def figure_voluntario(q):
    """Voluntario de 1806 a pie (los jinetes que dejaron los caballos para tomar la Justina): casaca azul con vueltas rojas,
    calzón blanco, botas, bicornio negro con escarapela roja lisa, carabina y sable. Reconstrucción de DISEÑO: no es el
    uniforme de un cuerpo verificado; sin bandera argentina, escarapela celeste y blanca ni «Infernales»."""
    rh = (.25, .12, .97)
    arms = {"R": arm_pose(None, (.25, -.04, 1.17), rh), "L": arm_pose(None, (-.235, -.03, 1.16), (-.25, .06, .87))}
    J = standing_joints(arms)
    B = bones_from_joints(J)
    parts = [anchor_part("cadera")]
    parts += head_parts(J, q, beard=False, hair_long=False, queue=q.hi, skin="piel2")
    parts += bicorne(J, q, col=P["negro"], cock_col=P["borgona"] * 1.2)
    casaca, vueltas, blanco = lin("#253B53"), lin("#983C3C"), P["lino_blanco"]
    parts.append(torso_loft(J, q, casaca, "casaca", lower=J["pelvis"] + V3(0, 0, -.04),
                            rx=(.165, .175, .155, .175, .19, .075), ry=(.12, .125, .108, .122, .10, .062)))
    # faldones de la casaca, atrás, con vueltas rojas
    for s in (-1, 1):
        g = [[V3(s * .03, -.115, 1.0), V3(s * .16, -.10, 1.0)], [V3(s * .035, -.15, .62), V3(s * .19, -.10, .64)]]
        v, f = sheet(g)
        parts.append(Part("faldon", v, f, "casaca", casaca, chain=["cadera", "muslo_" + ("L" if s < 0 else "R")]))
        g = [[V3(s * .145, -.102, .98), V3(s * .165, -.098, .98)], [V3(s * .17, -.105, .64), V3(s * .195, -.098, .64)]]
        v, f = sheet(g)
        parts.append(Part("vuelta_faldon", v + V3(0, -.004, 0), f, "vueltas", vueltas, chain=["cadera"]))
        # solapa roja en el pecho
        v, f = cube(V3(s * .075, .118, 1.27), (.065, .012, .27))
        parts.append(Part("solapa", v, f, "vueltas", vueltas, smooth=False, chain=["pecho", "columna"]))
    for s in "LR":
        parts += arm_parts(J, s, q, casaca, "casaca", cuff=vueltas, cuff_role="vueltas", skin="piel2", sleeve_r=(.062, .052, .045))
    v, f = loft([J["neck"] - V3(0, 0, .01), J["neck"] + V3(0, 0, .055)], [.085, .08], [.078, .074], sides=q.limb + 2)
    parts.append(Part("cuello_casaca", v, f, "vueltas", vueltas, chain=["pecho", "cuello"]))
    v, f = loft([J["neck"] + V3(0, 0, .05), J["neck"] + V3(0, 0, .08)], [.06, .058], sides=q.limb)
    parts.append(Part("corbatin", v, f, "corbatin", P["negro"], chain=["cuello"]))
    # calzón blanco y botas de montar negras
    v, f = loft([V3(0, 0, .80), V3(0, 0, .88)], [.16, .17], [.11, .115], sides=q.torso)
    parts.append(Part("calzon", v, f, "calzon", blanco, chain=["cadera", "muslo_L", "muslo_R"]))
    for s in "LR":
        parts.append(leg_tube(J, s, q, .1, 1.0, .095, .07, blanco, "calzon", name="calzon_pierna", chain=["cadera", "muslo_" + s]))
        parts.append(leg_tube(J, s, q, .9, 1.95, .068, .052, P["negro"] * .8, "botas", name="bota",
                              chain=["muslo_" + s, "pierna_" + s]))
        v, f = loft([J["knee_" + s] + V3(0, 0, .02), J["knee_" + s] + V3(0, 0, .085)], [.074, .078], sides=q.limb)
        parts.append(Part("vuelta_bota", v, f, "botas", P["cuero_claro"], chain=["muslo_" + s, "pierna_" + s]))
        parts += foot_shoe(J, s, q, P["negro"] * .8, role="botas", name="pie_bota")
    # bandolera de ante, cartuchera, botones
    ring = sash_ring(V3(0, -.005, 0), .175, .13, 1.0, 1.47, .12, n=18 if q.hi else 10)
    v, f = loft(ring, .028, .006, sides=4, hint=(0, 0, 1), closed=True)
    parts.append(Part("bandolera", v, f, "correaje", lin("#BEAA78"), chain=["pecho", "columna", "cadera"], noise=0))
    v, f = cube(V3(.16, -.14, 1.0), (.17, .07, .12))
    parts.append(Part("cartuchera", v, f, "cuero", P["negro"], smooth=False, chain=["cadera"]))
    if q.hi:
        for z in (1.38, 1.30, 1.22, 1.14):
            for s in (-1, 1):
                v, f = ellipsoid(V3(s * .105, .126, z), (.009, .006, .009), 5, 4)
                parts.append(Part("boton", v, f, "laton", P["laton"], bone="pecho", noise=0))
    parts += sable(J, q)
    parts += carabina(rh, (.04, .12, 1.0), q, bone="mano_R")
    carry = {"R": .15, "L": 1.0}
    return parts, J, B, carry


def figure_realista(q):
    """Infante realista, 1817 (enemigo). DISEÑO plausible, sin datos del vestuario de un cuerpo concreto: chaqueta corta de
    bayeta gris blanquecina con cuello, vueltas y forros rojo borgoña (el rojo es el código del bando enemigo en el juego),
    pantalón gris, polainas cortas, chacó negro con chapa lisa y borla, correajes blancos cruzados, mochila con manta y
    fusil con bayoneta al hombro izquierdo. Sin cruz de Borgoña ni bandera."""
    lh = (-.205, .11, 1.0)
    arms = {"L": arm_pose(None, (-.24, -.04, 1.17), lh, .06), "R": arm_pose(None, (.235, -.03, 1.16), (.25, .07, .87))}
    J = standing_joints(arms)
    B = bones_from_joints(J)
    parts = [anchor_part("cadera")]
    parts += head_parts(J, q, beard=False, hair_long=False, skin="piel3", mustache=q.hi)
    parts += shako(J, q)
    parts.append(torso_loft(J, q, P["bayeta"], "chaqueta", lower=J["pelvis"] + V3(0, 0, -.03),
                            rx=(.16, .172, .152, .172, .188, .075), ry=(.118, .124, .106, .12, .10, .062)))
    for s in (-1, 1):
        g = [[V3(s * .03, -.112, 1.0), V3(s * .165, -.098, 1.0)], [V3(s * .04, -.13, .80), V3(s * .18, -.105, .80)]]
        v, f = sheet(g)
        parts.append(Part("faldon", v, f, "chaqueta", P["bayeta"], chain=["cadera"]))
        v, f = sheet([[V3(s * .15, -.10, .99), V3(s * .168, -.097, .99)], [V3(s * .165, -.108, .80), V3(s * .182, -.104, .80)]])
        parts.append(Part("vuelta_faldon", v + V3(0, -.004, 0), f, "vueltas", P["borgona"], chain=["cadera"]))
    for s in "LR":
        parts += arm_parts(J, s, q, P["bayeta"], "chaqueta", cuff=P["borgona"], cuff_role="vueltas", skin="piel3",
                           sleeve_r=(.062, .052, .045))
    v, f = loft([J["neck"] - V3(0, 0, .01), J["neck"] + V3(0, 0, .06)], [.085, .08], [.078, .074], sides=q.limb + 2)
    parts.append(Part("cuello_chaqueta", v, f, "vueltas", P["borgona"], chain=["pecho", "cuello"]))
    v, f = loft([V3(0, 0, .78), V3(0, 0, .88)], [.16, .17], [.11, .115], sides=q.torso)
    parts.append(Part("pantalon", v, f, "pantalon", P["pantalon_gris"], chain=["cadera", "muslo_L", "muslo_R"]))
    for s in "LR":
        parts.append(leg_tube(J, s, q, .1, 1.62, .095, .062, P["pantalon_gris"], "pantalon", name="pantalon_pierna"))
        parts += foot_shoe(J, s, q, P["negro"], gaiter=P["negro"] * 1.2, gaiter_top=1.6)
    for mir in (False, True):
        ring = sash_ring(V3(0, -.005, 0), .172, .132, .98, 1.47, .12, n=18 if q.hi else 10, mirror=mir)
        v, f = loft(ring, .026, .006, sides=4, hint=(0, 0, 1), closed=True)
        parts.append(Part("correaje", v, f, "correaje", P["correaje"], chain=["pecho", "columna", "cadera"], noise=0))
    v, f = cube(V3(0, -.20, 1.22), (.30, .12, .30))
    parts.append(Part("mochila", v, f, "cuero", P["cuero_claro"], smooth=False, chain=["pecho"]))
    v, f = loft([V3(-.17, -.20, 1.42), V3(.17, -.20, 1.42)], .055, sides=q.limb)
    parts.append(Part("manta", v, f, "manta", P["manta_gris"], chain=["pecho"]))
    v, f = cube(V3(.17, -.13, .97), (.15, .07, .12))
    parts.append(Part("cartuchera", v, f, "cuero", P["negro"], smooth=False, chain=["cadera"]))
    v, f = loft([V3(-.18, -.06, .95), V3(-.2, -.12, .6)], [.018, .012], sides=q.small)
    parts.append(Part("vaina_bayoneta", v, f, "cuero", P["negro"], chain=["cadera"], noise=0))
    parts += fusil(lh, (-.035, -.16, 1.0), q, bone="mano_L")
    carry = {"L": 0.0, "R": 1.0}
    return parts, J, B, carry


def figure_arriero(q):
    """Arriero del norte, 1817 (DISEÑO): chaqueta corta de lana parda, faja, calzón a la rodilla, piernas desnudas y
    ojotas, pañuelo atado a la cabeza bajo un sombrero de copa baja, poncho arrollado en bandolera; rebenque en la mano."""
    rh = (.245, .07, .90)
    arms = {"R": arm_pose(None, (.24, -.03, 1.15), rh), "L": arm_pose(None, (-.235, -.03, 1.16), (-.25, .06, .87))}
    J = standing_joints(arms)
    B = bones_from_joints(J)
    parts = [anchor_part("cadera")]
    parts += head_parts(J, q, beard=False, hair_long=True, skin="piel3", mustache=True)
    parts += hat_gaucho(J, q, color=P["paja"], brim=.23, crown_h=.085, tilt=-.02)
    v, f = ellipsoid(J["head"] + V3(0, -.03, .02), (.098, .112, .1), q.head[0], 5)
    parts.append(Part("panuelo_cabeza", v, f, "panuelo", P["lana_parda_osc"], bone="cabeza"))
    v, f = sheet([[J["head"] + V3(-.05, -.105, -.02), J["head"] + V3(.05, -.105, -.02)],
                  [J["head"] + V3(-.07, -.13, -.15), J["head"] + V3(.07, -.13, -.15)]])
    parts.append(Part("punta_panuelo", v, f, "panuelo", P["lana_parda_osc"] * .9, bone="cabeza"))
    parts.append(torso_loft(J, q, P["ropa_civil"], "chaqueta", lower=J["pelvis"] + V3(0, 0, .06),
                            rx=(.165, .17, .158, .178, .195, .078), ry=(.12, .124, .112, .124, .105, .064)))
    for s in "LR":
        parts += arm_parts(J, s, q, P["ropa_civil"], "chaqueta", skin="piel3", sleeve_r=(.066, .056, .048))
    parts.append(belt(J, q, P["azul_elegido"], "faja", z=J["pelvis"][2] + .07, h=.10, r=(.18, .135), name="faja"))
    parts += chiripa(J, q, P["chiripa"] * 1.15, role="pantalon", crotch=.76, knee_u=.95)
    for s in "LR":
        parts.append(leg_tube(J, s, q, .95, 1.93, .058, .046, P["piel3"], "piel", name="pierna_desnuda",
                              chain=["muslo_" + s, "pierna_" + s]))
        parts.append(leg_tube(J, s, q, .86, 1.16, .1, .088, P["lino_blanco"], "calzoncillo", name="calzoncillo",
                              flare_hem=.1 if q.hi else None))
        parts += foot_ojota(J, s, q)
    ring = sash_ring(V3(0, -.005, 0), .20, .155, .93, 1.53, .135, n=20 if q.hi else 10)
    v, f = loft(ring, .055, .045, sides=q.small + 1, closed=True)
    parts.append(Part("poncho_arrollado", v, f, "poncho", P["lana_parda_osc"] * 1.25, chain=["pecho", "columna", "cadera"]))
    if q.hi:   # lazo arrollado colgado del costado izquierdo
        tv, tf = loft([V3(-.21, -.02, 1.0) + V3(.0, .1 * math.cos(t), .1 * math.sin(t)) for t in np.linspace(0, 2 * math.pi, 13)[:-1]],
                      .014, sides=4, closed=True)
        parts.append(Part("lazo", tv, tf, "cuero", P["cuero_claro"], chain=["cadera"], noise=0))
    parts += rebenque(rh, q, bone="mano_R")
    carry = {"R": .8, "L": 1.0}
    return parts, J, B, carry


FIGURES = {
    "gaucho_1817": (lambda q: figure_gaucho(q, "tacuara"), "Paisano de las milicias gauchas, 1817, a pie, con tacuara"),
    "gaucho_1817_carabina": (lambda q: figure_gaucho(q, "carabina"), "Paisano de las milicias gauchas, 1817, a pie, con carabina"),
    "voluntario_1806": (figure_voluntario, "Voluntario de 1806 a pie (Justina): casaca azul, vueltas rojas, calzón blanco, bicornio"),
    "realista_1817": (figure_realista, "Infante realista, 1817 (enemigo): chaqueta de bayeta, vueltas borgoña, chacó, fusil al hombro"),
    "arriero_1817": (figure_arriero, "Arriero del norte, 1817: chaqueta corta, ojotas, poncho arrollado, rebenque"),
}


def build_person(key, hi):
    reset()
    fn, desc = FIGURES[key]
    q = Q(hi)
    parts, J, B, carry = fn(q)
    name = "persona_" + key + ("" if hi else "_lod")
    roles = sorted({p.role for p in parts if p.role != "ancla"})
    note = (desc + ". Obra propia (tools/f5_personas.py): geometría, poncho colgado por simulación propia, color con oclusión, "
            "esqueleto y ciclos por fórmula (diseño, no captura). Vestuario: DISEÑO plausible, no uniforme verificado.")
    extra = {"roles": roles, "height_m": round(float(max(p.v[:, 2].max() for p in parts if p.role in ("sombrero",))), 3),
             "hand_R_godot": godot(J["hand_R"]), "hand_L_godot": godot(J["hand_L"])}
    if not hi:
        mesh = build_mesh(name, parts, "F5", None)
        export(name, note + " LOD de tropa: estático, pose de reposo.", "persona", extra=extra)
        return
    rig = build_armature(B)
    mesh = build_mesh(name, parts, "F5", B)
    mesh.parent = rig
    m = mesh.modifiers.new("esqueleto", "ARMATURE")
    m.object = rig
    animate(rig, J, carry)
    extra["anim"] = json.loads(json.dumps(ANIM_REPORT))
    export(name, note, "persona", anims=("idle", "walk", "run", "crouch"), extra=extra)


# --------------------------------------------------------------------------------------
# Jinetes (sentados sobre el caballo criollo; origen = asiento)
# --------------------------------------------------------------------------------------
_HORSE = {}


def horse_geometry():
    """Malla del caballo criollo zaino en reposo (de su GLB): choque del poncho y las piernas, y oclusión."""
    if "vf" in _HORSE:
        return _HORSE["vf"]
    keep = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(HORSE_GLB))
    new = [o for o in bpy.data.objects if o not in keep]
    for o in new:
        if o.type == "ARMATURE":
            o.data.pose_position = "REST"
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    V, F = [], []
    for o in new:
        if o.type != "MESH" or not o.name.startswith("caballo"):
            continue
        me = o.evaluated_get(dg).to_mesh()
        V.append(np.array([tuple(o.matrix_world @ v.co) for v in me.vertices]))
        F.append([list(p.vertices) for p in me.polygons])
    for o in new:
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.armatures, bpy.data.actions, bpy.data.materials):
        for b in list(coll):
            if b.users == 0:
                coll.remove(b)
    _HORSE["vf"] = merge(*[(v, f) for v, f in zip(V, F)])
    return _HORSE["vf"]


def components(v, f, min_verts=150):
    """Piezas conexas de una malla (el caballo trae cuerpo, jerga, carona, bastos y vellón superpuestos: cada una es un
    sólido aparte para el choque; las correas y argollas chicas no cuentan)."""
    par = list(range(len(v)))

    def find(a):
        while par[a] != a:
            par[a] = par[par[a]]
            a = par[a]
        return a
    for face in f:
        r0 = find(face[0])
        for i in face[1:]:
            r = find(i)
            if r != r0:
                par[r] = r0
    root = np.array([find(i) for i in range(len(v))])
    out = []
    for r in np.unique(root):
        ids = np.nonzero(root == r)[0]
        if len(ids) < min_verts:
            continue
        remap = {int(i): k for k, i in enumerate(ids)}
        ff = [[remap[i] for i in face] for face in f if root[face[0]] == r]
        out.append(fix_normals(v[ids], ff))     # normales hacia afuera: el choque decide adentro/afuera con ellas
    return out


def seated_joints(rh, lh, re, le):
    J = {"pelvis": V3(0, -.03, 1.585), "waist": V3(0, -.05, 1.70), "chest": V3(0, -.055, 1.87), "neck": V3(0, -.055, 2.07),
         "head": V3(0, -.035, 2.195), "top": V3(0, -.035, 2.31)}
    for s, x in (("L", -1), ("R", 1)):
        J["hip_" + s] = V3(.125 * x, -.02, 1.585)
        J["knee_" + s] = V3(.42 * x, .175, 1.215)
        J["ankle_" + s] = V3(.40 * x, .205, .79)
        J["toe_" + s] = V3(.40 * x, .37, .71)
        J["shoulder_" + s] = V3(.185 * x, -.06, 2.03)
    for s, (e, h) in (("R", (re, rh)), ("L", (le, lh))):
        el, wr, ha = arm_pose(None, e, h)
        J["elbow_" + s], J["wrist_" + s], J["hand_" + s] = V3(*el), V3(*wr), V3(*ha)
    return J


def push_out_of_horse(parts, names, cols, d=.008):
    for p in parts:
        if p.name in names:
            p.v = collide(p.v, cols, d)


RIDER_RH = (.405, .02, 1.72)       # mano derecha (puño): ahí se toma la tacuara de arma_tacuara.glb
RIDER_LH = (-.065, .30, 1.665)     # mano izquierda con las riendas, sobre la cruz


def build_rider(period, hi):
    reset()
    q = Q(hi)
    J = seated_joints(RIDER_RH, RIDER_LH, (.29, -.12, 1.78), (-.245, .055, 1.775))
    hv, hf = horse_geometry()
    hcols = [Collider(v, f) for v, f in components(hv, hf)]
    parts = [anchor_part()]
    parts[0].v += SEAT          # el ancla va en el origen del GLB (el asiento)
    legs = ("chiripa_pierna", "calzoncillo", "bota", "bota_ruedo", "pie_bota", "dedos", "calzon_pierna", "vuelta_bota", "chiripa", "calzon")
    if period == 1817:
        parts += head_parts(J, q, beard=True, hair_long=True)
        parts += hat_gaucho(J, q, color=PJ["sombrero"])
        parts.append(torso_loft(J, q, P["lino"], "camisa", lower=V3(0, -.03, 1.525)))
        for s in "LR":
            parts += arm_parts(J, s, q, P["lino"], "camisa", sleeve_r=(.066, .058, .048))
        parts += chiripa(J, q, P["chiripa"], crotch=1.53, knee_u=.86)
        parts.append(belt(J, q, P["cuero"], "tirador", h=.085, r=(.182, .138)))
        for s in "LR":
            parts.append(leg_tube(J, s, q, .80, 1.45, .088, .098, P["lino_blanco"], "calzoncillo", name="calzoncillo",
                                  flare_hem=.12 if q.hi else None))
            parts += foot_boot_potro(J, s, q)
        if q.hi:
            parts += facon(J, q)
        push_out_of_horse(parts, legs, hcols)
        pp = poncho_on(parts, J, q, 1.50, 2.05, PJ["poncho"], PJ["guarda"], PJ["guarda"], horse=(hv, hf), cache_key="jinete")
        parts.append(pp)
        parts.append(collar(J["neck"], q, PJ["poncho"] * .92, "poncho", r=(.095, .088)))
        v, f = loft([J["neck"] + V3(0, 0, .03), J["neck"] + V3(0, 0, .065)], [.062, .06], sides=q.limb)
        parts.append(Part("panuelo", v, f, "panuelo", PJ["panuelo"], ao=.4))
        if q.hi:
            v, f = ellipsoid(J["neck"] + V3(0, .065, .035), (.03, .02, .028), 6, 4)
            parts.append(Part("nudo", v, f, "panuelo", PJ["panuelo"], ao=.4))
        desc = ("Jinete de 1817 (paisano de las milicias gauchas): poncho, chiripá, calzoncillo cribado, botas de potro, "
                "sombrero; la mano izquierda en las riendas, la derecha lista para la tacuara (arma_tacuara.glb, aparte)")
    else:
        parts += head_parts(J, q, beard=False, hair_long=False, queue=q.hi, skin="piel2")
        parts += bicorne(J, q)
        parts.append(torso_loft(J, q, PJ["casaca"], "casaca", lower=V3(0, -.03, 1.53),
                                rx=(.165, .175, .155, .175, .19, .075), ry=(.12, .125, .108, .122, .10, .062)))
        for s in (-1, 1):
            g = [[V3(s * .03, -.15, 1.66), V3(s * .17, -.13, 1.66)], [V3(s * .05, -.33, 1.535), V3(s * .22, -.30, 1.53)]]
            v, f = sheet(g)
            parts.append(Part("faldon", v, f, "casaca", PJ["casaca"]))
            v, f = cube(V3(s * .075, .07, 1.92), (.065, .012, .25))
            parts.append(Part("solapa", v, f, "vueltas", PJ["vueltas"], smooth=False, ao=.4))
        for s in "LR":
            parts += arm_parts(J, s, q, PJ["casaca"], "casaca", cuff=PJ["vueltas"], cuff_role="vueltas", skin="piel2",
                               sleeve_r=(.062, .052, .045))
        for pt in parts:
            if pt.role in ("vueltas", "calzon"):
                pt.ao = .35
        v, f = loft([J["neck"] - V3(0, 0, .01), J["neck"] + V3(0, 0, .055)], [.085, .08], [.078, .074], sides=q.limb + 2)
        parts.append(Part("cuello_casaca", v, f, "vueltas", PJ["vueltas"], ao=.35))
        v, f = loft([J["neck"] + V3(0, 0, .05), J["neck"] + V3(0, 0, .08)], [.06, .058], sides=q.limb)
        parts.append(Part("corbatin", v, f, "corbatin", PJ["sombrero"]))
        v, f = loft([V3(0, -.03, 1.525), V3(0, -.03, 1.6)], [.16, .17], [.12, .125], sides=q.torso)
        parts.append(Part("calzon", v, f, "calzon", PJ["calzon_blanco"], ao=.3))
        for s in "LR":
            parts.append(leg_tube(J, s, q, .05, 1.0, .095, .072, PJ["calzon_blanco"], "calzon", name="calzon_pierna"))
            parts[-1].ao = .3
            parts.append(leg_tube(J, s, q, .92, 1.95, .068, .052, PJ["bota_negra"], "botas", name="bota"))
            v, f = loft([J["knee_" + s] + (J["ankle_" + s] - J["knee_" + s]) * .0, J["knee_" + s] + (J["ankle_" + s] - J["knee_" + s]) * .14],
                        [.075, .072], sides=q.limb)
            parts.append(Part("vuelta_bota", v, f, "botas", P["cuero_claro"]))
            parts += foot_shoe(J, s, q, PJ["bota_negra"], role="botas", name="pie_bota")
        ring = sash_ring(V3(0, -.055, .0), .178, .13, 1.66, 2.07, .12, n=18 if q.hi else 10)
        v, f = loft(ring, .028, .006, sides=4, hint=(0, 0, 1), closed=True)
        parts.append(Part("bandolera", v, f, "correaje", PJ["correaje"], noise=0, ao=.3))
        v, f = cube(V3(.17, -.21, 1.66), (.17, .07, .12))
        parts.append(Part("cartuchera", v, f, "cuero", P["negro"], smooth=False))
        if q.hi:
            for z in (2.0, 1.93, 1.86, 1.79):
                for s in (-1, 1):
                    v, f = ellipsoid(V3(s * .105, .074, z), (.009, .006, .009), 5, 4)
                    parts.append(Part("boton", v, f, "laton", P["laton"], noise=0))
        Js = dict(J)
        parts += sable(Js, q)
        push_out_of_horse(parts, legs + ("faldon", "vaina"), hcols)
        desc = ("Jinete de 1806 (Justina): casaca azul con vueltas rojas, calzón blanco, botas, bicornio negro con escarapela "
                "roja lisa, bandolera y sable; sin bandera argentina, escarapela celeste y blanca ni «Infernales»")
    for p in parts:
        p.v = p.v - SEAT
    name = f"jinete_criollo_{period}" + ("" if hi else "_lod")
    hv2 = hv - SEAT
    build_mesh(name, parts, "F4", None, occluders=[(hv2, hf)])
    hat = [p for p in parts if p.role == "sombrero" and p.name in ("sombrero", "bicornio", "copa")]
    extra = {"roles": sorted({p.role for p in parts if p.role != "ancla"}),
             "hand_R_seat_godot": godot(np.asarray(RIDER_RH) - SEAT), "hand_L_seat_godot": godot(np.asarray(RIDER_LH) - SEAT),
             "hat_min_y_over_seat_m": round(float(min(p.v[:, 2].min() for p in hat)), 3),
             "hat_max_y_over_seat_m": round(float(max(p.v[:, 2].max() for p in hat)), 3)}
    export(name, desc + ". Obra propia (tools/f5_personas.py), sin esqueleto; origen = asiento: hijo de un BoneAttachment3D en el "
           "hueso 'silla' del caballo criollo (transformación identidad). Vestuario: DISEÑO." + (" LOD de tropa." if not hi else ""),
           "jinete", extra=extra)


def build_weapons():
    q = Q(True)
    specs = {
        "arma_tacuara": (lambda: tacuara((0, 0, 0), (0, 0, 1), q), "Tacuara (caña con hoja atada), 3,3 m; origen = agarre, la punta hacia +Y de Godot"),
        "arma_carabina": (lambda: carabina((0, 0, 0), (0, 0, 1), q), "Carabina (tercerola) de chispa; origen = garganta de la caja, boca hacia +Y"),
        "arma_fusil": (lambda: fusil((0, 0, 0), (0, 0, 1), q), "Fusil de chispa con bayoneta; origen = talón de la culata, boca hacia +Y"),
    }
    for name, (fn, note) in specs.items():
        reset()
        parts = [anchor_part()] + fn()
        build_mesh(name, parts, "F5", None, ao_strength=.3)
        export(name, note + ". Obra propia.", "arma")


# --------------------------------------------------------------------------------------
# Vistas de control (Workbench) a partir de los GLB exportados
# --------------------------------------------------------------------------------------
def preview(outdir):
    out = Path(outdir)
    out.mkdir(parents=True, exist_ok=True)

    def scene_reset():
        bpy.ops.wm.read_factory_settings(use_empty=True)
        sc = bpy.context.scene
        sc.render.engine = "BLENDER_WORKBENCH"
        sc.display.shading.light = "STUDIO"
        sc.display.shading.color_type = "VERTEX"
        sc.display.shading.show_shadows = True
        sc.display.shading.show_cavity = True
        sc.display.shading.cavity_type = "WORLD"
        sc.display.shading.show_object_outline = False
        sc.render.resolution_x, sc.render.resolution_y = 1600, 900
        sc.render.film_transparent = False
        sc.world = bpy.data.worlds.new("w") if sc.world is None else sc.world
        sc.display.shading.background_type = "VIEWPORT"
        sc.display.shading.background_color = (.62, .64, .66)
        bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, 0))
        g = bpy.context.object
        me = g.data
        a = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
        a.data.foreach_set("color", np.tile([.30, .27, .22, 1], len(me.loops)).astype(np.float32))
        return sc

    def load(name, loc=(0, 0, 0), rotz=0.0, frame=None, action=None):
        keep = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(OUT / (name + ".glb")))
        new = [o for o in bpy.data.objects if o not in keep]
        roots = [o for o in new if o.parent is None]
        for r in roots:
            r.location = Vector(loc) + r.location
            r.rotation_mode = "XYZ"
            r.rotation_euler.z += rotz
        act = action or "idle"
        for o in new:
            if o.type == "ARMATURE" and o.animation_data:
                cands = [a for a in bpy.data.actions if a.name.startswith(act)]
                if cands:   # el importador nombra las acciones «<animación>_<esqueleto>»: la del esqueleto recién cargado
                    o.animation_data.action = cands[-1]
        return new

    def cam(loc, look, lens=50, ortho=None):
        c = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
        bpy.context.scene.collection.objects.link(c)
        c.location = loc
        d = Vector(look) - Vector(loc)
        c.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        c.data.lens = lens
        if ortho:
            c.data.type = "ORTHO"
            c.data.ortho_scale = ortho
        bpy.context.scene.camera = c

    def render(fn):
        bpy.context.scene.render.filepath = str(out / fn)
        bpy.ops.render.render(write_still=True)
        print("PREVIEW", out / fn)

    def scale_bar(x, y, h=1.7):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, h / 2))
        o = bpy.context.object
        o.scale = (.03, .03, h)
        a = o.data.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
        a.data.foreach_set("color", np.tile([.9, .9, .9, 1], len(o.data.loops)).astype(np.float32))
        for z in np.arange(.5, h, .5):
            bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, z))
            t = bpy.context.object
            t.scale = (.12, .03, .012)

    people = ["gaucho_1817", "gaucho_1817_carabina", "arriero_1817", "voluntario_1806", "realista_1817"]
    # 1) fila con escala, caballo y jinetes
    scene_reset()
    x = -4.6
    scale_bar(-5.5, 0)
    for p in people:
        load("persona_" + p, (x, 0, 0), rotz=math.pi)
        x += 1.15
    load("caballo_criollo_zaino", (x + 1.0, 0, 0), rotz=math.pi / 2)
    load("jinete_criollo_1817", (x + 1.0, 0, 1.5), rotz=math.pi / 2)
    load("caballo_criollo_alazan", (x + 3.0, 0, 0), rotz=math.pi / 2)
    load("jinete_criollo_1806", (x + 3.0, 0, 1.5), rotz=math.pi / 2)
    bpy.context.scene.frame_set(0)
    cam((0.3, -12.5, 2.0), (0.3, 0, 1.25), lens=35)
    render("f5_01_fila_escala.png")
    # 2) LOD de tropa, misma fila
    scene_reset()
    x = -4.6
    scale_bar(-5.6, 0)
    for p in people:
        load("persona_" + p + "_lod", (x, 0, 0), rotz=math.pi)
        x += 1.15
    load("caballo_criollo_zaino_lod", (x + 1.0, 0, 0), rotz=math.pi / 2)
    load("jinete_criollo_1817_lod", (x + 1.0, 0, 1.5), rotz=math.pi / 2)
    load("caballo_criollo_alazan_lod", (x + 3.0, 0, 0), rotz=math.pi / 2)
    load("jinete_criollo_1806_lod", (x + 3.0, 0, 1.5), rotz=math.pi / 2)
    cam((0.3, -12.5, 2.0), (0.3, 0, 1.25), lens=35)
    render("f5_02_fila_lod_tropa.png")
    # 3) jinete de 1817 sobre el zaino, tres vistas
    for i, (cl, nm) in enumerate([((3.2, 3.0, 2.4), "tres_cuartos"), ((4.4, 0.0, 1.9), "perfil"), ((0.4, 4.6, 2.3), "frente")]):
        scene_reset()
        load("caballo_criollo_zaino")
        load("jinete_criollo_1817", (0, 0, 1.5))
        load("arma_tacuara", (RIDER_RH[0], RIDER_RH[1], RIDER_RH[2]))
        cam(cl, (0, 0.05, 1.55), lens=42)
        render(f"f5_03_jinete1817_zaino_{nm}.png")
    # el jinete de 1817 como lo tiñe el juego (world_view._poncho_mesh): tropa con poncho pardo, jefe con granate oscuro
    def game_tint(objs, hero):
        brown = lin("#5E1F1A") if hero else lin("#705741")
        sash = lin("#8A7350")
        for o in objs:
            if o.type != "MESH":
                continue
            me = o.data
            a = me.color_attributes[0]
            for poly in me.polygons:
                nm = me.materials[poly.material_index].name.rsplit(".", 1)[0] if "." in me.materials[poly.material_index].name[-4:] else me.materials[poly.material_index].name
                if not (nm.endswith("wool") or nm.endswith("linen")):
                    continue
                for li in poly.loop_indices:
                    c = np.array(a.data[li].color[:3]) / F4_ALBEDO
                    if c[0] > .1 and c[0] > c[1] * 2.5 and c[0] > c[2] * 2.5:
                        t = brown if nm.endswith("wool") else sash
                        f = min(max(c[0] / .5, .2), 1.15) * F4_ALBEDO
                        a.data[li].color = (*(t * f), 1.0)
    scene_reset()
    load("caballo_criollo_zaino", (-1.0, 0, 0))
    game_tint(load("jinete_criollo_1817", (-1.0, 0, 1.5)), True)
    load("caballo_criollo_alazan", (1.0, 0, 0))
    game_tint(load("jinete_criollo_1817", (1.0, 0, 1.5)), False)
    cam((0, 6.5, 2.4), (0, 0, 1.5), lens=40)
    render("f5_03_jinete1817_como_lo_tine_el_juego_tropa_izq_jefe_der.png")
    scene_reset()
    load("caballo_criollo_alazan")
    load("jinete_criollo_1806", (0, 0, 1.5))
    cam((3.2, 3.0, 2.4), (0, 0.05, 1.55), lens=42)
    render("f5_04_jinete1806_alazan.png")
    # 4) primeros planos de las figuras a pie (frente y espalda)
    for p in people:
        scene_reset()
        load("persona_" + p, (-.55, 0, 0), rotz=math.radians(-25))
        load("persona_" + p, (.55, 0, 0), rotz=math.radians(155))
        cam((0, 4.2, 1.35), (0, 0, 1.0), lens=50)
        render(f"f5_05_{p}_frente_espalda.png")
    # 5) ciclos: walk y run en cuadros sueltos
    for act, frames in (("walk", (0, 3, 6, 9, 12)), ("run", (0, 2, 4, 6, 8))):
        scene_reset()
        objs = []
        for i, fr in enumerate(frames):
            new = load("persona_gaucho_1817", (-2.4 + i * 1.2, 0, 0), action=act)
        sc = bpy.context.scene
        # cada copia en su cuadro: se desplaza la acción con NLA no hace falta; se renderiza un cuadro por vez
        cam((0.0, -7.5, 1.3), (0.0, 0, 1.0), lens=40)
        for i, fr in enumerate(frames):
            sc.frame_set(fr)
            render(f"f5_06_{act}_cuadro{fr:02d}.png")
    print("F5_PREVIEW_LISTO")


# --------------------------------------------------------------------------------------
def main():
    if PREVIEW:
        preview(PREVIEW)
        return
    OUT.mkdir(parents=True, exist_ok=True)
    for period in (1817, 1806):
        if f"jinete_{period}" in ONLY:
            build_rider(period, True)
            build_rider(period, False)
    for key in FIGURES:
        if key in ONLY:
            ANIM_REPORT.clear()
            build_person(key, True)
            build_person(key, False)
    if "armas" in ONLY:
        build_weapons()
    man = OUT / "f5_personas_manifest.json"
    old = json.loads(man.read_text(encoding="utf-8")) if man.is_file() else {}
    old.update(REPORT)
    old["_convenciones"] = {
        "unidad": "metro", "frente": "Godot -Z (Blender +Y)", "arriba": "Godot +Y", "fps": FPS,
        "fuente": "obra propia, tools/f5_personas.py (sin mallas ni texturas de terceros)",
        "color": "COLOR_0 lineal = albedo final (con oclusión horneada); material «<F4|F5> | <rol> | <clase>»",
        "jinete": {"origen": "asiento = hueso 'silla' del caballo criollo (Godot (0, 1.5, 0) sobre el suelo)", "asiento_godot": godot(SEAT),
                   "tintes_que_reconoce_el_juego": "1817: poncho lana granate (0.31, 0.035, 0.026)x0.62 y pañuelo lino granate; "
                   "1806: casaca índigo, vueltas rojas, calzón lino blanco, sombrero negro (ver world_view._poncho_mesh/_tinted_mesh "
                   "y humahuaca_units._rider_color)"},
        "persona": {"origen": "suelo, entre los pies", "huesos": BONES, "lado_L": "-X de Blender = izquierda de la figura (Godot -X)",
                    "animaciones": {k: {"frames": v["n"], "design_mps": v["v"]} for k, v in GAITS.items()} | {"idle": {"frames": 96, "design_mps": 0}},
                    "bucles": "idle, walk, run en el lugar (sin desplazamiento de raíz); loop_mode=1 en los .import",
                    "agachado": "crouch (visual/r1 F6): pose en el lugar, cadera %.2f m más abajo, pies apoyados; la usa el segundo reconocedor del nivel II" % CROUCH_DROP},
        "arma": {"origen": "punto de agarre", "eje": "Godot +Y (de la culata a la punta)"},
        "retinte": "por rol: cada rol es una superficie propia; color nuevo = tinte x (COLOR_0 / color base del rol) conserva la oclusión",
    }
    man.write_text(json.dumps(old, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print("F5_PERSONAS_LISTAS")


main()
