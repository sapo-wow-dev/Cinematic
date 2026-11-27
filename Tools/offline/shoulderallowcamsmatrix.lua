-- Shoulder Cam's Allow boxes for Cinematic's cameras under their tab (the
-- audit kit's matrix, Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-shoulder-allow-cams-tab.md):
--   python -I Tools/offline/run.py Tools/offline/shoulderallowcamsmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/shoulderallowcamsmatrix.lua forever --base <ref>
-- One of Cinematic's cameras running (an event's: vista, fish, cozy, AFK,
-- teleport, a fly-by, death, your own script; or one playing as you move or
-- talk: walk, auto-run, quest, Chat Cam), its Allow box ticked or not, and
-- the Shoulder Cam page's tab they're on (tabOn:Shoulder Cam/page:3) on or
-- off. Each cell: whether Shoulder Cam pauses for it (its pause reason).
-- The rule (2026-11-25, decided for the flight / death boxes, card
-- 2026-11-25-cameras-shoulder-allow-tab.md; the tab-is-container rule): a tab
-- off is everything on it off, so an Allow box under a tab that's off allows
-- nothing. (The flight path / death pauses themselves: shoulderallowmatrix.lua.)
local client = arg and arg[1] or "forever"
local function Install()
	local No = function() return false end
	for _, name in ipairs({ "UnitAffectingCombat", "InCombatLockdown", "UnitIsAFK", "IsMounted",
		"UnitIsDeadOrGhost", "IsFlying", "IsSwimming", "UnitInVehicle", "UnitCastingInfo", "UnitChannelInfo",
		"IsMouselooking", "IsMouseButtonDown", "UnitExists", "IsResting", "IsFalling", "IsStealthed",
		"issecretvalue", "IsIndoors", "UnitOnTaxi", "UnitIsDead", "UnitIsUnit" }) do
		_G[name] = No
	end
end
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db
db.enabled, db.shoulderCam, db.shoulderCamAlways, db.shoulderPauseMoved = true, true, true, true
db.cameraModes = true
local TAB = "tabOn:Shoulder Cam/page:3"
-- (name, how it runs, the camera's value, its Allow box)
local CAMS = {
	{ "vista", "event", "vista", "shoulderCamAllowVista" },
	{ "fish", "event", "fish", "shoulderCamAllowFish" },
	{ "cozy", "event", "cozy", "shoulderCamAllowCozy" },
	{ "afk", "event", "afk", "shoulderCamAllowAFK" },
	{ "tele", "event", "tele", "shoulderCamAllowTele" },
	{ "flyby", "event", "script:flyby", "shoulderCamAllowFlight" },
	{ "death", "event", "death", "shoulderCamAllowDeath" },
	{ "yours", "event", "script:matrixMine", "shoulderCamAllowYours" },
	{ "walk", "playing", "walk", "shoulderCamAllowWalk" },
	{ "run", "playing", "run", "shoulderCamAllowRun" },
	{ "quest", "playing", "quest", "shoulderCamAllowQuest" },
	{ "chat", "playing", "chatcam", "shoulderCamAllowChat" },
}
local NAMES, CAM_OF = {}, {}
for _, cam in ipairs(CAMS) do NAMES[#NAMES + 1] = cam[1] CAM_OF[cam[1]] = cam end
local realActive = ns.ActiveEvent

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "shoulder-allow-cams-tab",
	fixed = { client = client },
	dims = {
		{ "cam", NAMES },
		{ "allow", { "yes", "no" } },
		{ "tab", { "on", "off" } },
	},
	cell = function(c)
		local cam = CAM_OF[c.cam]
		for _, other in ipairs(CAMS) do db[other[4]] = false end
		db[cam[4]] = c.allow == "yes"
		db[TAB] = c.tab == "on"
		ns.ActiveEvent = function() return nil, nil end
		ns.activeCam = nil
		if cam[2] == "event" then
			ns.ActiveEvent = function() return "matrix", cam[3] end
		else
			ns.activeCam = cam[3]
		end
		local why = ns.GetShoulderCamDebug().paused
		ns.ActiveEvent, ns.activeCam = realActive, nil
		if why == cam[3] then return "paused" end
		return why == "no" and "allowed" or ("other: " .. tostring(why))
	end,
	pins = {
		{ "", "paused" },
		{ "allow=yes tab=on", "allowed" },
	},
})
