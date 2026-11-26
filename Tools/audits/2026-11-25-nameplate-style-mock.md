# Nameplate Style: the mock built (Bar · Colors · Name, colors per kind, Fade, rows follow Default) (fix card)
Fix: Nameplate Style's editor was hard on the eyes and its colors made no sense for NPCs (Class colors on a row
gave NPCs their reaction's, unsaid); rows' looks only counted while Plate color was Custom; plates had their own
Change time next to CineMode's fading; Show in sat on a Style page. Built to the mock the user agreed step by step
(Tools/style-studio/page-mock.html, theme-picker.html, 2026-11-25).
Found by: the user, 2026-11-25 (mock session)
Code: Style/Studio/{Controls,Studio}.lua (list, Drop, tabs, tooltips, footer, side host);
Style/Studio/Frames/Nameplates.lua (parts, Layout's Shown); Plates/PlateParts.lua (ns.PlateKinds, PlateColour,
PlateLook, RefreshTargetArrow, RefreshMarks, ns.PlateChangeTime); Style/PlateHealthStyle.lua (Shade, Gradient,
StylePlate); Plates/PlateRowLook.lua (Own, gradient modes, preview oneList + Default's colors); Options.lua
(Nameplate Style page: side editor, Show in moved to the Nameplates page's Style tab); Core.lua (DEFAULTS);
Migrations.lua (rowLookFollowsV1); Profiles/ProfileModules.lua (Ultra responsive).
Clients: both (Layout: Forever only, as before)
Base: HEAD (b53755f) while staged

## Before / after
- Before: Nameplate Style's look on its Default tab: a big preview over the settings with Unit and State lists,
  Theme as tiles + More..., Plate / Health bar / Name / Level box / Debuffs... parts in a dropdown, every
  explanation a line on the page, Looks, Reset, Undo/Redo buttons on top. Plate color on rows: Next row's, The
  game's, Mark's, Your target's, Gold, By reaction, Class colors, Custom (Class gave NPCs reaction colors, unsaid).
  A row's own Look settings counted only while its Plate color was Custom. Plates eased size/opacity over Change
  time (1.5 s; 0.6 s in the Cinema and Shoulder Cam profiles). Show in row on the Style page.
- After: the preview (268 wide) beside the settings with one Preview list (unit, then every state). Parts as tabs:
  Bar (Theme, Texture, Border, Size), Colors (Default: a line per kind of unit, Class only for players, The
  game's / Theme's accent / My own from the palette, and each kind's Fade: None, Darker, Lighter, Into a color;
  a row: Plate color Don't change / The game's / Default's colors / Mark's color / Gold / One color, which parts
  take it, its Fade), Name (Font, Size, Outline, Shadow, Color: The game's / Same as the bar / My own). Long lists
  are one line opening a list (sample, name, a line on what it is); 3 choices or fewer a switch; explanations are
  tooltips on the headers; Undo/Redo words under the settings only when there's a step; no Looks, Reset or Copy.
  Every setting on a row says Default's until set (a row's look counts whatever its Plate color). Each part's
  Shown is on the Layout tab. Plates ease at CineMode's fade times (Combat fade in time in fights, else Fade in
  time). The Show in row is on the Nameplates page's Style tab.

## Who relies on the old behavior
- Players: rows with Plate color "class"/"reaction" keep them (still listed while picked). Rows not Custom with Look
  settings: those were unused; rowLookFollowsV1 clears them, so no plate changes. Change time: anyone who moved it
  loses it (CineMode's fading takes over); Cinema/Shoulder Cam: 0.6 s → 0.2 s in fights, 1.5 s out of them.
  Default's colors start at The game's: nothing changes until picked.
- Other features: the Nameplate Style page's Smart tab placement used the Show in header (now an empty spot in its
  place); PlateLayoutPage and Combat Text Style use MakePlateRowLookPreview (oneList is opt-in: unchanged for them).
- Other addons: none (plate colors go through the same tint painter as Smart rows).
- Tests that encode it: Dev/StyleStudioTest.lua, Dev/PlateMatchTest.lua, Tools/offline/stylestudio.lua,
  gameplate.lua, platematch.lua, findrankmatrix.lua, boxwords.lua, profile-settings-*.txt (plateStyleFadeTime gone)
  — see the prerelease run.

## States (the matrix)
Unit kind (enemy player, friendly player, hostile/neutral/friendly NPC, not your kill) × each kind's color (game,
class, theme, custom) × Fade (none, darker, lighter, custom) × name color (game, same, custom) × Nameplate Style
on/off × a row's Plate color (-, default, custom) × fight or not (change time).
Test: Tools/offline/platekindcolors.lua (forever and retail in one run)

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| platekindcolors | client=forever case=rowlook | ignored | counts |
| platekindcolors | client=forever case=fight | 0.6 | 0.3 |
| platekindcolors | client=forever case=nofight | 0.6 | 1.2 |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| Tools/offline/profile-settings-*.txt | Cinema / Shoulder Cam plateStyleFadeTime=0.6 | 0.6 | gone | "yes in the addon when we get there" (2026-11-25) |
| Tools/offline/gameplate.lua | the previewer's lists | Unit and State lists | one Preview list (oneList) | "OK + requeue" (2026-11-25) |
| Tools/offline/gameplate.lua | what it shows in the middle of the room (debuffs off / on) | 40.49 / 49.73 | 54.49 / 63.73 (268-wide preview, one list) | "OK + requeue" (2026-11-25) |
| Tools/offline/gameplate.lua | the Theme tiles' part | "plate" | "bar" | "OK + requeue" (2026-11-25) |
| Dev/PlateMatchTest.lua, Tools/offline/platematch.lua | stylepage: lists shown; the editor's place; skips | 2 lists; right under the preview; 16 skips | 1 list; right of the preview (skipped offline); 17 skips | "OK + requeue" (2026-11-25) |
| Tools/offline/findrankmatrix.lua (forever, retail) | query=nameplate_color top hit | Nameplates [Nameplates] (page) | Color [Nameplate Style] | "OK + requeue" (2026-11-25) |
| Tools/offline/gameplate.lua | the Default stage's height and the plate in it | kept 210 tall (minHeight), what shows in its middle (54.49 / 63.73) | as tall as what shows (fitHeight), the plate as big as the 268 stage allows with its level box (scale ≥ 0.9), what shows inside it | "OK" (2026-11-25, after "visually not good") |
| LazyPageDefaults.lua | tabOn:Nameplates:PlateStyleShow | none | true, under handlePlates (the new Style tab) | "OK + requeue" (2026-11-25) |

## Risk
medium: the editor's look changes for everyone who opens Nameplate Style; plate colors and Fade only for those who
pick them. In-game only: the side layout's fit with the page's sticky/pop-out preview, the floating list's width,
the tint painter with Smart off (Default's colors alone), Not your kill turning without a refresh while Smart is off.
