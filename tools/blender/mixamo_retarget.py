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
