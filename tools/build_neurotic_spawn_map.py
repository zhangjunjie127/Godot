from pathlib import Path
from shutil import copyfile

from PIL import Image, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
MAP_DIR = ROOT / "assets" / "maps" / "spawn"
GENERATED_SOURCE = MAP_DIR / "spawn_neurotic_wilds_source.png"
FOUNDATION_SOURCE = MAP_DIR / "spawn_reference_foundation_source.png"
OVERVIEW = MAP_DIR / "spawn_reference_foundation_2048.png"
CHUNK_SIZE = 4096


def main() -> None:
    if not GENERATED_SOURCE.exists():
        raise FileNotFoundError(GENERATED_SOURCE)

    copyfile(GENERATED_SOURCE, FOUNDATION_SOURCE)
    with Image.open(GENERATED_SOURCE) as source:
        overview = source.convert("RGB").resize((2048, 2048), Image.Resampling.LANCZOS)
        overview = overview.filter(ImageFilter.UnsharpMask(radius=0.8, percent=70, threshold=3))
        overview.save(OVERVIEW, compress_level=6)

        for row in range(2):
            for column in range(2):
                quadrant = overview.crop(
                    (column * 1024, row * 1024, (column + 1) * 1024, (row + 1) * 1024)
                )
                chunk = quadrant.resize((CHUNK_SIZE, CHUNK_SIZE), Image.Resampling.LANCZOS)
                chunk = chunk.filter(ImageFilter.UnsharpMask(radius=1.2, percent=85, threshold=3))
                chunk.save(
                    MAP_DIR / f"spawn_reference_chunk_{column}_{row}.png",
                    compress_level=6,
                )

    expected = {
        OVERVIEW: (2048, 2048),
        **{
            MAP_DIR / f"spawn_reference_chunk_{column}_{row}.png": (CHUNK_SIZE, CHUNK_SIZE)
            for row in range(2)
            for column in range(2)
        },
    }
    for path, size in expected.items():
        with Image.open(path) as image:
            if image.size != size:
                raise RuntimeError(f"{path.name}: expected {size}, got {image.size}")
        print(f"{path.relative_to(ROOT)} {size[0]}x{size[1]}")


if __name__ == "__main__":
    main()
