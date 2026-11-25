-- The target marks wanted by their switches (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-target-marks-gate.md):
--   python -I Tools/offline/run.py Tools/offline/targetmarksgatematrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/targetmarksgatematrix.lua forever --base <ref>
-- The plates' target marks (Nameplate Style's Smart page): Enable Style on or
-- off, the Smart page on or off, their Always tick on or off, in CineMode.
-- Each cell: whether ns.PlateIconWanted wants them (it drives their level and
-- their When loop, PlateParts.lua). The rule: they draw only with the Smart
-- page on (RefreshTargetArrow), so off there none is wanted and the loop rests
-- (the in-game gating test, 2026-11-25: PlateParts.lua's loop ran with Style off).
local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local db = ns.db
db.enabled = true

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "target-marks-gate",
	fixed = { client = client },
	dims = {
		{ "style", { "on", "off" } },
		{ "smart", { "on", "off" } },
		{ "always", { "on", "off" } },
	},
	cell = function(c)
		db.styleGeneral = c.style == "on"
		db.handlePlateStyle = true
		db.plateMarks = c.smart == "on"
		db.targetArrowAlways = c.always == "on"
		local ok, wanted = pcall(ns.PlateIconWanted, "TargetArrow", true)
		if not ok then return "error: " .. tostring(wanted) end
		return wanted and "wanted" or "not wanted"
	end,
	pins = {
		{ "", "not wanted" },
		{ "style=on smart=on always=on", "wanted" },
	},
})
