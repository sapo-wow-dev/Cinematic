# Discovered card out of a dungeon: test ledger
Goal: no Discovered / New zone card for a dungeon's name just after leaving it.
Code: Visions/CardMoments.lua (StaleInstanceName, ns.CardReads), Dev/ZoneCardTest.lua step 9, Tools/offline/discoverinstance.lua

User's case 2026-11-23 (Forever): out of the Stormwind Stockade, the big New zone card "Stormwind Stockade".
Cause: the zone name stays the dungeon's ~6 s outside (rule forever.zone.stale-name-after-instance); the
+1 s check after the loading screen took it for a new outdoor zone (a city: no explore count, ours said new).

## Questions
| # | Question | Client | Answer | From |
|---|----------|--------|--------|------|
| Q1 | Zone name stale after leaving a dungeon? | forever | YES, ~6 s | the user's log 2026-11-23 |
| Q2 | Fix: no card for the leftover name, New zone's still for a new zone? | both | YES | offline discoverinstance (fails on old code); run 1 3 PASS |

## Runs
| Run | Date | Command | Answered | Still open, and why this run couldn't |
|-----|------|---------|----------|---------------------------------------|
| 1 | 2026-11-23 | /cine debug zonecard 9 (retail) | Q2: 3 PASS, errors +0, blocked +0, shot shows the New zone card; step 9 marked proven | none. Made-up reads, so client-independent; Forever's real exit covered by everyday play |

## New zone off by default (2026-11-23)
"DUN MOROGH" slammed big on a new character: New zone was on by default. Now
off (DEFAULTS) and turned off once by Migrations.lua newZoneOffV1 (settings,
profiles, reset points). Offline: newzonedefault.lua, zonecardnewzone.lua.

| Run | Date | Command | Answered | Still open |
|-----|------|---------|----------|------------|
| 1 | 2026-11-23 | zonecard 10 (queue q607a, Forever) | 8 PASS 0 FAIL: update ran, off everywhere saved, small Discovered card for a new zone, big card once ticked; no errors, nothing blocked | none |
