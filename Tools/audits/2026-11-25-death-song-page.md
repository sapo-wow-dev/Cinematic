# Audio: the death song off with the Audio page (fix card)
Fix: the death song played with the Audio page or Visual Effects off whenever your game music was on
Found by: audit 2026-11-25 (gating, finding E2 in 2026-11-25-gating-findings.md; the user's call: page off = all off)
Code: Atmosphere/Music.lua: ns.SetDeathSong
Clients: both
Base: baabf86

## Before / after
- Before: Audio page off (or Visual Effects off), the Death event's song ticked, game music on: dying played
  the song (PlayMusic, your volume written) as if the page were on. With game music off it didn't.
- After: no song with the page or Visual Effects off, game music on or off. The page on: as before (with
  game music off it's switched on for the song and put back after).

## Who relies on the old behavior
(`python -I Tools/audit.py refs SetDeathSong`)
- Players: anyone with the Audio page off who liked the death song. The user's call (E2).
- Other features: Death Vision's camera calls ns.SetDeathSong; the death test's log line (now says
  "CineMode music off: no song").
- Other addons: none.
- Tests that encode it: modules.lua (stand-ins only): unchanged.

## States (the matrix)
The Audio page, Visual Effects, game music on or off; the client.
Test: Tools/offline/deathsongpagematrix.lua forever
Test: Tools/offline/deathsongpagematrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| deathsong-page | page=off music=on | song=plays | song=none |
| deathsong-page | effects=off music=on | song=plays | song=none |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: the user's call. Not proven in game: dying with the page off and music on.
