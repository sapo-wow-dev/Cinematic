# Plate Layout: no key held in a fight (fix card)
Fix: an arrow nudge on the Layout tab held the keyboard (keys not passed on) till the next key out of a fight; a
fight starting in between, with the options left open on the page, kept every key from the game till it ended.
Found by: audit 2026-11-25
Code: Plates/PlateLayoutPage.lua: OnKey (keys passed on again a frame after each nudge), the key frame's
PLAYER_REGEN_DISABLED / ENABLED (hidden for the fight, shown after)
Clients: forever (no Layout tab on retail)
Base: cc7e40d376c2c6713a2c22b74542ec20cb109c68

## Before / after
- Before: nudge a part with an arrow, leave the options open on the page, get pulled into a fight: no key reached the
  game (no moving, no casting) till the fight ended.
- After: a frame after each nudge every key is passed on again; as a fight starts the page's key frame is passed on
  and hidden, so it never holds a key in a fight. After the fight it shows again and the arrows nudge as before.

## Who relies on the old behavior
(`python -I Tools/audit.py refs PlateLayoutPageKeys SetPropagateKeyboardInput`, read every hit.)
- Players: the Layout tab is unreleased (today's work); nobody relies on keys held in a fight.
- Other features: none use the page's key frame. The same "pass on again a frame later" is QuestTalk's and Style
  pop-outs' pattern (Visions/QuestTalk.lua, Style/StylePages.lua).
- Other addons: none.
- Tests that encode it: Tools/offline/platelayoutpage.lua (no key script at rest, let go off the preview, the arrow
  kept: kept, its C_Timer.After does nothing), Tools/offline/platelayoutkeysmatrix.lua (passed=false right after a
  nudge: kept, same reason). Memory onkeydown-takes-keyboard: kept.

## States (the matrix)
The mouse on the preview or away; the key Right or W; a fight: none, starting before the key, right after it (before
the next frame), or a frame after it. Each cell: the level box's x, whether the key frame holds the keyboard in the
fight, and whether the arrow nudges again after.
Test: Tools/offline/platelayoutfightkeysmatrix.lua forever

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| platelayout-fightkeys | mouse=preview key=RIGHT fight=soon | x=1 fight=held then=nudges | x=1 fight=free then=nudges |
| platelayout-fightkeys | mouse=preview key=RIGHT fight=later | x=1 fight=held then=nudges | x=1 fight=free then=nudges |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: the Layout tab only, unreleased. A held arrow repeating still nudges (each key down holds its own key). Not
offline: the real key repeat and that hiding the frame in a fight lets the keys through (the in-game run: nudge,
pull a mob with the options open, walk).
