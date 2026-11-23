"""Frost on the screen's edges for Cinematic (the Weather page's Frost, 2026-11-23):
512x512, stretched over the whole screen. Clear in the middle; toward the edges
and most in the corners, feathery ice crystals (branching strokes grown in from
the edge) over a fine frosty grain, in a pale icy white-blue. Drawn with BLEND.

    python -I Media/make_frost.py Textures/Frost.tga
"""
import math
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

N = 512
OUT = sys.argv[1] if len(sys.argv) > 1 else "Frost.tga"
random.seed(11)

# The crystals: branching strokes grown inward from random points on the edges.
lines = Image.new("L", (N, N), 0)
draw = ImageDraw.Draw(lines)


def grow(x, y, angle, length, width, depth):
    if depth > 5 or length < 3:
        return
    steps = int(length / 4)
    for _ in range(steps):
        nx = x + math.cos(angle) * 4
        ny = y + math.sin(angle) * 4
        draw.line((x, y, nx, ny), fill=int(150 + 100 * random.random()), width=max(1, int(width)))
        x, y = nx, ny
        angle += random.uniform(-0.25, 0.25)
        if random.random() < 0.22:
            side = random.choice((-1, 1))
            grow(x, y, angle + side * random.uniform(0.6, 1.1), length * 0.5, width * 0.7, depth + 1)


for _ in range(140):
    edge = random.randrange(4)
    t = random.random() * N
    if edge == 0:
        x, y, angle = t, 0, math.pi / 2
    elif edge == 1:
        x, y, angle = t, N, -math.pi / 2
    elif edge == 2:
        x, y, angle = 0, t, 0
    else:
        x, y, angle = N, t, math.pi
    grow(x, y, angle + random.uniform(-0.6, 0.6), random.uniform(40, 120), random.uniform(1.5, 3), 0)

lines = lines.filter(ImageFilter.GaussianBlur(0.8))
grain = Image.effect_noise((N, N), 60).filter(ImageFilter.GaussianBlur(1.2))

CLEAR = 0.62  # radius (0 middle, 1 edge midpoint) still clear of frost
FULL = 1.2    # radius at full frost (past the corners' 1.41 it holds)


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


lp, gp = lines.load(), grain.load()
img = Image.new("RGBA", (N, N))
px = img.load()
for y in range(N):
    for x in range(N):
        dx, dy = (x + 0.5) / N * 2 - 1, (y + 0.5) / N * 2 - 1
        # (Rounded-square distance: the edges frost, not a circle.)
        r = (abs(dx) ** 4 + abs(dy) ** 4) ** 0.25
        mask = smooth((r - CLEAR) / (FULL - CLEAR))
        crystal = lp[x, y] / 255
        frost = gp[x, y] / 255
        alpha = mask * min(1.0, 0.25 + 0.35 * frost + 0.75 * crystal)
        shade = 0.88 + 0.12 * crystal
        px[x, y] = (int(222 * shade), int(236 * shade), int(255 * shade), int(255 * alpha))

img.save(OUT)
