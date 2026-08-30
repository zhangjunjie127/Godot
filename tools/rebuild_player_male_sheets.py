from pathlib import Path

from PIL import Image


ACTIONS = (
    "player_male_walk",
    "player_male_run",
    "player_male_attack",
    "player_male_idle_relaxed",
    "player_male_crouch",
    "player_male_prone_idle",
    "player_male_crawl",
    "player_male_jump",
    "player_male_pickup",
    "player_male_torch_hold",
    "player_male_swim",
)
DIRECTIONS = ("s", "se", "e", "ne", "n", "nw", "w", "sw")
CELL_SIZE = 128
FRAME_COUNTS = {
    "player_male_walk": 16,
    "player_male_run": 16,
    "player_male_attack": 16,
    "player_male_idle_relaxed": 16,
    "player_male_jump": 16,
}


def rebuild(action_dir: Path) -> None:
    frame_count = FRAME_COUNTS.get(action_dir.name, 12)
    sheet = Image.new("RGBA", (CELL_SIZE * frame_count, CELL_SIZE * 8), (0, 0, 0, 0))
    for row, direction in enumerate(DIRECTIONS):
        for column in range(frame_count):
            frame_path = action_dir / "_source" / direction / f"{column + 1:02d}.png"
            frame = Image.open(frame_path).convert("RGBA")
            if frame.size != (CELL_SIZE, CELL_SIZE):
                raise ValueError(f"{frame_path} must be 128x128, got {frame.size}")
            sheet.alpha_composite(frame, (column * CELL_SIZE, row * CELL_SIZE))
    output = action_dir / "sheet-transparent.png"
    sheet.save(output)
    print(output)


def main() -> None:
    project = Path(__file__).resolve().parents[1]
    characters = project / "assets" / "characters"
    for action in ACTIONS:
        rebuild(characters / action)


if __name__ == "__main__":
    main()
