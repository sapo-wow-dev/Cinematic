"""The console's settings per client: every CVar with its value, default and
flags, and every console command, from the simulation probe's engine step
(Dev/SimProbeTest.lua, /cine debug simprobe step 1: ConsoleGetAllCommands and
C_CVar.GetCVarInfo, saved as CinematicDB.simCVarsLog).

From the repo root:

    python -I Tools/engine/cvars.py                      (every client's saved dev copy)
    python -I Tools/engine/cvars.py <SavedVariables file> ...
    python -I Tools/engine/cvars.py --selftest

For each client it writes Tools/engine/api/<client>-cvars.txt (git-ignored:
Blizzard's data, kept on this PC only, like the API docs): one line per
setting, `cvar<TAB>name<TAB>value<TAB>default<TAB>flags<TAB>help`, and per
command `cmd<TAB>name<TAB><TAB><TAB><TAB>help`, after a `# client ...` header.
flags: account, character, locked, secure, readonly (comma-separated), or
noinfo. The replay bench (Tools/sim/gamedata.lua) reads it: each setting's
default, and which are secure (blocked in a fight).

It prints the counts per client, and SECURE lines for the settings Cinematic's
own sets (ns.CVarSet) write that are secure there.
"""
import os
import re
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, ".claude", "skills", "test"))
import savedlogs  # noqa: E402

OUT_DIR = os.path.join(ROOT, "Tools", "engine", "api")
KEY = "simCVarsLog"
HEADER = re.compile(r"^client (\w+)\|")


def parse(lines):
    """(client, header, settings {name: (value, default, flags, help)}, commands {name: help}) or None."""
    if not lines or not HEADER.match(lines[0]):
        return None
    client = HEADER.match(lines[0]).group(1)
    settings, commands = {}, {}
    for line in lines[1:]:
        parts = line.split("\t")
        if len(parts) < 6:
            continue
        kind, name, value, default, flags, help_ = parts[:6]
        if kind == "cvar":
            settings[name] = (value, default, [f for f in flags.split(",") if f], help_)
        elif kind == "cmd":
            commands[name] = help_
    return client, lines[0], settings, commands


def render(parsed):
    client, header, settings, commands = parsed
    out = ["# " + header, "# Made by Tools/engine/cvars.py from the simulation probe's simCVarsLog. Don't edit."]
    for name in sorted(settings, key=str.lower):
        value, default, flags, help_ = settings[name]
        out.append("\t".join(("cvar", name, value, default, ",".join(flags), help_)))
    for name in sorted(commands, key=str.lower):
        out.append("\t".join(("cmd", name, "", "", "", commands[name])))
    return "\n".join(out) + "\n"


def ours():
    """Every setting name Cinematic's own sets write: ns.CVarSet("...", ..., { values = { name = ... } })."""
    names = set()
    value = re.compile(r"\b([A-Za-z][A-Za-z0-9_]{3,})\s*=\s*\"[^\"]*\"")
    for base, dirs, files in os.walk(ROOT):
        top = os.path.relpath(base, ROOT).split(os.sep)[0]
        if top in ("Tools", "Dev", ".git", "Locales"):
            dirs[:] = []
            continue
        for f in files:
            if not f.endswith(".lua"):
                continue
            with open(os.path.join(base, f), encoding="utf-8", errors="replace") as handle:
                text = handle.read()
            for block in re.finditer(r"CVarSet\(.*?values\s*=\s*\{(.*?)\}", text, re.S):
                names.update(m.group(1) for m in value.finditer(block.group(1)))
    return names


def run(paths):
    found = 0
    mine = ours()
    for client_hint, path in paths:
        tables = savedlogs.log_tables(path)
        parsed = parse(tables.get(KEY))
        if not parsed:
            print("%s: no %s in %s (run /cine debug simprobe 1, then /reload)" % (client_hint, KEY, path))
            continue
        found += 1
        client, header, settings, commands = parsed
        os.makedirs(OUT_DIR, exist_ok=True)
        out = os.path.join(OUT_DIR, "%s-cvars.txt" % client)
        with open(out, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(render(parsed))
        secure = sorted(n for n, s in settings.items() if "secure" in s[2])
        print("%s: %d settings (%d secure), %d commands -> %s" % (client, len(settings), len(secure), len(commands),
                                                                  os.path.relpath(out, ROOT)))
        hit = sorted(n for n in secure if n in mine)
        if hit:
            print("SECURE %s: Cinematic's sets write %d secure settings (blocked in a fight): %s"
                  % (client, len(hit), ", ".join(hit)))
        missing = sorted(n for n in mine if n not in settings)
        if missing:
            print("ABSENT %s: Cinematic's sets name %d settings this client doesn't list: %s"
                  % (client, len(missing), ", ".join(missing)))
    return found


def selftest():
    problems = []
    lines = ["client forever|version 1.60.1|build 71037|toc 16001|at 2026-11-28 10:00",
             "cvar\tnameplateShowAll\t0\t0\tsecure\tShow all plates",
             "cvar\tcameraSmoothStyle\t0\t1\taccount\t",
             "cvar\tbroken\t\t\tnoinfo\t",
             "cmd\treloadui\t\t\t\tReloads the UI",
             "short line"]
    parsed = parse(lines)
    if not parsed or parsed[0] != "forever" or len(parsed[2]) != 3 or len(parsed[3]) != 1:
        problems.append("parse: %r" % (parsed,))
    elif parsed[2]["nameplateShowAll"] != ("0", "0", ["secure"], "Show all plates"):
        problems.append("setting: %r" % (parsed[2]["nameplateShowAll"],))
    text = render(parsed) if parsed else ""
    if "cvar\tbroken\t\t\tnoinfo\t" not in text or not text.startswith("# client forever|"):
        problems.append("render: %r" % text)
    if parse(["no header"]) is not None or parse([]) is not None:
        problems.append("a log with no header was read")
    if "nameplateShowAll" not in ours():
        problems.append("ours: Cinematic's own sets not found (nameplateShowAll)")
    with tempfile.TemporaryDirectory() as tmp:
        sv = os.path.join(tmp, "CinematicDev.lua")
        with open(sv, "w", encoding="utf-8") as handle:
            handle.write("CinematicDB = {\n[\"%s\"] = {\n" % KEY)
            for line in lines:
                handle.write("\"%s\", -- [1]\n" % line.replace("\t", "\\t"))
            handle.write("},\n}\n")
        tables = savedlogs.log_tables(sv)
        if parse(tables.get(KEY)) is None:
            problems.append("SavedVariables: %r" % tables.get(KEY))
    print("cvars selftest: " + ("ok" if not problems else "FAIL\n  " + "\n  ".join(problems)))
    return not problems


def main():
    if sys.argv[1:] == ["--selftest"]:
        sys.exit(0 if selftest() else 1)
    paths = [("file", p) for p in sys.argv[1:]] or savedlogs.saved_files()
    if not paths:
        print("no saved dev copy found under %s" % savedlogs.WOW)
        sys.exit(1)
    sys.exit(0 if run(paths) else 1)


if __name__ == "__main__":
    main()
