"""Builds every course: visual ribbon + berms, simplified collider, surrounding terrain, backdrop mountains,
ramps, dividers, platforms, rails, tunnels, zone visuals and 3 unique landmarks per course.
Outputs: assets/models/tracks/<id>.glb, assets/data/tracks/<id>.json, source_art/blend/track_<id>.blend
Usage: python build_tracks.py [track_id ...]"""
import sys, os, math, json, random
HERE = os.path.dirname(__file__)
sys.path.insert(0, HERE); sys.path.insert(0, os.path.join(HERE, ".."))
import bpy
import numpy as np
from mathutils import Vector
from lib import *
from track_defs import TRACKS, ORDER
from track_geom import *

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
P = math.pi


def g2b(p):
    return (float(p[0]), float(-p[2]), float(p[1]))


def C(h, r=0.6, m=0.0, e=None, es=1.0):
    return mat("T_" + h.strip("#") + f"_{int(r*10)}{int(m*10)}", hexc(h), r, m, hexc(e) if e else None, es)


def named(name, col, r=0.7, m=0.0, e=None, es=1.0):
    return mat(name, hexc(col), r, m, hexc(e) if e else None, es)


class Course:
    def __init__(self, tid):
        self.tid = tid
        self.tr = TRACKS[tid]
        self.cl = centreline(self.tr)
        self.n = len(self.cl["s"])
        self.objs = []
        self.data = {"id": tid, "features": [], "vegetation": [], "props": []}
        self.rng = random.Random(hash(tid) & 0xffffffff)

    # ---------- helpers
    def idx(self, s):
        return int(max(0, min(self.n - 1, round(s / DS))))

    def sp(self, s, lat, h=0.0):
        return surface_point(self.cl, self.idx(s), lat, h)

    def frame(self, s):
        i = self.idx(s)
        return self.cl["fwd"][i], self.cl["right"][i], surface_normal(self.cl, i)

    def place(self, ob, s, lat, h=0.0, yaw_extra=0.0):
        """Place a Blender object at course coords, rotated to the course heading."""
        p = self.sp(s, lat, h)
        i = self.idx(s)
        ob.location = g2b(p)
        ob.rotation_euler = (0, 0, -math.radians(self.cl["head"][i]) + yaw_extra)
        self.objs.append(ob)
        return ob

    def zone_at(self, s, lat):
        for f in self.tr["features"]:
            if f["type"] == "zone" and f["s0"] <= s <= f["s1"] and f["lat0"] <= lat <= f["lat1"] and f["kind"] in ("ice", "slush", "boost"):
                return f["kind"]
        return None

    # ---------- course surface
    def ribbon(self, step=1, collider=False):
        cl = self.cl
        verts, faces, fmat, uvs = [], [], [], []
        mats = [named("track_groomed", "#f4f8ff", 0.55), named("track_berm", "#e6eefc", 0.7), named("track_ice", "#9ad8f4", 0.1),
                named("track_slush", "#b8c8d8", 0.8), named("track_boost", "#ffd23a", 0.4, 0, "#ffb400", 0.6)]
        rows = []
        idxs = list(range(0, self.n, step))
        if idxs[-1] != self.n - 1:
            idxs.append(self.n - 1)
        for i in idxs:
            hw = cl["width"][i] / 2
            xs, hs = cross_profile(hw)
            if not collider:
                xs = [-hw - BERM_W - 4] + xs + [hw + BERM_W + 4]
                hs = [BERM_H + 0.8] + hs + [BERM_H + 0.8]
            else:
                xs = [xs[0]] + xs + [xs[-1]]
                hs = [BERM_H + WALL_H] + hs + [BERM_H + WALL_H]
            row = []
            for x, h in zip(xs, hs):
                p = surface_point(cl, i, x, h)
                row.append(len(verts)); verts.append(g2b(p)); uvs.append((x / 6.0, cl["s"][i] / 6.0))
            rows.append((i, row, xs))
        for k in range(len(rows) - 1):
            i, a, xs = rows[k]; _, b, _ = rows[k + 1]
            for j in range(len(a) - 1):
                faces.append((a[j], a[j + 1], b[j + 1], b[j]))
                xm = (xs[j] + xs[j + 1]) / 2
                hw = cl["width"][i] / 2
                if abs(xm) > hw:
                    fmat.append(1)
                else:
                    z = self.zone_at(cl["s"][i], xm)
                    fmat.append({"ice": 2, "slush": 3, "boost": 4}.get(z, 0))
        name = "course-colonly" if collider else "course_surface"
        ob = mesh_from(name, verts, faces, mats=mats, face_mats=fmat, uvs=uvs)
        if not collider:
            smooth(ob, 60)
        self.objs.append(ob)
        return ob



def value_noise(nz, nx, cell, seed):
    rs = np.random.default_rng(seed)
    g = rs.random((nz // cell + 3, nx // cell + 3))
    zi = np.arange(nz) / cell; xi = np.arange(nx) / cell
    z0 = zi.astype(int); x0 = xi.astype(int)
    tz = (zi - z0)[:, None]; tx = (xi - x0)[None, :]
    tz = tz * tz * (3 - 2 * tz); tx = tx * tx * (3 - 2 * tx)
    a = g[z0][:, x0]; b = g[z0][:, x0 + 1]; c = g[z0 + 1][:, x0]; d = g[z0 + 1][:, x0 + 1]
    return (a * (1 - tx) + b * tx) * (1 - tz) + (c * (1 - tx) + d * tx) * tz


def build_terrain(co):
    cl = co.cl
    P2 = cl["pos"][:, [0, 2]]
    lo = P2.min(0) - 280; hi = P2.max(0) + 280
    res = 6.0
    nx = int((hi[0] - lo[0]) / res) + 1; nz = int((hi[1] - lo[1]) / res) + 1
    gx = lo[0] + np.arange(nx) * res; gz = lo[1] + np.arange(nz) * res
    X, Z = np.meshgrid(gx, gz)
    pts = np.stack([X.ravel(), Z.ravel()], 1)
    best_d = np.full(len(pts), 1e9); best_i = np.zeros(len(pts), int)
    for c0 in range(0, co.n, 48):
        seg = P2[c0:c0 + 48]
        d = np.linalg.norm(pts[:, None, :] - seg[None, :, :], axis=2)
        j = d.argmin(1); dm = d[np.arange(len(pts)), j]
        upd = dm < best_d
        best_d[upd] = dm[upd]; best_i[upd] = c0 + j[upd]
    cy = cl["pos"][best_i, 1]
    hw = cl["width"][best_i] / 2
    rgt = cl["right"][best_i][:, [0, 2]]
    lat = ((pts - P2[best_i]) * rgt).sum(1)
    bank = np.radians(cl["bank"][best_i])
    edge = hw + BERM_W
    edge_h = cy + BERM_H - np.sign(lat) * edge * np.sin(bank)
    seed = sum(ord(c) for c in co.tid)
    n1 = value_noise(nz, nx, 10, seed).ravel(); n2 = value_noise(nz, nx, 30, seed + 1).ravel()
    out = np.maximum(0.0, best_d - edge - 3.0)
    ramp = np.minimum(1.0, out / 40.0)
    h = edge_h + 0.4 - 0.0 * out + ramp * (n1 * 10 + n2 * 22) + out * 0.10 + np.maximum(0, out - 150) * 0.55
    under = best_d < edge + 3.0
    h = np.where(under, cy - 2.5, h)
    # keep the lift corridor clear (cable from bottom station to top station)
    a = np.array(co.lift_bottom[[0, 2]]); b = np.array(co.lift_top[[0, 2]])
    ab = b - a; t = np.clip(((pts - a) @ ab) / (ab @ ab), 0, 1)
    dl = np.linalg.norm(pts - (a + t[:, None] * ab), axis=1)
    cable_y = co.lift_bottom[1] + (co.lift_top[1] - co.lift_bottom[1]) * t
    clear = cable_y - 14.0
    h = np.where((dl < 40) & (h > clear), clear + (h - clear) * np.clip((dl - 20) / 20, 0, 1), h)
    H = h.reshape(nz, nx)
    co.terrain_grid = dict(lo=lo.tolist(), res=res, nx=nx, nz=nz)
    co.terrain_H = H
    verts = [g2b((X.ravel()[k], H.ravel()[k], Z.ravel()[k])) for k in range(nx * nz)]
    faces = []
    for zi in range(nz - 1):
        for xi in range(nx - 1):
            a0 = zi * nx + xi
            faces.append((a0, a0 + nx, a0 + nx + 1, a0 + 1))
    ob = mesh_from("terrain", verts, faces, material=named("terrain_snow", "#eef4ff", 0.75),
                   uvs=[(X.ravel()[k] / 12.0, Z.ravel()[k] / 12.0) for k in range(nx * nz)])
    # vertex colour: rocks on steep slopes
    gyz, gyx = np.gradient(H, res)
    steep = np.sqrt(gyx ** 2 + gyz ** 2).ravel()
    col = ob.data.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    rock = hexc(co.tr.get("rock_col", "#7a7f8c"))
    for k in range(nx * nz):
        t = min(1.0, max(0.0, (steep[k] - 0.55) * 2.0))
        c = (1 - t) * 1.0 + t * rock[0], (1 - t) * 1.0 + t * rock[1], (1 - t) * 1.0 + t * rock[2]
        col.data[k].color = (*c, 1.0)
    smooth(ob, 80)
    co.objs.append(ob)
    # backdrop mountains (ring)
    ctr = (P2.min(0) + P2.max(0)) / 2
    rad = np.linalg.norm(P2.max(0) - P2.min(0)) / 2 + 520
    base_y = cl["pos"][:, 1].min() - 40
    rng = random.Random(seed)
    mtn_mat = named("mountain", "#8a9ab8", 0.9); cap_mat = named("mountain_cap", "#f4f8ff", 0.6)
    for k in range(16):
        a = 2 * P * k / 16 + rng.random() * 0.2
        r = rad + rng.random() * 200
        hgt = 260 + rng.random() * 260
        rb = 260 + rng.random() * 160
        c = (ctr[0] + math.cos(a) * r, base_y, ctr[1] + math.sin(a) * r)
        m = cyl(f"mtn{k}", rb, hgt, material=mtn_mat, verts=9, r2=8)
        m.location = g2b((c[0], c[1] + hgt / 2, c[2]))
        for v in m.data.vertices:
            v.co.x *= 0.8 + rng.random() * 0.4; v.co.y *= 0.8 + rng.random() * 0.4
        cap = cyl(f"mtncap{k}", rb * 0.36, hgt * 0.34, material=cap_mat, verts=9, r2=6)
        cap.location = g2b((c[0], c[1] + hgt * 0.84, c[2]))
        co.objs += [m, cap]


def terrain_h(co, x, z):
    g = co.terrain_grid
    xi = (x - g["lo"][0]) / g["res"]; zi = (z - g["lo"][1]) / g["res"]
    xi = min(max(xi, 0), g["nx"] - 2); zi = min(max(zi, 0), g["nz"] - 2)
    x0, z0 = int(xi), int(zi); tx, tz = xi - x0, zi - z0
    H = co.terrain_H
    return float((H[z0, x0] * (1 - tx) + H[z0, x0 + 1] * tx) * (1 - tz) + (H[z0 + 1, x0] * (1 - tx) + H[z0 + 1, x0 + 1] * tx) * tz)


# ---------------- features
def wedge(co, name, s, lat, w, l, h, material, lip=None):
    """Kicker ramp following the banked surface: rises from s-l/2 to s+l/2."""
    v = []
    for (ds, dl, dh) in [(-l / 2, -w / 2, 0), (-l / 2, w / 2, 0), (l / 2, w / 2, 0), (l / 2, -w / 2, 0), (l / 2, w / 2, h), (l / 2, -w / 2, h)]:
        v.append(g2b(co.sp(s + ds, lat + dl, dh - (0.05 if dh == 0 else 0))))
    f = [(0, 3, 2, 1), (0, 1, 4, 5), (1, 2, 4), (0, 5, 3), (3, 5, 4, 2)]
    ob = mesh_from(name, v, f, material=material)
    co.objs.append(ob)
    if lip:
        a = co.sp(s + l / 2 - 0.05, lat - w / 2, h + 0.02); b = co.sp(s + l / 2 - 0.05, lat + w / 2, h + 0.02)
        a2 = co.sp(s + l / 2 - 0.6, lat - w / 2, h * (1 - 0.6 / l) + 0.02); b2 = co.sp(s + l / 2 - 0.6, lat + w / 2, h * (1 - 0.6 / l) + 0.02)
        co.objs.append(mesh_from(name + "_lip", [g2b(a), g2b(b), g2b(b2), g2b(a2)], [(0, 1, 2, 3), (3, 2, 1, 0)], material=lip))
    return ob


def strip_mesh(co, name, s0, s1, lat, w, h, material, top=True, step=2.0, taper=4.0):
    """A raised strip (divider mound / platform deck) following the course."""
    verts, faces = [], []
    s_vals = list(np.arange(s0, s1 + 0.01, step))
    for s in s_vals:
        t = min(1.0, (s - s0) / taper, (s1 - s) / taper) if taper > 0 else 1.0
        hh = h * max(0.0, t)
        for dl, dh in [(-w / 2, 0), (-w / 2 * 0.8, hh), (w / 2 * 0.8, hh), (w / 2, 0)]:
            verts.append(g2b(co.sp(s, lat + dl, dh - 0.05)))
    for k in range(len(s_vals) - 1):
        a = k * 4; b = a + 4
        for j in range(3):
            faces.append((a + j, b + j, b + j + 1, a + j + 1))
    ob = mesh_from(name, verts, faces, material=material)
    smooth(ob, 50)
    co.objs.append(ob)
    return ob


def tube(co, name, s0, s1, lat, radius, material, step=2.0, arc=P):
    verts, faces = [], []
    n = 12
    s_vals = list(np.arange(s0, s1 + 0.01, step))
    for s in s_vals:
        i = co.idx(s)
        c = co.sp(s, lat, 0.0); r = co.cl["right"][i]
        for k in range(n + 1):
            a = P / 2 - arc / 2 + arc * k / n
            p = c + r * (-math.cos(a) * radius) + np.array([0, 1.0, 0]) * (math.sin(a) * radius * 0.75)
            verts.append(g2b(p))
    for j in range(len(s_vals) - 1):
        for k in range(n):
            a = j * (n + 1) + k; b = a + n + 1
            faces.append((a, a + 1, b + 1, b))
    ob = mesh_from(name, verts, faces, material=material)
    smooth(ob, 50)
    co.objs.append(ob)
    # outer shell (double sided appearance)
    ob2 = mesh_from(name + "_out", [Vector(v) for v in verts], [tuple(reversed(f)) for f in faces], material=material)
    co.objs.append(ob2)
    return ob


def rail_mesh(co, name, s, lat, L, material):
    verts, faces = [], []
    pts = []
    s_vals = list(np.arange(s - L / 2, s + L / 2 + 0.01, 1.0))
    n = 8
    for sv in s_vals:
        c = co.sp(sv, lat, 0.9)
        pts.append(c)
        i = co.idx(sv); r = co.cl["right"][i]
        for k in range(n):
            a = 2 * P * k / n
            verts.append(g2b(c + r * math.cos(a) * 0.09 + np.array([0, 1.0, 0]) * math.sin(a) * 0.09))
    for j in range(len(s_vals) - 1):
        for k in range(n):
            a = j * n + k; b = a + n; a1 = j * n + (k + 1) % n; b1 = a1 + n
            faces.append((a, a1, b1, b))
    ob = mesh_from(name, verts, faces, material=material)
    smooth(ob, 60)
    co.objs.append(ob)
    for k in range(0, len(s_vals), 4):
        sv = s_vals[k]
        leg = cyl(f"{name}_leg{k}", 0.06, 0.9, material=named("metal_dark", "#555a66", 0.5, 0.8), verts=6)
        co.place(leg, sv, lat, 0.45)
    return [p.tolist() for p in pts]


def add_prop(co, kind, s, lat, yaw=0.0, scale=1.0, h=0.0):
    i = co.idx(s)
    p = co.sp(s, lat, h)
    co.data["props"].append(dict(kind=kind, pos=p.tolist(), yaw=-math.radians(co.cl["head"][i]) + yaw, scale=scale))


# ---------------- landmarks (3 unique per course)
def LM(co, f):
    kind = f["kind"]; s = f["s"]; lat = f["lat"]
    i = co.idx(s)
    base = co.sp(s, lat, 0)
    gy = terrain_h(co, base[0], base[2]) if abs(lat) > co.cl["width"][i] / 2 + BERM_W + 2 else base[1]
    origin = np.array([base[0], gy, base[2]])
    yaw = -math.radians(co.cl["head"][i])
    parts = []
    W = lambda col, r=0.7, m=0.0, e=None, es=1.0: C(col, r, m, e, es)

    def at(o, x, y, z):
        o.location = (x, y, z); parts.append(o); return o
    rng = random.Random(kind)
    if kind == "village":
        for k, (x, y, w, d, hgt, wall, roof) in enumerate([(0, 0, 7, 6, 4, "#c08850", "#a0302a"), (11, 3, 5, 5, 3.5, "#e0d4c0", "#2a6a8a"), (-10, 4, 6, 5, 3.8, "#8a5a32", "#3a8a5a"), (4, 12, 5, 4, 3.2, "#d8c0a0", "#8a2a5a")]):
            at(box(f"vh{k}", (w, d, hgt), material=W(wall), bevel=0.06), x, y, hgt / 2)
            r = mesh_from(f"vr{k}", [(-w / 2 - .5, -d / 2 - .5, 0), (w / 2 + .5, -d / 2 - .5, 0), (w / 2 + .5, d / 2 + .5, 0), (-w / 2 - .5, d / 2 + .5, 0), (0, -d / 2 - .5, w * .45), (0, d / 2 + .5, w * .45)],
                          [(0, 1, 4), (2, 3, 5), (1, 2, 5, 4), (3, 0, 4, 5)], material=W(roof))
            at(r, x, y, hgt)
            at(box(f"vw{k}", (w * 0.25, 0.1, hgt * 0.3), material=W("#ffd98a", 0.3, 0, "#ffc860", 1.2)), x, y - d / 2 - 0.05, hgt * 0.6)
        at(cyl("well", 1.2, 1.0, material=W("#8a8f99"), verts=12), 2, -8, 0.5)
        at(cyl("well_roof", 2.0, 1.2, material=W("#a0302a"), verts=4, r2=0.1), 2, -8, 3.0)
    elif kind == "covered_bridge":
        L = 16
        at(box("cb_deck", (5, L, 0.4), material=W("#8a5a32")), 0, 0, 0.6)
        for x in (-2.4, 2.4):
            at(box(f"cb_wall{x}", (0.3, L, 2.6), material=W("#a0302a")), x, 0, 2.0)
        r = mesh_from("cb_roof", [(-3, -L / 2, 0), (3, -L / 2, 0), (3, L / 2, 0), (-3, L / 2, 0), (0, -L / 2, 1.8), (0, L / 2, 1.8)], [(0, 1, 4), (2, 3, 5), (1, 2, 5, 4), (3, 0, 4, 5)], material=W("#5a3a2a"))
        at(r, 0, 0, 3.3)
        at(box("cb_snow", (6.2, L + 0.4, 0.3), material=W("#f4f8ff", 0.5)), 0, 0, 5.0)
        at(box("cb_creek", (40, 6, 0.1), material=W("#5ab0e0", 0.05, 0.1)), 0, 0, -0.3)
    elif kind == "watermill":
        at(box("wm_body", (8, 8, 7), material=W("#d8c0a0"), bevel=0.1), 0, 0, 3.5)
        at(cyl("wm_roof", 6.5, 5, material=W("#5a3a2a"), verts=4, r2=0.2), 0, 0, 9.5).rotation_euler = (0, 0, P / 4)
        hub = Vector((0, -4.6, 6))
        at(cyl("wm_hub", 0.6, 1.2, material=W("#4a3a30"), verts=10), hub.x, hub.y, hub.z).rotation_euler = (P / 2, 0, 0)
        for k in range(4):
            b = at(box(f"wm_blade{k}", (1.4, 0.2, 9), material=W("#f2e8d8")), hub.x, hub.y - 0.6, hub.z)
            b.rotation_euler = (0, k * P / 4, 0)
    elif kind == "clocktower":
        at(box("ct_base", (5, 5, 14), material=W("#c8b8a0"), bevel=0.1), 0, 0, 7)
        at(cyl("ct_face", 1.7, 0.3, material=W("#ffffff", 0.3, 0, "#fff8d0", 0.6), verts=24), 0, -2.55, 11).rotation_euler = (P / 2, 0, 0)
        at(box("ct_hand1", (0.15, 0.1, 1.3), material=W("#1a1a22")), 0, -2.75, 11.5)
        at(box("ct_hand2", (1.0, 0.1, 0.15), material=W("#1a1a22")), 0.4, -2.75, 11)
        at(cyl("ct_roof", 4.2, 5, material=W("#2a5a8a"), verts=4, r2=0.1), 0, 0, 16.5).rotation_euler = (0, 0, P / 4)
        at(sphere("ct_bell", 0.7, material=W("#ffc21a", 0.3, 0.9), seg=10, rings=6), 0, 0, 14.5)
    elif kind == "frozen_lake":
        at(cyl("fl_ice", 40, 0.3, material=W("#9ad8f4", 0.05, 0.1), verts=32), 0, 0, -0.5)
        for k in range(7):
            a = k * 2 * P / 7
            at(cyl(f"fl_rock{k}", 2 + rng.random() * 2, 2 + rng.random() * 3, material=W("#6a7a9a", 0.9), verts=6, r2=1), math.cos(a) * 38, math.sin(a) * 38, 1)
        at(box("fl_dock", (3, 12, 0.4), material=W("#8a5a32")), 0, 30, 0.2)
        at(cyl("fl_hut", 2.5, 3, material=W("#c03a3a"), verts=8), 6, 20, 1.5)
    elif kind == "ice_castle":
        for k, (x, y, r, hh) in enumerate([(0, 0, 4, 22), (-8, 4, 2.5, 15), (8, 4, 2.5, 15), (-5, -6, 2, 12), (5, -6, 2, 12)]):
            at(cyl(f"ic_t{k}", r, hh, material=W("#a8e4ff", 0.1, 0.1, "#7ad0ff", 0.25), verts=8), x, y, hh / 2)
            at(cyl(f"ic_c{k}", r * 1.2, r * 2.2, material=W("#e8f8ff", 0.1), verts=8, r2=0.1), x, y, hh + r * 1.1)
        at(box("ic_wall", (18, 3, 8), material=W("#c8f0ff", 0.1, 0.1)), 0, 2, 4)
    elif kind == "ice_bridge":
        for k in range(9):
            a = P * k / 8
            at(box(f"ib_s{k}", (3, 4.6, 1.2), material=W("#bfeaff", 0.1, 0.1, "#7ad0ff", 0.2)), math.cos(a) * 14, 0, math.sin(a) * 10 + 1).rotation_euler = (0, -a + P / 2, 0)
        for x in (-14, 14):
            at(cyl(f"ib_p{x}", 2, 3, material=W("#6a7a9a"), verts=8), x, 0, 0.5)
    elif kind == "volcano":
        at(cyl("vo_cone", 90, 110, material=W("#3a2a28", 0.95), verts=14, r2=16), 0, 60, 55)
        at(cyl("vo_glow", 15, 3, material=W("#ff5a1a", 0.6, 0, "#ff4a0a", 6), verts=14), 0, 60, 110.5)
        at(cyl("vo_lava", 3, 80, material=W("#ff6a1a", 0.6, 0, "#ff4a0a", 4), verts=6, r2=1.5), -10, 18, 55).rotation_euler = (0.65, 0, 0.2)
    elif kind == "lava_falls":
        at(box("lf_cliff", (24, 10, 26), material=W("#2a2022", 0.95)), 0, 6, 13)
        for k in range(3):
            at(box(f"lf_fall{k}", (2.2, 0.6, 24), material=W("#ff6a1a", 0.6, 0, "#ff4a0a", 5)), -7 + k * 7, 0.6, 12)
        at(cyl("lf_pool", 12, 0.6, material=W("#ff5a1a", 0.6, 0, "#ff3a0a", 4), verts=16), 0, -6, 0.2)
    elif kind == "obsidian_arch":
        for x in (-8, 8):
            at(box(f"oa_leg{x}", (3, 3, 16), material=W("#1a1218", 0.2, 0.4)), x, 0, 8).rotation_euler = (0, -0.12 * (1 if x > 0 else -1), 0)
        at(box("oa_top", (21, 3.4, 3), material=W("#1a1218", 0.2, 0.4)), 0, 0, 16.5)
        at(box("oa_glow", (19, 0.4, 0.6), material=W("#ff6a1a", 0.6, 0, "#ff4a0a", 3)), 0, -1.8, 15.5)
    elif kind == "pagoda":
        for k in range(4):
            w = 10 - k * 2
            at(box(f"pg_f{k}", (w, w, 3), material=W("#c02a2a", 0.6)), 0, 0, 1.5 + k * 4)
            at(cyl(f"pg_r{k}", w * 0.85, 1.2, material=W("#1a2a4a"), verts=4, r2=w * 0.5), 0, 0, 3.6 + k * 4).rotation_euler = (0, 0, P / 4)
            for c in ((-w / 2, -w / 2), (w / 2, -w / 2), (w / 2, w / 2), (-w / 2, w / 2)):
                at(sphere(f"pg_l{k}{c}", 0.45, material=W("#ffb040", 0.4, 0, "#ff9a20", 4), seg=8, rings=5), c[0], c[1], 3.0 + k * 4)
        at(cyl("pg_spire", 0.3, 4, material=W("#ffc21a", 0.3, 0.9), verts=6, r2=0.05), 0, 0, 19)
    elif kind == "ferris_wheel":
        hub = (0, 0, 16)
        at(torus("fw_ring", 13, 0.3, material=W("#ff3a6e", 0.4, 0.4, "#ff3a6e", 1.5), seg=40, cseg=6), *hub).rotation_euler = (P / 2, 0, 0)
        for k in range(10):
            a = 2 * P * k / 10
            sp_ = at(box(f"fw_sp{k}", (0.2, 0.2, 13), material=W("#e0e6f0", 0.4, 0.8)), hub[0] + math.cos(a) * 6.5, 0, hub[2] + math.sin(a) * 6.5)
            sp_.rotation_euler = (0, -a + P / 2, 0)
            at(box(f"fw_cab{k}", (1.6, 1.6, 1.6), material=W(["#ffd23a", "#3ad2ff", "#7aff7a", "#ff7ad2"][k % 4], 0.5, 0, ["#ffd23a", "#3ad2ff", "#7aff7a", "#ff7ad2"][k % 4], 0.8)), hub[0] + math.cos(a) * 13, 0, hub[2] + math.sin(a) * 13 - 1.2)
        for x in (-5, 5):
            at(box(f"fw_leg{x}", (0.5, 0.5, 18), material=W("#e0e6f0", 0.4, 0.8)), x * 0.6, 0, 8).rotation_euler = (0, 0.3 * (1 if x > 0 else -1), 0)
    elif kind == "plaza_tree":
        at(cyl("pt_base", 6, 0.8, material=W("#8a8f99"), verts=16), 0, 0, 0.4)
        for k in range(5):
            at(cyl(f"pt_c{k}", 5 - k * 0.9, 4, material=W("#1f5a3a", 0.85), verts=10, r2=0.4), 0, 0, 3 + k * 2.5)
        at(cyl("pt_star", 1.0, 0.4, material=W("#ffd23a", 0.3, 0.5, "#ffd23a", 5), verts=5), 0, 0, 15.5).rotation_euler = (P / 2, 0, 0)
        for k in range(16):
            a = k * 1.7; hh = 2.5 + k * 0.75; r = 4.6 - k * 0.25
            at(sphere(f"pt_light{k}", 0.25, material=W(["#ff3a3a", "#ffd23a", "#3ad2ff"][k % 3], 0.4, 0, ["#ff3a3a", "#ffd23a", "#3ad2ff"][k % 3], 5), seg=6, rings=4), math.cos(a) * r, math.sin(a) * r, hh)
    elif kind == "treehouse":
        at(cyl("th_trunk", 2.4, 24, material=W("#4e3424", 0.95), verts=12, r2=1.6), 0, 0, 12)
        at(box("th_deck", (9, 9, 0.5), material=W("#8a5a32")), 0, 0, 12)
        at(box("th_house", (5, 5, 4), material=W("#c08850")), 0, 0, 14.3)
        at(cyl("th_roof", 4.5, 3, material=W("#3a7a4a"), verts=4, r2=0.2), 0, 0, 17.8).rotation_euler = (0, 0, P / 4)
        for k in range(3):
            at(cyl(f"th_can{k}", 8 - k * 2, 5, material=W("#2a6e46"), verts=10, r2=1), 0, 0, 21 + k * 4)
        at(box("th_ladder", (1, 0.2, 12), material=W("#6b4a2e")), 0, -2.6, 6)
    elif kind == "mushroom_ring":
        for k in range(7):
            a = 2 * P * k / 7; r = 9
            hh = 2.5 + (k % 3) * 1.5
            at(cyl(f"mr_st{k}", 0.5, hh, material=W("#f2e8d8"), verts=8), math.cos(a) * r, math.sin(a) * r, hh / 2)
            cap = at(sphere(f"mr_cap{k}", 2.0 + (k % 3) * 0.6, scale=(1, 1, 0.5), material=W("#d22a2a"), seg=12, rings=6), math.cos(a) * r, math.sin(a) * r, hh)
            for d in range(4):
                at(sphere(f"mr_dot{k}{d}", 0.3, material=W("#ffffff"), seg=6, rings=4), math.cos(a) * r + math.cos(d * 1.6) * 1.1, math.sin(a) * r + math.sin(d * 1.6) * 1.1, hh + 0.7)
        at(cyl("mr_stone", 1.5, 3, material=W("#7a7f8c"), verts=6), 0, 0, 1.5)
    elif kind == "hollow_trunk":
        at(cyl("ht_log", 7, 30, material=W("#4e3424", 0.95), verts=16), 0, 0, 7).rotation_euler = (P / 2, 0, 0.3)
        at(cyl("ht_hole", 5.5, 30.2, material=W("#1a120c", 0.95), verts=16), 0, 0, 7).rotation_euler = (P / 2, 0, 0.3)
        at(sphere("ht_snow", 7, scale=(1.1, 4.2, 0.35), material=W("#f4f8ff", 0.5), seg=12, rings=6), 0, 0, 13.5).rotation_euler = (0, 0, 0.3)
        for k in range(4):
            at(sphere(f"ht_moss{k}", 1.5, material=W("#3a7a3a"), seg=8, rings=5), -6 + k * 4, -5, 3)
    elif kind == "water_tower":
        for x in (-2.5, 2.5):
            for y in (-2.5, 2.5):
                at(box(f"wt_leg{x}{y}", (0.4, 0.4, 12), material=W("#6a4a32")), x, y, 6)
        at(cyl("wt_tank", 4, 5, material=W("#8a5a32"), verts=16), 0, 0, 14.5)
        at(cyl("wt_roof", 4.4, 2.5, material=W("#5a5f68", 0.5, 0.7), verts=16, r2=0.3), 0, 0, 18.2)
        at(box("wt_spout", (0.5, 4, 0.5), material=W("#5a5f68", 0.5, 0.7)), 0, -5, 12).rotation_euler = (0.6, 0, 0)
    elif kind == "station_hall":
        at(box("sh_body", (24, 10, 8), material=W("#b8a890"), bevel=0.2), 0, 0, 4)
        at(box("sh_roof", (26, 12, 0.8), material=W("#5a5f68", 0.5, 0.6)), 0, 0, 8.4)
        at(box("sh_snow", (26, 12, 0.5), material=W("#f4f8ff", 0.5)), 0, 0, 9.0)
        at(cyl("sh_clock", 1.5, 0.3, material=W("#ffffff", 0.3, 0, "#fff8d0", 0.5), verts=20), 0, -5.2, 6).rotation_euler = (P / 2, 0, 0)
        for k in range(5):
            at(box(f"sh_win{k}", (2.6, 0.2, 3.4), material=W("#2a3040", 0.2, 0.3)), -9.6 + k * 4.8, -5.05, 3.8)
        for k in range(3):
            at(box(f"sh_track{k}", (0.2, 60, 0.2), material=W("#6a5040", 0.6, 0.6)), -2 + k * 2, -30, 0.1)
    elif kind == "signal_bridge":
        for x in (-10, 10):
            at(box(f"sb_leg{x}", (0.8, 0.8, 10), material=W("#4a4f58", 0.5, 0.7)), x, 0, 5)
        at(box("sb_top", (21, 1.2, 1.2), material=W("#4a4f58", 0.5, 0.7)), 0, 0, 10)
        for k, col in enumerate(["#ff2a2a", "#ffd23a", "#2aff6a"]):
            at(sphere(f"sb_l{k}", 0.4, material=W(col, 0.3, 0, col, 6), seg=8, rings=5), -4 + k * 4, -0.8, 9.2)
    elif kind == "weather_station":
        at(cyl("ws_dome", 5, 5, material=W("#e0e6f0", 0.3, 0.3), verts=16), 0, 0, 2.5)
        at(sphere("ws_top", 5, scale=(1, 1, 0.6), material=W("#ffffff", 0.2, 0.2), seg=16, rings=8), 0, 0, 5)
        at(box("ws_mast", (0.3, 0.3, 12), material=W("#8a8f99", 0.4, 0.8)), 6, 0, 6)
        for k in range(3):
            a = 2 * P * k / 3
            at(sphere(f"ws_cup{k}", 0.4, material=W("#ff3a3a"), seg=8, rings=5), 6 + math.cos(a) * 1.2, math.sin(a) * 1.2, 12)
        at(sphere("ws_beacon", 0.4, material=W("#ff3a3a", 0.3, 0, "#ff2a2a", 6), seg=8, rings=5), 6, 0, 12.6)
    elif kind == "ice_spires":
        for k in range(9):
            a = rng.random() * 2 * P; r = rng.random() * 12
            hh = 8 + rng.random() * 18
            at(cyl(f"is_{k}", 1.5 + rng.random() * 1.5, hh, material=W("#a8e4ff", 0.08, 0.1, "#7ad0ff", 0.35), verts=6, r2=0.05), math.cos(a) * r, math.sin(a) * r, hh / 2).rotation_euler = (rng.random() * 0.2, rng.random() * 0.2, 0)
    elif kind == "wind_turbines":
        for k in range(3):
            x = -16 + k * 16
            at(cyl(f"wtb_t{k}", 0.7, 26, material=W("#f2f4f8", 0.3, 0.2), verts=10, r2=0.45), x, 0, 13)
            at(box(f"wtb_n{k}", (1.4, 3, 1.4), material=W("#f2f4f8", 0.3, 0.2)), x, 0, 26.5)
            for b in range(3):
                bl = at(box(f"wtb_b{k}{b}", (0.6, 0.2, 11), material=W("#ffffff", 0.3)), x, -1.6, 26.5)
                bl.rotation_euler = (0, b * 2 * P / 3 + k, 0)
                bl.location = (x + math.sin(b * 2 * P / 3 + k) * 5.5, -1.6, 26.5 + math.cos(b * 2 * P / 3 + k) * 5.5)
    elif kind == "sky_temple":
        at(box("st_base", (20, 14, 2), material=W("#f2e8ff", 0.4)), 0, 0, 1)
        for k in range(6):
            x = -8 + (k % 3) * 8; y = -5 if k < 3 else 5
            at(cyl(f"st_col{k}", 0.9, 10, material=W("#ffffff", 0.3), verts=12), x, y, 7)
        at(box("st_roof", (22, 16, 1.4), material=W("#b8a0ff", 0.4)), 0, 0, 12.7)
        at(cyl("st_tri", 12, 5, material=W("#b8a0ff", 0.4), verts=4, r2=0.5), 0, 0, 15.8).rotation_euler = (0, 0, P / 4)
        at(sphere("st_orb", 1.5, material=W("#ffe0ff", 0.2, 0, "#ffb0ff", 4), seg=12, rings=8), 0, 0, 20)
    elif kind == "floating_isles":
        for k in range(5):
            x = rng.uniform(-20, 20); y = rng.uniform(-15, 15); z = 18 + rng.uniform(0, 22)
            r = rng.uniform(4, 8)
            at(cyl(f"fi_rock{k}", r, r * 1.4, material=W("#6a6aa0", 0.9), verts=7, r2=0.4), x, y, z - r * 0.7).rotation_euler = (P, 0, 0)
            at(cyl(f"fi_top{k}", r, 0.8, material=W("#f4f0ff", 0.5), verts=7), x, y, z)
            at(cyl(f"fi_tree{k}", r * 0.5, r * 1.2, material=W("#3a7a6a"), verts=7, r2=0.2), x, y, z + r * 0.6)
    elif kind == "star_gate":
        at(torus("sg_ring", 9, 0.9, material=W("#ffd23a", 0.2, 0.8, "#ffc21a", 2), seg=40, cseg=8), 0, 0, 11).rotation_euler = (P / 2, 0, 0)
        for k in range(8):
            a = 2 * P * k / 8
            at(cyl(f"sg_star{k}", 1.0, 0.4, material=W("#ffffff", 0.2, 0, "#fff0a0", 5), verts=5), math.cos(a) * 9, 0, 11 + math.sin(a) * 9).rotation_euler = (P / 2, 0, 0)
        for x in (-6, 6):
            at(cyl(f"sg_base{x}", 1.5, 3, material=W("#b8a0ff"), verts=8), x, 0, 1.5)
    else:
        raise ValueError("unknown landmark " + kind)
    grp = join(parts, f"landmark_{kind}")
    grp.location = g2b(origin)
    grp.rotation_euler = (0, 0, yaw)
    co.objs.append(grp)
    co.data["features"].append(dict(type="landmark", kind=kind, s=s, lat=lat, pos=origin.tolist()))


DIVIDER_PROPS = {"rocks": ["rock_grey"], "trees": ["tree_pine_a", "tree_pine_b"], "ice_pillars": ["rock_ice"], "lava_rocks": ["rock_dark"],
                 "houses": ["building_chalet", "building_shop"], "giant_roots": ["tree_giant"], "train": ["wagon"], "ice_wall": ["rock_ice"], "crystals": ["rock_ice"]}


def build_features(co):
    ramp_mat = named("ramp_snow", "#f8fbff", 0.5); lip = named("ramp_lip", "#ff3a6e", 0.5)
    metal = named("ramp_metal", "#8a8f99", 0.4, 0.7)
    for f in co.tr["features"]:
        t = f["type"]
        if t == "ramp":
            wedge(co, f"ramp_{int(f['s'])}_{f['lat']}", f["s"], f["lat"], f["w"], f["l"], f["h"], metal if f.get("kind") == "metal" else ramp_mat, lip)
            co.data["features"].append(dict(f, corners=[co.sp(f["s"] + ds, f["lat"] + dl, dh).tolist() for ds, dl, dh in
                                                     [(-f["l"] / 2, -f["w"] / 2, 0), (-f["l"] / 2, f["w"] / 2, 0), (f["l"] / 2, f["w"] / 2, 0), (f["l"] / 2, -f["w"] / 2, 0), (f["l"] / 2, f["w"] / 2, f["h"]), (f["l"] / 2, -f["w"] / 2, f["h"])]]))
        elif t == "split":
            kind = f["kind"]
            col = {"rocks": "#8a8f99", "trees": "#eef4ff", "ice_pillars": "#a8e4ff", "lava_rocks": "#3a2a28", "houses": "#eef4ff", "giant_roots": "#5a3a24",
                   "train": "#6a6f7a", "ice_wall": "#bfeaff", "crystals": "#d8c8ff"}[kind]
            hh = {"ice_wall": 4.0, "train": 1.2, "houses": 1.0}.get(kind, 1.6)
            strip_mesh(co, f"divider_{int(f['s0'])}", f["s0"], f["s1"], 0.0, f["div"], hh, named("divider_" + kind, col, 0.6 if kind not in ("ice_wall", "crystals", "ice_pillars") else 0.1))
            props = DIVIDER_PROPS[kind]
            step = {"houses": 16, "giant_roots": 40, "train": 9, "trees": 7}.get(kind, 6)
            s = f["s0"] + 6
            k = 0
            while s < f["s1"] - 5:
                if kind in ("ice_wall",):
                    pass
                else:
                    add_prop(co, props[k % len(props)], s, 0.0, yaw=(P / 2 if kind == "train" else co.rng.random() * 6.28) if kind not in ("houses", "train") else (P / 2 if kind == "train" else 0.0),
                             scale=(0.6 if kind == "giant_roots" else 1.0), h=hh * 0.8)
                if kind == "crystals":
                    i = co.idx(s)
                    cr = cyl(f"crystal_{int(s)}", 0.9, 4 + (k % 3) * 1.5, material=named("crystal", "#e8c8ff", 0.05, 0.1, "#c08aff", 1.5), verts=6, r2=0.05)
                    co.place(cr, s, (k % 2 - 0.5) * 1.2, 2.5 + (k % 3) * 0.7)
                s += step; k += 1
            co.data["features"].append(dict(f, height=hh))
        elif t == "platform":
            deck = {"roof": "#a0302a", "walkway": "#8a5a32", "metal": "#8a8f99", "cloud": "#ffffff"}[f["kind"]]
            m = named("platform_" + f["kind"], deck, 0.6, 0.6 if f["kind"] == "metal" else 0, "#ffe8ff" if f["kind"] == "cloud" else None, 0.3)
            L = 7.0
            wedge(co, f"plat_in_{int(f['s0'])}", f["s0"] + L / 2, f["lat"], f["w"], L, f["h"], m, lip)
            strip_mesh(co, f"plat_{int(f['s0'])}", f["s0"] + L - 0.3, f["s1"] - L + 0.3, f["lat"], f["w"], f["h"], m, taper=0)
            # exit ramp going down
            a, b = f["s1"] - L, f["s1"]
            v = [g2b(co.sp(a, f["lat"] - f["w"] / 2, f["h"])), g2b(co.sp(a, f["lat"] + f["w"] / 2, f["h"])), g2b(co.sp(b, f["lat"] + f["w"] / 2, -0.05)), g2b(co.sp(b, f["lat"] - f["w"] / 2, -0.05)),
                 g2b(co.sp(a, f["lat"] - f["w"] / 2, -0.05)), g2b(co.sp(a, f["lat"] + f["w"] / 2, -0.05))]
            co.objs.append(mesh_from(f"plat_out_{int(f['s0'])}", v, [(0, 1, 2, 3), (4, 0, 3), (5, 2, 1), (4, 5, 1, 0)], material=m))
            ss = f["s0"] + L
            while ss < f["s1"] - L:
                for dl in (-f["w"] / 2 + 0.4, f["w"] / 2 - 0.4):
                    co.place(cyl(f"pl_leg{int(ss)}{dl}", 0.18, f["h"], material=named("metal_dark", "#555a66", 0.5, 0.8), verts=6), ss, f["lat"] + dl, f["h"] / 2)
                ss += 8
            co.data["features"].append(f)
        elif t == "rail":
            pts = rail_mesh(co, f"rail_{int(f['s'])}_{f['lat']}", f["s"], f["lat"], f["len"], named("rail_metal", "#ff7a3a", 0.3, 0.9))
            co.data["features"].append(dict(f, points=pts))
        elif t == "tunnel":
            i = co.idx((f["s0"] + f["s1"]) / 2)
            if "lat" in f:
                r = 4.0; lat = f["lat"]
            else:
                r = co.cl["width"][i] / 2 + BERM_W; lat = 0.0
            m = named("tunnel_" + f["kind"], {"cave": "#7ab0d0", "narrow": "#a8e4ff", "rail_tunnel": "#6a6f7a"}[f["kind"]], 0.8, 0.0, "#4a90c0" if f["kind"] != "rail_tunnel" else None, 0.15)
            tube(co, f"tunnel_{int(f['s0'])}", f["s0"], f["s1"], lat, r, m)
            co.data["features"].append(f)
        elif t == "zone":
            k = f["kind"]
            if k == "pit":
                s0, s1 = f["s0"], f["s1"]
                v = [g2b(co.sp(s0, f["lat0"], 0.03)), g2b(co.sp(s0, f["lat1"], 0.03)), g2b(co.sp(s1, f["lat1"], 0.03)), g2b(co.sp(s1, f["lat0"], 0.03))]
                co.objs.append(mesh_from(f"pit_{int(s0)}", v, [(0, 1, 2, 3)], material=named("pit_dark", "#0a0608", 0.9, 0, "#ff3a0a", 0.4)))
                for s in (s0 - 3, s1 + 3):
                    for lat in (f["lat0"], f["lat1"]):
                        add_prop(co, "flag_0", s, lat)
                add_prop(co, "sign_caution", s0 - 24, (f["lat0"] + f["lat1"]) / 2 + (6 if f["lat0"] < 0 else -6))
            co.data["features"].append(f)
        elif t == "sign":
            add_prop(co, f["kind"], f["s"], f["lat"])
            co.data["features"].append(f)
        elif t == "hazard":
            p = co.sp(f["s"], f["lat"]).tolist()
            co.data["features"].append(dict(f, pos=p, yaw=-math.radians(co.cl["head"][co.idx(f["s"])]) + (P / 2 if f["kind"] in ("log",) else 0.0)))
        elif t == "landmark":
            LM(co, f)
        else:
            co.data["features"].append(f)


def vegetation(co):
    tr = co.tr
    rng = random.Random(sum(ord(c) for c in co.tid) * 7)
    out = []
    cl = co.cl
    dens = tr["tree_density"]
    s = 10.0
    # stay clear of landmarks and the lift corridor
    lms = [np.array(f["pos"]) for f in co.data["features"] if f["type"] == "landmark"]
    a = co.lift_bottom; b = co.lift_top
    while s < cl["total"] - 10:
        for side in (-1, 1):
            if rng.random() < 0.85 * min(1.0, dens):
                i = co.idx(s)
                d = cl["width"][i] / 2 + BERM_W + 3 + rng.random() * (30 + 50 * dens)
                p = surface_point(cl, i, side * d, 0)
                x, z = p[0], p[2]
                ok = all(np.linalg.norm(np.array([x, z]) - l[[0, 2]]) > 22 for l in lms)
                ab = (b - a)[[0, 2]]; t = np.clip(((np.array([x, z]) - a[[0, 2]]) @ ab) / (ab @ ab), 0, 1)
                if np.linalg.norm(np.array([x, z]) - (a[[0, 2]] + t * ab)) < 18:
                    ok = False
                # also away from any other part of the course
                dmin = np.min(np.linalg.norm(cl["pos"][:, [0, 2]] - np.array([x, z]), axis=1) - cl["width"] / 2)
                if dmin < BERM_W + 2.5:
                    ok = False
                if ok:
                    kind = tr["trees"][rng.randrange(len(tr["trees"]))]
                    if kind == "tree_giant" and rng.random() < 0.6:
                        kind = tr["trees"][1]
                    out.append(dict(kind=kind, pos=[float(x), terrain_h(co, x, z) - 0.2, float(z)], yaw=rng.random() * 6.283, scale=0.8 + rng.random() * 0.5))
        s += 9.0 / max(0.3, dens)
    # bushes/rocks sprinkled near berms
    s = 20.0
    while s < cl["total"]:
        i = co.idx(s); side = rng.choice((-1, 1))
        d = cl["width"][i] / 2 + BERM_W + 1.5 + rng.random() * 6
        p = surface_point(cl, i, side * d, 0)
        dmin = np.min(np.linalg.norm(cl["pos"][:, [0, 2]] - p[[0, 2]], axis=1) - cl["width"] / 2)
        if dmin > BERM_W + 1.0:
            out.append(dict(kind=rng.choice(["bush_0", "bush_1", "bush_2", "rock_grey", "snowbank_0", "snowbank_2"]), pos=[float(p[0]), terrain_h(co, p[0], p[2]) - 0.1, float(p[2])], yaw=rng.random() * 6.283, scale=0.7 + rng.random() * 0.6))
        s += 23.0
    co.data["vegetation"] = out


def course_dressing(co):
    """Signs on corners, fences along the start/finish, flags, lanterns (festival), arches."""
    cl = co.cl
    # arrow signs before strong turns
    last = -100
    for i in range(0, co.n, 5):
        if abs(cl["curv"][i]) > 0.45 and cl["s"][i] - last > 70 and cl["s"][i] > 60:
            s = max(10, cl["s"][i] - 25)
            side = 1 if cl["curv"][i] < 0 else -1  # put sign on the outside
            add_prop(co, "sign_right" if cl["curv"][i] > 0 else "sign_left", s, side * (cl["width"][co.idx(s)] / 2 + BERM_W + 1.5), yaw=0)
            last = cl["s"][i]
    # flags every 50 m alternating sides (visual guidance)
    for k, s in enumerate(np.arange(30, cl["total"] - 40, 50)):
        i = co.idx(s); side = -1 if k % 2 else 1
        add_prop(co, f"flag_{k % 3}", s, side * (cl["width"][i] / 2 + 0.6))
    # fences at start and runout
    for s in np.arange(4, 40, 4.2):
        for side in (-1, 1):
            add_prop(co, "fence_1", s, side * (cl["width"][co.idx(s)] / 2 + BERM_W + 0.5))
    for s in np.arange(cl["total"] - 78, cl["total"] - 2, 4.2):
        for side in (-1, 1):
            add_prop(co, "fence_2", s, side * (cl["width"][co.idx(s)] / 2 + BERM_W + 0.5))
    if co.tr["theme"] in ("night",):
        for k, s in enumerate(np.arange(20, cl["total"], 24)):
            for side in (-1, 1):
                add_prop(co, f"lantern_{(k + (side > 0)) % 4}", s, side * (cl["width"][co.idx(s)] / 2 + BERM_W + 1.0), yaw=(0 if side > 0 else math.pi))
    elif co.tr["theme"] in ("station",):
        for k, s in enumerate(np.arange(40, cl["total"], 60)):
            add_prop(co, "lantern_1", s, (cl["width"][co.idx(s)] / 2 + BERM_W + 1.0))


def export_data(co):
    cl = co.cl
    total = cl["total"]
    samples = []
    for i in range(co.n):
        samples.append(dict(s=float(cl["s"][i]), p=[round(float(v), 3) for v in cl["pos"][i]], r=[round(float(v), 4) for v in cl["right"][i]],
                            f=[round(float(v), 4) for v in cl["fwd"][i]], n=[round(float(v), 4) for v in surface_normal(cl, i)],
                            w=float(cl["width"][i]), b=round(float(cl["bank"][i]), 2), c=round(float(cl["curv"][i]), 4)))
    cps = [float(s) for s in np.arange(0, total - 70, 60)]
    finish_s = total - 72.0
    spawns = []
    for k in range(4):
        lat = (-1 if k % 2 == 0 else 1) * 3.2
        s = 22.0 - (k // 2) * 6.0
        spawns.append(dict(pos=co.sp(s, lat, 0.3).tolist(), s=s, lat=lat))
    i_end = co.n - 1
    co.data.update(dict(
        name=co.tr["name"], name_en=co.tr["name_en"], theme=co.tr["theme"], snow=co.tr["snow"], rock=co.tr["rock"],
        sky=co.tr["sky"], fog=co.tr["fog"], sun=co.tr["sun"], length=total, ds=DS, samples=samples, checkpoints=cps,
        finish_s=finish_s, lift_s=total - 22.0, spawns=spawns,
        lift=dict(bottom=co.lift_bottom.tolist(), top=co.lift_top.tolist(), towers=co.towers, entry=co.sp(total - 20, 0, 0).tolist(),
                  exit=co.sp(10, 0, 0.3).tolist()),
        terrain=co.terrain_grid, berm_w=BERM_W, berm_h=BERM_H))
    os.makedirs(os.path.join(ROOT, "assets", "data", "tracks"), exist_ok=True)
    with open(os.path.join(ROOT, "assets", "data", "tracks", co.tid + ".json"), "w") as fh:
        json.dump(co.data, fh, separators=(",", ":"))


def build(tid):
    reset()
    co = Course(tid)
    cl = co.cl
    co.tr["rock_col"] = {"rock_grey": "#7a7f8c", "rock_volcanic": "#3a2a28", "rock_blue": "#6a7a9a"}[co.tr["rock"]]
    # lift: bottom station after the runout, top station behind the start
    end = cl["pos"][-1] + cl["fwd"][-1] * 14
    start = cl["pos"][0] - cl["fwd"][0] * 26
    co.lift_bottom = end + np.array([0, 7.5, 0]) + cl["right"][-1] * 0
    co.lift_top = start + np.array([0, 7.5, 0])
    co.ribbon(step=1)
    co.ribbon(step=2, collider=True)
    build_terrain(co)
    # lift towers along the cable
    L = np.linalg.norm((co.lift_top - co.lift_bottom)[[0, 2]])
    nt = max(2, int(L / 90))
    co.towers = []
    for k in range(1, nt):
        t = k / nt
        c = co.lift_bottom + (co.lift_top - co.lift_bottom) * t
        gy = terrain_h(co, c[0], c[2])
        co.towers.append(dict(pos=[float(c[0]), float(gy), float(c[2])], cable_y=float(c[1])))
    for e, nm in ((end, "bottom"), (start, "top")):
        gy = e[1] - 0.6
        pad = cyl(f"lift_pad_{nm}", 9, 1.2, material=named("lift_pad", "#d8e0ec", 0.7), verts=20)
        pad.location = g2b((e[0], gy, e[2])); co.objs.append(pad)
    build_features(co)
    course_dressing(co)
    vegetation(co)
    export_data(co)
    save_blend(os.path.join(ROOT, "source_art", "blend", f"track_{tid}.blend"))
    export_glb(os.path.join(ROOT, "assets", "models", "tracks", f"{tid}.glb"))
    print(f"TRACK {tid} len={cl['total']} tris={tri_count()} props={len(co.data['props'])} veg={len(co.data['vegetation'])}")


if __name__ == "__main__":
    for t in (sys.argv[1:] or ORDER):
        build(t)
