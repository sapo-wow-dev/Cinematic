-- Death Vision's Test by its switches (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-death-vision-test-master.md):
--   python -I Tools/offline/run.py Tools/offline/deathtestmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/deathtestmatrix.lua forever --base <ref>
-- Death Vision's page on or off, Visions > General's Enable Visions on or
-- off, its Test running or not (alive, so only the Test can show it). Each
-- cell: whether its screen comes up a moment later. The rule: page off (its
-- own switch or a master over it) means none, its Test too.
local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local db = ns.db
if ns.CreateDeathScreen then ns.CreateDeathScreen() end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "death-vision-test",
	fixed = { client = client },
	dims = {
		{ "page", { "on", "off" } },
		{ "visions", { "on", "off" } },
		{ "test", { "running", "no" } },
	},
	cell = function(c)
		db.enabled = true
		db.deathScreen = c.page == "on"
		db.visionsAll = c.visions == "on"
		ns.deathVisionTest = nil
		ns.UpdateDeathVision(120) -- (anything from the last cell gone)
		if c.test == "running" then ns.TestDeathVision() end
		ns.UpdateDeathVision(0.5)
		local shows = ns.DeathScreenBusy()
		ns.deathVisionTest = nil
		ns.UpdateDeathVision(120)
		return shows and "shows" or "none"
	end,
	pins = {
		{ "", "none" },
		{ "page=on visions=on test=running", "shows" },
	},
})
