---
name: audit
description: The user typed /audit, asked for a code audit, or a fix from an audit or a release review is about to change behavior. Each fix gets a fix card (before/after, who relies on the old behavior, every state it touches), a matrix test run on the old code and the new so any changed state the card doesn't declare fails, a check against existing offline tests, ledgers and engine rules (a changed expectation needs the user's OK), and a risk note in its own commit. Stops audit fixes breaking what players relied on.
argument-hint: "[area or files] | card <Tools/audits/card.md>"
---

# /audit

The user: "im so tired of us 'fixing' some things in audits and breaking
others". What went wrong before (7c3e0c1, bdb2e1d, ae2cda8, 2026-11-22):

- 8 to 20 fixes per commit, 55 files: nobody could weigh one fix alone.
- Each fix's offline test pinned **only the bug's own state**. bdb2e1d made
  the game's zone line show "when no card replaces it"; its test pinned "no
  card, the last one gone: shows". No one asked "and with the last card still
  up?". Players saw the zone name twice (e202b4a). Its territory change broke
  another state the release review then fixed (ae2cda8).
- Nothing compared the new code's behavior with the old's, state by state.

`python -I Tools/audit.py diff Tools/offline/zonecardmatrix.lua forever --base bdb2e1d^ --new bdb2e1d`
shows what this kit would have said: 26 changed cells, none declared, the
Darrowmere case (`card=up gap=within`) and the territory one among them.

## The rules

1. **One fix, one card, one commit.** A card is `Tools/audits/<date>-<area>.md`
   (copy `Tools/audits/TEMPLATE.md`). Fixes in one function may share one.
2. **Before and after, in player words, and who relies on the old.**
3. **Every state the code reads is a matrix dimension, and every cell is
   pinned** with what's *right* (not what the code does). A cell whose right
   answer isn't plain is the user's call: ask, don't guess.
4. **Only the cells the card declares may change.** `audit.py diff` fails on
   any other.
5. **A changed expectation needs the user's OK before the commit.** That is:
   an existing offline check or matrix pin whose outcome changes or that is
   edited or removed; a test ledger answer that was settled (not "open");
   an engine rule's rule, works, fails, clients or tested status; a built-in
   profile's settings (`check.lua --update`), the sweep baseline. Show the
   user the was -> now and why, wait for a plain yes, quote it in the card,
   and put one line per file in the commit message:
   `Expectation-changed: Tools/offline/x.lua: <check>: <was> -> <now> (OK'd by the user YYYY-MM-DD)`.
   The commit-msg hook refuses the commit without it. Never write the line
   without the user's yes in this conversation; never edit an old check to
   make the new code pass.
6. **A risk note in the commit body**, and the card's path.

## 0. An audit (many findings)

Read the area, list the findings first, **no edits**: each with file:line,
before -> after, who'd notice, risk, and whether it's a clear bug or the
user's call. The user picks. Then steps 1-7 for each picked fix, one at a
time, each its own commit (stage + commit in one command, only your files,
the whats-new skill first: the repo's commit rules).

## 1. The card

- Copy `Tools/audits/TEMPLATE.md`. `Base:` = the current HEAD hash (the code
  before the fix).
- Who relies on it: `python -I Tools/audit.py refs <function> <setting key> <frame> <event>`
  lists the addon's code, Support/, Migrations, the built-in profiles' settings,
  offline and Dev tests, ledgers, engine rules, other cards and memory. **Read
  each hit**; write down the ones that depend on the old behavior. Then
  `python -I .claude/skills/test/known.py <words>` for test logs and API docs.
- An engine rule (Tools/engine/rules) or a ledger answer that says the fix
  can't work, or that the old behavior is what the game needs: stop and tell
  the user.

## 2. The matrix test

- List every condition the changed code and its callers read: settings (each
  row and tick), what's on screen (a card up, a frame shown), time (within a
  gap or after), combat, CineMode on/off, instance kind, the client, another
  addon loaded or not. Each is a dimension; keep the values that change the
  branch taken. All of them, not only the bug's.
- Write `Tools/offline/<area>matrix.lua` on `Tools/offline/matrix.lua` (copy
  `Tools/offline/zonecardmatrix.lua`). The cell function returns one outcome
  string from what the player sees (alpha, text, a setting, a card fired), and
  uses only what the **old** code has too: it runs on both.
- Pin every cell (`pins`, later pins win). An unpinned cell FAILs.
- Run it on the old code: `python -I Tools/audit.py diff <test> <client> --base HEAD`
  (nothing changed yet: 0 changed cells). The pins that FAIL now must be
  exactly the bug's cells. Any other failing pin is another bug: report it,
  don't fold it into this fix.
- Write the bug's cells into the card's **Meant to change** table
  (`| matrix | dim=value ... | before | after |`; `*` = any).

## 3. The fix

Change the code. Then:

```
python -I Tools/audit.py card Tools/audits/<card>.md
```

Must say: the declared cells changed as declared, no UNDECLARED cell, every
pin PASS, both clients. An UNDECLARED cell is a neighbor the fix breaks: fix
the fix, or (if the change is right) ask the user and add the row.

## 4. Old expectations

```
python -I Tools/audit.py oldtests --base HEAD [Tools/offline/x.lua ...]
```

runs the **old** version of each offline test you changed (or name the
related ones from step 1) on the new code: each FAIL is an expectation the
fix changes. Run the related offline tests as they are now too, `luacheck .`,
and the error skill's `errors.py check .`. Each changed expectation: rule 5.

## 5. In-game gaps

The matrix stubs some states (a card "up" by a stand-in). Write each into the
card's Risk ("not proven offline") and into the feature's ledger as a question
for the test skill's one run. Don't hand over steps: the test skill decides.

## 6. The commit

Body (after the player-facing subject, as usual):

```
Risk: <low|medium|high>: <who could notice, how often>
Before -> after: <one line>
Keeps: <matrix>: <n> cells unchanged, both clients; <other tests kept>
Expectations changed: none | <each, with the user's OK>
Card: Tools/audits/<date>-<area>.md
```

plus the `Expectation-changed:` lines (rule 5). The pre-commit hook runs the
staged card's matrices (HEAD vs staged: a row new in this commit must happen,
nothing undeclared); the commit-msg hook checks expectations, `Risk:` and the
card for any commit whose message says code audit / audit fix.

## 7. Before a release

`Tools/prerelease.py` runs every card's matrices against the last tag (a
changed cell no card declares fails: a later change broke a pinned neighbor)
and lists every expectation changed since the tag with its OK line. The
release review shows both.

## Tools

| Command | What |
|---|---|
| `audit.py refs <word>...` | who relies on a function, setting, frame, event |
| `audit.py diff <test> [client] --base REF [--new REF\|staged\|DIR] [--card C]` | a matrix, old code vs new, cell by cell |
| `audit.py card <card>` | every Test: of a card against its Base: (a landed card, `Base: X^`, against X itself; its pins then only noted, as they say what's right today) |
| `audit.py oldtests --base REF [tests]` | old tests on the new code |
| `audit.py since [REF]` | expectations changed since a tag, with their OKs |
| `audit.py guard <msgfile>` | the commit-msg check (Tools/hooks/commit-msg) |
| `audit.py selftest` | the kit's own checks |

All from the repo root with `python -I`. They export old code with
`git archive` into a scratch folder: never a stash, checkout or branch switch.
