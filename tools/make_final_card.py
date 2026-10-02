from PIL import Image, ImageDraw, ImageFont
import sys
logo, out = sys.argv[1], sys.argv[2]
canvas = Image.new('RGB', (1080, 1920), '#18282B')
mark = Image.open(logo).convert('RGB')
mark.thumbnail((360, 360))
canvas.paste(mark, ((1080-mark.width)//2, 430))
draw = ImageDraw.Draw(canvas)
font_path = '/System/Library/Fonts/SFNS.ttf'
try:
    f1 = ImageFont.truetype(font_path, 104)
    f2 = ImageFont.truetype(font_path, 42)
    f3 = ImageFont.truetype(font_path, 48)
except OSError:
    f1 = f2 = f3 = ImageFont.load_default()
def centered(text, y, font, fill):
    box = draw.textbbox((0,0), text, font=font)
    draw.text(((1080-(box[2]-box[0]))//2, y), text, font=font, fill=fill)
centered('RUMAR', 1160, f1, 'white')
centered('A tua equipa técnica, mais organizada.', 1320, f2, 'white')
centered('Pede uma demonstração', 1460, f3, '#E9643A')
canvas.save(out, quality=95)
