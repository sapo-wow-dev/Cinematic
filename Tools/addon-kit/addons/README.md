# How each addon works

One file per supported addon, `<Addon>.md` (its folder name), written by
/addon-support (Phase 1 step 3) so nobody has to learn the addon twice. Each
fact has its file:line in the addon, and `(proven <run>)` once a game run
showed it. Reread and fixed on every /addon-support for that addon: check the
version line first.

Its ready recipe (`ns.TestKit.DefineAddonReady`, in `Dev/<Addon>SupportTest.lua`)
is built from the "Set up for a test" part: what code can do goes in `make`,
the rest in `guide`.

```
# <Addon>

Version read: <version> (<clients>), <date>

## What it is
One line on what it's for, then each part a player sees: one line each.

## How a player starts it
First login (installer, welcome, profile pick, and the saved flag that says
it's done), its slash commands, its minimap button, where its options are.

## What each part needs before it shows
- <frame or part>: <content / option / state it waits for> (file:line)

## Set up for a test
- by code: <global call or saved value> -> <what it gets> (file:line)
- by hand: <one click per line, names as on screen>
- out of reach: <calls inside its private table, states code can't make>

## Surprises
What it does by itself that a test can trip on (hides one part with another,
its own fades, resets on reload).
```
