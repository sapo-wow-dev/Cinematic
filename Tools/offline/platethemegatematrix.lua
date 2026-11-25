-- A plate theme's ground and bar shape under the switches (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-plate-theme-extras.md):
--   python -I Tools/offline/run.py Tools/offline/platethemegatematrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/platethemegatematrix.lua forever --base <ref>
-- Plate theme Clean picked (a flat texture, a black border, a dark ground
-- behind the fill); Enable Style on or off, Nameplate Style's switch on or
-- off. Each cell: what a plate's bar takes (Plates/PlateThemes.lua): its
-- texture (ours or game) and its ground (ours or game).
-- The rule (page off = every setting on it off): both, or neither.
local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local db = ns.db

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "plate-theme-extras",
	fixed = { client = client },
	dims = {
		{ "style", { "on", "off" } },
		{ "page", { "on", "off" } },
	},
	cell = function(c)
		db.plateTheme = "clean"
		db.styleGeneral, db.handlePlateStyle = c.style == "on", c.page == "on"
		local texture = ns.PlateThemeBar()
		local _, ground = ns.PlateThemeExtras()
		db.plateTheme, db.styleGeneral, db.handlePlateStyle = "main", true, true
		return ("texture=%s ground=%s"):format(texture and "ours" or "game", ground and "ours" or "game")
	end,
	pins = {
		{ "", "texture=game ground=game" },
		{ "style=on page=on", "texture=ours ground=ours" },
	},
})
