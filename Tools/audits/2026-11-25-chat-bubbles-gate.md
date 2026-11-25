# Chat bubbles: off with Chat's Show tab or the HUD off (fix card)
Fix: with Chat's Show tab or the whole HUD (General) off, the Chat Bubbles page kept writing the game's bubble settings once a second and never put them back; its bubble watch and speech from behind kept going
Found by: audit 2026-11-25 (gating, finding C12 in 2026-11-25-gating-findings.md)
Code: UI/Bubbles.lua: BubblesOn (new), ns.BubbleKindOff, its loop, ns.ApplyBubbles, OnUpdate, the watcher's events, the keep-on-screen lift; UI/Chat.lua: SpeakOrPeek
Clients: both
Base: baabf86

## Before / after
- Before: Chat Bubbles page on (say bubbles off in towns, say). Turn Chat's Show tab off, or the HUD's
  General: the page's switch greys, but the game's bubble settings stay as the page set them, written
  again every second; each say or yell still starts the bubble watch; speech from behind you still shows.
- After: within a second the game's own bubble settings are back and the page's loop stops; bubble lines
  don't start the watch for the page (the Style page still does, as before); speech from behind follows the
  page with its switches. On again: the page writes its settings again.

## Who relies on the old behavior
(`python -I Tools/audit.py refs handleBubbles ApplyBubbles chatSpeechBehind`)
- Players: those with Chat's Show or the HUD off and the bubbles page on: the page's switch is greyed for
  them, so the rule says off.
- Other features: Chat.lua's speech behind (now through ns.BubblesOn), ns.BubbleKindOff (already gated),
  the keep-on-screen lift (now gated too, as the page's other lift reads were).
- Other addons: none.
- Tests that encode it: bubblehookmatrix (page on/off with all switches on: unchanged), profilekeepmatrix,
  cooldownlinesmatrix (stub ApplyBubbles).

## States (the matrix)
What's off: nothing, the page's own switch, Chat's Show tab, the HUD's General; two seconds then pass.
Test: Tools/offline/bubblesgatematrix.lua forever
Test: Tools/offline/bubblesgatematrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| chatbubbles-gate | off=show | cvar=ours loop=on | cvar=game loop=off |
| chatbubbles-gate | off=hud | cvar=ours loop=on | cvar=game loop=off |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: only players with a parent switch off and the page on notice, and then the greyed page now does
nothing, as it shows. The put-back waits for the next second (no live hook on the parent switches; the
loop runs once more to put back). Not proven offline: speech from behind with Chat's Show off, in game.
