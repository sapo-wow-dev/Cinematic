-- Plate Layout: a kind's own layout as it starts (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-plate-layout-kind-copy.md):
--   python -I Tools/offline/run.py Tools/offline/platelayoutkindmatrix.lua < /dev/null
--   python -I Tools/audit.py diff Tools/offline/platelayoutkindmatrix.lua forever --base <ref>
-- The Layout tab with Layout for on Hostile: All plates' layout empty or with
-- the level box 10 right and Balanced; then crowd control nudged 1 right with
-- the arrow key, or Own layout ticked. Each cell: what Hostile's plates get
-- (ns.PlateLayoutFor): its own or not, the level box's and crowd control's
-- left / right, its center.
-- luacheck: ignore 111 112 113 121 122 212 431
local parts = dofile("Tools/offline/gameplate_parts.lua")(function() end)
local ns = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc", function()
	issecretvalue = function() return false end
	parts.Install()
end)
local page = ns.plateLayoutPage
IsShiftKeyDown = function() return false end

local function OwnBox()
	for _, each in ipairs(page and page.controls or {}) do
		if each[2] == "Own layout" then return each[1] end
	end
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "platelayout-kindcopy",
	fixed = { client = "forever" },
	dims = { { "all", { "empty", "levelRight" } }, { "action", { "nudge", "tick" } } },
	cell = function(c)
		if not page then return "no page" end
		ns.db.plateLayout = true
		ns.db.plateLayoutData = c.all == "levelRight" and { all = { center = "balanced", parts = { level = { x = 10 } } } }
			or nil
		page.Edit("all")
		page.Edit("hostile")
		if c.action == "nudge" then
			page.Select("crowd")
			local keys = page.keys
			keys.SetPropagateKeyboardInput = function() end
			keys.EnableKeyboard = function() end
			page.holder.IsMouseOver = function() return true end
			page.holder.IsVisible = function() return true end
			ns.PlateLayoutPageKeys()
			local onKey = keys:GetScript("OnKeyDown")
			if onKey then onKey(keys, "RIGHT") end
		else
			local box = OwnBox()
			if not box then return "no Own layout box" end
			box:SetChecked(true)
			box:GetScript("OnClick")(box)
		end
		local data = ns.db.plateLayoutData or {}
		local hostile = type(data.hostile) == "table" and data.hostile or {}
		local got = ns.PlateLayoutFor("hostile") or {}
		local p = got.parts or {}
		return ("own=%s level=%s crowd=%s center=%s"):format(tostring(hostile.own and true or false),
			tostring(p.level and p.level.x or 0), tostring(p.crowd and p.crowd.x or 0), tostring(got.center or "bar"))
	end,
	pins = {
		-- What's right (the audit, 2026-11-25): Hostile starts from All plates' layout, its own from then on.
		{ "all=empty action=nudge", "own=true level=0 crowd=1 center=bar" },
		{ "all=empty action=tick", "own=true level=0 crowd=0 center=bar" },
		{ "all=levelRight action=nudge", "own=true level=10 crowd=1 center=balanced" },
		{ "all=levelRight action=tick", "own=true level=10 crowd=0 center=balanced" },
	},
})
