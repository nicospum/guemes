"""visual/r1 F4 - caballos criollos (paso 1: tuberia de assets). Blender 4.4.x en linea de comandos.

    blender -b --disable-autoexec --factory-startup --python tools/f4_caballos.py -- \
        --src ../materiales-privados/f4_caballos/fuentes/riggedHorse.blend [--only caballo,jinete] [--out assets/models]
        [--coats zaino,alazan] [--diag]   (--diag: imprime los cuadros donde el casco no sigue su trayectoria)

Fuente de la malla del caballo (unica pieza de terceros): «Rigged Horse», modelo de Lyndon Daniels («Realtime Ranchers
3D model pack») con esqueleto de ChadM, OpenGameArt, licencia CC0 (https://opengameart.org/content/rigged-horse).
Del .blend se toma SOLO la malla «Plane» (cuerpo), cargada con bpy.data.libraries.load: no se abren escenas, textos ni
scripts del archivo, ni se usan sus texturas (fotograficas) ni su esqueleto. Todo lo demas es obra propia de este script:
escala y orientacion, esqueleto, pesos, crin tusada, cola, recado, cabezada, pelajes (color por vertice con oclusion
calculada aca), los ciclos idle/walk/trot/gallop (claves procedurales, NO captura de movimiento) y el LOD de tropa.
El jinete sale de `mounted_rider()` de tools/create_models.py (obra propia del proyecto), que se ejecuta sin modificar
(se lee el archivo y se omite su llamada final a main()).

Convenciones (las mismas de create_models.py): metros, Blender +Y = frente (Godot -Z), Z arriba (Godot Y), origen en el
suelo entre los cuatro cascos. Cruz (withers) a 1,45 m. Sin texturas: un COLOR_0 lineal con el color final.
Salidas en assets/models/:
  caballo_criollo_<pelaje>.glb      jefe: esqueleto + idle/walk/trot/gallop, con recado (<= 15k tri)
  caballo_criollo_<pelaje>_lod.glb  tropa: malla estatica en pose de reposo, con recado simple (<= 3k tri con jinete)
  jinete_criollo_<1806|1817>.glb, ..._lod.glb   jinete sin caballo, origen en el asiento (hueso «silla»)
  f4_caballos_manifest.json         triangulos, huesos, animaciones, cotas y sha256
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


SRC = Path(_arg("--src", str(ROOT.parent / "materiales-privados" / "f4_caballos" / "fuentes" / "riggedHorse.blend")))
OUT = Path(_arg("--out", str(ROOT / "assets" / "models")))
# visual/r1 F5: los jinete_criollo_*.glb los hace ahora tools/f5_personas.py; «jinete» acá regenera los viejos de F4
# (create_models) y pisaría los nuevos: solo a pedido explícito.
ONLY = (_arg("--only") or "caballo").split(",")
FPS = 24
WITHERS = 1.45
SEAT = Vector((0.0, 0.0, 1.50))          # punto del asiento (cima del cojinillo); Godot (0, 1.50, 0)
REPORT = {}

# Pelajes (sRGB). Etiqueta «diseño»: aproximaciones de lectura, no mediciones. La base del zaino es la de
# data/justina_map.json -> palette.mounts. visual/r1 F4b (diseño): el alazán deja la base #8A5A3A de ese mismo mapa
# (de noche, en Humahuaca, se leía rojizo, casi rosado, y se podía confundir con el rojo del enemigo): ahora es un alazán
# tostado, más pardo y menos saturado (tono 24° -> 28°, saturación 0,58 -> 0,47), que sigue más claro y cálido que el zaino.
COATS = {
    "zaino":    {"base": "#4A3A2D", "points": "#17120E", "mane": "#120E0B", "muzzle": "#241C16", "hoof": "#2A231D"},
    "alazan":   {"base": "#785A40", "points": None,      "mane": "#5C4230", "muzzle": "#4A3729", "hoof": "#3A3027",
                 "star": True, "socks": ["HL"]},
    "tordillo": {"base": "#9A958B", "points": "#5E5A54", "mane": "#C9C5BC", "muzzle": "#3E3B37", "hoof": "#3A3530",
                 "dapple": "#6F6B64"},
    "overo":    {"base": "#7A4A2E", "points": None,      "mane": "#5A3A26", "muzzle": "#C9B9A0", "hoof": "#8A7A62",
                 "white": "#E6DFD0", "blaze": True, "socks": ["FL", "FR", "HL", "HR"]},
}
TACK = {
    "cuero": "#3B2618", "cuero_claro": "#6A4A30", "jerga": "#6B5A45", "jerga_franja": "#3F3428",
    "jerga_roja": "#5E2A20", "vellon": "#D2C6A8", "metal": "#4A4A46", "madera": "#5A3D24",
}


def lin(h):
    h = h.lstrip("#")
    c = np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


# --------------------------------------------------------------------------------------
# Escena y materiales
# --------------------------------------------------------------------------------------
def reset():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.armatures, bpy.data.actions, bpy.data.materials, bpy.data.curves):
        for b in list(coll):
            coll.remove(b)
    bpy.context.scene.render.fps = FPS


_MATS = {}


def vc_material(name, rough=0.85, metal=0.0):
    """Material sin texturas: COLOR_0 -> albedo. El nombre termina en la «clase» que lee world_view.gd."""
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


def col_attr(me):
    a = me.color_attributes.get("Col")
    if a is None:
        a = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    me.color_attributes.active_color = a
    return a


def set_loop_colors(obj, per_vertex_rgb):
    me = obj.data
    a = col_attr(me)
    vi = np.empty(len(me.loops), np.int32)
    me.loops.foreach_get("vertex_index", vi)
    rgba = np.ones((len(me.loops), 4), np.float32)
    rgba[:, :3] = per_vertex_rgb[vi]
    a.data.foreach_set("color", rgba.ravel())


def new_obj(name, verts, faces, mat, color, smooth=True):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], [tuple(f) for f in faces])
    me.update()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    me.materials.append(mat)
    for p in me.polygons:
        p.use_smooth = smooth
    c = np.asarray(color, np.float32)
    if c.ndim == 1:
        c = np.tile(c, (len(me.vertices), 1))
    set_loop_colors(o, c)
    return o


def verts_np(obj):
    me = obj.data
    co = np.empty(len(me.vertices) * 3, np.float32)
    me.vertices.foreach_get("co", co)
    return co.reshape(-1, 3)


def tri_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


# --------------------------------------------------------------------------------------
# Primitivas propias (tubos, cajas, aros alrededor de la malla)
# --------------------------------------------------------------------------------------
def tube(name, pts, radius, mat, color, sides=8, flat=1.0, caps=True):
    """Tubo por una polilínea; radius escalar o lista; flat<1 aplasta la sección (cintas)."""
    pts = [Vector(p) for p in pts]
    n = len(pts)
    rad = radius if isinstance(radius, (list, tuple)) else [radius] * n
    verts, faces = [], []
    up = Vector((0, 0, 1))
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        side = t.cross(up)
        if side.length < 1e-4:
            side = t.cross(Vector((0, 1, 0)))
        side.normalize()
        nrm = side.cross(t).normalized()
        for k in range(sides):
            a = 2 * math.pi * k / sides
            verts.append(p + side * math.cos(a) * rad[i] + nrm * math.sin(a) * rad[i] * flat)
    for i in range(n - 1):
        for k in range(sides):
            a, b = i * sides + k, i * sides + (k + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    if caps:
        faces.append(tuple(reversed(range(sides))))
        faces.append(tuple(range((n - 1) * sides, n * sides)))
    return new_obj(name, verts, faces, mat, color)


def box(name, c, s, mat, color, rot_x=0.0):
    c = Vector(c)
    hx, hy, hz = s[0] / 2, s[1] / 2, s[2] / 2
    R = Matrix.Rotation(rot_x, 3, "X")
    vs = [c + R @ Vector((x, y, z)) for x in (-hx, hx) for y in (-hy, hy) for z in (-hz, hz)]
    fs = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    return new_obj(name, vs, fs, mat, color, smooth=False)


def hull2d(p):
    p = sorted(set(map(tuple, np.round(p, 5))))
    if len(p) < 3:
        return p

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lo, up = [], []
    for q in p:
        while len(lo) >= 2 and cross(lo[-2], lo[-1], q) <= 0:
            lo.pop()
        lo.append(q)
    for q in reversed(p):
        while len(up) >= 2 and cross(up[-2], up[-1], q) <= 0:
            up.pop()
        up.append(q)
    return lo[:-1] + up[:-1]


def section_ring(co, origin, normal, slab=0.02, grow=0.012, n=20, keep=None):
    """Contorno convexo de la malla en un plano, agrandado `grow` m: sirve para cinchas, cabezada, bozal."""
    origin, normal = np.asarray(origin, float), np.asarray(normal, float) / np.linalg.norm(normal)
    d = (co - origin) @ normal
    s = co[np.abs(d) < slab]
    if keep is not None:
        s = s[keep(s)]
    u = np.cross(normal, [1.0, 0, 0])
    if np.linalg.norm(u) < 1e-3:
        u = np.cross(normal, [0, 0, 1.0])
    u /= np.linalg.norm(u)
    v = np.cross(normal, u)
    p2 = np.stack([(s - origin) @ u, (s - origin) @ v], 1)
    h = np.array(hull2d(p2))
    c = h.mean(0)
    # remuestreo por ángulo para un aro parejo
    ang = np.arctan2(h[:, 1] - c[1], h[:, 0] - c[0])
    order = np.argsort(ang)
    h, ang = h[order], ang[order]
    out = []
    for a in np.linspace(-math.pi, math.pi, n, endpoint=False):
        dirv = np.array([math.cos(a), math.sin(a)])
        r = max(((q - c) @ dirv) for q in h)  # soporte de la envolvente convexa
        q2 = c + dirv * (r + grow)
        out.append(origin + u * q2[0] + v * q2[1])
    return out


# --------------------------------------------------------------------------------------
# Caballo: malla fuente normalizada
# --------------------------------------------------------------------------------------
def load_body():
    with bpy.data.libraries.load(str(SRC), link=False) as (df, dt):
        if "Plane" not in df.meshes:
            raise SystemExit("La fuente no tiene la malla 'Plane' (riggedHorse.blend de OpenGameArt)")
        dt.meshes = ["Plane"]
    me = dt.meshes[0]
    me.name = "caballo_cuerpo"
    co = np.array([v.co[:] for v in me.vertices])
    zmin = co[:, 2].min()
    # cruz de la fuente: máximo de la línea dorsal entre los hombros (y de la fuente en [-2.8, -2.0])
    sel = (co[:, 1] > -2.8) & (co[:, 1] < -2.0)
    k = WITHERS / (co[sel, 2].max() - zmin)
    co[:, 2] -= zmin
    co[:, :2] *= -1.0                      # 180 grados en Z: la cabeza pasa a +Y
    co *= k
    feet = co[co[:, 2] < 0.05]
    co[:, 1] -= (feet[:, 1].min() + feet[:, 1].max()) / 2   # origen entre los cascos
    co[:, 0] -= (co[:, 0].min() + co[:, 0].max()) / 2
    me.vertices.foreach_set("co", co.astype(np.float32).ravel())
    for uv in list(me.uv_layers):
        me.uv_layers.remove(uv)
    me.materials.clear()
    o = bpy.data.objects.new("caballo_cuerpo", me)
    bpy.context.collection.objects.link(o)
    o.vertex_groups.clear()
    if me.shape_keys:
        o.shape_key_clear()
    me.materials.append(vc_material("F4 | pelaje"))
    for p in me.polygons:
        p.use_smooth = True
    me.update()
    return o, k


def top_line(co, y0, y1, n, xw=0.05):
    out = []
    for y in np.linspace(y0, y1, n):
        dy = .03
        s = co[(np.abs(co[:, 1] - y) < dy) & (np.abs(co[:, 0]) < xw)]
        while len(s) == 0:   # malla rala en el lomo: se agranda la ventana
            dy *= 1.5
            s = co[(np.abs(co[:, 1] - y) < dy) & (np.abs(co[:, 0]) < xw * 1.5)]
        out.append((y, s[:, 2].max()))
    return out


# --------------------------------------------------------------------------------------
# Esqueleto propio (huesos en castellano). Todos con eje X local = +X del mundo, salvo los que miran hacia atrás.
# --------------------------------------------------------------------------------------
LEGS = {
    # pierna: (hombro/cadera, codo/babilla, rodilla/corvejón, menudillo, casco)
    "FL": [(-.20, .60, .98), (-.22, .44, .76), (-.23, .36, .42), (-.23, .31, .14), (-.23, .33, .0)],
    "FR": [(.20, .60, .98), (.22, .44, .76), (.23, .36, .42), (.23, .31, .14), (.23, .33, .0)],
    "HL": [(-.17, -.50, 1.15), (-.19, -.36, .80), (-.17, -.58, .52), (-.17, -.44, .14), (-.16, -.40, .0)],
    "HR": [(.17, -.50, 1.15), (.19, -.36, .80), (.17, -.58, .52), (.17, -.44, .14), (.16, -.40, .0)],
}
SEG = ["sup", "inf", "cana", "cuartilla"]


def build_rig(co):
    neck = top_line(co, .55, 1.18, 4)
    bones = [
        ("raiz", (0, 0, 0), (0, .3, 0), None, False),
        ("cuerpo", (0, -.10, 1.05), (0, .45, 1.10), "raiz", True),
        ("grupa", (0, -.10, 1.05), (0, -.62, 1.18), "cuerpo", True),
        ("cuello", (0, .60, 1.20), (0, .90, 1.42), "cuerpo", True),
        ("cuello2", (0, .90, 1.42), (0, 1.17, 1.55), "cuello", True),
        ("cabeza", (0, 1.17, 1.55), (0, 1.42, 1.12), "cuello2", True),
        ("cola", (0, -.84, 1.22), (0, -.96, .98), "grupa", True),
        ("cola2", (0, -.96, .98), (0, -1.0, .60), "cola", True),
        ("silla", tuple(SEAT), tuple(SEAT + Vector((0, 0, .3))), "cuerpo", False),
    ]
    for leg, pts in LEGS.items():
        parent = "cuerpo" if leg[0] == "F" else "grupa"
        for i, s in enumerate(SEG):
            bones.append((f"{leg}_{s}", pts[i], pts[i + 1], parent if i == 0 else f"{leg}_{SEG[i - 1]}", True))
    data = bpy.data.armatures.new("esqueleto_caballo")
    rig = bpy.data.objects.new("esqueleto_caballo", data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for nm, h, t, par, deform in bones:
        eb = data.edit_bones.new(nm)
        eb.head, eb.tail = Vector(h), Vector(t)
        eb.use_deform = deform
        if nm == "silla":
            eb.align_roll(Vector((0, -1, 0)))   # base global = identidad en Godot (X der., Y arriba, Z atrás)
        elif abs((eb.tail - eb.head).normalized().z) > .7:
            eb.align_roll(Vector((0, 1, 0)))    # huesos verticales: Z local hacia adelante -> X local = +X
        else:
            eb.align_roll(Vector((0, 0, 1)))
        if par:
            eb.parent = data.edit_bones[par]
            eb.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in rig.pose.bones:
        pb.rotation_mode = "XYZ"
    return rig


def skin(obj, rig, rigid_bone=None):
    obj.parent = rig
    obj.matrix_parent_inverse = Matrix.Identity(4)
    if rigid_bone:
        g = obj.vertex_groups.new(name=rigid_bone)
        g.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    m = obj.modifiers.new("esqueleto", "ARMATURE")
    m.object = rig


def auto_weights(objs, rig):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    bad = [o.name for o in objs if len(o.vertex_groups) == 0]
    if bad:
        raise SystemExit("Pesos automáticos fallaron en " + ",".join(bad))
    # sin pesos sueltos: cada vértice debe tener al menos un hueso
    for o in objs:
        miss = [v.index for v in o.data.vertices if not v.groups or sum(g.weight for g in v.groups) < 1e-4]
        if miss:
            g = o.vertex_groups.get("cuerpo") or o.vertex_groups.new(name="cuerpo")
            g.add(miss, 1.0, "REPLACE")
        print(f"PESOS {o.name}: {len(o.vertex_groups)} grupos, {len(miss)} vértices reasignados a 'cuerpo'")


# --------------------------------------------------------------------------------------
# Pelaje: oclusión propia + máscaras por posición
# --------------------------------------------------------------------------------------
def occlusion(points, normals, bvh, rays=24, dist=.45, seed=7):
    rng = np.random.default_rng(seed)
    d = rng.normal(size=(rays, 3))
    d /= np.linalg.norm(d, axis=1)[:, None]
    out = np.empty(len(points))
    for i, (p, n) in enumerate(zip(points, normals)):
        nv = Vector(n)
        hits = 0
        for r in d:
            rv = Vector(r)
            if rv.dot(nv) < 0:
                rv = -rv
            hit = bvh.ray_cast(Vector(p) + nv * .004, rv, dist)
            if hit[0] is not None:
                hits += 1
        out[i] = 1.0 - .75 * hits / rays
    return out


def vnoise3(p, freq, seed):
    rng = np.random.default_rng(seed)
    acc = np.zeros(len(p))
    for k in range(6):
        d = rng.normal(size=3)
        d /= np.linalg.norm(d)
        acc += np.sin(p @ d * freq * (1 + .37 * k) + rng.uniform(0, 6.28)) / (1 + .5 * k)
    return acc / 2.2


def coat_colors(co, nrm, ao, coat):
    c = COATS[coat]
    base = np.tile(lin(c["base"]), (len(co), 1))
    z, y, x = co[:, 2], co[:, 1], co[:, 0]
    if "dapple" in c:   # tordillo: anillos oscuros sobre el gris, más claros en el lomo
        dn = vnoise3(co, 17.0, 11)
        ring = .85 * smoothstep(.10, .40, np.abs(dn)) * smoothstep(.55, 1.0, z)
        base = base * (1 - ring[:, None]) + lin(c["dapple"]) * ring[:, None]
        head = smoothstep(1.05, 1.30, y)  # cabeza algo más oscura en los tordillos jóvenes
        base = base * (1 - .35 * head[:, None]) + lin(c["dapple"]) * .35 * head[:, None]
    if c.get("points"):  # cabos negros: de la rodilla y el corvejón para abajo
        knee = np.where(y > 0, .44, .52)
        pm = smoothstep(knee + .06, knee - .06, z)
        base = base * (1 - pm[:, None]) + lin(c["points"]) * pm[:, None]
    if "white" in c:     # overo: manchas blancas irregulares, más en vientre, cuello y patas
        bias = .35 * smoothstep(.95, .62, z) + .25 * smoothstep(.85, 1.15, y) - .15 * smoothstep(1.2, 1.4, z)
        wm = smoothstep(-.05, .10, vnoise3(co, 7.5, 23) + bias - .30)
        base = base * (1 - wm[:, None]) + lin(c["white"]) * wm[:, None]
    white = lin(c.get("white", "#E6DFD0"))
    for leg in c.get("socks", []):
        lx, ly = LEGS[leg][4][0], LEGS[leg][4][1]
        sm = smoothstep(.24, .16, z) * ((np.abs(x - lx) < .14) & (np.abs(y - ly) < .2))
        base = base * (1 - sm[:, None]) + white * sm[:, None]
    face = (y > 1.15) & (np.abs(x) < .045 + .02 * (y - 1.15))
    if c.get("blaze"):
        fm = face & (nrm[:, 2] > -.2)
        base[fm] = white
    elif c.get("star"):
        sm = (np.linalg.norm(co - np.array([0, 1.22, 1.50]), axis=1) < .05) & (nrm[:, 1] > 0)
        base[sm] = white
    mz = smoothstep(.13, .05, np.linalg.norm(co - np.array([0, 1.43, 1.12]), axis=1))
    base = base * (1 - mz[:, None]) + lin(c["muzzle"]) * mz[:, None]
    ear = smoothstep(1.60, 1.66, z) * (y > 1.0)
    base = base * (1 - .6 * ear[:, None]) + lin(c["mane"]) * .6 * ear[:, None]
    hoof = smoothstep(.065, .045, z)
    base = base * (1 - hoof[:, None]) + lin(c["hoof"]) * hoof[:, None]
    shade = (.86 + .2 * smoothstep(.7, 1.4, z)) * ao
    return np.clip(base * shade[:, None], 0, 1)


def color_body(body, hi_bvh, coat):
    me = body.data
    co = verts_np(body)
    nrm = np.empty(len(me.vertices) * 3, np.float32)
    me.vertices.foreach_get("normal", nrm)
    nrm = nrm.reshape(-1, 3)
    ao = occlusion(co, nrm, hi_bvh)
    set_loop_colors(body, coat_colors(co, nrm, ao, coat))


# --------------------------------------------------------------------------------------
# Apoyo sobre la piel: rayos desde adentro del cuerpo hacia afuera (la primera pared es la piel)
# --------------------------------------------------------------------------------------
def cast_out(bvh, center, direction, d=0.0):
    c, dv = Vector(center), Vector(direction).normalized()
    loc = bvh.ray_cast(c, dv, 3.0)[0]
    return None if loc is None else loc + dv * d


def ring_around(bvh, center, axis, n, d, a0=0.0, a1=2 * math.pi, closed=True):
    ax = Vector(axis).normalized()
    u = Vector((1, 0, 0)) - ax * ax.x
    u.normalize()
    v = ax.cross(u)
    out = []
    for k in range(n + (0 if closed else 1)):
        a = a0 + (a1 - a0) * k / n
        p = cast_out(bvh, center, u * math.cos(a) + v * math.sin(a), d)
        if p is not None:
            out.append(p)
    if closed:
        out.append(out[0])
    return out


def neck_axis(t):
    """Eje del cuello, t=0 en la cruz, t=1 en la nuca."""
    p0, p1 = Vector((0, .45, 1.12)), Vector((0, 1.15, 1.50))
    return p0.lerp(p1, t)


def drape(bvh, ys, thetas, d, cz=1.0):
    """Grilla que copia el lomo: para cada y, rayos en el plano XZ a ángulo theta de la vertical."""
    return [[cast_out(bvh, (0, y, cz), (math.sin(t), 0, math.cos(t)), d) for t in thetas] for y in ys]


def grid_obj(name, grid, mat, colors, thick=0.0):
    nu = len(grid[0])
    verts = [p for row in grid for p in row]
    faces = [(i * nu + j, (i + 1) * nu + j, (i + 1) * nu + j + 1, i * nu + j + 1) for i in range(len(grid) - 1) for j in range(nu - 1)]
    o = new_obj(name, verts, faces, mat, colors)
    if thick:
        s = o.modifiers.new("espesor", "SOLIDIFY")
        s.thickness = thick
        s.offset = 0.0
    return o


# --------------------------------------------------------------------------------------
# Crin tusada, copete y cola (propios)
# --------------------------------------------------------------------------------------
def mane_and_tail(bvh, coat, lod=False):
    c = COATS[coat]
    hair = lin(c["mane"])
    out = []
    ndir = (neck_axis(1) - neck_axis(0)).normalized()
    up = Vector((0, -ndir.z, ndir.y))           # perpendicular al cuello, hacia la crin
    n = 7 if lod else 14
    crest = [cast_out(bvh, neck_axis(.06 + .9 * i / (n - 1)), up, -.012) for i in range(n)]
    crest = [crest[0]] + [(crest[i - 1] + crest[i] * 2 + crest[i + 1]) / 4 for i in range(1, n - 1)] + [crest[-1]]
    verts, faces = [], []
    for i, p in enumerate(crest):
        h = .045 + .02 * math.sin(math.pi * i / (n - 1))  # tusada: cepillo corto y parejo, algo más alto al medio
        verts += [p + Vector((-.02, 0, 0)), p + up * h + Vector((0, -.012, 0)), p + Vector((.02, 0, 0))]
    for i in range(n - 1):
        a = i * 3
        faces += [(a, a + 3, a + 4, a + 1), (a + 1, a + 4, a + 5, a + 2), (a + 2, a + 5, a + 3, a)]
    faces += [(0, 1, 2), (len(verts) - 1, len(verts) - 2, len(verts) - 3)]
    out.append(new_obj("crin_tusada", verts, faces, vc_material("F4 | pelaje"), hair))
    poll = crest[-1]
    out.append(tube("copete", [poll + Vector((0, -.01, .015)), poll + Vector((0, .06, .0)), poll + Vector((0, .1, -.07))],
                    [.028, .022, .01], vc_material("F4 | pelaje"), hair, sides=5 if lod else 7, flat=.6))
    tail = [(0, -.83, 1.22), (0, -.90, 1.13), (0, -.95, .98), (0, -.98, .82), (0, -.99, .66), (0, -.98, .52), (0, -.96, .42)]
    rad = [.045, .05, .065, .075, .08, .075, .045]
    if lod:
        tail, rad = tail[::2], rad[::2]
    tc = hair if coat != "overo" else lin(COATS["overo"]["white"]) * .9
    out.append(tube("cola", tail, rad, vc_material("F4 | pelaje"), tc, sides=6 if lod else 10, flat=.8))
    return out


# --------------------------------------------------------------------------------------
# Recado criollo simplificado (propio): jerga, carona, bastos, cojinillo (vellón), cincha, arciones y estribos de palo;
# cabezada con bozal, freno y riendas. Sin pretal, sin montura inglesa ni hebillas modernas.
# --------------------------------------------------------------------------------------
def recado(bvh, lod=False):
    T = {k: lin(v) for k, v in TACK.items()}
    m_lana, m_cuero = vc_material("F4 | lana"), vc_material("F4 | cuero", .7)
    m_metal, m_madera = vc_material("F4 | metal", .45, .6), vc_material("F4 | madera", .8)
    out = []
    r = math.radians
    # jerga: manta tejida a franjas con guarda roja
    ys = np.linspace(-.32, .36, 5 if lod else 9)
    th = np.linspace(r(-78), r(78), 7 if lod else 13)
    g = drape(bvh, ys, th, .010)
    cols = []
    for i in range(len(ys)):
        for j in range(len(th)):
            edge = j in (0, len(th) - 1) or i in (0, len(ys) - 1)
            cols.append(T["jerga_roja"] if edge else (T["jerga_franja"] if (i + j // 3) % 3 == 0 else T["jerga"]))
    out.append(grid_obj("recado_jerga", g, m_lana, np.array(cols), .012))
    # carona de cuero encima, más corta
    g = drape(bvh, np.linspace(-.25, .29, 4 if lod else 7), np.linspace(r(-64), r(64), 6 if lod else 11), .024)
    out.append(grid_obj("recado_carona", g, m_cuero, T["cuero"], .008))
    # bastos: dos rollos a los lados del espinazo
    yb = np.linspace(-.22, .27, 4 if lod else 7)
    for sx in (-1, 1):
        pts = [cast_out(bvh, (0, y, 1.0), (sx * math.sin(r(16)), 0, math.cos(r(16))), .075) for y in yb]
        out.append(tube("recado_basto", pts, .05, m_cuero, T["cuero_claro"], sides=6 if lod else 10, flat=.8))
    # cojinillo: vellón que cubre los bastos; su cara de arriba en y=SEAT.y queda a SEAT.z (el asiento del jinete)
    top0 = cast_out(bvh, (0, SEAT.y, 1.0), (0, 0, 1), 0).z
    dmid = SEAT.z - top0 - .025
    ycj = np.linspace(-.24, .26, 4 if lod else 8)
    thc = np.linspace(r(-46), r(46), 6 if lod else 11)
    g = [[p if abs(t) < r(20) else p for p, t in zip(row, thc)] for row in drape(bvh, ycj, thc, dmid)]
    # aplanar la cima (el vellón se apoya en los bastos y no copia el espinazo)
    flat_g = []
    for row in g:
        zc = max(p.z for p in row)
        flat_g.append([Vector((p.x, p.y, max(p.z, zc - .06 * (p.x / .25) ** 2 * 1.0))) for p in row])
    out.append(grid_obj("recado_cojinillo", flat_g, m_lana, T["vellon"], .05))
    if not lod:  # mechones del vellón por los bordes
        for i, row in enumerate(flat_g[1:-1]):
            for p in (row[0], row[-1]):
                sx = 1 if p.x > 0 else -1
                ln = .03 + .015 * ((i * 7 + (sx > 0) * 3) % 3)
                out.append(tube("recado_vellon_mechon", [p + Vector((0, 0, .01)), p + Vector((sx * .02, .01, -ln))], [.03, .012], m_lana, T["vellon"] * .93, sides=5))
    # cincha de cuero crudo, detrás del codo
    out.append(tube("recado_cincha", ring_around(bvh, (0, .20, .98), (0, 1, .15), 12 if lod else 22, .014),
                    .04, m_cuero, T["cuero_claro"], sides=4, flat=.25, caps=False))
    if lod:
        return out
    # arciones (correas) y estribos de palo, donde apoya el pie del jinete
    for sx in (-1, 1):
        top_p = cast_out(bvh, (0, .10, 1.0), (sx * math.sin(r(50)), 0, math.cos(r(50))), .06)
        out.append(tube("recado_arcion", [top_p, top_p + Vector((sx * .05, .06, -.2)), Vector((sx * .37, .27, .75))], .012, m_cuero, T["cuero"], sides=4))
        tri = [(sx * .37, .21, .74), (sx * .37, .33, .74), (sx * .37, .27, .66), (sx * .37, .21, .74)]
        out.append(tube("recado_estribo", tri, .014, m_madera, T["madera"], sides=5, caps=False))
    # cabezada: nuca, bozal, carrilleras; freno con argollas; riendas que caen sobre el cuello hasta el recado
    P, M = Vector((0, 1.17, 1.56)), Vector((0, 1.43, 1.12))
    ax = (M - P).normalized()
    nuca = ring_around(bvh, P + ax * .05, ax, 16, .008)
    bozal = ring_around(bvh, P + ax * .34, ax, 16, .008)
    out.append(tube("cabezada_nuca", nuca, .011, m_cuero, T["cuero"], sides=4, caps=False))
    out.append(tube("cabezada_bozal", bozal, .011, m_cuero, T["cuero"], sides=4, caps=False))
    for sx in (-1, 1):
        a = max(nuca, key=lambda p: sx * p.x)
        b = max(bozal, key=lambda p: sx * p.x)
        out.append(tube("cabezada_carrillera", [a, a.lerp(b, .5) + Vector((sx * .006, 0, 0)), b], .01, m_cuero, T["cuero"], sides=4))
        bit = cast_out(bvh, P + ax * .43, (sx, 0, 0), .012)
        ring = [bit + Vector((0, .025 * math.cos(k * math.pi / 3), .025 * math.sin(k * math.pi / 3))) for k in range(7)]
        out.append(tube("freno_argolla", ring, .006, m_metal, T["metal"], sides=4, caps=False))
        neck = [cast_out(bvh, neck_axis(t), (sx * math.sin(r(a)), 0, math.cos(r(a))), .012) for t, a in ((.80, 75), (.55, 62), (.28, 55))]
        pommel = Vector((sx * .06, .30, SEAT.z - .02))
        out.append(tube("riendas", [bit + Vector((0, -.01, 0)), *neck, pommel], .008, m_cuero, T["cuero"], sides=4))
    return out


# --------------------------------------------------------------------------------------
# Andares: claves propias por fórmula (diseño, no captura).
# visual/r1 F4b: el casco ya no sale de ángulos sueltos sino de una trayectoria: en el apoyo el casco queda en el suelo y
# retrocede a la velocidad del andar (barrido = velocidad · apoyo · ciclo); en el vuelo vuelve adelante alzándose. Los
# ángulos de cada articulación se resuelven acá con cinemática inversa numérica (mínimos cuadrados amortiguados) sobre el
# esqueleto y los pesos reales del casco, y se guardan como claves de rotación: el GLB no lleva IK. Así el tranco es el de
# un caballo de 1,45 m (antes, la mitad) y ningún casco baja del suelo (antes, hasta 9 a 13 cm en el paso y el galope).
# --------------------------------------------------------------------------------------
GAITS = {
    # nombre: (cuadros, fases (desfase de cada pata; apoya cuando (t + desfase) mod 1 = 0), apoyo, velocidad m/s de diseño,
    #          alzada delante y detrás (m), sube-baja (m), cabeceo (rad), vueltas de sube-baja por ciclo, centro del apoyo
    #          delante y detrás respecto del casco en reposo (m), baja del cuerpo (m))
    # Velocidades objetivo (visual/r1 F4b, diseño, órdenes de magnitud de un caballo de 1,45 m de cruz): paso ≈ 1,6,
    # trote ≈ 3,3, galope ≈ 7 m/s; medidas sobre el GLB dan 1,60 / 3,30 / 7,00. Orden de pisadas: paso LH LF RH RF; trote en diagonales; galope transverso a la izquierda
    # (HR HL FR FL) con un tiempo de suspensión.
    "walk":   (26, {"HL": 0.0, "FL": .75, "HR": .5, "FR": .25}, .58, 1.6, (.13, .13), .022, .03, 2, (.18, -.14), .03),
    "trot":   (18, {"FL": 0.0, "HR": 0.0, "FR": .5, "HL": .5}, .37, 3.3, (.30, .25), .035, .025, 2, (.19, -.18), .04),
    "gallop": (14, {"HR": 0.0, "HL": .86, "FR": .64, "FL": .50}, .27, 7.0, (.30, .22), .05, .07, 1, (.17, -.12), .05),
}


def key(rig, bone, frame, rot=None, loc=None):
    pb = rig.pose.bones[bone]
    if rot is not None:
        pb.rotation_euler = rot
        pb.keyframe_insert("rotation_euler", frame=frame, group=bone)
    if loc is not None:
        pb.location = loc
        pb.keyframe_insert("location", frame=frame, group=bone)


def _rx(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0, 0], [0, c, -s, 0], [0, s, c, 0], [0, 0, 0, 1.0]])


def _rz(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0, 0], [s, c, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1.0]])


def _tr(v):
    m = np.eye(4)
    m[:3, 3] = v
    return m


class LegIK:
    """visual/r1 F4b: cinemática directa e inversa de una pata, con el mismo esqueleto y los mismos pesos que exporta el GLB.
    Variables: rotación X local de sup, inf, caña y cuartilla (como las claves) y un corrimiento del hombro o la cadera hacia
    adelante o atrás (la escápula y la pelvis acompañan el tranco; tope ±8 cm). Medidas del casco = las de la prueba: centro
    del casco en Y y punto más bajo en Z."""
    LIMITS = {"F": [(-1.2, 1.2), (-.10, 1.6), (-2.0, .02), (-1.6, .40)], "H": [(-1.2, 1.2), (-1.6, .35), (-.35, 2.0), (-1.6, .40)]}

    def __init__(self, rig, mesh, leg):
        self.leg = leg
        self.A = {b.name: np.array(b.matrix_local) for b in rig.data.bones}
        self.Ai = {k: np.linalg.inv(v) for k, v in self.A.items()}
        self.bones = [f"{leg}_{s}" for s in SEG]
        self.parent = "cuerpo" if leg[0] == "F" else "grupa"
        hx, hy = LEGS[leg][4][0], LEGS[leg][4][1]
        co = verts_np(mesh)
        # todo el casco y la corona (hasta 14 cm; el posterior de la malla es largo, de la pinza a los talones) para que
        # ningún punto baje del suelo al rodar sobre la pinza; el centro se mide con la suela (z < 5 cm), como la prueba
        sel = np.where((co[:, 2] < .14) & (np.abs(co[:, 0] - hx) < .13) & (co[:, 0] * hx > 0)
                       & (np.abs(co[:, 1] - hy) < (.16 if leg[0] == "F" else .24)))[0]
        self.sole = co[sel, 2] < .05
        gname = {g.index: g.name for g in mesh.vertex_groups}
        self.v = np.c_[co[sel], np.ones(len(sel))]
        self.w = np.zeros((len(sel), len(self.bones)))
        for r, vi in enumerate(sel):
            ws = sorted(((g.weight, gname[g.group]) for g in mesh.data.vertices[vi].groups if g.weight > 1e-5), reverse=True)[:4]
            tot = sum(w for w, _ in ws)
            for w, nm in ws:
                if nm in self.bones:
                    self.w[r, self.bones.index(nm)] += w / tot
        # los pesos fuera de la pata (casi nulos en el casco) se reparten en la caña
        self.w[:, 2] += 1 - self.w.sum(1)
        self.y_rest = float(co[sel, 1][self.sole].mean())
        self.slide_axis = self.A[self.bones[0]][:3, :3].T @ np.array([0, 1.0, 0])

    def body(self, bob, pitch, yaw=0.0):
        W_raiz = self.A["raiz"] @ _tr((0, 0, bob))
        W_c = W_raiz @ self.Ai["raiz"] @ self.A["cuerpo"] @ _rx(pitch) @ _rz(yaw)
        return W_c if self.parent == "cuerpo" else W_c @ self.Ai["cuerpo"] @ self.A["grupa"]

    def hoof(self, Wp, x):
        W = Wp @ self.Ai[self.parent]
        acc = np.zeros((len(self.v), 4))
        for i, b in enumerate(self.bones):
            P = _rx(x[i])
            if i == 0:
                P = _tr(self.slide_axis * x[4]) @ P
            W = W @ self.A[b] @ P if i == 0 else W @ self.Ai[self.bones[i - 1]] @ self.A[b] @ P
            acc += self.w[:, i:i + 1] * (self.v @ (W @ self.Ai[b]).T)
        return acc[:, :3]

    def solve(self, Wp, pitch, ty, tz, pref, wpref, flat, wflat, x0):
        lo = self.LIMITS[self.leg[0]]

        def res(x):
            p = self.hoof(Wp, x)
            zmin = -np.log(np.exp(-600 * (p[:, 2] - p[:, 2].min())).sum()) / 600 + p[:, 2].min()
            r = [40 * (p[self.sole, 1].mean() - ty), 40 * (zmin - tz)]
            r += [wpref[i] * (x[i] - pref[i]) for i in range(4)]
            r.append(wflat * (pitch + x[0] + x[1] + x[2] + x[3] - flat))
            r.append(1.2 * x[4])
            r += [30 * max(0.0, lo[i][0] - x[i]) + 30 * max(0.0, x[i] - lo[i][1]) for i in range(4)]
            r.append(60 * max(0.0, abs(x[4]) - .08))
            return np.array(r)
        x = np.array(x0, float)
        lam = 1e-3
        r = res(x)
        for _ in range(60):
            J = np.empty((len(r), 5))
            for j in range(5):
                d = np.zeros(5)
                d[j] = 1e-5
                J[:, j] = (res(x + d) - r) / 1e-5
            H = J.T @ J
            step = np.linalg.solve(H + lam * np.diag(np.diag(H) + 1e-9), -J.T @ r)
            r2 = res(x + step)
            if r2 @ r2 < r @ r:
                x, r, lam = x + step, r2, lam * .4
                if np.abs(step).max() < 1e-6:
                    break
            else:
                lam *= 5
        p = self.hoof(Wp, x)
        return x, float(p[self.sole, 1].mean() - ty), float(p[:, 2].min())


def _swing_pref(leg, f):
    """Flexión buscada en el vuelo (f = 0 en el suelo, 1 en lo más alto): rodilla doblada atrás adelante, corvejón detrás."""
    if leg[0] == "F":
        return [0.0, .55 * f, -1.35 * f, -.65 * f]
    return [0.0, -.55 * f, .85 * f, -.65 * f]


def gait_targets(leg, ph, duty, stride, v, period, y_c, lift):
    """Trayectoria del casco (centro en Y, punto más bajo en Z), en el marco del caballo (que avanza a v)."""
    if ph < duty:
        t = ph / duty
        return y_c + stride / 2 - stride * t, .004, t, 0.0
    s = (ph - duty) / (1 - duty)
    # sale casi derecho hacia adelante (que la mano no espere al posterior que viene a pisar su huella) y llega
    # retrocediendo un poco (retracción del vuelo: el casco toca el suelo casi sin velocidad respecto de él)
    m0, m1 = -.05 * v * (1 - duty) * period, -.3 * v * (1 - duty) * period
    y0 = y_c - stride / 2
    y = y0 + stride * (3 * s * s - 2 * s ** 3) + m0 * (s - 2 * s * s + s ** 3) + m1 * (s ** 3 - s * s)
    sk = s ** (.6 if leg[0] == "F" else .8)   # se alzan antes de llegar a la mitad (las manos, más: doblan la rodilla al salir)
    z = .004 + lift * math.sin(math.pi * sk)
    return y, z, 1.0, math.sin(math.pi * sk)


def new_action(rig, name):
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    rig.animation_data.action = act
    return act


GAIT_REPORT = {}


def animate(rig, mesh):
    rig.animation_data_create()
    iks = {leg: LegIK(rig, mesh, leg) for leg in LEGS}
    for name, (n, phases, duty, v, lifts, bob, pitch, nb, centers, drop) in GAITS.items():
        act = new_action(rig, name)
        period = n / FPS
        stride = v * duty * period            # barrido del casco apoyado
        # sube-baja: en el trote el cuerpo baja a mitad del apoyo; en el paso sube sobre la pata de apoyo; en el galope
        # sube en la suspensión. Cabeceo: el galope levanta la cabeza al empujar los posteriores y la baja al caer las manos.
        if name == "gallop":
            last_off = phases["FL"]
            g_up = ((1 - last_off) + duty + 1.0) / 2 % 1.0   # mitad de la suspensión
        else:
            g_up = duty / 2 + (.25 if name == "trot" else 0.0)
        x_prev = {leg: np.zeros(5) for leg in LEGS}
        worst = {"err_y_m": 0.0, "min_z_m": 1.0, "stance_max_z_m": 0.0, "slide_m": 0.0}
        sols = []
        for f in range(2 * n):   # dos vueltas: la segunda arranca de la primera y el bucle cierra sin salto
            if f == n:
                sols = []
                worst = {"err_y_m": 0.0, "min_z_m": 1.0, "stance_max_z_m": 0.0, "slide_m": 0.0}
            g = (f % n) / n
            w = 2 * math.pi * g
            p_body = pitch * (math.cos(w - 2 * math.pi * .2) if name == "gallop" else math.sin(w))
            yaw = .015 * math.sin(w) if nb == 2 else 0.0
            z_body = -drop + bob * math.cos(nb * (w - 2 * math.pi * g_up))
            fr = {"pitch": p_body, "yaw": yaw, "z": z_body, "legs": {}}
            for leg, off in phases.items():
                ik = iks[leg]
                ph = (g + off) % 1.0
                y_c = ik.y_rest + centers[0 if leg[0] == "F" else 1]
                ty, tz, t, fl = gait_targets(leg, ph, duty, stride, v, period, y_c, lifts[0 if leg[0] == "F" else 1])
                stance = ph < duty
                if stance:   # apoyo: pata derecha, casco plano; al final el talón se despega (el casco rueda sobre la pinza)
                    pref, wpref = [0.0, 0.0, 0.0, .15], [.05, .8, 1.5, .25]
                    flat, wflat = -.5 * smoothstep(.72, 1.0, t), 3.0
                else:
                    pref, wpref = _swing_pref(leg, fl), [.05, .5, .5, .5]
                    flat, wflat = 0.0, 0.0
                Wp = ik.body(z_body, p_body, yaw)
                x, ey, zmin = ik.solve(Wp, p_body, ty, tz, pref, wpref, flat, wflat, x_prev[leg])
                x_prev[leg] = x
                fr["legs"][leg] = x
                worst["min_z_m"] = min(worst["min_z_m"], zmin)
                worst["slide_m"] = max(worst["slide_m"], abs(float(x[4])))
                if f >= n and (abs(zmin - tz) > .012 or abs(ey) > .02) and "--diag" in ARGV:
                    print("DIAG", name, leg, "t=%.2f" % t, "ey=%.3f z=%.3f" % (ey, zmin), np.round(x, 2))
                if stance:
                    worst["err_y_m"] = max(worst["err_y_m"], abs(ey))
                    worst["stance_max_z_m"] = max(worst["stance_max_z_m"], zmin)
            sols.append(fr)
        GAIT_REPORT[name] = {"stride_m": round(stride, 3), "design_mps": v, **{k: round(val, 4) for k, val in worst.items()}}
        print("ANDAR", name, json.dumps(GAIT_REPORT[name]))
        for f in range(n + 1):
            fr = sols[f % n]
            g = (f % n) / n
            w = 2 * math.pi * g
            for leg, x in fr["legs"].items():
                for i, s in enumerate(SEG):
                    if i == 0:
                        key(rig, f"{leg}_{s}", f, rot=(float(x[0]), 0, 0), loc=tuple(iks[leg].slide_axis * float(x[4])))
                    else:
                        key(rig, f"{leg}_{s}", f, rot=(float(x[i]), 0, 0))
            # cuerpo: cabeceo y algo de giro en los andares de dos tiempos; sube-baja en la raíz (hueso horizontal con
            # Z local = Z del mundo). Sin desplazamiento: el avance lo pone el juego.
            key(rig, "cuerpo", f, loc=(0, 0, 0), rot=(fr["pitch"], 0, fr["yaw"]))
            key(rig, "raiz", f, loc=(0, 0, fr["z"]), rot=(0, 0, 0))
            key(rig, "cuello", f, rot=(-pitch * 1.2 * math.sin(w + .6) - (.10 if name == "gallop" else 0), 0, 0))
            key(rig, "cuello2", f, rot=(-pitch * .6 * math.sin(w + 1.0), 0, 0))
            key(rig, "cabeza", f, rot=(pitch * .5 * math.sin(w + 1.2), 0, 0))
            key(rig, "cola", f, rot=(-.10 - .12 * math.sin(w * nb - .8) - (.35 if name == "gallop" else 0), 0, .06 * math.sin(w + .5)))
            key(rig, "cola2", f, rot=(-.08 * math.sin(w * nb - 1.4), 0, .08 * math.sin(w)))
        finish_action(act, n)
    # idle: respiración, la cabeza baja y sube despacio, la cola espanta moscas; un posterior descansa
    n = 96
    act = new_action(rig, "idle")
    for f in range(0, n + 1, 4):
        w = 2 * math.pi * f / n
        key(rig, "raiz", f, loc=(0, 0, .004 + .004 * math.sin(4 * w)))   # visual/r1 F4b: +4 mm, ningún casco bajo el suelo
        key(rig, "cuerpo", f, loc=(0, 0, 0), rot=(0, 0, 0))
        key(rig, "cuello", f, rot=(-.10 - .07 * (.5 - .5 * math.cos(w)), 0, .04 * math.sin(w)))
        key(rig, "cuello2", f, rot=(-.03 * (.5 - .5 * math.cos(w)), 0, .03 * math.sin(w)))
        key(rig, "cabeza", f, rot=(.05 * math.sin(2 * w), 0, 0))
        key(rig, "cola", f, rot=(-.06, 0, .22 * math.sin(3 * w) * (.5 + .5 * math.sin(w))))
        key(rig, "cola2", f, rot=(0, 0, .18 * math.sin(3 * w - .7) * (.5 + .5 * math.sin(w))))
        for leg in LEGS:
            rest = leg == "HR"
            key(rig, f"{leg}_sup", f, rot=(.06 if rest else 0, 0, 0), loc=(0, 0, 0))
            key(rig, f"{leg}_inf", f, rot=(-.10 if rest else 0, 0, 0))
            key(rig, f"{leg}_cana", f, rot=(.12 if rest else 0, 0, 0))
            key(rig, f"{leg}_cuartilla", f, rot=(-.25 if rest else 0, 0, 0))
    finish_action(act, n)
    rig.animation_data.action = bpy.data.actions["trot"]


def finish_action(act, last):
    for fc in act.fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = "BEZIER" if act.name == "idle" else "LINEAR"
    act.frame_range = (0, last)   # cuadro 0 = tiempo 0; el último repite el primero: el bucle no se traba
    act.use_frame_range = True


# --------------------------------------------------------------------------------------
# Exportación
# --------------------------------------------------------------------------------------
def anchor(parent_rig=None):
    """Esfera de 2 mm como primera primitiva (defecto de Godot 4.7.2 con COLOR_0, ver docs/ASSETS.md)."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=6, v_segments=4, radius=.001)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, .002))
    me = bpy.data.meshes.new("ancla")
    bm.to_mesh(me)
    o = bpy.data.objects.new("ancla", me)
    bpy.context.collection.objects.link(o)
    me.materials.append(vc_material("F4 | ancla"))
    set_loop_colors(o, np.full((len(me.vertices), 3), .5, np.float32))
    if parent_rig:
        skin(o, parent_rig, "cuerpo")
    return o


def join(objs, name):
    for o in objs:
        for m in list(o.modifiers):
            if m.type in ("SOLIDIFY", "DECIMATE"):
                bpy.context.view_layer.objects.active = o
                bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = name
    o.data.name = name
    return o


def export(name, note, anims=()):
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
    dg = bpy.context.evaluated_depsgraph_get()
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
        "front": "Godot -Z", "origin": "suelo, centro entre los cascos" if name.startswith("caballo") else "asiento (hueso silla del caballo)",
        "sha256": hashlib.sha256(data).hexdigest(), "note": note,
    }
    print("ASSET_READY " + json.dumps(REPORT[name], ensure_ascii=False))


# --------------------------------------------------------------------------------------
# Construcción
# --------------------------------------------------------------------------------------
def build_horse(coat, lod):
    reset()
    _MATS.clear()
    body, k = load_body()
    co = verts_np(body)
    hi_bvh = BVHTree.FromObject(body, bpy.context.evaluated_depsgraph_get())
    if lod:
        d = body.modifiers.new("lod", "DECIMATE")
        d.ratio = .15
        d.use_symmetry = True
        d.symmetry_axis = "X"
        bpy.context.view_layer.objects.active = body
        bpy.ops.object.modifier_apply(modifier="lod")
    color_body(body, hi_bvh, coat)
    hair = mane_and_tail(hi_bvh, coat, lod)
    tack = recado(hi_bvh, lod)
    note = (f"Caballo criollo, pelaje {coat} (diseño). Malla del cuerpo: «Rigged Horse» de Lyndon Daniels/ChadM (OpenGameArt, "
            "CC0), reescalada a 1,45 m de cruz; esqueleto, pesos, crin tusada, cola, recado, cabezada, pelaje y andares propios.")
    if lod:
        parts = [anchor()] + [body] + hair + tack
        join(parts, f"caballo_criollo_{coat}_lod")
        export(f"caballo_criollo_{coat}_lod", note + " LOD de tropa: estático, pose de reposo.")
        return
    rig = build_rig(co)
    auto_weights([body] + [h for h in hair if h.name.startswith("cola")], rig)
    for h in hair:
        if not h.name.startswith("cola"):
            skin(h, rig, "cuello2" if h.name.startswith("copete") else "cuello")
    for t in tack:
        nm = t.name
        bone = ("cabeza" if nm.startswith(("cabezada", "freno")) else "cuello" if nm.startswith("riendas") else "cuerpo")
        # los estribos y arciones cuelgan del recado (cuerpo), no de las patas
        skin(t, rig, bone)
    a = anchor(rig)
    # una sola malla con varias superficies, pesada al esqueleto
    objs = [a, body] + hair + tack
    for o in objs:
        for m in list(o.modifiers):
            if m.type == "SOLIDIFY":
                bpy.context.view_layer.objects.active = o
                bpy.ops.object.modifier_apply(modifier=m.name)
    merged = join(objs, f"caballo_criollo_{coat}")
    for m in list(merged.modifiers)[1:]:
        merged.modifiers.remove(m)
    animate(rig, merged)
    export(f"caballo_criollo_{coat}", note, anims=("idle", "walk", "trot", "gallop"))


def load_create_models():
    src = (ROOT / "tools" / "create_models.py").read_text(encoding="utf-8")
    src = src.rstrip()
    assert src.endswith("main()"), "create_models.py cambió: revisar cómo se reutiliza mounted_rider"
    ns = {"__file__": str(ROOT / "tools" / "create_models.py"), "__name__": "create_models_f4"}
    exec(compile(src[: -len("main()")], "create_models.py", "exec"), ns)
    return ns


def build_rider(period, lod, cm):
    reset()
    _MATS.clear()
    cm["_KM"].clear()
    cm["_TEX"].clear() if "_TEX" in cm else None
    m = cm["palette"]()
    cm["mounted_rider"](m, None, period)
    for o in list(bpy.context.scene.objects):
        # fuera lo que era del caballo viejo (pellón, pistolera): el recado nuevo es del caballo
        if o.name.startswith(("Tack | sheepskin pellon", "Tack | holster", "Tack | pistol butt")):
            bpy.data.objects.remove(o, do_unlink=True)

    # asiento del modelo viejo (cima del pellón): (0, -0.06, 1.86) -> SEAT
    off = SEAT - Vector((0, -.06, 1.86))
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in objs:
        o.location += off
        bpy.context.view_layer.objects.active = o
        o.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for o in objs:   # el caballo criollo es más angosto que el viejo: las piernas se cierran 15 % hacia el centro
        if any(k in o.name for k in ("thigh", "knee", "boot", "spur")):
            o.data.transform(Matrix.Diagonal((.85, 1, 1, 1)))
    for o in objs:
        kind = o.data.materials[0].name.split("| ")[-1] if o.data.materials else "wool"
        o.data.materials.clear()
        rough = .45 if kind in ("metal", "gloss") else .85
        o.data.materials.append(vc_material("F4 | " + kind, rough, .6 if kind == "metal" else 0))
        a = o.data.color_attributes.get("Col")
        arr = np.empty(len(o.data.loops) * 4, np.float32)
        a.data.foreach_get("color", arr)
        arr = arr.reshape(-1, 4)
        arr[:, :3] *= cm["ALBEDO_LIN"]   # create_models guarda color/0.62 porque lo multiplica una textura; acá no hay
        a.data.foreach_set("color", arr.ravel())
        o.data.color_attributes.active_color = a
        for uv in list(o.data.uv_layers):
            o.data.uv_layers.remove(uv)
        # posición relativa al asiento: el origen del GLB es el asiento
        o.data.transform(Matrix.Translation(-SEAT))
    name = f"jinete_criollo_{period}" + ("_lod" if lod else "")
    if lod:   # tropa: se une y se reduce a ~1.050 triángulos (el ancla se agrega después, intacta)
        j = join(objs, name)
        d = j.modifiers.new("lod", "DECIMATE")
        d.ratio = min(1.0, 1050 / max(tri_count(j), 1))
        d.use_symmetry = True
        d.symmetry_axis = "X"
        bpy.context.view_layer.objects.active = j
        bpy.ops.object.modifier_apply(modifier="lod")
        objs = [j]
    join([anchor()] + objs, name)
    for img in list(bpy.data.images):
        bpy.data.images.remove(img)
    export(name, f"Jinete de {period} de tools/create_models.py (obra propia), sin caballo, sentado; origen = asiento. "
           "Se pone como hijo de un BoneAttachment3D en el hueso 'silla' del caballo (transformación identidad)."
           + (" LOD de tropa." if lod else ""))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    if not SRC.is_file() and "caballo" in ONLY:
        raise SystemExit(f"No está la fuente {SRC}")
    if "caballo" in ONLY:
        REPORT["_fuente"] = {"file": SRC.name, "sha256": hashlib.sha256(SRC.read_bytes()).hexdigest(),
                             "url": "https://opengameart.org/content/rigged-horse", "license": "CC0",
                             "author": "Lyndon Daniels (malla, «Realtime Ranchers 3D model pack»); ChadM (esqueleto, no usado)"}
        for coat in (_arg("--coats") or ",".join(COATS)).split(","):
            build_horse(coat, False)
            build_horse(coat, True)
    if "jinete" in ONLY:
        cm = load_create_models()
        for period in (1817, 1806):
            build_rider(period, False, cm)
            build_rider(period, True, cm)
    man = OUT / "f4_caballos_manifest.json"
    old = json.loads(man.read_text(encoding="utf-8")) if man.is_file() else {}
    old.update(REPORT)
    old["_convenciones"] = {"unidad": "metro", "frente": "Godot -Z (Blender +Y)", "arriba": "Godot +Y",
                            "cruz_m": WITHERS, "asiento_godot": [SEAT.x, SEAT.z, -SEAT.y], "fps": FPS,
                            "pelajes": list(COATS), "hueso_jinete": "silla"}
    man.write_text(json.dumps(old, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print("F4_CABALLOS_LISTOS")


main()
