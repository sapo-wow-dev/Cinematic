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
local ADDON_NAME, ns = ...
local L = ns.L

-- Advanced Frames rows: one frame each. (from: the row that held it with
-- others till 2026-11-12, whose settings it starts with: ns.SplitAddonRows.)
for _, known in ipairs({
	{
		key = "dlMeter1", from = "dlMeters", addon = "DaylightUI_InfoPanel",
		label = "DaylightUI damage meter 1", short = "DaylightUI meter 1",
		about = L["its first damage meter window"],
		names = { "DaylightUIDamageMeter" },
	},
	-- (Its second meter became the first of the windows you add, 1.9: any
	-- number, meters, threat and summaries, each DaylightUIMeterWindow_<id>.
	-- One row for all of them, as for Details' windows; key kept, so the
	-- second meter's settings carry over.)
	{
		key = "dlMeter2", from = "dlMeters", addon = "DaylightUI_InfoPanel",
		label = "DaylightUI meter windows", short = "DaylightUI windows",
		about = L["the meter windows you add to it"],
		patterns = { "^DaylightUIMeterWindow_" },
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

-- (Frames those rows fade, by name or pattern: left out of the areas below.)
local OWN_ROWS, OWN_PATTERNS = {}, {}
for _, known in ipairs(ns.ADDON_FRAMES) do
	if known.suite == "DaylightUI" then
		for _, name in ipairs(known.names or {}) do
			OWN_ROWS[name] = true
		end
		for _, pattern in ipairs(known.patterns or {}) do
			OWN_PATTERNS[#OWN_PATTERNS + 1] = pattern
		end
	end
end
local function OwnRow(name)
	if OWN_ROWS[name] then return true end
	for _, pattern in ipairs(OWN_PATTERNS) do
		if name:find(pattern) then return true end
	end
	return false
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
	-- (Its party members' targets, beside their frames.)
	["UnitFrames.partyTarget"] = { "party", "party" },
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
	if type(frame) ~= "table" or type(frame.GetName) ~= "function" or not ns.Reachable(frame) then
		return
	end
	local name = frame:GetName()
	if name and OwnRow(name) then
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
	-- Its tracked recipes panel stands in for the game's tracker's recipes
	-- while its quest tracker is on: it goes with that row. (No fade area of
	-- its own.)
	ns.FadeWithRow("quests", "quests", { "DaylightUICraftTrack" }, true, true)
end)

-- Its buff bars (DaylightUIBuffs, DaylightUIDebuffs) come through its fade
-- areas above. Not in them: the popout a grouped buff opens on mouseover (a
-- second aura container, with a backing frame of no name, its .back), and
-- the private debuff slots under the debuff bar. They go with the Buffs row.
-- (Its container's alpha is set only outside fights by its own code: tested
-- in a fight before calling it done.)
ns.WhenAddonLoads("DaylightUI_Buffs", function()
	ns.FadeWithRow("buffs", "buffs", { "DaylightUIBuffsPopout", "DaylightUIDebuffsPrivate" }, true, true)
	ns.AddScanner(function()
		local popout = _G.DaylightUIBuffsPopout
		local back = type(popout) == "table" and popout.back
		if type(back) == "table" and type(back.SetAlpha) == "function" and not ns.IsFaded(back) then
			ns.AddFoundFrame(back, "buffs", true, true)
		end
	end)
end)

-- Its separate reputation bar at the bottom of the screen (its XP bar's
-- area doesn't hold it): with the Experience and reputation bars row.
ns.WhenAddonLoads("DaylightUI_InfoPanel", function()
	ns.FadeWithRow("xp", "bars", { "DaylightUIReputationBar" }, true, true)
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
	-- (Chained to a keeper set before it, as Leatrix Plus's is: its
	-- ADDON_LOADED can come first (DaylightUI loaded late), and replaced, its
	-- layout and a profile's took turns at every login. Audit 2026-11-22.)
	local before = ns.layoutKeeper
	ns.layoutKeeper = function()
		local DUI = _G.DaylightUI
		local editMode, installer = DUI and DUI.EditMode, DUI and DUI.Installer
		if not editMode then
			return before and before() or nil
		end
		local okSet, state = pcall(function() return installer and installer.State() end)
		local okOn, on = pcall(editMode.AnyActive)
		if (okSet and state == "installed") or (okOn and on) then
			return "DaylightUI"
		end
		return before and before() or nil
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
	-- Its combo points (a holder on UIParent its own fade sets with the target
	-- frame's): named here too, as a class without them never shows its area.
	ns.FadeWithRow("target", "target", { "DaylightUIComboPoints" }, true, true)
	named.DaylightUIComboPoints = true
end)

-- Its Quality of Life part has its own version of some of Cinematic's
-- features: its AFK screen and campfire scene (those scenes' cameras), its
-- zone title, level-up and reputation banners (those cards), and its object
-- glow (soft targeting settings of its own: Quest Vision's object glow and
-- Hide object icons). Whose plays is the Addon Conflicts pick (AddonSupport,
-- Conflicts.lua): its own while unpicked (the player's pick, 2026-11-12).
-- "Ours" holds its banner or screen at alpha 0 while Cinematic's is on. Its
-- error text and quest progress lines draw instead of the game's, which is
-- all Cinematic hides, but one: the "Discovered:" line under our Discovered
-- card (both at once, 2026-11-22), hidden below.
local LABEL = "DaylightUI"
local function DUI() return _G.DaylightUI end
local function QoLOn(key)
	return function()
		local dui = DUI()
		if dui and dui.Get and dui:Get("QoL", key) == true then
			return LABEL
		end
		return nil
	end
end
-- Its error text (DaylightUI_QoL/ErrorText.lua) draws the game's lines in
-- rows of its own, children of DaylightUIErrorText with a .text: the row
-- with our Discovered card's line goes (CardMoments.lua). Hidden, a row is
-- free for its next line. A secret line is never compared.
ns.DiscoveredLineHiders = ns.DiscoveredLineHiders or {}
table.insert(ns.DiscoveredLineHiders, function(text)
	local holder = _G.DaylightUIErrorText
	if type(holder) ~= "table" or not holder.GetChildren then return end
	for _, row in ipairs({ holder:GetChildren() }) do
		local line = type(row.text) == "table" and row.text.GetText and row.text:GetText()
		if not (issecretvalue and issecretvalue(line)) and line == text and ns.Flag(row:IsShown()) then
			row:Hide()
			ns.Log("card", "DaylightUI's Discovered line hidden: our card has it")
		end
	end
end)

ns.WhenAddonLoads("DaylightUI_QoL", function()
	-- Its zone title showing a place's name as you walk into an inn: our
	-- Rested card (the inn's name too) waits till it's gone, rather than
	-- both names at once (the user's pick, 2026-11-19).
	if ns.AddCardWait then
		ns.AddCardWait(function(id)
			local title = _G.DaylightUIZoneTitle
			if id == "rested" and type(title) == "table" and ns.Flag(title:IsVisible()) then
				return L["DaylightUI's zone title is showing"]
			end
			return nil
		end)
	end
	local function Scene(key)
		return function() return ns.TriggerRowNow(key) ~= nil end
	end
	local function Card(id)
		return function() return ns.CardOn(id) end
	end
	local function Glow()
		return ns.QuestVisionSetting("questObjectGlow") or ns.QuestVisionSetting("hideObjectIcons")
	end
	for _, each in ipairs({
		{ "scene:AFK", "afkScreen", "AFK scene", "scenes", Scene("AFK"), { "DaylightUIAfkScreen" },
			"What plays while you're away: Cinematic's AFK camera, or DaylightUI's AFK screen" },
		{ "scene:Campfire", "campfire", "Campfire scene", "scenes", Scene("Campfire"), { "DaylightUICampfire" },
			"What plays as you sit by a campfire: Cinematic's Campfire camera, or DaylightUI's campfire scene" },
		{ "card:zone", "zoneTitle", "Zone card", "scenes", Card("zone"), { "DaylightUIZoneTitle" },
			"The banner as you enter a new zone" },
		{ "card:levelUp", "levelUp", "Level-up card", "scenes", Card("levelUp"), { "DaylightUILevelUp" },
			"The banner as you gain a level" },
		{ "card:reputation", "repBanner", "Reputation card", "scenes", Card("reputation"), { "DaylightUIRepBanner" },
			"The banner as you reach a new standing with a faction" },
		{ "questObjectGlow", "objectGlow", "Object glow and icons", "quest", Glow, nil,
			"Herbs, ore and quest objects lighting up near you: Quest Vision's object glow and Hide object " ..
			"icons, or DaylightUI's object glow. Both set the game's soft targeting, so only one can", true },
	}) do
		local row = { key = each[1], addon = LABEL, label = each[3], group = each[4], ours = each[5],
			hide = each[6], about = each[7], noBoth = each[8] }
		ns.AddFeatureYield(each[1], QoLOn(each[2]), row)
		-- (Hide object icons goes with the glow: one row.)
		if each[1] == "questObjectGlow" then ns.AddFeatureYield("hideObjectIcons", QoLOn(each[2]), row) end
	end
	-- Its "Welcome to <place>" as you land from a flight (v1.9.6), against our
	-- Flight arrival card. It plays only with its flight timer on too (its
	-- welcome is on unless switched off).
	ns.AddFeatureYield("card:arrival", function()
		local dui = DUI()
		if dui and dui.Get and dui:Get("QoL", "flightTimer") == true and dui:Get("QoL", "flightWelcome") ~= false then
			return LABEL
		end
		return nil
	end, { key = "card:arrival", addon = LABEL, label = "Flight arrival card", group = "scenes", ours = Card("arrival"),
		hide = { "DaylightUIFlightWelcome" }, about = "The banner as you land from a flight" })
end)

-- Its looks against the Style hub's (Addon Conflicts' Style rows: one look
-- wins, no Both). Theirs: Cinematic's page stands aside while its own is on
-- (ns.StyleOn). Ours: Cinematic's look, and its own held at alpha 0 where it
-- can be (its tooltip and bubble backgrounds); its settings left be.
local TOOLTIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "EmbeddedItemTooltip" }
local function Shells(list)
	local dui = DUI()
	local get = dui and dui.Style and dui.Style.GetShell
	local out = {}
	if type(get) ~= "function" then return out end
	for _, frame in ipairs(list) do
		local ok, shell = pcall(get, frame)
		if ok and type(shell) == "table" then out[#out + 1] = shell end
	end
	return out
end
local function ModuleOn(name)
	local dui = DUI()
	local mod = dui and dui.GetModule and dui:GetModule(name)
	return type(mod) == "table" and mod.enabled and true or false
end

ns.WhenAddonLoads("DaylightUI_Tooltip", function()
	ns.AddConflict({ key = "style:tooltip", addon = LABEL, label = "Tooltip look", group = "style", noBoth = true,
		styleSwitch = "tooltipStyle",
		about = "How tooltips look: the Interface hub's Tooltip Style page, or DaylightUI's tooltips",
		theirs = function()
			local dui = DUI()
			local aside = dui and dui.PrettyAside and dui.PrettyAside.Draws and dui.PrettyAside.Draws()
			return ModuleOn("Tooltip") and not aside
		end,
		ours = function() return ns.StyleOn("tooltipStyle") end,
		hide = function()
			local list = {}
			for _, name in ipairs(TOOLTIPS) do
				if type(_G[name]) == "table" then list[#list + 1] = _G[name] end
			end
			return Shells(list)
		end,
		onPick = function() if ns.RefreshTooltipStyle then ns.RefreshTooltipStyle() end end })
end)

-- Its chat (DaylightUI_Chat/Chat.lua): one holder, DaylightUIChat, that its
-- fade area hands out in every style. In its own-window styles it draws the
-- lines there and keeps the game's windows at alpha 0 (Box.lua); in its
-- classic style the game's windows sit on it. Either way it's the panel of
-- the main chat window: a message peeking chat brings it up (ns.ClaimLinkPart,
-- UI/FrameLinks.lua), as for Glass. Unclaimed, the peek raised only the game's
-- window at alpha 0 and nothing showed (test q5a6f, 2026-11-24). (Its being
-- loaded also turns off Show just those messages: UI/Chat.lua.)
ns.AddonKitExpect("DaylightUI_Chat", "chat.linesOnly", "chatIsDefault", "false: its chat window draws the lines")
ns.AddonKitExpect("DaylightUI_Chat", "chat.linesOnly", "linesOnly",
	"false: a message brings up its window, no copy under it (2979131)")
ns.WhenAddonLoads("DaylightUI_Chat", function()
	ns.AddScanner(function()
		local holder, window = _G.DaylightUIChat, _G.ChatFrame1
		if type(holder) == "table" and type(window) == "table" and ns.Reachable(holder) then
			ns.ClaimLinkPart("DaylightUI", "chatwindow", holder, { window = window })
		end
	end)
end)

ns.WhenAddonLoads("DaylightUI_Chat", function()
	ns.AddConflict({ key = "style:bubbles", addon = LABEL, label = "Chat bubble look", group = "style", noBoth = true,
		styleSwitch = "bubblesStyle",
		about = "How chat bubbles look: the Interface hub's Chat Bubble Style page, or DaylightUI's bubbles",
		theirs = function()
			local dui = DUI()
			return dui and dui.Get and dui:Get("Chat", "bubbles") == true or false
		end,
		ours = function() return ns.StyleOn("bubblesStyle") end,
		hide = function()
			local list = {}
			local all = C_ChatBubbles and C_ChatBubbles.GetAllChatBubbles and C_ChatBubbles.GetAllChatBubbles()
			for _, bubble in pairs(type(all) == "table" and all or {}) do
				if type(bubble) == "table" and ns.Reachable(bubble) then
					local frame = bubble:GetChildren()
					if type(frame) == "table" and ns.Reachable(frame) then
						list[#list + 1] = frame
					end
				end
			end
			return Shells(list)
		end,
		onPick = function() if ns.RefreshBubbleStyle then ns.RefreshBubbleStyle() end end })
end)

ns.WhenAddonLoads("DaylightUI_InfoPanel", function()
	ns.AddConflict({ key = "style:minimap", addon = LABEL, label = "Minimap look", group = "style", noBoth = true,
		about = "Its square minimap: left as DaylightUI draws it, or also colored by the Style hub's Minimap " ..
			"page, which puts its ring and buttons in the theme's color",
		theirs = function()
			local dui = DUI()
			return dui and dui.Get and dui:Get("InfoPanel", "map.enabled") == true or false
		end,
		ours = function() return ns.StyleOn("minimapStyle") end,
		onPick = function() if ns.RefreshMinimapStyle then ns.RefreshMinimapStyle() end end })
end)

-- Its damage number font (DAMAGE_TEXT_FONT, set as it loads, after
-- Cinematic's) against the Combat Text Style page's Hide all the game's
-- floating text (a blank font: Core.lua). Theirs: its font. Ours: the blank
-- one again after each time it sets its own. The game reads it at login, so
-- either shows from the next game start.
do
	local BLANK = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Fonts\\Blank.ttf"
	local function OursOn()
		local db = ns.db
		-- (Its tab too, Combat Text Style's General. Audit 2026-11-25.)
		return db and db.hideWorldText and db.combatTextStyle and db.styleGeneral ~= false and ns.ModuleLoaded("style")
			and db["tabOn:Combat Text Style/page:1"] ~= false and true or false
	end
	local row
	local function Apply()
		if row and OursOn() and ns.ConflictPick(row) == "ours" then DAMAGE_TEXT_FONT = BLANK end
	end
	ns.WhenAddonLoads("DaylightUI", function()
		local dui = DUI()
		local fonts = dui and dui.GameFonts
		if type(fonts) ~= "table" then return end
		row = ns.AddConflict({ key = "style:damageFont", addon = LABEL, label = "Damage number font", group = "style",
			noBoth = true, restart = true,
			about = "The game's floating numbers: hidden by the Combat Text Style page's Hide all the game's " ..
				"floating text, or shown in DaylightUI's damage font. Takes effect the next time you start the " ..
				"game",
			theirs = function()
				return type(fonts.DamageWanted) == "function" and fonts.DamageWanted() ~= nil or false
			end,
			ours = OursOn, onPick = Apply })
		if type(fonts.Apply) == "function" then hooksecurefunc(fonts, "Apply", Apply) end
	end)
end

-- Its loot roll window (Skins, since 2.2: DaylightUIRollStack, on by
-- default) against Roll Vision's (Visions/RollWindow.lua): both showed at
-- every roll. One plays, by the Addon Conflicts pick (its own while
-- unpicked). Ours: its window held hidden. It keeps the game's roll popups
-- at alpha 0 under it either way. (Off with the controller UI: the game's
-- gamepad window rolls then.)
local function RollsTheirs()
	local dui = DUI()
	if not (dui and dui.Get and ModuleOn("Skins")) then return false end
	local input = _G.InputUtil
	if type(input) == "table" and type(input.IsGamepadUIEnabled) == "function" and input.IsGamepadUIEnabled() == true then
		return false
	end
	local ok, on = pcall(dui.Get, dui, "Skins", "rolls.enabled")
	return ok and on ~= false
end
ns.WhenAddonLoads("DaylightUI_Skins", function()
	ns.AddConflict({ key = "rolls", addon = LABEL, label = "Loot roll window", group = "windows",
		about = "Group loot rolls: Roll Vision's window, or DaylightUI's loot roll window",
		theirs = RollsTheirs,
		ours = function() return ns.Setting("rollWindow") end,
		hide = function()
			local stack = _G.DaylightUIRollStack
			return type(stack) == "table" and { stack } or {}
		end,
		onPick = function() if ns.RefreshRollWindow then ns.RefreshRollWindow() end end })
end)

-- Its key and macro texts on its own action buttons are its own switches:
-- the Standard Frames page's Hide keybinds and Hide macro names never reached
-- them, only the game's pet buttons it keeps in its pet bar. Those stand
-- aside for good (no pick), and the two checkboxes aren't shown (Options).
ns.WhenAddonLoads("DaylightUI_ActionBars", function()
	local function Theirs() return LABEL end
	ns.AddFeatureYield("hideKeybinds", Theirs)
	ns.AddFeatureYield("hideMacroText", Theirs)
	if ns.ApplyHideKeybinds then ns.ApplyHideKeybinds() end
end)

-- Not HUD frames, left alone: its setup and What's new window (and the
-- screen dim under it), its lines on the game's Escape menu, the "Welcome
-- back" line at login, and the outlines and light its login reveal draws
-- over its frames (unnamed: its Fade.revealOverlays).
ns.WhenAddonLoads("DaylightUI", function()
	ns.LeaveAlone({ "DaylightUIInstaller", "DaylightUIWelcomeHolder", "GameMenuFrame" })
	ns.AddScanner(function()
		local dui = DUI()
		local ui = dui and dui.InstallerUI
		if type(ui) == "table" and type(ui.Veil) == "function" then
			local ok, veil = pcall(ui.Veil)
			if ok then ns.LeaveAloneFrame(veil) end
		end
		local overlays = dui and type(dui.Fade) == "table" and dui.Fade.revealOverlays
		for _, overlay in ipairs(type(overlays) == "table" and overlays or {}) do
			ns.LeaveAloneFrame(overlay)
			if type(overlay) == "table" then ns.LeaveAloneFrame(overlay.shine) end
		end
	end)
end)

-- Its chat bubbles (DaylightUI_Chat/Bubbles.lua): a frame on UIParent drawn
-- over each game bubble (its .balloon) while that bubble is up, so it goes
-- with the game's bubbles and is left alone. Unnamed and kept in its own
-- list: found among UIParent's children, only while a bubble is up.
ns.WhenAddonLoads("DaylightUI_Chat", function()
	local bubbles = _G.C_ChatBubbles
	local seen = setmetatable({}, { __mode = "k" })
	ns.AddScanner(function()
		local all = bubbles and bubbles.GetAllChatBubbles and bubbles.GetAllChatBubbles()
		if type(all) ~= "table" or next(all) == nil then return end
		for _, child in ipairs({ UIParent:GetChildren() }) do
			if not seen[child] then
				seen[child] = true
				if ns.Reachable(child) and rawget(child, "balloon") ~= nil and rawget(child, "said") ~= nil then
					ns.LeaveAloneFrame(child)
				end
			end
		end
	end)
end)

-- The addon kit's expectations (Tools/addon-kit/diff.py): game frames it
-- puts away, moves or holds at alpha 0 because its own stand in (and fade
-- with those rows, above), and game functions it hooks (all hooksecurefunc:
-- ours still run).
ns.AddonKitExpect("DaylightUI_ActionBars", "*MainActionBar", "*", "parked in DaylightUIParkedBars: its bar 1 stands in")
ns.AddonKitExpect("DaylightUI_ActionBars", "*MultiBar*", "*", "parked in DaylightUIParkedBars: its bars 2-8 stand in")
ns.AddonKitExpect("DaylightUI_ActionBars", "touch.ActionButton_", "*", "parked with the main bar: its buttons stand in")
ns.AddonKitExpect("DaylightUI_ActionBars", "*Stance*", "parent", "parked: its stance bar stands in")
ns.AddonKitExpect("DaylightUI_ActionBars", "touch.PossessActionBar", "parent", "parked: its possess bar stands in")
ns.AddonKitExpect("DaylightUI_ActionBars", "*PetActionBar", "*", "the game's pet bar kept at alpha 0: its buttons sit in its pet bar")
ns.AddonKitExpect("DaylightUI_ActionBars", "touch.PetActionButton_", "*", "in DaylightUIPetBar, its pet bar (Pet bar row)")
ns.AddonKitExpect("DaylightUI_ActionBars", "*MainMenuBarVehicleLeaveButton", "*", "its own leave button stands in")
ns.AddonKitExpect("DaylightUI_ActionBars", "*BagsBar", "*", "its bag bar stands in")
ns.AddonKitExpect("DaylightUI_ActionBars", "touch.MainMenuBarBackpackButton", "visible", "with the game's bag bar: its bag bar stands in")
ns.AddonKitExpect("DaylightUI_ActionBars", "*MicroMenuContainer", "alpha", "its micro menu stands in")
ns.AddonKitExpect("DaylightUI_ActionBars", "*TotemFrame", "parent", "its totem bar holds it")
ns.AddonKitExpect("DaylightUI_ActionBars", "touch.PlayerFrame_ToPlayerArt", "sameAsLogin", "hooksecurefunc: ours still run")
ns.AddonKitExpect("DaylightUI_ActionBars", "addons.yields", "hideKeybinds", "its bars' own key texts: Hide keybinds stands aside")
ns.AddonKitExpect("DaylightUI_ActionBars", "addons.yields", "hideMacroText", "its bars' own macro texts: Hide macro names stands aside")
ns.AddonKitExpect("DaylightUI_UnitFrames", "*PlayerFrame", "*", "put away: its player frame stands in")
ns.AddonKitExpect("DaylightUI_UnitFrames", "*TargetFrame", "parent", "put away: its target frame stands in")
ns.AddonKitExpect("DaylightUI_UnitFrames", "*FocusFrame", "parent", "put away: its focus frame stands in")
ns.AddonKitExpect("DaylightUI_UnitFrames", "*PetFrame", "parent", "put away: its pet frame stands in")
ns.AddonKitExpect("DaylightUI_UnitFrames", "touch.PetFrameHappiness", "shown", "with the game's pet frame: its pet frame stands in")
ns.AddonKitExpect("DaylightUI_UnitFrames", "*PartyFrame", "*", "put away: its party frames stand in")
ns.AddonKitExpect("DaylightUI_UnitFrames", "*CompactRaidFrame*", "parent", "put away: its raid frames stand in")
ns.AddonKitExpect("DaylightUI_UnitFrames", "*ArenaEnemyFramesContainer", "parent", "put away: its arena frames stand in")
ns.AddonKitExpect("DaylightUI_UnitFrames", "*CastingBarFrame", "alpha", "at alpha 0: its cast bars stand in")
ns.AddonKitExpect("DaylightUI_UnitFrames", "*SwingTimer*Frame", "alpha", "at alpha 0: its swing timer stands in")
ns.AddonKitExpect("DaylightUI_Buffs", "*uffFrame", "*", "hidden: its buff and debuff bars stand in")
ns.AddonKitExpect("DaylightUI_Chat", "*ChatFrameChannelButton", "*", "hidden: its chat window has its own buttons")
ns.AddonKitExpect("DaylightUI_Chat", "*ChatFrameMenuButton", "*", "hidden: its chat window has its own buttons")
ns.AddonKitExpect("DaylightUI_Chat", "*QuickJoinToastButton", "*", "hidden: its chat window has its own buttons")
ns.AddonKitExpect("DaylightUI_Chat", "*GeneralDockManager", "alpha", "at alpha 0: its chat window has its own tabs")
ns.AddonKitExpect("DaylightUI_Chat", "touch.ChatFrame_", "alpha", "at alpha 0: its chat window draws the lines")
ns.AddonKitExpect("DaylightUI_Chat", "hook.ChatFrame1.AddMessage", "state", "hooksecurefunc: ours still run")
ns.AddonKitExpect("DaylightUI_InfoPanel", "*MainStatusTrackingBarContainer", "*", "hidden: its XP bar stands in")
ns.AddonKitExpect("DaylightUI_InfoPanel", "*UIWidgetBelowMinimapContainerFrame", "parent", "moved under its info panel")
ns.AddonKitExpect("DaylightUI_InfoPanel", "touch.DurabilityFrame", "parent", "moved under its info panel")
ns.AddonKitExpect("DaylightUI_InfoPanel", "touch.MinimapCluster", "alpha", "at alpha 0: its info panel holds the minimap")
ns.AddonKitExpect("DaylightUI_InfoPanel", "touch.MinimapBackdrop", "*", "put away: its info panel draws the minimap's edge")
ns.AddonKitExpect("DaylightUI_InfoPanel", "touch.MinimapCompassTexture", "*", "put away with the minimap's edge")
ns.AddonKitExpect("DaylightUI_InfoPanel", "touch.MinimapZoneText", "visible", "its info panel shows the zone")
ns.AddonKitExpect("DaylightUI_InfoPanel", "touch.TimeManagerClockButton", "*", "put away: its info panel shows the time")
ns.AddonKitExpect("DaylightUI_InfoPanel", "touch.GameTimeFrame", "*", "on the minimap at alpha 0: its info panel shows the time")
ns.AddonKitExpect("DaylightUI_InfoPanel", "touch.AddonCompartmentFrame", "*", "put away: its info panel has its own addon list")
ns.AddonKitExpect("DaylightUI_InfoPanel", "touch.QueueStatusButton", "parent", "moved onto the minimap")
ns.AddonKitExpect("DaylightUI_Quests", "*ObjectiveTrackerFrame", "alpha", "at alpha 0: its quest tracker stands in")
ns.AddonKitExpect("DaylightUI_QoL", "touch.*TextString", "alpha", "at alpha 0: its zone title stands in (the zone card's Conflicts row)")
ns.AddonKitExpect("DaylightUI_QoL", "*TakeTaxiNode", "*", "hooksecurefunc for its flight timer: ours still run")
ns.AddonKitExpect("DaylightUI", "touch.CombatText", "*", "hidden: its combat text stands in")
-- (Game windows put out of sight under a hidden frame while its own stand
-- in: Quest Talk stands aside by itself, QuestTalk.lua's TuckedAway.)
ns.AddonKitExpect("DaylightUI", "touch.GossipFrame", "parent", "out of sight: its own gossip window stands in")
ns.AddonKitExpect("DaylightUI", "touch.QuestFrame", "parent", "out of sight: its own quest window stands in")
ns.AddonKitExpect("DaylightUI", "touch.MerchantFrame", "parent", "out of sight: its own merchant window stands in")
ns.AddonKitExpect("DaylightUI", "touch.MailFrame", "parent", "out of sight: its own mail window stands in")
ns.AddonKitExpect("DaylightUI", "touch.CharacterFrame", "parent", "out of sight: its own character window stands in")
ns.AddonKitExpect("DaylightUI", "touch.LFGParentFrame", "parent", "out of sight: its own group finder stands in")
ns.AddonKitExpect("DaylightUI_Bags", "touch.BankFrame", "parent", "out of sight: its bank stands in")
ns.AddonKitExpect("DaylightUI_Bags", "touch.ContainerFrameCombinedBags", "parent", "out of sight: its bags stand in")
ns.AddonKitExpect("DaylightUI", "*UIPanel*", "*", "hooksecurefunc for its windows: ours still run")
ns.AddonKitExpect("DaylightUI", "*StaticPopup_Show", "*", "hooksecurefunc: ours still run")
ns.AddonKitExpect("DaylightUI", "touch.PlaySound", "sameAsLogin", "hooksecurefunc: ours still run")
ns.AddonKitExpect("DaylightUI_Tooltip", "touch.GameTooltip_SetDefaultAnchor", "sameAsLogin", "hooksecurefunc: ours still run")
ns.AddonKitExpect("DaylightUI_Bags", "touch.ContainerFrame_", "parent", "put out of sight: its bags stand in")
ns.AddonKitExpect("DaylightUI_Bags", "touch.*Bag*", "sameAsLogin", "hooksecurefunc for its bags: ours still run")
ns.AddonKitExpect("DaylightUI_Bags", "touch.*Backpack", "sameAsLogin", "hooksecurefunc for its bags: ours still run")
ns.AddonKitExpect("DaylightUI_Skins", "touch.GroupLootFrame_", "alpha", "at alpha 0 under its loot roll window (Conflicts: Loot roll window)")
ns.AddonKitExpect("DaylightUI_Chat", "touch.ChatFrame_Tab", "alpha", "at alpha 0: its chat window has its own tabs")
ns.AddonKitExpect("DaylightUI_Chat", "link.chatwindow", "*", "its chat holder is the chat window's panel (ns.ClaimLinkPart, above)")
ns.AddonKitExpect("DaylightUI_Tooltip", "touch.GameTooltip", "*", "up or not by where the mouse was at the probe: not in the first run (qb025)")
-- The same game frames on the Standard Frames rows' probes (their field is
-- "<frame>.<field>").
ns.AddonKitExpect("DaylightUI_ActionBars", "frame.*", "MainActionBar.*", "parked in DaylightUIParkedBars: its bar 1 stands in")
ns.AddonKitExpect("DaylightUI_ActionBars", "frame.*", "MultiBar*.*", "parked in DaylightUIParkedBars: its bars 2-8 stand in")
ns.AddonKitExpect("DaylightUI_ActionBars", "frame.*", "StanceBar.*", "parked: its stance bar stands in")
ns.AddonKitExpect("DaylightUI_ActionBars", "frame.*", "PetActionBar.*", "the game's pet bar kept at alpha 0: its buttons sit in its pet bar")
ns.AddonKitExpect("DaylightUI_ActionBars", "frame.*", "MainMenuBarVehicleLeaveButton.*", "its own leave button stands in")
ns.AddonKitExpect("DaylightUI_ActionBars", "frame.*", "BagsBar.*", "its bag bar stands in")
ns.AddonKitExpect("DaylightUI_ActionBars", "frame.*", "MicroMenuContainer.alpha", "its micro menu stands in")
ns.AddonKitExpect("DaylightUI_ActionBars", "frame.*", "TotemFrame.parent", "its totem bar holds it")
ns.AddonKitExpect("DaylightUI_UnitFrames", "frame.*", "PlayerFrame.*", "put away: its player frame stands in")
ns.AddonKitExpect("DaylightUI_UnitFrames", "frame.*", "TargetFrame.parent", "put away: its target frame stands in")
ns.AddonKitExpect("DaylightUI_UnitFrames", "frame.*", "FocusFrame.parent", "put away: its focus frame stands in")
ns.AddonKitExpect("DaylightUI_UnitFrames", "frame.*", "PetFrame.parent", "put away: its pet frame stands in")
ns.AddonKitExpect("DaylightUI_UnitFrames", "frame.*", "CompactRaidFrame*.parent", "put away: its raid frames stand in")
ns.AddonKitExpect("DaylightUI_UnitFrames", "frame.*", "ArenaEnemyFramesContainer.parent", "put away: its arena frames stand in")
ns.AddonKitExpect("DaylightUI_UnitFrames", "frame.*", "*CastingBarFrame.alpha", "at alpha 0: its cast bars stand in")
ns.AddonKitExpect("DaylightUI_UnitFrames", "frame.*", "SwingTimer*Frame.alpha", "at alpha 0: its swing timer stands in")
ns.AddonKitExpect("DaylightUI_Buffs", "frame.*", "*uffFrame.*", "hidden: its buff and debuff bars stand in")
ns.AddonKitExpect("DaylightUI_Chat", "frame.*", "ChatFrameChannelButton.*", "hidden: its chat window has its own buttons")
ns.AddonKitExpect("DaylightUI_Chat", "frame.*", "ChatFrameMenuButton.*", "hidden: its chat window has its own buttons")
ns.AddonKitExpect("DaylightUI_Chat", "frame.*", "QuickJoinToastButton.*", "hidden: its chat window has its own buttons")
ns.AddonKitExpect("DaylightUI_Chat", "frame.*", "GeneralDockManager.alpha", "at alpha 0: its chat window has its own tabs")
ns.AddonKitExpect("DaylightUI_InfoPanel", "frame.*", "MainStatusTrackingBarContainer.*", "hidden: its XP bar stands in")
ns.AddonKitExpect("DaylightUI_InfoPanel", "frame.*", "UIWidgetBelowMinimapContainerFrame.parent", "moved under its info panel")
ns.AddonKitExpect("DaylightUI_Quests", "frame.*", "ObjectiveTrackerFrame.alpha", "at alpha 0: its quest tracker stands in")

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
		return type(frame) == "table" and ns.Reachable(frame)
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
					and ns.Reachable(plate) then
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
