"""The rule walk on both clients (Tools/addon-kit/rulewalk.lua: every row's
show logic, every rule word, every tick column, against its baseline). From
the repo root:

    python -I Tools/addon-kit/rulewalk.py            both clients
    python -I Tools/addon-kit/rulewalk.py --update   save both baselines (an expectation change: the user's OK)
    python -I Tools/addon-kit/rulewalk.py --selftest each mutant (one break in the rule code) must FAIL

Exit 1 on a FAIL.
"""
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CLIENTS = ("forever", "retail")
MUTANTS = ("ruleignored", "wrongfact", "nofact", "follow", "tick")


def run(*args):
    proc = subprocess.run([sys.executable, "-I", "Tools/offline/run.py", "Tools/addon-kit/rulewalk.lua"] + list(args),
                          cwd=ROOT, stdin=subprocess.DEVNULL, capture_output=True, text=True, encoding="utf-8",
                          errors="replace")
    return proc.returncode, proc.stdout + proc.stderr


def main():
    if "--selftest" in sys.argv:
        with ThreadPoolExecutor(len(MUTANTS)) as pool:
            results = list(pool.map(lambda m: run("forever", "--mutant", m), MUTANTS))
        bad = 0
        for name, (code, out) in zip(MUTANTS, results):
            fails = [x for x in out.splitlines() if x.startswith("FAIL ")]
            ok = code != 0 and fails
            bad += 0 if ok else 1
            print("%s mutant %s: %s" % ("PASS" if ok else "FAIL", name,
                                        fails[0][5:] if fails else "the walk didn't see it"))
        print("rulewalk selftest: %d FAIL" % bad)
        sys.exit(1 if bad else 0)
    extra = ["--update"] if "--update" in sys.argv else []
    with ThreadPoolExecutor(len(CLIENTS)) as pool:
        results = list(pool.map(lambda c: run(c, *extra), CLIENTS))
    bad = 0
    for client, (code, out) in zip(CLIENTS, results):
        for line in out.splitlines():
            if not line.startswith("PASS "):
                print("%s: %s" % (client, line))
        bad += 0 if code == 0 else 1
    print("rulewalk: %d of %d clients FAIL" % (bad, len(CLIENTS)))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
