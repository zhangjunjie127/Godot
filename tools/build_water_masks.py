from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter


PROJECT_ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = PROJECT_ROOT / "assets/maps/spawn/spawn_map.json"


def water_mask(image: Image.Image) -> Image.Image:
    rgb = np.asarray(image.convert("RGB"), dtype=np.float32) / 255.0
    red, green, blue = np.moveaxis(rgb, -1, 0)
    maximum = rgb.max(axis=2)
    minimum = rgb.min(axis=2)
    chroma = maximum - minimum
    saturation = np.divide(chroma, maximum, out=np.zeros_like(maximum), where=maximum > 0.0)

    hue = np.zeros_like(maximum)
    non_gray = chroma > 0.0001
    red_max = non_gray & (maximum == red)
    green_max = non_gray & (maximum == green)
    blue_max = non_gray & (maximum == blue)
    hue[red_max] = np.mod((green[red_max] - blue[red_max]) / chroma[red_max], 6.0)
    hue[green_max] = (blue[green_max] - red[green_max]) / chroma[green_max] + 2.0
    hue[blue_max] = (red[blue_max] - green[blue_max]) / chroma[blue_max] + 4.0
    hue /= 6.0

    blue_water = (
        (hue >= 0.47)
        & (hue <= 0.68)
        & (saturation >= 0.42)
        & (blue >= 0.35)
        & ((blue - red) >= 0.12)
        & (green >= red * 1.02)
    )
    mask = Image.fromarray((blue_water * 255).astype(np.uint8), mode="L")
    return mask.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(1.15))


def padded_chunk(images: dict[tuple[int, int], np.ndarray], position: tuple[int, int], padding: int = 4) -> Image.Image:
    source = images[position]
    height, width = source.shape[:2]
    padded = np.pad(source, ((padding, padding), (padding, padding), (0, 0)), mode="edge")
    for offset_y in (-1, 0, 1):
        for offset_x in (-1, 0, 1):
            neighbor = images.get((position[0] + offset_x * width, position[1] + offset_y * height))
            if neighbor is None:
                continue
            source_x = slice(width - padding, width) if offset_x < 0 else slice(0, padding) if offset_x > 0 else slice(0, width)
            source_y = slice(height - padding, height) if offset_y < 0 else slice(0, padding) if offset_y > 0 else slice(0, height)
            target_x = slice(0, padding) if offset_x < 0 else slice(padding + width, padding * 2 + width) if offset_x > 0 else slice(padding, padding + width)
            target_y = slice(0, padding) if offset_y < 0 else slice(padding + height, padding * 2 + height) if offset_y > 0 else slice(padding, padding + height)
            padded[target_y, target_x] = neighbor[source_y, source_x]
    return Image.fromarray(padded, mode="RGB")


def main() -> None:
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    images = {
        tuple(chunk["position"]): np.asarray(Image.open(PROJECT_ROOT / chunk["image"]).convert("RGB"))
        for chunk in manifest["chunks"]
    }
    generated = 0
    for chunk in manifest["chunks"]:
        source_path = PROJECT_ROOT / chunk["image"]
        mask_path = source_path.with_name(source_path.stem + "_water_mask.png")
        padding = 4
        mask = water_mask(padded_chunk(images, tuple(chunk["position"]), padding)).crop(
            (padding, padding, padding + images[tuple(chunk["position"])].shape[1], padding + images[tuple(chunk["position"])].shape[0])
        )
        mask.save(mask_path, optimize=True)
        depth_path = mask_path.with_name(mask_path.name.replace("_mask.png", "_depth.png"))
        chunk["water"] = {
            "image": mask_path.relative_to(PROJECT_ROOT).as_posix(),
            "depth": depth_path.relative_to(PROJECT_ROOT).as_posix(),
        }
        generated += 1

    manifest.setdefault(
        "waterSurface",
        {
            "enabled": True,
            "flowDirection": [0.94, 0.34],
            "flowSpeed": 22.0,
            "flowStrength": 0.075,
            "causticsScale": 0.018,
            "causticsStrength": 0.12,
            "tint": [0.06, 0.50, 0.66, 1.0],
        },
    )
    MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Generated {generated} water masks")


if __name__ == "__main__":
    main()
