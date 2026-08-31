from __future__ import annotations

import argparse
import json
import shutil
from collections import Counter
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageOps


ALPHA_THRESHOLD = 64
MIN_COMPONENT_AREA = 500
COMPONENT_PADDING = 28


def _color_ratios(rgba: np.ndarray, component_mask: np.ndarray) -> tuple[float, float, float]:
    pixels = rgba[:, :, :3][component_mask]
    if len(pixels) == 0:
        return 0.0, 0.0, 0.0
    rgb = pixels.astype(np.float32) / 255.0
    hsv = cv2.cvtColor(rgb.reshape(-1, 1, 3), cv2.COLOR_RGB2HSV).reshape(-1, 3)
    red_or_orange = ((rgb[:, 0] > 0.62) & (rgb[:, 0] > rgb[:, 1] * 1.12) & (rgb[:, 2] < 0.62))
    pink = ((rgb[:, 0] > 0.62) & (rgb[:, 2] > 0.42) & (rgb[:, 0] > rgb[:, 1] * 1.08))
    white = ((hsv[:, 1] < 0.22) & (hsv[:, 2] > 0.73))
    colorful = float(np.mean(red_or_orange | pink | white))
    brown = float(np.mean((rgb[:, 0] > rgb[:, 1] * 1.08) & (rgb[:, 1] > rgb[:, 2] * 1.12)))
    gray = float(np.mean((hsv[:, 1] < 0.28) & (hsv[:, 2] > 0.32)))
    return colorful, brown, gray


def _classify(
    sheet_width: int,
    sheet_height: int,
    box: tuple[int, int, int, int],
    colorful: float,
    brown: float,
    gray: float,
) -> str:
    x, y, width, height = box
    cx = (x + width / 2) / sheet_width
    cy = (y + height / 2) / sheet_height
    aspect = width / max(height, 1)

    if cy < 0.245:
        return "palms" if brown > 0.025 and height > 420 else "tropical_plants"

    if cy < 0.50:
        if cx > 0.83 and aspect < 0.9:
            return "vines"
        if height > 650 and brown > 0.025:
            return "trees"
        if colorful > 0.04:
            return "flowering_plants"
        if height > 420:
            return "tropical_plants"
        return "foliage"

    if cy < 0.73:
        if cx > 0.72 and brown > 0.20 and height > 340:
            return "deadwood"
        if gray > 0.05 and cy > 0.68:
            return "rocks"
        if colorful > 0.08:
            return "flowering_plants"
        if height < 300 or aspect > 1.8:
            return "grasses"
        return "foliage"

    if gray > 0.05:
        return "rocks"
    if aspect > 1.45:
        return "groundcover"
    return "grasses"


NAME_PREFIXES = {
    "deadwood": "deadwood",
    "flowering_plants": "flowering_plant",
    "foliage": "foliage",
    "grasses": "grass_clump",
    "groundcover": "ground_patch",
    "palms": "palm_tree",
    "rocks": "rock",
    "trees": "tree",
    "tropical_plants": "tropical_plant",
    "vines": "vine",
}


def _write_contact_sheet(output_root: Path, entries: list[dict], destination: Path, title: str) -> None:
    columns = 6
    cell_width = 220
    cell_height = 210
    header_height = 42
    rows = (len(entries) + columns - 1) // columns
    preview = Image.new("RGB", (columns * cell_width, header_height + rows * cell_height), (36, 43, 38))
    draw = ImageDraw.Draw(preview)
    draw.text((14, 12), f"{title} ({len(entries)})", fill=(238, 242, 229))

    for index, entry in enumerate(entries):
        row, column = divmod(index, columns)
        path = output_root / entry["path"]
        asset = Image.open(path).convert("RGBA")
        scale = min(188 / max(asset.width, 1), 160 / max(asset.height, 1), 1.0)
        shown = asset.resize(
            (max(1, round(asset.width * scale)), max(1, round(asset.height * scale))),
            Image.Resampling.LANCZOS,
        )
        x = column * cell_width + (cell_width - shown.width) // 2
        y = header_height + row * cell_height + 5 + 160 - shown.height
        preview.paste(shown, (x, y), shown)
        draw.text(
            (column * cell_width + 8, header_height + row * cell_height + 171),
            entry["id"],
            fill=(229, 234, 218),
        )

    destination.parent.mkdir(parents=True, exist_ok=True)
    preview.save(destination, optimize=True)


def split_sheet(source: Path, output_root: Path) -> list[dict]:
    sheet = Image.open(source).convert("RGBA")
    rgba = np.asarray(sheet)
    alpha = rgba[:, :, 3]
    count, labels, stats, _ = cv2.connectedComponentsWithStats(
        (alpha > ALPHA_THRESHOLD).astype(np.uint8), connectivity=8
    )
    components = [index for index in range(1, count) if stats[index, cv2.CC_STAT_AREA] >= MIN_COMPONENT_AREA]
    components.sort(key=lambda index: (stats[index, cv2.CC_STAT_TOP], stats[index, cv2.CC_STAT_LEFT]))
    if len(components) < 150:
        raise RuntimeError(f"Only detected {len(components)} assets; expected a densely packed sheet")

    output_root.mkdir(parents=True, exist_ok=True)
    source_root = output_root / "_source"
    source_root.mkdir(parents=True, exist_ok=True)
    (source_root / ".gdignore").touch()
    shutil.copy2(source, source_root / "vegetation_master.png")

    category_counts: Counter[str] = Counter()
    entries: list[dict] = []
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (COMPONENT_PADDING * 2 + 1,) * 2)

    for component_index in components:
        x, y, width, height, area = map(int, stats[component_index])
        left = max(0, x - COMPONENT_PADDING)
        top = max(0, y - COMPONENT_PADDING)
        right = min(sheet.width, x + width + COMPONENT_PADDING)
        bottom = min(sheet.height, y + height + COMPONENT_PADDING)
        local_rgba = rgba[top:bottom, left:right].copy()
        component_mask = labels[top:bottom, left:right] == component_index
        colorful, brown, gray = _color_ratios(local_rgba, component_mask)
        category = _classify(sheet.width, sheet.height, (x, y, width, height), colorful, brown, gray)
        category_counts[category] += 1
        asset_id = f"{NAME_PREFIXES[category]}_{category_counts[category]:03d}"

        expanded = cv2.dilate(component_mask.astype(np.uint8), kernel, iterations=1).astype(bool)
        local_rgba[:, :, 3] = np.where(expanded, local_rgba[:, :, 3], 0)
        isolated_image = Image.fromarray(local_rgba, "RGBA")
        local_box = isolated_image.getchannel("A").point(lambda value: 255 if value > 1 else 0).getbbox()
        if local_box is None:
            continue
        margin = 4
        local_box = (
            max(0, local_box[0] - margin),
            max(0, local_box[1] - margin),
            min(isolated_image.width, local_box[2] + margin),
            min(isolated_image.height, local_box[3] + margin),
        )
        crop_box = [left + local_box[0], top + local_box[1], left + local_box[2], top + local_box[3]]
        asset = ImageOps.expand(isolated_image.crop(local_box), border=8, fill=(0, 0, 0, 0))
        destination = output_root / category / f"{asset_id}.png"
        destination.parent.mkdir(parents=True, exist_ok=True)
        asset.save(destination, optimize=True)
        entries.append(
            {
                "id": asset_id,
                "category": category,
                "path": destination.relative_to(output_root).as_posix(),
                "source_crop": crop_box,
                "source_component_area": area,
                "width": asset.width,
                "height": asset.height,
                "anchor": "bottom_center",
                "features": {
                    "colorful_ratio": round(colorful, 5),
                    "brown_ratio": round(brown, 5),
                    "gray_ratio": round(gray, 5),
                },
            }
        )

    manifest = {
        "source": "vegetation_master.png",
        "source_size": [sheet.width, sheet.height],
        "asset_count": len(entries),
        "categories": dict(sorted(category_counts.items())),
        "assets": entries,
    }
    (source_root / "split_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    _write_contact_sheet(output_root, entries, source_root / "all_assets_preview.png", "All vegetation assets")
    for category in sorted(category_counts):
        category_entries = [entry for entry in entries if entry["category"] == category]
        _write_contact_sheet(
            output_root,
            category_entries,
            source_root / "category_previews" / f"{category}.png",
            category,
        )
    print(json.dumps(manifest["categories"], ensure_ascii=False))
    print(f"Split {len(entries)} assets into {output_root}")
    return entries


def main() -> None:
    parser = argparse.ArgumentParser(description="Split an RGBA vegetation sheet into categorized transparent PNGs")
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    split_sheet(args.source, args.output)


if __name__ == "__main__":
    main()
