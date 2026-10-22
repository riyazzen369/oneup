"""Generate iOS AppIcon set + LaunchImage from a drawn sparkle mark matching assets/images/stellarone_logo.png."""
import json, math, os
from PIL import Image, ImageDraw, ImageFilter
ROOT = os.path.join(os.path.dirname(__file__), '..', 'ios', 'Runner', 'Assets.xcassets')
S = 1024

def lerp(a, b, t): return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

def sparkle(size, cx, cy, r, inner):
    pts = []
    for k in range(8):
        ang = -math.pi / 2 + k * math.pi / 4
        rr = r if k % 2 == 0 else inner
        pts.append((cx + rr * math.cos(ang), cy + rr * math.sin(ang)))
    return pts

def mark(size, bg=True):
    img = Image.new('RGB' if bg else 'RGBA', (size, size), (0, 0, 0) if bg else (0, 0, 0, 0))
    if bg:
        px = img.load()
        for y in range(size):
            for x in range(size):
                t = (x + y) / (2 * size)
                px[x, y] = lerp((14, 18, 44), (40, 22, 74), t)
    # gradient sparkle via mask
    mask = Image.new('L', (size, size), 0)
    d = ImageDraw.Draw(mask)
    c = size / 2
    d.polygon(sparkle(size, c, c, size * 0.34, size * 0.075), fill=255)
    d.polygon(sparkle(size, c + size * 0.24, c - size * 0.24, size * 0.08, size * 0.02), fill=255)
    grad = Image.new('RGB', (size, size))
    gp = grad.load()
    for y in range(size):
        for x in range(size):
            gp[x, y] = lerp((56, 220, 255), (168, 110, 255), (x + y) / (2 * size))
    glow = mask.filter(ImageFilter.GaussianBlur(size * 0.03))
    base = img.convert('RGBA')
    glow_layer = Image.new('RGBA', (size, size), (90, 160, 255, 0))
    glow_layer.putalpha(glow.point(lambda v: int(v * 0.55)))
    base = Image.alpha_composite(base, glow_layer)
    g = grad.convert('RGBA'); g.putalpha(mask)
    base = Image.alpha_composite(base, g)
    return base.convert('RGB') if bg else base

master = mark(S)
icons = os.path.join(ROOT, 'AppIcon.appiconset')
contents = json.load(open(os.path.join(icons, 'Contents.json')))
for im in contents['images']:
    pt = float(im['size'].split('x')[0]); sc = int(im['scale'][0])
    px = round(pt * sc)
    master.resize((px, px), Image.LANCZOS).save(os.path.join(icons, im['filename']))
launch = os.path.join(ROOT, 'LaunchImage.imageset')
m = mark(512, bg=False)
for n, sc in (('LaunchImage.png', 1), ('LaunchImage@2x.png', 2), ('LaunchImage@3x.png', 3)):
    m.resize((120 * sc, 120 * sc), Image.LANCZOS).save(os.path.join(launch, n))
print('ok', len(contents['images']))
