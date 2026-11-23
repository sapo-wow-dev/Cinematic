# Cooldown Manager: two old rules true at once keep each spell's own (fix card)
Fix: updating from v2.1.23 (ae2cda8's carry-over), when two spells (or bars) had different real rules that are true together (one spell's "boss", another's "combat": a boss fight is a fight too), only the first-met rule's scene was used, so the other spell lost its rule and fell back to its plain answer.
Found by: card audit of the v2.1.24 audit fixes, 2026-11-23 (finding 2, verified by running); the user: "Fix 1, 2, 3"
Code: Migrations.lua: ns.MigrateCooldownLines (Answers takes a set of true rules; a scene per set of rules, before the single-rule scenes)
Clients: both
Base: 63a724f

## Before / after
- Before: A "boss -> proc", B "combat -> never". In a boss fight v2.1.23 showed A proc and B never; the grid had
  scenes "boss" then "combat", only the first that fits is in use, so B (no cell in "boss") showed its plain answer.
  The other order: A "combat -> never", B "boss -> proc": B's boss rule never applied at all.
- After: a scene for the rules together ("(boss) and (combat)") goes first, with each spell's answer when they're all
  true (its own first line that fits, as v2.1.23 read it); only where that changes what the later scenes would give.
  Sets of 2-4 rules, smallest first while the grid's 9 scenes have room (the rest counted in the "left out" note).

## Who relies on the old behavior
- Players: anyone updating from v2.1.23 or earlier from now on, and v2.1.23 profile strings and backups, with real
  rules on two or more spells or bars. Nobody relies on the lost rule.
- Not repaired: setups already updated on v2.1.24-v2.1.26 (the update deletes the old lines once done; the order of
  each spell's lines, needed to work out the combined answers, isn't in the grid). They keep what they have.
- Other features: UI/CooldownRules.lua (reads scenes, first that fits: unchanged), the page's scene list (one or two
  more scenes, named by their rules).
- Tests that encode it: cooldown-lines (720 cells, unchanged), cooldowngrid, cooldownoldshare (old versions hold).

## States (the matrix)
cooldown-lines as before. New cooldown-rules-overlap: from (live, a v2.1.23 string) x A's rule (boss, combat) x B's
rule (none, boss, combat) x which is met first; outcome both spells' modes at six moments, pinned from v2.1.23's
reading (each spell's own rule where it fits, else the bar's default).
Test: Tools/offline/cooldownlinesmatrix.lua forever
Test: Tools/offline/cooldownlinesmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| cooldown-rules-overlap | a=boss b=fight | * | * |
| cooldown-rules-overlap | a=fight b=boss | * | * |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none (a new matrix part; the 720 old cells, cooldowngrid and cooldownoldshare unchanged) | | | | |

## Risk
low: runs once per old setup or imported string; more scenes only where rules overlap and change answers. Not proven
offline: three or more overlapping rules (sets of 3-4: written, not in the matrix), place lines mixed with rules in
one set's scene, the 9-scene limit with sets.
