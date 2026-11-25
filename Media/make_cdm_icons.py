"""The Cooldown Manager grid's small icons (UI/CooldownGrid.lua), our own,
drawn from scratch here: one strip, 512x32, sixteen slots of white 32x32
icons on a see-through background (nine used), tinted in game by each
choice's color:
  0 eye (Always)  1 check (When ready)  2 clock (While recharging)
  3 lightning bolt (When it procs)  4 slashed circle (Never / Hidden)
  5 crossed swords (In combat)  6 moon (Out of combat)  7 plus (Add group)
  8 broken ring (Missing)
And a white 32x32 disc (the pills' round ends: its left and right halves).
usage: make_cdm_icons.py Textures/CdmIcons.tga Textures/CdmDisc.tga"""
import math
import sys
from PIL import Image, ImageDraw

N, S = 32, 8  # each icon N px, drawn S times bigger then shrunk for smooth edges
W = 2.6 * S  # line width
WHITE = (255, 255, 255, 255)
OUT = sys.argv[1] if len(sys.argv) > 1 else "CdmIcons.tga"
DISC = sys.argv[2] if len(sys.argv) > 2 else "CdmDisc.tga"


def canvas():
    img = Image.new("RGBA", (N * S, N * S), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def p(x, y):
    return (x * S, y * S)


def eye(d):
    pts_top = [p(4 + 24 * t / 30, 16 - 9 * math.sin(math.pi * t / 30)) for t in range(31)]
    pts_bot = [p(4 + 24 * t / 30, 16 + 9 * math.sin(math.pi * t / 30)) for t in range(31)]
    d.line(pts_top, fill=WHITE, width=int(W), joint="curve")
    d.line(pts_bot, fill=WHITE, width=int(W), joint="curve")
    d.ellipse([p(11.5, 11.5), p(20.5, 20.5)], fill=WHITE)


def check(d):
    d.line([p(6, 17), p(13, 24), p(26, 8)], fill=WHITE, width=int(W * 1.25), joint="curve")


def clock(d):
    d.ellipse([p(5, 5), p(27, 27)], outline=WHITE, width=int(W))
    d.line([p(16, 9.5), p(16, 16), p(21, 19)], fill=WHITE, width=int(W), joint="curve")


def spark(d):
    # A bold lightning bolt, filled. (An 8-point star till 2026-11-22: its
    # thin points shrank to an "x" at pill size, "looks broken", the user.)
    d.polygon([p(19, 3), p(7, 18), p(15, 18), p(12, 29), p(25, 13), p(17, 13), p(21, 3)], fill=WHITE)


def never(d):
    d.ellipse([p(5, 5), p(27, 27)], outline=WHITE, width=int(W))
    d.line([p(8.5, 23.5), p(23.5, 8.5)], fill=WHITE, width=int(W))


def swords(d):
    for a, b in (((7, 25), (24, 8)), ((25, 25), (8, 8))):
        d.line([p(*a), p(*b)], fill=WHITE, width=int(W))
    for x, y in ((9.5, 19.5), (22.5, 19.5)):
        d.line([p(x - 3, y + 3 if x < 16 else y - 3), p(x + 3, y - 3 if x < 16 else y + 3)], fill=WHITE, width=int(W))


def moon(d):
    d.ellipse([p(6, 5), p(27, 26)], fill=WHITE)
    d.ellipse([p(11, 2), p(30, 21)], fill=(0, 0, 0, 0))


def plus(d):
    d.line([p(16, 7), p(16, 25)], fill=WHITE, width=int(W * 1.2))
    d.line([p(7, 16), p(25, 16)], fill=WHITE, width=int(W * 1.2))


def gap_ring(d):
    # Missing (2026-11-25): a ring broken in four, "something's not there".
    # (It had the procs bolt till then: the two read the same, the user's shot.)
    for start in (20, 110, 200, 290):
        d.arc([p(5, 5), p(27, 27)], start=start, end=start + 50, fill=WHITE, width=int(W * 1.1))
    d.ellipse([p(13.5, 13.5), p(18.5, 18.5)], fill=WHITE)


# (16 slots, 512 wide, a power of two: 9 used. Was 8 in 256 till Missing came.)
strip = Image.new("RGBA", (N * 16, N), (0, 0, 0, 0))
for i, draw in enumerate((eye, check, clock, spark, never, swords, moon, plus, gap_ring)):
    img, d = canvas()
    draw(d)
    strip.paste(img.resize((N, N), Image.LANCZOS), (i * N, 0))
strip.save(OUT)

img, d = canvas()
d.ellipse([p(0, 0), p(32, 32)], fill=WHITE)
img.resize((N, N), Image.LANCZOS).save(DISC)
print("wrote", OUT, DISC)
