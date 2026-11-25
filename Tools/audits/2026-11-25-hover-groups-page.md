# Hover Groups: the page off turns the groups off, their events too (fix card)
Fix: the Hover Groups page off only stopped hovering; the groups' events (chat, whisper, typing, aura, ping, tracking, quest, roster, gamepad, cooldown), their reach and the Death Cam's kept groups still brought their members up
Found by: audit 2026-11-25 (gating, finding E3 in 2026-11-25-gating-findings.md; the user's call: page off = all off)
Code: Frames.lua: ns.UpdateFrames (hoverGroups, deathKept)
Clients: both
Base: baabf86

## Before / after
- Before: the Hover Groups page switched off. Hovering a faded frame brought nothing up, but a chat
  message still brought up the frames of a group with Chat message ticked (the minimap, say), a new buff
  those with New buff, and so on; the Death Cam kept its picked groups up.
- After: with the page off no group does anything: each frame shows only as its own row says. Hovering
  and the groups' events come back with the page.

## Who relies on the old behavior
(`python -I Tools/audit.py refs GetHoverGroups HoverGroupReach deathKeepGroups mouseover`)
- Players: anyone who switched the page off to stop the mouse but kept event groups: they now need it on
  (the user's decision, audit 2026-11-25).
- Other features: the Death Cam's Keep up groups (off with the page), unit frame parts per group
  (SetUnitPartsOff: no groups, every part as its row says), the default groups' Gamepad and Cooldown
  triggers. The groups' own frames' rows (chat by chat, buffs by peeks) still come up on their own.
- Other addons: none.
- Tests that encode it: hovermatrix, chatbgsettle (page off there, nothing hovered): PASS both clients.

## States (the matrix)
The page on or off; a chat window peeking or not (an event a group has ticked); a frames pass in CineMode.
Test: Tools/offline/hoverpagematrix.lua forever
Test: Tools/offline/hoverpagematrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| hover-groups-page | page=off event=chat | groups=1 up=1 reach=1 | groups=0 up=0 reach=0 |
| hover-groups-page | page=off event=none | groups=1 up=0 reach=1 | groups=0 up=0 reach=0 |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
medium: a real behavior change for players with the page off and event groups set (decided by the
user). True with the page on (its default). Not proven offline: the Death Cam's kept groups with the page
off, a unit frame's parts coming back when the groups go.
