# Atmosphere: the view distance's ticker and the music's watch idle when off (fix card)
Fix: the bad-weather view distance looked every second for everyone (slider at 0 or its page off), and the music's watch on the game's music settings did its full work (a debugstack each) with the Audio page off
Found by: audit 2026-11-25 (gating, finding D15: Graphics' 1 s ticker, Music's CVar hooks)
Code: Graphics.lua: the bad weather view distance's loop, ns.PreviewRainView; Atmosphere/Music.lua: ns.musicKeep.Idle, TraceMusicWrite, the CVAR_UPDATE trace, MusicSwitchedByPlayer
Clients: both
Base: baabf86

## Before / after
- Before: a game timer once a second, always, to look at the bad weather view distance; each change to the
  music volume or its on/off (yours, the game's, another addon's) read who made it, with the Audio page off.
- After: the view distance's look runs only while it can bring the view in (slider up, CineMode, bad
  weather, the page on), while it's still in or coming back out, or while the page's Preview runs. The
  music's watch returns first thing with the page (or Visual Effects) off and nothing of the music held (no
  fade of ours, no setting of yours held, no death song). Nothing a player sees changes.

## Who relies on the old behavior
(`python -I Tools/audit.py refs rainViewScale PreviewRainView musicKeep`)
- Players: none (cost only). The "music volume set ... from outside Cinematic" log line isn't written with
  the Audio page off any more (nothing of ours touches the music then).
- Other features: /cine debug viewdist (ns.RainViewDebug, unchanged), the Weather page's Preview (wakes the
  loop), /cine debug music (the page on: unchanged).
- Other addons: none.
- Tests that encode it: musicvolume.lua (the page on), atmopreview.lua: unchanged.

## States (the matrix)
View distance: slider 0 or up, CineMode, rain, and before: nothing, already in, a Preview. Music: the Audio
page, Visual Effects, music handled or held or not, a volume or on/off write or CVAR_UPDATE. The client.
Test: Tools/offline/rainviewloopmatrix.lua forever
Test: Tools/offline/rainviewloopmatrix.lua retail
Test: Tools/offline/musichooksmatrix.lua forever
Test: Tools/offline/musichooksmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| rainview-loop | before=none | loop=on view=yours | loop=off view=yours |
| rainview-loop | before=preview | loop=on view=yours | loop=off view=yours |
| music-hooks | page=off handling=no | work=yes | work=no |
| music-hooks | effects=off handling=no | work=yes | work=no |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: the view distance's loop is woken within a second by the loops' look (its step is 1 s anyway). Not
proven in game: rain starting in CineMode with the slider up (the view coming in), the Preview ending.
