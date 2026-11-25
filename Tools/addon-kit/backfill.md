# Addon kit backfill (step 8)

Every supported addon through the kit, one client at a time. Each queue run is one `/cine debug addonkit` with
up to 11 addons: the baseline first, then each addon alone (probes + rows). You click Reload once per stage.
After each run: `python -I Tools/addon-kit/diff.py all <client>`, then fix what fails, or declare it with
`ns.AddonKitExpect` in the addon's Support file when the difference is meant.

| # | Addons | Client | Status |
|---|---|---|---|
| 1 | DaylightUI, EllesmereUI, FlareUI (the user's pick, 2026-11-25; then /addon-support on each) | forever | ran 2026-11-25 (qb025): DaylightUI 174 FAIL + 87 frames NOT COVERED, EllesmereUI 120 + 1 + 64 blocked, FlareUI 93 + 5; runs/2026-11-25-forever-qb025.txt |
| 2 | ElvUI, NaowhForever, ClassicUIForever, Frames_Forever (whole-UI suites) | forever | ran q9ef0 (2026-11-25) with 3 and 4 as one run, runs/2026-11-25-forever-q9ef0.txt: ElvUI 175 FAIL + 3 rows lines. NaowhForever, ClassicUIForever, Frames_Forever, Prat and TomTom aren't installed |
| 3 | Glass, Prat (chat) | forever | q9ef0: Glass 21 FAIL (puts its own ChatFrame1.AddMessage, FCF_OpenTemporaryWindow and SetItemRef in place after our hooks), rows clean |
| 4 | Questie, RXPGuides, TomTom (quests) | forever | q9ef0: Questie 6 FAIL (replaces StaticPopup_Show after our hook; hides the game's tracker), RXPGuides 3 (replaces ToggleAllBags, ToggleBag, ToggleQuestLog), rows clean |
| 5 | Plater, Platynator, ThreatPlates (nameplates) | forever | ran qcbb3 (2026-11-25) with every other installed addon not yet run. Rows clean for Platynator, BattleTextForever and Guidelime. MikScrollingBattleText_Forever wasn't loaded after its solo (Guidelime was), so it's untested. The probe diffs can't be judged: another run in the same queue overwrote the baseline. Fixed with per-run keys (3d78862 + the test's edits), so run it again once those are committed. Plater and ThreatPlates aren't installed |
| 6 | Bartender4, Details, BigWigs, DBM, WeakAuras, HealBot, ShamanPower (bars, meters, bosses) | forever | |
| 7 | the rest installed (none named: every installed supported addon) | forever | |
| 8 | every installed supported addon | retail | |

Not installed on either client (2026-11-25), so the kit can't run them until they are: Bartender4, BigWigs,
ClassicUIForever, CooldownManagerCentered, DBM, Details, DialogueUI, DynamicCam, ForeverEnhancedCooldownManager,
Frames_Forever, HealBot, HorizonSuite, Immersion, Leatrix_Plus, LoreForever, MinimapButtonButton, NaowhForever,
Plater, Prat-3.0, RareScanner, ShamanPower, Spoken, TidyPlates_ThreatPlates, Titan, TomTom, WeakAuras. On retail
only DaylightUI is installed.

Notes:
- DaylightUI's retail copy is v1.9.5 against Forever's v2.2.7 (2026-11-25): update it before its retail run.
- `latest_version.py` couldn't read GitHub from here (2026-11-25), so check each one's latest version on Wago or
  CurseForge before its `/addon-support` rerun.
- A FAIL that turns out to be a real bug players hit becomes a `misses/` case once it's fixed.
