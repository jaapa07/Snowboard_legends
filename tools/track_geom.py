"""Course geometry in Godot coordinates (X right, Y up, -Z forward at start). Pure numpy."""
import math
import numpy as np

DS = 2.0
BERM_W = 6.0      # berm horizontal extent beyond the riding surface
BERM_H = 3.2      # berm height
WALL_H = 7.0      # invisible containment wall above berm


def centreline(tr):
    segs = tr["segments"]
    total = sum(s[0] for s in segs)
    n = int(total / DS) + 1
    pos = np.zeros((n, 3)); head = np.zeros(n); width = np.zeros(n); bank = np.zeros(n); slope = np.zeros(n); curv = np.zeros(n)
    # per-sample parameters with smoothing between segments
    seg_idx = []
    acc = 0
    params = []
    for L, turn, sl, w, bk in segs:
        params.append((acc, acc + L, turn / L, sl, w, bk * (1 if turn >= 0 else -1)))
        acc += L
    def param_at(s):
        for p in params:
            if s <= p[1] or p is params[-1]:
                return p
    h = 0.0
    p = np.array([0.0, 0.0, 0.0])
    raw = []
    for i in range(n):
        s = i * DS
        a0, a1, tr_rate, sl, w, bk = param_at(s)
        raw.append((tr_rate, sl, w, bk))
    raw = np.array(raw)
    # smooth all parameters over +-12 m so transitions are continuous
    k = 7
    ker = np.ones(2 * k + 1) / (2 * k + 1)
    sm = np.stack([np.convolve(np.pad(raw[:, j], k, mode="edge"), ker, mode="valid") for j in range(4)], 1)
    for i in range(n):
        tr_rate, sl, w, bk = sm[i]
        head[i] = h; width[i] = w; bank[i] = bk; slope[i] = sl; curv[i] = tr_rate
        pos[i] = p
        d = np.array([math.sin(math.radians(h)), 0.0, -math.cos(math.radians(h))])
        p = p + d * DS + np.array([0, -math.tan(math.radians(sl)) * DS, 0])
        h += tr_rate * DS
    s_arr = np.arange(n) * DS
    fwd = np.stack([np.sin(np.radians(head)), np.zeros(n), -np.cos(np.radians(head))], 1)
    right = np.stack([np.cos(np.radians(head)), np.zeros(n), np.sin(np.radians(head))], 1)
    return dict(pos=pos, head=head, width=width, bank=bank, slope=slope, curv=curv, s=s_arr, fwd=fwd, right=right, total=total)


def surface_point(cl, i, lat, extra_h=0.0):
    """Point on the riding surface (banked) at sample i, lateral offset lat."""
    b = math.radians(cl["bank"][i])
    r = cl["right"][i]
    up = np.array([0, 1.0, 0])
    # bank raises the outside of the turn: positive bank (right turn) raises the left side (lat < 0)
    return cl["pos"][i] + r * lat * math.cos(b) + up * (-lat * math.sin(b) + extra_h)


def surface_normal(cl, i):
    b = math.radians(cl["bank"][i])
    r = cl["right"][i]; f = cl["fwd"][i]
    sl = math.radians(cl["slope"][i])
    fs = f * math.cos(sl) + np.array([0, -math.sin(sl), 0])
    rs = r * math.cos(b) + np.array([0, -math.sin(b), 0])
    n = np.cross(rs, fs)
    n = n / np.linalg.norm(n)
    if n[1] < 0:
        n = -n
    return n


def cross_profile(hw):
    """Lateral offsets and heights for the riding surface + berms (left -> right)."""
    xs = [-hw - BERM_W, -hw - BERM_W * 0.6, -hw - BERM_W * 0.25, -hw]
    hs = [BERM_H, BERM_H * 0.55, BERM_H * 0.15, 0.0]
    inner = np.linspace(-hw, hw, 9)[1:-1]
    xs += list(inner); hs += [0.0] * len(inner)
    xs += [hw, hw + BERM_W * 0.25, hw + BERM_W * 0.6, hw + BERM_W]
    hs += [0.0, BERM_H * 0.15, BERM_H * 0.55, BERM_H]
    return xs, hs


def check_overlap(cl, margin=26.0):
    p = cl["pos"][:, [0, 2]]
    n = len(p)
    bad = []
    for i in range(0, n, 3):
        d = np.linalg.norm(p - p[i], axis=1)
        far = np.abs(np.arange(n) - i) * DS > 80
        lim = (cl["width"] + cl["width"][i]) / 2 + 2 * BERM_W + margin
        hit = np.where(far & (d < lim))[0]
        if len(hit):
            bad.append((i * DS, int(hit[0]) * DS, float(d[hit[0]])))
    return bad
