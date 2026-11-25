-- Plate Layout: how far a part moves (the audit kit's matrix, Tools/offline/matrix.lua;
-- fix card Tools/audits/2026-11-25-plate-layout-range.md):
--   python -I Tools/offline/run.py Tools/offline/platelayoutrangematrix.lua < /dev/null
--   python -I Tools/audit.py diff Tools/offline/platelayoutrangematrix.lua forever --base <ref>
-- The Layout tab's level box saved 245 right (near the edge) or 400 right (past
-- it, as a shared or older layout could hold), then the arrow keys: Shift+Right
-- three times, or Left once. Each cell: the level box's left / right after.
-- The range, every way of moving (the user, 2026-11-25): 250 across, 150 up / down.
-- luacheck: ignore 111 112 113 121 122 212 431
local parts = dofile("Tools/offline/gameplate_parts.lua")(function() end)
local ns = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc", function()
	issecretvalue = function() return false end
	parts.Install()
end)
local page = ns.plateLayoutPage

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "platelayout-range",
	fixed = { client = "forever" },
	dims = { { "start", { "245", "400" } }, { "action", { "shiftRight3", "left1" } } },
	cell = function(c)
		if not page then return "no page" end
		ns.db.plateLayout = true
		ns.db.plateLayoutData = { all = { parts = { level = { x = tonumber(c.start) } } } }
		page.Edit("all")
		page.Select("level")
		local keys = page.keys
		keys.SetPropagateKeyboardInput = function() end
		keys.EnableKeyboard = function() end
		page.holder.IsMouseOver = function() return true end
		page.holder.IsVisible = function() return true end
		ns.PlateLayoutPageKeys()
		local onKey = keys:GetScript("OnKeyDown")
		if not onKey then return "no keys" end
		if c.action == "shiftRight3" then
			IsShiftKeyDown = function() return true end
			for _ = 1, 3 do onKey(keys, "RIGHT") end
		else
			IsShiftKeyDown = function() return false end
			onKey(keys, "LEFT")
		end
		local p = ns.db.plateLayoutData.all.parts.level
		return "x=" .. tostring(p and p.x or 0)
	end,
	pins = {
		-- What's right (the user's range, 2026-11-25): never past 250, from anywhere.
		{ "start=245 action=shiftRight3", "x=250" },
		{ "start=245 action=left1", "x=244" },
		{ "start=400 action=shiftRight3", "x=250" },
		{ "start=400 action=left1", "x=250" },
	},
})
