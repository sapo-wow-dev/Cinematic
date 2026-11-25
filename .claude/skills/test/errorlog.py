"""The errors around a test run, for read_log.py and Tools/testqueue.py wait (the user, 2026-11-25: "update our
test kit and batch test kit to check error log").

Two sources, both from the saved file:
  * the kit's own inspection lines in the test's log (Dev/TestKit.lua): "during the test: <kind> xN: <message> |
    at <file:line> | <owner>" and "after the test: ...", each counted, with whose it is;
  * CinematicDB.log's deverror / BLOCKED / ERROR lines from the test's session (Dev/ErrorWindow.lua saves each
    error once a session, stack and all; an older test without the kit has only these).
Each distinct error is printed once with its count, place and owner, and matched against the known errors
(Tools/errors/known.lua): KNOWN (accepted / fixed = regression / open) or NEW.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "Tools", "errors"))
_known = None
CLOCK = re.compile(r"^(\d\d):(\d\d):(\d\d)")
KIT = re.compile(r"(during the test|after the test):\s+(.+?) x(\d+): (.*?) \| at (\S+) \| (.*)$")
TALLY = re.compile(r"errors \+(\d+), blocked \+(\d+)")
SESSION_NOTE = re.compile(r"deverror:|BLOCKED|ERROR:")


def known():
    """(module, entries) of Tools/errors, or (None, reason) when lupa or known.lua can't load."""
    global _known
    if _known is None:
        try:
            import errors as mod
            _known = (mod, mod.load())
        except Exception as err:  # (lupa missing, known.lua broken: say so, carry on)
            _known = (None, str(err))
    return _known


def match(text):
    """One line: KNOWN <id> [status] ... per hit, or NEW."""
    mod, entries = known()
    if mod is None:
        return "known errors not loaded (%s)" % entries
    hits = mod.find(text, entries)
    if not hits:
        return "NEW: no known entry; root first (/error), then an entry in Tools/errors/known.lua"
    out = []
    for e in hits:
        what = {"accepted": "accepted, nothing to fix", "fixed": "REGRESSION: fixed before, back"}.get(e["status"], "open")
        out.append("KNOWN %s [%s] %s: %s" % (e["id"], e["status"], what, e["title"]))
    return "; ".join(out)


def kit_errors(lines):
    """[(when, kind, count, message, where, owner, step)] from the kit's inspection lines in a test's log; step: the
    step it first came in ("step 3 probe", "setup", "finish"), from the line's "| first in ..." (None: after DONE)."""
    out = []
    for line in lines:
        m = KIT.search(line)
        if m:
            owner, _, step = m.group(6).partition(" | first in ")
            out.append((m.group(1), m.group(2), int(m.group(3)), m.group(4), m.group(5), owner, step or None))
    return out


def saved_where(line):
    """The test and step an ErrorWindow line says it came in ("[in kitcheck step 3/7 probe]"), or None."""
    m = re.search(r" \[in ([^\]]+)\]", line.split("\n", 1)[0])
    return m.group(1) if m else None


def tally(lines):
    """(errors, blocked) from the kit's DONE/STOPPED line, or None (an older test)."""
    for line in reversed(lines):
        m = TALLY.search(line)
        if m and ("DONE:" in line or "STOPPED:" in line):
            return int(m.group(1)), int(m.group(2))
    return None


def session_begin(game, test_lines):
    """Index in CinematicDB.log where the test's session starts (its first clock time), else the last session."""
    def secs(m):
        return int(m.group(1)) * 3600 + int(m.group(2)) * 60 + int(m.group(3))
    starts = [i for i, l in enumerate(game) if "session: ----" in l]
    begin = starts[-1] if starts else 0
    first = next((CLOCK.match(l) for l in test_lines if CLOCK.match(l)), None)
    if first:
        at = secs(first)
        for i in reversed(starts):
            c = CLOCK.match(game[i])
            if c and secs(c) <= at:
                begin = i
                break
    return begin


def _secs(line):
    m = CLOCK.match(line)
    return int(m.group(1)) * 3600 + int(m.group(2)) * 60 + int(m.group(3)) if m else None


def session_errors(game, begin, test_lines=()):
    """The saved deverror / BLOCKED / ERROR lines from begin on (each with its stack), from the test's first clock
    time on: the session's errors before the test aren't the test's (/error reads those)."""
    start = next((s for s in (_secs(l) for l in test_lines) if s is not None), None)
    out = []
    for line in game[begin:]:
        if SESSION_NOTE.search(line):
            at = _secs(line)
            if start is None or at is None or at >= start - 1:
                out.append(line)
    return out


def report(test_lines, game, show=print):
    """Prints the errors block; returns how many distinct errors there were (0 = clean)."""
    if not test_lines:
        show("== errors: no test log saved, so no start time to read the session's errors from (/error reads them)")
        return 0
    found = kit_errors(test_lines)
    saved = session_errors(game, session_begin(game, test_lines), test_lines) if game else []
    counts = tally(test_lines)
    show("== errors: %s; %d kind(s) the kit inspected, %d deverror/BLOCKED/ERROR line(s) saved since the start" % (
        ("errors +%d, blocked +%d during the test" % counts) if counts else "no kit tally (an older test)",
        len(found), len(saved)))
    used = set()
    for when, kind, n, msg, where, owner, step in found:
        # (The kit's line cuts the message; the saved line has the stack, for the known match.)
        full = next((s for s in saved if msg[:60] and msg[:60] in s), None)
        if full:
            used.add(full)
        came = step or (saved_where(full) if full else None) or ("after DONE" if when == "after the test" else "?")
        show("  %s, in %s: %s x%d at %s | %s\n    %s\n    %s" % (when, came, kind, n, where, owner, msg,
                                                             match(full or msg)))
    rest = [s for s in saved if s not in used]
    if rest:
        show("  saved since the start, not in the kit's lines (an older test, a mid-run reload, the gap to the next):")
        for s in rest[-30:]:
            head = s.split("\n", 1)[0]
            came = saved_where(s)
            show("    %s%s\n      %s" % (head[:300], "" if came else "  (no test or step said)", match(s)))
    if found or rest:
        show("  list EVERY one in the reply: count, file:line, whose; not ours or not this feature = say whose and get it"
             " fixed (dev-errors-in-log)")
    return len(found) + len(rest)
