-- The game settings Style writes, through a safety stop and /cine resume,
-- every state (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-23-settings-resume-styles.md):
--   python -I Tools/offline/run.py Tools/offline/resumematrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/resumematrix.lua --base <ref>
-- Three styles that write a game setting (CVar) as their setting says, not
-- every frame: Combat Text Style (the game's damage numbers off while ours
-- draw them), Text on You (the game's floating combat text kept on) and the
-- Style hub's nameplate style. Each on (ours) or off (the game's), and where
-- the session is: running, stopped (ns.Suspend: an error stop or /cine
-- panic), stopped with the style's own refresh run after (its 2-s ticker; the
-- plate style's runs after a fight or a setting change), resumed (/cine
-- resume) and resumed with a refresh after. Each cell: the game setting,
-- "ours" (the style's value) or "game" (the player's own). The rule: a stop
-- puts the player's own back and keeps it till /cine resume; resume writes
-- ours again at once, no reload, no setting change needed.
-- (ae2cda8 release review 2026-11-22: the 2-s refresh undid the stop, and
-- resume left them the game's till a reload.)

local client = arg and arg[1] or "forever"
local cvars = {}
local OWN = { floatingCombatTextCombatDamage = "1", enableFloatingCombatText = "0", nameplateStyle = "0" }
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	for name, value in pairs(OWN) do cvars[name] = value end
	GetCVar = function(name) return cvars[name] end
	SetCVar = function(name, value) cvars[name] = tostring(value) end
	GetCVarBool = function(name) return cvars[name] == "1" end
	C_CVar.GetCVar, C_CVar.SetCVar = GetCVar, SetCVar
	InCombatLockdown = function() return false end
	-- luacheck: pop
end
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db

local STYLES = {
	combat = { cvar = "floatingCombatTextCombatDamage", ours = "0", refresh = "RefreshCombatTextStyle",
		set = function(on)
			db.combatTextStyle, db.combatTextDamageBy = on, "ours"
		end },
	self = { cvar = "enableFloatingCombatText", ours = "1", refresh = "RefreshSelfTextStyle",
		set = function(on)
			db.selfTextStyle, db.selfTextAlways, db.selfTextBy = on, true, "ours"
		end },
	plate = { cvar = "nameplateStyle", ours = "2", refresh = "RefreshPlateHealthStyle",
		set = function(on)
			db.stylePlate = on and 2 or "game"
		end },
}
local function Refresh(style)
	if ns[style.refresh] then ns[style.refresh]() end
end
local Print = ns.Print

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "resume-styles",
	fixed = { client = client },
	dims = {
		{ "style", { "combat", "self", "plate" } },
		{ "setting", { "ours", "game" } },
		{ "step", { "running", "stopped", "stoppedRefresh", "resumed", "resumedRefresh" } },
	},
	cell = function(c)
		local style = STYLES[c.style]
		ns.Print = function() end
		if ns.IsSuspended() then ns.Resume() end
		db.styleGeneral = true
		style.set(c.setting == "ours")
		Refresh(style)
		if c.step ~= "running" then ns.Suspend("resumematrix") end
		if c.step == "stoppedRefresh" then Refresh(style) end
		if c.step == "resumed" or c.step == "resumedRefresh" then ns.Resume() end
		if c.step == "resumedRefresh" then Refresh(style) end
		ns.Print = Print
		local value = cvars[style.cvar]
		return value == style.ours and "ours" or value == OWN[style.cvar] and "game" or ("other " .. tostring(value))
	end,
	pins = {
		{ "", "game" },
		{ "setting=ours step=running", "ours" },
		{ "setting=ours step=resumed", "ours" },
		{ "setting=ours step=resumedRefresh", "ours" },
	},
})
if ns.IsSuspended() then ns.Resume() end
