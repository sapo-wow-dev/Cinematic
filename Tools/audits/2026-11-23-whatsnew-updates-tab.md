# What's new line: the Chat page's Updates tab switch (fix card)
Fix: with the Chat page's Updates tab switched off, the "What's new" line still came at login after an update.
Found by: lazytabsmatrix (retro state tests of 7c3e0c1), 2026-11-23; older than the audit
Code: WhatsNew.lua: the login notice (read db.updateNotice and db.handleChat straight, not the switch tree)
Clients: both
Base: 2deb1a9

## Before / after
- Before: Chat page on, its Updates tab off: after an update with new features, the "What's new" line still showed
  in chat at login (only the Get notified of updates box itself, or the whole Chat page off, stopped it).
- After: the tab off stops it too, as every tab's switch does (and the Interface hub above the page, as before).

## Who relies on the old behavior
- Players: anyone who switched the Updates tab off (default on) but not its box; they now stop getting the line,
  which is what the switch says.
- Other features: none read the notice. The What's new page itself and its link are untouched.
- Tests that encode it: lazytabsmatrix (pins already said off); lazytabs.lua checks the Nameplates and
  Graphics+ tabs only.

## States (the matrix)
lazytabsmatrix: page made yet or not x page (Nameplates, Graphics+, Chat) x page switch x tab switch x saved or flipped.
Test: Tools/offline/lazytabsmatrix.lua forever
Test: Tools/offline/lazytabsmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| lazytabs-switch | page=chat pageSwitch=on tab=off | on | off |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none (the matrix's pins already said off; the user, 2026-11-23: "Yes, fix all 6") | | | | |

## Risk
low: one condition at login, through ns.PageSetting (the switch tree without CineMode's Allow, as the notice
comes out of CineMode). Not proven in game: the line itself after a real update (needs a version with new features).
