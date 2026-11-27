# Style: Combat Text's Spells tab draws physical abilities in their own look (fix card)
Fix: a physical ability's hit (Mortal Strike, Sinister Strike) never took its cast, so a physical ability on the Spells tab never drew in its look in game and never showed under "Your spells that hit"
Found by: audit 2026-11-25 (Combat Text by Spell, commit 67ac5f4)
Code: Style/CombatTextStyle.lua: OnHit (the physical WOUND branch), TakeCast (the order casts are tried)
Clients: both
Base: cc7e40d376c2c6713a2c22b74542ec20cb109c68

## Before / after
- Before: a physical hit in the frame of a cast of yours is an ability's (yellow, Abilities' look), but it
  was claimed with no school, and the cast matching (CastOf) needs one: it took no cast and got no spell.
  The Add list offered Mortal Strike from the spellbook and the preview played it in its look, but in
  fights its hits always drew as plain Abilities, and it never came under "Your spells that hit".
- After: an ability's hit comes with its school (physical) and takes its cast: the newest one (the cast in
  its frame), so a Mortal Strike right after a Charge (no hit of its own) is Mortal Strike's, not Charge's.
  It draws in its Spells tab look when listed and is learned under "Your spells that hit" either way.
  White swings, a swing landing while an ability's cast still waits, and misses (a dodged Mortal Strike)
  take no cast, as before.

## Who relies on the old behavior
(`python -I Tools/audit.py refs CastOf TakeCast Physical`, read every hit.)
- Players: anyone with a physical ability on the Spells tab sees its look now; with none listed, an
  ability's number looks as before (the Abilities text, instant: 100% size, rank as an ability's already).
  Its spell is now learned for the Add list (CinematicCharDB.combatTextSeen) under Abilities.
- Other features: Claim's checks that read the school all also need "not melee" (off-class, In a group's
  scoring), so an ability's hit goes the same way as before; Mine marks the mob for its school (physical:
  no group hit is ever scored by it). TakeCast's order changes only for physical hits, which reached it
  never before (a bandage's heal, school 1, is a channel: taken before the list).
- Other addons: none.
- Tests that encode it: combattextspells.lua (spells' hits, not physical: unchanged), linekinds.lua,
  linecolors.lua, totemhit.lua, totemcast.lua: PASS as they are and in their HEAD versions.

## States (the matrix)
The hit: an ability in its cast's frame, one just after a Charge, a white swing, a swing while an ability's
cast waits, an ability dodged, a Fire spell's; a crit or not; the spells listed (each its own color) or
not; the combat log's lines coming or not; the client.
Test: Tools/offline/combattextabilitymatrix.lua forever
Test: Tools/offline/combattextabilitymatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| combat-text-ability-cast | hit=ability listed=yes | look=plain seen=none | look=Mortal Strike seen=Mortal Strike |
| combat-text-ability-cast | hit=ability listed=no | look=plain seen=none | look=plain seen=Mortal Strike |
| combat-text-ability-cast | hit=abilityAfterCharge listed=yes | look=plain seen=none | look=Mortal Strike seen=Mortal Strike |
| combat-text-ability-cast | hit=abilityAfterCharge listed=no | look=plain seen=none | look=plain seen=Mortal Strike |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: only physical abilities' hits change, and only in which spell they're learned as and drawn in (an
unlisted one looks the same). A swing that lands in the very frame of a cast of yours is still read as an
ability's (as before): it now takes that cast, the newest harmful one, so its number may draw in that
spell's look. A dodged or parried ability still leaves its cast waiting (counted as a cast no hit took
when it runs out, as a resisted spell's). Not proven offline: real Forever and retail fights (the cast's
frame against the hit's), an area ability's (Cleave, Whirlwind) several hits in one instant.
