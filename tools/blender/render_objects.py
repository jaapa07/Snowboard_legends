"""Render each named root object of a .blend to a transparent PNG (thumbnails / icons).
Usage: python render_objects.py <blend> <outdir> <size> <view: board|item|prop> name1 name2 ..."""
import sys, os, math
import bpy
from mathutils import Vector

blend, outdir, size, view = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
names = sys.argv[5:]
bpy.ops.wm.open_mainfile(filepath=blend)
sc = bpy.context.scene
os.makedirs(outdir, exist_ok=True)
cam_d = bpy.data.cameras.new("cam"); cam = bpy.data.objects.new("cam", cam_d); sc.collection.objects.link(cam)
sc.camera = cam
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); sc.collection.objects.link(sun)
sun.data.energy = 3.5; sun.rotation_euler = (math.radians(40), math.radians(10), math.radians(35))
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.8, 0.85, 1.0, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 0.9
sc.render.engine = "CYCLES"; sc.cycles.samples = 16; sc.cycles.device = "CPU"
sc.render.film_transparent = True
sc.render.resolution_x = size; sc.render.resolution_y = size
sc.view_settings.view_transform = "Standard"
cam_d.type = "ORTHO"
for o in sc.objects:
    if o.type == "MESH":
        o.hide_render = True
for n in names:
    ob = bpy.data.objects[n]
    ob.hide_render = False
    pts = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
    ctr = sum(pts, Vector()) / 8
    ext = max((p - ctr).length for p in pts)
    if view == "board":
        d = Vector((0.0, 0.0, 1.0)); cam.location = ctr + d * 5
        cam.rotation_euler = (0, 0, math.radians(90))
        cam_d.ortho_scale = ext * 2.05
    else:
        d = Vector((0.7, -1.0, 0.6)).normalized(); cam.location = ctr + d * (ext * 6)
        cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
        cam_d.ortho_scale = ext * 2.1
    sc.render.filepath = os.path.join(outdir, n + ".png")
    bpy.ops.render.render(write_still=True)
    ob.hide_render = True
    print("rendered", n)
