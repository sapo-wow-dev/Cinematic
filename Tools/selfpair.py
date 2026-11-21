"""Compare the game's target frame of you with ours (Keep the shoulder when
selecting yourself), from one run of /cine debug shoulder selfpair.

The run shows both side by side in every theme, on a plain backdrop, and logs
per screenshot each frame's rect in screen pixels (db.shoulderSelfPair). This
crops both from each shot and compares them part by part (name strip, health,
power, portrait, level badge, buff rows): for each part the shift that lines
ours up with the game's best, and how far apart they still are then. So one
run shows every difference, not one a run.

    python -I Tools/selfpair.py [--sv FILE] [--shots DIR] [--out DIR] [--no-save]
    python -I Tools/selfpair.py --selftest

Each part comes out SAME (lined up, alike), SHIFTED (alike once moved by
dx,dy screen pixels: ours is off by that much) or DIFFER (unlike however it's
moved: the art, color or contents differ). Out: the summary (stdout and
summary.txt), sheets (sheet-N.png: the game's | ours | ours with the
differences in red) and, against the last run's results (last.json, kept in
the out folder), what's new, gone or changed since.
"""
import argparse
import json
import os
import re
import sys
import tempfile
from datetime import datetime, timedelta

import numpy as np
from PIL import Image, ImageDraw

FOREVER = r"C:\Program Files (x86)\World of Warcraft\_forever_"
SV = os.path.join(FOREVER, r"WTF\Account\LORDZEPPELIN\SavedVariables\CinematicDev.lua")
SHOTS = os.path.join(FOREVER, "Screenshots")

# Around each frame, in its own units: the level badge can stick out at the
# sides and top, and the buff rows sit under it (two rows, 21 + 3 + 21).
MARGIN_SIDE, MARGIN_TOP, MARGIN_BOTTOM = 14, 10, 62
# The parts, in the target frame art's units from its top-left (Forever's
# target frame recipe: bars on the left, portrait on the right; art 194x68).
PARTS = {
    "name strip": (5, 14, 116, 11),
    "health bar": (2, 26, 126, 15),
    "power bar": (2, 43, 126, 8),
    "portrait": (132, 6, 50, 40),
    "level badge": (156, 34, 40, 34),
    "buff rows": (2, 56, 146, 48),  # (rows wrap at 127; the badge hangs in from 156)
}
# With Buffs on Top (a shot's kind "ontop-..."): the rows over the frame,
# their shared bottom 4.8 under the art's top, going up.
MARGIN_TOP_ON, MARGIN_BOTTOM_ON = 62, 10
PARTS_ON_TOP = dict(PARTS)
PARTS_ON_TOP["buff rows"] = (2, -52, 146, 56)
SHIFT = 4        # tried each way, in screen pixels
ALIKE = 9.0      # mean difference (of 255) under which a part counts as alike
WORST = 40.0     # and its most different block (BLOCK px a side) under this
BLOCK = 6
LIMIT = 48       # a pixel differs (for the red overlay): any channel this far apart

SHOT_LINE = re.compile(r"shot (\S+) theme (\S+) kind (\S+) game (\S+) ours (\S+) px ([\d.]+)")
# The test's probe of every part, both frames, at each shot; and each hiding call.
PART_LINE = re.compile(r"part (\S+) (.+?) \| game (.*?) \| ours (.*)$")
TRACE_LINE = re.compile(r"trace (\S+) (game|ours) (.+?) (SetAlpha|Hide|SetShown|SetVertexColor|SetTextColor|SetPoint)\((.*?)\) from (.*)$")
PLACE_KEYS = ("x", "y", "w", "h", "tx", "tw")
PLACE_OFF = 0.6  # (art units: a probe place this far apart differs)


def fields(text):
    return dict(kv.split("=", 1) for kv in text.split() if "=" in kv)


def looks_wrong(probe_list):
    """What looks wrong on a frame whatever the other does: each bar's numbers,
    shown, taller than their bar (the mana numbers stood over theirs on both
    frames, so matching the game passed them, the user, 2026-11-21)."""
    parts = {}
    for part, game_info, ours_info in probe_list:
        parts[part] = (fields(game_info) if game_info != "none" else {}, fields(ours_info) if ours_info != "none" else {})
    out = []
    for bar in ("health", "power"):
        if bar not in parts or bar + " text" not in parts:
            continue
        for side, name in ((0, "the game's"), (1, "ours")):
            b, t = parts[bar][side], parts[bar + " text"][side]
            try:
                shown = t.get("shown") == "1" and t.get("vis") == "1" and float(t.get("a", "0")) > 0.05
                tall, high = float(t["th"]), float(b["h"])
            except (KeyError, ValueError):
                continue
            if shown and tall > high + 0.5:
                out.append("%s %s numbers taller than their bar (%.1f, bar %.1f)" % (name, bar, tall, high))
    return out


def probe_differences(game, ours):
    """What the probe says differs for one part: 'key game X ours Y' each."""
    if game == "none" or ours == "none":
        return ["missing on %s" % ("the game's" if game == "none" else "ours")] if game != ours else []
    g, o = fields(game), fields(ours)
    out = []
    # (A text's box can be any width, ours none: where its words start counts.)
    words = "tx" in g and "tx" in o
    for key in sorted(set(g) | set(o)):
        a, b = g.get(key), o.get(key)
        # (An anchor names each frame's own parent: it always differs; it's in
        # the log for reading, not for counting.)
        if a == b or (words and key in ("x", "w")) or key == "anchor":
            continue
        if key in PLACE_KEYS:
            try:
                if abs(float(a) - float(b)) <= PLACE_OFF:
                    continue
            except (TypeError, ValueError):
                pass
        out.append("%s game %s ours %s" % (key, a, b))
    return out


def read_lines(sv_text, key="shoulderSelfPair"):
    start = sv_text.find('["%s"] = {' % key)
    if start < 0:
        return []
    lines = []
    for raw in sv_text[start:].splitlines()[1:]:
        raw = raw.strip()
        if raw.startswith("}"):
            break
        m = re.match(r'"(.*)",?$', raw)
        if m:
            lines.append(m.group(1).replace('\\"', '"').replace("\\\\", "\\"))
    return lines


def rect(text):
    if text == "none":
        return None
    return [float(v) for v in text.split(",")]


def find_shot(shots, name):
    path = os.path.join(shots, "WoWScrnShot_%s.jpg" % name)
    if os.path.exists(path):
        return path
    # (The name is the second the run asked for it; the file can be a second on.)
    try:
        when = datetime.strptime(name, "%m%d%y_%H%M%S")
    except ValueError:
        return None
    for step in (1, -1, 2):
        other = (when + timedelta(seconds=step)).strftime("%m%d%y_%H%M%S")
        for ext in (".jpg", ".png", ".tga"):
            path = os.path.join(shots, "WoWScrnShot_%s%s" % (other, ext))
            if os.path.exists(path):
                return path
    return None


def crop(image, r, k, on_top=False):
    left, top, wide, high = r
    above, below = (MARGIN_TOP_ON, MARGIN_BOTTOM_ON) if on_top else (MARGIN_TOP, MARGIN_BOTTOM)
    box = (round(left - MARGIN_SIDE * k), round(top - above * k),
           round(left + wide + MARGIN_SIDE * k), round(top + high + below * k))
    return image.crop(box)


def part_shift(a, b, box):
    """The shift (dx, dy) of ours that lines the part up best, its mean
    difference then, and with none."""
    x0, y0, x1, y1 = box
    h, w = a.shape[:2]
    pa = a[y0:y1, x0:x1]
    best = None
    for dy in range(-SHIFT, SHIFT + 1):
        for dx in range(-SHIFT, SHIFT + 1):
            if y0 + dy < 0 or x0 + dx < 0 or y1 + dy > h or x1 + dx > w:
                continue
            pb = b[y0 + dy:y1 + dy, x0 + dx:x1 + dx]
            score = float(np.abs(pa - pb).mean())
            # (A tie goes to the smaller shift.)
            key = (round(score, 2), abs(dx) + abs(dy))
            if best is None or key < best[0]:
                best = (key, dx, dy, score)
    still = float(np.abs(pa - b[y0:y1, x0:x1]).mean())
    # (Its most different block once lined up: one changed icon in a row is
    # lost in the row's mean.)
    dx, dy = best[1], best[2]
    d = np.abs(pa - b[y0 + dy:y1 + dy, x0 + dx:x1 + dx]).mean(axis=2)
    rows, cols = d.shape[0] // BLOCK, d.shape[1] // BLOCK
    worst = float(d[:rows * BLOCK, :cols * BLOCK].reshape(rows, BLOCK, cols, BLOCK).mean(axis=(1, 3)).max()) if rows and cols else 0.0
    return dx, dy, best[3], still, worst


def compare(game_img, ours_img, k, on_top=False):
    a = np.asarray(game_img.convert("RGB"), dtype=np.float32)
    b = np.asarray(ours_img.convert("RGB"), dtype=np.float32)
    h, w = min(a.shape[0], b.shape[0]), min(a.shape[1], b.shape[1])
    a, b = a[:h, :w], b[:h, :w]
    parts = {}
    above = MARGIN_TOP_ON if on_top else MARGIN_TOP
    for name, (x, y, pw, ph) in (PARTS_ON_TOP if on_top else PARTS).items():
        box = (round((x + MARGIN_SIDE) * k), round((y + above) * k),
               round((x + pw + MARGIN_SIDE) * k), round((y + ph + above) * k))
        box = (max(box[0], SHIFT), max(box[1], SHIFT), min(box[2], w - SHIFT), min(box[3], h - SHIFT))
        if box[2] - box[0] < 4 or box[3] - box[1] < 4:
            continue
        dx, dy, score, still, worst = part_shift(a, b, box)
        if score >= ALIKE or worst >= WORST:
            verdict = "DIFFER"
        elif dx or dy:
            verdict = "SHIFTED"
        else:
            verdict = "SAME"
        # (dx, dy: where ours is against the game's, in screen pixels; + is
        # right / lower.)
        parts[name] = {"verdict": verdict, "dx": dx, "dy": dy, "score": round(score, 1), "still": round(still, 1),
                       "worst": round(worst, 1)}
    diff = np.abs(a - b).max(axis=2) > LIMIT
    return diff, parts


def overlay(ours_img, diff):
    base = np.asarray(ours_img.convert("RGB"), dtype=np.float32) * 0.45
    h, w = diff.shape
    base = base[:h, :w]
    base[diff] = [255, 40, 40]
    return Image.fromarray(base.astype(np.uint8))


def describe(name, p, k):
    if p["verdict"] == "SAME":
        return "%-12s SAME" % name
    where = ""
    if p["dx"] or p["dy"]:
        parts = []
        if p["dy"]:
            parts.append("%d px %s" % (abs(p["dy"]), "lower" if p["dy"] > 0 else "higher"))
        if p["dx"]:
            parts.append("%d px %s" % (abs(p["dx"]), "right" if p["dx"] > 0 else "left"))
        where = " ours %s (%.1f units)" % (" and ".join(parts), max(abs(p["dx"]), abs(p["dy"])) / k)
    if p["verdict"] == "SHIFTED":
        return "%-12s SHIFTED%s" % (name, where)
    return "%-12s DIFFER (apart %.1f, worst spot %.0f%s)%s" % (name, p["score"], p.get("worst", 0),
                                                         "" if not where else ", even lined up", where)


def run(sv, shots, out, quiet=False, save=True):
    with open(sv, encoding="utf-8", errors="replace") as f:
        lines = read_lines(f.read())
    if not lines:
        print("no db.shoulderSelfPair in", sv)
        return None
    os.makedirs(out, exist_ok=True)
    report, rows, results = [], [], {}
    probes, traces = {}, {}
    looks_count = [0]
    context = {}
    for line in lines:
        m = PART_LINE.search(line)
        if m:
            probes.setdefault(m.group(1), []).append((m.group(2), m.group(3), m.group(4)))
            continue
        m = TRACE_LINE.search(line)
        if m:
            theme, frame, part, call, detail, stack = m.groups()
            # (The first real file in the stack, not the engine's own [C] frames.)
            frames_ = [f for f in stack.split(" < ") if not f.startswith("[C]") and f != "..."]
            where = frames_[0] if frames_ else stack
            # (A move: where to, too.)
            what = "%s(%s)" % (call, detail) if call == "SetPoint" else call
            traces.setdefault((frame, part, what, where), []).append(theme)
            continue
        # (The contextual layer's shown parts, by frame: summed up below.)
        m = re.search(r"context \S+ (game|ours) (\S+) \| (.*)$", line)
        if m:
            context.setdefault(m.group(1), {})[m.group(2)] = m.group(3)
            continue
        if not SHOT_LINE.search(line) and not line.split(" ", 1)[-1].startswith(
                ("geometry", "strip ", "numbers", "settings")):
            report.append("log: " + line)
    for line in lines:
        m = SHOT_LINE.search(line)
        if not m:
            continue
        name, theme, kind, game_r, ours_r, k = m.groups()
        game_r, ours_r, k = rect(game_r), rect(ours_r), float(k)
        label = "%s / %s" % (theme, kind)
        path = find_shot(shots, name)
        if not (path and game_r and ours_r and k > 0):
            report.append("%-24s SKIPPED: %s" % (label, "no screenshot " + name if not path else "a frame's place unread"))
            continue
        image = Image.open(path)
        on_top = kind.startswith("ontop")
        game_img, ours_img = crop(image, game_r, k, on_top), crop(image, ours_r, k, on_top)
        diff, parts = compare(game_img, ours_img, k, on_top)
        size_note = ""
        if abs(game_r[2] - ours_r[2]) > 1 or abs(game_r[3] - ours_r[3]) > 1:
            size_note = "  SIZE game %.0fx%.0f ours %.0fx%.0f px" % (game_r[2], game_r[3], ours_r[2], ours_r[3])
        off = [n for n, p in parts.items() if p["verdict"] != "SAME"]
        verdict = "SAME" if not off and not size_note else "DIFFER"
        results[label] = {n: p for n, p in parts.items()}
        report.append("%-24s %s%s" % (label, verdict, size_note))
        for n, p in parts.items():
            if p["verdict"] != "SAME":
                report.append("    " + describe(n, p, k))
        # (What looks wrong on either, matching or not.)
        for wrong in looks_wrong(probes.get(name, [])):
            report.append("    LOOKS " + wrong)
            looks_count[0] += 1
        # (The probe at that shot: every value that differs between them.)
        for part, game_info, ours_info in probes.get(name, []):
            diffs = probe_differences(game_info, ours_info)
            if diffs:
                report.append("    probe %-11s %s" % (part, "; ".join(diffs)))
        rows.append((label, verdict, game_img, ours_img, overlay(ours_img, diff)))
    report.append("looks right: %s" % ("every shot" if not looks_count[0] else "%d problems (LOOKS lines)" % looks_count[0]))
    # (Parts shown in the contextual layer: the game's PvP flag wasn't its PvpIcon.)
    if context:
        game_only = sorted(set(context.get("game", {})) - set(context.get("ours", {})))
        report.append("contextual parts shown: game %s | ours %s" % (", ".join(sorted(context.get("game", {}))) or "none",
                                                                    ", ".join(sorted(context.get("ours", {}))) or "none"))
        for key in game_only:
            report.append("    game only: %s | %s" % (key, context["game"][key]))
    # (Who hid what: each hiding call once, with the themes it came in.)
    if traces:
        report.append("hiding calls (%d kinds):" % len(traces))
        for (frame, part, call, where), themes in sorted(traces.items()):
            seen = sorted(set(themes))
            report.append("    %s %s %s x%d in %s, from %s" % (frame, part, call, len(themes),
                                                             ", ".join(seen[:6]) + (" ..." if len(seen) > 6 else ""), where))
    # (The icon crop A/B: whole icons against the buff bar's cut, in the game's look.)
    whole, cut = results.get("game / plain", {}).get("buff rows"), results.get("game / barcrop", {}).get("buff rows")
    if whole and cut:
        report.append("icon crop A/B: whole icons apart %.1f, the buff bar's cut %.1f: %s nearer the game's" % (
            whole["score"], cut["score"], "whole" if whole["score"] <= cut["score"] else "the buff bar's cut"))
    # (Against the last run: what's new, gone or changed.)
    last_path = os.path.join(out, "last.json")
    if os.path.exists(last_path):
        with open(last_path, encoding="utf-8") as f:
            last = json.load(f)
        changes = []
        for label, parts in results.items():
            for n, p in parts.items():
                before = last.get(label, {}).get(n)
                if not before:
                    continue
                if before["verdict"] != p["verdict"] or (before["dx"], before["dy"]) != (p["dx"], p["dy"]):
                    changes.append("    %-24s %-12s %s -> %s" % (label, n, Short(before), Short(p)))
        report.append("since the last run: %s" % ("no change" if not changes else "%d changes" % len(changes)))
        report.extend(changes)
    if save:
        with open(last_path, "w", encoding="utf-8") as f:
            json.dump(results, f, indent=1)
    # (Sheets of 8 rows: the game's | ours | differences, twice the size.)
    sheets = []
    for start in range(0, len(rows), 8):
        chunk = rows[start:start + 8]
        cw = max(r[2].width for r in chunk)
        ch = max(r[2].height for r in chunk)
        sheet = Image.new("RGB", (cw * 3 * 2 + 40, (ch * 2 + 22) * len(chunk)), (20, 20, 20))
        draw = ImageDraw.Draw(sheet)
        for i, (label, verdict, g, o, d) in enumerate(chunk):
            y = i * (ch * 2 + 22)
            draw.text((6, y + 4), "%s  %s   (game | ours | differences)" % (label, verdict),
                      fill=(255, 210, 80) if verdict == "DIFFER" else (140, 220, 140))
            for j, part in enumerate((g, o, d)):
                sheet.paste(part.resize((part.width * 2, part.height * 2)), (j * (cw * 2 + 20), y + 20))
        name = os.path.join(out, "sheet-%d.png" % (start // 8 + 1))
        sheet.save(name)
        sheets.append(name)
    text = "\n".join(report)
    with open(os.path.join(out, "summary.txt"), "w", encoding="utf-8") as f:
        f.write(text + "\n")
    if not quiet:
        print(text)
        for name in sheets:
            print("sheet:", name)
    return report


def Short(p):
    if p["verdict"] == "SHIFTED":
        return "SHIFTED %+d,%+d" % (p["dx"], p["dy"])
    return p["verdict"]


def selftest():
    """Frames drawn alike on the same backdrop; then ours with its buff row 2
    units lower, then with a buff changed, then whole vs cut icons."""
    work = tempfile.mkdtemp(prefix="selfpair-")
    shots, out = os.path.join(work, "shots"), os.path.join(work, "out")
    os.makedirs(shots)
    k = 2.0
    frame_w, frame_h = 194, 68

    def frame(draw, left, top, buff_down=0, patch=False, cut=False, on_top=False):
        s = lambda v: v * k
        draw.rectangle([left, top, left + s(frame_w), top + s(52)], fill=(30, 30, 30))
        draw.text((left + s(40), top + s(15)), "Sapo", fill=(250, 210, 40))
        draw.rectangle([left + s(4), top + s(27), left + s(126), top + s(40)], fill=(40, 200, 40))
        draw.rectangle([left + s(4), top + s(43), left + s(126), top + s(50)], fill=(60, 80, 220))
        draw.ellipse([left + s(130), top + s(2), left + s(188), top + s(60)], fill=(200, 160, 120))
        draw.ellipse([left + s(164), top + s(40), left + s(190), top + s(66)], fill=(40, 30, 20))
        for i in range(4):
            x, y = left + s(5 + i * 24), top + s((-16 if on_top else 56) + buff_down)
            draw.rectangle([x, y, x + s(21), y + s(21)], fill=(230, 230, 230) if not cut else (60, 120, 220))
            draw.rectangle([x + s(2), y + s(2), x + s(19), y + s(19)], fill=(60, 120, 220))
            draw.rectangle([x + s(6), y + s(6), x + s(12), y + s(14)], fill=(200, 40, 40))
        if patch:
            x, y = left + s(5 + 2 * 24), top + s(56)
            draw.rectangle([x, y, x + s(21), y + s(21)], fill=(250, 240, 120))

    cases = [("112126_100000", "plain", {}), ("112126_100010", "barcrop", {"cut": True}),
             ("112126_100020", "numbers", {"buff_down": 2}), ("112126_100030", "patch", {"patch": True}),
             ("112126_100040", "ontop-plain", {"on_top": True, "buff_down": -2})]
    for name, _, how in cases:
        img = Image.new("RGB", (1200, 900), (82, 82, 87))  # (the run's backdrop)
        d = ImageDraw.Draw(img)
        frame(d, 300, 200, on_top=how.get("on_top", False))
        frame(d, 300, 520, **how)
        img.save(os.path.join(shots, "WoWScrnShot_%s.jpg" % name), quality=92)
    gw, gh = frame_w * k, frame_h * k
    sv = os.path.join(work, "Cinematic.lua")

    def write_sv(names):
        with open(sv, "w", encoding="utf-8") as f:
            f.write('CinematicDB = {\n["shoulderSelfPair"] = {\n"0.00 start | Forever",\n')
            for name, kind, _ in names:
                f.write('"1.00 part %s strip | game shown=1 a=0.00 x=5.0 st=0 rw=0.00 | ours shown=1 a=1.00 x=5.2 st=0 rw=-",\n'
                        % name)
                f.write('"1.00 part %s name | game shown=1 a=1.00 x=40.0 | ours shown=1 a=1.00 x=40.3",\n' % name)
                f.write('"1.00 part %s level | game x=172.6 w=11.0 tx=174.0 | ours x=180.1 w=0.0 tx=174.2",\n' % name)
                f.write('"1.00 part %s power | game shown=1 h=10.0 | ours shown=1 h=10.0",\n' % name)
                tall = "11.5" if kind == "numbers" else "8.0"
                f.write('"1.00 part %s power text | game shown=1 vis=1 a=1.00 th=%s | ours shown=1 vis=1 a=1.00 th=%s",\n'
                        % (name, tall, tall))
                f.write('"1.00 shot %s theme game kind %s game 300,200,%.0f,%.0f ours 300,520,%.0f,%.0f px %.4f",\n'
                        % (name, kind, gw, gh, gw, gh, k))
            f.write('"1.00 trace reel game strip SetAlpha(0) from [C]: in function SetAlpha < '
                    '[CinematicDev/Frames.lua]:14472: in function x",\n')
            f.write('"1.00 context 112126_100000 game PrestigeBadge | shown=1 x=170.0 y=40.0 w=24.0 h=24.0",\n')
            f.write('"1.00 context 112126_100000 game RaidTargetIcon | shown=1 x=80.0 y=0.0 w=16.0 h=16.0",\n')
            f.write('"1.00 context 112126_100000 ours RaidTargetIcon | shown=1 x=80.0 y=0.0 w=16.0 h=16.0",\n')
            f.write('"2.00 trace codex game strip SetAlpha(0) from [C]: in function SetAlpha < '
                    '[CinematicDev/Frames.lua]:14472: in function x",\n')
            f.write('"9.00 end: done",\n},\n}\n')

    write_sv(cases)
    report = run(sv, shots, out, quiet=True)
    text = "\n".join(report)

    def block(label):
        i = next(i for i, r in enumerate(report) if r.startswith(label))
        lines = [report[i]]
        for r in report[i + 1:]:
            if not r.startswith("    "):
                break
            lines.append(r)
        return "\n".join(lines)

    assert "SAME" in block("game / plain"), text
    numbers = block("game / numbers")
    assert "buff rows    SHIFTED ours 4 px lower (2.0 units)" in numbers, numbers
    assert "health bar" not in numbers and "portrait" not in numbers, "a part not moved counted: " + numbers
    patch = block("game / patch")
    assert "buff rows    DIFFER" in patch, patch
    assert "icon crop A/B" in text and "whole nearer" in text, text
    assert "probe strip       a game 0.00 ours 1.00; rw game 0.00 ours -" in block("game / plain"), block("game / plain")
    assert "probe name" not in text, "a place within 0.6 units counted: " + text
    assert "probe level" not in text, "a text box's width counted over where its words start: " + text
    nums = block("game / numbers")
    assert "LOOKS the game's power numbers taller than their bar (11.5, bar 10.0)" in nums and \
        "LOOKS ours power numbers taller than their bar" in nums, nums
    assert "LOOKS" not in block("game / plain"), "numbers that fit flagged"
    assert "looks right: 2 problems" in text, text
    assert "contextual parts shown: game PrestigeBadge, RaidTargetIcon | ours RaidTargetIcon" in text, text
    assert "    game only: PrestigeBadge | shown=1 x=170.0" in text, text
    assert "game strip SetAlpha x2 in codex, reel, from [CinematicDev/Frames.lua]:14472: in function x" in text, text
    ontop = block("game / ontop-plain")
    assert "buff rows    SHIFTED ours 4 px higher (2.0 units)" in ontop, "buffs on top: " + ontop
    assert os.path.exists(os.path.join(out, "sheet-1.png"))
    # (Next run: the shifted row fixed, the rest the same: one change said.)
    os.remove(os.path.join(shots, "WoWScrnShot_112126_100020.jpg"))
    img = Image.new("RGB", (1200, 900), (82, 82, 87))
    d = ImageDraw.Draw(img)
    frame(d, 300, 200)
    frame(d, 300, 520)
    img.save(os.path.join(shots, "WoWScrnShot_112126_100020.jpg"), quality=92)
    report = run(sv, shots, out, quiet=True)
    text = "\n".join(report)
    assert "since the last run: 1 changes" in text and "SHIFTED +0,+4 -> SAME" in text, text
    # (A missing screenshot is said, not skipped silently.)
    os.remove(os.path.join(shots, "WoWScrnShot_112126_100000.jpg"))
    report = run(sv, shots, out, quiet=True, save=False)
    assert any("SKIPPED: no screenshot" in r for r in report), report
    print("PASS selfpair selftest: alike SAME; a row 2 units low SHIFTED 4 px lower, the rest SAME; "
          "a changed buff DIFFER; icon A/B picks whole; the next run's change said; missing shot said")


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--sv", default=SV)
    parser.add_argument("--shots", default=SHOTS)
    parser.add_argument("--out", default=os.path.join(tempfile.gettempdir(), "cinematic-selfpair"))
    parser.add_argument("--no-save", action="store_true", help="don't keep this run as the last one")
    parser.add_argument("--selftest", action="store_true")
    args = parser.parse_args()
    if args.selftest:
        return selftest()
    run(args.sv, args.shots, args.out, save=not args.no_save)


if __name__ == "__main__":
    sys.exit(main())
