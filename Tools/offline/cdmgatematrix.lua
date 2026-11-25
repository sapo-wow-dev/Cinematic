-- The Cooldown Manager's extras by its page and its bars' tabs (the audit kit's
-- matrix, Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-cdm-tab-gate.md):
--   python -I Tools/offline/run.py Tools/offline/cdmgatematrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/cdmgatematrix.lua forever --base <ref>
-- Every extra set on to start (Close the gaps, a bar row's keybinds, Show
-- numbers and Use the spell's cooldown, a tracked buff's Ring, stack counts),
-- then the page's switch and the bars' tabs (all of them) switched, and the
-- switches' own refresh (ns.SyncSwitches, each frames pass). Each cell: what
-- the Essential bar's icons get (center, keys, numbers, notBuff), and whether
-- the ring's and the stacks' watchers still run.
-- The rule (the user's): page off = all off; a tab is a container (off: all
-- in it off, the icons as the game has them).
local client = arg and arg[1] or "forever"
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local db = ns.db
local TABS = { "essential", "utility", "buffs", "bars" }

local function Reset()
	db.handleFrames, db.showInCooldowns, db.handleCooldowns = true, true, true -- (the HUD and its section on)
	for _, group in ipairs(TABS) do db[ns.CDM_TABS[group]] = true end
	db.cooldownGroupDefaults.essential = nil -- (Close the gaps: on until set)
	db.cooldownRowSettings = { essential = { keybinds = true, numbers = "show", notBuff = true },
		[12345] = { ring = "on" } }
	db.cooldownStacks = true
	ns.ApplyCooldownRing()
	ns.ApplyCooldownStacks()
	ns.SyncSwitches()
end
-- (The two watchers, found by their events while running.)
Reset()
local ring, stacks
for _, frame in ipairs(wow.frames) do
	local events = rawget(frame, "_events") or {}
	if events.UNIT_ABSORB_AMOUNT_CHANGED then ring = frame end
	if events.PLAYER_DEAD and events.UNIT_SPELLCAST_SUCCEEDED and events.PLAYER_ENTERING_WORLD
		and frame:GetScript("OnUpdate") then stacks = frame end
end
local function Running(frame)
	if not frame then return "none" end
	local events = rawget(frame, "_events") or {}
	return frame:IsShown() and (frame == stacks or next(events) ~= nil) and "run" or "stop"
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "cdm-gate",
	fixed = { client = client },
	dims = {
		{ "page", { "on", "off" } },
		{ "tab", { "on", "off" } },
	},
	cell = function(c)
		Reset()
		db.handleCooldowns = c.page == "on"
		for _, group in ipairs(TABS) do db[ns.CDM_TABS[group]] = c.tab == "on" end
		ns.SyncSwitches()
		local out = ("center=%s keys=%s nums=%s notBuff=%s ring=%s stacks=%s"):format(
			tostring(ns.CooldownGroupCentered("essential") and true or false),
			tostring(ns.CooldownRowSetting("keybinds", nil, "essential")),
			tostring(ns.CooldownRowSetting("numbers", nil, "essential")),
			tostring(ns.CooldownRowSetting("notBuff", nil, "essential")),
			Running(ring), Running(stacks))
		Reset()
		return out
	end,
	pins = {
		{ "", "center=false keys=false nums=untouched notBuff=false ring=stop stacks=stop" },
		{ "page=on tab=on", "center=true keys=true nums=show notBuff=true ring=run stacks=run" },
	},
})
