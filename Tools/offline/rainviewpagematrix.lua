-- The bad-weather view distance against its page (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-rain-view-page.md):
--   python -I Tools/offline/run.py Tools/offline/rainviewpagematrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/rainviewpagematrix.lua forever --base <ref>
-- Reduce view distance in bad weather at 100% (rainViewScale, on the Weather
-- page), then the Weather page on or off, Enable Visual Effects on or off,
-- CineMode on or off, and rain falling or not. Each cell: whether the view
-- distance is wanted in ("in") or left as yours ("out").
-- The rule (page off = every setting on it off): in only in CineMode, in rain,
-- with the Weather page and Visual Effects both on.
local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local db = ns.db

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "rainview-page",
	fixed = { client = client },
	dims = {
		{ "page", { "on", "off" } },
		{ "effects", { "on", "off" } },
		{ "cine", { "on", "off" } },
		{ "rain", { "yes", "no" } },
	},
	cell = function(c)
		if not ns.RainViewDebug then return "no RainViewDebug" end
		db.enabled = true
		db.rainViewScale = 1
		db.weatherPage = c.page == "on"
		db.visualEffects = c.effects == "on"
		ns.lastCinematic = c.cine == "on"
		local intensity = ns.BadWeatherIntensity
		ns.BadWeatherIntensity = function() return c.rain == "yes" and 1 or 0 end
		local _, want = ns.RainViewDebug()
		ns.BadWeatherIntensity = intensity
		ns.lastCinematic = false
		return (want or 0) > 0 and "in" or "out"
	end,
	pins = {
		{ "", "out" },
		{ "page=on effects=on cine=on rain=yes", "in" },
	},
})
