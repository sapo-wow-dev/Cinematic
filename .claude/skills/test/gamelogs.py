"""The game's own logs, read beside ours: the console's saved history and Logs/FrameXML.log.

- <client>/WTF/SavedVariables/Blizzard_Console.lua: Blizzard_Console keeps the console's last 1000 lines
  (SavedVariablesMachine), saved on /reload and logout like ours, with or without -console (retail's held
  Cinematic's own Lua errors on 2026-11-20 with no -console). No times: each UI load adds a "Previous Session" line,
  so the lines after the last one are the last UI session. Color 3 = error (Lua errors with their stack, including
  errors in Blizzard's own code that never reach CinematicDB.log), 4 = warning.
- <client>/Logs/FrameXML.log: load-time errors with time and file (a syntax error: the file never ran, so our own
  log can't say it).

    python -I .claude/skills/test/gamelogs.py [client] [sessions=1]    (both, for one client or every client)
    python -I .claude/skills/test/gamelogs.py --selftest

Used by read_log.py (check log) and the /error skill's recent_errors.py.
"""
import os
import re
import sys
import tempfile
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gamesource  # noqa: E402
import savedlogs  # noqa: E402

ENTRY = re.compile(r'\{\s*\n"((?:[^"\\]|\\.)*)",\s*\n(\d+),\s*\n\}')
BREAK = "Previous Session"
COLORS = {3: "error", 4: "warning"}
XMLLINE = re.compile(r"^(\d\d)/(\d\d) (\d\d):(\d\d):(\d\d)\.\d+\s+(.*)$")
OURS = re.compile(r"Cinematic", re.I)


def client_dirs(wow=savedlogs.WOW):
    """(client, client folder) for each client folder that exists."""
    return [(c, os.path.join(wow, f)) for f, c in savedlogs.CLIENTS.items() if os.path.isdir(os.path.join(wow, f))]


def console_file(client_dir):
    return os.path.join(client_dir, "WTF", "SavedVariables", "Blizzard_Console.lua")


def console_sessions(path):
    """[[(message, color)], ...] oldest UI session first; [] if there's no file."""
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            text = f.read()
    except OSError:
        return []
    block = text.split('["messageHistory"]', 1)[-1].split('["commandHistory"]', 1)[0]
    sessions = [[]]
    for m in ENTRY.finditer(block):
        msg = savedlogs.unescape(m.group(1))
        if BREAK in msg and msg.strip("- ").startswith(BREAK):
            sessions.append([])
        else:
            sessions[-1].append((msg, int(m.group(2))))
    return sessions


def console_notes(sessions, last=1):
    """[(kind, count, message, ours)] for the errors and warnings of the last sessions, in order; repeats of the same
    first line fold into one row (its first stack kept)."""
    seen, out = {}, []
    for session in sessions[-last:] if last else sessions:
        for msg, color in session:
            if color not in COLORS:
                continue
            key = (color, msg.strip().splitlines()[0] if msg.strip() else "")  # (same error, other caller: one row)
            if key in seen:
                seen[key][1] += 1
                continue
            row = [COLORS[color], 1, msg, bool(OURS.search(msg))]
            seen[key] = row
            out.append(row)
    return [tuple(r) for r in out]


def framexml_lines(client_dir, since):
    """FrameXML.log lines logged at or after `since` (epoch seconds), as (epoch, text)."""
    path = os.path.join(client_dir, "Logs", "FrameXML.log")
    try:
        year = time.localtime(os.path.getmtime(path)).tm_year
        lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    except OSError:
        return []
    out = []
    for line in lines:
        m = XMLLINE.match(line)
        if not m:
            if out:
                out[-1] = (out[-1][0], out[-1][1] + " " + line.strip())
            continue
        mo, d, h, mi, s = (int(x) for x in m.groups()[:5])
        when = time.mktime((year, mo, d, h, mi, s, 0, 0, -1))
        if when >= since:
            out.append((when, m.group(6)))
    return out


def report(client, client_dir, last=1, since=None, show=print, known=None, source=True, wow=savedlogs.WOW):
    """Prints the console's errors/warnings (last UI sessions) and FrameXML.log since `since`; returns the count.
    Under each error: the game's own code at its Blizzard frames, from the client's export (gamesource.explain)."""
    path = console_file(client_dir)
    sessions = console_sessions(path)
    count = 0
    if sessions:
        saved = os.path.getmtime(path)
        notes = console_notes(sessions, last)
        errors = sum(1 for n in notes if n[0] == "error")
        show("== %s console (saved %s, last %d UI session(s) of %d): %d error(s), %d warning(s)" % (
            client, time.strftime("%Y-%m-%d %H:%M", time.localtime(saved)), min(last, len(sessions)), len(sessions),
            errors, len(notes) - errors))
        for kind, n, msg, ours in notes:
            count += 1
            lines = msg.strip().splitlines()
            show("  %s%s%s: %s" % (kind, " x%d" % n if n > 1 else "", "" if ours else " (game code only)", lines[0][:300]))
            for line in lines[1:8]:
                show("      " + line[:200])
            if kind == "error" and source:
                gamesource.explain(msg, client, show, wow)
            if known and kind == "error":
                known(msg)
    else:
        show("== %s console: no saved history (%s)" % (client, path))
    if since is None:
        since = time.time() - 86400
    xml = framexml_lines(client_dir, since)
    show("== %s FrameXML.log since %s: %d line(s)" % (client, time.strftime("%m-%d %H:%M", time.localtime(since)), len(xml)))
    for when, text in xml[-30:]:
        count += 1
        show("  %s  %s" % (time.strftime("%m-%d %H:%M:%S", time.localtime(when)), text[:300]))
        if known:
            known(text)
    return count


def selftest():
    import shutil
    tmp = tempfile.mkdtemp()
    try:
        cdir = os.path.join(tmp, "_forever_")
        os.makedirs(os.path.join(cdir, "WTF", "SavedVariables"))
        os.makedirs(os.path.join(cdir, "Logs"))

        def entry(msg, color):
            return '{\n"%s",\n%d,\n},\n' % (msg.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n"), color)
        sep = "-" * 50 + " Previous Session " + "-" * 50
        body = (entry("old error", 3) + entry(sep, 0) + entry("Battle.net logon", 0)
                + entry('Lua Error: Interface/AddOns/CinematicDev/Core.lua:1: boom "x"\n[C]: in function', 3)
                + entry('Lua Error: Interface/AddOns/CinematicDev/Core.lua:1: boom "x"\n[C]: in function', 3)
                + entry("Lua Error: ...Blizzard_UnitFrame/CompactUnitFrame.lua:1557: bad argument\n[C]: a", 3)
                + entry("Lua Error: ...Blizzard_UnitFrame/CompactUnitFrame.lua:1557: bad argument\n[C]: b", 3)
                + entry("Overlay is disabled.", 4))
        with open(console_file(cdir), "w", encoding="utf-8") as f:
            f.write('Blizzard_Console_SavedVars = {\n["version"] = 3,\n["messageHistory"] = {\n%s},\n'
                    '["commandHistory"] = {\n"exportInterfaceFiles code",\n},\n}\n' % body)
        now = time.localtime()
        with open(os.path.join(cdir, "Logs", "FrameXML.log"), "w") as f:
            f.write("01/01 00:00:01.000  old line\n%s.123  Interface/AddOns/CinematicDev/Dev/PaceTest.lua:373: 'end' expected\n"
                    % time.strftime("%m/%d %H:%M:%S", now))
        sessions = console_sessions(console_file(cdir))
        notes = console_notes(sessions, 1)
        bad = []
        if len(sessions) != 2 or [m for m, _ in sessions[0]] != ["old error"]:
            bad.append("sessions %r" % sessions)
        if [(k, n, o) for k, n, _, o in notes] != [("error", 2, True), ("error", 2, False), ("warning", 1, False)]:
            bad.append("notes %r" % notes)
        if notes and notes[0][2] != 'Lua Error: Interface/AddOns/CinematicDev/Core.lua:1: boom "x"\n[C]: in function':
            bad.append("unescape %r" % notes[0][2])
        if len(console_notes(sessions, 0)) != 4:  # (old error + the three rows)
            bad.append("all sessions")
        out = []
        seen = []
        # (The game's code under a Blizzard error, from a stand-in export.)
        uf = os.path.join(cdir, "BlizzardInterfaceCode", "Interface", "AddOns", "Blizzard_UnitFrame")
        os.makedirs(uf)
        with open(os.path.join(uf, "Blizzard_UnitFrame.toc"), "w") as f:
            f.write("CompactUnitFrame.lua\n")
        with open(os.path.join(uf, "CompactUnitFrame.lua"), "w") as f:
            f.write("\n" * 1556 + "\tlocal widgetSetID = UnitWidgetSet(frame.unit);\n")
        n = report("forever", cdir, 1, time.time() - 3600, out.append, seen.append, wow=tmp)
        if not any("game code: forever Blizzard_UnitFrame/CompactUnitFrame.lua:1557 [loads]" in l for l in out) \
                or not any("> 1557" in l and "UnitWidgetSet(frame.unit)" in l for l in out):
            bad.append("game code under the error %r" % out)
        if n != 4 or len(seen) != 3 or not any("PaceTest.lua:373" in l for l in out) or any("old line" in l for l in out):
            bad.append("report %d %d %r" % (n, len(seen), out))
        if not any("(game code only)" in l and "CompactUnitFrame" in l for l in out):
            bad.append("game-code mark")
        print("selftest: %s" % ("PASS" if not bad else "FAIL\n  " + "\n  ".join(bad)))
        return not bad
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    args = sys.argv[1:]
    if args == ["--selftest"]:
        sys.exit(0 if selftest() else 1)
    want = args[0] if args and not args[0].isdigit() else None
    last = int(next((a for a in args if a.isdigit()), "1"))
    for client, cdir in client_dirs():
        if want and client != want:
            continue
        report(client, cdir, last)
        print()
