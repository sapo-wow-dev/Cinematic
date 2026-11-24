"""Icon for the links back from a Style page to its frame's settings
(StylePages.lua's ns.SettingsIcon, the way back from ns.StyleIcon's palette):
64x64, a flat cream gear on a see-through background, its hub hole cut out.
Our own, drawn from scratch here, a pair with make_style_palette.py; usage:
make_settings_gear.py Textures/SettingsGear.tga"""
import math
import sys
from PIL import Image, ImageDraw

N = 64
S = 4  # drawn this many times bigger, then shrunk, for smooth edges
OUT = sys.argv[1] if len(sys.argv) > 1 else "SettingsGear.tga"
CREAM = (246, 236, 212, 255)
CLEAR = (0, 0, 0, 0)
TEETH = 8
OUTER, INNER, HOLE = 28, 21, 8.5  # tooth tips, the ring under them, the hub hole
CX = CY = 32

big = Image.new("RGBA", (N * S, N * S), CLEAR)
draw = ImageDraw.Draw(big)

# The gear's edge: each tooth a flat-topped bump, a little narrower at its tip.
points = []
step = 2 * math.pi / TEETH
for i in range(TEETH):
    a = i * step - math.pi / 2
    for angle, r in ((a - step * 0.30, INNER), (a - step * 0.18, OUTER), (a + step * 0.18, OUTER),
                     (a + step * 0.30, INNER)):
        points.append(((CX + r * math.cos(angle)) * S, (CY + r * math.sin(angle)) * S))
draw.polygon(points, fill=CREAM)
draw.ellipse([(CX - INNER) * S, (CY - INNER) * S, (CX + INNER) * S, (CY + INNER) * S], fill=CREAM)
draw.ellipse([(CX - HOLE) * S, (CY - HOLE) * S, (CX + HOLE) * S, (CY + HOLE) * S], fill=CLEAR)

big.resize((N, N), Image.LANCZOS).save(OUT)
