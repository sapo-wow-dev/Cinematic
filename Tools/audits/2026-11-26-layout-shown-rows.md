# Nameplate Layout: the Shown rows are the Overrides' setting (fix card)
Fix: Layout's Shown rows looked per-kind but were one setting, greyed by Layout's switch though the Overrides decide, and reset by Layout's resets
Found by: audit 2026-11-26
Code: Style/Studio/Frames/Nameplates.lua: the Layout parts' Shown rows (LayoutShown, ShownStatus, partStatus);
Style/StyleOverrides.lua: ns.StyleOverrideOn (ns.StyleOverride's gate, now its own function); Style/Studio/Editor.lua:
Studio.ResetWrites (prop.otherPage), Studio.Status (f.partStatus); Style/Studio/Studio.lua: body:Draw passes its
variant and part to Studio.Status
Clients: forever
Base: e0ca906

## Before / after
- Before: on Nameplate Layout (Forever), each part's Shown row (Health, Name, Level, Debuffs, Buffs, Raid marker,
  Elite, Cast bar: styleOver_platePart*, the Style hub's Overrides tab's) was on every Layout for kind, so a player
  who set Level Hidden on Hostile hid it on every plate. It greyed with Layout's own switch, but the plates use it by
  the Overrides' gate (ns.StyleOverride: the addon on, Style, the Overrides tab and its Nameplates tab on): with
  Layout off it was greyed yet still hid the part; with the Overrides off it was live yet did nothing. Every Layout
  reset (This part, This variant, Everything on this page, the Theme's look) put it back to "As its page says".
- After: the Shown row is on All plates only (no kind has a key of its own). It's live while the Overrides use it and
  greyed while they don't, with a status line over the settings: "Shown belongs to the Style hub's Overrides tab,
  which is off, so it doesn't change your plates." With Layout off and the Overrides on, the Layout-off line adds
  "Shown belongs to the Style hub's Overrides tab: it changes your plates with Nameplate Layout off too." Layout's
  wider resets leave it be; its own row's Reset (right-click, the row's reset mark) still puts it back. Layout's
  Reset page didn't touch it before and still doesn't.

## Who relies on the old behavior
(`python -I Tools/audit.py refs styleOver_platePart platePartLevel StyleOverride SHOWN_ROW`, read every hit.)
- Players: a Shown pick made on a kind is kept (one key) and now shows on All plates only. A player who used a
  Layout reset to clear a Shown pick now clears it on its row, or on the Overrides tab (Clear overrides).
- Other features: ns.StyleOverride unchanged (its gate moved into ns.StyleOverrideOn, called by it: same answer for
  every key); the plates (PlateParts.lua's UpdatePlateParts, PlateRowLook.lua's preview) read ns.StyleOverride as
  before. The Overrides frame (GeneralBand.lua) has its own Shown rows for the same keys: Everything in Style and its
  own resets still reset them. Studio.Status's new arguments are optional; only Layout gives f.partStatus.
  ns.PageSettings still lists the keys under Nameplate Layout (its RecordKey loop is unchanged).
- Other addons: none.
- Tests that encode it: Dev/StyleStudioTest.lua sets styleOver_platePartLevel itself (unchanged); stylestudio.lua,
  platelayoutpage.lua, styleresetscopematrix.lua (MakeYours picks a slider or switch, never a Shown row) all PASS.

## States (the matrix)
Layout for (All plates, Hostile), Layout's switch (plateLayout on/off, Nameplate Style's on), the Overrides' gate
(open, its Nameplates tab off, the Overrides off, Style off, the addon off), the action: the Level part's Shown row as
the Layout page's editor draws it (shown, greyed, the status line), or with it set Hidden: the row's own Reset, Reset's
This part / This variant / Everything on this page (This frame before the reset-scope fix), the Reset page button.
Retail: no Layout (not-on-client, pinned).
Test: Tools/offline/layoutshownmatrix.lua forever
Test: Tools/offline/layoutshownmatrix.lua retail

## Meant to change
Only these cells may change; any other changed cell fails `audit.py diff`. Cell = the pairs a cell must have.
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| layout-shown-forever | variant=all layout=on action=row | shown=yes greyed=no status=none | shown=yes greyed=yes status=overrides-off |
| layout-shown-forever | variant=all action=row | shown=yes greyed=yes status=layout-off | shown=yes greyed=yes status=layout-off+overrides-off |
| layout-shown-forever | variant=all layout=off gate=open action=row | shown=yes greyed=yes status=layout-off | shown=yes greyed=no status=layout-off+still-used |
| layout-shown-forever | variant=hostile action=row | shown=yes greyed=no status=none | shown=no status=none |
| layout-shown-forever | variant=hostile action=row | shown=yes greyed=yes status=layout-off | shown=no status=layout-off |
| layout-shown-forever | variant=hostile action=reset:row | reset | no-row |
| layout-shown-forever | action=reset:part | reset | kept |
| layout-shown-forever | action=reset:variant | reset | kept |
| layout-shown-forever | action=reset:page | reset | kept |

## Expectations changed
Existing checks, ledger answers or rules whose expectation this fix changes (`audit.py oldtests`, the guard).
Each needs the user's OK before the commit, quoted here.
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: Nameplate Layout's editor only (Forever), and every Shown row there. The plates' use of the setting is unchanged
(ns.StyleOverride gives the same answers). Pinned: every row, reset and status cell, both clients. Not proven offline:
the status line as drawn in game (its wrap and height over the settings; the matrix reads the stand-in's text), and
that the row greys and the line shows again when the Overrides are turned on or off on their own page while Layout's
page is open (the editor redraws on show).
