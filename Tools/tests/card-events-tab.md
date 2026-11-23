# Card Vision Events tab (rebuilt 2026-11-23)

Test: `/cine debug cardevents` (Dev/CardEventsTest.lua). Mockups: Option B with tabs, picked by the user.

| run | client | result | notes |
| --- | --- | --- | --- |
| 1 | forever | 19/19 | tiles, picks, tabs, tab off, find, page off all pass; shots never showed the tab row (below the window): test now scrolls to it |
| queue qcb80 | forever | 23/23 | compact layout: preview 300x150, type settings beside it (x 1538 vs preview right 1522), tabs and first 4 rows on the first screen |

Open: retail not run yet. Offline sweep: the known Card Vision stack overflow (stand-in sizes never settle) now reports from wow.lua; added to both baselines.
