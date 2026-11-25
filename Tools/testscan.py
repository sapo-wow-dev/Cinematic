"""What each kit test asks of the user, step by step, read from its code (for Tools/testqueue.py's catalog).

The queue says per run whether it needs you. Read per test, a test with one step that asks made every run of it
"Needs you", even a run of other steps only (the user, 2026-11-25: "a part of the test that isnt being test in
that run is false flagging it"). So each step is read on its own, with the helper functions it calls (and theirs),
and the setup on its own; the game adds up the steps a run picks.

An ask: r:WaitFor / r:Prompt / r:Click with words, a step's say = "...", an Edit Mode or Target yourself button.
Not an ask (hands off): a wait or prompt with handsOff = true, or whose words say "hands off"; a wait with no words.
A Reload button is counted apart (reloads).

    python -I Tools/testscan.py [test ...]     prints each test's steps and what they ask
"""
import glob
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
SKIP_FILES = ("TestKit.lua", "TestKitWrap.lua", "TestQueue.lua", "TestQueueList.lua")
OPEN = {"function", "if", "do", "repeat"}
CLOSE = {"end", "until"}
WORD = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
PROMPT = re.compile(r"\b(?:r|run|self)\s*:\s*(WaitFor|Prompt|Click)\s*\(")
SAY = re.compile(r"\bsay\s*=\s*")
SECURE = re.compile(r'kind\s*=\s*"(reload|editmode|targetself)"')
HANDS_OFF = re.compile(r"\bhandsOff\s*=\s*true\b")
FUNC_DEF = re.compile(r"\b(?:local\s+)?function\s+([A-Za-z_][\w.:]*)\s*\(|\blocal\s+([A-Za-z_]\w*)\s*=\s*function\s*\(")
CALL = re.compile(r"(?<![\w.:])([A-Za-z_]\w*)\s*\(")
DEFINE = re.compile(r"TestKit\.Define\s*\(")
NAME = re.compile(r'\bname\s*=\s*"([^"]+)"')
NEEDS = re.compile(r'\bneeds\s*=\s*"((?:[^"\\]|\\.)*)"')
KEY = re.compile(r'\bkey\s*=\s*"([^"]+)"')


def unlua(text):
    return re.sub(r"\\(.)", r"\1", text)


def mask(text):
    """The text with every comment and string's inside blanked (same length, quotes kept): code structure only."""
    out = list(text)
    i, n = 0, len(text)

    def blank(a, b):
        for k in range(a, b):
            if out[k] != "\n":
                out[k] = " "

    while i < n:
        c = text[i]
        if c == "-" and text.startswith("--", i):
            m = re.match(r"--\[(=*)\[", text[i:])
            if m:
                end = text.find("]%s]" % m.group(1), i + len(m.group(0)))
                end = n if end < 0 else end + len(m.group(1)) + 2
            else:
                end = text.find("\n", i)
                end = n if end < 0 else end
            blank(i, end)
            i = end
        elif c == "[" and re.match(r"\[(=*)\[", text[i:]):
            m = re.match(r"\[(=*)\[", text[i:])
            close = "]%s]" % m.group(1)
            end = text.find(close, i + len(m.group(0)))
            end = n if end < 0 else end
            blank(i + len(m.group(0)), end)
            i = end + len(close)
        elif c in "\"'":
            j = i + 1
            while j < n and text[j] != c and text[j] != "\n":
                j += 2 if text[j] == "\\" else 1
            blank(i + 1, min(j, n))
            i = j + 1
        else:
            i += 1
    return "".join(out)


def match_close(masked, at, opener, closer):
    """Index just past the bracket that closes the one at `at`."""
    depth = 0
    for k in range(at, len(masked)):
        ch = masked[k]
        if ch == opener:
            depth += 1
        elif ch == closer:
            depth -= 1
            if depth == 0:
                return k + 1
    return len(masked)


def block_end(masked, at):
    """Index just past the `end` closing the block a `function` (or if/do/repeat) word at `at` opens."""
    depth = 0
    for m in WORD.finditer(masked, at):
        w = m.group(0)
        if w in OPEN:
            depth += 1
        elif w in CLOSE:
            depth -= 1
            if depth == 0:
                return m.end()
    return len(masked)


def functions(text, masked):
    """{name: (start, end)} of every named function in the file (its bare name too: M.Ask is also Ask)."""
    out = {}
    for m in FUNC_DEF.finditer(masked):
        name = m.group(1) or m.group(2)
        at = masked.find("function", m.start())
        span = (m.start(), block_end(masked, at))
        out[name] = span
        out[re.split(r"[.:]", name)[-1]] = span
    return out


def first_string(text, masked, at):
    """The first argument at `at` (just past "("): its words if it's a string literal, else None."""
    k = at
    while k < len(text) and text[k] in " \t\r\n":
        k += 1
    if k < len(text) and text[k] in "\"'":
        end = masked.find(text[k], k + 1)
        return unlua(text[k + 1:end]) if end > k else ""
    word = WORD.match(masked, k)
    if word and word.group(0) == "nil":
        return None
    # (Words built at run time, ("..."):format(...) or a variable: an ask with no words we can read.)
    m = re.match(r'\(\s*"((?:[^"\\]|\\.)*)"', text[k:])
    return unlua(m.group(1)) if m else ""


def asks_in(text, masked, a, b):
    """(asks, reloads, first words) in text[a:b], not following calls."""
    asks, first = 0, ""
    for m in PROMPT.finditer(masked, a, b):
        open_at = m.end() - 1
        args_end = match_close(masked, open_at, "(", ")")
        args = text[open_at:args_end]
        words = first_string(text, masked, m.end())
        if words is None and m.group(1) != "Click":
            continue  # (a wait with no words: nothing on the box)
        if HANDS_OFF.search(args) or (words and "hands off" in words.lower()):
            continue
        if re.search(r'kind\s*=\s*"reload"', args):
            continue  # (a Reload box: counted as a reload, below, not twice)
        asks += 1
        if not first and words:
            first = words
    for m in SAY.finditer(masked, a, b):
        words = first_string(text, masked, m.end())
        # (The step's own handsOff = true, anywhere in the step's table.)
        if words is None or (words and "hands off" in words.lower()):
            continue
        asks += 1
        first = first or words or ""
    secure = SECURE.findall(text[a:b])
    asks += sum(1 for k in secure if k != "reload")
    return asks, secure.count("reload"), first


def reach(text, masked, a, b, funcs, seen=None):
    """(asks, reloads, first) in text[a:b] and every file function it calls, each function once."""
    seen = set() if seen is None else seen
    asks, reloads, first = asks_in(text, masked, a, b)
    for m in CALL.finditer(masked, a, b):
        name = m.group(1)
        span = funcs.get(name)
        if not span or name in seen or (span[0] <= m.start() < span[1] and span[0] >= a):
            continue
        seen.add(name)
        x, y, f = reach(text, masked, span[0], span[1], funcs, seen)
        asks, reloads, first = asks + x, reloads + y, first or f
    # (A function passed by name, setup = Setup or run = Step: it runs too.)
    for m in re.finditer(r"\b(?:run|setup)\s*=\s*([A-Za-z_]\w*)\b(?!\s*\()", masked[a:b]):
        name = m.group(1)
        if name in funcs and name not in seen and name != "function":
            seen.add(name)
            span = funcs[name]
            x, y, f = reach(text, masked, span[0], span[1], funcs, seen)
            asks, reloads, first = asks + x, reloads + y, first or f
    return asks, reloads, first


def table_items(masked, a, b):
    """[(start, end)] of each {...} item at the top level of the table body masked[a:b]."""
    items, k = [], a
    while k < b:
        if masked[k] == "{":
            end = match_close(masked, k, "{", "}")
            items.append((k, end))
            k = end
        elif masked[k] == "(":
            k = match_close(masked, k, "(", ")")
        else:
            k += 1
    return items


def Level(masked, a, b):
    """A table item's own level: masked[a:b] with every nested {...}, (...) and function...end blanked."""
    out = list(masked[a:b])
    k = a + 1
    while k < b - 1:
        ch = masked[k]
        end = None
        if ch == "{":
            end = match_close(masked, k, "{", "}")
        elif ch == "(":
            end = match_close(masked, k, "(", ")")
        elif masked.startswith("function", k) and not (masked[k - 1].isalnum() or masked[k - 1] == "_"):
            end = block_end(masked, k)
        if end:
            for x in range(k - a, min(end, b) - a):
                out[x] = " "
            k = end
        else:
            k += 1
    return "".join(out)


def field_span(masked, a, b, field):
    """(start, end) of a field's value in a table body: a {...} table or a function...end."""
    # (Found at the table's own level, not a step's field of the same name.)
    m = re.search(r"\b%s\s*=" % field, Level(masked, a - 1, b + 1)[1:])
    if not m:
        return None
    # (Past the spaces in the masked text itself: in the level view the value is blanked to spaces too.)
    at = a + m.end()
    while at < b and masked[at] in " \t\r\n":
        at += 1
    if masked[at] == "{":
        return at, match_close(masked, at, "{", "}")
    if masked.startswith("function", at):
        return at, block_end(masked, at)
    word = WORD.match(masked, at)
    return (at, word.end()) if word else None


def scan_file(path, root=ROOT):
    text = open(path, encoding="utf-8", errors="ignore").read()
    masked = mask(text)
    funcs = functions(text, masked)
    out = {}
    for d in DEFINE.finditer(masked):
        open_at = d.end() - 1
        end = match_close(masked, open_at, "(", ")")
        body_at = masked.find("{", open_at)
        name = NAME.search(text, body_at, min(end, body_at + 800))
        if not name:
            continue
        needs = NEEDS.search(text, body_at, end)
        info = {"file": os.path.relpath(path, root).replace(os.sep, "/"),
                "needs": unlua(needs.group(1)) if needs else "", "steps": None}
        setup = field_span(masked, body_at + 1, end, "setup")
        info["setup"] = reach(text, masked, *setup, funcs) if setup else (0, 0, "")
        steps = field_span(masked, body_at + 1, end, "steps")
        items = None
        if steps and masked[steps[0]] == "{":
            items = table_items(masked, steps[0] + 1, steps[1] - 1)
        elif steps:
            # (steps = a list built in the file: local steps = { ... } and steps[#steps + 1] = { ... }, a loop's
            # one item for each step it makes; the game matches them by key, "solo" for solo1, solo2...)
            var = masked[steps[0]:steps[1]]
            items = []
            made = re.search(r"\blocal\s+%s\s*=\s*\{" % re.escape(var), masked)
            if made:
                at = made.end() - 1
                items += table_items(masked, at + 1, match_close(masked, at, "{", "}") - 1)
            for m in re.finditer(r"\b%s\s*\[\s*#\s*%s\s*\+\s*1\s*\]\s*=\s*\{" % (re.escape(var), re.escape(var)), masked):
                at = m.end() - 1
                items.append((at, match_close(masked, at, "{", "}")))
            items.sort()
            items = items or None
        if items is not None:
            info["steps"] = []
            for a, b in items:
                key = KEY.search(text, a, b)
                asks, reloads, first = reach(text, masked, a, b, funcs)
                # (A step's own say with handsOff = true at its top level: its words are the box, not an ask.)
                say = SAY.search(masked, a, b)
                if say and re.search(r"\bhandsOff\s*=\s*true\b", Level(masked, a, b)):
                    words = first_string(text, masked, say.end())
                    if words is not None and "hands off" not in (words or "").lower():
                        asks = max(0, asks - 1)
                        first = "" if first == words else first
                info["steps"].append({"key": key.group(1) if key else "?", "asks": asks, "reloads": reloads,
                                      "first": first})
        if info["steps"] is None:
            # (Steps built by code: the whole test read as one, as before.)
            whole = reach(text, masked, body_at, end, funcs)
            info["whole"] = whole
        out[name.group(1)] = info
    return out


def scan(root=ROOT):
    """{test name: {file, needs, setup: (asks, reloads, first), steps: [{key, asks, reloads, first}] or None,
    asks, reloads, first}}: the totals are a full run's."""
    out = {}
    for path in sorted(glob.glob(os.path.join(root, "Dev", "*.lua"))):
        if os.path.basename(path) in SKIP_FILES:
            continue
        for name, info in scan_file(path, root).items():
            parts = [info["setup"]] + [(s["asks"], s["reloads"], s["first"]) for s in info["steps"] or []]
            if info["steps"] is None:
                parts.append(info["whole"])
            info["asks"] = sum(p[0] for p in parts)
            info["reloads"] = sum(p[1] for p in parts)
            info["first"] = next((p[2] for p in parts if p[2]), "")
            out[name] = info
    return out


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    want = set(sys.argv[1:])
    for name, info in sorted(scan().items()):
        if want and name not in want:
            continue
        print("%-18s %-28s asks %d, reloads %d%s" % (name, info["file"], info["asks"], info["reloads"],
                                                    "" if info["steps"] is not None else "  (steps built by code)"))
        if info["setup"][0] or info["setup"][1]:
            print("    setup: asks %d, reloads %d  %s" % info["setup"])
        for i, s in enumerate(info["steps"] or [], 1):
            print("    %2d %-22s %s%s" % (i, s["key"], "asks %d" % s["asks"] if s["asks"] else "hands off",
                                         (", reloads %d" % s["reloads"]) if s["reloads"] else "")
                  + ("  \"%s\"" % s["first"][:70] if s["first"] else ""))
