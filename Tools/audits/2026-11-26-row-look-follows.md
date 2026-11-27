# Nameplate Style: the rows' look update keeps every plate's look (fix card)
Fix: rowLookFollowsV1 (679e735, unreleased) read a row's Plate color from the row alone, but a row with none takes its parent's (npcEnemy2 -> npcEnemy -> npc). A row inheriting Custom lost its Look; a copy not Custom under a Custom row, its own Look cleared, showed its parent's.
Found by: release review 2026-11-26
Code: Migrations.lua: the rowLookFollowsV1 step
Clients: both
Base: e0ca906

## Before / after
- Before: after the update, some Smart rows' plates changed look: a numbered, Distance or Who row with no Plate color of its own under a Custom row lost its texture, border and font (the Default row's instead); a copy set to Gold under a Custom row took that row's look; a Custom row with nothing of its own under a row set to Gold lost the look it had from it.
- After: no plate's look changes, for every row shape. Each row's look is worked out as it showed (its Plate color and Look through its parent chain), the rows not Custom have their unused Look cleared, and a row whose look would now come from its parent's gets the values that keep it as it was (the Default row's "default" values for one that wasn't Custom, the parent's for a Custom one).

## Who relies on the old behavior
(`python -I Tools/audit.py refs rowLookFollowsV1 PLATE_LOOK_DEFAULTS`, every hit read.)
- Players: none yet. v2.1.34 has no rowLookFollowsV1 (`git show v2.1.34:Migrations.lua`: 0 hits); it is only in 679e735, unreleased, so it is corrected in place with the same done flag. The author's dev copy already ran the old one (its rows as they are now; not put back).
- Other features: PlateRowLook.lua's Own (now any row's, whatever its Plate color) and PlateParts' OwnSetting (the parent chain) read what it leaves: both read only.
- Other addons: none.
- Tests that encode it: Tools/offline/platekindcolors.lua "migration: not Custom, cleared" / "Custom, kept" (base rows: still true); card 2026-11-25-nameplate-style-mock.md says "no plate changes" (now true for every shape).

## States (the matrix)
The row's kind (Focus starts at "same", Not your kill at Custom) x its shape (the kind's own, a Who, a numbered copy, a Distance, a copy of a Distance) x its Plate color (unset: its parent's; Custom; Gold) x a Look texture of its own or not x its parent's Plate color x the parent's own Look texture. Each cell: the texture the row's plates and its parent's show after the update. Every cell pinned with what they showed before it (worked out in the test from the v2.1.34 rule, on its own).
Test: Tools/offline/rowlookfollowsmatrix.lua forever
Test: Tools/offline/rowlookfollowsmatrix.lua retail

## Meant to change
Only these cells may change; any other changed cell fails `audit.py diff`. Cell = the pairs a cell must have.
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| rowlookfollows | color=custom look=none plook=par | row=none parent=none | row=par parent=none |
| rowlookfollows | color=gold plook=par | row=par parent=par | row=none parent=par |
| rowlookfollows | color=unset look=own plook=none | row=none parent=none | row=own parent=none |
| rowlookfollows | color=unset look=own plook=par | row=par parent=par | row=own parent=par |
| rowlookfollows | kind=tapped shape=distcopy color=custom look=own pcolor=unset plook=par | row=own parent=none | row=own parent=par |
| rowlookfollows | kind=tapped shape=distcopy color=gold pcolor=unset plook=par | row=none parent=none | row=none parent=par |
| rowlookfollows | kind=tapped shape=distcopy color=unset look=own pcolor=unset plook=par | row=none parent=none | row=own parent=par |
| rowlookfollows | kind=tapped shape=distcopy look=none pcolor=unset plook=par | row=none parent=none | row=par parent=par |

## Expectations changed
Existing checks, ledger answers or rules whose expectation this fix changes (`audit.py oldtests`, the guard).
Each needs the user's OK before the commit, quoted here.
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: the step hasn't reached players; it touches only Look keys of the rows on the grid. Pinned: 360 cells a client, every shape, color and Look mix, the texture as the stand-in. Not proven offline: the other Look keys (border, font, size, outline, shadow, level box, gradient) go through the same code per key but only the texture is in the matrix; profiles' saved copies run the same Clear; rows not on the grid (parents only read through the chain) are left as they are.
