# Nameplates: the Nameplates and Names tabs switch their rows off (fix card)
Fix: right-clicking a Nameplates or Names tab off (Enemy, Friendly, Dungeons & raids, Default parts, Target, and the
Names icon's Players, Enemy NPCs, Friendly NPCs, Extras, Target) did nothing: their rows are list rows, read raw
(Effects.lua's KeptHere, ShownInFights, NameKeptHere...), never hung under the tab's switch.
Found by: audit 2026-11-25 (gating, finding C1 in 2026-11-25-gating-findings.md)
Code: Effects.lua: ns.PlateTabOff, ns.NameTabOff, ns.InstancePlatesTabOff (new, one map of rows to tabs), RuleSays
(so KeptHere, ShownInFights, ns.PlateRowWanted and every reader through them), NameKeptHere, ns.UpdateCVars,
TargetHeldDown, MarkersHiddenOverFriends, UpdateLockedPlates, ns.EnsurePlateRows, ns.plates.FriendRowWanted,
ns.plates.FriendWants, PlateAlphas (your target's names rule), ns.PlatesWhy and ns.PlateItemsWhy (the Why window)
Clients: both
Base: baabf86

## What "off" means (decided here, the user's call to change)
As the Chat page's tabs (2026-11-22-settings-chat-tabs.md) a tab off = every row on it off, read here the way the
page's own switch off reads: Cinematic leaves that tab's units to the game. None of its rows hides or adds anything:
- Enemy, Friendly: a kind's plates (enemy players, hostile NPCs, friendly players...) show in CineMode as your own
  game settings show them (ns.plates.OwnKindShown: with Always Show Nameplates off, only in fights), not faded by
  CineMode; the kinds' own custom parts are shown; the unit rows (Enemies within, your pet, group members and their
  minions) add nothing; Cinematic no longer switches friendly plates on for those rows (FriendWants).
- Dungeons & raids: friendly plates there aren't switched off by its choices (your own settings).
- Default parts: every part shown on plates that are up (as the game draws them).
- Target: your target's plate isn't kept up, nor held down: its kind's row decides; the mouseover row adds nothing.
- Names tabs: those names over heads are left to the game's own settings (CineMode doesn't hold them off), and no
  names are kept on faded plates by those rows. All NPCs (the game's one setting for every NPC) is left alone only
  when all three NPC rows' tabs are off; with one tab on, that tab's rows still decide it. Interactive NPCs' names
  stay off wherever CineMode keeps every plate on: that's the plates' doing, not a row's.
- Extras: the Raid marker row neither keeps markers up nor hides friendly ones (the game's own).
Its rows' rules (plate:<row>, name:<row>) count for nothing either while the tab is off.

## Before / after
- Before: a tab off (its name greyed) changed nothing: Enemy off, enemies still faded and showed by their rows;
  Target off, your target's plate still held down or kept up; Players off, friendly names still hidden.
- After: as above, "What off means". Each switch back on, its rows as they were (within half a second: the plates'
  and names' passes look again; FriendWants at once).

## Who relies on the old behavior
(`python -I Tools/audit.py refs tabOn:Nameplates KeptHere ShownInFights NameKeptHere PlateRowWanted`)
- Players: tabs start on (LazyPageDefaults.lua). Only anyone who right-clicked one off, and saw nothing change.
- Other features: everything that goes by these rows does through the readers changed: the plate pass (keptLevel,
  combatCap, AnyPlatesKeptCinematic, AnyFightKinds, PlatesFiltered), names on plates (nameLevel, NamesOnPlates, the
  guild line's plateGuildLevel), PlateParts (ns.PlateRowWanted per part), the raid marker (KeepRaidMarker), the Why
  window. The All names row (over the Names tabs) has no tab: unchanged. Quest mobs' row (Quest Vision): unchanged.
- Other addons: none.
- Tests that encode it: talknamesmatrix, calmplatesmatrix, farnamesgatematrix (all tabs on: unchanged).
- Not changed here: Plates/PlateGuild.lua reads the Friendly NPCs tab's Service NPCs settings (nameServiceShow,
  nameService<kind>, nameServiceIcons...) raw: with that tab off, titles still go by them where a Service NPCs name
  shows. That file is the Style fix's; reported.

## States (the matrix)
The tab (each of the ten) x on/off x a representative row of it ticked (Always) or not x in a fight or not, in
CineMode with both pages on. Each cell reads what the tab's rows decide through the readers above. 80 cells.
Test: Tools/offline/platetabsmatrix.lua forever
Test: Tools/offline/platetabsmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| plates-names-tabs | tab=Enemy tabState=off row=off | plate=down part=down | plate=up part=up |
| plates-names-tabs | tab=Friendly tabState=off row=off | plate=down pet=down | plate=up pet=down |
| plates-names-tabs | tab=Friendly tabState=off row=on | plate=up pet=up | plate=up pet=down |
| plates-names-tabs | tab=Instances tabState=off row=on fight=no | locked=off | locked=game |
| plates-names-tabs | tab=Parts tabState=off row=off | part=down | part=up |
| plates-names-tabs | tab=Target tabState=off row=off | kept=down held=down | kept=down held=no |
| plates-names-tabs | tab=Target tabState=off row=on | kept=up held=no | kept=down held=no |
| plates-names-tabs | tab=NamesPlayers tabState=off row=on | kept=yes names=game | kept=no names=game |
| plates-names-tabs | tab=NamesPlayers tabState=off row=off fight=no | kept=no names=hidden | kept=no names=game |
| plates-names-tabs | tab=Names tabState=off row=on | kept=yes names=game | kept=no names=game |
| plates-names-tabs | tab=Names tabState=off row=off fight=no | kept=no names=hidden | kept=no names=game |
| plates-names-tabs | tab=NamesService tabState=off row=on fight=no | kept=yes names=hidden | kept=no names=hidden |
| plates-names-tabs | tab=NamesService tabState=off row=on fight=yes | kept=yes names=game | kept=no names=game |
| plates-names-tabs | tab=NamesTarget tabState=off row=on | kept=yes names=game | kept=no names=game |
| plates-names-tabs | tab=NamesTarget tabState=off row=off fight=no | kept=no names=hidden | kept=no names=game |
| plates-names-tabs | tab=NamesExtras tabState=off row=on | kept=yes names=game marker=up | kept=no names=game marker=down |
| plates-names-tabs | tab=NamesExtras tabState=off row=off fight=no | kept=no names=hidden marker=down | kept=no names=game marker=down |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
medium: many readers, but every change is behind a tab being off, and tabs start on: no one with every tab on sees
anything change (all 40 tab-on cells unchanged, both clients). The meaning of "off" for the Enemy and Friendly tabs
(the game's own look, not hidden) is decided here: the user's call. Not proven offline: real plates' alphas in a
fight and out (the matrix reads the rows' answers, not a plate's alpha), forced plates with your own enemy plates
switched off (OwnKindShown), the live right-click flip settling within half a second, the Why window's new line.
