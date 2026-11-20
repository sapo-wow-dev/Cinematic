# Game Settings page: edit and search

Status 2026-11-20: built on main, uncommitted. Offline test
`Tools/offline/gamesettingsedit.lua` passes; in game `/cine debug gsedit`
(dev copy) not run yet. Plan below as built, except: the two "for all"
buttons act on the rows the filter shows.

Player ask (Discord, 2026-11-20): set the game settings right on Help > Game
Settings instead of leaving the window to find them.

## What the page is today (GameSettingsPage.lua)

- Rows = every CVar in a `playerWins` set (ns.cvarSets) + the profile switches
  (ns.ProfileSwitchRows: cooldownViewerEnabled, nameplateShowSelf).
- Columns: Setting, Used for, Ours, Yours, Now, Keep yours / Use ours.
- Only choice: who wins (db.cvarsLeftAlone). No way to set a value.
- The hub's "Search this page" box already finds row names (cells are
  FontStrings), but only once the rows exist (made on first Refresh).

## Which values aren't on/off

- `nameplateStyle`: 6 named styles (ns.GamePlateStyles, Forever only).
- Ours can be two values at once: `nameplateShowOffscreen` (On by one set,
  Off by another), shown "Off / On".
- Everything else on the page today is 0/1. A future set may hold a number
  (camera sets are not playerWins, so not listed now).

## Design

**Edit Yours, not Ours.** Ours is what a feature needs (CineMode hiding
names, Duel Vision...); changing it belongs on that feature's page. Yours is
the player's own value and is what they asked to set.

1. **Yours column becomes a control** per row, picked by value kind:
   - on/off -> a checkbox (On/Off text beside it)
   - `nameplateStyle` -> a dropdown of ns.GamePlateStyles names
   - anything else -> a small number box (Enter sets, Esc reverts), checked
     against C_CVar.GetCVarInfo (missing / read-only -> hidden, per the
     hide-unclickable rule)
   - A per-cvar `KINDS` table (like NAMES) says which; default from the value.
2. **Setting Yours** = new `ns.SetYourCVar(cvar, value)` in Core.lua next to
   KeepYourCVar/UseOurCVar:
   - held now by a set (state ours/changed): store it in
     db.savedCVars[cvar] only; the set puts it back when it lets go. Never
     SetCVar while held, or heldCVars reads it as "you changed it" (state
     changed) and yours wins early.
   - kept or idle: WriteCVar now.
   - secure (nameplate*/UnitName*) in a fight: false -> FightNote, as today.
   - Logged ("cvar", "...: yours set to X, from the Game Settings page").
3. **Rows whose Yours another Cinematic setting owns** (must not fight it):
   - Names/plate CVars written by HUD Show in rows (Effects.lua SetOwnValue,
     cvarsOurs/cvarsBefore): Yours shows the value + "set by <row>" and a
     link that opens that row (`/cine find row:<key>`), no control.
   - Profile switches (cooldownViewerEnabled, nameplateShowSelf): the switch
     row's own CVAR_UPDATE path already treats a change as the player's
     (Profiles.lua:465). Setting Yours here -> leftAlone mark + write, same
     as switching it in the game's menu. Needs its own test.
4. **Used for becomes a link**: click opens the feature's page/setting that
   decides Ours (a PURPOSES entry gets an id: `hideNames`, `duelVision`...).
5. **Search / browse**
   - A filter box on the page (left of the summary): types filter the rows
     live by name, cvar name, used for. Sections with nothing left hide.
   - A state filter dropdown: All / Cinematic's now / Kept as yours / Changed.
   - `ns.searchPrepare` entry that runs Refresh, so the hub search and the
     main search find rows before the page was ever opened.
   - Each row gets `settingKey = "cvar:<name>"` -> `/cine find cvar:nameplateStyle`
     jumps to and flashes the row (and `/cine debug ids` lists them).
6. Layout: Yours column wider (0.09 -> 0.14), Now narrower; the row tooltip
   gets the cvar's game default ("Game default: On").

## Not in scope (ask first)

- A browser for **all** game CVars (hundreds; AdvancedInterfaceOptions does
  it). Goes against "don't mirror Blizzard settings"; many are secure,
  account-wide or unknown on Forever. Recommend no. If wanted: a separate,
  advanced-off page, read-only list + edit, own plan.

## Tests

- Offline `Tools/offline/gamesettingsedit.lua`: fake CVars + sets; SetYourCVar
  while held (saved only, Now unchanged, letting go writes it), idle (written),
  kept (written, stays kept), fight (false), row-owned (refused), filter
  (name / cvar / purpose / state), searchPrepare makes rows.
- In game: one `/cine debug gamesettingsedit` recorder run (Forever, then
  retail): opens the page, sets Yours on a held row + an idle row + the style
  dropdown, turns CineMode on and off, logs Now/Yours/saved at each step,
  screenshots, puts everything back, DONE.
