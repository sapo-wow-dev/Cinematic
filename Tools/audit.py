"""The audit kit: an audit fix must not break the states next to its bug.
The process is the /audit skill (.claude/skills/audit/SKILL.md); fix cards
live in Tools/audits/. From the repo root:

  python -I Tools/audit.py diff <test.lua> [args] [--base REF] [--new REF|worktree|staged|DIR]
          [--card CARD.md ...] [--loose]
      A matrix test (Tools/offline/matrix.lua) on the old code and on the new,
      cell by cell. A cell whose outcome changed must be declared in a card's
      "Meant to change" table: an undeclared change FAILs (a neighbor the fix
      broke), a declared one that didn't happen FAILs (the fix doesn't work;
      --loose makes that a NOTE). The new run's pins FAIL too. Base: HEAD.
      New: the working tree. Both run the new tree's harness and test.
  python -I Tools/audit.py card <CARD.md> [--new ...] [--loose]
      diff for every Test: line of a card, against the card's Base: ref.
  python -I Tools/audit.py oldtests [--base REF] [--new ...] [test.lua ...]
      The OLD version of offline tests run on the NEW code: each FAIL is an
      expectation the change breaks (they need the user's OK). No tests named:
      every Tools/offline test that differs between base and new.
  python -I Tools/audit.py refs <word> [word...]
      Who relies on a function, setting, frame or event: the addon's code,
      Support/, settings defaults and migrations, built-in profiles, offline
      and Dev tests, ledgers, engine rules, fix cards, memory.
  python -I Tools/audit.py guard <commit message file>
      The commit-msg hook (Tools/hooks/commit-msg): a staged change to an
      existing expectation (an offline test's Check or pins, a ledger's
      settled answer, an engine rule) needs an "Expectation-changed:" line
      naming its file, with "OK'd by the user YYYY-MM-DD". An audit commit
      needs a "Risk:" line and its fix card (Tools/audits/*.md).
  python -I Tools/audit.py since [REF]
      Every expectation changed by the commits since REF (last tag), with the
      OK line each commit gave, for the release review. Never a FAIL.
  python -I Tools/audit.py precommit <staged dir>
      The pre-commit hook: each staged fix card's matrices, HEAD vs staged.
  python -I Tools/audit.py prerelease [REF]
      Every fix card's matrices against REF (last tag), --loose: any change
      since the tag no card declares FAILs.
  python -I Tools/audit.py selftest
      The guard's and diff's own checks on made-up input.

Exit 1 on a FAIL (guard: the commit is refused). Needs lupa (run.py).
"""
import io
import glob
import os
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PY = sys.executable
MEMORY = os.path.expanduser(r"~\.claude\projects\C--dev-Cinematic\memory")
HARNESS = ("Tools/offline/run.py", "Tools/offline/wow.lua", "Tools/offline/load.lua", "Tools/offline/matrix.lua")
# Tools/offline files that are no test (the stand-in game and helpers).
NOT_TESTS = {"wow.lua", "load.lua", "matrix.lua", "check.lua", "export.lua", "upgrade-dump.lua", "migrate-test.lua"}
ARCHIVE_PATHS = ["*.lua", "*.toc", "*.xml", "Tools/offline"]
OK_RE = re.compile(r"ok'?d by the user\b.*\b20\d\d-\d\d-\d\d", re.I)
AUDIT_RE = re.compile(r"code audit|audit fix|from an? audit|^audit\b|^audit:", re.I | re.M)


def git(*args, cwd=ROOT, check=False):
    out = subprocess.run(["git"] + list(args), cwd=cwd, capture_output=True, text=True,
                         encoding="utf-8", errors="replace")
    if check and out.returncode != 0:
        raise RuntimeError("git %s: %s" % (" ".join(args), out.stderr.strip()))
    return out


def last_tag():
    return git("describe", "--tags", "--abbrev=0").stdout.strip()


# --- code trees ---------------------------------------------------------------

_trees = {}


def export(ref):
    """A folder holding ref's code (its .lua, .toc, .xml and Tools/offline)."""
    if ref in _trees:
        return _trees[ref]
    into = tempfile.mkdtemp(prefix="cine-audit-")
    data = subprocess.run(["git", "archive", "--format=tar", ref, "--"] + ARCHIVE_PATHS, cwd=ROOT,
                          capture_output=True).stdout
    if not data:
        raise RuntimeError("can't read %s from git" % ref)
    with tarfile.open(fileobj=io.BytesIO(data)) as tar:
        tar.extractall(into)
    _trees[ref] = into
    return into


def staged():
    """A folder holding what's staged now (the index, a temporary one too)."""
    if ":staged" in _trees:
        return _trees[":staged"]
    into = tempfile.mkdtemp(prefix="cine-audit-")
    files = git("ls-files", "-z", "--", *ARCHIVE_PATHS).stdout.split("\0")
    files = [f for f in files if f]
    for i in range(0, len(files), 200):
        git("checkout-index", "--prefix=%s/" % into.replace("\\", "/"), "--", *files[i:i + 200])
    _trees[":staged"] = into
    return into


def tree(which):
    if which in (None, "worktree"):
        return ROOT
    if which == "staged":
        return staged()
    if os.path.isdir(which):
        return which
    return export(which)


def cleanup():
    for path in _trees.values():
        shutil.rmtree(path, ignore_errors=True)
    _trees.clear()


def with_harness(code, test, harness_from):
    """code, with the harness and the test from harness_from (both sides alike)."""
    if os.path.abspath(code) == os.path.abspath(harness_from):
        return code
    for rel in list(HARNESS) + [test]:
        src = os.path.join(harness_from, rel)
        if os.path.exists(src):
            dst = os.path.join(code, rel)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy(src, dst)
    return code


def run_lua(code, test, args, nopins=False):
    env = dict(os.environ)
    if nopins:
        env["MATRIX_NOPINS"] = "1"
    proc = subprocess.run([PY, "-I", "Tools/offline/run.py", test] + list(args), cwd=code, env=env,
                          stdin=subprocess.DEVNULL, capture_output=True, text=True, encoding="utf-8",
                          errors="replace")
    return proc.returncode, proc.stdout + proc.stderr


# --- matrices -----------------------------------------------------------------

CELL_RE = re.compile(r"^CELL (\S+) \| (.*?): (.*)$")


def cells(output):
    out = {}
    for line in output.splitlines():
        m = CELL_RE.match(line.strip())
        if m:
            out[(m.group(1), m.group(2))] = m.group(3).strip()
    return out


def matches(key, pattern):
    have = set(key.split())
    return all(pair in have for pair in pattern.split())


def read_card(path, text=None):
    """A fix card's Base:, Test: lines and its Meant to change rows."""
    if text is None:
        with open(path, encoding="utf-8") as f:
            text = f.read()
    card = {"path": path, "base": None, "tests": [], "changes": []}
    section = None
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("#"):
            section = s.lstrip("#").strip().lower()
            continue
        m = re.match(r"^(?:[-*]\s*)?Base:\s*`?([^`\s]+)`?", s)
        if m and card["base"] is None:
            card["base"] = m.group(1)
        m = re.match(r"^(?:[-*]\s*)?Test:\s*`?([^`]+?)`?\s*$", s)
        if m:
            parts = m.group(1).split()
            card["tests"].append((parts[0], parts[1:]))
        if section and section.startswith("meant to change") and s.startswith("|"):
            row = [c.strip().strip("`") for c in s.strip("|").split("|")]
            if len(row) < 4 or set(row[0]) <= set("-: ") or row[0].lower() == "matrix":
                continue
            card["changes"].append({"matrix": row[0], "cell": row[1], "before": row[2], "after": row[3],
                                    "card": path, "hit": False})
    return card


def common(keys):
    """The name=value pairs every key has (where a group of cells lies)."""
    sets = [set(k.split()) for k in keys]
    both = set.intersection(*sets) if sets else set()
    return " ".join(p for p in keys[0].split() if p in both) if keys else ""


def compare(base, new, changes, loose=False, pin_fails=()):
    """Lines for the cell-by-cell comparison (cells grouped by change), and how many FAILs."""
    lines, fails, groups, order = [], 0, {}, []

    def add(kind, name, was, now, key, note=""):
        g = (kind, name, was, now, note)
        if g not in groups:
            groups[g] = []
            order.append(g)
        groups[g].append(key)
    for (name, key), now in sorted(new.items()):
        was = base.get((name, key))
        if was is None:
            add("NOTE new cell", name, "", now, key)
            continue
        if was == now:
            continue
        if was.startswith("error:"):
            add("NOTE old code errors", name, was, now, key)
            continue
        rows = [c for c in changes if c["matrix"] == name and matches(key, c["cell"])]
        good = [c for c in rows if c["before"] in ("*", was) and c["after"] in ("*", now)]
        for c in good:
            c["hit"] = True
        if good:
            add("PASS as declared", name, was, now, key)
        elif rows:
            add("FAIL not as declared", name, was, now, key, "the card says %s -> %s" % (rows[0]["before"],
                                                                                          rows[0]["after"]))
        else:
            add("FAIL UNDECLARED", name, was, now, key)
    for (name, key), was in sorted(base.items()):
        if (name, key) not in new:
            add("NOTE cell gone", name, was, "", key)
    for g in order:
        kind, name, was, now, note = g
        keys = groups[g]
        if kind.startswith("FAIL"):
            fails += len(keys)
        where = common(keys)
        lines.append("%s %s: %s -> %s in %d cell%s%s%s" % (
            kind.split()[0], name, was or "(none)", now or "(none)", len(keys), "" if len(keys) == 1 else "s",
            (" where " + where) if where else "", " [%s]" % " ".join(kind.split()[1:]) +
            ((": " + note) if note else "")))
        for k in keys[:6]:
            lines.append("      " + k)
        if len(keys) > 6:
            lines.append("      ... %d more" % (len(keys) - 6))
    names = {name for name, _ in new}
    for c in changes:
        if c["matrix"] in names and not c["hit"]:
            soft = loose or c.get("loose")
            word = "NOTE" if soft else "FAIL"
            fails += 0 if soft else 1
            lines.append("%s %s | %s: declared %s -> %s (%s), but no cell changed so" % (
                word, c["matrix"], c["cell"], c["before"], c["after"], os.path.basename(c["card"])))
    if pin_fails:
        fails += len(pin_fails)
        lines.append("FAIL %d cells don't give what the test pins now (the new code's own PASS/FAIL):" % len(pin_fails))
        lines += ["      " + l[5:] for l in pin_fails[:8]]
        if len(pin_fails) > 8:
            lines.append("      ... %d more" % (len(pin_fails) - 8))
    return lines, fails


def diff(test, args, base_ref="HEAD", new="worktree", changes=(), loose=False, quiet=False):
    # (The harness and the test from the new tree, or the working tree when
    # the new code is an older commit: the same on both sides.)
    new_code = tree(new)
    source = new_code if os.path.exists(os.path.join(new_code, test)) else ROOT
    new_code = with_harness(new_code, test, source)
    base_code = with_harness(tree(base_ref), test, source)
    _, out_b = run_lua(base_code, test, args, nopins=True)
    _, out_n = run_lua(new_code, test, args)
    base, now = cells(out_b), cells(out_n)
    label = "%s %s" % (test, " ".join(args))
    if not now:
        tail = "\n      ".join(out_n.strip().splitlines()[-6:])
        return ["FAIL %s: no CELL lines on the new code\n      %s" % (label, tail)], 1
    if not base:
        tail = "\n      ".join(out_b.strip().splitlines()[-4:])
        print("NOTE %s: no CELL lines on %s (the test can't run there)\n      %s" % (label, base_ref, tail))
    pin_fails = [l.strip() for l in out_n.splitlines() if l.startswith("FAIL ")]
    for c in changes:
        c["hit"] = False
    lines, fails = compare(base, now, list(changes), loose, pin_fails)
    changed = sum(1 for k in now if k in base and base[k] != now[k])
    summary = "%s %s: %d cells, %d changed since %s, %d FAIL" % ("FAIL" if fails else "PASS", label, len(now),
                                                                  changed, base_ref, fails)
    return lines + [summary], fails


def all_cards():
    out = []
    for path in sorted(glob.glob(os.path.join(ROOT, "Tools", "audits", "*.md"))):
        name = os.path.basename(path)
        if name.upper().startswith(("README", "TEMPLATE")):
            continue
        out.append(read_card(path))
    return out


# --- expectations (the guard) --------------------------------------------------

def parse_diff(text):
    """Per file: old path, new path, deleted?, and the old line numbers removed."""
    files, cur = [], None
    for line in text.splitlines():
        if line.startswith("diff --git "):
            m = re.match(r"diff --git a/(.*) b/(.*)$", line)
            cur = {"old": m.group(1), "new": m.group(2), "deleted": False, "added": False, "removed": []}
            files.append(cur)
        elif cur is None:
            continue
        elif line.startswith("deleted file mode"):
            cur["deleted"] = True
        elif line.startswith("new file mode"):
            cur["added"] = True
        elif line.startswith("rename from "):
            cur["old"] = line[len("rename from "):]
        elif line.startswith("rename to "):
            cur["new"] = line[len("rename to "):]
        elif line.startswith("@@"):
            m = re.match(r"@@ -(\d+)(?:,(\d+))? \+", line)
            start, count = int(m.group(1)), int(m.group(2) if m.group(2) is not None else 1)
            cur["removed"].extend(range(start, start + count))
    return files


def call_spans(text, word):
    """(first line, last line, name) of each word( ... ) call in Lua text."""
    spans = []
    for m in re.finditer(r"(?<![\w.:])%s\(" % re.escape(word), text):
        before = text[max(0, m.start() - 9):m.start()]
        if before.endswith("function "):
            continue
        line_start = text.rfind("\n", 0, m.start()) + 1
        if "--" in text[line_start:m.start()]:
            continue
        i, depth, quote = m.end(), 1, None
        while i < len(text) and depth:
            ch = text[i]
            if quote:
                if ch == "\\":
                    i += 1
                elif ch == quote:
                    quote = None
            elif ch in "\"'":
                quote = ch
            elif ch == "-" and text.startswith("--", i):
                nl = text.find("\n", i)
                i = len(text) if nl < 0 else nl
                continue
            elif ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
            i += 1
        name = re.search(r"([\"'])(.+?)(?<!\\)\1", text[m.end():i])
        first = text.count("\n", 0, m.start()) + 1
        last = text.count("\n", 0, i) + 1
        spans.append((first, last, name.group(2).strip(" :") if name else "%s at line %d" % (word, first)))
    return spans


def pins_span(text):
    m = re.search(r"(?m)^\s*pins\s*=\s*\{", text)
    if not m:
        return None
    first = text.count("\n", 0, m.start()) + 1
    depth, i = 0, m.end() - 1
    while i < len(text):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                break
        i += 1
    return first, text.count("\n", 0, i) + 1


def ledger_answers(text):
    out = {}
    for line in text.splitlines():
        s = line.strip()
        if not re.match(r"^\|\s*Q\d", s):
            continue
        row = [c.strip() for c in s.strip("|").split("|")]
        if len(row) >= 4:
            out[row[0]] = row[3]
    return out


def is_test(path):
    return (path.startswith("Tools/offline/") and path.endswith(".lua")
            and os.path.basename(path) not in NOT_TESTS)


def expectations(diff_text, old_text):
    """[(file, what)] for each existing expectation the diff changes."""
    found = []
    for f in parse_diff(diff_text):
        old, new = f["old"], f["new"]
        if f["added"]:
            continue
        if is_test(old):
            text = old_text(old)
            if text is None:
                continue
            checks = call_spans(text, "Check")
            pins = pins_span(text)
            if f["deleted"] or not is_test(new):
                if checks or pins:
                    found.append((old, "test removed (%d checks%s)" % (len(checks), ", pins" if pins else "")))
                continue
            removed = set(f["removed"])
            names = [name for first, last, name in checks if removed & set(range(first, last + 1))]
            if names:
                found.append((old, "checks changed: " + "; ".join(names[:6]) + (" ..." if len(names) > 6 else "")))
            if pins and removed & set(range(pins[0], pins[1] + 1)):
                found.append((old, "matrix pins changed"))
        elif old.startswith("Tools/tests/") and old.endswith(".md"):
            text = old_text(old)
            if text is None:
                continue
            was = ledger_answers(text)
            now = {} if f["deleted"] else ledger_answers(new_text_cache.get(new) or "")
            for q, answer in was.items():
                if not answer or answer.lower().startswith("open"):
                    continue
                if now.get(q) != answer:
                    found.append((old, "%s answer %r -> %r" % (q, answer, now.get(q, "(gone)"))))
        elif old.startswith("Tools/engine/rules/") and old.endswith(".lua"):
            text = old_text(old)
            if text is None:
                continue
            lines = text.splitlines()
            ids = set()
            for n in f["removed"]:
                if n - 1 >= len(lines):
                    continue
                line = lines[n - 1]
                m = re.match(r"^\s*(id|rule|works|fails|clients|status)\s*=", line)
                if not m:
                    continue
                if m.group(1) == "status" and "tested" not in line:
                    continue
                rid = None
                for back in range(n - 1, -1, -1):
                    mid = re.match(r'^\s*id\s*=\s*"([^"]+)"', lines[back])
                    if mid:
                        rid = mid.group(1)
                        break
                ids.add(rid or "line %d" % n)
            for rid in sorted(ids):
                found.append((old, "rule %s changed" % rid))
    return found


new_text_cache = {}


def oks(message):
    lines = [l for l in message.splitlines() if not l.startswith("#")]
    return [l for l in lines if l.strip().lower().startswith("expectation-changed:")]


def covered(path, ok_lines):
    base = os.path.basename(path)
    for line in ok_lines:
        if (path in line or base in line) and OK_RE.search(line):
            return True
    return False


def guard(message, diff_text, old_text, card_exists):
    """Problems with a commit: [str]. Empty = it may land."""
    problems = []
    ok_lines = oks(message)
    for path, what in expectations(diff_text, old_text):
        if not covered(path, ok_lines):
            problems.append("%s: %s" % (path, what))
    body = "\n".join(l for l in message.splitlines() if not l.startswith("#"))
    if AUDIT_RE.search(body):
        if not re.search(r"(?m)^\s*Risk:", body):
            problems.append("an audit commit needs a Risk: line (who could notice, how likely, what's pinned)")
        refs = re.findall(r"Tools/audits/[\w.\-]+\.md", body)
        if not refs:
            problems.append("an audit commit names its fix card (Tools/audits/<date>-<area>.md)")
        for ref in refs:
            if not card_exists(ref):
                problems.append("%s isn't staged or committed" % ref)
    return problems


def cmd_guard(msgfile):
    if os.environ.get("CINE_SKIP_CHECKS"):
        return 0
    gitdir = git("rev-parse", "--git-dir").stdout.strip()
    if os.path.exists(os.path.join(ROOT, gitdir, "MERGE_HEAD")) or git("rev-parse", "-q", "--verify", "HEAD").returncode:
        return 0
    with open(msgfile, encoding="utf-8", errors="replace") as f:
        message = f.read()
    diff_text = git("diff", "--cached", "-U0", "--no-color", "-M", "HEAD").stdout

    def old_text(path):
        out = git("show", "HEAD:" + path)
        return out.stdout if out.returncode == 0 else None
    for f in parse_diff(diff_text):
        if f["new"].startswith("Tools/tests/") and not f["deleted"]:
            new_text_cache[f["new"]] = git("show", ":" + f["new"]).stdout

    def card_exists(ref):
        return git("cat-file", "-e", ":" + ref).returncode == 0 or git("cat-file", "-e", "HEAD:" + ref).returncode == 0
    problems = guard(message, diff_text, old_text, card_exists)
    if not problems:
        return 0
    print("commit-msg: this commit changes what existing tests, ledgers or rules expect, or is an audit "
          "commit without its notes:")
    for p in problems:
        print("  - " + p)
    print("A changed expectation needs the user's OK first (show them was -> now, wait for a yes), then one line\n"
          "per file in the message:\n"
          "  Expectation-changed: Tools/offline/x.lua: <check>: <was> -> <now> (OK'd by the user 2026-11-23)\n"
          "The /audit skill has the whole rule. Nothing committed.")
    return 1


def cmd_since(ref):
    ref = ref or last_tag()
    commits = git("rev-list", "--reverse", "--no-merges", "%s..HEAD" % ref).stdout.split()
    total = 0
    for c in commits:
        diff_text = git("diff", "-U0", "--no-color", "-M", c + "^", c).stdout
        new_text_cache.clear()
        for f in parse_diff(diff_text):
            if f["new"].startswith("Tools/tests/") and not f["deleted"]:
                new_text_cache[f["new"]] = git("show", "%s:%s" % (c, f["new"])).stdout

        def old_text(path, c=c):
            out = git("show", "%s^:%s" % (c, path))
            return out.stdout if out.returncode == 0 else None
        found = expectations(diff_text, old_text)
        if not found:
            continue
        message = git("log", "-1", "--format=%B", c).stdout
        subject = message.splitlines()[0][:90] if message else ""
        print("%s %s" % (c[:8], subject))
        ok_lines = oks(message)
        for path, what in found:
            total += 1
            print("  %s %s: %s" % ("OK'd " if covered(path, ok_lines) else "NO OK", path, what[:200]))
    print("expectations changed since %s: %d" % (ref, total))
    return 0


# --- refs ---------------------------------------------------------------------

def cmd_refs(words, limit=12):
    words = [w for w in words if w]
    pat = re.compile("|".join(re.escape(w) for w in words), re.I)
    groups = [
        ("code", lambda p: p.endswith(".lua") and not p.startswith(("Tools/", "Dev/", "Support/", "Locales/", "Libs/"))),
        ("other addons (Support/)", lambda p: p.startswith("Support/") and p.endswith(".lua")),
        ("settings updates (Migrations.lua)", lambda p: p == "Migrations.lua"),
        ("built-in profiles' settings", lambda p: p.startswith("Tools/offline/profile-settings-")),
        ("offline tests", lambda p: is_test(p)),
        ("in-game tests (Dev/)", lambda p: p.startswith("Dev/") and p.endswith(".lua")),
        ("test ledgers", lambda p: p.startswith("Tools/tests/") and p.endswith(".md")),
        ("engine rules", lambda p: p.startswith("Tools/engine/rules/")),
        ("fix cards", lambda p: p.startswith("Tools/audits/") and p.endswith(".md")),
    ]
    files = git("ls-files", "--cached", "--others", "--exclude-standard").stdout.split("\n")
    files = [f for f in files if f and os.path.exists(os.path.join(ROOT, f))]
    for title, want in groups:
        hits = []
        for path in files:
            if not want(path):
                continue
            try:
                with open(os.path.join(ROOT, path), encoding="utf-8", errors="replace") as f:
                    for n, line in enumerate(f, 1):
                        if pat.search(line):
                            hits.append("%s:%d: %s" % (path, n, line.strip()[:150]))
            except OSError:
                continue
        print("== %s: %d" % (title, len(hits)))
        for h in hits[:limit]:
            print("  " + h)
        if len(hits) > limit:
            print("  ... %d more" % (len(hits) - limit))
    hits = []
    for path in sorted(glob.glob(os.path.join(MEMORY, "*.md"))):
        with open(path, encoding="utf-8", errors="replace") as f:
            for n, line in enumerate(f, 1):
                if pat.search(line):
                    hits.append("%s:%d: %s" % (os.path.basename(path), n, line.strip()[:150]))
    print("== memory notes: %d" % len(hits))
    for h in hits[:limit]:
        print("  " + h)
    print("(Also: python -I .claude/skills/test/known.py %s for test logs and API docs.)" % " ".join(words))
    return 0


# --- commands -----------------------------------------------------------------

def opt(argv, name, default=None, many=False):
    vals, rest, i = [], [], 0
    while i < len(argv):
        if argv[i] == name and i + 1 < len(argv):
            vals.append(argv[i + 1])
            i += 2
        else:
            rest.append(argv[i])
            i += 1
    argv[:] = rest
    if many:
        return vals
    return vals[-1] if vals else default


def report(lines):
    for line in lines:
        print(line)


def cmd_card(path, new, loose):
    card = read_card(path)
    base = card["base"] or "HEAD"
    fails = 0
    for test, args in card["tests"]:
        lines, f = diff(test, args, base, new, card["changes"], loose)
        report(lines)
        fails += f
    if not card["tests"]:
        print("FAIL %s: no Test: line" % path)
        fails += 1
    return fails


def cmd_oldtests(base_ref, new, tests):
    if not tests:
        names = git("diff", "--name-only", base_ref, "--", "Tools/offline").stdout.split()
        tests = [t for t in names if is_test(t)]
    new_code = tree(new)
    copy = tempfile.mkdtemp(prefix="cine-audit-old-")
    fails = 0
    try:
        files = git("ls-files", "--cached", "--others", "--exclude-standard", "--", *ARCHIVE_PATHS).stdout.split("\n")
        for rel in [f for f in files if f]:
            src = os.path.join(new_code, rel)
            if os.path.exists(src):
                dst = os.path.join(copy, rel)
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                shutil.copy(src, dst)
        for test in tests:
            parts = test.split()
            old = git("show", "%s:%s" % (base_ref, parts[0]))
            if old.returncode != 0:
                print("NOTE %s: not in %s (a new test)" % (parts[0], base_ref))
                continue
            for client in (parts[1:] and [parts[1:]] or [["forever"], ["retail"]]):
                with open(os.path.join(copy, parts[0]), "w", encoding="utf-8", newline="") as f:
                    f.write(old.stdout)
                _, out = run_lua(copy, parts[0], client)
                bad = [l.strip() for l in out.splitlines() if l.startswith("FAIL ")]
                fails += len(bad)
                print("%s %s %s (its %s version on the new code): %s" % (
                    "FAIL" if bad else "PASS", parts[0], " ".join(client), base_ref,
                    "%d old expectations broken" % len(bad) if bad else "every old check holds"))
                for l in bad[:12]:
                    print("      " + l[:220])
    finally:
        shutil.rmtree(copy, ignore_errors=True)
    return fails


def cmd_precommit(staged_dir):
    names = git("diff", "--cached", "--name-only", "--diff-filter=AM", "--", "Tools/audits").stdout.split()
    names = [n for n in names if n.endswith(".md") and not os.path.basename(n).upper().startswith(("README", "TEMPLATE"))]
    if not names:
        return 0
    code_changed = any(not p.startswith(("Tools/", ".claude/", "docs/")) for p in
                       git("diff", "--cached", "--name-only").stdout.split())
    fails = 0
    for name in names:
        card = read_card(name, git("show", ":" + name).stdout)
        old = git("show", "HEAD:" + name)
        old_rows = set()
        if old.returncode == 0:
            old_rows = {(c["matrix"], c["cell"], c["before"], c["after"]) for c in read_card(name, old.stdout)["changes"]}
        # (The fix in this commit: its card's new rows must happen. A card
        # staged without code, or its older rows, only catch an undeclared
        # change.)
        # (A card whose Base is an older commit (its fix already landed) is
        # loose too: HEAD has its change already.)
        base = card["base"] or "HEAD"
        on_head = base == "HEAD" or git("rev-parse", "-q", "--verify", base + "^{commit}").stdout.strip() == \
            git("rev-parse", "HEAD").stdout.strip()
        for c in card["changes"]:
            new_row = (c["matrix"], c["cell"], c["before"], c["after"]) not in old_rows
            c["loose"] = not (code_changed and new_row and on_head)
        for test, args in card["tests"]:
            lines, f = diff(test, args, "HEAD", staged_dir, card["changes"])
            report(["audit: " + l for l in lines if not l.startswith("PASS ") or " cells, " in l])
            fails += f
    return fails


def cmd_prerelease(ref):
    ref = ref or last_tag()
    cards = all_cards()
    changes = [c for card in cards for c in card["changes"]]
    tests = []
    for card in cards:
        for t in card["tests"]:
            if t not in tests:
                tests.append(t)
    fails = 0
    for test, args in tests:
        lines, f = diff(test, args, ref, "worktree", changes, loose=True)
        report([l for l in lines if not l.startswith("PASS ") or "cells" in l])
        fails += f
    print("audit matrices vs %s: %d tests, %d FAIL" % (ref, len(tests), fails))
    return fails


def selftest():
    fails = 0

    def check(name, ok):
        nonlocal fails
        fails += 0 if ok else 1
        print(("PASS " if ok else "FAIL ") + name)
    old_test = ('local function Check(name, ok) end\n'
                'Check(client .. ": 1 the card plays", played == 1, played)\n'
                'Check(client .. ": 3 the game\'s zone line shows",\n'
                '\tAlpha("ZoneTextString") == 1)\n'
                'Matrix.Run({ name = "x",\n'
                '\tpins = {\n'
                '\t\t{ "", "shown" },\n'
                '\t},\n'
                '})\n')
    d = ("diff --git a/Tools/offline/zonecardgame.lua b/Tools/offline/zonecardgame.lua\n"
         "@@ -4 +4 @@\n-\tAlpha(\"ZoneTextString\") == 1)\n+\tAlpha(\"ZoneTextString\") == 0)\n")
    found = expectations(d, lambda p: old_test)
    check("guard: a check's continuation line changed is that check",
          found == [("Tools/offline/zonecardgame.lua", "checks changed: 3 the game's zone line shows")])
    d2 = "diff --git a/Tools/offline/zonecardgame.lua b/Tools/offline/zonecardgame.lua\n@@ -7 +7 @@\n"
    check("guard: a pin changed", expectations(d2, lambda p: old_test) ==
          [("Tools/offline/zonecardgame.lua", "matrix pins changed")])
    d3 = "diff --git a/Tools/offline/zonecardgame.lua b/Tools/offline/zonecardgame.lua\n@@ -9,0 +10,3 @@\n"
    check("guard: checks only added need no OK", expectations(d3, lambda p: old_test) == [])
    d4 = ("diff --git a/Tools/offline/old.lua b/Tools/offline/old.lua\ndeleted file mode 100644\n@@ -1,9 +0,0 @@\n")
    check("guard: a test deleted", expectations(d4, lambda p: old_test)[0][1].startswith("test removed (2 checks"))
    d5 = ("diff --git a/Tools/offline/a.lua b/Tools/offline/b.lua\nsimilarity index 100%\n"
          "rename from Tools/offline/a.lua\nrename to Tools/offline/b.lua\n")
    check("guard: a test only renamed", expectations(d5, lambda p: old_test) == [])
    msg_ok = ("Fix\n\nExpectation-changed: Tools/offline/zonecardgame.lua: 3: shows -> hidden "
              "(OK'd by the user 2026-11-23)\n")
    check("guard: the OK line lets it through", guard(msg_ok, d, lambda p: old_test, lambda r: True) == [])
    check("guard: no OK line, refused", len(guard("Fix\n", d, lambda p: old_test, lambda r: True)) == 1)
    check("guard: an OK line without a date, refused",
          len(guard("Expectation-changed: zonecardgame.lua (OK'd by the user)\n", d, lambda p: old_test,
                    lambda r: True)) == 1)
    check("guard: an audit commit needs Risk and its card",
          len(guard("More fixes from the code audit: ...\n", "", lambda p: None, lambda r: True)) == 2)
    check("guard: audit commit with both",
          guard("Fixes from a code audit\n\nRisk: low\nCard: Tools/audits/2026-11-23-x.md\n", "",
                lambda p: None, lambda r: True) == [])
    check("guard: lazyaudit.lua / audit.py aren't audit commits",
          guard("lazyaudit.lua and auditsettings.lua: new checks\n", "", lambda p: None, lambda r: True) == [])
    ledger_old = "| Q1 | x? | both | yes offline | run 1 |\n| Q2 | y? | forever | open | run 1 |\n"
    ledger_new = "| Q1 | x? | both | no | run 2 |\n| Q2 | y? | forever | yes | run 2 |\n"
    new_text_cache["Tools/tests/z.md"] = ledger_new
    d6 = "diff --git a/Tools/tests/z.md b/Tools/tests/z.md\n@@ -1,2 +1,2 @@\n"
    found = expectations(d6, lambda p: ledger_old)
    check("guard: a settled ledger answer changed; an open one filled is fine",
          len(found) == 1 and found[0][1].startswith("Q1 answer"))
    rules_old = ('return {\n  {\n    id = "a.b",\n    rule = "x",\n    status = "tested",\n    tested = "1",\n  },\n}\n')
    d7 = "diff --git a/Tools/engine/rules/x.lua b/Tools/engine/rules/x.lua\n@@ -6 +6 @@\n@@ -4 +4 @@\n"
    check("guard: a rule's text changed; its tested date isn't", expectations(d7, lambda p: rules_old) ==
          [("Tools/engine/rules/x.lua", "rule a.b changed")])
    base = {("m", "card=up gap=within"): "hidden", ("m", "card=gone gap=within"): "hidden"}
    new = {("m", "card=up gap=within"): "shown", ("m", "card=gone gap=within"): "shown"}
    rows = [{"matrix": "m", "cell": "card=gone gap=within", "before": "hidden", "after": "shown", "card": "c",
             "hit": False}]
    lines, f = compare(base, new, rows)
    check("diff: the bdb2e1d miss (card up, undeclared) FAILs, the declared cell passes",
          f == 1 and any("UNDECLARED" in l and "card=up" in l for l in lines))
    check("diff: a group's cells share where they lie", common(["a=1 b=2 c=3", "a=1 b=5 c=3"]) == "a=1 c=3")
    rows[0]["hit"] = False
    lines, f = compare(base, base, rows)
    check("diff: a declared change that didn't happen FAILs", f == 1)
    rows[0]["hit"] = False
    lines, f = compare(base, base, rows, loose=True)
    check("diff: ... a NOTE with --loose", f == 0)
    card = read_card("x.md", "# X\nBase: abc123\nTest: Tools/offline/z.lua forever\n## Meant to change\n"
                             "| Matrix | Cell | Before | After |\n|---|---|---|---|\n| m | card=up | a | b |\n")
    check("card: Base, Test and rows read", card["base"] == "abc123" and card["tests"] ==
          [("Tools/offline/z.lua", ["forever"])] and len(card["changes"]) == 1 and card["changes"][0]["after"] == "b")
    print("audit selftest: %s" % ("all passed" if fails == 0 else "%d FAILED" % fails))
    return fails


def main():
    argv = sys.argv[1:]
    if not argv:
        sys.exit(__doc__)
    cmd = argv.pop(0)
    try:
        if cmd == "guard":
            try:
                return cmd_guard(argv[0])
            except Exception as err:  # (a broken guard never blocks a commit)
                print("commit-msg: the audit guard broke, not checked: %s" % err)
                return 0
        if cmd == "diff":
            base = opt(argv, "--base", "HEAD")
            new = opt(argv, "--new", "worktree")
            cards = opt(argv, "--card", many=True)
            loose = "--loose" in argv
            argv = [a for a in argv if a != "--loose"]
            changes = [c for p in cards for c in read_card(p)["changes"]]
            lines, fails = diff(argv[0].replace("\\", "/"), argv[1:], base, new, changes, loose)
            report(lines)
            return 1 if fails else 0
        if cmd == "card":
            new = opt(argv, "--new", "worktree")
            return 1 if cmd_card(argv[0], new, "--loose" in argv) else 0
        if cmd == "oldtests":
            base = opt(argv, "--base", "HEAD")
            new = opt(argv, "--new", "worktree")
            return 1 if cmd_oldtests(base, new, argv) else 0
        if cmd == "refs":
            return cmd_refs(argv)
        if cmd == "since":
            return cmd_since(argv[0] if argv else None)
        if cmd == "precommit":
            return 1 if cmd_precommit(argv[0]) else 0
        if cmd == "prerelease":
            return 1 if cmd_prerelease(argv[0] if argv else None) else 0
        if cmd == "selftest":
            return 1 if selftest() else 0
        sys.exit(__doc__)
    finally:
        cleanup()


if __name__ == "__main__":
    sys.exit(main())
