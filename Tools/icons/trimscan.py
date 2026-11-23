"""Every icon in the game's art export, checked for a frame drawn into its art that a round
Cooldown Manager icon would show as straight lines inside the circle (Style/ActionBarStyle.lua
CDM_TRIM; fix card Tools/audits/2026-11-23-style-cdm-round-trim.md).

    python -I Tools/icons/trimscan.py [--client _forever_] [--out DIR] [--sheet 0.12]

Needs the console's `exportInterfaceFiles art` (at character select) for that client. Reads the art
in place; writes only a report and contact sheets (to --out, the scratchpad by default: the art is
Blizzard's and never goes into the repo).

A frame: a straight edge parallel to the icon's side, at the same depth on at least two sides, across
the middle half of the side (what a circle's chord shows). Its depth is a share of the art's width;
a trim at or past it cuts it off, one short of it leaves it inside the circle.
"""
import argparse
import os
import sys
from concurrent.futures import ProcessPoolExecutor

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import roundlib as R  # noqa: E402

N = 64
TRIMS = (0.07, 0.08, 0.10, 0.12, 0.14, 0.16, 0.18, 0.20)
MAX_DEPTH = 16          # px of 64 looked into (0.25)
STEP = 0.07             # a frame edge's brightness step (0 to 1)
CONSISTENT = 0.8        # share of the span stepping the same way
SPAN = slice(16, 48)    # the middle half of a side


SHARP = 1.8            # a frame's step over the steps 3 rows either side (a vignette fades: no)


def side_lines(gray):
    """For each side, the depths (px) where a sharp straight edge runs along it: at the same row
    across the middle half of the side (round art curves away; a soft vignette isn't sharp)."""
    sides = [gray, gray[::-1], gray.T, gray.T[::-1]]  # top, bottom, left, right: row k from that edge
    found = []
    for g in sides:
        g = g[:, SPAN]
        # (A step over two rows, centered on k: an edge smeared over two pixels still counts.)
        s = np.zeros_like(g)
        s[1:-1] = g[2:] - g[:-2]
        depths = []
        for k in range(2, MAX_DEPTH + 1):
            step = s[k]
            m = float(np.median(step))
            if abs(m) < STEP:
                continue
            around = np.maximum(np.abs(s[max(0, k - 3)]), np.abs(s[k + 3]))
            sharp = (np.sign(step) == np.sign(m)) & (np.abs(step) > STEP) & (np.abs(step) > SHARP * around)
            if float(np.mean(sharp)) >= CONSISTENT:
                depths.append((k, abs(m)))
        found.append(depths)
    return found


def frame_depth(path):
    """(depth share, strength) of the deepest frame edge on 2+ sides, or (0, 0)."""
    try:
        art = R.load(path, N)
    except Exception as err:  # noqa: BLE001
        return path, -1.0, str(err)
    gray = art @ np.array([0.299, 0.587, 0.114], np.float32)
    lines = side_lines(gray)
    best, score = 0, 0.0
    for k in range(2, MAX_DEPTH + 1):
        sides = [max((s for kk, s in side if abs(kk - k) <= 1), default=0) for side in lines]
        hits = [s for s in sides if s > 0]
        if len(hits) >= 2 and k > best:
            best, score = k, float(np.mean(hits))
    return path, best / N, score


def sheet(rows, trims, out, title):
    tiles = []
    for path, depth, _ in rows:
        art = R.load(path, N)
        tiles.append(np.hstack([R.render(art, t, 72) for t in trims]))
    if not tiles:
        return None
    cols = 4
    while len(tiles) % cols:
        tiles.append(np.zeros_like(tiles[0]))
    grid = np.vstack([np.hstack(tiles[i:i + cols]) for i in range(0, len(tiles), cols)])
    path = os.path.join(out, title + ".png")
    Image.fromarray((np.clip(grid, 0, 1) * 255).astype(np.uint8)).save(path)
    return path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--client", default="_forever_")
    ap.add_argument("--out", default=os.environ.get("TEMP", "."))
    ap.add_argument("--sheet", type=float, default=0.12)
    ap.add_argument("--limit", type=int, default=0)
    args = ap.parse_args()
    folder = R.icons_dir(args.client)
    files = sorted(os.path.join(folder, f) for f in os.listdir(folder) if f.lower().endswith(".blp"))
    if args.limit:
        files = files[:args.limit]
    with ProcessPoolExecutor() as pool:
        results = list(pool.map(frame_depth, files, chunksize=64))
    bad = [r for r in results if r[1] < 0]
    ok = [r for r in results if r[1] >= 0]
    print(f"{len(ok)} icons read ({len(bad)} unreadable) from {folder}")
    framed = [r for r in ok if r[1] > 0]
    print(f"{len(framed)} with a frame edge on 2+ sides")
    for t in TRIMS:
        # (Inside the circle: deeper than the trim by a pixel of the art.)
        left = sum(1 for r in ok if r[1] > t + 1.0 / N)
        print(f"  trim {t:.2f}: {left} icons ({100.0 * left / max(1, len(ok)):.2f}%) still show a frame")
    os.makedirs(args.out, exist_ok=True)
    report = os.path.join(args.out, "trimscan.tsv")
    with open(report, "w", encoding="utf-8") as fh:
        for path, depth, score in sorted(ok, key=lambda r: (-r[1], -r[2])):
            fh.write(f"{os.path.basename(path)}\t{depth:.3f}\t{score:.3f}\n")
    print("report:", report)
    still = sorted((r for r in ok if r[1] > args.sheet + 1.0 / N), key=lambda r: (-r[2]))[:48]
    shown = sheet(still, (0.0, 0.07, args.sheet, 0.16), args.out, f"trimscan-left-at-{args.sheet:.2f}")
    print("still framed at", args.sheet, "(columns: 0, 0.07, it, 0.16):", shown)
    fixed = sorted((r for r in ok if 0.07 + 1.0 / N < r[1] <= args.sheet + 1.0 / N), key=lambda r: -r[2])[:48]
    shown = sheet(fixed, (0.0, 0.07, args.sheet, 0.16), args.out, f"trimscan-fixed-by-{args.sheet:.2f}")
    print("framed at 0.07, clean at", args.sheet, ":", shown)


if __name__ == "__main__":
    main()
