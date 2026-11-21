# Text on You page: the works (plan, 2026-11-21)

The page today (Style/SelfTextStyle.lua, `ns.CreateSelfTextStylePanel`) is one long list: no preview, a
Test that plays behind the options window, 12 kind rows of three ticks each. This plan brings it up to the
other Style pages (Combat Text Style, Nameplate Style) and past them. Mock:
https://claude.ai/artifact/62KeDLxYsBDq9wPWWeWnTx ("Text on You Redesign").

## What's wrong now (from the screenshot, 2026-11-21)
1. **Font shows "The game's, The game's"**: the page passes its own `{ "game", "The game's" }` first
   choice, and `ns.StyleFontChoices()` already starts with `game`. Two entries, one value. Fix: no first.
2. **No preview.** Test draws at your spot on the screen, under the options window: you can't see it.
3. **Every kind's swatch shows always**, also on Game's color and Hidden, where clicking it changes a
   color that isn't used ([[hide-unclickable]]: shown only on Own; greyed only if another setting can
   bring it back).
4. **Test doesn't turn into Stop** ([[running-button-state]]).
5. **No tabs**: every other Style page has General / Look (PageTabsBelow, each tab a container,
   right-click off).
6. **No Show in row** at the top ([[default-show-in-row]]).
7. **Choices as ticks** in a 4-column grid; the rest of the Style hub moved to picture tiles (rows.Tiles /
   Segments, look-panel-redesign phase 3).
8. **Nothing says what's going on**: whether the game's floating text is on, which Text on Me kinds the
   game makes, whether the Shoulder Cam is over your shoulder, whether another addon has it (BattleText,
   MSBT: the conflict row stands the page aside silently).
9. **No Experimental notice** (Shoulder Cam and Combat Text Style have one; this one copies the game's
   text, which a patch could change).
10. The Who draws row's Follow tick sits on its own line under it, reading as part of it.

## The page, top to bottom

### Header
- Title **Text on You Style** + **?** + the Enable switch (as now), one-line intro.
- **Experimental** notice (skull + red word, as Combat Text Style): "Copies the game's own combat text;
  a game patch can change how it's made."
- **Status chips** (a row, each a short word + a dot; click opens what it's about):
  - Game's text: **copied** / held on for you / off (with why) / standing aside for BattleText (opens
    Addon Conflicts)
  - Shoulder Cam: **over your shoulder** / behind you / off (opens Shoulder Cam)
  - Text on Me: **9 of 14 kinds on** (opens the game's Combat options; we don't mirror them,
    [[no-mirror-blizzard-settings]])
  - Last fight: 42 copied, 0 dropped (a tiny proof it's working; from ns.SelfTextStats)

### Show in (default row, [[default-show-in-row]])
World / Dungeons / Raids / PvP / Cities, as every page.

### Preview (the centerpiece)
Sticky at the top as you scroll, pops out like every Style preview (StylePopout, StylePreviewTest).
- **Your character from behind** (a PlayerModel of "player", back view, idle), standing on the Style
  scene backdrop, the camera framing it as the Shoulder Cam would: **Over your shoulder** puts you left of
  the middle, **Behind you** in the middle. A toggle on the preview flips it (the preview's own, not a
  setting).
- **The real drawing code plays in it**: `Show()` given a parent and scale (the preview's layer), so
  font, edge, size, crit size, side, motion, height and each kind's color are exactly what you'll get.
- **What plays**: a fight mix (hits, a crit, a dodge, heals with a healer name, power, combo points,
  an aura, Mana Low) on a loop; picking a kind on the Kinds tab plays that kind alone (as Combat Text
  Style's Look tab does).
- **Buttons** (on hover, icons, as the Style previews): Play / Stop (turns into Stop while running),
  Pop out, Backdrop, Over shoulder / Behind, **Show the game's spot** (a faint ghost of where the game
  would draw it, to see the difference).
- **Drag to place**: grab the text's start mark in the preview and drag: up/down sets Height, sideways
  sets the new **Across** nudge. Snaps to 5. (The drag writes the same settings as the boxes.)
- **Your real screen too**: "Play on screen" (the old Test) plays at your real spot with the options
  window faded out for its few seconds, then back.

### Tabs (PageTabsBelow: each a container, right-click turns it off)

**General**
- **Who draws it**: Ours / The game's / None as segments (one row, not ticks).
- **Where**: Side as three picture tiles (a little figure with arrows: Over you, Free side, Split), then
  **Follow the Shoulder Cam** under it, indented.
- **Height**, **Across** (new: a nudge sideways from your spot), **Time shown**, as sliders with the box.
- **Motion**: four picture tiles that animate on hover (Up, Down, Arc, Pop).
- **Busy fights** (new section):
  - **Merge repeats**: the same kind within 0.5 s in one line with "x3" (secret numbers can't be
    added, so it shows the latest and the count, as BattleText does). Crits never merge.
  - **At most**: texts at once (now MAX_LIVE 30), the oldest fades first.
  - **Crits stay**: a crit holds for a moment where it popped (sticky), as MSBT/BattleText.

**Look**
- **Quick looks** (tiles, each drawn in its look): The game's, Clean (outline, no shadow), Bold (thick
  edge, bigger crits), Comic (a round font, bouncy pop), Small (0.8, quiet). A quick look sets the rows
  under it; changing one after marks it "changed" (the Style gold dot).
- **Font** (dropdown, each name in its font; the double "The game's" gone), **Edge** (segments, each
  word drawn with its edge), **Size**, **Crit size**, **Shadow strength** (new), **Fade** (when it starts
  fading, now FADE_FROM 0.6).

**Kinds** (the Combat Text Style Look tab's list, for the 12 groups)
- One row per kind: its **switch** (on/off), a **sample chip** in its color ("-26", "+120 [Sapo]",
  "Dodge", "<2 Combo Points>", "Mana Low"...), and a **badge** when the game won't make it ("off in the
  game's options": its Text on Me tick).
- **Click a row**: its own settings open under it, each its group's until changed (gold dot), **Clear**
  puts it back:
  - Color: the game's / its own (swatch shown only on its own)
  - Size, Crit size (on kinds with crits only), Font
  - Side (as General / over you / left / right): e.g. heals under you, damage to the side
  - Motion (as General / ...)
  - Sound (none / a few game sounds): Low Health, a crit, combo points at max (spam limit 0.3 s)
- The preview plays the picked kind alone while its row is open.

### Footer
- "Changed: Size, Damage taken color" with the gold dots; **Reset page** (ns.DEFAULTS + the kind keys,
  [[page-defaults]]).

## Code plan (phases)
1. **Fixes** (small, now): the font double, swatch shown on Own only, Test → Stop, Who draws as
   segments, Follow under Side. Offline test for each.
2. **Preview**: `Show()` takes a target (layer, scale, spot) so the page's preview runs the real code;
   the PlayerModel back view; StylePopout + sticky; Play/Stop; Over shoulder / Behind; ghost of the
   game's spot. In-game check: one self-running test (screenshots of each look, no action).
3. **Tabs + tiles**: PageTabsBelow (General, Look, Kinds), picture tiles for Side / Motion / Edge /
   quick looks, the Show in row, status chips, Experimental notice.
4. **Kinds editor**: per-kind settings (color, size, crit size, font, side, motion, sound) as
   `selfText_<kind><Part>`, "its group's till changed", Clear; game-tick badges (read the
   floatingCombatText*_v2 CVars, never set them).
5. **Busy fights**: merge repeats, at most, crits stay, Across; drag-to-place in the preview.
6. **Out of dev**: dev = false, What's new entry, /cine find ids, docs page, migration of the Follow
   HUD's "Floating combat text" row, translations at release.

## Tests
- Offline per phase (Tools/offline/selftextstyle.lua grows: kinds editor keys, merge, sticky, the
  preview's Show target, chips' states).
- In game: one run per phase at most ([[fewest-test-actions]]): phase 2's needs no action (samples in
  the preview, screenshots); phase 5's needs one fight (merge and crits stay on real hits).

## Built (2026-11-21, dev copy, untested in game)
Phases 1-5 built: Style/SelfTextPage.lua (the page) and Style/SelfTextStyle.lua (boards so the preview runs the
real code; each kind's parts; merge repeats, at most, crits stay, across, shadow, fade; the Show in row
`style:selfText`; sounds; game ticks read). Offline: selftextstyle.lua (engine), selftextpage.lua (page, 52 checks,
6 deliberate breakages caught), selftextpagetest.lua (the in-game test). In game: `/cine debug selftextpage`
(nothing to do, 8 steps). Ledger: Tools/tests/self-text-page.md.
Not done (phase 6, after the in-game check): dev = false, What's new, /cine find ids, docs, the Follow HUD's
Floating combat text row's migration (ShoulderCam.lua), translations at release.
