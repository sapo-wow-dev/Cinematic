-- A Skyriding probe's camera setting comes back after a Reset, every state
-- (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-23-skyride-probe-reset.md):
--   python -I Tools/offline/run.py Tools/offline/skyrideproberesetmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/skyrideproberesetmatrix.lua --base <ref>
-- /cine debug skyride's fov and follow probes change cameraFov or
-- cameraSmoothStyle for a few seconds and note yours (db.skyrideProbeRestore),
-- put back after, or at the next login if a /reload cut the probe. A Reset
-- (Settings or Everything) mid-probe, or none; then the reload: the saved
-- settings that survive it, loaded, and the login. The rule: your value back.

local client = arg and arg[1] or "retail" -- (the probes are retail only: SkyrideCam.lua)
local cvars = { cameraFov = "90", cameraSmoothStyle = "4", Sound_MusicVolume = "1", Sound_EnableMusic = "1" }
local timers = {}
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
	C_Timer.After = function(_, fn) timers[#timers + 1] = fn end
	-- luacheck: pop
end

local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
ns.Reload = function() end
ns.ResetLayouts = function() return true end
local YOURS = { cameraFov = "90", cameraSmoothStyle = "4" }
local PROBE = { cameraFov = "70", cameraSmoothStyle = "0" }
local db = ns.db

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "skyride-probe-reset",
	fixed = { client = client },
	dims = {
		{ "probe", { "cameraFov", "cameraSmoothStyle" } },
		{ "reset", { "none", "settings", "everything" } },
	},
	cell = function(c)
		ns.db, CinematicDB = db, db
		for cvar, value in pairs(YOURS) do cvars[cvar] = value end
		-- (Mid-probe, as its Hold leaves it: yours noted, the probe's written.)
		db.skyrideProbeRestore = { [c.probe] = YOURS[c.probe] }
		cvars[c.probe] = PROBE[c.probe]
		timers = {}
		if c.reset ~= "none" then
			local ok, err = pcall(ns.ResetAddon, c.reset == "settings")
			if not ok then return "error: " .. tostring(err) end
		end
		-- (The reload: the probe's timer never runs; what was saved comes
		-- back as the saved settings, then the login.)
		timers = {}
		W.Fire("PLAYER_LOGOUT")
		-- (Loaded as the game does: CinematicDB as the reset left it, made
		-- whole at ADDON_LOADED; a nil one is a fresh install.)
		W.Fire("ADDON_LOADED", "CinematicDev")
		W.Fire("PLAYER_LOGIN")
		ns.db, CinematicDB = db, db
		db.skyrideProbeRestore = nil
		return cvars[c.probe] == YOURS[c.probe] and "yours" or (cvars[c.probe] .. " (the probe's)")
	end,
	pins = {
		{ "", "yours" },
	},
})
ns.db, CinematicDB = db, db
