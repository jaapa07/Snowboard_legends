#!/usr/bin/env python3
"""Download the CC0 photographic materials and skies used by the game and convert them for runtime use.

Sources (all CC0 1.0, no attribution required; credited in ASSET_LICENSES.md anyway):
  - Poly Haven  (https://polyhaven.com)  textures: diffuse + OpenGL normal + roughness, 1K JPG
                                         skies: "puresky" HDRIs, 2K .hdr, tone-mapped here to 2048x1024 JPG
  - ambientCG   (https://ambientcg.com)  ice texture, 1K JPG

Raw downloads are cached in source_art/cc0/ (re-runs are offline); outputs go to assets/textures/cc0/ and
assets/sky/. Deterministic: same input files -> same outputs. A JSON record with URLs and MD5s is written to
source_art/cc0/sources.json (copied into the asset manifest).

    python3 tools/fetch_cc0.py
"""
import hashlib
import io
import json
import os
import sys
import urllib.request
import zipfile

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "source_art", "cc0")
TEX_OUT = os.path.join(ROOT, "assets", "textures", "cc0")
SKY_OUT = os.path.join(ROOT, "assets", "sky")

# runtime name -> Poly Haven texture id
# Albedos are "neutralised": the photo's mean colour is divided out so the game's stylised palette (the
# material colour authored in Blender) tints the photographic detail. Snow photos carry dirt, so for snow only
# the relief (normal + roughness) is used as-is and the albedo is a softened, desaturated version.
PH_TEXTURES = {
    "snow_groomed": ("snow_02", "snow"),     # packed piste snow
    "snow_powder": ("snow_01", "snow"),      # soft berms, terrain, mountain caps
    "rock_cliff": ("rocks_ground_04", "neutral"),   # grey mountain faces, rock dividers
    "rock_dark": ("dark_rock_02", "neutral"),       # volcanic rock
    "metal_plate": ("metal_plate_02", "neutral"),   # rails, lift, ramps
    "wood_planks": ("brown_planks_03", "neutral"),  # platforms, cabins
}
AC_TEXTURES = {"ice": ("Ice002", "neutral")}

# course theme -> Poly Haven pure-sky HDRI (sky dome only, no ground objects), exposure (stops)
# theme -> (asset, exposure stops, colour grade multiplier). Below the horizon the dome fades to the horizon
# colour (pure-sky HDRIs mirror the sky there, which read as a lake under the mountains).
PH_SKIES = {
    "day": ("kloofendal_48d_partly_cloudy_puresky", -0.3, (1.0, 1.0, 1.0)),
    "forest": ("kloppenheim_06_puresky", 0.0, (1.0, 1.0, 1.0)),
    "ice": ("syferfontein_18d_clear_puresky", 0.0, (0.95, 1.0, 1.05)),
    "volcano": ("belfast_sunset_puresky", -0.4, (1.25, 0.86, 0.68)),
    "night": ("qwantani_night_puresky", -2.6, (0.55, 0.7, 1.35)),
    "sky": ("qwantani_dusk_2_puresky", -0.7, (1.12, 0.86, 1.18)),
    "storm": ("kloofendal_overcast_puresky", 0.0, (0.95, 0.98, 1.04)),
    "station": ("kloofendal_28d_misty_puresky", 0.0, (0.97, 0.99, 1.02)),
}

UA = {"User-Agent": "snowboard-legends-asset-fetch/1.0"}
record = {"polyhaven_textures": {}, "ambientcg_textures": {}, "polyhaven_skies": {}}


def get(url: str) -> bytes:
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read()


def cached(name: str, url: str) -> bytes:
    os.makedirs(RAW, exist_ok=True)
    p = os.path.join(RAW, name)
    if not os.path.exists(p):
        print("  download", url)
        data = get(url)
        with open(p, "wb") as f:
            f.write(data)
    with open(p, "rb") as f:
        return f.read()


def md5(b: bytes) -> str:
    return hashlib.md5(b).hexdigest()


def ph_files(asset: str) -> dict:
    p = os.path.join(RAW, asset + ".files.json")
    if not os.path.exists(p):
        os.makedirs(RAW, exist_ok=True)
        with open(p, "wb") as f:
            f.write(get("https://api.polyhaven.com/files/" + asset))
    with open(p) as f:
        return json.load(f)


def save_jpg(img: Image.Image, path: str, q: int = 90) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, "JPEG", quality=q, subsampling=0 if img.mode == "RGB" else -1)


def fetch_textures() -> None:
    for name, (asset, mode) in PH_TEXTURES.items():
        files = ph_files(asset)
        rec = {"asset": asset, "page": "https://polyhaven.com/a/" + asset, "license": "CC0-1.0", "files": {}}
        for key, suffix in (("Diffuse", "albedo"), ("nor_gl", "normal"), ("Rough", "rough")):
            url = files[key]["1k"]["jpg"]["url"]
            data = cached(os.path.basename(url), url)
            rec["files"][suffix] = {"url": url, "md5": md5(data)}
            img = Image.open(io.BytesIO(data)).convert("RGB" if suffix != "rough" else "L")
            if img.size != (1024, 1024):
                img = img.resize((1024, 1024), Image.LANCZOS)
            if suffix == "albedo":
                img = grade_albedo(img, mode)
            save_jpg(img, os.path.join(TEX_OUT, f"{name}_{suffix}.jpg"))
        rec["albedo_mode"] = mode
        record["polyhaven_textures"][name] = rec
        print("texture", name, "<-", asset)
    for name, (asset, mode) in AC_TEXTURES.items():
        url = f"https://ambientcg.com/get?file={asset}_1K-JPG.zip"
        data = cached(f"{asset}_1K-JPG.zip", url)
        z = zipfile.ZipFile(io.BytesIO(data))
        rec = {"asset": asset, "page": "https://ambientcg.com/view?id=" + asset, "license": "CC0-1.0",
               "files": {"zip": {"url": url, "md5": md5(data)}}}
        for member in z.namelist():
            low = member.lower()
            suffix = "albedo" if low.endswith("_color.jpg") else "normal" if low.endswith("_normalgl.jpg") else \
                "rough" if low.endswith("_roughness.jpg") else None
            if suffix:
                img = Image.open(io.BytesIO(z.read(member))).convert("RGB" if suffix != "rough" else "L")
                if suffix == "albedo":
                    img = grade_albedo(img, mode)
                save_jpg(img, os.path.join(TEX_OUT, f"{name}_{suffix}.jpg"))
        record["ambientcg_textures"][name] = rec
        print("texture", name, "<-", asset)


def grade_albedo(img: Image.Image, mode: str) -> Image.Image:
    a = np.asarray(img).astype(np.float32) / 255.0
    lin = np.power(a, 2.2)
    mean = lin.reshape(-1, 3).mean(0)
    if mode == "snow":
        lum = (lin @ np.array([0.2126, 0.7152, 0.0722], np.float32))
        lum = lum / max(float(lum.mean()), 1e-4)
        lum = 1.0 + (lum - 1.0) * 0.35          # keep 35 % of the photo's tonal variation, drop the dirt colour
        out = np.clip(lum, 0.55, 1.15)[..., None] * np.array([0.86, 0.89, 0.93], np.float32)
    else:
        out = lin / np.maximum(mean, 1e-4) * 0.5  # neutral grey mean (linear 0.5), photo contrast preserved
    out = np.power(np.clip(out, 0, 1), 1 / 2.2)
    return Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGB")


def read_hdr(data: bytes) -> np.ndarray:
    """Minimal Radiance RGBE reader (new-style RLE scanlines, -Y +X), returns float32 HxWx3."""
    i = 0
    width = height = 0
    while True:
        j = data.index(b"\n", i)
        line = data[i:j].decode("ascii", "replace")
        i = j + 1
        if line.startswith("-Y"):
            parts = line.split()
            height, width = int(parts[1]), int(parts[3])
            break
    out = np.zeros((height, width, 4), np.uint8)
    buf = np.frombuffer(data, np.uint8)
    p = i
    for y in range(height):
        if buf[p] != 2 or buf[p + 1] != 2:
            raise ValueError("unsupported HDR scanline encoding")
        p += 4
        for c in range(4):
            x = 0
            row = out[y, :, c]
            while x < width:
                n = int(buf[p]); p += 1
                if n > 128:
                    n -= 128
                    row[x:x + n] = buf[p]; p += 1
                else:
                    row[x:x + n] = buf[p:p + n]; p += n
                x += n
    rgbe = out.astype(np.float32)
    e = out[..., 3].astype(np.int32)
    scale = np.where(e > 0, np.ldexp(1.0, e - 136), 0.0).astype(np.float32)
    return rgbe[..., :3] * scale[..., None]


def tonemap(hdr: np.ndarray, stops: float) -> np.ndarray:
    x = hdr * (2.0 ** stops)
    # ACES fitted (Narkowicz) keeps the sun disc from clipping the whole sky white
    a, b, c, d, e = 2.51, 0.03, 2.43, 0.59, 0.14
    y = np.clip((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0)
    srgb = np.where(y <= 0.0031308, 12.92 * y, 1.055 * np.power(y, 1 / 2.4) - 0.055)
    return (np.clip(srgb, 0, 1) * 255.0 + 0.5).astype(np.uint8)


def fetch_skies() -> None:
    sun_uv = {}
    for theme, (asset, stops, grade) in PH_SKIES.items():
        files = ph_files(asset)
        url = files["hdri"]["2k"]["hdr"]["url"]
        data = cached(os.path.basename(url), url)
        hdr = read_hdr(data) * np.array(grade, np.float32)
        h = hdr.shape[0]
        horizon = np.median(hdr[h // 2 - h // 30:h // 2 - h // 120].reshape(-1, 3), axis=0) * 0.85
        y = np.arange(h, dtype=np.float32)[:, None, None]
        w = np.clip((y - h * 0.5) / (h * 0.06), 0.0, 1.0)   # fade over the first ~11 degrees below the horizon
        hdr = hdr * (1.0 - w) + horizon * w
        lum = hdr[: h // 2].sum(axis=2)
        sy, sx = np.unravel_index(int(np.argmax(lum)), lum.shape)
        sun_uv[theme] = [round(float(sx) / hdr.shape[1], 4), round(float(sy) / h, 4)]
        img = Image.fromarray(tonemap(hdr, stops), "RGB")
        if img.size != (2048, 1024):
            img = img.resize((2048, 1024), Image.LANCZOS)
        save_jpg(img, os.path.join(SKY_OUT, f"sky_{theme}.jpg"), 88)
        record["polyhaven_skies"][theme] = {"asset": asset, "page": "https://polyhaven.com/a/" + asset,
                                            "license": "CC0-1.0", "url": url, "md5": md5(data), "exposure_stops": stops,
                                            "grade": list(grade)}
        print("sky", theme, "<-", asset)
    with open(os.path.join(SKY_OUT, "sky_meta.json"), "w") as f:
        json.dump({"sun_uv": sun_uv}, f, indent=1, sort_keys=True)


def main() -> int:
    fetch_textures()
    fetch_skies()
    with open(os.path.join(RAW, "sources.json"), "w") as f:
        json.dump(record, f, indent=1, sort_keys=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
