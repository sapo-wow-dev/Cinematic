-- The death song against the Audio page (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-death-song-page.md):
--   python -I Tools/offline/run.py Tools/offline/deathsongpagematrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/deathsongpagematrix.lua forever --base <ref>
-- The Death event's song ticked, then the Audio page (musicInCinematic) on or
-- off, Enable Visual Effects on or off, and the game's own music on or off;
-- you die (the death camera starts its song) and the music's tick runs.
-- Each cell: whether the song plays, and the game's music switched on for it.
-- The rule (page off = every setting on it off, the user 2026-11-25): the
-- song only with the Audio page and Visual Effects on; then with your game
-- music off too (switched on for it, put back after).
local client = arg and arg[1] or "forever"
local cvars = { Sound_MusicVolume = "0.55", Sound_EnableMusic = "1" }
local played = 0
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function()
	-- luacheck: push ignore 111 112 113 121 122
	C_CVar = C_CVar or {}
	C_CVar.SetCVar = function(name, value) cvars[name] = tostring(value) end
	C_CVar.GetCVar = function(name) return cvars[name] end
	SetCVar = function(name, value) return C_CVar.SetCVar(name, value) end
	GetCVar = function(name) return cvars[name] or "0" end
	PlayMusic = function() played = played + 1 return true end
	StopMusic = function() end
	-- luacheck: pop
end)
local db = ns.db

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "deathsong-page",
	fixed = { client = client },
	dims = {
		{ "page", { "on", "off" } },
		{ "effects", { "on", "off" } },
		{ "music", { "on", "off" } },
	},
	cell = function(c)
		if not ns.SetDeathSong then return "no death song" end
		local triggerSetting = ns.TriggerSetting
		ns.TriggerSetting = function(event, key)
			if event == "Death" and key == "music" then return true end
			return triggerSetting and triggerSetting(event, key)
		end
		db.musicInCinematic = c.page == "on"
		db.visualEffects = c.effects == "on"
		cvars.Sound_EnableMusic = c.music == "on" and "1" or "0"
		played = 0
		ns.SetDeathSong(true)
		for _ = 1, 3 do ns.UpdateMusic(true, 0.1) end
		local song = played > 0
		local switched = c.music == "off" and cvars.Sound_EnableMusic == "1"
		-- (Put back: the song ends, your settings back.)
		ns.SetDeathSong(false)
		for _ = 1, 3 do ns.UpdateMusic(true, 0.1) end
		local back = cvars.Sound_EnableMusic == (c.music == "on" and "1" or "0")
		ns.TriggerSetting = triggerSetting
		db.musicInCinematic, db.visualEffects = true, true
		return ("song=%s%s%s"):format(song and "plays" or "none", switched and " musicSwitchedOn" or "",
			back and "" or " notPutBack")
	end,
	pins = {
		{ "", "song=none" },
		{ "page=on effects=on music=on", "song=plays" },
		{ "page=on effects=on music=off", "song=plays musicSwitchedOn" },
	},
})
