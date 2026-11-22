# Load Style: test ledger
Goal: unticking Style > General's Load Style keeps Style's code from running after a reload (Style/ but its toolkit, the nameplate looks: themes, every Style page, the looks they set on the game's frames, plates and our Visions) and every place it shows gone (the Style hub's pages, Visions' and Atmosphere's Style tabs, the Welcome window's Themes), the rest of the addon works with the game's look, the Style settings stay, and ticking it brings it all back. Same rule as Visions (user, 2026-11-21): all of it, front end and back end.
Code: Modules.lua (style part, stand-ins), Style/*.lua (ns.Module "style" but StyleFonts, StylePages, ColorPalette: the toolkit every page uses), Style/LetterboxStyle.lua (its Atmosphere effect pages loaded, the Letterbox Style page gated), Style/RollStyle.lua (RollTabs loaded), Plates/PlateThemes, NameThemes, PlateRowLook (gated), Plates/NameRowLook (loaded: plates draw names by it), Style/StylePages.lua (StyleOn off when left out; no Style link on a tab row), Core.lua (styleGeneral left out, combat text CVar set, blank world font), Plates/PlateParts + PlateGuild (StyleOn for the Style font), Support/DaylightUI.lua (blank font check), Options.lua (Style General page left out; Name Style, Nameplate Style, Tint Style, Card Styles, Vitals Style, Damage Vision Look, Emote Vision Style gated; Letterbox page apart from its Style page), Profiles/Welcome.lua (Themes), Dev/LoadPartsTest.lua.

## Questions
| # | Question | Client | Answer | From |
|---|----------|--------|--------|------|
| Q1 | Code at ADDON_LOADED, secure buttons made then | forever | YES (rules addon.addon-loaded.handlers-in-register-order, addon.secure-buttons-made-at-addon-loaded) | load-visions.md |
| Q2 | Style off: none of its code, 0 errors in play (plates, unit frames, bubbles, Visions' panels go through stand-ins or read Style off), memory saved? | forever | YES: 0 errors in 8 s of play; all three parts off: 27.7 MB less (61.0 to 33.2), 6,846 frames fewer | run 1 step 4 |
| Q3 | Style off: our menus and the game's frames draw plain (no theme), the Atmosphere Letterbox and Tint pages still there? | forever | YES: the game's own player frame and action bars (gryphons), no theme (WoWScrnShot_112226_005505) | run 1 step 4 |
| Q4 | Settings kept off and back (abSlots, in the profile)? | forever | YES (abSlots kept, in the profile, back) | run 1 steps 4, 5 |

## Plan tree (step 3)
Q2 an error -> its deverror line names the call: a stand-in or StyleOn, the confirm run.

## Runs
| Run | Date | Command | Answered | Still open, and why this run couldn't |
|-----|------|---------|----------|---------------------------------------|
| 1 | 2026-11-22 | /cine debug loadparts | Q2-Q4: 73 PASS 0 FAIL, 0 errors, 0 blocked; one Reload box naming all three each time | none |

Done: every question answered in 1 run.
