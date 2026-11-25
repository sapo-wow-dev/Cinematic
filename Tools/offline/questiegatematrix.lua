-- Questie's support gated, every state (the audit kit's matrix, Tools/offline/matrix.lua; fix cards
-- Tools/audits/2026-11-22-addons-questie-gate.md and 2026-11-23-addons-support-box-reload.md):
--   python -I Tools/offline/run.py Tools/offline/questiegatematrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/questiegatematrix.lua forever --base <ref>
-- Questie not installed, in at login or loaded late (after login), and its
-- support box on the Addons page: on, off (saved off: after the reload),
-- unticked this session with no reload yet, or ticked back on with no reload
-- yet. Each cell is its own login (a fresh load: a /reload). Each cell: whether
-- its setup ran (its tracker fades with the Quest tracker row) and which of
-- our paths reached into Questie's support: tooltip lines (tip), the No wait
-- for list (wait), the quest item button stepping aside (item), the target
-- frame's quest mark stepping aside (mark) and Questie's own target icon
-- hidden or put back (icon).
-- The rule: none of it without Questie; with it, everything as the box was at
-- login (it says it counts after a reload), so unticking it still lets our
-- put-back code run till the reload (ae2cda8), and ticking it back on brings
-- nothing back before one. (bdb2e1d gated tip, wait, item and mark on
-- ns.AddonUp and made AddonUp read the box live; ae2cda8 read it at login.)

local client = arg and arg[1] or "forever"
local loaded, saved = {}, nil
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	C_AddOns.IsAddOnLoaded = function(name) return loaded[name] == true end
	IsAddOnLoaded = C_AddOns.IsAddOnLoaded
	-- (The saved settings this login starts from: the last cell's are gone.)
	CinematicDB, CinematicCharDB = saved, nil
	-- luacheck: pop
end

-- A local of a file, found through the upvalues of ns's functions.
local function Local(ns, name)
	local seen = {}
	local function Walk(fn, depth)
		if type(fn) ~= "function" or seen[fn] or depth > 4 then return end
		seen[fn] = true
		for i = 1, 60 do
			local upName, value = debug.getupvalue(fn, i)
			if not upName then break end
			if upName == name and type(value) == "function" then return value end
			local found = Walk(value, depth + 1)
			if found then return found end
		end
	end
	for _, value in pairs(ns) do
		local found = Walk(value, 0)
		if found then return found end
	end
end

local function SetupRan(ns)
	for _, item in ipairs(ns.COMBAT_SHOW or {}) do
		if item.key == "quests" then
			for _, name in ipairs(item.frames or {}) do
				if name == "Questie_BaseFrame" then return true end
			end
		end
	end
	return false
end

local PATHS = { "tip", "wait", "item", "mark", "icon" }
local WATCH = { tip = "QuestieTooltipLines", wait = "QuestieObjectiveMob", item = "QuestieItemButton",
	mark = "QuestieMarks", icon = "QuestieTargetIcon" }

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "questie-gate",
	fixed = { client = client },
	dims = {
		{ "questie", { "none", "login", "late" } },
		{ "box", { "on", "off", "unticked", "reticked" } },
	},
	cell = function(c)
		loaded = { Questie = c.questie == "login" or nil }
		local offAtLogin = c.box == "off" or c.box == "reticked"
		saved = offAtLogin and { addonSupportOff = { Questie = true } } or nil
		local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
		local db = ns.db
		-- (Our paths into Questie's support, as play reaches them.)
		db.enabled, db.handleTooltips, db.tooltipNoWaitQuest, db.tooltipFullAfter = true, true, true, 2
		db.mouseover = true -- (the Tooltips page is under Mouseover's Show: Audit 2026-11-25, OK'd by the user)
		db.questVision, db.questItemButton, db.targetQuestIcon = true, true, true
		local tooltip = wow.CreateFrame("GameTooltip")
		rawset(tooltip, "GetUnit", function() return "Young Wolf", "mouseover" end)
		local LinesToCut, SkipsWait = Local(ns, "LinesToCut"), Local(ns, "SkipsWait")
		if not (LinesToCut and SkipsWait) then return "tooltip passes not found" end
		local function Play()
			-- (Tooltips: a mob's lines and the No wait for list.)
			ns.IsQuestMob = function() return false end
			pcall(LinesToCut, tooltip, 1, "mouseover", false)
			pcall(SkipsWait, tooltip)
			-- (A tracked quest with an item, near: our button, unless Questie has one up.)
			ns.QuestLogItems = function() return { { questID = 7, itemID = 5, index = 1 } } end
			local log = C_QuestLog
			C_QuestLog = { -- luacheck: ignore 111 121
				GetQuestWatchType = function() return 0 end,
				GetDistanceSqToQuest = function() return 100, true end,
				GetQuestObjectives = function() return {} end,
			}
			if ns.RefreshQuestItemButton then pcall(ns.RefreshQuestItemButton) end
			C_QuestLog = log -- luacheck: ignore 111 121
			-- (A quest mob targeted: the target frame's mark.)
			ns.IsQuestMob = function() return true end
			local exists = UnitExists
			UnitExists = function() return true end -- luacheck: ignore 121
			if ns.RefreshTargetQuestIcon then pcall(ns.RefreshTargetQuestIcon) end
			UnitExists = exists -- luacheck: ignore 121
		end
		-- (A moment of play after login, then the Addons page.)
		Play()
		if c.box == "unticked" then db.addonSupportOff.Questie = true end
		if c.box == "reticked" then db.addonSupportOff.Questie = nil end
		if c.questie == "late" then
			loaded.Questie = true
			wow.Fire("ADDON_LOADED", "Questie")
		end
		local asked = {}
		for path, fnName in pairs(WATCH) do
			local real = ns[fnName]
			if real then ns[fnName] = function(...) asked[path] = true return real(...) end end
		end
		Play()
		local list = {}
		for _, path in ipairs(PATHS) do
			if asked[path] then list[#list + 1] = path end
		end
		return ("setup=%s asks=%s"):format(SetupRan(ns) and "ran" or "no",
			#list > 0 and table.concat(list, ",") or "none")
	end,
	pins = {
		-- (Questie not in: nothing of its support.)
		{ "questie=none", "setup=no asks=none" },
		-- (In, its support on: all of it.)
		{ "box=on", "setup=ran asks=tip,wait,item,mark,icon" },
		-- (Saved off: after the reload, as if it weren't in.)
		{ "box=off", "setup=no asks=none" },
		-- (Unticked, no reload yet: as at login, so our put-back code runs.)
		{ "box=unticked", "setup=ran asks=tip,wait,item,mark,icon" },
		-- (Ticked back on, no reload yet: still off till the reload.)
		{ "box=reticked", "setup=no asks=none" },
		{ "questie=none", "setup=no asks=none" },
	},
})
