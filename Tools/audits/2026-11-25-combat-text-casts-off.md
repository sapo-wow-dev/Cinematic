# Style: Combat Text's Spells tab no longer learns "never hits" from casts made while our numbers are off (fix card)
Fix: casts made with Combat Text Style off (the page, its General tab, the numbers switch, or Forever Combat Text loaded) were kept and counted as casts no hit took, so two of them marked the spell "never hits" for the session
Found by: audit 2026-11-25 (Combat Text by Spell, commit 67ac5f4)
Code: Style/CombatTextStyle.lua: OnCastEvent (DropOld, CastFits read what it keeps)
Clients: both
Base: cc7e40d376c2c6713a2c22b74542ec20cb109c68

## Before / after
- Before: with our numbers off, every cast of yours was still kept for its hit. Hits only reach the matching
  while our numbers are on, so each of those casts ran out "untaken" and counted against its spell. Two
  Shadow Bolts cast with the page off, and until /reload that spell's hits never took a cast again: its
  long-cast numbers didn't grow and its Spells tab look never showed. A cast made just before turning the
  numbers on could also be taken by the first hit after.
- After: casts made while our numbers are off aren't kept or counted at all (and cost nothing: no spell
  name, icon, description or harmful check). Any cast still waiting when one comes while off is let go
  uncounted. Turning the numbers on starts clean; a hit just after, with no cast since, takes none (its
  school's look, its size as it is).

## Who relies on the old behavior
(`python -I Tools/audit.py refs OnCastEvent CombatTextSpellMatch noHit`, read every hit.)
- Players: anyone who plays a while with Combat Text Style (or its numbers) off and turns it on without a
  /reload: their spells' sizes and Spells looks now work.
- Other features: TakeCast, TakeTick, PeekCast, TakeLongCast, Physical (castAt) read what OnCastEvent keeps;
  all of them run only from hits, which come only while On(). The wand's shots (off.wand) and channels
  likewise.
- Other addons: Forever Combat Text loaded (ns.combatTextBlocked): ours step aside, now the casts too.
- Tests that encode it: Tools/offline/combattextspells.lua (its page and numbers on: unchanged, PASS);
  Dev/CombatTextSpellsTest.lua sets the page and numbers on before casting.

## States (the matrix)
The spell's hit taken once before or never; our numbers off by the page, its General tab, the numbers
switch, Forever Combat Text, or not off; 0, 1 or 2 casts with no hit taken while that way; then on again
and a new cast and its hit, or a hit with no new cast (one cast just before turning on); the client.
Test: Tools/offline/combattextcastsoffmatrix.lua forever
Test: Tools/offline/combattextcastsoffmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| combat-text-casts-off | learned=no offCasts=2 then=cast off=page | spell=none secs=none | spell=Shadow Bolt secs=2.5 |
| combat-text-casts-off | learned=no offCasts=2 then=cast off=tab | spell=none secs=none | spell=Shadow Bolt secs=2.5 |
| combat-text-casts-off | learned=no offCasts=2 then=cast off=numbers | spell=none secs=none | spell=Shadow Bolt secs=2.5 |
| combat-text-casts-off | learned=no offCasts=2 then=cast off=blocked | spell=none secs=none | spell=Shadow Bolt secs=2.5 |
| combat-text-casts-off | then=hit off=page | spell=Shadow Bolt secs=2.5 | spell=none secs=none |
| combat-text-casts-off | then=hit off=tab | spell=Shadow Bolt secs=2.5 | spell=none secs=none |
| combat-text-casts-off | then=hit off=numbers | spell=Shadow Bolt secs=2.5 | spell=none secs=none |
| combat-text-casts-off | then=hit off=blocked | spell=Shadow Bolt secs=2.5 | spell=none secs=none |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: only players who cast with our numbers off and then turn them on in the same session notice, and what
they get is the tab working. The one hit that lands right as the numbers go on, from a cast made just
before, now shows in its school's look at its plain size (pinned). Not proven offline: a cast left waiting
when the numbers go off with no cast while off is still counted once when it runs out (one count; a spell
needs two to stop waiting), and the real switch toggles in game.
