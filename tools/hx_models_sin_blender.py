"""Exporta los modelos hx_* del nivel II «Humahuaca» SIN Blender (pista P6).

Corre los mismos constructores hx_* de tools/create_models.py, pero reemplaza las primitivas de
bpy (cubo, cono, esfera, toro, icosfera, malla) por equivalentes en numpy y escribe GLB 2.0
propios en assets/models/hx_*.glb. Variante SIN texturas PBR: el color va por vértice (COLOR_0),
con biseles en las cajas de adobe y madera, normales suavizadas por ángulo y variación de color
que imita la textura (tongadas del tapial, piedras de la pirca, facetas de piedra y torta).

Uso:   python tools/hx_models_sin_blender.py                (los nueve)
       python tools/hx_models_sin_blender.py --only hx_tapia,hx_corral
Requiere solo numpy. El manifiesto assets/models/model_manifest.json se fusiona (solo hx_*).
Cuando haya Blender, la variante con texturas PBR sale de:
       blender --background --factory-startup --python tools/create_models.py -- --only hx_...
Todo es reconstrucción artística propia; nada se descarga.
"""
import sys, types, json, math, struct, hashlib
import numpy as np
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "models"
argv = sys.argv[1:]
ONLY = argv[argv.index("--only") + 1].split(",") if "--only" in argv else None

# --- cargar create_models.py sin Blender ------------------------------------------------------
sys.modules.setdefault("bpy", types.ModuleType("bpy"))
_mu = types.ModuleType("mathutils")
_mu.Vector = lambda v: np.array(v, float)
sys.modules.setdefault("mathutils", _mu)
_src = (ROOT / "tools" / "create_models.py").read_text(encoding="utf-8").rsplit("\nmain()", 1)[0]
CM = {"__file__": str(ROOT / "tools" / "create_models.py"), "__name__": "create_models_sin_blender"}
exec(compile(_src, "create_models.py", "exec"), CM)

OBJS = []
REPORT = {}
# Bisel (m) por clase de material, para cajas y sólidos de 8 vértices. Tapial y pirca no: sus
# módulos se apoyan uno contra otro y el bisel marcaría la junta.
CHAMFER = {"hx_adobe": .06, "hx_cal": .05, "hx_torta": .035, "stone": .03, "hx_paja": .02}
# Ángulo de suavizado (grados) por clase: la piedra y la pirca quedan facetadas.
SMOOTH_DEG = {"hx_pirca": 12.0, "stone": 25.0}
SMOOTH_DEFAULT = 50.0


# Calidez por material (pista P2, ronda 3): la tierra de la quebrada es ocre y rojiza. Con la luna fría, la torta de barro y el adobe tal como salen de la paleta
# se leían gris verdoso; se los corre hacia siena (factor lineal por canal, por prefijo del nombre del material). La geometría y los nombres no cambian.
WARMTH = {
    "Techo | torta": (1.10, 0.84, 0.62),
    "Adobe |": (1.07, 0.92, 0.76),
    "Tapial |": (1.06, 0.90, 0.74),
    "Ramada | cañizo": (1.04, 0.92, 0.74),
}


def _warm(mat):
    col = np.array(mat.color if mat else (.5, .5, .5), float)
    name = getattr(mat, "name", "") if mat else ""
    for prefix, k in WARMTH.items():
        if name.startswith(prefix):
            return np.minimum(col * np.array(k, float), 1.0)
    return col


class O:
    def __init__(self, name, v, f, mat):
        self.name, self.mat = name, mat
        self.v = np.asarray(v, float)
        self.f = [tuple(x) for x in f]
        self.kind = mat.kind if mat else "anchor"
        self.col = np.tile(_warm(mat), (len(self.v), 1))
        OBJS.append(self)


def rot_euler(rx, ry, rz):
    cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    Rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    Rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return Rz @ Ry @ Rx


HEX_FACES = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
HEX_EDGES = [(0, 1), (1, 2), (2, 3), (3, 0), (4, 5), (5, 6), (6, 7), (7, 4), (0, 4), (1, 5), (2, 6), (3, 7)]


def _orient(face, V, centre):
    p = V[list(face)]
    n = np.cross(p[1] - p[0], p[2] - p[0])
    return face if np.dot(n, p.mean(0) - centre) >= 0 else tuple(reversed(face))


def chamfer_hexa(c, w):
    """Bisel de un sólido convexo de 8 esquinas (orden de hx_hexa): 6 caras, 12 chaflanes, 8 esquinas."""
    c = np.asarray(c, float)
    centre = c.mean(0)
    V, idx = [], {}
    for fi, face in enumerate(HEX_FACES):
        for k, ci in enumerate(face):
            prv, nxt = c[face[k - 1]] - c[ci], c[face[(k + 1) % 4]] - c[ci]
            p = c[ci] + w * (prv / np.linalg.norm(prv) + nxt / np.linalg.norm(nxt))
            idx[(ci, fi)] = len(V)
            V.append(p)
    V = np.array(V)
    F = [tuple(idx[(ci, fi)] for ci in face) for fi, face in enumerate(HEX_FACES)]
    for a, b in HEX_EDGES:
        fa, fb = [fi for fi, face in enumerate(HEX_FACES) if a in face and b in face]
        F.append(_orient((idx[(a, fa)], idx[(b, fa)], idx[(b, fb)], idx[(a, fb)]), V, centre))
    for ci in range(8):
        fs = [fi for fi, face in enumerate(HEX_FACES) if ci in face]
        F.append(_orient(tuple(idx[(ci, fi)] for fi in fs), V, centre))
    return V, F


def solid8(name, corners, mat):
    corners = np.asarray(corners, float)
    w = CHAMFER.get(mat.kind if mat else "", 0)
    edges = [np.linalg.norm(corners[a] - corners[b]) for a, b in HEX_EDGES]
    w = min(w, .3 * min(edges))
    if w >= .008 and min(edges) >= .06:
        v, f = chamfer_hexa(corners, w)
        return O(name, v, f, mat)
    return O(name, corners, HEX_FACES, mat)


def box_corners(scale):
    sx, sy, sz = (s / 2 for s in scale)
    return np.array([(-sx, -sy, -sz), (sx, -sy, -sz), (sx, sy, -sz), (-sx, sy, -sz),
                     (-sx, -sy, sz), (sx, -sy, sz), (sx, sy, sz), (-sx, sy, sz)])


# --- primitivas equivalentes a las de create_models.py ------------------------------------------
def r_reset():
    OBJS.clear()


def r_mesh(name, vertices, faces, mat, smooth=True, bone=None, rig=None):
    if len(vertices) == 8 and [tuple(f) for f in faces] == HEX_FACES:
        return solid8(name, vertices, mat)
    return O(name, vertices, faces, mat)


def r_box(name, position, scale, mat, bevel=.015, bone=None, rig=None, segs=2):
    return solid8(name, box_corners(scale) + np.array(position), mat)


def r_rbox(name, position, scale, rotation, mat, bevel=.0, bone=None, rig=None):
    return solid8(name, box_corners(scale) @ rot_euler(*rotation).T + np.array(position), mat)


def _frame_z(d):
    z = d / np.linalg.norm(d)
    a = np.array([0, 1, 0]) if abs(z[1]) < .9 else np.array([1, 0, 0])
    x = np.cross(a, z)
    x /= np.linalg.norm(x)
    return np.stack([x, np.cross(z, x), z], 1)


def r_segment(name, a, b, radius_a, radius_b, mat, bone=None, rig=None, sides=12):
    a, b = np.array(a, float), np.array(b, float)
    L = np.linalg.norm(b - a)
    v = [(math.cos(2 * math.pi * j / sides) * r, math.sin(2 * math.pi * j / sides) * r, z)
         for z, r in ((-L / 2, radius_a), (L / 2, radius_b)) for j in range(sides)]
    v = np.array(v) @ _frame_z(b - a).T + (a + b) / 2
    f = [(j, (j + 1) % sides, sides + (j + 1) % sides, sides + j) for j in range(sides)]
    f += [tuple(reversed(range(sides))), tuple(range(sides, 2 * sides))]
    return O(name, v, f, mat)


def r_sphere(name, position, scale, mat, bone=None, rig=None, seg=16, rings=10):
    v = [(0, 0, -1)]
    for i in range(1, rings):
        ph = -math.pi / 2 + math.pi * i / rings
        v += [(math.cos(ph) * math.cos(2 * math.pi * j / seg), math.cos(ph) * math.sin(2 * math.pi * j / seg), math.sin(ph)) for j in range(seg)]
    v.append((0, 0, 1))
    top = len(v) - 1
    f = [(0, 1 + (j + 1) % seg, 1 + j) for j in range(seg)]
    for i in range(rings - 2):
        for j in range(seg):
            p, q = 1 + i * seg + j, 1 + i * seg + (j + 1) % seg
            f.append((p, q, q + seg, p + seg))
    base = 1 + (rings - 2) * seg
    f += [(base + j, base + (j + 1) % seg, top) for j in range(seg)]
    return O(name, np.array(v) * np.array(scale) + np.array(position), f, mat)


def r_torus(name, position, major, minor, rotation, mat, bone=None, rig=None, ms=20, ns=6):
    v = []
    for i in range(ms):
        u = 2 * math.pi * i / ms
        for j in range(ns):
            w = 2 * math.pi * j / ns
            r = major + minor * math.cos(w)
            v.append((r * math.cos(u), r * math.sin(u), minor * math.sin(w)))
    f = [(i * ns + j, ((i + 1) % ms) * ns + j, ((i + 1) % ms) * ns + (j + 1) % ns, i * ns + (j + 1) % ns) for i in range(ms) for j in range(ns)]
    return O(name, np.array(v) @ rot_euler(*rotation).T + np.array(position), f, mat)


def r_tube(name, points, radius, mat, bone=None, rig=None):
    o = None
    for a, b in zip(points, points[1:]):
        o = r_segment(name, a, b, radius, radius, mat, sides=8)
    return o


def _icosphere(sub):
    t = (1 + 5 ** .5) / 2
    v = [np.array(p) / np.linalg.norm(p) for p in [(-1, t, 0), (1, t, 0), (-1, -t, 0), (1, -t, 0), (0, -1, t), (0, 1, t), (0, -1, -t), (0, 1, -t),
                                                   (t, 0, -1), (t, 0, 1), (-t, 0, -1), (-t, 0, 1)]]
    f = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6), (7, 1, 8),
         (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9), (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)]
    for _ in range(sub - 1):
        cache, nf = {}, []

        def mid(a, b):
            k = (min(a, b), max(a, b))
            if k not in cache:
                p = v[a] + v[b]
                v.append(p / np.linalg.norm(p))
                cache[k] = len(v) - 1
            return cache[k]
        for a, b, c in f:
            ab, bc, ca = mid(a, b), mid(b, c), mid(c, a)
            nf += [(a, ab, ca), (b, bc, ab), (c, ca, bc), (ab, bc, ca)]
        f = nf
    return np.array(v), f


def r_blob(name, position, radii, mat, rng, subdiv=2, jitter=.10, seed_shift=0.0):
    v, f = _icosphere(subdiv)
    ph = [rng.uniform(0, 6.28) for _ in range(3)]
    out = []
    for c in v:
        lump = math.sin(c[0] * 3.1 + ph[0]) * math.sin(c[1] * 2.7 + ph[1]) * math.sin(c[2] * 3.3 + ph[2])
        k = 1 + jitter * lump + jitter * .6 * (rng.random() - .5)
        out.append([c[i] * radii[i] * k + position[i] for i in range(3)])
    return O(name, out, f, mat)


def r_paint_fn(obj, fn):
    fac = np.asarray(fn(obj.v), float)
    obj.col = obj.col * (fac[:, None] if fac.ndim == 1 else fac)


def r_hx_low(objs, fn):
    for o in objs:
        if o.v[:, 2].max() < 1.2:
            r_paint_fn(o, fn)


def r_hx_settle(center=True):
    allv = np.concatenate([o.v for o in OBJS])
    cx = (allv[:, 0].min() + allv[:, 0].max()) / 2 if center else 0.0
    cy = (allv[:, 1].min() + allv[:, 1].max()) / 2 if center else 0.0
    for o in OBJS:
        o.v[:, 0] -= cx
        o.v[:, 1] -= cy
        o.v[:, 2] = np.maximum(o.v[:, 2], 0)
    return cx, cy


# --- variación que imita la textura ----------------------------------------------------------
def _hash(p):
    return (np.sin(p @ np.array([12.9898, 78.233, 37.719])) * 43758.5453) % 1.0


# Celdas de subdivisión (vertical, horizontal en m) para las clases que llevan dibujo propio.
DICE = {"hx_tapial": (.25, 1.0), "hx_pirca": (.3, .3)}


def dice(o):
    cz, cxy = DICE[o.kind]
    rng = np.random.default_rng(len(o.v) * 7 + len(o.f))
    V, F = list(o.v), []

    def nseg(a, b):
        d = b - a
        return max(1, int(math.ceil(abs(d[2]) / cz - 1e-6)), int(math.ceil(math.hypot(d[0], d[1]) / cxy - 1e-6)))
    for face in o.f:
        if len(face) != 4:
            F.append(face)
            continue
        p = o.v[list(face)]
        nu = max(nseg(p[0], p[1]), nseg(p[3], p[2]))
        nv = max(nseg(p[1], p[2]), nseg(p[0], p[3]))
        if nu * nv == 1:
            F.append(face)
            continue
        nrm = np.cross(p[1] - p[0], p[3] - p[0])
        nrm /= max(np.linalg.norm(nrm), 1e-9)
        grid = {}
        for i in range(nu + 1):
            for j in range(nv + 1):
                s, t = i / nu, j / nv
                q = (1 - s) * (1 - t) * p[0] + s * (1 - t) * p[1] + s * t * p[2] + (1 - s) * t * p[3]
                if o.kind == "hx_pirca" and 0 < i < nu and 0 < j < nv:
                    q = q + nrm * rng.uniform(-.015, .03)          # piedras que abultan
                grid[i, j] = len(V)
                V.append(q)
        for i in range(nu):
            for j in range(nv):
                F.append((grid[i, j], grid[i + 1, j], grid[i + 1, j + 1], grid[i, j + 1]))
    col = np.ones((len(V), 3)) * o.col.mean(0)
    col[:len(o.col)] = o.col
    # interpolación simple del color base para los vértices nuevos: el más cercano de los originales
    if len(V) > len(o.v):
        newv = np.array(V[len(o.v):])
        d = ((newv[:, None, :] - o.v[None, :, :]) ** 2).sum(-1)
        col[len(o.v):] = o.col[d.argmin(1)]
    o.v, o.f, o.col = np.array(V), F, col


def pattern(kind, P, centroid, normal):
    """Factor de color por esquina de triángulo (P: Nx3, centroid y normal de la cara)."""
    n = len(P)
    h = _hash(np.round(centroid, 3)[None, :])[0]
    if kind == "hx_tapial":
        band = math.floor(centroid[2] / .5)
        t = np.clip((P[:, 2] - band * .5) / .5, 0, 1)
        tone = (.84 + .24 * t) * (1 + .07 * (_hash(np.array([[band, 3.1, 7.7]]))[0] - .5)) * (1 + .06 * (h - .5))
        return tone[:, None] * np.ones((n, 3))
    if kind == "hx_pirca":
        tone = .70 + .38 * h
        warm = _hash(np.round(centroid, 3)[None, :] + 1.7)[0]
        tint = np.array([1.0 + .06 * warm, 1.0, 1.0 - .05 * warm])
        return np.tile(tone * tint, (n, 1))
    if kind == "stone":
        return np.full((n, 3), .82 + .3 * h)
    if kind in ("hx_adobe", "hx_torta", "hx_cal"):
        return np.full((n, 3), .94 + .1 * h)
    if kind in ("wood", "planks", "hx_paja"):
        return np.full((n, 3), .9 + .18 * h)
    return np.ones((n, 3))


# --- escritura del GLB -----------------------------------------------------------------------
MATDEF = {  # (metallic, roughness)
    "hx_hierro": (.55, .6), "metal": (.6, .45), "hx_brasa": (0, .9), "anchor": (0, .5),
}


def corner_normals(o):
    """Normales por esquina con suavizado por ángulo (como el «auto smooth» de Blender)."""
    tris = []
    for face in o.f:
        for i in range(1, len(face) - 1):
            tris.append((face[0], face[i], face[i + 1]))
    T = np.array(tris)
    p = o.v[T]
    fn = np.cross(p[:, 1] - p[:, 0], p[:, 2] - p[:, 0])
    area = np.linalg.norm(fn, axis=1)
    fnu = fn / np.maximum(area, 1e-12)[:, None]
    lim = math.cos(math.radians(SMOOTH_DEG.get(o.kind, SMOOTH_DEFAULT)))
    inc = [[] for _ in range(len(o.v))]
    for ti, tri in enumerate(T):
        for vi in tri:
            inc[vi].append(ti)
    N = np.zeros((len(T), 3, 3))
    for ti, tri in enumerate(T):
        for k, vi in enumerate(tri):
            ts = [tj for tj in inc[vi] if np.dot(fnu[ti], fnu[tj]) >= lim]
            s = fn[ts].sum(0)
            ln = np.linalg.norm(s)
            N[ti, k] = s / ln if ln > 1e-12 else fnu[ti]
    return T, N, fnu


def export(name, animation_names):
    anchor = O("Anchor | importer workaround", r_sphere_pts(), _ANCHOR_F, None)
    OBJS.remove(anchor)
    OBJS.insert(0, anchor)
    for o in OBJS:
        if o.kind in DICE:
            dice(o)
    groups = {}
    for o in OBJS:
        groups.setdefault(o.kind, []).append(o)
    bin_ = bytearray()
    views, accs, prims, mats = [], [], [], []
    tris_total = 0

    def add(arr, comp, typ, target=None, minmax=False):
        nonlocal bin_
        while len(bin_) % 4:
            bin_ += b"\x00"
        views.append({"buffer": 0, "byteOffset": len(bin_), "byteLength": arr.nbytes, **({"target": target} if target else {})})
        bin_ += arr.tobytes()
        acc = {"bufferView": len(views) - 1, "componentType": comp, "count": int(arr.shape[0]), "type": typ}
        if minmax:
            acc["min"], acc["max"] = arr.min(0).tolist(), arr.max(0).tolist()
        accs.append(acc)
        return len(accs) - 1

    for kind, objs in groups.items():
        mean = CM["HX_LINMEAN"].get(kind, CM["ALBEDO_LIN"]) if kind != "anchor" else 1.0
        rows = []
        for o in objs:
            T, N, fnu = corner_normals(o)
            for ti, tri in enumerate(T):
                P = o.v[list(tri)]
                fac = pattern(kind, P, P.mean(0), fnu[ti])
                C = np.clip(o.col[list(tri)] * fac * mean, 0, 1)
                for k in range(3):
                    q, nn = P[k], N[ti, k]
                    rows.append((q[0], q[2], -q[1], nn[0], nn[2], -nn[1], C[k, 0], C[k, 1], C[k, 2]))
        R = np.array(rows, np.float32)
        tris_total += len(R) // 3 if kind != "anchor" else 0
        key = np.round(R, 5)
        uniq, inv = np.unique(key, axis=0, return_inverse=True)
        uniq = uniq.astype(np.float32)
        a_p = add(np.ascontiguousarray(uniq[:, 0:3]), 5126, "VEC3", 34962, True)
        a_n = add(np.ascontiguousarray(uniq[:, 3:6]), 5126, "VEC3", 34962)
        col4 = np.concatenate([uniq[:, 6:9], np.ones((len(uniq), 1), np.float32)], 1)
        a_c = add(np.ascontiguousarray(col4), 5126, "VEC4", 34962)
        a_i = add(inv.astype(np.uint32).ravel(), 5125, "SCALAR", 34963)
        met, rough = MATDEF.get(kind, (0.0, .9))
        mat = {"name": "PBR | " + kind, "pbrMetallicRoughness": {"baseColorFactor": [1, 1, 1, 1], "metallicFactor": met, "roughnessFactor": rough}}
        if kind == "hx_brasa":
            mat["emissiveFactor"] = [1.0, .42, .10]
        mats.append(mat)
        prims.append({"attributes": {"POSITION": a_p, "NORMAL": a_n, "COLOR_0": a_c}, "indices": a_i, "material": len(mats) - 1})
    allv = np.concatenate([o.v for o in OBJS if o.kind != "anchor"])
    mn, mx = allv.min(0).tolist(), allv.max(0).tolist()
    gltf = {"asset": {"version": "2.0", "generator": "Patria: Guemes tools/hx_models_sin_blender.py (P6, sin Blender)"},
            "scene": 0, "scenes": [{"nodes": [0]}], "nodes": [{"mesh": 0, "name": name + "_geometry"}],
            "meshes": [{"name": name + "_geometry", "primitives": prims}], "materials": mats,
            "accessors": accs, "bufferViews": views, "buffers": [{"byteLength": len(bin_)}]}
    js = json.dumps(gltf, ensure_ascii=False).encode("utf-8")
    js += b" " * ((4 - len(js) % 4) % 4)
    while len(bin_) % 4:
        bin_ += b"\x00"
    data = (struct.pack("<III", 0x46546C67, 2, 28 + len(js) + len(bin_)) + struct.pack("<II", len(js), 0x4E4F534A) + js
            + struct.pack("<II", len(bin_), 0x004E4942) + bytes(bin_))
    target = OUT / (name + ".glb")
    target.write_bytes(data)
    REPORT[name] = {"file": target.name, "bytes": len(data), "triangles_base_mesh": tris_total, "animations_expected": [],
                    "animations_exported": [], "mesh_count": 1, "surfaces": len(prims), "materials": [m["name"] for m in mats],
                    "textures": 0, "vertex_colors": True, "sha256": hashlib.sha256(data).hexdigest(),
                    "blender_bounds": {"min": mn, "max": mx},
                    "godot_bounds": {"min": [mn[0], mn[2], -mx[1]], "max": [mx[0], mx[2], -mn[1]]}, "front": "Godot -Z",
                    "provenance": "Own procedural geometry (hx_* builders of tools/create_models.py) exported WITHOUT Blender by "
                                  "tools/hx_models_sin_blender.py: vertex colour only, no PBR textures. Artistic reconstruction."}
    print("ASSET_READY", name, json.dumps({k: REPORT[name][k] for k in ("bytes", "triangles_base_mesh", "surfaces")}))


def r_sphere_pts():
    v = np.array([(0, 0, -1), (1, 0, 0), (-.5, .87, 0), (-.5, -.87, 0), (0, 0, 1)]) * .001 + np.array([0, 0, .002])
    return v


_ANCHOR_F = [(0, 2, 1), (0, 3, 2), (0, 1, 3), (4, 1, 2), (4, 2, 3), (4, 3, 1)]

for _k, _fn in dict(reset=r_reset, mesh=r_mesh, box=r_box, rbox=r_rbox, segment=r_segment, sphere=r_sphere, torus=r_torus,
                    tube=r_tube, blob=r_blob, paint_fn=r_paint_fn, hx_low=r_hx_low, hx_settle=r_hx_settle,
                    _image=lambda name, arr, color=True: arr, export=export, kind_material=lambda kind: None,
                    hx_ember_material=lambda: None).items():
    CM[_k] = _fn


def main():
    manifest = OUT / "model_manifest.json"
    data = json.loads(manifest.read_text(encoding="utf-8")) if manifest.is_file() else {}
    for name, builder in CM["HX_BUILDERS"].items():
        if ONLY and name not in ONLY:
            continue
        builder()
        REPORT[name]["historical_note"] = CM["NOTES"].get(name, "")
        data[name] = REPORT[name]
    manifest.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("ALL_MODELS_READY")


if __name__ == "__main__":
    main()
