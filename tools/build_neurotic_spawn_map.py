from pathlib import Path
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
MAP_DIR = ROOT / "assets" / "maps" / "spawn"
SOURCE = MAP_DIR / "source" / "tropical_island_source.png"
OVERVIEW = MAP_DIR / "spawn_reference_foundation_2048.png"
MAP_SIZE = 8192
CHUNK_SIZE = 2048
GRID_SIZE = MAP_SIZE // CHUNK_SIZE


def main() -> None:
    if not SOURCE.exists():
        raise FileNotFoundError(SOURCE)

    with Image.open(SOURCE) as source:
        if source.size != (MAP_SIZE, MAP_SIZE):
            raise RuntimeError(f"{SOURCE.name}: expected {MAP_SIZE}x{MAP_SIZE}, got {source.size}")

        overview = source.resize((2048, 2048), Image.Resampling.LANCZOS)
        overview.save(OVERVIEW, compress_level=6)

        for row in range(GRID_SIZE):
            for column in range(GRID_SIZE):
                chunk = source.crop(
                    (
                        column * CHUNK_SIZE,
                        row * CHUNK_SIZE,
                        (column + 1) * CHUNK_SIZE,
                        (row + 1) * CHUNK_SIZE,
                    )
                )
                chunk.save(
                    MAP_DIR / f"spawn_reference_chunk_{column}_{row}.png",
                    compress_level=6,
                )

    expected = {
        OVERVIEW: (2048, 2048),
        **{
            MAP_DIR / f"spawn_reference_chunk_{column}_{row}.png": (CHUNK_SIZE, CHUNK_SIZE)
            for row in range(GRID_SIZE)
            for column in range(GRID_SIZE)
        },
    }
    for path, size in expected.items():
        with Image.open(path) as image:
            if image.size != size:
                raise RuntimeError(f"{path.name}: expected {size}, got {image.size}")
        print(f"{path.relative_to(ROOT)} {size[0]}x{size[1]}")


if __name__ == "__main__":
    main()
