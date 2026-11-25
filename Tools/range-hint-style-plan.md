# Range Hint: styling plan

Status: BUILT, all 4 phases (2026-11-25, the user: "build all 4 phases, style
page plus tab"), uncommitted. Offline rangehintstyle.lua ALL PASS both
clients; sweep 0 new; in game queued (q84e2). Differences from the plan below:
the motion runs in the existing OnUpdate (it already runs while there's a
target), not AnimationGroups; spell school is our own table (no game call
gives it; a spell not listed keeps the custom color); the theme gives the
mark its cast color and General's font. Feature: UI/RangeHint.lua (built,
Forever tested: qeb71, qafa5). Ledger: Tools/features/requests.md
("Subtle range hint"). Questions for the user at the end: answer them before
phase 1.

## 1. Goal

Let a player make the out-of-range mark look the way they want: from a
barely-there dot to a clear "Too far: Frostbolt" badge, matching their theme.
It stays **subtle by default**: the look built today is the default, so
nobody's screen changes until they touch a setting. Mission check: a quiet
in-world cue, not a HUD widget. Every option has to serve "smooth and subtle".

## 2. Rules it has to follow (from memory and the code)

- **Style module gate**: the page lives in `Style/RangeHintStyle.lua` inside
  `ns.Module("style", ...)`. Every default lives in `UI/RangeHint.lua`, so the
  mark still draws (in today's look) with Style left out (Modules.lua,
  `Tools/offline/modules.lua`). Watch the 60-upvalue cap.
- **Page switch gates all**: Range Hint Style off = the default look, via
  `ns.StyleLook(switchKey)`. **Style switch chain**: the look needs Enable
  Style, the page, and the tab on. Tests walk the chain.
- **Switch tree / layout is the tree / tab is a container**: each folder tab
  (`ns.FolderTabs`) is a switch; parent off greys its children.
- **Folder tabs, not stacked panels**: groups on the page are folder tabs,
  never a second Look panel stacked under the first.
- **Default means reset**: Reset (`ns.DEFAULTS`) gives today's look exactly.
- **Hide unclickable**: an option one client can't do is hidden there, not
  greyed (`ns.isRetail` gates).
- **One-client fixes**: a fix for one client never changes the other.
- **No translations till release**: English `L[]` keys only.
- **Short tooltips**: one sentence, no part lists.
- **Label capitalization**: page title and Enable Page in Title Case.
- **Font max 120 / Cyrillic swap**: sizes cap at 120 (SetTextScale beyond);
  set the font before the text, and keep the game's font for ruRU/koKR/zh.
- **CineMode owns the outer frame** (`CinematicRangeHint`, the HUD row):
  every style or motion goes on the inner `mark` frame, never on the outer
  frame's alpha or shown state.
- **No text resizing while walking**: no size that changes with distance.
- **Preview match**: the preview draws with the live mark's own code.

## 3. Where it goes (ASK the user first)

Recommended, as the Cooldown Manager has it:
- A **Style hub page "Range Hint Style"** (its icon: the spyglass, in the
  Combat group beside Swing Timer's recolor rows).
- The Range Hint icon gets a third tab, **"Style"**, that opens that page
  (`SHOW_IN_TABS.range` in StylePages.lua; `cdm` already does this).
- On the Settings tab, a `ns.StyleLink` line pointing to it.

## 4. Everything that can be styled

### 4.1 The mark (folder tab "Mark")

| Option | Choices | Default |
|---|---|---|
| Shape | Chevron, Double chevron, Dot, Ring, Bracket `[ ]`, Arrow up, Spell icon, None (text only) | Chevron |
| Size | 50-300% | 100% |
| Line thickness (line shapes) | thin, normal, bold | normal (today's 3 px) |
| Color by | Custom, Theme accent, Class color, Spell school (if probe says yes: §6) | Custom |
| Color | swatch | soft orange 0.94/0.54/0.31 |
| Opacity | 10-100% | 100% |
| Glow | off / soft halo behind the mark, its own color and strength | off |
| Spell icon only: | desaturated, tinted by Color, round/square (Action Bar Style's shape) | desaturated + tinted |

Art: anti-aliased TGAs from a script (`Media/make_range_marks.py` → `Textures/RangeMark_*.tga`,
64 px, white, tinted in game), not `CreateLine`. That gives one way to draw
every shape at every size and a clean glow (blurred copy). New textures load
only after /reload on Forever.

### 4.2 The words (folder tab "Text")

| Option | Choices | Default |
|---|---|---|
| Show | Spell name, "Out of range", "Too far" / "Too close" (§6), Spell name + yards ("Frostbolt 30 yd"), None | Spell name |
| Side | Under the mark, Over, Left, Right | Under |
| Font, size, color, outline, outline color, shadow | the Look panel's Text group (`LOOK_BUILD`: font, textColor, outline, shadow), General's shared font first | General's font, 100%, soft peach, no outline, shadow on (today's) |
| Gap to the mark | 0-20 px | today's |
| Case | as is, UPPER, lower | as is |

### 4.3 Behind it (folder tab "Background")

| Option | Choices | Default |
|---|---|---|
| Background | None, Soft dark pill, Theme panel (`ns.ThemePanel`), Bar texture strip | None |
| Opacity, padding | sliders | 50%, 6 px |
| Border | `ns.StyleBorder` (none, thin, theme) | none |

### 4.4 Motion (folder tab "Motion")

| Option | Choices | Default |
|---|---|---|
| Fade in / fade out | 0-1.5 s each | 0.35 s (today's) |
| Show after | 0-1 s out of range before it shows (stops flicker at the range edge while you back-pedal) | 0 |
| Entrance | Fade, Rise (slides up a few px as it fades in), Grow (scale 80→100%) | Fade |
| Pulse | off / gentle breathing for the first N s / always | off |
| Hide after | never / N s out of range (it said its piece) | never |

All motion through AnimationGroups on `mark` (no Lua per frame; the 10/s range
check stays the only work).

### 4.5 Sound (folder tab "Sound")

Off by default. A soft cue when the target leaves range (pick from a short
list of game sounds; volume follows the game's SFX). Never on every check:
once per in→out change, at most once every 2 s.

### 4.6 Not in this plan

- Screen-edge tint and nameplate dimming: the other two mockup looks, not
  picked (2026-11-25).
- Anything shown while in range: the user picked "Nothing" (2026-11-25).
- A yards slider: no distance API for enemies.

## 5. Themes, Reset, Share

- **Themes** (StyleThemes.lua): each theme may write the mark's color (its
  accent), shape and background. The page's Look tags show "Set by theme:
  <name>" (`ns.PageLookSource`). Default theme = today's look.
- **Reset**: the page's Reset puts `ns.DEFAULTS` back (today's look).
- **Share** (Share.lua CINE1): the new keys go out like any other.
  Unknown keys are skipped on older copies.
- **Built-in profiles**: none set the look. Run `check.lua --update` only if a
  row's default changes.

## 6. Unknowns (need a probe before planning them in)

1. **Spell school color** (the player asked for "discernment" by school: fire,
   frost, shadow, holy). `C_Spell.GetSpellInfo` gives no school. To try on
   both clients: `C_Spell.GetSchoolString`, the spell's tooltip lines,
   `GetSpellBookItemInfo`. Fallback: a small school table for each class's
   ranged attacks (our own data). → probe step in Dev/RangeHintTest.lua.
2. **"Too close"** (a hunter's Auto Shot dead zone, Charge): the spell's
   minRange (FindRangeSpells already reads it) + `CheckInteractDistance
   ("target", 3)`. Forever: plain in fights (rule
   forever.checkinteractdistance.plain-in-combat). Retail: blocked in fights
   (secrets-combat.lua) → retail shows "Too far" only, the choice hidden there.
   The user has no hunter: test with a stand-in answer, plus one real read.
3. **Spell + yards** text: the spell's own maxRange (plain): "30 yd" is the
   spell's reach, not the distance. Fine, but the tooltip must say so.

## 7. Code changes

| File | Change |
|---|---|
| `UI/RangeHint.lua` | Every new default (§4). Split drawing out: `ns.RangeHintDraw(holder, look)` builds or updates the shape, glow, text and background on any frame. Used by the live mark and the preview. `ApplyLook()` runs on setting change and theme change, never per frame. AnimationGroups for entrance, pulse and fades (the fade moves from OnUpdate to the group; the 10/s check stays). "Show after" and "Hide after" timers. Too-close state (`state.why = "too close"`). Sound cue. |
| `Style/RangeHintStyle.lua` (new) | The page: title, Enable Page, sticky preview (`ns.StyleScene`, `ns.AddPreviewFit`), Test button (`ns.StylePreviewTest`: the live mark on screen for 5 s, Test → Stop while running), Look panel with folder tabs Mark / Text / Background / Motion / Sound. |
| `Style/StylePages.lua` | `SHOW_IN_TABS.range` + "Style" tab; hub card. |
| `Options.lua` | Style hub page entry (HUBS Style pages), Settings tab's `ns.StyleLink`. |
| `Style/StyleThemes.lua` | Each theme's mark look (accent, shape, background). |
| `Media/make_range_marks.py` + `Textures/RangeMark_*.tga` | The shapes and their glow copies. |
| `Cinematic.toc`, `CinematicDev.toc` | RangeHintStyle.lua in the Style block. |
| `Changelog.lua` | What's new entry at commit (whats-new skill). |

## 8. Preview

- A stand-in character silhouette over `ns.StyleScene`, with the mark under
  it drawn by `ns.RangeHintDraw` in the page's look.
- A slow loop: out of range (entrance, pulse, hold), back in range (fade
  out), so fade times and entrance are seen, not imagined. A static frame
  when Motion is off.
- Sticky preview and dock-above (style-preview-redesign) like the other Style
  pages. Preview and live mark come from the same code, so they can't drift.

## 9. Risks

- **Taint**: none expected. Our own frames only, no game frame touched.
- **Combat**: nothing protected. Style changes in a fight apply at once.
- **Secrets**: the range answer is plain (tested). The school read is unknown (§6).
- **Performance**: look applied on change only, motion in AnimationGroups;
  the per-frame cost stays one alpha step.
- **Caps**: the page in its own file. Options.lua gets one table row, no new
  local. Style module's 60-upvalue cap: keep the page's helpers local to its
  builder.
- **Fonts**: Cyrillic/CJK keep the game font (as SwingTimerStyle.lua's ROMAN).

## 10. Tests

**Offline** (`Tools/offline/rangehintstyle.lua`, both clients):
- Every option writes what it says on the mark.
- Page off, tab off and Style left out each give today's look exactly.
- Reset gives the defaults. A theme writes its look; your own setting wins.
- Retail hides "Too close" (and school color, if the probe says so).
- `ns.RangeHintDraw` on the preview equals the live mark: same parts, same values.
- Sweep (`sweep.lua forever|retail`), `menurows.lua`, `modules.lua`
  (style off/on), `check.lua`.

**In game**: extend `Dev/RangeHintTest.lua` (reuse, not a new test):
- Step "style page", hands off: open Range Hint Style in every state (page
  on/off, each folder tab, Style left out = the note). `r:Overlaps` every
  control, no off card, a shot per tab, one shot per second.
- Step "looks", hands off: each shape on the live mark (Fake out of range),
  a shot each; text sides; background; check each part's rect stays clear of
  the bars (the bar walk from the editmode step).
- Step "probe", reusing the fight step's one action (pull a mob): school
  reads for the chosen spell (§6.1), `CheckInteractDistance` in the fight,
  too-close with a stand-in.
- Retail: one run of the same test on retail before "retail tested".

## 11. Phases

1. **Core look**: refactor to `ns.RangeHintDraw`, art script + shapes,
   size, color (custom/theme/class), opacity, text group, the page with
   preview, the Style tab link. Offline + one hands-off run.
2. **Motion + background**: AnimationGroups, fades, show after / hide after,
   entrance, pulse, background, border, glow. One hands-off run.
3. **Themes**: each theme's mark look + Set by theme tags.
4. **Extras** (after the probe): school color, too close, spell + yards,
   sound. One run with the fight (the probe), then one to confirm.

Size: big. Phase 1 is a session, the rest a session each or less.

## 12. Questions for the user

1. Where: Style hub page "Range Hint Style" plus a "Style" tab on the Range
   Hint icon (recommended), or just a Style tab on the icon?
2. All four phases, or which ones?
3. Shapes: is the list in 4.1 right? Any to drop or add?
4. School color: worth a probe (it answers the player's "discernment" ask)?
5. Sound cue: wanted at all?
6. "Too close": Forever only (retail can't read it in fights). OK?
