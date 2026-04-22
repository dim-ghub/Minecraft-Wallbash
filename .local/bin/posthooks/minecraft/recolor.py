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


def recolor_image(job):
    img_path = job["img_path"]
    out_path = job["out_path"]
    base_rgb = job["base_rgb"]
    target_rgb = job["target_rgb"]

    try:
        img = Image.open(img_path).convert("RGBA")
        data = np.array(img)

        rgb = data[:, :, :3].astype(np.int32)
        alpha = data[:, :, 3]

        opaque_mask = alpha > 0

        distances = np.sum(
            (rgb[:, :, None, :] - base_rgb[None, None, :, :]) ** 2, axis=3
        )
        nearest_indices = np.argmin(distances, axis=2)
        rgb = target_rgb[nearest_indices].astype(np.uint8)

        result = np.dstack([rgb, alpha])
        out_img = Image.fromarray(result, "RGBA")

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

    base_rgb = np.array([hex_to_rgb(c) for c in base_palette], dtype=np.int32)
    target_rgb = np.array([hex_to_rgb(c) for c in target_palette], dtype=np.uint8)
    if len(target_rgb) < len(base_rgb):
        reps = (len(base_rgb) + len(target_rgb) - 1) // len(target_rgb)
        target_rgb = np.tile(target_rgb, (reps, 1))[: len(base_rgb)]

    for job in jobs:
        job["base_rgb"] = base_rgb
        job["target_rgb"] = target_rgb

    with ThreadPoolExecutor() as executor:
        executor.map(recolor_image, jobs)


if __name__ == "__main__":
    main()
