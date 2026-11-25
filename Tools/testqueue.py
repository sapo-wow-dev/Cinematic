"""The test queue, the sessions' side: queue a kit test for the next game run, wait for its result.

Several Claude sessions work at once; each queues its own kit test here instead of handing the user a command.
The user /reloads once, clicks Run all, and the game runs every queued test one after another (Dev/TestQueue.lua),
then reloads to save. Each session's `wait` sees its own result then.

    python -I Tools/testqueue.py add <test> [args] --session "<short name>" [--note "what it checks"] [--needs "be in a city"]
                                     [--client forever|retail|both]   (default: either, the first client that runs it)
        queues a kit test (the name /cine debug takes; its args: step numbers, full); prints the id. --needs: where the
        user must be or what they need (the picker shows it; what the test asks is found on its own)
    python -I Tools/testqueue.py wait <id> [--timeout MIN] [--keep]
        waits for the result in the saved file (run it in the background); prints the result line and the log
        to read (read_log.py testQueue_<id>); then takes the entry off the queue unless --keep. Not clean (a FAIL,
        stop, reported issue): also prints "requeue: <add command>" for the session's Requeue button
    python -I Tools/testqueue.py list [--client retail]   what's queued, each client's result; --client: just what that
                                                          client still owes
    python -I Tools/testqueue.py remove <id ...> | --session "<name>"
    python -I Tools/testqueue.py errors --session "<name>" [--client forever]
        the last queue run's errors, load errors at its reloads and between tests too (wait prints this as well):
        each not accepted in Tools/errors/known.lua is claimed for one session (Dev/TestQueueErrorClaims.json);
        FIX NOW lines are this session's to fix at the root without asking. Exit 1 when any are
    python -I Tools/testqueue.py catalog         rescans every kit test for what it asks of the user (add/remove do too)
    python -I Tools/testqueue.py selftest        checks this script on a scratch copy

The list is Dev/TestQueueList.lua (git-ignored), read by the game at /reload; a lock file keeps two sessions from
writing it at once. A test changed after it was queued runs with the code loaded at that /reload.
"""
import argparse
import importlib.util
import os
import random
import re
import sys
import tempfile
import time

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
QUEUE = os.path.join(ROOT, "Dev", "TestQueueList.lua")
sys.path.insert(0, os.path.join(ROOT, ".claude", "skills", "test"))
import errorlog  # noqa: E402
import savedlogs  # noqa: E402
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import testscan  # noqa: E402

HEAD = ("-- The test queue's list (Tools/testqueue.py writes it, Dev/TestQueue.lua runs it). Not kept in git.\n"
        "local _, ns = ...\nns.TestQueueList = {\n")
FIELDS = ("id", "test", "args", "session", "note", "needs", "client", "added")
CLIENTS = ("forever", "retail")
ENTRY = re.compile(r"^\s*\{(.*)\},\s*$")
FIELD = re.compile(r'(\w+) = "((?:[^"\\]|\\.)*)"')
ISSUE = re.compile(r'\bissue client=(\S+) id=(\S+) test=(\S+) step=(\S+) msg="((?:[^"\\]|\\.)*)"')
RESULT = re.compile(r"\bid=(\S+) test=(\S+) session=\"((?:[^\"\\]|\\.)*)\" result=(.*?) log=(\S+)$")


def lua_str(text):
    return '"%s"' % str(text).replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ").replace("\r", " ")


def unlua(text):
    return re.sub(r"\\(.)", r"\1", text)


def read(path):
    if not os.path.exists(path):
        return []
    out = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            if line.startswith("ns.TestQueueCatalog"):
                break
            m = ENTRY.match(line)
            if m:
                out.append({k: unlua(v) for k, v in FIELD.findall(m.group(1))})
    return out


def scan(root=ROOT):
    """{test name: {asks, first, reloads, needs, file, setup, steps}}: what each kit test asks of the user, step by
    step (Tools/testscan.py). The totals are a full run's; the game adds up just the steps a run picks."""
    return testscan.scan(root)


def catalog_line(name, c):
    def part(asks, reloads, first, key=None):
        return "{ %sasks = %d, reloads = %d, first = %s }" % ("key = %s, " % lua_str(key) if key else "", asks,
                                                             reloads, lua_str(first))
    steps = c.get("steps")
    return '\t[%s] = { asks = %d, reloads = %d, first = %s, file = %s, setup = %s%s },\n' % (
        lua_str(name), c["asks"], c["reloads"], lua_str(c["first"]), lua_str(c["file"]),
        part(*(c.get("setup") or (0, 0, ""))),
        "" if steps is None else ", steps = { %s }" % ", ".join(
            part(s["asks"], s["reloads"], s["first"], s["key"]) for s in steps))


def write(path, entries, catalog=None):
    catalog = scan() if catalog is None else catalog
    body = "".join("\t{ %s },\n" % ", ".join("%s = %s" % (k, lua_str(e.get(k, ""))) for k in FIELDS) for e in entries)
    cat = "".join(catalog_line(name, c) for name, c in sorted(catalog.items()))
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8", newline="\n") as f:
        f.write(HEAD + body + "}\n-- What each kit test asks of you (testqueue.py scans the tests' code).\n"
                "ns.TestQueueCatalog = {\n" + cat + "}\n")
    os.replace(tmp, path)


class Lock:
    """A lock file beside the list: one writer at a time (a stale one, over 30 s old, is taken over)."""

    def __init__(self, path):
        self.path = path + ".lock"

    def __enter__(self):
        start = time.time()
        while True:
            try:
                os.close(os.open(self.path, os.O_CREAT | os.O_EXCL | os.O_WRONLY))
                return self
            except FileExistsError:
                try:
                    if time.time() - os.path.getmtime(self.path) > 30:
                        os.remove(self.path)
                        continue
                except OSError:
                    pass
                if time.time() - start > 20:
                    raise SystemExit("testqueue: the list is locked (%s); try again" % self.path)
                time.sleep(0.1)

    def __exit__(self, *_):
        try:
            os.remove(self.path)
        except OSError:
            pass


def old_tests(root=ROOT):
    """The older tests (Dev/TestKitWrap.lua's OLD list): queued too, the user clicks Done on each."""
    path = os.path.join(root, "Dev", "TestKitWrap.lua")
    if not os.path.exists(path):
        return set()
    return set(re.findall(r'\{\s*cmd\s*=\s*"([^"]+)"', open(path, encoding="utf-8", errors="ignore").read()))


def kit_tests():
    spec = importlib.util.spec_from_file_location("kit_names", os.path.join(ROOT, "Tools", "kit-names.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return {name for name, _ in mod.kit_names()} | old_tests()


def results():
    """{id: {client: (saved time, result line fields)}} from each client's saved file (its last line per id)."""
    out = {}
    for client, path in savedlogs.saved_files():
        for line in savedlogs.log_tables(path).get("testQueueLog", []):
            m = RESULT.search(line)
            if m:
                out.setdefault(m.group(1), {})[client] = (os.path.getmtime(path), {
                    "test": m.group(2), "session": unlua(m.group(3)), "result": m.group(4), "log": m.group(5),
                    "line": line})
    return out


def requeue_command(entry):
    """The add command that queues this entry again (the session's Requeue button runs it)."""
    if not entry:
        return ""
    parts = ["python -I Tools/testqueue.py add", entry["test"]]
    if entry.get("args"):
        parts.append(entry["args"])
    parts.append("--session %s" % lua_str(entry.get("session", "")))
    for key in ("note", "needs", "client"):
        if entry.get(key):
            parts.append("--%s %s" % (key, lua_str(entry[key])))
    return " ".join(parts)


def issues():
    """{id: [(client, step, message)]}: what the user reported with Report issue, from each client's saved file."""
    out = {}
    for client, path in savedlogs.saved_files():
        for line in savedlogs.log_tables(path).get("testQueueLog", []):
            m = ISSUE.search(line)
            if m:
                out.setdefault(m.group(2), []).append((client, m.group(4), unlua(m.group(5))))
    return out


def needed(entry):
    """The clients an entry waits for: one of them (either), or each of them."""
    want = (entry or {}).get("client", "")
    if want == "both":
        return "all", CLIENTS
    if want in CLIENTS:
        return "all", (want,)
    return "any", CLIENTS


def owed(entry, got):
    """The clients still owing this entry a result."""
    how, clients = needed(entry)
    have = [c for c in clients if c in got]
    if how == "any":
        return [] if have else list(clients)
    return [c for c in clients if c not in got]


def good(result):
    # (An older test's RAN: the user clicked Done; its FAIL lines counted.)
    return result.startswith(("DONE", "RAN")) and " fail=0 " in result


def add(path, test, args, session, note, known=None, needs="", catalog=None, client=""):
    known = kit_tests() if known is None else known
    if test not in known:
        raise SystemExit("testqueue: %r is neither a kit test (ns.TestKit.Define in Dev/*.lua) nor an older one "
                         "(Dev/TestKitWrap.lua's OLD list)" % test)
    with Lock(path):
        entries = read(path)
        ids = {e.get("id") for e in entries}
        while True:
            new = "q%04x" % random.randrange(0x10000)
            if new not in ids:
                break
        entries.append({"id": new, "test": test, "args": args, "session": session, "note": note, "needs": needs,
                        "client": client,
                        "added": time.strftime("%Y-%m-%d %H:%M")})
        write(path, entries, catalog)
    return new, len(entries)


def remove(path, ids=(), session=None, catalog=None):
    with Lock(path):
        entries = read(path)
        keep = [e for e in entries if e.get("id") not in ids and not (session and e.get("session") == session)]
        write(path, keep, catalog)
    return len(entries) - len(keep)


def run_errors(qid, client, log_key):
    """Prints a result's errors (errorlog.py: the kit's inspected ones in its copied log, and the saved
    deverror / BLOCKED / ERROR lines since it started, matched to the known errors); returns how many kinds."""
    for c, path in savedlogs.saved_files():
        if c == client:
            tables = savedlogs.log_tables(path)
            return errorlog.report(tables.get(log_key, []), tables.get("log", []))
    return 0


# The queue-wide error sweep (the user, 2026-11-25: "i need the test kit to auto fix errors"). A test's own errors
# reach the session that queued it; a load error at a reload, or one between two tests, belonged to no test and
# so to no session: the same ones came back every reload. The sweep takes every saved deverror / BLOCKED / ERROR
# line from the reload the queue started on to the save, one per error, matched to Tools/errors/known.lua, and
# claims each one that isn't accepted for one session (the first whose wait or `errors` sees it), so it's fixed
# once, at its root, without asking.
CLAIMS = os.path.join(ROOT, "Dev", "TestQueueErrorClaims.json")
CLAIM_DAYS = 1  # (a claim older than this, its error still coming: up for grabs again)
CLOCK = re.compile(r"^(\d\d):(\d\d):(\d\d)")
QSTART = re.compile(r"^\d{4}-\d\d-\d\d (\d\d):(\d\d):(\d\d) queue start")
NOTE = re.compile(r"^[\d:.]+ (deverror: |BLOCKED|ERROR: )")


def _clock(m):
    return int(m.group(1)) * 3600 + int(m.group(2)) * 60 + int(m.group(3))


def error_sig(line):
    """One error's name: its first line without the time, the kind word, the [in ...] stamp or the path's start."""
    head = line.split("\n", 1)[0]
    head = re.sub(r"^[\d:.]+ ", "", head)
    head = re.sub(r"^(deverror: |ERROR: )", "", head)
    head = re.sub(r"^(caught|warning|error|blocked|BLOCKED):? ", "", head)
    head = re.sub(r" \[(in|after) [^\]]*\]$", "", head)
    head = re.sub(r"(\.\.\.|\S*?)(ter)?face/AddOns/", "AddOns/", head)
    return head.strip()


def queue_errors(game, queue_log):
    """{sig: {"count", "line" (the fullest one, with its stack), "first" (its time)}}: every saved error from the
    session the last queue started in (its reload's load errors too) to the end of the log."""
    starts = [QSTART.match(l) for l in queue_log]
    starts = [m for m in starts if m]
    if not starts:
        return {}
    at = _clock(starts[-1])
    sessions = [i for i, l in enumerate(game) if "session: ----" in l]
    begin = None
    for i in reversed(sessions):  # (from the end: the log runs back over older days)
        c = CLOCK.match(game[i])
        if c and _clock(c) <= at:
            begin = i
            break
    if begin is None:
        return {}
    out = {}
    for line in game[begin:]:
        if not NOTE.search(line):
            continue
        sig = error_sig(line)
        e = out.setdefault(sig, {"count": 0, "line": line, "first": line[:8]})
        e["count"] += 1
        if len(line) > len(e["line"]):
            e["line"] = line
    return out


_known = None


def known_errors():
    """(Tools/errors/errors.py, its entries), or (None, why) when lupa or known.lua can't load."""
    global _known
    if _known is None:
        try:
            sys.path.insert(0, os.path.join(ROOT, "Tools", "errors"))
            import errors as mod
            _known = (mod, mod.load())
        except Exception as err:  # (lupa missing, known.lua broken: say so, carry on)
            _known = (None, str(err))
    return _known


def known_line(text):
    """KNOWN <id> [status] ... per entry it matches, or NEW."""
    mod, entries = known_errors()
    if mod is None:
        return "known errors not loaded (%s)" % entries
    hits = mod.find(text, entries)
    if not hits:
        return "NEW: no known entry; root first (/error), then an entry in Tools/errors/known.lua"
    return "; ".join("KNOWN %s [%s] %s: %s" % (e["id"], e["status"], {
        "accepted": "accepted, nothing to fix", "fixed": "REGRESSION: fixed before, back"}.get(e["status"], "open"),
        e["title"]) for e in hits)


def accepted(text):
    """True when every known entry it matches is accepted (nothing to fix)."""
    mod, entries = known_errors()
    if mod is None:
        return False
    hits = mod.find(text, entries)
    return bool(hits) and all(e["status"] == "accepted" for e in hits)


def read_claims(path=CLAIMS):
    import json
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def claim_errors(session, found, path=CLAIMS, now=None):
    """Claims each unclaimed (or long-stale) error in found for session; returns [(sig, entry, owner)]."""
    import json
    now = time.time() if now is None else now
    out = []
    with Lock(path):
        claims = read_claims(path)
        for sig, e in sorted(found.items(), key=lambda kv: kv[1]["first"]):
            if accepted(e["line"]):
                continue
            c = claims.get(sig)
            if not c or now - c.get("at", 0) > CLAIM_DAYS * 86400:
                c = claims[sig] = {"session": session, "at": now, "first": e["first"]}
            out.append((sig, e, c["session"]))
        with open(path, "w", encoding="utf-8") as f:
            json.dump(claims, f, indent=1, sort_keys=True)
    return out


def sweep(session, client=None, show=print, files=None, claims_path=CLAIMS):
    """Prints the queue run's errors, each FIX NOW (claimed for session) or whose; returns how many are this
    session's to fix."""
    mine, seen = 0, set()
    for c, path in (files if files is not None else savedlogs.saved_files()):
        if (client and c != client) or c in seen:
            continue
        seen.add(c)  # (the newest saved file of each client)
        tables = savedlogs.log_tables(path)
        found = queue_errors(tables.get("log", []), tables.get("testQueueLog", []))
        rows = claim_errors(session, found, claims_path)
        show("== queue errors (%s, the whole run: load errors at its reloads and between tests too): %d to fix" % (
            c, len(rows)))
        for sig, e, owner in rows:
            ours = owner == session
            mine += 1 if ours else 0
            stack = [s.strip() for s in e["line"].split("\n")[1:5] if s.strip()]
            show("  %s %s x%d, first %s\n    %s%s" % ("FIX NOW (yours):" if ours else "claimed by %s:" % owner, sig,
                                                   e["count"], e["first"], known_line(e["line"]),
                                                   "".join("\n      " + s for s in stack) if ours else ""))
    if mine:
        show("FIX NOW: %d error(s) are yours. Fix each at its root (/error's rules, a known.lua entry) without asking,"
             " whoever's feature it is; commit only your own lines (USER RULE 2026-11-25)" % mine)
    return mine


def wait(path, qid, timeout_min, keep, poll=5.0, found=results, catalog=None, reported=issues, errors_of=run_errors,
         swept=None):
    """Until every client the entry asked for (--client) saved a result; exit 0 when all are clean (no FAIL, stop,
    reported issue or error: every error gets listed in the reply, whoever's it is)."""
    entry = next((e for e in read(path) if e.get("id") == qid), None)
    if entry is None and qid not in found():
        raise SystemExit("testqueue: no %s in the queue" % qid)
    stop = time.time() + timeout_min * 60
    said, errs = set(), 0
    while True:
        got = found().get(qid, {})
        for client, (saved, r) in sorted(got.items()):
            if client not in said:
                said.add(client)
                print("%s %s, saved %s: %s" % (qid, client, time.strftime("%H:%M", time.localtime(saved)), r["result"]))
                errs += errors_of(qid, client, r["log"])
                print("log: python -I .claude/skills/test/read_log.py %s %s" % (r["log"][:-3], client))
        left = owed(entry, got)
        if got and not left:
            told = reported().get(qid, [])
            for client, step, msg in told:
                print("ISSUE the user reported (%s, step %s): %s" % (client, step, msg))
            if not keep:
                remove(path, ids=(qid,), catalog=catalog)
            passed = all(good(r["result"]) for _, r in got.values()) and not told
            session = (entry or {}).get("session") or next(iter(got.values()))[1]["session"]
            for client in sorted(got):
                errs += (swept or sweep)(session, client)
            clean = passed and not errs
            if errs:
                print("ERRORS: %d kind(s) above; list each with its owner, get every one fixed" % errs)
            # (Errors alone don't requeue: the run itself was good, the errors get fixed.)
            if not passed and entry is not None:
                # (The session offers a Requeue button; the user, 2026-11-23: "sometimes i just mess it up".)
                print("requeue: %s" % requeue_command(entry))
            return 0 if clean else 1
        if time.time() > stop:
            print("testqueue: %s still owed by %s after %d min (the game saves on /reload; is it still queued?)" % (
                qid, " and ".join(left), timeout_min))
            return 2
        time.sleep(poll)


def show(path, client=None):
    entries, done, told = read(path), results(), issues()
    if client:
        entries = [e for e in entries if client in owed(e, done.get(e["id"], {}))
                   and e.get("client", "") in ("", "both", client)]
    if not entries:
        print("testqueue: nothing queued" + (" that %s still owes" % client if client else ""))
    for e in entries:
        got = done.get(e["id"], {})
        parts = ["%s: %s" % (c, got[c][1]["result"].split(" (")[0]) for c in sorted(got)]
        left = owed(e, got)
        if needed(e)[0] == "any" and left:
            parts.append("waiting (either client)")
        else:
            parts += ["%s: waiting" % c for c in left]
        print("%-6s %-16s %-10s %-8s %-24s %s  %s" % (e["id"], e["test"], e.get("args", ""), e.get("client", "") or "either",
                                                     e.get("session", ""), e.get("added", ""), " | ".join(parts)))
        for c, step, msg in told.get(e["id"], []):
            print("       ISSUE (%s, step %s): %s" % (c, step, msg))


def selftest():
    fails = 0
    global sweep  # (wait's own checks never claim the real saved errors)
    real_sweep, sweep = sweep, (lambda *a, **k: 0)
    try:
        return _selftest(fails, real_sweep)
    finally:
        sweep = real_sweep


def _selftest(fails, sweep):

    def check(name, ok, detail=""):
        nonlocal fails
        fails += 0 if ok else 1
        print("%s %s%s" % ("PASS" if ok else "FAIL", name, (" (%s)" % (detail,)) if detail else ""))

    known = {"kitcheck", "hoverplate"}
    with tempfile.TemporaryDirectory() as tmp:
        dev = os.path.join(tmp, "Dev")
        os.makedirs(dev)
        with open(os.path.join(dev, "AskTest.lua"), "w", encoding="utf-8") as f:
            f.write('-- r:WaitFor("in a comment")\nlocal function Ask(r) r:WaitFor("Hit any mob once", { events = {} }) end\n'
                    'ns.TestKit.Define({ name = "asktest", key = "askTest", needs = "be near a mob",\n'
                    '  steps = { { key = "a", run = function(r) Ask(r); r:WaitFor(nil, { check = f }); tile:Click()\n'
                    '    r:WaitFor("Reload", { buttons = { { kind = "reload" } } }) end } } })\n')
        with open(os.path.join(dev, "QuietTest.lua"), "w", encoding="utf-8") as f:
            f.write('ns.TestKit.Define({ name = "quiettest", key = "quietTest",\n'
                    '  steps = { { key = "a", run = function(r) r:WaitFor(nil, { check = f }); r:Shot("x") end } } })\n')
        # (Per step, 2026-11-25: a run of the hands-off steps isn't "Needs you" for one step that asks.)
        with open(os.path.join(dev, "MixedTest.lua"), "w", encoding="utf-8") as f:
            f.write('local steps = { { key = "look", run = function(r) r:Shot("a") end } }\n'
                    'local function Wait(r) r:WaitFor("Waiting for it to load", { handsOff = true, check = f }) end\n'
                    'for i = 1, 2 do steps[#steps + 1] = { key = "row" .. i, run = function(r) Wait(r)\n'
                    '  r:WaitFor("The test does it: hands off", { check = f }) end } end\n'
                    'steps[#steps + 1] = { key = "hit", say = "Hit a mob \\"once\\" -- not a comment", run = function(r) end }\n'
                    'steps[#steps + 1] = { key = "auto", say = "Watch it fade", handsOff = true, seconds = 5, run = function(r) end }\n'
                    'ns.TestKit.Define({ name = "mixedtest", key = "mixedTest", setup = function(r)\n'
                    '  r:Prompt("Stand still") end, steps = steps })\n')
        cat = scan(tmp)
        ask, quiet, mixed = cat.get("asktest", {}), cat.get("quiettest", {}), cat.get("mixedtest", {})
        check("scan: helper prompt counted; comment, frame:Click() and the Reload box (a reload) not",
              ask.get("asks") == 1 and ask.get("reloads") == 1 and ask.get("first") == "Hit any mob once", ask)
        check("scan: the test's needs", ask.get("needs") == "be near a mob", ask)
        check("scan: a wait on the game only is hands off", quiet.get("asks") == 0 and quiet.get("reloads") == 0, quiet)
        steps = mixed.get("steps") or []
        check("scan: steps from a built list, in order, by key",
              [s["key"] for s in steps] == ["look", "row", "hit", "auto"], steps)
        check("scan: handsOff = true and \"hands off\" words aren't asks; a say is",
              [s["asks"] for s in steps] == [0, 0, 1, 0] and steps[2]["first"] == 'Hit a mob "once" -- not a comment',
              steps)
        check("scan: the setup on its own", mixed.get("setup") == (1, 0, "Stand still"), mixed.get("setup"))
        path = os.path.join(tmp, "TestQueueList.lua")
        a, n = add(path, "kitcheck", "", 'Hover "plate" fix', "a note\nwith a line", known, catalog=cat)
        b, n = add(path, "hoverplate", "2 3", "Other session", "", known, needs="be in a city", catalog=cat)
        check("two added", n == 2 and a != b)
        entries = read(path)
        check("read back with quotes and the line break", entries[0]["session"] == 'Hover "plate" fix'
              and entries[0]["note"] == "a note with a line" and entries[1]["args"] == "2 3"
              and entries[1]["needs"] == "be in a city", entries)
        text = open(path, encoding="utf-8").read()
        check("a Lua table the game reads", text.startswith("-- ") and "ns.TestQueueList = {" in text
              and text.rstrip().endswith("}"))
        check("the catalog in the same file",
              '["asktest"] = { asks = 1, reloads = 1, first = "Hit any mob once"' in text
              and 'steps = { { key = "a", asks = 1, reloads = 1, first = "Hit any mob once" } }' in text, text[-600:])
        try:
            add(path, "nosuchtest", "", "x", "", known)
            check("an unknown test refused", False)
        except SystemExit:
            check("an unknown test refused", True)
        with Lock(path):
            check("lock file held", os.path.exists(path + ".lock"))
        check("lock file gone after", not os.path.exists(path + ".lock"))
        line = ('2026-11-23 14:05:03 id=%s test=kitcheck session="Hover \\"plate\\" fix" '
                'result=DONE pass=11 fail=0 skip=1 (DONE: ...) log=testQueue_%sLog') % (a, a)
        m = RESULT.search(line)
        check("result line parsed", m and m.group(1) == a and unlua(m.group(3)) == 'Hover "plate" fix'
              and m.group(4).startswith("DONE pass=11"), m and m.groups())
        fake = {a: {"forever": (time.time(), {"result": m.group(4), "log": m.group(5), "line": line})}}
        code = wait(path, a, 0.01, False, poll=0.01, found=lambda: fake, catalog=cat)
        check("wait: a clean result is exit 0, entry taken off", code == 0 and [e["id"] for e in read(path)] == [b], code)
        code = wait(path, b, 0.001, True, poll=0.01, found=lambda: {}, catalog=cat)
        check("wait: no result in time is exit 2, entry kept", code == 2 and len(read(path)) == 1, code)
        c, n = add(path, "kitcheck", "", "Both clients", "", known, catalog=cat, client="both")
        clean = (time.time(), {"result": "DONE pass=1 fail=0 skip=0", "log": "testQueue_%sLog" % c, "line": ""})
        check("both: owed by each client until each saved", owed(read(path)[-1], {}) == ["forever", "retail"]
              and owed(read(path)[-1], {"forever": clean}) == ["retail"]
              and owed(read(path)[-1], {"forever": clean, "retail": clean}) == [])
        code = wait(path, c, 0.001, True, poll=0.01, found=lambda: {c: {"forever": clean}}, catalog=cat)
        check("both: one client's result isn't the end (exit 2, kept)", code == 2 and any(e["id"] == c for e in read(path)), code)
        code = wait(path, c, 0.01, False, poll=0.01, found=lambda: {c: {"forever": clean, "retail": clean}}, catalog=cat)
        check("both: done once each client saved, then taken off", code == 0 and not any(e["id"] == c for e in read(path)), code)
        line = '2026-11-23 11:02:00 issue client=forever id=%s test=mouseplate step=3/4:hover msg="mousing over, \\"nothing\\" happens"' % c
        m = ISSUE.search(line)
        check("an issue line parsed", m and m.group(2) == c and m.group(4) == "3/4:hover"
              and unlua(m.group(5)) == 'mousing over, "nothing" happens', m and m.groups())
        d, n = add(path, "kitcheck", "", "Issue", "", known, catalog=cat)
        code = wait(path, d, 0.01, True, poll=0.01, catalog=cat,
                    found=lambda: {d: {"forever": clean}}, reported=lambda: {d: [("forever", "3/4:hover", "it broke")]})
        check("a clean result with an issue isn't clean (exit 1)", code == 1, code)
        remove(path, ids=(d,), catalog=cat)
        f, n = add(path, "hoverplate", "2 3", 'Hover "plate" fix', "a note", known, needs="be in a city",
                   catalog=cat, client="retail")
        cmd = requeue_command(next(e for e in read(path) if e["id"] == f))
        check("requeue: the same add command back", cmd == 'python -I Tools/testqueue.py add hoverplate 2 3 '
              '--session "Hover \\"plate\\" fix" --note "a note" --needs "be in a city" --client "retail"', cmd)
        bad = (time.time(), {"result": "DONE pass=3 fail=1 skip=0", "log": "testQueue_%sLog" % f, "line": ""})
        import io
        import contextlib
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = wait(path, f, 0.01, False, poll=0.01, catalog=cat, found=lambda: {f: {"retail": bad}}, reported=dict)
        check("a FAIL: exit 1, taken off, the requeue command printed", code == 1 and not any(e["id"] == f for e in read(path))
              and ("requeue: " + cmd) in out.getvalue(), out.getvalue())
        good_run = (time.time(), {"result": "DONE pass=3 fail=0 skip=0", "log": "x", "line": ""})
        g, n = add(path, "kitcheck", "", "Clean", "", known, catalog=cat)
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            wait(path, g, 0.01, False, poll=0.01, catalog=cat, found=lambda: {g: {"forever": good_run}}, reported=dict)
        check("a clean result: no requeue line", "requeue:" not in out.getvalue(), out.getvalue())
        # Errors (2026-11-25): a good run with errors isn't clean, but isn't requeued either.
        h, n = add(path, "kitcheck", "", "Errors", "", known, catalog=cat)
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = wait(path, h, 0.01, False, poll=0.01, catalog=cat, found=lambda: {h: {"forever": good_run}},
                        reported=dict, errors_of=lambda *_: 2)
        check("errors: exit 1, ERRORS line, no requeue", code == 1 and "ERRORS: 2 kind(s)" in out.getvalue()
              and "requeue:" not in out.getvalue(), out.getvalue())
        test_log = ["10:00:00 start: /cine debug kitcheck", "10:01:00 DONE: 3 pass, 0 fail, 0 skip; errors +0, blocked +36",
                    "10:01:00   during the test: blocked x36: CinematicDev: UNKNOWN() (in combat) | at Frames.lua:4936"
                    " | another feature: say whose and get it fixed | first in step 3 probe",
                    "10:01:05   after the test: error x1: attempt to index nil | at nil | owner: check the file"]
        game = ["09:00:00 session: ---- login", "09:30:00 deverror: error: before the test",
                "10:00:30 deverror: blocked: CinematicDev: UNKNOWN() (in combat)\n  [CinematicDev/Frames.lua]:4936:",
                "10:00:40 deverror: error: something else [in kitcheck step 5/7 shots]\n  [CinematicDev/Core.lua]:1:"]
        out = io.StringIO()
        n = errorlog.report(test_log, game, show=lambda s: out.write(s + "\n"))
        text = out.getvalue()
        check("errorlog: kit lines + the saved one not in them, not the one before the test",
              n == 3 and "blocked x36 at Frames.lua:4936" in text and "errors +0, blocked +36" in text
              and "something else" in text and "before the test" not in text, text)
        check("errorlog: each error's step (the kit's first in, the saved line's [in], after DONE)",
              "during the test, in step 3 probe: blocked x36" in text and "after the test, in after DONE: error x1" in text
              and "[in kitcheck step 5/7 shots]" in text and "(no test or step said)" not in text, text)
        check("errorlog: no test log, nothing read", errorlog.report([], game, show=lambda s: None) == 0)
        check("either: any one client is enough", owed({"client": ""}, {"retail": clean}) == [])
        check("older tests can be queued (namescale)", "namescale" in old_tests() and "namescale" in kit_tests())
        check("remove by session", remove(path, session="Other session", catalog=cat) == 1 and read(path) == [])
        # The queue-wide sweep (2026-11-25): the load error at the queue's reload and one between tests are swept,
        # one line per error, a day-old session's not; each claimed once, the second session sees whose it is.
        game = ["09:00:00 session: ---- old day ----",
                "12:30:00 deverror: caught: AddOns/CinematicDev/Old.lua:1: gone",
                "12:40:00 session: ---- CinematicDev dev ----",
                "12:40:01 deverror: warning: Interface/AddOns/CinematicDev/CinematicDev.toc:232 Error loading "
                "Interface/AddOns/CinematicDev/Style/Studio/Frames/CombatBand.lua [in test queue, between tests]",
                "12:41:12 deverror: caught: ...terface/AddOns/CinematicDev/Visions/CombatVision.lua:321: attempt to"
                " index field 'db' (a nil value) [in test queue, between tests]\n  [CinematicDev/Visions/CombatVision.lua]:321",
                "12:41:12 ERROR: ...terface/AddOns/CinematicDev/Visions/CombatVision.lua:321: attempt to index field 'db'"
                " (a nil value)\n[CinematicDev/Visions/CombatVision.lua]:321: in function <x>\n[CinematicDev/Studio.lua]:471",
                "12:41:20 chat: not an error"]
        qlog = ["2026-11-25 12:24:50 queue start: 5 test(s)", "2026-11-25 12:41:37 queue start: 4 test(s)"]
        swept = queue_errors(game, qlog)
        check("sweep: the queue's reload and between tests, one per error, not an older session's",
              sorted(swept) == ["AddOns/CinematicDev/CinematicDev.toc:232 Error loading AddOns/CinematicDev/Style/Studio/"
                                "Frames/CombatBand.lua",
                                "AddOns/CinematicDev/Visions/CombatVision.lua:321: attempt to index field 'db' (a nil value)"]
              and swept[sorted(swept)[1]]["count"] == 2 and "Studio.lua]:471" in swept[sorted(swept)[1]]["line"],
              sorted(swept))
        saved = os.path.join(tmp, "CinematicDev.lua")
        with open(saved, "w", encoding="utf-8") as f:
            f.write("CinematicDB = {\n")
            for key, lines in (("log", game), ("testQueueLog", qlog)):
                f.write('["%s"] = {\n' % key)
                for line in lines:
                    f.write('"%s",\n' % line.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n"))
                f.write("},\n")
            f.write("}\n")
        claims, said = os.path.join(tmp, "claims.json"), []
        mine = sweep("Session A", files=[("forever", saved)], show=said.append, claims_path=claims)
        text = "\n".join(said)
        check("sweep: both claimed for the first session, FIX NOW with the stack",
              mine == 2 and text.count("FIX NOW (yours):") == 2 and "Studio.lua]:471" in text, text)
        said = []
        mine = sweep("Session B", files=[("forever", saved)], show=said.append, claims_path=claims)
        text = "\n".join(said)
        check("sweep: the next session sees whose they are, none its own",
              mine == 0 and text.count("claimed by Session A:") == 2 and "FIX NOW" not in text, text)
        stale = read_claims(claims)
        for c in stale.values():
            c["at"] -= 2 * 86400
        import json
        with open(claims, "w", encoding="utf-8") as f:
            json.dump(stale, f)
        check("sweep: a claim a day old with its error still coming: taken again",
              sweep("Session B", files=[("forever", saved)], show=lambda s: None, claims_path=claims) == 2)
    print("testqueue selftest: %s" % ("all pass" if not fails else "%d FAIL" % fails))
    return 1 if fails else 0


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = p.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("add")
    a.add_argument("test")
    a.add_argument("args", nargs="*")
    a.add_argument("--session", required=True)
    a.add_argument("--note", default="")
    a.add_argument("--needs", default="")
    a.add_argument("--client", default="", choices=["", "either", "forever", "retail", "both"])
    w = sub.add_parser("wait")
    w.add_argument("id")
    w.add_argument("--timeout", type=float, default=240)
    w.add_argument("--keep", action="store_true")
    ls = sub.add_parser("list")
    ls.add_argument("--client", choices=["forever", "retail"])
    sub.add_parser("catalog")
    r = sub.add_parser("remove")
    r.add_argument("ids", nargs="*")
    r.add_argument("--session")
    sub.add_parser("selftest")
    e = sub.add_parser("errors")
    e.add_argument("--session", required=True)
    e.add_argument("--client", choices=["forever", "retail"])
    o = p.parse_args()
    if o.cmd == "errors":
        return 1 if sweep(o.session, o.client) else 0
    if o.cmd == "add":
        qid, n = add(QUEUE, o.test, " ".join(o.args), o.session, o.note, needs=o.needs,
                     client="" if o.client == "either" else o.client)
        print("queued %s: %s %s (%d in the queue). The user: /reload, then Run all." % (qid, o.test, " ".join(o.args), n))
        print("then: python -I Tools/testqueue.py wait %s   (in the background)" % qid)
        return 0
    if o.cmd == "wait":
        return wait(QUEUE, o.id, o.timeout, o.keep)
    if o.cmd == "catalog":
        with Lock(QUEUE):
            entries, cat = read(QUEUE), scan()
            write(QUEUE, entries, cat)
        quiet = sorted(n for n, c in cat.items() if not c["asks"] and not c["reloads"] and not c["needs"])
        print("catalog: %d kit tests, %d hands off: %s" % (len(cat), len(quiet), ", ".join(quiet)))
        return 0
    if o.cmd == "list":
        show(QUEUE, o.client)
        return 0
    if o.cmd == "remove":
        if not o.ids and not o.session:
            raise SystemExit("testqueue: remove <id ...> or --session NAME")
        print("removed %d" % remove(QUEUE, ids=set(o.ids), session=o.session))
        return 0
    return selftest()


if __name__ == "__main__":
    sys.exit(main())
