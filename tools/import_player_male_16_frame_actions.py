import argparse
from io import BytesIO
from pathlib import Path
import shutil
from zipfile import ZipFile

from PIL import Image

from rebuild_player_male_sheets import rebuild


ACTION_SOURCES = {
    "player_male_idle_relaxed": {
        "folder": "Idle",
        "s": "1788087957640-x81hxkrt4f-godot4.zip",
        "se": "1788087927558-rt8sh6ohq3-godot4.zip",
        "e": "1788087959419-9c5me6xwkb4-godot4.zip",
        "ne": "1788087969057-94tuhfg9uul-godot4.zip",
        "n": "1788088002388-aycviuhan9h-godot4.zip",
    },
    "player_male_jump": {
        "folder": "Jump",
        "s": "1788087593665-shmko7mxgu-godot4.zip",
        "se": "1788086603297-jbx1wlu900r-godot4.zip",
        "e": "1788086809834-33fsmhrmffq-godot4.zip",
        "ne": "1788086851501-6oaznob375s-godot4.zip",
        "n": "1788087627532-5i9xzjwvq93-godot4.zip",
    },
    "player_male_run": {
        "folder": "Run",
        "s": "1788088840793-258igwlbtyrj-godot4.zip",
        "se": "1788088561537-gdihu4qca4i-godot4.zip",
        "e": "1788088807557-o1ceb06raa8-godot4.zip",
        "ne": "1788088850987-9zjsg6p395g-godot4.zip",
        "n": "1788088824409-9sj8v69ablj-godot4.zip",
    },
    "player_male_walk": {
        "folder": "Walk",
        "s": "1788089141196-9hjm5hjpxyg-godot4.zip",
        "se": "1788089060620-3j39wncskfh-godot4.zip",
        "e": "1788089081212-o4fycbw6kuq-godot4.zip",
        "ne": "1788089095330-xf41prevspi-godot4.zip",
        "n": "1788089102262-3t39okxicw4-godot4.zip",
    },
    "player_male_attack": {
        "folder": "Attack",
        "s": "1788089857221-8o34dybqmyk-godot4.zip",
        "se": "1788089695977-xokj2b19gp-godot4.zip",
        "e": "1788090136319-esza8py6qo-godot4.zip",
        "ne": "1788090049684-isfedh68ene-godot4.zip",
        "n": "1788089876280-ip60k4das28-godot4.zip",
    },
}
MIRRORED_DIRECTIONS = {"nw": "ne", "w": "e", "sw": "se"}
SOURCE_FRAME_SIZE = 640
TARGET_FRAME_SIZE = 128
TARGET_FEET_BASELINE = 117
SOURCE_SCALE = 0.25
FRAME_COUNT = 16


def read_frames(zip_path: Path) -> list[Image.Image]:
    with ZipFile(zip_path) as archive:
        names = [name for name in archive.namelist() if name.endswith("_spritesheet.png")]
        if len(names) != 1:
            raise ValueError(f"{zip_path} must contain one spritesheet")
        sheet = Image.open(BytesIO(archive.read(names[0]))).convert("RGBA")
    expected_size = SOURCE_FRAME_SIZE * 4
    if sheet.size != (expected_size, expected_size):
        raise ValueError(f"{zip_path} must be {expected_size}x{expected_size}, got {sheet.size}")
    return [
        sheet.crop(
            (
                (index % 4) * SOURCE_FRAME_SIZE,
                (index // 4) * SOURCE_FRAME_SIZE,
                (index % 4 + 1) * SOURCE_FRAME_SIZE,
                (index // 4 + 1) * SOURCE_FRAME_SIZE,
            )
        )
        for index in range(FRAME_COUNT)
    ]


def normalize_frame(frame: Image.Image) -> Image.Image:
    scaled_size = round(SOURCE_FRAME_SIZE * SOURCE_SCALE)
    resized = frame.resize((scaled_size, scaled_size), Image.Resampling.LANCZOS)
    bounds = resized.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError("Animation frame is empty")
    canvas = Image.new("RGBA", (TARGET_FRAME_SIZE, TARGET_FRAME_SIZE), (0, 0, 0, 0))
    x = round((TARGET_FRAME_SIZE - scaled_size) * 0.5)
    y = TARGET_FEET_BASELINE - bounds[3]
    canvas.paste(resized, (x, y))
    if canvas.getchannel("A").getbbox() is None:
        raise ValueError("Normalized animation frame is empty")
    return canvas


def write_source_frames(action_dir: Path, frames_by_direction: dict[str, list[Image.Image]]) -> None:
    source_dir = action_dir / "_source"
    source_dir.mkdir(parents=True, exist_ok=True)
    (source_dir / ".gdignore").write_text(
        "Editable source frames. Godot imports only ../sheet-transparent.png.\n",
        encoding="ascii",
    )
    (source_dir / "README.md").write_text(
        "# Male character source frames\n\n"
        "Each direction contains 16 transparent 128x128 PNG frames.\n"
        "Edit the numbered frames, then run `tools/rebuild_player_male_sheets.py`.\n"
        "Runtime row order: S, SE, E, NE, N, NW, W, SW.\n"
        "Frames were imported from the 16-frame Godot exports on 2026-08-30.\n"
        "Keep visible feet on pixel row 117.\n",
        encoding="ascii",
    )
    for direction, frames in frames_by_direction.items():
        direction_dir = source_dir / direction
        if direction_dir.exists():
            shutil.rmtree(direction_dir)
        direction_dir.mkdir(parents=True)
        for index, frame in enumerate(frames, 1):
            frame.save(direction_dir / f"{index:02d}.png")


def import_action(download_root: Path, characters_root: Path, action: str, sources: dict[str, str]) -> None:
    folder = sources["folder"]
    frames_by_direction = {
        direction: [normalize_frame(frame) for frame in read_frames(download_root / folder / zip_name)]
        for direction, zip_name in sources.items()
        if direction != "folder"
    }
    for direction, source_direction in MIRRORED_DIRECTIONS.items():
        frames_by_direction[direction] = [
            frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            for frame in frames_by_direction[source_direction]
        ]
    action_dir = characters_root / action
    write_source_frames(action_dir, frames_by_direction)
    rebuild(action_dir)


def main() -> None:
    parser = argparse.ArgumentParser(description="Import the 16-frame, eight-direction male action exports.")
    parser.add_argument("download_root", type=Path)
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    characters = project / "assets" / "characters"
    for action, sources in ACTION_SOURCES.items():
        import_action(args.download_root, characters, action, sources)


if __name__ == "__main__":
    main()
