"""The addon kit's baseline and diff (Tools/addon-kit-plan.md, part D): the
probes' records (Dev/AddonKit.lua) with no other addon loaded, saved as the
baseline, and an addon's run judged against it. From the repo root:

    python -I Tools/addon-kit/diff.py baseline <client> [--log FILE]
    python -I Tools/addon-kit/diff.py check <Addon> <client> [--log FILE] [--no-expect]
    python -I Tools/addon-kit/diff.py --selftest

--log: a file of the log's lines (Tools/addon-kit/kitrun.lua writes one);
without it, CinematicDB.addonKitLog from that client's saved dev settings
(the game saves them on /reload).

baseline: the run must have no other addon loaded (addons= empty, as
/cine debug solo with no addon gives). Saved to
Tools/addon-kit/baseline-<client>.txt, an expectation change (the user's OK).

check: the run must have <Addon> loaded (its parts too: names starting with
it). Each probe and field against the baseline. A field that differs is
EXPECTED when the Support files declare it for an addon loaded in the run
(ns.AddonKitExpect(addon, probe, field or "*", note), read from their text),
else a FAIL. Also a FAIL, as it can't be judged:
- a probe's error in the run (E line);
- the baseline from another game build (a patch: rerun the baseline);
- a probe whose version (v) differs from the baseline's, or that the baseline
  doesn't have, or that the run lacks (the probes changed: rerun the baseline).
A declared expectation that matched nothing is a note (fixed, or the addon's
setting is off). Exit 1 on a FAIL.
"""
import fnmatch
import glob
import os
import re
import subprocess
import sys
import tempfile
import time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
KIT = os.path.join(ROOT, "Tools", "addon-kit")
FORMAT = 1
OWNED_PREFIXES = ("frame.", "addons.")
# Frames that follow the game's state whatever addon is loaded (context.state's fields).
STATE_FRAMES = {
    "pet": (r"\bpet", r"PetFrame", r"PetActionBar", r"PetActionButton"),
    "vehicle": (r"vehicle", r"OverrideActionBar", r"PossessBar"),
    "mounted": (r"mount",),
    "group": (r"party", r"raid", r"CompactRaid", r"CompactParty"),
    "combat": (r"combat",),
    "instance": (r"instance", r"boss", r"arena"),
    # (Settings or the game menu open: the game dims the micro buttons while it is.)
    "window": (r"SettingsPanel", r"GameMenu", r"MicroButton"),
}
sys.path.insert(0, os.path.join(ROOT, ".claude", "skills", "test"))

EXPECT = re.compile(r'ns\.AddonKitExpect\(\s*"([^"]+)"\s*,\s*"([^"]+)"\s*,\s*"([^"]+)"\s*,\s*"((?:[^"\\]|\\.)*)"', re.S)


class Run:
    def __init__(self, lines, source="log"):
        self.head, self.records, self.errors, self.done = {}, {}, {}, None
        self.versions, self.owned = {}, set()
        if not lines or not lines[0].startswith("H "):
            raise ValueError("%s: no H line first: not an addon kit log" % source)
        for pair in lines[0][2:].split():
            key, _, value = pair.partition("=")
            self.head[key] = value
        if self.head.get("format") != str(FORMAT):
            raise ValueError("%s: format %s, this reads %d (made by another version: run it again)" % (
                source, self.head.get("format"), FORMAT))
        for line in lines[1:]:
            if line.startswith("R "):
                parts = line[2:].split("\t")
                if len(parts) != 4:
                    continue
                probe, field, value, v = parts
                self.records.setdefault(probe, {})[field] = value
                self.versions[probe] = v
            elif line.startswith("E "):
                probe, _, err = line[2:].partition("\t")
                self.errors[probe] = err
                self.versions.setdefault(probe, "?")
            elif line.startswith("O "):
                self.owned.add(line[2:].strip())
            elif line.startswith("D "):
                self.done = line[2:]
        if self.done is None:
            raise ValueError("%s: no D line: the run didn't finish" % source)

    @property
    def addons(self):
        return [a for a in self.head.get("addons", "").split(",") if a]


def read_lines(path):
    with open(path, encoding="utf-8") as f:
        return [l.rstrip("\r\n") for l in f if l.strip()]


def log_key(target):
    """The saved log of one target of /cine debug addonkit (Dev/AddonKitTest.lua's LogKey)."""
    return "addonKit" + re.sub(r"[^A-Za-z0-9]", "", target) + "Log"


def saved_logs(client):
    """({key: lines}, path) of that client's saved dev settings."""
    import savedlogs
    for c, path in savedlogs.saved_files():
        if c == client:
            return savedlogs.log_tables(path), path
    raise ValueError("no saved dev settings for %s" % client)


def game_log(client, target=None):
    tables, path = saved_logs(client)
    for key in ([log_key(target)] if target else []) + ["addonKitLog"]:
        if tables.get(key):
            return tables[key], "%s (%s)" % (path, key)
    raise ValueError("no %s in %s's saved dev settings (run /cine debug addonkit, then /reload)" % (
        log_key(target) if target else "addonKitLog", client))


def load_run(client, log, target=None):
    if log:
        return Run(read_lines(log), log)
    lines, path = game_log(client, target)
    return Run(lines, path)


def expectations(root=ROOT):
    """[(addon, probe, field, note, file)] from the Support files' text."""
    out = []
    for path in sorted(glob.glob(os.path.join(root, "Support", "*.lua"))) + [os.path.join(root, "AddonSupport.lua")]:
        if not os.path.exists(path):
            continue
        with open(path, encoding="utf-8", errors="replace") as f:
            text = f.read()
        text = re.sub(r"--[^\n]*", "", text)
        for m in EXPECT.finditer(text):
            out.append((m.group(1), m.group(2), m.group(3), m.group(4), os.path.relpath(path, root)))
    return out


def baseline_path(client):
    return os.path.join(KIT, "baseline-%s.txt" % client)


def at_risk():
    """{probe id: [settings]}: the settings that reach each probe's touch points (touchpoints.txt),
    the features to look at when its fields differ."""
    path = os.path.join(KIT, "touchpoints.txt")
    if not os.path.exists(path):
        return {}
    sys.path.insert(0, KIT)
    import touchpoints
    with open(path, encoding="utf-8") as f:
        reg = touchpoints.parse(f.read(), path)
    out = {}
    for point, t in reg.items():
        out["touch." + re.sub(r"[^\w]", "_", point)] = sorted(t["settings"])
    return out


def compare(base, run, addon, expects, risk=None):
    """(fails, expected, notes)."""
    risk = risk or {}
    fails, expected, notes = [], [], []
    if not any(a == addon or a.startswith(addon) for a in run.addons):
        fails.append("%s isn't loaded in this run (addons: %s): /cine debug solo %s first" % (
            addon, ",".join(run.addons) or "none", addon))
    if base.head.get("client") != run.head.get("client"):
        fails.append("baseline is %s's, the run %s's" % (base.head.get("client"), run.head.get("client")))
    if base.head.get("build") != run.head.get("build"):
        fails.append("baseline from build %s, the run from build %s: the game changed, rerun the baseline" % (
            base.head.get("build"), run.head.get("build")))
    for probe, err in sorted(run.errors.items()):
        fails.append("%s errored: %s" % (probe, err))
    loaded = set(run.addons)
    # (Owned: an addon's own rows. The O lines, and always the frame probes
    # (their fields are frame names: one the baseline lacks is a frame the
    # addon's Support file put on our row, 845 of them in the first game run,
    # 2026-11-25) and the addons.* rows.)
    owned = set(run.owned) | {p for p in set(run.versions) | set(base.versions) if p.startswith(OWNED_PREFIXES)}
    mine = [e for e in expects if e[0] in loaded]
    used = set()

    def declared(probe, field):
        for i, (a, p, f, note, src) in enumerate(mine):
            if fnmatch.fnmatchcase(probe, p) and fnmatch.fnmatchcase(field, f):
                used.add(i)
                return "%s (%s, %s)" % (note, a, src)
        return None

    # (The game's state, context.state: where it differs from the baseline's,
    # differences on the frames that follow it can't be put down to the addon.)
    ctx_a, ctx_b = base.records.get("context.state", {}), run.records.get("context.state", {})
    moved = sorted(k for k in set(ctx_a) | set(ctx_b) if ctx_a.get(k) != ctx_b.get(k))
    for k in moved:
        notes.append("the game's state differed from the baseline's: %s %s then, %s now (frames that follow it "
                     "can't tell)" % (k, ctx_a.get(k, "?"), ctx_b.get(k, "?")))
    volatile = [re.compile(p, re.I) for k in moved for p in STATE_FRAMES.get(k, ())]
    probes = sorted(set(base.versions) | set(run.versions))
    for probe in probes:
        if probe not in base.versions:
            if probe in owned:
                expected.append("%s: the addon's own row (a probe the baseline can't have)" % probe)
            else:
                fails.append("%s: the baseline doesn't have it (a new probe): rerun the baseline" % probe)
            continue
        if probe not in run.versions:
            fails.append("%s: not in the run (the probes changed since): rerun it" % probe)
            continue
        if base.versions[probe] != run.versions[probe]:
            fails.append("%s: probe %s in the run, %s in the baseline: rerun the baseline" % (
                probe, run.versions[probe], base.versions[probe]))
            continue
        if probe in run.errors or probe in base.errors:
            continue
        a, b = base.records.get(probe, {}), run.records.get(probe, {})
        for field in sorted(set(a) | set(b)):
            was, now = a.get(field, "(none)"), b.get(field, "(none)")
            if was == now:
                continue
            if probe == "context.state":
                continue
            # (An alpha on a frame hidden in both runs draws nothing: what the
            # game left from fading its last line, ActionStatus 0.010 then and 1
            # now in EllesmereUI's run q8e26, 2026-11-25.)
            if field.endswith("alpha"):
                seen = field[:-len("alpha")] + "visible"
                if a.get(seen) == "false" and b.get(seen) == "false":
                    notes.append("hidden in both: %s %s: %s then, %s now (draws nothing)" % (probe, field, was, now))
                    continue
            why = declared(probe, field)
            if not why and any(v.search(probe + " " + field) for v in volatile):
                notes.append("can't tell: %s %s: %s then, %s now (the game's state moved)" % (probe, field, was, now))
                continue
            if not why and was == "(none)" and probe in owned:
                why = "the addon's own row (an owned probe)"
            line = "%s %s: %s with no addon, %s now" % (probe, field, was, now)
            if why:
                expected.append(line + ": " + why)
            else:
                features = risk.get(probe) or []
                more = ""
                if features:
                    more = "; features on it to check: %s%s" % (" ".join(features[:12]),
                                                               " +%d" % (len(features) - 12) if len(features) > 12 else "")
                fails.append(line + " (no ns.AddonKitExpect declares it%s)" % more)
    for i, (a, p, f, note, src) in enumerate(mine):
        if i not in used:
            notes.append("declared but the same as the baseline: %s %s %s (%s): fixed, or its setting off?" % (
                a, p, f, src))
    return fails, expected, notes


def cmd_baseline(client, log):
    run = load_run(client, log, "none")
    if run.addons:
        print("FAIL a baseline needs no other addon loaded; this run had: %s (/cine debug solo with no addon)" %
              ",".join(run.addons))
        return 1
    if run.errors:
        for probe, err in sorted(run.errors.items()):
            print("FAIL %s errored: %s" % (probe, err))
        return 1
    lines = ["H " + " ".join("%s=%s" % (k, v) for k, v in run.head.items())]
    for probe in sorted(run.records):
        for field in sorted(run.records[probe]):
            lines.append("R %s\t%s\t%s\t%s" % (probe, field, run.records[probe][field], run.versions[probe]))
    lines.append("D %s; saved %s" % (run.done, time.strftime("%Y-%m-%d %H:%M")))
    with open(baseline_path(client), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print("baseline %s: %d probes saved (build %s) to %s" % (client, len(run.records), run.head.get("build"),
                                                            os.path.relpath(baseline_path(client), ROOT)))
    return 0


def cmd_check(addon, client, log, use_expect=True, base_file=None):
    path = base_file or baseline_path(client)
    if not os.path.exists(path):
        print("FAIL no baseline for %s yet: diff.py baseline %s, after a run with no other addon" % (client, client))
        return 1
    base = Run(read_lines(path), path)
    run = load_run(client, log, addon)
    fails, expected, notes = compare(base, run, addon, expectations() if use_expect else [], at_risk())
    for x in expected:
        print("EXPECTED " + x)
    for x in notes:
        print("note " + x)
    for x in fails:
        print("FAIL " + x)
    print("addon kit %s %s: %d probes, %d differ as declared, %d FAIL" % (addon, client, len(run.versions),
                                                                         len(expected), len(fails)))
    return 1 if fails else 0


def cmd_all(client):
    """After /cine debug addonkit: the baseline from its none run, then every addon it ran, judged."""
    tables, path = saved_logs(client)
    if not tables.get(log_key("none")):
        print("FAIL no %s in %s: the run's baseline step didn't happen" % (log_key("none"), path))
        return 1
    code = cmd_baseline(client, None)
    base_run = Run(tables[log_key("none")], "none").head.get("run")
    bad, older = 0, []
    for key in sorted(tables):
        m = re.match(r"^addonKit(\w+?)Log$", key)
        if (not m or key in (log_key("none"), "addonKitLog", "addonKitTestLog") or key.endswith("RowsLog")
                or key.endswith("PrevLog") or not (tables[key] and tables[key][0].startswith("H "))):
            continue
        run = Run(tables[key], key)
        addon = run.head.get("label") or m.group(1)
        # (Only the stages of the baseline's own run: an older run's addon,
        # judged against a newer baseline, showed the baseline's drift as its
        # FAILs, 2026-11-25. Logs from before run ids: older too.)
        if not base_run or run.head.get("run") != base_run:
            older.append(addon)
            continue
        print("--- %s" % addon)
        bad += 1 if cmd_check(addon, client, None) else 0
        rows = tables.get(key[:-3] + "RowsLog") or []
        # (A FAIL verdict, or a frame's own NOT COVERED line: "  NOT COVERED <frame>". Not the
        # "0 NOT COVERED" inside a PASS verdict, which the first game run counted, 2026-11-25.)
        fails = [l for l in rows if re.search(r"VERDICT .*: FAIL|\s\sNOT COVERED \S", l)]
        for line in fails[:20]:
            print("FAIL rows: " + line)
        bad += 1 if fails else 0
    if older:
        print("note not judged, from an older run than this baseline (run them again): %s" % ", ".join(older))
    print("addon kit all %s: %d addons with a FAIL" % (client, bad))
    return 1 if (bad or code) else 0


def opt(name):
    if name in sys.argv:
        i = sys.argv.index(name)
        return sys.argv[i + 1] if i + 1 < len(sys.argv) else None
    return None


def kitrun(client, out, addons=""):
    args = [sys.executable, "-I", "Tools/offline/run.py", "Tools/addon-kit/kitrun.lua", client, out]
    if addons:
        args.append(addons)
    proc = subprocess.run(args, cwd=ROOT, stdin=subprocess.DEVNULL, capture_output=True, text=True,
                          encoding="utf-8", errors="replace")
    if proc.returncode != 0:
        raise RuntimeError("kitrun failed: " + (proc.stdout + proc.stderr)[-400:])


def selftest():
    bad = []

    def check(name, ok, detail=""):
        if not ok:
            bad.append(name)
        print(("PASS " if ok else "FAIL ") + name + (" (%s)" % detail if detail and not ok else ""))

    tmp = tempfile.mkdtemp(prefix="cine-kitdiff-")
    k0, k1 = os.path.join(tmp, "base.txt"), os.path.join(tmp, "daylight.txt")
    kitrun("forever", k0)
    kitrun("forever", k1, "DaylightUI,DaylightUI_Chat")
    base, run = Run(read_lines(k0), k0), Run(read_lines(k1), k1)
    check("offline baseline: no addon, no errors", not base.addons and not base.errors)
    expects = expectations()
    fails, expected, _ = compare(base, run, "DaylightUI", expects)
    check("DaylightUI's chat: the differences are the ones its Support file declares", not fails and expected,
          "; ".join(fails))
    fails, _, _ = compare(base, run, "DaylightUI", [])
    check("the same without the declarations FAILs on chat.linesOnly (the 2979131 miss)",
          any("chat.linesOnly linesOnly" in f for f in fails), "; ".join(fails))
    fails, _, _ = compare(base, run, "ElvUI", expects)
    check("an addon not in the run FAILs", any("isn't loaded" in f for f in fails))
    stale = [l.replace("\tv1", "\tv2") if l.startswith("R chat.linesOnly") else l for l in read_lines(k1)]
    fails, _, _ = compare(base, Run(stale), "DaylightUI", expects)
    check("a probe changed since the baseline FAILs (stale)", any("rerun the baseline" in f for f in fails))
    patched = [l.replace("build=16001", "build=99999") if l.startswith("H ") else l for l in read_lines(k1)]
    fails, _, _ = compare(base, Run(patched), "DaylightUI", expects)
    check("a baseline from another game build FAILs", any("game changed" in f for f in fails))
    errored = read_lines(k1)[:-1] + ["E chat.linesOnly\tboom", read_lines(k1)[-1]]
    fails, _, _ = compare(base, Run(errored), "DaylightUI", expects)
    check("a probe's error FAILs", any("errored" in f for f in fails))
    try:
        Run(["H format=999", "D x"])
        check("another format refused", False)
    except ValueError:
        check("another format refused", True)
    try:
        Run(read_lines(k1)[:-1])
        check("a run that didn't finish refused", False)
    except ValueError:
        check("a run that didn't finish refused", True)
    fake = ["H format=1 client=forever build=16001 label=x addons=Fake",
            "R touch.ChatFrame_	shown	false	v1", "R frame.player	PlayerFrame.alpha	0	v1", "D 2 probes, 0 errors"]
    fbase = ["H format=1 client=forever build=16001 label=x addons=",
             "R touch.ChatFrame_	shown	true	v1", "R frame.player	PlayerFrame.alpha	1	v1", "D 2 probes, 0 errors"]
    fails, _, _ = compare(Run(fbase), Run(fake), "Fake", [], {"touch.ChatFrame_": ["chatPeekLinesOnly"]})
    check("an undeclared difference names the features on that touch point",
          any("chatPeekLinesOnly" in f for f in fails), "; ".join(fails))
    fails, expected, _ = compare(Run(fbase), Run(fake), "Fake",
                                 [("Fake", "frame.*", "*.alpha", "its unit frames", "x"),
                                  ("Fake", "touch.ChatFrame_", "*", "its chat", "x")])
    check("wildcards in a declaration (frame.*, *.alpha)", not fails and len(expected) == 2, "; ".join(fails))
    own = ["H format=1 client=forever build=16001 label=x addons=Fake", "O addons.conflicts",
           "R addons.conflicts	Fake:style.theirs	true	v1", "D 1 probes, 0 errors"]
    obase = ["H format=1 client=forever build=16001 label=x addons=", "O addons.conflicts",
             "R addons.conflicts	Other:x.theirs	false	v1", "D 1 probes, 0 errors"]
    fails, expected, _ = compare(Run(obase), Run(own), "Fake", [])
    check("an owned probe: the addon's new rows are its own, not differences",
          not any("Fake:style" in f for f in fails) and any("Fake:style" in e for e in expected), "; ".join(fails))
    check("an owned probe: a row the baseline had, changed, still FAILs",
          any("Other:x.theirs" in f for f in fails))
    newrow = ["H format=1 client=forever build=16001 label=x addons=Fake", "R frame.prdpower	FakeBar.exists	true	v1",
              "R touch.X	shown	true	v1", "D 2 probes, 0 errors"]
    nbase = ["H format=1 client=forever build=16001 label=x addons=", "R touch.X	shown	true	v1",
             "R frame.player	PlayerFrame.exists	true	v1", "D 2 probes, 0 errors"]
    fails, expected, _ = compare(Run(nbase), Run(newrow), "Fake", [])
    check("a frame probe the baseline lacks (the addon's frame on our row) is its own, not a FAIL",
          not any("prdpower" in f for f in fails) and any("prdpower" in e for e in expected), "; ".join(fails))
    sbase = ["H format=1 client=forever build=16001 label=x addons=", "R context.state	pet	false	v1",
             "R frame.petframe	PetFrame.shown	false	v1", "R frame.player	PlayerFrame.shown	true	v1",
             "D 2 probes, 0 errors"]
    srun = ["H format=1 client=forever build=16001 label=x addons=Fake", "R context.state	pet	true	v1",
            "R frame.petframe	PetFrame.shown	true	v1", "R frame.player	PlayerFrame.shown	false	v1",
            "D 2 probes, 0 errors"]
    fails, _, notes = compare(Run(sbase), Run(srun), "Fake", [])
    check("a pet out in one run only: the pet frame can't tell, the player frame still FAILs",
          not any("PetFrame" in f for f in fails) and any("PlayerFrame" in f for f in fails)
          and any("pet false then" in n for n in notes), "; ".join(fails))
    hbase = ["H format=1 client=forever build=16001 label=x addons=", "R touch.ActionStatus	visible	false	v1",
             "R touch.ActionStatus	alpha	0.010	v1", "R frame.buffs	BuffFrame.visible	true	v1",
             "R frame.buffs	BuffFrame.alpha	1	v1", "D 2 probes, 0 errors"]
    hrun = ["H format=1 client=forever build=16001 label=x addons=Fake", "R touch.ActionStatus	visible	false	v1",
            "R touch.ActionStatus	alpha	1	v1", "R frame.buffs	BuffFrame.visible	true	v1",
            "R frame.buffs	BuffFrame.alpha	0	v1", "D 2 probes, 0 errors"]
    fails, _, notes = compare(Run(hbase), Run(hrun), "Fake", [])
    check("an alpha on a frame hidden in both runs is a note, a shown frame's still FAILs",
          not any("ActionStatus" in f for f in fails) and any("BuffFrame.alpha" in f for f in fails)
          and any("hidden in both" in n for n in notes), "; ".join(fails))
    wbase = ["H format=1 client=forever build=16001 label=x addons=", "R context.state	window	true	v2",
             "R touch.SettingsPanel	shown	true	v1", "R touch.TalentMicroButton	alpha	0.500	v1",
             "R touch.BuffFrame	shown	true	v1", "D 3 probes, 0 errors"]
    wrun = ["H format=1 client=forever build=16001 label=x addons=Fake", "R context.state	window	false	v2",
            "R touch.SettingsPanel	shown	false	v1", "R touch.TalentMicroButton	alpha	1	v1",
            "R touch.BuffFrame	shown	false	v1", "D 3 probes, 0 errors"]
    fails, _, notes = compare(Run(wbase), Run(wrun), "Fake", [])
    check("Settings open in one run only: it and the dimmed micro buttons can't tell, the buffs still FAIL",
          not any("SettingsPanel" in f or "MicroButton" in f for f in fails) and any("BuffFrame" in f for f in fails)
          and any("window true then" in n for n in notes), "; ".join(fails))
    saved = (saved_logs, baseline_path)
    tmpb = os.path.join(tmp, "b.txt")
    globals()["baseline_path"] = lambda c: tmpb
    one = ["H format=1 client=forever build=16001 label=none addons= run=A", "R touch.X	shown	true	v1", "D 1"]
    same = ["H format=1 client=forever build=16001 label=Same addons=Same run=A", "R touch.X	shown	true	v1", "D 1"]
    old = ["H format=1 client=forever build=16001 label=Old addons=Old run=B", "R touch.X	shown	false	v1", "D 1"]
    globals()["saved_logs"] = lambda c: ({"addonKitnoneLog": one, "addonKitSameLog": same, "addonKitOldLog": old}, "x")
    import io
    import contextlib
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        code = cmd_all("forever")
    globals()["saved_logs"], globals()["baseline_path"] = saved
    text = out.getvalue()
    check("all: an addon from an older run isn't judged against a newer baseline",
          code == 0 and "--- Same" in text and "--- Old" not in text and "not judged" in text and "Old" in text, text[-300:])
    check("expectations read across lines", any(e[2] == "linesOnly" and "2979131" in e[3] for e in expects))
    print("diff selftest: %d FAIL" % len(bad))
    return 1 if bad else 0


def main():
    if "--selftest" in sys.argv:
        sys.exit(selftest())
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    log = opt("--log")
    if log in args:
        args.remove(log)
    if len(args) >= 2 and args[0] == "baseline":
        sys.exit(cmd_baseline(args[1], log))
    if len(args) >= 2 and args[0] == "all":
        sys.exit(cmd_all(args[1]))
    if len(args) >= 3 and args[0] == "check":
        sys.exit(cmd_check(args[1], args[2], log, use_expect="--no-expect" not in sys.argv))
    print(__doc__)
    sys.exit(2)


if __name__ == "__main__":
    main()
