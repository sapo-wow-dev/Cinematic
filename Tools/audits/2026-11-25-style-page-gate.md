# Style: the Visions' and Atmosphere's Style pages go off with Enable Style (fix card)
Fix: with Style left out or Enable Style off, Tint Style's zone tints, presets and day phases and Emote Vision Style's card size and spot still applied
Found by: audit 2026-11-25 (gating, finding C9 in 2026-11-25-gating-findings.md)
Code: Core.lua: PAGE_SWITCH (styleGeneral's list); Atmosphere/Tint.lua: Look; Visions/EmoteVision.lua: Look
Clients: both
Base: baabf86

## Before / after
- Before: ten Style hub pages had no switch over them: Text on You, Damage, Vitals, Quest (talk), Quest Item,
  Roll, Emote, Tint, Letterbox and Weather. ns.Setting and ns.PageOn read them on with Enable Style off or Style
  left out (only ns.StyleOn knew). Two readers went by them: the Tint Style page's own zone tints, zone presets,
  day phases and clock kept applying, and Emote Vision Style's card look, face, size and spot (ns.EmoteOpt) too.
  Their Enable Page boxes didn't grey with Enable Style off, unlike every other Style page's.
- After: all ten under Enable Style, as the other Style pages. Enable Style off or Style left out: the tint goes
  by its built-in moods and main preset, the emote card by its starting look, size and spot; the pages' Enable
  Page boxes grey with Enable Style. Saved settings kept: on again, all as it was.
  (The finding's targetArrowStyle and questTalkStyle are values, not page switches: Quest Talk's switch is
  questTalkStyled; the target arrow has no page of its own. Not added.)

## Who relies on the old behavior
(`python -I Tools/audit.py refs tintStyle emoteStyle` and each key's grep.)
- Players: those with Enable Style off (or Style unticked in Load) who set zone tints or moved the emote card:
  now the defaults, as every other Style page's look with Enable Style off.
- Other features: the other eight keys were only read through ns.StyleOn / ns.StyleLook (already right). The
  Tint Style page (TintStyle.lua's ns.PageOn dimming) and the Emote Style tiles' alpha now dim with Enable Style
  off too. Tab mappings (Options.lua MapTabContainers) walk the chain up: these pages' tabs' settings stay
  under their tabs.
- Other addons: none.
- Tests that encode it: emote/tint offline tests run with Enable Style on (the default): unchanged.

## States (the matrix)
Every part loaded or Style or Visions left out; Enable Style on or off; each page's switch, plus the player
view (Tint's own zone tint, Emote's card size).
Test: Tools/offline/stylepagegatematrix.lua forever
Test: Tools/offline/stylepagegatematrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| style-page-gate | enableStyle=off key=selfTextStyle | * | off |
| style-page-gate | enableStyle=off key=damageVisionLook | * | off |
| style-page-gate | enableStyle=off key=lowHealthStyle | * | off |
| style-page-gate | enableStyle=off key=questTalkStyled | * | off |
| style-page-gate | enableStyle=off key=questItemStyle | * | off |
| style-page-gate | enableStyle=off key=rollStyle | * | off |
| style-page-gate | enableStyle=off key=emoteStyle | * | off |
| style-page-gate | enableStyle=off key=tintStyle | * | off |
| style-page-gate | enableStyle=off key=letterboxStyle | * | off |
| style-page-gate | enableStyle=off key=weatherStyle | * | off |
| style-page-gate | load=style key=selfTextStyle | * | off |
| style-page-gate | load=style key=damageVisionLook | * | off |
| style-page-gate | load=style key=lowHealthStyle | * | off |
| style-page-gate | load=style key=questTalkStyled | * | off |
| style-page-gate | load=style key=questItemStyle | * | off |
| style-page-gate | load=style key=rollStyle | * | off |
| style-page-gate | load=style key=emoteStyle | * | off |
| style-page-gate | load=style key=tintStyle | * | off |
| style-page-gate | load=style key=letterboxStyle | * | off |
| style-page-gate | load=style key=weatherStyle | * | off |
| style-page-gate | enableStyle=off key=tintLook | yours | plain |
| style-page-gate | load=style key=tintLook | yours | plain |
| style-page-gate | load=all enableStyle=off key=emoteLook | yours | default |
| style-page-gate | load=style key=emoteLook | yours | default |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| Tools/offline/atmopreview.lua | the tint lift checks (a "warm" preset set with Enable Style off) | the preset applied | ignored, the default ran (Lua error on the stand-in's clock); setup now turns Enable Style and Tint Style on, passes | yes, the user 2026-11-25 ("Yes, edit it") |

## Risk
low: Enable Style is on for nearly everyone; with it off, two looks now go to their defaults as every other
Style page's already did. Not proven in game: the tint's live change as Enable Style flips (the tint's loop
reads Look() on its next pass), and the emote card's spot moving back on its next card.
