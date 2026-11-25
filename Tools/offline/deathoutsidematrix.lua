-- Death Vision by its Allow outside CineMode tick (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-death-vision-outside-cine.md):
--   python -I Tools/offline/run.py Tools/offline/deathoutsidematrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/deathoutsidematrix.lua forever --base <ref>
-- Death Vision's page on, its Allow outside CineMode tick on or off (the
-- CineMode page's Death Vision row: Always / CineMode), CineMode on or off.
-- Each cell: whether Death Vision may show (ns.Setting("deathScreen"), what
-- its screen goes by). The rule, as every other Vision's: with the tick off,
-- only in CineMode.
local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local db = ns.db
db.enabled, db.deathScreen = true, true

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "death-vision-outside-cine",
	fixed = { client = client },
	dims = {
		{ "tick", { "on", "off" } },
		{ "cine", { "on", "off" } },
	},
	cell = function(c)
		db.outsideCineDeath = c.tick == "on"
		ns.lastCinematic = c.cine == "on"
		local on = ns.Setting("deathScreen")
		ns.lastCinematic = nil
		return on and "may show" or "held"
	end,
	pins = {
		{ "", "may show" },
		{ "tick=off cine=off", "held" },
	},
})
