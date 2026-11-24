-- The old far-names set's leftovers cleanup (Effects.lua ns.plates.FarLeftovers),
-- every state (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-23-far-names-leftovers.md):
--   python -I Tools/offline/run.py Tools/offline/farleftoversmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/farleftoversmatrix.lua --base <ref>
-- The client (and Classic Era, ns.isClassicEra, on the Forever load), the
-- game's distances 41 / 5 there or not, 41 / 5 saved as yours or not, in a
-- fight or not, which API gives the game's defaults (C_CVar's, the global, none).
-- The rule: only WoW Forever had the old set, so only there, once, out of a
-- fight: 41 / 5 (live or saved) back to the game's defaults. No defaults to
-- read: nothing changed, no error. Every other client: never runs.

local client = arg and arg[1] or "forever"
local cvars = {}
local fighting = false
local api = "c_cvar"
local function Default() return "10" end

local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	local get = GetCVar -- (the stand-in's, for every other setting)
	C_CVar = {
		SetCVar = function(name, value) if cvars[name] ~= nil then cvars[name] = tostring(value) end end,
		GetCVar = function(name) if cvars[name] ~= nil then return cvars[name] end return get(name) end,
	}
	SetCVar = function(name, value) return C_CVar.SetCVar(name, value) end
	GetCVar = C_CVar.GetCVar
	InCombatLockdown = function() return fighting end
	-- luacheck: pop
end

local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db
local era = ns.isClassicEra

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = client == "retail" and "far-leftovers-retail" or "far-leftovers",
	fixed = { client = client },
	dims = {
		{ "era", { "no", "yes" } },
		{ "live", { "old", "game" } },
		{ "saved", { "none", "old" } },
		{ "fight", { "no", "yes" } },
		{ "api", { "c_cvar", "global", "none" } },
	},
	cell = function(c)
		-- luacheck: push ignore 111 112 113 121 122
		ns.isClassicEra = c.era == "yes" or era
		fighting = c.fight == "yes"
		api = c.api
		C_CVar.GetCVarDefault = api == "c_cvar" and Default or nil
		rawset(_G, "GetCVarDefault", api == "global" and Default or false)
		-- luacheck: pop
		local live = c.live == "old"
		cvars.nameplateMaxScaleDistance = live and "41" or "20"
		cvars.nameplateMinScaleDistance = live and "5" or "20"
		db.savedCVars = c.saved == "old" and { nameplateMaxScaleDistance = "41", nameplateMinScaleDistance = "5" } or {}
		db.farNamesLeftoversV1, db.farNamesLeftoversV2 = nil, nil
		local ok = pcall(ns.plates.FarLeftovers)
		ns.isClassicEra = era
		if not ok then return "error" end
		return ("live=%s/%s saved=%s/%s ran=%s"):format(cvars.nameplateMaxScaleDistance, cvars.nameplateMinScaleDistance,
			tostring(db.savedCVars.nameplateMaxScaleDistance), tostring(db.savedCVars.nameplateMinScaleDistance),
			tostring(db.farNamesLeftoversV2 or false))
	end,
	pins = {
		-- (Not Forever, or in a fight: nothing touched, not run.)
		{ "live=old saved=none", "live=41/5 saved=nil/nil ran=false" },
		{ "live=old saved=old", "live=41/5 saved=41/5 ran=false" },
		{ "live=game saved=none", "live=20/20 saved=nil/nil ran=false" },
		{ "live=game saved=old", "live=20/20 saved=41/5 ran=false" },
		-- (Forever, out of a fight: runs once; no defaults to read: nothing changed.)
		{ "client=forever era=no fight=no live=old saved=none", "live=41/5 saved=nil/nil ran=true" },
		{ "client=forever era=no fight=no live=old saved=old", "live=41/5 saved=41/5 ran=true" },
		{ "client=forever era=no fight=no live=game saved=none", "live=20/20 saved=nil/nil ran=true" },
		{ "client=forever era=no fight=no live=game saved=old", "live=20/20 saved=41/5 ran=true" },
		-- (A default to read: 41 / 5 back to it, live and saved.)
		{ "client=forever era=no fight=no live=old saved=none api=c_cvar", "live=10/10 saved=nil/nil ran=true" },
		{ "client=forever era=no fight=no live=old saved=none api=global", "live=10/10 saved=nil/nil ran=true" },
		{ "client=forever era=no fight=no live=old saved=old api=c_cvar", "live=10/10 saved=10/10 ran=true" },
		{ "client=forever era=no fight=no live=old saved=old api=global", "live=10/10 saved=10/10 ran=true" },
		{ "client=forever era=no fight=no live=game saved=old api=c_cvar", "live=20/20 saved=10/10 ran=true" },
		{ "client=forever era=no fight=no live=game saved=old api=global", "live=20/20 saved=10/10 ran=true" },
	},
})
