# Smart rows: any plate within X yards

Status: BUILT 2026-11-25 (steps 1-4), untested in game: queue q88d3
(/cine debug platerange). Choices made: X 5-45, a tie takes the nearer
ring, the dropdown lists Within... / Past... only (old 11/28/40 rows show
as those with their yards and keep their own measuring). Items dropped
(never answer on Forever plates). Retail not probed yet. Near aggro range stays as it is
(parked until we tune it); at the end it switches to the new measuring code.

## Goal

On Nameplate Style > Smart, any row (Units, Target, Aggro, Not your kill...)
can be limited to plates **within X yards** or **past X yards**, X picked by
the player, instead of only today's fixed 11 / 28 / 40.

## Where things stand (re-read 2026-11-25)

- A row's Distance is part of its id: `allPast40`, `npcEnemyIn282` (Core
  `ns.MARK_DISTANCES`, `MarkRowSplit`). Fixed list: In11, In28, In40, Past28,
  Past40, OutOfRange, NearAggro.
- `FittingRow` (PlateParts.lua) asks `ns.UnitInBand(unit, distance)` per plate.
  `DistanceRowsOn()` re-runs every plate twice a second (no event for moving).
- `ns.UnitInBand` (Frames.lua): 11/28 = `CheckInteractDistance` 2 / 4, 40 = a
  40-yard spell on your bars, OutOfRange = every attack on your bars (longest
  range first, f0b5fbb), NearAggro = `ns.UnitNearAggro` (own ring picking).
- The row drawer (Options.lua `DistanceChoices`, `RetypeRow`) already moves a
  row's look, When, roles and name to a new id when its Distance changes.
- Tested engine rules:
  - Forever: `CheckInteractDistance(unit, 4)` ~28 yd out of fights; index 3 on
    `target` plain in fights (nameplate tokens in fights: untested).
  - Retail: `CheckInteractDistance` in fights = ADDON_ACTION_BLOCKED, never ask.
  - `C_Spell.IsSpellInRange` for a ranged spell: plain in fights (retail).
  - Forever: item/spell range "unreliable" (2026-10-23, no detail),
    `UnitDistanceSquared` nil outside the group.
- Nothing measures real yards. Only yes/no "rings": interact distances, spell
  ranges, maybe item ranges. **X can only be as fine as the rings a character
  has.** The page has to say which ring it uses.

## Design

### 1. Row ids (Core.lua)

New Distance tokens carry the yards, ended by `y` so a copy number still
reads: `In20y`, `Past18y` -> `npcEnemyIn20y`, `allPast35y2`.

- `MarkRowSplit` reads `^In(%d+)y` / `^Past(%d+)y` before the fixed list;
  returns distance `"In20y"` plus yards as a 5th value.
- Old ids (In11, In28, In40, Past28, Past40) keep working as they are: same
  meaning, shown as "Within 28 yards". **No migration**, so saved profiles,
  built-in recipes (ProfileModules `allPast40`...) and shared CINE1 strings are
  untouched. Changing an old row's yards retypes it to a `y` id (RetypeRow).
- X limits: 5 to 45 yards, whole yards.

### 2. Measuring (Frames.lua): `ns.UnitWithinYards(unit, yards)`

Returns `within` (true/false/nil), the ring's yards, and what measured it.

- **Rings** on this character, rebuilt every few seconds (as
  `LookForRangeSpells` is now):
  - interact distances, as many indexes as the probe (step 0) shows read on
    plates: out of fights everywhere; in fights Forever only, if the probe
    says nameplate tokens read plain there;
  - spell ranges: attacks for enemies, helpful spells for friends. From the
    spellbook, not just the bars, for more rings (a spell has to be known,
    not on a bar). Each spell's longest range (Charge's 8-25 counts as 25).
  - item ranges: only if the probe finds `C_Item.IsItemInRange` plain on
    Forever and allowed on retail. Our own item list, measured by our probe
    (no other addon's data).
- **Which ring:** the one nearest X. On a tie, the closer one (fits fewer
  plates rather than more). Kept per X until the rings change.
- **Per pass cache:** one answer per (unit, ring) per 0.5 s pass, cleared in
  `RefreshMarks`. Ten rows at 20 yd on 40 plates = 40 calls, not 400.
- `UnitInBand` gains In/Past `y` ids. The old fixed bands go through the same
  function (In28 = 28) so there's one measuring path.
- Near aggro range then calls `ns.UnitWithinYards(unit, radius + warn)` and
  its own ring code goes.

### 3. The drawer (Options.lua)

- Distance dropdown: Any distance, **Within...**, **Past...**, Out of range,
  Near aggro range. (The fixed 11/28/40 entries go from the list; old rows
  show as Within/Past with their yards.)
- Picking Within or Past shows a **yards box** (number stepper, 5-45) after
  the dropdown. The row retypes on Enter / release, not on every step.
- Under it, one short line: **"Measured at 25 yd: Lightning Bolt"**, and in
  fights if it differs: "In fights: 30 yd". Nothing on this character that
  far: "Nothing reaches 45 yd here: uses 40 yd".
- Row label sub line: "in 20 yd" / "past 20 yd". Tooltip: one sentence
  ("Just units about that far from you.").

### 4. Debug and tests

- **Step 0 probe**, a kit test (ns.TestKit.Define, test queue), both clients:
  `/cine debug ringprobe`. One action: stand with a few mobs and friendly
  NPCs around (no walking). It asks every interact index, spells in the
  spellbook and a candidate item list on every plate, out of and in a fight
  (it says "pull something" once), and logs: plain / secret / nil / blocked
  per call kind, and whether answers nest (in a 20-yd ring => in the 28).
  Findings go into Tools/engine/rules.
- **Ring yards**: reuse Dev/AggroTest.lua's walk-in trick (your position is
  readable; walking straight at a still mob, each ring's flip spot gives its
  yards against a spell with a known range). Only needed for the interact
  indexes and items whose yards aren't documented.
- **Offline** (Tools/offline/platedistance.lua): id parsing (old ids, `y`
  ids, copy numbers: `npcEnemyIn282`, `npcEnemyIn28y2`), ring choice table
  (X vs rings -> picked ring, ties), the drawer's labels and Retype of an
  old row, profile recipes unchanged.
- **In game**, `/cine debug platerange` (kit test): a Within 20 row and a
  Past 20 row on, stand near mobs; logs per plate which row fit and the
  ring answers, checks no plate fits both, and times a 40-plate pass
  (budget: under 0.1 ms per pass on top of today's).
- `/cine debug range` gains the ring list and which ring each X picks.

### 5. Order of work

1. Probe (step 0), both clients; write engine rules. **Decides** whether
   items and in-fight interact checks are in.
2. Core ids + offline parsing test.
3. `ns.UnitWithinYards` + cache + `UnitInBand` on it; offline ring test.
4. Drawer: dropdown, yards box, "measured at" line; menu test in every
   state (loaded, tabbed) with a shot.
5. In-game `platerange` kit test; perf check.
6. Near aggro onto `UnitWithinYards`.
7. Guidebook (docs/guides/nameplates.html Distance table), What's new.
   No translations till release.

## Open questions

1. X limits: 5-45 OK, or narrower (5-40, where nearly every class has rings)?
2. Ties: closer ring (fewer plates) or further (more plates)?
3. Keep the old fixed 11/28/40 entries in the dropdown too, or only
   Within.../Past... with old rows read as those?
