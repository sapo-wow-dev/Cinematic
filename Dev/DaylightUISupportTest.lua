-- DaylightUI's ready recipe (Support/DaylightUI.lua): what its Advanced
-- Frames rows cover, set up so a test sees real frames. Notes on how it
-- works: Tools/addon-kit/addons/DaylightUI.md (code read, not yet proven by a
-- run).
-- Ready means: its setup guide and options window closed; its default-off
-- parts on (cursor ring, data bar, quest marker and arrow, the damage meter
-- and threat meter in their own windows); a meter window of your own; a quest
-- picked for the game's marker; and its test mode on, so the flight timer,
-- loot feed, threat meter, buff reminder, leader tab and quest progress show
-- their samples. A part that isn't loaded is skipped.
-- By code: its settings are written in its module tables (as its options do,
-- but without DaylightUI:Set, which would mark a character that isn't set up
-- as set up), test mode through DaylightUI.SetTestMode (what /dui test does),
-- the quest pick through the game's C_SuperTrack. All put back after.
-- By your clicks: a meter window (its call is inside the addon), its setup
-- guide, and a quest in your log if it's empty. Its pull timer only shows
-- for a countdown: a test step does that (DaylightUI.RunCommand("leader test
-- party")), not this recipe. Same on both clients. Dev copy only.
local _, ns = ...

local function DUI() return _G.DaylightUI end

-- The settings it needs, by its module: { module, dotted path, value }.
local WANT = {
	{ "QoL", "cursorRing", true },
	{ "QoL", "cursorRingWhen", "always" },
	{ "InfoPanel", "databar.enabled", true },
	{ "InfoPanel", "meter.detached", true },
	{ "InfoPanel", "threat.at", "free" },
	{ "Quests", "nav.marker", true },
	{ "Quests", "nav.arrow", true },
}
-- Its test mode's parts whose samples our rows cover (its tick box can hide them).
local PARTS = { "flight", "loot", "questprogress", "meter", "threat", "buffreminder", "party", "datatexts" }

-- A module that's up, or nil (each is its own addon, and can be off).
local function Module(name)
	local dui = DUI()
	if not (dui and dui.GetModule) then return nil end
	local ok, mod = pcall(dui.GetModule, dui, name)
	if ok and type(mod) == "table" and mod.enabled and type(mod.db) == "table" then return mod end
end

-- Its saved table for a module, up or not (the same table as mod.db).
local function ModuleTable(name)
	local mod = Module(name)
	if mod then return mod.db end
	local ok, t = pcall(function() return DUI().DB.Active().modules[name] end)
	return ok and type(t) == "table" and t or nil
end

local function Get(t, path)
	for part in path:gmatch("[^%.]+") do
		if type(t) ~= "table" then return nil end
		t = t[part]
	end
	return t
end

local function Put(t, path, value)
	local keys = {}
	for part in path:gmatch("[^%.]+") do keys[#keys + 1] = part end
	for i = 1, #keys - 1 do
		if type(t[keys[i]]) ~= "table" then return false end
		t = t[keys[i]]
	end
	t[keys[#keys]] = value
	return true
end

-- Tells a module its settings changed, as its options do (out of fights only:
-- it lays out frames). Quests wants the path.
local function Refresh(name, path)
	local mod = Module(name)
	if not mod or InCombatLockdown() or type(mod.OnSettingChanged) ~= "function" then return end
	pcall(mod.OnSettingChanged, mod, path)
end

local function Shown(name)
	local frame = _G[name]
	return frame and frame.IsShown and ns.Flag(frame:IsShown()) or false
end

local function OptionsOpen()
	local ok, open = pcall(function() return DUI().OptionsPanel.IsShown() end)
	return ok and open == true
end

local function HiddenParts()
	local ok, t = pcall(function() return DUI().DB.Root().testHidden end)
	return ok and type(t) == "table" and t or nil
end

local function SuperTracked()
	local st = _G.C_SuperTrack
	if not (st and st.GetSuperTrackedQuestID) then return nil end
	local ok, id = pcall(st.GetSuperTrackedQuestID)
	return ok and type(id) == "number" and id or nil
end

-- The first quest in your log (not a header), or nil.
local function FirstQuest()
	local log = _G.C_QuestLog
	if not (log and log.GetNumQuestLogEntries and log.GetInfo) then return nil end
	local ok, n = pcall(log.GetNumQuestLogEntries)
	if not ok or type(n) ~= "number" then return nil end
	for i = 1, n do
		local got, info = pcall(log.GetInfo, i)
		if got and type(info) == "table" and not info.isHeader and type(info.questID) == "number" and info.questID > 0 then
			return info.questID
		end
	end
end

ns.TestKit.DefineAddonReady("DaylightUI", {
	about = "its setup guide closed, its default-off parts on, a meter window, a quest picked, its test mode on",
	ready = function()
		if not DUI() then return false, "DaylightUI's core isn't there" end
		if Shown("DaylightUIInstaller") then return false, "its setup guide is open" end
		if OptionsOpen() then return false, "its options window is open (it holds its frames at full)" end
		for _, want in ipairs(WANT) do
			if Module(want[1]) and Get(Module(want[1]).db, want[2]) ~= want[3] then
				return false, ("%s %s isn't %s"):format(want[1], want[2], tostring(want[3]))
			end
		end
		local info = Module("InfoPanel")
		local order = info and Get(info.db, "meters.order")
		if info and not (type(order) == "table" and #order > 0) then return false, "no meter window of your own" end
		if Module("Quests") and (SuperTracked() or 0) == 0 then return false, "no quest picked for the game's marker" end
		if DUI().testMode ~= true then return false, "its test mode is off (a fight ends it)" end
		local hidden = HiddenParts()
		for _, part in ipairs(PARTS) do
			if hidden and hidden[part] then return false, "its test mode hides the " .. part .. " sample" end
		end
		return true
	end,
	make = function(r)
		local dui = DUI()
		if not dui then return end
		if InCombatLockdown() then
			r:Log("in a fight: DaylightUI's setup waits (its frames lay out out of fights only)")
			return
		end
		local changed = {}
		for _, want in ipairs(WANT) do
			local mod = Module(want[1])
			local old = mod and Get(mod.db, want[2])
			if mod and old ~= want[3] then
				r:Keep("dl:set:" .. want[1] .. ":" .. want[2], old)
				if Put(mod.db, want[2], want[3]) then
					changed[want[1]] = want[2]
					r:Log(("DaylightUI %s %s = %s"):format(want[1], want[2], tostring(want[3])))
				end
			end
		end
		for name, path in pairs(changed) do Refresh(name, path) end
		if Module("Quests") and (SuperTracked() or 0) == 0 then
			local id = FirstQuest()
			if id and pcall(_G.C_SuperTrack.SetSuperTrackedQuestID, id) then
				r:Keep("dl:superTrack", id)
				r:Log("picked quest " .. id .. " for the game's marker")
			end
		end
		local hidden = HiddenParts()
		for _, part in ipairs(PARTS) do
			if hidden and hidden[part] then
				r:Keep("dl:hidden:" .. part, true)
				hidden[part] = nil
			end
		end
		if dui.testMode ~= true and type(dui.SetTestMode) == "function" then
			r:Keep("dl:testMode", true)
			local ok, on = pcall(dui.SetTestMode, true)
			r:Log("DaylightUI test mode (as /dui test): " .. tostring(ok and on))
		end
		r:Sleep(1)
	end,
	putBack = function(extra)
		local dui = DUI()
		if not dui then return end
		local said, changed = {}, {}
		for key, old in pairs(extra) do
			local name, path
			if type(key) == "string" then name, path = key:match("^dl:set:([^:]+):(.+)$") end
			local t = name and ModuleTable(name)
			local value = old
			if value == "<nil>" then value = nil end
			if t and Put(t, path, value) then
				changed[name] = path
				said[#said + 1] = name .. " " .. path
			end
		end
		for name, path in pairs(changed) do Refresh(name, path) end
		local hidden = HiddenParts()
		for _, part in ipairs(PARTS) do
			if extra["dl:hidden:" .. part] and hidden then hidden[part] = true end
		end
		local picked = extra["dl:superTrack"]
		local st = _G.C_SuperTrack
		if type(picked) == "number" and SuperTracked() == picked and st and st.SetSuperTrackedQuestID then
			pcall(st.SetSuperTrackedQuestID, 0)
			said[#said + 1] = "quest pick"
		end
		if extra["dl:testMode"] and dui.testMode == true and type(dui.SetTestMode) == "function" then
			pcall(dui.SetTestMode, false)
			said[#said + 1] = "test mode off"
		end
		if #said == 0 then return nil end
		return "DaylightUI put back: " .. table.concat(said, ", ")
	end,
	guide = {
		"Its setup guide is open: close it with its X, top right (Play now there sets this character up for good, with a Reload).",
		"Type /dui to open Daylight UI's options.",
		"Click Info Panel, then Meters.",
		"Click New window and pick Damage (remove it later with its Delete, clicked twice).",
		"Close Daylight UI's options with its X.",
		"Empty quest log? Pick up any quest from a quest giver (a yellow !).",
		"Its sample frames went away (a fight ends them)? Type /dui test.",
	},
})
