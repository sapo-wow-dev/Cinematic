"""Test kit names vs /cine debug's own commands (pre-commit).

A kit test (Dev/*.lua, ns.TestKit.Define) is reached only after every
`/cine debug` handler in Slash.lua (ns.TestKitRun is the last one asked). So a
test named like an older command, or starting with a prefix one takes
(arg:find("^hover")), never runs: /cine debug hoverplate turned on the hover
watch instead (2026-11-23). Fails on any such clash.

    python -I Tools/kit-names.py
"""
import glob
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))


def kit_names():
    names = []
    for path in sorted(glob.glob(os.path.join(ROOT, "Dev", "*.lua"))):
        text = open(path, encoding="utf-8", errors="ignore").read()
        for m in re.finditer(r"TestKit\.Define\(\{", text):
            head = text[m.end():m.end() + 400]
            found = re.search(r'\bname\s*=\s*"([^"]+)"', head)
            if found:
                names.append((found.group(1), os.path.relpath(path, ROOT)))
    return names


def slash_patterns():
    text = open(os.path.join(ROOT, "Slash.lua"), encoding="utf-8", errors="ignore").read()
    stop = text.find("ns.TestKitRun(arg)")
    text = text[:stop] if stop > 0 else text
    exact = set(re.findall(r'arg == "([^"]+)"', text))
    prefixes = set(re.findall(r'arg:find\("\^([A-Za-z0-9 ]+)', text))
    return exact, prefixes


def main():
    exact, prefixes = slash_patterns()
    names = kit_names()
    bad = 0
    for name, path in names:
        hits = sorted(p for p in prefixes if name.startswith(p))
        if name in exact or hits:
            bad += 1
            why = "an older command" if name in exact else "starts with " + ", ".join('"%s"' % h for h in hits)
            print('kit-names: %s: test "%s" never runs: %s in Slash.lua takes it first. Rename it.' % (path, name, why))
    if bad:
        return 1
    print("kit-names: %d kit tests, no clash with /cine debug's commands" % len(names))
    return 0


if __name__ == "__main__":
    sys.exit(main())
