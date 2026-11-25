-- A quest giver's window with Quest Cam off (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-cameras-quest-cam-off.md):
--   python -I Tools/offline/run.py Tools/offline/questcamoffmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/questcamoffmatrix.lua forever --base <ref>
-- A quest giver's window opens (QUEST_DETAIL, an NPC), and the mouse goes onto
-- a unit (UPDATE_MOUSEOVER_UNIT). The Quest scene's row set to the quest
-- camera, to its script, or to no camera; Enable Cameras on or off; Quest
-- talk (Quest Vision) on or off. Each cell: whether the talk is followed
-- (ns.QuestCamWindowUp) and Quest Cam's update loop runs; whether the mouse's
-- pass over the unit is watched (QuestCam.lua's pass watcher, every frame
-- while on a unit: Quest talk's Opposite clicked and the quest camera read it).
-- The rule: the talk and its loop only for the quest camera or its script on
-- here; the pass only for those or Quest talk.
local client = arg and arg[1] or "forever"
local function Install()
	local No = function() return false end
	for _, name in ipairs({ "UnitOnTaxi", "UnitAffectingCombat", "InCombatLockdown", "UnitIsAFK", "IsMounted",
		"UnitIsDeadOrGhost", "UnitIsDead", "IsFlying", "IsSwimming", "UnitInVehicle", "UnitCastingInfo",
		"UnitChannelInfo", "IsMouselooking", "IsMouseButtonDown", "IsResting", "IsFalling", "IsStealthed",
		"UnitIsPlayer", "issecretvalue" }) do
		_G[name] = No
	end
	UnitExists = function(unit) return unit == "npc" or unit == "mouseover" end -- luacheck: ignore 121
	UnitGUID = function(unit) return unit == "mouseover" and "Creature-0-1-2-3-4-5" or nil end -- luacheck: ignore 121
end
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db
local now = 100
GetTime = function() return now end -- luacheck: ignore 121
db.enabled = true
db.questCamNotDaily = false -- (the stand-in's quest reads as a daily)
local row = ns.TriggerRowIds("Quest")[1]
db.cameraRows[row .. ".always"] = true
ns.SetCameraRowOn(row, true)
-- (Quest Cam's frame: its events; the pass watcher: the mouse's only.)
local camFrame, passFrame
for _, frame in ipairs(wow.frames) do
	local e = frame._events
	if e.QUEST_DETAIL and e.CINEMATIC_START and e.PLAYER_REGEN_DISABLED then camFrame = frame end
	if e.UPDATE_MOUSEOVER_UNIT and next(e, next(e)) == nil and not frame._shown and frame._scripts.OnUpdate then
		passFrame = frame
	end
end
assert(camFrame and passFrame, "matrix: Quest Cam's frames not found")
local CAMERA = { quest = "quest", script = "script:quest", none = "none" }

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "quest-cam-off",
	fixed = { client = client },
	dims = {
		{ "row", { "quest", "script", "none" } },
		{ "cameras", { "on", "off" } },
		{ "talk", { "on", "off" } },
	},
	cell = function(c)
		-- (The last talk ended first: a fight, then the loop's next frame.)
		wow.Fire("PLAYER_REGEN_DISABLED")
		now = now + 10
		if camFrame._scripts.OnUpdate then camFrame._scripts.OnUpdate(camFrame, 0.1) end
		passFrame:Hide()
		db.cameraModes = c.cameras == "on"
		ns.SetCameraRowValue(row, "camera", CAMERA[c.row])
		db.questVision, db.questTalk = c.talk == "on", c.talk == "on"
		ns.CameraRowsChanged()
		now = now + 10
		wow.Fire("QUEST_DETAIL")
		ns.QuestCamWake()
		wow.Fire("UPDATE_MOUSEOVER_UNIT")
		return ("talk %s, loop %s, pass %s"):format(ns.QuestCamWindowUp() and "on" or "off",
			camFrame._scripts.OnUpdate and "on" or "off", passFrame._shown and "on" or "off")
	end,
	pins = {
		{ "", "talk off, loop off, pass off" },
		{ "talk=on", "talk off, loop off, pass on" },
		{ "cameras=on row=quest", "talk on, loop on, pass on" },
		{ "cameras=on row=script", "talk on, loop on, pass on" },
	},
})
