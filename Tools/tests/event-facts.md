# Event-driven rule facts: test ledger
Goal: the rule words class, role, group, flagged, afk, resting, dead, mounted, casting and the place read the game's answer as asked only after its events (commits 096cbe9..2a83026), never a stale one
Code: Frames.lua (ns.AddEventFact, ns.ReadEventFacts, the entries), Core.lua (ns.GetPlaceType, ns.placeWatch); fix cards Tools/audits/2026-11-25-event-fact-*.md
Test: Dev/EventFactsTest.lua, `/cine debug eventfacts`

## Questions
| # | Question | Client | Answer | From |
|---|----------|--------|--------|------|
| Q1 | At rest, each cached word (and the place) equals the game's live answer? | forever | YES: every word and the place, 24 samples | run 1 step 1 |
| Q2 | /cine debug group (ns.fakeGroup, no game event) turns group on and back within 1 s? | forever | YES: on with the fake party, back to off | run 1 step 2 |
| Q3 | Mounting and getting off: PLAYER_MOUNT_DISPLAY_CHANGED comes each way and mounted follows IsMounted within 1.2 s? | forever | open: no mount on the Forever character (level 12) | run 1 step 3 skipped; retail run 2 |
| Q4 | Any word stale for over 1.2 s at any time in the run: which events the game DID send around it? | forever | NO word stale in 1356 samples over 4.7 min; 2 casts came (UNIT_SPELLCAST_START 2, STOP 4) and casting stayed right | run 1, every step |
| Q5 | Cost of a full working out now vs every entry asked again (the old way)? | forever | 0.0544 ms now vs 0.0643 ms asking every entry and the place (-15% a pass; the words no rule names were already skipped, badf2f0) | run 1 step 4 |
| Q6 | The same on retail? | retail | open | a retail run, only if you bring it up |
| Q7 | AFK in a boss fight (secret where chat is locked down) comes back after the fight? | forever | open, not this run (needs a boss fight) | the cards' Risk lines |
| Q8 | Every place change sends one of the five place events (a capital's edge, a phased area, a portal)? | forever | partly: what this run passes through (the watcher, Q4) | run 1 |

## Plan tree (step 3)
- Q1/Q3/Q4 all agree -> the fixes stand; the next run is none (confirm done), unless retail is wanted (Q6).
- A word stale (Q1 or Q4) -> the log names the word, live vs cached, and the game's events in the 3 s before (the watcher): an event we don't listen to -> add it to that entry; no event at all -> that word goes back to being polled (its fix reverted alone, its card says why). Both decided from this one log.
- Q3 mounted lags past 1.2 s with the event seen -> IsMounted answers after the settle: longer settle for that entry (the log gives the lag). No event -> back to polled.
- Q2 fails -> entry.key isn't compared each pass: a code bug, offline matrix first.
- Q5: informational (the ledger keeps the numbers).

## Runs
| Run | Date | Command | Answered | Still open, and why this run couldn't |
|-----|------|---------|----------|---------------------------------------|
| 1 | 2026-11-25 | qa1dd: `/cine debug eventfacts full` (Forever) | Q1, Q2, Q4, Q5 (5 pass, 0 fail, errors +0, blocked +0) | Q3: no mount on the Forever character (the user's issue at step 3); Q6 retail. Steps 1, 2, 4 proven |
| 2 | 2026-11-25 | qbdd7: `/cine debug eventfacts 1 3` (retail: you have mounts there) | waiting | |
