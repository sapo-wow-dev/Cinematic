# Nameplate Style: a Smart row's popped-out preview closes with the settings and Escape (fix card)
Fix: a Smart row's preview popped out into its window (a16eb17) stayed over the game when the settings closed, its
plate preview still drawing, and Escape didn't close it
Found by: audit 2026-11-26 (Nameplate Style editor, 679e735 / a16eb17)
Code: Style/StylePages.lua: ns.PopPreviewOut (the window's UISpecialFrames entry, ns.CloseWithSettings, its OnHide)
Clients: both
Base: e0ca906

## Before / after
- Before: a row's preview popped out (CinematicRowPreviewWindow), then the settings closed or Escape pressed: the
  window stayed up over the game with the preview in it, drawing. Its x and its pop-out button put it back.
- After: closing the settings (any way) or Escape closes the window too, and the preview goes back to its row's
  page, as the pages' preview window does. Hidden any way, the preview goes back. Its x and pop-out button: as before.

## Who relies on the old behavior
(`python -I Tools/audit.py refs PopPreviewOut CinematicRowPreviewWindow`, every hit read.)
- Players: nothing saved (docked/undocked and where it was dragged are kept for the session as before).
- Other features: the Smart rows' pop-out button (Nameplates.lua) and ns.StylePopout's pages' window, which already
  closed with the settings (Skin.lua's ns.CloseWithSettings): this window now does the same.
- Other addons: none. UISpecialFrames gets one more name: the game's Escape hides it as any other window.
- Tests that encode it: none before this matrix.

## States (the matrix)
Docked or undocked; how it's closed (the settings closed, Escape, its x, its pop-out button again); the settings
opened again or not; the client. Each cell: the window, where the preview is, whether it's drawn.
Test: Tools/offline/rowpopoutmatrix.lua forever
Test: Tools/offline/rowpopoutmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| rowpopout | close=escape | window=shown preview=window drawn=yes | window=hidden preview=page drawn=yes |
| rowpopout | close=settings reopen=yes | window=shown preview=window drawn=yes | window=hidden preview=page drawn=yes |
| rowpopout | close=settings reopen=no | window=shown preview=window drawn=yes | window=hidden preview=page drawn=no |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: a window from the settings, closing with them. Not proven offline: the game's Escape order with other
UISpecialFrames windows open (the stand-in hides every shown one), and a fight closing the settings.
The matrix's Window() reads the global with rawget: the stand-in answers an unknown global with a stub of its own
(its own parent), which made the first cell loop forever on any code.
