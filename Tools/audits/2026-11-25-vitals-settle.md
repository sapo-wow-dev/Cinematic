# Vitals Vision: its edges go when it's turned off, asleep with secret health too (fix card)
Fix: on WoW Forever (health always secret), out of a fight, Vitals turned off by its Health tab, Enable Visions,
a profile or CineMode ending (Allow outside CineMode unticked) left its red edges painted and the game's own
low-health flash hidden, till Vitals was wanted again
Found by: audit 2026-11-25 (review of 2d31359, the card 2026-11-25-vitals-wake.md)
Code: Atmosphere/LowHealth.lua: the events frame's OnEvent (both Wake conditions), its PLAYER_LOGIN (a
ns.tabSwitchHooks entry); Core.lua: ns.RefreshOutsideCine's list; Profiles/Profiles.lua: SettingsChanged
Clients: both (the bug is Forever's: secret health out of fights; retail's health is plain there)
Base: cc7e40d

## Before / after
- Before: secret health, still for 3 s out of a fight: Vitals' update sleeps with the edges shown (the game's
  alpha over them) and the game's flash hidden. Turned off then by the Health tab's right-click, Enable Visions,
  a profile loading, or CineMode ending with Allow outside CineMode unticked: nothing woke it (none of those
  calls ns.RefreshLowHealth, and since 2d31359 health events don't wake it with the tab off), so the edges stayed
  up and the game's flash stayed hidden until Vitals was wanted again. Its page's own switch was fine (it calls
  ns.RefreshLowHealth).
- After: each of those wakes it (the tab's right-click by ns.tabSwitchHooks, Enable Visions and CineMode ending
  by ns.RefreshOutsideCine, a profile by SettingsChanged), and a health event wakes it too while its edges are
  still up. It settles: the edges go, the game's flash is back. Once settled (edges gone), hits with it off
  still don't run its update (2d31359's saving kept).

## Who relies on the old behavior
(`python -I Tools/audit.py refs RefreshLowHealth tabSwitchHooks RefreshOutsideCine SettingsChanged wasShown`)
- Players: nobody wants edges left up with Vitals off. Vitals on: unchanged (RefreshLowHealth only wakes it and
  sets its look up again; Update settles back to sleep).
- Other features: ns.RefreshLowHealth also calls ns.RefreshManaVision (low mana, same pages): now also run by
  CineMode changing (only with some Allow outside CineMode tick off, or forced), a profile loading and the Vitals
  tabs' right-click; it only wakes Mana Vision's loop to settle. ns.RefreshOutsideCine's other refreshes:
  unchanged. SettingsChanged's other refreshes: unchanged. ns.tabSwitchHooks: a new prefix
  "tabOn:VitalsVision:" (Health and Mana tabs); Graphics+ and Keybinds keep theirs.
- Other addons: none.
- Tests that encode it: vitalswakematrix.lua (edges gone: hits don't wake it with the tab off): unchanged.
  manavisionloopmatrix.lua, manavision.lua, vitalsdraw.lua, visionsmastermatrix.lua, questtalkloopmatrix.lua,
  qolrefreshmatrix.lua, hunterclassmatrix.lua (SettingsChanged / RefreshOutsideCine callers): run, see below.
  Dev/GatingTest.lua runs every ns.tabSwitchHooks entry for a tab's key: the new one only wakes Vitals.

## States (the matrix)
Your health (secret, plain and low, plain and full); how Vitals stops being wanted (not at all, its page's switch,
its Health tab's right-click, Enable Visions, a profile, the tab's setting written with nothing called (quiet:
only a health change can tell it), CineMode ending with Allow outside CineMode unticked, or
ticked); then nothing more or a health change. Each: edges up or gone, the game's flash hidden or shown, and
whether a hit then wakes its update. Every cell pinned.
Test: Tools/offline/vitalssettlematrix.lua forever
Test: Tools/offline/vitalssettlematrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| vitals-settle | health=secret off=tab | edges=up game=hidden hits=rest | edges=gone game=shown hits=rest |
| vitals-settle | health=secret off=visions | edges=up game=hidden hits=rest | edges=gone game=shown hits=rest |
| vitals-settle | health=secret off=profile | edges=up game=hidden hits=rest | edges=gone game=shown hits=rest |
| vitals-settle | health=secret off=cineEnds | edges=up game=hidden hits=rest | edges=gone game=shown hits=rest |
| vitals-settle | health=secret off=quiet then=health | edges=up game=hidden hits=rest | edges=gone game=shown hits=rest |
| vitals-settle | health=secret off=quiet then=nothing | edges=up game=hidden hits=rest | edges=up game=hidden hits=wake |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: a few more wake-ups (each settles in a frame or two, then sleeps), only on a switch, a profile or CineMode
changing. Not proven offline: the game's real alpha curve over the edges with secret health (stubbed), the
game's flash hook (hooksecurefunc is a no-op offline: its SetAlpha read directly), a real tab right-click and
profile switch in game. Not covered by this fix: Vitals' Show in row set to CineMode only (Always unticked),
CineMode ending with every Allow outside CineMode tick on: ns.RefreshOutsideCine returns early, so asleep with
secret health the edges stay till the next health event (now woken, as the tab's still on); as before 2d31359.
