"""Motion transfer from Mixamo FBX clips (skeleton-only, 'mixamorig:' names) onto the game's simple rider rig.

The riders keep their own stylised stance (open chest, goofy feet); what is transferred is the *motion* of the
captured clip relative to a reference frame, layered on top of an authored base pose:

    D_ours(t) = E(t) * D_base,     E(t) = M_mix(t) * M_mix(ref)^-1      (world-space rotation deltas)

Mixamo skaters ride regular (left foot forward); the riders ride goofy, so the clip is mirrored across X and
left/right are swapped. Hip translation and the free (pushing) foot are taken relative to the front foot, which
stays planted on the board, so the clip's root motion is removed. Output keys are pose dicts understood by
build_riders.apply_pose (Quaternion values = armature-space relative rotations, "*_loc" = world offsets).

Raw Mixamo files are not redistributed (Adobe's terms allow use inside a game, not standalone redistribution):
they live in source_art/anim_import/ (gitignored). Without them build_riders falls back to the authored clips.
"""
import os
import bpy
from mathutils import Matrix, Quaternion, Vector

S = Matrix.Diagonal((-1.0, 1.0, 1.0))

# ours <- mixamo (after the mirror, mixamo Left becomes our Right)
BONES = {
    "hips": "Hips", "spine": "Spine2", "head": "Head",
    "upperarm.R": "LeftArm", "forearm.R": "LeftForeArm", "hand.R": "LeftHand",
    "upperarm.L": "RightArm", "forearm.L": "RightForeArm", "hand.L": "RightHand",
}
PARENT = {"hips": None, "spine": "hips", "head": "spine", "upperarm.R": "spine", "forearm.R": "upperarm.R",
          "hand.R": "forearm.R", "upperarm.L": "spine", "forearm.L": "upperarm.L", "hand.L": "forearm.L"}
ORDER = list(BONES.keys())


def _mirror_q(q: Quaternion) -> Quaternion:
    return (S @ q.to_matrix() @ S).to_quaternion()


def _mirror_v(v: Vector) -> Vector:
    return Vector((-v.x, v.y, v.z))


def sample(path: str, fps: int = 24):
    """Import the FBX in a scratch scene and return per-frame world rotations / positions (mirrored)."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=path)
    arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
    act = arm.animation_data.action
    f0, f1 = act.frame_range
    src_fps = bpy.context.scene.render.fps / bpy.context.scene.render.fps_base
    n = int(round((f1 - f0) / src_fps * fps))
    frames = []
    sc = bpy.context.scene
    for i in range(n + 1):
        sc.frame_set(int(f0), subframe=0.0)
        f = f0 + i / fps * src_fps
        sc.frame_set(int(f), subframe=f - int(f))
        mw = arm.matrix_world
        rec = {}
        for ours, mix in BONES.items():
            pb = arm.pose.bones["mixamorig:" + mix]
            rec[ours] = _mirror_q((mw @ pb.matrix).to_3x3().normalized().to_quaternion())
        pos = lambda b: _mirror_v(mw @ arm.pose.bones["mixamorig:" + b].head)
        rec["hips_pos"] = pos("Hips")
        rec["front_foot"] = pos("LeftFoot")    # -> our R (front) foot
        rec["back_foot"] = pos("RightFoot")    # -> our L (back) foot
        frames.append(rec)
    return frames


def transfer(frames, base_q: dict, base_hips_loc, ref: int = 0, gain: float = 1.0, leg_scale: float = 1.0,
             move_back_foot: bool = False, loop_blend: int = 0):
    """frames from sample(); base_q = {bone: armature-space relative quaternion of the base pose}.
    Returns [(frame, pose_dict)]."""
    # base armature-space deltas D = D_parent * q
    D_base = {}
    for b in ORDER:
        p = PARENT[b]
        D_base[b] = (D_base[p] if p else Quaternion()) @ base_q.get(b, Quaternion())
    r = frames[ref]
    hip_ref = r["hips_pos"] - r["front_foot"]
    foot_ref = r["back_foot"] - r["front_foot"]
    keys = []
    for i, f in enumerate(frames):
        pose = {}
        D = {}
        for b in ORDER:
            E = f[b] @ r[b].inverted()
            if gain != 1.0:
                E = Quaternion().slerp(E, gain)
            D[b] = E @ D_base[b]
            p = PARENT[b]
            pose[b] = (D[p].inverted() if p else Quaternion()) @ D[b]
        dh = (f["hips_pos"] - f["front_foot"] - hip_ref) * leg_scale * gain
        pose["hips_loc"] = tuple(base_hips_loc[k] + dh[k] for k in range(3))
        if move_back_foot:
            df = (f["back_foot"] - f["front_foot"] - foot_ref) * leg_scale
            pose["ik.L_loc"] = (df.x, df.y, max(df.z, -0.02))
        keys.append((i, pose))
    if loop_blend > 0 and len(keys) > loop_blend * 2:
        first = keys[0][1]
        n = len(keys)
        for j in range(loop_blend):
            idx = n - loop_blend + j
            w = (j + 1) / loop_blend
            keys[idx] = (idx, blend(keys[idx][1], first, w))
    return keys


def blend(a: dict, b: dict, w: float) -> dict:
    out = {}
    for k, va in a.items():
        vb = b.get(k, va)
        if isinstance(va, Quaternion):
            out[k] = va.slerp(vb, w)
        else:
            out[k] = tuple(va[i] * (1 - w) + vb[i] * w for i in range(3))
    return out


def available(root: str, name: str) -> str:
    p = os.path.join(root, "source_art", "anim_import", name)
    return p if os.path.exists(p) else ""


# ---------------------------------------------------------------- full-body clips (dances -> victory)
# Rokoko "HumanIK" exports (Character1_*) and Mixamo (mixamorig:*) share the bone names after the prefix.
# Dances are captured standing, facing the camera; here the absolute pose is transferred (not a delta on an
# authored pose): every bone's world rotation since the capture's rest pose is applied to our bone after
# aligning the rest directions, the facing is turned to the rider's chest direction, feet stay on the board.
DBONES = {"hips": "Hips", "spine": "Spine2", "head": "Head",
          "upperarm.L": "LeftArm", "forearm.L": "LeftForeArm", "hand.L": "LeftHand",
          "upperarm.R": "RightArm", "forearm.R": "RightForeArm", "hand.R": "RightHand"}
DCHILD = {"Hips": "Spine", "Spine2": "Neck", "Head": None, "LeftArm": "LeftForeArm", "LeftForeArm": "LeftHand",
          "LeftHand": "LeftHandMiddle1", "RightArm": "RightForeArm", "RightForeArm": "RightHand",
          "RightHand": "RightHandMiddle1"}


def _prefix(arm) -> str:
    return [b.name for b in arm.data.bones if b.name.endswith("Hips")][0][:-4]


def sample_abs(path: str, fps: int = 24):
    """Whole clip at `fps`: per frame world rotations (relative to the capture rest), hips height and
    hips offset from the feet midpoint; plus the rest bone directions and facing."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=path)
    arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
    pre = _prefix(arm)
    act = arm.animation_data.action
    f0, f1 = act.frame_range
    src = bpy.context.scene.render.fps / bpy.context.scene.render.fps_base
    mw = arm.matrix_world
    rest_q, rest_dir = {}, {}
    for ours, mix in DBONES.items():
        b = arm.data.bones[pre + mix]
        rest_q[ours] = (mw @ b.matrix_local).to_3x3().normalized().to_quaternion()
        ch = DCHILD[mix]
        tail = (mw @ arm.data.bones[pre + ch].head_local) if ch else (mw @ b.tail_local)
        rest_dir[ours] = (tail - mw @ b.head_local).normalized()
    rhip = mw @ arm.data.bones[pre + "RightUpLeg"].head_local - mw @ arm.data.bones[pre + "LeftUpLeg"].head_local
    rhip.z = 0.0
    facing = Vector((0, 0, 1)).cross(rhip.normalized())        # F = U x R
    rest_h = (mw @ arm.data.bones[pre + "Hips"].head_local).z
    n = int((f1 - f0) / src * fps)
    sc = bpy.context.scene
    frames = []
    for i in range(n + 1):
        f = f0 + i / fps * src
        sc.frame_set(int(f), subframe=f - int(f))
        rec = {}
        for ours, mix in DBONES.items():
            q = (mw @ arm.pose.bones[pre + mix].matrix).to_3x3().normalized().to_quaternion()
            rec[ours] = q @ rest_q[ours].inverted()              # world delta since rest
        hp = mw @ arm.pose.bones[pre + "Hips"].head
        feet = (mw @ arm.pose.bones[pre + "LeftFoot"].head + mw @ arm.pose.bones[pre + "RightFoot"].head) / 2
        rec["hips_off"] = Vector((hp.x - feet.x, hp.y - feet.y, hp.z - rest_h))
        frames.append(rec)
    return {"frames": frames, "rest_dir": rest_dir, "facing": facing, "rest_h": rest_h}


def _ang(q: Quaternion) -> float:
    return min(q.angle, 6.283185307 - q.angle)


def pick_window(clip, length=(96, 144), step=6, max_hips=0.8):
    """Most energetic stretch that loops well and keeps the hips roughly facing forward (feet are on a board)."""
    fr = clip["frames"]
    arms = ["upperarm.L", "forearm.L", "upperarm.R", "forearm.R", "spine", "head", "hips"]
    speed = [0.0] + [sum(_ang(fr[i][b] @ fr[i - 1][b].inverted()) for b in arms) for i in range(1, len(fr))]
    best, best_s = None, -1e9
    for L in range(length[0], length[1] + 1, 12):
        for s in range(0, max(1, len(fr) - L), step):
            e = s + L
            if any(_ang(fr[i]["hips"]) > max_hips for i in range(s, e, 3)):
                continue
            energy = sum(speed[s:e]) / L
            seam = sum(_ang(fr[e][b] @ fr[s][b].inverted()) for b in arms)
            score = energy - 0.08 * seam
            if score > best_s:
                best, best_s = (s, e), score
    return best or (0, min(len(fr) - 1, length[0]))


def transfer_abs(clip, window, our_dir: dict, chest_facing: Vector, leg_scale: float, loop_blend: int = 10,
                 hips_clamp: float = 0.1, base_hips_loc=(0, 0, -0.04), z_range=(-0.3, 0.08), speed: float = 1.0,
                 upper_only: bool = False, base_q: dict = None):
    """speed > 1 plays the capture faster (falls are quicker on a board than standing). upper_only keeps the
    hips/legs in the authored base pose (seated captures used for a standing rider)."""
    s, e = window
    fz = clip["facing"]
    Y = fz.rotation_difference(chest_facing)                  # capture facing -> rider chest
    A = {b: our_dir[b].rotation_difference(Y @ clip["rest_dir"][b]) for b in DBONES}
    keys = []
    n_out = int((e - s) / speed)
    for k in range(n_out + 1):
        i = min(e, s + int(round(k * speed)))
        f = clip["frames"][i]
        D, pose = {}, {}
        for b in ORDER:
            if upper_only and b == "hips":
                D[b] = (base_q or {}).get("hips", Quaternion())
            else:
                D[b] = (Y @ f[b] @ Y.inverted()) @ A[b]
            p = PARENT[b]
            pose[b] = (D[p].inverted() if p else Quaternion()) @ D[b]
        if upper_only:
            pose["hips_loc"] = tuple(base_hips_loc)
        else:
            o = Y @ f["hips_off"]
            h = Vector((max(-hips_clamp, min(hips_clamp, o.x)), max(-hips_clamp, min(hips_clamp, o.y)), o.z)) * leg_scale
            pose["hips_loc"] = (base_hips_loc[0] + h.x, base_hips_loc[1] + h.y,
                                base_hips_loc[2] + max(z_range[0], min(z_range[1], h.z)))
        keys.append((k, pose))
    if loop_blend:
        n = len(keys)
        for j in range(loop_blend):
            idx = n - loop_blend + j
            keys[idx] = (idx, blend(keys[idx][1], keys[0][1], (j + 1) / loop_blend))
    return keys
