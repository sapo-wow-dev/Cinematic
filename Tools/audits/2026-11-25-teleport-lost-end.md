# Teleport Vision: a cast whose end never comes no longer holds the portal on screen (fix card)
Fix: ns.departCast was ended only by the player's cast end events; one lost (across a loading screen, say) left
Teleport Vision held at full for good, with your tooltips and cast bar faded out.
Found by: player case 2026-11-25 (gray filter stuck after a teleport to Stormwind till Alt+F4) + overlay audit
Code: Diagnostics.lua: ns.OnLoadingScreen (new, shared); Camera/Camera.lua: the depart watcher's loading clear;
Atmosphere/TeleportVision.lua: Settle (Cast, FadeWanted), Update's no-size return
Clients: both
Base: 11e50fe

## Before / after
- Before: if the game's "cast finished" never reached us, the portal, its dark shade and clouds stayed on screen
  until a reload or the next Hearthstone, and every tooltip and your cast bar stayed invisible.
- After: a loading screen ends the cast (you're gone: the usual fade out). With no loading screen, 1.5 s after the
  cast should have ended, and the game no longer saying you're casting, it opens back out as if cancelled.

## Who relies on the old behavior
(`python -I Tools/audit.py refs departCast OnLoadingScreen`)
- Players: nobody wants it stuck. A cast delayed by pushback is still "casting" to the game, so it isn't cut short.
- Other features: only Teleport Vision reads ns.departCast (Cast, FadeWanted). The tele camera keeps its own
  castEndsAt, untouched here.
- Other addons: none.
- Tests that encode it: none before this card.

## States (the matrix)
the cast's end (SUCCEEDED / STOP / none) x a loading screen (yes / no) x the game still saying casting (yes / no) x
when it's looked at (0.5 s / 10 s after the cast's end), per client. 24 cells.
Test: Tools/offline/teleportcastmatrix.lua forever
Test: Tools/offline/teleportcastmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| teleport-cast-end | ending=lost loading=no casting=no after=late | portal=shown bar=held tip=faded | portal=hidden bar=free tip=full |
| teleport-cast-end | ending=lost loading=yes casting=no after=late | portal=shown bar=held tip=faded | portal=hidden bar=free tip=full |
| teleport-cast-end | ending=lost loading=yes casting=yes after=late | portal=shown bar=held tip=faded | portal=hidden bar=free tip=full |
| teleport-cast-end | ending=stop loading=yes casting=yes after=late | portal=shown bar=held tip=faded | portal=hidden bar=free tip=full |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: only a cast past its end that the game no longer calls a cast, or a loading screen, changes anything. Not
proven offline: that LOADING_SCREEN_ENABLED / PLAYER_LEAVING_WORLD fire on a real teleport on both clients (the
camera scripts already lean on them, CameraScripts.lua), and how the real cast bar looks as it's given back.
