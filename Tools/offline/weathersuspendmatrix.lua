-- The weather effects after a safety stop or /cine stop (the audit kit's
-- matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-25-weather-suspend.md):
--   python -I Tools/offline/run.py Tools/offline/weathersuspendmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/weathersuspendmatrix.lua forever --base <ref>
-- One weather effect (frost, rain on the lens, lightning, heavier weather) at
-- a strength, its row on, all the way in; then Cinematic carrying on, or
-- stopped for the session (ns.Suspend, as a safety stop or /cine stop), then
-- 30 seconds more. Each cell: whether it still shows (frost, rain: drawn on a
-- shown frame; lightning: a flash or thunder in those 30 seconds; heavier
-- weather: the game's weatherDensity held).
-- The rule: stopped, Cinematic puts everything back and nothing of its own
-- shows or plays till /cine resume.
local client = arg and arg[1] or "forever"
local now = 100
local cvars = { weatherDensity = "1" }
local sounds = 0
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function()
	-- luacheck: push ignore 111 112 113 121 122
	GetTime = function() return now end
	PlaySoundFile = function() sounds = sounds + 1 return true end
	local get, set = GetCVar, SetCVar
	GetCVar = function(name) if cvars[name] then return cvars[name] end return get and get(name) end
	SetCVar = function(name, value)
		if cvars[name] then cvars[name] = tostring(value) return end
		if set then return set(name, value) end
	end
	C_CVar = C_CVar or {}
	C_CVar.GetCVar, C_CVar.SetCVar = GetCVar, SetCVar
	InCombatLockdown = function() return false end
	-- luacheck: pop
end)
local frame = _G.CinematicWeatherFX
local KEYS = ns.WEATHER_FX_KEYS
local TEXTURE = { frost = "frost", rainlens = "drops" }

-- Seconds of frames, at 10 a second: the loop's update, only while its frame
-- is shown (as in the game: a hidden frame's update never runs).
local function Run(seconds)
	for _ = 1, seconds * 10 do
		now = now + 0.1
		ns.WakeFeatureLoop(frame)
		local update = frame:GetScript("OnUpdate")
		if update and frame:IsShown() then update(frame, 0.1) end
	end
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "weatherfx-suspend",
	fixed = { client = client },
	dims = {
		{ "kind", { "frost", "rainlens", "lightning", "density" } },
		{ "stop", { "none", "suspended" } },
	},
	cell = function(c)
		local db = ns.db
		db.enabled, db.visualEffects, db.weatherPage = true, true, true
		ns.effectWanted = ns.effectWanted or {}
		for kind, keys in pairs(KEYS) do
			db[keys.strength] = 0
			db[keys.switch] = true
			ns.effectWanted[kind] = false
		end
		db[KEYS[c.kind].strength] = c.kind == "density" and 3 or 0.8
		ns.effectWanted[c.kind] = true
		Run(25) -- (all the way in; a storm's first flash comes within 22 seconds)
		ns.suspendQuiet = true
		if c.stop == "suspended" then ns.Suspend("weathersuspendmatrix") end
		sounds, ns.lightningFlashes = 0, 0
		-- (Core's tick, stopped while suspended, would ask the rows again: kept as asked.)
		Run(30)
		local shows
		if c.kind == "density" then
			shows = cvars.weatherDensity == "3"
		elseif c.kind == "lightning" then
			shows = (ns.lightningFlashes or 0) > 0 or sounds > 0
		else
			local tex = ns.weatherFxTextures[TEXTURE[c.kind]]
			shows = frame:IsShown() and tex:IsShown() and (tex:GetAlpha() or 0) > 0
		end
		-- (Put back for the next cell: resumed, nothing wanted, faded out.)
		if c.stop == "suspended" then ns.Resume() end
		ns.suspendQuiet = nil
		for kind in pairs(KEYS) do ns.effectWanted[kind] = false end
		Run(15)
		return shows and "shows" or "gone"
	end,
	pins = {
		{ "stop=none", "shows" },
		{ "stop=suspended", "gone" },
	},
})
