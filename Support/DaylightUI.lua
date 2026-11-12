-- Cinematic: DaylightUI, a whole-UI suite: a core (DaylightUI) and one addon
-- per part. It swaps the game's unit frames, action bars, buffs, chat and the
-- like for its own, which fade with the frames they stand in for and follow
-- the same rows on the Standard Frames page. Its parts with no game frame to
-- follow get rows of their own on the Advanced Frames page.
--
-- Its core has one fade engine for all its parts: each part registers its
-- areas (DaylightUI.Fade.Register: a key and a function handing out the
-- area's frames, many of them unnamed), and from then on that engine sets
-- their alpha. Those areas are what's faded here, found through that same
-- list. Its own frames are hooked; the game's frames it sets (the chat
-- frames, the quest tracker, the micro menu) are followed.
local _, ns = ...
local L = ns.L

-- Advanced Frames rows: one frame each. (from: the row that held it with
-- others till 2026-11-12, whose settings it starts with: ns.SplitAddonRows.)
for _, known in ipairs({
	{
		key = "dlMeter1", from = "dlMeters", addon = "DaylightUI_InfoPanel",
		label = "DaylightUI damage meter 1", short = "DaylightUI meter 1",
		about = L["its first damage meter window"],
		note = L["Its info panel (XP bar and minimap) follows the Minimap row on the HUD page; " ..
			"its unit frames, bars, buffs, chat and quest tracker follow the rows of the frames they replace."],
		names = { "DaylightUIDamageMeter" },
	},
	{
		key = "dlMeter2", from = "dlMeters", addon = "DaylightUI_InfoPanel",
		label = "DaylightUI damage meter 2", short = "DaylightUI meter 2",
		about = L["its second damage meter window"],
		names = { "DaylightUIDamageMeter2" },
	},
	{
		key = "dlThreat", addon = "DaylightUI_InfoPanel",
		label = "DaylightUI threat meter", short = "DaylightUI threat",
		about = L["its threat meter window"],
		names = { "DaylightUIThreatMeterFrame" },
	},
	{
		key = "dlFlightTimer", from = "dlQoL", addon = "DaylightUI_QoL",
		label = "DaylightUI flight timer", short = "DaylightUI flight timer",
		about = L["its flight timer"],
		names = { "DaylightUIFlightTimer" },
	},
	{
		key = "dlLootFeed", from = "dlQoL", addon = "DaylightUI_QoL",
		label = "DaylightUI loot feed", short = "DaylightUI loot feed",
		about = L["its loot feed"],
		names = { "DaylightUILootFeed" },
	},
	{
		key = "dlReminder", addon = "DaylightUI_Buffs",
		label = "DaylightUI buff reminder", short = "DaylightUI reminder",
		about = L["its missing-buff reminder"],
		names = { "DaylightUIBuffReminderHolder" },
	},
	{
		key = "dlPull", addon = "DaylightUI_UnitFrames",
		label = "DaylightUI pull timer", short = "DaylightUI pull",
		about = L["its pull timer"],
		note = L["Its cast bar isn't faded, like the game's."],
		names = { "DaylightUIPullTimer" },
	},
	{
		key = "dlQuestArrow", from = "dlQuestNav", addon = "DaylightUI_Quests",
		label = "DaylightUI quest arrow", short = "DaylightUI arrow",
		about = L["its quest arrow"],
		names = { "DaylightUIQuestArrow" },
	},
	{
		key = "dlQuestMarker", from = "dlQuestNav", addon = "DaylightUI_Quests",
		label = "DaylightUI quest marker", short = "DaylightUI marker",
		about = L["its quest marker"],
		names = { "DaylightUIQuestMarker" },
	},
	{
		key = "dlQuestProgress", addon = "DaylightUI_Quests",
		label = "DaylightUI quest progress", short = "DaylightUI progress",
		about = L["its quest progress lines over the world"],
		names = { "DaylightUIQuestProgress" },
	},
	{
		key = "dlDataBar", addon = "DaylightUI_InfoPanel",
		label = "DaylightUI data bar", short = "DaylightUI data bar",
		about = L["its data bar along the bottom of the screen"],
		names = { "DaylightUIDataBar" },
	},
	{
		key = "dlCursorRing", addon = "DaylightUI_QoL",
		label = "DaylightUI cursor ring", short = "DaylightUI cursor ring",
		about = L["its ring around the mouse cursor"],
		names = { "DaylightUICursorRing" },
	},
	{
		key = "dlLeaderTab", addon = "DaylightUI_UnitFrames",
		label = "DaylightUI leader tab", short = "DaylightUI leader",
		about = L["its group leader tab on the left edge of the screen"],
		names = { "DaylightUILeaderTab" },
	},
}) do
	known.suite, known.hookAlpha = "DaylightUI", true
	table.insert(ns.ADDON_FRAMES, known)
end

-- (Frames those rows fade: left out of the areas below.)
local OWN_ROWS = {}
for _, known in ipairs(ns.ADDON_FRAMES) do
	if known.suite == "DaylightUI" then
		for _, name in ipairs(known.names or {}) do
			OWN_ROWS[name] = true
		end
	end
end

-- Its fade areas by Standard Frames row: the row and the fade group. Bars
-- 1-8 aren't here: their holders have no name (so no row of their own), so
-- their buttons, named, fade instead (below).
local AREAS = {
	["UnitFrames.player"] = { "player", "player" },
	["UnitFrames.pet"] = { "petframe", "player" },
	["UnitFrames.target"] = { "target", "target" },
	["UnitFrames.targettarget"] = { "tot", "target" },
	["UnitFrames.focus"] = { "focus", "target" },
	["UnitFrames.focustarget"] = { "focustot", "target" },
	["UnitFrames.party"] = { "party", "party" },
	["UnitFrames.raid"] = { "raidplayers", "raidplayers" },
	-- (Its bars at your feet, and the battleground's enemy flag carriers.)
	["UnitFrames.personal"] = { "prd", "prd" },
	["UnitFrames.arena"] = { "flags", "flags" },
	-- (Its Cooldown Manager layout.)
	["ActionBars.cdm"] = { "cooldowns", "cooldowns" },
	["Chat.side"] = { "chat", "chat" },
	["InfoPanel.xp"] = { "xp", "bars" },
	["Buffs.buffs"] = { "buffs", "buffs" },
	["Buffs.debuffs"] = { "buffs", "buffs" },
	["ActionBars.stance"] = { "stance", "bars" },
	["ActionBars.pet"] = { "pet", "bars" },
	["ActionBars.possess"] = { "mainbar", "bars" },
	["ActionBars.totem"] = { "totems", "totems" },
	["ActionBars.totemTimers"] = { "totems", "totems" },
	["ActionBars.bagBar"] = { _G.BagsBar and "bags" or "micro", "bars" },
	["ActionBars.microMenu"] = { "micro", "bars" },
	["Chat.chat"] = { "chat", "chat" },
	-- (The info panel holds the minimap, its XP bar and the meters.)
	["InfoPanel.panel"] = { "minimap", "minimap" },
	["InfoPanel.tracker"] = { "quests", "quests" },
	["Quests.tracker"] = { "quests", "quests" },
}

-- Its bars 1-8, by the game's bar each stands in for (Standard Frames row,
-- fade group).
local BARS = {
	{ "mainbar", "bars" }, { "bottomleft", "bars" }, { "bottomright", "bars" }, { "right1", "sidebars" },
	{ "right2", "sidebars" }, { "bar6", "bars" }, { "bar7", "bars" }, { "bar8", "bars" },
}

local areas = {} -- key -> its frames function, as each part registers it
local named = {} -- frame name -> true once given its row

local function Own(name)
	return name:find("^DaylightUI") ~= nil
end

-- An area's frame: its own by name with the row (hooked), unnamed ones as
-- found, and the game's (already faded with their own rows) followed.
local function AddAreaFrame(frame, row, group)
	if type(frame) ~= "table" or type(frame.GetName) ~= "function" or (frame.IsForbidden and frame:IsForbidden()) then
		return
	end
	local name = frame:GetName()
	if name and OWN_ROWS[name] then
		return
	elseif name then
		if not named[name] then
			named[name] = true
			if Own(name) then
				ns.FadeWithRow(row, group, { name }, true, true)
			else
				ns.FollowOwnAlpha({ name })
			end
		end
	elseif not ns.IsFaded(frame) then
		ns.AddFoundFrame(frame, group, true, true)
	end
end

local function ScanAreas()
	for key, frames in pairs(areas) do
		local spot = AREAS[key]
		local ok, list = pcall(frames)
		if spot and ok and type(list) == "table" then
			for _, frame in ipairs(list) do
				AddAreaFrame(frame, spot[1], spot[2])
			end
		end
	end
end

ns.WhenAddonLoads("DaylightUI", function()
	local fade = _G.DaylightUI and _G.DaylightUI.Fade
	if type(fade) ~= "table" or type(fade.Register) ~= "function" then
		return
	end
	-- (Its parts register as they're enabled, at login: after this.)
	hooksecurefunc(fade, "Register", function(def)
		if type(def) == "table" and type(def.key) == "string" and type(def.frames) == "function" then
			areas[def.key] = def.frames
		end
	end)
	ns.AddScanner(ScanAreas)
	-- Its quest tracker sets its item buttons' holder (screen-sized) to the
	-- tracker's alpha by hand.
	ns.FadeWithRow("quests", "quests", { "DaylightUIQuestItems" }, true, true)
end)

ns.WhenAddonLoads("DaylightUI_ActionBars", function()
	local rows = {}
	for num, bar in ipairs(BARS) do
		local row = { bar[1], bar[2] }
		for i = 1, 12 do
			row[i + 2] = "DaylightUIBar" .. num .. "Button" .. i
		end
		rows[num] = row
	end
	ns.FadeWithRows(rows)
end)

-- Its own Edit Mode layout: once a character's set up with it (or is on
-- one of its layouts), it puts that layout back on every login, asking for a
-- reload. A profile's layout of ours switching it away each login too made
-- the two take turns, so its layout is left to it (Layouts.lua). A
-- character that said "not now" to its setup, on another layout, isn't
-- kept: profiles' layouts work there as without it.
ns.WhenAddonLoads("DaylightUI", function()
	ns.layoutKeeper = function()
		local DUI = _G.DaylightUI
		local editMode, installer = DUI and DUI.EditMode, DUI and DUI.Installer
		if not editMode then
			return nil
		end
		local okSet, state = pcall(function() return installer and installer.State() end)
		local okOn, on = pcall(editMode.AnyActive)
		if (okSet and state == "installed") or (okOn and on) then
			return "DaylightUI"
		end
		return nil
	end
end)

ns.WhenAddonLoads("DaylightUI_UnitFrames", function()
	ns.FadeWithRow("swing", "swing", { "DaylightUISwingTimer" }, true, true)
	ns.AddPortraitFrame("DaylightUIFrame_player")
	-- Its cast bars standing apart from their unit frames (named only then):
	-- yours with the Cast bar row, the others with their unit's.
	ns.FadeWithRow("castbar", "castbar", { "DaylightUICastBar_player" }, true, true)
	ns.FadeWithRow("target", "target", { "DaylightUICastBar_target" }, true, true)
	ns.FadeWithRow("focus", "target", { "DaylightUICastBar_focus" }, true, true)
end)

-- Its Quality of Life part has its own version of some of Cinematic's
-- features. While its own is on, it wins and Cinematic's stands aside (the
-- player's pick, 2026-11-12): its AFK screen and campfire scene over those
-- scenes' cameras, its zone title, level-up and reputation banners over
-- those cards, and its object glow (soft targeting settings of its own) over
-- Quest Vision's object glow and Hide object icons. Its error text and quest
-- progress lines need nothing: they draw instead of the game's, which is all
-- Cinematic hides.
ns.WhenAddonLoads("DaylightUI_QoL", function()
	local function QoLOn(key)
		return function()
			local DUI = _G.DaylightUI
			if DUI and DUI.Get and DUI:Get("QoL", key) == true then
				return "DaylightUI"
			end
			return nil
		end
	end
	for feature, key in pairs({
		["scene:AFK"] = "afkScreen",
		["scene:Campfire"] = "campfire",
		["card:zone"] = "zoneTitle",
		["card:levelUp"] = "levelUp",
		["card:reputation"] = "repBanner",
		questObjectGlow = "objectGlow",
		hideObjectIcons = "objectGlow",
	}) do
		ns.AddFeatureYield(feature, QoLOn(key))
	end
end)

-- Its nameplates are its own frames, one put on each game plate that shows a
-- unit (parented to it), with the game's unit frame kept at alpha 0 under
-- it. So the fade leaves that unit frame be (ns.addonPlateHidden: setting
-- its alpha would show the game's plate under its own) and goes on its plate
-- instead. It sets that plate's alpha itself too (back to full as a plate
-- appears, and its Fade other plates), so it's hooked: ours times its own
-- (ns.SetPlateFrameAlpha). Its plates are pooled and move from plate to
-- plate: one moved takes the alpha of the plate it lands on.
do
	local plateAlpha = setmetatable({}, { __mode = "k" }) -- [game plate] = its fade, below 1
	local hooked = setmetatable({}, { __mode = "k" })
	local LABEL = "DaylightUI plate alpha"

	local function Usable(frame)
		return type(frame) == "table" and not (frame.IsForbidden and frame:IsForbidden())
	end

	-- Its plate on a game plate: the child that has that plate's unit frame
	-- as the frame it hid.
	local function Ours(plate)
		local unitFrame = plate.UnitFrame
		if not unitFrame then
			return nil
		end
		for _, child in ipairs({ plate:GetChildren() }) do
			if Usable(child) and child.nameplate == plate and child.gameFrame == unitFrame then
				return child
			end
		end
		return nil
	end

	local function Hook(ours)
		if hooked[ours] then
			return
		end
		hooked[ours] = true
		hooksecurefunc(ours, "SetParent", function(self, parent)
			ns.SetPlateFrameAlpha(self, Usable(parent) and plateAlpha[parent] or nil, LABEL)
		end)
	end

	local function SetPlateAlpha(plate, alpha)
		alpha = alpha and alpha < 1 and alpha or nil
		plateAlpha[plate] = alpha
		local ours = Ours(plate)
		if ours then
			Hook(ours)
			ns.SetPlateFrameAlpha(ours, alpha, LABEL)
		end
	end

	ns.WhenAddonLoads("DaylightUI_Nameplates", function()
		ns.AddPlateAlpha(SetPlateAlpha)
		ns.AddPlateHidden(function(plate)
			return Ours(plate) ~= nil
		end)
		-- A new plate gets its plate in its own handler, which runs after
		-- ours (Effects: NAME_PLATE_UNIT_ADDED). Its own "last" handler runs
		-- after that one: the new unit's alpha goes on then, before it's drawn
		-- (the game plate's last alpha was its last unit's: a hidden enemy's
		-- plate flashed up for a frame).
		local DUI = _G.DaylightUI
		if DUI and DUI.RegisterEvent then
			DUI.RegisterEvent("NAME_PLATE_UNIT_ADDED", function(_, unit)
				local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit(unit)
				if ns.db and ns.db.enabled and type(plate) == "table"
					and not (plate.IsForbidden and plate:IsForbidden()) then
					ns.RefreshPlateAlpha(plate)
				end
			end, true)
		else
			ns.AfterPlateAdded(function(plate)
				SetPlateAlpha(plate, plateAlpha[plate])
			end)
		end
	end)
end
