"""Own procedural meshes for Patria: Guemes. Blender 4.x, no downloaded assets.

Run: blender --background --factory-startup --python tools/create_models.py
Blender +Y is forward; glTF exports it as Godot -Z. Blender Z becomes Godot Y.
All dimensions are metres. These are artistic reconstructions, not scanned relics.
"""
import bpy
import math
import random
import json
import struct
import hashlib
import sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "models"
OUT.mkdir(parents=True, exist_ok=True)
RNG = random.Random(18061817)
REPORT = {}


def reset():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in list(bpy.data.materials):
        bpy.data.materials.remove(block)
    for block in list(bpy.data.actions):
        bpy.data.actions.remove(block)
    bpy.context.scene.render.fps = 24


def material(name, color, roughness=.76, metallic=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.diffuse_color = (*color, 1)
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    return m


def palette():
    return {
        "coat": material("Wool | colonial indigo", (.035, .075, .12)),
        "redcoat": material("Wool | muted British red", (.42, .045, .035)),
        "poncho": material("Wool | deep garnet poncho", (.31, .035, .026)),
        "stripe": material("Wool | woven dark border", (.085, .026, .019)),
        "cream": material("Linen | unbleached", (.61, .58, .45)),
        "trouser": material("Wool | earth grey trousers", (.18, .17, .13)),
        "skin": material("Skin | warm ochre", (.48, .285, .16), .69),
        "skinlight": material("Skin | highlight", (.57, .36, .22), .69),
        "hair": material("Hair | dark brown", (.034, .02, .014)),
        "black": material("Hat felt | charcoal", (.021, .023, .021)),
        "leather": material("Leather | oxblood brown", (.095, .036, .018), .53),
        "boot": material("Boot leather", (.034, .024, .015), .48),
        "metal": material("Iron | dark forged", (.075, .08, .075), .39, .74),
        "brass": material("Brass | aged", (.42, .27, .08), .38, .68),
        "eye": material("Eyes | dark", (.006, .005, .003), .22),
        "horse": material("Horse | bay coat", (.205, .082, .033), .64),
        "horse_dark": material("Horse | shading", (.095, .032, .012), .65),
        "muzzle": material("Horse | velvet muzzle", (.055, .044, .032), .8),
        "hoof": material("Hoof | dark horn", (.042, .034, .025), .65),
        "wood": material("Wood | walnut", (.19, .086, .027)),
    }


def finish(obj, mat, smooth=True, bone=None, rig=None):
    if mat is not None:
        obj.data.materials.append(mat)
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


def box(name, position, scale, mat, bevel=.015, bone=None, rig=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=position)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new("Soft manufactured edges", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        bpy.ops.object.modifier_apply(modifier=mod.name)
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


def build_horse(m, rig, joints):
    rings_y("Horse | continuous barrel and croup", [
        (-.96, 1.32, .045, .11), (-.85, 1.34, .23, .33),
        (-.65, 1.31, .33, .4), (-.35, 1.29, .36, .43),
        (0, 1.29, .355, .43), (.3, 1.30, .33, .44),
        (.58, 1.34, .295, .4), (.78, 1.35, .24, .31), (.91, 1.4, .08, .16)
    ], m["horse"], 24, "body", rig)
    rings_z("Horse | sculpted rising neck", [
        (1.15, .61, .24, .27), (1.38, .73, .255, .31),
        (1.6, .85, .22, .28), (1.82, 1.00, .185, .24),
        (2.02, 1.12, .155, .19), (2.16, 1.17, .115, .10)
    ], m["horse"], 20, "neck", rig)
    rings_y("Horse | angular skull and face", [
        (1.04, 2.06, .09, .14), (1.18, 2.07, .16, .21),
        (1.33, 2.02, .15, .22), (1.5, 1.91, .115, .17),
        (1.68, 1.81, .115, .13), (1.78, 1.79, .09, .095)
    ], m["horse"], 20, "head", rig)
    sphere("Horse | velvet nose", (0, 1.73, 1.79), (.118, .12, .10), m["muzzle"], "head", rig)
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
    mane_rows=[(.56,1.64),(.66,1.83),(.79,1.99),(.97,2.15),(1.12,2.23)]
    verts=[]
    for y,z in mane_rows:
        verts.extend([(-.065,y,z),(.035,y-.05,z+.08),(.09,y-.09,z-.15)])
    faces=[]
    for i in range(len(mane_rows)-1):
        for j in [0,1]:
            faces.append((i*3+j,(i+1)*3+j,(i+1)*3+j+1,i*3+j+1))
    mesh("Horse | falling mane",verts,faces,m["hair"],True,"neck",rig)
    for k in range(9):
        x=(k-4)*.014
        tube("Horse | tail hair",[(x,-.91,1.54),(x*1.6,-1.24,1.22),(x*1.2,-1.49,.81),(x*.6,-1.48,.53)],.022,m["hair"],"tail",rig)
    for key, pts in joints.items():
        upper, lower, foot = key+"_upper", key+"_lower", key+"_foot"
        hip,knee,ankle,toe=pts
        if key[0]=="F":
            sphere("Horse | "+key+" shoulder muscle",(hip[0],hip[1]-.035,hip[2]-.04),(.125,.17,.245),m["horse"],upper,rig)
        segment("Horse | "+key+" upper muscle",hip,knee,.145 if key[0]=="H" else .112,.069,m["horse"],upper,rig,16)
        sphere("Horse | "+key+" joint",knee,(.071,.077,.078),m["horse"],lower,rig)
        segment("Horse | "+key+" cannon",knee,ankle,.063,.041,m["horse"],lower,rig)
        sphere("Horse | "+key+" fetlock",ankle,(.054,.06,.06),m["horse_dark"],foot,rig)
        segment("Horse | "+key+" pastern",ankle,toe,.043,.052,m["horse_dark"],foot,rig)
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
    seat=box("Tack | leather seat",(0,-.06,1.765),(.47,.57,.09),m["leather"],.04,"body",rig)
    for y in [-.37,.23]:
        tube("Tack | saddle raised edge",[(-.24,y,1.78),(-.15,y,1.86),(.15,y,1.86),(.24,y,1.78)],.045,m["leather"],"body",rig)
    for side in [-1,1]:
        tube("Tack | stirrup leather",[(side*.23,.07,1.79),(side*.4,.1,1.38),(side*.44,.2,1.07)],.021,m["leather"],"body",rig)
        tube("Tack | iron stirrup",[(side*.44,.2,1.15),(side*.52,.2,1.02),(side*.36,.2,1.02),(side*.44,.2,1.15)],.016,m["metal"],"body",rig)
    tube("Tack | girth",[(-.35,.2,1.54),(-.35,.2,1.03),(0,.2,.90),(.35,.2,1.03),(.35,.2,1.54)],.028,m["leather"],"body",rig)


def human_head(m, rig, bone, pos, hat="wide", beard=False, small=False):
    x,y,z=pos
    size=.94 if small else 1.0
    sphere("Rider | skull",(x,y,z),(.111*size,.118*size,.15*size),m["skin"],bone,rig)
    # Deliberate jaw / brow / nose silhouette; eyes lie on the forward +Y side.
    sphere("Rider | jaw",(x,y+.014,z-.078),(.089*size,.09*size,.07*size),m["skin"],bone,rig)
    nose=mesh("Rider | nose",[(x-.026,y+.103,z+.005),(x+.026,y+.103,z+.005),(x,y+.154,z-.028),(x,y+.10,z-.045)],[(0,1,2),(0,2,3),(1,3,2)],m["skinlight"],False,bone,rig)
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
    else:
        sphere("Hat | bicorne crown",(x,y,z+.13),(.14,.12,.09),m["black"],bone,rig)
        verts=[(x-.30,y,z+.14),(x-.12,y-.085,z+.29),(x+.12,y-.085,z+.29),(x+.30,y,z+.14),
               (x+.10,y+.10,z+.23),(x-.10,y+.10,z+.23),(x-.26,y+.02,z+.12),(x+.26,y+.02,z+.12)]
        mesh("Hat | folded bicorne",verts,[(0,1,2,3),(0,5,4,3),(0,3,7,6),(0,6,5),(3,4,7)],m["black"],False,bone,rig)
        sphere("Hat | plain cockade",(x-.14,y+.055,z+.21),(.023,.012,.023),m["cream"],bone,rig,12,6)


def mounted_rider(m, rig, period):
    bone="rider"
    cloth=m["coat"] if period==1806 else m["poncho"]
    pants=m["cream"] if period==1806 else m["trouser"]
    rings_z("Rider | tailored torso",[(1.86,-.10,.17,.12),(2.05,-.12,.18,.13),(2.25,-.10,.22,.14),(2.46,-.075,.24,.14),(2.56,-.06,.13,.095)],cloth,16,bone,rig)
    segment("Rider | neck",(0,-.06,2.5),(0,-.06,2.67),.065,.063,m["skin"],bone,rig)
    human_head(m,rig,bone,(0,-.035,2.76),"bicorne" if period==1806 else "wide",period==1817)
    box("Rider | sash",(0,-.11,2.01),(.38,.27,.09),m["poncho"] if period==1806 else m["stripe"],.025,bone,rig)
    for side in [-1,1]:
        hip=(side*.14,-.10,1.92); knee=(side*.43,.22,1.53); ankle=(side*.43,.18,1.08)
        segment("Rider | thigh",hip,knee,.115,.08,pants,bone,rig,16)
        sphere("Rider | knee",knee,(.084,.094,.09),pants,bone,rig)
        segment("Rider | boot shaft",knee,ankle,.081,.058,m["boot"],bone,rig)
        box("Rider | boot toe",(side*.43,.26,1.06),(.14,.29,.12),m["boot"],.025,bone,rig)
        shoulder=(side*.215,-.075,2.44); elbow=(side*.3,.09,2.23); hand=(side*.15,.37,2.10)
        segment("Rider | upper sleeve",shoulder,elbow,.085,.068,cloth,bone,rig)
        segment("Rider | bent sleeve",elbow,hand,.068,.043,cloth,bone,rig)
        sphere("Rider | hand on reins",hand,(.044,.064,.044),m["skin"],bone,rig)
        if period==1806:
            box("Rider | shoulder tab",(side*.2,-.07,2.515),(.11,.18,.025),m["cream"],.008,bone,rig)
    if period==1806:
        # Visible buttons and crossbelt, without claiming an exact surviving uniform.
        for z in [2.14,2.25,2.36,2.46]:
            sphere("Rider | brass button",(0,.043,z),(.013,.008,.013),m["brass"],bone,rig,10,6)
        tube("Rider | buff crossbelt",[(-.18,.035,2.49),(0,.058,2.28),(.17,.025,2.03)],.026,m["cream"],bone,rig)
        for side in [-1,1]:
            mesh("Rider | coat tail",[(side*.17,-.20,2.05),(side*.25,-.30,1.62),(side*.04,-.35,1.67),(side*.03,-.24,2.05)],[(0,1,2,3)],cloth,False,bone,rig)
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
    tube("Rider | sabre scabbard",[(-.27,-.22,2.02),(-.42,-.37,1.62),(-.48,-.52,1.31)],.025,m["boot"],bone,rig)
    segment("Rider | sabre grip",(-.26,-.20,2.01),(-.22,-.17,2.19),.023,.023,m["leather"],bone,rig)
    tube("Rider | sabre guard",[(-.27,-.22,2.04),(-.33,-.20,2.12),(-.28,-.17,2.20),(-.22,-.17,2.19)],.013,m["brass"],bone,rig)


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
                b=rig.pose.bones[key+"_"+suffix]
                b.rotation_mode="XYZ"
                b.rotation_euler=(angle,0,0)
                b.keyframe_insert("rotation_euler",frame=f,group=key)
        b=rig.pose.bones["body"]
        b.location=(0,0,.025*math.cos(phase*2))
        b.keyframe_insert("location",frame=f,group="body")
        for bn,amplitude in [("rider",.035),("neck",.025),("head",.018),("tail",.09)]:
            b=rig.pose.bones[bn]; b.rotation_mode="XYZ"
            b.rotation_euler=(amplitude*math.sin(phase*2),0,0)
            b.keyframe_insert("rotation_euler",frame=f,group=bn)
    for fcurve in action.fcurves:
        for key in fcurve.keyframe_points:
            key.interpolation="BEZIER"
        fcurve.modifiers.new("CYCLES")
    bpy.context.scene.frame_start=1; bpy.context.scene.frame_end=25
    bpy.context.scene.frame_set(1)


def mounted(period):
    reset(); m=palette()
    if period==1817:
        m["horse"].node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value=(.15,.135,.105,1)
        m["horse"].diffuse_color=(.15,.135,.105,1)
    rig,joints=horse_rig()
    build_horse(m,rig,joints)
    mounted_rider(m,rig,period)
    animate_trot(rig)
    export("rider_"+str(period),["trot"])


def horse_only():
    reset();m=palette()
    rig,joints=horse_rig()
    build_horse(m,rig,joints)
    animate_trot(rig)
    export("horse_only",["trot"])


def foot_soldier(name, british):
    reset(); m=palette()
    bones=[("root",(0,0,.05),(0,0,.8),None),
           ("body",(0,0,.93),(0,0,1.48),"root"),
           ("head",(0,0,1.45),(0,0,1.72),"body")]
    for side,x in [("L",-.11),("R",.11)]:
        bones.extend([(side+"_thigh",(x,0,.98),(x,.015,.53),"root"),
                      (side+"_shin",(x,.015,.53),(x,0,.10),side+"_thigh")])
    rig=armature("Dismounted_skeleton",bones)
    cloth=m["redcoat"] if british else m["coat"]
    rings_z("Soldier | tailored coat",[(.86,-.015,.16,.09),(1.02,0,.15,.10),(1.20,0,.185,.105),(1.39,0,.20,.11),(1.48,0,.11,.085)],cloth,16,"body",rig)
    segment("Soldier | neck",(0,0,1.45),(0,0,1.56),.055,.055,m["skin"],"head",rig)
    human_head(m,rig,"head",(0,.005,1.65),"bicorne",False,True)
    for side,x in [("L",-.11),("R",.11)]:
        hip=(x,0,.97); knee=(x,.015,.53); ankle=(x,0,.10)
        segment("Soldier | breeches",hip,knee,.099,.065,m["cream"],side+"_thigh",rig,16)
        sphere("Soldier | knee",knee,(.067,.067,.074),m["cream"],side+"_shin",rig)
        segment("Soldier | gaiter",knee,ankle,.063,.045,m["boot"],side+"_shin",rig)
        box("Soldier | shoe",(x,.072,.06),(.135,.25,.12),m["boot"],.025,side+"_shin",rig)
    for side in [-1,1]:
        shoulder=(side*.19,0,1.39); elbow=(side*.25,.035,1.13)
        hand=(side*.12,.20,1.10) if side<0 else (side*.17,.17,.99)
        segment("Soldier | upper sleeve",shoulder,elbow,.073,.056,cloth,"body",rig)
        segment("Soldier | forearm sleeve",elbow,hand,.055,.036,cloth,"body",rig)
        sphere("Soldier | hand",hand,(.035,.05,.039),m["skin"],"body",rig)
    box("Soldier | waistbelt",(0,.015,1.03),(.32,.20,.055),m["cream"],.009,"body",rig)
    box("Soldier | buckle",(0,.12,1.03),(.048,.02,.046),m["brass"],.003,"body",rig)
    tube("Soldier | crossbelt",[(-.16,.08,1.44),(0,.125,1.22),(.15,.09,1.03)],.024,m["cream"],"body",rig)
    if british:
        tube("Soldier | second crossbelt",[(.16,.08,1.44),(0,.127,1.22),(-.15,.09,1.03)],.023,m["cream"],"body",rig)
    for z in [1.13,1.23,1.33,1.42]:
        sphere("Soldier | brass button",(0,.11,z),(.011,.007,.011),m["brass"],"body",rig,10,6)
    # Musket at an upward diagonal across the chest; no anachronistic optics.
    a=(-.22,.21,.89); b=(.35,.20,1.85)
    segment("Musket | walnut stock",a,(.07,.20,1.38),.042,.026,m["wood"],"body",rig)
    segment("Musket | iron barrel",(-.04,.20,1.18),b,.017,.014,m["metal"],"body",rig)
    box("Musket | lock",(-.035,.237,1.21),(.07,.028,.07),m["metal"],.007,"body",rig)
    rig.animation_data_create(); action=bpy.data.actions.new("walk");rig.animation_data.action=action
    for f in range(1,26,3):
        phase=(f-1)/24*2*math.pi
        for side,offset in [("L",0),("R",math.pi)]:
            for suffix,angle in [("_thigh",.32*math.sin(phase+offset)),("_shin",.35*max(0,-math.sin(phase+offset)))]:
                bone=rig.pose.bones[side+suffix];bone.rotation_mode="XYZ";bone.rotation_euler=(angle,0,0)
                bone.keyframe_insert("rotation_euler",frame=f,group=side)
        bone=rig.pose.bones["body"];bone.location=(0,0,.018*math.cos(phase*2));bone.keyframe_insert("location",frame=f,group="body")
    for curve in action.fcurves:
        curve.modifiers.new("CYCLES")
    bpy.context.scene.frame_start=1;bpy.context.scene.frame_end=25;bpy.context.scene.frame_set(1)
    export(name,["walk"])


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
    # Two-sided cloth is needed from both directions in glTF.
    ob.data.materials[0].use_backface_culling=False
    return ob


def ship():
    reset();m=palette()
    wood=[material("Hull | oak plank %02d"%i,(.14+i*.012,.065+i*.006,.025+i*.0025)) for i in range(7)]
    deckmat=material("Deck | weathered timber",(.33,.235,.13))
    pale=material("Hull | pale gun strake",(.50,.41,.26))
    rope=material("Rigging | tarred hemp",(.08,.065,.038))
    linen=material("Sail | weathered flax",(.66,.61,.46),.94)
    seam=material("Sail | sewn seams",(.40,.36,.25))
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
    for material_item in wood[1:]:hull.data.materials.append(material_item)
    for poly in hull.data.polygons:poly.material_index=(poly.index%pcount)%7
    outline=[(-w,y,3.5+sheer(y)) for y,w in STATIONS]+[(w,y,3.5+sheer(y)) for y,w in reversed(STATIONS)]
    # Triangulated strip deck follows longitudinal stations.
    deckverts=[];deckfaces=[]
    for y,w in STATIONS:deckverts.extend([(-w+.06,y,3.505+sheer(y)),(w-.06,y,3.505+sheer(y))])
    for i in range(len(STATIONS)-1):deckfaces.append((2*i,2*i+1,2*i+3,2*i+2))
    mesh("Justine | main deck",deckverts,deckfaces,deckmat,False)
    for x in [i*.22 for i in range(-10,11)]:
        valid=[(x,y,3.52+sheer(y)) for y,w in STATIONS if abs(x)<w-.1]
        if len(valid)>1:tube("Deck | plank seam",valid,.007,m["wood"])
    # Wale, caprail, stanchions and gun strakes on both sides.
    for side in [-1,1]:
        for z,rad,ma in [(1.45,.075,m["black"]),(2.9,.06,pale),(3.54,.08,m["black"]),(4.13,.045,m["wood"])]:
            tube("Hull | continuous wale or rail",[(side*w,y,z+sheer(y)) for y,w in STATIONS],rad,ma)
        for y in [i*.75 for i in range(-8,9)]:
            w=width_at(y)
            segment("Rail | stanchion",(side*w,y,3.53+sheer(y)),(side*w,y,4.13+sheer(y)),.032,.032,m["wood"],sides=8)
        for i in range(13):
            y=-5.55+i*.925;w=width_at(y)*.985;z=2.32+sheer(y)
            box("Gunport | dark recessed opening",(side*(w+.015),y,z),(.05,.44,.45),m["black"],0)
            hatch=box("Gunport | raised wooden lid",(side*(w+.10),y,z+.31),(.23,.47,.055),pale,.005)
            # 26 exterior apertures suggest the source's count; this is no verified deck plan.
            a=(side*(w-.14),y,z-.01);b=(side*(w+.56),y,z-.01)
            segment("Cannon | barrel",a,b,.12,.095,m["metal"],sides=16)
            segment("Cannon | dark muzzle",(side*(w+.562),y,z-.01),(side*(w+.566),y,z-.01),.073,.073,m["black"],sides=16)
            segment("Cannon | muzzle ring",(side*(w+.47),y,z-.01),(side*(w+.55),y,z-.01),.11,.11,m["metal"],sides=16)
    tube("Hull | stem",[(0,7.0,4.06),(0,7.1,2),(0,6.9,.4),(0,6.45,-.6)],.11,m["wood"])
    tube("Hull | keel",[(0,-6.8,-.8),(0,-5,-1.44),(0,0,-1.45),(0,5,-1.44),(0,6.8,-.8)],.13,m["wood"])
    box("Stern | cabin",(0,-5.25,3.97),(2.9,1.9,.82),m["wood"],.08)
    box("Stern | cabin roof",(0,-5.25,4.41),(3.14,2.05,.10),deckmat,.04)
    for x in [-.85,0,.85]:
        box("Stern | window dark pane",(x,-6.218,4.02),(.51,.04,.32),m["black"],.025)
        for dx in [-.18,0,.18]:box("Stern | window glazing bar",(x+dx,-6.245,4.02),(.018,.03,.32),pale,0)
    box("Deck | hatch rim",(0,.4,3.61),(1.35,1.65,.19),m["wood"],.025)
    box("Deck | hatch interior",(0,.4,3.72),(1.12,1.40,.035),m["black"],0)
    for x in [-.42,-.21,0,.21,.42]:box("Deck | grating",(x,.4,3.75),(.055,1.4,.065),deckmat,.005)
    for y in [-.2,0,.2,.4,.6,.8,1.0]:box("Deck | grating",(0,y,3.77),(1.12,.045,.06),deckmat,.005)
    for y,height,lower_w in [(-1.7,11.2,5.9),(3.15,9.8,5.1)]:
        segment("Rig | mast",(0,y,3.4),(0,y,height),.16,.075,m["wood"],sides=16)
        segment("Rig | mast iron collar",(0,y,3.5),(0,y,3.65),.19,.19,m["metal"],sides=16)
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
        for side in [-1,1]:
            anchors=[]
            for off in [-.85,-.27,.3,.86]:
                a=(side*(width_at(y+off)+.05),y+off,3.7+sheer(y+off));b=(side*.04,y,height-1.1)
                tube("Rig | shroud",[a,b],.019,rope);anchors.append(a)
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
            bpy.ops.mesh.primitive_torus_add(major_radius=.23,minor_radius=.018,major_segments=20,minor_segments=6,location=(x,y,z))
            ob=bpy.context.object;ob.name="Cargo | barrel hoop";finish(ob,m["metal"])
    export("justine",[])


def export(name, animation_names):
    # Consolidate disjoint sculpted parts. Keeping every rein/button/rope as an
    # individual draw node would make the tactical view needlessly expensive.
    mesh_objects=[ob for ob in bpy.context.scene.objects if ob.type=="MESH"]
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
                export_apply=False)
    properties=bpy.ops.export_scene.gltf.get_rna_type().properties
    if "export_nla_strips" in properties:
        kwargs["export_nla_strips"]=False
    if "export_animation_mode" in properties:
        kwargs["export_animation_mode"]="ACTIONS"
    bpy.ops.export_scene.gltf(**kwargs)
    data=target.read_bytes()
    json_size,_=struct.unpack_from("<I4s",data,12)
    gltf=json.loads(data[20:20+json_size])
    REPORT[name]={"file":target.name,"bytes":target.stat().st_size,"triangles_base_mesh":triangles,
                  "animations_expected":animation_names,
                  "animations_exported":[a.get("name","") for a in gltf.get("animations",[])],
                  "mesh_count":len(gltf.get("meshes",[])),
                  "surfaces":sum(len(me["primitives"]) for me in gltf.get("meshes",[])),
                  "sha256":hashlib.sha256(data).hexdigest(),
                  "blender_bounds":{"min":mn,"max":mx},
                  "godot_bounds":{"min":[mn[0],mn[2],-mx[1]],"max":[mx[0],mx[2],-mn[1]]},
                  "front":"Godot -Z","provenance":"Own procedural geometry; artistic reconstruction."}
    print("ASSET_READY "+json.dumps(REPORT[name],ensure_ascii=False))


def royalist_variant():
    """Recolor our own infantry GLB, keeping all geometry/animation bytes intact.

    The neutral off-white coat marks an aggregate royalist figure in 1817. It is
    an artistic reconstruction, not an identified regiment's verified uniform.
    """
    source=OUT/"infantry.glb"
    if not source.is_file() or "infantry" not in REPORT:
        raise RuntimeError("royalist_variant requires the generated infantry.glb and its manifest.")
    data=source.read_bytes()
    magic,version,total=struct.unpack_from("<4sII",data,0)
    if magic!=b"glTF" or version!=2 or total!=len(data):
        raise RuntimeError("The source infantry GLB header is invalid.")
    chunks=[];offset=12
    while offset<len(data):
        length,kind=struct.unpack_from("<I4s",data,offset)
        chunks.append((kind,data[offset+8:offset+8+length]))
        offset+=8+length
    gltf=json.loads(next(chunk for kind,chunk in chunks if kind==b"JSON"))
    changed=False
    for mat in gltf.get("materials",[]):
        if mat.get("name")=="Wool | muted British red":
            mat["name"]="Wool | neutral off-white campaign coat"
            mat["pbrMetallicRoughness"]["baseColorFactor"]=[.58,.57,.51,1.0]
            changed=True
    if not changed:
        raise RuntimeError("The infantry coat material was not found; refusing an unverified variant.")
    for collection in ["nodes","meshes"]:
        for item in gltf.get(collection,[]):
            if "name" in item:
                item["name"]=item["name"].replace("infantry_geometry","royalist_1817_geometry")
    gltf.setdefault("asset",{}).setdefault("extras",{}).update({
        "variant_of":"infantry.glb — original project geometry",
        "historical_status":"Aggregate royalist figure, 1817. Artistic reconstruction; uniform not verified.",
    })
    encoded=json.dumps(gltf,ensure_ascii=False,separators=(",",":")).encode("utf-8")
    encoded+=b" "*((-len(encoded))%4)
    rebuilt=[]
    for kind,chunk in chunks:
        if kind==b"JSON":chunk=encoded
        rebuilt.append(struct.pack("<I4s",len(chunk),kind)+chunk)
    body=b"".join(rebuilt)
    result=struct.pack("<4sII",b"glTF",2,12+len(body))+body
    target=OUT/"royalist_1817.glb"
    target.write_bytes(result)
    entry=dict(REPORT["infantry"])
    entry.update({
        "file":target.name,"bytes":len(result),"sha256":hashlib.sha256(result).hexdigest(),
        "source_variant":"infantry.glb",
        "provenance":"Own geometry; off-white material variant for an aggregate royalist figure in 1817.",
        "historical_note":"Artistic reconstruction; no verified regimental uniform or British insignia.",
        "animations_exported":[a.get("name","") for a in gltf.get("animations",[])],
    })
    REPORT["royalist_1817"]=entry
    print("ASSET_READY "+json.dumps(entry,ensure_ascii=False))


if "--only-royalist" in sys.argv:
    REPORT.update(json.loads((OUT/"model_manifest.json").read_text(encoding="utf-8")))
    royalist_variant()
else:
    mounted(1806)
    mounted(1817)
    horse_only()
    foot_soldier("infantry",True)
    royalist_variant()
    foot_soldier("dismounted_1806",False)
    ship()
(OUT/"model_manifest.json").write_text(json.dumps(REPORT,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print("ALL_MODELS_READY")
