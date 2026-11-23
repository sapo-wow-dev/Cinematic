"""What we already know about some game calls, frames, CVars or words: before any in-game test.

Searches, ranked by how many of the words each hit has:
  rules    Tools/engine/rules/*.lua (tested game rules: works / fails / status / proof)
  wiki     Tools/engine/wiki-api-tags.lua (retail restriction tags: protected, nocombat...)
  apidocs  Tools/engine/api/<client>.txt (each client's own /api docs, from its code export or dumped) and
           <client>-help.txt (the docs' help sentences, from the export)
  source   the game's own UI code (<client>/BlizzardInterfaceCode, from the console's exportInterfaceFiles code):
           file:line, and whether that file loads on the client (gamesource.py)
  logs     Tools/tests/logs/ (archived test logs) + every test log in the saved files now
  memory   the memory notes (name + description)
  ledgers  Tools/tests/*.md (per-feature test ledgers: questions, runs)
  tests    Dev/*.lua test headers (which test already covers it)
  plans    Tools/*-plan.md
  commits  git log subjects

usage: known.py word [word...] [--only rules,logs,...] [--max N]
  Words are case-insensitive; a hit needs at least one. Quote a phrase ("in combat").
"""
import glob
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gamesource  # noqa: E402
import savedlogs  # noqa: E402

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
MEMORY = os.path.expanduser(r"~\.claude\projects\C--dev-Cinematic\memory")


def score(text, words):
    """Words found; a whole-word find counts half a point more, so "mana" beats "GeneralDockManager"."""
    low = text.lower()
    return sum((1.5 if re.search(r"(?<![a-z0-9_])%s(?![a-z0-9_])" % re.escape(w), low) else 1)
               for w in words if w in low)


def rel(path):
    return os.path.relpath(path, REPO).replace("\\", "/")


def rules(words):
    hits = []
    for path in sorted(glob.glob(os.path.join(REPO, "Tools", "engine", "rules", "*.lua"))):
        text = open(path, encoding="utf-8", errors="replace").read()
        # One rule = a table opened at two spaces in and closed the same way.
        for block in re.findall(r"\n  \{\n(.*?)\n  \},", text, re.S):
            s = score(block, words)
            if not s:
                continue

            def field(name):
                m = re.search(r"\b%s = (\{.*?\}|\"(?:[^\"\\]|\\.)*\")," % name, block, re.S)
                return m.group(1).strip('"') if m else ""
            out = "%s [%s] %s %s\n      %s" % (field("id"), field("status"), field("clients"), field("tested"), field("rule"))
            for name in ("works", "fails", "when", "proof"):
                v = field(name)
                if v:
                    out += "\n      %s: %s" % (name, v)
            hits.append((s, out))
    return hits


def wiki(words):
    path = os.path.join(REPO, "Tools", "engine", "wiki-api-tags.lua")
    hits = []
    if os.path.exists(path):
        for line in open(path, encoding="utf-8", errors="replace"):
            m = re.match(r'\s*\["([^"]+)"\] = \{(.*)\},', line)
            if m and score(m.group(1), words):
                hits.append((score(m.group(1), words), "%s: %s (retail tags)" % (m.group(1), m.group(2).strip())))
    return hits


def apidocs(words):
    hits = []
    for path in sorted(glob.glob(os.path.join(REPO, "Tools", "engine", "api", "*.txt"))):
        client = os.path.splitext(os.path.basename(path))[0]
        for line in open(path, encoding="utf-8", errors="replace"):
            s = score(line, words)
            if s:
                hits.append((s, "%s: %s" % (client, line.strip()[:300])))
    if not glob.glob(os.path.join(REPO, "Tools", "engine", "api", "*.txt")):
        hits.append((0, "(no api docs yet: python -I Tools/engine/apidocs.py reads the game's code export, or /cine debug apidocs once per client first)"))
    return hits


def source(words):
    return gamesource.search(words, score)


def logs(words):
    hits = []
    for path in sorted(glob.glob(os.path.join(REPO, "Tools", "tests", "logs", "*.txt"))):
        for n, line in enumerate(open(path, encoding="utf-8", errors="replace"), 1):
            s = score(line, words)
            if s:
                hits.append((s, "%s:%d  %s" % (rel(path), n, line.strip()[:300])))
    archived = {os.path.basename(p) for p in glob.glob(os.path.join(REPO, "Tools", "tests", "logs", "*.txt"))}
    for client, path in savedlogs.saved_files():
        for key, lines in savedlogs.log_tables(path).items():
            if key == "log" or savedlogs.archive_name(client, path, key, lines) in archived:
                continue
            for line in lines:
                s = score(line, words)
                if s:
                    hits.append((s, "%s %s (saved, not archived)  %s" % (client, key, line[:300])))
    return hits


def memory(words):
    hits = []
    for path in sorted(glob.glob(os.path.join(MEMORY, "*.md"))):
        text = open(path, encoding="utf-8", errors="replace").read()
        s = score(text, words)
        if s and os.path.basename(path) != "MEMORY.md":
            m = re.search(r"^description: (.*)$", text, re.M)
            hits.append((s, "%s: %s" % (os.path.basename(path), (m.group(1) if m else "").strip('"')[:250])))
    return hits


def ledgers(words):
    hits = []
    for path in sorted(glob.glob(os.path.join(REPO, "Tools", "tests", "*.md"))):
        for n, line in enumerate(open(path, encoding="utf-8", errors="replace"), 1):
            s = score(line, words)
            if s:
                hits.append((s, "%s:%d  %s" % (rel(path), n, line.strip()[:250])))
    return hits


def tests(words):
    hits = []
    for path in sorted(glob.glob(os.path.join(REPO, "Dev", "*.lua"))):
        head = []
        for line in open(path, encoding="utf-8", errors="replace"):
            if not line.startswith("--"):
                break
            head.append(line[2:].strip())
        text = " ".join(head)
        s = score(text, words)
        if s:
            hits.append((s, "%s: %s" % (rel(path), text[:300])))
    return hits


def plans(words):
    hits = []
    for path in sorted(glob.glob(os.path.join(REPO, "Tools", "*-plan.md"))):
        for n, line in enumerate(open(path, encoding="utf-8", errors="replace"), 1):
            s = score(line, words)
            if s:
                hits.append((s, "%s:%d  %s" % (rel(path), n, line.strip()[:250])))
    return hits


def commits(words):
    try:
        out = subprocess.run(["git", "-C", REPO, "log", "--format=%h %as %s"], capture_output=True, text=True,
                             encoding="utf-8", errors="replace").stdout
    except OSError:
        return []
    return [(score(line, words), line[:250]) for line in out.splitlines() if score(line, words)]


SOURCES = [("rules", rules), ("wiki", wiki), ("apidocs", apidocs), ("source", source), ("logs", logs), ("memory", memory),
           ("ledgers", ledgers), ("tests", tests), ("plans", plans), ("commits", commits)]


def main():
    args = sys.argv[1:]
    only, most = None, 12
    if "--only" in args:
        i = args.index("--only")
        only = set(args[i + 1].split(","))
        del args[i:i + 2]
    if "--max" in args:
        i = args.index("--max")
        most = int(args[i + 1])
        del args[i:i + 2]
    words = [w.lower() for w in args]
    if not words:
        print(__doc__)
        return
    for name, fn in SOURCES:
        if only and name not in only:
            continue
        hits = sorted(fn(words), key=lambda h: -h[0])
        print("== %s: %d hit(s)%s" % (name, len(hits), " (top %d)" % most if len(hits) > most else ""))
        for _, text in hits[:most]:
            print("  " + text)
        print()


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    main()
