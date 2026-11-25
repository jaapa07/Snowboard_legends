"""Builds the 8 original riders of Snowboard Legends 3D.
Each rider: unique mesh parts (hair/headwear, outfit, accessories, proportions, face) on a shared humanoid
armature with IK-locked feet, plus the full clip set required by the spec. Output: assets/models/riders/<id>.glb
Usage: python build_riders.py [rider_id ...]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
import bpy
from mathutils import Vector, Quaternion, Matrix
from lib import *
import mixamo_retarget as mixr

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
P = math.pi
YAW = math.radians(35)
F = Vector((math.sin(YAW), -math.cos(YAW), 0))   # chest facing
U = Vector((0, 0, 1))
R = F.cross(U).normalized()                        # character right
L = -R
FPS = 30

RIDERS = {
    "niko":  dict(name="Niko", skin="#f2c6a0", jacket="#19c3c0", accent="#0b6f78", pants="#2a3550", boots="#ff8a1e", glove="#ffd23a", hair="#5a3420", head="spiky", goggles="big", scale=1.0, bw=1.0, hr=0.30, eye="#3a2a1a", victory="fist"),
    "mika":  dict(name="Mika", skin="#f6d2b4", jacket="#fff2e2", accent="#ff6f5e", pants="#ff6f5e", boots="#7a4ad2", glove="#ff6f5e", hair="#2a1a14", head="beanie_braids", goggles="small", scale=0.95, bw=0.92, hr=0.30, eye="#2a1a10", victory="wave"),
    "taro":  dict(name="Taro", skin="#d8a27a", jacket="#ff7a1a", accent="#2a2a30", pants="#3a3a44", boots="#2a2a30", glove="#2a2a30", hair="#1a1410", head="helmet", goggles="visor_strap", scale=1.06, bw=1.18, hr=0.29, eye="#1a1410", victory="flex"),
    "luna":  dict(name="Luna", skin="#f8dcc8", jacket="#8a4ae0", accent="#ffd23a", pants="#4a2a8a", boots="#ffffff", glove="#ffd23a", hair="#e8e0ff", head="ponytail_stars", goggles="star", scale=0.97, bw=0.9, hr=0.30, eye="#5a2aa0", victory="spin"),
    "boro":  dict(name="Boro", skin="#c8946a", jacket="#3aa84a", accent="#f2e0a0", pants="#2a5a30", boots="#6a4a2a", glove="#f2e0a0", hair="#3a2a1a", head="earflap", goggles="small", scale=1.04, bw=1.3, hr=0.31, eye="#1a1410", victory="clap", backpack=True),
    "yuki":  dict(name="Yuki", skin="#fbe4d6", jacket="#ffffff", accent="#3a7aff", pants="#3a7aff", boots="#1a3a8a", glove="#3a7aff", hair="#1a2a5a", head="hood", goggles="small", scale=0.96, bw=0.9, hr=0.29, eye="#1a3a8a", victory="bow"),
    "zed":   dict(name="Zed", skin="#e8b890", jacket="#ffd800", accent="#1a1a22", pants="#1a1a22", boots="#ffd800", glove="#1a1a22", hair="#1a1a22", head="visor_helmet", goggles="none", scale=1.02, bw=1.05, hr=0.28, eye="#00e0ff", victory="point", pads=True),
    "kaito": dict(name="Kaito", skin="#f0c09a", jacket="#c8283c", accent="#2a2d36", pants="#3a3f4c", boots="#2a2d36", glove="#2a2d36", hair="#1c1a24", head="ninja", goggles="none", scale=1.0, bw=1.02, hr=0.30, eye="#c87a10", victory="point", backpack=True, scarf="#ffb020", fur=True, pouch=True, wraps="#e8dcc0", hair_tip="#c8283c"),
    "pippa": dict(name="Pippa", skin="#f6d0b8", jacket="#ff7ab8", accent="#ffffff", pants="#d23a8a", boots="#ffffff", glove="#ffb0d8", hair="#ffcf5a", head="bunny", goggles="small", scale=0.9, bw=0.95, hr=0.32, eye="#3a1a2a", victory="jump", big_gloves=True),
}


def C(h, r=0.6, m=0.0, e=None, es=1.0):
    return mat("R_" + h.strip("#") + f"_{int(r*10)}{int(m*10)}", hexc(h), r, m, hexc(e) if e else None, es)


def seg_cyl(name, a, b, r, material, r2=None, verts=12):
    a, b = Vector(a), Vector(b)
    d = b - a
    o = cyl(name, r, d.length, material=material, verts=verts, r2=r2)
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    o.location = (a + b) / 2
    return o


def oriented(o, fwd=F):
    """Rotate an object built facing -Y so it faces the character's forward."""
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = Vector((0, -1, 0)).rotation_difference(fwd) @ o.rotation_quaternion if o.rotation_mode == "QUATERNION" else o.rotation_quaternion
    return o


def vg(o, bone):
    g = o.vertex_groups.new(name=bone)
    apply_transform(o)
    g.add([v.index for v in o.data.vertices], 1.0, "REPLACE")
    return o


def build_mesh(rid, s):
    k = s["scale"]; bw = s["bw"]; hr = s["hr"] * k * 1.12   # caricature: bigger head
    parts = []
    hip_z = 0.60 * k
    H = Vector((0, 0, hip_z))
    chest = H + U * 0.26 * k
    neck = H + U * (0.44 * k)
    head_c = neck + U * (hr * 0.95)
    skin, jacket, accent, pants = C(s["skin"], 0.7), C(s["jacket"], 0.75), C(s["accent"], 0.6), C(s["pants"], 0.8)
    # torso / jacket
    t = sphere("torso", 1.0, chest, scale=(0.275 * bw * k, 0.265 * bw * k, 0.31 * k), material=jacket, seg=18, rings=12)
    t.rotation_euler = (0, 0, YAW); subsurf(t); parts.append(vg(t, "spine"))
    quilt = C(s["jacket"], 0.85)
    for qi, (dz, rr) in enumerate(((-0.13, 0.245), (0.0, 0.27), (0.13, 0.245))):   # puffer-jacket quilting
        qb = torus(f"quilt{qi}", rr * bw * k, 0.032 * k, chest + U * dz * k, material=quilt, seg=22, cseg=6)
        qb.scale = (1.0, 0.97, 1.0)
        parts.append(vg(qb, "spine"))
    hem = torus("hem", 0.215 * bw * k, 0.045 * k, H + U * 0.07 * k, material=accent, seg=18, cseg=6)
    hem.scale = (1, 1, 1); parts.append(vg(hem, "hips"))
    col = torus("collar", 0.11 * k, 0.05 * k, neck - U * 0.03 * k, material=accent, seg=14, cseg=6)
    parts.append(vg(col, "spine"))
    zp = box("zip", (0.035 * k, 0.02, 0.34 * k), chest + F * 0.235 * bw * k, material=accent)
    zp.rotation_euler = (0, 0, YAW); parts.append(vg(zp, "spine"))
    for side in (-1, 1):  # jacket side stripes / pockets
        pk = box(f"pocket{side}", (0.09 * k, 0.03, 0.07 * k), chest + F * 0.21 * bw * k + R * side * 0.11 * bw * k - U * 0.08 * k, material=accent, bevel=0.01)
        pk.rotation_euler = (0, 0, YAW + side * 0.3); parts.append(vg(pk, "spine"))
    pel = sphere("pelvis", 1.0, H, scale=(0.235 * bw * k, 0.2 * bw * k, 0.15 * k), material=pants, seg=16, rings=10)
    pel.rotation_euler = (0, 0, YAW); parts.append(vg(pel, "hips"))
    if s.get("pads"):
        for side in (-1, 1):
            pd = box(f"pad{side}", (0.16 * k, 0.2 * k, 0.07 * k), chest + R * side * 0.24 * bw * k + U * 0.13 * k, material=accent, bevel=0.03)
            pd.rotation_euler = (side * 0.35, 0, YAW); parts.append(vg(pd, "spine"))
            ln = box(f"padl{side}", (0.17 * k, 0.03, 0.02), chest + R * side * 0.24 * bw * k + U * 0.17 * k + F * 0.08, material=C("#00e0ff", 0.3, 0, "#00e0ff", 3))
            ln.rotation_euler = (0, 0, YAW); parts.append(vg(ln, "spine"))
    if s.get("backpack"):
        bp = box("backpack", (0.3 * k, 0.18 * k, 0.34 * k), chest - F * 0.27 * bw * k, material=C("#d28a2a", 0.8), bevel=0.05, segs=3)
        bp.rotation_euler = (0, 0, YAW); parts.append(vg(bp, "spine"))
        bpp = box("bp_pocket", (0.2 * k, 0.06, 0.12 * k), chest - F * 0.37 * bw * k - U * 0.06 * k, material=C("#a8641a", 0.8), bevel=0.02)
        bpp.rotation_euler = (0, 0, YAW); parts.append(vg(bpp, "spine"))
        roll = cyl("bp_roll", 0.06 * k, 0.32 * k, chest - F * 0.27 * bw * k + U * 0.21 * k, rot=(0, P / 2, YAW), material=C("#5a8a3a", 0.8), verts=10)
        parts.append(vg(roll, "spine"))
    if s.get("fur"):
        fr = torus("furcollar", 0.15 * k * bw, 0.065 * k, neck - U * 0.05 * k, material=C("#f2eee6", 0.95), seg=18, cseg=7)
        for v in fr.data.vertices:  # tufted, irregular fur
            v.co = Vector(v.co) * (0.94 + 0.12 * ((hash((round(v.co.x, 3), round(v.co.y, 3))) % 100) / 100.0))
        parts.append(vg(fr, "spine"))
    if s.get("scarf"):
        sc = C(s["scarf"], 0.85)
        parts.append(vg(torus("scarf", 0.165 * k, 0.05 * k, neck + U * 0.035 * k, material=sc, seg=18, cseg=6), "spine"))
        knot = neck + U * 0.03 * k - F * 0.1 * k + L * 0.13 * k
        parts.append(vg(sphere("scarf_knot", 0.05 * k, knot, material=sc, seg=8, rings=6), "spine"))
        for j, (dr, dz) in enumerate(((-0.07, 0.03), (-0.11, -0.03))):
            p0 = knot
            for seg_i in range(4):  # tails flowing back and slightly up, tapering
                p1 = p0 - F * 0.13 * k + R * dr * k + U * (dz + 0.025 * seg_i) * k
                parts.append(vg(seg_cyl(f"stail{j}{seg_i}", p0, p1, 0.04 * k * (1 - seg_i * 0.18), sc, r2=0.035 * k * (1 - seg_i * 0.2), verts=6), "spine"))
                p0 = p1
    # neck + head
    parts.append(vg(cyl("neck", 0.07 * k, 0.1 * k, neck, material=skin, verts=10), "head"))
    hd = sphere("head", hr, head_c, scale=(1.0, 0.95, 0.93), material=skin, seg=20, rings=14)
    subsurf(hd); parts.append(vg(hd, "head"))
    for side in (-1, 1):   # ears: rounded, with an inner fold
        ec = head_c + R * side * hr * 0.97 - U * hr * 0.05 - F * hr * 0.05
        ear = sphere(f"ear{side}", hr * 0.2, ec, scale=(0.45, 0.8, 1.0), material=skin, seg=10, rings=7)
        ear.rotation_euler = (0, 0, YAW); parts.append(vg(ear, "head"))
        ein = sphere(f"earin{side}", hr * 0.11, ec + R * side * hr * 0.06, scale=(0.3, 0.6, 0.8), material=C("#e0907a", 0.7), seg=8, rings=5)
        ein.rotation_euler = (0, 0, YAW); parts.append(vg(ein, "head"))
    # face (eyes, pupils, highlights, brows, nose, mouth, cheeks)
    eye_w = C("#ffffff", 0.3)
    for side in (-1, 1):
        ep = head_c + F * hr * 0.86 + R * side * hr * 0.36 + U * hr * 0.05
        e = sphere(f"eye{side}", hr * 0.27, ep, scale=(0.75, 0.45, 1.05), material=eye_w, seg=14, rings=10)
        e.rotation_euler = (0, 0, YAW); parts.append(vg(e, "head"))
        ir = sphere(f"iris{side}", hr * 0.16, ep + F * hr * 0.095 - U * hr * 0.02, scale=(0.85, 0.4, 1.1), material=C(s["eye"], 0.25), seg=12, rings=8)
        ir.rotation_euler = (0, 0, YAW); parts.append(vg(ir, "head"))
        pu = sphere(f"pupil{side}", hr * 0.085, ep + F * hr * 0.125 - U * hr * 0.02, scale=(0.85, 0.35, 1.1), material=C("#0c0c12", 0.2), seg=10, rings=6)
        pu.rotation_euler = (0, 0, YAW); parts.append(vg(pu, "head"))
        hl = sphere(f"hl{side}", hr * 0.05, ep + F * hr * 0.16 + U * hr * 0.07 + R * side * hr * 0.035, material=C("#ffffff", 0.1, 0, "#ffffff", 0.6), seg=6, rings=4)
        parts.append(vg(hl, "head"))
        hl2 = sphere(f"hlb{side}", hr * 0.025, ep + F * hr * 0.16 - U * hr * 0.06 - R * side * hr * 0.03, material=C("#ffffff", 0.1, 0, "#ffffff", 0.6), seg=6, rings=4)
        parts.append(vg(hl2, "head"))
        lid = sphere(f"lid{side}", hr * 0.285, ep + U * hr * 0.035, scale=(0.78, 0.48, 1.05), material=skin, seg=14, rings=10)
        lid.rotation_euler = (0, 0, YAW)
        apply_transform(lid)
        for v in lid.data.vertices:   # keep only the top cap: an upper eyelid that gives the eyes expression
            if (Vector(v.co) - ep).dot(U) < hr * 0.12:
                v.co = Vector(v.co) - U * ((Vector(v.co) - ep).dot(U) - hr * 0.12)
        parts.append(vg(lid, "head"))
        br = box(f"brow{side}", (hr * 0.34, 0.03, hr * 0.085), ep + U * hr * 0.36 + F * hr * 0.04, material=C(s["hair"], 0.8), bevel=hr * 0.03)
        br.rotation_euler = (0, -side * 0.15, YAW); parts.append(vg(br, "head"))
        ck = sphere(f"cheek{side}", hr * 0.13, head_c + F * hr * 0.78 + R * side * hr * 0.55 - U * hr * 0.25, scale=(1, 0.35, 0.7), material=C("#ff9a9a", 0.7), seg=8, rings=5)
        ck.rotation_euler = (0, 0, YAW + side * 0.5); parts.append(vg(ck, "head"))
    no = sphere("nose", hr * 0.14, head_c + F * hr * 0.97 - U * hr * 0.12, scale=(1.0, 0.9, 0.85), material=C(s["skin"], 0.55), seg=10, rings=7)
    parts.append(vg(no, "head"))
    mo = torus("mouth", hr * 0.12, hr * 0.03, head_c + F * hr * 0.9 - U * hr * 0.36, material=C("#8a2a2a", 0.5), seg=12, cseg=4)
    mo.rotation_mode = "QUATERNION"
    mo.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(F)
    apply_transform(mo)
    for v in mo.data.vertices:  # keep lower half = smile
        if (Vector(v.co) - (head_c + F * hr * 0.9 - U * hr * 0.36)).dot(U) > 0:
            v.co = Vector(v.co) - U * ((Vector(v.co) - (head_c + F * hr * 0.9 - U * hr * 0.36)).dot(U))
    parts.append(vg(mo, "head"))
    # ears
    for side in (-1, 1):
        ea = sphere(f"ear{side}", hr * 0.16, head_c + R * side * hr * 0.97, scale=(0.5, 0.8, 1.0), material=skin, seg=8, rings=6)
        ea.rotation_euler = (0, 0, YAW); parts.append(vg(ea, "head"))
    hair = C(s["hair"], 0.8)
    top = head_c + U * hr * 0.6
    style = s["head"]
    if style == "spiky":
        cap = sphere("hcap", hr * 1.04, head_c + U * hr * 0.12 - F * hr * 0.05, scale=(1, 1, 0.85), material=hair, seg=16, rings=10)
        for v in cap.data.vertices:
            if v.co.z < -hr * 0.1: v.co.z = -hr * 0.1
        parts.append(vg(cap, "head"))
        for i, (a, b, l) in enumerate([(0, 0.9, 1.0), (0.9, 0.7, 0.9), (-0.9, 0.7, 0.9), (2.2, 0.6, 0.8), (-2.2, 0.6, 0.8), (3.14, 0.5, 0.85), (0.45, 0.4, 0.75), (-0.45, 0.4, 0.75)]):
            dirv = (F * math.cos(a) * math.sin(b) + R * math.sin(a) * math.sin(b) + U * math.cos(b)).normalized()
            base = head_c + dirv * hr * 0.85
            parts.append(vg(seg_cyl(f"spike{i}", base, base + (dirv + U * 0.6 - F * 0.3).normalized() * hr * 0.75 * l, hr * 0.2, hair, r2=0.005, verts=6), "head"))
    elif style == "ninja":
        cap = sphere("hcap", hr * 1.05, head_c + U * hr * 0.14 - F * hr * 0.08, scale=(1, 1.02, 0.86), material=hair, seg=16, rings=10)
        for v in cap.data.vertices:
            if v.co.z < -hr * 0.15: v.co.z = -hr * 0.15
        parts.append(vg(cap, "head"))
        tip = C(s.get("hair_tip", s["hair"]), 0.7)
        # long swept-back spikes (pointing up and backwards), two-tone tips
        for i, (a, b, l) in enumerate([(0.0, 0.55, 1.25), (0.55, 0.65, 1.1), (-0.55, 0.65, 1.1), (1.2, 0.8, 0.95), (-1.2, 0.8, 0.95),
                                        (2.0, 0.75, 1.0), (-2.0, 0.75, 1.0), (2.7, 0.7, 1.15), (-2.7, 0.7, 1.15), (3.14, 0.9, 1.2), (0.3, 0.3, 0.8), (-0.3, 0.3, 0.8)]):
            dirv = (F * math.cos(a) * math.sin(b) + R * math.sin(a) * math.sin(b) + U * math.cos(b)).normalized()
            base = head_c + dirv * hr * 0.82
            tipdir = (dirv + U * 0.35 - F * 0.9).normalized()
            mid = base + tipdir * hr * 0.55 * l
            parts.append(vg(seg_cyl(f"nspk{i}", base, mid, hr * 0.22, hair, r2=hr * 0.11, verts=6), "head"))
            parts.append(vg(seg_cyl(f"nspt{i}", mid, mid + tipdir * hr * 0.45 * l, hr * 0.11, tip, r2=0.004, verts=6), "head"))
        # side bangs framing the face
        for side in (-1, 1):
            b0 = head_c + F * hr * 0.45 + R * side * hr * 0.86 + U * hr * 0.3
            parts.append(vg(seg_cyl(f"nbang{side}", b0, b0 - U * hr * 0.5 + F * hr * 0.1 + R * side * hr * 0.12, hr * 0.12, hair, r2=0.004, verts=6), "head"))
    elif style == "beanie_braids":
        bn = sphere("beanie", hr * 1.07, head_c + U * hr * 0.18, scale=(1, 1, 0.9), material=C(s["accent"], 0.9), seg=16, rings=10)
        for v in bn.data.vertices:
            if v.co.z < 0: v.co.z = 0
        parts.append(vg(bn, "head"))
        parts.append(vg(torus("beanie_rim", hr * 1.0, hr * 0.12, head_c + U * hr * 0.2, material=C("#ffffff", 0.9), seg=20, cseg=6), "head"))
        parts.append(vg(sphere("pompom", hr * 0.3, head_c + U * hr * 1.18, material=C("#ffffff", 0.95), seg=10, rings=7), "head"))
        for side in (-1, 1):
            b0 = head_c + R * side * hr * 0.8 - F * hr * 0.2 - U * hr * 0.1
            for j in range(4):
                parts.append(vg(sphere(f"braid{side}{j}", hr * (0.17 - j * 0.02), b0 - U * hr * 0.28 * j + R * side * hr * 0.05 * j, material=hair, seg=8, rings=6), "head"))
            parts.append(vg(sphere(f"tie{side}", hr * 0.08, b0 - U * hr * 1.0, material=C(s["accent"]), seg=8, rings=5), "head"))
        fr = sphere("fringe", hr * 0.98, head_c + U * hr * 0.05 + F * hr * 0.12, scale=(1, 0.9, 0.5), material=hair, seg=14, rings=8)
        for v in fr.data.vertices:
            if v.co.z < -0.0: v.co.z = 0
        parts.append(vg(fr, "head"))
    elif style == "helmet":
        hm = sphere("helmet", hr * 1.12, head_c + U * hr * 0.15, scale=(1, 1.05, 0.92), material=C(s["jacket"], 0.3, 0.1), seg=18, rings=12)
        for v in hm.data.vertices:
            if v.co.z < -hr * 0.05: v.co.z = -hr * 0.05
        parts.append(vg(hm, "head"))
        st = box("hstripe", (hr * 0.3, hr * 2.2, hr * 0.12), head_c + U * hr * 1.13, material=C("#ffffff", 0.3), bevel=0.01)
        st.rotation_euler = (0, 0, YAW); parts.append(vg(st, "head"))
        for side in (-1, 1):
            parts.append(vg(sphere(f"hvent{side}", hr * 0.12, head_c + U * hr * 0.9 + R * side * hr * 0.45, scale=(1, 1, 0.4), material=C("#2a2a30", 0.4), seg=8, rings=5), "head"))
    elif style == "ponytail_stars":
        cap = sphere("hcap", hr * 1.05, head_c + U * hr * 0.1, scale=(1, 1, 0.9), material=hair, seg=16, rings=10)
        for v in cap.data.vertices:
            if v.co.z < -hr * 0.2 and (Vector(v.co)).dot(F) > 0: v.co.z = -hr * 0.2
        parts.append(vg(cap, "head"))
        p0 = head_c - F * hr * 0.9 + U * hr * 0.5
        for j in range(5):
            parts.append(vg(sphere(f"pony{j}", hr * (0.34 - j * 0.05), p0 - F * hr * 0.25 * j - U * hr * 0.3 * j, material=hair, seg=10, rings=7), "head"))
        star = C("#ffd23a", 0.3, 0.3, "#ffd23a", 0.6)
        for i, off in enumerate([R * 0.5 + U * 0.7, -R * 0.6 + U * 0.6]):
            parts.append(vg(cyl(f"star{i}", hr * 0.2, hr * 0.08, head_c + off * hr + F * hr * 0.3, rot=(P / 2, 0, YAW), material=star, verts=5), "head"))
        for i in range(3):
            st = cyl(f"jstar{i}", 0.04 * k, 0.02, chest + F * 0.22 * bw * k + R * (i - 1) * 0.08 * k + U * (0.05 * (i % 2)) * k, rot=(P / 2, 0, YAW), material=star, verts=5)
            parts.append(vg(st, "spine"))
    elif style == "earflap":
        hat = sphere("hat", hr * 1.08, head_c + U * hr * 0.15, scale=(1, 1, 0.9), material=C("#a8641a", 0.9), seg=16, rings=10)
        for v in hat.data.vertices:
            if v.co.z < 0: v.co.z = 0
        parts.append(vg(hat, "head"))
        for side in (-1, 1):
            fl = sphere(f"flap{side}", hr * 0.35, head_c + R * side * hr * 0.95 - U * hr * 0.25, scale=(0.35, 0.8, 1.0), material=C("#f2e0a0", 0.95), seg=10, rings=6)
            fl.rotation_euler = (0, 0, YAW); parts.append(vg(fl, "head"))
        parts.append(vg(torus("hat_rim", hr * 1.02, hr * 0.13, head_c + U * hr * 0.15, material=C("#f2e0a0", 0.95), seg=20, cseg=6), "head"))
    elif style == "hood":
        hd2 = sphere("hood", hr * 1.22, head_c + U * hr * 0.05 - F * hr * 0.12, scale=(1, 1.05, 1.0), material=C(s["jacket"], 0.85), seg=18, rings=12)
        for v in hd2.data.vertices:  # open the face
            if Vector(v.co).dot(F) > hr * 0.55: v.co = Vector(v.co) - F * (Vector(v.co).dot(F) - hr * 0.55)
        parts.append(vg(hd2, "head"))
        fur = torus("fur", hr * 0.95, hr * 0.17, head_c + F * hr * 0.62 + U * hr * 0.03, material=C("#e8eef8", 0.95), seg=20, cseg=6)
        fur.rotation_mode = "QUATERNION"; fur.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(F)
        parts.append(vg(fur, "head"))
        bang = sphere("bang", hr * 0.6, head_c + F * hr * 0.55 + U * hr * 0.55, scale=(1.3, 0.5, 0.45), material=hair, seg=10, rings=6)
        bang.rotation_euler = (0, 0, YAW); parts.append(vg(bang, "head"))
    elif style == "visor_helmet":
        hm = sphere("helmet", hr * 1.14, head_c + U * hr * 0.1, scale=(1.05, 1.1, 0.95), material=C(s["jacket"], 0.25, 0.3), seg=18, rings=12)
        parts.append(vg(hm, "head"))
        vs = sphere("visor", hr * 0.95, head_c + F * hr * 0.66 + U * hr * 0.1, scale=(1.05, 0.72, 0.48), material=C("#00c8ff", 0.05, 0.6, "#0090ff", 0.6), seg=16, rings=8)
        vs.rotation_euler = (0, 0, YAW); parts.append(vg(vs, "head"))
        parts.append(vg(seg_cyl("antenna", head_c + U * hr * 0.9 - F * hr * 0.4 + R * hr * 0.3, head_c + U * hr * 1.6 - F * hr * 0.8 + R * hr * 0.5, 0.012, C("#1a1a22", 0.4, 0.8), verts=6), "head"))
        parts.append(vg(sphere("ant_tip", hr * 0.08, head_c + U * hr * 1.62 - F * hr * 0.8 + R * hr * 0.5, material=C("#00e0ff", 0.2, 0, "#00e0ff", 4), seg=8, rings=5), "head"))
        for side in (-1, 1):
            parts.append(vg(cyl(f"earpc{side}", hr * 0.28, hr * 0.12, head_c + R * side * hr * 1.08, rot=(0, P / 2, YAW), material=C("#1a1a22", 0.4, 0.6), verts=12), "head"))
    elif style == "bunny":
        cap = sphere("hcap", hr * 1.04, head_c + U * hr * 0.1, scale=(1, 1, 0.88), material=hair, seg=16, rings=10)
        for v in cap.data.vertices:
            if v.co.z < -hr * 0.3: v.co.z = -hr * 0.3
        parts.append(vg(cap, "head"))
        hat = sphere("bhat", hr * 1.1, head_c + U * hr * 0.25, scale=(1, 1, 0.8), material=C(s["jacket"], 0.95), seg=16, rings=10)
        for v in hat.data.vertices:
            if v.co.z < 0.0: v.co.z = 0.0
        parts.append(vg(hat, "head"))
        for side in (-1, 1):
            base = head_c + U * hr * 0.95 + R * side * hr * 0.42
            ear = seg_cyl(f"bear{side}", base, base + (U * 1.0 + R * side * 0.35).normalized() * hr * 1.2, hr * 0.18, C(s["jacket"], 0.95), r2=hr * 0.12, verts=10)
            parts.append(vg(ear, "head"))
            inn = seg_cyl(f"bein{side}", base + F * hr * 0.1, base + F * hr * 0.1 + (U * 1.0 + R * side * 0.35).normalized() * hr * 1.0, hr * 0.08, C("#ffffff", 0.9), r2=hr * 0.05, verts=8)
            parts.append(vg(inn, "head"))
        for side in (-1, 1):
            parts.append(vg(sphere(f"curl{side}", hr * 0.22, head_c + R * side * hr * 0.85 - U * hr * 0.5, material=hair, seg=10, rings=6), "head"))
    # goggles
    g = s["goggles"]
    if g != "none":
        big = g == "big"
        band_h = head_c + U * hr * (0.55 if g != "visor_strap" else 0.4)
        band = torus("gband", hr * 1.03, hr * 0.07, band_h, material=C("#1a1a22" if g != "star" else "#8a4ae0", 0.6), seg=24, cseg=5)
        parts.append(vg(band, "head"))
        lens_col = {"big": "#ff8a3a", "small": "#5ad2ff", "visor_strap": "#ffd23a", "star": "#ff7ad2"}[g]
        if g == "visor_strap":
            lv = sphere("glens", hr * 0.55, band_h + F * hr * 0.95, scale=(1.4, 0.35, 0.45), material=C(lens_col, 0.05, 0.7, lens_col, 0.3), seg=14, rings=7)
            lv.rotation_euler = (0, 0, YAW); parts.append(vg(lv, "head"))
        else:
            for side in (-1, 1):
                rr = hr * (0.34 if big else 0.24)
                fr = torus(f"gframe{side}", rr, hr * 0.06, band_h + F * hr * 0.95 + R * side * rr * 0.95, material=C("#ffffff" if big else "#2a2a30", 0.4), seg=16, cseg=5)
                fr.rotation_mode = "QUATERNION"; fr.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(F)
                parts.append(vg(fr, "head"))
                le = sphere(f"glens{side}", rr, band_h + F * hr * 0.97 + R * side * rr * 0.95, scale=(1, 0.3, 1), material=C(lens_col, 0.05, 0.8, lens_col, 0.25), seg=12, rings=6)
                le.rotation_euler = (0, 0, YAW); parts.append(vg(le, "head"))
    # arms
    for side, sn in ((1, "R"), (-1, "L")):
        sh = chest + R * side * 0.24 * bw * k + U * 0.1 * k
        el = sh + R * side * 0.08 * k - U * 0.2 * k + F * 0.03 * k
        wr = el + R * side * 0.03 * k - U * 0.18 * k + F * 0.06 * k
        sho = sphere(f"shoulder{sn}", 0.115 * k * bw, sh, material=jacket, seg=12, rings=8); subsurf(sho)
        parts.append(vg(sho, f"upperarm.{sn}"))
        parts.append(vg(seg_cyl(f"uarm{sn}", sh, el, 0.1 * k, jacket, r2=0.09 * k, verts=14), f"upperarm.{sn}"))
        parts.append(vg(torus(f"uq{sn}", 0.098 * k, 0.022 * k, (sh + el) / 2, material=quilt, seg=14, cseg=5), f"upperarm.{sn}"))
        elb = sphere(f"elbow{sn}", 0.092 * k, el, material=jacket, seg=12, rings=8); subsurf(elb)
        parts.append(vg(elb, f"forearm.{sn}"))
        parts.append(vg(seg_cyl(f"farm{sn}", el, wr, 0.09 * k, jacket, r2=0.08 * k, verts=14), f"forearm.{sn}"))
        if s.get("wraps"):
            for wi in range(3):
                wp = wr + (el - wr).normalized() * (0.03 + wi * 0.035)
                parts.append(vg(torus(f"wrap{sn}{wi}", 0.064 * k, 0.014 * k, wp, material=C(s["wraps"], 0.9), seg=10, cseg=4), f"forearm.{sn}"))
        parts.append(vg(torus(f"cuff{sn}", 0.082 * k, 0.03 * k, wr + (el - wr).normalized() * 0.02, material=accent, seg=14, cseg=6), f"forearm.{sn}"))
        gs = (1.55 if s.get("big_gloves") else 1.25)   # chunky cartoon mittens
        gl = sphere(f"glove{sn}", 0.08 * k * gs, wr + (wr - el).normalized() * 0.065 * gs, scale=(1, 0.8, 1.15), material=C(s["glove"], 0.8), seg=14, rings=10)
        subsurf(gl); parts.append(vg(gl, f"hand.{sn}"))
        th = sphere(f"thumb{sn}", 0.036 * k * gs, wr + (wr - el).normalized() * 0.05 * gs + F * 0.065 * gs, scale=(1, 1, 1.3), material=C(s["glove"], 0.8), seg=10, rings=6)
        parts.append(vg(th, f"hand.{sn}"))
    # legs: feet placed along the board (front = -Y)
    foot = {"R": Vector((0, -0.24, 0.11)), "L": Vector((0, 0.24, 0.11))}
    hipj = {"R": H + R * 0.1 * bw * k, "L": H + L * 0.1 * bw * k}
    knees = {}
    boots = C(s["boots"], 0.5)
    for sn in ("R", "L"):
        a, b = hipj[sn], foot[sn]
        mid = (a + b) / 2 + F * 0.12 * k
        knees[sn] = mid
        parts.append(vg(seg_cyl(f"thigh{sn}", a, mid, 0.122 * k * bw, pants, r2=0.108 * k, verts=14), f"thigh.{sn}"))
        if s.get("pouch") and sn == "R":
            pp = (a + mid) / 2 + R * 0.1 * k
            pz = box("legpouch", (0.07 * k, 0.12 * k, 0.11 * k), pp, material=C("#5a4632", 0.85), bevel=0.015)
            pz.rotation_euler = (0, 0, YAW); parts.append(vg(pz, f"thigh.{sn}"))
            st2 = torus("legstrap", 0.095 * k * bw, 0.012 * k, pp - R * 0.1 * k, material=C("#2a2a30", 0.6), seg=12, cseg=4)
            parts.append(vg(st2, f"thigh.{sn}"))
        if s.get("pouch"):
            parts.append(vg(sphere(f"kneepad{sn}", 0.085 * k, mid + F * 0.035 * k, scale=(1, 0.6, 1.1), material=C("#2a2d36", 0.5), seg=10, rings=6), f"shin.{sn}"))
        kn_ = sphere(f"knee{sn}", 0.11 * k, mid, material=pants, seg=14, rings=9)
        parts.append(vg(kn_, f"shin.{sn}"))
        parts.append(vg(seg_cyl(f"shin{sn}", mid, b + U * 0.1, 0.105 * k, pants, r2=0.125 * k, verts=14), f"shin.{sn}"))   # flared snow pants
        parts.append(vg(torus(f"pantcuff{sn}", 0.12 * k, 0.026 * k, b + U * 0.12, material=C(s["pants"], 0.9), seg=14, cseg=5), f"shin.{sn}"))
        bt = box(f"boot{sn}", (0.34 * k, 0.19 * k, 0.2 * k), b + U * 0.03 + Vector((0.02, 0, 0)), material=boots, bevel=0.07, segs=3)
        parts.append(vg(bt, f"ik.{sn}"))
        st = box(f"bootstrap{sn}", (0.36 * k, 0.05, 0.055 * k), b + U * 0.08 + Vector((0.02, 0, 0)), material=accent, bevel=0.015)
        parts.append(vg(st, f"ik.{sn}"))
        sole = box(f"sole{sn}", (0.35 * k, 0.2 * k, 0.045), b - U * 0.06 + Vector((0.02, 0, 0)), material=C("#2a2a30", 0.6), bevel=0.015)
        parts.append(vg(sole, f"ik.{sn}"))
    body = join(parts, rid + "_body")
    smooth(body, 50)
    return body, dict(H=H, chest=chest, neck=neck, head_c=head_c, hr=hr, hipj=hipj, knees=knees, foot=foot, k=k, bw=bw)


def build_armature(rid, j):
    k = j["k"]
    arm_d = bpy.data.armatures.new(rid + "_rig")
    ob = bpy.data.objects.new(rid + "_rig", arm_d)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_d.edit_bones

    def bone(n, h, t, par=None, deform=True):
        b = eb.new(n); b.head = h; b.tail = t; b.use_deform = deform
        if par: b.parent = eb[par]
        return b
    bone("root", (0, 0, 0), (0, 0.3, 0))
    H, chest, neck, hc, hr = j["H"], j["chest"], j["neck"], j["head_c"], j["hr"]
    bone("hips", H, H + U * 0.14 * k, "root")
    bone("spine", H + U * 0.14 * k, neck, "hips")
    bone("head", neck, hc + U * hr, "spine")
    for side, sn in ((1, "R"), (-1, "L")):
        sh = chest + R * side * 0.24 * j["bw"] * k + U * 0.1 * k
        el = sh + R * side * 0.08 * k - U * 0.2 * k + F * 0.03 * k
        wr = el + R * side * 0.03 * k - U * 0.18 * k + F * 0.06 * k
        bone(f"upperarm.{sn}", sh, el, "spine")
        bone(f"forearm.{sn}", el, wr, f"upperarm.{sn}")
        bone(f"hand.{sn}", wr, wr + (wr - el).normalized() * 0.1, f"forearm.{sn}")
        kn = j["knees"][sn]; ft = j["foot"][sn]
        bone(f"thigh.{sn}", j["hipj"][sn], kn, "hips")
        bone(f"shin.{sn}", kn, ft + U * 0.06, f"thigh.{sn}")
        bone(f"ik.{sn}", ft + U * 0.06, ft + U * 0.06 + Vector((0.15, 0, 0)), "root")
        bone(f"pole.{sn}", kn + F * 0.6, kn + F * 0.6 + U * 0.1, "root", deform=False)
    for b in eb:
        b.roll = 0
    eb["shin.R"].use_connect = False
    bpy.ops.object.mode_set(mode="POSE")
    for sn in ("R", "L"):
        c = ob.pose.bones[f"shin.{sn}"].constraints.new("IK")
        c.target = ob; c.subtarget = f"ik.{sn}"; c.pole_target = ob; c.pole_subtarget = f"pole.{sn}"
        c.pole_angle = -P / 2; c.chain_count = 2; c.use_tail = True
    bpy.ops.object.mode_set(mode="OBJECT")
    return ob


# ---------------- animation authoring -----------------
def axis_q(axis, deg):
    return Quaternion(axis, math.radians(deg))


def pose_q(rig, bname, pitch=0, yaw=0, roll=0):
    """Rotation expressed in character axes (pitch fwd about R, yaw about U, roll about F) -> bone local."""
    q = axis_q(R, -pitch) @ axis_q(U, yaw) @ axis_q(F, roll)
    bm = rig.data.bones[bname].matrix_local.to_3x3().to_quaternion()
    return bm.inverted() @ q @ bm


def loc_local(rig, bname, v):
    bm = rig.data.bones[bname].matrix_local.to_3x3()
    return bm.inverted() @ Vector(v)


BASE = {"hips_loc": (0, 0, -0.06)}


def P_(**kw):
    d = {}
    d.update(kw)
    return d


def arms(p=0, ab=0, el=0, y=0, pR=None, abR=None, elR=None):
    """Arm helper: p = swing forward, ab = raise sideways, el = elbow bend."""
    pR = p if pR is None else pR; abR = ab if abR is None else abR; elR = el if elR is None else elR
    # arms hang down: a forward swing / elbow bend is a negative rotation about R; abduction mirrors per side
    return {"upperarm.L": (-p, y, ab), "upperarm.R": (-pR, -y, -abR), "forearm.L": (-el, 0, 0), "forearm.R": (-elR, 0, 0)}


def mk(hips=(0, 0, -0.06), spine=(0, 0, 0), head=(0, 0, 0), hipsrot=(0, 0, 0), **extra):
    d = {"hips_loc": hips, "hips": hipsrot, "spine": spine, "head": head}
    d.update(extra)
    return d


def pose_set(*dicts):
    out = {}
    for d in dicts:
        out.update(d)
    return out


IDLE = pose_set(mk(hips=(0, 0, -0.05), spine=(8, -10, 0), head=(-4, -25, 0)), arms(5, 18, 25))
GLIDE = pose_set(mk(hips=(0, 0, -0.09), spine=(14, -14, 0), head=(-10, -28, 0)), arms(10, 32, 30, pR=-5))
TUCK = pose_set(mk(hips=(0, 0, -0.22), spine=(42, -15, 0), head=(-30, -25, 0)), arms(-25, 15, 70))
CARVE_L = pose_set(mk(hips=(0, 0.05, -0.14), spine=(18, -5, -14), head=(-10, -18, 8), hipsrot=(0, 0, -12)), arms(5, 55, 20, abR=20))
CARVE_R = pose_set(mk(hips=(0, -0.05, -0.14), spine=(18, -22, 14), head=(-10, -38, -8), hipsrot=(0, 0, 12)), arms(5, 20, 20, abR=55))
BRAKE = pose_set(mk(hips=(0, 0, -0.16), spine=(-6, -25, 0), head=(4, -35, 0), hipsrot=(-8, 0, 0)), arms(-20, 45, 15))
JCHARGE = pose_set(mk(hips=(0, 0, -0.26), spine=(34, -12, 0), head=(-20, -25, 0)), arms(-35, 25, 45))
TAKEOFF = pose_set(mk(hips=(0, 0, 0.02), spine=(-4, -10, 0), head=(-6, -20, 0)), arms(40, 60, 10))
AIR = pose_set(mk(hips=(0, 0, -0.08), spine=(10, -10, 0), head=(-8, -22, 0)), arms(15, 70, 25))
GRAB = pose_set(mk(hips=(0, 0, -0.24), spine=(48, -20, 10), head=(-28, -30, 0)), arms(55, 20, 30, pR=10, abR=65, elR=10))
SPIN = pose_set(mk(hips=(0, 0, -0.14), spine=(20, -5, 0), head=(-14, -5, 0)), arms(20, 10, 100))
FLIP = pose_set(mk(hips=(0, 0, -0.27), spine=(55, -5, 0), head=(-35, -10, 0)), arms(60, 10, 60))
GRIND = pose_set(mk(hips=(0, 0, -0.12), spine=(10, -30, 0), head=(-10, -40, 0)), arms(0, 75, 10))
LAND = pose_set(mk(hips=(0, 0, -0.25), spine=(30, -12, 0), head=(-15, -22, 0)), arms(10, 45, 40))
HIT = pose_set(mk(hips=(0, 0, -0.1), spine=(-28, -10, 18), head=(20, -10, 15)), arms(-60, 80, 10, pR=-40, abR=90))
FALL = pose_set(mk(hips=(0, 0, -0.32), spine=(-40, 0, 30), head=(25, 15, 20)), arms(-90, 100, 10, pR=-70, abR=110))
DIZZY = pose_set(mk(hips=(0, 0, -0.18), spine=(15, 10, -10), head=(10, 20, -15)), arms(-10, 30, 30))
LIFT = pose_set(mk(hips=(0, 0, -0.04), spine=(0, -20, 0), head=(-5, -35, 0)), arms(20, 10, 80))
DEFEAT = pose_set(mk(hips=(0, 0, -0.12), spine=(30, -10, 0), head=(30, -20, 0)), arms(-5, 5, 10))
VICTORY = {
    "fist": [pose_set(mk(spine=(-5, -10, 0), head=(-15, -20, 0)), arms(10, 20, 30, pR=0, abR=160, elR=10)), pose_set(mk(spine=(-8, -10, 0), head=(-20, -20, 0)), arms(10, 20, 30, pR=10, abR=150, elR=90))],
    "wave": [pose_set(mk(spine=(0, -15, 0), head=(-10, -30, -10)), arms(5, 15, 20, abR=130, elR=40)), pose_set(mk(spine=(0, -15, 0), head=(-10, -30, 10)), arms(5, 15, 20, abR=110, elR=80))],
    "flex": [pose_set(mk(hips=(0, 0, -0.1), spine=(5, 0, 0), head=(-10, -10, 0)), arms(0, 85, 110)), pose_set(mk(hips=(0, 0, -0.12), spine=(10, 0, 0), head=(-15, -10, 0)), arms(0, 95, 130))],
    "spin": [pose_set(mk(spine=(-5, -40, 0), head=(-15, -40, 0)), arms(0, 150, 5)), pose_set(mk(spine=(-5, 30, 0), head=(-15, 30, 0)), arms(0, 150, 5))],
    "clap": [pose_set(mk(spine=(5, -15, 0), head=(-10, -25, 0)), arms(70, 10, 60)), pose_set(mk(spine=(5, -15, 0), head=(-12, -25, 0)), arms(70, 25, 40))],
    "bow": [pose_set(mk(spine=(5, -15, 0), head=(-5, -25, 0)), arms(0, 10, 5)), pose_set(mk(spine=(45, -15, 0), head=(10, -25, 0)), arms(-10, 10, 70))],
    "point": [pose_set(mk(spine=(-5, -20, 0), head=(-15, -30, 0)), arms(0, 10, 90, pR=120, abR=20, elR=0)), pose_set(mk(spine=(-10, -25, 0), head=(-20, -35, 0)), arms(0, 10, 90, pR=140, abR=10, elR=0))],
    "jump": [pose_set(mk(hips=(0, 0, -0.2), spine=(20, -10, 0), head=(-10, -20, 0)), arms(-20, 30, 30)), pose_set(mk(hips=(0, 0, 0.08), spine=(-10, -10, 0), head=(-25, -20, 0)), arms(0, 150, 10))],
}

def padd(base, delta, w=1.0):
    """base pose + w * delta (per-bone tuple addition); missing bones in base start at zero."""
    out = dict(base)
    for k, v in delta.items():
        b = out.get(k, (0, 0, 0))
        out[k] = tuple(b[i] + w * v[i] for i in range(3))
    return out


def cycle(base, layers, length, step=4):
    """Seamless loop: base + sum(delta * sin(2*pi*(f*t) + phase)) for each (delta, freq, phase) layer.
    Gives continuous secondary motion (weight shift, arm balance, breathing) instead of two static poses."""
    keys = []
    for fr in range(0, length + 1, step):
        t = fr / length
        pose = dict(base)
        for delta, freq, phase in layers:
            pose = padd(pose, delta, math.sin(2 * math.pi * (freq * t) + phase))
        keys.append((fr, pose))
    keys[-1] = (length, keys[0][1])   # exact loop closure
    return keys


H = lambda x=0, y=0, z=0: {"hips_loc": (x, y, z)}
SP = lambda p=0, y=0, r=0: {"spine": (p, y, r)}
HD = lambda p=0, y=0, r=0: {"head": (p, y, r)}
HR = lambda p=0, y=0, r=0: {"hips": (p, y, r)}
ARM_L = lambda p=0, ab=0, el=0: {"upperarm.L": (-p, 0, ab), "forearm.L": (-el, 0, 0)}
ARM_R = lambda p=0, ab=0, el=0: {"upperarm.R": (-p, 0, -ab), "forearm.R": (-el, 0, 0)}


def M(*ds):
    return pose_set(*ds)


SPIN_OPEN = pose_set(SPIN, arms(10, 70, 20))
SPIN_WRAP = pose_set(SPIN, arms(45, 5, 115))
FLIP_TIGHT = pose_set(FLIP, mk(hips=(0, 0, -0.31), spine=(64, -5, 0), head=(-40, -10, 0)), arms(70, 5, 75))

CLIPS = [
    # name, loop, [(frame, pose)]  — all loops are seamless; rates are scaled at runtime by speed
    ("idle", True, cycle(IDLE, [(M(SP(3, 0, 0), H(0, 0, -0.012)), 2, 0.0),            # breathing
                                (M(HD(0, 22, 4)), 1, 0.0),                              # look around
                                (M(H(0, 0.02, 0), HR(0, 0, 3)), 1, 1.2),                 # weight shift
                                (M(ARM_L(4, 5, 6), ARM_R(-4, 5, 6)), 1, 0.6)], 72, 6)),
    ("push", True, cycle(GLIDE, [(M(H(0, 0, -0.06), SP(10, 0, 0), HD(-4, 0, 0)), 1, 0.0),   # pumping
                                 (M(ARM_L(22, 0, 10), ARM_R(-22, 0, -10)), 1, 0.0)], 24, 3)),
    ("glide", True, cycle(GLIDE, [(M(H(0, 0.03, -0.015), SP(0, 0, 4), HR(0, 0, 3)), 1, 0.0),   # weight shift
                                  (M(ARM_L(0, 10, 8), ARM_R(0, -8, -6)), 1, 0.4),             # balancing arms
                                  (M(HD(3, 6, -3), SP(3, 0, 0)), 2, 0.9),                      # bob
                                  (M(H(0, 0, -0.02)), 3, 0.3)], 48, 4)),
    ("tuck", True, cycle(TUCK, [(M(H(0, 0, -0.015), SP(2, 0, 0)), 2, 0.0), (M(HD(-3, 4, 0)), 1, 0.5)], 24, 3)),
    ("carveLeft", True, cycle(pose_set(CARVE_L, mk(hips=(0, 0.06, -0.18), spine=(21, -5, -17), head=(-10, -14, 10), hipsrot=(0, 0, -15)), arms(0, 62, 18, abR=14)),
                              [(M(H(0, 0.015, -0.03), SP(2, 0, -3)), 1, 0.0), (M(ARM_L(8, 8, 0), ARM_R(-6, 0, 10)), 1, 0.7)], 40, 4)),
    ("carveRight", True, cycle(pose_set(CARVE_R, mk(hips=(0, -0.06, -0.18), spine=(21, -22, 17), head=(-10, -42, -10), hipsrot=(0, 0, 15)), arms(0, 14, 18, abR=62)),
                               [(M(H(0, -0.015, -0.03), SP(2, 0, 3)), 1, 0.0), (M(ARM_R(8, 8, 0), ARM_L(-6, 0, 10)), 1, 0.7)], 40, 4)),
    ("brake", True, cycle(BRAKE, [(M(H(0, 0, -0.01), SP(2, 0, 1)), 4, 0.0), (M(ARM_L(0, 6, 0), ARM_R(0, 6, 0)), 2, 1.0)], 12, 1)),
    ("jumpCharge", True, cycle(JCHARGE, [(M(H(0, 0, -0.025), SP(3, 0, 0)), 2, 0.0), (M(ARM_L(-6, 0, 6), ARM_R(-6, 0, 6)), 2, 0.0)], 16, 2)),
    ("takeoff", False, [(0, JCHARGE), (3, pose_set(TAKEOFF, mk(hips=(0, 0, 0.06), spine=(-10, -10, 0), head=(-10, -20, 0)), arms(55, 80, 5))), (7, TAKEOFF), (12, AIR)]),
    ("airIdle", True, cycle(pose_set(AIR, mk(hips=(0, 0, -0.12), spine=(14, -10, 0), head=(-10, -22, 0))),
                            [(M(ARM_L(10, 12, 10), ARM_R(-10, 12, -10)), 1, 0.0), (M(H(0, 0, -0.02), SP(2, 0, 2)), 2, 0.4)], 40, 4)),
    ("grab", True, [(0, GRAB), (5, pose_set(GRAB, mk(hips=(0, 0, -0.27), spine=(54, -24, 14), head=(-32, -34, 0)))),
                    (12, pose_set(GRAB, mk(hips=(0, 0, -0.26), spine=(52, -14, 4), head=(-30, -22, 6)), arms(55, 20, 30, pR=10, abR=80, elR=5))),
                    (18, pose_set(GRAB, mk(hips=(0, 0, -0.27), spine=(54, -26, 16), head=(-32, -36, -4)))), (24, GRAB)]),
    ("spin", True, [(0, SPIN_OPEN), (4, SPIN_WRAP), (10, pose_set(SPIN_WRAP, mk(hips=(0, 0, -0.16), spine=(24, -8, 6)))), (16, SPIN_WRAP), (20, SPIN_OPEN)]),
    ("flip", True, [(0, FLIP), (5, FLIP_TIGHT), (15, FLIP_TIGHT), (20, FLIP)]),
    ("grind", True, cycle(GRIND, [(M(SP(0, 0, 7), HR(0, 0, 4), H(0, 0.02, 0)), 1, 0.0), (M(ARM_L(0, 12, 6), ARM_R(0, -10, -6)), 1, 1.2), (M(HD(0, 8, 4)), 2, 0.5)], 30, 3)),
    ("landSoft", False, [(0, AIR), (3, LAND), (6, pose_set(LAND, mk(hips=(0, 0, -0.28), spine=(34, -12, 0)))), (11, pose_set(GLIDE, mk(hips=(0, 0, -0.04), spine=(8, -14, 0)))), (16, GLIDE)]),
    ("landHard", False, [(0, AIR), (3, pose_set(LAND, mk(hips=(0, 0, -0.35), spine=(50, -12, 0), head=(-25, -22, 0)), arms(30, 70, 20))),
                         (9, pose_set(LAND, mk(hips=(0, 0, -0.3), spine=(40, -4, 8)), arms(10, 85, 10, abR=40))),
                         (15, pose_set(LAND, mk(spine=(36, -18, -8)), arms(10, 40, 30, abR=80))), (26, GLIDE)]),
    ("hit", False, [(0, GLIDE), (3, HIT), (7, pose_set(HIT, mk(spine=(-36, -10, 22), head=(28, -10, 20)))), (13, pose_set(HIT, mk(spine=(-12, -10, -8), head=(5, -10, -5)))), (24, GLIDE)]),
    ("fall", False, [(0, HIT), (6, FALL), (12, pose_set(FALL, mk(spine=(-50, 10, -25), head=(30, 25, -20)), arms(-100, 130, 5, pR=-50, abR=80))),
                     (20, pose_set(FALL, mk(spine=(-35, -10, 35)))), (30, FALL), (40, pose_set(FALL, mk(head=(25, 5, 15))))]),
    ("recover", False, [(0, FALL), (8, DIZZY), (12, pose_set(DIZZY, mk(head=(10, -15, 15)))), (16, pose_set(DIZZY, mk(head=(10, 20, -15)))), (24, GLIDE)]),
    ("liftEnter", False, [(0, GLIDE), (8, pose_set(LIFT, mk(hips=(0, 0, -0.08)))), (15, LIFT)]),
    ("liftIdle", True, cycle(LIFT, [(M(HD(0, 25, 3)), 1, 0.0), (M(SP(2, 0, 0)), 2, 0.0), (M(ARM_L(0, 0, 8), ARM_R(0, 0, -8)), 1, 1.0)], 72, 6)),
    ("liftExit", False, [(0, LIFT), (8, pose_set(GLIDE, mk(hips=(0, 0, -0.14)))), (15, GLIDE)]),
    ("defeat", True, cycle(DEFEAT, [(M(HD(4, 20, 3)), 1, 0.0), (M(SP(3, 0, 0), H(0, 0, -0.01)), 2, 0.0)], 60, 5)),
]


def apply_pose(rig, pose):
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = Quaternion()
        pb.location = Vector()
    for bn, v in pose.items():
        if bn == "hips_loc":
            rig.pose.bones["hips"].location = loc_local(rig, "hips", Vector(v))
            continue
        if bn.endswith("_loc"):
            ib = bn[:-4]
            if ib in rig.pose.bones:
                rig.pose.bones[ib].location = loc_local(rig, ib, Vector(v))
            continue
        if bn not in rig.pose.bones:
            continue
        if isinstance(v, Quaternion):   # armature-space relative rotation (motion transfer)
            bm = rig.data.bones[bn].matrix_local.to_3x3().to_quaternion()
            rig.pose.bones[bn].rotation_quaternion = bm.inverted() @ v @ bm
            continue
        rig.pose.bones[bn].rotation_quaternion = pose_q(rig, bn, *v)


def key_all(rig, frame):
    for pb in rig.pose.bones:
        if pb.name.startswith("pole") or pb.name == "root":
            continue
        if pb.name.startswith("ik"):
            pb.keyframe_insert("location", frame=frame)   # rest in authored clips; the push clip lifts the back foot
            continue
        pb.keyframe_insert("rotation_quaternion", frame=frame)
        if pb.name == "hips":
            pb.keyframe_insert("location", frame=frame)


# ---------------- motion-captured clips (Mixamo, optional) -----------------
# name -> (file in source_art/anim_import, reference frame, gain, lift back foot, loop blend frames)
MOCAP = {
    # Skateboarding.fbx (riding still) was tried for "glide": its body moves < 3 degrees, less than the
    # authored glide cycle, so it is not used.
    "push": ("Skateboarding_1.fbx", 0, 1.0, True, 8),      # pushing with the back foot (start, low speed)
}
MIX = {}


def load_mocap():
    for name, (fn, *_rest) in MOCAP.items():
        path = mixr.available(ROOT, fn)
        if path:
            MIX[name] = mixr.sample(path, 24)   # build scenes run at the factory 24 fps
            print(f"MOCAP {name} <- {fn} ({len(MIX[name])} frames)")


def char_q(p=0, y=0, r=0):
    return axis_q(R, -p) @ axis_q(U, y) @ axis_q(F, r)


def mocap_clips(rig):
    base = {b: char_q(*GLIDE.get(b, (0, 0, 0))) for b in mixr.ORDER}
    leg_scale = rig.data.bones["hips"].head_local.z / 0.85
    out = []
    for name, frames in MIX.items():
        _fn, ref, gain, foot, lb = MOCAP[name]
        out.append((name, True, mixr.transfer(frames, base, GLIDE["hips_loc"], ref=ref, gain=gain,
                                              leg_scale=leg_scale, move_back_foot=foot, loop_blend=lb)))
    return out


def make_actions(rig, victory_kind):
    rig.animation_data_create()
    clips = list(CLIPS)
    if MIX:
        clips = [c for c in clips if c[0] not in MIX] + mocap_clips(rig)
    v = VICTORY[victory_kind]
    mid = padd(v[1], {"hips_loc": (0, 0, 0.02)})          # small overshoot for snap
    clips.append(("victory", True, [(0, v[0]), (8, mid), (15, v[1]), (22, mid), (30, v[0])]))
    actions = []
    for name, loop, keys in clips:
        act = bpy.data.actions.new(name)
        rig.animation_data.action = act
        for fr, pose in keys:
            apply_pose(rig, pose)
            key_all(rig, fr)
        act.use_fake_user = True
        act.use_frame_range = True
        act.frame_range = (0, keys[-1][0])
        actions.append(act)
        # NLA track so the exporter picks every clip
        tr = rig.animation_data.nla_tracks.new(); tr.name = name
        tr.strips.new(name, 0, act)
        tr.mute = True
        rig.animation_data.action = None
    apply_pose(rig, IDLE)
    return actions


def build(rid):
    reset()
    s = RIDERS[rid]
    body, j = build_mesh(rid, s)
    rig = build_armature(rid, j)
    body.parent = rig
    m = body.modifiers.new("Armature", "ARMATURE"); m.object = rig
    make_actions(rig, s["victory"])
    rig.name = rid
    tris = tri_count([body])
    save_blend(os.path.join(ROOT, "source_art", "blend", f"rider_{rid}.blend"))
    export_glb(os.path.join(ROOT, "assets", "models", "riders", f"{rid}.glb"), animations=True)
    print(f"RIDER {rid} tris={tris}")
    return tris


if __name__ == "__main__":
    ids = sys.argv[1:] or list(RIDERS.keys())
    load_mocap()
    for r in ids:
        build(r)
