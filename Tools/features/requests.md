# Feature requests

One line per wish, kept by the /feature skill. A repeat ask adds its date and
source to the same line.

Category: a already there, b can do, c part of it, d can't, e unknown, f doesn't fit.

| Date | Wish | From | Cat | Status |
|---|---|---|---|---|
| 2026-11-18 | Entering combat card with its own words and look for a fight against players (PvP) vs mobs | Discord #requests "Combat Cards" (likely Forever, from screenshot); links "Card Vision" thread | c/e | built 2026-11-23 (uncommitted): Entering a PvP fight row, on for new installs (off for players from before, pvpCardOffV1), words "Rival"; offline pvpcard.lua 20/20, /cine debug pvpcard 4/4 (pretend duel); a real enemy player's reads still untested |
| 2026-11-23 | Show a mob's whole nameplate while the mouse is on it, without targeting it | Discord (rudy), Forever (screenshot) | b | built 2026-11-23 (uncommitted): Nameplates page, Target section, Mouseover row under Your target (row:plate:YourMouseover, every box off to start); offline hoverplate.lua ALL PASS both clients; /cine debug mouseplate run 4 (2026-11-23, Forever): works, whole in 1.5 s and back down after; fights and retail untested |
| 2026-11-23 | Square minimap with a plain border (like Leatrix Plus), and more minimap styling | Discord #requests "Formal Request for Minimap Styling options" (Discipline), Forever | b | built 2026-11-23 (uncommitted): new Style > Minimap page (minimapStyle; Interface Recolor's ring rows moved there): Square minimap, border size + color, zone name and clock inside, size, hide zoom/zone bar/dial; retail row hidden (untested there); offline squaremap.lua ALL PASS, /cine debug minimapsquare 23/23 + layout run 6/6 (Forever) |
