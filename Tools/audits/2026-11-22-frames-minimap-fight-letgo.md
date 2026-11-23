# Frames: the minimap let go in a fight while parked full size (fix card)
Fix: a faded minimap kept full size (a Reveal tick, the dots sweep) is parked off the right edge; let go in a fight
with it protected (an addon's secure button on it), it had no waiter, so it stayed off the screen till a reload.
Found by: audit 2026-11-22; fixed in 7c3e0c1 (retroactive card, 2026-11-23)
Code: Frames.lua: RemoveFrame() (the parkedFullSize + ns.ScaleBlocked branch), ns.UnparkFullSize, ns.UnparkShrunk
Clients: both
Base: 7c3e0c1^

## Before / after
- Before: with a minimap kept full size while faded, switching its fade off (or a profile, /cine keep) in a fight
  with an addon's secure button on the minimap left it off the screen till a /reload.
- After: it stays where it is for the rest of the fight (it can't be moved then), and comes back on its own spot,
  clamped again, as the fight ends, as a shrunk one always did.

## Who relies on the old behavior
(`python -I Tools/audit.py refs UnparkFullSize parkedFullSize ParkFullSize`)
- Players: anyone with a Minimap Reveal tick or the dots sweep and an addon's secure button on the minimap
  (protected), who lets the minimap go in a fight. Nobody wants the old behavior.
- Other features: Diagnostics.lua's sweep Stay() (unparks out of a fight), Frames.lua 2076/2096 (the pass parks and
  unparks), NodeSweep.lua, ShoulderCam.lua's savedRect read. None relies on the frame staying parked.
- Other addons: SexyMap, EllesmereUI lay the minimap out themselves (the meanwhile=laidout cells: left where they put it).
- Tests that encode it: Tools/offline/minimapfightpark.lua checks 1-2 (kept); Dev/ShoulderCamTest.lua prints
  parkedFullSize only; memory forever-minimap-blobs.md.

## States (the matrix)
park (shrunk / fullsize / none) x fight (yes / no) x protected (yes / no) x clamped to the screen (yes / no) x
another addon laying it out before the fight's end (nothing / laidout), per client. 48 cells per client.
Test: Tools/offline/minimapletgomatrix.lua forever
Test: Tools/offline/minimapletgomatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| minimap-letgo | park=fullsize fight=yes protected=yes clamped=no meanwhile=nothing | now=parked end=parked scale=full | now=parked end=home scale=full |
| minimap-letgo | park=fullsize fight=yes protected=yes clamped=yes meanwhile=nothing | now=parked end=parked scale=full clamp=off | now=parked end=home scale=full clamp=on |
| minimap-letgo | park=fullsize fight=yes protected=yes clamped=yes meanwhile=laidout | now=parked end=elsewhere scale=full clamp=off | now=parked end=elsewhere scale=full clamp=on |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none (retroactive) | | | | |

## Risk
low: one new branch in RemoveFrame; every other cell unchanged on both clients (audit.py card --new 7c3e0c1).
Not proven offline: the real PLAYER_REGEN_ENABLED order against the pass re-taking the minimap at the fight's end
(the matrix lets it go and ends the fight with nothing else running), and the game's own refusal to move a protected
minimap in a fight (the matrix trusts ns.ScaleBlocked).

## Open
- user's call: laid out elsewhere by another addon while waiting (meanwhile=laidout), it's left where that addon put
  it, not pulled back to the spot saved before it was parked. Pinned so (the addon's layout wins).
