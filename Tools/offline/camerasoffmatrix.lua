-- Enable Cameras off and camera scripts (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-cameras-off-scripts.md):
--   python -I Tools/offline/run.py Tools/offline/camerasoffmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/camerasoffmatrix.lua forever --base <ref>
-- Enable Cameras on or off, the Scenes page on or off, the Scripts page on or
-- off, and what plays: the Stand still scene's row set to a script of yours
-- (script:u1, its row's When Always), or the RP walk camera's key (the
-- camera wheel goes by it too: Cinematic_StartCam). Each cell: for the
-- scene, what the camera scripts' watcher picks (TriggerNow) and whether it
-- worked out the scene event to get there ("asked": ns.ActiveEvent, every
-- frame); for the key, which walk script it plays ("yours", the Scripts
-- page's copy, or "shipped", as we ship it) or none.
-- The rule: Enable Cameras off, no camera of ours plays and nothing is worked
-- out for one; the Scenes page off, no scene plays (a key still does); the
-- Scripts page off, none of yours plays and a key plays ours as shipped.
local client = arg and arg[1] or "forever"
local function Install()
	-- (Standing about: not on a flight, in a fight, mounted, dead...)
	local No = function() return false end
	for _, name in ipairs({ "UnitOnTaxi", "UnitAffectingCombat", "InCombatLockdown", "UnitIsAFK", "IsMounted",
		"UnitIsDeadOrGhost", "UnitIsDead", "IsFlying", "IsSwimming", "UnitInVehicle", "UnitCastingInfo",
		"UnitChannelInfo", "IsMouselooking", "IsMouseButtonDown", "UnitExists", "IsResting", "IsFalling",
		"IsStealthed" }) do
		_G[name] = No
	end
end
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db
local now = 100
GetTime = function() return now end -- luacheck: ignore 121
db.enabled = true
local row = ns.TriggerRowIds("Still")[1]
db.cameraRows[row .. ".always"] = true
ns.SetCameraRowValue(row, "camera", "script:u1")
-- (Counted: the scene event worked out; the key's script, caught, not played.)
local asked = 0
local active = ns.ActiveEvent
ns.ActiveEvent = function(...)
	asked = asked + 1
	return active(...)
end
local played
ns.PlayCameraScript = function(script)
	played = script
	return true
end
ns.PlayingCameraScript = function() return nil end
-- (The walk script as the Scripts page has it, marked: yours.)
local find = ns.FindCameraScript
local yours
ns.FindCameraScript = function(id)
	if id ~= "walk" then return find(id) end
	yours = yours or find(id)
	yours.yours = true
	return yours
end
-- (The first look after loading starts the standing-still time: once, before.)
db.cameraModes, db.cameraScenes = true, true
for _ = 1, 2 do
	ns.stillSince, now = 0, now + 10
	ns.ScriptTriggerNow()
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "cameras-off-scripts",
	fixed = { client = client },
	dims = {
		{ "cameras", { "on", "off" } },
		{ "scenes", { "on", "off" } },
		{ "scripts", { "on", "off" } },
		{ "what", { "scene", "key" } },
	},
	cell = function(c)
		db.cameraModes = c.cameras == "on"
		db.cameraScenes = c.scenes == "on"
		db.cameraScriptsPage = c.scripts == "on"
		ns.CameraRowsChanged()
		ns.manualCam, ns.stillSince = nil, 0
		now = now + 10
		if c.what == "scene" then
			asked = 0
			local key, camera = ns.ScriptTriggerNow()
			return ("%s %s"):format(key and (tostring(key) .. " " .. tostring(camera)) or "none",
				asked > 0 and "asked" or "not asked")
		end
		played = nil
		Cinematic_StartCam("walk", true)
		if not played then return "none" end
		return played.yours and "yours" or played.id == "walk" and "shipped" or ("other " .. tostring(played.id))
	end,
	pins = {
		{ "what=scene", "none asked" },
		{ "what=scene cameras=on scenes=on scripts=on", "Still script:u1 asked" },
		{ "what=scene cameras=off", "none not asked" },
		{ "what=key", "yours" },
		{ "what=key scripts=off", "shipped" },
		{ "what=key cameras=off", "none" },
	},
})
