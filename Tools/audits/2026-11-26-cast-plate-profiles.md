# Profiles: the nameplates' own cast bar settings saved, shared and reset (fix card)
Fix: Cast Bars' Nameplates settings of their own (<key>_PLATE) were left out of profiles, share strings and backups, and "(changed)" missed them
Found by: audit 2026-11-26 (Nameplate Style editor, 679e735 / a16eb17)
Code: Style/PlateCastStyle.lua: ns.CastPlateDefault (new); Core.lua: ns.MarkRowDefault; Profiles/Profiles.lua: CastPlateChanges (new), ns.ProfileChanged, ns.ProfileChangedDebug, ns.ResetAddon
Clients: both
Base: e0ca9065ba70b460efc1b6485acec750446c45a9

## Before / after
- Before: since the nameplates' cast settings follow Default one by one (no DEFAULTS entry for <key>_PLATE), the
  profile code (all of it built from pairs(ns.DEFAULTS)) never saw them. A Nameplates cast setting of your own
  stayed in the live settings on a profile switch (so the next profile had it too), Reset profile left it, an export
  left it out, a backup left it out, an older string's plateCast*_PLATE values were skipped with "settings from a
  newer Cinematic will be skipped", and the Profiles page's "(changed)" didn't count it.
- After: they go through Core's MarkRowDefault (as Name Style's rows and Combat Text's spells do), with Default's
  default as their kind: saved with the profile, cleared and loaded on a switch, exported and imported, backed up
  and restored, cleared by Reset profile, counted by "(changed)" (and /cine debug changed). Reset Settings doesn't
  keep them in a built-in (it keeps only what you made there: rows, cameras, themes).

## Who relies on the old behavior
(`python -I Tools/audit.py refs MarkRowDefault EachRowSetting ProfileChanged _PLATE`, every hit read.)
- Players: anyone with a Nameplates cast setting of their own since 679e735 (one day, unreleased): on the next
  switch the profile they switch to drops it (it was carried over). Profiles saved before 679e735 with "Its own look"
  on keep their plateCast*_PLATE copies (Migrations.lua castPlateFollowsV1 clears only those with it off): those now
  load as the nameplates' own on a switch, as they were saved.
- Other features: MarkRowDefault's other callers: Options.lua FindSetting (/cine find plateCastFill_PLATE now opens
  it, as before 679e735), Dev/Prerelease.lua's findable-ids check (the same ids as before 679e735), ProfileModules'
  module key check (a module may set them), Style/Studio/Frames/Nameplates.lua RowKey/PlateColorField (only the
  Nameplates frame's mark keys reach it, none end in _PLATE). Profiles.lua's EachRowSetting users: Snapshot, Load,
  ProfileSettings, AgainstDefaults, EachInSlot (Customize: a choice has none of them, so a live one is cleared as
  the slot's, as other rows' are), ResetAddon (now skips them).
- Other addons: none.
- Tests that encode it: none read these keys through profiles (castlook.lua, styleeditorhovermatrix.lua and
  castplateasmatrix.lua set them on the live db only).

## States (the matrix)
Which setting (the nameplates' own, Target & focus's own: a neighbor with a default all along), the profile has one
of its own or none, and what's done: switch away and back, switch to another profile, "(changed)", an export
imported, an older string with it, a backup restored, Reset profile, Reset Settings.
Test: Tools/offline/castplateprofilematrix.lua forever
Test: Tools/offline/castplateprofilematrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| cast-plate-profiles | key=plate own=set path=carry | mine | follows |
| cast-plate-profiles | key=plate own=set path=reset | mine | follows |
| cast-plate-profiles | key=plate own=set path=changed | changed=no | changed=yes |
| cast-plate-profiles | key=plate own=set path=export | follows | mine |
| cast-plate-profiles | key=plate own=set path=backup | follows | mine |
| cast-plate-profiles | key=plate own=set path=oldstring | follows skipped=1 | mine skipped=0 |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: only the nameplates' own cast settings, which nothing kept before. Not proven in game: the Profiles page's
"(changed)" word redrawn after a Nameplates cast change, and an export pasted on another character.
