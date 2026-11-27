# Style editor: Reset everything puts the unit and raid frames' Look from back (fix card)
Fix: Reset > "Everything in Style" counted Unit frames' and Raid frames' "Its own look" but wrote nothing (ns.UnitStyleSetOwn / ns.RaidStyleSetOwn are gone), so it never reached 0
Found by: audit 2026-11-25 (style editors from b53755f)
Code: Style/Studio/Frames/CombatBand.lua: UnitOwnField, RaidOwnField (set)
Clients: both
Base: cc7e40d

## Before / after
- Before: with a unit frame (Player, Target...) or a raid group set to "Its own look" on Unit Frame Style / Raid
  Frame Style, the editor's Reset > Everything in Style counted it, left it on its own look, and counted it again
  the next time: the count never reached 0.
- After: Reset puts it back to Follows Default (ufOwn_<frame> / rfOwn_<group> false, written as the old pages'
  Look from dropdown does); the next Reset counts 0 for it; Undo gives its own look back (its own settings were
  never touched, so they're as they were).

## Who relies on the old behavior
(`python -I Tools/audit.py refs UnitStyleSetOwn RaidStyleSetOwn ufOwn_ rfOwn_`, every hit read.)
- Players: anyone pressing Reset > Everything in Style on Nameplate Style / Name Style / Layout / Range Hint with a
  frame on its own look: it now follows Default after (as Reset says). Nobody can have relied on it staying.
- Other features: Style/UnitStyle.lua and RaidStyle.lua's page dropdowns (SetOwn: also copy Default's look the
  first time, ufStarted_/rfStarted_); the field's set doesn't copy: Reset only gives Follows Default, Undo only a
  look the frame had (its copy already made). Style/StyleThemes.lua:1192 snapshots the keys; unchanged.
- Other addons: none.
- Tests that encode it: Dev/GradientTest.lua, Dev/DimNameTest.lua write the keys directly; unaffected.

## States (the matrix)
The frame or group (Player, Target, Raid; retail's Arena group goes the same way, the same field, left out: a
retail-only cell can't be declared for both clients), its Look from (own or Follows Default), its page's
switch (ufStyle / rfStyle), the client.
Test: Tools/offline/styleresetownmatrix.lua forever
Test: Tools/offline/styleresetownmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| style-reset-own | which=PLAYER look=own | counted=1 after=own again=1 undo=own | counted=1 after=default again=0 undo=own |
| style-reset-own | which=TARGET look=own | counted=1 after=own again=1 undo=own | counted=1 after=default again=0 undo=own |
| style-reset-own | which=RAID look=own | counted=1 after=own again=1 undo=own | counted=1 after=default again=0 undo=own |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: only Reset everything in Style (and its Undo) reaches these fields; the Unit/Raid Frame Style pages are their
old code and write the keys themselves. Not proven in game: the unit and raid frames redrawn to Default's look
right after the Reset (Studio.Reset refreshes every frame's runtime). Open (the user's call, not changed): Reset
everything in Style reaches every registered Style frame, also pages that no longer use this editor (Tooltips,
Minimap, Combat Text, Quest Talk, Unit/Raid frames...).
