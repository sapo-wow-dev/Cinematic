# Mouseover nameplate (Nameplates page, Target section, Mouseover row)

A player's wish (Discord, Forever, 2026-11-23): the whole plate of the unit
under the mouse, without targeting it.

- Code: Effects.lua `ns.plates.hover` / `UpdateHover` / `HoverLevel` (faded
  in like Your target's, out when the mouse leaves; a 0.1 s watcher, as no
  event says the mouse left). Row `YourMouseover` in ns.PLATE_UNIT_ROWS.
- Offline: `python -I Tools/offline/run.py Tools/offline/hoverplate.lua <forever|retail>`
  ALL PASS both (2026-11-23).
- In game: `/cine debug mouseplate` (Dev/HoverPlateTest.lua). Run 1 (2026-11-23) never ran: `hoverplate` was taken by the hover watch (`arg:find("^hover")`); renamed, and Tools/kit-names.py (pre-commit) now catches such clashes. Run 2 (Stormwind, 6/0/1): page row + ready PASS (proven); hover SKIP, the unit under the mouse changed in the crowd before the one read 4 s later: step 3 now samples every 0.25 s.
- Open: Forever in a fight (plates of kinds hidden in fights are alpha 0:
  should rise too); retail untested.
- Run 3 (Stormwind guard, 5/2/0): row off stays 0 (PASS); the hold came ~2 s
  after the row was ticked mid-hover (no event: the settled pass's 2 s
  refresh), so the reads at 2.25 s saw 0.05 (FAIL); it then reached ~1 (0.71
  at 0.3 s after leaving, fading, not cut: PASS). Real use can't tick the row
  while hovering (the mouse is on the menu), and coming onto a unit fires
  UPDATE_MOUSEOVER_UNIT, which wakes the pass. The test now wakes it the
  same way after ticking. Name alpha unread (no GetEffectiveAlpha on the font
  string): read as own alpha x parent's.
- Run 4 (queue qd36b, Goldshire guard, 6/1/0): WORKS. Row off 0.00 in 8
  samples; row on 0.16 / 0.51 / 0.85 / 1.00 over 1.5 s (frame, bar and name
  alike), held; mouse off: 0.74 at 0.3 s, 0 at 2.1 s, hold let go. The FAIL
  was the test's: other plates with names kept by other rows (0.24-1.00)
  read the same before and after; the check now says "left as they were".
  Steps 3-4 proven by this run. Open: in a fight; retail.
