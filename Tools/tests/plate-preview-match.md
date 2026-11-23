# Nameplate preview, 1:1 with the game's plate: test ledger
Goal: the Nameplate Style preview (and every page that shows its plate) looks exactly like the game's nameplate on
the client you're on, every part the game draws, in every state it draws it in, proven by a test.
Code: Plates/PlateRowLook.lua (ns.MakePlateRowLookPreview), Style/PlateCastStyle.lua (ns.MakePlateCastSample),
Style/GeneralStyle.lua (ns.MakeGeneralPlatePreview), Plates/PlateParts.lua (PART_FRAMES). Test: Dev/PlateMatchTest.lua
(`/cine debug platematch`). Plan context: Tools/preview-match-plan.md (cast bars and unit frames done this way).

## What the preview draws today (2026-11-22)
One plate (Hostile / Neutral / Friendly / Player pills): health bar (texture, border, gradient, full color), name,
Forever's level box, the cast bar sample (icon, spell name, spark, timer when on; Fireball only, so never the
can't-interrupt shield), the row's mark (target / focus / mouseover / aggro rows). Nothing else of the 44 parts on
the user's list. The fill is a guess: retail's plate atlas or a drawn bar, the ground a guess on Forever (the trim
copy, GamePlateTrim, reads healthBar.bgTexture's points, which error since build 70959).

## The plan for the missing parts

### Way A first: the game's own plate as the preview
Retail's template probe (2026-11-20, CinematicDev templateProbe.retail) made these clean in an addon:
- `NamePlateUnitFrameTemplate` (a Button, not secure): every part by its game name: HealthBarsContainer/healthBar,
  CastBarsContainer, AurasFrame, ClassificationFrame + classificationIndicator, LevelFrame, PlayerLevelDiffFrame,
  RaidTargetFrame, SoftTargetFrame, WidgetContainer, aggroHighlight/Base/Additive/Mask/aggroFlash,
  selectionHighlight, behindCameraIcon, myHealPrediction, otherHealPrediction, myHealAbsorb (+ shadows),
  overAbsorbGlow, overHealAbsorbGlow, name, +2 more. Sizes 0x0: the driver lays it out.
- `NamePlatePreviewTemplate`: the game's own Settings preview of a plate (Border, NamePlate button, Preview text).
- `NameplateAuraItemTemplate` (Icon, Cooldown, CountFrame), `NamePlateAuraListTemplate`, `NamePlateFullBorderTemplate`,
  `NamePlateCastingBarTemplate` (already the cast sample's base).
If the template can be laid out on our own frame (its mixin's setup, or the game's preview code), the preview IS the
game's plate: every part, its atlases, sizes and places, on both clients, after any patch; our plate looks already
work on those part names (PlateParts.lua), so styled and unstyled both match by construction. On our own frame its
places read too (the live plate's are restricted), so it doubles as the recipe.

### Way B where A can't: a recipe read off the live plate
Per part, what reads on a real plate (atlas, file, tex coords, vertex color, blend, layer; font, size, flags, color,
shadow; a bar's fill and color), saved per client like UnitFrameCopy's recipes. Places can't be read on a live plate
(rules all.plate.position-unreadable, forever.plate.getpoint-restricted): they come from the template copy (A's
walk, even if A can't be the preview), else from a twin drawn at the real plate's scale and the screenshots.

### The parts, by group (the user's list), and what the probe decides
| Group | Parts | Game part (to confirm) | In the preview |
|---|---|---|---|
| Bars | HEALTH, CAST | healthBar, castBar | there; fill + ground to match |
| Bars | HEALTH_FILL_TEXT, ENERGY, PLAYER_POWER | none known on a plate; class bar on target (nameplateResourceOnTarget) | if the walk finds them |
| Highlights | TARGETED | healthBar.selectedBorder (Forever), selectionHighlight | add, a state |
| Highlights | SOFT_TARGET | SoftTargetFrame | add, a state |
| Highlights | AUTOMATIC (aggro) | aggroHighlight*, aggroFlash | add, a state |
| Highlights | MOUSEOVER, FOCUSED | unknown (walk) | if the game draws one |
| Highlights | FIXED, FIXED_BORDERED, AURAS, ANIMATED_BORDER, FLASHING | not game parts as far as known | Cinematic extras only, later |
| Auras | DEBUFFS, BUFFS, CROWD_CONTROL | AurasFrame.DebuffListFrame / BuffListFrame / CrowdControlListFrame (retail), BuffFrame (Forever?) | add, NameplateAuraItemTemplate icons |
| Texts | CREATURE_NAME, LEVEL, CAST_NAME | name, PlayerLevelDiffFrame/LevelFrame, castBar.Text | there |
| Texts | CAST_TARGET | castBar.CastTargetNameText + CastTargetIndicator (retail) | add on retail |
| Texts | CAST_TIME_LEFT | not the game's (Cinematic's timer) | there as ours |
| Texts | GUILD, HEALTH_VALUE, DAMAGE_ABSORB_VALUE, ENERGY_PERCENTAGE, THREAT_*, TARGET, CAST_INTERRUPTER, QUEST_OBJECTIVE, MYTHIC_PLUS_FORCES_VALUE | not known on a game plate (walk) | not in a 1:1; extras later |
| Icons | CAST, CANNOT_INTERRUPT | castBar.Icon, castBar.BorderShield | add the shield state |
| Icons | ELITE, RARE, BOSS | classificationIndicator (atlas per kind) | add, a pick |
| Icons | RAID_MARKER | RaidTargetFrame | add, a state |
| Icons | QUEST_OBJECTIVE | unknown on a plate (walk; Questie draws its own) | if the game draws one |
| Icons | PVP_FLAG_CARRIER, PLAYER_FACTION | unknown (walk, on a player plate) | if the game draws one |
| Regions | CLICK, STACK | the plate's click box and stacking: not drawn | none |
| (game, not on the list) | heal prediction, absorbs, behind-camera icon, widgets | myHealPrediction..., behindCameraIcon, WidgetContainer | decide after the walk |

The preview then gets a strip of states over the plate (target, mouseover, soft target, aggro, casting / can't
interrupt, elite / rare / boss, marker, auras), each the game's own part switched on. Where that strip goes is the
user's call (ask before building it).

## Questions
| # | Question | Client | Answer | From |
|---|----------|--------|--------|------|
| Q1 | NamePlateUnitFrameTemplate makes clean in an addon? | retail | YES, parts listed above, sizes 0x0 | templateProbe.retail 2026-11-20 |
| Q1f | Same on Forever? | forever | YES, 21 nameplate templates listed, all 8 asked known; copy made, not protected | run 1, rule forever.plate.unitframe-template-copy |
| Q2 | Which methods does the template's mixin have (layout, SetUnit...)? | forever | 44: no SetUnit; OnUnitSet, SetExplicitValues, ApplyFrameOptions, UpdateAnchors, UpdateScale, UpdateIsTarget, UpdateRaidTarget, UpdateAggroHighlight... (args unknown) | run 1 |
| Q3 | Does SetUnit (or another setup call) lay the copy out on our frame? | forever | NO SetUnit; the bare copy stays 0x0. Its events must be cut at once (13 UnitWidgetSet errors from hidden copies). The other calls need their arguments: open | run 1 |
| Q4 | On our copy, do GetPoint / GetSize read (the recipe for places)? | forever | YES, plain (only the preview's fill texture secret) | run 1 |
| Q5 | NamePlatePreviewTemplate (the game's Settings preview) exists and draws a plate on Forever? | forever | EXISTS and lays out a whole plate at the live sizes (the recipe), but draws nothing alone: the Settings code fills it | run 1, rule forever.plate.preview-template-laid-out |
| Q6 | Live plate (seen: target border + level box border, soft target frame, debuffs, cast parts, marker, classification, widgets; NOT seen: aggro, mouseover or focus highlight, health text, power, quest/PvP icons, heal prediction) Which pieces in each state: which pieces are there and shown in each state (hostile/neutral/friendly NPC, player; target, mouseover, soft target, aggro, casting, can't interrupt, elite/rare/boss, marker, debuffs/buffs)? | forever | open | run 1 step 3 |
| Q7 | Live plate fills: health fill, ground, cast fill | forever | health: UI-HUD-CoolDownManager-Bar tinted (hostile 1,0,0), tex coords secret; ground UI-HUD-CoolDownManager-Bar-BG 215x25; deselectedOverlay on non-targets; cast fill UI-CastingBar-Full-Standard. Neutral color and other cast kinds: read, check the walks | run 1, rule forever.plate.health-fill-look |
| Q8 | Live plate sizes | forever | plain out of a fight (bar 207.5x15.83, plate 237.5x85, eff 0.64); points error | run 1 |
| Q9 | Our preview's plate next to the real one (screenshot)? | forever | open: Style was left out on that copy (no preview maker), no twin drawn | run 1: Style not loaded |
| Q10 | Plate CVars that change the look | forever | nameplateStyle=1, nameplateSize=3 (plate 237.5x85), nameplateAuraScale=1; Horizontal/Vertical/Global scales don't exist | run 1 context |

## Plan tree
- Q3 yes (laid out, no errors) -> Way A: the preview becomes the template copy fed fake values; next need: how to set
  each state on it (selectedBorder, aggro, marker, classification, auras) = Q2's methods + Q6's part names, both in
  run 1. Run 2 = the built preview + the match compare.
- Q3 laid out but errors / taint -> try the copy without events (UnregisterAllEvents after OnLoad) and the mixin's
  own layout calls by name (Q2); if Q4 reads, we still take the places from it (Way B's recipe). Run 2 carries both.
- Q3 no layout at all (sizes stay 0) -> Way B: recipe from Q6/Q7/Q8 reads + Q5's game preview if it draws, + Q9.
- Q5 yes -> the game's own preview on Forever: read its layout as a second source of places.
- Q7 secret in a fight -> take the fills out of a fight only (the walk runs before and after the pull).

## Runs
| Run | Date | Command | Answered | Still open, and why this run couldn't |
|-----|------|---------|----------|---------------------------------------|
| full | 2026-11-23 07:18 | `/cine debug platematch full` | all 32 | - |
| 10 | 2026-11-23 07:14 | `/cine debug platematch` | everything: 28/28 | - |
| 9 | 2026-11-23 07:12 | (old code, no reload) | - | not counted |
| 8 | 2026-11-23 07:08 | `/cine debug platematch` | dropdowns, all states and samples, page on/off | State dropdown past the edge at 300 (fixed); off-page verdict wrong (fixed) |
| 7 | 2026-11-23 06:55 | `/cine debug platematch` | all 27 checks; layout at 3 widths; page pills clear | heal/absorb ticks, aggro fading into the next shot (fixed); page shots spoiled by the test (fixed) |
| 6 | 2026-11-23 06:52 | `/cine debug platematch` | the preview: built, every sample and state, sizes and fill = a real plate's | shots under the test box, page overlaps not run (test's fault), 300-wide pills (fixed) |
| 5 | 2026-11-23 06:47 | `/cine debug platematch` | - | same: two Build errors in the main log (loss of control lookup, options not ready at login), fixed |
| 4 | 2026-11-23 06:45 | `/cine debug platematch` | the fallback holds (pages fine, no errors) | the game plate never built: width read before placing (fixed) |
| 3 | 2026-11-23 06:04 | `/cine debug platematch` | layout = the game's (9/9 sizes, font); 8 of 9 states | shield (showShield by hand), level box (Camelot), stray marker sheet: fixed from the code, proven in the preview's confirm run |
| 2 | 2026-11-23 06:00 | `/cine debug platematch` | the copy takes the game's own state calls; name font same; 3 fixed-size frames same | layout: no plate frame given (the test's fault, fixed) |
| 1 | 2026-11-23 05:11 | `/cine debug platematch` | Q1f, Q2, Q4, Q5, Q7, Q8, Q10; Q3 no (no SetUnit) | Q3/Q5 fill: SetExplicitValues' and the Settings preview's arguments unknown (no game UI source to read); Q9: Style left out on the client, no twin; aggro/mouseover/focus states not reached (no aggro shown on a wolf). The test's fault: copies kept their events (13 errors), fixed (Quiet) |

## From the game's own code (exportInterfaceFiles code, Forever 71037, read 2026-11-23)
Blizzard_NamePlates + Blizzard_SettingsDefinitions_Frame/Nameplates.lua answer Q3 and Q5 without a run:
- How the game builds a plate: NamePlateDriverFrame acquires a NamePlateUnitFrameTemplate from its pool, then
  NamePlateBaseMixin:SetUnit -> ApplyFrameOptions(NamePlateSetupOptions, NamePlateEnemy/FriendlyFrameOptions) ->
  UpdateAnchors (all layout from NamePlateSetupOptions: insetWidth, healthBarHeight, castBarHeight,
  castBarToHealthBarSpacing, useClassicHealthBar...) -> OnUnitSet (events, unit reads).
- The Settings preview (NamePlatePreviewMixin:OnShow) registers itself with the driver as a "script nameplate"
  (token "preview", shown as the player, enemy options), takes a unit frame from the SAME pool real plates use,
  and fakes values: SetExplicitValues (isPlayer, isFriend, isMinion, isMinusMob, threatSituation, aggroFlash,
  classification), explicitAuraList + RefreshExplicitAuras, castBar:SimulateCast(castData). Not for us: driving
  the game's driver and its pool from addon code risks real plates (run 1's P copy did exactly that).
- Our way (run 2): our own template copy, events cut at once, sized C_NamePlate.GetNamePlateSize(), laid out by its
  own ApplyFrameOptions with the live NamePlateSetupOptions, then each state with the game's own calls:
  healthBar:SetIsTarget / SetIsFocus (selectedBorder in NAMEPLATE_BORDER_TARGET_COLOR / ..._FOCUS_TARGET_COLOR,
  deselectedOverlay on the rest), castBar:SimulateCast, RaidTargetFrame:SetRaidTargetIndex,
  ClassificationFrame:SetExplicitValues{classification} (atlases: elite and worldboss nameplates-icon-elite-gold,
  rare UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star, rareelite nameplates-icon-elite-silver; hidden while a
  marker is up), aggroHighlight shown + UpdateAggroHighlight, explicit auras.
- Q6 from the code: a mouseover look only in the Classic plate style (yellow name, nameMouseoverColor, and the
  selection highlight); none in the others, so none was seen in run 1. The plate styles (Modern, Block, Classic,
  Legacy: the nameplateStyle CVar) change the layout through NamePlateSetupOptions, so a copy laid out from the live
  options follows the player's style by itself. Focus = the target border in the focus
  color; aggro = aggroHighlight pieces from the threat situation; health text (LeftText/RightText) is driven by
  a CVar (NamePlateHealthBarMixin:UpdateTextDisplay); the level box (PlayerLevelDiffFrame) only on other players
  under a game rule. CORRECTED after run 3: Forever loads the Camelot files (rule forever.ui.game-type-camelot): its
  level box shows on NPCs too, and its constants and option overrides differ (read Camelot\ first).

## Run 2 (2026-11-23 06:00): 8 pass, 5 fail, the test's build at fault
- ApplyFrameOptions stopped at UnitFrame.lua:607: our copy had no plate frame, and the layout hands the click area
  to it before UpdateAnchors. So no layout: health bar and cast bar 0 wide (shot: only the name and the marker).
- Worked on the copy anyway: the target and focus borders, the darker overlay, SimulateCast (fill
  UI-CastingBar-Filling-Standard / -Uninterruptable), the raid marker, the aggro flare, the name font (same as the
  real plate's: FRIZQT 17.5 OUTLINE SLUG). Sizes that need no layout matched the real plate: marker, elite and
  soft-target frames.
- Shield and icon hidden: SimulateCast doesn't run UpdateIconShown. Elite hidden: the frame's options were never
  passed (ClassificationFrame:SetOptions). Debuffs errored (Auras.lua:274 SetScale nil): UpdateScale never ran.
- Fixed for run 3: a plate frame from the game's own NamePlateScriptBaseMixin (its click calls do nothing), then
  UpdateCastBarDisplay, UpdateScale, ClassificationFrame:SetOptions, and UpdateIconShown after each cast.
- New in the log: the kit now writes console and CVar lines (the console session's work); Shoulder Cam's camera
  CVar writes filled ~80 lines during the compare wait.

## Run 3 (2026-11-23 06:04): 11 pass, 2 fail; the copy IS the game's plate
- Laid out: every readable size the same as a real plate's (Defias Prisoner, Stockade), the name font the same.
  The name's size can't be read on a real plate (not counted now). Compare marked proven.
- States shown on the copy with the game's calls: overlay, target border, focus border, cast (icon, name, spark,
  fill), marker, elite (nameplates-icon-elite-gold), aggro flare, debuffs (all three lists fill, as the Settings
  preview's do). Not shown: the shield (showShield is only set by the cast bar's SetUnit: set by hand now).
- Seen in the shots: our copy had no level box where the real NPC plate has one (Forever is Camelot: level box on
  NPCs), and the marker sheet sat above the copy at rest (the marker frame's shown check never ran): both fixed, a
  level-box state added. Rules forever.plate.template-copy-laid-out and forever.ui.game-type-camelot.

## Preview rebuild plan (2026-11-23)

### The idea
The preview's plate becomes our copy of the game's plate (the recipe in rule forever.plate.template-copy-laid-out),
and it's dressed by the SAME functions that dress real plates. Those already take a plate and work on its
UnitFrame's game-named parts (PlateHealthStyle StylePlate/SetPlateBarOverride: fill, ground, border, gradient,
full color, theme shape; PlateRowLook NameLook: the name; PlateCastStyle StylePlate/Restyle: the cast bar;
PlateParts ApplyPlateNow: the level box and our own name). A small stand-in "plate" holding the copy as its
UnitFrame goes through them, so the preview can't drift from what your real plates get.

### Steps
1. `Plates/PlateCopy.lua` (new, Style module): `ns.MakeGamePlate(parent)` builds the copy (events cut, script-plate
   stand-in, sized, ApplyFrameOptions with the live options, the unit-free setup lines), returns a plate stand-in
   `{ UnitFrame = copy }`; `ns.SetGamePlateState(plate, state)` puts a state on it with the game's calls (target,
   focus, casting, can't interrupt, marker, elite/rare/boss, level box, aggro, debuffs); `ns.SetGamePlateUnit(plate,
   sample)` the sample's name, bar color (the game's reaction colors, read from CompactUnitFrame code), level.
   Built once per preview, out of a fight, under ns.Guard; nil if the template or layout fails (then the old drawn
   plate stays, so nothing breaks).
2. Hooks into the real-plate code, one per file, so it takes our stand-in: PlateHealthStyle
   `ns.StylePlateBar(plate, look)`, PlateCastStyle `ns.StylePlateCast(plate)` (and a Restyle after a pretend cast),
   PlateRowLook `ns.DressPlateName(unitFrame, look)`, PlateParts' level box. Each already exists as a local; it gets
   a public name, no new logic. The preview's "pointed at, not saved" looks (Refresh's `over`) pass the look in, as
   now.
3. `ns.MakePlateRowLookPreview` (Nameplate Style's Look panels, Combat Text Style's page and its welcome demo) and
   `ns.MakeGeneralPlatePreview` (General's screen, the welcome shelf's tiles, ThemeShots, Style Lab's dump) put the
   copy where the drawn plate was; the drawn plate code stays as the fallback. holder.plate keeps pointing at the
   plate (Combat Text draws on it). The cast bar sample under the plate goes: the copy has the game's own.
4. The state picker (user, 2026-11-23): a second row of toggle pills under the unit pills, several on at once
   (Target, Focus, Casting, Can't interrupt, Marker, Elite, Aggro, Debuffs; Focus and Target exclusive, Can't
   interrupt turns Casting on). Kept for the next panel opened, like the unit pick.
5. Retail: not switched until retail's code is exported and one retail run proves the recipe (one-client-fix rule):
   `ns.isRetail` keeps today's preview.

### Tests
- Offline: Tools/offline/platematch.lua's stand-in grows into a preview check (copy made, dressed through the real
  functions, fallback when the template fails, retail untouched); Tools/offline/styledemo.lua and the style-lab dump
  still build.
- In game, ONE confirm run, extending `/cine debug platematch` (kit): the preview made the pages' way, every sample
  and state shown on it with a shot each (this also proves run 3's code fixes: shield, level box, marker at rest);
  a Style look put on (texture, border, a theme) and checked the same on the preview's bar and a real plate's;
  the Nameplate Style page opened in its states (page on/off, tabbed) with r:Overlaps on the picker; the welcome
  shelf's Nameplate tile. Then `full` once before the commit.

## Built (2026-11-23, uncommitted)
- `Plates/PlateCopy.lua`: ns.MakeGamePlate (the recipe; nil on retail or when it fails), ns.SetGamePlateUnit,
  ns.SetGamePlateLevel, ns.SetGamePlateStates (a cast played again while casting is on), ns.GamePlateReport.
- Real plates' code, public for a stand-in plate: ns.StylePlateBar (PlateHealthStyle), ns.StylePlateCast
  (PlateCastStyle), ns.PlateNameLook (PlateRowLook).
- Nameplate Style's preview (and Combat Text Style's, which is the same maker): the game plate, dressed through
  those; a second row of state pills (wraps to the preview's width); holder.plateLift for Combat Text's placing.
  General's screen: the game plate as your target, casting, in the Default row's look.
- Bar colors as the game's selection colors (hostile 1,0,0, neutral 1,1,0, friendly 0,1,0; you: your class);
  names white (friendly players: class color). Neutral and friendly colors are the game's defaults, not read off
  a plate yet: the confirm run logs each sample's bar color.
- Offline: Tools/offline/gameplate.lua (with Tools/offline/gameplate_parts.lua) and the confirm run's
  Tools/offline/platematch.lua, both in Tools/prerelease.py. Not covered by a test: the Nameplate Style Look
  panel's preview inside its panel (only made standalone; the Combat Text page is opened for real).

## Run 4 (2026-11-23 06:45): 0 pass, 4 fail: the game plate never built
- ns.MakeGamePlate checked the layout by the bar's width; inside a preview not yet placed every width reads 0, so
  it gave up (silently) and the drawn plate stood in everywhere (shot: Combat Text Style with the old plate, no
  error, the fallback worked). The test's own copy (runs 2-3) was always placed first, so it never showed.
- Fixed: the layout checked by the health bar's anchors; why it falls back is logged once. Offline stand-in now
  reads widths 0 until placed and anchors in its layout call, plus a layout-that-anchors-nothing case.

## Run 5 (2026-11-23 06:47): 0 pass, 4 fail again; the reasons were in the main log all along
- CinematicDB.log "plates" lines (runs 4 AND 5; check log only showed deverror lines, and I didn't look):
  1. "game plate copy failed: ... C_LossOfControl.GetActiveLossOfControlDataByUnit(unitToken, index)": the aura size
     refresh asked the loss of control slot about the plate's unit, and the copy has none. Fixed: the slot hidden
     first (it's left out anyway).
  2. "UnitFrame.lua:239 bad argument #1 to 'SetSize'": previews built at login before NamePlateDriverFrame filled
     NamePlateSetupOptions (playerLevelDiffWidth nil). Fixed: the copy is built the first time a preview is drawn
     with the options complete (ns.GamePlateReady); till then the drawn plate shows.
- The test now puts the logged reason into its FAIL line. Offline: both cases reproduced (options not ready; the
  loss of control slot errs when shown with no unit), and `plate.gameCopy` (not UnitFrame) marks a built copy.

## Run 6 (2026-11-23 06:52): 27 pass, 1 fail, 2 skip; the preview works, the test's shots didn't
- The game plate built in the preview; nothing up at rest; its sizes the real plate's; each sample (bar 1,0,0 /
  1,1,0 / 0,1,0 / your class) and each state shown by its pill; the Combat Text page shows it, switch on and off;
  9 of 9 readable sizes the same as a Defias Prisoner's; one texture (flat) gives the same fill on both; the real
  plate's own fill back. Compare marked proven.
- The test's fault: the preview sat under the test's own box (the user: "your test is bad"), so the state shots
  show the box; r:Overlaps given words where it takes label frames (kit error, the page check skipped).
- Found: at 300 wide the Scene pick met the unit picks: it now takes a row of its own when they'd reach it.

## Run 7 (2026-11-23 06:55): 27 pass, 0 fail, 0 skip; the shots show two look faults
- Every check passed, the pills clear at 300 wide, the page's pills cover nothing (0) with the switch on and off.
- The shots (a contact sheet of all 12): very near the game's plate, but a cyan tick at the bar's end and a red one
  at its start in every shot (the heal and absorb glows, shown by the template; the game shows them only for a unit
  with a shield or heals coming) and the debuffs shot still glowing red (the aggro flare fading from the step
  before). Both fixed in PlateCopy.lua, both checked offline.
- The test's faults: its standalone preview sat over the settings window in the page shots, and the switch-off shot
  showed the page still on (set while open, never redrawn). Fixed: preview hidden first; settings closed, set,
  opened again, and the switch's state logged.

## The picks as two dropdowns (user, 2026-11-23: "all the nameplate options are kind of ugly to see")
The two rows of pills under the preview are now two dropdowns, Unit (pick one) and State (tick any, the menu kept
open while ticking), Scene its own pick as before (a row of its own where they'd meet it). Pills only on a client
without the dropdown template. holder.PickSample / holder.ToggleState are what the dropdowns call (the test drives
them). Retail: the Unit dropdown, no State one (no game plate there yet).

## Run 8 (2026-11-23 07:08): 28 pass, 1 fail; the look is right
- Contact sheet of the 13 preview shots: every sample and state as the game draws it, no stray ticks or lingering
  glow, the State menu open with its ticks. The page with the switch on: the preview, two dropdowns, Scene, nothing
  covered; off: the game's off card.
- Fail: at 300 wide the State dropdown reached past the edge; at 480 Scene sat alone on a row. Fixed: the
  dropdowns size to the room (130 + 170, one row with Scene at the usual width; State squeezed when narrow).
- The test's fault: with the switch off it passed "the preview on the page" though the preview was under the off
  card. Now: on = the preview and no off card, overlaps checked; off = the off card shows.

## Run 9 (2026-11-23 07:12): ran the old code (no /reload after the fixes: its log had the old wording); not counted

## Run 10 (2026-11-23 07:14): 28 pass, 0 fail, 0 skip: done on Forever
- One row (Unit, State, Scene) at 480 wide (height 129), Scene up a row at 380 and 300, nothing outside or
  overlapping; every sample and state as the game draws it (shots); Combat Text page: on, the preview and picks
  covering nothing; off, the off card. Every step now proven: a normal run is empty, `full` before the commit.

## Full run (2026-11-23 07:18): `/cine debug platematch full`: 32 pass, 0 fail, 0 skip
All four steps, proven or not: templates, preview (every sample and state), page, compare (9 of 9 sizes, the same
fill, the real plate's back). No errors, nothing blocked, console clean. Ready to commit.

## Left
- Retail: export its UI code, prove the recipe there (one run), then switch retail's preview.
- Neutral and friendly bar colors are the game's default selection colors, not read off a real plate.
- The Look panel inside a Nameplate Style row: same maker, not opened by the test (needs a click).
Over budget (6): runs 4-5 were the same build failing for reasons the log held; each later step's game calls were
checked against the game's code and earlier runs before handing this over.
Run 4 because the probe needed three (Forever being Camelot and the layout's plate-frame need only showed in the
code once the template was tried); this one checks the shipped code, not a probe.

## Next: build the preview on the copy (no more probe runs)
What's left (the shield by hand, the level box, the unit-free setup lines) is read straight off the game's code and
passes offline; it gets proven in the confirm run of the built preview, not in a run of its own.
`/cine debug platematch`: build (our copy, whole tree, shot) -> states (9, a shot each) -> compare (target any
mob: 10 pieces' sizes + the name's font against the real plate, a shot of both). One action: target a mob.
If it all matches, the preview is built on this copy next (Nameplate Style page and General's preview), with our
looks applied to its game-named parts.
