"""Top-down orthographic Cycles render of an authored course (terrain, course surface, landmarks, ramps, rails)
for the illustrated course maps. Writes <out_dir>/<track>.png and <track>.json (camera mapping for the overlay).
Usage: python render_maps.py <out_dir> <size> track_id [track_id ...]
The overlay (route, start/finish, stations, lift, vegetation) is drawn by tools/gen_maps.py."""
import sys, os, math, json
import bpy
from mathutils import Vector

out_dir, size = sys.argv[1], int(sys.argv[2])
tracks = sys.argv[3:]
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
os.makedirs(out_dir, exist_ok=True)

for tid in tracks:
    bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT, "source_art", "blend", f"track_{tid}.blend"))
    sc = bpy.context.scene
    course = bpy.data.objects["course_surface"]
    pts = [course.matrix_world @ Vector(c) for c in course.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    ctr = (lo + hi) * 0.5
    # landscape card (3:2): turn the camera 90 degrees when the course runs north-south so it fills the frame
    w_, h_ = hi.x - lo.x, hi.y - lo.y
    rot = math.pi / 2 if h_ > w_ else 0.0
    long_, short_ = max(w_, h_), min(w_, h_)
    span = max(long_ * 1.12, short_ * 1.5 * 1.12)
    cam_d = bpy.data.cameras.new("mapcam")
    cam_d.type = "ORTHO"
    cam_d.ortho_scale = span
    cam_d.clip_end = 5000.0
    cam = bpy.data.objects.new("mapcam", cam_d)
    sc.collection.objects.link(cam)
    cam.location = (ctr.x, ctr.y, hi.z + 400.0)
    cam.rotation_euler = (0.0, 0.0, rot)   # looking straight down -Z
    sc.camera = cam
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sc.collection.objects.link(sun)
    sun.data.energy = 4.0
    sun.data.angle = math.radians(6)
    sun.rotation_euler = (math.radians(42), 0.0, math.radians(-35))
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.62, 0.75, 0.95, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.35
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 24
    sc.cycles.device = "CPU"
    try:
        sc.cycles.use_denoising = True
    except Exception:
        pass
    sc.render.film_transparent = False
    sc.render.resolution_x = size
    sc.render.resolution_y = size * 2 // 3
    sc.view_settings.view_transform = "AgX"       # compresses the bright snow so slopes and relief read
    sc.view_settings.exposure = -0.6
    try:
        sc.view_settings.look = "AgX - Medium High Contrast"
    except Exception:
        pass
    sc.render.filepath = os.path.join(out_dir, f"{tid}.png")
    bpy.ops.render.render(write_still=True)
    with open(os.path.join(out_dir, f"{tid}.json"), "w") as f:
        json.dump({"cx": ctr.x, "cy": ctr.y, "span": span, "w": size, "h": size * 2 // 3, "rot": rot}, f)
    print("rendered map", tid)
