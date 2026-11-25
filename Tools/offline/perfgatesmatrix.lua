-- Work done for pages that are off (the audit kit's matrix, Tools/offline/matrix.lua;
-- fix card Tools/audits/2026-11-25-perf-gates.md):
--   python -I Tools/offline/run.py Tools/offline/perfgatesmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/perfgatesmatrix.lua forever --base <ref>
-- Three costs, each its own matrix:
--   frame-scan: the HUD's switch, the Advanced Frames page's and the Gamepad
--     page's, on or off: whether any page fades frames (ns.AnyFramePageOn;
--     false, Core.lua's frame scan stops).
--   buff-peek: the HUD's switch and the Buffs page's, on or off, then an aura
--     change on you: whether its handler walked the buff icons
--     (ns.CheckNewBuffIcons called).
--   minimap-tracking: the Minimap page's switch and Keep Open's, on or off,
--     then a frames pass: how many times the tracking list and its "Except
--     in" row were read.
-- The rule (the user's): page off = all off, its work too.
-- luacheck: push ignore 111 112 113 121 122
local client = arg and arg[1] or "forever"
local now = 100
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function()
	GetTime = function() return now end
	InCombatLockdown = function() return false end
	UnitAffectingCombat = function() return false end
	MouseIsOver = function() return false end
	UnitIsDeadOrGhost = function() return false end
	UnitIsDead = function() return false end
	UnitIsGhost = function() return false end
	GetMouseFoci = function() return {} end
	ChatEdit_GetActiveWindow = function() return nil end
	C_Minimap = setmetatable({ GetNumTrackingTypes = function() return 0 end },
		{ __index = function() return function() end end })
end)
local db = ns.db
db.mouseover = false
ns.MarkChatHolders = function() end
ns.IsChatActive = function() return false end
ns.EditModeActive = function() return false end
local Matrix = dofile("Tools/offline/matrix.lua")

Matrix.Run({
	name = "frame-scan",
	fixed = { client = client },
	dims = {
		{ "hud", { "on", "off" } },
		{ "addon", { "on", "off" } },
		{ "gamepad", { "on", "off" } },
	},
	cell = function(c)
		-- (The HUD's own pages on, as they start: under it.)
		for _, key in ipairs(ns.HANDLE_SWITCHES) do db[key] = true end
		db.handleFrames, db.handleAddonFrames, db.handleGamepad = c.hud == "on", c.addon == "on", c.gamepad == "on"
		local on = ns.AnyFramePageOn()
		db.handleFrames = true
		return on and "scan" or "none"
	end,
	pins = {
		{ "", "scan" },
		{ "hud=off addon=off gamepad=off", "none" },
	},
})

local calls = 0
local check = ns.CheckNewBuffIcons
ns.CheckNewBuffIcons = function(...)
	calls = calls + 1
	return check(...)
end
Matrix.Run({
	name = "buff-peek",
	fixed = { client = client },
	dims = {
		{ "hud", { "on", "off" } },
		{ "page", { "on", "off" } },
	},
	cell = function(c)
		db.buffPeek = true
		db.handleFrames, db.showInBuffs, db.handleBuffs = c.hud == "on", true, c.page == "on"
		now = now + 30
		calls = 0
		wow.Fire("UNIT_AURA", "player", { addedAuras = {} })
		db.handleFrames, db.handleBuffs = true, true
		return calls > 0 and "walked" or "skipped"
	end,
	pins = {
		{ "", "skipped" },
		{ "hud=on page=on", "walked" },
	},
})

local reads = 0
local keeping, offHere = ns.IsKeepingMinimapForTracking, ns.IsTrackingOffHere
ns.IsKeepingMinimapForTracking = function(...)
	reads = reads + 1
	return keeping(...)
end
ns.IsTrackingOffHere = function(...)
	reads = reads + 1
	return offHere(...)
end
Matrix.Run({
	name = "minimap-tracking",
	fixed = { client = client },
	dims = {
		{ "page", { "on", "off" } },
		{ "keepOpen", { "on", "off" } },
	},
	cell = function(c)
		db.handleFrames, db.showInMinimap = true, true
		db.handleMinimap, db.minimapKeepOpen = c.page == "on", c.keepOpen == "on"
		reads = 0
		now = now + 0.05
		local ok, err = pcall(ns.UpdateFrames, true, 0.05)
		db.handleMinimap, db.minimapKeepOpen = true, true
		if not ok then return "pass: " .. tostring(err) end
		return ("reads=%d"):format(reads)
	end,
	pins = {
		{ "", "reads=2" },
		{ "page=off keepOpen=off", "reads=0" },
	},
})
-- luacheck: pop
