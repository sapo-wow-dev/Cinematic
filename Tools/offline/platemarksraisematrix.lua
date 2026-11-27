-- Smart marks' two raises, where a player can reach them on each client (the audit
-- kit's matrix, Tools/offline/matrix.lua; fix card Tools/audits/2026-11-26-plate-marks-raise.md):
--   python -I Tools/offline/run.py Tools/offline/platemarksraisematrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/platemarksraisematrix.lua retail --base <ref>
-- The marks over the plates move up or down by targetArrowY (with a plate) and
-- targetArrowBareY (without one). 679e735 moved them from Smart's All marks line to
-- Nameplate Layout's Smart marks part; Nameplate Layout is Forever's only (its page and
-- its editor frame aren't made on retail), so retail players lost them. Each cell: the
-- pages that hold the setting (ns.PageSettings, the pages built), "none" when none. The
-- rule (2026-11-26): retail has them on Smart (Nameplate Style's page), as before;
-- Forever keeps them on Layout only.

local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local pages = ns.PageSettings and ns.PageSettings() or {}

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "plate-marks-raise-" .. client,
	fixed = { client = client },
	dims = { { "key", { "targetArrowY", "targetArrowBareY" } } },
	cell = function(c)
		local found = {}
		for name, page in pairs(pages) do
			if page.keys and page.keys[c.key] ~= nil then found[#found + 1] = name end
		end
		table.sort(found)
		return #found > 0 and table.concat(found, ",") or "none"
	end,
	pins = {
		{ "client=forever", "Nameplate Layout" },
		{ "client=retail", "Nameplate Style" },
	},
})
