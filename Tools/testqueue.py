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
    python -I Tools/testqueue.py catalog         rescans every kit test for what it asks of the user (add/remove do too)
    python -I Tools/testqueue.py selftest        checks this script on a scratch copy

The list is Dev/TestQueueList.lua (git-ignored), read by the game at /reload; a lock file keeps two sessions from
writing it at once. A test changed after it was queued runs with the code loaded at that /reload.
"""
import argparse
import glob
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
import savedlogs  # noqa: E402

HEAD = ("-- The test queue's list (Tools/testqueue.py writes it, Dev/TestQueue.lua runs it). Not kept in git.\n"
        "local _, ns = ...\nns.TestQueueList = {\n")
FIELDS = ("id", "test", "args", "session", "note", "needs", "client", "added")
CLIENTS = ("forever", "retail")
PROMPT = re.compile(r'\b(?:r|run)\s*:\s*(WaitFor|Prompt|Click)\(\s*("(?:[^"\\]|\\.)*"|[^\s,)]+)')
SAY = re.compile(r'\bsay\s*=\s*("(?:[^"\\]|\\.)*")')
SECURE = re.compile(r'kind\s*=\s*"(reload|editmode|targetself)"')
NEEDS = re.compile(r'\bneeds\s*=\s*"((?:[^"\\]|\\.)*)"')
DEFINE = re.compile(r'TestKit\.Define\(\{')
NAME = re.compile(r'\bname\s*=\s*"([^"]+)"')
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


def strip_comments(text):
    text = re.sub(r"--\[(=*)\[.*?\]\1\]", "", text, flags=re.S)
    return re.sub(r"--[^\n]*", "", text)


def scan(root=ROOT):
    """{test name: {asks, first, reloads, needs, file}}: what each kit test asks of the user, from its code.

    asks: prompts that wait on the user (r:WaitFor / r:Prompt / r:Click with words, a step's say =, an Edit Mode
    or Target yourself button); first: the first one's words; reloads: Reload buttons; needs: the test's own
    needs = "...". A file with one test is read whole (its helpers ask too); with several, each test's part."""
    out = {}
    for path in sorted(glob.glob(os.path.join(root, "Dev", "*.lua"))):
        base = os.path.basename(path)
        if base in ("TestKit.lua", "TestKitWrap.lua", "TestQueue.lua", "TestQueueList.lua"):
            continue
        text = strip_comments(open(path, encoding="utf-8", errors="ignore").read())
        starts = [m.start() for m in DEFINE.finditer(text)]
        for i, at in enumerate(starts):
            name = NAME.search(text[at:at + 600])
            if not name:
                continue
            part = text if len(starts) == 1 else text[at:starts[i + 1] if i + 1 < len(starts) else len(text)]
            asks, first = 0, ""
            for _kind, arg in PROMPT.findall(part):
                if arg == "nil":
                    continue
                asks += 1
                if not first and arg.startswith('"'):
                    first = unlua(arg[1:-1])
            for arg in SAY.findall(part):
                asks += 1
                first = first or unlua(arg[1:-1])
            secure = SECURE.findall(part)
            asks += sum(1 for k in secure if k != "reload")
            needs = NEEDS.search(text[at:at + 1500])
            out[name.group(1)] = {"asks": asks, "first": first, "reloads": secure.count("reload"),
                                  "needs": unlua(needs.group(1)) if needs else "",
                                  "file": os.path.relpath(path, root).replace(os.sep, "/")}
    return out


def write(path, entries, catalog=None):
    catalog = scan() if catalog is None else catalog
    body = "".join("\t{ %s },\n" % ", ".join("%s = %s" % (k, lua_str(e.get(k, ""))) for k in FIELDS) for e in entries)
    cat = "".join('\t[%s] = { asks = %d, reloads = %d, first = %s, file = %s },\n' % (
        lua_str(name), c["asks"], c["reloads"], lua_str(c["first"]), lua_str(c["file"]))
        for name, c in sorted(catalog.items()))
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


def wait(path, qid, timeout_min, keep, poll=5.0, found=results, catalog=None, reported=issues):
    """Until every client the entry asked for (--client) saved a result; exit 0 when all are clean."""
    entry = next((e for e in read(path) if e.get("id") == qid), None)
    if entry is None and qid not in found():
        raise SystemExit("testqueue: no %s in the queue" % qid)
    stop = time.time() + timeout_min * 60
    said = set()
    while True:
        got = found().get(qid, {})
        for client, (saved, r) in sorted(got.items()):
            if client not in said:
                said.add(client)
                print("%s %s, saved %s: %s" % (qid, client, time.strftime("%H:%M", time.localtime(saved)), r["result"]))
                print("log: python -I .claude/skills/test/read_log.py %s %s" % (r["log"][:-3], client))
        left = owed(entry, got)
        if got and not left:
            told = reported().get(qid, [])
            for client, step, msg in told:
                print("ISSUE the user reported (%s, step %s): %s" % (client, step, msg))
            if not keep:
                remove(path, ids=(qid,), catalog=catalog)
            clean = all(good(r["result"]) for _, r in got.values()) and not told
            if not clean and entry is not None:
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
        cat = scan(tmp)
        ask, quiet = cat.get("asktest", {}), cat.get("quiettest", {})
        check("scan: helper prompt + Reload prompt counted, comment and frame:Click() not", ask.get("asks") == 2
              and ask.get("reloads") == 1 and ask.get("first") == "Hit any mob once", ask)
        check("scan: the test's needs", ask.get("needs") == "be near a mob", ask)
        check("scan: a wait on the game only is hands off", quiet.get("asks") == 0 and quiet.get("reloads") == 0, quiet)
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
              '["asktest"] = { asks = 2, reloads = 1, first = "Hit any mob once"' in text, text[-300:])
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
        check("either: any one client is enough", owed({"client": ""}, {"retail": clean}) == [])
        check("older tests can be queued (namescale)", "namescale" in old_tests() and "namescale" in kit_tests())
        check("remove by session", remove(path, session="Other session", catalog=cat) == 1 and read(path) == [])
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
    o = p.parse_args()
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
