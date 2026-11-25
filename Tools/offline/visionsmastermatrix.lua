-- Enable Visions as a master switch (the audit kit's matrix, Tools/offline/matrix.lua;
-- fix card Tools/audits/2026-11-25-visions-master.md):
--   python -I Tools/offline/run.py Tools/offline/visionsmastermatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/visionsmastermatrix.lua forever --base <ref>
-- Enable Visions (Visions > General, visionsAll) on or off, a Vision page's
-- own switch (Damage Vision's) on or off, and how things got there: set as
-- saved now ("live"), or Enable Visions turned off by the old cascade (which
-- switched the page off and noted it in hubKept) and the settings updates run
-- ("updated"). Each cell: whether Damage Vision runs (ns.Setting) and its own
-- switch as saved. The rule (the user, 2026-11-25: "Make Visions a master"):
-- with Enable Visions off no Vision runs, whatever its own switch says, and
-- its own switch stays as you left it; the old cascade's offs put back once.
local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local db = ns.db
db.enabled = true

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "visions-master",
	fixed = { client = client },
	dims = {
		{ "how", { "live", "updated" } },
		{ "visions", { "on", "off" } },
		{ "page", { "on", "off" } },
	},
	cell = function(c)
		db.visionsAll = c.visions == "on"
		db.damageVision = c.page == "on"
		db.hubKept = nil
		db.visionsMasterV3 = nil
		if c.how == "updated" then
			-- (The old cascade: Enable Visions off switched the page off and noted it.)
			if c.visions == "off" then
				db.hubKept = { Visions = c.page == "on" and { damageVision = true } or {} }
				db.damageVision = false
			end
			ns.RunMigrations()
		end
		local runs = ns.Setting("damageVision") and true or false
		return ("runs=%s own=%s"):format(runs and "yes" or "no", db.damageVision and "on" or "off")
	end,
	pins = {
		{ "visions=on page=on", "runs=yes own=on" },
		{ "visions=on page=off", "runs=no own=off" },
		{ "visions=off page=on", "runs=no own=on" },
		{ "visions=off page=off", "runs=no own=off" },
	},
})
