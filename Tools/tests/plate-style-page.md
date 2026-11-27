# Nameplate Style's Default tab, rebuilt: plan + test ledger
Goal: the page players see first shows the game's own nameplate (as the Look panels and Combat Text now do), with
the theme pick and Customize up front instead of a wall of theme tiles and a button at the bottom.
Code: Options.lua (the Default tab: the 4-plate preview ~12640-12990, Plate theme + Customize ~13002-13040),
Plates/PlateCopy.lua, Plates/PlateThemes.lua (ns.MakePartThemeStrip, ns.PlateThemeList), Plates/PlateRowLook.lua.
Builds on: Tools/tests/plate-preview-match.md (the game plate copy, proven on Forever 2026-11-23).

## What's there today (user, 2026-11-23: "I don't like how we show all the themes and the customize button is
## hidden at the bottom")
- A hand-drawn preview: four small drawn plates (Hostile, Neutral, Friendly, Player) dressed as the picked Smart
  Style row (the grid's Look buttons and plate clicks pick it; a grid row hovered lights its plate), all four always
  casting the same yellow bar, health moving, the row's opacity and width moved to.
- Under it, every plate theme as a tile (16+, ns.MakePartThemeStrip), a note on the pick, then Customize (opens the
  Default row's Look panel).

## The plan
1. The preview on the game's plate. Four ns.MakeGamePlate copies, one per unit kind, closer together and a bit
   larger, each dressed by the real-plate code for the picked row (ns.StylePlateBar with the row's look, the name
   look, the cast style), the row's mark (target arrow) on each. Kept from today: Pick(id) / Hover(id) / a plate
   clicked opens its row, the row's colors where it paints the bar / name / border, its opacity and width (Forever:
   the width the client takes), the gentle health movement (the bar's value). Retail and a failed build: today's
   drawn plates (as the other previews).
2. One State dropdown under the four (the same list as the Look panel's: Target, Focus, Casting, Can't interrupt,
   Marker, Elite, Aggro, Debuffs), on all four at once; starts with Casting. Kept with the Look panels' pick.
3. Plate theme, under the preview, one row (user's pick, 2026-11-23): a Theme dropdown (each entry its name and its
   bar swatch, the current one ticked; Follow General first) and Customize beside it, then the one-line note. The
   tile grid goes from this page. Pointing at an entry shows it on the preview before you pick (the "Preview: not
   saved" way the Look panel does: entry:SetOnEnter / SetOnLeave), the pick on click.
4. Name Style has the same tile wall for name themes (Options.lua ~11915): same change there? The user's call
   (asked after this lands).

## Tests
- Offline: Tools/offline/gameplate.lua grows a case for the 4-plate preview (four copies, dressed through the real
  code, Pick/Hover, the State dropdown on all four, retail and failure keep the drawn plates); a check that the
  theme dropdown lists every theme (ns.PlateThemeList) and picking one sets plateTheme and refreshes; the page
  builds in tools/offline lazyaudit and modules.
- In game: extend /cine debug platematch (kit) with a step that opens Nameplate Style (ns.OpenOptions) in its
  states (page switch on and off; Style loaded): the four game plates shown, each state through the dropdown (one
  shot per state, preview on screen), the Theme dropdown and Customize visible near the top with r:Overlaps on
  both, a theme picked through the dropdown and seen on the preview (shot), Customize opens the Look panel; a grid
  row's Look button picks its row on the preview. Hands off. The earlier steps stay proven.

## Built (2026-11-23, uncommitted)
- Options.lua: the Default tab's preview draws four ns.MakeGamePlate copies when all four build (else the drawn
  plates), dressed by ns.DressGamePlateForRow; click / hover / opacity / width / health kept; a State list at its
  bottom-left (250 tall where the game's plates can stand in). Theme list (ns.MakePlateThemeDropdown) and Customize
  on one row under the preview, the note under them; the tiles only without the dropdown template.
- PlateThemes.lua: PlateThemeNow/Bar/Extras take a theme key (a preview's pointed-at theme); MakePlateThemeDropdown.
- PlateHealthStyle.lua: ns.StylePlateBar(plate, look, theme): a preview plate can carry that theme.
- PlateRowLook.lua: ns.MakePlateStateDropdown (shared with the Look panel preview), ns.PlatePreviewStates,
  ns.TogglePlatePreviewState, ns.DressGamePlateForRow.
- Offline: Tools/offline/gameplate.lua (the page built: four game plates dressed through the real code, State list,
  a theme pointed at not saved, the Theme list's 20 entries, a pick saved and the plates refreshed, the row of
  Theme + Customize) and Tools/offline/platematch.lua (the new stylepage step). Style demos, lazyaudit both
  clients, platecopyevents: pass.

## Run 1 (handed over 2026-11-23): `/cine debug platematch`, the stylepage step new, hands off

## Crowd control and timers (2026-11-23, user: a Forest Spider's plate showed a root, 10, right of the level box)
- That's the game's CrowdControlListFrame (auras C_Spell.IsSpellCrowdControl; enemy NPCs, per the aura display
  CVar; NPCs never show the loss of control slot). The preview hid it (debuffs only). Added: a "Crowd control"
  state (a root in that row), and every fake aura now has a duration and a time left (the game counts down auras of
  a minute or less), renewed before running out. Offline checks: each list filled on its own, timed, renewed.

## What else the game's plate draws that the preview doesn't (audit of Forever's code, 2026-11-23)
From the game's own option lists (NamePlateConstantsDocumentation) and Blizzard_NamePlates / CompactUnitFrame:
| Part | Game's option / trigger | Preview now |
|---|---|---|
| Health text: % and/or value on the bar | Info display: Current Health Percent / Value (healthBar LeftText/RightText) | no |
| Cast target name beside the spell | Cast bar display: Spell Target (CastTargetNameText) | no (pretend cast has none) |
| Important cast glow | Cast bar display: Highlight Important Casts (ImportantCastIndicator) | no |
| "You're its target" glow on the cast | Cast bar display: Highlight When Cast Target (CastTargetIndicator) | no |
| Channel, interrupted ("Interrupted"), failed casts | cast bar's own states | no (cast and can't-interrupt only) |
| Rare, rare elite, world boss marks | Info display: Rarity Icon (star, silver, gold) | elite only |
| Threat: progressive glow, flash, or health bar in threat color | Threat display: Progressive / Flash / Health Bar Color | the red glow only |
| Grey bar for a mob tapped by others | CompactUnitFrame tap-denied | no |
| Skull for a much higher level / boss | level box highLevelTexture | no |
| Smaller "simplified" plates (minions, minor mobs, friendly players/NPCs) | Simplified types | no |
| Interact / quest icon over the plate (your soft target) | SoftTargetFrame icon (the game's cursor icon; Forever's quest "!") | no |
| Off-screen arrow icon | behindCameraIcon | no (hidden on purpose) |
| Shields and incoming heals on the bar | heal prediction / absorb pieces | no (hidden on purpose) |
| PvP marks (flag carrier...) | PvP classification, battlegrounds only | no |
| Widgets (progress bars some NPCs carry) | WidgetContainer | no |
| Plate style (Modern, Thin, Block, Health/Cast focus, Legacy, Classic) | nameplateStyle | YES, by itself (laid out from the live options) |

## The batch, built (2026-11-23, user: "add the batch"), uncommitted
All through the game's own code (read in the Forever export), each as your game settings show it:
- Health text: the copy's bar has a real-looking total (2400); the game's own UpdateTextDisplay shows percent and/or
  value as your Info display setting says. No state: always as a real plate.
- Cast: Channeling (SimulateCast channel, draining as the bar's OnUpdate runs a channel), Interrupted (cast, then
  the bar's own HandleInterruptOrSpellFailed 1.2 s in, every 3.5 s), Important cast and Casting at you (the cast's
  own flags: the glows and your name as its target, as your cast bar settings show them).
- Rank: Elite, Rare, Rare elite, Boss (one at a time; the game's marks as your Rarity icon setting shows them; a
  boss: the skull in the level box).
- Threat: Aggro and Pulling threat (explicit threat 3 / 1, the game's own pieces: the glow with Progressive, the
  flash with Flash, the bar in the threat color with Health Bar Color; enemies only, as the game).
- Tapped (the game's grey), Quest giver (the soft target's quest icon, as your soft target icon settings show it).
- The State list grouped: Selected, Cast, Rank, Threat, More; either/or sets kept one at a time; cast details turn
  Casting on, Casting off takes them off.
- Test: each state checked against what your settings say should show (a part your settings hide counts right
  when it's absent); the preview and page steps lost their proven mark (their code changed); compare stays proven.
- Offline: gameplate.lua checks every new part (each game call, the threat colors, the either/or sets, the
  interrupted loop on pretend time); platematch.lua runs the test with the plates' update loops driven.

## Run 11 (2026-11-23 08:10): 66 pass, 4 fail
- Fails: "Casting at you" glow never on (the cast bar's highlightWhenCastTarget flag unset: its setter reads the
  unit; now set from your setting) and Tapped (the grey was there, 0.8999 read as a float: the test now compares
  with a tolerance), each on both previews.
- The user: the page's lower plates sat on the State list (now placed by their bottoms, clear of it), and the crowd
  control row overlapped the level box (the game places it right of the box in its layout; laid out before the
  box showed: UpdateControlAnchors again when the box is shown; rule forever.plate.crowd-control-row).
- Shots: every state right but Interrupted (shot after the game's fade: the test now times it to the next cut).
  Aggro, Pulling threat and Quest giver show nothing with your threat and soft target icon settings: right.

## Run 12 (2026-11-23 08:21): 70 pass, 0 fail
- Every state on both previews as your settings draw it, the cast glows, the tapped grey, Interrupted caught in
  its shot, the crowd control row right of the level box. The user: the page's upper row's debuffs cut off at its
  top. Fixed: the page preview 300 tall (was 250), rows 104 apart; the test now checks the debuff row's top inside
  the preview on both previews (offline: skipped, no real layout).
- Run 13 (2026-11-23): 71/1. The 300 never took: the shared fitter (StylePages.lua FitPreview) sizes every
  preview to the screen's shape, ~201 tall on a 3440x1440 screen, so the upper row's debuffs ran 32 over the top
  (the new check caught it). The user also asked for the State list outside the preview. Fixed: FitPreview keeps a
  preview's minHeight (230 here); the State list on its own row under the preview; the plates lower (LOW 10) and
  not zoomed by the fitter (noAutoFit in game mode). The test checks the State list sits under the preview.
- Run 14 (2026-11-23): 72/0, the debuffs inside; the user: the right column's crowd control icons cut off at the
  preview's right edge (a plate's CC sits right of its level box, ~180 past the frame's middle vs ~104 left of it),
  and "this test testing everything is costing me a lot of time". Fixed: the columns centered on a plate's whole
  width (GAME_W 290, SHIFT 38); a CC-inside check for plates 2 and 4. Proven and left out of a plain run: the
  preview and page steps, the page's off pass, theme hover, Customize and 17 of its 19 states (debuffs and crowd
  control stay: they reach past the plate). Offline platematch now runs a plain pass too.
- Run 15 (2026-11-23): the user, before reading it: "make the previewer just one big plate but add the dropdown
  for unit back ... the same previewer in both here and the style panel". Built: the page's preview holds the
  Look panel's previewer (ns.MakePlateRowLookPreview, all points on the preview): one game plate, scale up to 1.6
  (fits its debuffs under the top and its whole width, CC included, 38 right of its frame's middle), its own Unit
  and State lists and Scene pill; the four plates, the State row under the preview and the backdrop button gone
  on Forever (retail keeps the drawn plates). The previewer takes holder.kind (the grid's picked row),
  hoverTheme (the Theme list's pointed-at theme), gameScale and gameShift. The test: each unit with casting,
  debuffs and crowd control checked inside the preview, the lists covering nothing, the theme on the previewer.
- Run 16 (2026-11-23): 14/0, plain run ~17 s. The page preview 606 x 201, the plate at 1.6; all four units'
  debuffs (top 742 of 761) and crowd control (right 1811 of 1887) inside; the Unit and State lists cover nothing;
  the theme hover on the previewer with its "Preview: not saved". Shots clean. Only fix: the step's title.
- Full run (2026-11-23): `/cine debug platematch full`, 81/0/0, 53 shots, no errors. Every step and state on the
  page's previewer as your settings draw it (interrupted, marker, boss shots looked at); the compare step too.
- After it, the user: "its not really centered". The plate sat 38 left for its crowd control icon; centered on
  its bar now (as the game's), the scale kept so the icon (180 right of the middle) still fits. Plain run to confirm.
- Run 17 (2026-11-23): 14/0, centered on its bar; committed bdc70d4. Then the user: "center this better" (the
  plate sat low, the room over it empty) and, on the Look panel, "give more space" (its debuffs touched the top).
  Fixed: the page's plate body (cast bar to name, 0-58.3) in the middle of the room over its lists, scale to fit
  its debuffs (to 89.1) under the top, minHeight 240 so 1.6 still fits on an ultrawide; the Look panel's previewer
  18 over its debuffs (height plateLift + 89 + 18; was the frame's 85 + 6).
- Run 18 (2026-11-23): `platematch 2 4`, 53/0. The Look panel's debuffs 18 under its top. The page's plate was
  centered on cast bar to name, so with debuffs on they filled the top (4 from it) and left a gap under the cast.
  Fixed: centered on what it shows, to its debuffs' top when they're on (it moves as Debuffs is ticked; the
  previewer's own State list now redraws the page, holder.onStates), scale fit for debuffs, minHeight 210.
- Run 19 (2026-11-23): 14/0, the preview 607 x 210 at 1.6; debuffs 13 under the top on every unit; shots: centered
  with debuffs on (debuffs to cast bar) and with Casting only (name to cast bar).

## Questions
| # | Question | Answer | From |
|---|----------|--------|------|
| Q1 | Several game plate copies at once: any cost or clash (four from one template, each Quiet)? | open (one per preview so far) | run |
| Q2 | Can a dropdown entry's hover drive the preview (the Look panel's "not saved" preview)? | YES: menu entries take SetOnEnter / SetOnLeave (Blizzard_Menu/Menu.lua:758, MenuTemplates.lua:341) | game source, Forever export |
| Q3 | Layout tab: an arrow nudge, the options left open, a fight: do movement and casting keys reach the game in it (the key frame hidden on PLAYER_REGEN_DISABLED), and do the arrows nudge again after? Does a held arrow still repeat-nudge? | open | Tools/audits/2026-11-25-plate-layout-fight-keys.md |
| Q4 | A layout saved, Nameplate Style off, /reload, then Nameplate Style on: do live plates take the layout within a second (and let go within a second when turned off)? | open | Tools/audits/2026-11-25-plate-layout-switch-back.md |
| Q5 | Cast bars tab: pointing at Look from's "Its own look" (not clicked): the preview stays as saved and plateCastStarted_PLATE stays unset? | open | Tools/audits/2026-11-25-style-editor-hover.md |

## Runs
| Run | Date | Command | Answered | Still open |
|-----|------|---------|----------|------------|
