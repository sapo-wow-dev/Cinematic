-- A built-in trigger's tabs switched off (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-cameras-builtin-trigger-tabs.md):
--   python -I Tools/offline/run.py Tools/offline/builtintabsmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/builtintabsmatrix.lua forever --base <ref>
-- The Stand still trigger (one of ours) named by its source, its camera set;
-- none of its Triggers page tabs off, or its Starts, Ends, Timing or Scenes
-- tab off (tabOn:Trigger:<id>:<part>); its Timing tab's Wait 0 or 5 sec. Each
-- cell: the trigger the pick gives at once (Triggers.lua's ns.PickTrigger).
-- The rule: as your own triggers (CustomTriggers.lua): Starts or Scenes off,
-- it never starts; Timing off, no wait, cooldown or chance; Ends off changes
-- nothing here (ours end as their thing does).
local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local db = ns.db
local now = 100
GetTime = function() return now end -- luacheck: ignore 121
local id = ns.OursTriggerId("Still")
local function CameraOf() return "afk" end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "builtin-trigger-tabs",
	fixed = { client = client },
	dims = {
		{ "off", { "none", "starts", "ends", "timing", "scenes" } },
		{ "wait", { "0", "5" } },
	},
	cell = function(c)
		ns.PickTrigger({}, CameraOf) -- (nothing named: the last pick and its wait forgotten)
		for _, part in ipairs({ "starts", "ends", "timing", "scenes" }) do
			db[("tabOn:Trigger:%s:%s"):format(id, part)] = part ~= c.off
		end
		db.cameraRows[id .. ".delay"] = c.wait ~= "0" and tonumber(c.wait) or nil
		ns.triggerLibVersion = (ns.triggerLibVersion or 0) + 1
		now = now + 10
		local key = ns.PickTrigger({ still = true }, CameraOf)
		return key or "none"
	end,
	pins = {
		{ "", "Still" },
		{ "wait=5", "none" }, -- (its wait: not yet)
		{ "off=timing", "Still" },
		{ "off=starts", "none" },
		{ "off=scenes", "none" },
	},
})
