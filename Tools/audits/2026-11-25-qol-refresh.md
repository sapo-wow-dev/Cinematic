# Profiles and Quality of life: switching off puts things back at once (fix card)
Fix: switching to a profile with them off left Graphics+ raised, the XP bar's "(N left)", the inspect Talents and Back buttons, the talent calculator link and the dressing room docked to the AH till the next reload; the Quality of life switch left the XP text and the drag strips; the Hunter switch left a vendor's Fill buttons
Found by: audit 2026-11-25 (gating, finding C17 in 2026-11-25-gating-findings.md)
Code: Profiles/Profiles.lua: SettingsChanged; Options.lua: CreateQualityPanel (handleQuality and handleHunter switches); QoL/HunterAmmo.lua: ns.RefreshHunterFill (new); QoL/Hunter.lua: ns.RefreshHunterPull (new, D4's card); QoL/CenterPanels.lua: ns.RefreshPanelStrips (new, D8's card)
Clients: both (the Hunter page, Fill buttons, Talents buttons, calculator link and AH dressing room: Classic clients only)
Base: baabf86

## Before / after
- Before: a profile with Graphics Boost or Quality of life helpers off: the boosted graphics, the XP bar's
  "(N left)", the Talents button on the inspect window, the dressing room by the auction house stayed till
  a reload. Quality of life's switch off: the XP text and the windows' drag strips stayed. Hunter's switch
  off at a vendor: the Fill buttons stayed.
- After: each goes (or comes back) as the profile loads or the switch is clicked.

## Who relies on the old behavior
(`python -I Tools/audit.py refs SettingsChanged RefreshXpLeft RefreshTalentLink RefreshTalentCalc RefreshAhDressUp ApplyGraphicsPlus`)
- Players: none want them kept after switching them off.
- Other features: every SettingsChanged caller (SetProfile, Reset, FollowHud, first pick): each now also
  runs these refreshes, which only read settings and put their own frames or CVars right (Graphics+ keeps
  its fight guard on secure CVars).
- Other addons: none.
- Tests that encode it: profilekeepmatrix (stubs the older refreshes; the new ones run there: still PASS),
  graphicsleavematrix (unchanged).

## States (the matrix)
The change (a profile loading, the Quality of life switch, the Hunter switch) and the feature asked
about; the client.
Test: Tools/offline/qolrefreshmatrix.lua forever
Test: Tools/offline/qolrefreshmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| qol-refresh | via=profile | not | refreshed |
| qol-refresh | via=qol item=xp | not | refreshed |
| qol-refresh | via=hunter item=fill | not | refreshed |
| qol-refresh-retail | via=profile item=graphics | not | refreshed |
| qol-refresh-retail | via=profile item=xp | not | refreshed |
| qol-refresh-retail | via=qol item=xp | not | refreshed |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: refreshes that already ran from their own ticks now also run on a profile load and the page switch.
Not proven offline: the drag strips coming down (D8's matrix covers the gate), the hunter's pull on Classic
Era (no Classic Era load offline), the real XP bar text and an open vendor in game.
