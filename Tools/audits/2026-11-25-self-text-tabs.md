# Style: Text on You's tabs switch what's on them off (fix card)
Fix: Self Text Style's General, Look and Kinds tabs gated nothing, and its 2 s refresh ran with the page off
Found by: audit 2026-11-25 (gating, findings C3 and D15's Self Text ticker in 2026-11-25-gating-findings.md)
Code: Style/SelfTextStyle.lua: DB (now a look over the saved settings), On, ns.SelfTextGameSample, its refresh timer (now ns.FeatureLoop), ns.RefreshSelfTextStyle
Clients: both
Base: baabf86

## Before / after
- Before: Text on You on, its General tab right-clicked off: the game's combat text was still copied and
  drawn our way, the game's own held hidden, its floating combat text setting held on. Look off: our font,
  size and edge kept. Kinds off: a kind hidden there stayed hidden, each kind's color and size kept. The page
  off: its refresh still ran every 2 seconds for good.
- After: General off: the game's text as it was (nothing copied, its frame and setting let go). Look off:
  the default look. Kinds off: every kind as the default (shown, the game's color). The page off: once what it
  held is let go, its refresh stops; on again, it starts within a second.

## Who relies on the old behavior
(`python -I Tools/audit.py refs RefreshSelfTextStyle SelfTextBy SelfTextPart SelfTextGameSample`)
- Players: anyone with one of its tabs off (default all on): that tab's settings now count as off.
- Other features: the page (SelfTextPage.lua) and its preview read through the same look, so a tab off shows
  the default there too; The game's sample now forces its look over what's read rather than writing it into
  the saved settings (and puts nothing back on an error). /cine resume still runs the refresh.
- Other addons: none (BattleText Forever's clash: the setting is still held only while ours draws).
- Tests that encode it: selftext, selftextall, selftextmerge, selftextpage, selftextpagetest, selftextrelease,
  selftextstyle, selftextstyletest, stylepagegatematrix, resumematrix, fightsfades: all PASS, both clients.

## States (the matrix)
The page on or off, no tab off or one (General, Look, Kinds), the client; then the page applied and two
seconds passing. Retail has no Self Text page (no tabs): its own matrix, self-text-tabs-retail, page only.
Test: Tools/offline/selftexttabsmatrix.lua forever
Test: Tools/offline/selftexttabsmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| self-text-tabs | client=forever page=on tabOff=general | by=ours hidden=yes cvar=ours sample=big loop=on | by=game hidden=no cvar=game sample=big loop=on |
| self-text-tabs | client=forever page=on tabOff=look | by=ours hidden=yes cvar=ours sample=big loop=on | by=ours hidden=yes cvar=ours sample=base loop=on |
| self-text-tabs | client=forever page=on tabOff=kinds | by=ours hidden=yes cvar=ours sample=big loop=on | by=ours hidden=yes cvar=ours sample=big+damage loop=on |
| self-text-tabs | page=off tabOff=none | by=game hidden=no cvar=game sample=big loop=on | by=game hidden=no cvar=game sample=big loop=off |
| self-text-tabs | client=forever page=off tabOff=general | by=game hidden=no cvar=game sample=big loop=on | by=game hidden=no cvar=game sample=big loop=off |
| self-text-tabs | client=forever page=off tabOff=look | by=game hidden=no cvar=game sample=big loop=on | by=game hidden=no cvar=game sample=base loop=off |
| self-text-tabs | client=forever page=off tabOff=kinds | by=game hidden=no cvar=game sample=big loop=on | by=game hidden=no cvar=game sample=big+damage loop=off |
| self-text-tabs-retail | page=off tabOff=none | by=game hidden=no cvar=game sample=big loop=on | by=game hidden=no cvar=game sample=big loop=off |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: only players with a Text on You tab off see a change. Each read of its settings now asks the switch
tree once. The page switched on elsewhere (a profile) is caught up within about 3 seconds instead of 2. Not
proven in game: the game's CombatText let go at once on the General tab's right-click (it is on the next
refresh, within 2 seconds).
