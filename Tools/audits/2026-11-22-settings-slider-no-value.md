# Settings: a slider with no value saved (fix card, retroactive)
Fix: a slider whose setting had no number saved (a setting added since, a profile without it, a broken profile's text
or tick) errored "arithmetic on nil" in its Refresh, which broke the whole page's Refresh.
Found by: audit 2026-11-22; fixed in bdb2e1d
Code: Options.lua: Slider (slider.Refresh)
Clients: both
Base: bdb2e1d^

## Before / after
- Before: opening a page (or loading a profile) with such a slider gave a Lua error and the rest of the page wasn't
  refreshed.
- After: the slider shows its setting's default, or its lowest value without one; nothing is saved by showing it.

## Who relies on the old behavior
(`python -I Tools/audit.py refs slider.Refresh settingKey`)
- Players: none rely on the error. A number saved as text ("5") showed as that number before (Lua's coercion) and
  still does.
- Other features: every options page's Refresh; Camera/CameraManager.lua and Options.lua read settingKey (unchanged).
- Other addons: none.
- Tests that encode it: Tools/offline/auditsettings.lua check 4 (kept).

## States (the matrix)
what's saved (a number / a number in text / nothing / other text / a tick) x the setting has a default or none, per
client. 10 cells. Only a key slider (not a get/set table slider: same branch, the default skipped).
Test: Tools/offline/slidermatrix.lua forever
Test: Tools/offline/slidermatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| slider-refresh | saved=nothing default=has | error | default |
| slider-refresh | saved=text default=has | error | default |
| slider-refresh | saved=tick default=has | error | default |
| slider-refresh | saved=nothing default=none | error | least |
| slider-refresh | saved=text default=none | error | least |
| slider-refresh | saved=tick default=none | error | least |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none (retroactive card) | | | | |

## Risk
low: retroactive. Not proven offline: the slider's real clamping to its range (the stand-in doesn't clamp).

## Open (user's call)
- `saved=text|tick`: pinned "default" (else "least"), as for nothing saved. The value stays bad in the saved settings
  until the slider is moved; whether Refresh should also write the default back is the user's call (pinned: no).
