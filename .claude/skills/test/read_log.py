"""Reads a test's saved log for "check log", with everything around it, and archives it so it's never lost.

usage:
  read_log.py                 every test log in each client's saved file (lines, PASS/FAIL counts), archived
  read_log.py <key> [client]  that log in full (key: mapPinLog, or just mapPin), then from the same session:
                              its errors (errorlog.py: the kit's inspected ones and CinematicDB.log's deverror /
                              BLOCKED / ERROR lines since it started, each matched to Tools/errors), chat lines, the screenshots
                              taken since the test started (paths, to open), and the game's own logs: the
                              console's errors/warnings from the last UI session and FrameXML.log since the
                              test started (gamelogs.py). Archived to Tools/tests/logs/.
  client: forever | retail | classic_era (default: the newest saved file that has the key)
"""
import glob
import os
import re
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import errorlog  # noqa: E402
import gamelogs  # noqa: E402
import savedlogs  # noqa: E402

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
ARCHIVE = os.path.join(REPO, "Tools", "tests", "logs")
CLOCK = re.compile(r"^(\d\d):(\d\d):(\d\d)")
NOTE = re.compile(r"deverror:|BLOCKED|ERROR:|^chat:|blocked|taint", re.I)


def archive(client, path, key, lines):
    os.makedirs(ARCHIVE, exist_ok=True)
    out = os.path.join(ARCHIVE, savedlogs.archive_name(client, path, key, lines))
    if os.path.exists(out) or not lines:
        return out, False
    with open(out, "w", encoding="utf-8") as f:
        f.write("# %s %s, saved %s\n" % (client, key, time.strftime("%Y-%m-%d %H:%M", time.localtime(os.path.getmtime(path)))))
        f.write("\n".join(lines) + "\n")
    return out, True


def counts(lines):
    # (Not a summary's tally, "done: 10 PASS, 0 FAIL": a word after a number
    # is a count, not a verdict; it made a clean run read FAIL 1.)
    # (Nor the kit's closing "verdicts: PASS ...; SKIP ..." line, which repeats
    # every verdict: kitcheck's clean run read PASS 12, SKIP 4 for 6 and 1.)
    text = "\n".join(l for l in lines if not re.match(r"^\S*\s*verdicts: ", l))
    def n(word):
        return len(re.findall(r"(?<!\d )\b%s\b" % word, text))
    return "PASS %d, FAIL %d, SKIP %d" % (n("PASS"), n("FAIL"), n("SKIP"))


def overview():
    for client, path in savedlogs.saved_files():
        saved = os.path.getmtime(path)
        print("== %s, saved %s (%d min ago)" % (client, time.strftime("%Y-%m-%d %H:%M", time.localtime(saved)),
                                                (time.time() - saved) // 60))
        for key, lines in sorted(savedlogs.log_tables(path).items()):
            if key == "log":
                continue
            out, new = archive(client, path, key, lines)
            print("  %-28s %4d lines, %s%s" % (key, len(lines), counts(lines), "  (archived now)" if new else ""))
        notes = gamelogs.console_notes(gamelogs.console_sessions(gamelogs.console_file(path.split(os.sep + "WTF")[0])))
        errors = sum(1 for n in notes if n[0] == "error")
        print("  console, last UI session: %d error(s), %d warning(s)%s" % (
            errors, len(notes) - errors, "  (gamelogs.py %s shows them)" % client if notes else ""))
    print("\narchive: %s (%d files)" % (os.path.relpath(ARCHIVE, REPO), len(glob.glob(os.path.join(ARCHIVE, "*.txt")))))


def seconds(clock):
    h, m, s = (int(x) for x in clock.groups())
    return h * 3600 + m * 60 + s


def one(key, want):
    if not key.endswith("Log") and key != "log":
        key += "Log"
    for client, path in savedlogs.saved_files():
        if want and client != want:
            continue
        tables = savedlogs.log_tables(path)
        if key not in tables:
            continue
        lines = tables[key]
        saved = os.path.getmtime(path)
        print("== %s %s: %d lines, %s; saved %s (%d min ago)" % (
            client, key, len(lines), counts(lines), time.strftime("%Y-%m-%d %H:%M", time.localtime(saved)),
            (time.time() - saved) // 60))
        for line in lines:
            print(line)

        # The session the test ran in: from its first clock time, else the last session's start.
        game = tables.get("log", [])
        starts = [i for i, l in enumerate(game) if "session: ----" in l]
        first = next((CLOCK.match(l) for l in lines if CLOCK.match(l)), None)
        begin = starts[-1] if starts else 0
        if first:
            at = seconds(first)
            for i in reversed(starts):
                c = CLOCK.match(game[i])
                if c and seconds(c) <= at:
                    begin = i
                    break
        # The errors: the kit's inspection lines and the saved ones, each once, matched to the known errors.
        print()
        errorlog.report(lines, game)
        notes = [l for l in game[begin:] if NOTE.search(l) and not errorlog.SESSION_NOTE.search(l)]
        print("\n== CinematicDB.log from %s: %d chat/blocked/taint line(s)" % (game[begin][:8] if game else "?", len(notes)))
        for line in notes[-60:]:
            print(line)

        # Screenshots since the test's start, that day.
        c = CLOCK.match(game[begin]) if game else None
        day = time.localtime(saved)
        since = time.mktime((day.tm_year, day.tm_mon, day.tm_mday, 0, 0, 0, 0, 0, -1)) + (
            seconds(first) if first else (seconds(c) if c else 0))
        shots = sorted(p for p in glob.glob(os.path.join(os.path.dirname(path).split("WTF")[0], "Screenshots", "*"))
                       if os.path.getmtime(p) >= since - 5)
        print("\n== screenshots since then: %d" % len(shots))
        for p in shots:
            print("  %s  %s" % (time.strftime("%H:%M:%S", time.localtime(os.path.getmtime(p))), p))

        # The game's own logs: Blizzard-side errors and load errors our log never sees.
        print()
        gamelogs.report(client, os.path.dirname(path).split(os.sep + "WTF")[0], 1, since - 5)

        out, new = archive(client, path, key, lines)
        print("\narchived: %s%s" % (os.path.relpath(out, REPO), "" if new else " (already)"))
        return
    print("no %s in any saved file%s (the game saves on /reload or logout)" % (key, " for " + want if want else ""))


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    args = sys.argv[1:]
    if args:
        one(args[0], args[1] if len(args) > 1 else None)
    else:
        overview()
