"""A name used above its own `local` line (known.lua: lua-local-before-defined).

In Lua a name read before its `local` line is a global, so a call to a local
function written further down calls nil. luacheck catches it (W113) unless the
name is also a known global (Lua's own or one in .luacheckrc), e.g. a local
`time` or `IsHarmfulSpell` added under a line that read the game's. This runs
luacheck with no whitelist and flags every global read whose name gets a
`local` further down the same file.

A use that means the real global gets `-- dont-ok: lua-local-before-defined`
on its line. Exit 1 on any hit.

Usage: python -I Tools/errors/forwardlocal.py [luacheck path]
"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MARK = "dont-ok: lua-local-before-defined"
LINE = re.compile(r"^(.+?):(\d+):\d+: \(W11[1-3]\).*?'([^']+)'\s*$")


def main():
    luacheck = sys.argv[1] if len(sys.argv) > 1 else "luacheck"
    out = subprocess.run(
        [luacheck, ".", "--no-config", "--std", "lua51", "--codes", "--formatter", "plain",
         "--exclude-files", "Release/*", ".claude/*", "Libs/*"],
        cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace").stdout
    files, hits = {}, []
    for line in out.splitlines():
        m = LINE.match(line)
        if not m:
            continue
        path, at, name = m.group(1), int(m.group(2)), m.group(3)
        if path not in files:
            with open(os.path.join(ROOT, path), encoding="utf-8", errors="replace") as f:
                files[path] = f.read().splitlines()
        src = files[path]
        if MARK in src[at - 1]:
            continue
        decl = re.compile(r"^\s*local\s+(function\s+%s\b|[\w\s,]*\b%s\b[\w\s,]*(=|$))"
                          % (re.escape(name), re.escape(name)))
        for i in range(at, len(src)):
            if decl.search(src[i]):
                hits.append("%s:%d: %s is read here as a global, but a local %s is made at line %d"
                            % (path, at, name, name, i + 1))
                break
    for hit in hits:
        print(hit)
    if hits:
        print("forwardlocal: %d name(s) used above their local line: move the local up, or mark the line"
              " '-- %s' if it means the real global" % (len(hits), MARK))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
