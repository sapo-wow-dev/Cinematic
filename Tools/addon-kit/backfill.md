# Addon kit backfill (step 8)

Every supported addon through the kit, one client at a time. Each queue run is one `/cine debug addonkit` with
up to 11 addons: the baseline first, then each addon alone (probes + rows). You click Reload once per stage.
After each run: `python -I Tools/addon-kit/diff.py all <client>`, then fix what fails, or declare it with
`ns.AddonKitExpect` in the addon's Support file when the difference is meant.

| # | Addons | Client | Status |
|---|---|---|---|
| 1 | DaylightUI, EllesmereUI, FlareUI (the user's pick, 2026-11-25; then /addon-support on each) | forever | ran 2026-11-25 (qb025): DaylightUI 174 FAIL + 87 frames NOT COVERED, EllesmereUI 120 + 1 + 64 blocked, FlareUI 93 + 5; runs/2026-11-25-forever-qb025.txt |
| 2 | ElvUI, NaowhForever, ClassicUIForever, FramesForever (whole-UI suites) | forever | |
| 3 | Glass, Prat (chat) | forever | |
| 4 | Questie, RXPGuides, TomTom (quests) | forever | |
| 5 | Plater, Platynator, ThreatPlates (nameplates) | forever | |
| 6 | Bartender4, Details, BigWigs, DBM, WeakAuras, HealBot, ShamanPower (bars, meters, bosses) | forever | |
| 7 | the rest installed (none named: every installed supported addon) | forever | |
| 8 | every installed supported addon | retail | |

Notes:
- DaylightUI's retail copy is v1.9.5 against Forever's v2.2.7 (2026-11-25): update it before its retail run.
- `latest_version.py` couldn't read GitHub from here (2026-11-25), so check each one's latest version on Wago or
  CurseForge before its `/addon-support` rerun.
- A FAIL that turns out to be a real bug players hit becomes a `misses/` case once it's fixed.
