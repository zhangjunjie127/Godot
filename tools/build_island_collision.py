from __future__ import annotations

import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
MAP_DIR = ROOT / "assets" / "maps" / "spawn"
OVERVIEW_PATH = MAP_DIR / "spawn_reference_foundation_2048.png"
MANIFEST_PATH = MAP_DIR / "spawn_map.json"
SCENE_PATH = ROOT / "land_collision.tscn"
OUTPUT_DIR = ROOT / "tests" / "output"
PREVIEW_SCALE = 4
SPAWN = (6500, 2500)
BEACH_ENTRY_RECT = (6200, 1600, 7350, 3050)
MIN_COMPONENT_AREA = 350

WATERFALL_BLOCKERS = {
    "WestUpperFalls": (1770, 2220, 360, 380),
    "WestLowerFalls": (1710, 4750, 430, 560),
    "CentralFalls": (3140, 4930, 500, 500),
    "EastFalls": (5700, 4900, 520, 590),
}


def load_water_overview() -> np.ndarray:
    water = Image.new("L", (2048, 2048))
    for row in range(4):
        for column in range(4):
            path = MAP_DIR / f"spawn_reference_chunk_{column}_{row}_water_mask.png"
            chunk = Image.open(path).convert("L").resize((512, 512), Image.Resampling.LANCZOS)
            water.paste(chunk, (column * 512, row * 512))
    return np.asarray(water, dtype=np.uint8)


def build_obstacle_mask(image: np.ndarray, water: np.ndarray) -> np.ndarray:
    hsv = cv2.cvtColor(image, cv2.COLOR_RGB2HSV).astype(np.float32)
    hue = hsv[:, :, 0] / 179.0
    saturation = hsv[:, :, 1] / 255.0
    value = hsv[:, :, 2] / 255.0
    red, green, blue = np.moveaxis(image.astype(np.float32) / 255.0, -1, 0)

    water_margin = cv2.dilate((water >= 96).astype(np.uint8), np.ones((11, 11), np.uint8)) > 0
    grass = (
        (green > red * 1.02)
        & (green > blue * 1.18)
        & (hue >= 0.16)
        & (hue <= 0.46)
        & (saturation >= 0.24)
    )
    sand = (
        (red > blue * 1.22)
        & (green > blue * 1.12)
        & (hue >= 0.07)
        & (hue <= 0.20)
        & (saturation >= 0.22)
    )
    neutral_rock = (saturation <= 0.40) & (value >= 0.25) & (value <= 0.88)
    dark_cliff = (
        (value < 0.62)
        & (saturation < 0.52)
        & (green >= red * 0.78)
        & (blue >= red * 0.68)
    )
    mask = (neutral_rock | dark_cliff) & ~water_margin & ~grass & ~sand
    mask = cv2.morphologyEx(mask.astype(np.uint8) * 255, cv2.MORPH_CLOSE, np.ones((11, 11), np.uint8))
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, np.ones((5, 5), np.uint8))
    mask = cv2.dilate(mask, np.ones((9, 9), np.uint8))

    count, labels, stats, _centroids = cv2.connectedComponentsWithStats(mask)
    cleaned = np.zeros_like(mask)
    for label in range(1, count):
        if stats[label, cv2.CC_STAT_AREA] >= MIN_COMPONENT_AREA:
            cleaned[labels == label] = 255

    left, top, right, bottom = (value // PREVIEW_SCALE for value in BEACH_ENTRY_RECT)
    cleaned[top:bottom, left:right] = 0
    spawn_x, spawn_y = (value // PREVIEW_SCALE for value in SPAWN)
    cv2.circle(cleaned, (spawn_x, spawn_y), 48, 0, -1)
    return cleaned


def contour_polygons(mask: np.ndarray) -> list[list[tuple[int, int]]]:
    contours, _hierarchy = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    polygons: list[list[tuple[int, int]]] = []
    for contour in contours:
        if cv2.contourArea(contour) < MIN_COMPONENT_AREA:
            continue
        perimeter = cv2.arcLength(contour, True)
        approximate = cv2.approxPolyDP(contour, 0.008 * perimeter, True)
        points = [(int(point[0][0]) * PREVIEW_SCALE, int(point[0][1]) * PREVIEW_SCALE) for point in approximate]
        if len(points) < 3:
            continue
        if signed_area(points) < 0.0:
            points.reverse()
        polygons.append(points)
    polygons.sort(key=lambda points: abs(signed_area(points)), reverse=True)
    return polygons


def signed_area(points: list[tuple[int, int]]) -> float:
    return sum(
        x1 * y2 - x2 * y1
        for (x1, y1), (x2, y2) in zip(points, points[1:] + points[:1])
    ) * 0.5


def rectangle_polygon(rectangle: tuple[int, int, int, int]) -> list[tuple[int, int]]:
    x, y, width, height = rectangle
    return [(x, y), (x + width, y), (x + width, y + height), (x, y + height)]


def packed_vector(points: list[tuple[int, int]]) -> str:
    return ", ".join(f"{x}, {y}" for x, y in points)


def write_collision_scene(polygons: list[list[tuple[int, int]]]) -> None:
    lines = [
        '[gd_scene format=3 uid="uid://d08jw460pq4r6"]',
        "",
        '[ext_resource type="Script" path="res://scripts/land_collision_editor.gd" id="1_collision_editor"]',
        '[ext_resource type="Texture2D" path="res://assets/maps/spawn/spawn_reference_foundation_2048.png" id="2_map_preview"]',
        "",
        '[node name="Collision" type="Node2D"]',
        'script = ExtResource("1_collision_editor")',
        "",
        '[node name="MapPreview" type="Sprite2D" parent="."]',
        "z_index = -100",
        "texture_filter = 2",
        "scale = Vector2(4, 4)",
        'texture = ExtResource("2_map_preview")',
        "centered = false",
        "",
        '[node name="TerrainBlockers" type="StaticBody2D" parent="."]',
        "collision_layer = 2",
        "collision_mask = 0",
    ]
    for index, points in enumerate(polygons, start=1):
        lines.extend(
            [
                "",
                f'[node name="Terrain{index:03d}" type="CollisionPolygon2D" parent="TerrainBlockers"]',
                f"polygon = PackedVector2Array({packed_vector(points)})",
            ]
        )
    for name, rectangle in WATERFALL_BLOCKERS.items():
        lines.extend(
            [
                "",
                f'[node name="{name}" type="CollisionPolygon2D" parent="TerrainBlockers"]',
                f"polygon = PackedVector2Array({packed_vector(rectangle_polygon(rectangle))})",
            ]
        )
    SCENE_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")


def update_manifest() -> None:
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    manifest["version"] = 9
    manifest["source"] = "user-supplied-island-20260903"
    manifest["spawn"] = {"x": SPAWN[0], "y": SPAWN[1]}
    zones = manifest.get("zones", [])
    spawn_zone = next((zone for zone in zones if zone.get("type") == "spawn"), None)
    if spawn_zone is None:
        zones.insert(0, {"id": "spawn_zone", "type": "spawn", "radius": 120})
        spawn_zone = zones[0]
    spawn_zone.update({"x": SPAWN[0], "y": SPAWN[1]})
    manifest["zones"] = zones
    MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def write_preview(image: np.ndarray, mask: np.ndarray, polygons: list[list[tuple[int, int]]]) -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    overlay = image.copy()
    tint = np.zeros_like(image)
    tint[mask > 0] = (255, 40, 30)
    overlay = cv2.addWeighted(overlay, 1.0, tint, 0.48, 0.0)
    for points in polygons:
        contour = np.asarray([(x // PREVIEW_SCALE, y // PREVIEW_SCALE) for x, y in points], dtype=np.int32)
        cv2.polylines(overlay, [contour], True, (255, 0, 0), 3)
    for rectangle in WATERFALL_BLOCKERS.values():
        points = np.asarray(
            [(x // PREVIEW_SCALE, y // PREVIEW_SCALE) for x, y in rectangle_polygon(rectangle)],
            dtype=np.int32,
        )
        cv2.polylines(overlay, [points], True, (255, 120, 0), 3)
    cv2.circle(overlay, (SPAWN[0] // PREVIEW_SCALE, SPAWN[1] // PREVIEW_SCALE), 16, (30, 30, 255), -1)
    Image.fromarray(mask).save(OUTPUT_DIR / "new_map_obstacle_mask.png")
    Image.fromarray(overlay).save(OUTPUT_DIR / "new_map_collision_overlay.png")


def main() -> None:
    image = np.asarray(Image.open(OVERVIEW_PATH).convert("RGB"))
    water = load_water_overview()
    mask = build_obstacle_mask(image, water)
    polygons = contour_polygons(mask)
    write_collision_scene(polygons)
    update_manifest()
    write_preview(image, mask, polygons)
    print(f"Generated {len(polygons)} terrain polygons and {len(WATERFALL_BLOCKERS)} waterfall blockers")
    print(f"Spawn set to beach position {SPAWN[0]},{SPAWN[1]}")


if __name__ == "__main__":
    main()
