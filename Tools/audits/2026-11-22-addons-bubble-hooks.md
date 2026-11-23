# Chat bubbles: a reused bubble's place (fix card)
Fix: a bubble's state first made text-anchored (retail) or hidden off the screen had no SetPoint hook, so once the game reused that bubble the other way, its saved place went stale.
Found by: audit 2026-11-22 (retroactive card, 2026-11-23)
Code: UI/Bubbles.lua: StateOf(), Lift(), ns.HideOffScreenBubble()
Clients: both
Base: bdb2e1d^

## Before / after
- Before: with Keep bubbles on screen on, a reused bubble that had first been text-anchored or hidden for our
  off-screen bubble jumped to a stale place (off the screen's top or bottom) for its next lines; with the box
  unticked afterwards it went back to an old place, not the game's.
- After: wherever its state is first made, the hook is too: the bubble follows the game's latest place.

## Who relies on the old behavior
(`python -I Tools/audit.py refs bubblesOffTop HideOffScreenBubble`)
- Players: Keep bubbles on screen (default on; Subtle has it off); Chat Cam's off-screen bubble (UI/Chat.lua 978).
- Other features: ns.IsBubbleOnScreen (reads the copy), the bubble copy (retail).
- Tests that encode it: Tools/offline/questiegate.lua check 4.

## States (the matrix)
The bubble's first use (new / text-anchored / hidden off screen, then reused) x Keep bubbles on screen (on / off /
turned off after its lines), per client. Then the game places it near the top twice.
Test: Tools/offline/bubblehookmatrix.lua forever
Test: Tools/offline/bubblehookmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| bubble-hook | first=text page=on | * | spot=under the line |
| bubble-hook | first=hidden page=on | * | spot=under the line |
| bubble-hook | first=text page=offLater | * | spot=game's |
| bubble-hook | first=hidden page=offLater | * | spot=game's |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none (retroactive card) | | | | |

## Risk
low: the state and its hook made in one place. Not proven offline: the real engine placing retail's text-anchored
bubbles (the matrix stubs points and tops), the copy's look.
