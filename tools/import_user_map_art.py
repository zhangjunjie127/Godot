from __future__ import annotations

import argparse
import heapq
import json
import random
import shutil
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter


VEGETATION_CROPS = [
    ("trees", "tree_broadleaf_large", (2, 3, 47, 77)),
    ("trees", "tree_palm_large", (122, 2, 169, 79)),
    ("trees", "tree_palm_small", (198, 28, 226, 79)),
    ("trees", "tree_twisted_small", (318, 26, 357, 79)),
    ("trees", "tree_canopy_large", (2, 78, 47, 133)),
    ("trees", "tree_canopy_medium", (47, 95, 82, 133)),
    ("deadwood", "dead_tree_large", (97, 78, 142, 137)),
    ("deadwood", "dead_tree_medium", (138, 86, 173, 137)),
    ("deadwood", "fallen_log_large", (2, 207, 61, 252)),
    ("deadwood", "fallen_log_medium", (70, 216, 121, 252)),
    ("deadwood", "stump_large", (122, 202, 174, 253)),
    ("deadwood", "stump_small", (176, 215, 203, 253)),
    ("rocks", "spire_large", (199, 79, 244, 138)),
    ("rocks", "spire_medium", (238, 92, 276, 138)),
    ("rocks", "spire_cluster_large", (330, 81, 365, 138)),
    ("rocks", "boulder_large", (2, 130, 43, 170)),
    ("rocks", "boulder_medium", (47, 141, 76, 170)),
    ("plants", "broad_grass_large", (198, 136, 234, 173)),
    ("plants", "blade_grass_large", (291, 135, 337, 173)),
    ("plants", "shrub_large", (2, 169, 43, 206)),
    ("flowers", "flowers_white_large", (109, 166, 151, 205)),
    ("flowers", "flowers_white_medium", (153, 176, 186, 205)),
    ("flowers", "flowers_pink_large", (219, 165, 267, 205)),
    ("flowers", "flowers_pink_medium", (270, 177, 306, 205)),
    ("plants", "cattails_large", (336, 165, 372, 206)),
    ("plants", "spiral_fern_large", (203, 202, 250, 252)),
    ("mushrooms", "mushroom_red_large", (305, 202, 345, 254)),
    ("mushrooms", "mushroom_orange_medium", (344, 213, 373, 253)),
]


def _remove_small_components(alpha: np.ndarray) -> np.ndarray:
    mask = alpha >= 34
    height, width = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    components: list[list[tuple[int, int]]] = []
    for y in range(height):
        for x in range(width):
            if not mask[y, x] or seen[y, x]:
                continue
            stack = [(x, y)]
            seen[y, x] = True
            component: list[tuple[int, int]] = []
            while stack:
                px, py = stack.pop()
                component.append((px, py))
                for nx, ny in ((px - 1, py), (px + 1, py), (px, py - 1), (px, py + 1)):
                    if 0 <= nx < width and 0 <= ny < height and mask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        stack.append((nx, ny))
            components.append(component)
    if not components:
        return alpha
    largest = max(len(component) for component in components)
    kept = np.zeros_like(mask)
    for component in components:
        if len(component) < max(5, int(largest * 0.08)):
            continue
        if max(y for _, y in component) < height * 0.48:
            continue
        for x, y in component:
            kept[y, x] = True
    expanded = Image.fromarray((kept * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))
    return (alpha.astype(np.float32) * (np.asarray(expanded, dtype=np.float32) / 255.0)).astype(np.uint8)


def remove_background(image: Image.Image) -> Image.Image:
    rgb = np.asarray(image.convert("RGB"), dtype=np.float32)
    height, width, _ = rgb.shape
    barrier = np.full((height, width), np.inf, dtype=np.float32)
    queue: list[tuple[float, int, int]] = []
    for corner_x, corner_y in ((0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)):
        for y in range(max(0, corner_y - 2), min(height, corner_y + 3)):
            for x in range(max(0, corner_x - 2), min(width, corner_x + 3)):
                barrier[y, x] = 0.0
                heapq.heappush(queue, (0.0, x, y))
    while queue:
        cost, x, y = heapq.heappop(queue)
        if cost != barrier[y, x]:
            continue
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if not (0 <= nx < width and 0 <= ny < height):
                continue
            step = float(np.linalg.norm(rgb[y, x] - rgb[ny, nx]))
            next_cost = max(cost, step)
            if next_cost < barrier[ny, nx]:
                barrier[ny, nx] = next_cost
                heapq.heappush(queue, (next_cost, nx, ny))
    alpha = np.clip((barrier - 5.0) / 13.0, 0.0, 1.0)
    alpha = (alpha * alpha * (3.0 - 2.0 * alpha) * 255.0).astype(np.uint8)
    alpha = np.asarray(Image.fromarray(alpha).filter(ImageFilter.MedianFilter(3)), dtype=np.uint8)
    alpha = _remove_small_components(alpha)
    rgba = np.dstack((rgb.astype(np.uint8), alpha))
    output = Image.fromarray(rgba, "RGBA")
    bbox = output.getchannel("A").point(lambda value: 255 if value >= 12 else 0).getbbox()
    if bbox is None:
        return output
    left, top, right, bottom = bbox
    return output.crop((max(0, left - 2), max(0, top - 2), min(output.width, right + 2), min(output.height, bottom + 2)))


def extract_vegetation(sheet_path: Path, output_root: Path) -> list[dict]:
    sheet = Image.open(sheet_path).convert("RGB")
    if sheet.size != (392, 255):
        raise ValueError(f"Expected a 392x255 vegetation sheet, got {sheet.size}")
    source_root = output_root / "_source"
    source_root.mkdir(parents=True, exist_ok=True)
    shutil.copy2(sheet_path, source_root / "vegetation_pack.png")
    manifest: list[dict] = []
    for category, name, crop_box in VEGETATION_CROPS:
        destination = output_root / category / f"{name}.png"
        destination.parent.mkdir(parents=True, exist_ok=True)
        asset = remove_background(sheet.crop(crop_box))
        asset.save(destination, optimize=True)
        manifest.append(
            {
                "id": name,
                "category": category,
                "path": destination.relative_to(output_root.parent.parent.parent.parent).as_posix(),
                "sourceCrop": list(crop_box),
                "width": asset.width,
                "height": asset.height,
                "anchor": "bottom_center",
            }
        )
    (source_root / "vegetation_pack_manifest.json").write_text(
        json.dumps({"source": "vegetation_pack.png", "assets": manifest}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    _write_preview(output_root, manifest, source_root / "vegetation_pack_preview.png")
    return manifest


def _write_preview(output_root: Path, manifest: list[dict], destination: Path) -> None:
    columns = 8
    cell_width = 112
    cell_height = 124
    rows = (len(manifest) + columns - 1) // columns
    preview = Image.new("RGB", (columns * cell_width, rows * cell_height), (40, 52, 39))
    draw = ImageDraw.Draw(preview)
    for index, entry in enumerate(manifest):
        row, column = divmod(index, columns)
        path = output_root / entry["category"] / f'{entry["id"]}.png'
        asset = Image.open(path).convert("RGBA")
        scale = min(88 / max(asset.width, 1), 82 / max(asset.height, 1), 2.0)
        shown = asset.resize((max(1, round(asset.width * scale)), max(1, round(asset.height * scale))), Image.Resampling.NEAREST)
        x = column * cell_width + (cell_width - shown.width) // 2
        y = row * cell_height + 5 + 82 - shown.height
        preview.paste(shown, (x, y), shown)
        label = entry["id"].replace("_", " ")
        draw.text((column * cell_width + 4, row * cell_height + 91), label[:18], fill=(235, 238, 216))
    preview.save(destination, optimize=True)


def slice_map(map_path: Path, output_root: Path) -> None:
    image = Image.open(map_path).convert("RGB")
    if image.size != (4096, 4096):
        raise ValueError(f"Expected a 4096x4096 map, got {image.size}")
    output_root.mkdir(parents=True, exist_ok=True)
    for row in range(2):
        for column in range(2):
            chunk = image.crop((column * 2048, row * 2048, (column + 1) * 2048, (row + 1) * 2048))
            chunk.save(output_root / f"spawn_reference_chunk_{column}_{row}.png", optimize=True)
    overview = image.resize((2048, 2048), Image.Resampling.LANCZOS)
    overview.save(output_root / "spawn_reference_foundation_2048.png", optimize=True)


def write_spawn_map(project_root: Path, assets: list[dict]) -> None:
    by_id = {entry["id"]: entry for entry in assets}
    rng = random.Random(20260828)
    zones = [
        (850, 1350, 1700, 1850),
        (1400, 1050, 2650, 1750),
        (2450, 1250, 3500, 2050),
        (950, 2050, 1750, 2850),
        (2450, 2000, 3500, 2950),
        (1050, 2700, 2650, 3300),
    ]
    blocked = [
        (1050, 900, 500),
        (2100, 650, 620),
        (3050, 1050, 540),
        (650, 2200, 480),
        (2050, 2350, 520),
        (2100, 1450, 260),
        (2850, 1600, 280),
        (820, 1850, 340),
        (850, 3300, 430),
        (1430, 2600, 230),
        (2450, 2300, 180),
    ]
    placed: list[tuple[float, float]] = []

    def next_position(spacing: float) -> tuple[int, int]:
        for _ in range(500):
            left, top, right, bottom = rng.choice(zones)
            x = rng.randint(left, right)
            y = rng.randint(top, bottom)
            if any((x - cx) ** 2 + (y - cy) ** 2 < radius**2 for cx, cy, radius in blocked):
                continue
            if any((x - px) ** 2 + (y - py) ** 2 < spacing**2 for px, py in placed):
                continue
            placed.append((x, y))
            return x, y
        raise RuntimeError("Could not place vegetation without overlap")

    prop_counts = {
        "tree_broadleaf_large": 4,
        "tree_palm_large": 4,
        "tree_palm_small": 4,
        "tree_twisted_small": 4,
        "tree_canopy_large": 4,
        "tree_canopy_medium": 4,
        "dead_tree_large": 2,
        "dead_tree_medium": 2,
        "fallen_log_large": 2,
        "fallen_log_medium": 2,
        "stump_large": 2,
        "stump_small": 2,
        "spire_large": 2,
        "spire_medium": 2,
        "spire_cluster_large": 2,
        "boulder_large": 2,
        "boulder_medium": 2,
        "broad_grass_large": 2,
        "blade_grass_large": 2,
        "shrub_large": 3,
        "flowers_white_large": 2,
        "flowers_white_medium": 2,
        "flowers_pink_large": 2,
        "flowers_pink_medium": 2,
        "cattails_large": 2,
        "spiral_fern_large": 2,
        "mushroom_red_large": 2,
        "mushroom_orange_medium": 2,
    }
    props = []
    for asset_id, count in prop_counts.items():
        asset = by_id[asset_id]
        category = asset["category"]
        for index in range(count):
            is_tree = category == "trees"
            spacing = 82.0 if is_tree else 48.0
            x, y = next_position(spacing)
            if is_tree:
                scale = rng.uniform(1.15, 1.50)
            elif category in ("deadwood", "rocks"):
                scale = rng.uniform(1.08, 1.35)
            else:
                scale = rng.uniform(0.95, 1.22)
            width = max(16, round(asset["width"] * scale))
            height = max(16, round(asset["height"] * scale))
            prop = {
                "id": f"new_{asset_id}_{index + 1}",
                "image": asset["path"],
                "x": x,
                "y": y,
                "w": width,
                "h": height,
                "flipH": bool(rng.getrandbits(1)),
            }
            if category in ("trees", "deadwood", "rocks"):
                prop["collision"] = {
                    "type": "circle",
                    "radius": max(7, round(width * (0.15 if is_tree else 0.19))),
                    "offset": [0, -5],
                }
            props.append(prop)

    grass = [
        {"id": "west_grass", "image": by_id["shrub_large"]["path"], "x": 1320, "y": 1720, "w": 112, "h": 86},
        {"id": "north_grass", "image": by_id["broad_grass_large"]["path"], "x": 1730, "y": 1260, "w": 110, "h": 88},
        {"id": "east_grass", "image": by_id["blade_grass_large"]["path"], "x": 3300, "y": 2200, "w": 112, "h": 86},
        {"id": "south_grass", "image": by_id["shrub_large"]["path"], "x": 1900, "y": 3030, "w": 114, "h": 88},
        {"id": "shore_cattails", "image": by_id["cattails_large"]["path"], "x": 3400, "y": 2780, "w": 92, "h": 94},
    ]
    resource_specs = [
        ("resource_oak", "伐木", "wood_oak", "橡木", "tree_broadleaf_large", 2520, 2140, "stone_axe", 3, 3),
        ("resource_pine", "伐木", "wood_pine", "松木", "tree_canopy_medium", 2760, 2260, "stone_axe", 3, 3),
        ("resource_birch", "伐木", "wood_birch", "白桦木", "tree_canopy_large", 3150, 2450, "stone_axe", 3, 3),
        ("resource_palm", "伐木", "wood_palm", "棕榈木", "tree_palm_large", 3350, 2650, "stone_axe", 3, 3),
        ("resource_ancient_wood", "伐木", "wood_ancient", "古木", "tree_twisted_small", 1550, 2860, "stone_axe", 4, 2),
        ("resource_berries", "采集", "fruit_berry", "红浆果", "flowers_pink_large", 2390, 2420, "", 1, 3),
        ("resource_bananas", "采集", "fruit_banana", "香蕉", "tree_palm_small", 2940, 2760, "", 1, 2),
        ("resource_coconut", "采集", "fruit_coconut", "椰子", "tree_palm_large", 3210, 2860, "", 1, 2),
        ("resource_rainforest_fruit", "采集", "fruit_rainforest", "雨林红果", "mushroom_red_large", 1710, 1840, "", 1, 2),
        ("resource_citrus", "采集", "fruit_citrus", "金柑", "flowers_white_large", 1830, 2960, "", 1, 3),
        ("resource_stone", "采石", "stone", "石料", "boulder_large", 2620, 2550, "", 2, 3),
    ]
    resources = []
    for resource_id, action, item_id, name, asset_id, x, y, tool, hits, yield_amount in resource_specs:
        asset = by_id[asset_id]
        scale = 1.25 if asset["category"] == "trees" else 1.15
        entry = {
            "id": resource_id,
            "action": action,
            "resourceId": item_id,
            "name": name,
            "image": asset["path"],
            "x": x,
            "y": y,
            "w": round(asset["width"] * scale),
            "h": round(asset["height"] * scale),
            "radius": 28 if asset["category"] == "trees" else 23,
            "hits": hits,
            "yield": yield_amount,
        }
        if tool:
            entry["requiredTool"] = tool
        resources.append(entry)

    document = {
        "version": 5,
        "source": "desktop-map-import-20260828",
        "vegetationSeed": 20260828,
        "contentScale": 1.0,
        "mapSize": {"width": 4096, "height": 4096},
        "spawn": {"x": 2450, "y": 2300},
        "chunks": [
            {"id": "chunk_0_0", "image": "assets/maps/spawn/spawn_reference_chunk_0_0.png", "position": [0, 0]},
            {"id": "chunk_1_0", "image": "assets/maps/spawn/spawn_reference_chunk_1_0.png", "position": [2048, 0]},
            {"id": "chunk_0_1", "image": "assets/maps/spawn/spawn_reference_chunk_0_1.png", "position": [0, 2048]},
            {"id": "chunk_1_1", "image": "assets/maps/spawn/spawn_reference_chunk_1_1.png", "position": [2048, 2048]},
        ],
        "props": props,
        "grass": grass,
        "resources": resources,
        "zones": [
            {"id": "spawn_zone", "type": "spawn", "x": 2450, "y": 2300, "radius": 100},
            {"id": "west_skull", "type": "landmark", "x": 820, "y": 1850, "radius": 360},
            {"id": "south_stone_circle", "type": "landmark", "x": 850, "y": 3300, "radius": 430},
            {"id": "south_whirlpool", "type": "landmark", "x": 2250, "y": 3650, "radius": 480},
        ],
    }
    (project_root / "assets/maps/spawn/spawn_map.json").write_text(
        json.dumps(document, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--map-source", type=Path, required=True)
    parser.add_argument("--vegetation-sheet", type=Path, required=True)
    parser.add_argument("--project-root", type=Path, required=True)
    args = parser.parse_args()
    slice_map(args.map_source, args.project_root / "assets/maps/spawn")
    manifest = extract_vegetation(args.vegetation_sheet, args.project_root / "assets/maps/props/vegetation")
    write_spawn_map(args.project_root, manifest)
    print(f"Imported 4096x4096 map and {len(manifest)} vegetation assets")


if __name__ == "__main__":
    main()
