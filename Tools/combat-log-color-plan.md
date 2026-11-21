# Whose hit, by the combat log's line colors: plan (2026-11-21)

For the Style hub's Combat Text Style (our numbers over nameplates). Today a hit is "yours" when a
COMBAT_LOG_MESSAGE line comes within HOLD of it, one line per hit (Style/CombatTextStyle.lua, "Whose
hit"). The line's text is protected (`|Ky16|k`), but its color (values 2-4) is plain. Today the color
is ignored. That's why the page says "You may see other people's damage as your own".

## What we know
- **The color comes from the Combat Log window's current filter.** Its settings live in
  `Blizzard_CombatLog_Filters` (the Blizzard_CombatLog addon's saved variables): `currentFilter` (an
  index) and `filters[i]`, each with `colors.eventColoring` (event name -> r, g, b),
  `colors.unitColoring` (unit flags -> color), `colors.schoolColoring`, and `settings.lineColoring` /
  `lineColorPriority` (which of those wins), `sourceFlags` (17681 = you, 12561 = your pet) and
  `eventList`. Read from the user's saved file, 2026-11-21.
- **Under Blizzard's default "My actions" filter every line has one color:** the warlock recording
  (2026-11-19, Cinematic.lua `combatTextLog`) had 16 of 17 lines at 179/179/179 (unitColoring 0.7 for
  "mine"), Shadow and Fire alike. So the default filter tells nothing apart, and pets have no lines
  (its sourceFlags: only 17681).
- **MSBT Forever writes its own filter** ("MSBT combat") into that table at logout, makes it current,
  adds your pet (12561), gives every event its own color (`eventColoring`, `lineColorPriority` 3), and
  asks for a reload. It writes only at logout: writing during play taints Blizzard's combat log. The
  user has it now (currentFilter = 3, "MSBT combat"). So the lines our page counts today include your
  pet's (untested how that shifts our counting).
- BattleText Forever uses the lines' timing only, never their colors.

## The idea
A line's color says what kind of line it is, as long as the current filter colors kinds apart. Then a
line only pairs with a hit of the same kind:

| Line kind | Pairs with |
|---|---|
| swing (SWING_DAMAGE) | a physical swing on your target (PLAYER_SWING tells your own swings) |
| spell (SPELL_DAMAGE) | a non-periodic hit |
| tick (SPELL_PERIODIC_DAMAGE) | a tick |
| miss (*_MISSED_*) | a MISS / DODGE / PARRY... action |
| heal (SPELL_HEAL, PERIODIC) | a heal |
| pet's (pet source) | your pet's hit |

A teammate's hit in the same instant then can't take your line unless it's the same kind, and your
pet's hits finally get numbers of their own (the forever-pet-hits finding).

## Plan, in steps

### 0. Probe (one fight, one command): `/cine debug linecolors`
- Reads `Blizzard_CombatLog_Filters` live: is it a plain table in game (not secret)? The current filter's
  name, sourceFlags, lineColoring, lineColorPriority and how many eventColoring entries it has.
- Records every line (time, color) and every hit (plate, target, player, pet, swing, school, flag,
  action) for one fight, and pairs them by time the way the page does.
- Its verdicts: how many colors came, which hit kinds each color sat next to (a color always next to
  one kind = usable), pet lines yes/no, and whether the colors match what the filter's settings say.
- One thing to do: "kill one mob". Your filter left as it is (MSBT's now). If you want the default's
  numbers too, rerun it after picking "My actions" in the Combat Log tab (that's the game's own setting).

### 1. Read the colors (no writing at all)
- Each line's kind from its color, by **learning**: a color seen with one kind only, several times
  (solo, one hit per instant), is that kind. Kept per filter name (`db.combatTextLineKinds`), learned
  again if the filter changes. No guessing Blizzard's color rules.
- Pairing then needs the same kind; a color not learned yet pairs as today.
- One color only (the default filter): exactly as today. Nothing gets worse.
- Pet's lines (a learned pet color): your pet's hits drawn as your pet's (Your pet's row).
- Offline test: replay recorded fights (the probe's log) through the pairing, with and without kinds:
  fewer of others' hits taken as yours, none of yours lost.

### 2. Only if step 1 isn't enough: a filter that tells kinds apart (needs your OK)
- Like MSBT, written at logout only: but subtle shades (each kind a hair off the default grey), so the
  Combat Log window still looks the same.
- It changes a game setting (the Combat Log's filter), so it's an opt-in checkbox with a reload, not
  automatic. If MSBT's filter is current, we use it as it is and write nothing.

### 3. Tell the player
- The Experimental notice stays until the in-game check shows it's gone; then a short note: "Tells
  your hits apart better with a combat log filter that colors kinds (MSBT's, or ours)".

## Risks
- Kinds can still collide: your Fireball and a teammate's in the same instant are both "spell".
- A player recoloring their filter mid-session: learned again (kept per filter name, reset on change).
- Retail: no lines come (combat text rules); this is Forever only.

## Probe run 1 (2026-11-21, Forever, warlock 11 with imp, MSBT combat filter current, one mob)
- The filter table is a **plain table in game**: readable live, no saved file needed.
- **12 of 12 line colors were the filter's own event colors**: SPELL_DAMAGE 255/204/77 (7 lines),
  SPELL_PERIODIC_DAMAGE 204/153/255 (4: Corruption and Immolate ticks), PARTY_KILL 255/255/255 (1, the
  killing blow's line). Each color came with one kind only. 10 of 10 hits had a line.
- **The kill line is not a hit**, yet today's pairing counts it as one: it can take a hit (a
  teammate's) as yours. With colors it's dropped.
- **Ticks are told from direct hits by color**, which UNIT_COMBAT can't do.
- **Your pet's lines look like yours** under MSBT's filter (event colors win, unit coloring off): the
  imp's Firebolts came as SPELL_DAMAGE like yours. Pet apart needs a filter that tints by unit (step 2).
- No swings (a caster): swing/miss colors untested in game.

### Step 1, revised
Decode a line's color from the current filter live (color -> its events), no learning needed. Only
damage/heal/miss lines pair with hits; kill, cast, aura and other lines are skipped. A tick line pairs
only with a tick-looking hit and marks it as a tick (for its look). Default filter (one grey): as today.
