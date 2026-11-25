"""Every check that runs outside the game, before a release, in one go. From
the repo root:

    python -I Tools/prerelease.py            all of it (about 4 minutes)
    python -I Tools/prerelease.py --game     only the in-game runs' results
    python -I Tools/prerelease.py --nogame   the in-game runs skipped this time (said, not a FAIL)

Runs side by side, each a PASS or FAIL line, then one line for all of it:
- luacheck (baseline 0 warnings) and the Lua 5.1 compile of every .lua (the
  200-local cap and syntax, which luacheck misses);
- check-toc.py (dev TOC = release TOC + dev files, packaging);
- local-room.py: files near Lua's 200-local cap (named, never a FAIL);
- the full offline check (Tools/offline/check.lua: the profile modules, the
  built-in profiles' settings, setting ids);
- the settings sweep on the stand-in game, both clients
  (Tools/offline/sweep.lua: new FAIL lines against its baseline);
- the once-only settings updates on your own saved settings (each client's
  Cinematic.lua and CinematicDev.lua, a copy: nothing is written there),
  every update run from scratch: none may error, and a second run may change
  nothing (an update its done-flag doesn't guard takes a setting at every
  login, as the Cities columns did before 0fd4d31);
- the upgrade check (Tools/upgrade-check.py): the last release's code and
  this one's on the same players' saved settings; what changes for existing
  players is listed (never a FAIL: the review judges it), only a version
  that doesn't load or an update that errors fails;
- the offline tests of fixed bugs (OFFLINE_TESTS: no FAIL line), and every
  other offline test found in Tools/offline (found_tests: one printing PASS /
  FAIL / ok lines that isn't an audit matrix), so none is left out;
- the player impact scan (Tools/release-audit.py impact): player text,
  pages, /cine words, key bindings, CVars, TOC files, hooks and busy-event
  handlers added or gone since the last tag (listed, never a FAIL: the
  review raises each with the user), and the script's own selftest;
- other addons as installed against Support/ (Tools/addon-check.py: a name
  our support uses gone fails; what changed since its baseline is listed);
- the addon kit (Tools/addon-kit): every game frame our code touches against
  touchpoints.txt (a new one, a new file on one or a setting newly reaching
  one fails until --update), and the past addon misses replayed (each test
  must fail on the code before its fix and pass now), and the rule walk
  (every row's show logic for every rule word and tick column, against its
  baseline per client), with each tool's selftest (the rule walk's: each
  mutant must FAIL);
- the audit kit (Tools/audit.py): its selftest, every fix card's matrix
  against the last tag (a changed cell no card declares fails), and every
  test, ledger or rule expectation changed since the tag (listed, with
  whether its commit carried the user's OK; never a FAIL).
Then the last /cine prerelease runs on each client, read from the dev
copy's saved settings (after a /reload): their summary and NEW FAIL lines.
Each client needs a finished full run newer than the last change to the
addon's code (a commit or a changed file outside Tools/, docs/, .claude/):
none, or an older one, FAILs, unless --nogame says they were skipped.

Exit 1 on any FAIL. Needs lupa (pip install lupa) and luacheck in ~/bin.
The game's folder: CINE_WOW, else C:/Program Files (x86)/World of Warcraft.
"""
import glob
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WOW = os.environ.get("CINE_WOW", r"C:\Program Files (x86)\World of Warcraft")
CLIENTS = {"forever": "_forever_", "retail": "_retail_"}
PY = sys.executable
HOME = os.path.expanduser("~")
# Offline tests of one fixed bug each, PASS/FAIL per check (any FAIL line fails it).
OFFLINE_TESTS = [
    ("left list: a line with lines under it opens on every click", "Tools/offline/listclick.lua"),
    ("settings pages made on first open: no errors while waiting, forever", "Tools/offline/lazyaudit.lua", "forever"),
    ("settings pages made on first open: no errors while waiting, retail", "Tools/offline/lazyaudit.lua", "retail"),
    ("search makes waiting pages over frames; hub switch makes only its pages", "Tools/offline/lazysearch.lua"),
    ("/cine debug pagecost runs through the kit", "Tools/offline/pagecosttest.lua"),
    ("Exit CineMode: Show in row in place of its boxes, forever", "Tools/offline/exitrow.lua", "forever"),
    ("Exit CineMode: Show in row in place of its boxes, retail", "Tools/offline/exitrow.lua", "retail"),
    ("Exit CineMode: back at once and stays as its row ends", "Tools/offline/exitrowtick.lua"),
    ("nameplate previews: the game's own plate, dressed by the plates' code", "Tools/offline/gameplate.lua"),
    ("/cine debug platematch on the stand-in", "Tools/offline/platematch.lua"),
    ("Smart rows within / past any yards: ids, rings, fights", "Tools/offline/platedistance.lua"),
    ("no addon's support runs with it not loaded; late loads followed, forever", "Tools/offline/noaddons.lua", "forever"),
    ("no addon's support runs with it not loaded; late loads followed, retail", "Tools/offline/noaddons.lua", "retail"),
    ("party flicker (DaylightUI range fade)", "Tools/offline/partyflicker.lua"),
    ("map pin: its own Reveal box, Shortest Path's journey pin left out", "Tools/offline/mappin.lua"),
    ("card wait (Rested card behind DaylightUI's zone title)", "Tools/offline/cardwait.lua"),
    ("Discovered card hides DaylightUI's Discovered line", "Tools/offline/discoveredline.lua"),
    ("Fights: secret anchor counts and refusing frames (issue #7)", "Tools/offline/fightpoints.lua"),
    ("loops off with their page off; page building waits for /cine debug loops", "Tools/offline/loopsoff.lua"),
    ("Heal Vision: its own Show in for unit frames and for nameplates", "Tools/offline/healtworules.lua"),
    ("tooltip Location row (zone apart from class)", "Tools/offline/tooltiplocation.lua"),
    ("tooltip No wait for quest mobs with a secret unit (fights)", "Tools/offline/tooltipnowait.lua"),
    ("You level up card: Cheer, Congratulate, Commend", "Tools/offline/youlevelemotes.lua"),
    ("Auto-Hide UI: Mouseover groups on, and back on for players on it", "Tools/offline/autohidemouseover.lua"),
    ("Cooldown Manager grid: place groups and cells", "Tools/offline/cooldowngrid.lua"),
    ("cast bar other kind's look, forever", "Tools/offline/castlook.lua", "forever"),
    ("cast bar other kind's look, retail", "Tools/offline/castlook.lua", "retail"),
    ("preview match unit frames run, forever", "Tools/offline/unitmatch.lua", "forever"),
    ("preview match unit frames run, retail", "Tools/offline/unitmatch.lua", "retail"),
    ("Themes page has its own rotating preview, forever", "Tools/offline/themespreview.lua", "forever"),
    ("Themes page has its own rotating preview, retail", "Tools/offline/themespreview.lua", "retail"),
    ("Cast Bars pages show the unit frame over their cast bars, forever", "Tools/offline/castframe.lua", "forever"),
    ("Cast Bars pages show the unit frame over their cast bars, retail", "Tools/offline/castframe.lua", "retail"),
    ("Mac notch covers, forever", "Tools/offline/notchgap.lua", "forever"),
    ("Mac notch covers, retail", "Tools/offline/notchgap.lua", "retail"),
    ("Far Service NPCs names fade behind walls, forever", "Tools/offline/servicefardim.lua", "forever"),
    ("Far Service NPCs names fade behind walls, retail", "Tools/offline/servicefardim.lua", "retail"),
    ("XP text font per character at login", "Tools/offline/xpfont.lua"),
    ("music volume never kept near 0", "Tools/offline/musicvolume.lua"),
    ("Shoulder Cam off in a fight: soft target given back after", "Tools/offline/shoulderfightoff.lua"),
    ("tabs off before their page is opened; Graphics+ tabs, forever", "Tools/offline/lazytabs.lua", "forever"),
    ("tabs off before their page is opened; Graphics+ tabs, retail", "Tools/offline/lazytabs.lua", "retail"),
    ("camera script played over another finishes it first", "Tools/offline/scriptreplace.lua"),
    ("minimap let go in a fight while parked full size", "Tools/offline/minimapfightpark.lua"),
    ("unit frame parts let go with their frame; a failed loop back with its feature", "Tools/offline/heldpartsletgo.lua"),
    ("PRD power fill: the game's newest put back after a form change, forever", "Tools/offline/prdformfill.lua", "forever"),
    ("PRD power fill: the game's newest put back after a form change, retail", "Tools/offline/prdformfill.lua", "retail"),
    ("audit: Chat tabs gate their rows; left-out errors; hover watch; slider with no value, forever", "Tools/offline/auditsettings.lua", "forever"),
    ("audit: Chat tabs gate their rows; left-out errors; hover watch; slider with no value, retail", "Tools/offline/auditsettings.lua", "retail"),
    ("addon support gated: Questie not in or switched off, DaylightUI keeper chained, bubble hooks", "Tools/offline/questiegate.lua"),
    ("plate fill's color back after a full-color theme, forever", "Tools/offline/platefullwhite.lua", "forever"),
    ("plate fill's color back after a full-color theme, retail", "Tools/offline/platefullwhite.lua", "retail"),
    ("By health: one curve, no garbage per health change", "Tools/offline/byhealthalloc.lua"),
    ("combat text past 120: font capped, words scaled, forever", "Tools/offline/combattextsize.lua", "forever"),
    ("combat text past 120: font capped, words scaled, retail", "Tools/offline/combattextsize.lua", "retail"),
    ("plates' guild line: no garbage per frame of a fade", "Tools/offline/guildlinealloc.lua"),
    ("every texture wrap mode is one the game knows", "Tools/offline/wrapmode.lua"),
    ("the Reload box drops a layout reason no longer true", "Tools/offline/reloadreason.lua"),
    ("a shared profile's lists of the wrong shape refused; Follow HUD undo safe", "Tools/offline/shareshape.lua"),
    ("cameras, fights and fades: safety stop, zoom max holds, raid auras, detached parts, boss end, corpse check, forever", "Tools/offline/fightsfades.lua", "forever"),
    ("cameras, fights and fades: safety stop, zoom max holds, detached parts, boss end, corpse check, retail", "Tools/offline/fightsfades.lua", "retail"),
    ("chat background partway doesn't keep the frame pass busy", "Tools/offline/chatbgsettle.lua"),
    ("game's zone text shows when no Zone card replaces it, forever", "Tools/offline/zonecardgame.lua", "forever"),
    ("game's zone text shows when no Zone card replaces it, retail", "Tools/offline/zonecardgame.lua", "retail"),
    ("a v2.1.23 share string or backup keeps its Cooldown Manager lines", "Tools/offline/cooldownoldshare.lua"),
    ("chat lines-only peeks only with the game's own chat", "Tools/offline/chatdefault.lua"),
    ("/cine debug chatdefault passes, game's chat and DaylightUI's", "Tools/offline/chatdefaultkit.lua"),
    ("combat text keeps the game's numbers as its rows say", "Tools/offline/combattextkeep.lua"),
    ("combat text: a totem's hit matched to its cast", "Tools/offline/totemcast.lua"),
    ("totem test (/cine debug totemhit) steps and verdicts", "Tools/offline/totemhit.lua"),
    ("page snapshot (/cine debug pagestate) logs the preview and what hangs from it", "Tools/offline/pagestate.lua"),
    ("combat text page's Experimental notice, forever", "Tools/offline/combattextwarn.lua", "forever"),
    ("combat text page's Experimental notice, retail", "Tools/offline/combattextwarn.lua", "retail"),
    ("reloads through a secure /reload on Forever, forever", "Tools/offline/reload.lua", "forever"),
    ("reloads as before on retail, retail", "Tools/offline/reload.lua", "retail"),
    ("detached parts follow our fade (FlareUI's gryphons)", "Tools/offline/gryphons.lua"),
    ("loose parts survey (/cine debug loose) finds exactly the detached parts", "Tools/offline/loosesurvey.lua"),
    ("dead mob test (/cine debug deadmob) steps and verdicts", "Tools/offline/corpse.lua"),
    ("a logout forgets the last tab under each icon, forever", "Tools/offline/hublasttab.lua", "forever"),
    ("a logout forgets the last tab under each icon, retail", "Tools/offline/hublasttab.lua", "retail"),
    ("every Style page links back to its settings (gear), and back again, forever", "Tools/offline/stylebacklinks.lua", "forever"),
    ("every Style page links back to its settings (gear), and back again, retail", "Tools/offline/stylebacklinks.lua", "retail"),
    ("Style left out: Visions General shows no palette", "Tools/offline/stylebacklinks.lua", "forever", "nostyle"),
    ("Allow offscreen nameplates: the old tick moved, Auto / Always / Never, forever", "Tools/offline/offscreenallow.lua", "forever"),
    ("Allow offscreen nameplates: the old tick moved, Auto / Always / Never, retail", "Tools/offline/offscreenallow.lua", "retail"),
    ("hover through a stand-in (Shoulder Cam's button over your player frame)", "Tools/offline/hoverstandin.lua"),
    ("Interface Recolor with Glass's HookScript on the chat tabs", "Tools/offline/glasshook.lua"),
    ("Questie's 40 quest item buttons fade with the Quest tracker row", "Tools/offline/questieitembuttons.lua"),
    ("addon test: steps that showed nothing skipped, frames never made can't pass", "Tools/offline/addontestsmarts.lua"),
    ("test kit (/cine debug kitcheck): steps, undo, stop, login put back", "Tools/offline/testkit.lua"),
    ("old tests on the kit's logs (Dev/TestKitWrap.lua): context, run before kept, totals", "Tools/offline/testkitwrap.lua"),
    ("test queue (Dev/TestQueue.lua): offer, Run all, results apart, Stop queue, reload pickup, cut-off", "Tools/offline/testqueue.lua"),
    ("a part the Show-in rows let go comes back at the alpha it was given (theme's name strip)", "Tools/offline/parthold.lua"),
    ("the side-by-side test's probe finds every part on both target frames of you", "Tools/offline/selfpairprobe.lua"),
    ("the test box's timers: step, run, time left, took", "Tools/offline/testboxclock.lua"),
    ("a bar's numbers sized to fit their bar (the thin mana bar's)", "Tools/offline/bartextsize.lua"),
    ("mana words are whole numbers, never 338.00003051758 (secret mana after a cast)", "Tools/offline/wholemana.lua"),
    ("settings opened in a fight: the gamepad UI's blocked lines kept out of the dev box", "Tools/offline/quietblock.lua"),
]


PASS_PRINT = re.compile(r'"(PASS[ "%]|FAIL |ok  )')
CLIENT_ARG = re.compile(r'client\w*\s*=\s*[^\n]*arg\s+and\s+arg\[1\]')
# Offline files that print PASS/FAIL lines but aren't tests to run on their
# own: run above with their own arguments (the sweep per client, the check,
# the updates on your saved settings). A helper that matches goes here too.
NOT_RUN = {"sweep.lua", "check.lua", "migrate-test.lua"}


def found_tests():
    """Every other offline test (prints PASS / FAIL / ok lines, not an audit matrix: those run through
    Tools/audit.py prerelease), so a new test runs before a release without being listed by hand. Before
    2026-11-23 only the hand list ran: 71 tests never did, 3 of them failing (prerelease audit). One whose
    client comes from arg[1] runs on both. Its name: the file's first comment line."""
    listed = {each[1] for each in OFFLINE_TESTS}
    found = []
    for path in sorted(glob.glob(os.path.join(ROOT, "Tools", "offline", "*.lua"))):
        script = "Tools/offline/" + os.path.basename(path)
        if script in listed or os.path.basename(path) in NOT_RUN:
            continue
        with open(path, encoding="utf-8", errors="replace") as f:
            text = f.read()
        if "Matrix.Run" in text or not PASS_PRINT.search(text):
            continue
        head = next((l[3:].strip() for l in text.splitlines() if l.startswith("-- ")), script)
        head = re.sub(r"\s*[(,]\s*(dev tool, )?(offline|Lua 5\.1)\b.*$", "", head).rstrip(" :,(") or script
        name = "%s (%s)" % (head, os.path.basename(path))
        if CLIENT_ARG.search(text):
            found += [("%s, %s" % (name, client), script, client) for client in CLIENTS]
        else:
            found.append((name, script))
    return found


def lua_files():
    out = subprocess.run(["git", "ls-files", "--cached", "--others", "--exclude-standard", "*.lua"],
                         cwd=ROOT, capture_output=True, text=True).stdout.split()
    return [f for f in out if not f.startswith((".claude/", "Release/")) and os.path.exists(os.path.join(ROOT, f))]


def saved_files(client, name):
    pattern = os.path.join(WOW, CLIENTS[client], "WTF", "Account", "*", "SavedVariables", name)
    return sorted(glob.glob(pattern))


class Job:
    """One check as a process: its name, command, and how to read its output."""

    def __init__(self, name, cmd, judge=None):
        self.name, self.cmd, self.judge = name, cmd, judge
        self.started = time.time()
        self.proc = subprocess.Popen(cmd, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                     stdin=subprocess.DEVNULL, text=True, encoding="utf-8", errors="replace")

    def finish(self):
        output, _ = self.proc.communicate()
        self.seconds = time.time() - self.started
        ok = self.proc.returncode == 0
        detail = ""
        if self.judge:
            ok, detail = self.judge(ok, output)
        self.ok, self.output, self.detail = ok, output, detail
        return self


def last_line(output, starts=None):
    lines = [l for l in output.strip().splitlines() if l.strip()]
    if starts:
        lines = [l for l in lines if l.startswith(starts)] or lines
    return lines[-1].strip() if lines else ""


def judge_luacheck(ok, output):
    total = last_line(output, "Total:")
    return ok and "0 warnings / 0 errors" in total, total


def judge_compile(ok, output):
    bad = [l for l in output.splitlines() if l.strip() and not l.rstrip().endswith(" ok")]
    return ok and not bad, ("%d files ok" % len(output.splitlines())) if not bad else "; ".join(bad[:5])


def judge_room(ok, output):
    # (Never a FAIL by itself: a file at the cap still loads. Each tight one is
    # named, so a session adding locals there sees it; a file that doesn't
    # compile fails here and in the compile above.)
    tight = [l.strip() for l in output.splitlines() if l[:3].strip().isdigit()]
    detail = last_line(output, "local room:")
    if tight:
        detail += "\n      " + "\n      ".join(tight)
    return ok, detail


def judge_check(ok, output):
    line = last_line(output, "profile modules:")
    return ok and "0 problems" in line, line


def judge_sweep(ok, output):
    lines = output.strip().splitlines()
    new = [l.strip() for l in lines if l.strip().startswith(("NEW ", "GONE "))]
    summary = last_line(output, "sweep ")
    detail = summary + ("".join("\n      " + l[:220] for l in new[:8]) if new else "")
    return ok, detail


def judge_test(ok, output):
    # (PASS lines or "ok" ones (servicefardim's), or none but an all-passed end
    # (enginerules' OK, shelforder's ALL PASS); any FAIL line or exit 1 fails.)
    lines = [l.strip() for l in output.splitlines()]
    # (A test's own FAIL line is "FAIL <name>" or a bare "FAIL"; "FAIL: ..." is
    # a dev test's verdict text the test echoes and checks on purpose, as
    # totemhit.lua does with "FAIL: 0 numbers drawn", 2026-11-23.)
    failed = [l for l in lines if l == "FAIL" or l.startswith(("FAIL ", "FAIL\t"))]
    passed = sum(1 for l in lines if l.startswith(("PASS ", "ok ")))
    if failed or not ok:
        return False, "; ".join(failed[:4]) or last_line(output)
    if passed:
        return True, "%d checks passed" % passed
    end = last_line(output)
    if re.search(r"(?i)all passed|all pass$|^ok$", end):
        return True, end
    return False, "no PASS lines and no all-passed end: " + end


def judge_audit(ok, output):
    # (A changed cell no fix card declares, or a cell the test pins
    # differently: each FAIL line with the cells under it.)
    lines = output.splitlines()
    shown = [l.rstrip() for l in lines if l.startswith("FAIL")]
    detail = last_line(output, "audit matrices")
    return ok, detail + "".join("\n      " + l[:220] for l in shown[:12])


def judge_since(ok, output):
    # (Never a FAIL: the review shows each one, and whether its commit had the user's OK.)
    lines = output.splitlines()
    shown = [l.strip() for l in lines if l.startswith("  ")]
    detail = last_line(output, "expectations changed")
    return True, detail + "".join("\n      " + l[:220] for l in shown[:20])


def judge_impact(ok, output):
    # (Never a FAIL: each line is a flag the release review raises with the user. All shown.)
    lines = [l.strip() for l in output.splitlines() if l.startswith("  ")]
    return ok, last_line(output, "impact scan:") + "".join("\n      " + l[:220] for l in lines)


def judge_addons(ok, output):
    lines = output.splitlines()
    shown = [l.strip() for l in lines if l.startswith(("FAIL", "MISS", "NOTE", "      +", "      -"))]
    detail = last_line(output, "addon check:")
    return ok, detail + "".join("\n      " + l[:220] for l in shown[:16])


def judge_migrate(ok, output):
    # (Also a second run that changes anything: an update not guarded by its done-flag.)
    failed = [l for l in output.splitlines() if l.startswith("update failed")]
    if failed:
        return False, "; ".join(failed[:3]) + (" (and %d more)" % (len(failed) - 3) if len(failed) > 3 else "")
    line = last_line(output)
    return ok, line.split(" lines written")[0] + " lines" if " lines written" in line else line


UPGRADE_FILE = os.path.join(tempfile.gettempdir(), "cine-upgrade-check.txt")
# (What an existing player gets changed: every one shown. Before 2026-11-23
# the first 30 of ~200 lines were, mostly dropped settings, so a changed
# default (planted: tooltipFadeTime 0.2 -> 2) never reached the review.)
UPGRADE_SHOWN = ("FAIL", "  CHANGED", "  DEFAULT", "  TYPE", "  RELOAD", "  FALLBACK", "  NEW ON")
UPGRADE_COUNTED = (("  DROPPED", "dropped"), ("  NEW ", "new"))


def judge_upgrade(ok, output):
    lines = output.splitlines()
    try:
        with open(UPGRADE_FILE, "w", encoding="utf-8") as f:
            f.write(output)
    except OSError:
        pass
    # (Each once, with how many of its runs, both clients and each kind of
    # player, it came up in.)
    seen = {}
    for l in lines:
        if l.startswith(UPGRADE_SHOWN):
            seen[l.strip()] = seen.get(l.strip(), 0) + 1
    shown = [k + ("   (x%d)" % n if n > 1 else "") for k, n in seen.items()]
    counted = []
    for prefix, word in UPGRADE_COUNTED:
        unique = {l.strip() for l in lines if l.startswith(prefix) and not l.startswith(UPGRADE_SHOWN)}
        if unique:
            counted.append("%d %s" % (len(unique), word))
    detail = last_line(output, "upgrade check:") + " (all of it: %s)" % UPGRADE_FILE
    detail += "".join("\n      " + l[:220] for l in shown)
    if counted:
        detail += "\n      and " + ", ".join(counted) + " settings (in the file)"
    return ok, detail


def last_code_change():
    """When the addon's code last changed: its last commit, or a file changed since (not Tools/, docs/ or
    .claude/: they don't run in the game). As "YYYY-MM-DD HH:MM", the in-game runs' own clock."""
    outside = ["--", ".", ":!Tools", ":!docs", ":!.claude", ":!*.md"]
    stamp = subprocess.run(["git", "log", "-1", "--format=%cd", "--date=format-local:%Y-%m-%d %H:%M"] + outside,
                           cwd=ROOT, capture_output=True, text=True).stdout.strip()
    changed = subprocess.run(["git", "diff", "HEAD", "--name-only"] + outside, cwd=ROOT, capture_output=True,
                             text=True).stdout.split()
    changed += subprocess.run(["git", "ls-files", "--others", "--exclude-standard"] + outside, cwd=ROOT,
                              capture_output=True, text=True).stdout.split()
    for path in changed:
        full = os.path.join(ROOT, path)
        if os.path.exists(full):
            stamp = max(stamp, time.strftime("%Y-%m-%d %H:%M", time.localtime(os.path.getmtime(full))))
    return stamp


def selftest():
    """The in-game gate on made-up saved settings: no run, an older full run, a newer one, one with a NEW FAIL,
    --nogame. PASS/FAIL per check."""
    global WOW
    real, failed = WOW, 0
    for name, output, want in (("a test's FAIL line fails it", "PASS a\nFAIL b\n", False),
                               ("an echoed 'FAIL: ...' verdict text doesn't", "PASS a\nFAIL: 0 drawn\nALL PASS\n", True)):
        got = judge_test(True, output)[0]
        print("%s  test lines: %s" % ("PASS" if got == want else "FAIL", name))
        failed += 0 if got == want else 1
    run = ('{ kind = "%s", when = "%s", finished = true, summary = "s", new = {%s}, '
           'results = { ["x"] = { detail = "d" } } }')
    cases = [
        ("no run: FAIL", "", "2026-11-23 10:00", False, False),
        ("a full run older than the code: FAIL", run % ("full", "2026-11-23 09:00", ""), "2026-11-23 10:00", False,
         False),
        ("a full run newer than the code: PASS", run % ("full", "2026-11-23 11:00", ""), "2026-11-23 10:00", False,
         True),
        ("a newer full run with a NEW FAIL: FAIL", run % ("full", "2026-11-23 11:00", '"x"'), "2026-11-23 10:00",
         False, False),
        ("only an older quick run, no full: FAIL", run % ("quick", "2026-11-23 09:00", ""), "2026-11-23 10:00", False,
         False),
        ("--nogame: never a FAIL", "", "2026-11-23 10:00", True, True),
    ]
    for name, ok, output, want in [
        ("judge: ok lines pass (servicefardim's)", True, "ok   1 x\nok   2 y\nx: all passed\n", True),
        ("judge: an OK end passes (enginerules')", True, "360 rules\nOK\n", True),
        ("judge: ALL PASS end passes (shelforder's)", True, "shelf order: a\nALL PASS\n", True),
        ("judge: no PASS lines and no all-passed end fails", True, "did something\n", False),
        ("judge: a FAIL line fails, exit 0 or not", True, "PASS a\nFAIL b\n", False),
        ("judge: exit 1 fails", False, "PASS a\n", False),
    ]:
        good = judge_test(ok, output)[0] == want
        failed += 0 if good else 1
        print("%s %s" % ("PASS" if good else "FAIL", name))
    sample = ("  DROPPED [\"a\"] (was 1)\n" * 40 + "  CHANGED [\"x\"]: 1 -> 2\n  CHANGED [\"x\"]: 1 -> 2\n"
              "  DEFAULT [\"tooltipFadeTime\"]: 0.2 -> 2 (existing players keep 0.2)\n  NEW     [\"n\"] = false\n"
              "upgrade check: 44 things change for existing players\n")
    _, shown = judge_upgrade(True, sample)
    good = ("DEFAULT [\"tooltipFadeTime\"]" in shown and "CHANGED [\"x\"]: 1 -> 2   (x2)" in shown
            and "DROPPED" not in shown and "1 dropped, 1 new" in shown)
    failed += 0 if good else 1
    print("%s judge: a changed default shown past 40 dropped lines; repeats once; dropped/new counted" % (
        "PASS" if good else "FAIL"))
    found = {script for _, script, *_ in found_tests()}
    good = "Tools/offline/followhud.lua" in found and not any("matrix" in s for s in found)
    failed += 0 if good else 1
    print("%s found tests: a test not in the list is run (followhud), no audit matrix" % ("PASS" if good else "FAIL"))
    global last_code_change
    real_since = last_code_change
    try:
        for name, runs, since, skipped, want in cases:
            WOW = tempfile.mkdtemp(prefix="cine-prerelease-selftest-")
            for client, folder in CLIENTS.items():
                saved = os.path.join(WOW, folder, "WTF", "Account", "A", "SavedVariables")
                os.makedirs(saved)
                with open(os.path.join(saved, "CinematicDev.lua"), "w", encoding="utf-8") as f:
                    f.write("CinematicDB = { prerelease = { %s = { %s } } }\n" % (client, runs))
            last_code_change = lambda since=since: since  # noqa: E731
            rows = game_results(skipped)
            passed = all(ok is not False for _, ok, _ in rows)
            good = passed == want
            failed += 0 if good else 1
            print("%s %s%s" % ("PASS" if good else "FAIL", name, "" if good else ": " + repr(rows)))
            shutil.rmtree(WOW, ignore_errors=True)
    finally:
        WOW, last_code_change = real, real_since
    return failed


def game_results(skipped=False):
    """The last /cine prerelease runs per client and kind, from the dev copy's saved settings. Each client
    needs a finished full run after the last code change: none, or an older one, FAILs (it proves nothing
    about this code). --nogame: the user skipped them this time (said, never a FAIL)."""
    if skipped:
        return [("in game, %s" % client, None, "skipped this time (--nogame)") for client in CLIENTS]
    try:
        import lupa.lua51 as lua51
    except ImportError:
        return [("in-game runs", False, "lupa isn't installed (pip install lupa)")]
    since = last_code_change()
    rows = []
    for client in CLIENTS:
        files = saved_files(client, "CinematicDev.lua")
        if not files:
            rows.append(("in game, %s" % client, False, "no CinematicDev.lua saved settings found"))
            continue
        for path in files:
            lua = lua51.LuaRuntime(unpack_returned_tuples=True)
            env = lua.eval("{}")
            chunk = lua.eval("function(text, env) local f = assert(loadstring(text)) setfenv(f, env) f() end")
            with open(path, encoding="utf-8", errors="replace") as f:
                chunk(f.read(), env)
            db = env["CinematicDB"]
            store = db and db["prerelease"]
            runs = store and store[client]
            if not runs or len(runs) == 0:
                rows.append(("in game, %s" % client, False, "no /cine prerelease run yet (run it, or --nogame to "
                                                            "skip it this time)"))
                continue
            latest = {}
            for i in range(1, len(runs) + 1):
                latest[runs[i]["kind"]] = runs[i]
            if "full" not in latest:
                rows.append(("in game, %s, full" % client, False, "no full /cine prerelease run yet"))
            for kind in ("full", "quick", "guided"):
                each = latest.get(kind)
                if not each:
                    continue
                if str(each["when"]) < since:
                    # (A run of older code: it proves nothing about this one.)
                    rows.append(("in game, %s, %s" % (client, kind), False if kind == "full" else None,
                                 "%s (%s): older than the last code change (%s), run it again" % (
                                     each["summary"], each["when"], since)))
                    continue
                new = each["new"]
                names = [new[i] for i in range(1, len(new) + 1)] if new else []
                results = each["results"]
                lines = []
                for name in names[:10]:
                    detail = results[name] and results[name]["detail"]
                    lines.append("NEW FAIL %s%s" % (name, (": " + str(detail)[:160]) if detail else ""))
                ok = bool(each["finished"]) and not names
                detail = "%s (%s)" % (each["summary"], each["when"]) + "".join("\n      " + l for l in lines)
                rows.append(("in game, %s, %s" % (client, kind), ok, detail))
    return rows


def main():
    if "--selftest" in sys.argv:
        sys.exit(1 if selftest() else 0)
    only_game = "--game" in sys.argv
    jobs = []
    if not only_game:
        lua = [PY, "-I", "Tools/offline/run.py"]
        luacheck = os.path.join(HOME, "bin", "luacheck.exe")
        jobs.append(Job("luacheck", [luacheck, "."], judge_luacheck))
        jobs.append(Job("Lua 5.1 compile", [PY, os.path.join(HOME, "bin", "luacompile.py")] + lua_files(),
                        judge_compile))
        jobs.append(Job("TOCs", [PY, "-I", "Tools/check-toc.py"], lambda ok, out: (ok, last_line(out))))
        jobs.append(Job("locals to spare (Lua's 200 cap)", [PY, "-I", "Tools/local-room.py"], judge_room))
        jobs.append(Job("offline check (profiles, ids)", lua + ["Tools/offline/check.lua"], judge_check))
        for client in CLIENTS:
            jobs.append(Job("offline sweep, %s" % client, lua + ["Tools/offline/sweep.lua", client], judge_sweep))
        for name, script, *args in OFFLINE_TESTS + found_tests():
            jobs.append(Job(name, lua + [script] + args, judge_test))
        jobs.append(Job("prerelease's own checks (the in-game gate)", [PY, "-I", "Tools/prerelease.py", "--selftest"],
                        judge_test))
        jobs.append(Job("audit kit's own checks (Tools/audit.py selftest)", [PY, "-I", "Tools/audit.py", "selftest"],
                        judge_test))
        jobs.append(Job("fix cards' matrices vs the last release (Tools/audits)", [PY, "-I", "Tools/audit.py",
                                                                                   "prerelease"], judge_audit))
        jobs.append(Job("expectations changed since the last release", [PY, "-I", "Tools/audit.py", "since"],
                        judge_since))
        jobs.append(Job("upgrade check (existing players' settings)", [PY, "-I", "Tools/upgrade-check.py"],
                        judge_upgrade))
        jobs.append(Job("release audit's own checks (Tools/release-audit.py selftest)",
                        [PY, "-I", "Tools/release-audit.py", "selftest"], judge_test))
        jobs.append(Job("player impact scan (labels, pages, commands, keys, CVars, hooks, load)",
                        [PY, "-I", "Tools/release-audit.py", "impact"], judge_impact))
        jobs.append(Job("other addons vs our support", [PY, "-I", "Tools/addon-check.py"], judge_addons))
        jobs.append(Job("addon kit: game frames we touch vs Tools/addon-kit/touchpoints.txt",
                        [PY, "-I", "Tools/addon-kit/touchpoints.py"], lambda ok, out: (ok, last_line(out))))
        jobs.append(Job("addon kit: past addon misses replayed (Tools/addon-kit/misses)",
                        [PY, "-I", "Tools/addon-kit/misses.py"], lambda ok, out: (ok, last_line(out))))
        jobs.append(Job("addon kit: rule walk, every row x word x tick vs its baseline (both clients)",
                        [PY, "-I", "Tools/addon-kit/rulewalk.py"], lambda ok, out: (ok, last_line(out))))
        for kit in ("touchpoints", "misses", "rulewalk"):
            jobs.append(Job("addon kit: %s.py's own checks" % kit, [PY, "-I", "Tools/addon-kit/%s.py" % kit,
                                                                     "--selftest"], judge_test))
        scratch = tempfile.mkdtemp(prefix="cine-prerelease-")
        for client in CLIENTS:
            for name, toc in (("Cinematic.lua", "Cinematic.toc"), ("CinematicDev.lua", "CinematicDev.toc")):
                for path in saved_files(client, name):
                    out = os.path.join(scratch, "%s-%s.txt" % (client, name))
                    jobs.append(Job("updates on your %s %s" % (client, name),
                                    lua + ["Tools/offline/migrate-test.lua", client, toc, path, out], judge_migrate))
        print("prerelease: %d checks running side by side (the offline check takes a few minutes)..." % len(jobs))
        sys.stdout.flush()

    failed = 0
    for job in jobs:
        job.finish()
        mark = "PASS" if job.ok else "FAIL"
        failed += 0 if job.ok else 1
        print("%s  %s (%.0f s): %s" % (mark, job.name, job.seconds, job.detail))
        if not job.ok and not job.detail:
            print("      " + "\n      ".join(job.output.strip().splitlines()[-8:]))
    if not only_game:
        shutil.rmtree(scratch, ignore_errors=True)
    for name, ok, detail in game_results("--nogame" in sys.argv):
        mark = "PASS" if ok else ("----" if ok is None else "FAIL")
        failed += 1 if ok is False else 0
        print("%s  %s: %s" % (mark, name, detail))
    print("prerelease: %s" % ("all passed" if failed == 0 else "%d FAILED" % failed))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
