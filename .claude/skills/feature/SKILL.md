---
name: feature
description: The user typed /feature, or pasted a player's idea or wish (a comment, GitHub issue, Discord message or screenshot asking for something Cinematic doesn't do), or asked "could we add X?". Checks whether Cinematic already does it (and on which client), whether it was parked or removed before, and whether the game lets an addon do it at all; then reports a short plan (where it goes, what it touches, how it's tested) and a draft reply to the player. Builds only after the user's OK.
argument-hint: "[pasted player request, issue, or idea; or just images]"
---

Someone wants something new. The goal is an honest answer fast: **it's
already there** (and how to find it), **it can't be done** (and why), or **here's
the plan**. Memories and old plans are leads to check, not answers: the code
changes every day.

Two phases with a hard stop between them, as in /support and /addon-support:
**phase 1 investigates, plans and drafts; nothing is built, committed, posted
or closed until the user says so.**

If it turns out to be a problem, not a wish ("X doesn't work"), it's /support.
If it's "work with addon X", it's /addon-support. Say so and switch.

## Phase 1: investigate

### 1. Intake

- Read every image and all the text. **Cut off?** Say so first and ask for
  the rest.
- Restate the request in one plain sentence: what the player wants to see or
  do, in game terms ("hide the minimap only while mounted", not "a minimap
  mount condition"). If it could mean two things, say both and ask.
- Note the **client** (Forever, retail, Classic Era), **version** and other
  addons if given. A pasted `/cine log` has them all.
- Name the session: `mcp__ccd_session_mgmt__set_session_title`,
  `session_id: "self"`, `Feature: <the wish in a few words>` (under ~50
  characters, no player names). Load it with ToolSearch if it's deferred; if
  the user declines, go on.

### 2. Is it asked before?

Check `Tools/features/requests.md` (the ledger, one line per wish). Already
there: add this ask to its line (date, where from, client) and use what it
already says. More asks = a stronger case; say the count in the report.

### 3. Does Cinematic already do it?

- Settings that might cover it, with exact ids:

  ```
  python -I .claude/skills/support/find_ids.py <words> [--client forever|retail] [--version <theirs>] [--hidden]
  ```

  Try a few word sets (the player's words and ours). Read the code behind a
  hit to make sure it really does what they ask, on their client.
- A CQL rule or a Show in row may already express it (Rules, "Show in"
  columns, Turn off in stays, Keep up columns). Check before planning a new
  switch.
- Already added since their version:

  ```
  python -I .claude/skills/support/fixed_in.py --since <their version> --grep <word>
  ```

- **Parked or removed before?** grep the memory folder
  (`C:\Users\casal\.claude\projects\C--dev-Cinematic\memory\`) and the plans
  (`Tools/*-plan.md`) for the area. Parked = say what stopped it and whether
  that has changed. Removed by the user (right-click skinning, the menu wheel
  Friends slot...) = say so and why; don't re-plan it unless the user asks.

Already there = skip to the report with the `/cine find` ids.

### 4. Can an addon do it?

Before any plan, check what the game allows:

```
python -I .claude/skills/test/known.py <calls> <frames> <words> ...
```

(engine rules in Tools/engine/rules, past test logs, memory.) Then the usual
walls: secret values in fights, protected frames and anchors in combat,
forbidden plates, blocked calls, Forever vs retail APIs (the quirk hubs in
memory). For game frames, read Blizzard's own code first
(`python -I .claude/skills/test/gamesource.py ...`).

Put it in one of these, and say which:

- **(a) Already there**: the ids (step 3).
- **(b) Can do**, on both clients or only one (say which; the other client's
  control is hidden, not greyed).
- **(c) Can do part of it**: what part, and what the game blocks.
- **(d) Can't**: the game limit, plainly, and any close alternative.
- **(e) Don't know yet**: what's unknown, and the ONE probe run (the /test
  skill) that would settle it.
- **(f) Doesn't fit**: clashes with Cinematic's mission ("bringing Azeroth to
  life"), a removed design, or something another addon does better. The user
  decides; say why it might not fit.

### 5. Plan (for b, c, e)

Short and concrete:

- **Where it goes**: which page / tab / row. Don't decide: offer the spot
  that fits the switch tree best and **ask** (a new control = the user picks
  where). Page off = every setting on it off; parent off greys its children.
- **What it touches**: the files (area folders, ns.DEFAULTS in Core.lua,
  Migrations.lua if an old setting changes, Frames.lua rows, Support/ files),
  and anything it could change for players who don't turn it on (default off
  unless the user says otherwise).
- **Clients**: what each one gets; `ns.isRetail` gates.
- **Other addons**: code for one only runs with `ns.AddonUp`.
- **Risks**: taint, combat locks, secrets, performance (anything per frame or
  per plate), the 200-local / 60-upvalue caps in big files.
- **Test**: the offline check that proves it (Tools/offline) and the ONE
  self-running `/cine debug` test (test kit, `ns.TestKit.Define`) with at most
  one real action from the user. Extend a kit test before making a new one.
- **Size**: small (an hour), medium (a session), big (needs a plan file in
  `Tools/<name>-plan.md` first).

### 6. Ledger

Add or update its line in `Tools/features/requests.md`:

```
| <date> | <wish, one line> | <from: issue #/Discord/comment, client> | <a-f> | <status: open / planned / built vX / no: why> |
```

## Report to the user (end of phase 1)

1. **Questions first** (cut-off text, two meanings, where it goes).
2. **Findings**: the category (a-f), what already exists (ids), what the game
   allows (with the rule or test that says so, or "untested"), how many times
   it's been asked.
3. **The plan** (step 5), short.
4. **The draft reply**: one plain ```text block, commands on their own lines,
   also saved as `<short-slug>-reply.md` in the repo root. Voice:
   - short and simple, American spelling, no colons in the text
   - already there: `/cine find <id>` and one line on what it does
   - planned: "good idea, I'll look into it" and hedge, never promise a
     version until it's built
   - can't: what the game doesn't let addons do, plainly, and any close
     alternative; thank them anyway
   - end with something like "Thanks for the idea!"
5. **Stop.** Offer the next step (build it here, a probe run first, park it).

## Phase 2: on the user's OK

- Build it in the plan's spot, with the test in the same change (offline
  check + the kit test). luacheck, the offline checks, the whats-new skill
  before any commit (new feature = likely a What's new entry). No locale edits
  till release.
- **Every build ends with the in-game test handed over**, never "done" without
  it: the offline check's PASS lines, then `/reload` and the ONE
  `/cine debug <name>` command, each in its own code block (the /test
  skill's rules: self-running, at most one real action). When the user says
  "check log", read it (`read_log.py <key>`), fix and rerun until it passes.
- Update the ledger line (built, the version it will be in) and the draft
  reply ("in the next update (vX.Y.Z)", flagged as a forecast).
- Never post the reply, never close or label a GitHub issue, never write
  "Fixes #N": the user answers the player.
