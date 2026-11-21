"""Reads the game's own API docs saved by /cine debug apidocs (Dev/ApiDocsDump.lua)
and checks the engine rules against them. From the repo root:

    python -I Tools/engine/apidocs.py                 (every client's saved copy)
    python -I Tools/engine/apidocs.py <SavedVariables file> ...
    python -I Tools/engine/apidocs.py --selftest

For each client with a saved copy it writes Tools/engine/api/<client>.txt (one
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


def main(paths):
    files = paths or saved_files()
    dumps = []
    for p in files:
        d = read_dump(p)
        if d:
            dumps.append(d)
            print("read %s (%s): %d lines -> %s" % (p, d["client"], len(d["lines"]),
                                                   os.path.relpath(write_copy(d), ROOT)))
    if not dumps:
        sys.exit("no saved API docs found: run /cine debug apidocs in game, then reload")
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
    for p in problems:
        print("FAIL " + p)
    print("OK" if not problems else "FAILED")
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    if sys.argv[1:] == ["--selftest"]:
        selftest()
    else:
        main(sys.argv[1:])
