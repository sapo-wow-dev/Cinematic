# Style: Combat Text's Spells tab files a spellbook heal under Heals once it's seen (fix card)
Fix: a heal added to the Spells tab from the spellbook stayed a damage spell for good: under its school, previewed and colored as damage
Found by: audit 2026-11-25 (Combat Text by Spell, commit 67ac5f4)
Code: Style/CombatTextTexts.lua: CT.NoteSeen
Clients: both
Base: cc7e40d376c2c6713a2c22b74542ec20cb109c68

## Before / after
- Before: the Add list adds a spellbook spell as a damage spell (its kind isn't known before its first hit).
  When its hit was seen, NoteSeen learned its school and whether it ticks, never its kind, so Healing Wave
  filed under Nature, its look started from Nature's, and its preview played it as a damage hit.
- After: a listed damage spell seen as a heal (or your pet's) becomes that: under Heals (Your pet), its look
  starting from the Heals text, its preview a heal. Its own settings stay. One listed as a heal or your
  pet's stays so; a damage sighting changes nothing. Players who added a heal before this fix get it on
  its next heal.

## Who relies on the old behavior
(`python -I Tools/audit.py refs NoteSeen combatTextSpells`, read every hit.)
- Players: their combatTextSpells list (per profile): an entry's kind may change from "damage" to "heal"
  or "pet" once seen so; profile sharing takes all three (Profiles.lua's check).
- Other features: CT.SpellBase, CT.SpellGroups (the tab's headings), CombatTextSpells.lua's preview and
  Look panel read the kind. Spawn calls NoteSeen with CT.Kind of the text drawn.
- Other addons: none.
- Tests that encode it: combattextspells.lua C7 (a damage spell's first tick: its school learned): PASS.

## States (the matrix)
The spell added from the spellbook (not seen yet, or seen once already), as a heal, as your pet's, or not
listed; seen as a damage hit, a heal or your pet's; a direct hit or a tick; the client.
Test: Tools/offline/combattextseenkindmatrix.lua forever
Test: Tools/offline/combattextseenkindmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| combat-text-seen-kind | added=book seenAs=heal | kind=damage base=spellNature | kind=heal base=heal |
| combat-text-seen-kind | added=book seenAs=pet | kind=damage base=spellNature | kind=pet base=pet |
| combat-text-seen-kind | added=bookSeen seenAs=heal | kind=damage base=spellNature | kind=heal base=heal |
| combat-text-seen-kind | added=bookSeen seenAs=pet | kind=damage base=spellNature | kind=pet base=pet |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: only listed spells seen as heals or your pet's change, and they move to the heading they belong
under. A spell that both harms and heals is never seen as a heal today (its heal never takes its cast), so
it stays a damage spell. Not proven offline: the tab's rows moving while the page is open (they rebuild
on the next page show).
