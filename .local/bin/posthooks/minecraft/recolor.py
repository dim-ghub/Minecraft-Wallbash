#!/usr/bin/env python3
import sys
import json
import os
import numpy as np
from PIL import Image
from concurrent.futures import ThreadPoolExecutor


def hex_to_rgb(hex_color):
    hex_color = hex_color.lstrip("#")
    return tuple(int(hex_color[i : i + 2], 16) for i in (0, 2, 4))


def build_or_load_lut(base_palette, cache_path):
    try:
        if os.path.exists(cache_path):
            print("Loading cached lookup table...", file=sys.stderr, flush=True)
            return np.load(cache_path)
    except Exception as e:
        print(f"Error loading cache: {e}", file=sys.stderr)

    print("Building lookup table...", file=sys.stderr)
    base_rgb = np.array([hex_to_rgb(c) for c in base_palette], dtype=np.int32)

    r_grid, g_grid, b_grid = np.mgrid[0:256, 0:256, 0:256]
    target = np.stack([r_grid.ravel(), g_grid.ravel(), b_grid.ravel()], axis=1).astype(
        np.int32
    )
    distances = np.sum((target[:, None, :] - base_rgb[None, :, :]) ** 2, axis=2)
    lut = np.argmin(distances, axis=1).reshape(256, 256, 256).astype(np.uint8)

    try:
        os.makedirs(os.path.dirname(cache_path), exist_ok=True)
        np.save(cache_path, lut)
        print("Saved to " + cache_path, file=sys.stderr)
    except Exception as e:
        print(f"Error saving cache: {e}", file=sys.stderr)
    print("Done.", file=sys.stderr)
    return lut


def recolor_image(job):
    img_path = job["img_path"]
    out_path = job["out_path"]
    lut = job["lut"]
    target_rgb = job["target_rgb"]

    try:
        img = Image.open(img_path).convert("RGBA")
        data = np.array(img)

        rgb = data[:, :, :3]
        alpha = data[:, :, 3]

        opaque_mask = alpha > 0
        rgb_opaque = rgb[opaque_mask]

        nearest_indices = lut[rgb_opaque[:, 0], rgb_opaque[:, 1], rgb_opaque[:, 2]]
        rgb[opaque_mask] = target_rgb[nearest_indices]

        result = np.dstack([rgb, alpha])
        out_img = Image.fromarray(result, "RGBA")

        os.makedirs(os.path.dirname(out_path), exist_ok=True)
        out_img.save(out_path)
    except Exception as e:
        print(f"Failed to process {img_path}: {e}", file=sys.stderr)


def main():
    print("Starting recolor.py", flush=True)
    jobs = json.load(sys.stdin)
    if not jobs:
        sys.exit("No jobs provided.")

    base_palette = jobs[0]["base_palette"]
    target_palette = jobs[0]["target_palette"]

    target_rgb = np.array([hex_to_rgb(c) for c in target_palette], dtype=np.uint8)

    base_rgb = np.array([hex_to_rgb(c) for c in base_palette], dtype=np.int32)
    if len(target_rgb) < len(base_rgb):
        reps = (len(base_rgb) + len(target_rgb) - 1) // len(target_rgb)
        target_rgb = np.tile(target_rgb, (reps, 1))[: len(base_rgb)]

    script_path = os.path.realpath(__file__)
    script_dir = os.path.dirname(script_path)
    cache_path = os.path.join(script_dir, "lut.npy")
    print(f"Script dir: {script_dir}, cache: {cache_path}", file=sys.stderr, flush=True)
    lut = build_or_load_lut(base_palette, cache_path)

    for job in jobs:
        job["lut"] = lut
        job["target_rgb"] = target_rgb

    with ThreadPoolExecutor() as executor:
        executor.map(recolor_image, jobs)


if __name__ == "__main__":
    main()
