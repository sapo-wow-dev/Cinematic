"""The drain ring round a tracked buff's icon (UI/CooldownRing.lua): the ring cut
into segments, one TGA each, white (tinted in game), clockwise from 12 o'clock.
Each segment is its own StatusBar fill turned fully on or off by the shield's
amount (an addon can't do math on the secret amount; the bar's range does it),
so segment i sits alone on a canvas the size of the whole ring.
  CdmRing8_<i>.tga   8 chunky pips (gaps between)
  CdmRing24_<i>.tga  24 thin steps, read as one smooth ring
  CdmDrainGrad.tga   a red-to-green gradient for the bar and liquid fills
Our own, made from scratch here; usage: make_cdm_ring.py Textures"""
import math
import os
import sys
from PIL import Image

N = 64
OUT = sys.argv[1] if len(sys.argv) > 1 else "."
SOFT = 1.2  # texture pixels each edge fades over
OUTER = N / 2 - 1.0
WIDTH = {8: 6.0, 24: 4.0}  # band thickness, texture pixels
GAP = {8: 9.0, 24: 0.6}  # degrees left empty between segments


def segment(count, index):
    width, gap = WIDTH[count], GAP[count]
    span = 360.0 / count
    start, end = index * span + gap / 2, (index + 1) * span - gap / 2
    data = []
    for y in range(N):
        for x in range(N):
            dx, dy = x + 0.5 - N / 2, y + 0.5 - N / 2
            d = (dx * dx + dy * dy) ** 0.5
            radial = min(1.0, max(0.0, 0.5 - max(d - OUTER, OUTER - width - d) / SOFT))
            # Angle clockwise from 12 o'clock (screen y grows down).
            angle = math.degrees(math.atan2(dx, -dy)) % 360
            # Fade the segment's ends over SOFT pixels of arc at radius d.
            px = math.radians(1) * max(d, 1)
            inside = min(angle - start, end - angle) * px
            around = min(1.0, max(0.0, 0.5 + inside / SOFT))
            data.append((255, 255, 255, round(255 * radial * around)))
    image = Image.new("RGBA", (N, N))
    image.putdata(data)
    image.save(os.path.join(OUT, "CdmRing%d_%d.tga" % (count, index + 1)), compression="tga_rle")


for count in (8, 24):
    for i in range(count):
        segment(count, i)

# Red on the left to green on the right: a fill cropped from the left keeps
# its red end, so what's left of a draining bar turns redder.
W, H = 64, 8
grad = Image.new("RGBA", (W, H))
pixels = []
for y in range(H):
    for x in range(W):
        t = x / (W - 1)
        r = round(255 * min(1.0, 2 * (1 - t)) * 0.95)
        g = round(255 * min(1.0, 2 * t) * 0.85)
        pixels.append((r, g, 40, 255))
grad.putdata(pixels)
grad.save(os.path.join(OUT, "CdmDrainGrad.tga"), compression="tga_rle")
