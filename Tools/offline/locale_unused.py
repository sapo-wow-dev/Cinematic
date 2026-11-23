"""Finds the translations no code asks for any more, and takes them out.

Every string the game's code holds (all .lua outside Locales/ and Tools/,
Dev/ too: the dev copy loads it) is read with a small Lua tokenizer, with
"a" .. "b" chains of plain strings joined into the one string they make. A
translation's English key that is none of those strings is unused, unless it
is one the code builds (KEEP_BUILT: race names from the game's tokens).

"Near" ones (their first or last 30 characters are in some string) are
mostly old wordings: a tip cut down to its first sentence, a line reworded.
They go too, as no code builds a key from pieces: an L[...] with a .. and a
name in it (L["Show " .. what]) stops the tool, as its keys can't be found.

    python -I Tools/offline/locale_unused.py           report
    python -I Tools/offline/locale_unused.py --fix     remove them

After --fix, each file is loaded again and checked: the same table as before,
less exactly the removed keys. Exit 1 on any problem.
"""
import pathlib
import re
import subprocess
import sys

import lupa.lua51 as lua51

ROOT = pathlib.Path(__file__).resolve().parents[2]
LANGS = ["deDE", "esES", "frFR", "itIT", "koKR", "ptBR", "ruRU", "zhCN", "zhTW"]

# Keys the code makes at run time instead of writing out
# (Camera/ShoulderCalibrate.lua: the game's race token, "NightElf" -> "Night Elf").
RACES = ["Human", "Orc", "Dwarf", "Night Elf", "Undead", "Tauren", "Gnome", "Troll", "Goblin", "Blood Elf",
         "Draenei", "Worgen", "Pandaren", "Nightborne", "Highmountain Tauren", "Void Elf", "Lightforged Draenei",
         "Zandalari Troll", "Kul Tiran", "Dark Iron Dwarf", "Vulpera", "Maghar Orc", "Mag'har Orc", "Mechagnome",
         "Dracthyr", "Earthen", "Haranir"]
KEEP_BUILT = set(RACES)

ESCAPES = {"n": "\n", "t": "\t", "r": "\r", "a": "\a", "b": "\b", "f": "\f", "v": "\v",
           "\\": "\\", '"': '"', "'": "'", "\n": "\n"}


def decode(body):
    out, i = [], 0
    while i < len(body):
        c = body[i]
        if c != "\\":
            out.append(c)
            i += 1
            continue
        n = body[i + 1]
        if n.isdigit():
            j = i + 1
            while j < len(body) and j < i + 4 and body[j].isdigit():
                j += 1
            out.append(chr(int(body[i + 1:j])))
            i = j
        else:
            out.append(ESCAPES.get(n, n))
            i += 2
    return "".join(out)


LONG_OPEN = re.compile(r"\[(=*)\[")


def strings_of(text):
    """Every string constant in a Lua file, chains of "a" .. "b" joined too."""
    found = []
    chain = None  # the string being built from a .. chain
    pending_concat = False
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c in " \t\r\n":
            i += 1
            continue
        if text.startswith("--", i):
            m = LONG_OPEN.match(text, i + 2)
            if m:
                end = text.find("]" + m.group(1) + "]", m.end())
                i = n if end < 0 else end + len(m.group(1)) + 2
            else:
                end = text.find("\n", i)
                i = n if end < 0 else end + 1
            continue
        s = None
        if c in "\"'":
            j = i + 1
            while j < n and text[j] != c:
                j += 2 if text[j] == "\\" else 1
            s = decode(text[i + 1:j])
            i = j + 1
        elif c == "[":
            m = LONG_OPEN.match(text, i)
            if m:
                end = text.find("]" + m.group(1) + "]", m.end())
                body = text[m.end():end if end >= 0 else n]
                if body.startswith("\n"):
                    body = body[1:]
                s = body
                i = n if end < 0 else end + len(m.group(1)) + 2
        if s is not None:
            found.append(s)
            if pending_concat and chain is not None:
                chain += s
                found.append(chain)
            else:
                chain = s
            pending_concat = False
            continue
        if text.startswith("..", i) and not text.startswith("...", i):
            pending_concat = chain is not None
            i += 2
            continue
        # Any other token ends a chain.
        chain = None
        pending_concat = False
        i += 1
    return found


def lua_files():
    """Every .lua the game can load: tracked, and new ones not added yet (the v2.1.24 cleanup took out
    the share window's strings while it sat in a new, untracked UI/ShareWindow.lua)."""
    return subprocess.run(["git", "ls-files", "--cached", "--others", "--exclude-standard", "*.lua"],
                          cwd=ROOT, capture_output=True, text=True, check=True).stdout.split()


def code_strings():
    files = lua_files()
    strings = set()
    for path in files:
        if path.startswith(("Locales/", "Tools/")):
            continue
        full = ROOT / path
        if not full.exists():
            continue
        strings.update(strings_of(full.read_text(encoding="utf-8", errors="replace")))
    return strings


def built_lookups():
    """Each L[...] whose key is joined with .. from something not a string."""
    files = lua_files()
    found = []
    for path in files:
        if path.startswith(("Locales/", "Tools/")) or not (ROOT / path).exists():
            continue
        text = (ROOT / path).read_text(encoding="utf-8", errors="replace")
        for m in re.finditer(r"\bL\[", text):
            depth, j, quote = 1, m.end(), None
            while j < len(text) and depth:
                c = text[j]
                if quote:
                    if c == "\\":
                        j += 2
                        continue
                    if c == quote:
                        quote = None
                elif c in "\"'":
                    quote = c
                elif c == "[":
                    depth += 1
                elif c == "]":
                    depth -= 1
                j += 1
            inner = text[m.end():j - 1]
            bare = re.sub(r'"(?:[^"\\]|\\.)*"' + r"|'(?:[^'\\]|\\.)*'", "", inner, flags=re.S)
            if ".." in bare and re.search(r"[A-Za-z_]", bare):
                found.append("%s:%d" % (path, text.count("\n", 0, m.start()) + 1))
    return found


def load_table(lua, text, lang):
    chunk = lua.execute("return function(src) return assert(loadstring(src)) end")(text)
    ns = lua.eval("{ LANGUAGES = {} }")
    chunk("Cinematic", ns)
    table = ns.LANGUAGES[lang]
    return {k: v for k, v in table.items()}


def blocks(text):
    """The file as blocks: (key-statement or None, its lines)."""
    lines = text.split("\n")
    out, i = [], 0
    while i < len(lines):
        line = lines[i]
        if line.startswith("L["):
            j = i + 1
            while j < len(lines) and lines[j].startswith(("\t", " ")) and lines[j].strip():
                j += 1
            out.append(("entry", lines[i:j]))
            i = j
        else:
            out.append((None, [line]))
            i += 1
    return out


def get_key(lua, lines):
    f = lua.execute("return function(src) local L = {} local fn = assert(loadstring('local L = ...\\n' .. src)) "
                    "fn(L) local k = next(L) assert(next(L, k) == nil, 'two keys in one block') return k end")
    return f("\n".join(lines))


def main():
    fix = "--fix" in sys.argv
    built = built_lookups()
    if built:
        print("A key built from pieces (its translation can't be told from an old one), fix first:")
        for where in built:
            print("  " + where)
        sys.exit(1)
    strings = code_strings()
    joined = chr(0).join(s for s in strings if len(s) >= 30)
    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    problems = 0
    total_removed = 0
    near_all = {}
    for lang in LANGS:
        path = ROOT / "Locales" / (lang + ".lua")
        text = path.read_text(encoding="utf-8")
        before = load_table(lua, text, lang)
        unused, near = [], []
        for key in before:
            if key in strings or key in KEEP_BUILT:
                continue
            head, tail = key[:30], key[-30:]
            if len(key) > 30 and (head in joined or tail in joined):
                near.append(key)
            else:
                unused.append(key)
        near_all[lang] = near
        size = sum(len(k.encode()) + len(before[k].encode()) for k in unused + near)
        print("%s: %d entries, %d unused, %d of them near (%d KB)" % (lang, len(before), len(unused) + len(near),
                                                                      len(near), size // 1024))
        if not fix:
            continue
        drop = set(unused) | set(near)
        kept_lines = []
        for kind, lines in blocks(text):
            if kind == "entry" and get_key(lua, lines) in drop:
                continue
            kept_lines.extend(lines)
        # Section comments ("-- File.lua") left with no entries under them go too.
        cleaned = []
        for idx, line in enumerate(kept_lines):
            cleaned.append(line)
        new_text = drop_empty_sections("\n".join(cleaned))
        after = load_table(lua, new_text, lang)
        expect = {k: v for k, v in before.items() if k not in drop}
        if after != expect:
            print("  PROBLEM: %s doesn't load back to the same table less the removed keys" % lang)
            problems += 1
            continue
        path.write_text(new_text, encoding="utf-8", newline="\n")
        total_removed += len(drop)
    if "--near" in sys.argv:
        for lang, near in near_all.items():
            for key in near:
                print("near", lang, key[:100].replace("\n", "\\n"))
    if fix:
        print("removed %d entries" % total_removed)
    sys.exit(1 if problems else 0)


SECTION = re.compile(r"^-- \S+\.lua$")


def drop_empty_sections(text):
    lines = text.split("\n")
    out = []
    for i, line in enumerate(lines):
        if SECTION.match(line):
            j = i + 1
            while j < len(lines) and not lines[j].strip():
                j += 1
            if j >= len(lines) or SECTION.match(lines[j]):
                continue
        out.append(line)
    # No runs of blank lines left behind.
    text = "\n".join(out)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text


if __name__ == "__main__":
    main()
