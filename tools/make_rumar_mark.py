from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

S = 1024
im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(im)

# RUMAR mark chosen by the founder: one open, forward-facing R assembled
# from a mint structural stroke and a coral directional cap.
mint = "#A8DCCB"
coral = "#ED806F"

# Structural stem and outward leg.
d.polygon([
    (250, 172), (475, 172), (543, 306), (414, 306),
    (414, 486), (589, 798), (423, 798), (250, 493)
], fill=mint)

# Directional cap: broad at the top and opening into the counter of the R.
d.polygon([
    (475, 172), (756, 172), (820, 242), (820, 396),
    (697, 526), (492, 526), (568, 386), (686, 386),
    (686, 310), (543, 306)
], fill=coral)

im.save("mobile/assets/brand/rumar-mark-v7.png")
im.save("public/rumar-mark.png")


def app_icon(size):
    canvas = Image.new("RGB", (size, size), "#173437")
    symbol = im.copy()
    bbox = symbol.getbbox()
    symbol = symbol.crop(bbox)
    target = int(size * 0.62)
    symbol.thumbnail((target, target), Image.Resampling.LANCZOS)
    canvas.paste(
        symbol,
        ((size - symbol.width) // 2, (size - symbol.height) // 2),
        symbol,
    )
    return canvas


icon_targets = [
    "mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset",
    "mobile/android/app/src/main/res/mipmap-mdpi",
    "mobile/android/app/src/main/res/mipmap-hdpi",
    "mobile/android/app/src/main/res/mipmap-xhdpi",
    "mobile/android/app/src/main/res/mipmap-xxhdpi",
    "mobile/android/app/src/main/res/mipmap-xxxhdpi",
]
for folder in icon_targets:
    for path in Path(folder).glob("*.png"):
        with Image.open(path) as existing:
            app_icon(existing.width).save(path)

app_icon(192).save("mobile/web/icons/Icon-192.png")
app_icon(192).save("mobile/web/icons/Icon-maskable-192.png")
app_icon(512).save("mobile/web/icons/Icon-512.png")
app_icon(512).save("mobile/web/icons/Icon-maskable-512.png")
app_icon(48).save("mobile/web/favicon.png")


def font(size):
    return ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", size)


# Deterministic social card: the approved mark and the current product promise.
social = Image.new("RGB", (1200, 630), "#173437")
sd = ImageDraw.Draw(social)
sd.ellipse((930, -170, 1320, 220), fill="#214649")
sd.ellipse((-160, 470, 210, 840), fill="#214649")

mark = im.copy()
mark.thumbnail((175, 175), Image.Resampling.LANCZOS)
social.paste(mark, (82, 75), mark)
sd.text((290, 104), "RUMAR", font=font(78), fill="#F5F4EF")
sd.text((86, 306), "O teu dia técnico,", font=font(60), fill="#F5F4EF")
sd.text((86, 378), "sob controlo.", font=font(60), fill="#F5F4EF")
sd.text(
    (90, 500),
    "Agenda  ·  Trabalhos  ·  Clientes  ·  Percursos",
    font=font(27),
    fill="#A8DCCB",
)
social.save("public/og.png", optimize=True)
