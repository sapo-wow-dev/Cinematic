# Emote Vision: its events do nothing while it's off (fix card)
Fix: with Emote Vision off, every aura change on you out of a fight was still read (each buff looked up,
plates walked, a log line), each fight's end scanned up to 80 auras, and each group change read the group
Found by: audit 2026-11-25 (gating, finding D17 in 2026-11-25-gating-findings.md)
Code: Visions/EmoteVision.lua: the watcher's OnEvent
Clients: both
Base: baabf86

## Before / after
- Before: Emote Vision's page off (or held to CineMode out of it): no card can come, but UNIT_AURA ran
  AurasChanged (Buffed for each new buff), PLAYER_REGEN_ENABLED ran ScanOld and LearnEnds, and
  GROUP_ROSTER_UPDATE ran LearnLevels and RosterChanged, as when on.
- After: off, the watcher only keeps the cheap state (loading screen, dead, the once-only setup at
  PLAYER_ENTERING_WORLD) and asks the queue's next card (the campfire cards come anyway); back on, it
  learns your auras, the group and its levels again quietly first, so nothing old reads as new.

## Who relies on the old behavior
(`python -I Tools/audit.py refs AurasChanged ScanOld LearnEnds LearnLevels RosterChanged emoteVision`)
- Players: nothing on screen: every card these lead to was gated on emoteVision already (FireFor). A
  group joined while off isn't greeted as it comes back on (RosterChanged(true) learns it quietly), as
  before a buff cast while off isn't thanked later.
- Other features: the campfire cards (anyMode, outside CineMode too) come through ns.Listen, not this
  watcher; the queue's Next on stopping and at a fight's end is kept for them.
- Other addons: none.
- Tests that encode it: emote offline checks (Tools/offline/emote*.lua): run, unchanged.

## States (the matrix)
Emote Vision on, off, off then on again; the event (an aura change, a fight's end, the group changing).
Test: Tools/offline/emoteeventsmatrix.lua forever
Test: Tools/offline/emoteeventsmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| emote-events | vision=off | read=yes | read=no |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: Emote Vision on runs as before. Not proven offline: the Eyes/Stalked watches stopping live (WatchGaze
cancels its own ticker when off; the stalk list is cleared once as it goes off), a resurrection offered
while off then the vision on (no thank-you card: the offer wasn't kept).
