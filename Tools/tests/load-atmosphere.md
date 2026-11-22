# Load Atmosphere: test ledger
Goal: unticking Atmosphere > General's Load Atmosphere keeps Atmosphere's code from running after a reload (the tint, the letterbox bars, edge haze, Graphics+ writing the game's settings, Cinematic's music) and every place it shows gone (the hub's Tint, Letterbox, Graphics Boost and Audio pages, the Style hub's Tint and Letterbox pages, the Welcome window's Letterbox, Tint and Audio, the letterbox key's row, the Why tab's rows), the rest of the addon works, the settings stay, Graphics+'s values go back to the game's as it's unticked, and ticking it brings it all back. Same rule as Visions (user, 2026-11-21): all of it, front end and back end.
Code: Modules.lua (atmosphere part, stand-ins, ON_LEAVE), Atmosphere/Music.lua + Atmosphere/Letterbox.lua (out of Effects.lua; the bars' drawing stays there for Combat Vision and the Style previews), Atmosphere/Tint.lua (vignette, gradient and clock helpers loaded, ns.TintParts; the tint gated), Visions/TimeOfDay.lua (time title and cards, out of Tint.lua: Visions), Atmosphere/Focus.lua, Graphics.lua (GRAPHICS_PLUS list loaded), Style/LetterboxStyle.lua (effect pages gated), Atmosphere/DeathVision.lua (no tint frame: level 0), Core.lua (switches left out), Options.lua (Effects page box; other pages, Tint Style, Letterbox Style, key row), UI/WhyFeatures.lua, Profiles/Welcome.lua, ShowMe.lua, ProfileChoices.lua (Auto-Hide UI and Blank Slate leave it out), Slash.lua, Dev/DemoHub.lua, Dev/LoadPartsTest.lua.

## Questions
| # | Question | Client | Answer | From |
|---|----------|--------|--------|------|
| Q1 | Code at ADDON_LOADED, secure buttons made then | forever | YES (rules) | load-visions.md |
| Q2 | Atmosphere off: no tint, letterbox or haze frame, 0 errors in play, memory saved? | forever | YES: CinematicTint, CinematicLetterbox, CinematicFocus never made; 0 errors, 0 blocked; all four parts off: 14.6 MB less, 6,934 frames fewer | run 1 step 4 |
| Q3 | Atmosphere off: Graphics Boost's values put back, your music volume untouched? | forever | YES (none left written; volume 0.400 both ways) | run 1 step 4 |
| Q4 | Effects page in the menu: its Load box, no off card (shot) | forever | YES: as Camera > General (WoWScrnShot_112226_014552) | run 1 step 4 |
| Q5 | Back on: tint, bars and haze made again, setting kept | forever | YES | run 1 step 5 |
| Q6 | Visions on, Atmosphere off: Death Vision and the time-of-day title work | forever | offline only (modules.lua atmosphere: 0 errors in the event storm) | modules.lua |

## Plan tree (step 3)
Q2 an error -> its deverror line names the call: a stand-in missing in Modules.lua.

## Runs
| Run | Date | Command | Answered | Still open, and why this run couldn't |
|-----|------|---------|----------|---------------------------------------|
| 1 | 2026-11-22 | /cine debug loadparts | Q2-Q5: 105 PASS 0 FAIL, 0 errors, 0 blocked; one Reload box naming all four each time | Q6 in game (Visions on, Atmosphere off): offline only |

Done: Q2-Q5 in 1 run.
