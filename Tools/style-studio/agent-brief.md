# Style Studio build: brief for each page agent (2026-11-25)

You are converting some of Cinematic's Style settings pages (a WoW addon, Lua; you work for its author) onto the
new **Style Studio** editor. The plan is `Tools/style-studio/plan.md`. Read it first, especially sections 3-8 and
section 10. The user answered **"Yes, recommended"** to every decision in section 10.

## The framework (done; don't edit these files)
- `Style/Studio/Editor.lua`: the model. `ns.StyleFrame(id, spec)` registers a frame. Its header documents
  every spec and property field. It also holds sources, history, Reset scopes, Find and Status.
- `Style/Studio/Recipes.lua`: `ns.Studio.R.*` property makers. **Use these** so every page has the same words,
  choices and control: `R.Font`, `R.Texture`, `R.Outline`, `R.Shadow`, `R.Border` (returns 3 props: put it last
  in `R.Group`), `R.Choice`, `R.Drop`, `R.Slider` (min/max/step **as shown**, `opts.scale` = shown/saved, as the
  old `rows.Slider`), `R.Switch`, `R.Color` (mode key + rgb keys + custom value), `R.Swatch`, `R.Button`, `R.Note`,
  `R.Shown(rowKey)` (a part's Shown: the old Overrides `styleOver_<rowKey>`), `R.Group(recipe, ...)`.
- `Style/Studio/Controls.lua` and `Style/Studio/Studio.lua`: the controls and the two hosts.
  `ns.StyleEditorPage(kit, content, stack, frameId, { preview = <the page's preview>, canvas = canvas,
  variant = <optional> })` puts the editor on a page. `ns.OpenStyleStudio(frameId, variant, partId)` opens the
  window.
- **Reference conversion:** `Style/Studio/Frames/Tooltips.lua` plus `Style/TooltipStyle.lua`
  (`ns.CreateTooltipStylePanel`). Copy that pattern:
  - keep the page's tabs, title, intro, `kit.PageSwitch` and preview;
  - replace every look control (`rows.*`, `rows.Look`, hand-built widgets) with ONE `ns.StyleEditorPage(...)`;
  - write the spec in your Frames file;
  - give the preview fields so parts can be clicked (`holder.unitTip = unit`; a part's `region = function(p)
    return p.unitTip end`).
- If you truly need something the core lacks, add it as a helper in YOUR Frames file. If the core itself must
  change, don't edit it: describe the change exactly in your final report.

## The rules (the user's standing rules; breaking them gets work thrown away)
1. **Saved settings keep their keys and meanings.** Never rename a db key. A spec property points at the same key
   the old control wrote. Where a value must show differently (a 0-1 value shown as %), use `scale`. Field
   tables `{ get, set }` are fine where the old page used one (`KeyGet`/`KeyPut` in Options.lua).
2. **Every look setting the page had must be in the spec.** No setting may be lost. Before deleting old code,
   list every key it wrote; after, grep your spec for each one. Put behavior settings (when something shows,
   sounds, positions) **only where your scope below says**.
3. **Grammar:** 2-5 words → `R.Choice`; looks judged by eye → tiles (`R.Font`/`R.Texture`/tiles with
   `texture`/`font`); long lists → `R.Drop`; amounts → `R.Slider` with a unit; colors → `R.Color`/`R.Swatch`;
   actions → `R.Button`.
   - Group recipes, in `Studio.RECIPES` order: Look, Text, Bar, Icon, Border, Background, Place, Motion, Sound.
   - Words: "Background" (never "Dark ground" / "Behind the bar"), "Custom" (never "Your own"), "Test" (never
     "Play"), "Size" (never "Text size" / "Thickness"), "The game's", "Follow main theme".
   - Outline is always None/Thin/Thick (`R.Outline`, `opts.values` when a page saves words instead of 0/1/2).
   - Shadow is always The game's/On/None (`R.Shadow`, `opts.on`/`opts.none` for other saved words).
   - Labels have no trailing colon and use sentence case.
4. **Tooltips: one short plain sentence** (keep the old pages' good tips). American English.
5. **Hide what can never be used on this client** (`client = "retail"|"forever"`, or `shown`). Grey (`test`) only
   when another setting can turn it on.
6. **Variants:** a page with rows (Default, Player, Target...) becomes `variants = { { id, label } ... }` with
   `key = function(variant) ... end`. The first variant is the one the others follow. `inherit` is the saved
   value that means "follows the first" (e.g. "default"), if the page has one.
7. **Edit files with the Edit/Write tools only.** No `sed -i`, no python or perl rewriting files, no `git stash`,
   `checkout`, `reset` or `commit`. Other sessions are editing this checkout at the same time, so change only the
   hunks you need. If an Edit fails because the file changed, Read it again and redo the Edit.
8. **No locale files** (`Locales/*`). New text goes in as `L["English"]` keys.
9. Don't open the game's Settings in any test. Don't start servers.

## Checks you must run before reporting
- `~/bin/luacheck <every file you touched>`: clean (no new warnings).
- `python -I Tools/offline/run.py Tools/offline/stylestudio.lua forever <frameId> < /dev/null` and the same with
  `retail`, for each of your frame ids: 0 FAIL. It checks the specs (keys, recipes, words, defaults are among the
  choices), the model, the Studio on every variant and part, and that your page called `ns.StyleEditorPage`.
- Run the existing offline tests that cover your pages: grep `Tools/offline/*.lua` for your page ids, keys and
  `Create...Panel` names, and run each with `run.py`. A test that now fails because its expectation changed:
  **don't change the expectation.** Report it with the old and new values. The user OKs changed expectations,
  per the audit-kit rule. A test that reached into removed widgets (old `rows.Look` internals) may be pointed at
  the editor (`ns.Studio`, the frame spec) instead. Say which.

## Your report (final message, under ~400 words)
- Files changed; frame ids registered; the variants and parts of each.
- Every old key → the spec (a count is fine, plus any key deliberately left off the editor and why).
- Each fix from your list: done, or not and why.
- Moves done (decision 2).
- Check results (pass/fail counts) and any test whose expectation changed.
- Anything you need from the core.
