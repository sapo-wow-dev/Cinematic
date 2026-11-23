"""Cinematic performance analyzer: reads the profiler's saved recordings and
ranks what costs the most, with the code behind each and what to try.

    python Tools/perf/analyze.py                 # newest recording, any client
    python Tools/perf/analyze.py --client forever
    python Tools/perf/analyze.py --all            # every client's newest
    python Tools/perf/analyze.py --top 15 --no-save
    python Tools/perf/analyze.py --selftest       # the addon ranking's parser, offline

Reads CinematicDB.profiler (the Profiler page's / `/cine profiler` recording:
`last`, `digest`, `samples`) from each client's SavedVariables, keeps every
recording it sees in Tools/perf/history/ (so trends survive the game
overwriting `last`), and writes the report to Tools/perf/reports/.

What it ranks (see ISSUE KINDS in the report): steady cost per frame, hitches
(calls that take over a millisecond each), garbage, calls made too often,
time no timer covers, and changes against earlier recordings of the same
kind. It also ranks Cinematic among the addons loaded with it, from the
game's own figures saved with the recording (CinematicDB.profiler.addons). Each issue carries the function's source, what in its body looks costly
(tables, closures, strings, loops, game calls) and concrete things to try.
The /perf skill (.claude/skills/perf) reads this and then the code in full.
"""
import argparse
import glob
import json
import os
import re
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
WOW = r"C:\Program Files (x86)\World of Warcraft"
CLIENTS = {"forever": "_forever_", "retail": "_retail_", "classic": "_classic_era_"}
HISTORY = os.path.join(HERE, "history")
LOGIN_SETTLE = 180  # seconds after a /reload before a recording reads steady
REPORTS = os.path.join(HERE, "reports")

# ---------------------------------------------------------------- loading


def lua_runtime():
    try:
        import lupa
    except ImportError:
        sys.exit("needs lupa: pip install lupa")
    return lupa, lupa.LuaRuntime(unpack_returned_tuples=True)


def to_py(lupa, value, depth=0):
    """A Lua table as dicts/lists (array tables as lists)."""
    if lupa.lua_type(value) != "table" or depth > 12:
        return value
    keys = list(value.keys())
    if keys and all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)):
        return [to_py(lupa, value[k], depth + 1) for k in range(1, len(keys) + 1)]
    return {str(k): to_py(lupa, value[k], depth + 1) for k in keys}


def read_profiler(path):
    """CinematicDB.profiler (and the log's cpu lines) from one SavedVariables file."""
    lupa, L = lua_runtime()
    with open(path, encoding="utf-8", errors="replace") as f:
        src = f.read()
    # (Only the profiler table and the log: the rest of the file is settings.
    # Running the whole file is simplest and fast enough, ~1 s for 6 MB.)
    L.execute(src)
    db = L.globals().CinematicDB
    if db is None:
        return None, []
    prof = to_py(lupa, db["profiler"]) if db["profiler"] is not None else None
    log = to_py(lupa, db["log"]) if db["log"] is not None else []
    bench = to_py(lupa, db["perfHistory"]) if db["perfHistory"] is not None else []
    read_profiler.bench = bench if isinstance(bench, list) else []
    return prof, log if isinstance(log, list) else []


def sv_files(client=None):
    out = []
    for name, folder in CLIENTS.items():
        if client and client != name:
            continue
        for path in glob.glob(os.path.join(WOW, folder, "WTF", "Account", "*", "SavedVariables", "Cinematic*.lua")):
            if path.endswith(".bak") or path.endswith(".old"):
                continue
            out.append((name, path))
    return out


STATE_RE = re.compile(r"(CineMode|normal UI), camera (\S+), (in combat|out of combat), (\w+), ([^,]+), "
                      r"(\d+) faded frames, (\d+) nameplates")


def parse_state(text):
    m = STATE_RE.search(text or "")
    if not m:
        return {}
    return {"mode": m.group(1), "camera": m.group(2), "combat": m.group(3) == "in combat", "group": m.group(4),
            "place": m.group(5), "faded": int(m.group(6)), "plates": int(m.group(7))}


def recording_from(client, path, prof):
    last = (prof or {}).get("last")
    if not isinstance(last, dict) or not last.get("sections"):
        return None
    rec = dict(last)
    rec["client"] = client
    rec["source"] = os.path.basename(path)
    rec["start"] = parse_state(last.get("startState"))
    rec["end"] = parse_state(last.get("endState"))
    rec["digest"] = prof.get("digest") if isinstance(prof.get("digest"), list) else []
    rec["samples"] = summarize_samples(prof.get("samples"))
    rec["addons"] = parse_addons(prof.get("addons"))
    return rec


ADDON_LINE = re.compile(r"^(.+?): now ([\d.]+), average ([\d.]+), worst ([\d.]+)$")
OURS = ("Cinematic", "CinematicDev")


def parse_addons(lines):
    """The Profiler page's line per loaded addon (ProfilerPage.lua AddonLines: the game's own figures, in ms a
    frame: now = RecentAverageTime, average = SessionAverageTime, worst = PeakTime) as dicts."""
    out = []
    for line in lines if isinstance(lines, list) else []:
        m = ADDON_LINE.match(str(line).strip())
        if m:
            out.append({"name": m.group(1), "now": float(m.group(2)), "average": float(m.group(3)),
                        "worst": float(m.group(4))})
    return out


def addon_rank(addons, top=5):
    """Lines on where Cinematic stands among the addons loaded with it, by the game's session average and its
    worst frame (ms, never %)."""
    if not addons:
        return []
    out = []
    by_avg = sorted(addons, key=lambda a: -a["average"])
    by_worst = sorted(addons, key=lambda a: -a["worst"])
    total = sum(a["average"] for a in addons)
    ours = [a for a in addons if a["name"] in OURS]
    for a in ours:
        out.append("- **%s: #%d of %d by the game's session average (%.3f ms a frame), #%d by its worst frame "
                   "(%.2f ms)**; all addons together %.3f ms a frame." % (
                       a["name"], by_avg.index(a) + 1, len(addons), a["average"], by_worst.index(a) + 1, a["worst"],
                       total))
    if not ours:
        out.append("- Cinematic isn't in the game's addon list for this recording.")
    if len([a for a in ours if a["average"] > 0]) > 1:
        out.append("- **Both Cinematic and CinematicDev were running**: each pays its own cost, so the figures "
                   "above count Cinematic twice. Record with one of them only.")
    out.append("- (The game's figures are over the whole session, not just this recording; a deep recording's "
               "wrapper cost is in them.)")
    out.append("- Top %d by session average: %s." % (min(top, len(by_avg)), ", ".join(
        "%s %.3f" % (a["name"], a["average"]) for a in by_avg[:top])))
    return out


def summarize_samples(samples):
    """Per-second graph samples: how spiky the session was, per state."""
    if not isinstance(samples, dict):
        return None
    addon = samples.get("addon") or []
    state = samples.get("state") or []
    if not addon:
        return None
    vals = [v for v in addon if isinstance(v, (int, float))]
    if not vals:
        return None
    vals_sorted = sorted(vals)

    def pct(p):
        return vals_sorted[min(len(vals_sorted) - 1, int(len(vals_sorted) * p))]

    by_state = {}
    for i, v in enumerate(addon):
        if not isinstance(v, (int, float)):
            continue
        s = state[i] if i < len(state) else None
        by_state.setdefault(str(s), []).append(v)
    return {"count": len(vals), "mean": sum(vals) / len(vals), "p50": pct(0.5), "p90": pct(0.9), "p99": pct(0.99),
            "max": vals_sorted[-1], "by_state": {k: sum(v) / len(v) for k, v in by_state.items()}}


def since_login(log, rec):
    """Seconds from the last /reload or login to the recording's start (from
    the log's "session: ----" line), or None. The first minutes after one
    carry builds that end on their own (settings pages and slots made ahead),
    so a recording started then reads high."""
    start_line = None
    for i, line in enumerate(log):
        if isinstance(line, str) and ("Detailed CPU recording" in line or "cmd: /cine profiler" in line):
            start_line = i
    if start_line is None:
        return None
    def secs(line):
        m = re.match(r"(\d\d):(\d\d):(\d\d)", line)
        return int(m.group(1)) * 3600 + int(m.group(2)) * 60 + int(m.group(3)) if m else None
    started = secs(log[start_line])
    for line in reversed(log[:start_line]):
        if isinstance(line, str) and "session: ----" in line:
            at = secs(line)
            if at is not None and started is not None:
                return (started - at) % 86400
            return None
    return None


def save_history(rec):
    os.makedirs(HISTORY, exist_ok=True)
    key = "%s-%s.json" % (rec["client"], int(rec.get("finished") or 0))
    path = os.path.join(HISTORY, key)
    if not os.path.exists(path):
        with open(path, "w", encoding="utf-8") as f:
            json.dump(rec, f)
    return path


def load_history():
    out = []
    for path in sorted(glob.glob(os.path.join(HISTORY, "*.json"))):
        try:
            with open(path, encoding="utf-8") as f:
                out.append(json.load(f))
        except (OSError, ValueError):
            pass
    return out


# ---------------------------------------------------------------- source index

FUNC_RE = re.compile(r"^\s*(local\s+)?function\s+([\w.:]+)\s*\(", re.M)
ASSIGN_RE = re.compile(r"^\s*(ns(?:\.\w+)+)\s*=\s*(?:ns\.Profiled\([^,]+,\s*)?function\s*\(", re.M)
PROFILED_RE = re.compile(r"""ns\.Profiled\(\s*["']([^"']+)["']""")
PROFNAME_RE = re.compile(r"""ns\.ProfileName\(\s*([\w.]+)\s*,\s*["']([^"']+)["']""")


def lua_sources():
    files = []
    for root, dirs, names in os.walk(REPO):
        rel = os.path.relpath(root, REPO)
        parts = rel.replace("\\", "/").split("/")
        if parts[0] in (".git", "Tools", "Libs", "Release", "docs", ".claude"):
            dirs[:] = []
            continue
        for n in names:
            if n.endswith(".lua"):
                files.append(os.path.join(root, n))
    return files


def strip_code(text):
    """Comments and strings blanked (same length, newlines kept) for scanning."""
    out = []
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if text.startswith("--", i):
            m = re.match(r"--\[(=*)\[", text[i:])
            if m:
                close = "]" + m.group(1) + "]"
                j = text.find(close, i)
                j = n if j < 0 else j + len(close)
            else:
                j = text.find("\n", i)
                j = n if j < 0 else j
            out.append(re.sub(r"[^\n]", " ", text[i:j]))
            i = j
            continue
        m = re.match(r"\[(=*)\[", text[i:i + 10]) if c == "[" else None
        if m:
            close = "]" + m.group(1) + "]"
            j = text.find(close, i + 2)
            j = n if j < 0 else j + len(close)
            out.append(re.sub(r"[^\n]", " ", text[i:j]))
            i = j
            continue
        if c in "\"'":
            j = i + 1
            while j < n and text[j] != c and text[j] != "\n":
                j += 2 if text[j] == "\\" else 1
            j = min(n, j + 1)
            out.append(c + " " * (j - i - 2) + c if j - i >= 2 else text[i:j])
            i = j
            continue
        out.append(c)
        i += 1
    return "".join(out)


OPEN_RE = re.compile(r"\b(function|if|do|repeat|end|until)\b")


def body_end(clean, start):
    """Index just past the `end` that closes the function starting at start."""
    depth = 0
    for m in OPEN_RE.finditer(clean, start):
        w = m.group(1)
        if w in ("function", "if", "do", "repeat"):
            depth += 1
        else:
            depth -= 1
            if depth == 0:
                return m.end()
    return len(clean)


class Index:
    def __init__(self):
        self.defs = {}      # name -> [(file, line, start, end)]
        self.files = {}     # file -> (text, clean)
        self.labels = {}    # profiled label -> [(file, line)]
        self.locals_by_file = {}
        for path in lua_sources():
            try:
                with open(path, encoding="utf-8", errors="replace") as f:
                    text = f.read()
            except OSError:
                continue
            clean = strip_code(text)
            rel = os.path.relpath(path, REPO).replace("\\", "/")
            self.files[rel] = (text, clean)
            local_names = set()
            for m in FUNC_RE.finditer(clean):
                full = m.group(2)
                short = full.split(".")[-1].split(":")[-1]
                start = m.start(2) - len("function ") if True else m.start()
                start = clean.rfind("function", 0, m.end())
                end = body_end(clean, start)
                line = clean.count("\n", 0, m.start(2)) + 1
                for key in {full, short, "ns." + short if full.startswith("ns.") else full}:
                    self.defs.setdefault(key, []).append((rel, line, start, end))
                if m.group(1):
                    local_names.add(short)
            for m in ASSIGN_RE.finditer(clean):
                full = m.group(1)
                start = clean.find("function", m.start())
                end = body_end(clean, start)
                line = clean.count("\n", 0, m.start(1)) + 1
                self.defs.setdefault(full, []).append((rel, line, start, end))
                self.defs.setdefault(full.split(".")[-1], []).append((rel, line, start, end))
            for m in PROFILED_RE.finditer(text):
                line = text.count("\n", 0, m.start()) + 1
                self.labels.setdefault(m.group(1), []).append((rel, line))
                # (the function given to it, when inline: its body is the label's)
                fn_at = clean.find("function", m.end())
                nl = clean.find("\n", m.end())
                same_stmt = fn_at >= 0 and (fn_at < nl or nl < 0 or fn_at - m.end() < 40)
                if same_stmt and clean[m.end():fn_at].strip(" ,\t") == "":
                    end = body_end(clean, fn_at)
                    self.defs.setdefault(m.group(1), []).append((rel, line, fn_at, end))
                else:
                    arg = re.match(r"\s*,\s*([\w.]+)", clean[m.end():])
                    if arg:
                        self.labels.setdefault(m.group(1), []).append(("->", arg.group(1)))
            for m in PROFNAME_RE.finditer(text):
                line = text.count("\n", 0, m.start()) + 1
                self.labels.setdefault(m.group(2), []).append((rel, line))
                self.labels.setdefault(m.group(2), []).append(("->", m.group(1)))
            self.locals_by_file[rel] = local_names

    def find(self, name):
        """Definitions for a profiler row name ('ns.X', 'X', 'Update tick')."""
        seen, out = set(), []
        keys = [name]
        if name.startswith("ns."):
            keys += [name[3:]]
        else:
            keys += ["ns." + name]
        for target in self.labels.get(name, []):
            if target[0] == "->":
                keys.append(target[1])
                keys.append(target[1].split(".")[-1])
        for k in keys:
            for d in self.defs.get(k, []):
                if (d[0], d[1]) not in seen:
                    seen.add((d[0], d[1]))
                    out.append(d)
        # (A Dev/ test's wrapper of the same name last: the real one first.)
        out.sort(key=lambda d: d[0].startswith("Dev/"))
        if not out:
            for target in self.labels.get(name, []):
                if target[0] != "->":
                    out.append((target[0], target[1], None, None))
        return out


# Game calls that are known to cost (garbage, C round trips, secure work).
COSTLY_API = [
    "C_NamePlate.GetNamePlates", "C_NamePlate.GetNamePlateForUnit", "GetCVar", "SetCVar", "C_CVar.GetCVar",
    "C_CVar.SetCVar", "C_UnitAuras", "UnitAura", "AuraUtil", "C_QuestLog", "GetNumQuestLogEntries",
    "GetChildren", "GetRegions", "GetPoint", "GetNumPoints", "GetText", "GetStringWidth", "debugstack",
    "table.sort", "collectgarbage", "CreateFrame", "CreateTexture", "CreateFontString", "SetFont",
    "UnitGUID", "UnitName", "UnitIsUnit", "GetMouseFoci", "GetMouseFocus", "IsMouseOver", "GetCursorPosition",
    "C_Map", "C_Spell", "GetSpellInfo", "C_Item", "GetItemInfo", "C_Timer.After", "C_Timer.NewTimer",
    "SetPoint", "ClearAllPoints", "SetAlpha", "Show", "Hide", "SetShown", "issecretvalue", "pcall",
    "GetTime", "GetBuildInfo", "InCombatLockdown", "C_TooltipInfo", "GameTooltip",
]


def smells(clean, start, end):
    body = clean[start:end]
    inner = body[body.find("(") + 1:] if body else body
    found = {}

    def count(pattern):
        return len(re.findall(pattern, inner))

    found["lines"] = body.count("\n") + 1
    # (tables: "{" not part of a long string/comment, minus the empty-check
    # pattern `next(x)`)
    found["tables"] = count(r"(?<![\w\]\)])\{")
    found["closures"] = count(r"\bfunction\s*\(")
    found["strings"] = count(r"\.\.") + count(r":format\(") + count(r"string\.format") + count(r"tostring\(")
    found["loops"] = count(r"\bfor\b")
    found["pairs"] = count(r"\bpairs\(")
    found["settings"] = count(r"ns\.Setting\(") + count(r"ns\.db\.\w+")
    found["sorts"] = count(r"table\.sort|\bsort\(")
    found["wipes"] = count(r"\bwipe\(")
    nested = 0
    depth = 0
    for m in re.finditer(r"\b(for|while)\b|\bend\b|\b(function|if|repeat)\b|\buntil\b", inner):
        pass
    api = {}
    for name in COSTLY_API:
        c = len(re.findall(r"(?<![\w.])" + re.escape(name) + r"\b", inner))
        if not c and ":" not in name:
            c = len(re.findall(r":" + re.escape(name) + r"\(", inner)) if name[0].isupper() and "." not in name else 0
        if c:
            api[name] = c
    found["api"] = api
    calls = re.findall(r"(?<![\w.:])([A-Z]\w+)\s*\(", inner)
    found["local_calls"] = calls
    found["ns_calls"] = re.findall(r"\bns\.(\w+)\s*\(", inner)
    return found


# ---------------------------------------------------------------- analysis

def real_ms(rec):
    game = (rec.get("game") or {}).get("addon")
    overhead = 0.0
    if rec.get("deep"):
        calls = 0.0
        for s in rec.get("sections") or []:
            calls += s.get("calls", 0)
            for c in s.get("children") or []:
                calls += c.get("calls", 0)
        overhead = (rec.get("overhead") or 0) * calls
    measured = rec.get("total") or 0
    if game:
        return game - overhead, game, overhead
    return measured - overhead, None, overhead


def rows(rec):
    """Every row with its section, deduplicating 'X' and 'ns.X' pairs (the
    step's own timer and the deep wrapper over the same call)."""
    out = []
    for s in rec.get("sections") or []:
        out.append(dict(s, section=None))
        seen = {}
        for c in s.get("children") or []:
            key = c["name"][3:] if c["name"].startswith("ns.") else c["name"]
            if key in seen:
                prev = seen[key]
                # keep the outer one (the larger time: the step timer includes the wrapper)
                if c.get("ms", 0) > prev.get("ms", 0):
                    prev.update(c)
                continue
            row = dict(c, section=s["name"])
            seen[key] = row
            out.append(row)
    return out


SLOW_RE = re.compile(r"at ([\d.]+) s: (.+?) ([\d.]+) ms, (in combat|out of combat), (CineMode|normal UI)"
                     r" \(fight (.+?)\)(?:, memory [-\d]+ KB: a collection ran in it)?: (.*)")


def slow_calls(rec):
    out = []
    in_slow = False
    for line in rec.get("lines") or []:
        if line.startswith("slow calls"):
            in_slow = True
            continue
        if in_slow:
            if not line.startswith("    "):
                break
            m = SLOW_RE.search(line)
            if not m:
                continue
            parts = []
            for p in m.group(7).split(", "):
                pm = re.match(r"(.+) ([\d.]+)$", p)
                if pm:
                    parts.append((pm.group(1), float(pm.group(2))))
            out.append({"at": float(m.group(1)), "section": m.group(2), "ms": float(m.group(3)),
                        "combat": m.group(4) == "in combat", "mode": m.group(5), "fight": m.group(6),
                        "gc": "collection ran" in line, "parts": parts})
    return out


def game_spikes(rec):
    for line in rec.get("lines") or []:
        m = re.search(r"Over1Ms (\d+), Over5Ms (\d+), Over10Ms (\d+)", line)
        if m:
            return tuple(int(x) for x in m.groups())
    return None


def counts(rec):
    out = {}
    for line in rec.get("lines") or []:
        m = re.match(r"count (.+): ([\d.]+) a frame", line)
        if m:
            out[m.group(1)] = float(m.group(2))
    return out


def fight_share(rec):
    """Share of the run's frames in a fight or its Calm Timer, from the
    profiler's counts (ns.SlowChecks' reasons), or None where not counted."""
    # (Out of CineMode the checks aren't asked every frame: the share is of
    # the frames they were asked on, all their reasons together.)
    c = counts(rec)
    keys = ("slow checks off: in a fight", "slow checks off: Calm Timer")
    asked = sum(v for k, v in c.items() if k.startswith("slow checks "))
    if asked <= 0:
        return None
    return sum(c.get(k, 0) for k in keys) / asked


def kind_of(rec):
    """A recording's kind, to compare like with like. Fights by the share of
    frames in one (or its Calm Timer), not the start: a run that starts calm
    and fights half the time is a fight run. Place from the start."""
    st = rec.get("start") or {}
    plates = max(st.get("plates", 0), (rec.get("end") or {}).get("plates", 0))
    band = "0-5 plates" if plates <= 5 else ("6-20 plates" if plates <= 20 else "20+ plates")
    share = fight_share(rec)
    if share is None:
        fights = "fight" if st.get("combat") else "calm"
    else:
        fights = "fights" if share >= 0.15 else "calm"
    # (Deep and normal runs apart: a deep one's figures carry its wrappers.)
    return "%s | %s | %s | %s | %s | %s | %s" % (rec.get("client"), "deep" if rec.get("deep") else "normal",
                                                 st.get("mode", "?"), fights, st.get("place", "?"),
                                                 st.get("group", "?"), band)


class Issue:
    def __init__(self, kind, name, score, headline, detail, row=None, section=None):
        self.kind, self.name, self.score = kind, name, score
        self.headline, self.detail = headline, detail
        self.row, self.section = row, section
        self.defs, self.smell, self.tries = [], None, []


def analyze(rec, history, index, top):
    frames_per_s = rec.get("fps") or 60
    frame_ms = rec.get("frameMs") or 16.7
    real, game, overhead = real_ms(rec)
    deep = rec.get("deep")
    per_call_cost = (rec.get("overhead") or 0) if deep else 0
    issues = []
    all_rows = rows(rec)
    by_name = {}
    for r in all_rows:
        by_name.setdefault(r["name"], []).append(r)

    for r in all_rows:
        name = r["name"]
        ms = r.get("ms", 0)
        calls = r.get("calls", 0)
        avg = r.get("average", 0)
        worst = r.get("worst", 0)
        kb = r.get("kb", 0)
        own_overhead = per_call_cost * calls
        net = max(0.0, ms - own_overhead)
        where = r["section"] and ("under " + r["section"]) or "section"
        # Steady cost: what it takes off every frame.
        if net >= 0.02:
            issues.append(Issue("steady", name, net,
                                "%.3f ms a frame (%s)" % (net, where),
                                "%.2f calls a frame, %.4f ms a call%s" % (
                                    calls, avg, ", ~%.3f of it the profiler's wrapper" % own_overhead
                                    if own_overhead > 0.002 else ""), r, r["section"]))
        total_calls = calls * frames_per_s * (rec.get("seconds") or 0)
        # One-offs (opening settings, a first build): listed apart, not ranked
        # with what costs every frame.
        if avg >= 1.0 and 0 < total_calls < 5:
            issues.append(Issue("oneoff", name, 0.0, "%.1f ms, %d call(s) in the run" % (avg, round(total_calls)),
                                "a one-off: matters only if it lands in play (a fight, a login burst)",
                                r, r["section"]))
        # (Deep runs: a loop over many rows calls wrapped ns functions per row,
        # ~1.5 us each, so a part like that reads several times its real cost.)
        # Hitches: each call over a millisecond is a visible bump.
        elif avg >= 1.0 and calls > 0:
            per_s = calls * frames_per_s
            issues.append(Issue("hitch", name, (avg - 1.0) * per_s / frames_per_s + avg / 10,
                                "%.2f ms a call, %.1f calls a second (worst %.2f)" % (avg, per_s, worst),
                                "every call is a long frame: split it over frames, or do less per call",
                                r, r["section"]))
        elif worst >= 5.0 and avg < 1.0:
            issues.append(Issue("spike", name, worst / 20,
                                "worst %.2f ms against %.3f average" % (worst, avg),
                                "a rare path is %dx the normal one: find what that call did" % (worst / max(avg, 0.001)),
                                r, r["section"]))
        # Garbage: collection runs in proportion to it.
        if kb >= 2.0 and not (r["section"] is None and r.get("children")):
            issues.append(Issue("garbage", name, kb / 20, "%.1f KB a second" % kb,
                                "%.2f KB a call" % (kb / max(calls * frames_per_s, 0.001)), r, r["section"]))
        # Called too often: per-call costs add up, and the answer rarely changes.
        if calls >= 3 and avg < 0.01 and r["section"] is not None:
            issues.append(Issue("chatty", name, calls * max(avg, per_call_cost) / 2,
                                "%.1f calls a frame (%.0f a second)" % (calls, calls * frames_per_s),
                                "cheap alone; worth one answer a frame (or per change) if its inputs hold",
                                r, r["section"]))

    # Hidden time: slow calls whose timed parts don't add up.
    slows = slow_calls(rec)
    for s in slows:
        parts = {}
        for pname, pms in s["parts"]:
            key = pname[3:] if pname.startswith("ns.") else pname
            parts[key] = max(parts.get(key, 0), pms)
        # the biggest part and what's under it: parts listed flat, so the
        # biggest one's own uncovered time = it minus the next ones it calls
        ordered = sorted(parts.items(), key=lambda kv: -kv[1])
        if ordered:
            top_name, top_ms = ordered[0]
            covered = sum(v for k, v in ordered[1:] if v < top_ms)
            hidden = top_ms - covered
            if top_ms >= 3 and hidden >= 0.6 * top_ms and len(ordered) <= 4:
                issues.append(Issue("hidden", top_name, hidden / 2,
                                    "%.1f ms of a %.1f ms slow call no timer below it explains (at %.1f s, %s, %s)"
                                    % (hidden, s["ms"], s["at"], "fight" if s["combat"] else "calm", s["mode"]),
                                    "its local functions aren't timed: name them (ns.ProfileName) or time the "
                                    "branches, then record again", None, s["section"]))
    # Unwrapped time: the game sees more than the timers.
    if game is not None:
        gap = game - (rec.get("total") or 0)
        # (A deep run's wrappers are only half inside their own timers: up to
        # the whole overhead lands in this gap. 2026-11-22: 0.455 gap with
        # 0.511 overhead = nothing real. A normal run gives the true figure.)
        real_gap = gap - overhead if deep else gap
        if real_gap > 0.08:
            issues.append(Issue("unwrapped", "(not timed)", real_gap,
                                "%.3f ms a frame the game counts that no timer covers%s" % (
                                    real_gap, " (after the profiler's own %.3f)" % overhead if deep else ""),
                                "events, hooks and scripts not wrapped with ns.Profiled", None, None))

    # Against earlier recordings of the same kind.
    kind = kind_of(rec)
    same = [h for h in history if kind_of(h) == kind and h.get("finished") != rec.get("finished")
            and (h.get("finished") or 0) < (rec.get("finished") or 0)]
    trend = None
    if same:
        prev = max(same, key=lambda h: h.get("finished") or 0)
        prev_real = real_ms(prev)[0]
        trend = (prev, prev_real)
        prev_rows = {r["name"]: r for r in rows(prev)}
        for r in all_rows:
            p = prev_rows.get(r["name"])
            if not p:
                continue
            d = r.get("ms", 0) - p.get("ms", 0)
            dkb = r.get("kb", 0) - p.get("kb", 0)
            if d >= 0.02 or (d >= 0.01 and d > p.get("ms", 0)):
                issues.append(Issue("regression", r["name"], d * 2,
                                    "+%.3f ms a frame since %s (%.3f -> %.3f)" % (
                                        d, stamp(prev.get("finished")), p.get("ms", 0), r.get("ms", 0)),
                                    "same kind of recording: look at what changed in it", r, r["section"]))
            if dkb >= 5:
                issues.append(Issue("regression", r["name"], dkb / 20,
                                    "+%.1f KB a second since %s" % (dkb, stamp(prev.get("finished"))),
                                    "more garbage than the last recording of this kind", r, r["section"]))

    # Merge issues of the same name into one, keep the kinds.
    merged = {}
    for i in issues:
        key = i.name[3:] if i.name.startswith("ns.") else i.name
        m = merged.get(key)
        if not m:
            merged[key] = m = {"name": i.name, "score": 0.0, "issues": [], "section": i.section}
        m["score"] += i.score
        m["issues"].append(i)
    oneoffs = [m for m in merged.values() if all(i.kind == "oneoff" for i in m["issues"])]
    ranked = sorted((m for m in merged.values() if m not in oneoffs), key=lambda m: -m["score"])
    oneoffs.sort(key=lambda m: -m["issues"][0].row.get("average", 0))

    # Source and what to try for the top ones.
    for m in ranked[:top]:
        m["defs"] = index.find(m["name"]) if m["name"] != "(not timed)" else []
        m["smell"] = None
        for d in m["defs"]:
            if d[2] is not None:
                text, clean = index.files[d[0]]
                m["smell"] = smells(clean, d[2], d[3])
                m["smell"]["file"], m["smell"]["line"] = d[0], d[1]
                # the local functions it calls (time that hides from the profiler)
                locs = index.locals_by_file.get(d[0], set())
                m["smell"]["untimed_locals"] = sorted({c for c in m["smell"]["local_calls"] if c in locs})
                break
        m["tries"] = suggestions(m, rec)
    for m in oneoffs:
        m["defs"] = index.find(m["name"])
    return {"real": real, "game": game, "overhead": overhead, "frame_ms": frame_ms, "ranked": ranked,
            "oneoffs": oneoffs,
            "slows": slows, "trend": trend, "kind": kind, "spikes": game_spikes(rec), "counts": counts(rec)}


def suggestions(m, rec):
    kinds = {i.kind for i in m["issues"]}
    s = m.get("smell") or {}
    api = s.get("api") or {}
    tries = []
    row = next((i.row for i in m["issues"] if i.row), None) or {}
    calls = row.get("calls", 0)
    if "hitch" in kinds:
        tries.append("Spread it: do a slice a frame (a cursor over the list, like ns.plates.RollStep), "
                     "or a coroutine with a ms budget (the settings builder's 3 ms a frame).")
        if s.get("loops", 0) >= 2:
            tries.append("It loops %d times in its body: find the loop over the biggest list (managed frames, "
                         "plates, children) and only visit what changed (dirty set from events)." % s["loops"])
    if "spike" in kinds:
        tries.append("Find the rare branch: the worst call is far above the average. Usual suspects: a first build, "
                     "a cache miss after an event, a list rebuilt from scratch. Warm it out of the hot path.")
    if "hidden" in kinds:
        locs = s.get("untimed_locals") or []
        tries.append("Time its parts: wrap %s with ns.Profiled/ns.ProfileName and record again; the slow call line "
                     "will then name the culprit." % (", ".join(locs[:8]) if locs else "its local helpers"))
    if "garbage" in kinds:
        if s.get("tables"):
            tries.append("%d table constructor(s) in its body: hoist constants to file level, reuse a scratch table "
                         "(wipe it), or return several values instead of a table." % s["tables"])
        if s.get("closures"):
            tries.append("%d closure(s) made per call: move them out as file-level functions taking arguments "
                         "(sort comparators especially)." % s["closures"])
        if s.get("strings"):
            tries.append("%d string build(s) (.., format, tostring): cache keys per input, or skip building "
                         "text unless a log line will use it." % s["strings"])
        if not (s.get("tables") or s.get("closures") or s.get("strings")):
            tries.append("No table/closure/string in its own body: the garbage is in what it calls "
                         "(game API returning tables, or helpers): check the children rows and the API list.")
    if "chatty" in kinds:
        tries.append("Called %.1f times a frame: cache the answer for the frame (stamp with the frame counter) "
                     "or until the event that changes it, and let callers read the cached value." % calls)
    if "steady" in kinds and not ({"hitch", "chatty"} & kinds):
        if s.get("settings", 0) >= 4:
            tries.append("%d setting reads per call: read them once into locals when settings change "
                         "(ns.OnSettingChanged style) instead of every call." % s["settings"])
        tries.append("Ask whether it must run every frame: an event, a pace (ns.Pace) or 'only while moving' gate "
                     "may cover it; see what its inputs are and when they change.")
    if "regression" in kinds:
        tries.append("It grew since the last recording of this kind: `git log -L` on its function, or diff "
                     "the files it calls, from that date.")
    if "unwrapped" in kinds:
        tries.append("Wrap the remaining OnUpdate/event handlers with ns.Profiled (look for SetScript(\"OnEvent\" "
                     "and ns.SetOnUpdate without it) so the time has a name.")
    heavy = [a for a in api if a in ("C_NamePlate.GetNamePlates", "GetChildren", "GetRegions", "debugstack",
                                     "table.sort", "C_UnitAuras", "C_QuestLog", "GetCVar", "C_CVar.GetCVar",
                                     "C_TooltipInfo", "CreateFrame")]
    if heavy:
        tries.append("Costly game calls in its body: %s. Each makes tables or crosses into C; cache the result "
                     "until its event (NAME_PLATE_UNIT_ADDED, CVAR_UPDATE, QUEST_LOG_UPDATE...)."
                     % ", ".join("%s x%d" % (a, api[a]) for a in heavy))
    return tries


# ---------------------------------------------------------------- coverage

def coverage(history, latest):
    """Which kinds of recording we have, and which are missing."""
    have = {}
    for h in history + latest:
        st = h.get("start") or {}
        have.setdefault(h.get("client"), set()).add((
            "fight" if st.get("combat") else "calm",
            st.get("group", "solo") if st.get("group") in ("party", "raid") else "solo",
            "many plates" if st.get("plates", 0) > 15 else "few plates",
            st.get("mode", "?")))
    wanted = [("fight", "solo", "few plates", "CineMode"), ("fight", "party", "many plates", "CineMode"),
              ("calm", "solo", "many plates", "CineMode"), ("calm", "solo", "few plates", "normal UI"),
              ("fight", "solo", "few plates", "normal UI")]
    missing = {}
    for client in ("forever", "retail"):
        got = have.get(client, set())
        missing[client] = [w for w in wanted if w not in got]
    return have, missing


# ---------------------------------------------------------------- report


def stamp(t):
    try:
        return time.strftime("%Y-%m-%d %H:%M", time.localtime(int(t)))
    except (TypeError, ValueError, OSError):
        return "?"


def report(rec, res, cov_missing, top):
    out = []
    add = out.append
    st = rec.get("start") or {}
    add("# Cinematic performance report: %s, %s" % (rec["client"], stamp(rec.get("finished"))))
    add("")
    add("Recording: %s%.0f s, %.0f fps (%.2f ms a frame), %s." % (
        "deep, " if rec.get("deep") else "", rec.get("seconds", 0), rec.get("fps", 0), res["frame_ms"],
        rec.get("startState")))
    add("Kind: `%s`" % res["kind"])
    share = fight_share(rec)
    if share is not None:
        add("In a fight or its Calm Timer: %.0f%% of frames." % (share * 100))
    sl = rec.get("since_login")
    if sl is not None and sl < LOGIN_SETTLE:
        add("")
        add("**Started %d s after a /reload or login**: the login builds (settings slots and pages made ahead, "
            "one step a frame) may still run and read high (ns.SettingSlot, ns.MarkRowDefault, ns.ApplyModules "
            "rows). For steady figures, record %d s or more after one." % (sl, LOGIN_SETTLE))
    add("")
    add("## Headline")
    add("")
    real = res["real"]
    add("- **Real cost: %.3f ms a frame** (%.1f%% of the frame)%s." % (
        real, real * 100 / res["frame_ms"] if res["frame_ms"] else 0,
        "; game figure %.3f minus profiler wrapper %.3f" % (res["game"], res["overhead"])
        if res["game"] is not None else "; no game figure on this client"))
    add("- Garbage: %.1f KB a second." % (rec.get("kb") or 0))
    sp = res["spikes"]
    if sp:
        frames = (rec.get("seconds") or 0) * (rec.get("fps") or 0)
        add("- Our frames over 1 / 5 / 10 ms (game's count): %d / %d / %d of %d (%.1f%% over 5)." % (
            sp[0], sp[1], sp[2], frames, sp[1] * 100 / frames if frames else 0))
    add("- Worst measured frame: %.2f ms." % (rec.get("worst") or 0))
    rank = addon_rank(rec.get("addons"))
    if rank:
        add("")
        add("## Among your addons (the game's own figures)")
        add("")
        out.extend(rank)
        add("")
    if res["trend"]:
        prev, prev_real = res["trend"]
        add("- Last recording of this kind (%s): %.3f ms a frame, %.1f KB/s -> now %+.3f ms, %+.1f KB/s." % (
            stamp(prev.get("finished")), prev_real, prev.get("kb") or 0, real - prev_real,
            (rec.get("kb") or 0) - (prev.get("kb") or 0)))
    else:
        add("- No earlier recording of this kind in Tools/perf/history yet.")
    smp = rec.get("samples")
    if smp:
        add("- Per-second graph (%d s): mean %.3f, p90 %.3f, p99 %.3f, max %.3f ms a frame." % (
            smp["count"], smp["mean"], smp["p90"], smp["p99"], smp["max"]))
    if rec.get("digest"):
        add("")
        add("Digest:")
        add("")
        for line in rec["digest"][:5]:
            add("    " + str(line))
    add("")
    add("## Biggest issues")
    add("")
    if rec.get("deep"):
        add("Deep recording: every ns function is wrapped (~%.1f us a call), so loops over many rows (the combat "
            "list's rows, the frames pass's entries) read several times their real cost, and so do their "
            "spikes. Confirm a spike with a normal run (`/cine profiler 120`) before fixing it." % (
                (rec.get("overhead") or 0) * 1000))
        add("")
    add("Score = rough ms a frame it costs or could save (hitches and garbage weighted up). "
        "Rows named both `X` and `ns.X` are one call.")
    add("")
    for n, m in enumerate(res["ranked"][:top], 1):
        add("### %d. %s  (score %.3f)" % (n, m["name"], m["score"]))
        add("")
        for i in m["issues"]:
            add("- **%s**: %s. %s" % (i.kind, i.headline, i.detail))
        s = m.get("smell")
        if s:
            add("- Source: `%s:%d` (%d lines). Body: %d tables, %d closures, %d string builds, %d loops "
                "(%d pairs), %d setting reads, %d sorts." % (
                    s["file"], s["line"], s["lines"], s["tables"], s["closures"], s["strings"], s["loops"],
                    s["pairs"], s["settings"], s["sorts"]))
            if s["api"]:
                add("- Game calls: %s." % ", ".join("%s x%d" % kv for kv in sorted(s["api"].items(),
                                                                                    key=lambda kv: -kv[1])))
            if s.get("untimed_locals"):
                add("- Untimed local helpers it calls: %s." % ", ".join(s["untimed_locals"][:12]))
            nsc = sorted(set(s["ns_calls"]))
            if nsc:
                add("- ns calls: %s." % ", ".join(nsc[:16]))
        elif m.get("defs"):
            add("- Source: %s" % ", ".join("`%s:%d`" % (d[0], d[1]) for d in m["defs"][:3]))
        elif m["name"] != "(not timed)":
            add("- Source: not found by name (a label: grep `ns.Profiled(\"%s\"`)." % m["name"])
        if m.get("tries"):
            add("- Try:")
            for t in m["tries"]:
                add("    - " + t)
        add("")
    if res["oneoffs"]:
        add("## One-off long calls")
        add("")
        for m in res["oneoffs"][:12]:
            i = m["issues"][0]
            src = ", ".join("`%s:%d`" % (d[0], d[1]) for d in m.get("defs", [])[:2])
            add("- %s: %s%s" % (m["name"], i.headline, " (%s)" % src if src else ""))
        add("")
    if res["slows"]:
        add("## Slow calls (over 8 ms)")
        add("")
        for s in res["slows"]:
            add("- at %.1f s, %s %.1f ms (%s, %s%s): %s" % (
                s["at"], s["section"], s["ms"], "fight" if s["combat"] else "calm", s["mode"],
                ", GC ran" if s["gc"] else "", ", ".join("%s %.1f" % p for p in s["parts"]) or "no timed parts"))
        add("")
    if res["counts"]:
        add("## Counts")
        add("")
        for k, v in sorted(res["counts"].items()):
            add("- %s: %.3f a frame" % (k, v))
        add("")
    add("## Recordings still missing")
    add("")
    add("Each finds costs the others can't (fights wake Vitals and plates; parties bring frames; "
        "40 plates bring the plate passes).")
    add("")
    for client, miss in cov_missing.items():
        if miss:
            add("- %s: %s" % (client, "; ".join("%s / %s / %s / %s" % w for w in miss)))
        else:
            add("- %s: all kinds recorded." % client)
    add("")
    add("Record: `/cine profiler 120 deep` (the user plays as usual; the run saves on /reload or logout).")
    return "\n".join(out)


def bench_report(runs):
    """/cine debug perf (Dev/PerfTest.lua) results: each step's latest run on
    each client against its run before, with the parts of the slowest."""
    out = ["## Benchmarks (/cine debug perf)", ""]
    if not runs:
        out.append("None yet: `/cine debug perf` (stand still; about a minute, nothing to do).")
        return "\n".join(out)
    by = {}
    for r in runs:
        if isinstance(r, dict) and r.get("step"):
            by.setdefault((r.get("client"), r["step"]), []).append(r)
    # (Change by the median too: one rare slow call, a cache rebuilt, moves
    # the average of 60 a lot and the median not at all.)
    out.append("| Client | Step | Now (ms a call) | p50 | p95 | Worst | KB a call | Before | Change | Median change |")
    out.append("|---|---|---|---|---|---|---|---|---|---|")
    lives = []
    for (client, step), rs in sorted(by.items(), key=lambda kv: (kv[0][0] or "", kv[0][1])):
        rs.sort(key=lambda r: r.get("at") or 0)
        now = rs[-1]
        if step == "questlive":
            lives.append((client, now))
            continue
        prev = rs[-2] if len(rs) > 1 else None
        change = ""
        if prev and prev.get("avg"):
            pct = (now.get("avg", 0) - prev["avg"]) * 100 / prev["avg"]
            change = "%+.0f%%" % pct + (" (slower)" if pct > 15 else " (faster)" if pct < -15 else "")
        median = ""
        if prev and prev.get("p50"):
            mp = (now.get("p50", 0) - prev["p50"]) * 100 / prev["p50"]
            median = "%+.0f%%" % mp + (" (slower)" if mp > 15 else " (faster)" if mp < -15 else "")
        out.append("| %s | %s | %.3f | %.3f | %.3f | %.2f | %.2f | %s | %s | %s |" % (
            client, now.get("label", step), now.get("avg", 0), now.get("p50", 0), now.get("p95", 0),
            now.get("worst", 0), now.get("kbCall", 0),
            "%.3f (%s)" % (prev["avg"], stamp(prev.get("at"))) if prev else "-", change, median))
    for client, now in lives:
        out.append("")
        out.append("Quest walk held 10 s (%s, %s): %.0f passes (%.0f settled), the tracker walked %s and skipped %s; "
                   "the game put %.0f parts' alpha back, %.0f set, %.0f already so." % (
                       client, stamp(now.get("at")), now.get("walks", 0), now.get("settledWalks", 0),
                       "%.0f" % now["walked"] if "walked" in now else "?",
                       "%.0f" % now["skipped"] if "skipped" in now else "?", now.get("gameChanged", 0),
                       now.get("set", 0), now.get("alreadySo", 0)))
    slow = [rs[-1] for rs in by.values() if rs[-1].get("parts")]
    for r in sorted(slow, key=lambda r: -(r.get("avg") or 0))[:3]:
        out.append("")
        out.append("Parts of %s (%s):" % (r.get("label"), r.get("client")))
        for part in r["parts"][:8]:
            out.append("- %s: %.3f ms a call, worst %.2f" % (part.get("name"), part.get("average") or 0,
                                                            part.get("worst") or 0))
    return "\n".join(out)


def selftest():
    bad = []
    lines = ["CinematicDev: now 2.182, average 1.696, worst 216.87", "Cinematic: now 3.879, average 0.809, worst 112.35",
             "EllesmereUI: now 0.013, average 0.075, worst 85.79", "Bagnon: now 0.500, average 0.900, worst 300.00",
             "not an addon line"]
    got = parse_addons(lines)
    if [a["name"] for a in got] != ["CinematicDev", "Cinematic", "EllesmereUI", "Bagnon"] or got[3]["worst"] != 300.0:
        bad.append("parse %r" % got)
    rank = addon_rank(got, top=2)
    if not rank or "**CinematicDev: #1 of 4" not in rank[0] or "#2 by its worst frame (216.87 ms)" not in rank[0]:
        bad.append("rank dev %r" % rank)
    if "**Cinematic: #3 of 4" not in rank[1] or "all addons together 3.480 ms" not in rank[1]:
        bad.append("rank release %r" % rank)
    top = "Top 2 by session average: CinematicDev 1.696, Bagnon 0.900."
    if not any("Both Cinematic and CinematicDev" in r for r in rank) or top not in rank[-1]:
        bad.append("both / top %r" % rank)
    one = addon_rank(parse_addons(lines[1:4]))
    if any("Both" in r for r in one) or "#2 of 3" not in one[0]:
        bad.append("one copy %r" % one)
    if addon_rank([]) != [] or "isn't in" not in addon_rank(parse_addons(lines[2:3]))[0]:
        bad.append("empty / missing")
    print("selftest: %s" % ("PASS" if not bad else "FAIL\n  " + "\n  ".join(bad)))
    return not bad


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--client", choices=list(CLIENTS))
    ap.add_argument("--all", action="store_true", help="a report per client")
    ap.add_argument("--top", type=int, default=12)
    ap.add_argument("--no-save", action="store_true", help="don't write history or the report file")
    ap.add_argument("--json", action="store_true", help="print the ranked issues as JSON")
    ap.add_argument("--history", help="analyze this history file instead of the newest recording")
    ap.add_argument("--bench", action="store_true", help="only the /cine debug perf benchmarks")
    ap.add_argument("--selftest", action="store_true", help="check the addon ranking's parser")
    args = ap.parse_args()
    if args.selftest:
        sys.exit(0 if selftest() else 1)

    if args.bench:
        runs = []
        for client, path in sv_files(args.client):
            try:
                read_profiler(path)
                runs += [r for r in read_profiler.bench if isinstance(r, dict)]
            except Exception as e:  # noqa: BLE001
                print("skipped %s: %s" % (path, e), file=sys.stderr)
        print(bench_report(runs))
        return
    latest = []
    bench_runs = []
    if args.history:
        with open(args.history, encoding="utf-8") as f:
            latest.append(json.load(f))
    else:
        for client, path in sv_files(args.client):
            try:
                prof, log = read_profiler(path)
            except Exception as e:  # noqa: BLE001 (a half-written file mid-save)
                print("skipped %s: %s" % (path, e), file=sys.stderr)
                continue
            bench_runs += [r for r in getattr(read_profiler, "bench", []) if isinstance(r, dict)]
            rec = recording_from(client, path, prof)
            if rec:
                rec["since_login"] = since_login(log, rec)
                latest.append(rec)
                if not args.no_save:
                    save_history(rec)
    if not latest:
        sys.exit("no profiler recording found: record with /cine profiler 120 deep, then /reload")
    history = load_history()
    if not args.all:
        latest = [max(latest, key=lambda r: r.get("finished") or 0)]
    index = Index()
    _, missing = coverage(history, latest)
    for rec in latest:
        res = analyze(rec, history, index, args.top)
        text = report(rec, res, missing, args.top) + "\n\n" + bench_report(
            [r for r in bench_runs if r.get("client") == rec["client"]])
        if args.json:
            print(json.dumps([{"name": m["name"], "score": m["score"],
                               "kinds": [i.kind for i in m["issues"]],
                               "source": m.get("smell") and "%s:%d" % (m["smell"]["file"], m["smell"]["line"]),
                               "tries": m.get("tries")} for m in res["ranked"][:args.top]], indent=1))
        else:
            print(text)
        if not args.no_save:
            os.makedirs(REPORTS, exist_ok=True)
            path = os.path.join(REPORTS, "%s-%s.md" % (rec["client"], time.strftime(
                "%Y-%m-%d-%H%M", time.localtime(int(rec.get("finished") or time.time())))))
            with open(path, "w", encoding="utf-8") as f:
                f.write(text + "\n")
            print("\nreport: %s" % os.path.relpath(path, REPO), file=sys.stderr)


if __name__ == "__main__":
    main()
