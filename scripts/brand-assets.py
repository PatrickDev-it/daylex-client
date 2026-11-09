"""Rasterize the homepage's code-native folio mark for OS icon formats (Pillow)."""
from pathlib import Path
import shutil
from PIL import Image, ImageDraw
from PIL.PngImagePlugin import PngInfo

root = Path(__file__).resolve().parents[1]
app = root / 'app'
source = root / 'site/home-mark.svg'
shutil.copy2(source, root / 'site/favicon.svg')
shutil.copy2(source, app / 'web/icon.svg')
# The two closed polygons are the exact path from the 48-unit source SVG.
polygons = [
    [(8, 8), (30, 8), (30, 14), (14, 14), (14, 34), (8, 34)],
    [(18, 18), (40, 18), (40, 40), (18, 40), (18, 34), (34, 34), (34, 24), (18, 24)],
]
canvas = Image.new('RGBA', (2048, 2048))
draw = ImageDraw.Draw(canvas)
draw.rounded_rectangle((0, 0, 2047, 2047), radius=384, fill='#000000')
for polygon in polygons:
    draw.polygon([(round(x * 2048 / 48), round(y * 2048 / 48)) for x, y in polygon], fill='#dff4e2')

def save_png(path, size):
    path.parent.mkdir(parents=True, exist_ok=True)
    provenance = PngInfo()
    provenance.add_text('Source', 'Daylex authored vector: site/home-mark.svg; rasterized by scripts/brand-assets.py')
    canvas.resize((size, size), Image.Resampling.LANCZOS).save(path, pnginfo=provenance)

for size in (192, 512):
    save_png(app / f'web/icon-{size}.png', size)
for size in (16, 32, 64, 128, 256, 512, 1024):
    save_png(app / f'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_{size}.png', size)
save_png(app / 'assets/branding/daylex.png', 512)
canvas.resize((256, 256), Image.Resampling.LANCZOS).save(
    app / 'windows/runner/resources/app_icon.ico', format='ICO',
    sizes=[(n, n) for n in (16, 24, 32, 48, 64, 128, 256)],
)
print('Generated website, PWA, Windows, macOS and Linux branding assets.')
