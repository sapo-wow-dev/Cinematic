# Visions: time-of-day test commands with Visions left out (fix card)
Fix: /cine tinttest and /cine timetest all threw a Lua error per phase with Visions left out
Found by: audit 2026-11-25 (gating, finding A2 in 2026-11-25-gating-findings.md)
Code: Atmosphere/Tint.lua: UpdateTint (the day sweep); Slash.lua: timetest
Clients: both
Base: badf2f0

## Before / after
- Before: Load Visions unticked. /cine tinttest: the tint runs through the day, and each phase's title
  (Visions' Time of day card) is called from the tint's update: an error per phase. /cine timetest all:
  each title on a timer, an error each. Both later than the command, so its "isn't loaded" catch missed them.
- After: /cine tinttest shows the tint alone; /cine timetest says "Visions isn't loaded".

## Who relies on the old behavior
(`python -I Tools/audit.py refs TestTimeChangeTitle DaySweep`)
- Players: test commands; nothing changes with Visions loaded.
- Other features: ShowMe's timeTitle demo (removed with Visions out by its NEEDS table).
- Tests that encode it: none.

## States (the matrix)
Visions loaded or left out, the command (tinttest, timetest all), played on pretend time; the client.
Test: Tools/offline/timetitlematrix.lua forever
Test: Tools/offline/timetitlematrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| time-title-test | visions=out | * | ok |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: two nil checks on a test command's path, true whenever Visions is loaded.
