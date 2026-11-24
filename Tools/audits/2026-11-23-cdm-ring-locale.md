# Cooldown Manager: the drain ring reads a shield's size on every language (fix card)
Fix: the shield size and the charges were read from English description text only; on German, Russian (and part of French/Spanish) clients no shield got a size, so the page hid the Ring and Amount cells for every shield.
Found by: release review 2026-11-23 (v2.1.28; code from f936dd8 / bf2c4cb)
Code: UI/CooldownRing.lua: AbsorbNumber, ChargesNumber (new NearWord, Numbers, English)
Clients: both
Base: 4d01a3a

## Before / after
- Before: on a deDE or ruRU client, Power Word: Shield (and every shield) got no size: no Ring/Amount on the page, no ring. Lightning Shield's Ring came only once more than one charge had been seen. frFR/esES found "absorbe 44" but read "1 234" / "1.234" as 1. English fine.
- After: on a non-English client the number nearest the shield word ("absor", "assorb", "поглощ", "흡수", "吸收") or the charges word ("charge", "aufladung", "carga", "caric", "заряд", "충전", "充能"), before or after it, in the same sentence (40 bytes at most), whole with that language's thousands marks (, . space, no-break, narrow and thin spaces), not a percent. English clients (GetLocale "en..") run the old English patterns alone: identical.

## Who relies on the old behavior
(`python -I Tools/audit.py refs AbsorbNumber ChargesNumber CooldownRingDescriptionSize CooldownRingDescriptionCharges`, read every hit.)
- Players: English clients: unchanged (same code path). Other languages: shields now get a Ring on the page.
- Other features: ns.CooldownRingFits (UI/CooldownGrid.lua Ring/Amount cells), SizeFor, MostCharges, TooltipSize (each tooltip line goes through the same parse).
- Other addons: none.
- Tests that encode it: Tools/offline/cdmring.lua, cdmringsizematrix.lua, cdmringgroupmatrix.lua (all English, unchanged); Dev/CdmRingTest.lua (in game, English client).

## States (the matrix)
The client language (enUS, deDE, frFR, ruRU, esES) and the text: a shield (44), a big shield (1234 with the language's thousands mark), a buff with a number and no shield, Lightning Shield's "3 charges". Fight/tooltip/retry states are the size matrix's (unchanged).
Test: Tools/offline/cdmringlocalematrix.lua forever
Test: Tools/offline/cdmringlocalematrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| cdmring-locale | locale=deDE text=shield | size=none charges=none | size=44 charges=none |
| cdmring-locale | locale=deDE text=big | size=none charges=none | size=1234 charges=none |
| cdmring-locale | locale=deDE text=charges | size=none charges=none | size=none charges=3 |
| cdmring-locale | locale=frFR text=big | size=1 charges=none | size=1234 charges=none |
| cdmring-locale | locale=ruRU text=shield | size=none charges=none | size=44 charges=none |
| cdmring-locale | locale=ruRU text=big | size=none charges=none | size=1234 charges=none |
| cdmring-locale | locale=ruRU text=charges | size=none charges=none | size=none charges=3 |
| cdmring-locale | locale=esES text=big | size=1 charges=none | size=1234 charges=none |
| cdmring-locale | locale=esES text=charges | size=none charges=none | size=none charges=3 |

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none | | | | |

## Risk
low: English clients run the same code as before (gated on GetLocale). Not proven offline: the matrix's texts are close to, not copied from, each client's real descriptions; koKR/zhCN/itIT/ptBR words are in the lists but not in the matrix. A non-English description with the shield word near another number (a duration in the same clause) could give a wrong size; the nearest number wins. No non-English client was tested in game. No non-text source exists (rule forever.absorbs.secret-out-of-combat: the description is the only plain start size; the aura's points were never reached, ledger Tools/tests/cdm-shield-strength.md Q5).
