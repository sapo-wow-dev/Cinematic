# Gamepad Frames: its Show and Settings tabs off now turn off what's on them (fix card)
Fix: with the Show tab off the gamepad bars, button hints and reticle still faded by their rows; with the Settings tab off a button press still brought the bars up
Found by: audit 2026-11-25 (gating, finding C7 in 2026-11-25-gating-findings.md)
Code: Frames.lua: GroupHandled (the gamepad groups), OnPadButton (the press reveal), SyncSwitches
Clients: both (the page shows on Forever only)
Base: baabf86

## Before / after
- Before: right-click the Gamepad Frames page's Show tab off: the gamepad action bars, hints and reticle
  kept fading in CineMode as their rows said. Its Settings tab off: pressing a gamepad button still brought
  the action bars up.
- After: Show tab off, those frames are let go (the game's own alpha, at once: the switches' refresh
  notices the tab now). Settings tab off, a press brings nothing up.

## Who relies on the old behavior
(`python -I Tools/audit.py refs GroupHandled gamepadPressReveal handleGamepad`)
- Players: none want a tab they switched off to keep working.
- Other features: the Hover groups' Gamepad trigger (events.gamepad) comes only from a press: off with it.
  The pad's watch (autorun, held buttons) is unchanged; the held-button keep-up needs a reveal first.
- Other addons: ConsolePort (the pad watch off with its bars hidden): unchanged.
- Tests that encode it: none offline; Dev gamepad tests run with the tabs on.

## States (the matrix)
The page's switch, its Show tab and its Settings tab, each on or off, after the switches' refresh; the
client. (The HUD on.)
Test: Tools/offline/gamepadtabsmatrix.lua forever
Test: Tools/offline/gamepadtabsmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| gamepad-tabs | page=on show=off settings=off | faded=yes press=reveals | faded=no press=nothing |
| gamepad-tabs | page=on show=off settings=on | faded=yes press=reveals | faded=no press=reveals |
| gamepad-tabs | page=on show=on settings=off | faded=yes press=reveals | faded=yes press=nothing |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: true whenever both tabs are on (everyone who never right-clicks them). Not proven offline: the real
GamepadMainActionBarFrame let go on a live tab flip on Forever.
