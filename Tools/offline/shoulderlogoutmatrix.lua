-- Shoulder Cam's give-back at logout with one setting refused (the audit
-- kit's matrix, Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-shoulder-logout.md):
--   python -I Tools/offline/run.py Tools/offline/shoulderlogoutmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/shoulderlogoutmatrix.lua forever --base <ref>
-- Shoulder Cam on (its settings written over yours: the offset, Keep
-- Character Centered, the talk focus, the soft target), Load Cameras kept or
-- unticked, in a fight or not, and one of them refused by the game at the
-- logout (none, or one: as a Lua error or as a write that doesn't take, the
-- way a protected setting's ADDON_ACTION_BLOCKED leaves it). Each cell: which
-- are still Shoulder Cam's after it ("ours"), which it still keeps of yours
-- to give back later ("kept"), and whether the logout raised a Lua error.
-- The rule: each setting is tried on its own. One given back is cleared from
-- what's kept; one refused stays Shoulder Cam's and is kept for the next time
-- Cameras loads; no Lua error, and a refused one never stops the others.
-- Otherwise as before (2026-11-25-shoulder-leave.md, 2026-11-22 fight-off):
-- Load Cameras kept, the offset and focus stay for the next session, Keep
-- Character Centered goes back (still kept, the next session takes it off
-- again); the soft target goes back unless in a fight (then kept).
local client = arg and arg[1] or "forever"
local cvars = {}
local fight = false
local refuse, kind = nil, nil
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	GetCVar = function(name) return cvars[name] or "0" end
	SetCVar = function(name, value)
		if name == refuse then
			if kind == "error" then error("refused: " .. name) end
			return -- (blocked: the write doesn't take)
		end
		cvars[name] = tostring(value)
	end
	C_CVar = C_CVar or {}
	C_CVar.GetCVar = GetCVar
	C_CVar.SetCVar = SetCVar
	InCombatLockdown = function() return fight end
	-- luacheck: pop
end
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db
-- (name, CVar, yours, Shoulder Cam's)
local SETTINGS = {
	{ "offset", "test_cameraOverShoulder", "0", "1.2" },
	{ "centered", "CameraKeepCharacterCentered", "1", "0" },
	{ "focus", "test_cameraTargetFocusInteractEnable", "0", "1" },
	{ "soft", "SoftTargetEnemy", "1", "3" },
}
local CVAR_OF = {}
for _, s in ipairs(SETTINGS) do CVAR_OF[s[1]] = s[2] end

local function List(set)
	local out = {}
	for _, s in ipairs(SETTINGS) do
		if set[s[1]] then out[#out + 1] = s[1] end
	end
	return #out == 0 and "none" or table.concat(out, ",")
end

local REFUSED = { "none", "offset", "centered", "focus", "soft" }
local Matrix = dofile("Tools/offline/matrix.lua")

-- What's right, from the rule above.
local pins = {}
for _, load in ipairs({ "kept", "unticked" }) do
	for _, inFight in ipairs({ "no", "yes" }) do
		for _, refused in ipairs(REFUSED) do
			local ours, kept = {}, {}
			if load == "kept" then
				ours.offset, ours.focus = true, true
				kept.offset, kept.centered, kept.focus = true, true, true
			end
			if inFight == "yes" then ours.soft, kept.soft = true, true end
			if refused ~= "none" then ours[refused], kept[refused] = true, true end
			pins[#pins + 1] = { ("load=%s fight=%s refused=%s"):format(load, inFight, refused),
				("ours: %s; kept: %s; error: no"):format(List(ours), List(kept)) }
		end
	end
end

Matrix.Run({
	name = "shoulder-logout",
	fixed = { client = client },
	dims = {
		{ "load", { "kept", "unticked" } },
		{ "fight", { "no", "yes" } },
		{ "refused", REFUSED },
		{ "kind", { "error", "blocked" } },
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
		refuse, kind = c.refused ~= "none" and CVAR_OF[c.refused] or nil, c.kind
		local warned = #wow.warnings
		wow.Fire("PLAYER_LOGOUT")
		local erred = #wow.warnings > warned
		fight, refuse, kind = false, nil, nil
		local ours, kept = {}, {}
		local left = db.shoulderCamYours or {}
		for _, s in ipairs(SETTINGS) do
			if cvars[s[2]] == s[4] then ours[s[1]] = true end
			if left[s[2]] ~= nil then kept[s[1]] = true end
		end
		return ("ours: %s; kept: %s; error: %s"):format(List(ours), List(kept), erred and "yes" or "no")
	end,
	pins = pins,
})
ns.SetModuleWanted("cameras", true)
