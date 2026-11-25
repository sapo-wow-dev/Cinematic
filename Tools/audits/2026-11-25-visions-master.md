# Visions: Enable Visions is a master switch, as Enable Style is (fix card)
Fix: Enable Visions was a cascade that switched every Vision page off and back on, so a page ticked back by hand, or a profile's, ran with Enable Visions off
Found by: audit 2026-11-25 (gating, your-call item E8); the user: "Make Visions a master"
Code: Core.lua: PAGE_SWITCH (visionsAll over every Vision page's switch), LEFT_OUT for Visions left out; Options.lua: Visions General's switch (no ns.CascadeHub, a refresh instead); Migrations.lua: a step putting back the pages the cascade had switched off (hubKept.Visions), visionsMasterV3
Clients: both
Base: 35e0e42

## Before / after
- Before: Enable Visions off switched each Vision page's own switch off (noting the ones on in hubKept),
  and on, back on. With it off, ticking Damage Vision's page on by hand, or loading a profile with it on,
  made Damage Vision run while Enable Visions still read off.
- After: Enable Visions sits over every Vision page's switch (Core.lua PAGE_SWITCH), as Enable Style over the
  Style pages: off, ns.Setting / ns.PageOn / ns.MasterOff read every Vision off, and the pages grey under it;
  their own switches stay as left. Flipping it refreshes what the Visions put on frames and plates
  (ns.RefreshOutsideCine), and their loops ask again within a second. Players whose Enable Visions was off:
  the update puts back the pages the cascade had switched off, once, so turning Enable Visions on brings back
  the same Visions it did.

## Who relies on the old behavior
(`python -I Tools/audit.py refs visionsAll CascadeHub hubKept`)
- Players: Enable Visions off: nothing changes (no Vision runs, before and after). A page ticked on by hand
  with it off: was running, now held off by Enable Visions (the point of the change).
- Other features: ns.CascadeHub stays for the HUD's switch (UI Manager), unchanged. Profiles carry visionsAll
  as before; a profile with it off and a page on now runs no Vision.
- Tests that encode it: none read the cascade; sweep, gate and tree matrices, profiles check run below.

## States (the matrix)
Enable Visions on or off, a Vision page's switch on or off, set live or after the old cascade plus the update.
Test: Tools/offline/visionsmastermatrix.lua forever
Test: Tools/offline/visionsmastermatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| visions-master | how=live visions=off page=on | runs=yes own=on | runs=no own=on |
| visions-master | how=updated visions=off page=on | runs=no own=off | runs=no own=on |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
medium: every Vision now also reads Enable Visions; one ticked on under an off Enable Visions stops. Not
proven in game: the pages greying under it, a live flip putting a Vision's frames back.
