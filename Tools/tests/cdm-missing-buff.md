# CDM Missing buff mode: test ledger
Goal: a tracked buff set to Missing shows its icon only while the buff is off you (a reminder); groups of alternatives (Demon Skin or Demon Armor) count as one.
Code: UI/CooldownMissing.lua (new), Frames.lua (ns.CooldownBuffShows, ReadyTarget, UpdateReadyOnly), UI/CooldownGrid.lua (BUFF_MODES), Dev/CdmGridTest.lua (steps missing, missingfight)

## Questions
| # | Question | Client | Answer | From |
|---|----------|--------|--------|------|
| Q1 | Does a tracked buff icon keep its slot while the game hides it (Hide When Inactive)? | both | YES: CooldownViewerBuffIconItemTemplate has includeAsLayoutChildWhenHidden; hidden items are laid out | Blizzard_CooldownViewer/CooldownViewer.xml:162, LayoutFrame.lua:38 |
| Q2 | What hides an inactive buff icon? | both | item:UpdateShownState -> SetShown(ShouldBeShown()); hidden when hideWhenInactive and not IsActive and settings window shut | CooldownViewer.lua:288-317 |
| Q3 | Does the item run Blizzard code when shown (OnShow)? | forever | NO: base item template has OnLoad/OnEnter/OnLeave only | CooldownViewer.xml:1-10 |
| Q4 | Buff on/off readable in fights? | forever | YES: type(icon.auraInstanceID) ~= "nil" | rule forever.cooldownviewer.aurainstanceid-type |
| Q5 | Our Show() after the game's SetShown(false) (hooksecurefunc on the item) brings the icon back and keeps it there out of a fight? | forever | YES: shown, 8 of 8 looks over 4 s, Hide() puts it back; not protected out of fights; no errors | run 1, rule forever.cooldownviewer.show-hidden-buff-icon |
| Q6 | Same in a fight: icon protected? Show() blocked? "secret while tainted" errors? on/off still read? | forever | YES works: shown 38/38 looks over 22 s, 0 refused, 0 errors/blocked, console clean | run 3, rule forever.cooldownviewer.show-hidden-buff-icon |
| Q7 | Stand-in (our own texture at the hidden icon's slot, way A2): icon texture readable, slot readable, looks right? | forever | YES: texture and center plain while hidden; stand-in drawn exactly on the slot (shot) | runs 1-2 |
| Q8 | What does an inactive icon look like once shown (desaturated, swipe)? | forever | full color, not desaturated (desat=false, shot) | run 1 |
| Q10 | A buff on you set Missing fades? | forever | YES: 17 of 17 looks faded in a fight once Demon Skin was cast | run 4 |
| Q11 | Does a tracked buff icon light up for the same buff cast by someone else? | both | NO: NeedsAddedAuraUpdate returns false unless auraInfo.sourceUnit == "player"; Missing on the icon alone would nag while another priest's Fortitude is on you | CooldownViewer.lua:395-397 |
| Q12 | Does a tracked Power Word: Fortitude (or a Blessing) icon light for Prayer of Fortitude / the Greater Blessing? | forever | open: needs a priest or paladin | later probe |
| Q13 | Out of fights, can we read any-source buffs on you (C_UnitAuras.GetAuraDataByIndex, name + sourceUnit plain)? | forever | YES: name, spellId, sourceUnit plain; pet's = "pet", outsiders' = nil; isFromPlayerOrPlayerPet unreliable | run 3, rule forever.auras.player-helpful-out-of-combat |
| Q14 | Groups: any one / each / none on, the group's row, Ungroup | forever | YES: any one with Blood Pact (imp's) on = no reminder; each = Skin shown; none on = Skin's icon; row 'or Demon Armor'; Ungroup splits back. The 8 px spill was the test's (Layout without Changed: no panel refit) | run 4 |
| Q15 | Ready-made alternatives: names on Forever; the hint fits? | forever | YES: all sets resolve except Blessing of Salvation/Sanctuary/Light and their Greater (not on Forever), Fel Armor, Molten Armor, Water Shield (later expansions); dropped by design. Hint 'or Demon Armor' fits | run 6 |
| Q9 | Same on retail | retail | open, not asked yet | later |
| Q17 | Can a player track a DoT (Corruption, Bane of Agony) in Tracked Buffs / Bars on Forever? | forever | YES: Tracked Buffs has Corruption, Bane of Agony, Immolate, Bane of Doom (Tracked Bars: none) | run 7 |
| Q18 | Does a tracked DoT icon follow your DoT on the target (auraInstanceID set, auraDataUnit "target"), in a fight? | forever | YES: auraDataUnit "target" 50 looks in a fight, cleared on each of 3 target changes; way B (our own target debuff read) errors in fights | run 7, rule forever.cooldownviewer.tracked-dot-follows-target |
| Q19 | Missing on a DoT: shown while the target hasn't got it, faded while it has, back on a new target? | forever | YES: shown before, faded 48/48 on the target, shown 4/4 off it, back after a target change, 0 refused, 0 errors | run 7 |
| Q20 | Missing on a spell (2026-11-25, the user: "why not add an option to essential or utility spells"): does an Essential/Utility DoT icon hold your DoT on the target in a fight (auraInstanceID, auraDataUnit "target")? | forever | game code says yes (CooldownViewer.lua:854-900 CheckCacheCooldownValuesFromAura, :483 target registration; Frames.lua ShowsBuff already reads it for "Shows"); offline yes | YES: 42 looks on from the target, faded 40/40, shown 45/45, back after a target change, 0 errors | run 8 (q2743) |
| Q21 | The game's info for an Essential DoT: hasAura / selfAura plain and right on Forever? | forever | YES: Agony, Corruption, Immolate hasAura=true selfAura=false; Will to Survive, Healthstone false/false; Perception false/true (no Missing there) | run 8 |
| Q22 | Missing's pill mark: the procs bolt read the same as When it procs (run 8's shot) | both | built: its own broken ring (slot 8 of a 16-slot CdmIcons strip); lab audit clean; in game: run 9 | run 9 |
| Q16 | Retail in fights: a Missing buff's icon Show() (now refused in fights on retail till Q9 proves it; card 2026-11-23-cdm-secret-compares.md) | retail | open | later |

## Plan tree (step 3)
Q5+Q6 yes, no errors -> way A is the build; next: groups (pure logic + menu, offline), confirm run.
Q5 yes, Q6 blocked/protected in fights -> show only out of fights + stand-in (A2) in fights; A2 probed in the same run (Q7).
Q5 no (game re-hides every frame / icon has no texture) -> A2 stand-in everywhere (Q7 answers it).
Any taint error -> A2 (touches no game frame) or way B (ask for Hide When Inactive off).
Any caster (user, 2026-11-23): on/off = the icon, or our read of your buffs by name out of fights (anyone's); in fights another's buff read before still counts, yours go by the icon. Q13 yes -> keep; names don't match (aura name != spell name) -> match linkedSpellIDs/spellId too.
Next after run 3: groups with Missing: any one / Missing: each per scene (paladin solo vs raid), built-in alternative sets; Q12 needs a priest or paladin.

## Runs
| Run | Date | Command | Answered | Still open, and why this run couldn't |
|-----|------|---------|----------|---------------------------------------|
| 1 | 2026-11-23 | /cine debug cdmgrid (steps missing, missingfight; the rest proven) | Q5, Q7 part, Q8 | Q6 and Q10: the test's fault (stale on/off pick; GetCenter read through Plain kept one value, Lua error stopped the run). Fixed |
| 2 | 2026-11-23 | /cine debug cdmgrid | Q7; step missing proven | Q6: the fight loop asked InCombatLockdown right at PLAYER_REGEN_DISABLED (still false), 0 looks. Q10: buff off the whole run. Fixed: loop on lockdown or UnitAffectingCombat after 0.3 s; fade checked in the fight (cast it there) |
| 3 | 2026-11-23 | /cine debug cdmgrid (missingfight only, + any-caster read probes) | Q6, Q13 | Q10: the step asked for the buff off before checking it on (test's fault, fixed: fade checked first). Next run = groups build + this; 4 runs total, over the 3 target because of test bugs in runs 1-2 |
| 4 | 2026-11-23 | /cine debug cdmgrid (missinggroup, missingfight) | Q10, Q14; missingfight proven, group logic proven | Ungroup overlap: the test ticked with Layout (no panel refit); fixed to Changed as a click does. Re-checked in the full run |
| 5 | 2026-11-23 | cdmgrid full via the test queue (q9afb; the end run: every step) | steps 1-12 PASS (shaman, Stormwind) | 13-16: the shaman had no tracked buff; the test asked to right-click one off and waited till a /reload (test's fault: now skips with none) |
| 6 | 2026-11-23 | cdmgrid 13 14 15 16 full via the queue (qc31f), on the warlock | everything: Missing, groups, alternatives, fight 14/14 faded + 4/4 shown, 0 errors/blocked | 1 FAIL the test's: after Ungroup the row (still Missing) shows its ready-made hint, the check wanted no line. Fixed. All steps proven; nothing open on Forever (retail Q9 not asked) |
| 7 | 2026-11-25 | cdmgrid 17 via the queue (q25f7), warlock, Elwynn | Q17, Q18, Q19; step missingdot proven | nothing on Forever (retail Q9 not asked) |
| 9 | 2026-11-25 | cdmgrid 18 (qf947), page only | Q22: the shot shows the broken ring on Missing, apart from the procs bolt | 1 false FAIL, the test's: GetTexCoord's 2nd value is UL y, not the right edge (fixed: 5th). The mark check stays unproven till a PASS |
| 8 | 2026-11-25 | cdmgrid 18 via the queue (q2743), warlock, Elwynn | Q20, Q21: Missing on spells works in fights; fight part proven | Q22: the shot showed Missing with the procs bolt (a look issue, not a game fact). Fixed; run 9 = the page alone, hands off |

Run 7 plan (2026-11-25, Discord DoT ask): step 17 missingdot. Q18 yes + Q19 yes -> nothing to build, reply "already there" (+ tooltip words). Q18 no (icon never lights from the target) -> read the target's debuff ourselves: out of fights by name (C_UnitAuras HARMFUL|PLAYER on target), in fights the target's aura reads are secret (rule forever.unit_aura.addedauras-secret): likely (c) part of it. Q17 no -> (d) for Forever's catalog, say so.

Run 8 plan (2026-11-25): Missing on spells built (db.cooldownMissingOnly, Frames.lua ReadyTarget "missing", grid choice on aura spells only, tip). Step 18 missingspell. Q20 yes -> done, reply points at the Essential row. Q20 no (icon never holds the target aura in fights) -> spell Missing can't work in fights: take it off spells, the reply points at Tracked Buffs (step 17 proven). Q21 no -> keep the DoT list fallback, log which spells it missed.

## Not in run 1 (no game facts needed)
- Groups: built (mockup B, Select rows > Count as one buff; Ungroup in the same bar). Ready-made sets built as alternatives Missing counts (UI/CooldownMissing.lua ALTERNATIVES), shown under a Missing row.
- Missing's own icon in Textures/CdmIcons (uses the procs spark for now).
- Another addon running the Cooldown Manager (ns.FeatureYieldedTo / Support rows): Missing should stand down; check with addon-support later.
