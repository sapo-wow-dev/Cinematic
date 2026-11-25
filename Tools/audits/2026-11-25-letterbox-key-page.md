# Letterbox: the key's and Ultra immersive's bars off with the page (fix card)
Fix: the letterbox key and Chat Cam's Ultra immersive brought the bars in with the Letterbox page or Visual Effects off
Found by: audit 2026-11-25 (gating, finding E1 in 2026-11-25-gating-findings.md; the user's call: page off = all off)
Code: Atmosphere/Letterbox.lua: ns.LetterboxExtra, Cinematic_ToggleLetterbox, ns.UpdateLetterbox
Clients: both
Base: baabf86

## Before / after
- Before: Letterbox page off (or Enable Visual Effects off): the letterbox key still brought the bars in and
  said "letterbox bars on"; Chat Cam's Ultra immersive still brought them in, twice as tall, through a talk.
- After: neither brings them in with the page or Visual Effects off; the key says why ("letterbox bars:
  the Letterbox page is off", or "...: Enable Visual Effects is off (Atmosphere > General)"). Bars the key
  brought in go out if the page goes off. Ultra immersive's subtitles (Chat Cam's) still show, low on the
  screen, as they do without bars. A new place's bars: as before (already gated).

## Who relies on the old behavior
(`python -I Tools/audit.py refs Cinematic_ToggleLetterbox ChatCamImmersive`)
- Players: anyone using the key or Ultra immersive with the Letterbox page off. The user's call (E1).
- Other features: Chat Cam's subtitles (placed by the bars' real height: fine without them),
  Dev/WorldViewTest.lua and Dev/LoadPartsTest.lua (the page on there).
- Other addons: none.
- Tests that encode it: letterboxworld.lua (the page on): unchanged.

## States (the matrix)
What brings them in (the key, a new place, Ultra immersive), the Letterbox page, Visual Effects, CineMode; the client.
Test: Tools/offline/letterboxkeymatrix.lua forever
Test: Tools/offline/letterboxkeymatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| letterbox-key-page | source=key page=off effects=on | bars=up said=on | bars=down said=pageOff |
| letterbox-key-page | source=key effects=off | bars=up said=on | bars=down said=effectsOff |
| letterbox-key-page | source=immersive page=off | bars=up | bars=down |
| letterbox-key-page | source=immersive effects=off | bars=up | bars=down |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: the user's call. Two new chat lines (English till the release's translations). Not proven in game:
Ultra immersive with the page off (subtitles without bars).
