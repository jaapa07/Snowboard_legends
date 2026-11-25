"""Shared Blender (bpy 5.x) modelling helpers for Snowboard Legends 3D.
All geometry is authored in Blender through these scripts (scripted modelling),
saved to .blend source files and exported to GLB (+Y up, metres)."""
import bpy, bmesh, math
from mathutils import Vector, Matrix, Euler

_MATS = {}


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _MATS.clear()


def mat(name, color, rough=0.6, metal=0.0, emit=None, emit_strength=1.0, alpha=1.0):
    if name in _MATS:
        return _MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    c = color if len(color) == 4 else (*color, 1.0)
    b.inputs["Base Color"].default_value = c
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit is not None:
        b.inputs["Emission Color"].default_value = (*emit, 1.0)
        b.inputs["Emission Strength"].default_value = emit_strength
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
        m.blend_method = "BLEND" if hasattr(m, "blend_method") else None
    _MATS[name] = m
    return m


def hexc(h):
    h = h.lstrip("#")
    return tuple(((int(h[i:i + 2], 16) / 255.0) ** 2.2) for i in (0, 2, 4))


def _obj_from_bm(bm, name, material=None):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    if material is not None:
        me.materials.append(material)
    return ob


def box(name, size, loc=(0, 0, 0), rot=(0, 0, 0), material=None, bevel=0.0, segs=2):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=segs, affect="EDGES", profile=0.5)
    ob = _obj_from_bm(bm, name, material)
    ob.location = loc
    ob.rotation_euler = rot
    return ob


def cyl(name, r, depth, loc=(0, 0, 0), rot=(0, 0, 0), material=None, verts=16, r2=None, cap=True):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=cap, cap_tris=False, segments=verts,
                          radius1=r, radius2=(r if r2 is None else r2), depth=depth)
    ob = _obj_from_bm(bm, name, material)
    ob.location = loc
    ob.rotation_euler = rot
    return ob


def sphere(name, r, loc=(0, 0, 0), scale=(1, 1, 1), material=None, seg=16, rings=10, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=r)
    bmesh.ops.scale(bm, vec=Vector(scale), verts=bm.verts)
    ob = _obj_from_bm(bm, name, material)
    ob.location = loc
    ob.rotation_euler = rot
    return ob


def torus(name, R, r, loc=(0, 0, 0), rot=(0, 0, 0), material=None, seg=24, cseg=8):
    bm = bmesh.new()
    verts = []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        ring = []
        for j in range(cseg):
            b = 2 * math.pi * j / cseg
            x = (R + r * math.cos(b)) * math.cos(a)
            y = (R + r * math.cos(b)) * math.sin(a)
            z = r * math.sin(b)
            ring.append(bm.verts.new((x, y, z)))
        verts.append(ring)
    for i in range(seg):
        for j in range(cseg):
            a, b = verts[i][j], verts[(i + 1) % seg][j]
            c, d = verts[(i + 1) % seg][(j + 1) % cseg], verts[i][(j + 1) % cseg]
            bm.faces.new((a, b, c, d))
    ob = _obj_from_bm(bm, name, material)
    ob.location = loc
    ob.rotation_euler = rot
    return ob


def mesh_from(name, verts, faces, material=None, mats=None, face_mats=None, uvs=None):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    if mats:
        for m in mats:
            me.materials.append(m)
        if face_mats:
            for p, mi in zip(me.polygons, face_mats):
                p.material_index = mi
    elif material is not None:
        me.materials.append(material)
    if uvs is not None:
        uvl = me.uv_layers.new(name="UVMap")
        for p in me.polygons:
            for li in p.loop_indices:
                vi = me.loops[li].vertex_index
                uvl.data[li].uv = uvs[vi]
    me.validate()
    me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def smooth(ob, angle=40):
    for p in ob.data.polygons:
        p.use_smooth = True
    try:
        ob.data.set_sharp_from_angle(angle=math.radians(angle))
    except Exception:
        pass
    return ob


def subsurf(ob, levels=1):
    m = ob.modifiers.new("Sub", "SUBSURF")
    m.levels = levels
    m.render_levels = levels
    return ob


def apply_all(ob):
    bpy.context.view_layer.objects.active = ob
    for m in list(ob.modifiers):
        with bpy.context.temp_override(object=ob, active_object=ob):
            bpy.ops.object.modifier_apply(modifier=m.name)
    return ob


def join(objs, name):
    objs = [o for o in objs if o is not None]
    for o in objs:
        if o.modifiers:
            apply_all(o)
    ctx = {"active_object": objs[0], "selected_editable_objects": objs, "object": objs[0]}
    with bpy.context.temp_override(**ctx):
        bpy.ops.object.join()
    ob = objs[0]
    ob.name = name
    ob.data.name = name
    return ob


def apply_transform(ob):
    ob.data.transform(ob.matrix_basis)
    ob.matrix_basis = Matrix.Identity(4)
    return ob


def parent(child, par):
    child.parent = par
    return child


def empty(name, loc=(0, 0, 0)):
    e = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(e)
    e.location = loc
    return e


def tri_count(objs=None):
    objs = objs or [o for o in bpy.data.objects if o.type == "MESH"]
    t = 0
    for o in objs:
        for p in o.data.polygons:
            t += len(p.vertices) - 2
    return t


def export_glb(path, objects=None, animations=False):
    if objects is not None:
        bpy.ops.object.select_all(action="DESELECT")
        for o in objects:
            o.select_set(True)
            for c in o.children_recursive:
                c.select_set(True)
    kw = dict(filepath=path, export_format="GLB", export_yup=True, export_apply=True,
              use_selection=objects is not None, export_animations=animations,
              export_vertex_color="ACTIVE")
    if animations:
        kw.update(export_animation_mode="ACTIONS", export_force_sampling=True, export_frame_range=False)
    bpy.ops.export_scene.gltf(**kw)


def save_blend(path):
    bpy.ops.wm.save_as_mainfile(filepath=path, compress=True)
