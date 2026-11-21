# Level up card emotes at yourself: test ledger
Goal: the You level up card's emotes don't address everyone around (user, 2026-11-21). No emote can go to yourself, so: emotes whose at-no-one line names no one, Cheer, Victory, Flex (user picked, 2026-11-21).
Code: Visions/EmoteVision.lua (MOMENTS YouLevel emotes, Answer's atSelf branch: DoEmote(token, "none"), ns.EmoteVisionLevelMoment), Migrations.lua youLevelEmotesV2, Dev/LevelEmoteTest.lua, Tools/offline/youlevelemotes.lua, Dev/TestKit.lua r:Click

## Questions
| # | Question | Client | Answer | From |
|---|----------|--------|--------|------|
| Q1 | DoEmote(token, "player") aims at you? | forever | NO: the at-no-one line ("everyone around you") | run 1, rule forever.emote.doemote-player-unit |
| Q2 | DoEmote(token, your "First Last" or first name) gives a self line? | forever | NO: at-no-one line | run 2 step 4 |
| Q3 | Does the game have self lines at all (you targeted, DoEmote(token) / "target")? | forever | NO for these 3: at-no-one line | run 2 step 6 |
| Q4 | An /e line of your own goes out (fallback)? | forever | from a timer: BLOCKED (resume()); from a click: open | run 2 step 7, rule forever.chat.emote-needs-click |
| Q5 | Which way the card goes (own /e line vs emotes whose at-no-one line names no one) | - | neutral emotes: Cheer, Victory, Flex | user, 2026-11-21 |
| Q6 | Victory, Flex at no one name no one? (Proud, Huzzah, Magnificent logged as spares) | forever | YES: "You bask in the glory of victory.", "You flex your muscles.  Oooooh so strong!"; Proud "You are proud of yourself."; Huzzah, Magnificent no line | run 3 step 2, rule forever.emote.lines-at-no-one |
| Q7 | The kit's r:Click gets an /e line out (a hardware event)? | forever | sent, no block; the line back was your own "/e test" (test now waits for its own text) | run 3 step 4, rule forever.chat.emote-needs-click |

## Plan tree
Q2 yes -> the card already uses it (built in run 2); run 2's card step is the confirm. Done.
Q2 no, Q3 yes -> the game has self lines but only through a target; the card can't target you (TargetUnit protected): use Q4's own /e line, or a plain "none" for emotes whose none line names no one (CHEER: "You cheer!").
Q2 no, Q3 no -> no self line exists: own /e line (Q4) or at-no-one only for emotes that don't say "everyone". All probed in run 2. PICKED: neutral emotes.
Run 3: Victory or Flex names others -> swap in a spare that names no one (Proud, Huzzah, Magnificent lines logged in the same run): no run 4 needed for the pick, only a code change.

## Runs
| Run | Date | Command | Answered | Still open, and why this run couldn't |
|-----|------|---------|----------|---------------------------------------|
| 1 | 2026-11-21 | /cine debug levelemote | Q1 NO | Q2-Q4: run 1 only tried "player" (the first build) |
| 2 | 2026-11-21 | /cine debug levelemote | Q2 NO, Q3 NO, Q4 blocked from a timer | Q4 from a click: the test sent it from a step (kit fixed: r:Click, and the kit now names a blocked resume()) |
| 3 | 2026-11-21 | /cine debug levelemote | 10 PASS: defaults + update, Cheer/Victory/Flex name no one, card plays them at no one, target left alone, r:Click sends with no block | none for the card. The test's "/e line back" check matched another line; fixed (waits for its own text) |
