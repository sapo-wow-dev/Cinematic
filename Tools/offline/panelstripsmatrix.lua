-- The game's windows rearranged on each open and close (QoL/CenterPanels.lua),
-- with the switches off after a drag strip was made (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-panel-strips.md):
--   python -I Tools/offline/run.py Tools/offline/panelstripsmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/panelstripsmatrix.lua forever --base <ref>
-- A drag strip made on the bags first (Drag windows on as a window opened);
-- then Drag windows on or off, Open windows clear of your character on or
-- off, the Quality of life page on or off; then the change applied either by
-- a window opening or by the page's refresh (its switch, a profile: the new
-- ns.RefreshPanelStrips, nothing in the old code), then another window opens.
-- Each cell: whether that last one still rearranged the windows (a pass a
-- frame later asked for), and whether the strip is up.
-- The rule (page off = every setting on it off, and no cost): with neither
-- on, a window opening does nothing, and the strip is down.
local client = arg and arg[1] or "forever"
local afters = 0
local loaded = false
local function Install(wow)
	-- luacheck: push ignore 111 112 113 121 122
	hooksecurefunc = function(a, b, c)
		local tbl, name, fn = a, b, c
		if type(a) == "string" then tbl, name, fn = _G, a, b end
		local orig = tbl[name]
		rawset(tbl, name, function(...)
			local r = { orig(...) }
			fn(...)
			return unpack(r)
		end)
	end
	GetUIPanel = function() return nil end
	ShowUIPanel = function() end
	C_Timer = {
		-- (After the load, run at once: the frame later's pass.)
		After = function(_, fn)
			afters = afters + 1
			if loaded then pcall(fn) end
		end,
		NewTicker = function() return { Cancel = function() end } end,
		NewTimer = function() return { Cancel = function() end } end,
	}
	ContainerFrameCombinedBags = wow.CreateFrame("Frame", "ContainerFrameCombinedBags", UIParent)
	-- luacheck: pop
end
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
loaded = true
local db = ns.db
local bags = ContainerFrameCombinedBags

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "panel-strips",
	fixed = { client = client },
	dims = {
		{ "drag", { "on", "off" } },
		{ "center", { "on", "off" } },
		{ "page", { "on", "off" } },
		{ "by", { "window", "refresh" } },
	},
	cell = function(c)
		db.handleQuality, db.dragPanels, db.centerPanels = true, true, false
		ShowUIPanel() -- (the strip made, or put up again)
		local strip = bags._children[1]
		if not strip then return "no strip made" end
		db.dragPanels, db.centerPanels = c.drag == "on", c.center == "on"
		db.handleQuality = c.page == "on"
		if c.by == "window" then
			ShowUIPanel()
		elseif ns.RefreshPanelStrips then
			ns.RefreshPanelStrips()
		end
		local up = strip:IsShown()
		afters = 0
		ShowUIPanel()
		return "rearranged=" .. (afters > 0 and "yes" or "no") .. " strip=" .. (up and "up" or "down")
	end,
	pins = {
		{ "", "rearranged=no strip=down" },
		{ "page=on drag=on", "rearranged=yes strip=up" },
		{ "page=on center=on drag=off", "rearranged=yes strip=down" },
	},
})
