# Plate Layout plan (2026-11-25): full control over where every nameplate part sits

Goal: a player can move, resize, hide and re-anchor every part of a nameplate, and keep the plate balanced (its
visual center where the unit is) when parts come and go. One layout function dresses the preview's game-plate copy
and real plates alike, so what the editor shows is what plates get.

## What we stand on (already true)
- The preview IS the game's plate: `ns.MakeGamePlate` (Plates/PlateCopy.lua), laid out by the game's own
  ApplyFrameOptions, every state via the game's calls (rule forever.plate.template-copy-laid-out).
- On OUR copy GetPoint / GetSize read plain (Q4 in Tools/tests/plate-preview-match.md). On live plates they error
  (all.plate.position-unreadable, forever.plate.getpoint-restricted). So: the copy is the anchor recipe for live
  plates. Same nameplateStyle + size = same anchors.
- Live plate parts take SetPoint: healthBar re-anchored narrower works and the game doesn't redo it within 8 s
  (forever.plate.narrow-width); the raid marker and EQoL's mark are already repinned with a SetPoint hook
  (PlateParts.lua ~1830-1920). The Shoulder Cam / aura lift use AdjustPointsOffset on secret places.
- PART_FRAMES (PlateParts.lua) already names every part by its game field.

## The parts
| Group | Part | Game field | Notes |
|---|---|---|---|
| Body | Health bar | HealthBarsContainer / healthBar | the plate's "spine"; width/height already in Style |
| Body | Cast bar | CastBarsContainer.castBar | sub-parts below |
| Cast | Spell icon, Spell name, Shield, Timer (ours), Spark | castBar.Icon / .Text / .BorderShield | place depends on nameplateStyle (all.plate.castbar-layout-by-style) |
| Text | Name | name | restricted region: we can anchor it, never read it |
| Text | Level box | PlayerLevelDiffFrame (Forever), LevelFrame | Forever shows it on NPCs too (Camelot) |
| Text | Guild / title, Health text | ours (PlateGuild), healthBar LeftText/RightText | ours: free to place |
| Icons | Raid marker, Elite/rare/boss, Quest mark (ours, Questie, EQoL) | RaidTargetFrame, ClassificationFrame | marker hides elite in the game |
| Auras | Debuffs, Buffs, Crowd control | AurasFrame.* lists | CC row hangs off the level box (forever.plate.crowd-control-row) |
| Glows | Target border, Threat, Soft target, Selection | healthBar.selectedBorder, aggro*, SoftTargetFrame | follow the bar, offset/size only |
| Other | Widgets | WidgetContainer | move only |

## The model (per part)
- Show (already: the Plate parts grid; layout only places).
- Anchor to: Health bar (default for most), Name, Plate center, or another part (no loops; a part whose anchor is
  hidden falls back to that anchor's anchor, so hiding Level doesn't strand the CC row).
- Side: 9-point picker + Inside/Outside (a part's point and its anchor's point as one choice: "right of", "above",
  "inside left"...), plus Gap.
- X / Y nudge (pixels on screen, scaled by the plate's effective scale so they look the same at any plate size).
- Size (scale for icons/auras/text; width/height for bars, the existing plateStyleWidth/Height kept as the bar's).
- Text: justify + max width (the name is cut to its box today).
- Layer: in front / behind the bar (frame level / draw layer), for icons over the bar.
- "Game's" on every field = the recipe's own anchor, so a Reset puts back exactly what the game does.

Where layouts live (needs the user's call, see Questions): one layout for all plates, with an override per kind
(hostile / friendly NPC / player / ...) through the existing kindParts ("Use custom parts"), and the Nameplate Style
rows (Target, Focus, Mouseover...) able to nudge on top.

## Balance (the plate's real center)
The problem: the game anchors the plate on the unit at the health bar's center, so hiding the level box on the
right leaves the plate's look lopsided; moving the name changes it again.
- The editor works out each shown part's box from the recipe (sizes read on the copy; live sizes read plain out of
  a fight, Q8) in plate units, and draws: the unit's spot (crosshair), the bar's center, and the group's center.
- Center mode per layout: **Bar** (the game's), **Balanced** (shift everything so the group of shown parts is
  centered on the unit, horizontally; vertical optional), **Custom** (an X/Y shift of the whole group).
- Balanced is worked out per state on real plates: a part that comes and goes (level box on players only, CC row,
  cast bar while casting, elite icon) can either count always (steady, no jumping, the default) or only while shown
  ("follow", re-centers on change). Per part tick: "Counts for balance".
- The shift is applied once to the root (HealthBarsContainer and its free parts move together), so parts keep their
  places relative to each other.
- Symmetry helpers: "Mirror" (put this part on the other side at the same gap), "Match gap" (left and right parts
  the same distance from the bar), and snapping to the bar's edges / center while dragging.
- The click box: the game's hit area is the plate's, not the parts'. Balanced shifts the look, the click stays on
  the unit (that's what we want); parts dragged far away aren't clickable. Said in the editor.

## The editor (on the Nameplate Style preview; the spot is the user's call)
- A Layout tab (ns.FolderTabs) with the big game-plate preview. Click a part on the preview to pick it (or from a
  part list beside it), drag it, arrow keys nudge 1 px, shift+arrows 5 px. Snap guides to the bar's edges, center
  line, and the other parts' edges.
- The Unit and State dropdowns already there drive what's shown (casting, can't interrupt, marker, elite, debuffs,
  level box, target): lay out with everything up via an "All parts" state, check each state after.
- Under the preview: the picked part's fields (Anchor to, Side, Gap, X/Y, Size, Layer, Counts for balance) and the
  plate's Center mode. Change dots + Reset per field, Reset part, Reset layout (existing Look panel shell).
- Presets: Game, Centered (level and marker balanced on both sides), Compact (icons inside the bar), Name over bar,
  and each Style theme can carry one. Layouts ride in CINE1 share strings (Share.lua) as settings.

## How it works on real plates (Plates/PlateLayout.lua, new file, Style module)
1. Recipe: on the copy, per nameplateStyle + size, read every part's anchors and size (ns.GamePlateRecipe); cached
   per client in CinematicDB, rebuilt when nameplateStyle / nameplateSize change or the game build changes.
2. ns.ApplyPlateLayout(plate, layout): for each part, from the recipe's anchors + the layout's fields work out the
   points, ClearAllPoints + SetPoint (pcall, ns.Guard), mark it moved. Parts left at Game aren't touched at all.
3. Kept: the game lays parts out again in UpdateAnchors / UpdateControlAnchors / the cast bar's
   ApplyStyleAndAnchoring / the auras' layout and on plate reuse (NAME_PLATE_UNIT_ADDED). hooksecurefunc on each
   (per unit frame, once, like the EQoL hook) re-applies ours after theirs. One pass per plate per frame at most
   (OncePerFrame) for CPU.
4. Off: every moved part back to the recipe's game anchors (we can't read live ones, the recipe is the truth).
5. The same function runs on the preview's stand-in plate, so the preview can't drift.
6. Gates: page switch + Style switch chain (page-switch-gates-all, style-switch-chain); forbidden plates (retail
   dungeons) skipped; retail stays on today's look until its recipe is proven (one-client-fix).

## Steps
0. Read the game's layout code (Forever export: Blizzard_NamePlates, Camelot first) for every anchor and every
   function that re-anchors; write the recipe table from it and from the copy. Engine rules for anything new.
1. One probe run, as a kit test (extend `/cine debug platematch`, step "layout"): on a live plate, out of a fight and
   in one, move each part by +10/+10 and read it back through the copy-recipe twin + a shot; target change, cast,
   plate reuse and a nameplateStyle switch, and whether ours survives each; the hit area. One action: target a mob,
   pull it.
2. PlateLayout.lua: recipe, apply, keep, put back; offline stand-in (Tools/offline/platelayout.lua): every part moved
   and put back, anchor loops refused, hidden-anchor fallback, recipe per style, a game re-layout undone and redone.
3. Balance math (pure functions, offline tested: hide level -> group re-centered within 0.5 px; mirror; counts-for-
   balance off / follow).
4. Editor UI (after the user picks the spot): drag, nudge, snap, guides, fields, presets. Offline layout check at
   300 / 480 / 760 wide (r:Overlaps, no off card), page opened in every state.
5. One in-game confirm run: a layout with every part moved + Balanced on the preview and on real plates (hostile
   mob, friendly NPC, a player), shots side by side, reuse and a fight; then `full` before the commit.
6. Retail: export its code, one run, switch it on.

## Questions for the user
1. ANSWERED (user, 2026-11-25, screenshot): a Layout tab on the Nameplate Style page's tab row, right after
   Default (Default, Layout, Smart, Cast Bars, gear). Right-click toggles it like every tab (ns.TabContainer).
2. ANSWERED: one layout for all plates, each kind can override it (existing kindParts "Use custom parts").
3. ANSWERED: default center = Bar (the game's); Balanced is opt-in.
4. ANSWERED: parts that come and go always count for balance by default (steady); "only while shown" per part.
5. ANSWERED: free drag anywhere, no box.

## Risks
- In a fight a plate part may refuse SetPoint (98078e3 found frames that refuse addon code in fights): the probe
  answers it; if so, layouts apply out of fights and on plate creation only, and a plate first seen in a fight
  keeps the game's until the fight ends.
- The cast bar's sub-parts re-anchor on every cast in some styles: hook cost on many plates in a city (perf kit
  check before release).
- Names are restricted: anchoring works, reading doesn't, so the name's box for balance comes from its font and text
  width on our own measuring FontString.

## Built (2026-11-25, uncommitted)
- Plates/PlateLayout.lua: the engine. Each part's game anchors are mirrored by hooks on its SetPoint,
  ClearAllPoints and SetScale. Parts the game anchored before we watched are seeded from the copy's recipe
  (GetPoint reads on our copy). Anchors are replayed with the offsets after UpdateAnchors and UpdateControlAnchors,
  and the cast bar's ApplyStyleAndAnchoring and any stray re-anchor are put right on the next frame.
  - Put-back is exact. Hanging on another part works, and loops are refused through any chain.
  - Sizing keeps one anchor. The center is Bar, Balanced or Custom, shifting the chain's roots (CastBarsContainer
    and SoftTargetFrame).
  - Balance is measured on an off-screen copy. Parts can count always, only while shown (OnShow/OnHide), or never.
  - Kinds use their own layout when ticked. No hooks are set until a layout changes something.
- Plates/PlateLayoutPage.lua is the Layout tab, after Default. It has:
  - the previewer with click, drag and arrow-key editing, and guides (unit, bar, shown parts) with an offset readout;
  - Layout for and Own layout, presets (Game's, Balanced, Compact, Name in the bar), and the Center dropdown with
    Custom's shift sliders;
  - the parts list with gold change dots, and fields: Hang on, Side, Gap, X/Y, Size and Balance;
  - Mirror, Reset part and Reset layout.
- Not built from the mockup: a real Hide per part. Showing and hiding stays on the Show tab's Plate parts grid,
  because two writers to a part's alpha fight in CineMode.
- First in-game load broke the game: the page build stopped partway on an unknown stack kind, and its key frame
  took every key (memory onkeydown-takes-keyboard). Fixed: the key script is set only while the mouse is on a part,
  every other key passes on, and the canvas is hidden first. Proven offline in Tools/offline/platelayoutpage.lua.
- Tests:
  - Offline: Tools/offline/platelayout.lua (41 checks on a stand-in with real anchor geometry),
    Tools/offline/platelayoutpage.lua, and Tools/offline/platematch.lua updated. All are in prerelease.
  - In game: `/cine debug platematch` steps layoutpage, layoutlive and layoutfight (optional). Queued as qb095.

## Run qb095 (2026-11-25 08:30, Forever): 30 pass, 1 fail, 0 errors, 0 blocked
- Layout tab: built and shown, no keyboard held, the game plate with 9 clickable parts, lists covering nothing.
  The level box moved 12.35 right on the preview. Switch off showed the off card.
- Real plates: 14 parts moved, kept through the game's own re-layout (debuff padding CVar), 0 layout errors, and
  0 moved with the switch off. In a fight: kept, 0 errors.
- FAIL, Balanced, 23 off: the test checked with only a cast up. Balanced counts what can show (marker and elite room
  on the left), and the elite mark was counted though the game hides it under a marker. Fixed: only parts visible
  on the measure plate count, and the test checks with every part up.
- The live shots' backing panel covered the plate itself: live plates are now shot without one.

## Run q2b06 (2026-11-25 08:36, Forever): 31 pass, 0 fail, 0 errors, 0 blocked
- Balanced on the preview is off by -0.31, and the real plate shots show it working (Stonetusk Boar: level box from
  the bar's right to its left, name up, plate shifted to balance; kept through the re-layout; back with the switch
  off). It's kept in a fight.
- Seen in the Balanced shot: the page's readout said "38 right" of a balanced plate, because it counted the parts
  set to Doesn't count. Fixed (it counts as Balanced does), and the test now checks the readout too.
  Not run in game yet.

## The look, rebuilt (2026-11-25, runs qc3be to q2431)
The user's calls: the first page "looks like shit". The preview "can't pop out" and didn't fit the addon. Two
unnamed lines; lines over the bar but under the cast bar. Now:
- The preview is the Style pages' shared one (ns.StylePopout): first on the page, held at the top as you scroll,
  pops out and docks, sized to the screen's shape. The Nameplate Style previewer fills it.
- Center uses the Look panels' rows.Segments. Other buttons copy that look. Reset page clears the layouts.
- Guides are marks off the plate: a Unit tick (white) over and under the plate, and the Plate's middle tick
  (blue) only with Balanced or Custom, joined by a thin line. A status line by the toggles says it in words.
  Drawn above every frame of the plate.
- Part boxes only over parts that show (aura lists with an icon, the soft target with its icon). The plate's room
  fits the soft target's quest icon.
- Test: guides against every plate part in 3 modes, status words, overlaps, pop-out and back. A popped preview is
  put back for the run. Run q2431: 39/39.
