"""Known errors and don'ts (Tools/errors/known.lua). From the repo root:

    python -I Tools/errors/errors.py match [file]   which entries an error matches (stdin or a file)
    python -I Tools/errors/errors.py check [root]   the don't-checks over our Lua (pre-commit runs it)
    python -I Tools/errors/errors.py selftest       fields, ids, regexes, examples
    python -I Tools/errors/errors.py list           one line per entry

Needs lupa (pip install lupa), as Tools/offline/run.py does.
"""
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
STATUSES = ("open", "fixed", "accepted")
WHY = ("call", "caller", "path", "rule", "pattern")
# (Not ours, or not code: never checked.)
SKIP = ("Libs/", "Tools/", "Locales/")


def _lua():
    import lupa.lua51 as lua51
    return lua51.LuaRuntime(unpack_returned_tuples=True)


def _py(value):
    """A lupa table as Python lists/dicts (strings stay strings)."""
    if value is None or isinstance(value, (str, int, float, bool)):
        return value
    keys = list(value.keys())
    if keys and all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)):
        return [_py(value[k]) for k in sorted(keys)]
    if not keys:
        return []
    return {k: _py(value[k]) for k in keys}


def load(path=None):
    path = path or os.path.join(HERE, "known.lua")
    with open(path, encoding="utf-8") as f:
        source = f.read()
    entries = _lua().execute(source)
    return _py(entries)


def matches(entry, text):
    m = entry.get("match") or {}
    if not isinstance(m, dict) or not (m.get("all") or m.get("any")):
        return False
    if any(s not in text for s in m.get("all") or []):
        return False
    if m.get("any") and not any(s in text for s in m["any"]):
        return False
    if any(s in text for s in m.get("none") or []):
        return False
    return True


def find(text, entries=None):
    return [e for e in (entries if entries is not None else load()) if matches(e, text)]


def describe(entry):
    """What /error prints for a match: what to do depends on the status."""
    status = entry["status"]
    lines = ["KNOWN %s [%s]: %s" % (entry["id"], status, entry["title"])]
    if status == "accepted":
        lines.append("  accepted, nothing to fix: " + entry.get("fix", ""))
    elif status == "fixed":
        lines.append("  REGRESSION: fixed before (%s) and seen again. The fix didn't hold: go back to the why,"
                     " find what it missed; don't patch the line." % entry.get("fix", ""))
    else:
        lines.append("  open: keep digging; the why below is what's known so far")
    if entry.get("note"):
        lines.append("  note: " + entry["note"])
    lines.append("  don't: " + entry["dont"])
    for k in WHY:
        lines.append("  why.%s: %s" % (k, entry["why"][k]))
    return "\n".join(lines)


def cmd_match(args):
    text = open(args[0], encoding="utf-8", errors="replace").read() if args else sys.stdin.read()
    hits = find(text)
    if not hits:
        print("NO MATCH: a new error. Find the root before any fix: fill the five why parts"
              " (call, caller, path, rule, pattern), then add the entry with this error as its example.")
        return 0
    for e in hits:
        print(describe(e))
    return 0


def _code(line, state):
    """The line with its Lua comments cut (state[0] = inside a --[[ ]] block)."""
    out = ""
    i = 0
    while i < len(line):
        if state[0]:
            end = line.find("]]", i)
            if end < 0:
                return out
            state[0] = False
            i = end + 2
            continue
        # (Strings are kept as they are; a -- inside a string is rare here.)
        dash = line.find("--", i)
        if dash < 0:
            return out + line[i:]
        out += line[i:dash]
        if line.startswith("--[[", dash) or line.startswith("--[=[", dash):
            state[0] = True
            i = dash + 4
            continue
        return out
    return out


def _files(root):
    try:
        listed = subprocess.run(["git", "ls-files", "*.lua"], cwd=root, capture_output=True, text=True,
                                check=True).stdout.split()
    except (OSError, subprocess.CalledProcessError):
        listed = []
        for base, _, names in os.walk(root):
            for n in names:
                if n.endswith(".lua"):
                    listed.append(os.path.relpath(os.path.join(base, n), root).replace("\\", "/"))
    return [f for f in listed if not f.startswith(SKIP)]


def check(root, entries=None):
    entries = entries if entries is not None else load()
    rules = [(e, re.compile(e["check"]["pattern"]), e["check"].get("allow") or [])
             for e in entries if isinstance(e.get("check"), dict)]
    hits = []
    for rel in _files(root):
        path = os.path.join(root, rel)
        if not os.path.isfile(path):
            continue
        mine = [(e, rx) for e, rx, allow in rules if not any(rel == a or (a.endswith("/") and rel.startswith(a))
                                                             for a in allow)]
        if not mine:
            continue
        state = [False]
        with open(path, encoding="utf-8", errors="replace") as f:
            for n, raw in enumerate(f, 1):
                code = _code(raw.rstrip("\n"), state)
                if not code.strip():
                    continue
                for e, rx in mine:
                    if rx.search(code) and ("dont-ok: " + e["id"]) not in raw:
                        hits.append((rel, n, e, raw.strip()))
    return hits


def cmd_check(args):
    root = args[0] if args else ROOT
    hits = check(root)
    for rel, n, e, line in hits:
        print("%s:%d: don't [%s]: %s\n    %s" % (rel, n, e["id"], e["dont"], line))
    if hits:
        print("errors check: %d line(s) do what a known error says never to do (Tools/errors/known.lua);"
              " fix them, or mark a sanctioned one with -- dont-ok: <id> and why" % len(hits))
        return 1
    print("errors check: clean")
    return 0


def _engine_ids():
    lua = _lua()
    cwd = os.getcwd()
    try:
        os.chdir(ROOT)
        got = lua.eval('dofile("Tools/engine/rules.lua")')
        rules = _py(got[0] if isinstance(got, tuple) else got)
    finally:
        os.chdir(cwd)
    return {r["id"] for r in rules}


def selftest():
    entries = load()
    problems = []
    seen = set()
    try:
        engine = _engine_ids()
    except Exception as err:  # (engine rules broken: their own check says why)
        engine = None
        problems.append("engine rules didn't load: %s" % err)
    for i, e in enumerate(entries, 1):
        name = e.get("id") or "#%d" % i
        if not isinstance(e.get("id"), str) or not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", e["id"]):
            problems.append("%s: id must be short kebab-case" % name)
        if name in seen:
            problems.append("%s: id used twice" % name)
        seen.add(name)
        if e.get("status") not in STATUSES:
            problems.append("%s: status must be one of %s" % (name, ", ".join(STATUSES)))
        for k in ("title", "dont", "example"):
            if not isinstance(e.get(k), str) or not e[k].strip():
                problems.append("%s: needs %s" % (name, k))
        why = e.get("why")
        if not isinstance(why, dict):
            problems.append("%s: needs why = { %s }" % (name, ", ".join(WHY)))
        else:
            for k in WHY:
                if not isinstance(why.get(k), str) or not why[k].strip():
                    problems.append("%s: why.%s missing (the root isn't found till all five are)" % (name, k))
        if e.get("status") in ("fixed", "accepted") and not e.get("fix"):
            problems.append("%s: %s needs fix (what was done or decided)" % (name, e.get("status")))
        m = e.get("match")
        if not isinstance(m, dict) or not (m.get("all") or m.get("any")):
            problems.append("%s: match needs all or any" % name)
        if isinstance(e.get("check"), dict):
            try:
                re.compile(e["check"].get("pattern") or "")
            except re.error as err:
                problems.append("%s: check pattern: %s" % (name, err))
            if not e["check"].get("pattern"):
                problems.append("%s: check needs pattern" % name)
        if engine is not None:
            for rid in e.get("engine") or []:
                if rid not in engine:
                    problems.append("%s: engine rule %s not in Tools/engine/rules" % (name, rid))
        if isinstance(e.get("example"), str):
            got = [x["id"] for x in find(e["example"], entries)]
            if got != [e.get("id")]:
                problems.append("%s: its example matches %s (must be itself only)" % (name, got or "nothing"))
    # (The checker itself: a hit, a comment, a sanctioned line, a block comment.)
    fake = {"id": "x", "dont": "d", "check": {"pattern": r"Bad\("}}
    state = [False]
    cases = [("Bad()", True), ("-- Bad()", False), ("ok() -- Bad()", False), ("Bad() -- dont-ok: x", False),
             ("--[[ Bad()", False), ("Bad() ]]", False), ("Bad()", True)]
    for line, want in cases:
        code = _code(line, state)
        got = bool(re.search(fake["check"]["pattern"], code)) and "dont-ok: x" not in line
        if got != want:
            problems.append("checker: %r gave %s" % (line, got))
    for p in problems:
        print("FAIL " + p)
    print("%d entries, %s" % (len(entries), "ALL PASS" if not problems else "%d FAILED" % len(problems)))
    return 1 if problems else 0


def cmd_list(_):
    for e in load():
        print("%-38s %-9s %s" % (e["id"], e["status"], e["title"]))
    return 0


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ("match", "check", "selftest", "list"):
        sys.exit(__doc__)
    cmd = sys.argv[1]
    if cmd == "selftest":
        return selftest()
    return {"match": cmd_match, "check": cmd_check, "list": cmd_list}[cmd](sys.argv[2:])


if __name__ == "__main__":
    sys.exit(main())
