-- A game setting the addon writes erroring (Core.lua: WriteCVar, used by
-- ns.ApplyCVarSet and RestoreCVar), every state (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-23-cvar-write-error.md):
--   python -I Tools/offline/run.py Tools/offline/cvarwriteerrormatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/cvarwriteerrormatrix.lua --base <ref>
-- A set marked playerWins holds a setting (ours 0); then another set's write
-- errors (the game refusing it) or doesn't; then you change the held setting
-- yourself (1) or not. The rule: a change of yours to a held setting stands
-- (the set lets it go), whatever another write did before; with no change it
-- stays held. (Before the fix, the error left the "addon writing" flag on, so
-- your change went unseen for the session and was written over later.)

local client = arg and arg[1] or "forever"
local cvars = { Sound_MusicVolume = "1", Sound_EnableMusic = "1" }
local throw = {}
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	C_CVar = {
		SetCVar = function(name, value)
			if throw[name] then error("refused: " .. name, 0) end
			cvars[name] = tostring(value)
		end,
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
	debugstack = function() return "Interface/AddOns/CinematicDev/Test.lua:1: in main chunk" end
	C_Timer.After = function() end
	-- luacheck: pop
end
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db

local Matrix = dofile("Tools/offline/matrix.lua")
local n = 0
Matrix.Run({
	name = "cvar-write-error",
	fixed = { client = client },
	dims = {
		{ "otherWrite", { "ok", "errors" } },
		{ "yours", { "changed", "untouched" } },
	},
	cell = function(c)
		n = n + 1
		local held, other = "TestHeld" .. n, "TestOther" .. n
		cvars[held], cvars[other] = "1", "1"
		db.savedCVars, db.cvarsLeftAlone = db.savedCVars or {}, db.cvarsLeftAlone or {}
		local holder = { values = { [held] = "0" }, playerWins = true }
		ns.ApplyCVarSet(holder, true)
		throw[other] = c.otherWrite == "errors"
		local wrote = pcall(ns.ApplyCVarSet, { values = { [other] = "0" } }, true)
		throw[other] = nil
		if c.yours == "changed" then SetCVar(held, "1") end
		return ("write=%s held=%s value=%s"):format(wrote and "ok" or "error", tostring(ns.IsCVarHeld(held)),
			tostring(cvars[held]))
	end,
	pins = {
		{ "otherWrite=ok", "write=ok held=true value=0" },
		{ "otherWrite=errors", "write=error held=true value=0" },
		-- (Your change stands: let go.)
		{ "otherWrite=ok yours=changed", "write=ok held=false value=1" },
		{ "otherWrite=errors yours=changed", "write=error held=false value=1" },
	},
})
