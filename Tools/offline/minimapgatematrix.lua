-- The Minimap page's Questie pins and its reveals with the switches it's under
-- (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-25-minimap-gate.md):
--   python -I Tools/offline/run.py Tools/offline/minimapgatematrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/minimapgatematrix.lua forever --base <ref>
-- The Minimap page on or off, Minimap's Show tab on or off, the HUD's General
-- on or off; the feature: the Questie pins on the minimap
-- (ns.QuestieMinimapOn), the reveals by node name (AnyReveal), by the cursor
-- (cursor.On), the quests-only reveal (QuestReveal). Each set on, and the
-- client able (stubbed: Questie loaded, the sweeps possible). Each cell: on or off.
-- The rule (page off = every setting on it off; its parents too): on only
-- with all three on.
local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local db = ns.db

-- A file's local function, found through the upvalues of ns's functions.
local function Local(name, kind)
	local seen = {}
	local function Walk(fn, depth)
		if type(fn) ~= "function" or seen[fn] or depth > 4 then return end
		seen[fn] = true
		for i = 1, 60 do
			local upName, value = debug.getupvalue(fn, i)
			if not upName then break end
			if upName == name and type(value) == kind then return value end
			local found = Walk(value, depth + 1)
			if found then return found end
		end
	end
	for _, value in pairs(ns) do
		local found = Walk(value, 0)
		if found then return found end
	end
end
local cursor = Local("cursor", "table")
local FEATURES = {
	questie = function() return ns.QuestieMinimapOn and ns.QuestieMinimapOn() end,
	reveal = Local("AnyReveal", "function"),
	cursor = cursor and cursor.On,
	quests = Local("QuestReveal", "function"),
}
for _, name in ipairs({ "QuestieLoaded", "CanSweepMinimap", "CanCursorSweepMinimap", "CanRevealQuestsOnly" }) do
	ns[name] = function() return true end
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "minimap-gate",
	fixed = { client = client },
	dims = {
		{ "feature", { "questie", "reveal", "cursor", "quests" } },
		{ "page", { "on", "off" } },
		{ "show", { "on", "off" } },
		{ "hud", { "on", "off" } },
	},
	cell = function(c)
		local fn = FEATURES[c.feature]
		if not fn then return "not found" end
		db.minimapQuestie, db.minimapRevealNodes, db.minimapNodesByCursor, db.minimapRevealAreas = true, true, true, true
		db.handleMinimap, db.showInMinimap, db.handleFrames = c.page == "on", c.show == "on", c.hud == "on"
		local ok, on = pcall(fn)
		if not ok then return "error " .. tostring(on) end
		return on and "on" or "off"
	end,
	pins = {
		{ "", "off" },
		{ "page=on show=on hud=on", "on" },
	},
})
