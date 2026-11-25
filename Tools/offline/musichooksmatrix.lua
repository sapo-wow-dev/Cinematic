-- The music's watch on the game's music settings with the Audio page off
-- (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-25-atmosphere-idle-cost.md):
--   python -I Tools/offline/run.py Tools/offline/musichooksmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/musichooksmatrix.lua forever --base <ref>
-- The Audio page (musicInCinematic) on or off, Enable Visual Effects on or
-- off, Cinematic handling the music right now or not (a fade of its own, a
-- setting of yours held), then the music's volume or its on/off changed from
-- outside Cinematic (the game's Sound settings, another addon), or the
-- game's own CVAR_UPDATE for it. Each cell: whether Music.lua's watch did
-- work for it (read who wrote it, debugstack; or the trace's log check).
-- The rule: with the page off and nothing of the music's handled or held,
-- the watch does nothing (a cheap first check); otherwise as before.
local client = arg and arg[1] or "forever"
local cvars = { Sound_MusicVolume = "0.55", Sound_EnableMusic = "1" }
local work = 0
local function FromMusic()
	local info = debug.getinfo(3, "S")
	return info and info.source and info.source:find("Music.lua", 1, true) ~= nil
end
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function()
	-- luacheck: push ignore 111 112 113 121 122
	C_CVar = {
		SetCVar = function(name, value) cvars[name] = tostring(value) end,
		GetCVar = function(name) return cvars[name] end,
		GetCVarDefault = function(name) return name == "Sound_MusicVolume" and "0.4" or "0" end,
	}
	SetCVar = function(name, value) return C_CVar.SetCVar(name, value) end
	GetCVar = function(name) return cvars[name] or "0" end
	GetCVarDefault = C_CVar.GetCVarDefault
	hooksecurefunc = function(a, b, c)
		local tbl, name, fn = a, b, c
		if type(a) == "string" then tbl, name, fn = _G, a, b end
		local orig = tbl[name]
		tbl[name] = function(...)
			local r = { orig(...) }
			fn(...)
			return unpack(r)
		end
	end
	debugstack = function()
		if FromMusic() then work = work + 1 end
		return "[C]: in function 'SetCVar'\n[C]: ?"
	end
	-- luacheck: pop
end)
local db = ns.db
local logDetailOn = ns.LogDetailOn
ns.LogDetailOn = function(...)
	if FromMusic() then work = work + 1 end
	return logDetailOn(...)
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "music-hooks",
	fixed = { client = client },
	dims = {
		{ "page", { "on", "off" } },
		{ "effects", { "on", "off" } },
		{ "handling", { "no", "yes" } },
		{ "change", { "volume", "enable", "event" } },
	},
	cell = function(c)
		if not ns.music then return "no music" end
		db.musicInCinematic = c.page == "on"
		db.visualEffects = c.effects == "on"
		local managing = ns.music.managing
		ns.music.managing = c.handling == "yes"
		work = 0
		if c.change == "volume" then
			SetCVar("Sound_MusicVolume", "0.6")
		elseif c.change == "enable" then
			SetCVar("Sound_EnableMusic", "1")
		else
			wow.Fire("CVAR_UPDATE", "Sound_MusicVolume", "0.6")
		end
		local did = work
		ns.music.managing = managing
		cvars.Sound_MusicVolume = "0.55"
		return did > 0 and "work=yes" or "work=no"
	end,
	pins = {
		{ "", "work=yes" },
		-- (The page off, or Visual Effects off, and nothing handled: nothing.)
		{ "page=off handling=no", "work=no" },
		{ "effects=off handling=no", "work=no" },
	},
})
