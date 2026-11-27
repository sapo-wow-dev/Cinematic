-- Cast Bars' Nameplates settings following Default in the Style editor: "edited", the row's x,
-- Reset page, Reset everything, set to Default's value, Undo (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-26-cast-plate-follow.md):
--   python -I Tools/offline/run.py Tools/offline/castplatefollowmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/castplatefollowmatrix.lua forever --base <ref>
-- Each Nameplates setting (CombatBand.lua's PlateField) is the nameplates' own (<key>_PLATE)
-- or, empty, Default's. The states: which setting (a slider: Height; a color: Casting's
-- swatch), Default's value (its default, or changed), the nameplates' own (none: follows;
-- set: a value of their own; same: one of their own equal to Default's now), and what's done:
-- nothing, the row's x (Reset "prop"), Reset page (the page's variant), Reset everything in
-- Style (Default reset in the same step), the setting set to Default's value, the x then Undo.
-- Each cell: whether the row shows edited before, and after it the own value (none, mine,
-- def: Default's default, chg: Default's changed value) and whether it shows edited.
-- The rule (2026-11-26): following Default isn't edited; Reset (x, Reset page, Reset
-- everything) clears the own value: the setting follows Default again, never pinned to a
-- value; Undo gives the own value back.

local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local Studio = ns.Studio
local db = ns.db
local f = Studio.frames.cast

local SETTINGS = {
	height = { base = "plateCastHeight", def = 1, chg = 1.5, mine = 2 },
	color = { base = "plateCastR", def = 1, chg = 0.4, mine = 0.2, swatch = true },
}
-- (Each setting's row on the cast frame: the prop whose Default key is the base, or whose
-- swatch's first key is.)
local function Row(spec)
	for _, each in ipairs(Studio.Props(f)) do
		local p = each.prop
		if spec.swatch then
			local rgb = p.kind == "swatch" and Studio.RGB(p, "default")
			if rgb and rgb[1] == spec.base then return each end
		elseif p.kind ~= "swatch" and Studio.KeyOf(p, "default") == spec.base then
			return each
		end
	end
end
local function Edited(each)
	return Studio.SourceOf(f, each.prop, "PLATE") == "yours" and "yes" or "no"
end
local function Word(spec, value)
	if value == nil then return "none" end
	if value == spec.mine then return "mine" end
	if value == spec.chg then return "chg" end
	if value == spec.def then return "def" end
	return tostring(value)
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "cast-plate-follow",
	fixed = { client = client },
	dims = {
		{ "setting", { "height", "color" } },
		{ "default", { "same", "changed" } },
		{ "own", { "none", "set", "same" } },
		{ "action", { "none", "x", "page", "all", "setdefault", "xundo" } },
	},
	cell = function(c)
		local spec = SETTINGS[c.setting]
		local own = spec.base .. "_PLATE"
		local each = Row(spec)
		if not each then return "no row" end
		-- (Each cell from the defaults: nothing else of yours.)
		for _, w in ipairs(Studio.ResetWrites("all")) do pcall(Studio.Put, w[1], w[2]) end
		for _, k in ipairs({ "plateCastHeight", "plateCastR", "plateCastG", "plateCastB" }) do
			db[k] = ns.DEFAULTS[k]
			db[k .. "_PLATE"] = nil
		end
		if ns.DEFAULTS[spec.base] ~= spec.def then return "DEFAULTS moved: " .. tostring(ns.DEFAULTS[spec.base]) end
		db[spec.base] = c.default == "changed" and spec.chg or spec.def
		if c.own == "set" then db[own] = spec.mine
		elseif c.own == "same" then db[own] = db[spec.base] end
		local before = Edited(each)
		if c.action == "x" or c.action == "xundo" then
			-- (Undo only what the x did: the history is the session's.)
			local n = Studio.Reset("prop", f, "PLATE", each.part.id, each.prop)
			if c.action == "xundo" and n > 0 then Studio.Undo() end
		elseif c.action == "page" then
			Studio.Reset("variant", f, "PLATE", nil, nil, "Reset page")
		elseif c.action == "all" then
			Studio.Reset("all", f)
		elseif c.action == "setdefault" then
			local key = spec.swatch and Studio.RGB(each.prop, "PLATE")[1] or Studio.KeyOf(each.prop, "PLATE")
			if spec.swatch then
				Studio.Apply(f, "set", { { key, db[spec.base] } })
			else
				Studio.Set(f, each.prop, "PLATE", db[spec.base], each.part)
			end
		end
		local out = ("before=%s own=%s edited=%s"):format(before, Word(spec, db[own]), Edited(each))
		-- (Cleaned up: the next cell's Reset all starts from here.)
		db[own], db[spec.base] = nil, ns.DEFAULTS[spec.base]
		return out
	end,
	pins = {
		-- (Following Default: never edited, nothing to reset, whatever Default's value.)
		{ "own=none", "before=no own=none edited=no" },
		-- (A value of its own: edited; kept by nothing and by Reset of nothing.)
		{ "own=set", "before=yes own=mine edited=yes" },
		-- (Reset, every way, and set to Default's value: follows Default again.)
		{ "own=set action=x", "before=yes own=none edited=no" },
		{ "own=set action=page", "before=yes own=none edited=no" },
		{ "own=set action=all", "before=yes own=none edited=no" },
		{ "own=set action=setdefault", "before=yes own=none edited=no" },
		-- (Undo after the x: its own value back.)
		{ "own=set action=xundo", "before=yes own=mine edited=yes" },
		-- (Its own equal to Default's now (Default changed to it later, or a profile): still its
		-- own, so edited, and Reset clears it as any other. Already at Default's value, set to it
		-- writes nothing. The card's "user's call" row.)
		{ "own=same default=same", "before=yes own=def edited=yes" },
		{ "own=same default=changed", "before=yes own=chg edited=yes" },
		{ "own=same action=x", "before=yes own=none edited=no" },
		{ "own=same action=page", "before=yes own=none edited=no" },
		{ "own=same action=all", "before=yes own=none edited=no" },
		-- (Undo gives the value back, Default's, and a value set to Default's follows it: the
		-- same on screen, it only follows Default's next change.)
		{ "own=same action=xundo", "before=yes own=none edited=no" },
	},
})
