"""The addon kit's miss corpus: every other-addon bug that got past our support
and reached players, kept as an offline case (Tools/addon-kit-plan.md, part G).
From the repo root:

    python -I Tools/addon-kit/misses.py              every case
    python -I Tools/addon-kit/misses.py <case>       one (its file name, without .txt)
    python -I Tools/addon-kit/misses.py --selftest   its own checks

A case (Tools/addon-kit/misses/<name>.txt):

    # addon-kit miss, format 1
    fix <commit that fixed it>
    test <offline test that proves the fix>
    args <its arguments, if any>
    addon <the other addon>
    what <what players saw>

Each case's test runs twice: on the code as it is now (it must pass: no
FAIL line, exit 0), and on the code from just before the fix (git archive of
<fix>^, with today's harness and test, as Tools/audit.py diff does: nothing
in the working tree is touched). There it must FAIL: a FAIL line. A run that
only errors proves nothing (a call the old code didn't have) and counts as
a FAIL of the case, so a test that can't see the bug can't sit in the corpus.
A new miss adds a case here, and the check that would have caught it to the
kit (as Tools/errors does for errors).

Exit 1 when any case fails.
"""
import os
import re
import sys
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CASES = os.path.join(ROOT, "Tools", "addon-kit", "misses")
FORMAT = 1
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import audit  # noqa: E402  (its git export and harness copy)


def read_case(path):
    with open(path, encoding="utf-8") as f:
        lines = f.read().splitlines()
    m = re.match(r"# addon-kit miss, format (\d+)", lines[0] if lines else "")
    if not m or int(m.group(1)) != FORMAT:
        raise ValueError("%s: not a miss of format %d" % (os.path.basename(path), FORMAT))
    case = {"name": os.path.basename(path)[:-4], "args": []}
    for line in lines[1:]:
        word, _, rest = line.partition(" ")
        if word == "args":
            case["args"] = rest.split()
        elif word in ("fix", "test", "addon", "what"):
            case[word] = rest.strip()
    for need in ("fix", "test", "what"):
        if not case.get(need):
            raise ValueError("%s: no %s line" % (case["name"], need))
    return case


def verdict(code, output):
    """"pass", "fail" (a FAIL line) or "error" (no FAIL line, but it didn't pass)."""
    fails = [x for x in output.splitlines() if x.strip().startswith("FAIL")]
    if fails:
        return "fail", fails
    if code != 0:
        tail = [x for x in output.strip().splitlines() if x.strip()][-2:]
        return "error", tail
    return "pass", []


def run_case(case):
    """(ok, lines)."""
    out = []
    code, output = audit.run_lua(audit.ROOT, case["test"], case["args"])
    now, why = verdict(code, output)
    if now != "pass":
        out.append("now: %s: %s" % (now, " | ".join(why[:3])))
    try:
        old = audit.with_harness(audit.tree(case["fix"] + "^"), case["test"], audit.ROOT)
    except RuntimeError as err:
        return False, out + ["before the fix: can't read %s^ (%s)" % (case["fix"], err)]
    code, output = audit.run_lua(old, case["test"], case["args"])
    before, why = verdict(code, output)
    if before == "pass":
        out.append("before the fix (%s^): passes, so the test can't see this bug" % case["fix"])
    elif before == "error":
        out.append("before the fix (%s^): only errors, no FAIL line: %s" % (case["fix"], " | ".join(why)))
    return now == "pass" and before == "fail", out


def main():
    if "--selftest" in sys.argv:
        sys.exit(selftest())
    only = [a for a in sys.argv[1:] if not a.startswith("-")]
    paths = sorted(os.path.join(CASES, f) for f in os.listdir(CASES) if f.endswith(".txt"))
    cases, bad = [], 0
    for path in paths:
        try:
            case = read_case(path)
        except ValueError as err:
            print("FAIL %s" % err)
            bad += 1
            continue
        if not only or case["name"] in only:
            cases.append(case)
    # (Every fix^ exported first, one at a time: git archive side by side is fine,
    # but the cache in audit.tree isn't built for threads.)
    for case in cases:
        try:
            audit.tree(case["fix"] + "^")
        except RuntimeError:
            pass
    try:
        with ThreadPoolExecutor(4) as pool:
            results = list(pool.map(run_case, cases))
    finally:
        audit.cleanup()
    for case, (ok, lines) in zip(cases, results):
        print("%s %s (%s, fixed in %s): %s" % ("PASS" if ok else "FAIL", case["name"], case.get("addon", "?"),
                                              case["fix"], case["what"]))
        for line in lines:
            print("      " + line)
        bad += 0 if ok else 1
    print("misses: %d cases, %d FAIL" % (len(cases), bad))
    sys.exit(1 if bad else 0)


def selftest():
    bad = []

    def check(name, ok):
        if not ok:
            bad.append(name)
        print(("PASS " if ok else "FAIL ") + name)

    check("a FAIL line is a fail", verdict(0, "PASS a\nFAIL b")[0] == "fail")
    check("an error with no FAIL line is an error", verdict(1, "lua: boom")[0] == "error")
    check("clean is a pass", verdict(0, "PASS a\nPASS b")[0] == "pass")
    import tempfile
    tmp = tempfile.mkdtemp(prefix="cine-miss-self-")
    path = os.path.join(tmp, "x.txt")
    with open(path, "w") as f:
        f.write("# addon-kit miss, format 999\nfix abc\ntest t.lua\nwhat w\n")
    try:
        read_case(path)
        check("another format refused", False)
    except ValueError:
        check("another format refused", True)
    with open(path, "w") as f:
        f.write("# addon-kit miss, format %d\nfix abc\nwhat w\n" % FORMAT)
    try:
        read_case(path)
        check("a case with no test refused", False)
    except ValueError:
        check("a case with no test refused", True)
    print("misses selftest: %d FAIL" % len(bad))
    return 1 if bad else 0


if __name__ == "__main__":
    main()
