# Plan: npc / interacting rule words + All names rule

Asked 2026-11-24 (Discord, rudy, DialogueUI): hide names while talking to an NPC.

## The problems today

1. **`npc` is named wrong.** It doesn't mean "an NPC". It is on while any NPC or
   service window is open (vendor, gossip, quest, trainer, bank, auction house,
   flight map, book text, mailbox, even a trade with a player: Core.lua
   NPC_WINDOWS / REVEAL_AT_NPCS), or the game has an `npc` unit (Frames.lua
   facts.npc). Its button "At an NPC" hides behind You > +4.
2. **A rule covers one row only.** Every Names row has its own rule, and the
   rows OR together: `not npc` on the Target row hides only what that row adds.
   The Service NPCs row (rule `not camera`, titles by default) still shows a
   vendor's or quest giver's title, so the name turns into the title as the
   window opens (the "glitch").
3. **No rule over all names.** Hiding every name while talking means editing
   every row.

## The design

| Word | Means | Editor line | Button |
|---|---|---|---|
| `npc` (new meaning) | Your target is an NPC, any reaction: `hostilenpc or neutralnpc or friendlynpc`. Read in fights too, as the kind words are. | Target | Any NPC |
| `interacting` (new word) | An NPC or service window open (the old `npc` list, mailbox and trade included), or the game's `npc` unit there (so DialogueUI, which hides the game's gossip and quest windows, still counts). | You (first line, not behind +4) | Interacting |

- **Talking to an NPC only** (no mailbox) = `interacting and npc`.
- Known gap: an NPC targeted, then a mailbox opened = on. Said in the word's tooltip.

**All names**: a new parent row at the top of the Names grid with its own
rule (default `always`). While it is off, every Names row's names are off:
Target, Mouseover names, Service NPCs (titles too), group, guild, all kinds.
Switch tree: parent off stops its children.

The player's case: All names = `not (interacting and npc)` (or `not interacting`).

## Target vs Service NPCs (and the other kind rows)

Today the rows OR together: the Target row can only add your target's name,
never take it away. So a Target rule saying "hidden" (the editor's "Right now:
hidden") still leaves the name up when Service NPCs (or Friendly NPCs...)
keep it, drawn by that row instead: the name turns into the vendor's title
(Service shows titles by default), the "glitch" seen at Tradesman.

**Fix: the Target row's rule decides for your target.** With a rule on the
Target Names row, your target's name is shown or hidden by that rule alone:
- rule true: shown, in the Target row's look (no title swap while targeted);
- rule false: hidden, whatever Service, Friendly NPCs or any kind row says;
  other (untargeted) units are untouched.
With no rule (ticks only, the default), it stays as today: the Target row
adds, the kind rows still show what they show. So no player's setup changes
unless they wrote a Target rule, and those players already meant it.

The same for the Target Nameplates row's rule and your target's plate, so the
two rows read the same way. (Mouseover rows stay add-only: the mouse passes
over too much to have it hide things.)

The editor's tooltip for the Target rows says it: "With a rule, this row
alone decides your target's name."

The player's case can then be either:
- just their target: Target Names = `not interacting`;
- every name: All names = `not interacting` (below).

## A Target tab on Names

The Nameplates and Names icons share one page; a section goes to the Names
icon only when its key starts with "Names" (Options.lua IsNames). The Target
section (key "Target", built 2026-10-29, before the two icons split on
2026-11-16) holds both rows, plate and name, plus the Mouseover pair, so the
whole of it stayed on the Nameplates icon. Your target's name row is on
Nameplates > Target, not on Names.

**Fix: split it** (layout is the tree: name rows on the Names icon):
- Nameplates > Target: Nameplates, Mouseover nameplates.
- Names > Target (new first sub-tab, key "NamesTarget"): Names (your
  target's), Mouseover names. Same setting keys and rule keys
  (name:YourTarget, name:YourMouseover): nothing saved moves.
- /cine find ids for the two name rows point at Names > Target
  (Dev/FindTabsTest.lua's list updated); the Section remembered as open
  ("Target" on the Names side) falls back to NamesPlayers.

**All names** sits above the Names sub-tabs (under Enable Page), so it reads
as the parent of every tab, Target included.

## Steps

1. **Words** (Frames.lua RULE_WORDS + facts): `npc` = any NPC target;
   `interacting` (alias `interact`) = the old npc fact. Aliases kept for both.
2. **Migration** (Migrations.lua, as the `world` / `arena` rewrites): every
   saved rule's `npc` becomes `interacting`, once, before the new meaning, so
   no player's rule changes what it does. All profiles.
3. **Editor** (UI/GridRows.lua): "Any NPC" on the Target line (after Friendly
   NPCs), "Interacting" moved to the first line of You. Short tooltips.
4. **All names row** (Options.lua Names grid, Effects.lua NameKeptHere, the
   Service NPCs title path, Mouseover names): rule key `name:AllNames`,
   default `always` in ns.RULE_DEFAULTS. A gate checked once a tick, not per
   plate. Page Reset puts it back.
5. **Target rule decides** (Effects.lua: the name and plate passes, where a
   unit is your target): a Target row with a rule overrides the kind rows,
   Service included, for that one unit; its look wins while shown. Checked
   once per pass for the target only (no per-plate cost).
6. **Names > Target tab** (Options.lua Target section split in two, as above).
   Test: the menu test opens Names > Target and Nameplates > Target in every
   state (r:Overlaps, no row off its card, a shot each).
7. **Why** (UI/WhyFeatures / Effects explain): "Names: the All names rule is
   off here" and "Names: the Target rule hides your target's name" when they
   hide a name.
8. **Tests**
   - Offline `Tools/offline/rulewords.lua`: `npc` on for each NPC kind, off for
     players and yourself; `interacting` at a vendor, a mailbox, gossip with
     no window (DialogueUI case: `npc` unit only); the migration rewrite
     (`not npc` -> `not interacting`, `npcs` untouched).
   - Offline names check: All names off = every row off, Service title too;
     `always` = no change from today. Target rule false on a targeted vendor
     = its name and title hidden, an untargeted vendor's title still up;
     Target rule true = Target look, no title; no Target rule = as today.
   - In game: extend `Dev/RuleWordsTest.lua` (no new test). ONE real action:
     open a vendor, close it. Checks `interacting`, `npc`, the Target rule
     `not interacting` hiding the vendor's name and title (no swap to the
     title), then the All names rule doing it for every name, both back after
     closing. Queued through the test queue.
   - luacheck, Tools/offline/run.py.
   - /audit card for the Target rule change (rows that had a Target rule).
9. **After**: ledger line (Tools/features/requests.md), the player's reply,
   What's new check before the commit.

## Clients

Both (Forever and retail). No addon code (DialogueUI is covered by the `npc`
unit, not by its frames). DialogueUI with the in-game test: untested until run.

## Not changing

What turns `interacting` on (mailbox and trade stay in). Splitting them out
would change existing rules: an audit of its own.

## Size

Medium: one session.
