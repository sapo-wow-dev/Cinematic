-- Range Hint's HUD row in the player copy and the dev copy, every list it
-- could show in (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-25-range-hint-row.md):
--   python -I Tools/offline/run.py Tools/offline/rangehintrowsmatrix.lua [forever|retail] [player|dev] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/rangehintrowsmatrix.lua forever player --base <ref>
-- Range Hint is dev only (UI/RangeHint.lua only in CinematicDev.toc; the
-- user, 2026-11-25). The copy is loaded by its .toc (one copy per run: the
-- dev copy makes the CinematicRangeHint frame). Each cell: one place a row
-- can be listed, and whether the "rangehint" row is in it:
-- - combatshow: the HUD rows (ns.COMBAT_SHOW), which the Show in grids,
--   rule words, profiles, the sweep and searches are built from;
-- - hoverrows: the Mouseover groups' rows (ns.HOVER_ROWS);
-- - keypicker: the key groups' frame picker (ns.FRAME_KEY_ROWS), a "Range
--   hint" heading with a row under it;
-- - offered: the row offered on the pages (ns.OptionAvailable: its frame exists);
-- - binding: its "Hide/show: Range hint" key binding name.
-- The rule: the player copy has none of it anywhere; the dev copy has it all.

local client = arg and arg[1] or "forever"
local copy = arg and arg[2] or "player"
local ns = dofile("Tools/offline/load.lua")(client, copy == "dev" and "CinematicDev.toc" or "Cinematic.toc")

local function Has(list)
	for _, item in ipairs(list or {}) do
		if item.key == "rangehint" then return item end
	end
end

local PLACES = {
	combatshow = function() return Has(ns.COMBAT_SHOW) ~= nil end,
	hoverrows = function() return Has(ns.HOVER_ROWS) ~= nil end,
	keypicker = function()
		for _, picks in ipairs(ns.FRAME_KEY_ROWS or {}) do
			if Has(picks) then return true end
		end
		return false
	end,
	-- (ns.OptionAvailable's frame check, by rawget: the stand-in answers every
	-- unknown global with a stub, the game nil. So this was "none" in the
	-- player copy before the fix too: the pages never showed the row.)
	offered = function()
		local item = Has(ns.COMBAT_SHOW)
		if not item then return false end
		for _, name in ipairs(item.frames or {}) do
			if rawget(_G, name) then return true end
		end
		return false
	end,
	binding = function()
		return rawget(_G, "BINDING_NAME_CLICK " .. tostring(ns.FRAME_KEY_BUTTON) .. ":rangehint") ~= nil
	end,
}

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	-- (One matrix per copy: a fix card's rows name the one they change.)
	name = "range-hint-row-" .. copy,
	fixed = { client = client, copy = copy },
	dims = {
		{ "place", { "combatshow", "hoverrows", "keypicker", "offered", "binding" } },
	},
	cell = function(c)
		-- (A dev copy from before Range Hint (3b6b1d0) has no row to list: an
		-- error, so audit.py reads "old code errors", not a changed cell.)
		if copy == "dev" and not rawget(_G, "CinematicRangeHint") then
			error("no Range Hint in this code (CinematicRangeHint)")
		end
		return PLACES[c.place]() and "listed" or "none"
	end,
	pins = {
		{ "copy=player", "none" },
		{ "copy=dev", "listed" },
	},
})
