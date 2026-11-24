# Auction House dressing room: undocked as the AH closes (fix card)
Fix: with "Dressing room beside the Auction House" on, closing the AH could leave the side dressing room docked to
the hidden AH (our AUCTION_HOUSE_CLOSED handler heard before the AH's frame hid itself): it came back with the last
item next time, and the next fight's start ran our Undock (CloseSideDressUpFrame, SetParent) as the fight began.
Found by: release review v2.1.28 (038cdd4)
Code: QoL/AhDressUp.lua: the events frame's OnEvent (AUCTION_HOUSE_CLOSED)
Clients: forever (retail: the file doesn't load)
Base: 4d01a3a

## Before / after
- Before: AUCTION_HOUSE_CLOSED ran Update, which reads AuctionHouseFrame:IsShown(). Heard before the AH hid, it saw
  the AH open and kept the side dressing room docked to it; `docked` stayed true.
- After: AUCTION_HOUSE_CLOSED undocks straight away (when we docked it, or it's docked to the AH), whatever the AH's
  frame says yet. The next fight finds nothing to undock.

## Who relies on the old behavior
(`python -I Tools/audit.py refs AUCTION_HOUSE_CLOSED ahDressUp AhDressUpUndock SideDressUpFrame`, read every hit.)
- Players: those with the row on (off by default, Forever only). Nobody wants it left docked after the AH closes.
- Other features: ns.RefreshAhDressUp (Options.lua row and page switch) still runs Update: unchanged.
  Camera/ShoulderCam.lua listens for AUCTION_HOUSE_CLOSED on its own: untouched.
- Other addons: none (no Support/ hits).
- Tests that encode it: Tools/offline/ahdressup.lua ("closing the AH undocks it", AH hidden first: still passes);
  Dev/AhDressUpTest.lua step "close" (undocked after C_AuctionHouse.CloseAuctionHouse, proven 3/3: the order there
  was benign or the AH hid first; unchanged).

## States (the matrix)
row (on / off) x fight going on as it closes (none / during) x order (AH hidden first / event first), per client.
Test: Tools/offline/ahdressupmatrix.lua forever
Test: Tools/offline/ahdressupmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| ahdressup-close | client=forever row=on fight=none order=eventfirst | closed: atAH=yes ours=docked nextfight=undock | closed: atAH=no ours=undocked nextfight=nothing |

(Changes since v2.1.27 by earlier commits in this release: Tools/audits/2026-11-23-release-v2.1.28-since-tag.md.)

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: one event branch, only with the row on (off by default, Forever only); 8 cells per client pinned, the other 7
unchanged on Forever, all 8 on retail. Not proven offline: which order the game really fires AUCTION_HOUSE_CLOSED
and the AH's hide in (walking away, the server closing it); the fix is right either way.
