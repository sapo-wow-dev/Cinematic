# Addon baseline kit: plan (2026-11-25)

Status: steps 1 and 2 built 2026-11-25 (Tools/addon-kit/README.md); steps 3-8 plan.

Step 1 as built, where it differs from the plan below:
- **No `ns.Touch` declarations in the code.** Touches are found
  automatically instead: a static scan of our code plus the sweep run in
  touch mode. The results are saved in a generated registry,
  `touchpoints.txt`. Declarations in about 150 files would have collided
  with parallel sessions, and the scan finds what declarations would have
  claimed.
- **No `no-frame.txt`.** ns.DEFAULTS has about 8000 keys, nearly all our
  own frames' looks, so a list of every key that touches nothing couldn't
  be kept up. The gate is now "a setting newly reaching a touch point
  FAILs", which flags a new feature on a game frame.
- The miss corpus holds 5 cases: DaylightUI chat twice, Discovered line,
  party flicker and card wait, plus Questie item buttons. EllesmereUI chat
  (0bd9803) can't be proven by today's test, so it's left out.

## Why addon support keeps missing things

Case: Show just those messages (chatPeekLinesOnly) with DaylightUI's chat
drew a second copy of each new line (fixed in 2979131, after a player hit it).
Nothing in the addon-support flow could have caught it:

1. **It only thinks in the addon's frames.** scan_addon.py and the skill ask
   "which frames does the addon make, and which row fades each?". They never ask
   "which of OUR features draw on, copy, read or hook a game frame this addon
   replaced or hid?". DaylightUI replaces ChatFrame1; the scan's section 3 saw
   that, but section 3 only maps to fade rows, not to features.
2. **`addontest` only hides and shows rows by key.** It never switches a
   feature on, never walks a rule word, never fights an addon's own logic.
3. **Our feature tests run on stand-ins.** ChatLinesTest builds a test chat
   window of its own, so an addon replacing the real one is invisible to it.
   Same pattern elsewhere (preview frames, stand-in trackers).
4. **No list of what we touch.** There's no registry of the game frames and
   globals Cinematic hooks, reads, reskins or copies, so nothing can enumerate
   "every possible frame we touch" against an addon.
5. **No baseline.** Nothing says how each feature behaves with no other addon,
   so "different with addon X" can't be seen; each run is judged by hand.

## The kit

One run per addon, hands off after at most one real action, compared with a
saved no-addons baseline. Every difference is either declared in the Support
file or a FAIL.

### Part A: touch-point registry (the list that can't go stale)

- `Tools/addon-kit/touchpoints.py` scans OUR code for every game frame / global
  we touch: `hooksecurefunc(X, ...)`, `HookScript` on named game frames,
  `_G[...]`/bare game frame names we SetAlpha/SetPoint/SetParent/reskin/copy,
  every `ns.COMBAT_SHOW` row's names, Style looks' targets, Chat/Quest/Minimap/
  Tooltip/Bubble/Plate/UnitFrame code. ~49 hooksecurefunc sites + 127 rows today.
- Output: `Tools/addon-kit/touchpoints.txt`: each touch point -> the files and
  settings keys (features) that use it, e.g.
  `ChatFrame1 -> chatPeek, chatPeekLinesOnly, Chat Cam, Chat row, ChatLinesTest`.
- Each touch point needs a probe (Part B). A touch point in code with no entry,
  or an entry with no probe = FAIL in `prerelease.py`. That's what keeps
  "every frame we touch" true as code grows.

### Part B: feature probes (on the REAL frame, not a stand-in)

- One probe per (touch point, feature): set the feature's state, act, read the
  result, put it back. Registered on `ns.TestKit.Define` under
  `Dev/AddonKit/<Area>.lua` (Chat, QuestTracker, Minimap, Tooltip, Bubbles,
  UnitFrames, ActionBars, Plates, Cards/Zone text, CDM, Camera CVars).
- A probe reads the frame the player actually sees: it finds the visible
  replacement (the addon's chat window if ChatFrame1 is hidden/zero-alpha/off
  screen) and records what it found. E.g. chatPeekLinesOnly: send a test line
  through the real message path, count copies drawn on screen, record where
  each sits and which window came up.
- **Reuse first**: ChatLinesTest, ChatDefaultTest, the Quest tracker / Questie /
  RestedXP / EllesmereUI tests and `/cine debug sweep` become probes (a "real
  frame" mode added beside their stand-in mode), not rewritten.
- Each probe returns a small record (counts, alphas, anchors, errors,
  BLOCKED lines), not a pass/fail: pass/fail comes from the baseline diff.

### Part C: rule walk (every advanced logic rule, per row)

For every row an addon's frames sit on (its Addons page rows + the game rows
it stands in for) and every game row we fade:

- Force the facts (a test override on `ns.RuleFacts` / `ns.RuleFactsNow`, no
  fights needed) and walk every word group in `ns.RULE_WORDS`: combat/calm,
  target kinds, interacting/npc, hover words, mounted/flying, instance kinds,
  cameras, weather... Per word: rule `<word>` with it true -> frame up, false ->
  down; `not <word>` the reverse.
- Plus the non-CQL logic: In / After / Out of combat ticks, Keep up columns,
  Calm Timer, hover (HOVER_BY_RECT), Show in / Turn off in stays, switch tree
  parent off, page switch off, tab container off, CineMode on/off.
- Per step: target alpha reached, held for N frames (an addon fighting our
  fade), mouse state, back after. Offline first (Tools/offline matrix, fake
  frames) for the decision logic; in game only proves the addon doesn't fight.

### Part D: baseline + diff

- `/cine debug addonkit baseline`: `solo` with NO other addon, run A+B+C on
  each client, saved to `Tools/addon-kit/baseline-<client>.json` (read off
  the log by `read_log.py`).
- `/cine debug addonkit <Addon>`: `solo <Addon>`, same run (all probes, not
  just the ones the scan predicts: the miss was a feature nobody predicted),
  plus the existing addontest coverage check (NOT COVERED frames).
- `python -I Tools/addon-kit/diff.py <Addon> <client>`: each probe vs baseline.
  A difference is OK only if `Support/<Addon>.lua` declares it
  (`ns.AddonKitExpect("chatPeekLinesOnly", "hidden: DaylightUI's window comes up instead")`);
  otherwise FAIL with the probe's record side by side. Same shape as the audit
  kit's old-vs-new matrix, and a changed baseline needs the user's OK line.

### Part E: scan + skill tie-in

- scan_addon.py section 3 gains "3b: our features on these frames": for each
  game frame the addon replaces/hides/reskins, the touch-point entries and
  probes at risk. That line would have said
  `ChatFrame1 replaced -> chatPeekLinesOnly at risk`.
- SKILL.md: Phase 1 report lists 3b with a decision per feature; Phase 3 runs
  `addonkit` (replaces the plain addontest call); done = diff clean.

### Part F: all supported addons

- `Tools/addon-kit/backfill.md`: the 38 Support files, run worst-first: whole-UI
  suites (ElvUI, EllesmereUI, DaylightUI, FlareUI, NaowhForever, ClassicUIForever),
  chat (Glass, Prat), quest (Questie*, RestedXP), plates (Plater, Platynator,
  ThreatPlates), then the rest.
- Queued through the test queue: one Run all walks solo A -> kit -> solo B...
  Reloads on Forever need the cineReload popup click (reload is blocked from
  code there), so one click per addon; retail can chain.
- After every addon update (addon-check.py baseline note) its kit runs again.

### Part G: future proof

The kit has to stay right as Cinematic, the addons and the game change, without
anyone remembering to update it. Rule: **nothing is hand-listed that code can
enumerate, and anything new without a test fails the prerelease check.**

What changes, and what catches it:

| Change | Caught by |
|---|---|
| New feature touches a game frame | The feature declares it in its own code (`ns.Touch("ChatFrame1", "chatPeekLinesOnly")`, a no-op in the player copy), so the claim moves with the code. touchpoints.py also scans for undeclared hooks, SetAlpha and copies: either one with no probe = FAIL. |
| New setting in `ns.DEFAULTS` | It must be listed as touching a frame (with a probe) or in `Tools/addon-kit/no-frame.txt` with a reason. A setting in neither = FAIL. |
| New rule word, row, tick column or switch | The rule walk reads `ns.RULE_WORDS`, `ns.COMBAT_SHOW`, the keep-up columns and the switch tree at run time, so nothing is hard-coded. A word with no way to force its fact = FAIL. |
| Addon update | addon-check.py (already in prerelease) sees the new version, so that addon's kit result is marked stale and goes back in the queue. Baselines and results are saved per addon version. |
| Game patch | Baselines are saved per client build. A new build = baseline stale, rerun first, and the client changes go into engine rules. |
| A feature we changed on purpose | The diff says the baseline is older than the feature's last commit. Rerun the baseline; a changed record needs the user's OK line, as in the audit kit. |
| A new addon nobody supports yet | Probes never name an addon. They find whatever is drawn where the game frame was, so `addonkit <any addon>` works with no Support file. That gives /support and /addon-support a ready answer. |
| The kit itself rots | The records carry a format version, so old baselines are refused rather than half-read. A replay corpus (`Tools/addon-kit/misses/`) keeps every addon bug that got past us as an offline case (DaylightUI chat first). The kit must fail on each one with its fix taken out. A new miss adds a case and the kind of check that would have caught it, the same way known-errors works. |

Gates: prerelease runs touchpoints.py, the no-frame list, the rule-walk
enumeration, the stale-result check and the miss corpus. /addon-support can't
finish an addon without a clean diff on its current version.

## Build order

1. A: `ns.Touch` declarations, touchpoints.py, touchpoints.txt, no-frame.txt
   and the prerelease gate (offline, no game). The format version and the
   miss corpus (DaylightUI chat case) land here too, so every later part is
   built future-proof from the start.
2. C offline: rule walk on the offline loader for every row (catches logic
   bugs with no game at all).
3. D: baseline format, diff.py, `ns.AddonKitExpect`.
4. B: probes, Chat first (the miss), then Quest tracker, Minimap, Tooltip,
   Bubbles, Unit frames, Bars, Plates, the rest. Each area: real-frame mode,
   offline kit where one exists, then one game run.
5. C in game + `addonkit` command (wraps addontest).
6. Baseline runs on both clients.
7. E: scan 3b + SKILL.md.
8. F: backfill, DaylightUI first (prove the kit catches the known miss on the
   pre-2979131 code via the audit matrix, offline), then worst-first.

Proof the kit works: with 2979131's DaylightUI fix taken out (offline audit
matrix on the old code, never a stash), the DaylightUI run must FAIL on
chatPeekLinesOnly. If it doesn't, the kit isn't done.

## Open questions

- Run every probe for every addon (slow, catches the unpredicted) or only the
  touch points the scan flags (fast)? Plan says every probe.
- Where `addonkit` sits in the Test queue / Addons page (a button, per the
  "buttons not commands" rule).
