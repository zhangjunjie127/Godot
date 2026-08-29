from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/ui/title/cover-background-source.png"
OUTPUT = ROOT / "assets/ui/title/cover-background.png"
FONT = Path(r"C:\Windows\Fonts\NotoSansSC-VF.ttf")
SIZE = (1536, 864)


def draw_spaced_text(draw, position, text, font, fill, spacing):
    x, y = position
    for character in text:
        draw.text((x, y), character, font=font, fill=fill)
        x += draw.textlength(character, font=font) + spacing


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

    draw = ImageDraw.Draw(image)
    chinese = ImageFont.truetype(str(FONT), 116)
    english = ImageFont.truetype(str(FONT), 38)
    x, y = 92, 62
    bone = (244, 240, 218)
    brass = (209, 164, 72)
    charcoal = (8, 21, 27)

    draw.text((x + 6, y + 7), "我要上天", font=chinese, fill=charcoal, stroke_width=5, stroke_fill=charcoal)
    draw.text((x, y), "我要上天", font=chinese, fill=bone, stroke_width=3, stroke_fill=charcoal)
    draw_spaced_text(draw, (x + 4, y + 132), "ASCENSION", english, charcoal, 8)
    draw_spaced_text(draw, (x, y + 128), "ASCENSION", english, brass, 8)
    draw.rounded_rectangle((x, y + 190, x + 472, y + 196), radius=3, fill=brass)

    image.save(OUTPUT, optimize=True)
    print(OUTPUT)


if __name__ == "__main__":
    main()
