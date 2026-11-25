-- Questie's ready recipe (Tools/addon-kit/addons/Questie.md), for the addon
-- kit's stages and any Questie test. What our support covers: its tracker
-- (Questie_BaseFrame, its header and quest lines: Support/Questie.lua,
-- Support/QuestieTracker.lua) with its quest item buttons, and its minimap
-- icons (Support/QuestieMinimap.lua). Ready = its tracker on screen, open,
-- with a quest in it. Its item buttons need a quest with a usable item and
-- its minimap icons a quest giver near you: those are places, not settings,
-- so they're in the notes, not here. No test of its own yet: the addon kit's
-- probes and its rows check cover the tracker. Dev copy only.
local _, ns = ...

local function Profile()
	local questie = _G.Questie
	return questie and questie.db and questie.db.profile
end

local function Char()
	local questie = _G.Questie
	return questie and questie.db and questie.db.char
end

-- Its tracker module (QuestieLoader is global; its modules are reachable).
local function Tracker()
	local loader = _G.QuestieLoader
	if not (loader and loader.ImportModule) then return nil end
	local ok, tracker = pcall(loader.ImportModule, loader, "QuestieTracker")
	return ok and type(tracker) == "table" and tracker or nil
end

local function Tracked()
	local tracker = Tracker()
	if not (tracker and tracker.GetNumTrackedQuests) then return 0 end
	local ok, count = pcall(tracker.GetNumTrackedQuests)
	return ok and tonumber(count) or 0
end

-- The first quest in your quest log that isn't done yet (a done one can be
-- hidden by its "hide complete quests" option), else the first quest at all.
local function QuestToTrack()
	local log = C_QuestLog
	if not (log and log.GetNumQuestLogEntries and log.GetInfo) then return nil end
	local okCount, count = pcall(log.GetNumQuestLogEntries)
	if not okCount or type(count) ~= "number" then return nil end
	local first
	for i = 1, count do
		local ok, info = pcall(log.GetInfo, i)
		if ok and type(info) == "table" and not info.isHeader and type(info.questID) == "number" and info.questID > 0 then
			local okDone, done = pcall(log.IsComplete or error, info.questID)
			if okDone and not done then return info.questID end
			first = first or info.questID
		end
	end
	return first
end

-- Its tracker is on (trackerEnabled, on to start with; turning it on takes a
-- reload: its own Enable reloads) and shows the quests it tracks. It tracks
-- every quest in your log to start with (autoTrackQuests); a quest is
-- tracked by the game's own call, which it hooks (C_QuestLog.AddQuestWatch,
-- QuestieTracker.lua:1261). In instances it folds itself up (on to start with).
ns.TestKit.DefineAddonReady("Questie", {
	about = "its quest tracker on screen and open, with a quest in it",
	ready = function()
		local profile = Profile()
		if not profile then return false, "Questie's settings aren't loaded yet" end
		if not profile.trackerEnabled then return false, "its tracker is turned off (takes a reload to turn on)" end
		local base = _G.Questie_BaseFrame
		if not base then return false, "its tracker isn't made yet" end
		if IsInInstance() then return false, "its tracker folds up or hides in instances: step outside" end
		local char = Char()
		if char and char.isTrackerExpanded == false then return false, "its tracker is folded up" end
		if Tracked() == 0 then return false, "no quest tracked (is your quest log empty?)" end
		return ns.Flag(base:IsShown()), "its tracker is hidden"
	end,
	make = function(r)
		local profile = Profile()
		if not profile then return end
		if not profile.trackerEnabled then
			r:Keep("QuestieTrackerWasOff", true)
			profile.trackerEnabled = true
			r:Log("turned Questie's tracker on (trackerEnabled)")
			r:WaitFor("Questie's tracker was off: turned on. Reload so it takes.",
				{ check = function() return false end, buttons = { { kind = "reload" } } })
			return
		end
		local tracker = Tracker()
		local char = Char()
		if char and char.isTrackerExpanded == false and tracker and tracker.Expand and not IsInInstance() then
			r:Keep("QuestieTrackerWasFolded", true)
			pcall(tracker.Expand, tracker)
			r:Log("opened Questie's folded-up tracker")
		end
		if Tracked() == 0 and C_QuestLog and C_QuestLog.AddQuestWatch then
			local questID = QuestToTrack()
			if questID then
				r:Keep("QuestieTrackedQuest", questID)
				pcall(C_QuestLog.AddQuestWatch, questID)
				r:Log(("tracked quest %d for Questie's tracker (the game's AddQuestWatch)"):format(questID))
			end
		end
		r:Sleep(1)
	end,
	putBack = function(extra)
		local said = {}
		local questID = tonumber(extra.QuestieTrackedQuest)
		if questID and C_QuestLog and C_QuestLog.RemoveQuestWatch then
			pcall(C_QuestLog.RemoveQuestWatch, questID)
			said[#said + 1] = ("quest %d untracked again"):format(questID)
		end
		local tracker = Tracker()
		local char = Char()
		if extra.QuestieTrackerWasFolded and tracker and tracker.Collapse and char and char.isTrackerExpanded then
			pcall(tracker.Collapse, tracker)
			said[#said + 1] = "Questie's tracker folded up again"
		end
		local profile = Profile()
		if extra.QuestieTrackerWasOff and profile then
			profile.trackerEnabled = false
			said[#said + 1] = "Questie's tracker off again (from the next reload)"
		end
		return #said > 0 and table.concat(said, "; ") or nil
	end,
	guide = {
		"Step outside any dungeon or raid (its tracker folds up in instances).",
		"Quest log empty? Accept any quest from an NPC with a yellow ! over its head.",
	},
})
