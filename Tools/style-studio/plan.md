# Plan: Style Studio — every Style page, redesigned

Asked 2026-11-25: "our style edit panels are kind of annoying me lately… no consistency or intuitiveness…
sometimes features don't even work or buttons don't even look obvious… the CQL panel looks beautiful… come up
with an audit of every style panel… really go all out."

**Plan only. Nothing in the addon is built.** Mockup: `Tools/style-studio/mockup.html` (open it in a browser:
the Studio window works, with real frames, parts, labels and keys; the audit scorecard and fix list are on the
same page).

Sources: four code audits (2026-11-25), one per band, every claim with file:line (kept in section 9), plus
in-game shots of Nameplate Style from today's Plate Layout run (Forever, 11:15).

---

## 1. What's wrong today (the audit in one screen)

38 page ids under the Style hub (Options.lua HUBS `name = "Style"`), built with **five different systems**:

| System | Pages |
|---|---|
| `ns.StyleRows` flat rows | Visions Style, Quest Talk, Quest Item, Roll, Letterbox, Weather, Interface Recolor, Minimap, Range Hint |
| `rows.Look` tabbed panel (the 2026-11-14 template) | Unit, Raid, Unit Cast, Player Cast, Cast Bar, Names, Personal, Action, CDM ring, Bubbles, Tooltips, Smart rows |
| `ns.VisionRows` Builder (number boxes) | Damage Vision Look, Emote Vision Style |
| Hand-built widgets | Combat Text, Text on You, Tint, Card Types (LookGrid), Overrides, Plate Layout |
| Theme editors | Style General / Themes, Vitals |

What that does to a player:

1. **One kind of choice, five controls.** A choice is radio boxes, segments, three PanelButtons, a dropdown or
   tiles, depending on the page and whether it sits inside a tabbed panel (StylePages.lua 2741-3044 swaps them).
   **Outline alone has seven models** (Names segments, plate row Outline, cast 5-option Choices, Bubbles 4 levels
   no shadow, Tooltips 3 levels + shadow, Range Hint 0/1/2, Combat/Self Text "Edge").
2. **Buttons that look like text.** Visions list names (VisionsStyle 128), cast row buttons in grey
   (PlateCastStyle 2531), the 16 px "Scene" pill (PlateRowLook 574), Flat toggles (PlateLayoutPage 88). Four button
   styles beside PanelButton.
3. **Features that don't work, or work while greyed:**
   - Card Types' Enable Page is the `cards` key: on a Style page it turns **all cards off** (CardsPage 1779).
   - "Look:" buttons on Quest Talk Panels, Quest Item Button and Roll Cards always read "The game's", whatever
     you pick (StylePages 4593 Summary reads only texture/font/outline/border).
   - Minimap Border color is greyed yet still colors the round map's button rings (MinimapStyle 703 vs 549).
   - Behind Bubbles is greyed by four switches on the Chat pages, with no hint (BubbleStyle 117); Test/Move
     stay clickable (106, 114).
   - Action Bars do nothing with Dominos or Masque loaded, and the page doesn't say so (ActionBarStyle 55, 996).
   - Nameplate preview never applies your Layout and fits parts by fixed numbers (Options 13298): debuffs sit
     on the name (today's shot 11:15:23).
   - Layout "Preset" is a dropdown with no state that wipes the layout, no confirm, no undo (PlateLayoutPage 152, 857).
   - Name distance settings are hidden but still read (SHOW_DISTANCE = false, Options 12781; PlateParts 535-545):
     retail players can never change `plateNameY` / `plateNameFixedSize` again.
   - Personal Resources heights run 0-100% with 100% default: bars can only shrink; 0% hides them (PersonalStyle 900).
   - `combatTextNumbers` greys the whole Combat Text Look tab and no control writes it (CombatTextPage 102).
   - Emote, Quest Talk, Letterbox, Damage grey on the wrong switch: rows stay live with Enable Style off
     (EmoteVision 4367/3300, QuestTalkStyle 51/70, LetterboxStyle 400/490/505, DamageVision 1735).
   - Visions Style's Reset page silently resets Font/Outline/Shadow on six other pages (VisionsStyle 169).
   - Reset page skips field-table keys: General's fonts, bar texture and shapes, Combat Text's "Who draws"
     (Options 53; StyleThemes 1682-1730; CombatTextPage 274).
   - Raid's Arena row shows on Classic Era, which has no arena frames (RaidStyle 662).
4. **Reset has six meanings and places:** row Reset, panel "Reset all", panel tools "Reset" (same thing twice,
   StylePages 4196/4230), Reset page ("your profile's values", Options 1578 vs "its default", StylePages 4208),
   "Use General" (two meanings: GeneralStyle 576 vs StylePages 4401), Clear overrides, Layout Preset, CT tab Reset.
   **No undo anywhere**; the only confirm is Reset page.
5. **The good tools are locked in tabbed panels.** Source tags, changed dots, Hold to compare, Copy/Paste and
   hover previews exist only in `rows.Look` with `tabs` — and even there hover does nothing on Unit, Raid and every
   inline panel (UnitStyle 4108, RaidStyle 561, no `spec.preview`). Copy/Paste shows on one-look pages with
   nowhere to paste.
6. **Previews are missing or partial.** None: Overrides (unless popped out), Interface Recolor, Minimap, Damage,
   Emote, Names Size tab. Partial: General's jumbotron (no minimap, bars, recolor, Visions), Bubbles (ignores
   Behind Bubbles), Range Hint (fixed cycle ignores Delay/Hide after), Weather (no Test/pop-out).
7. **Same thing, different words.** Background / Behind the bar / Dark ground; Custom / Your own; Test / Play;
   Follow General / Follow main theme; "Same as the Default row" / "Default row's"; Cast Style / Cast Bars; tabs
   Vision|Style, Vision|Look, Vision|Dialogue, Events|Card Types|Settings.
8. **Behavior on look pages.** Vitals sound + volume, Quest Talk Controls, Text on You's Show in, Range Hint sound,
   Combat Text's Who draws, Damage type tiles split from their settings.
9. **Dead code.** `rows.PresetMenu`, `rows.Sub`, `tabbed.themeLook` (Start from a theme: never passed),
   `spec.defaultName`, `db.styleThemeKept` + `ns.UndoStyleTheme` (written every theme pick, read only by a test).

The CQL editor works because it is **one window with one grammar**: a fixed frame, a sidebar of categories,
one button kind, live truth ("True here"), search, a footer that never moves. The Style pages need the same.

---

## 2. Goals and limits

- **One editor, one grammar, every Style page.** A player who learned one page knows them all.
- **Nothing works silently.** Every control either changes what you see in the preview, or says why it can't
  (with a button that fixes it).
- **Every setting reachable in two clicks or a few typed letters** (Find a setting).
- **Undo for everything**, one Reset with one meaning, a confirm that says how many settings it touches.
- **Click the thing to edit it**: parts are picked on the preview, like the plate Layout tab already does.
- **Saved settings don't change.** Every db key keeps its name and meaning; the editor is a new view over them
  (as the CQL rewrite kept every rule). Exceptions are listed in section 8 and each gets an audit card.
- **The hub, its icons, tabs and switches don't move** (layout is the tree). Each Style page keeps its id, its
  Enable switch, its right-click and its place.
- Forever and retail (and Classic Era where it runs); per-client controls hidden, not greyed; mouse, keyboard,
  gamepad; every theme's palette (Skin roles, as the CQL editor uses them).

---

## 3. The Studio: one editor in two hosts

One editor (`ns.StyleEditor`), drawn in two hosts from the same code:

### 3.1 Style Studio window (wide): 960 x 640, fixed

```
+-- STYLE   Interface › Nameplates › Target            [ Find a setting… ]  ↶ ↷  Theme: Gilded Codex ▾  [Dock] [X] --+
| RAIL (176)          | STAGE (452)                                  | INSPECTOR (300)                               |
| Find…               |                                              | LOOKS  [Theme's][Game's][Bold][Clean][+ Save] |
| ◆ Everything        |        [debuffs]                             |-----------------------------------------------|
| ● Changed       14  |        Gnoll Brute            [14]           | APPLIES TO  Default › Hostile › [Target] ▾    |
|---------------------|        [=============       ]                |   (Target follows Default except 3 settings)  |
| INTERFACE           |        [Fireball ======    ]                 |-----------------------------------------------|
|  Combat             |                                              | PART  Name                     Shown: Always ▾|
|   ■ Unit frames  •  |  ( Style | Arrange )   click a part to edit  |  TEXT                                          |
|   ■ Cast bars       |----------------------------------------------|  ● Font     [Friz][Morpheus][Marcellus][More] |
|   ■ Personal        | Unit [Hostile][Neutral][Friendly][Player]    |  ◆ Size     ───────●──── 110 %                |
|  Nameplates         | Show [Casting][Debuffs][Target][Raid mark]   |  ↑ Color    [Game][Theme][Class][Reaction][■] |
|   ■ Nameplates   •  | Ground [Scene][Dark][Light]  Zoom [1x][2x]   |  ● Outline  [None][Thin][Thick]               |
|   ■ Names           | [ Test ]  [ Hold to compare ]  [ Peek ]      |  ○ Shadow   [None][Soft][Strong]          ↺   |
|  Info  …            |                                              |  PLACE   Hang on [Health bar ▾] Side [Top]    |
| VISIONS …           |                                              |          Left/right ─●─ 0 px  Down/up ─●─ 4 px|
| ATMOSPHERE …        |                                              |                                               |
+---------------------+----------------------------------------------+-----------------------------------------------+
| 3 changes on Nameplates · Target           [Copy look] [Paste]          [Reset ▾]                      [Done]     |
+------------------------------------------------------------------------------------------------------------------+
```

- **Title bar**: where you are (breadcrumb, each crumb clickable), Find a setting, Undo/Redo, the theme chip
  (opens the theme gallery in the stage), Dock/Pop out, X. Same chrome as the CQL editor (flat edge, Skin roles).
- **Rail**: every Style frame grouped as the hub's bands (Interface: Combat / Nameplates / Info, Visions,
  Atmosphere), colored band squares as the CQL categories. Each frame shows its switch as a pip (click or
  right-click toggles it, the same key as its page's Enable switch) and a **gold dot when it differs from the
  theme**. Two special views at the top: **Everything** (theme, fonts, shared recipes) and **Changed (n)**: every
  setting you changed anywhere, grouped by frame, each with ↺ — the "In this rule" of Style.
- **Stage**: the frame's real preview (the existing preview builders, see 6), with **hotspots**: pointing at a
  part outlines it and names it; clicking picks it in the inspector. Two modes: **Style** and **Arrange** (drag,
  arrow-key nudge, guides — today's Plate Layout, available to any frame whose parts can move). Under it the
  state bar: which unit/variant is shown, which states (Casting, Debuffs, In combat…), Ground (Scene/Dark/Light),
  Zoom, **Test** (plays the frame's animation: casts, numbers, letterbox in/out, a Vision card), **Hold to
  compare** (shows how it looked when you opened the Studio), **Peek** (fades the Studio out while held so you
  see the real frames in the world; Settings itself isn't touched, to stay clear of taint).
- **Inspector**: top to bottom, always the same order:
  1. **Looks** strip: Theme's, The game's, built-in looks for this frame, your saved looks, + Save. Hover = preview.
     Replaces Preset dropdowns, Layout Preset and "Start from a theme".
  2. **Applies to**: the variant chain, e.g. `Default › Target` (unit frames: Default, Player, Target, Focus, Pet,
     ToT, Party; plates: Default + the Smart rows; raid: Default, Raid, Party, Arena; cast bars: Default, Yours,
     Target & focus, Boss & arena, Nameplates). A line says how far it follows its parent ("follows Default
     except 3 settings"). A variant can carry a **When** rule (opens the CQL editor) where the page has rules
     today (Smart rows); see 7.
  3. **Part**: the picked part, with **Shown** (Always / Never / Follow Interface page: today's Overrides).
  4. **Property groups** built from **recipes** (4.2), in a fixed order: Text, Bar, Icon, Border, Background,
     Place, Motion, Sound-free.
- **Footer**: what changed here, Copy look / Paste (shown only when there is somewhere to paste), Reset ▾, Done.

Small screens: below 700 px of UIParent height the window scales to fit; below 1100 px width the rail folds
to icons (band squares + dots).

### 3.2 The Style page (compact): the same editor in the Settings page

Each Style page in Settings stays where it is, with its title, Enable switch and right-click, and shows the
**same editor in one column** (480 px): stage on top (sticky, as now), state bar, Looks, Applies to, a **parts
list** (the stage's hotspots as a list too), then the inspector. A button **Open in Studio** opens the wide
window on this frame, docked beside Settings. One build, two layouts: a fix lands in both.

This retires the preview's slide/dock/pop-out machinery (StylePages DockSpot, SlideSettings, UpdateSticky):
the compact page keeps its sticky stage; the Studio replaces the popped-out preview.

---

## 4. The grammar: one control per kind of choice

### 4.1 Controls (`Style/Studio/Controls.lua`)

| Kind | Control | Rules |
|---|---|---|
| On/off | **Switch** (the CQL editor's flat button with a knob) | label says what "on" does |
| 2-5 words | **Segments** | never radio boxes, never three PanelButtons |
| Looks you judge by eye (font, texture, shape, border art, panel style, icon shape) | **Tiles** strip with a picture, + **More…** gallery in the stage | hover previews on the stage with "Preview: not saved" |
| Long list (zones, card types, sounds) | **Dropdown** with a Find box | |
| Amount | **Slider** with its value as an edit box and its unit (`%`, `px`, `s`) | default tick on the track; double-click types; right-click resets. Sizes 50-200 % (100 in the middle), opacity 0-100 %, offsets -100..100 px, times 0-5 s. No raw multipliers (Text on You's 0.5-3) |
| Color | **Color chips**: `[The game's] [Theme] [Class] [Reaction] [■ Custom]` | only the chips that apply (hide-unclickable); Custom opens ColorPalette with the **theme's 7 colors** as its first row |
| Place | **Hang on** dropdown + **Side** segments + two offset sliders, and drag on the stage in Arrange | one word pair everywhere: Left/right, Down/up (not Shift/Up) |
| Action (Test, Move, Listen) | **Button** (the CQL red-gold button) | an action never sits in a dropdown |

Every **property row** has the same four parts:

```
[source]  Label ················ control ················ [↺]
```

- **Source mark**, one look everywhere: `○` the game's · `◆` theme (in the theme's accent) · `↑` follows the
  variant above (blue; click to jump there) · `●` yours (gold). Replaces "Set here / General's / Set by theme" text.
- **↺** shows only when the value is yours: back to what it follows.
- **Right-click**: Reset · Copy · Paste · Show on other frames (Find with this setting's name).
- **Greyed** only when another setting can turn it on, and then the tooltip names that setting with a
  **Turn on** link (fixes Behind Bubbles, Minimap border). Otherwise hidden.

### 4.2 Recipes (`Style/Studio/Recipes.lua`): the same setting set everywhere

| Recipe | Properties (always this order) |
|---|---|
| **Text** | Font (tiles) · Size % · Color (chips) · Outline: None / Thin / Thick · Shadow: None / Soft / Strong |
| **Bar** | Texture (tiles) · Color (chips) · Gradient (on/off + Fades to + Direction) · Background (color + opacity) · Spark · Smooth |
| **Icon** | Shape (tiles) · Zoom · Size · Border (recipe) |
| **Border** | Style (tiles: None, Line, the theme's art…) · Size px · Color (chips) |
| **Background** | Color (chips) · Opacity % · Panel shape (tiles, where the frame has one) |
| **Place** | Hang on · Side · Left/right · Down/up · Size % · Gap |
| **Motion** | Fade in s · Stay s · Fade out s · Rise / Grow · Pulse |
| **Glow / Band** | (Names, plates) Color · Size · Opacity |

A page's old controls map onto a recipe's properties **by key**: e.g. Tooltip `tooltipOutline` (3 levels) and
Bubble's 4-level outline both become Text.Outline + Text.Shadow; "Thick + shadow" reads as Outline Thick +
Shadow Strong. Where an old key packs two properties, a recipe property reads/writes the same key through a
small adapter (`get`/`set`), so saved values stay valid (section 8 lists the 4 adapters).

### 4.3 Words (one name per thing)

Background (never Behind the bar / Dark ground; Raid's two become **Bar background** and **Tile background**) ·
Custom (never Your own) · **Test** (never Play) · **Follow main theme** everywhere (plates too) · "Follows
Default" · The game's · tabs on every Vision/Atmosphere icon: **Vision | Style** (Quest: Vision | Style | Quest
Item Button; Cards: Events | Card Types | Settings stays, it's three things). Page titles = hub label
("Cast Bars", not "Cast Style"). Title Case only for page titles and Enable switches; tooltips one sentence.

---

## 5. Utilities, the same on every frame

- **Undo / Redo**: one history for the whole Studio session (Ctrl+Z / Ctrl+Y, the title bar arrows; the gamepad's
  back + shoulder). Each step is named ("Target · Name font → Friz Quadrata"), resets and theme picks included.
  Kept while the game runs (`ns.StyleHistory`, not saved). `db.styleThemeKept` / `ns.UndoStyleTheme` retired into it.
- **Reset**: one meaning, **back to what it follows** (the variant above, else the theme, else the game's).
  Scopes in one menu: This setting (↺) · This part · This variant · This frame · Everything in Style.
  The menu says the count ("Resets 12 settings on Nameplates") and an Undo toast follows. The page header's
  **Reset page** = This frame. Gone: panel "Reset all" + tools "Reset" twins, "Clear this row", "Use General",
  "Use Visions Style", Clear overrides, Layout's Reset part/Reset layout, CT tab Reset (all become scopes).
- **Hold to compare**: the stage as it was when the Studio opened (or as the theme draws it, Shift-held).
- **Copy look / Paste**: per recipe, so Text can go from Tooltips to Names. Paste lists where it can go.
  Hidden when nothing can take it.
- **Find a setting**: types against every property's label, its recipe name, synonyms ("thickness" → Border
  Size) and the frame; results grouped by frame; Enter jumps and flashes the row. The same index answers
  `/cine find` for Style settings.
- **Changed (n)**: the rail view of every setting you set, grouped by frame, each with ↺ and a jump.
- **Saved looks**: + Save on the Looks strip names the frame's look; your looks are account-wide
  (`styleMyLooks`), shareable as `CINEL1:` strings (Share.lua's pattern).
- **Why isn't it showing?** A status line under the stage when the frame can't be seen live: "Off: Enable Style
  › Nameplates" with **Turn on**; "Dominos draws your action bars" (no button); "Needs Chat › Bubbles › Behind
  bubbles" with **Open**. Uses ns.StyleOn's chain and the addon gates already in Support/.
- **In fights**: theme picks and Looks are locked (they already are: ApplyStyleTheme), the Studio shows a lock
  line; single settings that are safe stay live.

---

## 6. Stages (previews)

Each frame gets a stage adapter `{ Build(host), Draw(state, values), parts = { id = hotspot rect fn }, Test() }`
around the preview it already has; new ones where there is none:

| Frame | Stage | New work |
|---|---|---|
| Unit frames | UnitFrameCopy copy | hover previews draw pending values (today a no-op, UnitStyle 4108) |
| Cast bars | PlateCastStyle samples | one stage, variant picks the sample |
| Personal | PersonalStyle preview | animate Test (spend + regen) |
| Raid | RaidStyle tiles | hover previews (RaidStyle 561) |
| Action bars | 3 icons + empty slot | add hotkey/count text |
| Cooldown Manager | ring + icons (one stage, not two) | merge the second preview (CdmStyle 260) |
| Range Hint | looping mark | Test honors Delay / Hide after / Sound |
| Combat Text / Text on You | plate numbers / character board | one "Floating text" stage family |
| Nameplates | MakePlateRowLookPreview | **apply PlateLayout and measure parts** (fixes debuffs over name); states per host, not module-global (PlateRowLook 372) |
| Names | scene with a name per kind | **Distance** slider on the stage (Near…Far) previews Size by / Far names |
| Bubbles | MakeBubblePreview | draw the Behind-bubble line |
| Tooltips | unit + item tooltip | name color "The game's" reads the game color, not white (TooltipStyle 510) |
| Minimap | **new**: square/round map art, ring buttons, zone bar | |
| Recolor targets | **new**: tracker lines, meter bars, swing bar, XP bar | |
| Overrides | the unit frame / plate stage with Shown applied | parts hidden/shown live |
| Visions | jumbotron cells + **new** Damage meter list and Emote card | |
| Tint / Letterbox / Weather | split before/after scene; letterbox bars; weather panes | Weather gets Test and strength-0 fix |
| Everything | montage of every frame, each clickable (jumps to it) | covers the frames General's jumbotron misses |

---

## 7. Every page, what it becomes

Keys don't move. "Moves" lines change where a control lives and **need the user's OK** (ask-where-settings-go):
they are collected in section 10.

| Page id (label) | Frame · variants · parts | Fixes on the way |
|---|---|---|
| Style General | **Everything**: theme gallery, Text fonts (title/body/small), Bar texture, Shapes (panel, bar, button), Outline & border inline (no popup) | Reset covers fonts/texture/shapes (field keys recorded); RefreshAll adds Combat/Self Text; Recolor row gets its theme tick |
| Style Themes | Theme gallery + your-theme editor in the stage; card actions on a visible `⋯` (not right-click only) | Undo via history; heading casing |
| Style Overrides | the **Shown** property of each unit/plate/bar part; an "Overrides" list in Changed | Clear overrides = Reset scope; previews show it |
| Interface Recolor | Info › **Trackers & bars** frame: Quest tracker, Damage meter (clients that have it), Swing timer, XP/rep, Raid recolor as parts; each color = chips | greyed with a reason while theme = the game's; "Frame color" ×4 named per part |
| Minimap Style | Minimap: Map, Border, Ring buttons, Zone bar | border color not greyed while it still tints rings; refresh on theme change, not only OnShow; named colors → chips |
| Unit Style | Unit frames · Default, Player, Target, Focus, Pet, ToT, Party · Bar, Portrait, Name, Level, Border | Party drawn by Raid → "Raid frames draw your party · Edit there" link, not a live button; "Follows Default" wording |
| Unit Cast / Player Cast / Cast Bar Style | **Cast bars** · Default, Yours, Target & focus, Boss & arena, Nameplates · Bar, Icon, Spell name, Timer, Shield, Border | Nameplates variant can pick The game's; Outline/Shadow recipe; Timer under Text; `defaultName` removed. Each tab opens on its variant; switches unchanged |
| Personal Style | Personal resources · Health, Power, Mana (retail), Class resource | heights 50-200 % (adapter keeps 1.0 = 100 %); Copy/Paste hidden |
| Raid Style | Raid frames · Default, Raid, Party, Arena (clients with arena frames) · Bar, Name, Border, Tile | Arena hidden on Classic Era; Bar background vs Tile background |
| Action Style | Action bars · Icon, Empty slot, Border | "Dominos/Masque draws your bars" status |
| Cooldown Manager Style | Cooldown Manager · Drain ring, Icons, Cooldown + DoT | one stage; colors to chips; tab tools the same as everywhere |
| Range Hint Style | Range Hint · Mark, Text, Background, Motion | Outline/Shadow recipe; Listen button in the stack |
| Combat Text Style | Floating text · the ~20 texts as variants (grouped: Yours, Incoming, Heals, XP…) · Number, Miss words, Motion | Who draws recorded for Reset; `combatTextNumbers` can't grey the tab forever |
| Self Text Style | Floating text (on you) · kinds as variants · Board place on the stage | Quick-look tile reflects edits; % not multipliers; Test not Play |
| Nameplate Style (+ Layout, Smart) | Nameplates · Default + Smart rows (each with its When rule) · Name, Health, Level, Debuffs, Buffs, CC, Raid marker, Elite, Cast, Quest, Soft target · **Arrange mode = Layout tab** (the tab and its `plateLayout` switch stay; it opens the editor in Arrange) | width/height/change time move to Default's Plate part; Customize no longer fake-clicks a hidden button; Layout Preset → Looks with undo; Reset layout tooltip; intro per tab |
| Name Style | Names · All names + kinds (tree) · Text, Glow, Band, Second line, NPC titles; Distance group with stage slider | theme as tiles here and on plates, "Follow main theme" both; hidden distance settings: see decision 3; text size 50-400 % on both |
| Bubble Style | Chat bubbles · Bubble, Text, Tail, Behind bubbles | Behind bubbles: status + Open; Test/Move grey with it |
| Tooltip Style | Tooltips · Panel, Border, Health bar, Name, Text | outline recipe; game name color |
| Visions Style | Visions › Everything: shared Text/Border/Texture; each Vision's follow chip | **Reset page resets only its own keys**; "Reset every Vision" is a scope with a count |
| Damage Vision Look | Damage Vision · Bar, Words, See-through, Position · **new stage** | built only where C_DamageMeter exists; grey on the right switch; Custom wording |
| Vitals Style | Vitals · its themes stay the Looks strip (best on the hub today) · General, Blizzard, Cinematic art, Swirl, Mana, Game effect (retail) | opacity sliders throughout; dev tooltips localized or dev-only |
| Quest Talk Style | Quest · Panels, Words, Layout | Panels summary bug; greys on Enable Style |
| Quest Item Style | Quest Item Button · Button, Ready glow, Cooldown, Text | hub label; summary bug |
| Roll Style | Roll · Cards, Text, Time left (height moves inside), Picks, Winner | summary bug; icon hidden without a loot history |
| Emote Vision Style | Emote · Style tiles, Words, Frame · **new stage** | greys on emoteStyle + Enable Style |
| Card Styles | Cards · card types as variants ("Editing" becomes Applies to) · its LookGrid groups as recipes | **Enable Page = the style switch, not `cards`**; dot tip wording |
| Tint Style | Tint · Look, Zones, Time of day as stage modes; palette editor in the inspector | greying through the kit, not an overlay; 480 compact like the rest |
| Letterbox Style | Letterbox · Bars, Edge, Line, Coming in and going | greys on Enable Style; heights as sliders |
| Weather Style | Weather · one part per weather | Test + Studio stage; strength 0 preview |

Also gone: `rows.PresetMenu`, `rows.Sub`, `tabbed.themeLook`, the 5 hand-made segment/tile/cell widgets in
Combat Text, Text on You and Plate Layout, `ns.VisionRows` Builder on Style pages, Tint's own tab bar and Chip.

---

## 8. Data: frame specs, not hand-built pages

Each frame is a declarative spec (`Style/Studio/Frames/<frame>.lua`), read by both hosts:

```lua
ns.StyleFrame("plates", {
	page = "Nameplate Style", switch = "handlePlateStyle", band = "Interface", sub = "Nameplates",
	stage = ns.StagePlates,                              -- adapter (section 6)
	variants = ns.PlateVariants,                         -- Default + Smart rows, each with key prefix + When rule
	looks = { "theme", "game", "bold", "clean" },
	parts = {
		{ id = "name", label = L["Name"], shown = "platePartName",
			recipes = { Text = { font = "plateNameFont", size = "plateNameSize", color = "plateNameColor",
				outline = "plateNameOutline", shadow = "plateNameShadow" },
				Place = ns.PlateLayoutPlace("name") } },
		{ id = "health", label = L["Health bar"], recipes = { Bar = { … }, Border = { … } } },
		…
	},
})
```

- Every property names its existing db key (or a `get`/`set` adapter). Offline check: every key in a spec
  exists in `ns.DEFAULTS` and has a runtime reader (the audit's grep, automated).
- **Adapters** (the only reads that reinterpret old values; each with an audit card): Bubble 4-level outline →
  Outline + Shadow; Range Hint outline 0/1/2 → None/Thin/Thick; Text on You multipliers → %; Personal heights
  1.0 → 100 % on a 50-200 % track.
- Variants carry the inheritance chain the pages already implement (Default row, "inherit" values from D12 of
  the 2026-11-14 revamp); the editor only shows it.
- Switches: the frame's `switch` is its page's Enable key; variants with their own tab keep their tab switches
  (ns.TabContainer). The switch tree doesn't change.

---

## 9. Depth: what players gain (beyond fixing)

Proposed, each small on top of the framework; **pick which go in** (decision 6):

1. **Look rules**: any variant can carry a **When** CQL rule (today only plate Smart rows): "Names look like
   this in dungeons", "Unit frames go minimal out of combat". Uses `ns.OpenRuleEditor` and the compiled rule
   cache the plates already use.
2. **Saved looks + sharing** per frame (`CINEL1:`), next to the theme sharing that exists.
3. **Contrast check**: a text color too close to its background gets a small amber mark on the row (WCAG ratio
   from the stage's measured colors).
4. **Theme palette in the color picker**: the theme's 7 colors as the first row, so custom colors stay on-theme.
5. **Gradient & depth on every bar** (the "nothing one color" rule): the Bar recipe's Gradient and the sheen
   become available wherever a bar is drawn.
6. **Action bar text**: hotkey and count as a Text recipe (font, size, outline) — the Styling book's open item.
7. **Peek** (hold to see the real world with the Studio faded) and **2x zoom** on every stage.

---

## 10. Decisions (answered 2026-11-25: "Yes, recommended" — every first option below)

1. **Hosts**: Studio window + the same editor compact on each page *(recommended)* · page only · Studio only.
2. **Behavior settings out of Style pages** (each to its feature's own page, keys unchanged): Vitals sound +
   volume → Vitals Vision tab; Quest Talk Controls → Quest Vision tab; Text on You's Show in → its Show tab;
   Range Hint sound → Range Hint page; Combat Text's Who draws → Combat Text's Show tab; Damage type tiles next
   to their settings on the Vision tab. *(recommended: all six)*
3. **Hidden Name distance settings** (plateNameY, fixed size, hide delay, fade, close/far size): show them again
   in the Distance group *(recommended: players' values come back into view)* · or reset them once to defaults.
4. **Cast bars as one Studio frame** with variants (each hub tab still opens on its own variant, switches
   unchanged) *(recommended)* · or three frames.
5. **Overrides as each part's Shown** (and the Overrides tab opens the Studio's Changed › Overrides list)
   *(recommended)* · or keep the Overrides tab as is.
6. **Depth items** (section 9): all seven *(recommended)* · pick some · none for now.

---

## 11. Build, test, risk

Built in one go (user rule: no phases), in this order inside the build:

1. `Style/Studio/` — Editor.lua (model: frames, variants, parts, recipes, source resolution), History.lua,
   Find.lua (index), Controls.lua (the grammar), Recipes.lua, Window.lua (Studio host), Page.lua (compact host),
   Stages/*.lua (adapters).
2. Frame specs for all 29 frames (38 page ids).
3. Pages switch to `ns.StyleEditor(page, "compact")`; old builders removed (sections 1.9, 7).
4. The fixes in section 7.

Notes: new labels are `ns.L` English keys only (no locale edits till release). "Back to what it follows"
for a key with no inherit value means its `ns.DEFAULTS` value under the game's look, or the theme's value
under a theme, the same as page Reset does today (page-defaults), so Reset page keeps its meaning.

Tests:
- **Offline** `Tools/offline/stylestudio.lua`: every spec key exists in DEFAULTS and has a reader; every frame's
  inspector fits 300 px wide and the compact page 480 px on both clients; every control kind is from the grammar
  (no raw kit widgets on Style pages); Reset scopes count right and Undo puts back every value; Find reaches every
  property; switch tree unchanged (`/cine debug sweep pages` offline: 0 warnings); settings sweep over every
  Studio property.
- **Style Lab**: `studio-*` frames in `Tools/style-lab/dump.lua` for every theme (as `cql-*`).
- **Audit kit**: a card + old/new matrix for each changed behavior: Card Types switch, Visions reset scope,
  hidden Name settings, the four adapters, greying fixes, Minimap border color.
- **In game, one run**: TestKit `stylestudio` on Forever (then retail): opens each frame in the Studio and its
  compact page, picks every part by its hotspot, flips each Looks tile, Reset frame → Undo, Find "outline",
  one shot per frame; checks no deverror/BLOCKED. Never opens Settings from the test on Forever while a gamepad
  is attached (blocked line): it uses the Studio window alone there.

Risks:
- **Size**: the biggest UI change in the addon (estimate 7-9k lines touched, ~4k removed). Mitigated by keys not
  moving and both hosts sharing code.
- **Taint/combat**: the Studio is our own frame, never parents Blizzard secure frames; docking beside Settings
  reuses the CQL editor's dock (no SettingsPanel sliding).
- **Performance**: stages draw on change, throttled to one draw a frame; rail dots from a changed-index kept up
  by History, not by scanning db.
- **Retail secrets**: stages use the existing preview copies (preview-match), nothing reads live secret values.

---

## 12. Audit sources (file:line)

The mockup's Audit and "What's broken" tables carry each finding with its file:line (2026-11-25, main at
f5d5702 + uncommitted work). Line numbers drift: re-grep before fixing.
