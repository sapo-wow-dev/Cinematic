"""Reads /cine debug fontstep's grid off its screenshot: does text 0.1 font
size bigger draw bigger, or only jump at whole sizes?

    python -I Tools/tests/fontstep_measure.py [screenshot.jpg] [SavedVariables Cinematic.lua]

Defaults: Forever's account SavedVariables (the cells from
CinematicDB.fontStepTestLog: "cell <way> <base> <size> px L T R B") and the
newest screenshot. Per cell: the drawn text's width and height in pixels
(bright columns/rows) and its ink (summed brightness, which grows with
anti-aliased sub-pixel growth even when the width doesn't). Per column a
verdict by width: SMOOTH when nearly every 0.1 step draws wider, STEPS when
most steps draw the same width and it jumps (it lists where), else MIXED.
"""
import glob
import os
import re
import sys

from PIL import Image
import numpy as np

FOREVER = r"C:\Program Files (x86)\World of Warcraft\_forever_"


def saved_file():
    # (The dev copy saves to CinematicDev.lua, the player copy to
    # Cinematic.lua: the newest that holds the log.)
    found = [path for path in glob.glob(os.path.join(FOREVER, "WTF", "Account", "*", "SavedVariables", "Cinematic*.lua"))
             if "fontStepTestLog" in open(path, encoding="utf-8", errors="replace").read()]
    return max(found, key=os.path.getmtime) if found else None


def newest_shot():
    found = glob.glob(os.path.join(FOREVER, "Screenshots", "WoWScrnShot_*.jpg"))
    return max(found, key=os.path.getmtime) if found else None


def cells_from(path):
    text = open(path, encoding="utf-8", errors="replace").read()
    start = text.find('["fontStepTestLog"]')
    if start < 0:
        sys.exit("no fontStepTestLog in " + path)
    end = text.find("\n\t}", start)
    block = text[start:end]
    pat = re.compile(r"cell (\w+) (\d+) ([\d.]+) px ([\d.]+) ([\d.]+) ([\d.]+) ([\d.]+)")
    return [(m.group(1), int(m.group(2)), float(m.group(3)), *map(float, m.group(4, 5, 6, 7)))
            for m in pat.finditer(block)]


def measure(gray, left, top, right, bottom):
    box = gray[int(round(top)) + 1:int(round(bottom)) - 1, int(round(left)) + 1:int(round(right)) - 1]
    ink = box.astype(float) / 255.0
    bright = box > 90
    cols = np.nonzero(bright.any(axis=0))[0]
    rows = np.nonzero(bright.any(axis=1))[0]
    if len(cols) == 0:
        return 0, 0, 0.0
    return int(cols[-1] - cols[0] + 1), int(rows[-1] - rows[0] + 1), float(ink[ink > 0.12].sum())


def main():
    shot = sys.argv[1] if len(sys.argv) > 1 else newest_shot()
    saved = sys.argv[2] if len(sys.argv) > 2 else saved_file()
    cells = cells_from(saved)
    gray = np.asarray(Image.open(shot).convert("L"))
    print(f"screenshot {shot}\ncells {len(cells)} from {saved}\n")
    columns = {}
    for way, base, size, left, top, right, bottom in cells:
        columns.setdefault((base, way), []).append((size, *measure(gray, left, top, right, bottom)))
    for (base, way), rows in sorted(columns.items()):
        rows.sort()
        print(f"== {way} from {base}")
        grew, flat, jumps = 0, 0, []
        for i, (size, width, height, ink) in enumerate(rows):
            line = f"  {size:5.1f}  width {width:4d}  height {height:3d}  ink {ink:8.1f}"
            if i:
                prev = rows[i - 1]
                change = (ink / prev[3] - 1) * 100 if prev[3] else 0
                line += f"  ({change:+5.1f}% ink, {width - prev[1]:+d} px)"
                if change > 0.6:
                    grew += 1
                else:
                    flat += 1
                if change > 4 or width - prev[1] >= 3:
                    jumps.append(f"{prev[0]:.1f}->{size:.1f}")
            print(line)
        steps = len(rows) - 1
        wider = sum(1 for i in range(1, len(rows)) if rows[i][1] > rows[i - 1][1])
        still = sum(1 for i in range(1, len(rows)) if rows[i][1] == rows[i - 1][1])
        # (Width is the clean signal: drawn smoothly it grows a pixel or two
        # every 0.1; snapped to whole sizes it stays put, then jumps. Checked
        # on made-up shots: Pillow at whole sizes = STEPS, big text shrunk by
        # exact fractions = SMOOTH.)
        verdict = "SMOOTH" if wider >= steps - 2 else ("STEPS" if still >= steps // 2 + 1 else "MIXED")
        print(f"  verdict {verdict}: wider at {wider} of {steps} steps, same width at {still}; ink grew at {grew}"
              + (f"; jumps at {', '.join(jumps)}" if jumps else "") + "\n")


if __name__ == "__main__":
    main()
