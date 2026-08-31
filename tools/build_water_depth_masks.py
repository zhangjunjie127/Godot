from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter


PROJECT_ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = PROJECT_ROOT / "assets/maps/spawn/spawn_map.json"
OUTPUT_SIZE = 512
EROSION_STEPS = 40


def main() -> None:
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    generated = 0
    for chunk in manifest["chunks"]:
        mask_resource = chunk.get("water", {}).get("image", "")
        if not mask_resource:
            continue
        mask_path = PROJECT_ROOT / mask_resource
        depth_path = mask_path.with_name(mask_path.name.replace("_mask.png", "_depth.png"))
        build_depth_mask(mask_path, depth_path)
        generated += 1
    print(f"Generated {generated} water depth masks at {OUTPUT_SIZE}x{OUTPUT_SIZE}")


def build_depth_mask(mask_path: Path, depth_path: Path) -> None:
    source = Image.open(mask_path).convert("L").resize((OUTPUT_SIZE, OUTPUT_SIZE), Image.Resampling.NEAREST)
    water = np.asarray(source, dtype=np.uint8) >= 128
    depth = np.zeros((OUTPUT_SIZE, OUTPUT_SIZE), dtype=np.uint8)
    depth[water] = 1
    eroded = Image.fromarray((water * 255).astype(np.uint8), mode="L")
    for step in range(1, EROSION_STEPS + 1):
        eroded = eroded.filter(ImageFilter.MinFilter(3))
        remaining = np.asarray(eroded, dtype=np.uint8) >= 128
        depth[remaining] = round(step / EROSION_STEPS * 255)
    Image.fromarray(depth, mode="L").save(depth_path, optimize=True)


if __name__ == "__main__":
    main()
