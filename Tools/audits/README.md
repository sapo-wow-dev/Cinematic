# Fix cards

One card per audit fix (or per behavior fix from a release review or a player case), written before the fix lands:
what it changes for players, who relies on the old behavior, every state the code reads, which cells of its matrix
test may change, the expectations it changes (each with the user's OK), and its risk. The process is the `/audit`
skill (`.claude/skills/audit/SKILL.md`); start from `TEMPLATE.md`.

`Tools/audit.py` reads the cards: `Base:` (the code before the fix), `Test:` lines (matrix tests,
`Tools/offline/matrix.lua`) and the **Meant to change** table. `audit.py card <card>` checks one;
the pre-commit hook checks a staged one against HEAD; `Tools/prerelease.py` checks all of them against the last
tag, so a later change that flips a pinned cell fails there.

Each card's title line says what it covers (no list here: it went stale as cards were added). The 2026-11-22
and the ae2cda8 2026-11-23 cards were written after the fact for the three code audits (7c3e0c1, bdb2e1d,
ae2cda8), `Base:` the code before each; a card's **Open** section lists the cells pinned on a best reading that
are the user's call.
