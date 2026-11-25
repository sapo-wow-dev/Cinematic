-- Shoulder Cam's Allow in flight / while dead under their tab (the audit kit's
-- matrix, Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-cameras-shoulder-allow-tab.md):
--   python -I Tools/offline/run.py Tools/offline/shoulderallowmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/shoulderallowmatrix.lua forever --base <ref>
-- On a flight path or dead, its Allow box for that ticked or not, and the
-- Shoulder Cam page's tab they're on (tabOn:Shoulder Cam/page:3) on or off.
-- Each cell: whether Shoulder Cam pauses for it (its pause reason).
-- The rule (2026-11-25, decided): a tab off is everything on it off, so an
-- Allow box under a tab that's off allows nothing.
local client = arg and arg[1] or "forever"
local taxi, dead = false, false
local function Install()
	local No = function() return false end
	for _, name in ipairs({ "UnitAffectingCombat", "InCombatLockdown", "UnitIsAFK", "IsMounted",
		"UnitIsDeadOrGhost", "IsFlying", "IsSwimming", "UnitInVehicle", "UnitCastingInfo", "UnitChannelInfo",
		"IsMouselooking", "IsMouseButtonDown", "UnitExists", "IsResting", "IsFalling", "IsStealthed",
		"issecretvalue", "IsIndoors" }) do
		_G[name] = No
	end
	-- luacheck: push ignore 121
	UnitOnTaxi = function() return taxi end
	UnitIsDead = function() return dead end
	-- luacheck: pop
end
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db
db.enabled, db.shoulderCam, db.shoulderCamAlways, db.shoulderPauseMoved = true, true, true, true
db.cameraModes = true
local TAB = "tabOn:Shoulder Cam/page:3"
local KEY = { flight = "shoulderCamAllowFlight", dead = "shoulderCamAllowDeath" }

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "shoulder-allow-tab",
	fixed = { client = client },
	dims = {
		{ "what", { "flight", "dead" } },
		{ "allow", { "yes", "no" } },
		{ "tab", { "on", "off" } },
	},
	cell = function(c)
		taxi, dead = c.what == "flight", c.what == "dead"
		db.shoulderCamAllowFlight, db.shoulderCamAllowDeath = false, false
		db[KEY[c.what]] = c.allow == "yes"
		db[TAB] = c.tab == "on"
		local why = ns.GetShoulderCamDebug().paused
		return why == c.what and "paused" or "allowed"
	end,
	pins = {
		{ "", "paused" },
		{ "allow=yes tab=on", "allowed" },
	},
})
