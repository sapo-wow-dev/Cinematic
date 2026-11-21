# Preview Match plan (2026-11-19)

Goal: every Style preview looks like the frame it stands for, on the client the player is on, and a test proves it
before every release.

## Status (2026-11-20): cast bars done, the rest to go

Done and committed (ee3d51f, b86a5bf, 5c584c6, d17755a2, 289d3821; in v2.1.17 up to 5c584c6):
- Step 0 on both clients (`/cine debug templates`, results below).
- The match test, `/cine debug previewmatch` (Dev/PreviewMatch.lua): runs itself, never opens Settings (on Forever
  that prints the gamepad "Interface action failed" line), builds its own preview bars with the pages' code
  (`ns.MakeCastLookSample`), reads your bar, your target's (target yourself) and a nameplate's (it turns nameplates on
  for those steps, out of fights only; your pet's casts count), compares part by part incl. colors, verdicts, screenshots.
  `python Tools/preview-match/build.py [forever|retail]` makes the side-by-side page.
- Cast bar previews built from the game's templates (PlateCastStyle.lua `MakeSample`, SAMPLE_KINDS). Forever scores:
  63/62/53 before, 100/100/100 after (your bar / target / nameplate).
- Your cast bar has its own tab, Unit Frames > Your Cast Bar (`playerCastStyle`), user's pick.
- The "other kind's game look" pick (GameAs/DressAs): our own copy of name and icon, the game's faded (moving the
  game's failed where their place is secret). Offline: Tools/offline/castlook.lua (42 checks, in prerelease).
- Your bar's preview tinted by Interface Recolor's irCast like the real one (`ns.RecolorLike`).

Known gaps on cast bars:
- The can't-be-interrupted shield stays the game's in the other look (not moved with our copied icon).
- The nameplate preview's icon and name are placed by client (retail under the bar, Forever on it); the game decides
  by the player's nameplate style. Plate anchors read in game would settle it.
- Retail: no match test run yet.

Unit frames (started 2026-11-20): the match test's pairs are built, `/cine debug previewmatch units`
(Dev/PreviewMatchUnits.lua; offline Tools/offline/unitmatch.lua). It reads the player, target, focus and pet frames
and the Unit Frames page's mock-ups by part (frame art, portrait, bars, name, level), placed in health-bar widths,
in the game's look (page off) and yours, and logs the game frame's whole tree of shown art (TREE lines: the recipe
for the copy, B). Baseline, Forever 2026-11-20: player 69, target 68 (art drawn in plain color, bars too thin, no
masks, level not the game's circle).
Fix (B): Style/UnitFrameCopy.lua keeps a recipe per frame (atlases, places, sizes from the frame art's corner),
read off the live frame when it's up in the game's look, saved per client (CinematicDB.unitFrameRecipes), built-in
Forever numbers before that. The preview's game look (player, target, focus) draws from it (UnitStyle.lua
CopyLook): the game's frame art, its masked bar atlases, the level circle, corner piece, reaction strip. Offline
94/84 on the stand-in. In game, Forever: player 97 (69 before; the level's color, now white). Target not read:
targeting yourself makes the target frame's places secret on Forever, so the test now waits for someone else.
Rerun (a mob targeted): player 100, target 100 in all but the unit's own (no mana bar on that mob, its level's
difficulty color), which the test now notes, not counts. The target's mana bar place is still the built-in guess
(no target with mana read yet). Committed a382282d.
Focus and pet (2026-11-20, offline only): the recipe reader is generic now (frame art found as the biggest unit
frame atlas, masks read off each part, the frame's other art kept as "extras", states like rest or combat glow
left out), so the pet is copied once its frame has been seen (no built-in pet recipe), and the focus reads its own
frame. In-game run 14:32: player 97, target 96, the one difference the copy's art tinted by the theme (Neon) with
the page off (fixed: tinted only with the page on); no focus or pet up, so the test now waits for both (skip to go
without). Your style with Neon's petal shape (the drawn theme look): health bar 10:1 vs the game's 6:1, level
missing, name font too big, theme-shapes work.
In-game run 14:47: player, target, focus 100; pet 96 (its power bar: your pet's is mana, the sample's yellow; now
follows your pet's power kind, read with its frame).
Targets of target (2026-11-20, offline only): one recipe, TOT, read off TargetFrameToT (else FocusFrameToT); the
target's and focus's recipes keep where their ToT hangs (part "tot"), and the preview has two ToT mock-ups, TOT
under the target and FOCUSTOT under the focus (both dressed by the Target of target tab), each copy hung off its
frame's copy at the game's size; the preview grew to 232 tall for it. The test waits for both ToTs up (a target
and a focus each targeting someone, out of a fight: other players in a city).
In-game run 14:53: player 97, target 96, focus 96, pet 93, both ToTs 59 (still drawn: the game's ToT names its
parts HealthBar/Name/Portrait in capitals; the copier now reads those). A fight began a second before the read, so
the page-off put-back on the real frames (level badge size, pet name side) was held by the game and read as the
game's. The test now puts the game's look on at its start (out of a fight) and keeps it through the waiting, so
the game's look is read in a fight too (user: pull the focused mob to get both targets of target); your look goes
back on and is read once you're out of the fight, with what's still up.
In-game run 15:31 (in a fight): player 97, target 100, focus 100, pet and both ToTs 67 (drawn). ToTs: never read
(the copier wouldn't read in a fight, and a ToT is mostly up in one): it reads in fights now. Player: the saved
power atlas was Energy (a cat-form read): the copy now draws mana's art for the bar (others a grey of it). Pet:
drawn in the fight with a saved recipe, cause unknown (offline it's the copy): the test now logs each mock-up's
"the copy" or "drawn (why)".
In-game run 15:53 (in a fight), Forever: every mock-up the copy; player, target, focus, pet, target's ToT 100;
focus's ToT 96 (its sample's rage bar vs a mana user: the unit's, now noted, not counted). Unit frames done on
Forever except party and the theme shapes.
Quality control (user's screenshot of the Style General screen, 2026-11-20): an empty frame under yours (the pet
frame, a child of PlayerFrame, read into your frame's extras), the level cut to ".." (boxed to a 1-digit read),
frames on each other and the focus's ToT cut off (copies placed on the drawn samples' spots; every Style screen is
held to ns.StylePreviewHeight()). Fixed: extras never take another unit frame's art (recipes versioned, v2 wipes
the bad ones), level text sized to its words, frames sized against each other by their real scale, a layout pass
(UnitStyle.lua LayoutStage: yours + pet top left, party under, target + ToT top right, focus + ToT under, then
shrunk to the screen). ns.UnitPreviewLayoutCheck (Dev/PreviewMatchUnits.lua): CUT / OVERLAP / TEXT lines, run
offline at 480 and 760 wide and in the in-game test (LAYOUT lines) at the screens' size.
Retail baseline (12.1.5, 2026-11-20): target, pet 100; focus, ToTs 96 (name justify); player 83. No retail recipe
had been read: the player frame's art there was the class resource one (AlternatePowerFrameTexture, Elemental:
Maelstrom bar + a mana bar under it), so the read failed and Forever's built-in numbers stood in. Fixed (offline):
the shown art variant is read, the third bar (power2) read and drawn, parts the game hides are kept hidden (your
level at the top level, the target's level circle on retail), a text whose place is secret (retail's names and bar
texts) is placed by its anchor. The test reads the shown art and power2; a class power's own art is noted, not
counted. Retail run 17:25 (pet summoned in the fight): player, target, focus, pet 100; both ToTs 96: on retail a
name's anchor is secret too (GetPoint gives nothing), so the ToT name had no place at all: now its side and font
are read and the copy sets it on the health bar's top edge on that side.
Retail run 17:28: every pair compared 100 (focus's ToT too). The screenshot showed the Lich King's name on his
level: the in-fight read (side only) had replaced the place measured before. Now a weaker read (anchor or side
only) never replaces a measured place, and the test reads every frame up once at its start, out of a fight, in
the game's look. The focus's level is ~5 px in the preview (true to the game's smaller focus frame, shrunk):
a minimum text size is the user's call.
Retail run 17:36: all 11 pairs 100, layout clean; the screenshot shows the Lich King's level then name on the strip
(retail's built-in places, Style/UnitFrameCopy.lua RETAIL: a name's place is secret on retail even out of a fight).
The target's power bar came out grey: the mob's bar was the game's plain tinted art "-Bar-Mana-Status"; now drawn
as mana's colored art too.
Unit frame parts (2026-11-20, user: "think of all possible unit frame parts"; offline only): Style/UnitFrameParts.lua
(own file: UnitStyle.lua is at Lua's 200 locals) adds to every mock-up a buffs/debuffs row (target, focus, boss;
debuff type borders, a stack count), the health and power texts as the game's Status Text setting shows them, the
level as the game writes it (a skull for a boss or 10+ levels over yours), the boss dragon on the copy (place read,
built-in from retail). The Cast Bars pages show the Unit Frames preview's own frame over each cast bar
(ns.MakeUnitFrameSample: NewUnit/DressUnit pulled out of the preview), the target's with its target of target.
Not done: leader/role/PvP icons, the class resource under your frame, the state parts (raid marker, rest/combat,
threat, heal prediction, dead/offline).
Measured, not guessed (user 2026-11-20: "dont guess any more. get it right", a theme's real target frame next to
the preview): ns.UnitHangs (UnitFrameCopy.lua) measures off the live frames, per look (ns.UnitLookKey), the target
of target's health bar, the first buff, the level and its circle, in widths of the frame's health bar; the preview
places them by it (HangMeasured, the auras, MeasuredLevel), today's rules only where nothing's measured. The match
test compares totHealth, aura1, levelBack (and a skull as the level) in both looks. Offline: the stand-in's ToT and
buff reproduced exactly (1.06,0.47 0.52; -0.11,0.34 0.15). Fixed on the way: the layout code made CinematicDB before
the game loaded it (the Cast Bars frames draw at load): a fresh install skipped its profile pick (check.lua caught
it).
In-game run 18:50 (Forever): measured the game look (level, circle, both ToTs) and the petal theme (level, circle);
game look 100 but target/focus 97 (a buff row only ours: the target had none); theme player 86, pet 85 (bars thinner,
name bigger/centered, own circle art). Now also measured per look: the health bar's thickness, power bar, portrait,
name (place, size, side), level side; a theme's drawn frame takes them (MeasuredBody, the game's circle art in the
ring color); the buffs row wraps before a hung target of target (ns.WrapUnitAuras) as the game's does; the test waits
for a buff or debuff on the target, a buff on one side only is noted. Next on retail: bar texts ("100%", "554 K"), the aura row, leader/role icons. Left: then target of target, party, the theme shapes, retail. Still drawn: pet, target of target, party, and every theme shape.

2026-11-21 (Forever runs 09:52, 10:36; probes 10:19, 10:28):
- The test's flow, rebuilt after runs that each stalled somewhere new:
  - step 1 is two goals, met in any order and kept once met: FRAMES (everything up at once, read in your look,
    a fight is fine) and BUFFS;
  - step 2, the game's look, once out of the fight;
  - step 3, every built-in theme (16) on the real frames, out of a fight: a player as target and focus, your pet;
    quiet log lines, your theme snapshotted and put back, at the next login too;
  - checks once a second as well as on events;
  - reads taken before the screenshot (the focus's target of target was lost in the half second between).
- Offline (unitmatch.lua) now replays the user's real run, start to finish, with no skip, plus the themes cases.
- Forever's buff row can't be read: the container's place, size and anchors are secret even out of a fight, and
  it has no children or regions (rule forever.targetframe.aura-container-place-secret). It's worked out instead
  (UnitFrameCopy.lua WorkedOutAura), from the game's layout measured off screenshots:
  - first icon 24 units in from the frame's left;
  - top 5 under the frame's top with Buffs On Top, 74 under it without;
  - icons 17 units, 3 apart;
  - with Buffs On Top, Cinematic's theme lift (ns.UnitAuraLiftNow) on top of that.
  - Rows grow up with Buffs On Top. Retail still reads its buttons.
- Run 10:36: 9 frames, all 100 (your look was the game shape, no theme).

- Run 10:52 (the first themed run, all 16 themes read): fixed what it found:
  - with the page off, the preview took the active theme's layout (Slate's slab), so the game look scored player
    83 and pet 63. ns.UnitThemeLayout() now gives none while the Unit Frames page is off;
  - a theme's custom health color is made fuller on the real frame (ns.ThemeVivid) but wasn't on ours, so 8 themes
    were darker;
  - the pet is now measured per look too (HANG_FRAMES), and its power follows your live pet's (ns.LivePetPower);
  - the level circle was misread by the test (the badge's frame, not the circle on it);
  - slab themes hide the level and circle: the hangs keep levelHidden and levelBackHidden, and the preview, drawn
    or copy, hides them;
  - targets of target are worked out off the hidden frame (TOTPROBE: its rect reads), which fixes the buffs over
    the target of target in 12 themes;
  - class and by-health colors are noted (the unit's), not counted;
  - the look key names the theme: Gilded Codex and the game look shared one record.

Still to do (unit frames):
1. A second themed run, to confirm the fixes above.
2. Theme looks' targets of target: worked out off the hidden frame; confirm in that run.
3. The other session's findings (Blizzard shoulder cam snap issue, 2026-11-21), unconfirmed:
   - buff icon crop (the game shows the full icon with its edge);
   - Codex's name strip brown in game, ours blue.
4. Parts not drawn or not compared yet:
   - leader, role and PvP icons;
   - the class resource under the player frame;
   - raid marker, rest and combat icons, threat glow;
   - heal prediction, dead and offline states;
   - bar texts (statusText) compared, not only drawn.
5. Retail: bar texts, the aura row, leader/role icons, a themed run.
6. Party frames: a live read needs a group.
7. One Style General preview anchor loop (10:25, PLAYER portrait on its health bar) after a theme test, not
   reproduced offline; the dev anchor check logs the chain if it comes back.

Next (the order of work below, step 4): unit frames (copy, B), nameplates, action bars (A), raid (B), tooltip (A),
personal resource, roll window, quest item, combat text. Each: add pairs to the match test first, get a baseline,
then fix.

## What's wrong today

- Every preview is hand-built: `MakeSample` (Style/PlateCastStyle.lua) draws a cast bar from loose textures at a
  made-up 140 px width; `MakeUnitStylePreview` (Style/UnitStyle.lua) places frames by hand-typed coordinates
  (`framed = { 150, -140, 36, 80 }`). They drift from the game: on Forever the target cast bar is a gold bar with the
  spell name on a dark plate *under* it; our preview draws a thin bar with the name on top, icon left, a second bar
  under it.
- Nothing checks them. Style Lab (Tools/style-lab) and ThemeShots/PageShots show our previews, but never next to the
  real frame, so nobody sees the gap until a player does.
- Good part to keep: the samples carry the game's part names (`bar.Icon`, `bar.Spark`, `bar.Text`...) so our style
  code runs on them unchanged. The bug is the base they start from, not the styling.

## The idea: stop recreating, use or copy the game's own frame

Three ways to get a preview, best first. Each preview is moved to the best one that works on its client.

### A. Build it from the game's own template (best)

`CreateFrame(type, nil, ourParent, "<Blizzard template>")` makes a real copy of the game's frame: same art, atlases,
fonts, sizes, layers, offsets. We then feed it fake values (spell name, icon, 0-1 value, health, class color) and
switch off its own scripts (`UnregisterAllEvents`, `SetScript("OnEvent"/"OnUpdate", nil)`) so it never reads a real
unit. Our styling then runs on a frame that *is* the game's, so the preview and the real one can't drift, on either
client, after any game patch.

Candidates (names to confirm in step 0, they differ per client):

| Preview | Game template to try |
|---|---|
| Cast bars (yours, target/focus, boss) | `CastingBarFrameTemplate`, `SmallCastingBarFrameTemplate`, retail `PlayerCastingBarFrameTemplate`/`TargetSpellBarTemplate` |
| Nameplate cast bar | retail `NamePlateCastingBarTemplate`; Forever's plate cast bar template |
| Action bars | `ActionButtonTemplate` (not the secure one) |
| Tooltip | `GameTooltipTemplate` (we already create these) |
| Raid frames | `CompactUnitFrameTemplate` (no unit set, values filled by hand) |
| Roll window | `GroupLootFrameTemplate` / retail loot roll template |
| Unit frames, nameplates | probably too tied to units/secure code: B instead, A only if step 0 shows it's safe |

Rules: never a `Secure*` template, never in combat (`ns.Guard`), every create in `pcall` with a fallback to B, and
the template name per client in one table (`PREVIEW_TEMPLATES`), probed at load like `/cine selftest` does.

### B. Copy the live game frame (when the template can't be used)

A generic copier, `ns.CopyGameFrame(realFrame, parent)`: walks the real frame (TargetFrame, a nameplate, the
PlayerFrame...) and rebuilds each shown region: texture file or atlas, tex coords, vertex color, blend mode, size,
anchors, draw layer and sublevel; font strings' font, size, flags, color, justify, shadow; status bars' fill texture.
It reads the shape only, not the unit's values, so secret values in fights don't matter (and it only runs out of
combat anyway).

The copy's recipe is saved per client (`CinematicDB.frameRecipes[client][frame]`), so a preview can be built even when
the real frame isn't up (no target, no boss), and the offline Style Lab can draw the same recipe instead of its
guessed layout. A recipe holds atlas names and file IDs only, no game art, so nothing of Blizzard's is bundled
(see the no-unlicensed-data rule; A and B both use the game's art at runtime, which is fine).

### C. Hand-built (last resort)

Only where A and B both fail (screen effects, bubbles, Cinematic's own frames like cards and Quest Talk, which have no
game twin). These must still pass the match test where a game twin exists.

## Step 0: find how the game builds them (one evening)

1. Export the game's own UI source, once per client, for reading only (never copied into the repo):
   start Wow.exe with `-console`, then in the console (`` ` `` key) `exportInterfaceFiles code`. It writes
   `BlizzardInterfaceCode/` next to Wow.exe. Do it for `_forever_` and `_retail_`. From it we list the exact template
   names, which ones are secure, and which mixins call protected functions.
2. A dev command `/cine debug templates`: tries each candidate template on the current client in `pcall`, logs made /
   failed / taint warning, its size and named parts. One run per client, "check log".
3. Result: a table per preview of A/B/C per client, added to this file.

### Step 0 results

Forever (1.60.1 build 70959, 2026-11-19, `/cine debug templates`): 209 templates looked at, 120 made, 3 failed
(forbidden frames), nothing blocked. Retail (12.1.5 build 70961, same day, fixed probe): 132 made, 3 failed (the
same forbidden frames), nothing blocked. Every template in the table below makes clean on both, with the same parts
and sizes. The live `TargetFrameSpellBar` and `FocusFrameSpellBar` have exactly `TargetSpellBarTemplate`'s parts on
retail, so a preview made from it is the game's bar. Retail has no `PlayerCastingBarFrameTemplate` under that name;
`CastingBarFrameTemplate` sized like `PlayerCastingBarFrame` covers it there too.

Note: `BossTargetFrameTemplate` (built on the secure `TargetFrameTemplate`) slipped past the skip, because only its
direct parents are checked. It made clean on retail and errored on Forever (no name). It would be a whole real target
frame, but it's a secure unit button: keep unit frames on B unless a later test shows it's safe.

| Preview | Forever + retail | How |
|---|---|---|
| Target/focus cast bar | `TargetSpellBarTemplate` made clean, 150x10, Icon, Spark, Text, TextBorder (the dark plate under the bar), BorderShield | A |
| Your cast bar | `PlayerCastingBarFrameTemplate` is Edit Mode (skip); its base `CastingBarFrameTemplate` made clean, sized like `PlayerCastingBarFrame` (208x11) | A |
| Small cast bar (boss, arena) | `SmallCastingBarFrameTemplate` made clean, 150x20 | A |
| Nameplate cast bar | `NamePlateCastingBarTemplate` made clean (Icon, BorderShield, ImportantCastIndicator...) | A |
| Action buttons | `ActionButtonTemplate` made clean (45x45, the game's atlases) | A |
| Tooltip | `GameTooltipTemplate` made clean | A |
| Roll window | `GroupLootFrameBaseTemplate` made clean, 277x67 | A |
| Unit frames (target, player...) | `TargetFrameTemplate` is secure | B |
| Raid/party frames | `CompactUnitFrameTemplate` is secure | B |

Probe changes after the first run: bases that only exist to be built on (ClassPowerBar, ClassNameplateBar, pet battle)
are skipped, because the game warned about them; made frames get a name (action buttons and compact frames need one);
the limit went from 120 to 250.

## The match test (proves it, stays forever)

### In game: `/cine debug previewmatch [name]` (Dev copy)

One recorder run (in-game testing rules: runs itself, no time limit, CineMode off, steps on screen via
`ns.TestPrompt`, everything logged so "check log" is enough):

- For each preview, a pair entry: the preview maker, a getter for the real frame, and how to make the real one show
  (target yourself, start a cast, `/cine debug` dummy plate...). Steps that need the player ("cast Shadow Bolt now")
  wait on screen till it happens.
- With both up and the preview on "The game's" look (all Style off): place the preview at the real frame's size,
  side by side, `Screenshot()`, log both screen rects.
- Structural compare, no pixels needed: walk both frames and diff region by region (atlas/file, tex coords, color,
  size ratio, anchor side, layer, font, font size, justify). Each mismatch logged as one line:
  `cast/target: Text anchor TOP of bar (game) vs CENTER (ours)`.
- Then the same with a Style theme on, both preview and real frame styled, to check our styling lands the same on both.

### Offline: `Tools/preview-match/build.py`

Reads the log and the screenshots from `_forever_/Screenshots` and `_retail_/Screenshots`, crops each pair by the
logged rects, scales to the same size and writes one HTML page: game | ours | difference heat map, a match score per
preview, the structural mismatch lines under each. That page is how we look at it together.

### Kept as a check

- Each preview gets a score floor; `Tools/prerelease.py` and `/cine prerelease` fail when a preview's structural diff
  grows (a new mismatch line) on either client.
- Style Lab draws from the saved recipes, so offline shots match too.

## "Make sense", not only "look right"

Things the test can't catch, fixed as each preview is moved:

- Real proportions: show the frame at the game's size scaled down evenly, never squashed to a made-up width.
- The client's own layout: Forever previews look like Forever, retail like retail (one-client-fix rule: a change for
  one never moves the other).
- Real situations: a target cast bar sits under a target frame, a plate cast bar under a plate, not floating alone.
  Samples show the states players know (casting, channel, can't interrupt) as the game draws them.
- "The game's" pick shows exactly the untouched game frame, so before/after (Hold to compare) is honest.

## Order of work

1. Step 0 (export + `/cine debug templates`), both clients.
2. Build the match test and the HTML report first, run it on today's previews: a baseline score for each.
3. Cast bars first (the user's screenshot; most visible gap): A on both clients.
4. Then by how often players see them: unit frames (B), nameplates + plate cast (A/B), action bars (A), raid (A),
   tooltip (A), personal resource, roll window, quest item, combat text.
5. After each: rerun the match test on both clients, compare to the baseline, keep the HTML page.
6. Last: hook the scores into prerelease and Style Lab.

Each step is tested in game on Forever and retail before the next one starts.

## Risks

- Templates may run code on create (mixins' OnLoad registering events, touching unit APIs): handled by pcall,
  stripping scripts after create, and the fallback to B. Step 0 shows which ones.
- Taint: only non-secure templates, out of combat; the match test also logs any ADDON_ACTION_BLOCKED during the run.
- Retail nameplates and unit frames are partly forbidden/secret: B reads shapes, not values, and saved recipes cover
  the times the frame can't be read.
- Game patches change frames: A follows them by itself; B recipes are refreshed at login when the real frame is read.
