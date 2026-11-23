# Style: the Personal Resource Display's power fill after a form change (fix card)
Fix: the game's power fill was kept as first seen, so a druid who shifted (caster to Bear) and then set the texture back to the game's, or switched the page off, got the old form's art on the new power; and a new fill after a shift into mana wasn't greyed under our mana color.
Found by: audit 2026-11-22 (landed in 7c3e0c1; this card written after, retroactively)
Code: Style/PersonalStyle.lua: Apply() (the power bar's SetStatusBarTexture hook), DressBar() (putting the game's fill back)
Clients: both
Base: 7c3e0c1^

## Before / after
- Before: a druid with a texture of ours on the Personal Resource Display shifts into Bear, then picks the game's
  texture again (or turns the page off): the rage bar shows the blue mana art. Back in caster form with our mana
  color and the game's art, the mana bar isn't greyed, so our color sits tinted on blue art.
- After: the game's art for the power you have now comes back; a new mana fill is greyed under our mana color.

## Who relies on the old behavior
(`python -I Tools/audit.py refs RefreshPersonalStyle prdTexture prdManaColor`, read every hit.)
- Players: anyone with Style > Personal Resource Display on and a texture or mana color of theirs (or General's:
  prdTexture defaults to "general"); only shapeshifters (druids) and anything else whose power bar art changes.
- Other features: General Style's refresh list (GeneralStyle.lua), our own mana bar (PersonalMana.lua, reads
  prdTexture/prdManaColor, not this hook), /cine debug prdtextures and themecheck read the fill.
- Other addons: none (no Support/ hits).
- Tests that encode it: Tools/offline/prdformfill.lua (the bug's states only: 4 checks), Dev/GradientTest.lua calls
  the refresh. No ledger, rule or other card.

## States (the matrix)
Style (General) switch x the page switch (page on / off / Style off), texture ours / the game's, mana color ours /
the game's, the start power (caster: mana, Bear: rage), a form change or none, then the page kept, its texture set
back to the game's, or the page switched off; per client. 144 cells.
Test: Tools/offline/prdfillmatrix.lua forever
Test: Tools/offline/prdfillmatrix.lua retail

## Meant to change
| Matrix | Cell | Before | After |
|--------|------|--------|-------|
| prd-power-fill | page=on texture=ours start=caster shift=yes after=pageOff | fill=mana grey=n color=rage | fill=rage grey=n color=rage |
| prd-power-fill | page=on texture=ours start=caster shift=yes after=textureGame | fill=mana grey=n color=rage | fill=rage grey=n color=rage |
| prd-power-fill | page=on texture=ours manaColor=game start=bear shift=yes after=pageOff | fill=rage grey=n color=mana | fill=mana grey=n color=mana |
| prd-power-fill | page=on texture=ours manaColor=game start=bear shift=yes after=textureGame | fill=rage grey=n color=mana | fill=mana grey=n color=mana |
| prd-power-fill | page=on texture=ours manaColor=ours start=bear shift=yes after=pageOff | fill=rage grey=n color=ours | fill=mana grey=n color=ours |
| prd-power-fill | page=on texture=ours manaColor=ours start=bear shift=yes after=textureGame | fill=rage grey=y color=ours | fill=mana grey=y color=ours |
| prd-power-fill | page=on texture=game manaColor=ours start=bear shift=yes after=keep | fill=mana grey=n color=ours | fill=mana grey=y color=ours |

## Found next to it
2 cells FAIL on 7c3e0c1^, 7c3e0c1 and the current code alike (not this fix's doing): **start in Bear with our
mana color, shift to caster (our color goes on), then switch the page off**: the mana bar keeps OUR color
(`fill=mana grey=n color=ours`, pinned `color=mana`), both textures. The power bar's SetStatusBarColor hook paints
our color without marking the bar as colored (`colored[bar]`), so DressBar has nothing to put back; it stays ours
till the game sets the color again (the next form change). Not fixed here (report only).

## Open (the user's call)
- None of the pins above is in doubt for this fix. The one modeling choice: the stand-in bar drops its grey when
  the game sets a new fill (as prdformfill.lua's); whether the real game keeps a texture's desaturation across
  SetStatusBarTexture decides the "rage after our mana color" cells in game.

## Expectations changed
| File | Check | Was | Now | OK'd |
|------|-------|-----|-----|------|
| none (retroactive card) | | | | |

## Risk
low: one hook and the put-back; 135 of 144 cells unchanged on both clients, the 9 changed all declared. Not proven
offline: the real game's form-change order (art, then color), and whether desaturation survives a new fill.
