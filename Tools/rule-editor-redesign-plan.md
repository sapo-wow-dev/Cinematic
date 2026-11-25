# Plan: the CQL rule editor, redesigned

**Built 2026-11-25** with the recommended answers to section 14 (AND by itself on, Enter = Done,
600 x 600, "Doing", a real Undo history): `UI/RuleCatalog.lua`, `UI/RuleEditor.lua`; GridRows.lua's
old editor removed (ns.RulePieces is now a flat view of the catalog). Offline:
`Tools/offline/ruleeditor.lua` (catalog coverage, every pane fits at 600 x 600 on both clients,
inserting, typing, suggestions, search, readout, contexts, remembered). Look: the Style Lab's
`cql-*` frames (`Tools/style-lab/dump.lua`), every theme. In game: the `mousewords` kit test's
`editor` step. Found while building: a word after OR got an AND ("combat or and calm"), and a
whole word typed kept the list up so Enter re-took it; both fixed and tested. Not built from
the plan: clicking a word in In this rule selects it in the box (it adds it, as elsewhere).

Asked 2026-11-25 ("think this page has gotten too big? … come up with a full redesign. plan it. mock it
up. think of everything"). Plan only; nothing in the addon is built. Mockup:
`Tools/rule-editor/mockup.html` (open it in a browser: real words, labels and colors; a pretend
"where you stand" on the right drives the dots and the readout).

## 1. What's wrong today

Measured from `ns.RulePieces()` on Forever (`UI/GridRows.lua` BuildEditor):

- **17 lines, 152 buttons, ~1000 px tall** opened, near the whole screen at 1080p. Every new word
  makes it taller: the window's height is its content's.
- **The same words three times.** Target, Mouse over and Focus are 19 + 17 + 18 buttons for one idea
  ("this unit is X"). Each new unit property costs three buttons.
- **No way to find a word** but reading every line. Nothing to type a few letters into.
- **"+N" hides words** (two rows per line) and then a line opens to its full height: the window
  jumps, and a word you want is often behind a +N.
- **The verdict is one line**, "Right now: hidden", with no hint which word made it so.
- **Lines are grouped by history**, not by meaning: Values (10 menus) is a line of its own away from
  Location; Class is 13 buttons beside the class: picker; Spell range and Nearby are both distance;
  Role (3 buttons) a line of its own; indoors/outdoors sit under You.
- **Context-blind**: Entering/Leaving combat show on every row though only fight-edge rows read
  them; the Tooltip line is the only one already hidden where it doesn't apply.

## 2. Goals and limits

- One window, **600 x 600, fixed**: it never grows with the word list (about 60% of today's height).
- **Every word reachable in two clicks**, or a few typed letters.
- **The rule explains itself**: which words are true where you stand, and why the whole is shown or hidden.
- **Nothing about rules changes**: CQL, `ns.CompileRule`, the words, aliases, value words and every
  saved rule read exactly as now. Callers keep `ns.OpenRuleEditor(target)`; only an optional
  `context` is added.
- Forever and retail; a word a client can't read stays hidden there (hide-unclickable); mouse,
  keyboard and gamepad.
- Not in scope: the grid rows' dropdowns, ColoredRule's look outside the editor, the rule language.

## 3. The layout

```
+--------------------------------------------------------------- 600 ---+
| CQL            Rule: Enemy players                     [Pop out] [X]  |  title (30)
| +-------------------------------------------------------------------+ |
| | combat and hostile and player_                                    | |  the rule (62, 3 lines)
| +-------------------------------------------------------------------+ |  + suggestions drop under it
| [AND] [OR] [NOT] [(] [)]    [Undo] [Redo] [Clear]                     |  logic bar (24)
| +-------------------------------------------------------------------+ |
| | (v In combat) AND (x Target: Hostile) AND (x Target: Any player)  | |  readout (44): each word
| |                                          -> Hidden right now       | |  true/false here + verdict
| +-------------------------------------------------------------------+ |
|  Stays the row's rule (the dropdowns can't show it).                  |  grid note (14)
| +-------------+-----------------------------------------------------+ |
| | Find a word | Units  your target, the mouse, your focus           | |
| | True here 12| [Target *][Mouse][Focus]                            | |  picker (fills the rest)
| | In this rule| WHO      [Anything*][You][Enemy][Friendly*][Dead]   | |  sidebar 128 | pane
| |-------------| KIND     [Any NPC*][Any player][Hostile][Neutral]   | |
| | Fight     * | DISTANCE [Near (11)][Near (28)][Plate off screen]   | |
| | Units     * | RANK     [Elite][Rare][Boss][Critter]               | |
| | Distance    | MORE     [Quest mob][Tapped by others][Targeting you]| |
| | Place     * | TARGET   [This NPC...]                              | |
| | You       * | ONLY                                                | |
| | Doing       |                                                     | |
| | Travel      |                                                     | |
| | Group     * |                                                     | |
| | World     * |                                                     | |
| | Camera      |                                                     | |
| | Character * |                                                     | |
| +-------------+-----------------------------------------------------+ |
| [Reset to grid] [Follow a row]                               [Done]   |  footer (unchanged)
+-----------------------------------------------------------------------+
```

`*` = a green dot: true where you stand (on a word), or one of its words is (on a category / unit).

Why a sidebar and not folder tabs across the top: 14 entries don't fit across 600 px, a list can
show a dot and a count per entry, and the two special entries (True here, In this rule) sit at the
top of the same list. It's the same pattern as the settings' own left list.

## 4. The categories (every word, where it goes)

Sections are a narrow grey label in a column on the left of their words (no line of their own), so a
category with five sections still fits without scrolling. Colors stay the ones today's lines use (so
ColoredRule keeps them).

| Category | Section | Words (label → word) | From today's line |
|---|---|---|---|
| **True here** (special) | by category | every word true now, from every category | new |
| **In this rule** (special) | by category | every word the rule uses | new |
| **Fight** | | In combat `combat`, Calm Timer `calm`, Out of combat `nocombat`, Boss fight `boss`, PvP fight `pvpfight`, Aggro on you `aggro`; on fight-edge rows only: Entering `entering`, Leaving `leaving` | Combat |
| **Units** | switch Target / Mouse / Focus | (below) | Target, Mouse over, Focus |
| **Distance** | Spell range | Within 5-10* … Within 40* `range…` | Spell range |
| | Elites near you | Elite near (11/28/40 yards) `elite11/28/40` | Nearby |
| **Place** | Kind of place | Open world `world`, Cities `city`, Inns `inn`, BGs & arenas `bg`, (retail: Battlegrounds `battleground`, Arenas `arena`), Instances `instance`, Dungeons `dungeon`, Raids `raid`, Scenarios `scenario`, Sanctuary `sanctuary`, Contested zone `contested`, Indoors `indoors`, Outdoors `outdoors`; retail: War Mode `warmode`, Delves `delve`, Mythic+ `mythicplus`, Your house `housing` | Location, You (indoors/outdoors) |
| | This place | Zone… `zone:`, Subzone… `subzone:`, Instance… `instance:` | Values |
| **You** | State | Dead, Ghost, Casting, Lost control, Stealthed, Mounted, In a vehicle, In a form, Sit, Resting, Pet out, Max level | You |
| | Flags | AFK, Busy (DND), PvP flagged | You |
| | What you have | Aura… `aura:`, Form… `form:`, Mount… `mount:` | Values |
| **Doing** | With NPCs | Interacting, Talking, Window… `window:` | You, Values |
| | Your screen | Map open, Game window open, Edit Mode, Movie playing, Turning with the mouse, Using a gamepad | Screen |
| **Travel** | | Moving, Auto-run, RP Walk, Swimming, Under water, Flying, (retail: Gliding), Moving fast, Falling, On a flight path `taxi` | Travel, You (taxi) |
| **Group** | Group | Grouped, In a raid group, Group leader | You |
| | Role | Tank, Healer, Damage | Role |
| **World** | Weather | Rain, Snow, Sandstorm, Storm (heavy rain), Any weather (only where the client has weather) | World |
| | Time of day | Dawn, Day, Dusk, Night | World |
| **Camera** | | In a camera mode `camera`, Which camera… (the cam_ words, as today's menu) | Camera |
| **Character** | Class | this client's classes (bare words: `mage`…) | Class |
| | More | Spec… `spec:`, Race… `race:` | Values |
| **Tooltip** (Tooltips row only) | | Enemy, Friendly, Gatherable, Quest objective, Anything else `tip…` | Tooltip |

**Units**: one pane, a segmented switch **Target | Mouse | Focus** (remembered), the same sections
for each, inserting that unit's spelling (`hostile` / `hoverhostile` / `focushostile`; the target's
bare words stay bare: `enemy`, `npc`, `targetelite`, `targetingyou`):

| Section | Words |
|---|---|
| Who | Anything, You, Enemy, Friendly, Dead |
| Kind | Any NPC, Any player, Hostile, Neutral |
| Distance | Target: Near (11), Near (28), Plate off screen; Focus: Near (11), Near (28); Mouse: none |
| Rank | Elite, Rare, Boss, Critter |
| More | Quest mob, Tapped by others, Targeting you |
| (unit) only | Target: This NPC… `targetid:`; Mouse: On a unit frame `hoverframe` |

The Focus switch shows only where the client has a focus frame (as the Focus line today). Each switch
button carries a dot when one of that unit's words is true. Old kind words (`enemyplayer`…) stay
out of the editor and keep their color (colorOnly, as now).

Count: 152 buttons on 17 lines become 14 sidebar entries and at most ~25 buttons on screen at once.

## 5. Interactions

**Inserting a word** (click):
- At the cursor, spaced from its neighbors (today's Insert rules).
- **AND by itself**: right after a word or `)`, clicking a word (or `(`, NOT) puts `and` first. The
  most common mistake today is two words with nothing between ("combat hostile": out of place).
- **OR right after an added AND replaces it** (the AND was ours, not typed), so "word, OR, word"
  still reads as you meant.
- **Shift-click** adds it with NOT (`not talking`).
- A value menu button (Zone…, Aura…) opens its menu (RuleAxes `Pick`), as today; "Nothing to pick here
  now" when empty.

**Typing** (the box keeps focus as now):
- **Suggestions** after two letters of a word: up to 6 matches under the box: the word in its color,
  its label ("Target: Elite"), a dot if true here. Ranked: word starts with, label starts with, an
  alias (`dps` → Damage, `stun` → Lost control), contains, its tooltip mentions it.
  Up/Down choose, Tab or Enter take, Escape closes. Forever's EditBox: `OnTabPressed`,
  `OnArrowPressed` (needs `SetAltArrowKeyMode(false)`), `OnEnterPressed` (multi-line: handled, no
  new line), `OnEscapePressed` (closes the list first, the editor on a second Escape).
- **Undo / Redo** (buttons, Ctrl+Z / Ctrl+Y): a 50-step history of the text, every change (typed,
  clicked, cleared). Today's Undo takes off the piece before the cursor; history is what people
  expect and covers that too.
- Unknown words red with a wavy underline (today: red only).
- 255 letters as now; a counter shows past 200.

**Finding** (the box above the sidebar): searches every word by label, the word, its aliases and its
tooltip text; the pane shows the hits grouped by category (and unit), categories without a hit
dimmed. Enter adds the first. Clearing it goes back to the category you were on.

**Hovering** a word: its full name (with the unit: "Mouse: Elite"), what you'd type, one short line
on what counts (today's STATE_TIPS and friends, kept), "True/False where you stand now", and "Shift-
click adds NOT word".

**True here**: every true word, any category; the fastest way to build "show it when I'm like this
now". **In this rule**: its words; clicking one there selects it in the box, to change or delete
(the mockup still adds it again: built as specified here).

## 6. The readout (replaces "Right now: …")

The rule redrawn as chips in order: each word a chip with ✓ (green) / ✗ (grey) for where you stand,
AND / OR / NOT / brackets small and grey between them, then **→ Shown right now** / **→ Hidden right
now** at the end. Value words show their names (`zone: Elwynn Forest`, `aura: Blood Pact`). Hovering
a chip: what it means and why it's true/false ("Out of fights only", "the game won't say in a fight").

Errors take the verdict's place in red, with the rule's own message ("Not finished: AND needs a word
before it. Closing now puts back the rule it had.") and the bad word underlined in the box. Done
stays disabled while it doesn't read (as now). Blank: "Blank: never shown." on grid rows, "Empty: its
ticks decide." elsewhere (as now).

Under it, on grid rows only, the grid note as today: "Goes back into the dropdowns as you close it." /
"Stays the row's rule (…)".

## 7. Context: words only where they mean something

`ns.OpenRuleEditor(target)` takes `target.context`, one of: `row` (a Show in row, default),
`tooltip` (Tooltips row: today's showTip), `edge` (the Cards' and combat sounds' fight rows, which
read `entering`/`leaving`), `trigger` (a camera trigger's Only if), `cdm` (a Cooldown Manager scene),
`sound` (a combat sound rule). Each word may carry `only = { contexts }`; a category with no words
left is hidden. Typed anyway, such a word still reads and keeps its color (only the button is hidden).
Callers: GridRows (row/tooltip/edge by key), Camera/TriggersPage.lua (trigger), UI/CooldownGrid.lua
(cdm), Visions/CombatSoundRules.lua (sound/edge).

## 8. Kept as it is

- Pop out / Dock (ns.DockBeside "ruleEditor"), docked beside the settings; Escape and the settings
  closing close it; X; Done; Reset to grid; Follow a row; the "Rule: <row>" heading; the CQL hover.
- The colored copy over the box (Forever's cursor takes the text's color: the box text stays grey
  under the colored copy, as now).
- Dots every 0.5 s from `ns.RuleFactsFor(target.key)` (so a row's own facts: fight-edge, tooltip).
- `ns.ColoredRule` everywhere else; the rule language; every saved rule.

## 9. Remembered (per account, CinematicDB)

- `ruleEditorCat`: the last category ("units" to start); `ruleEditorUnit`: target/hover/focus.
- `ruleEditorOpen` (today's per-line +N state) is no longer read: a Migrations step clears it.

## 10. Code

- **New `UI/RuleCatalog.lua`**: `ns.RULE_CATALOG`, the categories, sections, words (word, label key,
  tip key, `only`, `client`, `pick`, `alias` for search), unit words as one list + `ns.UnitPropField`
  spellings. Built when first asked (after the language is known, as RulePieces is). Words a client
  lacks (gliding, warmode…, Focus without FocusFrame, weather without C_Weather) dropped there.
- **New `UI/RuleEditor.lua`**: BuildEditor moved out of GridRows.lua (2097 lines) and rebuilt: title,
  box + overlay + suggestions, logic bar, readout, sidebar, pane, footer. Buttons made once per
  category on its first showing, pooled; only the shown category's buttons refresh their dots.
- **GridRows.lua** keeps the grid, `ns.GridRule`, `ns.ReadGridRule`, `ns.ColoredRule` (FieldColor
  reads colors from the catalog) and `ns.RuleCameraList`.
- **`ns.RulePieces()` kept** as a flat view made from the catalog (one group per category, the units
  as three groups), so FieldColor, ColoredRule and the tests that list words keep working while the
  editor itself no longer uses it.
- Both TOCs: RuleCatalog.lua and RuleEditor.lua after GridRows.lua.
- Watch the 200-local and 60-upvalue limits (Frames.lua lessons): the editor is one builder function
  today; split into small local builders (BuildBox, BuildReadout, BuildPicker) with state on a table.

## 11. Forever, retail, gamepad, language

- Forever: EditBox key handlers above exist on 1.60 (check `OnArrowPressed` in the API dump before
  building; fallback: no arrow keys, Tab cycles). Cyrillic: set fonts before text (memory
  cyrillic-font-swap). Secret values: the readout uses the same facts as the dots, never the game.
- Retail: the retail-only places and Gliding in their categories; Battlegrounds/Arenas split.
- Gamepad (the settings' gamepad navigation): sidebar entries and word buttons are plain buttons in
  reading order; the search box and the rule box are EditBoxes the pad can focus. Check with
  "Blocked line = Settings open" in mind (SmartNavigation).
- New strings English only (no locale edits till release).

## 12. Performance

Built once (first open). Categories' buttons created lazily (Units ~50 incl. three units, others ≤ 25).
Refresh every 0.5 s: the shown buttons' dots, the sidebar's dots (one `any true` per category from
the facts table), the readout (tokens of the rule, ≤ 255 letters). Search filters a list of ~190
entries on each key. No cost while closed.

## 13. Tests (one game run at the end: memory no-phases)

- **Offline `Tools/offline/ruleeditor.lua`** (new; stand-in game, both clients):
  - every word in `ns.RULE_WORDS` that the editor should offer is in exactly one category (per
    context), none twice; retail-only words absent on Forever; Focus only with FocusFrame;
  - the window's height is the same for every category, unit and context (fixed);
  - each category's pane fits without scrolling at 600 x 600 (layout from button widths);
  - inserting: spacing, AND by itself, OR replacing an added AND, Shift adds NOT, `(`;
  - Undo/Redo across typed and clicked changes; Clear undoable;
  - suggestions: "ta", "dps", "stun" give the expected first match; Tab/Enter/Escape;
  - search: every word found by its label; aliases; Enter adds the first;
  - the readout's chips and verdict equal `ns.CompileRule(text)(facts)` for a set of rules and facts;
    errors match CompileRule's message;
  - contexts: `entering` only on edge, `tip…` only on tooltip; a typed out-of-context word still reads;
  - remembered category/unit; the Migrations step clears ruleEditorOpen.
- **Update** `unitwords.lua`, `statewords.lua`, `valuewords.lua`, `hoverwords.lua`: their editor
  checks read the catalog instead of RulePieces' lines (same words, new places).
- **One kit test** (extend `Dev/MouseWordsTest.lua`'s editor step, which already opens the editor and
  measures lines with r:Overlaps; renamed in title only): open from each caller (a Show in row, the
  Tooltips row, a Cards fight row, a camera trigger, a CDM scene); every category and each unit shown
  in turn: nothing cut, covered or past the edge, the window on screen, a paced shot each; the dots
  of True here equal `ns.RuleFactsFor`; type through the handlers ("ta" + Tab) and check the box;
  click a word twice and check the AND. No action asked of you.

## 14. Decisions for you

1. **AND by itself** when you click a word after a word: on (recommended), or off?
2. **Enter in the box**: takes a suggestion when the list is up, otherwise **Done**? (Today Enter does
   nothing useful in the box.)
3. **Size**: 600 x 600 fixed (mockup), or keep today's 560 width?
4. **"Doing"** as the name for NPCs + your screen, or split into "NPCs" and "Screen" (one more entry)?
5. **Undo** becomes a real history (recommended), or keep "take off the last piece"?
