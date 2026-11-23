-- The weather effects' update loop (Atmosphere/WeatherFX.lua), every state
-- (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-23-weather-loop-strength.md):
--   python -I Tools/offline/run.py Tools/offline/weatherloopmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/weatherloopmatrix.lua --base <ref>
-- One effect (frost, rain on the lens, lightning, heavier weather) with its
-- Show in row saying yes or no (Core's effectWanted), its strength Off or up,
-- its own switch on or off and the Weather page on or off. Each cell: whether
-- the loop runs (every frame) and whether the effect draws.
-- The rule (release review 2026-11-23, the user's OK to fix): the loop runs
-- only while an effect can draw: its row says yes, its strength is up, its
-- switch and the Weather page on. Off at strength 0 (the default), the page
-- off or its switch off: no loop at all.
local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local frame = _G.CinematicWeatherFX
local KEYS = ns.WEATHER_FX_KEYS

local function Running()
	ns.WakeFeatureLoop(frame)
	return frame:GetScript("OnUpdate") ~= nil
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "weatherfx-loop",
	fixed = { client = client },
	dims = {
		{ "kind", { "frost", "rainlens", "lightning", "density" } },
		{ "row", { "yes", "no" } },
		{ "strength", { "off", "up" } },
		{ "switch", { "on", "off" } },
		{ "page", { "on", "off" } },
	},
	cell = function(c)
		local db = ns.db
		db.enabled, db.visualEffects = true, true
		ns.effectWanted = ns.effectWanted or {}
		for kind, keys in pairs(KEYS) do
			db[keys.strength] = 0
			db[keys.switch] = true
			ns.effectWanted[kind] = false
		end
		db.weatherPage = c.page == "on"
		db[KEYS[c.kind].switch] = c.switch == "on"
		db[KEYS[c.kind].strength] = c.strength == "up" and (c.kind == "density" and 2 or 0.6) or 0
		ns.effectWanted[c.kind] = c.row == "yes"
		-- (Nothing left over from the cell before: one quiet pass with none wanted.)
		return "loop=" .. (Running() and "on" or "off")
	end,
	pins = {
		{ "", "loop=off" },
		{ "row=yes strength=up switch=on page=on", "loop=on" },
	},
})
