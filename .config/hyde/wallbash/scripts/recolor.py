#!/usr/bin/env python3
import sys
import json
import os
import numpy as np
from PIL import Image
from concurrent.futures import ProcessPoolExecutor

def hex_to_rgb(hex_color):
    hex_color = hex_color.lstrip("#")
    return tuple(int(hex_color[i:i+2], 16) for i in (0, 2, 4))

def get_palette_maps(base_palette, target_palette):
    base_rgb = np.array([hex_to_rgb(c) for c in base_palette])
    target_rgb = np.array([hex_to_rgb(c) for c in target_palette])
    if len(target_rgb) < len(base_rgb):
        reps = (len(base_rgb) + len(target_rgb) - 1) // len(target_rgb)
        target_rgb = np.tile(target_rgb, (reps, 1))[:len(base_rgb)]
    return base_rgb, target_rgb

def recolor_image(job):
    img_path = job["img_path"]
    out_path = job["out_path"]
    base_rgb = job["base_rgb"]
    target_rgb = job["target_rgb"]

    try:
        img = Image.open(img_path).convert("RGBA")
        data = np.array(img)

        rgb = data[:, :, :3].reshape(-1, 3)
        alpha = data[:, :, 3].reshape(-1)

        # Mask out fully transparent pixels
        opaque_mask = alpha > 0
        rgb_opaque = rgb[opaque_mask]

        # Compute distances between each pixel and base palette
        distances = np.linalg.norm(rgb_opaque[:, None, :] - base_rgb[None, :, :], axis=2)
        nearest_indices = np.argmin(distances, axis=1)
        rgb[opaque_mask] = target_rgb[nearest_indices]

        # Merge back and reshape
        result = np.concatenate([rgb, alpha[:, None]], axis=1).reshape(data.shape)
        out_img = Image.fromarray(result.astype(np.uint8), "RGBA")

        os.makedirs(os.path.dirname(out_path), exist_ok=True)
        out_img.save(out_path)
    except Exception as e:
        print(f"Failed to process {img_path}: {e}", file=sys.stderr)

def main():
    jobs = json.load(sys.stdin)
    if not jobs:
        sys.exit("No jobs provided.")

    base_palette = jobs[0]["base_palette"]
    target_palette = jobs[0]["target_palette"]
    base_rgb, target_rgb = get_palette_maps(base_palette, target_palette)

    for job in jobs:
        job["base_rgb"] = base_rgb
        job["target_rgb"] = target_rgb

    with ProcessPoolExecutor() as executor:
        executor.map(recolor_image, jobs)

if __name__ == "__main__":
    main()
