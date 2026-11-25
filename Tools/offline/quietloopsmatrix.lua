-- Loops and events that work for their feature only while its page leaves it
-- on (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-25-quiet-loops.md):
--   python -I Tools/offline/run.py Tools/offline/quietloopsmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/quietloopsmatrix.lua forever --base <ref>
-- The part: Quest Vision's item button (its refresh loop, Visions/QuestItemButton.lua)
-- and target frame quest icon (its 0.5 s loop, Visions/QuestMobs.lua), Damage
-- Vision's display (woken at a fight's edge, Visions/DamageVision.lua), Roll
-- Vision's loot events (Visions/RollWindow.lua). Its page on or off, and its
-- own tick (the two Quest Vision parts). Each cell: "work" (the loop on, the
-- display woken, the loot history read or logged) or "none". The rule: work
-- only while the part can show.
local client = arg and arg[1] or "forever"
local tickers, historyReads = {}, 0
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	UnitAffectingCombat = function() return false end
	C_Timer.NewTicker = function(_, fn)
		local handle = { fn = fn }
		function handle.Cancel() handle.cancelled = true end
		tickers[#tickers + 1] = handle
		return handle
	end
	C_LootHistory = {
		GetAllEncounterInfos = function() historyReads = historyReads + 1 return {} end,
		GetSortedDropsForEncounter = function() historyReads = historyReads + 1 return {} end,
		GetSortedInfoForDrop = function() historyReads = historyReads + 1 return nil end,
		GetInfoForEncounter = function() historyReads = historyReads + 1 return nil end,
	}
	-- luacheck: pop
end
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db
ns.lastCinematic = true

local function From(fn, file, upvalue)
	local seen = {}
	local function Walk(f, depth)
		if depth > 6 or seen[f] or type(f) ~= "function" then return false end
		seen[f] = true
		local info = debug.getinfo(f, "S")
		if info and info.source and info.source:find(file, 1, true) then
			if not upvalue then return true end
			for i = 1, 60 do
				local name = debug.getupvalue(f, i)
				if not name then break end
				if name == upvalue then return true end
			end
		end
		for i = 1, 60 do
			local name, value = debug.getupvalue(f, i)
			if not name then break end
			if Walk(value, depth + 1) then return true end
			if type(value) == "table" and Walk(rawget(value, "run"), depth + 1) then return true end
		end
		return false
	end
	return Walk(fn, 0)
end
local function UpdateFrame(file, upvalue)
	for _, frame in ipairs(wow.frames) do
		local update = frame._scripts and frame._scripts.OnUpdate
		if update and From(update, file, upvalue) then return frame, update end
	end
end
local function TickerOn(file)
	for _, handle in ipairs(tickers) do
		if not handle.cancelled and From(handle.fn, file) then return true end
	end
	return false
end
local function EventFrame(file, event)
	for _, frame in ipairs(wow.frames) do
		local onEvent = frame._scripts and frame._scripts.OnEvent
		local info = onEvent and debug.getinfo(onEvent, "S")
		if info and info.source:find(file, 1, true) and frame._events[event] then return frame end
	end
end
local function Send(frame, ...)
	if frame then pcall(frame._scripts.OnEvent, frame, ...) end
end

local PARTS = {
	itemButton = function(c)
		db.questItemButton = c.tick == "on"
		-- (A pass first: the login's one refresh done, the button hidden with no quest item.)
		local frame, update = UpdateFrame("QuestItemButton.lua")
		if update then pcall(update, frame, 3) end
		ns.SyncFeatureLoops()
		return UpdateFrame("QuestItemButton.lua") ~= nil
	end,
	-- (A bag or quest event coming in: in a town they're constant. Run 5 of the
	-- in-game gating test saw them wake the button's loop with Quest Vision off.)
	itemEvent = function(c)
		db.questItemButton = c.tick == "on"
		local frame, update = UpdateFrame("QuestItemButton.lua")
		if update then pcall(update, frame, 3) end
		ns.SyncFeatureLoops()
		Send(EventFrame("QuestItemButton.lua", "BAG_UPDATE_DELAYED"), "BAG_UPDATE_DELAYED")
		return UpdateFrame("QuestItemButton.lua") ~= nil
	end,
	targetIcon = function(c)
		db.targetQuestIcon = c.tick == "on"
		if ns.RefreshTargetQuestIcon then pcall(ns.RefreshTargetQuestIcon) end
		ns.SyncFeatureLoops()
		return TickerOn("QuestMobs.lua")
	end,
	damage = function()
		local frame = UpdateFrame("DamageVision.lua", "Allowed")
		if not frame then return false end
		frame:Hide()
		Send(EventFrame("DamageVision.lua", "PLAYER_REGEN_ENABLED"), "PLAYER_REGEN_ENABLED")
		return frame:IsShown()
	end,
	roll = function()
		historyReads = 0
		local logged = 0
		local realLog = ns.Log
		ns.Log = function(category, ...)
			if category == "rolls" then logged = logged + 1 end
			return realLog(category, ...)
		end
		local frame = EventFrame("RollWindow.lua", "LOOT_HISTORY_UPDATE_DROP")
		Send(frame, "LOOT_HISTORY_UPDATE_DROP", 1, 2)
		Send(frame, "START_LOOT_ROLL", 1, 60)
		ns.Log = realLog
		return historyReads + logged > 0
	end,
}
local PAGES = { itemButton = "questVision", itemEvent = "questVision", targetIcon = "questVision", damage = "damageVision",
	roll = "rollWindow" }

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "quiet-loops",
	fixed = { client = client },
	dims = {
		{ "part", { "itemButton", "itemEvent", "targetIcon", "damage", "roll" } },
		{ "page", { "on", "off" } },
		{ "tick", { "on", "off" } },
	},
	cell = function(c)
		db.enabled, db.visions = true, true
		db.questVision, db.damageVision, db.rollWindow = false, false, false
		db[PAGES[c.part]] = c.page == "on"
		return PARTS[c.part](c) and "work" or "none"
	end,
	pins = {
		{ "", "none" },
		{ "part=itemButton page=on tick=on", "work" },
		{ "part=itemEvent page=on tick=on", "work" },
		{ "part=targetIcon page=on tick=on", "work" },
		{ "part=damage page=on", "work" },
		{ "part=roll page=on", "work" },
	},
})
