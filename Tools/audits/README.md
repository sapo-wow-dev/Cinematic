# Fix cards

One card per audit fix (or per behavior fix from a release review or a player case), written before the fix lands:
what it changes for players, who relies on the old behavior, every state the code reads, which cells of its matrix
test may change, the expectations it changes (each with the user's OK), and its risk. The process is the `/audit`
skill (`.claude/skills/audit/SKILL.md`); start from `TEMPLATE.md`.

`Tools/audit.py` reads the cards: `Base:` (the code before the fix), `Test:` lines (matrix tests,
`Tools/offline/matrix.lua`) and the **Meant to change** table. `audit.py card <card>` checks one;
the pre-commit hook checks a staged one against HEAD; `Tools/prerelease.py` checks all of them against the last
tag, so a later change that flips a pinned cell fails there.

- `2026-11-23-zone-card-gap.md`: the game's zone line under a Zone card still up (e202b4a); matrix
  `Tools/offline/zonecardmatrix.lua`.
- `2026-11-23-zone-card-subzone.md`: a subzone's game line over a Zone card still up, Subzone row off (found by
  that matrix); same matrix.
