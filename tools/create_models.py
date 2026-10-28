"""Own procedural meshes and PBR textures for Patria: Guemes. Blender 4.x, no downloaded assets.

Run: blender --background --factory-startup --python tools/create_models.py
Optional: ... -- --only rider_1806,justine   (regenerate only the named assets; the manifest is merged)

Blender +Y is forward; glTF exports it as Godot -Z. Blender Z becomes Godot Y.
All dimensions are metres. These are artistic reconstructions, not scanned relics.

Material strategy (phase 2): every asset uses a handful of procedural PBR "kinds"
(wool, linen, leather, wood, planks, coat, skin, metal, ...). Each kind owns a tileable
albedo + normal + roughness/metal texture generated here with numpy; the per-object colour
lives in a COLOR_0 vertex attribute that multiplies the albedo. That keeps 7-10 glTF
surfaces per asset (fewer draw calls than the 16-17 flat-colour materials of 0.1.0) while
giving fabric weave, leather grain, wood grain, hair and plaster relief.
"""
import bpy
import math
import random
import json
import struct
import hashlib
import sys
import numpy as np
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "models"
OUT.mkdir(parents=True, exist_ok=True)
RNG = random.Random(18061817)
NPRNG = np.random.default_rng(18061817)
REPORT = {}
ALBEDO_MEAN = 0.8          # stored (sRGB-encoded) mean of every albedo texture
ALBEDO_LIN = 0.62          # ... which decodes to about 0.62 linear: colours are divided by it
_UV_COUNTER = [0]


# --------------------------------------------------------------------------------------
# Procedural textures (numpy). All maps are tileable; rows = V, columns = U.
# --------------------------------------------------------------------------------------
def vnoise(n, cy, cx, rng):
    g = rng.random((cy, cx))
    ys = np.arange(n) * cy / n
    xs = np.arange(n) * cx / n
    y0 = np.floor(ys).astype(int)
    x0 = np.floor(xs).astype(int)
    fy = ys - y0
    fx = xs - x0
    fy = fy * fy * (3 - 2 * fy)
    fx = fx * fx * (3 - 2 * fx)
    y1 = (y0 + 1) % cy
    x1 = (x0 + 1) % cx
    y0 %= cy
    x0 %= cx
    a = g[np.ix_(y0, x0)]
    b = g[np.ix_(y0, x1)]
    c = g[np.ix_(y1, x0)]
    d = g[np.ix_(y1, x1)]
    fyc = fy[:, None]
    fxc = fx[None, :]
    return (a * (1 - fxc) + b * fxc) * (1 - fyc) + (c * (1 - fxc) + d * fxc) * fyc


def fbm(n, cy, cx, octaves, rng, gain=.5):
    out = 0.0
    amp = 1.0
    tot = 0.0
    for o in range(octaves):
        out = out + amp * vnoise(n, cy * 2 ** o, cx * 2 ** o, rng)
        tot += amp
        amp *= gain
    return out / tot


def ridged(n, cy, cx, octaves, rng):
    return 1.0 - np.abs(2.0 * fbm(n, cy, cx, octaves, rng) - 1.0)


def grid(n):
    c = (np.arange(n) + .5) / n
    return np.meshgrid(c, c)      # X (columns), Y (rows)


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def norm_mean(a):
    return np.clip(a * (ALBEDO_MEAN / max(a.mean(), 1e-6)), 0, 1)


def mk_wool(n, r):
    X, Y = grid(n)
    K = 22
    fx, fy = X * K, Y * K
    ix, iy = np.floor(fx).astype(int), np.floor(fy).astype(int)
    px = np.sin(np.pi * (fx % 1))
    py = np.sin(np.pi * (fy % 1))
    over = ((ix + iy) % 4) < 2                  # twill diagonal
    h = np.where(over, px, py) * .8 + .2 * fbm(n, 64, 64, 3, r)
    alb = .55 + .45 * h + .10 * fbm(n, 6, 6, 3, r) - .05
    rough = .90 - .10 * h
    return alb, rough, h * .8, np.zeros_like(h), 1.6


def mk_linen(n, r):
    X, Y = grid(n)
    K = 48
    fx, fy = X * K, Y * K
    ix, iy = np.floor(fx).astype(int), np.floor(fy).astype(int)
    px = np.sin(np.pi * (fx % 1))
    py = np.sin(np.pi * (fy % 1))
    over = ((ix + iy) % 2) == 0
    slub = fbm(n, 1, K, 2, r) * .3 + fbm(n, K, 1, 2, r) * .3
    h = np.where(over, px, py) * .7 + slub
    alb = .62 + .30 * h + .10 * fbm(n, 5, 5, 3, r)
    return alb, .86 - .08 * h, h * .7, np.zeros_like(h), 1.2


def mk_leather(n, r):
    ra = ridged(n, 12, 12, 4, r)
    h = ra ** 1.6
    alb = .55 + .35 * h + .12 * fbm(n, 4, 4, 3, r)
    rough = .50 + .22 * (1 - h) + .08 * fbm(n, 8, 8, 2, r)
    return alb, rough, h, np.zeros_like(h), 2.0


def mk_wood(n, r):
    X, Y = grid(n)
    warp = fbm(n, 2, 3, 3, r) * 5.0
    g = .5 + .5 * np.sin(2 * np.pi * (Y * 7 + warp))
    fine = fbm(n, 160, 6, 2, r)
    alb = .52 + .30 * g + .18 * fine
    h = g * .35 + fine * .65
    return alb, .78 - .12 * g, h, np.zeros_like(h), 1.3


def mk_planks(n, r, vertical=False):
    X, Y = grid(n)
    rows = 4
    base_alb, base_rough, base_h, _, _ = mk_wood(n, r)
    row = np.floor(Y * rows).astype(int)
    offs = r.uniform(.78, 1.10, rows + 1)[row]
    seam_d = np.abs((Y * rows) % 1 - 0.0)
    seam_d = np.minimum(seam_d, 1 - seam_d) / rows
    seam = 1 - smooth(.003, .012, seam_d)
    joint_x = r.random(rows)[row]
    jd = np.abs(X - joint_x)
    jd = np.minimum(jd, 1 - jd)
    joint = 1 - smooth(.002, .007, jd)
    cut = np.maximum(seam, joint)
    alb = base_alb * offs * (1 - .75 * cut)
    h = base_h * (1 - cut) - .8 * cut
    rough = base_rough * (1 - cut) + .95 * cut
    if vertical:
        alb, rough, h = alb.T.copy(), rough.T.copy(), h.T.copy()
    return alb, rough, h, np.zeros_like(h), 2.2


def mk_deckplanks(n, r):
    return mk_planks(n, r, True)


def mk_coat(n, r):
    fine = fbm(n, 140, 10, 3, r)
    patch = fbm(n, 5, 5, 3, r)
    alb = .70 + .20 * fine + .16 * patch
    return alb, .62 + .06 * fine, fine * .5, np.zeros_like(fine), .8


def mk_skin(n, r):
    f = fbm(n, 48, 48, 3, r)
    pores = (r.random((n, n)) > .985).astype(float) * .15
    alb = .88 + .12 * f - pores
    return alb, .62 + .08 * f, f * .25 + pores * -1, np.zeros_like(f), .5


def mk_metal(n, r):
    s = fbm(n, 220, 3, 2, r)
    alb = .72 + .28 * s
    rough = .34 + .28 * fbm(n, 12, 12, 3, r) + .08 * s
    metal = .88 + .12 * s
    return alb, rough, s * .3, metal, .7


def mk_gloss(n, r):
    h = np.zeros((n, n))
    return np.full((n, n), 1.0), np.full((n, n), .14), h, np.zeros_like(h), .5


def mk_sail(n, r):
    X, Y = grid(n)
    K = 72
    fx, fy = X * K, Y * K
    ix, iy = np.floor(fx).astype(int), np.floor(fy).astype(int)
    px = np.sin(np.pi * (fx % 1))
    py = np.sin(np.pi * (fy % 1))
    h = np.where(((ix + iy) % 2) == 0, px, py)
    panel = np.floor(X * 4).astype(int)
    poff = r.uniform(.9, 1.05, 4)[panel]
    sd = np.abs((X * 4) % 1)
    sd = np.minimum(sd, 1 - sd) / 4
    seam = 1 - smooth(.002, .006, sd)
    stitch = seam * ((Y * 90) % 1 < .55)
    stain = fbm(n, 3, 3, 3, r)
    alb = (.70 + .22 * h) * poff * (1 - .28 * stain) * (1 - .35 * stitch)
    return alb, .92 - .06 * h, h * .6 + seam * .5, np.zeros_like(h), 1.4


def mk_plaster(n, r):
    m = fbm(n, 3, 3, 4, r)
    fine = fbm(n, 64, 64, 2, r)
    streak = fbm(n, 2, 14, 3, r)
    pits = (r.random((n, n)) > .993).astype(float)
    alb = .70 + .22 * m + .10 * fine - .12 * streak - .35 * pits
    h = m * .5 + fine * .35 - pits * .8
    return alb, .95 - .05 * fine, h, np.zeros_like(h), 1.5


def mk_tile(n, r):
    X, Y = grid(n)
    cols, rows = 6, 5
    fx, fy = X * cols, Y * rows
    ix, iy = np.floor(fx).astype(int), np.floor(fy).astype(int)
    prof = .5 + .5 * np.cos(2 * np.pi * fx)
    s = fy % 1
    h = prof * (.55 + .45 * s)
    gap = 1 - smooth(.0, .10, s)
    h = h * (1 - .7 * gap)
    tb = r.uniform(.72, 1.0, (rows, cols))[iy % rows, ix % cols]
    alb = (.50 + .38 * h) * tb * (1 - .3 * gap) + .08 * fbm(n, 40, 40, 2, r)
    return alb, .84 - .06 * h, h, np.zeros_like(h), 2.2


def mk_bark(n, r):
    ra = ridged(n, 2, 12, 4, r)
    h = ra
    alb = .40 + .55 * ra + .08 * fbm(n, 30, 30, 2, r)
    return alb, .93 - .05 * ra, h, np.zeros_like(h), 2.4


def mk_foliage(n, r):
    sp = fbm(n, 28, 28, 3, r)
    big = fbm(n, 5, 5, 2, r)
    alb = .42 + .50 * sp + .20 * big
    return alb, .82 - .1 * sp, sp * .7, np.zeros_like(sp), 1.4


def mk_stone(n, r):
    ra = ridged(n, 6, 6, 4, r)
    f = fbm(n, 40, 40, 2, r)
    alb = .52 + .34 * ra + .14 * f
    return alb, .90 - .06 * f, ra * .8 + f * .3, np.zeros_like(ra), 1.9


def mk_cactus(n, r):
    X, Y = grid(n)
    ribs = .5 + .5 * np.cos(2 * np.pi * X * 6)
    areole = (ribs > .93) & ((Y * 12) % 1 < .12)
    alb = .70 + .22 * ribs + .08 * fbm(n, 20, 20, 2, r) + .25 * areole
    return alb, .78 - .1 * ribs, ribs * .9, np.zeros_like(ribs), 1.8


# kind -> (tile metres, texture size, maker)
KINDS = {
    "wool": (.22, 256, mk_wool), "linen": (.2, 256, mk_linen), "leather": (.5, 256, mk_leather),
    "wood": (2.0, 256, mk_wood), "planks": (2.4, 512, mk_planks), "deckplanks": (2.4, 512, mk_deckplanks),
    "coat": (.8, 256, mk_coat), "skin": (.5, 256, mk_skin), "metal": (.5, 256, mk_metal),
    "gloss": (1.0, 64, mk_gloss), "anchor": (1.0, 8, mk_gloss), "sail": (2.0, 512, mk_sail), "plaster": (1.6, 512, mk_plaster),
    "tile": (1.5, 512, mk_tile), "bark": (1.2, 256, mk_bark), "foliage": (1.0, 256, mk_foliage),
    "stone": (1.5, 256, mk_stone), "cactus": (1.0, 256, mk_cactus),
}
_TEX = {}
_KM = {}


def _image(name, arr, color=True):
    h, w, _ = arr.shape
    im = bpy.data.images.new(name, width=w, height=h, alpha=False)
    rgba = np.concatenate([arr, np.ones((h, w, 1))], axis=2)
    im.pixels.foreach_set(rgba.astype(np.float32).ravel())
    if not color:
        im.colorspace_settings.name = "Non-Color"
    im.pack()
    return im


def texture_set(kind):
    if kind in _TEX:
        return _TEX[kind]
    tile, n, maker = KINDS[kind]
    rng = np.random.default_rng(sum(map(ord, kind)) * 7919)
    alb, rough, height, metal, strength = maker(n, rng)
    alb = norm_mean(alb)
    a3 = np.repeat(alb[:, :, None], 3, axis=2)
    dx = np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)
    dy = np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)
    nx, ny, nz = -dx * strength * 4.0, -dy * strength * 4.0, np.ones_like(dx)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    nmap = np.stack([nx / ln, ny / ln, nz / ln], axis=2) * .5 + .5
    rm = np.stack([np.ones_like(rough), np.clip(rough, .05, 1), np.clip(metal, 0, 1)], axis=2)
    _TEX[kind] = (_image("alb_" + kind, a3), _image("nor_" + kind, nmap, False),
                  _image("rm_" + kind, rm, False))
    return _TEX[kind]


def kind_material(kind):
    if kind in _KM:
        return _KM[kind]
    alb, nor, rm = texture_set(kind)
    m = bpy.data.materials.new("PBR | " + kind)
    m.use_nodes = True
    m["tile"] = KINDS[kind][0]
    nt = m.node_tree
    b = nt.nodes.get("Principled BSDF")
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = alb
    vc = nt.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Col"
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs[0].default_value = 1
    nt.links.new(t.outputs["Color"], mix.inputs[6])
    nt.links.new(vc.outputs["Color"], mix.inputs[7])
    nt.links.new(mix.outputs[2], b.inputs["Base Color"])
    tn = nt.nodes.new("ShaderNodeTexImage")
    tn.image = nor
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(tn.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
    tr = nt.nodes.new("ShaderNodeTexImage")
    tr.image = rm
    sp = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(tr.outputs["Color"], sp.inputs[0])
    nt.links.new(sp.outputs["Green"], b.inputs["Roughness"])
    nt.links.new(sp.outputs["Blue"], b.inputs["Metallic"])
    _KM[kind] = m
    return m


class Mat:
    """A colour + texture kind. Colour is stored per vertex (COLOR_0)."""

    def __init__(self, name, color, kind):
        self.name = name
        self.kind = kind
        self.color = tuple(min(1.0, c / ALBEDO_LIN) for c in color)


def material(name, color, roughness=None, metallic=None, kind="wool"):
    return Mat(name, color, kind)


def reset():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in list(bpy.data.materials):
        bpy.data.materials.remove(block)
    for block in list(bpy.data.actions):
        bpy.data.actions.remove(block)
    for block in list(bpy.data.meshes):
        if block.users == 0:
            bpy.data.meshes.remove(block)
    _KM.clear()
    bpy.context.scene.render.fps = 24


def palette():
    return {
        "coat": material("Wool | colonial indigo", (.035, .075, .12), kind="wool"),
        "redcoat": material("Wool | muted British red", (.42, .045, .035), kind="wool"),
        "whitecoat": material("Wool | neutral off-white campaign coat", (.58, .57, .51), kind="wool"),
        "facing": material("Wool | facing cloth", (.30, .035, .04), kind="wool"),
        "blue_facing": material("Wool | blue facing", (.04, .09, .20), kind="wool"),
        "poncho": material("Wool | deep garnet poncho", (.31, .035, .026), kind="wool"),
        "stripe": material("Wool | woven dark border", (.085, .026, .019), kind="wool"),
        "kerchief": material("Cotton | faded red kerchief", (.34, .05, .035), kind="linen"),
        "cream": material("Linen | unbleached", (.61, .58, .45), kind="linen"),
        "white": material("Linen | white", (.74, .72, .66), kind="linen"),
        "trouser": material("Wool | earth grey trousers", (.18, .17, .13), kind="wool"),
        "pelt": material("Sheepskin | pellon", (.66, .60, .46), kind="wool"),
        "skin": material("Skin | warm ochre", (.48, .285, .16), kind="skin"),
        "skinlight": material("Skin | highlight", (.57, .36, .22), kind="skin"),
        "hair": material("Hair | dark brown", (.034, .02, .014), kind="coat"),
        "black": material("Hat felt | charcoal", (.021, .023, .021), kind="wool"),
        "leather": material("Leather | oxblood brown", (.095, .036, .018), kind="leather"),
        "boot": material("Boot leather", (.034, .024, .015), kind="leather"),
        "metal": material("Iron | dark forged", (.075, .08, .075), kind="metal"),
        "brass": material("Brass | aged", (.42, .27, .08), kind="metal"),
        "eye": material("Eyes | dark", (.006, .005, .003), kind="gloss"),
        "glass": material("Glass | lantern", (.52, .44, .20), kind="gloss"),
        "horse": material("Horse | bay coat", (.205, .082, .033), kind="coat"),
        "horse_dark": material("Horse | shading", (.095, .032, .012), kind="coat"),
        "blaze": material("Horse | white marking", (.60, .57, .50), kind="coat"),
        "muzzle": material("Horse | velvet muzzle", (.055, .044, .032), kind="coat"),
        "hoof": material("Hoof | dark horn", (.042, .034, .025), kind="leather"),
        "wood": material("Wood | walnut", (.19, .086, .027), kind="wood"),
    }


# --------------------------------------------------------------------------------------
# Painting and UVs
# --------------------------------------------------------------------------------------
def _col_attr(me):
    a = me.color_attributes.get("Col")
    if a is None:
        a = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    return a


def paint(obj, color):
    me = obj.data
    a = _col_attr(me)
    arr = np.tile(np.array([*color, 1.0], np.float32), (len(me.loops), 1))
    a.data.foreach_set("color", arr.ravel())


def _world(obj):
    me = obj.data
    nv = len(me.vertices)
    co = np.empty(nv * 3, np.float32)
    me.vertices.foreach_get("co", co)
    mw = np.array(obj.matrix_world)
    w = co.reshape(-1, 3) @ mw[:3, :3].T + mw[:3, 3]
    vi = np.empty(len(me.loops), np.int32)
    me.loops.foreach_get("vertex_index", vi)
    return w[vi], mw


def paint_fn(obj, fn):
    """Multiply the stored colour by fn(world positions Nx3) -> Nx3 or Nx1 factors."""
    me = obj.data
    a = _col_attr(me)
    P, _ = _world(obj)
    cur = np.empty(len(me.loops) * 4, np.float32)
    a.data.foreach_get("color", cur)
    cur = cur.reshape(-1, 4)
    f = np.asarray(fn(P), np.float32)
    if f.ndim == 1:
        f = f[:, None]
    cur[:, :3] *= f
    a.data.foreach_set("color", cur.ravel())


def paint_poly(obj, fn):
    me = obj.data
    a = _col_attr(me)
    arr = np.ones((len(me.loops), 4), np.float32)
    for p in me.polygons:
        c = fn(p)
        for li in p.loop_indices:
            arr[li, :3] = c
    a.data.foreach_set("color", arr.ravel())


def auto_uv(obj):
    """Box projection in world space, tile size taken from the object's PBR material."""
    me = obj.data
    npoly = len(me.polygons)
    if npoly == 0:
        return
    P, mw = _world(obj)
    ls = np.empty(npoly, np.int32)
    lt = np.empty(npoly, np.int32)
    nrm = np.empty(npoly * 3, np.float32)
    mi = np.empty(npoly, np.int32)
    me.polygons.foreach_get("loop_start", ls)
    me.polygons.foreach_get("loop_total", lt)
    me.polygons.foreach_get("normal", nrm)
    me.polygons.foreach_get("material_index", mi)
    nw = nrm.reshape(-1, 3) @ mw[:3, :3].T
    poly_of_loop = np.repeat(np.arange(npoly), lt)
    axis = np.abs(nw).argmax(1)[poly_of_loop]
    tiles = np.array([float(m.get("tile", 1.0)) if m else 1.0 for m in me.materials] or [1.0])
    tile = tiles[np.clip(mi, 0, len(tiles) - 1)][poly_of_loop]
    _UV_COUNTER[0] += 1
    off = (_UV_COUNTER[0] * 0.6180339) % 1.0
    u = np.where(axis == 0, P[:, 1], P[:, 0]) / tile + off
    v = np.where(axis == 2, P[:, 1], P[:, 2]) / tile + off * 1.7
    uv = me.uv_layers.get("UVMap") or me.uv_layers.new(name="UVMap")
    uv.data.foreach_set("uv", np.stack([u, v], axis=1).astype(np.float32).ravel())
    for extra in [l.name for l in me.uv_layers if l.name != "UVMap"]:
        me.uv_layers.remove(me.uv_layers[extra])


# --------------------------------------------------------------------------------------
# Geometry helpers
# --------------------------------------------------------------------------------------
def finish(obj, mat, smooth=True, bone=None, rig=None):
    if mat is not None:
        obj.data.materials.append(kind_material(mat.kind))
        paint(obj, mat.color)
    if obj.type == "MESH":
        for p in obj.data.polygons:
            p.use_smooth = smooth
    if rig is not None and bone is not None:
        group = obj.vertex_groups.new(name=bone)
        group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
        modifier = obj.modifiers.new("Skeletal deformation", "ARMATURE")
        modifier.object = rig
        obj.parent = rig
    return obj


def mesh(name, vertices, faces, mat, smooth=True, bone=None, rig=None):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    return finish(obj, mat, smooth, bone, rig)


def sphere(name, position, scale, mat, bone=None, rig=None, seg=16, rings=10):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, location=position)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, mat, True, bone, rig)


def box(name, position, scale, mat, bevel=.015, bone=None, rig=None, segs=2):
    bpy.ops.mesh.primitive_cube_add(size=1, location=position)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new("Soft manufactured edges", "BEVEL")
        mod.width = bevel
        mod.segments = segs
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(obj, mat, False, bone, rig)


def rbox(name, position, scale, rotation, mat, bevel=.0, bone=None, rig=None):
    """Box rotated about its own centre (rotation = Euler radians), baked into the mesh."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0))
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new("Soft edges", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.rotation_euler = rotation
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    obj.location = position
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    return finish(obj, mat, False, bone, rig)


def segment(name, a, b, radius_a, radius_b, mat, bone=None, rig=None, sides=12):
    """Tapered mesh along a segment; no engine capsule primitives."""
    a, b = Vector(a), Vector(b)
    direction = b - a
    bpy.ops.mesh.primitive_cone_add(vertices=sides, radius1=radius_a, radius2=radius_b,
                                   depth=direction.length, location=(a + b) / 2)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = direction.to_track_quat("Z", "Y")
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return finish(obj, mat, True, bone, rig)


def tube(name, points, radius, mat, bone=None, rig=None):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 2
    curve.bevel_depth = radius
    curve.bevel_resolution = 2
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for p, co in zip(spline.points, points):
        p.co = (*co, 1)
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.object
    obj.select_set(False)
    return finish(obj, mat, True, bone, rig)


def torus(name, position, major, minor, rotation, mat, bone=None, rig=None, ms=20, ns=6):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=ms,
                                     minor_segments=ns, location=position, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    return finish(obj, mat, True, bone, rig)


def rings_y(name, sections, mat, sides=20, bone=None, rig=None):
    """Continuous elliptical section surface: (y, z_center, half_width, half_height)."""
    verts, faces = [], []
    for y, z, rx, rz in sections:
        for j in range(sides):
            t = 2 * math.pi * j / sides
            verts.append((math.cos(t) * rx, y, z + math.sin(t) * rz))
    for i in range(len(sections) - 1):
        for j in range(sides):
            a = i * sides + j
            b = i * sides + (j + 1) % sides
            faces.append((a, a + sides, b + sides, b))
    faces.append(tuple(range(sides)))
    faces.append(tuple((len(sections) - 1) * sides + j for j in reversed(range(sides))))
    return mesh(name, verts, faces, mat, True, bone, rig)


def rings_z(name, sections, mat, sides=16, bone=None, rig=None):
    """Tailored cross-sections: (z, y_center, half_width, half_depth)."""
    verts, faces = [], []
    for z, y, rx, ry in sections:
        for j in range(sides):
            t = 2 * math.pi * j / sides
            verts.append((math.cos(t) * rx, y + math.sin(t) * ry, z))
    for i in range(len(sections) - 1):
        for j in range(sides):
            a = i * sides + j
            b = i * sides + (j + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    faces.append(tuple(reversed(range(sides))))
    faces.append(tuple((len(sections) - 1) * sides + j for j in range(sides)))
    return mesh(name, verts, faces, mat, True, bone, rig)


def armature(name, bones):
    data = bpy.data.armatures.new(name)
    rig = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for bn, head, tail, parent in bones:
        eb = data.edit_bones.new(bn)
        eb.head, eb.tail = head, tail
        if parent:
            eb.parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    rig.select_set(False)
    return rig


def blob(name, position, radii, mat, rng, subdiv=2, jitter=.10, seed_shift=0.0):
    """Lumpy displaced icosphere used for foliage and rocks."""
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=1.0, location=position)
    obj = bpy.context.object
    obj.name = name
    ph = [rng.uniform(0, 6.28) for _ in range(3)]
    for v in obj.data.vertices:
        c = v.co.copy()
        lump = (math.sin(c.x * 3.1 + ph[0]) * math.sin(c.y * 2.7 + ph[1]) * math.sin(c.z * 3.3 + ph[2]))
        k = 1 + jitter * lump + jitter * .6 * (rng.random() - .5)
        v.co = Vector((c.x * radii[0] * k, c.y * radii[1] * k, c.z * radii[2] * k))
    return finish(obj, mat, True)


# --------------------------------------------------------------------------------------
# Horse
# --------------------------------------------------------------------------------------
def horse_rig():
    bones = [
        ("root", (0, 0, .1), (0, 0, .9), None),
        ("body", (0, -.1, 1.2), (0, .7, 1.5), "root"),
        ("neck", (0, .62, 1.43), (0, 1.08, 2.06), "body"),
        ("head", (0, 1.08, 2.06), (0, 1.73, 1.83), "neck"),
        ("tail", (0, -.9, 1.5), (0, -1.48, .95), "body"),
        ("rider", (0, -.12, 1.75), (0, -.1, 2.6), "body"),
    ]
    joints = {}
    for side, x in [("L", -.275), ("R", .275)]:
        for kind in ["F", "H"]:
            if kind == "F":
                points = [(x, .66, 1.34), (x, .69, .74), (x, .63, .23), (x, .72, .07)]
            else:
                points = [(x, -.67, 1.34), (x, -.43, .90), (x, -.77, .47), (x, -.69, .07)]
            key = kind + side
            joints[key] = points
            bones.extend([
                (key + "_upper", points[0], points[1], "body"),
                (key + "_lower", points[1], points[2], key + "_upper"),
                (key + "_foot", points[2], points[3], key + "_lower"),
            ])
    return armature("Horse_and_rider_skeleton", bones), joints


def build_horse(m, rig, joints, markings=False):
    # Counter-shading: dorsal lighter, belly and lower legs darker (painted into COLOR_0).
    def countershade(p):
        t = np.clip((p[:, 2] - .95) / .85, 0, 1)
        return (.74 + .36 * t)[:, None] * np.array([1.0, .95, .9])[None, :]

    o = rings_y("Horse | continuous barrel and croup", [
        (-.96, 1.32, .045, .11), (-.85, 1.34, .23, .33),
        (-.65, 1.31, .33, .4), (-.35, 1.29, .36, .43),
        (0, 1.29, .355, .43), (.3, 1.30, .33, .44),
        (.58, 1.34, .295, .4), (.78, 1.35, .24, .31), (.91, 1.4, .08, .16)
    ], m["horse"], 28, "body", rig)
    paint_fn(o, countershade)
    for side in [-1, 1]:
        o = sphere("Horse | gluteal haunch", (side * .19, -.6, 1.43), (.17, .31, .30), m["horse"], "body", rig, 14, 9)
        paint_fn(o, countershade)
        o = sphere("Horse | flank belly", (side * .13, .0, 1.02), (.2, .5, .17), m["horse"], "body", rig, 12, 8)
        paint_fn(o, countershade)
    o = sphere("Horse | deep chest", (0, .66, 1.3), (.27, .24, .33), m["horse"], "body", rig, 16, 10)
    paint_fn(o, countershade)
    o = sphere("Horse | withers", (0, .38, 1.68), (.11, .22, .1), m["horse"], "body", rig, 12, 8)
    o = rings_z("Horse | sculpted rising neck", [
        (1.15, .61, .24, .27), (1.38, .73, .255, .31),
        (1.6, .85, .22, .28), (1.82, 1.00, .185, .24),
        (2.02, 1.12, .155, .19), (2.16, 1.17, .115, .10)
    ], m["horse"], 22, "neck", rig)
    paint_fn(o, lambda p: (.78 + .22 * np.clip((p[:, 2] - 1.2) / .9, 0, 1))[:, None])
    rings_y("Horse | angular skull and face", [
        (1.04, 2.06, .09, .14), (1.18, 2.07, .16, .21),
        (1.33, 2.02, .15, .22), (1.5, 1.91, .115, .17),
        (1.68, 1.81, .115, .13), (1.78, 1.79, .09, .095)
    ], m["horse"], 20, "head", rig)
    sphere("Horse | velvet nose", (0, 1.73, 1.79), (.118, .12, .10), m["muzzle"], "head", rig)
    sphere("Horse | lower lip", (0, 1.70, 1.725), (.07, .075, .045), m["muzzle"], "head", rig, 12, 8)
    for side in [-1, 1]:
        sphere("Horse | masseter", (side * .11, 1.22, 1.96), (.10, .15, .15), m["horse"], "head", rig)
        sphere("Horse | eye rim", (side * .146, 1.31, 2.08), (.032, .049, .036), m["horse_dark"], "head", rig)
        sphere("Horse | eye", (side * .165, 1.326, 2.09), (.013, .028, .021), m["eye"], "head", rig)
        sphere("Horse | nostril", (side * .093, 1.785, 1.82), (.022, .022, .035), m["black"], "head", rig)
        verts = [(side*.08,1.13,2.16),(side*.15,1.12,2.39),(side*.20,1.19,2.18),
                 (side*.12,1.23,2.17),(side*.145,1.18,2.33)]
        mesh("Horse | pointed ear", verts, [(0,1,2),(0,3,4,1),(1,4,2),(2,4,3),(0,2,3)],m["horse"],True,"head",rig)
        tube("Horse | facial bridle", [(side*.165,1.18,2.12),(side*.18,1.3,1.98),(side*.12,1.68,1.79)],.014,m["leather"],"head",rig)
        tube("Horse | reins", [(side*.12,1.68,1.79),(side*.19,.93,1.87),(side*.15,.36,2.08)],.012,m["leather"],"body",rig)
        sphere("Horse | bit ring", (side*.132,1.66,1.78), (.026,.026,.026),m["brass"],"head",rig,12,6)
    tube("Horse | noseband", [(-.12,1.66,1.82),(0,1.70,1.90),(.12,1.66,1.82)],.017,m["leather"],"head",rig)
    tube("Horse | browband", [(-.17,1.2,2.14),(0,1.22,2.2),(.17,1.2,2.14)],.017,m["leather"],"head",rig)
    if markings:
        # A narrow blaze and two white socks: artistic variety, not an identified animal.
        tube("Horse | blaze", [(0, 1.3, 2.255), (0, 1.5, 2.09), (0, 1.68, 1.95), (0, 1.76, 1.90)],
             .026, m["blaze"], "head", rig)
    mane_rows=[(.56,1.64),(.66,1.83),(.79,1.99),(.97,2.15),(1.12,2.23)]
    verts=[]
    for y,z in mane_rows:
        verts.extend([(-.065,y,z),(.035,y-.05,z+.08),(.09,y-.09,z-.15)])
    faces=[]
    for i in range(len(mane_rows)-1):
        for j in [0,1]:
            faces.append((i*3+j,(i+1)*3+j,(i+1)*3+j+1,i*3+j+1))
    mesh("Horse | falling mane",verts,faces,m["hair"],True,"neck",rig)
    for k in range(13):
        t = k / 12.0
        y = .56 + (1.12 - .56) * t
        z = 1.64 + (2.23 - 1.64) * t
        tube("Horse | mane lock", [(0.0, y, z + .03), (.05, y - .03, z - .06), (.10 + .01 * (k % 3), y - .06, z - .19)],
             .017, m["hair"], "neck", rig)
    tube("Horse | forelock", [(0, 1.12, 2.22), (0, 1.22, 2.24), (.01, 1.34, 2.14)], .024, m["hair"], "head", rig)
    tube("Horse | forelock side", [(.03, 1.13, 2.2), (.07, 1.24, 2.2), (.08, 1.32, 2.1)], .016, m["hair"], "head", rig)
    for k in range(15):
        x=(k-7)*.011
        tube("Horse | tail hair",[(x,-.91,1.54),(x*1.6,-1.24,1.22),(x*1.2,-1.49,.81),(x*.6,-1.48-.02*(k%3),.50+.03*(k%4))],.02,m["hair"],"tail",rig)
    for key, pts in joints.items():
        upper, lower, foot = key+"_upper", key+"_lower", key+"_foot"
        hip,knee,ankle,toe=pts
        if key[0]=="F":
            sphere("Horse | "+key+" shoulder muscle",(hip[0],hip[1]-.035,hip[2]-.04),(.125,.17,.245),m["horse"],upper,rig)
        sock = markings and key in ("FR", "HL")
        o = segment("Horse | "+key+" upper muscle",hip,knee,.145 if key[0]=="H" else .112,.069,m["horse"],upper,rig,16)
        paint_fn(o, lambda p: (.62 + .46 * np.clip((p[:, 2] - .7) / .65, 0, 1))[:, None])
        sphere("Horse | "+key+" joint",knee,(.071,.077,.078),m["horse_dark"],lower,rig)
        segment("Horse | "+key+" cannon",knee,ankle,.063,.041,m["horse_dark"],lower,rig)
        sphere("Horse | "+key+" fetlock",ankle,(.054,.06,.06),m["blaze"] if sock else m["horse_dark"],foot,rig)
        segment("Horse | "+key+" pastern",ankle,toe,.043,.052,m["blaze"] if sock else m["horse_dark"],foot,rig)
        hv=[]
        for z,rx,ry in [(.015,.071,.09),(.135,.054,.067)]:
            for j in range(14):
                t=2*math.pi*j/14
                hv.append((toe[0]+rx*math.cos(t),toe[1]+.035+ry*math.sin(t),z))
        hf=[(j,(j+1)%14,(j+1)%14+14,j+14) for j in range(14)]
        hf.extend([tuple(reversed(range(14))),tuple(range(14,28))])
        mesh("Horse | "+key+" hoof",hv,hf,m["hoof"],True,foot,rig)
    # A woven saddle cloth following the barrel, with a leather seat on top.
    verts=[]
    for y in [-.49,.34]:
        verts.extend([(-.38,y,1.23),(-.35,y,1.55),(-.18,y,1.73),(.18,y,1.73),(.35,y,1.55),(.38,y,1.23)])
    mesh("Tack | saddle blanket",verts,[(i,i+1,i+7,i+6) for i in range(5)],m["cream"],False,"body",rig)
    box("Tack | leather seat",(0,-.06,1.765),(.47,.57,.09),m["leather"],.04,"body",rig)
    for y in [-.37,.23]:
        tube("Tack | saddle raised edge",[(-.24,y,1.78),(-.15,y,1.86),(.15,y,1.86),(.24,y,1.78)],.045,m["leather"],"body",rig)
    for side in [-1,1]:
        tube("Tack | stirrup leather",[(side*.23,.07,1.79),(side*.4,.1,1.38),(side*.44,.2,1.07)],.021,m["leather"],"body",rig)
        tube("Tack | iron stirrup",[(side*.44,.2,1.15),(side*.52,.2,1.02),(side*.36,.2,1.02),(side*.44,.2,1.15)],.016,m["metal"],"body",rig)
        box("Tack | stirrup buckle", (side*.34, .08, 1.62), (.04, .02, .05), m["brass"], .004, "body", rig)
    tube("Tack | girth",[(-.35,.2,1.54),(-.35,.2,1.03),(0,.2,.90),(.35,.2,1.03),(.35,.2,1.54)],.028,m["leather"],"body",rig)
    tube("Tack | breastband", [(-.36, .22, 1.5), (-.28, .7, 1.35), (0, .87, 1.28), (.28, .7, 1.35), (.36, .22, 1.5)], .02, m["leather"], "body", rig)
    tube("Tack | crupper", [(-.2, -.4, 1.72), (-.25, -.85, 1.55), (0, -.95, 1.5), (.25, -.85, 1.55), (.2, -.4, 1.72)], .018, m["leather"], "body", rig)


# --------------------------------------------------------------------------------------
# People
# --------------------------------------------------------------------------------------
def human_head(m, rig, bone, pos, hat="wide", beard=False, small=False, cockade=None):
    x,y,z=pos
    size=.94 if small else 1.0
    sphere("Rider | skull",(x,y,z),(.111*size,.118*size,.15*size),m["skin"],bone,rig)
    sphere("Rider | hair", (x, y - .018, z + .028), (.116 * size, .118 * size, .135 * size), m["hair"], bone, rig, 14, 8)
    # Deliberate jaw / brow / nose silhouette; eyes lie on the forward +Y side.
    sphere("Rider | jaw",(x,y+.014,z-.078),(.089*size,.09*size,.07*size),m["skin"],bone,rig)
    sphere("Rider | chin", (x, y + .045, z - .12), (.05 * size, .05 * size, .035 * size), m["skin"], bone, rig, 10, 6)
    mesh("Rider | nose",[(x-.026,y+.103,z+.005),(x+.026,y+.103,z+.005),(x,y+.154,z-.028),(x,y+.10,z-.045)],[(0,1,2),(0,2,3),(1,3,2)],m["skinlight"],False,bone,rig)
    tube("Rider | mouth", [(x - .03, y + .10, z - .082), (x, y + .108, z - .088), (x + .03, y + .10, z - .082)], .006,
         m["horse_dark"], bone, rig)
    for side in [-1,1]:
        sphere("Rider | ear",(x+side*.112,y,z-.01),(.024,.029,.046),m["skin"],bone,rig,12,8)
        sphere("Rider | eye",(x+side*.045,y+.107,z+.022),(.014,.008,.01),m["eye"],bone,rig,12,6)
        tube("Rider | brow",[(x+side*.023,y+.111,z+.048),(x+side*.068,y+.098,z+.043)],.009,m["hair"],bone,rig)
    if beard:
        sphere("Rider | short beard",(x,y+.035,z-.098),(.091,.079,.054),m["hair"],bone,rig)
        tube("Rider | moustache",[(x-.047,y+.112,z-.054),(x,y+.126,z-.050),(x+.047,y+.112,z-.054)],.012,m["hair"],bone,rig)
    if hat=="wide":
        sphere("Hat | broad felt brim",(x,y,z+.12),(.255,.24,.026),m["black"],bone,rig,24,8)
        segment("Hat | crown",(x,y,z+.12),(x,y,z+.245),.125,.105,m["black"],bone,rig,20)
        segment("Hat | leather band",(x,y,z+.13),(x,y,z+.16),.127,.124,m["leather"],bone,rig,20)
    elif hat == "bicorne":
        sphere("Hat | bicorne crown",(x,y,z+.13),(.14,.12,.09),m["black"],bone,rig)
        verts=[(x-.30,y,z+.14),(x-.12,y-.085,z+.29),(x+.12,y-.085,z+.29),(x+.30,y,z+.14),
               (x+.10,y+.10,z+.23),(x-.10,y+.10,z+.23),(x-.26,y+.02,z+.12),(x+.26,y+.02,z+.12)]
        mesh("Hat | folded bicorne",verts,[(0,1,2,3),(0,5,4,3),(0,3,7,6),(0,6,5),(3,4,7)],m["black"],False,bone,rig)
        sphere("Hat | plain cockade",(x-.14,y+.055,z+.21),(.023,.012,.023),cockade or m["cream"],bone,rig,12,6)
    elif hat == "shako_british":
        # 1800-1812 pattern "stovepipe": tall, black, brass plate; plain, no regimental badge.
        segment("Hat | stovepipe shako", (x, y, z + .06), (x, y, z + .31), .118, .128, m["black"], bone, rig, 20)
        segment("Hat | shako top", (x, y, z + .31), (x, y, z + .325), .13, .13, m["black"], bone, rig, 20)
        box("Hat | shako peak", (x, y + .13, z + .075), (.2, .11, .012), m["black"], .004, bone, rig)
        box("Hat | plain brass plate", (x, y + .12, z + .2), (.1, .012, .09), m["brass"], .004, bone, rig)
        sphere("Hat | cockade", (x - .08, y + .125, z + .29), (.022, .01, .022), cockade or m["facing"], bone, rig, 10, 6)
        segment("Hat | worsted tuft", (x + .0, y + .0, z + .325), (x, y, z + .39), .012, .03, m["white"], bone, rig, 8)
    else:   # shako_royalist
        segment("Hat | campaign shako", (x, y, z + .06), (x, y, z + .25), .113, .12, m["black"], bone, rig, 20)
        box("Hat | shako peak", (x, y + .125, z + .075), (.19, .10, .012), m["black"], .004, bone, rig)
        box("Hat | plain tin plate", (x, y + .115, z + .17), (.08, .012, .07), m["metal"], .004, bone, rig)


def mounted_rider(m, rig, period):
    bone="rider"
    cloth=m["coat"] if period==1806 else m["poncho"]
    pants=m["cream"] if period==1806 else m["trouser"]
    rings_z("Rider | tailored torso",[(1.86,-.10,.17,.12),(2.05,-.12,.18,.13),(2.25,-.10,.22,.14),(2.46,-.075,.24,.14),(2.56,-.06,.13,.095)],cloth,16,bone,rig)
    segment("Rider | neck",(0,-.06,2.5),(0,-.06,2.67),.065,.063,m["skin"],bone,rig)
    human_head(m,rig,bone,(0,-.035,2.76),"bicorne" if period==1806 else "wide",period==1817,
               cockade=m["facing"] if period==1806 else None)
    box("Rider | sash",(0,-.11,2.01),(.38,.27,.09),m["poncho"] if period==1806 else m["stripe"],.025,bone,rig)
    for side in [-1,1]:
        hip=(side*.14,-.10,1.92); knee=(side*.43,.22,1.53); ankle=(side*.43,.18,1.08)
        segment("Rider | thigh",hip,knee,.115,.08,pants,bone,rig,16)
        sphere("Rider | knee",knee,(.084,.094,.09),pants,bone,rig)
        segment("Rider | boot shaft",knee,ankle,.081,.058,m["boot"],bone,rig)
        box("Rider | boot toe",(side*.43,.26,1.06),(.14,.29,.12),m["boot"],.025,bone,rig)
        box("Rider | boot heel", (side * .43, .07, 1.0), (.09, .08, .06), m["boot"], .012, bone, rig)
        sphere("Rider | spur boss", (side * .5, .06, 1.04), (.018, .018, .018), m["brass"], bone, rig, 8, 5)
        tube("Rider | spur arm", [(side * .5, .06, 1.04), (side * .46, .0, 1.05), (side * .36, .0, 1.05)], .008, m["brass"], bone, rig)
        sphere("Rider | spur rowel", (side * .5, .06, 1.04), (.012, .03, .03), m["brass"], bone, rig, 8, 5)
        shoulder=(side*.215,-.075,2.44); elbow=(side*.3,.09,2.23); hand=(side*.15,.37,2.10)
        segment("Rider | upper sleeve",shoulder,elbow,.085,.068,cloth,bone,rig)
        segment("Rider | bent sleeve",elbow,hand,.068,.043,cloth,bone,rig)
        sphere("Rider | hand on reins",hand,(.044,.064,.044),m["skin"],bone,rig)
        d = (Vector(hand) - Vector(elbow)).normalized()
        if period == 1806:
            segment("Rider | coat cuff", Vector(hand) - d * .11, Vector(hand) - d * .02, .056, .052, m["facing"], bone, rig)
            box("Rider | shoulder tab",(side*.2,-.07,2.515),(.11,.18,.025),m["facing"],.008,bone,rig)
            sphere("Rider | epaulette fringe", (side * .245, -.07, 2.5), (.035, .035, .02), m["brass"], bone, rig, 8, 5)
    if period==1806:
        # Visible buttons and crossbelt, without claiming an exact surviving uniform.
        segment("Rider | stand collar", (0, -.06, 2.5), (0, -.06, 2.585), .09, .082, m["facing"], bone, rig, 16)
        segment("Rider | black stock", (0, -.055, 2.585), (0, -.055, 2.635), .07, .068, m["black"], bone, rig, 14)
        for z in [2.14,2.25,2.36,2.46]:
            sphere("Rider | brass button",(0,.043,z),(.013,.008,.013),m["brass"],bone,rig,10,6)
        tube("Rider | buff crossbelt",[(-.18,.035,2.49),(0,.058,2.28),(.17,.025,2.03)],.026,m["cream"],bone,rig)
        box("Rider | cartridge case", (.27, -.27, 2.0), (.2, .09, .15), m["leather"], .02, bone, rig)
        box("Rider | case flap plate", (.27, -.325, 2.0), (.07, .012, .07), m["brass"], .004, bone, rig)
        for side in [-1,1]:
            mesh("Rider | coat tail",[(side*.17,-.20,2.05),(side*.25,-.30,1.62),(side*.04,-.35,1.67),(side*.03,-.24,2.05)],[(0,1,2,3)],cloth,False,bone,rig)
            mesh("Rider | coat tail lining", [(side*.17,-.20,2.05),(side*.25,-.30,1.62),(side*.22,-.30,1.7),(side*.15,-.21,2.05)], [(0,1,2,3)], m["facing"], False, bone, rig)
        # Holster and pistol grip at the saddle bow.
        box("Tack | holster", (.28, .5, 1.88), (.11, .36, .13), m["leather"], .03, bone, rig)
        sphere("Tack | pistol butt", (.28, .30, 1.94), (.045, .06, .05), m["wood"], bone, rig, 10, 6)
    else:
        # Draped cloth over the shoulders and saddle, not a sphere around the torso.
        xs=[-.35,-.12,0,.12,.35]
        zs=[2.42,2.57,2.57,2.57,2.42]
        front_y=[.19,.115,.12,.115,.19]
        back_y=[-.26,-.19,-.20,-.19,-.26]
        verts=[]
        for row in range(4):
            for i,x in enumerate(xs):
                if row==0:verts.append((x,front_y[i],zs[i]))
                elif row==1:verts.append((x*1.16,.29+.025*math.cos(x*9),1.87-.04*abs(x)))
                elif row==2:verts.append((x,back_y[i],zs[i]))
                else:verts.append((x*1.22,-.40-.015*math.cos(x*9),1.80-.04*abs(x)))
        faces=[]
        for i in range(4):
            faces.append((i,i+1,i+6,i+5))
            faces.append((10+i,15+i,16+i,11+i))
        faces.extend([(0,5,15,10),(4,14,19,9),(0,10,11,1),(3,13,14,4)])
        mesh("Rider | draped poncho",verts,faces,cloth,False,bone,rig)
        tube("Rider | woven hem back",[(-.427,-.40,1.82),(0,-.415,1.83),(.427,-.40,1.82)],.024,m["stripe"],bone,rig)
        tube("Rider | woven hem front",[(-.406,.265,1.90),(0,.315,1.91),(.406,.265,1.90)],.025,m["stripe"],bone,rig)
        segment("Rider | poncho neck collar", (0, -.06, 2.50), (0, -.06, 2.585), .125, .098, cloth, bone, rig, 16)
        segment("Rider | neck kerchief", (0, -.06, 2.585), (0, -.06, 2.64), .075, .072, m["kerchief"], bone, rig, 14)
        sphere("Rider | kerchief knot", (0, .03, 2.60), (.03, .025, .03), m["kerchief"], bone, rig, 8, 5)
        tube("Rider | hat chin strap", [(-.108, -.03, 2.74), (-.07, .03, 2.63), (.07, .03, 2.63), (.108, -.03, 2.74)], .005, m["leather"], bone, rig)
        # Recado: sheepskin pellon over the saddle, plus gaucho gear.
        box("Tack | sheepskin pellon", (0, -.06, 1.83), (.62, .78, .06), m["pelt"], .03, bone, rig)
        torus("Tack | lazo coil", (0, -.50, 1.88), .17, .028, (0, 0, 0), m["leather"], bone, rig, 18, 6)
        torus("Tack | lazo coil", (0, -.50, 1.93), .15, .026, (0, 0, 0), m["leather"], bone, rig, 18, 6)
        for k, (bx, by, bz) in enumerate([(-.30, .52, 1.62), (-.36, .45, 1.55), (-.27, .44, 1.54)]):
            sphere("Tack | boleadora stone", (bx, by, bz), (.05, .05, .05), m["leather"], bone, rig, 10, 6)
        tube("Tack | boleadora thongs", [(-.30, .52, 1.62), (-.32, .46, 1.74), (-.36, .45, 1.55)], .007, m["leather"], bone, rig)
        tube("Tack | boleadora thongs", [(-.32, .46, 1.74), (-.27, .44, 1.54)], .007, m["leather"], bone, rig)
        # Rebenque (short whip) in the right hand.
        segment("Rider | whip handle", (.15, .36, 2.12), (.20, .52, 1.97), .018, .016, m["wood"], bone, rig, 8)
        tube("Rider | whip lash", [(.20, .52, 1.97), (.26, .58, 1.80), (.30, .6, 1.62)], .008, m["leather"], bone, rig)
    tube("Rider | sabre scabbard",[(-.27,-.22,2.02),(-.42,-.37,1.62),(-.48,-.52,1.31)],.025,m["boot"],bone,rig)
    sphere("Rider | scabbard tip", (-.48, -.52, 1.30), (.03, .03, .035), m["metal"], bone, rig, 8, 5)
    segment("Rider | sabre grip",(-.26,-.20,2.01),(-.22,-.17,2.19),.023,.023,m["leather"],bone,rig)
    sphere("Rider | sabre pommel", (-.215, -.165, 2.21), (.026, .026, .026), m["brass"], bone, rig, 8, 5)
    tube("Rider | sabre guard",[(-.27,-.22,2.04),(-.33,-.20,2.12),(-.28,-.17,2.20),(-.22,-.17,2.19)],.013,m["brass"],bone,rig)


def keyframe_bone(rig, name, frame, loc=None, rot=None, group=None):
    b = rig.pose.bones[name]
    b.rotation_mode = "XYZ"
    if loc is not None:
        b.location = loc
        b.keyframe_insert("location", frame=frame, group=group or name)
    if rot is not None:
        b.rotation_euler = rot
        b.keyframe_insert("rotation_euler", frame=frame, group=group or name)


def animate_trot(rig):
    rig.animation_data_create()
    action=bpy.data.actions.new("trot")
    rig.animation_data.action=action
    for f in range(1,26,3):
        phase=(f-1)/24*2*math.pi
        for key in ["FL","FR","HL","HR"]:
            p=phase+(0 if key in ["FL","HR"] else math.pi)
            knee_direction=-1 if key[0]=="F" else 1
            for suffix,angle in [("upper",.29*math.sin(p)),("lower",knee_direction*(.03+.36*max(0,math.cos(p)))),("foot",-.10*math.sin(p))]:
                keyframe_bone(rig, key + "_" + suffix, f, rot=(angle, 0, 0), group=key)
        # Two suspension phases per cycle: bob and a little pitch; lateral weight shift once per cycle.
        keyframe_bone(rig, "body", f, loc=(.012 * math.sin(phase), 0, .028 * math.cos(phase * 2)),
                      rot=(.012 * math.sin(phase * 2 + .6), 0, .0))
        # Rider bone points up: Y = vertical, X = pitch, Z = lean, Y rotation = twist.
        keyframe_bone(rig, "rider", f, loc=(0, .018 * math.cos(phase * 2 + math.pi * .35), 0),
                      rot=(.035 * math.sin(phase * 2), .02 * math.sin(phase), .028 * math.sin(phase)))
        keyframe_bone(rig, "neck", f, rot=(.03 * math.sin(phase * 2 - .5), 0, .015 * math.sin(phase)))
        keyframe_bone(rig, "head", f, rot=(.02 * math.sin(phase * 2 - 1.0), .0, -.02 * math.sin(phase)))
        keyframe_bone(rig, "tail", f, rot=(.09 * math.sin(phase * 2 - .8), 0, .07 * math.sin(phase + .5)))
    for fcurve in action.fcurves:
        for key in fcurve.keyframe_points:
            key.interpolation="BEZIER"
        fcurve.modifiers.new("CYCLES")
    bpy.context.scene.frame_start=1; bpy.context.scene.frame_end=25
    bpy.context.scene.frame_set(1)


def mounted(period):
    reset(); m=palette()
    if period==1817:
        m["horse"] = material("Horse | dun criollo", (.15, .135, .105), kind="coat")
        m["horse_dark"] = material("Horse | dun dark points", (.06, .052, .04), kind="coat")
    rig,joints=horse_rig()
    build_horse(m,rig,joints, markings=(period == 1806))
    mounted_rider(m,rig,period)
    animate_trot(rig)
    export("rider_"+str(period),["trot"])


def horse_only():
    reset();m=palette()
    rig,joints=horse_rig()
    build_horse(m,rig,joints, markings=True)
    animate_trot(rig)
    export("horse_only",["trot"])


def foot_soldier(name, variant):
    """variant: 'british' (Justine crew), 'royalist' (1817 aggregate) or 'dismounted' (1806 riders on foot)."""
    reset(); m=palette()
    bones=[("root",(0,0,.05),(0,0,.8),None),
           ("body",(0,0,.93),(0,0,1.48),"root"),
           ("head",(0,0,1.45),(0,0,1.72),"body")]
    for side,x in [("L",-.11),("R",.11)]:
        bones.extend([(side+"_thigh",(x,0,.98),(x,.015,.53),"root"),
                      (side+"_shin",(x,.015,.53),(x,0,.10),side+"_thigh")])
    rig=armature("Dismounted_skeleton",bones)
    cloth={"british": m["redcoat"], "royalist": m["whitecoat"], "dismounted": m["coat"]}[variant]
    facing={"british": m["facing"], "royalist": m["blue_facing"], "dismounted": m["facing"]}[variant]
    pants = m["white"] if variant != "dismounted" else m["cream"]
    rings_z("Soldier | tailored coat",[(.86,-.015,.16,.09),(1.02,0,.15,.10),(1.20,0,.185,.105),(1.39,0,.20,.11),(1.48,0,.11,.085)],cloth,16,"body",rig)
    segment("Soldier | neck",(0,0,1.45),(0,0,1.56),.055,.055,m["skin"],"head",rig)
    segment("Soldier | standing collar", (0, 0, 1.44), (0, 0, 1.53), .085, .075, facing, "body", rig, 14)
    segment("Soldier | black stock", (0, 0, 1.53), (0, 0, 1.575), .06, .058, m["black"], "head", rig, 12)
    hat = {"british": "shako_british", "royalist": "shako_royalist", "dismounted": "bicorne"}[variant]
    human_head(m,rig,"head",(0,.005,1.65),hat,False,True, cockade=m["facing"])
    # Coat turn-backs hanging behind the hips.
    for side in [-1, 1]:
        mesh("Soldier | coat skirt", [(side * .16, -.09, .98), (side * .19, -.12, .72), (side * .02, -.13, .72), (side * .02, -.09, .98)],
             [(0, 1, 2, 3)], cloth, False, "body", rig)
        mesh("Soldier | skirt turnback", [(side * .16, -.09, .98), (side * .19, -.12, .72), (side * .165, -.12, .76), (side * .14, -.09, .98)],
             [(0, 1, 2, 3)], facing, False, "body", rig)
    for side,x in [("L",-.11),("R",.11)]:
        hip=(x,0,.97); knee=(x,.015,.53); ankle=(x,0,.10)
        segment("Soldier | breeches",hip,knee,.099,.065,pants,side+"_thigh",rig,16)
        sphere("Soldier | knee",knee,(.067,.067,.074),pants,side+"_shin",rig)
        segment("Soldier | gaiter",knee,ankle,.063,.045,m["boot"] if variant == "dismounted" else m["black"],side+"_shin",rig)
        box("Soldier | shoe",(x,.072,.06),(.135,.25,.12),m["boot"],.025,side+"_shin",rig)
        for z in [.42, .32, .22]:
            sphere("Soldier | gaiter button", (x + (.06 if x > 0 else -.06), .02, z), (.011, .007, .011), m["metal"], side + "_shin", rig, 8, 5)
    for side in [-1,1]:
        shoulder=(side*.19,0,1.39); elbow=(side*.25,.035,1.13)
        hand=(side*.12,.20,1.10) if side<0 else (side*.17,.17,.99)
        segment("Soldier | upper sleeve",shoulder,elbow,.073,.056,cloth,"body",rig)
        segment("Soldier | forearm sleeve",elbow,hand,.055,.036,cloth,"body",rig)
        d = (Vector(hand) - Vector(elbow)).normalized()
        segment("Soldier | cuff", Vector(hand) - d * .10, Vector(hand) - d * .02, .05, .047, facing, "body", rig)
        sphere("Soldier | hand",hand,(.035,.05,.039),m["skin"],"body",rig)
        sphere("Soldier | shoulder wing", (side * .2, 0, 1.43), (.055, .05, .02), facing, "body", rig, 10, 6)
    box("Soldier | waistbelt",(0,.015,1.03),(.32,.20,.055),m["cream"],.009,"body",rig)
    box("Soldier | buckle",(0,.12,1.03),(.048,.02,.046),m["brass"],.003,"body",rig)
    tube("Soldier | crossbelt",[(-.16,.08,1.44),(0,.125,1.22),(.15,.09,1.03)],.024,m["cream"],"body",rig)
    if variant == "british":
        tube("Soldier | second crossbelt",[(.16,.08,1.44),(0,.127,1.22),(-.15,.09,1.03)],.023,m["cream"],"body",rig)
        box("Soldier | plain breast plate", (.0, .135, 1.2), (.06, .01, .05), m["brass"], .003, "body", rig)
    for z in [1.13,1.23,1.33,1.42]:
        sphere("Soldier | brass button",(0,.11,z),(.011,.007,.011),m["brass"] if variant != "royalist" else m["metal"],"body",rig,10,6)
    # Kit: pouch and canteen for every figure; pack for line infantry; sabre for the dismounted cavalry.
    box("Soldier | cartridge pouch", (.17, -.1, 1.0), (.17, .08, .14), m["leather"], .015, "body", rig)
    segment("Soldier | canteen", (-.2, -.06, .88), (-.2, -.06, 1.0), .062, .062, m["wood"], "body", rig, 12)
    tube("Soldier | canteen cord", [(-.2, -.06, 1.0), (-.12, -.1, 1.4), (.1, -.1, 1.42)], .006, m["leather"], "body", rig)
    if variant != "dismounted":
        box("Soldier | knapsack", (0, -.16, 1.2), (.30, .12, .34), m["leather"], .02, "body", rig)
        segment("Soldier | rolled blanket", (-.17, -.16, 1.42), (.17, -.16, 1.42), .06, .06, m["cream"] if variant == "british" else m["trouser"], "body", rig, 12)
    else:
        tube("Soldier | sabre scabbard", [(-.19, -.02, 1.0), (-.24, -.12, .7), (-.26, -.2, .35)], .022, m["boot"], "body", rig)
        segment("Soldier | sabre grip", (-.19, -.02, 1.0), (-.18, 0.0, 1.14), .02, .02, m["leather"], "body", rig, 8)
        tube("Soldier | sabre guard", [(-.22, -.03, 1.02), (-.2, 0.03, 1.07)], .01, m["brass"], "body", rig)
    # Musket at an upward diagonal across the chest; no anachronistic optics.
    a=(-.22,.21,.89); b=(.35,.20,1.85)
    segment("Musket | walnut stock",a,(.07,.20,1.38),.042,.026,m["wood"],"body",rig)
    segment("Musket | iron barrel",(-.04,.20,1.18),b,.017,.014,m["metal"],"body",rig)
    box("Musket | lock",(-.035,.237,1.21),(.07,.028,.07),m["metal"],.007,"body",rig)
    tube("Musket | sling", [(-.2, .21, .93), (-.12, .22, 1.2), (.05, .22, 1.4)], .006, m["leather"], "body", rig)
    if variant != "dismounted":
        segment("Musket | socket bayonet", b, (b[0] + .12, b[1], b[2] + .2), .014, .005, m["metal"], "body", rig, 6)
    rig.animation_data_create(); action=bpy.data.actions.new("walk");rig.animation_data.action=action
    for f in range(1,26,3):
        phase=(f-1)/24*2*math.pi
        for side,offset in [("L",0),("R",math.pi)]:
            for suffix,angle in [("_thigh",.32*math.sin(phase+offset)),("_shin",.35*max(0,-math.sin(phase+offset)))]:
                keyframe_bone(rig, side + suffix, f, rot=(angle, 0, 0), group=side)
        # Body bone points up: local Y is vertical, Z leans, Y-rotation twists the shoulders.
        keyframe_bone(rig, "body", f, loc=(0, .018 * math.cos(phase * 2), 0),
                      rot=(.02 * math.sin(phase * 2 + .5), -.04 * math.sin(phase), .022 * math.sin(phase)))
        keyframe_bone(rig, "head", f, rot=(0, .03 * math.sin(phase), -.015 * math.sin(phase)))
    for curve in action.fcurves:
        curve.modifiers.new("CYCLES")
    bpy.context.scene.frame_start=1;bpy.context.scene.frame_end=25;bpy.context.scene.frame_set(1)
    export(name,["walk"])


# --------------------------------------------------------------------------------------
# Justine (merchant ship)
# --------------------------------------------------------------------------------------
STATIONS=[(-7,.27),(-6.7,.9),(-6.2,1.5),(-5.5,1.99),(-4.6,2.28),(-3.4,2.43),
          (-2,2.5),(0,2.5),(2,2.39),(3.7,2.13),(5,1.70),(6,1.13),(6.8,.5),(7,.05)]


def width_at(y):
    for (a,wa),(b,wb) in zip(STATIONS,STATIONS[1:]):
        if a<=y<=b:
            return wa+(wb-wa)*(y-a)/(b-a)
    return STATIONS[0][1] if y<STATIONS[0][0] else STATIONS[-1][1]


def sheer(y):
    return .28*(abs(y)/7)**3


def sail(name,y,top,height,width,mat):
    verts=[]; faces=[]; nx=12;nz=8
    for j in range(nz+1):
        v=j/nz
        for i in range(nx+1):
            u=i/nx
            x=(u-.5)*width*(1-.08*v)
            z=top-v*height-.12*math.sin(u*math.pi)*v
            yy=y-.09-.32*math.sin(u*math.pi)*math.sin(v*math.pi)
            verts.append((x,yy,z))
    for j in range(nz):
        for i in range(nx):
            a=j*(nx+1)+i;faces.append((a,a+1,a+nx+2,a+nx+1))
    ob=mesh(name,verts,faces,mat,True)
    # Dirtier towards the foot of the sail.
    paint_fn(ob, lambda p: (.74 + .26 * np.clip((p[:, 2] - (top - height)) / height, 0, 1))[:, None])
    return ob


def ship():
    reset();m=palette()
    wood=[material("Hull | oak plank %02d"%i,(.14+i*.012,.065+i*.006,.025+i*.0025),kind="planks") for i in range(7)]
    deckmat=material("Deck | weathered timber",(.33,.235,.13),kind="deckplanks")
    pale=material("Hull | pale gun strake",(.50,.41,.26),kind="planks")
    rope=material("Rigging | tarred hemp",(.08,.065,.038),kind="linen")
    linen=material("Sail | weathered flax",(.66,.61,.46),kind="sail")
    seam=material("Sail | sewn seams",(.40,.36,.25),kind="linen")
    # Continuous hollow U cross-section, rounded below water and flared above it.
    profile=[(-1,3.5),(-1,3.1),(-.99,2.5),(-.97,1.8),(-.91,1),(-.77,.15),(-.52,-.70),(-.24,-1.2),
             (0,-1.45),(.24,-1.2),(.52,-.70),(.77,.15),(.91,1),(.97,1.8),(.99,2.5),(1,3.1),(1,3.5)]
    verts=[];faces=[]
    for y,w in STATIONS:
        for x,z in profile:
            # Keel rises naturally towards stem and stern.
            bottom_rise=max(0,(abs(y)-5)/2)*.85 if z<1 else 0
            verts.append((x*w,y,z+sheer(y)+bottom_rise))
    pcount=len(profile)
    for i in range(len(STATIONS)-1):
        for j in range(pcount-1):
            a=i*pcount+j;faces.append((a,a+pcount,a+pcount+1,a+1))
    faces.append(tuple(reversed(range(pcount))))
    faces.append(tuple((len(STATIONS)-1)*pcount+j for j in range(pcount)))
    hull=mesh("Justine | curved merchant hull",verts,faces,wood[0],True)
    paint_poly(hull, lambda poly: wood[(poly.index % pcount) % 7].color)
    # Wet, darker waterline and weed below z=1.2; sun-bleached topsides.
    paint_fn(hull, lambda p: np.where(p[:, 2:3] < 1.3, np.array([[.55, .72, .5]]), 1.0) *
             (.8 + .3 * np.clip((p[:, 2:3] - 1.3) / 2.2, 0, 1)))
    deckverts=[];deckfaces=[]
    for y,w in STATIONS:deckverts.extend([(-w+.06,y,3.505+sheer(y)),(w-.06,y,3.505+sheer(y))])
    for i in range(len(STATIONS)-1):deckfaces.append((2*i,2*i+1,2*i+3,2*i+2))
    mesh("Justine | main deck",deckverts,deckfaces,deckmat,False)
    # Wale, caprail, stanchions and gun strakes on both sides.
    for side in [-1,1]:
        for z,rad,ma in [(1.45,.075,m["black"]),(2.9,.06,pale),(3.54,.08,m["black"]),(4.13,.045,m["wood"])]:
            tube("Hull | continuous wale or rail",[(side*w,y,z+sheer(y)) for y,w in STATIONS],rad,ma)
        for y in [i*.75 for i in range(-8,9)]:
            w=width_at(y)
            segment("Rail | stanchion",(side*w,y,3.53+sheer(y)),(side*w,y,4.13+sheer(y)),.032,.032,m["wood"],sides=8)
        for i in range(13):
            y=-5.55+i*.925;w=width_at(y)*.985;z=2.32+sheer(y)
            box("Gunport | dark recessed opening",(side*(w+.015),y,z),(.05,.44,.45),m["eye"],0)
            box("Gunport | raised wooden lid",(side*(w+.10),y,z+.31),(.23,.47,.055),pale,.005)
            # 26 exterior apertures suggest the source's count; this is no verified deck plan.
            a=(side*(w-.14),y,z-.01);b=(side*(w+.56),y,z-.01)
            segment("Cannon | barrel",a,b,.12,.095,m["metal"],sides=16)
            segment("Cannon | dark muzzle",(side*(w+.562),y,z-.01),(side*(w+.566),y,z-.01),.073,.073,m["eye"],sides=16)
            segment("Cannon | muzzle ring",(side*(w+.47),y,z-.01),(side*(w+.55),y,z-.01),.11,.11,m["metal"],sides=16)
            tube("Cannon | breeching rope", [(side*(w-.15), y - .18, z - .02), (side * (w - .6), y, z - .1), (side*(w-.15), y + .18, z - .02)], .018, rope)
    tube("Hull | stem",[(0,7.0,4.06),(0,7.1,2),(0,6.9,.4),(0,6.45,-.6)],.11,m["wood"])
    tube("Hull | keel",[(0,-6.8,-.8),(0,-5,-1.44),(0,0,-1.45),(0,5,-1.44),(0,6.8,-.8)],.13,m["wood"])
    box("Stern | cabin",(0,-5.25,3.97),(2.9,1.9,.82),wood[3],.08)
    box("Stern | cabin roof",(0,-5.25,4.41),(3.14,2.05,.10),deckmat,.04)
    for x in [-.85,0,.85]:
        box("Stern | window dark pane",(x,-6.218,4.02),(.51,.04,.32),m["glass"],.025)
        for dx in [-.18,0,.18]:box("Stern | window glazing bar",(x+dx,-6.245,4.02),(.018,.03,.32),pale,0)
    # Transom details: rudder, quarter gallery rail, lanterns.
    box("Stern | rudder blade", (0, -7.12, 2.15), (.12, .22, 3.5), m["wood"], .02)
    for z in [.8, 1.8, 2.8]:
        box("Stern | rudder pintle", (0, -7.0, z), (.18, .1, .06), m["metal"], .006)
    tube("Stern | taffrail", [(-1.45, -6.25, 4.42), (-1.45, -6.35, 4.85), (1.45, -6.35, 4.85), (1.45, -6.25, 4.42)], .03, m["wood"])
    for sx in (-1.45, -.7, 0, .7, 1.45):
        segment("Stern | taffrail baluster", (sx, -6.35, 4.5), (sx, -6.35, 4.85), .02, .02, m["wood"], sides=8)
    for sx in (-1.55, 1.55):
        segment("Stern | lantern post", (sx, -6.1, 4.46), (sx, -6.1, 4.78), .025, .025, m["metal"], sides=8)
        sphere("Stern | lantern glass", (sx, -6.1, 4.92), (.12, .12, .16), m["glass"], seg=12, rings=8)
        sphere("Stern | lantern cap", (sx, -6.1, 5.12), (.1, .1, .05), m["metal"], seg=10, rings=6)
    box("Deck | hatch rim",(0,.4,3.61),(1.35,1.65,.19),m["wood"],.025)
    box("Deck | hatch interior",(0,.4,3.72),(1.12,1.40,.035),m["eye"],0)
    for x in [-.42,-.21,0,.21,.42]:box("Deck | grating",(x,.4,3.75),(.055,1.4,.065),deckmat,.005)
    for y in [-.2,0,.2,.4,.6,.8,1.0]:box("Deck | grating",(0,y,3.77),(1.12,.045,.06),deckmat,.005)
    # Wheel on the quarterdeck approach, capstan amidships, anchor at the cathead.
    box("Deck | wheel pedestal", (0, -4.0, 3.95), (.2, .22, .85), m["wood"], .02)
    torus("Deck | steering wheel rim", (0, -4.0, 4.55), .42, .026, (math.pi / 2, 0, 0), m["wood"], None, None, 20, 6)
    for k in range(8):
        a = k * math.pi / 4
        tube("Deck | wheel spoke", [(0, -4.0, 4.55), (math.cos(a) * .52, -4.0, 4.55 + math.sin(a) * .52)], .016, m["wood"])
    segment("Deck | capstan barrel", (0, -3.05, 3.53), (0, -3.05, 4.05), .2, .17, m["wood"], sides=14)
    segment("Deck | capstan head", (0, -3.05, 4.05), (0, -3.05, 4.12), .24, .24, m["metal"], sides=14)
    for k in range(4):
        a = k * math.pi / 2 + .4
        segment("Deck | capstan bar", (0, -3.05, 4.08), (math.cos(a) * .6, -3.05 + math.sin(a) * .6, 4.08), .022, .022, m["wood"], sides=8)
    segment("Bow | cathead beam", (1.1, 5.3, 3.95), (2.1, 5.3, 3.95), .07, .06, m["wood"], sides=10)
    segment("Bow | anchor shank", (1.95, 5.3, 2.1), (1.95, 5.3, 3.85), .045, .04, m["metal"], sides=10)
    tube("Bow | anchor arms", [(1.95, 4.75, 2.35), (1.95, 5.05, 2.12), (1.95, 5.3, 2.05), (1.95, 5.55, 2.12), (1.95, 5.85, 2.35)], .042, m["metal"])
    segment("Bow | anchor stock", (1.62, 5.3, 3.62), (2.28, 5.3, 3.62), .03, .03, m["wood"], sides=8)
    torus("Bow | anchor ring", (1.95, 5.3, 3.92), .08, .014, (0, math.pi / 2, 0), m["metal"], None, None, 12, 5)
    for sx in (-1, 1):
        segment("Bow | hawse pipe", (sx * 1.15, 6.15, 2.45), (sx * 1.15, 6.15, 2.7), .1, .1, m["eye"], sides=12)
    for y,height,lower_w in [(-1.7,11.2,5.9),(3.15,9.8,5.1)]:
        segment("Rig | mast",(0,y,3.4),(0,y,height),.16,.075,m["wood"],sides=16)
        segment("Rig | mast iron collar",(0,y,3.5),(0,y,3.65),.19,.19,m["metal"],sides=16)
        box("Rig | mast top platform", (0, y, height - 4.25), (.9, .8, .06), m["wood"], .01)
        for sx in (-.4, .4):
            segment("Rig | mast cheek", (sx, y, height - 4.6), (sx, y, height - 3.7), .05, .05, m["wood"], sides=8)
        for top,h,w in [(height-1.25,1.55,lower_w*.78),(height-3.1,1.7,lower_w)]:
            segment("Rig | yard",(-w*.56,y,top),(w*.56,y,top),.058,.058,m["wood"],sides=12)
            sail("Rig | slack square sail",y,top-.04,h,w,linen)
            tube("Sail | foot rope",[(-w*.46,y-.10,top-h),(0,y-.15,top-h-.12),(w*.46,y-.10,top-h)],.018,rope)
            for fraction in [-.3,-.1,.1,.3]:
                x=fraction*w
                points=[]
                for j in range(9):
                    v=j/8;u=fraction+.5
                    points.append((x*(1-.08*v),y-.1-.324*math.sin(u*math.pi)*math.sin(v*math.pi),top-.04-v*h-.12*math.sin(u*math.pi)*v))
                tube("Sail | vertical seam",points,.007,seam)
            # Reef points: short ties across the sail, one third of the way down.
            for k in range(-4, 5):
                u = k / 9.0 + .5
                v = .33
                px = (u - .5) * w * (1 - .08 * v)
                pz = top - .04 - v * h - .12 * math.sin(u * math.pi) * v
                py = y - .1 - .32 * math.sin(u * math.pi) * math.sin(v * math.pi) - .02
                segment("Sail | reef point", (px, py, pz), (px, py - .05, pz - .35), .01, .007, rope, sides=5)
        for side in [-1,1]:
            anchors=[]
            for off in [-.85,-.27,.3,.86]:
                a=(side*(width_at(y+off)+.05),y+off,3.7+sheer(y+off));b=(side*.04,y,height-1.1)
                tube("Rig | shroud",[a,b],.019,rope);anchors.append(a)
                box("Rig | chainplate deadeye", (side * (width_at(y + off) + .1), y + off, 3.55), (.07, .07, .09), m["wood"], .01)
            # Horizontal ratlines connect the exterior shrouds.
            for j in range(1,13):
                t=j/14
                lo=Vector(anchors[0]).lerp(Vector((side*.04,y,height-1.1)),t)
                hi=Vector(anchors[-1]).lerp(Vector((side*.04,y,height-1.1)),t)
                tube("Rig | ratline",[tuple(lo),tuple(hi)],.009,rope)
        tube("Rig | fore stay",[(0,y,height-.15),(0,8.9,4.7)],.025,rope)
        tube("Rig | aft stay",[(0,y,height-.15),(-1,-6.4,4.0)],.025,rope)
        tube("Rig | aft stay",[(0,y,height-.15),(1,-6.4,4.0)],.025,rope)
    segment("Rig | bowsprit",(0,5.7,3.7),(0,9.5,4.9),.15,.055,m["wood"],sides=16)
    tube("Rig | bobstay",[(0,7.0,1.0),(0,9.5,4.9)],.03,rope)
    # Clear boarding ladder on the port quarter: the player dismounts before deck access.
    for y in [-2.9,-2.25]:
        segment("Boarding | ladder rail",(-2.95,y,.05),(-2.48,y,3.73),.038,.038,m["wood"],sides=10)
    for j in range(13):
        t=j/12;x=-2.95+.47*t;z=.10+3.6*t
        segment("Boarding | ladder rung",(x,-2.9,z),(x,-2.25,z),.027,.027,m["wood"],sides=10)
    # Barrels and coils help the deck read as a working merchant vessel.
    for x,y in [(-1.3,-3.8),(1.2,-3.9),(1.1,1.65),(-1.1,4.5)]:
        segment("Cargo | barrel",(x,y,3.53),(x,y,4.12),.23,.23,m["wood"],sides=16)
        for z in [3.65,3.99]:
            torus("Cargo | barrel hoop", (x, y, z), .23, .018, (0, 0, 0), m["metal"], None, None, 20, 6)
    for x, y in [(.9, 3.9), (-.8, 2.4)]:
        torus("Cargo | rope coil", (x, y, 3.56), .26, .06, (0, 0, 0), rope, None, None, 18, 6)
        torus("Cargo | rope coil", (x, y, 3.64), .23, .055, (0, 0, 0), rope, None, None, 18, 6)
    box("Cargo | bale", (1.25, -2.7, 3.78), (.7, .55, .5), m["cream"], .06)
    box("Cargo | bale", (1.3, -2.7, 4.22), (.6, .5, .4), m["pelt"], .06)
    export("justine",[])


# --------------------------------------------------------------------------------------
# Colonial architecture and vegetation of the north (new, not yet wired by world_view.gd)
# --------------------------------------------------------------------------------------
def roof_pair(name, w, d, z_wall, rise, over_x, over_y, mat, along="x"):
    """Two thin tile slabs forming a gable roof. Ridge runs along X (along='x') or Y."""
    th = .10
    if along == "x":
        half = d / 2 + over_y
        run = d / 2
        ang = math.atan2(rise, run)
        slope = math.hypot(run, rise) + over_y * math.cos(ang) / math.cos(ang)
        for s in (-1, 1):
            cy = s * (run / 2 + over_y / 2)
            cz = z_wall + rise / 2 - over_y * math.tan(ang) / 2 + th / 2
            length = math.hypot(run + over_y, rise + over_y * math.tan(ang))
            rbox(name, (0, cy, cz), (w + over_x * 2, length, th), (-s * ang, 0, 0), mat)
        tube(name + " ridge", [(-w / 2 - over_x, 0, z_wall + rise + th), (w / 2 + over_x, 0, z_wall + rise + th)], .08, mat)
    else:
        run = w / 2
        ang = math.atan2(rise, run)
        for s in (-1, 1):
            cx = s * (run / 2 + over_x / 2)
            cz = z_wall + rise / 2 - over_x * math.tan(ang) / 2 + th / 2
            length = math.hypot(run + over_x, rise + over_x * math.tan(ang))
            rbox(name, (cx, 0, cz), (length, d + over_y * 2, th), (0, s * ang, 0), mat)
        tube(name + " ridge", [(0, -d / 2 - over_y, z_wall + rise + th), (0, d / 2 + over_y, z_wall + rise + th)], .08, mat)


def grime(p):
    """Splash-back dirt near the ground and soft vertical staining."""
    t = np.clip((p[:, 2] - .3) / 1.2, 0, 1)
    return (.62 + .38 * t)[:, None] * np.array([[1.0, .97, .9]])


def house_colonial():
    reset()
    wall = Mat("Adobe | limewashed wall", (.64, .56, .42), "plaster")
    wall2 = Mat("Adobe | ochre", (.60, .47, .30), "plaster")
    tile = Mat("Roof | clay tile", (.45, .20, .10), "tile")
    stone = Mat("Stone | plinth", (.40, .37, .30), "stone")
    wood = Mat("Wood | door", (.26, .15, .07), "planks")
    shut = Mat("Wood | green shutters", (.08, .17, .12), "planks")
    dark = Mat("Opening | dark", (.01, .01, .01), "gloss")
    iron = Mat("Iron | reja", (.06, .06, .06), "metal")
    beam = Mat("Wood | algarrobo beams", (.24, .13, .06), "wood")
    brass = Mat("Brass | knocker", (.42, .27, .08), "metal")
    W, D, H = 5.0, 4.0, 2.7
    zb = .3
    box("House | stone plinth", (0, 0, .15), (W + .24, D + .24, .3), stone, .03)
    o = box("House | adobe walls", (0, 0, zb + H / 2), (W, D, H), wall, .06)
    paint_fn(o, grime)
    for s in (-1, 1):
        mesh("House | gable wall", [(s * W / 2, -D / 2, zb + H), (s * W / 2, D / 2, zb + H), (s * W / 2, 0, zb + H + 1.15)],
             [(0, 1, 2)] if s > 0 else [(2, 1, 0)], wall, False)
    roof_pair("House | tile roof", W, D, zb + H - .08, 1.15, .35, .55, tile, "x")
    # Door and frame on the long front (-Y), with a lintel beam.
    fy = -D / 2
    box("House | door frame", (0, fy - .015, zb + 1.1), (1.25, .07, 2.3), beam, .02)
    box("House | plank door", (0, fy - .06, zb + 1.02), (.95, .06, 2.05), wood, .01)
    sphere("House | door knocker", (.28, fy - .105, zb + 1.05), (.04, .02, .04), brass, seg=8, rings=5)
    box("House | lintel beam", (0, fy - .06, zb + 2.32), (1.6, .13, .16), beam, .02)
    for sx in (-1.6, 1.6):
        box("House | window opening", (sx, fy - .01, zb + 1.35), (.85, .04, 1.05), dark, 0)
        box("House | window sill", (sx, fy - .09, zb + .78), (1.05, .18, .07), stone, .01)
        box("House | window lintel", (sx, fy - .07, zb + 1.97), (1.05, .13, .09), beam, .01)
        for k in range(5):
            xx = sx - .32 + k * .16
            segment("House | reja bar", (xx, fy - .09, zb + .85), (xx, fy - .09, zb + 1.9), .013, .013, iron, sides=6)
        for zz in (zb + 1.15, zb + 1.6):
            segment("House | reja rail", (sx - .4, fy - .09, zz), (sx + .4, fy - .09, zz), .012, .012, iron, sides=6)
        for s2 in (-1, 1):
            rbox("House | open shutter", (sx + s2 * .56, fy - .26, zb + 1.35), (.04, .46, 1.0), (0, 0, s2 * .35), shut)
    # Galeria: lean-to roof carried on four algarrobo posts.
    gy = fy - 1.35
    for px in (-W / 2 + .2, -W / 6, W / 6, W / 2 - .2):
        box("House | gallery post", (px, gy, zb + 1.2), (.17, .17, 2.4), beam, .02)
        box("House | post capital", (px, gy, zb + 2.4), (.28, .28, .09), beam, .01)
    box("House | gallery beam", (0, gy, zb + 2.52), (W - .2, .2, .17), beam, .02)
    rbox("House | gallery roof", (0, fy - .66, zb + 2.5), (W + .35, 1.5, .09), (math.radians(-9), 0, 0), tile)
    for k in range(9):
        box("House | rafter end", (-W / 2 + .3 + k * (W - .6) / 8, fy - .02, zb + 2.62), (.11, .16, .11), beam, .01)
    box("House | gallery floor", (0, fy - .68, zb - .06), (W + .1, 1.4, .12), stone, .02)
    # Chimney and a rear door.
    o = box("House | chimney", (W / 2 - .8, 0.9, zb + H + 1.0), (.55, .55, 1.4), wall2, .03)
    box("House | chimney cap", (W / 2 - .8, .9, zb + H + 1.75), (.7, .7, .08), stone, .01)
    box("House | rear door", (-1.0, D / 2 + .03, zb + 1.0), (.9, .05, 2.0), wood, .01)
    export("house_colonial", [])


def church_colonial():
    reset()
    wall = Mat("Adobe | whitewash", (.72, .67, .55), "plaster")
    tile = Mat("Roof | clay tile", (.44, .20, .11), "tile")
    stone = Mat("Stone | plinth", (.40, .37, .30), "stone")
    wood = Mat("Wood | doors", (.22, .12, .06), "planks")
    dark = Mat("Opening | dark", (.01, .01, .01), "gloss")
    beam = Mat("Wood | belfry", (.20, .11, .05), "wood")
    iron = Mat("Iron | cross", (.07, .07, .07), "metal")
    bell = Mat("Bronze | bell", (.35, .22, .07), "metal")
    W, D, H = 6.0, 11.0, 5.0
    zb = .4
    box("Church | stone plinth", (0, 0, .2), (W + .5, D + .5, .4), stone, .04)
    o = box("Church | nave walls", (0, 0, zb + H / 2), (W, D, H), wall, .08)
    paint_fn(o, lambda p: (.6 + .4 * np.clip((p[:, 2] - .4) / 1.6, 0, 1))[:, None] * np.array([[1.0, .98, .93]]))
    for s in (-1, 1):
        mesh("Church | facade gable", [(-W / 2, s * D / 2, zb + H), (W / 2, s * D / 2, zb + H), (0, s * D / 2, zb + H + 1.9)],
             [(0, 1, 2)] if s < 0 else [(2, 1, 0)], wall, False)
    roof_pair("Church | tile roof", W, D, zb + H - .1, 1.9, .5, .45, tile, "y")
    # Front tower with belfry arches, pyramidal roof and cross.
    ty = -D / 2 - .4
    o = box("Church | tower shaft", (0, ty, zb + 3.7), (2.9, 2.9, 7.4), wall, .06)
    paint_fn(o, grime)
    box("Church | tower cornice", (0, ty, zb + 7.45), (3.2, 3.2, .22), stone, .02)
    for px in (-1.2, 1.2):
        for py in (-1.2, 1.2):
            box("Church | belfry pier", (px, ty + py, zb + 8.5), (.5, .5, 2.0), wall, .03)
    for s in (-1, 1):
        box("Church | belfry arch dark", (s * 1.18, ty, zb + 8.45), (.2, 1.4, 1.5), dark, 0)
        box("Church | belfry arch dark", (0, ty + s * 1.18, zb + 8.45), (1.4, .2, 1.5), dark, 0)
        segment("Church | belfry arch top", (s * 1.2, ty - .7, zb + 9.2), (s * 1.2, ty + .7, zb + 9.2), .36, .36, dark, sides=14)
    segment("Church | bell", (0, ty, zb + 8.2), (0, ty, zb + 8.9), .5, .22, bell, sides=14)
    box("Church | belfry cap", (0, ty, zb + 9.6), (3.0, 3.0, .22), stone, .02)
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=2.15, radius2=.05, depth=2.1, location=(0, ty, zb + 10.7),
                                    rotation=(0, 0, math.pi / 4))
    pyr = bpy.context.object
    pyr.name = "Church | tower roof"
    finish(pyr, tile, False)
    segment("Church | cross shaft", (0, ty, zb + 11.6), (0, ty, zb + 12.9), .045, .045, iron, sides=6)
    segment("Church | cross arm", (-.38, ty, zb + 12.45), (.38, ty, zb + 12.45), .04, .04, iron, sides=6)
    # Entrance.
    fy = -D / 2 - 1.85
    box("Church | portal frame", (0, fy, zb + 1.75), (2.0, .1, 3.5), stone, .03)
    box("Church | portal doors", (0, fy - .06, zb + 1.5), (1.5, .08, 3.0), wood, .01)
    segment("Church | portal arch", (0, fy - .06, zb + 3.0), (0, fy - .02, zb + 3.0), .75, .75, wood, sides=18)
    # Buttresses and high windows.
    for s in (-1, 1):
        for k in range(3):
            y = -D / 2 + 2.2 + k * 3.3
            rbox("Church | buttress", (s * (W / 2 + .3), y, zb + 1.8), (.7, .8, 3.6), (0, -s * .1, 0), wall, .04)
            box("Church | window", (s * (W / 2 + .01), y + 1.6, zb + 3.3), (.06, .55, 1.1), dark, 0)
    export("church_colonial", [])


def lumpy_trunk(name, base, top, rb, rt, mat, rng, sides=10, sections=8):
    secs = []
    for i in range(sections):
        t = i / (sections - 1)
        z = base + (top - base) * t
        r = rb + (rt - rb) * t
        flare = 1 + .8 * max(0, 1 - t * 4) ** 2
        secs.append((z, .12 * math.sin(t * 5 + 1) + (rng.random() - .5) * .03, r * flare, r * flare * (1 + .1 * math.sin(t * 7))))
    return rings_z(name, secs, mat, sides)


def tree_algarrobo():
    reset()
    rng = random.Random(1806)
    bark = Mat("Bark | algarrobo", (.20, .13, .09), "bark")
    leaf = Mat("Foliage | algarrobo", (.20, .27, .10), "foliage")
    leaf2 = Mat("Foliage | algarrobo light", (.30, .35, .14), "foliage")
    lumpy_trunk("Algarrobo | trunk", 0, 3.0, .34, .2, bark, rng)
    limbs = [((-.05, 0, 2.5), (-1.1, .3, 3.9)), ((.05, 0, 2.7), (1.0, -.3, 3.8)), ((0, 0, 2.9), (.2, 1.1, 4.1)),
             ((0, 0, 2.8), (-.3, -1.0, 4.0))]
    for a, b in limbs:
        tube("Algarrobo | limb", [a, ((a[0] + b[0]) / 2 + .1, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2 + .1), b], .1, bark)
    centers = [(-1.2, .3, 4.4), (1.1, -.3, 4.3), (.2, 1.2, 4.6), (-.4, -1.1, 4.5), (0, 0, 5.3), (-1.8, -.5, 4.0),
               (1.8, .6, 4.1), (.5, .0, 4.6), (-.6, .8, 5.0)]
    for i, c in enumerate(centers):
        o = blob("Algarrobo | canopy clump", c, (1.15 + rng.random() * .4, 1.1 + rng.random() * .4, .75 + rng.random() * .25),
                 leaf if i % 2 == 0 else leaf2, rng, 3, .14)
        paint_fn(o, lambda p: (.55 + .5 * np.clip((p[:, 2] - 3.4) / 2.4, 0, 1))[:, None])
    export("tree_algarrobo", [])


def tree_cardon():
    reset()
    rng = random.Random(4000)
    green = Mat("Cactus | cardon", (.16, .27, .12), "cactus")
    spine = Mat("Spines | pale", (.62, .58, .42), "wood")
    ribs = 12

    def column(name, cx, cy, z0, height, radius, tilt=(0, 0)):
        secs = 9
        sides = ribs * 3
        verts, faces = [], []
        for i in range(secs):
            t = i / (secs - 1)
            z = z0 + height * t
            r = radius * (1 - .12 * t) * (1 if t < .94 else max(.15, 1 - (t - .94) * 14))
            for j in range(sides):
                a = 2 * math.pi * j / sides
                rr = r * (1 + .11 * math.cos(ribs * a))
                verts.append((cx + tilt[0] * t * t + math.cos(a) * rr, cy + tilt[1] * t * t + math.sin(a) * rr, z))
        for i in range(secs - 1):
            for j in range(sides):
                a = i * sides + j
                b = i * sides + (j + 1) % sides
                faces.append((a, b, b + sides, a + sides))
        faces.append(tuple(reversed(range(sides))))
        faces.append(tuple((secs - 1) * sides + j for j in range(sides)))
        o = mesh(name, verts, faces, green, True)
        paint_fn(o, lambda p: (.62 + .5 * np.clip((p[:, 2] - z0) / height, 0, 1))[:, None])
        for lvl in range(1, 6):
            t = lvl / 6.5
            for k in range(ribs):
                a = 2 * math.pi * k / ribs
                r = radius * (1 - .12 * t) * 1.12
                sphere("Cardon | areole spines", (cx + tilt[0] * t * t + math.cos(a) * r, cy + tilt[1] * t * t + math.sin(a) * r,
                                                  z0 + height * t), (.022, .022, .03), spine, seg=5, rings=3)

    column("Cardon | trunk", 0, 0, 0, 4.4, .24, (.15, .05))
    for z0, ang, hh in [(1.5, 0.0, 2.1), (2.1, math.pi, 1.7)]:
        dx, dy = math.cos(ang), math.sin(ang)
        tube("Cardon | arm elbow", [(dx * .2, dy * .2, z0), (dx * .6, dy * .6, z0 + .08), (dx * .85, dy * .85, z0 + .45)], .14, green)
        column("Cardon | arm", dx * .85, dy * .85, z0 + .4, hh, .16)
    export("tree_cardon", [])


def rock_cluster():
    reset()
    rng = random.Random(77)
    stone = Mat("Stone | weathered", (.42, .38, .31), "stone")
    lichen = Mat("Stone | lichen", (.42, .44, .28), "stone")
    for i, (pos, rad) in enumerate([((0, 0, .35), (.9, .75, .5)), ((.95, .3, .22), (.55, .5, .32)), ((-.7, .7, .2), (.45, .5, .28)),
                                    ((.3, -.8, .18), (.4, .35, .22))]):
        o = blob("Rock | boulder", pos, rad, stone if i % 2 == 0 else lichen, rng, 2, .22)
        paint_fn(o, lambda p: (.65 + .45 * np.clip((p[:, 2] - .0) / .8, 0, 1))[:, None])
    export("rock_cluster", [])


# --------------------------------------------------------------------------------------
# Export
# --------------------------------------------------------------------------------------
def export(name, animation_names):
    # Consolidate disjoint sculpted parts. Keeping every rein/button/rope as an
    # individual draw node would make the tactical view needlessly expensive.
    # Godot 4.7 glTF importer does not enable "vertex color as albedo" on the FIRST primitive of
    # a mesh, so a 2 mm sacrificial sphere with its own material is made first (see docs/ASSETS.md).
    bpy.ops.mesh.primitive_uv_sphere_add(segments=6, ring_count=4, radius=.001, location=(0, 0, .002))
    dummy = bpy.context.object
    dummy.name = "Anchor | importer workaround"
    finish(dummy, Mat("anchor", (.5, .5, .5), "anchor"))
    mesh_objects=[dummy]+[ob for ob in bpy.context.scene.objects if ob.type=="MESH" and ob is not dummy]
    bpy.context.view_layer.update()
    for ob in mesh_objects:
        auto_uv(ob)
        _col_attr(ob.data)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in mesh_objects:ob.select_set(True)
    bpy.context.view_layer.objects.active=mesh_objects[0]
    bpy.ops.object.join()
    bpy.context.object.name=name+"_geometry"
    bpy.context.view_layer.update()
    # Unanimated bind-pose bounds: useful for the engine's selection/collision volumes.
    points=[];triangles=0
    for ob in bpy.context.scene.objects:
        if ob.type=="MESH":
            points.extend([ob.matrix_world@Vector(c) for c in ob.bound_box])
            triangles+=sum(max(0,len(p.vertices)-2) for p in ob.data.polygons)
    mn=[min(p[i] for p in points) for i in range(3)]
    mx=[max(p[i] for p in points) for i in range(3)]
    target=OUT/(name+".glb")
    kwargs=dict(filepath=str(target),export_format="GLB",export_yup=True,
                export_animations=True,export_frame_range=True,export_force_sampling=True,
                export_materials="EXPORT",export_cameras=False,export_lights=False,
                export_apply=False,export_image_format="JPEG",export_jpeg_quality=88,
                export_tangents=False)
    properties=bpy.ops.export_scene.gltf.get_rna_type().properties
    if "export_nla_strips" in properties:
        kwargs["export_nla_strips"]=False
    if "export_animation_mode" in properties:
        kwargs["export_animation_mode"]="ACTIONS"
    if "export_vertex_color" in properties:
        kwargs["export_vertex_color"]="MATERIAL"
    bpy.ops.export_scene.gltf(**kwargs)
    data=target.read_bytes()
    json_size,_=struct.unpack_from("<I4s",data,12)
    gltf=json.loads(data[20:20+json_size])
    REPORT[name]={"file":target.name,"bytes":target.stat().st_size,"triangles_base_mesh":triangles,
                  "animations_expected":animation_names,
                  "animations_exported":[a.get("name","") for a in gltf.get("animations",[])],
                  "mesh_count":len(gltf.get("meshes",[])),
                  "surfaces":sum(len(me["primitives"]) for me in gltf.get("meshes",[])),
                  "materials":[mt.get("name","") for mt in gltf.get("materials",[])],
                  "textures":len(gltf.get("textures",[])),
                  "vertex_colors":all("COLOR_0" in pr["attributes"] for me in gltf.get("meshes",[]) for pr in me["primitives"]),
                  "sha256":hashlib.sha256(data).hexdigest(),
                  "blender_bounds":{"min":mn,"max":mx},
                  "godot_bounds":{"min":[mn[0],mn[2],-mx[1]],"max":[mx[0],mx[2],-mn[1]]},
                  "front":"Godot -Z","provenance":"Own procedural geometry and textures; artistic reconstruction."}
    print("ASSET_READY "+json.dumps(REPORT[name],ensure_ascii=False))


BUILDERS = {
    "rider_1806": lambda: mounted(1806),
    "rider_1817": lambda: mounted(1817),
    "horse_only": horse_only,
    "infantry": lambda: foot_soldier("infantry", "british"),
    "royalist_1817": lambda: foot_soldier("royalist_1817", "royalist"),
    "dismounted_1806": lambda: foot_soldier("dismounted_1806", "dismounted"),
    "justine": ship,
    "house_colonial": house_colonial,
    "church_colonial": church_colonial,
    "tree_algarrobo": tree_algarrobo,
    "tree_cardon": tree_cardon,
    "rock_cluster": rock_cluster,
}

NOTES = {
    "royalist_1817": "Aggregate royalist figure, 1817. Artistic reconstruction; no verified regimental uniform or British insignia.",
    "infantry": "British line infantry of the Justine crew, 1806; plain stovepipe shako, no regimental badge. Artistic reconstruction.",
    "dismounted_1806": "Riders of 1806 on foot; bicorne with plain red cockade, no Argentine flag or national cockade.",
    "rider_1806": "1806: dark coat with facings, bicorne with plain cockade. No Argentine flag, no Infernales.",
    "rider_1817": "1817: wide-brim hat, garnet poncho, sheepskin recado, gaucho gear. Poncho colour is an artistic reading, no unit insignia.",
    "house_colonial": "NEW in phase 2. Unit footprint 5.0 x 4.0 m, wall 2.7 m, door on the +Z (Godot) face. Not yet referenced by world_view.gd.",
    "church_colonial": "NEW in phase 2. Nave 6 x 11 m, front bell tower to ~12.9 m, facade towards +Z. Generic Andean-colonial chapel, not a specific church.",
    "tree_algarrobo": "NEW in phase 2. Height ~6.3 m, canopy radius ~2.6 m, origin at the trunk base.",
    "tree_cardon": "NEW in phase 2. Height ~4.4 m with two arms, origin at the base.",
    "rock_cluster": "NEW in phase 2. ~2.5 m cluster of four boulders.",
}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = None
    if "--only" in argv:
        only = argv[argv.index("--only") + 1].split(",")
    manifest = OUT / "model_manifest.json"
    if only and manifest.is_file():
        REPORT.update(json.loads(manifest.read_text(encoding="utf-8")))
    order = only or list(BUILDERS)
    for name in order:
        BUILDERS[name]()
        if name in NOTES:
            REPORT[name]["historical_note"] = NOTES[name]
    manifest.write_text(json.dumps(REPORT, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("ALL_MODELS_READY")


main()
