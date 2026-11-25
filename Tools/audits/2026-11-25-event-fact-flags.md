# Rules: flagged for PvP and AFK asked when your flags change, not every working out (fix card)
Fix: with a rule naming flagged or afk, the rule facts asked UnitIsPVP / UnitIsAFK on every full working out (every 0.1 s, 0.5 s idle), though the game announces every change
Found by: audit 2026-11-25 (event-driven rule facts)
Code: Frames.lua: the flagged and afk entries (ns.AddEventFact), ns.RuleFacts (their lines)
Clients: both
Base: 52538ad

## Before / after
- Before: flagged (ns.IsPvPFlagged) and afk (UnitIsAFK) asked each full working out while a rule named them.
- After: flagged asked after the player's UNIT_FLAGS, PLAYER_FLAGS_CHANGED or UNIT_FACTION; afk after PLAYER_FLAGS_CHANGED, and as a fight ends (PLAYER_REGEN_ENABLED: AFK may read secret where chat is locked down, so false in a boss fight); both after a loading screen, and for 0.5 s after each. Same words.

## Who relies on the old behavior
(`python -I Tools/audit.py refs IsPvPFlagged UnitIsAFK`, read every hit.)
- Players: rules naming flagged or afk. The per-place options (ns.GetOptionPlace) read ns.IsPvPFlagged themselves: untouched.
- Other features: none read facts.flagged/afk but the rules.
- Other addons: none.
- Tests that encode it: Tools/offline/rulewords.lua plays the Rule Words kit test on the stand-in: its /afk step flipped UnitIsAFK with no event; it now sends PLAYER_FLAGS_CHANGED as the game does (the check unchanged; with no event it never saw afk: 59 more FAIL). friendrows, noaddons pass.

## States (the matrix)
The states: flagged (afk) or not, nothing new or flipped with its event. A rule names the word in every cell. Client fixed per run.
Test: Tools/offline/eventfactsmatrix.lua forever flagged
Test: Tools/offline/eventfactsmatrix.lua retail flagged
Test: Tools/offline/eventfactsmatrix.lua forever afk
Test: Tools/offline/eventfactsmatrix.lua retail afk

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| event-facts-flagged | word=flagged start=off change=none | after=off later=off right=true polled=yes | after=off later=off right=true polled=no |
| event-facts-flagged | word=flagged start=off change=flip | after=on later=on right=true polled=yes | after=on later=on right=true polled=no |
| event-facts-flagged | word=flagged start=on change=none | after=on later=on right=true polled=yes | after=on later=on right=true polled=no |
| event-facts-flagged | word=flagged start=on change=flip | after=off later=off right=true polled=yes | after=off later=off right=true polled=no |
| event-facts-afk | word=afk start=off change=none | after=off later=off right=true polled=yes | after=off later=off right=true polled=no |
| event-facts-afk | word=afk start=off change=flip | after=on later=on right=true polled=yes | after=on later=on right=true polled=no |
| event-facts-afk | word=afk start=on change=none | after=on later=on right=true polled=yes | after=on later=on right=true polled=no |
| event-facts-afk | word=afk start=on change=flip | after=off later=off right=true polled=yes | after=off later=off right=true polled=no |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| Tools/offline/rulewords.lua | afk step (and the steps after it) | /afk flipped UnitIsAFK with no event: passed by polling | the stand-in sends PLAYER_FLAGS_CHANGED as the game does: passes; with no event the afk step fails | the user, 2026-11-25: "OK, commit" |

## Risk
low: PLAYER_FLAGS_CHANGED comes for /afk and its end, UNIT_FLAGS for the PvP flag (the 5-minute timer running out too). Not proven offline: the PvP flag timing out on Forever sends one of the three. For the test skill's run: /afk on and off, /pvp on and off with a rule naming them (the Rule Words kit test's afk step).
