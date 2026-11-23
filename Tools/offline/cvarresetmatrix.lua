-- Reset Cinematic puts back the game settings it held, every state (the
-- audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-23-cvar-reset-restore.md):
--   python -I Tools/offline/run.py Tools/offline/cvarresetmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/cvarresetmatrix.lua --base <ref>
-- The game's Damage numbers on your target (floatingCombatTextCombatDamage_v2)
-- held by Combat Text Style (its row Cinematic's: off; Game's: on), CineMode's
-- combat text off holding it too or not, Keep yours on the Game Settings page
-- or not, your own value on or off; then Reset Settings or Reset Everything,
-- and the setting read in the same frame (the reload done there) and a frame
-- later (the reload not yet done: "Type /reload to finish"). The rule: after
-- a reset the setting is yours, always.
-- (Before the fix, the reset's own write looked like an outside change to the
-- page's kept set, which wrote its value back a frame later: yours lost.)

local client = arg and arg[1] or "forever"
local DAMAGE = "floatingCombatTextCombatDamage_v2"
local cvars = { Sound_MusicVolume = "1", Sound_EnableMusic = "1" }
local timers = {}

local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	C_CVar = {
		SetCVar = function(name, value) if cvars[name] ~= nil then cvars[name] = tostring(value) end end,
		GetCVar = function(name) return cvars[name] end,
	}
	SetCVar = function(name, value) return C_CVar.SetCVar(name, value) end
	GetCVar = function(name) return cvars[name] end
	hooksecurefunc = function(a, b, c)
		local tbl, name, fn = a, b, c
		if type(a) == "string" then tbl, name, fn = _G, a, b end
		local orig = tbl[name]
		if type(orig) ~= "function" then return end
		tbl[name] = function(...)
			local r = { orig(...) }
			fn(...)
			return unpack(r)
		end
	end
	debugstack = function() return "Interface/AddOns/CinematicDev/Core.lua:1: in function 'WriteCVar'" end
	C_Timer.After = function(_, fn) timers[#timers + 1] = fn end
	-- luacheck: pop
end

local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local function RunTimers()
	for _ = 1, 5 do
		local now = timers
		timers = {}
		for _, fn in ipairs(now) do fn() end
	end
end
local cineSet
for _, set in ipairs(ns.cvarSets) do
	if set.label == "Combat text off" then cineSet = set end
end
local pageOn = false
ns.StyleOn = function(key) return key == "combatTextStyle" and pageOn end
ns.MasterOff = function() return false end
ns.Reload = function() end
ns.ResetLayouts = function() return true end
local db = ns.db

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "cvar-reset-restore",
	fixed = { client = client },
	dims = {
		{ "reset", { "settings", "everything" } },
		{ "row", { "ours", "game" } },
		{ "yours", { "on", "off" } },
		{ "cinemode", { "held", "free" } },
		{ "keepYours", { "no", "yes" } },
		{ "read", { "sameframe", "framelater" } },
	},
	cell = function(c)
		-- (Every set let go and the db back, from the last cell's reset.)
		ns.db = db
		CinematicDB = db
		db.savedCVars, db.cvarsLeftAlone = {}, {}
		pageOn = false
		ns.RefreshCombatTextStyle()
		if cineSet then ns.ApplyCVarSet(cineSet, false) end
		RunTimers()
		local yours = c.yours == "on" and "1" or "0"
		for name in pairs(cineSet and cineSet.values or {}) do cvars[name] = yours end
		cvars[DAMAGE], cvars.floatingCombatTextCombatDamage = yours, yours
		if c.keepYours == "yes" then db.cvarsLeftAlone[DAMAGE] = true end
		-- (Held: CineMode's first, then the page's, as at login with CineMode on.)
		if c.cinemode == "held" then
			if not cineSet then return "no CineMode set" end
			ns.ApplyCVarSet(cineSet, true)
		end
		db.combatTextDamageBy = c.row
		pageOn = true
		ns.RefreshCombatTextStyle()
		RunTimers()
		local ok, err = pcall(ns.ResetAddon, c.reset == "settings")
		if not ok then return "error: " .. tostring(err) end
		if c.read == "framelater" then RunTimers() end
		return cvars[DAMAGE] == yours and "damage=yours" or ("damage=" .. tostring(cvars[DAMAGE]) .. " (not yours)")
	end,
	pins = {
		{ "", "damage=yours" },
	},
})
ns.db, CinematicDB = db, db
