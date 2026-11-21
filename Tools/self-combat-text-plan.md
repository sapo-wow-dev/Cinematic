# Combat text on you, for the Shoulder Cam: plan (2026-11-20)

## Goal
The game's floating combat text about you (Options > Combat > "Scrolling Combat
Text for Self": "-26", "+120", "Dodge", "<Combo Points>", "+Overpower") should:
1. sit beside you on screen when the camera is over your shoulder, not in the middle where you aren't, and
2. be styled like our nameplate numbers are (Combat Text Style): font, edge, size, color per kind, motion.

## What we know (tested)
- The game's texts (Blizzard_CombatText, 20 FontStrings on `CombatText`, re-placed every frame,
  anchored on WorldFrame) have a **secret text and a secret place on Forever, even out of a fight**
  (`/cine debug cttest`, 2026-11-18).
- The only way to move one was `AdjustPointsOffset`, and that taints its place: the game then
  errors comparing it (`CombatText.lua:364 lowestMessage`, Forever dungeon 2026-11-19). Since then
  ShoulderCam.lua skips every secret place, so **the Follow HUD's "Floating combat text" row moves
  nothing on Forever today.** Moving the game's own text is a dead end.
- `UNIT_COMBAT` on you: action, flag, school plain; amount secret, and `SetText` of it works
  (proved on plates by Combat Text Style).

## What the probe finds out (`/cine debug selftext`, Dev/SelfTextProbe.lua)
One self-running run, 6 steps, each "take hits or heal yourself" (moves on after 4, no time limit),
screenshots, errors counted per step, verdicts in `CinematicDB.selfTextLog`:

| Step | Question | Decides |
|---|---|---|
| 1 watch | Does `COMBAT_TEXT_UPDATE` + `C_CombatText.GetCurrentEventInfo` give plain kinds (COMBO_POINTS, AURA_START, SPELL_ACTIVE, ENTERING_COMBAT...) and readable data? Which `floatingCombatText*` CVars exist? | Which of the "Text on Me" kinds we can draw ourselves |
| 2 color | Recolor the game's own texts (hook `SetTextColor`): works, no errors? | Whether "Game's text, our colors" is a mode at all |
| 3 font | `CombatTextFont:SetFont` bigger + thick edge: works, no errors? | Same, for font and size |
| 4 hide | `CombatText:SetAlpha(0)` hides every message, no errors? | How we hide the game's when ours draws |
| 5 off | With `enableFloatingCombatText 0`, do `COMBAT_TEXT_UPDATE` still come? | Hide by CVar (cleaner) or by alpha (keeps the events) |
| 6 ours | Our own text beside you: secret amount via `SetText`, kind names from step 1 | The approach below, end to end |

Offline check: `python -I Tools/offline/selftext.lua` via run.py (35 checks: steps, put-backs, stop mid-run).

### Run 1 (Forever 16001, 2026-11-20, a Defias Bandit in melee)
- COMBAT_TEXT_UPDATE: the **kind is plain** (DAMAGE, SPELL_MISS, ENERGIZE seen); every value of
  GetCurrentEventInfo is **secret** (DAMAGE: 1 secret; ENERGIZE: 2 secret; SPELL_MISS: none).
- `COMBAT_TEXT_TYPE_INFO` / `COMBAT_TEXT_FLOAT_MODE` aren't globals on Forever; the settings are
  `floatingCombatText*_v2` (Float mode: `floatingCombatTextFloatMode_v2`).
- Showing texts: text, font and scale secret; **color and alpha plain** (DAMAGE 1, 0.1, 0.1).
- color: PASS, the game's text recolored pink, no errors.
- font: FAILED, the text vanished (CombatTextFont gave size 127291 with FILTER, FIXEDHEIGHT;
  x1.6 of that). Putting it back with only three values left the game's numbers spaced out until
  /reload: now put back with every value it gave. Restyling the game's font is out.
- hide (alpha 0): PASS. off (`enableFloatingCombatText 0`): PASS, gone and COMBAT_TEXT_UPDATE still
  comes, so ours can hide the game's with its own setting.
- ours: PASS, pink numbers beside you from the secret amount.
- Other addons already do this on Forever (EllesmereUI QoL Self Combat Text, DaylightUI combat
  text feed): an Addon Support / Conflicts row is needed so two don't draw at once.

### Every kind: `/cine debug selftextall` (Dev/SelfTextCatalog.lua)
Records while you play, no end but the command typed again: every "Text on Me" setting on for the
run, each kind's info shape, the hit with it, the color the game drew it in, a screenshot of each
kind's first, messages with no event (Low Health/Mana), kinds not on the list (NEW). Kept across
runs in `CinematicDB.selfTextCatalog`, so more classes add up. 51 kinds listed in 12 groups.
Offline: Tools/offline/selftextall.lua.

### Catalog run 1 (Forever, druid 25, Skeletal Horrors, 2026-11-20)
10 kinds: DAMAGE (secret number, red 1/0.1/0.1), ENERGIZE (secret number + secret string,
**color secret**), HEAL and PERIODIC_HEAL (secret string = the healer's name, secret number; green
0.1/1/0.1; drawn "+244 [Sapo Druid]"), DODGE (nothing with it), SPELL_AURA_START/END and
_HARMFUL (a secret string: the aura's name), and one "no event" (red: **"Mana Low"**).
- **Combo points come as ENERGIZE**, not COMBO_POINTS ("<2 Combo Points>" on screen), with the
  power type secret: ours tells them apart by UNIT_POWER_UPDATE's power type in the same instant
  (the catalog now logs it as "with power ...").
- Low Health / Low Mana: no event, same red as damage: told apart by UNIT_HEALTH /
  UNIT_POWER_UPDATE in that instant (logged as "with").
- No ENTERING/LEAVING_COMBAT event though its setting was on and a fight ended: "+Combat/-Combat"
  may also be event-less (now logged "with fight start/end").
- Auras and Dodge fired but no color was caught: the catalog now spots drawing by SetText, so a
  kind the game doesn't draw says "drawn NO".
- The run was ended by a /reload, not the command: no summary, and the 12 Text on Me settings
  stayed on. Now: a /reload or logout ends it cleanly (summary, put back), what a run changes is
  saved so a crash is put back at the next login, and this first run's 12 go back to 0 at the
  next login (all were 0 in the first probe's survey).

### Mirror run (Forever, 2026-11-20, `/cine debug selftext mirror`)
PASS: the game's frame hidden (alpha 0), its messages copied into ours right of the middle,
in its own colors (green "+130" heal crit, red "-6"). Both ways copy the secret words: the text as
the game set it, and read back with GetText. 3 of 4 copied: the 4th neither counted nor logged an
error, most likely an error inside the game's call; the copy is now wrapped and logged per copy.
Rerun (same day): the missing copy was ours, not the copying: the first copy made our text frame,
and `ns.SetOnUpdate` names its loop from `debugstack`, which comes back **secret inside a hook on
the game's text** ("attempt to index local 'stack' (a secret string value)", Diagnostics.lua
LoopLabel). Fixed there (a secret stack names it "?"; offline: Tools/offline/looplabel.lua).
Every other copy: ok, both ways. A MISS on you drew nothing: the game's Dodge/Parry/Miss tick was
off, so mirroring follows the game's Text on Me ticks.
Ours drew every copy in one spot (a damage over a heal): the real one needs lanes.
**So the approach is mirroring:** the game decides what shows and its words (every kind, Low
Mana, ones with no event, new ones), we decide look, place and motion; the event of the same
instant gives the kind for per-kind looks.

## Approach (recommended): Cinematic draws the text on you
Same model as Combat Text Style on plates: a row per kind says who draws it,
**Cinematic / Game's / None**. Ours draws, the game's is hidden (step 4 or 5 decides how).

- **Where:** your spot on screen. Across = the Shoulder Cam's own slide (`followShift`, the same
  number the Follow HUD frames use), so it lands on you at every zoom; up/down = a Height slider.
  Camera behind you (Shoulder Cam paused, a cut scene): the middle, as the game's.
- **Side:** Over you / Your free side (away from the screen's middle, where there's room) / Split
  (taken on one side, gained on the other).
- **Motion:** Scroll up, Scroll down, Arc (the game's three), plus Pop (crits grow, as on plates).
- **Kinds,** one row each with an on switch and a color (the CombatTexts tree, a "You" root):
  Damage taken (swings, spells by school), Heals on you (+ healer names), Misses (Dodge, Parry,
  Miss, Block, Resist, Absorb, Immune), Damage reduction, Shields, Energy gains, Periodic energy,
  Combo points, Low health & mana, Spell alerts (procs), Auras gained/lost, Enter/leave combat,
  Reputation, Honor.
- **Look per kind:** font, edge, size, color, crit size: the same parts and "its group's until
  changed" rule as the plate texts, so the editor and the presets are shared.
- **Game ticks:** we don't mirror the game's "Text on Me" ticks ([[no-mirror-blizzard-settings]]).
  If step 1/5 shows a kind only comes while its game tick is on, its row says so ("Turned off in the
  game's options") instead of a dead switch.

### Fallback if step 6 fails: restyle the game's own text
Only if steps 2-3 pass with no errors: colors and font of the game's text, no placement. The
Follow HUD row stays dead on Forever. Much less than asked, so only as a stopgap.

## Where it lives (decided 2026-11-20, user)
A **new Style hub page right after Combat Text**, in Interface > Combat:
HUBS entry in Options.lua after "Combat Text Style":
`{ "Self Text Style", <icon>, label = "Text on You", section = "Interface", sub = "Combat" }`
(name to confirm). New file `Style/SelfTextStyle.lua` (toc: after CombatTextStyle.lua).

Built like Combat Text Style: Enable Page, a preview (you with text playing; Over your shoulder /
Behind you to flip), then a General tab (Who draws, Side, Motion, Height, Follow the Shoulder Cam)
and a Look tab (the kinds list, each with on switch + color, the picked kind's look under it,
sharing CombatTextPage's editor). Page off = everything on it off ([[page-switch-gates-all]]).

The Shoulder Cam only supplies your spot (`followShift`): with Follow the Shoulder Cam on and the
camera over your shoulder, the text sits by you; otherwise the middle of the screen. The Follow
HUD's "Floating combat text" row goes (it can't work on Forever; migrated: on = this page on with
Follow the Shoulder Cam on).

## Phases
0. **Probe** (built): `/cine debug selftext`, offline check passing.
1. **Drawing** (`Style/SelfTextStyle.lua`): pool, kinds map from UNIT_COMBAT + COMBAT_TEXT_UPDATE,
   motion, placement from the slide; offline test of kinds, placement, hiding/putting back the game's.
2. **Page + preview** (Style hub, after Combat Text); Follow HUD row removed + migration (Migrations.lua,
   migrate-test).
3. **Per-kind look**: the CombatTexts tree's "You" root, shared editor and presets.
4. **Game test**: `/cine debug shouldertext`, one self-running run on Forever, then retail.

## Known limits (tell players)
- The amount is secret: no rounding ("1.2k"), no "hide hits under N", no merging of hits into one
  number, no color by size.
- Retail: same secrets in fights; tested after Forever.

## Built: v1 (2026-11-20, dev copy only)
- `Style/SelfTextStyle.lua`: the mirror engine and the page. HUBS entry "Self Text Style" (label Text on
  You, after Combat Text, `dev = true` till tested in game). Settings `selfText*`.
- Engine: hooks SetText on CombatText's texts, hides its frame (alpha 0, kept at 0, put back on page off,
  Style off or Who draws The game's), copies the secret words into a pool on `CinematicSelfText`, a frame
  later: kind from COMBAT_TEXT_UPDATE in the same instant (before or after the text), combo points by
  UNIT_POWER_UPDATE COMBO_POINTS, no event by health/power (Low) or a fight starting/ending (Combat).
  Color: the game's (read off its text) or the group's own; a group can be Hidden.
- Place: `ns.ShoulderYouShift()` (new in ShoulderCam.lua: the frames' slide without Frames follow you's
  tick or the target turn), eased; Side over / free / split; texts on a side pushed apart as the game's.
  Motion up / down / arc / pop (crits from twice their size, SetTextScale).
- Page: Test button (samples of each kind), General (Who draws, Follow the Shoulder Cam, Side, Motion,
  Height, Time shown), Look (Font, Edge, Size, Crit size), Kinds (12 groups: Game's color / Own + swatch
  / Hidden).
- Tests: `Tools/offline/selftextstyle.lua` (engine + page builds), `/cine debug selftextstyle`
  (Dev/SelfTextStyleTest.lua, 3 self-running steps; offline: `selftextstyletest.lua`).

Not yet: a preview on the page, General/Look tabs, the Follow HUD's Floating combat text row removed
+ migrated, Addon Support rows (EllesmereUI QoL Self Combat Text, DaylightUI feed), /cine find ids,
retail.

## 2026-11-21: from reading BattleText Forever 1.29.0 (MIT) and MSBT Forever 2.0.8 (ideas only, no code)
- Neither copies the game's text; both rebuild from UNIT_COMBAT, COMBAT_LOG_MESSAGE, casts, CHAT_MSG_*.
- Done: a reused text blanked (SetText("")) before its new words (MSBT: a text that held secret words stays
  secret till then); enableFloatingCombatText held on while ours draw (ns.CVarSet "Floating combat text on",
  BattleText turns it off); Addon Conflicts rows "Combat text on you" for BattleText Forever
  (Support/BattleTextForever.lua: Ours hides its Incoming/Healing/Notifications areas) and MSBT
  (Support/MikScrollingBattleText.lua: all its text on one frame, nothing hidden). Offline: selftextstyle.lua 11b-11c.
- Untested: MSBT hides CombatText with :Hide() and per-kind COMBAT_TEXT_TYPE_INFO.show (nil as a global on
  Forever in our survey): whether our SetText copy still gets messages then.
