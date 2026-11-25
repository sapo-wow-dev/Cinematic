-- Plate Layout: the arrow keys (the audit kit's matrix, Tools/offline/matrix.lua;
-- fix card Tools/audits/2026-11-25-plate-layout-keys.md):
--   python -I Tools/offline/run.py Tools/offline/platelayoutkeysmatrix.lua < /dev/null
--   python -I Tools/audit.py diff Tools/offline/platelayoutkeysmatrix.lua forever --base <ref>
-- The level box picked on the Layout tab, the keys taken; then a key with the
-- mouse over the preview, over the parts panel (its list and fields), or away.
-- Each cell: the level box's left / right, whether the key went on to the game,
-- and whether the keyboard is still held. Every key but an arrow always goes
-- on to the game; away from the page, the keyboard is let go (the first build
-- took every key in the game, 2026-11-25).
-- luacheck: ignore 111 112 113 121 122 212 431
local parts = dofile("Tools/offline/gameplate_parts.lua")(function() end)
local ns = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc", function()
	issecretvalue = function() return false end
	parts.Install()
end)
local page = ns.plateLayoutPage
IsShiftKeyDown = function() return false end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "platelayout-keys",
	fixed = { client = "forever" },
	dims = { { "mouse", { "preview", "panel", "away" } }, { "key", { "RIGHT", "W" } } },
	cell = function(c)
		if not page then return "no page" end
		ns.db.plateLayout = true
		ns.db.plateLayoutData = { all = { parts = {} } }
		page.Edit("all")
		local keys = page.keys
		local passed, held = nil, false
		keys.SetPropagateKeyboardInput = function(_, on) passed = on end
		keys.EnableKeyboard = function(_, on) held = on and true or false end
		page.holder.IsVisible = function() return true end
		page.holder.IsMouseOver = function() return c.mouse == "preview" end
		if page.partsPanel then
			page.partsPanel.IsVisible = function() return true end
			page.partsPanel.IsMouseOver = function() return c.mouse == "panel" end
		end
		page.Select("level")
		ns.PlateLayoutPageKeys() -- (as the mouse comes onto a part of the plate)
		local onKey = keys:GetScript("OnKeyDown")
		if not onKey then return "no keys" end
		onKey(keys, c.key)
		local p = ns.db.plateLayoutData.all.parts.level
		return ("x=%s passed=%s held=%s"):format(tostring(p and p.x or 0), tostring(passed), tostring(held))
	end,
	pins = {
		-- What's right (the audit, 2026-11-25): the arrows nudge from the preview or the panel; any
		-- other key goes on to the game; away, every key goes on and the keyboard is let go.
		{ "mouse=preview key=RIGHT", "x=1 passed=false held=true" },
		{ "mouse=panel key=RIGHT", "x=1 passed=false held=true" },
		{ "mouse=away key=RIGHT", "x=0 passed=true held=false" },
		{ "mouse=preview key=W", "x=0 passed=true held=true" },
		{ "mouse=panel key=W", "x=0 passed=true held=true" },
		{ "mouse=away key=W", "x=0 passed=true held=false" },
	},
})
