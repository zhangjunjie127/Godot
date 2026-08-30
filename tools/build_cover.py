from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/ui/title/cover-background-source.png"
OUTPUT = ROOT / "assets/ui/title/cover-background.png"
SIZE = (1600, 900)


def main():
    image = Image.open(SOURCE).convert("RGB")
    target_ratio = SIZE[0] / SIZE[1]
    if image.width / image.height < target_ratio:
        crop_height = round(image.width / target_ratio)
        top = (image.height - crop_height) // 2
        image = image.crop((0, top, image.width, top + crop_height))
    else:
        crop_width = round(image.height * target_ratio)
        left = (image.width - crop_width) // 2
        image = image.crop((left, 0, left + crop_width, image.height))
    image = image.resize(SIZE, Image.Resampling.LANCZOS)

    image.save(OUTPUT, optimize=True)
    print(OUTPUT)


if __name__ == "__main__":
    main()
