-- Shoulder Cam's settings at logout as Cameras is left out (the audit kit's
-- matrix, Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-shoulder-leave.md):
--   python -I Tools/offline/run.py Tools/offline/shoulderleavematrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/shoulderleavematrix.lua forever --base <ref>
-- Shoulder Cam on (its settings written over yours: the offset, Keep
-- Character Centered, the talk focus), Load Cameras kept or unticked, in a
-- fight or not, then the logout (a /reload). Each cell: which of them are
-- still Shoulder Cam's after it ("game" = all yours again).
-- The rule: kept, the offset and focus stay for the next session's Shoulder
-- Cam (the game clears the offset each session anyway, on Forever), Keep
-- Character Centered goes back (as the game saves it). Unticked, nothing of
-- the Shoulder Cam is left: no Cameras code runs after the reload to put
-- anything back.
local client = arg and arg[1] or "forever"
local cvars = {}
local fight = false
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	GetCVar = function(name) return cvars[name] or "0" end
	SetCVar = function(name, value) cvars[name] = tostring(value) end
	C_CVar = C_CVar or {}
	C_CVar.GetCVar = GetCVar
	C_CVar.SetCVar = SetCVar
	InCombatLockdown = function() return fight end
	-- luacheck: pop
end
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db
-- (name, yours, Shoulder Cam's)
local SETTINGS = {
	{ "offset", "test_cameraOverShoulder", "0", "1.2" },
	{ "centered", "CameraKeepCharacterCentered", "1", "0" },
	{ "focus", "test_cameraTargetFocusInteractEnable", "0", "1" },
}

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "shoulder-leave",
	fixed = { client = client },
	dims = {
		{ "load", { "kept", "unticked" } },
		{ "fight", { "no", "yes" } },
	},
	cell = function(c)
		ns.SetModuleWanted("cameras", true)
		local yours = {}
		for _, s in ipairs(SETTINGS) do
			yours[s[2]] = s[3]
			cvars[s[2]] = s[4]
		end
		db.shoulderCamYours = yours
		if c.load == "unticked" then ns.SetModuleWanted("cameras", false) end
		fight = c.fight == "yes"
		wow.Fire("PLAYER_LOGOUT")
		fight = false
		local left = {}
		for _, s in ipairs(SETTINGS) do
			if cvars[s[2]] == s[4] then left[#left + 1] = s[1] end
		end
		return #left == 0 and "game" or ("ours: " .. table.concat(left, ","))
	end,
	pins = {
		{ "load=kept", "ours: offset,focus" },
		{ "load=unticked", "game" },
	},
})
ns.SetModuleWanted("cameras", true)
