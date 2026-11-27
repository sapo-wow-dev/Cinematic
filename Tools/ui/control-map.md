# Control map

Every unique control in Cinematic's settings pages and its own windows, grouped by kind. The goal: one look per kind,
so a control can be changed in one place and every page that uses it follows. Made 2026-11-27 from a read of all 296
functions that build a button, checkbox, slider, text box or dropdown (`python -I Tools/ui/controlmap.py` lists them).
Counts are call sites by search, so roughly right.

- **id**: the same id is on the Control Gallery page (Dev hub) when the control can be built on its own there.
- **See**: `gallery` = Dev > Control Gallery; otherwise the page or window it's on. `/cine debug controllooks` shoots
  all of them, in HD and SD.
- **Look**: `two looks` = goes through Skin.lua, so HD (flat) and SD (the game's) both work. `flat` = drawn by hand,
  the same in both looks. `game` = a game template with no skinning, so it never gets the HD look.

Out of scope: frames in the world or on the HUD (cards, wheels, quest talk, roll window, edit-mode movers, the chat
copy button, merchant buttons).

## Summary

| Kind | Unique looks | Most used |
|---|---|---|
| Buttons | 5 text buttons, 3 close buttons, 10 icon buttons | Panel button B1 (~164) |
| On/off | 5 | Checkbox T1 (~266) |
| Dropdowns and menus | 7 | Game dropdown D1 (~59) |
| A few choices | 7 segment/radio looks | Studio segments C3 (~87) |
| Tiles and cards | 10 | Style tiles C8 |
| Amounts | 4 sliders, 1 number box, 5 stepper arrows | Slider A1 (~227) |
| Typing | 5 | Skinned text box E1 (~37) |
| Color | 6 swatches | Style swatch K2 (17) |
| Tabs and chips | 3 tab looks, 6 chip looks | Folder tabs N1 (~20) |
| Section headers | 4 collapsible looks | |
| List rows | ~25 builders | |

## Buttons

| id | Control | Builder | Look | Uses | See |
|---|---|---|---|---|---|
| B1 | Panel button | `ns.PanelButton` Skin.lua:278 | two looks (UIPanelButtonTemplate + SkinButton). Same look: FollowHud `Button`, WheelsPage `PanelButton`, Why `CardButton` | ~164 | gallery |
| B2 | Game button, not skinned | UIPanelButtonTemplate alone: Camera.lua:3296 ExitCameraBox, ShoulderCalibrate.lua:222, Reload.lua:213 | game | 4 | gallery |
| B3 | Studio flat button (plain, on, red action) | `C.Button` Studio/Controls.lua:116; PlateLayoutPage.lua:117 `Flat` | flat, gold underline when on | 21 | gallery |
| B4 | Studio tool button with arrow | `C.PanelTool` Studio/Controls.lua:181 | two looks (PanelButton + arrow) | Studio bars | gallery |
| B5 | Welcome flat button (main gold, box, text link) | `FlatButton` = `ns.FlatStyle.Button` Welcome.lua:203 | flat backdrop | ~20 | gallery; Welcome, Profiles, Conflicts |
| B6 | Close X | `ns.SkinClose` Skin.lua:369 (two looks); UIPanelCloseButton alone (color picker, emote picker, Keyboard Map: game); `CloseX` Welcome.lua:255 (two drawn lines) | 3 looks | ~29 | gallery (first two); Welcome |
| B7 | Keybind button | `CreateKeybindButton` Options.lua:19670 | = B1, 140x22 | Keybinds | gallery |
| B8 | Style icon button (pop, dock, scene, close) | `IconButton` = `ns.StyleIconButton` StylePages.lua:980 | flat 22px, glyph from atlas | 8 | gallery |
| B9 | Page link icon (to Style or Settings) | `LinkIcon` StylePages.lua:357 via `ns.StyleIcon`, `ns.SettingsIcon` | flat 20px art, glow | 5 | Style pages, HUD sections |
| B10 | Page help "?" / warning | `PageIntro` Options.lua:229 | flat 18px ring | ~108 | every page title |
| B11 | Row icon buttons (delete, up, down) | `IconButton` CameraScriptsPage.lua:283 | game art, 16-24px | 3 | Camera Scripts |
| B12 | Talent calc icon buttons | `IconButton` TalentCalc.lua:885 | game quickslot art | 2 | Talent Calculator |
| B13 | Favorite star | `ns.AddFavoriteStar` Favorites.lua:371 | atlas 16px | every page | every page's search box |
| B14 | Remove X (red stop) | inline UI-StopButton 16px: TriggersPage.lua:949, CameraTriggerEditor.lua (x2) | game art | 3 | Triggers, Scenes |
| B15 | Gold-edged icon picker | CardsPage.lua:1738 `IconButton`; WheelsPage.lua:462 `IconTile` | flat, same edge color | 4 | Card Style, Your wheels |
| B16 | Link-text button (blue words) | `ns.LinkPointer` FrameLinks.lua:877 | flat text | 7 | Personal Resources, Buffs, Chat, Minimap... |
| B17 | Reset dot | `Dot` CardsPage.lua:478 | flat 7px gold dot | ~19 | Card Style, Card Types |

## On / off

| id | Control | Builder | Look | Uses | See |
|---|---|---|---|---|---|
| T1 | Checkbox | `Check` Options.lua:427 (`kit.Check`). Copies: `ns.LoadPartBox` Options.lua:16102 (7), `DraftCheck` TintStyle.lua:475, `TopTick` KeyboardMap.lua:1252 (label left), `Tick` CameraTriggerEditor | two looks, 26px (22 in the copies) | ~266 | gallery |
| T2 | Pill switch | `ns.MakeSwitchLook` Options.lua:1065 (page header switches); copied by hand: `MakePill` Options.lua:5508 (CineMode page) | flat green pill | every page switch | gallery; CineMode page |
| T3 | Flat tick | `rows.Toggle` StylePages.lua:4013; `C.Switch` Studio/Controls.lua:757 (a copy) | flat, gold box | Look panels, Studio | gallery; Style Look panels |
| T4 | Mini switch | in `MakeLine` CombatTextSpells.lua:449 | flat 26x13 track and knob | per spell row | Combat Text Style > Spells |
| T5 | Welcome switch | `SwitchOn` Welcome.lua:930 | flat 24x12, green | 2 | Welcome |

## Dropdowns and menus

| id | Control | Builder | Look | Uses | See |
|---|---|---|---|---|---|
| D1 | Game dropdown, skinned, radio list | `Dropdown` Options.lua:1315 (`kit.Dropdown`), `rows.Dropdown` StylePages.lua:3147 | two looks (WowStyle1DropdownTemplate + SkinDropdown) | ~59 | gallery |
| D2 | Game dropdown, its own menu | `ns.MenuDropdown` Skin.lua:607 direct: Options (15), TintStyle, StyleThemes, GameSettings, Camera pages, PlateRowLook (Unit, State), PlateThemes; `CameraPick` Options.lua:8320 (falls back to a stepping B1) | two looks | ~27 | gallery; Nameplate Style preview |
| D3 | Game dropdown, not skinned | ChatCopy.lua:340 | game, no long-list scroll | 1 | gallery; Copy chat |
| D4 | Studio dropdown with Find box | `C.Drop` Studio/Controls.lua:456 (+ its list `ListFrame`:246) | flat | ~13 | gallery |
| D5 | Grid cell button + tick menu | `ns.GridMenuButton` + `ns.TickMenu` GridRows.lua:194 | B1 + game arrow, game menu | every grid row | gallery; any grid page |
| D6 | Right-click menu | `ns.ContextMenu` Skin.lua:597 | game menu | 15 | gallery |
| D7 | Number box with menu arrow | `line.ShareBox` Options.lua:705 | E1 + scroll arrow, opens D6 | 2 | Vitals Vision, Heal Vision |
| D8 | "Look" button opening a Look panel | `rows.Look` StylePages.lua:4141 | B1 | 22 | Style pages |

## A few choices

| id | Control | Builder | Look | Uses | See |
|---|---|---|---|---|---|
| C1 | Radio as checkboxes | `Choice` Options.lua:1250 (`kit.Choice`) via `rows.Choices`, `look.Choices`, DamageVision `b.Choices`, CooldownGrid, CameraScriptsPage | two looks, square boxes | ~65 | gallery |
| C2 | Round radio | `line.Pick` Options.lua:824 (UIRadioButtonTemplate + SkinCheck round) | two looks | ~38 | gallery; Letterbox |
| C3 | Studio segments | `C.Segments` Studio/Controls.lua:209 via `R.Choice` | flat, gold underline when picked | ~87 | gallery |
| C4 | Studio tiles (picture choices + More) | `C.Tiles` Studio/Controls.lua:520 | flat 40x26 | Studio | gallery |
| C5 | Style-page segments | `rows.Segments` StylePages.lua:3732; copies: `Cell` CombatTextPage.lua:289 (6), `Segment` CombatTextSpells.lua:153 (2) | flat, gold underline (same look as C3, built 3 more times) | ~26 | Style Look panels, Combat Text Style |
| C6 | CineMode segments (Off / CineMode / Always) | `MakeChoices` Options.lua:5426 | flat, red/blue/green fill when picked | per row | CineMode page |
| C7 | Card segments | `Flat` CardsPage.lua:550 | flat, gold when picked | ~8 rows | Card Style, Card Types |
| C9 | Cooldown pills | `PillButton` CooldownGrid.lua:381 | flat rounded ends | ~12 | Cooldown Manager |

## Tiles and cards

| id | Control | Builder | Look | Uses | See |
|---|---|---|---|---|---|
| C8 | Style tiles (font, texture) | `rows.Tiles` / `MakeTile` StylePages.lua:3432 | flat | every Look panel | Style Look panels |
| C10 | Hub icon tile | `CreateTile` Options.lua:4206; `IconTile` Options.lua:21378 (same look, copied) | flat, gold edge | hubs, Hover Groups | hub pages, Mouseover groups |
| C11 | Hub card | `Card` in `ns.MakeHubCards` StylePages.lua:1789 | flat | 2 | Interface HUD, Visions General |
| C12 | Tint scene tile | `Tile` TintStyle.lua:116 | flat with picture | 1 | Tint Style |
| C13 | Theme card | `MakeCard` StyleThemes.lua:1773 | flat, theme's art | 2 | Style Themes |
| C14 | Card type tile | `TypeTile` CardsPage.lua:1051 | flat mini scene | 1 | Card Vision |
| C15 | Camera tile | `Tile` CameraManager.lua:83 | flat 88x84 | 1 | Cameras |
| C16 | Welcome level card, demo button | `Card` Welcome.lua:393, `DemoButton` Welcome.lua:987 | flat backdrop | 4 | Welcome |
| C17 | Profile card | `Card` Options.lua:20701 | FlatStyle backdrop | 2 | Profiles |
| C18 | Plate part theme strip | `ns.MakePartThemeStrip` PlateThemes.lua:175 | flat | 0 (no callers: dead?) | none |

## Amounts

| id | Control | Builder | Look | Uses | See |
|---|---|---|---|---|---|
| A1 | Slider | `Slider` Options.lua:460 (`kit.Slider`); Backups window | two looks (OptionsSliderTemplate + SkinSlider) | ~227 | gallery |
| A2 | Studio slider with value box | `C.Slider` Studio/Controls.lua:632 | flat 3px track, gold thumb | Studio | gallery |
| A3 | Number box | `line.Box` Options.lua:554 (`BoxLine`); copies: `PercentBox` Options.lua:14194 (5), `TimeBox` ShoulderCam.lua:4254 | two looks (E1), unit after | ~60 | gallery |
| A4 | Style-page flat slider | `rows.Slide` StylePages.lua:3821 | flat 4px track, gold thumb | Look panels | Style Look panels |
| A5 | Sound volume slider | `VolumeSlider` CombatSoundRules.lua:371 | own track, game thumb, no skin | per rule row | Audio (sound rules) |
| A6 | Up/down arrows | `MoveButton` Options.lua:8367 (Arrow-Up/Down 14px); `Arrow` TriggersPage.lua:445 and WheelsPage.lua:303 (chat scroll art 22px); CameraScriptsPage `IconButton` (scrollbar art); GeneralStyle preview (spellbook arrows) | 5 different arts | ~10 | Cameras, Trigger Priority, Wheels, Camera Scripts, Style General |

## Typing

| id | Control | Builder | Look | Uses | See |
|---|---|---|---|---|---|
| E1 | Text box, skinned | `ns.SkinEditBox(InputBoxTemplate)`; local copies: `ListBox` Options.lua:6889, `WordsRow` CardsPage.lua:1625, `Box` CameraScriptsPage.lua:256, `Box` TriggersPage.lua:748, `SkinnedBox` IconBrowser.lua:204, `InputBox` WheelsPage.lua:53, `AddBox` Options.lua:21468 (with hint), `LinkRows` WhatsNew.lua:198 | two looks | ~37 | gallery |
| E2 | Text box, not skinned | EmoteVision.lua:3359 picker search | game | 1 | gallery; emote picker |
| E3 | Search box | SearchBoxTemplate: `CreateSearch` Options.lua:2367 (main search), KeyboardMap, FrameLinks find | game: no HD look | ~8 | gallery; every hub's search |
| E4 | Studio Find box | Studio.lua window, Studio/Controls.lua `ListFrame` | flat | 2 | Style Studio |
| E5 | Multi-line box in a dark well | `CommandBox` WheelsPage.lua:429; share windows | tooltip backdrop | 3 | Your wheels, share windows |

## Color

| id | Control | Builder | Look | Uses | See |
|---|---|---|---|---|---|
| K1 | Palette chip | `palette.Chip` ColorPalette.lua:108 | flat, gold edge when picked | 2 | gallery; color picker |
| K2 | Style swatch | `rows.Swatch` StylePages.lua:3030; same look: `Swatch` Options.lua:14157 | flat 18px, grey border | 18 | Style pages, Nameplate Style marks |
| K3 | Tint / theme swatch | `Swatch` TintStyle.lua:152; `ColorSquare` StyleThemes.lua:1962 (a copy) | flat, black border | 5 | Tint Style, Style Themes |
| K4 | Spell color bar | `Swatch` CombatTextSpells.lua:181 | flat 30x15 | per spell | Combat Text Style > Spells |
| K5 | Studio chips + swatch | `C.Chips` Studio/Controls.lua:787 | C3 + flat 18px swatch | Studio | Style Studio |

## Tabs and chips

| id | Control | Builder | Look | Uses | See |
|---|---|---|---|---|---|
| N1 | Folder tabs | `ns.FolderTabs` Options.lua:10700 | flat, gold top line on the picked tab | ~20 | gallery |
| N2 | Underline tabs | `MakeTab` WhyPanel.lua:808; `TabButton` CooldownGrid.lua:754 | flat, gold 2px underline | 3 | Why showing, Cooldown Manager |
| N3 | Side nav row | Welcome.lua `SettingsPage` nav; Studio `RailItem` Studio.lua:1310; Rule editor `CatButton` RuleEditor.lua:1040 | 3 flat looks | 3 | Welcome Customize, Style Studio, Rule editor |
| N4 | Chips | `MakeChip` WhyPanel.lua:836; `Chip` RuleEditor.lua:1170; `MakeChip` Options.lua:5573 (CineMode, with dot); hub `Chip` StylePages.lua:1765; SelfTextPage status chips | 5 flat looks | ~6 | Why showing, Rule editor, CineMode page, hubs, Self Text Style |
| N5 | Column header button | `Head` CooldownGrid.lua:805 | flat, white underline | 1 | Cooldown Manager |

## Section headers (collapsible)

| id | Control | Builder | Look | Uses | See |
|---|---|---|---|---|---|
| H1 | Camera section band | `CameraSection` Options.lua:6716 | band, +/-, GameFontNormalLarge, Reset/Test B1 | ~6 | Camera Settings |
| H2 | Section band | `SectionBand` Options.lua:9126 | band, +/-, GameFontNormal, 26 high | 3 | Addon Frames, Hover Groups, Addon Links |
| H3 | Addon header | `SuiteHeader` Options.lua:18797 | +/- icon only | 1 | Addon Frames |
| H4 | Emote moment head | `Head` EmoteVision.lua:3924 | band, B1 +, T1, Test | per moment | Emote Vision |
| H5 | Grid section bar | `Title` GridRows.lua:1107 | | 0 (dead path) | none |

## List rows

One look each, drawn by hand; the highlight color differs (white 6-10% or gold 7-10%).

| Rows | Builders |
|---|---|
| Search and find results | `Row` Options.lua:2403, `FindRow` Options.lua:19300 (same), `FindRow` FrameLinks.lua:558, `MakeRow` Find.lua:605 |
| Why rows | `Row` WhyPanel.lua:750, `DetailLine` WhyPanel.lua:648, `ReasonLine` Why.lua:983 (same as DetailLine) |
| Camera rows | `StepRow` CameraScriptsPage.lua:728, `ListRow`:1033, `LinkRow` CameraManager.lua:123, `Row` TriggersPage.lua:213 and :423, `Row` ShoulderCalibrate.lua:476 |
| Page rows | CineMode `MakeRow` Options.lua:5633, key group `MakeRow` Options.lua:19785, `MemberRow` Options.lua:21419, Game Settings `Line` GameSettingsPage.lua:431, Welcome `Option` Welcome.lua:1676, Favorites `Tile` Favorites.lua:463, Wheels `Row` WheelsPage.lua:561, CooldownGrid `Row`:1359 |
| Pickers | Studio list `list.Fill` Studio/Controls.lua:289, spell `Entry` CombatTextSpells.lua:791, spell `MakeLine`:449, Rule editor `SuggRow` RuleEditor.lua:695, Studio changed `Line` Studio.lua:1640 |
| Tables | Profiler `Table` ProfilerPage.lua:458, Damage report `NewRow` DamageReport.lua:222 |

## Other

| Control | Builder | See |
|---|---|---|
| Drag grip | `Grip` Options.lua:13213 | Nameplate Style marks |
| Source mark (dot, diamond, caret) | `Mark` Studio.lua:46 | Style Studio |
| Preview hotspot | `Studio.Hotspots` Studio.lua:883 | Style Studio |
| "Page is off" card | `CreateOffCard` Options.lua:3971 | any hub page that's off |
| Keycap | `MakeKey` KeyboardMap.lua:811 | Keyboard Map |
| Talent node | `NewTalent` TalentCalc.lua:555 | Talent Calculator |
| Scrollbar | `MakeScrollBar` Find.lua:643 (flat) vs SkinScroll everywhere else | Find results |

## Same look, built more than once (merge first)

1. **Segments** (C3, C5): one look, built 4 times (`C.Button` on, `rows.Segments`, CombatTextPage `Cell`, CombatTextSpells `Segment`).
2. **Color swatch** (K1-K5): 6 builders, 4 looks.
3. **Flat tick** (T3): `rows.Toggle` and `C.Switch`, the second a copy. T2's pill is copied by hand in `MakePill`.
4. **Skinned text box** (E1): 8 local builders doing the same thing.
5. **Icon tile** (C10): `CreateTile` and `IconTile` the same. B15: CardsPage and WheelsPage the same.
6. **Underline tabs** (N2): WhyPanel and CooldownGrid.
7. **Result rows**: Options `Row`/`FindRow`, Why `ReasonLine`/`DetailLine`.
8. **Up/down arrows** (A6): 5 arts for one job.
9. **Collapsible headers** (H1-H4): 4 fonts and heights.
10. **Buttons**: 3 families (B1 two-look, B3 Studio flat, B5 Welcome flat), and B2's unskinned ones.

## Never get the HD look (game templates without Skin.lua)

B2 buttons, the UIPanelCloseButton in B6, D3, E2, E3 search boxes, A5, B12.

## Dead code found

`ns.MakePartThemeStrip` (C18) and GridRows' collapsible `Title` path (H5) have no callers.
