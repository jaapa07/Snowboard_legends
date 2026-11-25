"""Renders previews of a rider .blend with Cycles (CPU).
Usage: python render_rider.py <rid> <out.png> [action] [frame] [mode=preview|portrait] [size]"""
import sys, os, math
import bpy
from mathutils import Vector

rid, out = sys.argv[1], sys.argv[2]
action = sys.argv[3] if len(sys.argv) > 3 else "idle"
frame = int(sys.argv[4]) if len(sys.argv) > 4 else 0
mode = sys.argv[5] if len(sys.argv) > 5 else "preview"
size = int(sys.argv[6]) if len(sys.argv) > 6 else 320
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT, "source_art", "blend", f"rider_{rid}.blend"))
sc = bpy.context.scene
rig = [o for o in sc.objects if o.type == "ARMATURE"][0]
for t in rig.animation_data.nla_tracks:
    t.mute = True
rig.animation_data.action = bpy.data.actions[action]
sc.frame_set(frame)
# board stand-in for previews only (real boards are separate assets)
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0.025))
b = bpy.context.active_object; b.scale = (0.26, 1.45, 0.04)
m = bpy.data.materials.new("pv"); m.use_nodes = True
m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.9, 0.3, 0.1, 1)
b.data.materials.append(m)
cam_d = bpy.data.cameras.new("cam"); cam = bpy.data.objects.new("cam", cam_d); sc.collection.objects.link(cam)
if mode == "portrait":
    target = Vector((0, 0, 1.32)); dist = 2.25; cam_d.lens = 60
    d = Vector((0.85, -1.0, 0.15)).normalized()
else:
    target = Vector((0, 0, 0.65)); dist = 3.4; cam_d.lens = 45
    d = Vector((0.9, -1.0, 0.35)).normalized()
cam.location = target + d * dist
cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
sc.camera = cam
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); sc.collection.objects.link(sun)
sun.data.energy = 4.0; sun.rotation_euler = (math.radians(50), 0, math.radians(30))
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.75, 1.0, 1) if mode != "portrait" else (0, 0, 0, 0)
w.node_tree.nodes["Background"].inputs[1].default_value = 0.8
sc.render.engine = "CYCLES"; sc.cycles.samples = 24; sc.cycles.device = "CPU"
try:
    sc.cycles.use_denoising = True
except Exception:
    pass
sc.render.film_transparent = mode == "portrait"
sc.render.resolution_x = size; sc.render.resolution_y = size
sc.render.filepath = out
sc.view_settings.view_transform = "Standard"
if mode == "portrait":
    b.hide_render = True
bpy.ops.render.render(write_still=True)
print("rendered", out)
