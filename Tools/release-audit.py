"""The release audit: the code that ships, last release -> this one. From the
repo root:

    python -I Tools/release-audit.py areas [REF] [--out DIR]
    python -I Tools/release-audit.py impact [REF [NEW]]
    python -I Tools/release-audit.py selftest

REF is the last release (default: the latest tag), NEW a commit (default: the
working tree, untracked files too). Only what players get counts: the files
Cinematic.toc loads, the TOC itself and Bindings.xml (not Dev/, Tools/, docs/;
Locales/ only in the impact scan: translations are the release's step 5).

areas    the shipped files changed since REF, grouped by area folder (root
         files: "Core"), a big area cut in parts of about 2500 changed
         lines, each part's files and +/- counts. With --out, one diff file
         per part (8 lines of context, new and untracked files whole, the
         commits since REF that touched it at the top) for a reviewer each.
         Every commit since the tag is in it, not only what's uncommitted:
         commits made between releases were never reviewed by one.
impact   what this release could change for players who already have it,
         beyond their saved settings (Tools/upgrade-check.py does those):
           LABEL GONE    player text (L["..."]) the old code shows and the
                         new doesn't: a renamed or removed option, page or
                         message (guides, videos, /cine find, muscle memory);
           PAGE          a settings page added or gone (RegisterSubpage);
           COMMAND       a /cine word added or gone (Slash.lua);
           BINDING       a key binding added or gone (Bindings.xml): a gone
                         one loses the key players set;
           CVAR          a game setting Cinematic now sets, or no longer does;
           TOC           a file the player copy loads added or gone, or a
                         ## header (SavedVariables, Interface) changed;
           HOOK          a new hook on a game function or frame (taint,
                         other addons, behavior in fights);
           LOAD          more busy-event handlers or OnUpdates than before
                         (CPU in fights, raids, cities).
         Each line is a flag for the review to judge (meant, and what the
         player sees; or a finding), never an error. Exit 0.
"""
import collections
import difflib
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOC = "Cinematic.toc"
EXTRA = ("Cinematic.toc", "Bindings.xml")
PART_LINES = 2500
CONTEXT = 8
# Events that fire many times a second in fights, raids and cities.
BUSY = ("COMBAT_LOG_EVENT_UNFILTERED", "UNIT_AURA", "UNIT_HEALTH", "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT",
        "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_COMBAT",
        "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_CHARGES",
        "ACTIONBAR_UPDATE_COOLDOWN", "ACTIONBAR_UPDATE_STATE", "BAG_UPDATE", "UNIT_THREAT_LIST_UPDATE",
        "CURSOR_CHANGED", "UPDATE_MOUSEOVER_UNIT", "PLAYER_SOFT_INTERACT_CHANGED", "UNIT_TARGET")

RE_L = re.compile(r'\bL\["((?:[^"\\]|\\.)*)"\]')
RE_PAGE = re.compile(r'RegisterSubpage\([^,()]*,\s*"([^"]+)"')
RE_CMD = re.compile(r'\b(?:cmd|sub)\s*==\s*"([^"]+)"')
RE_BIND = re.compile(r'<Binding\s+name="([^"]+)"')
RE_CVAR = re.compile(r'SetCVar\(\s*"([^"]+)"')
RE_HOOK = re.compile(r'hooksecurefunc\(\s*([^,()]+?)\s*(?:,\s*"([^"]+)")?\s*,')
RE_EVENT = re.compile(r'RegisterEvent\(\s*"([A-Z_]+)"')
RE_UNIT_EVENT = re.compile(r'RegisterUnitEvent\(\s*"([A-Z_]+)"')
RE_ONUPDATE = re.compile(r'SetOnUpdate\(|HookOnUpdate\(|SetScript\(\s*"OnUpdate"\s*,\s*[^n]')


def git(*args):
    r = subprocess.run(["git"] + list(args), cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                       errors="replace")
    return r.returncode, r.stdout


class Tree:
    """Files at a commit (ref) or in the working tree (ref None)."""

    def __init__(self, ref=None):
        self.ref = ref

    def read(self, path):
        if self.ref is None:
            try:
                with open(os.path.join(ROOT, path), encoding="utf-8", errors="replace") as f:
                    return f.read()
            except OSError:
                return None
        code, out = git("show", "%s:%s" % (self.ref, path))
        return out if code == 0 else None


class Fake:
    """A tree from a dict (the selftest)."""

    def __init__(self, files):
        self.files = files

    def read(self, path):
        return self.files.get(path)


def toc_files(text):
    out = []
    for line in (text or "").splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            out.append(line.replace("\\", "/"))
    return out


def shipped(tree):
    return toc_files(tree.read(TOC)) + [p for p in EXTRA if tree.read(p) is not None]


def area_of(path):
    return path.split("/")[0] if "/" in path else "Core"


def latest_tag():
    _, out = git("tag", "--sort=-v:refname")
    tags = out.split()
    if not tags:
        sys.exit("release-audit: no tag to start from; give a ref")
    return tags[0]


def changed_files(old, new):
    """(path, old text, new text) of each shipped file that differs, Locales left out."""
    out = []
    for path in sorted(set(shipped(old)) | set(shipped(new))):
        if path.startswith("Locales/"):
            continue
        a, b = old.read(path), new.read(path)
        if (a or "").replace("\r\n", "\n") != (b or "").replace("\r\n", "\n"):
            out.append((path, a, b))
    return out


def file_diff(path, a, b):
    a = (a or "").replace("\r\n", "\n").splitlines(keepends=True)
    b = (b or "").replace("\r\n", "\n").splitlines(keepends=True)
    lines = list(difflib.unified_diff(a, b, "a/" + path, "b/" + path, n=CONTEXT))
    plus = sum(1 for l in lines if l.startswith("+") and not l.startswith("+++"))
    minus = sum(1 for l in lines if l.startswith("-") and not l.startswith("---"))
    return "".join(l if l.endswith("\n") else l + "\n" for l in lines), plus, minus


def parts(changed):
    """Areas, each cut in parts of about PART_LINES changed lines: [(name, [(path, diff, +, -)])]."""
    by_area = collections.OrderedDict()
    for path, a, b in changed:
        diff, plus, minus = file_diff(path, a, b)
        by_area.setdefault(area_of(path), []).append((path, diff, plus, minus))
    out = []
    for area, files in by_area.items():
        chunks, cur, size = [], [], 0
        for f in files:
            if cur and size + f[2] + f[3] > PART_LINES:
                chunks.append(cur)
                cur, size = [], 0
            cur.append(f)
            size += f[2] + f[3]
        chunks.append(cur)
        for i, chunk in enumerate(chunks):
            out.append(("%s-%d" % (area, i + 1) if len(chunks) > 1 else area, chunk))
    return out


def cmd_areas(args):
    out_dir = None
    if "--out" in args:
        i = args.index("--out")
        out_dir = args[i + 1]
        del args[i:i + 2]
    ref = args[0] if args else latest_tag()
    old, new = Tree(ref), Tree(None)
    found = parts(changed_files(old, new))
    if out_dir:
        if os.path.isdir(out_dir):
            shutil.rmtree(out_dir)
        os.makedirs(out_dir)
    total_plus = total_minus = 0
    for name, files in found:
        plus, minus = sum(f[2] for f in files), sum(f[3] for f in files)
        total_plus += plus
        total_minus += minus
        where = ""
        if out_dir:
            where = os.path.join(out_dir, name + ".diff")
            _, log = git("log", "--format=%h %s", "%s.." % ref, "--", *[f[0] for f in files])
            with open(where, "w", encoding="utf-8") as fh:
                fh.write("# Area %s, %s -> working tree. Commits since %s that touched it:\n" % (name, ref, ref))
                for l in log.splitlines() or ["(none: all uncommitted)"]:
                    fh.write("#   %s\n" % l)
                fh.write("\n")
                for f in files:
                    fh.write(f[1])
            where = " -> " + where
        print("%-16s %3d files  +%-5d -%-5d%s" % (name, len(files), plus, minus, where))
        for f in files:
            print("    %s  +%d -%d" % (f[0], f[2], f[3]))
    print("release audit: %d parts, %d files, +%d -%d shipped lines since %s"
          % (len(found), sum(len(f) for _, f in found), total_plus, total_minus, ref))


def counts(tree, files, pattern, group=1):
    c = collections.Counter()
    for path in files:
        text = tree.read(path)
        if text:
            for m in pattern.finditer(text):
                c[m.group(group) if group else path] += 1
    return c


def hooks(tree, files):
    c = collections.Counter()
    for path in files:
        for m in RE_HOOK.finditer(tree.read(path) or ""):
            c[m.group(1) + ("." + m.group(2) if m.group(2) else "")] += 1
    return c


def impact(old, new):
    """The flag lines, in order."""
    old_files, new_files = shipped(old), shipped(new)
    old_code = [p for p in old_files if not p.startswith("Locales/")]
    new_code = [p for p in new_files if not p.startswith("Locales/")]
    lines = []

    def gone_new(kind, a, b, gone_only=False):
        for k in sorted(set(a) - set(b)):
            lines.append("%-8s GONE  %s" % (kind, k))
        if not gone_only:
            for k in sorted(set(b) - set(a)):
                lines.append("%-8s NEW   %s" % (kind, k))

    la, lb = counts(old, old_code, RE_L), counts(new, new_code, RE_L)
    gone_new("LABEL", ['"%s"' % k for k in la], ['"%s"' % k for k in lb], gone_only=True)
    gone_new("PAGE", counts(old, old_code, RE_PAGE), counts(new, new_code, RE_PAGE))
    slash = ("Slash.lua", "SlashComplete.lua")
    gone_new("COMMAND", ["/cine " + k for k in counts(old, [p for p in old_code if p in slash], RE_CMD)],
             ["/cine " + k for k in counts(new, [p for p in new_code if p in slash], RE_CMD)])
    gone_new("BINDING", counts(old, ["Bindings.xml"], RE_BIND), counts(new, ["Bindings.xml"], RE_BIND))
    gone_new("CVAR", counts(old, old_code, RE_CVAR), counts(new, new_code, RE_CVAR))
    gone_new("TOC", [p for p in old_files if p not in EXTRA], [p for p in new_files if p not in EXTRA])
    ha = [l for l in (old.read(TOC) or "").splitlines() if l.startswith("##") and "Notes" not in l]
    hb = [l for l in (new.read(TOC) or "").splitlines() if l.startswith("##") and "Notes" not in l]
    for l in ha:
        if l not in hb:
            lines.append("TOC      WAS   %s" % l.strip())
    for l in hb:
        if l not in ha:
            lines.append("TOC      NOW   %s" % l.strip())
    a, b = hooks(old, old_code), hooks(new, new_code)
    for k in sorted(b):
        if b[k] > a.get(k, 0):
            lines.append("HOOK     NEW   %s%s" % (k, "" if not a.get(k) else "  (%d -> %d)" % (a[k], b[k])))
    for name, pattern in (("event", RE_EVENT), ("unit event", RE_UNIT_EVENT)):
        a, b = counts(old, old_code, pattern), counts(new, new_code, pattern)
        for k in sorted(b):
            if k in BUSY and b[k] > a.get(k, 0):
                lines.append("LOAD     MORE  %s %s: %d -> %d handlers" % (name, k, a.get(k, 0), b[k]))
    a, b = counts(old, old_code, RE_ONUPDATE, 0), counts(new, new_code, RE_ONUPDATE, 0)
    for k in sorted(b):
        if b[k] > a.get(k, 0):
            lines.append("LOAD     MORE  OnUpdate in %s: %d -> %d" % (k, a.get(k, 0), b[k]))
    return lines


def cmd_impact(args):
    ref = args[0] if args else latest_tag()
    new_ref = args[1] if len(args) > 1 else None
    lines = impact(Tree(ref), Tree(new_ref))
    for l in lines:
        print("  " + l)
    print("impact scan: %d flags for existing players, %s -> %s"
          % (len(lines), ref, new_ref or "working tree"))


def selftest():
    fails = []

    def check(name, cond):
        print("%s  %s" % ("PASS" if cond else "FAIL", name))
        if not cond:
            fails.append(name)

    old = Fake({
        "Cinematic.toc": "## Interface: 1\n## SavedVariables: CinematicDB\nCore.lua\nUI/Page.lua\nGone.lua\n",
        "Bindings.xml": '<Bindings><Binding name="CINE_TOGGLE"/><Binding name="CINE_OLD"/></Bindings>',
        "Core.lua": 'print(L["Fade the UI"])\nf:RegisterEvent("UNIT_AURA")\nSetCVar("nameplateShowAll", 1)\n',
        "UI/Page.lua": 'RegisterSubpage(c, "Old Page", x)\nL["Kept"]\n',
        "Slash.lua": "",
        "Gone.lua": "x = 1\n",
    })
    new = Fake({
        "Cinematic.toc": "## Interface: 2\n## SavedVariables: CinematicDB\nCore.lua\nUI/Page.lua\nSlash.lua\n",
        "Bindings.xml": '<Bindings><Binding name="CINE_TOGGLE"/></Bindings>',
        "Core.lua": ('print(L["Fade your UI"])\nf:RegisterEvent("UNIT_AURA")\ng:RegisterEvent("UNIT_AURA")\n'
                     'hooksecurefunc(PlayerFrame, "Show", fn)\nns.SetOnUpdate(f, fn)\n'
                     'f:RegisterEvent("PLAYER_LOGIN")\n'),
        "UI/Page.lua": 'RegisterSubpage(c, "New Page", x)\nL["Kept"]\n',
        "Slash.lua": 'if cmd == "why" then end\n',
    })
    lines = impact(old, new)
    text = "\n".join(lines)
    check("renamed label flagged", 'LABEL    GONE  "Fade the UI"' in text)
    check("kept label not flagged", '"Kept"' not in text)
    check("new label not flagged (only gone ones are)", "Fade your UI" not in text)
    check("page gone and new", "PAGE     GONE  Old Page" in text and "PAGE     NEW   New Page" in text)
    check("command new", "COMMAND  NEW   /cine why" in text)
    check("binding gone", "BINDING  GONE  CINE_OLD" in text and "CINE_TOGGLE" not in text)
    check("cvar no longer set", "CVAR     GONE  nameplateShowAll" in text)
    check("toc file gone and new", "TOC      GONE  Gone.lua" in text and "TOC      NEW   Slash.lua" in text)
    check("toc header changed", "TOC      WAS   ## Interface: 1" in text and "TOC      NOW   ## Interface: 2" in text)
    check("SavedVariables unchanged not flagged", "SavedVariables" not in text)
    check("new hook", "HOOK     NEW   PlayerFrame.Show" in text)
    check("busy event more", "LOAD     MORE  event UNIT_AURA: 1 -> 2 handlers" in text)
    check("quiet event not flagged", "PLAYER_LOGIN" not in text)
    check("new OnUpdate", "LOAD     MORE  OnUpdate in Core.lua: 0 -> 1" in text)
    check("same trees: no flags", impact(old, old) == [])

    changed = changed_files(old, new)
    names = [c[0] for c in changed]
    check("changed files: shipped only, gone file in", names == ["Bindings.xml", "Cinematic.toc", "Core.lua",
                                                                "Gone.lua", "Slash.lua", "UI/Page.lua"])
    check("line endings alone are no change", changed_files(
        Fake({TOC: "A.lua\n", "A.lua": "x\r\ny\r\n"}), Fake({TOC: "A.lua\n", "A.lua": "x\ny\n"})) == [])
    found = dict(parts(changed))
    check("areas: root files in Core, folders by name", "Core" in found and "UI" in found
          and [f[0] for f in found["UI"]] == ["UI/Page.lua"])
    big = [("UI/F%d.lua" % i, "", "x\n" * 1000) for i in range(4)]
    cut = parts(big)
    check("a big area is cut in parts", [n for n, _ in cut] == ["UI-1", "UI-2"]
          and all(sum(f[2] for f in fs) <= PART_LINES for _, fs in cut))
    check("a new file is in whole", parts([("A.lua", None, "a\nb\n")])[0][1][0][2] == 2)
    print("release-audit selftest: %s" % ("all passed" if not fails else "%d FAILED" % len(fails)))
    return not fails


def main():
    args = sys.argv[1:]
    if not args or args[0] not in ("areas", "impact", "selftest"):
        print(__doc__)
        sys.exit(2)
    if args[0] == "selftest":
        sys.exit(0 if selftest() else 1)
    (cmd_areas if args[0] == "areas" else cmd_impact)(args[1:])


if __name__ == "__main__":
    main()
