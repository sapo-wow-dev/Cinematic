# Heal Vision: keep auras shown

Ask (user, 2026-11-23): hiding a healthy member's frame is great, hiding their debuff or cleansable debuff is bad.
Keep those shown, or lay a 1:1 copy over them at 100%.

## Known before any run

- A copy can't work in fights: every C_UnitAuras read on a group member errors there, both clients
  (forever.auras.fight-apis-error, forever.c_secrets.shouldaurasbesecret).
- Raid frames' aura icons and DispelOverlay are forbidden or drawn by the game (forever.dispeloverlay.forbidden,
  forever.compactpartyframe.no-aura-icons): they can't be faded or read on their own, but they keep their
  parent's alpha.
- Today raid-style members are faded whole (the frame's own alpha), so the icons go with them.

## Idea

`healVisionKeepAuras` (Visions/HealVisionFrames.lua KeepAuras): raid-style members faded by their parts like the
plain party frames. Parts we reach (background, health bar, name...) fade; the icons and glow keep the frame's 1.
Reachable aura fields (debuffFrames, dispelDebuffFrames, buffFrames, DispelOverlay, CenterDefensiveBuff,
PrivateAuraAnchors) are never made parts. The game's range dimming stays on the frame (nothing reasserts it).
Cost: buffs stay too (no telling them apart).

## Questions for run 1 (`/cine debug healauras`)

1. Do the icons and dispel glow stay at full on a hidden member? (shot, step 3 vs step 2)
2. Which children/regions are reached, which forbidden, per client? (step 3 lines)
3. Does anything look left behind (a border, a highlight) on a hidden member? (shot)
4. Does it hold in a fight, with secret alpha? (step 4: whole 0, shots)
5. Does the game's range dimming still show on the frame? (frameAlpha per member)

## Runs

### Run 1, retail 12.1.5, Windrunner Spire follower dungeon, 2026-11-23 (4 pass, 1 fail)

Log: Tools/tests/logs/2026-11-23-retail-healAurasTestLog-a007be0f.txt.

1. YES on retail: in the fight, the player's frame (full health) was hidden, no bar or name, and still showed its
   debuff icon and the dispel glow (blue dashed border + wash) at full (WoWScrnShot_112326_061743). Rule
   retail.compactunitframe.auras-keep-frame-alpha.
2. Retail: no debuffFrames / buffFrames / dispelDebuffFrames fields at all; DispelOverlay forbidden; 18 regions +
   6 children reached; SelectionHighlight and ReadyCheckIcon ignore parent alpha (left alone).
3. Nothing left behind on hidden members out of combat (061712); in the fight only the icons and glow.
4. Holds in a fight: 0 of 14 faded whole.
5. The FAIL was the test: member frames' own alpha reads secret (the game's range dimming), counted as ours.
   Fixed: secret counts as the game's. Rule retail.compactunitframe.alpha-secret-out-of-combat.

Open: buffs (3-8 per member out of combat) didn't show on hidden members, but no shot shows whether the game draws
them at all; step 1 now takes a shot with Heal Vision off first. Forever not run yet (the main client).

### After run 1 (2026-11-23, the user's call)

Made a tick on both clients, off to start with: Heal Vision > Unit Frames > Debuffs: Show while hidden
(healVisionKeepAuras, a role tab setting like Ready check). Forever not run: hard to find a group there; the user
tests it when they can. Step 3 now finds the tick on the page, checks it overlaps nothing, shoots it and clicks it on.

### Run 2, retail 12.1.5, Windrunner Spire, 2026-11-23 (8 pass, 0 fail)

Log: Tools/tests/logs/2026-11-23-retail-healAurasTestLog-4e73fff7.txt.

- Buffs closed: with Heal Vision off (062827) the game draws no buff icons on these frames at all (its own
  filter), so none missing on hidden members is the game's, not ours.
- The page: the tick found, unticked to start, overlaps nothing, its click ticks it. But the shot (062835) showed
  the page's top: the Debuffs row sits below Dead, out of sight. Fixed: the test scrolls to it before the shot.
- The user's own shot in a fight: a hidden member above Captain Garrick showed only its debuff icon at full, no
  frame. The feature as meant.
- Fight: 0 of 14 faded whole, no errors.

Left: the tick's look on the page (next run's shot), Forever (the user, when they find a group).
