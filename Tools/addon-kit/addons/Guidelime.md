# Guidelime

Version read: the _forever_ copy installed 2026-11-25 (code read, not yet proven by a run of the recipe)

## What it is
A leveling guide: a list of steps to follow, with an arrow toward the next place.
- Guide window: the current guide's steps. It has no name of its own; we find it by its fields (`ns.IsGuidelimeWindow`, Support/Guidelime.lua).
- Ongoing window (`GuidelimeOngoingWindow`): the steps still in progress.
- Arrow (`GuidelimeArrow`): points to the place the current step goes to.
- Target and quest item buttons (`GuidelimeTargetButton<n>`, `GuidelimeUseItemButton<n>`): on the guide window, only on steps that have them (ActionButtons.lua).
- Map and minimap markers.

## How a player starts it
- No installer. `/lime` or `/guidelime` with nothing after it opens or closes the guide window (Guidelime.lua:15, `Guidelime.toggleMainFrame`).
- A fresh character has no guide: its guide window says "Click here in order to start by loading a guide", which opens the guide list.
- Its options: Interface > AddOns > Guidelime, and its minimap button.

## What each part needs before it shows
- Guide window: `GuidelimeDataChar.mainFrameShowing` true (on by default, Guidelime.lua:155).
- Arrow: a guide loaded with a current step that goes to a place, `showArrow` on (on by default, Guidelime.lua:167). It hides when the guide window closes, so the guide must fade, never close (the 2026-11-25 player wish, Dev/GuidelimeSupportTest.lua).
- Target / quest item buttons: a current step with a target or a usable quest item.

## Set up for a test
- by code: guide window closed -> `Guidelime.toggleMainFrame()` (global, Guidelime.lua:1014). The recipe does this and closes it again after.
- by code: arrow opacity -> `arrow:SetAlpha(x)`, as its slider does; the saved one is `GuidelimeDataChar.arrowAlpha`.
- by hand: no guide loaded -> in the guide window click "Click here in order to start by loading a guide", pick any guide, click Load guide. Saved per character (`GuidelimeDataChar.currentGuide`), so it's once per character.
- by hand: a guide with no step going anywhere -> click a step that says to go to a place.
- out of reach: `G.loadGuide(name)` (Guides.lua:148) is in its private addon table (only put on `Guidelime.addon` with its debugging on), so code can't load a guide.

## Surprises
- Its arrow hides with its guide window (see above).
- `/lime debug true` / `false` and `/lime questie true` / `false` reload the UI (Guidelime.lua:17-22): never send them from a test.
- With Questie's data as its source it needs QuestieDB too: solo keeps it (known error solo-split-companion).
