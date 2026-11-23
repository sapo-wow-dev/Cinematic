"""Searches the game's own UI source, as exported by the console's `exportInterfaceFiles code`, for known.py.

Each client's export sits next to its Wow.exe: <WoW>\\_forever_\\BlizzardInterfaceCode\\Interface\\AddOns (one per
client; make it at the login or character screen: start the game with -console, press `, type
`exportInterfaceFiles code`). It's Blizzard's code: read here, never copied into the repo (no-unlicensed-data).

One export holds every game flavor; each addon's .toc says which files load where ([AllowLoadGameType camelot],
## ExcludeLoadGameType: camelot, Camelot\\ folders). Forever is game type `camelot` (engine rule
forever.ui.game-type-camelot: Camelot's level frame showed on an NPC plate, 2026-11-23), and it passes `mainline`
gates too: Blizzard_PersonalResourceDisplay is "## AllowLoadGameType: mainline" and its frame was up on Forever
(prdKill test, 2026-11-22), with camelot-only lines inside it. What keeps a file off Forever is an exclude of camelot
(or an allow list without camelot or mainline). `standard` is retail-only (housing, delves). So each hit says whether
that file loads on the client, and a lookup gives the Camelot\\ copy first where one exists.

    python -I .claude/skills/test/gamesource.py <word> [word...]     (search, like known.py --only source)
    python -I .claude/skills/test/gamesource.py --template <Name> ...  (where a frame/template is made: file:line,
                                          loads or not, inherits, mixin, secure through which parent)
    python -I .claude/skills/test/gamesource.py --at "<Blizzard_X/File.lua:123, or a pasted stack>" [--client retail]
                                          (the game's code at each Blizzard frame of it)
    python -I .claude/skills/test/gamesource.py --selftest

(TOCs also say [Family]\\ and [Game]\\ for a flavor folder: Blizzard_UnitFrame lists [Family]\\PlayerFrameTemplates.xml
excluding camelot and [Game]\\PlayerFrameTemplates.xml for camelot, so on Forever [Game] is Camelot\\ and [Family]
looks like Mainline\\. A hit's folder decides: a Mainline\\ file under an "Exclude camelot" entry says no:.)
"""
import os
import re
import sys
import tempfile

WOW = r"C:\Program Files (x86)\World of Warcraft"
CLIENTS = {"_forever_": "forever", "_retail_": "retail", "_classic_era_": "classic_era"}
# The game types each client loads (see the docstring; classic_era is a guess).
TYPES = {"forever": {"camelot", "mainline"}, "retail": {"mainline", "standard"}, "classic_era": {"classic", "vanilla"}}
# Folder names that hold one flavor's files.
FOLDERS = {"camelot": "camelot", "mainline": "mainline", "standard": "standard", "classic": "classic",
           "vanilla": "vanilla", "tbc": "tbc", "wrath": "wrath", "cata": "cata", "mists": "mists",
           "plunderstorm": "plunderstorm", "wowhack": "wowhack"}
# The API docs are known.py's apidocs section already (Tools/engine/api), from the same files.
SKIP = {"blizzard_apidocumentationgenerated"}
TAG = re.compile(r"\[(Allow|Exclude)LoadGameType ([^\]]+)\]", re.I)
HEAD = re.compile(r"^##\s*(Allow|Exclude)LoadGameType:\s*(.+)$", re.I)


def exports(wow=WOW):
    """(client, AddOns folder) for each client with an export."""
    out = []
    for folder, client in CLIENTS.items():
        root = os.path.join(wow, folder, "BlizzardInterfaceCode", "Interface", "AddOns")
        if os.path.isdir(root):
            out.append((client, root))
    return out


def stale(root):
    """A line when Wow.exe is newer than the export (a patch since), else None."""
    exe = os.path.join(root.split(os.sep + "BlizzardInterfaceCode")[0], "Wow.exe")
    try:
        if os.path.getmtime(exe) > os.path.getmtime(root) + 60:
            return "Wow.exe is newer than this export: the game may have patched since; re-export to be sure"
    except OSError:
        pass
    return None


def types_of(text):
    return {t.strip().lower() for t in re.split(r"[,\s]+", text) if t.strip()}


def read_toc(addon_dir):
    """(header allow, header exclude, [(entry regex, allow, exclude)]) from the addon's .toc files."""
    allow, exclude, entries = set(), set(), []
    for name in os.listdir(addon_dir):
        if not name.lower().endswith(".toc"):
            continue
        with open(os.path.join(addon_dir, name), encoding="utf-8", errors="replace") as f:
            for raw in f:
                line = raw.strip()
                m = HEAD.match(line)
                if m:
                    (allow if m.group(1).lower() == "allow" else exclude).update(types_of(m.group(2)))
                    continue
                if not line or line.startswith("#"):
                    continue
                a, e = set(), set()
                for kind, words in TAG.findall(line):
                    (a if kind.lower() == "allow" else e).update(types_of(words))
                path = TAG.sub("", line).strip().replace("/", "\\").lower()
                # [Family] / [Game] stand for a flavor folder.
                pattern = re.escape(path).replace(re.escape("[family]"), r"[^\\]+").replace(re.escape("[game]"), r"[^\\]+")
                entries.append((re.compile("^%s$" % pattern), a, e))
    return allow, exclude, entries


def verdict(client, rel, toc):
    """'loads', 'no: <why>' or '?: <why>' for a file (path inside its addon folder) on that client."""
    want = TYPES.get(client, set())
    allow, exclude, entries = toc
    if allow and not allow & want:
        return "no: addon is %s only" % ", ".join(sorted(allow))
    if exclude & want:
        return "no: addon excludes %s" % ", ".join(sorted(exclude & want))
    low = rel.replace("/", "\\").lower()
    folder = next((FOLDERS[p] for p in low.split("\\")[:-1] if p in FOLDERS), None)
    if folder and folder not in want:
        return "no: %s folder" % folder
    for pattern, a, e in entries:
        if pattern.match(low):
            if a and not a & want:
                return "no: file is %s only" % ", ".join(sorted(a))
            if e & want:
                return "no: file excludes %s" % ", ".join(sorted(e & want))
            return "loads"
    if low.endswith(".toc"):
        return "loads"
    return "?: not in the .toc (an .xml may include it)"


def definition(line, words):
    """A line that defines a word (function, template, mixin, table key) ranks first."""
    low = line.lower()
    for w in words:
        if re.search(r"function [\w.:]*%s\b|name=\"%s\"|^\s*%s\s*=|\b%s\s*=\s*\{" % ((re.escape(w),) * 4), low):
            return True
    return False


def search(words, score, wow=WOW):
    """[(score, text)] for every source line with a word; known.py's ranking plus 1 for a definition."""
    hits = []
    found = exports(wow)
    if not found:
        return [(0, "(no game source exported: start the game with -console, at the character screen press ` and type"
                    " exportInterfaceFiles code; it lands in <client>\\BlizzardInterfaceCode)")]
    for client, root in found:
        warn = stale(root)
        if warn:
            hits.append((99, "%s: %s" % (client, warn)))
        for addon in sorted(os.listdir(root)):
            addon_dir = os.path.join(root, addon)
            if addon.lower() in SKIP or not os.path.isdir(addon_dir):
                continue
            toc = None
            for d, _, files in os.walk(addon_dir):
                for name in files:
                    if not name.lower().endswith((".lua", ".xml", ".toc")):
                        continue
                    path = os.path.join(d, name)
                    with open(path, encoding="utf-8", errors="replace") as f:
                        text = f.read()
                    low = text.lower()
                    if not any(w in low for w in words):
                        continue
                    toc = toc or read_toc(addon_dir)
                    rel = os.path.relpath(path, addon_dir)
                    v = verdict(client, rel, toc)
                    for n, line in enumerate(text.splitlines(), 1):
                        s = score(line, words)
                        if s:
                            s += 1 if definition(line, words) else 0
                            hits.append((s, "%s %s/%s:%d [%s]  %s" % (client, addon, rel.replace("\\", "/"), n, v,
                                                                     line.strip()[:220])))
    return hits


def walk(root, exts=(".lua", ".xml")):
    """(addon, path inside the addon, full path, toc) for every file of an export."""
    for addon in sorted(os.listdir(root)):
        addon_dir = os.path.join(root, addon)
        if addon.lower() in SKIP or not os.path.isdir(addon_dir):
            continue
        toc = None
        for d, _, files in os.walk(addon_dir):
            for name in sorted(files):
                if name.lower().endswith(exts):
                    toc = toc or read_toc(addon_dir)
                    path = os.path.join(d, name)
                    yield addon, os.path.relpath(path, addon_dir), path, toc


ATTR = re.compile(r'(\w+)\s*=\s*"([^"]*)"')


NAMED = re.compile(r'<(\w+)\b([^>]*\bname\s*=\s*"([^"]+)"[^>]*)>', re.S)
_XML = {}


def xml_index(client, root):
    """{lower name: [definition dicts]} for every named frame or template in one export's XML (once per run)."""
    if root in _XML:
        return _XML[root]
    index = {}
    for addon, rel, path, toc in walk(root, (".xml",)):
        with open(path, encoding="utf-8", errors="replace") as f:
            text = f.read()
        for m in NAMED.finditer(text):
            name = m.group(3)
            if "$parent" in name.lower():
                continue
            attrs = {k.lower(): v for k, v in ATTR.findall(m.group(2))}
            index.setdefault(name.lower(), []).append({
                "client": client, "name": name, "tag": m.group(1),
                "at": "%s/%s:%d" % (addon, rel.replace("\\", "/"), text.count("\n", 0, m.start()) + 1),
                "verdict": verdict(client, rel, toc), "virtual": attrs.get("virtual") == "true",
                "inherits": attrs.get("inherits", ""), "mixin": attrs.get("mixin", ""),
                "protected": attrs.get("protected") == "true",
            })
    _XML[root] = index
    return index


def secure_via(index, name, seen=None):
    """The template in this one's inherit chain that makes it secure (protected="true" or a Secure* template), or
    None. Only definitions that load on the client count."""
    seen = seen or set()
    if name.lower() in seen:
        return None
    seen.add(name.lower())
    if "secure" in name.lower() and name.lower() not in index:
        return name  # (the game's own C-side secure templates have no XML)
    for d in index.get(name.lower(), []):
        if d["verdict"].startswith("no:"):
            continue
        if d["protected"]:
            return d["name"]
        for parent in (p.strip() for p in d["inherits"].split(",") if p.strip()):
            if "secure" in parent.lower():
                return parent
            via = secure_via(index, parent, seen)
            if via:
                return via
    return None


def templates(names, wow=WOW):
    """Where each named frame or template is made in the XML, per client: [dict(client, name, at, verdict, tag,
    virtual, inherits, mixin, protected, secure)]. secure = the template in its inherit chain (itself included)
    that is protected="true" or Secure*, else None."""
    out = []
    for client, root in exports(wow):
        index = xml_index(client, root)
        for n in names:
            for d in index.get(n.lower(), []):
                out.append(dict(d, secure=secure_via(index, d["name"])))
    return out


def locate(fragment, client=None, wow=WOW):
    """The export files whose path ends with this stack path (Blizzard_X/.../File.lua, maybe cut off at its front):
    [(client, "addon/path", full path, verdict)]."""
    tail = fragment.replace("\\", "/").lower()
    tail = tail[tail.find("blizzard_"):] if "blizzard_" in tail else tail.rsplit("/", 1)[-1].lstrip(".")
    out = []
    for c, root in exports(wow):
        if client and c != client:
            continue
        if root not in _FILES:
            _FILES[root] = [("%s/%s" % (addon, rel.replace("\\", "/")), rel, path, toc)
                            for addon, rel, path, toc in walk(root)]
        for label, rel, path, toc in _FILES[root]:
            if label.lower().endswith(tail):
                out.append((c, label, path, verdict(c, rel, toc)))
    # (The file that loads first; on Forever its Camelot\ copy before the shared one: engine rule
    # forever.ui.game-type-camelot.)
    out.sort(key=lambda f: (f[3].startswith("no:"), "/camelot/" not in f[1].lower() if f[0] == "forever" else False))
    return out


_FILES = {}  # (each export's file list, once per run: many errors look up many frames)


# A Blizzard file and line in a stack: "[Interface/AddOns/Blizzard_X/Shared/F.lua]:1557",
# "...ddOns/Blizzard_X/F.lua:83" (the front cut off with "...").
FRAME = re.compile(r"(Blizzard_\w+(?:/[\w.-]+)+\.(?:lua|xml))\]?:(\d+)")


def explain(text, client=None, show=print, wow=WOW, most=2, around=2):
    """Under an error: the game's own code at its first Blizzard frames (file:line and the lines around it, from
    the export). Returns how many it showed."""
    shown, seen = 0, set()
    for m in FRAME.finditer(text or ""):
        key = (m.group(1).lower(), m.group(2))
        # ("in function <.../File.lua:107>" is where that function starts, not a frame: left out.)
        if key in seen or "in function <" in text[text.rfind("\n", 0, m.start()) + 1:m.start()]:
            continue
        seen.add(key)
        found = locate(m.group(1), client, wow)
        if not found:
            continue
        c, label, path, v = found[0]
        n = int(m.group(2))
        try:
            lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
        except OSError:
            continue
        show("      game code: %s %s:%d [%s]%s" % (c, label, n, v,
                                                 " (+%d more file(s) end so)" % (len(found) - 1) if len(found) > 1 else ""))
        for i in range(max(1, n - around), min(len(lines), n + around) + 1):
            show("      %s%5d  %s" % (">" if i == n else " ", i, lines[i - 1].rstrip()[:160]))
        shown += 1
        if shown >= most:
            break
    return shown


def selftest():
    import shutil
    tmp = tempfile.mkdtemp()
    try:
        root = os.path.join(tmp, "_forever_", "BlizzardInterfaceCode", "Interface", "AddOns")
        plates = os.path.join(root, "Blizzard_Plates")
        os.makedirs(os.path.join(plates, "Camelot"))
        os.makedirs(os.path.join(plates, "Mainline"))
        os.makedirs(os.path.join(root, "Blizzard_House"))
        with open(os.path.join(plates, "Blizzard_Plates.toc"), "w") as f:
            f.write("## Title: Plates\nPlates.lua\nPlates_Live.lua [ExcludeLoadGameType camelot]\n"
                    "Camelot\\Plates_Live.lua [AllowLoadGameType camelot]\n[Family]\\Bar.lua\n"
                    "Mainline\\Rogue.lua [AllowLoadGameType mainline] [ExcludeLoadGameType camelot]\n")
        files = {
            "Plates.lua": "function PlateMixin:SetExplicitValues(v)\n\tself.isFriend = v.isFriend;\nend\n",
            "Plates_Live.lua": "PREVIEW_TOKEN = \"preview\";\n",
            "Camelot\\Plates_Live.lua": "PREVIEW_TOKEN = \"preview\";\n",
            "Mainline\\Bar.lua": "-- SetExplicitValues bar\n",
            "Mainline\\Rogue.lua": "-- SetExplicitValues rogue\n",
            "Loose.lua": "-- SetExplicitValues loose\n",
        }
        for rel, text in files.items():
            with open(os.path.join(plates, rel), "w") as f:
                f.write(text)
        with open(os.path.join(root, "Blizzard_House", "Blizzard_House.toc"), "w") as f:
            f.write("## AllowLoadGameType: standard\nHouse.lua\n")
        with open(os.path.join(root, "Blizzard_House", "House.lua"), "w") as f:
            f.write("function House:SetExplicitValues() end\n")

        def score(text, words):
            return sum(1 for w in words if w in text.lower())
        hits = search(["setexplicitvalues"], score, tmp)
        got = {h[1].split(" [")[0].split(" ", 1)[1].rsplit(":", 1)[0]: (h[0], h[1].split("[", 1)[1].split("]")[0])
               for h in hits}
        want = {
            "Blizzard_Plates/Plates.lua": (2, "loads"),              # a definition: +1
            "Blizzard_Plates/Mainline/Bar.lua": (1, "loads"),        # [Family] entry, mainline loads on Forever
            "Blizzard_Plates/Mainline/Rogue.lua": (1, "no: file excludes camelot"),
            "Blizzard_Plates/Loose.lua": (1, "?: not in the .toc (an .xml may include it)"),
            "Blizzard_House/House.lua": (2, "no: addon is standard only"),
        }
        bad = [k for k in want if got.get(k) != want[k]] + [k for k in got if k not in want]
        live = search(["preview_token"], score, tmp)
        v = sorted(h[1].split("[", 1)[1].split("]")[0] for h in live)
        if v != ["loads", "no: file excludes camelot"]:
            bad.append("Plates_Live verdicts %s" % v)
        # A cut-off stack path both copies end with: the Camelot\ one, which loads on Forever, first.
        _FILES.clear()
        both = locate("...lates_Live.lua", "forever", tmp)
        if [f[1] for f in both] != ["Blizzard_Plates/Camelot/Plates_Live.lua", "Blizzard_Plates/Plates_Live.lua"]:
            bad.append("locate order %r" % both)
        if search(["x"], score, os.path.join(tmp, "nothing"))[0][0] != 0:
            bad.append("missing export hint")
        # Templates: where made, the inherit chain to a Secure* one, a no: file and $parent names left out.
        with open(os.path.join(plates, "Plates.xml"), "w") as f:
            f.write('<Ui>\n<Button name="PlateUnitTemplate" virtual="true" inherits="PlateBaseTemplate" mixin="PlateMixin">\n'
                    '</Button>\n<Frame name="PlateBaseTemplate" virtual="true" inherits="SecureUnitButtonTemplate"/>\n'
                    '<Frame name="$parentIcon"/>\n<Frame name="PlateLook" virtual="true" protected="true"/>\n</Ui>\n')
        with open(os.path.join(plates, "Mainline", "Rogue.xml"), "w") as f:
            f.write('<Ui><Frame name="RogueTemplate" virtual="true" inherits="SecureActionButtonTemplate"/></Ui>\n')
        with open(os.path.join(plates, "Blizzard_Plates.toc"), "a") as f:
            f.write("Plates.xml\nMainline\\Rogue.xml [AllowLoadGameType mainline] [ExcludeLoadGameType camelot]\n")
        _XML.clear()
        _FILES.clear()
        rows = {r["name"]: r for r in templates(["PlateUnitTemplate", "PlateLook", "RogueTemplate", "Nope"], tmp)}
        u = rows.get("PlateUnitTemplate", {})
        if (u.get("at"), u.get("mixin"), u.get("secure"), u.get("tag")) != (
                "Blizzard_Plates/Plates.xml:2", "PlateMixin", "SecureUnitButtonTemplate", "Button"):
            bad.append("template chain %r" % u)
        if rows.get("PlateLook", {}).get("secure") != "PlateLook":
            bad.append("protected=true %r" % rows.get("PlateLook"))
        if rows.get("RogueTemplate", {}).get("verdict") != "no: file excludes camelot" or "Nope" in rows:
            bad.append("rogue/nope %r" % rows)
        # A stack: the game's code at its Blizzard frames, a cut-off front found by its tail.
        said = []
        n = explain("Lua Error: ...zard_Plates/Plates.lua:2: boom\n[Interface/AddOns/Blizzard_Plates/Plates.lua]:2: in"
                    " function <Interface/AddOns/Blizzard_Plates/Plates.lua:1>", "forever", said.append, tmp)
        if n != 1 or not any("game code: forever Blizzard_Plates/Plates.lua:2 [loads]" in l for l in said) \
                or not any(l.startswith("      >    2  ") and "isFriend" in l for l in said):
            bad.append("explain %d %r" % (n, said))
        said = []
        explain("x [Interface/AddOns/Blizzard_Plates/Camelot/Plates_Live.lua]:1: in", "forever", said.append, tmp)
        if not any("Blizzard_Plates/Camelot/Plates_Live.lua:1 [loads]" in l for l in said):
            bad.append("explain the Camelot copy %r" % said)
        if explain("no frames here", "forever", said.append, tmp) != 0:
            bad.append("explain nothing")
        print("selftest: %s" % ("PASS" if not bad else "FAIL %s\n  got %s" % (bad, got)))
        return not bad
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    args = sys.argv[1:]
    if args == ["--selftest"]:
        sys.exit(0 if selftest() else 1)
    if args and args[0] == "--template":
        rows = templates(args[1:])
        for r in rows:
            print("  %s %s: %s [%s] <%s%s> inherits %s, mixin %s, %s" % (
                r["client"], r["name"], r["at"], r["verdict"], r["tag"], " virtual" if r["virtual"] else "",
                r["inherits"] or "-", r["mixin"] or "-", ("SECURE via " + r["secure"]) if r["secure"] else "not secure"))
        for n in sorted(set(n.lower() for n in args[1:]) - set(r["name"].lower() for r in rows)):
            print("  %s: in no export's XML (made in Lua, a C-side template, or not on these clients)" % n)
        sys.exit(0)
    if args and args[0] == "--at":
        who = None
        if "--client" in args:
            i = args.index("--client")
            who = args[i + 1] if i + 1 < len(args) else None
            del args[i:i + 2]
            if who and who not in [c for c, _ in exports()]:
                print("  no export for %s (have: %s)" % (who, ", ".join(c for c, _ in exports()) or "none"))
                sys.exit(0)
        if not explain(" ".join(args[1:]), who, most=20):
            print("  no Blizzard file:line found in it (or no export has that file)")
        sys.exit(0)
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import known  # noqa: E402
    words = [w.lower() for w in args]
    for _, text in sorted(search(words, known.score), key=lambda h: -h[0])[:25]:
        print("  " + text)
