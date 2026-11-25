-- The hunter's right-click pull watch (QoL/Hunter.lua, Classic Era only), every
-- state (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-25-hunter-pull-loop.md):
--   python -I Tools/offline/run.py Tools/offline/hunterpullmatrix.lua < /dev/null
--   python -I Tools/audit.py diff Tools/offline/hunterpullmatrix.lua --base <ref>
-- Loaded as a Classic Era hunter (whatever client is asked: the file only runs
-- there). The Hunter page on or off, Right click attack also uses Auto-shot
-- on or off, after the other cell's state (the watch let what it set go).
-- Each cell: whether the every-frame watch runs.
-- The rule (page off = every setting on it off, and no cost): it runs only
-- while the setting is on with its page.
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	GetBuildInfo = function() return "1.15.7", "0", "", 11507 end
	UnitClass = function() return "Hunter", "HUNTER", 3 end
	-- luacheck: pop
end
local ns, wow = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc", Install)
local db = ns.db

local watcher
for _, frame in ipairs(wow.frames) do
	if frame._events and frame._events.GLOBAL_MOUSE_DOWN and frame._events.PLAYER_REGEN_DISABLED then watcher = frame end
end

-- (A few frames and a second: the watch lets go of what it set, the loops are synced.)
local function Settle()
	for _ = 1, 3 do
		local run = watcher and watcher:GetScript("OnUpdate")
		if run then pcall(run, watcher, 0.02) end
		if ns.SyncFeatureLoops then ns.SyncFeatureLoops() end
	end
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "hunter-pull-loop",
	fixed = { client = "era" },
	dims = {
		{ "page", { "on", "off" } },
		{ "tick", { "on", "off" } },
		{ "before", { "on", "off" } },
	},
	cell = function(c)
		if not ns.isClassicEra then return "not era" end
		if not watcher then return "no watcher" end
		db.handleHunter, db.hunterRightClickShot = c.before == "on", c.before == "on"
		Settle()
		db.handleHunter, db.hunterRightClickShot = c.page == "on", c.tick == "on"
		Settle()
		return "loop=" .. (watcher:GetScript("OnUpdate") and "on" or "off")
	end,
	pins = {
		{ "", "loop=off" },
		{ "page=on tick=on", "loop=on" },
	},
})
