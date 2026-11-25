# Cards: the Sleeping bag line reads your auras only while it can show (fix card)
Fix: on Forever, every aura change on you out of a fight read the bag's two auras and built a log line, with
the Sleeping bag row and the camp timer both off
Found by: audit 2026-11-25 (gating, finding D20 in 2026-11-25-gating-findings.md)
Code: Visions/SleepingBag.lua: the watcher's OnEvent, BagWanted and catchUp (new)
Clients: forever (retail: no bag, unchanged)
Base: baabf86

## Before / after
- Before: Cards off (or its Sleeping bag row off) and Emote Vision's camp timer off: each UNIT_AURA still
  read Resting and Well-Rested and formatted the "in bag ..." line.
- After: nothing read while neither can show; as one comes on, the bag is read once (within half a
  second, not at the next aura change), then only on aura changes as before. Off, the bag counts as left,
  so its frame doesn't stay up updating.

## Who relies on the old behavior
(`python -I Tools/audit.py refs CampTimerOn sleepBag cardSleepBagOn`)
- Players: the bag line and the camp timer show as before while on; turned on while lying in the bag, the
  line now comes at once (before: at the next aura change).
- Other features: the Unroll Bag cast (learning the Resting aura) still watched; the page's Test unchanged.
- Other addons: none.
- Tests that encode it: none on the bag's reads.

## States (the matrix)
The Sleeping bag row on or off, the camp timer on or off; an aura change, or one of them coming on.
Test: Tools/offline/sleepbagreadmatrix.lua forever
(Retail: run by hand, `run.py ... retail`: no bag, every cell read=no, unchanged.)

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| sleep-bag-reads | client=forever row=off camp=off next=aura | read=yes | read=no |
| sleep-bag-reads | client=forever next=turnedOn row=on | read=no | read=yes |
| sleep-bag-reads | client=forever next=turnedOn row=off camp=on | read=no | read=yes |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: Forever only; a catch-up loop that's on only between an aura change skipped while off and the row or
timer coming back. Not proven in game: a real stay in the bag with the row toggled live.
