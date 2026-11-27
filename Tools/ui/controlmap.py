"""Every function that builds a menu control: python -I Tools/ui/controlmap.py

Lists each Lua function (outside Tools, Dev and Locales) that calls CreateFrame for a Button, CheckButton, Slider,
EditBox or DropdownButton and returns something: "file line name [widgets]". It over-finds (pages and helpers next to
a control show too); Tools/ui/control-map.md is the sorted result, read by hand from this list on 2026-11-27. Run it
after adding controls and look for names the map doesn't have.
"""
import os, re, sys, collections
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
WIDGET = re.compile(r'CreateFrame,?\s*\(?\s*"(Button|CheckButton|Slider|EditBox|DropdownButton)"')
FUNC = re.compile(r'^(\t*)(?:local\s+)?function\s+([A-Za-z_][\w.:]*)\s*\(|^(\t*)(?:local\s+)?([A-Za-z_][\w.]*)\s*=\s*function\s*\(')
def lua_files():
    for d, dirs, files in os.walk(ROOT):
        rel = os.path.relpath(d, ROOT)
        if rel.split(os.sep)[0] in ("Tools", "Dev", ".git", "Locales"): continue
        for f in files:
            if f.endswith(".lua"): yield os.path.join(d, f)
builders = []
for path in lua_files():
    lines = open(path, encoding="utf-8", errors="replace").read().split("\n")
    stack = []
    for i, line in enumerate(lines):
        m = FUNC.match(line)
        if m:
            indent = m.group(1) if m.group(1) is not None else m.group(3)
            name = m.group(2) or m.group(4)
            stack.append([indent, name, i, set(), False])
            continue
        for fr in stack:
            w = WIDGET.search(line)
            if w: fr[3].add(w.group(1))
            if re.search(r'\breturn\b', line): fr[4] = True
        if stack and re.match('^' + stack[-1][0] + r'end\b', line):
            indent, name, start, widgets, ret = stack.pop()
            if widgets and ret:
                builders.append((os.path.relpath(path, ROOT), start + 1, name, sorted(widgets)))
for b in builders: print(*b)
print(len(builders), file=sys.stderr)
