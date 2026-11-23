"""Rain on the lens for Cinematic (the Weather page's Rain on the lens, 2026-11-23).
Two textures:
  RainDrops.tga  512x512: round drops scattered over it, each a faint body, a
                 darker rim low down and a bright spot high up, as a water drop
                 on glass catches the light. Drawn with BLEND, tiled, shifted
                 to a new spot now and then so drops come and go.
  RainStreaks.tga 256x512: thin trails running down with a drop at the head,
                 scrolled down slowly. Drawn with ADD, faint.

    python -I Media/make_rain.py Textures
"""
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
random.seed(23)

# Drops.
N = 512
body = Image.new("L", (N, N), 0)
rim = Image.new("L", (N, N), 0)
shine = Image.new("L", (N, N), 0)
db, dr, ds = ImageDraw.Draw(body), ImageDraw.Draw(rim), ImageDraw.Draw(shine)
for _ in range(70):
    r = random.uniform(3, 11)
    x, y = random.uniform(r, N - r), random.uniform(r, N - r)
    stretch = random.uniform(1.0, 1.3)  # a little longer than wide, as they sag
    db.ellipse((x - r, y - r * stretch, x + r, y + r * stretch), fill=90)
    dr.ellipse((x - r, y - r * stretch, x + r, y + r * stretch), outline=170, width=max(1, int(r / 4)))
    ds.ellipse((x - r * 0.45, y - r * 0.75, x - r * 0.05, y - r * 0.3), fill=255)
body = body.filter(ImageFilter.GaussianBlur(1.5))
rim = rim.filter(ImageFilter.GaussianBlur(1.0))
shine = shine.filter(ImageFilter.GaussianBlur(1.2))
bp, rp, sp = body.load(), rim.load(), shine.load()
drops = Image.new("RGBA", (N, N))
px = drops.load()
for y in range(N):
    for x in range(N):
        b, r, s = bp[x, y] / 255, rp[x, y] / 255, sp[x, y] / 255
        # (Body and rim a cool dark grey-blue, the shine near white.)
        alpha = min(1.0, b * 0.5 + r * 0.55 + s * 0.8)
        light = 0.35 + 0.6 * s / max(alpha, 0.01) if alpha > 0 else 0
        light = max(0.0, min(1.0, light))
        px[x, y] = (int(150 + 100 * light), int(165 + 85 * light), int(185 + 70 * light), int(255 * alpha))
drops.save(os.path.join(OUT, "RainDrops.tga"))

# Streaks.
W, H = 256, 512
streaks = Image.new("L", (W, H), 0)
d = ImageDraw.Draw(streaks)
for _ in range(26):
    x = random.uniform(4, W - 4)
    top = random.uniform(0, H)
    length = random.uniform(60, 220)
    wobble = 0
    for i in range(int(length / 3)):
        y = top + i * 3
        wobble += random.uniform(-0.6, 0.6)
        d.line((x + wobble, y % H, x + wobble, (y + 3) % H), fill=int(60 + 90 * i / max(1, length / 3)), width=1)
    head = (top + length) % H
    d.ellipse((x + wobble - 2.5, head - 3, x + wobble + 2.5, head + 3), fill=220)
streaks = streaks.filter(ImageFilter.GaussianBlur(0.7))
sp2 = streaks.load()
img = Image.new("RGBA", (W, H))
p2 = img.load()
for y in range(H):
    for x in range(W):
        a = sp2[x, y]
        p2[x, y] = (235, 242, 255, a)
img.save(os.path.join(OUT, "RainStreaks.tga"))
