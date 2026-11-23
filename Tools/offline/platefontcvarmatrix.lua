-- /cine debug platefont gives back your friendly nameplates, every state (the
-- audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-23-platefont-friendly-plates.md):
--   python -I Tools/offline/run.py Tools/offline/platefontcvarmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/platefontcvarmatrix.lua --base <ref>
-- The test switches friendly plates on (nameplateShowFriends) for its run
-- when they're off. Your own value on or off; a set of ours (Plates off)
-- holding it off meanwhile or not; the run stopped out of a fight, in one
-- (then the fight ends), or cut by a /reload (logout, then login). Each
-- cell: the setting once the run's over and the set let go. The rule: yours.

local client = arg and arg[1] or "forever"
local FRIENDS = "nameplateShowFriends"
local cvars = { [FRIENDS] = "1", nameplateShowEnemies = "1", nameplateShowFriendlyPlayers = "1",
	nameplateShowFriendlyNPCs = "1", nameplateShowAll = "1", Sound_MusicVolume = "1", Sound_EnableMusic = "1" }
local timers = {}
local fighting = false
local W

local function Install(wow)
	W = wow
	-- luacheck: push ignore 111 112 113 121 122
	C_CVar = {
		SetCVar = function(name, value) if cvars[name] ~= nil then cvars[name] = tostring(value) end end,
		GetCVar = function(name) return cvars[name] end,
	}
	SetCVar = function(name, value) return C_CVar.SetCVar(name, value) end
	GetCVar = function(name) return cvars[name] end
	InCombatLockdown = function() return fighting end
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
	C_Timer.NewTicker = function() return { Cancel = function() end } end
	-- luacheck: pop
end

local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local function RunTimers()
	for _ = 1, 5 do
		local now = timers
		timers = {}
		for _, fn in ipairs(now) do pcall(fn) end
	end
end
local platesOff
for _, set in ipairs(ns.cvarSets) do
	if set.label == "Plates off" then platesOff = set end
end
ns.PadTestBox = ns.PadTestBox or function() end
ns.PadTestBoxHide = function() end
local db = ns.db

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "platefont-friendly-plates",
	fixed = { client = client },
	dims = {
		{ "yours", { "on", "off" } },
		{ "held", { "platesoff", "free" } },
		{ "finish", { "stopped", "infight", "reload" } },
	},
	cell = function(c)
		fighting = false
		if ns.plateFontTest then ns.plateFontTest.Finish("reset") end
		for _, set in ipairs(ns.cvarSets) do
			if set.active then ns.ApplyCVarSet(set, false) end
		end
		RunTimers()
		db.savedCVars = {}
		local yours = c.yours == "on" and "1" or "0"
		cvars[FRIENDS] = yours
		if c.held == "platesoff" then
			if not platesOff then return "no Plates off set" end
			ns.ApplyCVarSet(platesOff, true)
		end
		local ok, err = pcall(ns.PlateFontTest)
		if not ok then return "error: " .. tostring(err) end
		local during = cvars[FRIENDS]
		if c.finish == "stopped" then
			ns.PlateFontTest()
		elseif c.finish == "infight" then
			fighting = true
			ns.PlateFontTest()
			fighting = false
			W.Fire("PLAYER_REGEN_ENABLED")
		else
			-- (A /reload mid-run: its logout, then what the next login has.
			-- A fresh load can't run here: the next login's put-back
			-- (Core.lua's RestoreSavedCVars) writes what's saved, so the
			-- outcome is the saved value, or the setting as left.)
			ns.plateFontTest = nil
			W.Fire("PLAYER_LOGOUT")
			RunTimers()
			local after = db.savedCVars[FRIENDS] or cvars[FRIENDS]
			return ("during=%s after=%s"):format(during == "1" and "on" or "off",
				after == yours and "yours" or (after .. " (not yours)"))
		end
		RunTimers()
		if platesOff and platesOff.active then ns.ApplyCVarSet(platesOff, false) end
		RunTimers()
		return ("during=%s after=%s"):format(during == "1" and "on" or "off",
			cvars[FRIENDS] == yours and "yours" or (cvars[FRIENDS] .. " (not yours)"))
	end,
	pins = {
		{ "", "during=on after=yours" },
	},
})
