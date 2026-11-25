# Plan: the whole CQL vocabulary, once

Asked 2026-11-25. Plan only, nothing built. Sources: `ns.RULE_WORDS` and `ns.RulePieces`
(Frames.lua:3705, UI/GridRows.lua:55), the Forever API dump (`Tools/engine/api/forever.txt`,
410 systems, 1816 events) and the exported game UI (`_forever_\BlizzardInterfaceCode`).
Tags: **[F]** in Forever's API dump; **[R]** retail only; **[?]** a legacy global the dump
doesn't list (IsMouselooking, IsInRaid...): confirm with `/cine debug rulewords` before building.

## Why we keep adding words

1. **Words are combinations, not atoms.** `enemyplayer`, `hostilenpc`, `hoverneutralnpc`...
   are reaction x kind x unit baked into one word: 6 target kinds + 6 mouse kinds = 12 words for
   what 5 atoms say. Every new unit (focus, mouse) or property (elite, dead) multiplies again.
2. **No subject rule.** Target words have no prefix (`enemy`, `near`, `npc`), mouse words do
   (`hoverenemy`), you-words have none either (`dead`, `casting`). So `dead` is you, `targetdead`
   your target, `hoverdead` the mouse: three spellings of one property.
3. **Meanings that drift.** `npc` meant "a window open" until yesterday; `storm` meant rain or
   snow; `raid` is a place but reads like a group; `pvp` = `bg` but sounds like `flagged`;
   `walking` = RP walk; `friendly` = "not attackable" (dead units too), not the game's reaction.
4. **Gaps found one player at a time** (the npc/interacting fix, mouse words, weather).

## The rule from now on

- **One word = one fact on one axis.** Combinations are `and`/`or`/`not`, never a new word.
  `interacting and npc` (talking to an NPC), `hostile and player` (enemy player),
  `hoverdead and hovernpc` (a corpse to loot).
- **Unit words are one table of properties, written once, generated for each unit**:
  no prefix = your target (as today), `hover` = the mouse, `focus` = your focus (new).
  Adding a property gives it to every unit; adding a unit gives it every property.
- **Words name what the player sees**, not the API (`talking`, not `gossip`).
- **Old words never break**: they stay as aliases (and/or a Migrations.lua rewrite for the ones
  whose meaning changes, as the npc move did). The editor shows only the new atoms.
- **A word costs nothing until a rule names it** (the hover pattern, `ns.hoverState.used`):
  every new word that needs polling or a unit read is gated the same way.
- **Per client:** a word the client can't read is left out of the editor (hide-unclickable), and
  reads false if typed.

## The full map

Legend: **keep** = as today; **new**; **alias** = kept for old rules, out of the editor;
**rename** = meaning changes, needs a migration.

### 1. Combat (you)
| Word | Means | Status |
|---|---|---|
| combat, nocombat, calm | in a fight / out / the calm timer | keep |
| entering, leaving | the moment a fight starts / ends (Cards only) | keep |
| boss | a boss fight (encounter, boss1, world boss) | keep |
| pvpfight | a fight with an enemy player in it (the Cards PvP fight test, as a word) | new |
| controlled | stunned, feared, charmed... (LOSS_OF_CONTROL_ADDED, HasFullControl) [F] | new |
| aggro | a mob is on you (UnitThreatSituation player >= 2) [F] | new |
| lowhealth | you under 35% (secret on Forever: via a curve, as mana thresholds) [F] | new |

### 2. You (state)
| Word | Means | Status |
|---|---|---|
| dead | dead or a ghost | keep (`ghost` alias splits off, below) |
| ghost | a ghost, running back | new (was an alias of dead) |
| casting | casting or channeling | keep |
| mounted, taxi, sitting, afk, stealthed, resting, flagged, indoors, outdoors | as today | keep |
| dnd | flagged busy (IsDND) [F] | new |
| vehicle | in a vehicle or on a seat (UnitInVehicle) [F] | new |
| shapeshifted | in a form (cat, bear, ghost wolf...) (GetShapeshiftForm) [?] | new |
| pet | you have a pet out | new |
| maxlevel | at the client's level cap | new |
| leader | group leader (UnitIsGroupLeader) [F] | new |
| group | in a group | keep |
| raidgroup | in a raid group, not a party (IsInRaid) [?] | new (the `raid` place stays a place) |

### 3. Travel (you)
| Word | Means | Status |
|---|---|---|
| moving, autorun, rpwalk, swimming, underwater, flying, fast, gliding [R] | as today | keep |
| falling | in the air, not flying (IsFalling) [F] | new |
| walking | (= rpwalk today) | alias, out of the editor |

### 4. Interacting (what you're doing with the game)
| Word | Means | Status |
|---|---|---|
| interacting | any NPC or service window, mailbox and trade too, or the npc unit | keep |
| talking | a conversation: gossip, quest text, book text, a talking head (TALKINGHEAD_REQUESTED [F]) | new |
| (services) | `interacting and not talking`: no word needed | - |
| movie | an in-game cinematic or movie playing (CINEMATIC_START, PLAY_MOVIE) [F] | new |
| mapopen | the world map up | new |
| menuopen | a big game window up: bags, character, spellbook, talents, collections, settings, game menu | new |
| editmode | Edit Mode open | new |
| mouselook | turning the camera with the mouse held (IsMouselooking) [?] | new |
| gamepad | playing on a gamepad right now (GAME_PAD_ACTIVE_CHANGED) [F] | new |
| housing | in your house's edit modes (C_Housing) [R] | new, retail only |

Per-window words (vendor, bank, auction...) are left out on purpose: no one has asked, and
`interacting`/`talking` split what a cinematic cares about. If one is ever needed it gets a
value word (section 10), not a boolean each.

### 5. Units: target, mouse, focus (one property table)
Written once as `ns.UNIT_PROPS`, generated per unit: target = bare word (`dead` would clash
with you, so target keeps its `target` prefix where today's word has one), mouse = `hover...`,
focus = `focus...`.

| Property | Target word | Mouse word | Means | Status |
|---|---|---|---|---|
| exists | target | hover | anything there | keep |
| self | targetself | hoverself | you | keep |
| dead | targetdead | hoverdead | dead | keep |
| enemy | enemy | hoverenemy | can attack it (alive) | keep |
| friendly | friendly | hoverfriendly | can't attack it (dead too) | keep (decided 2026-11-25) |
| hostile / neutral | hostile, neutral | hoverhostile, hoverneutral | the game's reaction color (red / yellow) | new |
| player / npc | player, npc | hoverplayer, hovernpc | a player / an NPC | npc keep, rest new |
| elite | targetelite | hoverelite | elite or rare elite (UnitClassification) [F] | new |
| rare | targetrare | hoverrare | rare or rare elite | new |
| bossunit | targetboss | hoverboss | a boss or world boss (not the fight) | new |
| questmob | targetquest | hoverquest | needed for a quest (UnitIsQuestBoss / tooltip quest line, as tipquest) [F] | new |
| tapped | targettapped | hovertapped | tagged by someone else (UnitIsTapDenied) [F] | new |
| critter | targetcritter | hovercritter | a critter or totem (UnitCreatureType) [F] | new |
| targetingyou | targetingyou | hovertargetingyou | its target is you | new |
| frame | - | hoverframe | the mouse on a unit frame | keep |
| near, near28, noplate, range bands | as today | - | distance (target only: the mouse can be anywhere) | keep |

Old kind words become aliases that compile to the pair:
`enemyplayer` = `hostile and player`, `hostilenpc` = `hostile and npc`, `friendlyplayer` =
`not hostile and not neutral and player` (by reaction, not `friendly`, which counts dead
enemies too)... (12 words, mouse ones too). No migration needed: the alias compiles to
the same test. Check first: `ns.TargetNameRow`'s rows must match the reaction exactly (a
friendly-faction player who's dueling you). The matrix test proves it.

Focus (decided 2026-11-25: now, with the rest): every property in the table, as `focus...`
(`focus`, `focusself`, `focusdead`, `focusenemy`, `focusfriendly`, `focushostile`,
`focusneutral`, `focusplayer`, `focusnpc`, then `focuselite`... in phase 3), plus
`focusnear`/`focusnear28` (distance, as the target's). Read on PLAYER_FOCUS_CHANGED and
UNIT_FLAGS/UNIT_HEALTH for "focus" only, gated like the mouse words. Out of fights only on
Forever where the target words are. Its own editor line, **Focus**, under Mouse over.

### 6. Place
| Word | Means | Status |
|---|---|---|
| world, city, inn, instance, dungeon, raid, bg, battleground [R], arena [R] | as today | keep |
| pvp | (= bg today) | alias, out of the editor |
| sanctuary | a sanctuary zone (GetZonePVPInfo) [F] | new |
| contested | a contested zone (GetZonePVPInfo) [F] | new |
| warmode | War Mode on [R] (IsWarModeDesired) | new, retail only |
| scenario | a scenario (C_Scenario) [F] | new |
| delve | a delve (C_DelvesUI) [R] | new, retail only |
| mythicplus | a keystone running (C_ChallengeMode) [R] | new, retail only |

### 7. Nearby
elite11, elite28, elite40: keep. New: `enemiesnear` (3+ enemy plates in 28 yards, from the plates
we already track) only if a player asks.

### 8. World
rain, snow, sandstorm, storm, weather, dawn, day, dusk, night: keep. Nothing missing.

### 9. Camera, Role, Class, Tooltip
Keep as they are. `tip*` stays Tooltips-row only, `entering`/`leaving` Cards only.
Role and Class are value axes already (see section 10).

### 10. Value words (decided 2026-11-25: yes, phase 4)
Axes with many values get one word that takes a value, `axis:value`, instead of a word each.
Full design in **Phase 4** below.

## What it costs to build

- **Phase 1, the atoms:** `UNIT_PROPS` table + generator, `hostile`/`neutral`/
  `player` (+ hover), the focus unit with phase 1's properties (its one new read, gated), kind words become compiled aliases, the editor shows atoms only (kinds out),
  `walking`/`pvp`/`mouseover*` out of the editor. Pure Frames.lua + GridRows.lua.
  Test: offline matrix (old kind word vs its pair, every TargetNameRow row) in
  `Tools/offline/hoverwords.lua` + npcwordmatrix; no game run needed beyond the rulewords kit test.
- **Phase 2, cheap event words:** ghost, dnd, vehicle, pet, leader, raidgroup, maxlevel,
  talking, movie, mapopen, editmode, gamepad, sanctuary, contested, scenario, falling, controlled.
  Each: one event or one cheap call, gated by `used`. Test: extend `Dev/RuleWordsTest.lua`
  (reuse, not a new test): it sets up what it can (open the map, edit mode, sit) and asks for at
  most one real action.
- **Phase 3, unit properties:** elite, rare, bossunit, questmob, tapped, critter, targetingyou
  for target, mouse and focus. Secrets in fights on Forever: same out-of-fights rule as the kind words.
- **Phase 4: value words** (below).
- Retail-only words: built with the phase, hidden on Forever, checked on retail in one run.
- Each phase: engine rules for every finding, `luacheck .`, What's new only for phase 1 + 4.

Limits to watch: Frames.lua main chunk is at its 200 locals (keep it on `ns`), and Frames.lua's
60-upvalue cap per function; the facts builder may need splitting.

## Phase 1 status (2026-11-25)

Built, uncommitted: `hostile`, `neutral`, `player` (+ `target...` aliases) and `hover...` forms
via `ns.SetKindAtoms`; the focus words (`ns.FocusWords`, gated by `ns.focusState.used`, also
`ns.factsEvery`); the editor shows atoms, old kind words colored but off it (`colorOnly`), a
Focus line where `FocusFrame` exists. Focus is read as it is (like the mouse), not out of fights
only. Offline: `Tools/offline/unitwords.lua`, `hoverwords.lua` ALL PASS. In game: the
`mousewords` kit test's `units` step 7/7 (queue q68c0, Forever) and its editor step 26/26
(q52b5). Retail not run.

## Phase 4: value words

### Syntax
- `axis:value`, no spaces around the colon: `zone:1453`, `class:mage`, `aura:465`.
- Several values on one axis: `zone:1453,1519` reads as `zone:1453 or zone:1519` (one map lookup).
- A value with spaces is quoted: `subzone:"Lion's Pride Inn"`. Values are compared lower case.
- Combines like any word: `zone:1453 and not interacting`, `not aura:465 and combat`.
- An unknown axis is an error ("zone2 isn't a word it knows"). An unknown value isn't: it just
  reads false (a zone from another client, a buff you don't have), and the editor marks it gray
  with "not known on this client".

### Values are ids, shown as names
Rules get shared (CINE1 strings, profiles), so they can't hold names in the player's language.
The rule keeps the id and the editor shows the name next to it: `zone:1453` is shown as
**zone: Stormwind City**. Where the game has no id, the value is the client's English-free key
(class file names, interaction enum names). Only `subzone` stays text (the game gives no
subzone id to addons): its tooltip says it matches the language it was written in.

### The axes
| Axis | Value | True when | Read from | Client | Cost |
|---|---|---|---|---|---|
| `zone` | uiMapID | you're on that map **or one inside it** (a zone matches its towns; a continent its zones) | C_Map.GetBestMapForUnit + parent walk [F] | both | ZONE_CHANGED*, cached parent chain |
| `subzone` | text | GetSubZoneText() matches | [F] | both | ZONE_CHANGED |
| `instance` | instanceID | you're in that instance (a dungeon, raid, BG, delve) | GetInstanceInfo 8th return [F] | both | on zone change |
| `window` | interaction name (`merchant`, `banker`, `trainer`, `auctioneer`, `mailinfo`, `gossip`, `questgiver`, `taxinode`...) | that NPC or service window is open | PLAYER_INTERACTION_MANAGER_FRAME_SHOW/HIDE + IsInteractingWithNpcOfType [F] | both | events only |
| `aura` | spellID | you have that buff or debuff | C_UnitAuras.GetPlayerAuraBySpellID [F] | both | UNIT_AURA player, only ids named in rules |
| `form` | spellID of the form | you're in that form (cat, bear, ghost wolf, shadowform...) | GetShapeshiftFormInfo [?] | both | UPDATE_SHAPESHIFT_FORM |
| `mount` | mountID | you're on that mount | aura scan + C_MountJournal.GetMountFromSpell [F] | both? check Forever's journal | UNIT_AURA, only while mounted |
| `class` | class file (`mage`) | your class | UnitClass | both | once |
| `spec` | specID | your spec | C_SpecializationInfo [F] | both (Forever: check it has specs) | spec change event |
| `race` | race file (`nightelf`) | your race | UnitRace | both | once |
| `camera` | camera key (`flight`, `idle`, `chatcam`, `script`) | that Cinematic camera is running | ns.activeCam | ours | none |
| `targetid` | NPC id | your target is that NPC (GUID's npc id) | UnitGUID | both; secret in instances | target change |

Old words that fold into an axis stay as aliases, out of the editor: `mage` = `class:mage`,
`cam_flight` = `camera:flight`, `tank` stays a plain word (a role is one of three).

### Known limits (to state in the tooltips, and prove in the test)
- **aura in fights on Forever:** C_UnitAuras errors there (memory forever-fight-aura-apis);
  GetPlayerAuraBySpellID says `RequiresNonSecretAura`. So `aura:` is read out of fights only on
  Forever unless the run proves otherwise; it holds its last value through the fight. Retail:
  check SecretWhenUnitAuraRestricted the same way.
- **targetid in instances:** the GUID is secret, so it reads false there (as hover does).
- **zone ids differ per client** for the same place (Forever vs retail maps): fine, a rule
  written on one reads false on the other, and the editor's gray mark says why.

### Code
- Tokens(): after a word, a `:` takes a value (`[%w_,]+` or a quoted string).
- `ns.RULE_AXES = { zone = {...}, aura = {...} }`: each axis has `read(facts, values)`, its
  events, a `Name(id)` for the editor and a `Pick()` list. CompileRule makes
  `function(f) return f.axis.zone[1453] end` style tests, and adds each named id to the axis's
  `wanted` set, so `aura` only looks up the spells some rule names and `zone` walks parents only
  while a zone rule exists (the hover gating, per axis).
- `facts.axis[name]` holds a set (`zone`: the map and every parent; `aura`: the wanted ids you
  have), filled on the axis's events, not each tick.
- Lives in its own file (Rules/RuleAxes.lua or next to Frames.lua's rules) because of the
  200-local and 60-upvalue limits.

### Editor
- A **Values** line under Location: one button per axis (Zone, Instance, Window, Aura, Form,
  Mount, Spec, Class). Each opens a picker:
  - **Zone, Instance, Subzone:** "Here" first (fills where you stand now), then a search box.
  - **Aura:** your buffs right now as icons, then a spell id or name box.
  - **Window:** the list of interaction kinds, with "open now" marked.
  - **Form, Mount, Spec, Class, Race:** this character's own list first.
- Shown values: the name, colored by the axis's line; red if the axis is unknown, gray if the
  value is unknown on this client.
- The editor's lit dots work as for words: `zone:1453` lights while you're in Stormwind.

### Tests
- Offline (`Tools/offline/`): tokenizer cases (`zone:1,2`, quotes, bad colons, `aura:` with
  nothing after it), compile to the same answer as the or-joined form, aliases
  (`mage` = `class:mage`), unknown values false, and the wanted-sets fill only from rules.
- One kit test, extending `Dev/RuleWordsTest.lua`: it reads `zone:<here>`, `subzone:<here>`,
  `instance` (false in the world), `class`/`race`/`spec` of the character, `aura` with a buff it
  finds on you, `form`/`mount` if the character has one, and opens a mailbox-free window it can
  (the map isn't a window, so `window:` needs one real action: talk to any vendor). At most that
  one action, then a fight check that `aura:` holds through combat on Forever.
- Share.lua: a CINE1 string with value words round-trips, and an older version reading it skips
  only those rules (unknown settings skipped, as today).

## Decisions for you

1. **`friendly`**: DECIDED 2026-11-25: it keeps its meaning, "can't attack" (dead included).
   `hostile` and `neutral` are added next to it as the game's reaction. No migration.
2. **Value words**: DECIDED 2026-11-25: yes, phase 4 (designed above).
3. **Focus words**: DECIDED 2026-11-25: now. Phase 1 adds the focus unit, phase 3 its extra
   properties with the target's and mouse's.
4. **Anything missing** from the map you've wanted in a rule.
