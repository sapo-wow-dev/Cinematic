"""Reads the game's own API docs and checks the engine rules against them. Two sources, the same data:

- the console's `exportInterfaceFiles code` (no game run): each client's
  <client>/BlizzardInterfaceCode/.../Blizzard_APIDocumentationGenerated, walked
  by Dev/ApiDocsDump.lua's own code on stand-ins, so its lines are the in-game
  dump's to the letter (Forever, 2026-11-23: all 9241 the same), plus the
  tables outside any system the dump never reached ("T - ...": most Enums)
  and the Documentation lines (api/<client>-help.txt);
- /cine debug apidocs (Dev/ApiDocsDump.lua) saved in SavedVariables.

From the repo root:

    python -I Tools/engine/apidocs.py                 (every client: export and saved copy, the newer one used;
                                                       both there: compared, lines only in one listed)
    python -I Tools/engine/apidocs.py <SavedVariables file> ...
    python -I Tools/engine/apidocs.py --selftest

For each client it writes Tools/engine/api/<client>.txt (one
line per function, event and table; git-ignored: it is Blizzard's data, kept
on this PC only) and prints:

- the copy's build and counts;
- FLAG lines: every extra field Blizzard puts on entries (secret flags and the
  like), how many entries carry it, an example or two;
- MISSING lines: a rule names a call for a client whose docs don't have it,
  though another client's docs do (a wrong client list, or a call that client
  lacks);
- RULEFLAGS lines: the extra fields on the calls rules name, per client.

Needs lupa (pip install lupa), like Tools/offline/run.py.
"""
import glob
import os
import re
import sys
import tempfile
import time

import lupa.lua51 as lua51

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT, "Tools", "engine", "api")
WOW = r"C:\Program Files (x86)\World of Warcraft"
CLIENT_DIRS = ["_forever_", "_retail_", "_classic_era_"]
BRACES = re.compile(r"\{([^{}]*)\}")
# The flags that say when a call is secret, protected or restricted (SecretArguments is on almost every call).
SECRETISH = re.compile(r"((?:Secret|NeverSecret|ReturnsNeverSecret|ConditionalSecret|IsProtectedFunction|HasRestrictions)\w*)=(\w+)")
KEY = re.compile(r"([A-Za-z_]\w*)=")


def saved_files():
    out = []
    for d in CLIENT_DIRS:
        out += glob.glob(os.path.join(WOW, d, "WTF", "Account", "*", "SavedVariables", "CinematicDev.lua"))
        out += glob.glob(os.path.join(WOW, d, "WTF", "Account", "*", "SavedVariables", "Cinematic.lua"))
    return out


def read_dump(path):
    """CinematicDB.apiDocs from a SavedVariables file, as a dict, or None."""
    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    with open(path, encoding="utf-8", errors="replace") as f:
        text = f.read()
    if "apiDocs" not in text:
        return None
    env = lua.eval("function(src) local env = {} local f = assert(loadstring(src)) setfenv(f, env) f() return env end")(text)
    db = env["CinematicDB"]
    d = db and db["apiDocs"]
    if not d:
        return None
    lines = d["lines"]
    shape = d["shape"]
    return {
        "client": d["client"] or "unknown", "version": d["version"], "build": d["build"], "toc": d["toc"],
        "at": d["at"], "load": d["load"], "counts": d["counts"], "error": d["error"],
        "shape": [shape[i] for i in range(1, len(shape) + 1)] if shape else [],
        "lines": [clean(lines[i]) for i in range(1, len(lines) + 1)] if lines else [],
        "file": path,
    }


PARENT = re.compile(r",?(?:Function|Event|Table)=\{[^{}]*\}")


def clean(line):
    """Drops an argument's copy of its parent entry (dumps before 2026-11-21 kept it)."""
    line = PARENT.sub("", line)
    return line.replace("{,", "{").replace(" {}", "")


def entry_name(line):
    parts = line.split(" ", 3)
    if len(parts) < 3:
        return None
    return parts[2].split("(", 1)[0]


def index(dump):
    names = {}
    for line in dump["lines"]:
        n = entry_name(line)
        if n:
            names.setdefault(n, []).append(line)
    return names


def flags(dump):
    """{key: [count, examples]} for the extra fields in a dump."""
    out = {}
    for line in dump["lines"]:
        keys = set()
        for group in BRACES.findall(line):
            keys.update(KEY.findall(group))
        for k in keys:
            c = out.setdefault(k, [0, []])
            c[0] += 1
            if len(c[1]) < 2:
                c[1].append(line if len(line) < 160 else line[:157] + "...")
    return out


def load_rules():
    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    cwd = os.getcwd()
    os.chdir(ROOT)
    try:
        rules = lua.execute('return dofile("Tools/engine/rules.lua")')
        if isinstance(rules, tuple):
            rules = rules[0]
    finally:
        os.chdir(cwd)
    out = []
    for i in range(1, len(rules) + 1):
        r = rules[i]
        out.append({
            "id": r.id,
            "clients": [r.clients[j] for j in range(1, len(r.clients) + 1)],
            "api": [r.api[j] for j in range(1, len(r.api) + 1)],
        })
    return out


def api_name(a):
    """A rule's api word as a docs name: "C_Spell.GetSpellInfo()" -> "C_Spell.GetSpellInfo"."""
    return a.split("(", 1)[0].strip()


def write_copy(dump):
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, dump["client"] + ".txt")
    head = ["# /cine debug apidocs, %s %s (%s, toc %s), saved %s" % (
        dump["client"], dump["version"], dump["build"], dump["toc"], dump["at"]),
        "# load: %s" % dump["load"], "# %s" % dump["counts"]]
    head += ["# shape " + s for s in dump["shape"]]
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(head + sorted(dump["lines"])) + "\n")
    return path


def report(dumps, rules, out=print):
    by_client = {}
    for d in dumps:
        by_client[d["client"]] = d
    idx = {c: index(d) for c, d in by_client.items()}
    for c, d in sorted(by_client.items()):
        out("== %s %s (%s) saved %s: %s" % (c, d["version"], d["build"], d["at"], d["counts"] or "no counts"))
        if d["error"]:
            out("  ERROR in the dump: %s" % d["error"])
        if not d["lines"]:
            out("  no docs on this client (%s)" % d["load"])
        for s in d["shape"]:
            out("  shape " + s)
        for k, (n, ex) in sorted(flags(d).items(), key=lambda kv: -kv[1][0]):
            out("  FLAG %-28s %5d   e.g. %s" % (k, n, ex[0]))
    known = set()
    for names in idx.values():
        known.update(names)
    missing, ruleflags = [], []
    for r in rules:
        for a in r["api"]:
            n = api_name(a)
            if n not in known:
                continue
            for c in r["clients"]:
                if c not in idx or not idx[c]:
                    continue
                if n not in idx[c]:
                    missing.append("  MISSING %-12s %-40s %s" % (c, n, r["id"]))
                else:
                    for line in idx[c][n]:
                        got = sorted(set(k + "=" + v for k, v in SECRETISH.findall(line) if k != "SecretArguments"))
                        if got:
                            ruleflags.append("  RULEFLAGS %-12s %-40s %-28s %s" % (c, n, " ".join(got), r["id"]))
    out("Rules naming a call that a listed client's docs lack (other clients have it):")
    for m in missing or ["  none"]:
        out(m)
    out("Extra fields on calls the rules name:")
    for m in sorted(set(ruleflags)) or ["  none"]:
        out(m)
    return missing


# The same docs, from the console's `exportInterfaceFiles code` (no game run): each client's
# BlizzardInterfaceCode/.../Blizzard_APIDocumentationGenerated holds the files /api loads. They're run here on
# lupa with APIDocumentation:AddDocumentationTable collecting the systems, then walked by Dev/ApiDocsDump.lua itself
# (its own code, on stand-ins), so the lines are the in-game dump's to the letter. The Documentation lines the dump
# leaves out go to api/<client>-help.txt.
GENERATED = os.path.join("BlizzardInterfaceCode", "Interface", "AddOns", "Blizzard_APIDocumentationGenerated")
DUMPER = os.path.join(ROOT, "Dev", "ApiDocsDump.lua")
CLIENT_NAMES = {"_forever_": "forever", "_retail_": "retail", "_classic_era_": "classic_era"}

EXPORT_LUA = r'''
return function(files, dumper, client, at, where)
  -- (The files read Enum.X.Y and Constants.X.Y, the game's own values, some in sums. Those values are in the
  -- docs too (Enumeration tables' EnumValue, Constants tables' Value), so: load with unknowns as 0, take the
  -- values found, load again, until nothing changes.)
  local function Known(values)
    return setmetatable({}, { __index = function(_, group)
      local g = values[group] or {}
      return setmetatable({}, { __index = function(_, key) local v = g[key] if v == nil then v = 0 end return v end })
    end })
  end
  -- (Like Blizzard_APIDocumentation's AddDocumentationTable: a file with a Name is a system, one without only
  -- adds its Tables to the loose list, which the in-game dump never walks: they're added after it, under "-".)
  local systems, docs
  local enums, consts = {}, {}
  for _ = 1, 4 do
    systems, docs = {}, {}
    APIDocumentation = { systems = systems }
    function APIDocumentation:AddDocumentationTable(t)
      docs[#docs + 1] = t
      if t.Name then systems[#systems + 1] = t end
    end
    Enum, Constants = Known(enums), Known(consts)
    for _, path in ipairs(files) do
      local chunk, err = loadfile(path)
      if not chunk then error(path .. ": " .. tostring(err)) end
      chunk()
    end
    local changed = false
    for _, s in ipairs(docs) do
      for _, t in ipairs(s.Tables or {}) do
        local into = (t.Type == "Enumeration" and enums) or (t.Type == "Constants" and consts) or nil
        if into then
          into[t.Name] = into[t.Name] or {}
          for _, f in ipairs(t.Fields or t.Values or {}) do
            local v = f.EnumValue
            if v == nil then v = f.Value end
            if type(v) == "number" and into[t.Name][f.Name] ~= v then into[t.Name][f.Name] = v changed = true end
          end
        end
      end
    end
    if not changed then break end
  end
  Enum, Constants = nil, nil
  -- Stand-ins for what Dev/ApiDocsDump.lua touches.
  local tick
  CinematicDB = {}
  C_AddOns = { LoadAddOn = function() return true end }
  C_Timer = { After = function() end, NewTicker = function(_, fn)
    tick = { fn = fn, Cancel = function(self) self.cancelled = true end }
    return tick
  end }
  GetBuildInfo = function() return "export", "?", nil, "?" end
  date = function() return at end
  CreateFrame = function()
    return { RegisterEvent = function() end, UnregisterAllEvents = function() end, SetScript = function() end }
  end
  local ns = { isRetail = client == "retail", isClassicEra = client == "classic_era",
    PadTestBox = function() end, PadTestBoxHide = function() end, Print = function() end, ReloadOrAsk = function() end }
  local chunk = assert(loadfile(dumper))
  chunk("CinematicDev", ns)
  ns.ApiDocsDump()
  while tick and not tick.cancelled do tick.fn() end
  local d = CinematicDB.apiDocs
  d.load = "exportInterfaceFiles code: " .. where
  local loose = {}
  for _, t in ipairs(docs) do
    if not t.Name then for _, each in ipairs(t.Tables or {}) do loose[#loose + 1] = each end end
  end
  if #loose > 0 then
    APIDocumentation.systems = { { Name = "-", Tables = loose } }
    ns.ApiDocsDump()
    while tick and not tick.cancelled do tick.fn() end
    for _, line in ipairs(CinematicDB.apiDocs.lines) do d.lines[#d.lines + 1] = line end
    d.counts = d.counts .. (", plus %d tables outside a system (T -)"):format(#loose)
    CinematicDB.apiDocs = d
  end
  -- The help lines.
  local help = {}
  for _, s in ipairs(docs) do
    local prefix = s.Namespace and (s.Namespace .. ".") or ""
    local function Say(kind, name, docs)
      if type(docs) == "table" and #docs > 0 then
        local parts = {}
        for _, line in ipairs(docs) do parts[#parts + 1] = tostring(line) end
        help[#help + 1] = ("%s %s %s: %s"):format(kind, tostring(s.Name or "-"), name, table.concat(parts, " "))
      end
    end
    Say("S", "", s.Documentation)
    for _, f in ipairs(s.Functions or {}) do Say("F", prefix .. tostring(f.Name), f.Documentation) end
    for _, e in ipairs(s.Events or {}) do Say("E", tostring(e.LiteralName or e.Name), e.Documentation) end
    for _, t in ipairs(s.Tables or {}) do Say("T", tostring(t.Name), t.Documentation) end
  end
  d.help = help
  return d
end
'''


def export_dirs():
    """(client, Blizzard_APIDocumentationGenerated folder) for each client with an export."""
    out = []
    for folder in CLIENT_DIRS:
        d = os.path.join(WOW, folder, GENERATED)
        if os.path.isdir(d):
            out.append((CLIENT_NAMES.get(folder, folder.strip("_")), d))
    return out


def read_export(gen_dir, client):
    """The docs from an export, shaped like read_dump's (plus "help"), or None."""
    toc = os.path.join(gen_dir, "Blizzard_APIDocumentationGenerated.toc")
    files = []
    if os.path.exists(toc):
        for raw in open(toc, encoding="utf-8", errors="replace"):
            line = raw.strip()
            if line and not line.startswith("#") and line.lower().endswith(".lua"):
                files.append(os.path.join(gen_dir, line))
    else:
        files = sorted(glob.glob(os.path.join(gen_dir, "*.lua")))
    files = [f for f in files if os.path.exists(f)]
    if not files:
        return None
    at = time.strftime("%Y-%m-%d %H:%M", time.localtime(max(os.path.getmtime(f) for f in files)))
    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    fn = lua.execute(EXPORT_LUA)
    table = lua.table_from([f.replace("\\", "/") for f in files])
    d = fn(table, DUMPER.replace("\\", "/"), client, at, gen_dir)
    lines, shape, help_ = d["lines"], d["shape"], d["help"]
    return {
        "client": client, "version": d["version"], "build": d["build"], "toc": d["toc"], "at": at,
        "load": d["load"], "counts": d["counts"], "error": d["error"],
        "shape": [shape[i] for i in range(1, len(shape) + 1)] if shape else [],
        "lines": [lines[i] for i in range(1, len(lines) + 1)] if lines else [],
        "help": [help_[i] for i in range(1, len(help_) + 1)] if help_ else [],
        "file": gen_dir,
    }


def compare(game, export, out=print, most=5):
    """The in-game dump against the export's lines: returns (only in the game's, only in the export's)."""
    a, b = set(game["lines"]), set(export["lines"])
    only_game, only_export = sorted(a - b), sorted(b - a)
    out("  %s: in-game dump (%s, %s) vs export (%s): %d same, %d only in the dump, %d only in the export" % (
        game["client"], game["build"], game["at"], export["at"], len(a & b), len(only_game), len(only_export)))
    for line in only_game[:most]:
        out("    dump only:   " + line[:200])
    for line in only_export[:most]:
        out("    export only: " + line[:200])
    return only_game, only_export


def write_help(dump):
    if not dump.get("help"):
        return None
    path = os.path.join(OUT_DIR, dump["client"] + "-help.txt")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("# Documentation lines from %s's exportInterfaceFiles code (%s)\n" % (dump["client"], dump["at"]))
        f.write("\n".join(sorted(dump["help"])) + "\n")
    return path


def main(paths):
    if paths:
        dumps = [d for d in (read_dump(p) for p in paths) if d]
        for d in dumps:
            print("read %s (%s): %d lines -> %s" % (d["file"], d["client"], len(d["lines"]),
                                                   os.path.relpath(write_copy(d), ROOT)))
        if not dumps:
            sys.exit("no API docs in those files")
        return report(dumps, load_rules())
    # Every client: its in-game dump and its export, the newer one written; both there: compared.
    saved, exported = {}, {}
    for p in saved_files():
        d = read_dump(p)
        if d and (d["client"] not in saved or str(d["at"]) > str(saved[d["client"]]["at"])):
            saved[d["client"]] = d
    for client, gen in export_dirs():
        try:
            d = read_export(gen, client)
        except Exception as err:  # (a changed file layout: say so, use the in-game dump)
            print("export %s: couldn't read it: %s" % (client, err))
            continue
        if d:
            exported[client] = d
    dumps = []
    for client in sorted(set(saved) | set(exported)):
        game, export = saved.get(client), exported.get(client)
        if game and export:
            compare(game, export)
        pick = max((x for x in (game, export) if x), key=lambda x: str(x["at"]))
        dumps.append(pick)
        print("%s: %s (%s), %d lines -> %s" % (client, "export" if pick is export else "in-game dump", pick["at"],
                                              len(pick["lines"]), os.path.relpath(write_copy(pick), ROOT)))
        if export:
            h = write_help(export)
            if h:
                print("  %d help line(s) -> %s" % (len(export["help"]), os.path.relpath(h, ROOT)))
    if not dumps:
        sys.exit("no API docs found: export the game's code (-console, then exportInterfaceFiles code at the"
                 " character screen) or run /cine debug apidocs in game, then reload")
    report(dumps, load_rules())


FAKE = r'''
CinematicDB = {
  ["apiDocs"] = {
    ["client"] = "%s", ["version"] = "1.0", ["build"] = "1", ["toc"] = 1, ["at"] = "2030-01-01 00:00",
    ["load"] = "ok", ["counts"] = "1 systems",
    ["shape"] = { "system Name:string" },
    ["lines"] = { %s },
  },
}
'''


def selftest():
    problems = []
    with tempfile.TemporaryDirectory() as tmp:
        a = os.path.join(tmp, "a.lua")
        b = os.path.join(tmp, "b.lua")
        with open(a, "w") as f:
            f.write(FAKE % ("forever", '"F Unit UnitPower(unit:UnitToken, type:number?) -> (power:number {SecretReturns=true})",'
                                       ' "E Unit UNIT_POWER_UPDATE(unitTarget:UnitToken)"'))
        with open(b, "w") as f:
            f.write(FAKE % ("retail", '"F Unit UnitPower(unit:UnitToken) -> (power:number)", "F X C_X.Only() -> ()"'))
        da, db = read_dump(a), read_dump(b)
        old = "F U X(unit:UnitToken {Function={Name=X,Type=Function}}, n:number {Function={A=1},Secret=true}) -> ()"
        if clean(old) != "F U X(unit:UnitToken, n:number {Secret=true}) -> ()":
            problems.append("clean: %r" % clean(old))
        if not da or len(da["lines"]) != 2 or da["client"] != "forever":
            problems.append("read_dump: %r" % da)
        if entry_name("F Unit UnitPower(unit:UnitToken) -> ()") != "UnitPower" or entry_name("E X EV_NAME()") != "EV_NAME":
            problems.append("entry_name")
        fl = flags(da)
        if list(fl) != ["SecretReturns"] or fl["SecretReturns"][0] != 1:
            problems.append("flags: %r" % fl)
        rules = [{"id": "forever.x.only", "clients": ["forever"], "api": ["C_X.Only()", "UnitPower", "SomeFrame"]}]
        said = []
        missing = report([da, db], rules, out=said.append)
        if len(missing) != 1 or "C_X.Only" not in missing[0]:
            problems.append("missing: %r" % missing)
        if not any("RULEFLAGS" in s and "SecretReturns" in s for s in said):
            problems.append("ruleflags: %r" % said)
        # An export: a named system (an Enum value in a flag, help text), a loose enumeration, a constant in a sum.
        gen = os.path.join(tmp, "gen")
        os.makedirs(gen)
        with open(os.path.join(gen, "Blizzard_APIDocumentationGenerated.toc"), "w") as f:
            f.write("## Title: x\n# files\nUnitDocumentation.lua\nAspectDocumentation.lua\nMissing.lua\n")
        with open(os.path.join(gen, "UnitDocumentation.lua"), "w") as f:
            f.write('''local Unit = { Name = "Unit", Type = "System", Namespace = "C_Unit",
  Functions = { { Name = "Power", Type = "Function", SecretReturnsForAspect = { Enum.SecretAspect.Cooldown },
    Documentation = { "Reads power.", "Twice." },
    Arguments = { { Name = "unit", Type = "UnitToken", Nilable = false } },
    Returns = { { Name = "power", Type = "number", Nilable = true } } } },
  Events = { { Name = "PowerUpdate", Type = "Event", LiteralName = "UNIT_POWER", SynchronousEvent = true,
    Payload = { { Name = "unit", Type = "UnitToken", Nilable = false } } } },
  Tables = { { Name = "Max", Type = "Constants", Values = {
    { Name = "SLOTS", Type = "number", Value = Constants.Max.BASE + 1 },
    { Name = "BASE", Type = "number", Value = 4 } } } },
}
APIDocumentation:AddDocumentationTable(Unit);
''')
        with open(os.path.join(gen, "AspectDocumentation.lua"), "w") as f:
            f.write('''local A = { Tables = { { Name = "SecretAspect", Type = "Enumeration", NumValues = 1, MinValue = 32768,
  MaxValue = 32768, Fields = { { Name = "Cooldown", Type = "SecretAspect", EnumValue = 32768 } } } } }
APIDocumentation:AddDocumentationTable(A);
''')
        ex = read_export(gen, "forever")
        want = {
            "F Unit C_Unit.Power(unit:UnitToken) -> (power:number?) {SecretReturnsForAspect={1=32768}}",
            "E Unit UNIT_POWER(unit:UnitToken) {SynchronousEvent=true}",
            "T Unit Max Constants(SLOTS:number {Value=5}, BASE:number {Value=4})",
            "T - SecretAspect Enumeration(Cooldown:SecretAspect {EnumValue=32768}) {MaxValue=32768,MinValue=32768,NumValues=1}",
        }
        if not ex or set(ex["lines"]) != want:
            problems.append("read_export lines: %r" % (ex and sorted(ex["lines"])))
        if not ex or ex["help"] != ["F Unit C_Unit.Power: Reads power. Twice."]:
            problems.append("read_export help: %r" % (ex and ex["help"]))
        if not ex or "1 systems" not in ex["counts"] or "plus 1 tables outside a system" not in ex["counts"]:
            problems.append("read_export counts: %r" % (ex and ex["counts"]))
        game = dict(ex or {}, lines=sorted(want)[:3] + ["F Unit C_Unit.Gone() -> ()"], build="1", at="x")
        said = []
        og, oe = compare(game, ex or {"lines": [], "at": "?"}, out=said.append)
        if og != ["F Unit C_Unit.Gone() -> ()"] or len(oe) != 1 or "3 same" not in said[0]:
            problems.append("compare: %r %r %r" % (og, oe, said))
    for p in problems:
        print("FAIL " + p)
    print("OK" if not problems else "FAILED")
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    if sys.argv[1:] == ["--selftest"]:
        selftest()
    else:
        main(sys.argv[1:])
