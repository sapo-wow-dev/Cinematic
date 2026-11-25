"""The addon kit's touch points: every game frame and game global Cinematic's
own code touches, which files touch it, what they do to it and which
settings lead there. Another addon that replaces, hides or reskins one of
these is where our features can break (Tools/addon-kit-plan.md, part A).
From the repo root:

    python -I Tools/addon-kit/touchpoints.py            check against the saved registry
    python -I Tools/addon-kit/touchpoints.py --update   save what the code touches now
    python -I Tools/addon-kit/touchpoints.py --selftest its own checks

Two sources, merged per touch point (digits in a name become #, so
ChatFrame1..ChatFrame10 are one touch point, ChatFrame#):
1. Static: our files (not Dev/, Tools/, Libs/, Locales/), comments and
   player text left out, read for game frame names (bare names, "Name"
   strings, "Name" .. i built names). The game's names come from its own UI
   code as exported (BlizzardInterfaceCode, per client: only the names are
   read). A setting key (from ns.DEFAULTS) links to a touch point when a
   top-level block reads it and touches the frame, or does one of the two
   in a function it calls (one call deep).
2. Dynamic: the settings sweep on the stand-in in touch mode
   (Tools/addon-kit/touchmap.lua, both clients): each method called on a
   game frame and each hook, with the setting being changed then.

Saved in Tools/addon-kit/touchpoints.txt (generated; never edit by hand).
FAIL: a touch point the registry doesn't have, one it has that the code no
longer touches, a file added to or gone from a touch point's files, or a
setting that newly reaches a touch point (part G: a new feature on a game
frame, like chatPeekLinesOnly on ChatFrame#). Each is a change in what
another addon can break, so --update it in the same commit (an expectation
change: Tools/audit.py since lists it). What it does changing, or a setting
no longer reaching it, is a note. (A per-key list of settings that touch
nothing was tried and dropped, 2026-11-25: ~7000 keys, nearly all our own
frames' looks.)

Exit 1 on a FAIL. The game's folder: CINE_WOW, else the default.
"""
import glob
import os
import re
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
KIT = os.path.join(ROOT, "Tools", "addon-kit")
WOW = os.environ.get("CINE_WOW", r"C:\Program Files (x86)\World of Warcraft")
CLIENTS = {"forever": "_forever_", "retail": "_retail_"}
REGISTRY = os.path.join(KIT, "touchpoints.txt")
FORMAT = 1
MAP_FORMAT = 1
SKIP_DIRS = ("Dev/", "Tools/", "Libs/", "Locales/", "Release/", ".claude/")
READ = re.compile(r"^(Get|Is|Has|Can|Num)")


def family(name):
    return re.sub(r"\d+", "#", name)


# --- the game's names -----------------------------------------------------------

XML_NAME = re.compile(r'\bname="([A-Za-z_]\w+)"')
LUA_FRAME = re.compile(r'CreateFrame\(\s*"\w+"\s*,\s*"([A-Za-z_]\w+)"')
LUA_GLOBAL = re.compile(r"^(?:function\s+([A-Za-z_]\w*)[.:(]|([A-Za-z_]\w*)\s*=[^=])", re.M)


def game_names():
    """Global names the game's own UI code makes, from each client's export."""
    names, found = set(), []
    for client, folder in CLIENTS.items():
        base = os.path.join(WOW, folder, "BlizzardInterfaceCode")
        if not os.path.isdir(base):
            continue
        found.append(client)
        for dirpath, _, files in os.walk(base):
            for name in files:
                low = name.lower()
                if not (low.endswith(".xml") or low.endswith(".lua")):
                    continue
                with open(os.path.join(dirpath, name), encoding="utf-8", errors="replace") as f:
                    text = f.read()
                if low.endswith(".xml"):
                    names.update(XML_NAME.findall(text))
                else:
                    names.update(LUA_FRAME.findall(text))
                    for a, b in LUA_GLOBAL.findall(text):
                        names.add(a or b)
    names = {n for n in names if len(n) >= 4 and n[0].isupper() and not n.isupper()}
    return names, found


# --- static: our code -------------------------------------------------------------

def our_files():
    out = subprocess.run(["git", "ls-files", "*.lua"], cwd=ROOT, capture_output=True, text=True).stdout.split()
    return [f for f in out if not f.startswith(SKIP_DIRS)]


COMMENT_LONG = re.compile(r"--\[(=*)\[.*?\]\1\]", re.S)
COMMENT = re.compile(r"--[^\n]*")
PLAYER_TEXT = re.compile(r'\bL\[\s*"(?:[^"\\]|\\.)*"\s*\]')
STRING = re.compile(r'"((?:[^"\\\n]|\\.)*)"')


def strip(text):
    text = COMMENT_LONG.sub("", text)
    # (Comments, but not -- inside a string: good enough for this code base,
    # whose strings rarely hold "--".)
    text = COMMENT.sub("", text)
    return PLAYER_TEXT.sub('""', text)


def blocks(text):
    """Top-level blocks: split after each column-0 end / } / )."""
    out, cur = [], []
    for line in text.splitlines():
        cur.append(line)
        if re.match(r"^(end|\}|\))\b", line):
            out.append("\n".join(cur))
            cur = []
    if cur:
        out.append("\n".join(cur))
    return out


IDENT = re.compile(r"(?<![\w.:])([A-Z]\w{3,})\b")
BUILT = re.compile(r'"([A-Z]\w+)"\s*\.\.\s*[\w.\[\]()]+(?:\s*\.\.\s*"(\w+)")?')
DEFINES = re.compile(r"(?:\bfunction\s+((?:ns\.)?[A-Za-z_]\w*)\s*\(|\b((?:ns\.)?[A-Za-z_]\w*)\s*=\s*function\b)")
CALLS = re.compile(r"(?<![\w:])((?:ns\.)?[A-Za-z_]\w*)\s*\(")
# Settings pages: their touches count (the files list), but a page's controls
# sit in big blocks with tooltips on every one: no setting links from there.
# Font objects and API calls the game's UI code defines (GameFontNormal,
# GetCVar, C_Spell): touch points, but every page uses them, so no setting
# links (575 settings on GameFontNormalLarge, tried 2026-11-25).
NO_LINK = re.compile(r"Font|Template$|Mixin$|Util$|^Create|^StaticPopup|^(C_|Get|Set|Is|Has|Can)[A-Z_]")
SMALL_FN = 4
BIG_BLOCK = 16
FEATURE_FILE_POINTS = 15
FEATURE_FILE_SETTINGS = 60
MENU = re.compile(r"(Page|Pages|Options|PageDefaults|PageShots)\.lua$")


def static_touches(files, names, settings):
    """{touch point: {"files", "settings", "does"}} from our code. A setting
    links to a touch point when one top-level block reads the setting and
    touches the frame, or one of them happens in a function the block calls
    (one call deep: ns.X across files, a local function in its own file)."""
    fams = {}
    for n in names:
        fams.setdefault(family(n), set()).add(n)
    setting_re = None
    if settings:
        keys = sorted(settings, key=len, reverse=True)
        setting_re = re.compile(r'(?:\bdb\.|"\s*)(' + "|".join(re.escape(k) for k in keys) + r')\b')
    parsed = []  # (path, hits, linked, defines, calls)
    fn_sets, fn_hits = {}, {}
    for path in files:
        with open(os.path.join(ROOT, path), encoding="utf-8", errors="replace") as f:
            text = strip(f.read())
        for block in blocks(text):
            hit = set()
            for m in IDENT.finditer(block):
                if m.group(1) in names:
                    hit.add(family(m.group(1)))
            for m in STRING.finditer(block):
                if m.group(1) in names:
                    hit.add(family(m.group(1)))
            for m in BUILT.finditer(block):
                cand = m.group(1) + "#" + (m.group(2) or "")
                if cand in fams:
                    hit.add(cand)
            hit = {h for h in hit if not h.startswith("Cinematic")}
            linked = set(setting_re.findall(block)) if setting_re else set()
            defines = set()
            for a, b in DEFINES.findall(block):
                name = a or b
                defines.add(name if name.startswith("ns.") else path + ":" + name)
            calls = set()
            for name in CALLS.findall(block):
                calls.add(name if name.startswith("ns.") else path + ":" + name)
            calls -= defines
            parsed.append((path, hit, linked, defines, calls))
            for d in defines:
                fn_sets.setdefault(d, set()).update(linked)
                fn_hits.setdefault(d, set()).update(hit)
    touches = {}
    for path, hit, _, _, _ in parsed:
        for h in hit:
            touches.setdefault(h, {"files": set(), "settings": set(), "does": set()})["files"].add(path)
    for path, hit, linked, defines, calls in parsed:
        if MENU.search(path):
            continue
        reach_sets, reach_hits = set(linked), set(hit)
        for c in calls:
            # (Only a small function counts: a feature's own check, as
            # ns.ChatPeekLinesOnly. A hub that reads or touches many would
            # tie every setting to every frame: 800 a frame, tried 2026-11-25.)
            if len(fn_sets.get(c, ())) <= SMALL_FN:
                reach_sets |= fn_sets.get(c, set())
            if len(fn_hits.get(c, ())) <= SMALL_FN:
                reach_hits |= fn_hits.get(c, set())
        # (A block reading more settings than that is too big to tell which
        # one leads where: no links from it.)
        if len(reach_sets) > BIG_BLOCK:
            continue
        # (What a called function touches counts for linking, not for files:
        # the file that touches it is listed under its own block.)
        for h in reach_hits:
            if not NO_LINK.search(h):
                touches[h]["settings"].update(reach_sets)
    # A feature's own file: what it touches works on frames passed in
    # (UI/Chat.lua's chatFrame), so the setting and the frame's name never
    # meet in one block. A file that touches few game frames and reads few
    # settings is one feature: each of its settings links to each frame it
    # touches. (The big shared files are left to the block links.)
    by_file = {}
    for path, hit, linked, _, _ in parsed:
        f = by_file.setdefault(path, [set(), set()])
        f[0] |= hit
        f[1] |= linked
    for path, (hit, linked) in by_file.items():
        if MENU.search(path) or len(hit) > FEATURE_FILE_POINTS or len(linked) > FEATURE_FILE_SETTINGS:
            continue
        for h in hit:
            if not NO_LINK.search(h):
                touches[h]["settings"].update(linked)
    return touches


# --- dynamic: the sweep in touch mode ----------------------------------------------

def run_touchmap(client, out):
    proc = subprocess.run([sys.executable, "-I", "Tools/offline/run.py", "Tools/addon-kit/touchmap.lua", client, out],
                          cwd=ROOT, stdin=subprocess.DEVNULL, capture_output=True, text=True, encoding="utf-8",
                          errors="replace")
    return proc.returncode, proc.stdout + proc.stderr


def read_touchmap(path):
    """(touch lines [(path, method, file, settings)], DEFAULTS keys); refuses another format."""
    touches, keys = [], set()
    with open(path, encoding="utf-8") as f:
        head = f.readline()
        m = re.match(r"# addon-kit touch map, format (\d+)", head)
        if not m or int(m.group(1)) != MAP_FORMAT:
            raise ValueError("%s: not a touch map of format %d (%s)" % (path, MAP_FORMAT, head.strip()))
        for line in f:
            line = line.rstrip("\n")
            if line.startswith("T "):
                parts = line[2:].split("\t")
                if len(parts) == 4:
                    touches.append((parts[0], parts[1], parts[2], set(parts[3].split(",")) - {""}))
            elif line.startswith("D "):
                keys.add(line[2:].strip())
    return touches, keys


def merge_dynamic(touches, dyn, names, have_names):
    for path, method, file, settings in dyn:
        top = path.split(".")[0]
        hooked = method.startswith("(hook)")
        if top.startswith("Cinematic"):
            continue
        if have_names and top not in names and not hooked:
            continue
        if not have_names and not (hooked or top[0].isupper()):
            continue
        point = family(path)
        t = touches.setdefault(point if "." not in point else family(top), {"files": set(), "settings": set(),
                                                                           "does": set()})
        t["files"].add(file)
        sub = path[len(top):]
        t["does"].add(family(sub[1:] + ":" + method) if sub else method)
        if not READ.match(method):
            t["settings"].update(s for s in settings if not s.startswith("(") and not re.search(r"\s", s))


# --- the registry ----------------------------------------------------------------

def render(touches):
    lines = ["# addon-kit touch points, format %d. Generated by Tools/addon-kit/touchpoints.py --update:" % FORMAT,
             "# never edit by hand. Per game frame or global our code touches: the files, what they do",
             "# (offline sweep), the settings that lead there."]
    for point in sorted(touches):
        t = touches[point]
        lines.append(point)
        lines.append("\tfiles " + " ".join(sorted(t["files"])))
        if t["does"]:
            lines.append("\tdoes " + ", ".join(sorted(t["does"])))
        if t["settings"]:
            lines.append("\tsettings " + " ".join(sorted(t["settings"])))
    return "\n".join(lines) + "\n"


def parse(text, path="registry"):
    lines = text.splitlines()
    m = re.match(r"# addon-kit touch points, format (\d+)", lines[0] if lines else "")
    if not m or int(m.group(1)) != FORMAT:
        raise ValueError("%s: not touch points of format %d (made by another version: --update)" % (path, FORMAT))
    out, cur = {}, None
    for line in lines[1:]:
        if not line or line.startswith("#"):
            continue
        if not line.startswith("\t"):
            cur = out.setdefault(line.strip(), {"files": set(), "settings": set(), "does": set()})
            continue
        word, _, rest = line.strip().partition(" ")
        if cur is None:
            continue
        if word == "files":
            cur["files"] = set(rest.split())
        elif word == "settings":
            cur["settings"] = set(rest.split())
        elif word == "does":
            cur["does"] = set(x.strip() for x in rest.split(", ") if x.strip())
    return out


HOOKS_LUA = os.path.join(ROOT, "Dev", "AddonKitTouches.lua")
UNPROBED = os.path.join(KIT, "unprobed.txt")


def hooks_lua(touches):
    """Dev/AddonKitTouches.lua: every touch point, and every game function and method we hook."""
    lines = ["-- Generated by Tools/addon-kit/touchpoints.py --update from touchpoints.txt: never edit by hand.",
             "-- Every touch point (a game frame or global our code touches) and every game function and",
             "-- method it hooks, for the addon kit's generated probes (Dev/AddonKitProbes.lua). A family",
             "-- (ChatFrame#) is read on its members 1 to 20.",
             "local _, ns = ...", "ns.AddonKit.TOUCHES = {"]
    for point in sorted(touches):
        lines.append('	"%s",' % point)
    lines += ["}", "ns.AddonKit.HOOKS = {"]
    for point in sorted(touches):
        target = point.replace("#", "1")
        for does in sorted(touches[point]["does"]):
            if does == "(hook)":
                lines.append('\t{ point = "%s", target = "%s" },' % (point, target))
            elif does.startswith("(hook) "):
                lines.append('\t{ point = "%s", target = "%s", method = "%s" },' % (point, target, does[7:]))
    lines.append("}")
    return "\n".join(lines) + "\n"


def kit_coverage(scratch):
    """([(probe, touch point)], problems): the probes' P lines, run offline on both clients."""
    out, problems = [], []
    for client in CLIENTS:
        path = os.path.join(scratch, "kit-%s.txt" % client)
        proc = subprocess.run([sys.executable, "-I", "Tools/offline/run.py", "Tools/addon-kit/kitrun.lua", client, path],
                              cwd=ROOT, stdin=subprocess.DEVNULL, capture_output=True, text=True, encoding="utf-8",
                              errors="replace")
        if proc.returncode != 0 or not os.path.exists(path):
            problems.append("the probes didn't run offline on %s: %s" % (client, (proc.stdout + proc.stderr)[-300:]))
            continue
        with open(path, encoding="utf-8") as f:
            for line in f:
                if line.startswith("P "):
                    probe, _, points = line[2:].rstrip("\n").partition("\t")
                    out += [(probe, p) for p in points.split(",") if p]
                elif line.startswith("E "):
                    problems.append("probe errored offline on %s: %s" % (client, line[2:].strip()))
    return out, problems


def read_unprobed():
    """{touch point: why it has no probe} from unprobed.txt (kept by hand: never written by --update)."""
    out = {}
    if os.path.exists(UNPROBED):
        with open(UNPROBED, encoding="utf-8") as f:
            for line in f:
                line = line.rstrip("\n")
                if line.strip() and not line.startswith("#"):
                    point, _, why = line.strip().partition(" ")
                    out[point] = why.strip()
    return out


PROBE = re.compile(r'id\s*=\s*"([\w.]+)".*?touches\s*=\s*\{([^}]*)\}', re.S)


def probe_touches(root=None):
    """[(probe id, touch point)] from the addon kit's probes (Dev/AddonKit*.lua)."""
    out = []
    for path in sorted(glob.glob(os.path.join(root or ROOT, "Dev", "AddonKit*.lua"))):
        with open(path, encoding="utf-8", errors="replace") as f:
            text = COMMENT.sub("", f.read())
        for m in PROBE.finditer(text):
            for point in re.findall(r'"([^"]+)"', m.group(2)):
                out.append((m.group(1), point))
    return out


def compare(old, new):
    """(fails, notes) between two registries."""
    fails, notes = [], []
    for point in sorted(set(new) - set(old)):
        fails.append("new touch point %s (files: %s)" % (point, " ".join(sorted(new[point]["files"]))))
    for point in sorted(set(old) - set(new)):
        fails.append("touch point gone: %s (was: %s)" % (point, " ".join(sorted(old[point]["files"]))))
    for point in sorted(set(old) & set(new)):
        a, b = old[point], new[point]
        for f in sorted(b["files"] - a["files"]):
            fails.append("%s: newly touched by %s" % (point, f))
        for f in sorted(a["files"] - b["files"]):
            fails.append("%s: no longer touched by %s" % (point, f))
        # (A setting that newly reaches a game frame is a new way for another
        # addon to break us there: chatPeekLinesOnly on ChatFrame#.)
        for key in sorted(b["settings"] - a["settings"]):
            fails.append("%s: setting %s newly reaches it" % (point, key))
        gone = a["settings"] - b["settings"]
        if gone:
            notes.append("%s: %d settings no longer reach it (%s)" % (point, len(gone), " ".join(sorted(gone)[:5])))
        if b["does"] != a["does"]:
            notes.append("%s: does +%d -%d" % (point, len(b["does"] - a["does"]), len(a["does"] - b["does"])))
    return fails, notes


# --- the run ---------------------------------------------------------------------

def build(scratch):
    names, have = game_names()
    with ThreadPoolExecutor(len(CLIENTS)) as pool:
        jobs = {c: pool.submit(run_touchmap, c, os.path.join(scratch, "touchmap-%s.txt" % c)) for c in CLIENTS}
    dyn, keys, problems = [], set(), []
    for client, job in jobs.items():
        code, output = job.result()
        path = os.path.join(scratch, "touchmap-%s.txt" % client)
        if code != 0 or not os.path.exists(path):
            problems.append("touch map %s didn't finish: %s" % (client, output.strip().splitlines()[-1:]))
            continue
        t, k = read_touchmap(path)
        dyn += t
        # (Keys with a space, tabOn:Style Overrides:1, are which tab a page
        # shows, not a feature; the registry lists keys space-separated.)
        keys |= {key for key in k if not re.search(r"\s", key)}
    touches = static_touches(our_files(), names, keys)
    merge_dynamic(touches, dyn, names, bool(names))
    return touches, keys, have, problems


def main():
    if "--selftest" in sys.argv:
        sys.exit(selftest())
    update = "--update" in sys.argv
    scratch = tempfile.mkdtemp(prefix="cine-touch-")
    touches, keys, have, problems = build(scratch)
    for p in problems:
        print("FAIL " + p)
    if problems:
        sys.exit(1)
    if not have:
        print("note: no BlizzardInterfaceCode export in any client: only the sweep's touches (export it: "
              "`exportInterfaceFiles code` in the game's console)")
    linked = set()
    for t in touches.values():
        linked |= t["settings"]
    if update:
        with open(REGISTRY, "w", encoding="utf-8", newline="\n") as f:
            f.write(render(touches))
        with open(HOOKS_LUA, "w", encoding="utf-8", newline="\n") as f:
            f.write(hooks_lua(touches))
        probed, problems = kit_coverage(scratch)
        for p in problems:
            print("FAIL " + p)
        covered = {point for _, point in probed}
        missing = sorted(set(touches) - covered - set(read_unprobed()))
        if missing:
            print("note %d touch points have no probe and aren't in unprobed.txt (the check FAILs on them): %s" % (
                len(missing), " ".join(missing[:30])))
        print("touchpoints: %d saved (%s), %d of %d settings reach one" % (
            len(touches), "game names from " + "+".join(have) if have else "no game names", len(linked & keys),
            len(keys)))
        return
    if not os.path.exists(REGISTRY):
        print("FAIL no registry yet: --update")
        sys.exit(1)
    with open(REGISTRY, encoding="utf-8") as f:
        try:
            old = parse(f.read(), REGISTRY)
        except ValueError as err:
            print("FAIL %s" % err)
            sys.exit(1)
    fails, notes = compare(old, touches)
    with open(HOOKS_LUA, encoding="utf-8") if os.path.exists(HOOKS_LUA) else open(os.devnull) as f:
        if f.read().replace("\r\n", "\n") != hooks_lua(old):
            fails.append("Dev/AddonKitTouches.lua isn't the registry's: --update")
    probed, problems = kit_coverage(scratch)
    fails += problems
    for probe, point in probed:
        if point not in touches:
            fails.append("probe %s names touch point %s, which the code doesn't touch (a typo, or gone)" % (probe, point))
    covered = {point for _, point in probed} & set(touches)
    unprobed = read_unprobed()
    for point in sorted(set(touches) - covered - set(unprobed)):
        fails.append("%s has no probe: write one (Dev/AddonKitProbes.lua) or list it in unprobed.txt with why" % point)
    for point in sorted(set(unprobed) & covered):
        notes.append("%s has a probe now: take it off unprobed.txt" % point)
    for point in sorted(set(unprobed) - set(touches)):
        notes.append("%s is in unprobed.txt but the code no longer touches it: take it off" % point)
    notes.insert(0, "%d of %d touch points have a probe; %d listed in unprobed.txt (%d unreviewed)" % (
        len(covered), len(touches), len(set(unprobed) & set(touches)),
        sum(1 for p, why in unprobed.items() if why.startswith("unreviewed") and p in touches)))
    for n in notes[:20]:
        print("note " + n)
    if len(notes) > 20:
        print("note ... %d more" % (len(notes) - 20))
    for x in fails[:60]:
        print("FAIL " + x)
    if len(fails) > 60:
        print("FAIL ... %d more" % (len(fails) - 60))
    print("touchpoints: %d touch points, %d of %d settings reach one, %d FAIL%s" % (
        len(touches), len(linked & keys), len(keys), len(fails),
        " (each a change in what another addon can break: --update in the same commit)" if fails else ""))
    sys.exit(1 if fails else 0)


def selftest():
    bad = []

    def check(name, ok):
        if not ok:
            bad.append(name)
        print(("PASS " if ok else "FAIL ") + name)

    check("family: digits become #", family("ChatFrame10EditBox") == "ChatFrame#EditBox")
    names = {"ChatFrame1", "ChatFrame2", "ChatFrame1Tab", "GameTooltip", "PlayerFrame"}
    code = ('local f = _G["ChatFrame" .. i .. "Tab"]\nlocal x = ns.db.chatPeek\nend\n'
            '-- PlayerFrame in a comment\nGameTooltip:SetOwner(UIParent)\nlocal s = L["PlayerFrame"]\nend\n')
    tmp = tempfile.mkdtemp(prefix="cine-touch-self-")
    with open(os.path.join(tmp, "A.lua"), "w") as f:
        f.write(code)
    global ROOT, FEATURE_FILE_POINTS
    was, ROOT = ROOT, tmp
    # (Block links alone here: the feature-file link is checked on its own below.)
    points, FEATURE_FILE_POINTS = FEATURE_FILE_POINTS, 0
    try:
        t = static_touches(["A.lua"], names, {"chatPeek"})
    finally:
        ROOT, FEATURE_FILE_POINTS = was, points
    check("built name found as its family", "ChatFrame#Tab" in t)
    check("setting in the same block links", "ChatFrame#Tab" in t and t["ChatFrame#Tab"]["settings"] == {"chatPeek"})
    check("bare name found", "GameTooltip" in t)
    check("setting in another block doesn't link", "GameTooltip" in t and not t["GameTooltip"]["settings"])
    check("comments and player text left out", "PlayerFrame" not in t)
    # (The miss behind this kit: chatPeekLinesOnly is read in a function of
    # its own, and the chat frames are touched where that function is called.)
    with open(os.path.join(tmp, "B.lua"), "w") as f:
        f.write("function ns.LinesOnly()\n\treturn ns.db.chatLinesOnly\nend\n"
                "local function Peek()\n\tif ns.LinesOnly() then ChatFrame2:SetAlpha(0) end\nend\n")
    ROOT = tmp
    try:
        t3 = static_touches(["B.lua"], names, {"chatLinesOnly"})
    finally:
        ROOT = was
    check("a setting read in a called function links (one call deep)",
          "ChatFrame#" in t3 and "chatLinesOnly" in t3["ChatFrame#"]["settings"])
    # (As UI/Chat.lua: the frame is a parameter where the setting is read.)
    with open(os.path.join(tmp, "C.lua"), "w") as f:
        f.write("local function Copy(chatFrame)\n\tif ns.db.chatCopyLines then chatFrame:SetAlpha(0) end\nend\n"
                "local function Hook()\n\thooksecurefunc(ChatFrame1, \"AddMessage\", Copy)\nend\n")
    ROOT = tmp
    try:
        t4 = static_touches(["C.lua"], names, {"chatCopyLines"})
    finally:
        ROOT = was
    check("a small feature file links its settings to its frames",
          "ChatFrame#" in t4 and "chatCopyLines" in t4["ChatFrame#"]["settings"])
    reg = render(t)
    check("render and parse round trip", compare(parse(reg), t) == ([], []))
    try:
        parse(reg.replace("format %d" % FORMAT, "format 999"))
        check("another format refused", False)
    except ValueError:
        check("another format refused", True)
    new = dict(parse(reg))
    new["NewFrame"] = {"files": {"B.lua"}, "settings": set(), "does": set()}
    fails, _ = compare(parse(reg), new)
    check("a new touch point FAILs", any("new touch point NewFrame" in x for x in fails))
    dyn = [("ChatFrame3", "(hook) AddMessage", "UI/ChatCopy.lua", {"(load)"}),
           ("Minimap.ZoomIn", "Hide", "Style/MinimapStyle.lua", {"mmHideZoom"}),
           ("UnitName", "IsShown", "X.lua", {"(load)"})]
    t2 = {}
    merge_dynamic(t2, dyn, {"ChatFrame3", "Minimap"}, True)
    check("dynamic: a hook kept", "ChatFrame#" in t2 and "(hook) AddMessage" in t2["ChatFrame#"]["does"])
    check("dynamic: field method under its frame", "Minimap" in t2 and "ZoomIn:Hide" in t2["Minimap"]["does"])
    check("dynamic: a write links its setting", "Minimap" in t2 and t2["Minimap"]["settings"] == {"mmHideZoom"})
    check("dynamic: not a game name, left out", "UnitName" not in t2)
    print("touchpoints selftest: %d FAIL" % len(bad))
    return 1 if bad else 0


if __name__ == "__main__":
    main()
