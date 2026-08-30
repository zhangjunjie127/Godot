import argparse
from collections import deque
from pathlib import Path

from PIL import Image

from rebuild_player_male_sheets import rebuild


ATLAS_FRAME_SIZE = (640, 528)
ATLAS_COLUMNS = 4
ATLAS_ROWS = 3
CELL_SIZE = 128
FEET_BASELINE = 117
DIRECTION_COMPONENTS = {
    "s": 0,
    "se": 6,
    "e": 2,
    "ne": 7,
    "n": 3,
    "nw": 4,
    "w": 1,
    "sw": 5,
}
DIRECTION_HEIGHTS = {
    "s": 101,
    "se": 102,
    "e": 98,
    "ne": 101,
    "n": 100,
    "nw": 101,
    "w": 98,
    "sw": 102,
}


def component_bounds(frame: Image.Image) -> list[tuple[int, int, int, int]]:
    alpha = frame.getchannel("A")
    pixels = alpha.load()
    width, height = frame.size
    visited = bytearray(width * height)
    bounds = []

    for y in range(height):
        for x in range(width):
            index = y * width + x
            if visited[index] or pixels[x, y] <= 8:
                continue
            visited[index] = 1
            queue = deque([(x, y)])
            min_x = max_x = x
            min_y = max_y = y
            area = 0
            while queue:
                current_x, current_y = queue.popleft()
                area += 1
                min_x = min(min_x, current_x)
                max_x = max(max_x, current_x)
                min_y = min(min_y, current_y)
                max_y = max(max_y, current_y)
                for next_x, next_y in (
                    (current_x - 1, current_y),
                    (current_x + 1, current_y),
                    (current_x, current_y - 1),
                    (current_x, current_y + 1),
                ):
                    if not (0 <= next_x < width and 0 <= next_y < height):
                        continue
                    next_index = next_y * width + next_x
                    if visited[next_index] or pixels[next_x, next_y] <= 8:
                        continue
                    visited[next_index] = 1
                    queue.append((next_x, next_y))
            if area > 100:
                bounds.append((min_x, min_y, max_x + 1, max_y + 1))

    bounds.sort(key=lambda rect: (rect[1] >= height // 2, rect[0]))
    if len(bounds) != 8:
        raise ValueError(f"Expected 8 directional sprites, found {len(bounds)}")
    return bounds


def import_idle(sheet_path: Path, project: Path) -> None:
    atlas = Image.open(sheet_path).convert("RGBA")
    expected_size = (
        ATLAS_FRAME_SIZE[0] * ATLAS_COLUMNS,
        ATLAS_FRAME_SIZE[1] * ATLAS_ROWS,
    )
    if atlas.size != expected_size:
        raise ValueError(f"Expected {expected_size} atlas, got {atlas.size}")

    action_dir = project / "assets" / "characters" / "player_male_idle_relaxed"
    source_dir = action_dir / "_source"
    for frame_index in range(12):
        frame_x = frame_index % ATLAS_COLUMNS * ATLAS_FRAME_SIZE[0]
        frame_y = frame_index // ATLAS_COLUMNS * ATLAS_FRAME_SIZE[1]
        frame = atlas.crop(
            (
                frame_x,
                frame_y,
                frame_x + ATLAS_FRAME_SIZE[0],
                frame_y + ATLAS_FRAME_SIZE[1],
            )
        )
        bounds = component_bounds(frame)
        for direction, component_index in DIRECTION_COMPONENTS.items():
            sprite = frame.crop(bounds[component_index])
            target_height = DIRECTION_HEIGHTS[direction]
            target_width = round(sprite.width * target_height / sprite.height)
            sprite = sprite.resize(
                (target_width, target_height), Image.Resampling.LANCZOS
            )
            cell = Image.new("RGBA", (CELL_SIZE, CELL_SIZE), (0, 0, 0, 0))
            cell.alpha_composite(
                sprite,
                ((CELL_SIZE - target_width) // 2, FEET_BASELINE - target_height),
            )
            output = source_dir / direction / f"{frame_index + 1:02d}.png"
            cell.save(output)

    rebuild(action_dir)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Import the authored 12-frame, eight-direction male idle atlas."
    )
    parser.add_argument("sheet", type=Path)
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    import_idle(args.sheet.resolve(), project)


if __name__ == "__main__":
    main()
