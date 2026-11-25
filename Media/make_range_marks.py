"""Range Hint's marks (UI/RangeHint.lua, Style/RangeHintStyle.lua): each shape
as a white, anti-aliased TGA (tinted in game), at three line weights, plus a
soft glow copy of each drawn behind it.
  RangeMark_<shape>_<weight>.tga  shape: chevron, double, dot, ring, bracket,
                                  arrow; weight: thin, normal, bold
  RangeMark_<shape>_glow.tga      the bold shape blurred, for the Glow option
64 x 64, the shape centered. Our own, made from scratch here.
  RangeMark_pill.tga              the Background tab's soft pill
Usage: python Media/make_range_marks.py Textures"""
import math
import os
import sys
from PIL import Image, ImageFilter

N = 64
SOFT = 1.2  # texture pixels each edge fades over
OUT = sys.argv[1] if len(sys.argv) > 1 else "."
# Line weights, texture pixels (normal: the first mark's 3 px at 24 px shown).
WEIGHTS = {"thin": 5.0, "normal": 8.0, "bold": 11.0}

# Each shape: a list of polylines (points), or ("disc", r) / ("circle", r).
SHAPES = {
    # A V pointing down, as the first mark (18 x 9 at 24 px).
    "chevron": [[(8, 20), (32, 44), (56, 20)]],
    "double": [[(12, 12), (32, 30), (52, 12)], [(12, 32), (32, 50), (52, 32)]],
    "dot": ("disc", 10.0),
    "ring": ("circle", 18.0),
    "bracket": [[(22, 12), (12, 12), (12, 52), (22, 52)], [(42, 12), (52, 12), (52, 52), (42, 52)]],
    # Up, toward your target ahead of you.
    "arrow": [[(32, 54), (32, 12)], [(16, 28), (32, 12), (48, 28)]],
}


def seg_dist(px, py, ax, ay, bx, by):
    vx, vy = bx - ax, by - ay
    wx, wy = px - ax, py - ay
    t = max(0.0, min(1.0, (wx * vx + wy * vy) / (vx * vx + vy * vy)))
    dx, dy = px - (ax + t * vx), py - (ay + t * vy)
    return math.hypot(dx, dy)


def draw(shape, weight):
    spec = SHAPES[shape]
    data = []
    for y in range(N):
        for x in range(N):
            px, py = x + 0.5, y + 0.5
            if isinstance(spec, tuple):
                kind, r = spec
                d = math.hypot(px - N / 2, py - N / 2)
                if kind == "disc":
                    # (The dot's size goes with the weight: thin small, bold big.)
                    edge = d - r * weight / WEIGHTS["normal"]
                else:
                    edge = abs(d - r) - weight / 2
            else:
                d = min(seg_dist(px, py, *line[i], *line[i + 1]) for line in spec for i in range(len(line) - 1))
                edge = d - weight / 2
            a = min(1.0, max(0.0, 0.5 - edge / SOFT))
            data.append((255, 255, 255, round(255 * a)))
    image = Image.new("RGBA", (N, N))
    image.putdata(data)
    return image


GLOW_FIT = 0.6  # the shape's size in its glow texture (room for the blur); drawn 1/0.6 as big in game


def glow(shape):
    bold = draw(shape, WEIGHTS["bold"] + 4)
    inner = round(N * GLOW_FIT)
    small = bold.resize((inner, inner), Image.LANCZOS)
    canvas = Image.new("RGBA", (N, N), (255, 255, 255, 0))
    canvas.paste(small, ((N - inner) // 2, (N - inner) // 2))
    alpha = canvas.getchannel("A").filter(ImageFilter.GaussianBlur(3.5))
    # (Brighter: a blur thins the middle out.)
    alpha = alpha.point(lambda v: min(255, round(v * 1.6)))
    image = Image.new("RGBA", (N, N), (255, 255, 255, 0))
    image.putalpha(alpha)
    return image


def pill():
    """RangeMark_pill.tga: a soft-edged round-ended bar, cut in three in game
    (its two round ends and a stretched middle) to fit the mark and its words."""
    w, h = 64, 32
    r = h / 2 - 1
    data = []
    for y in range(h):
        for x in range(w):
            px, py = x + 0.5, y + 0.5
            cx = min(max(px, r + 1), w - r - 1)
            d = math.hypot(px - cx, py - h / 2) - r
            a = min(1.0, max(0.0, 0.5 - d / SOFT))
            data.append((255, 255, 255, round(255 * a)))
    image = Image.new("RGBA", (w, h))
    image.putdata(data)
    return image


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    pill().save(os.path.join(OUT, "RangeMark_pill.tga"), compression="tga_rle")
    for shape in SHAPES:
        for weight, size in WEIGHTS.items():
            draw(shape, size).save(os.path.join(OUT, f"RangeMark_{shape}_{weight}.tga"), compression="tga_rle")
        glow(shape).save(os.path.join(OUT, f"RangeMark_{shape}_glow.tga"), compression="tga_rle")
    print(f"made {len(SHAPES) * (len(WEIGHTS) + 1)} textures in {OUT}")
