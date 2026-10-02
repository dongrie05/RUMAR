from PIL import Image, ImageDraw, ImageFont
import sys

src, dst, text = sys.argv[1], sys.argv[2], sys.argv[3]
im = Image.open(src).convert('RGB')
im = im.resize((1080, 1920))
overlay = Image.new('RGBA', im.size, (23, 52, 55, 26))
overlay.alpha_composite(Image.new('RGBA', im.size, (0, 0, 0, 0)))
draw = ImageDraw.Draw(overlay)
try:
    font = ImageFont.truetype('/System/Library/Fonts/SFNS.ttf', 54)
except OSError:
    font = ImageFont.load_default()
draw.multiline_text((72, 1510), text.replace('\\n', '\n'), font=font, fill='white', spacing=10)
Image.alpha_composite(im.convert('RGBA'), overlay).convert('RGB').save(dst, quality=95)
