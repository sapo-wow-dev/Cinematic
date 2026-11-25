# Plate Layout: the arrow keys work from the parts panel too (fix card)
Fix: the arrow keys nudged the picked part only while the mouse was on the preview's plate; moving it to the parts
list or the fields stopped them with no sign why.
Found by: audit 2026-11-25
Code: Plates/PlateLayoutPage.lua: OverPreview (the preview or the parts panel), Pick (takes the keys)
Clients: forever (no Layout tab on retail)
Base: HEAD

## Before / after
- Before: arrows nudged only with the mouse on the preview; over the list or fields, the key went to the game and the
  keyboard was let go.
- After: with the mouse on the preview or the parts panel the arrows nudge the picked part, and picking a part in the
  list takes the keys. Every other key still goes on to the game; a key with the mouse anywhere else lets the
  keyboard go, as before.

## Who relies on the old behavior
- Players: the feature landed today (e439474), unreleased.
- Tests that encode it: Tools/offline/platelayoutpage.lua (no key script at rest; the keyboard let go off the page;
  W passed on): all kept.
- The game: the safety from the first build (onkeydown-takes-keyboard) kept: the key script only while wanted, every
  non-arrow key passed on.

## States (the matrix)
The mouse on the preview, on the parts panel, or away; the key Right or W.
Test: Tools/offline/platelayoutkeysmatrix.lua forever

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| platelayout-keys | mouse=panel key=RIGHT | x=0 passed=true held=false | x=1 passed=false held=true |
| platelayout-keys | mouse=panel key=W | x=0 passed=true held=false | x=0 passed=true held=true |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: the Layout tab only, unreleased. The keyboard is held a little longer (over the panel too), every non-arrow
key still passed on, let go away from the page and when the page hides. Pinned offline (6 cells, the old page
check). Not offline: the real mouse-over areas (the in-game run).
