# Style Studio build: behavior changes and changed test expectations (2026-11-25)

The build (plan.md, decisions all "recommended") keeps every saved key and its meaning. What follows changes
what a player sees or what a test expects. **Changed test expectations need the user's OK** (audit-kit rule);
none was edited by the build.

## Changed test expectations (need OK)

| Test | Was | Now | Why |
|---|---|---|---|
| `Tools/offline/gameplate.lua` "what it shows in the middle of the room" | 29 (debuffs off and on) | 40.49 off, 49.73 on | The plate preview no longer fits parts by fixed numbers (the debuffs-over-the-name bug); it measures them. |
| `Tools/offline/selftextpage.lua` "three tabs" | 3 | 2 (General, Look) | The Kinds tab became the editor's parts. |
| `Tools/offline/selftextpage.lua` "many controls" | over 40 | 21 | The look lives in the one editor now. |
| `Tools/offline/selftextpage.lua` "stopped: Play" | "Play" | "Test" | One word for it everywhere (plan 4.3). |
| `Tools/offline/manavision.lua` "Health, Mana and Style's Mana are tab containers" | 3 | 2 | Vitals Style's Mana is an editor part with its own switch row (still read off with it off), not a folder tab. |
| `Dev/AtmosphereTest.lua` stylepage step (via `atmopreview.lua`) "3 weather panes tinted" | 3 | 0 at the default strength 0 | The Weather picture used to fake 50% at strength 0; it now shows the real strength and says Off. |
| `Tools/offline/findrankmatrix.lua` letterbox_size | Size [Letterbox Style] | Letterbox [Letterbox] (page) | Editor settings are found through markers inside a closed part (ranked as buried). |
| `Tools/offline/findrankmatrix.lua` nameplate_color | Nameplates [Nameplates] (page) | Color [Cast Bar Style] | Cast Bar Style's colors are findable now (they were inside a closed Look popup before). |
| `Tools/offline/check.lua` Card grid | bar settings (Align, Bar scale, No letterbox) hidden without a bar | greyed | "Grey when another setting can turn it on" (hide-unclickable). |
| `Tools/offline/platematch.lua` "plain: the off pass, the state loop and Customize left out" | 3 "proven, not checked again" lines | 2 | Nameplate Style's Customize button is gone (the Default tab's editor replaced it), and its proven check went with it. |
| `Tools/offline/partrowsmatrix.lua` part=style state=out | error x172 (Options.lua:11247 StyleOverrideText nil) | ok | An improvement (Style left out no longer errors); needs declaring in its card. |

## Behavior changes (players)

- **Card Types tab** has no Enable Page: it was the `cards` key and turned every card off from a Style page. Cards
  stay switched from their Vision page (Events tab).
- **Visions Style's Reset page** resets only its own settings (it used to reset six other pages' fonts/outlines).
- **Interface Recolor's Damage meter rows** are hidden on clients without the game's meter.
- **Personal Resources heights** run 50-200% (they could only shrink before); saved values unchanged.
- **Raid frames' Arena variant** only on retail (it showed on Classic Era, which has no arena frames).
- **Name Style distance settings** (hide delay, fade, close/far size and raise; retail's raise and same size)
  are shown again (decision 3).
- **Layout Preset** is gone; its presets are Looks (one Undo step each). Reset part / Reset layout are the
  editor's Reset scopes.
- **Nameplate width / height / change time** moved from the Smart tab to the editor's Plate part (keys unchanged).
- **Moves (decision 2):** Vitals sound + volume → Vitals Vision page (Health tab, Sound); Quest Talk Controls →
  Quest Vision page; Range Hint's sound was removed altogether at the user's request (another session,
  2026-11-25); Damage type tiles → Damage Vision tab; Text on You's Show in → its General tab; Combat Text's
  Who draws stays on its General tab (no Show tab exists).
- **Quick-settings fonts (General):** picking the font a setting already follows keeps it following, and no
  longer switches the Style pages on.
- **Overrides page:** its folder tabs became parts; each tab's switch is the part's first row.
- **Emote** gets a "Sits" choice (Above speech / Where you put it) on its existing `emoteVisionSpot` key in
  place of the second position Reset button; its six drawn style pictures are text tiles now.
- **Cast bars, Nameplates variant** still can't pick "The game's" (no runtime key for it; the page switch does it).
- Every Style page's look is in the same editor: Undo/Redo, Reset with a count, Find, Copy/Paste, Looks.

## Kept on purpose

- `db.styleThemeKept` / `ns.UndoStyleTheme`: still written and read by tests.
- Damage Vision Look page is still built on every client (modules.lua expects it); the frame hides where the
  meter can't run.
