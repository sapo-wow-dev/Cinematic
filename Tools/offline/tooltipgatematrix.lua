-- The Tooltips page's fade and After countdown with the switch it's under (the
-- audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-25-tooltips-gate.md):
--   python -I Tools/offline/run.py Tools/offline/tooltipgatematrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/tooltipgatematrix.lua forever --base <ref>
-- Fade in/out and After (2 s) set, the Tooltips page on or off, Mouseover's
-- Show (the switch it's under) on or off; then the game shows its tooltip.
-- Each cell: whether it faded in (its alpha set from 0) and whether the After
-- countdown started (a game timer).
-- The rule (page off = every setting on it off; its parent off too): only
-- with both on does the tooltip fade or count down.
local client = arg and arg[1] or "forever"
local timers = 0
local now = 1000
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	GetTime = function() return now end
	C_Timer = {
		After = function() end,
		NewTicker = function() return { Cancel = function() end } end,
		NewTimer = function() timers = timers + 1; return { Cancel = function() end } end,
	}
	-- luacheck: pop
end
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db
local tip = GameTooltip
local fadedFrom0 = false
rawset(tip, "SetAlpha", function(_, a) if a == 0 then fadedFrom0 = true end end)

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "tooltips-gate",
	fixed = { client = client },
	dims = {
		{ "page", { "on", "off" } },
		{ "show", { "on", "off" } },
	},
	cell = function(c)
		db.enabled, db.handleFrames = true, true
		db.tooltipFadeTime, db.tooltipFullAfter = 0.3, 2
		db.handleTooltips = c.page == "on"
		db.mouseover = c.show == "on"
		local onShow = tip:GetScript("OnShow")
		local onHide = tip:GetScript("OnHide")
		if not onShow then return "no OnShow hook" end
		if onHide then pcall(onHide, tip) end
		now = now + 100 -- (a new tooltip, long after the last)
		timers, fadedFrom0 = 0, false
		local ok, err = pcall(onShow, tip)
		if not ok then return "error " .. tostring(err) end
		return "fade=" .. (fadedFrom0 and "yes" or "no") .. " countdown=" .. (timers > 0 and "yes" or "no")
	end,
	pins = {
		{ "", "fade=no countdown=no" },
		{ "page=on show=on", "fade=yes countdown=yes" },
	},
})
