# Cooldown Manager: v2.1.23's lines carried over exactly (fix card, retroactive)
Fix: the update from the numbered lines to the grid (cooldownGridV1, 2026-11-22) lost or changed a v2.1.23
setup: the rule the situations update wrote ("(dungeon or raid) and (combat or calm)") became a rule scene of its
own that took over the other spells' places; a spell's own setting lost to its bar's situation line; a line with
no place was dropped; and a string or backup from v2.1.23 came in with no lines at all.
Found by: release review 2026-11-22; fixed in ae2cda8 (card written after, 2026-11-23)
Code: Migrations.lua: ns.MigrateCooldownLines and the cooldownGridV1 step; Profiles/Share.lua ReadSharedProfile;
Profiles/Backups.lua Known
Clients: both
Base: ae2cda8^

## Before / after
- Before (v2.1.24 builds before ae2cda8): updating from v2.1.23, a spell with no lines of its own could lose its
  bar's Dungeons line where another spell on the bar had a rule; a spell's own Raids line was lost the same way; a
  line with no place did nothing; a spell's own Always/Never lost to its bar's situation line; a v2.1.23 string or
  backup had no Cooldown Manager lines.
- After: every spell does in each place and fight what its v2.1.23 lines did: its first line that fits, else its
  own mode, else its bar's first line that fits, else the bar's default; a line with no place is anywhere; one
  spell's lines never change another's; a string or backup gets the same.

## Who relies on the old behavior
(`python -I Tools/audit.py refs MigrateCooldownLines cooldownGridV1`)
- Players: anyone updating from v2.1.23 with Cooldown Manager lines (saved, in a profile, reset point, backup,
  a deleted profile's backup, or a string shared from v2.1.23). Nobody relies on the lines being lost.
- Other features: UI/CooldownRules.lua (the scenes and cells read), Frames.lua ns.CooldownSpellMode.
- Tests that encode it: Tools/offline/cooldowngrid.lua (the update checks, the review's added), cooldownoldshare.lua
  (new with the fix); ledger Tools/tests/cdm-grid.md; this matrix.

## States (the matrix)
One spell X on the Essential bar: where the settings come from (live, a saved profile switched to, a v2.1.23 string
pasted, a backup restored after the update ran) x X's own mode (none, Always, Never) x its bar's line (none, a
Dungeons In combat line, one with no place, the situations' rule) x X's own line (none, Raids, no place, the
situations' rule, a real rule "boss") x another spell's line on the bar (none, the situations' rule, a real rule).
Outcome: X's mode in a dungeon fight, dungeon out of fights, raid fight, open-world fight, open world out of fights,
dungeon boss fight. Pins worked out from v2.1.23's reading of the lines. 720 cells per client.
Test: Tools/offline/cooldownlinesmatrix.lua forever
Test: Tools/offline/cooldownlinesmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| cooldown-lines | from=string | * | * |
| cooldown-lines | from=backup | * | * |
| cooldown-lines | spell=noplace | * | * |
| cooldown-lines | bar=noplace | * | * |
| cooldown-lines | spell=place other=situation | * | * |
| cooldown-lines | bar=place other=situation | * | * |
| cooldown-lines | bar=place other=rule | * | * |
| cooldown-lines | spell=rule other=situation | * | * |
| cooldown-lines | own=always bar=situation | * | * |
| cooldown-lines | own=never bar=situation | * | * |
| cooldown-lines | bar=situation spell=rule | * | * |

(426 cells per client: every string and backup cell with lines (lost before); the no-place lines (dropped
before); another spell's rule taking over X's places or its bar's (the scene for the situations' rule, or a real
rule's, before X's place lines); a spell's own Always/Never under its bar's situation rule; and the bar's
situation rule beating X's own real rule in a boss fight.)

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none (cooldowngrid.lua's review checks and cooldownoldshare.lua were added with the fix) | | | | |

## Open (user's call)
- A spell's own mode against its bar's line: v2.1.23 read the spell's own mode first, pinned so (the fix's aim).

## Risk
medium: a rewrite of the whole conversion. Every other cell unchanged on both clients. Not proven offline: more
scenes than the grid draws (9) with real rules, where the fix keeps one scene per rule by majority.
