-- RestedXP Guides' ready recipe (Tools/addon-kit/addons/RXPGuides.md), for
-- the addon kit's stages and any RestedXP test. Its folder is RXPGuides, the
-- name the addon kit passes and Support/RestedXP.lua's rows use. What our
-- support covers: its guide window (RXPFrame), waypoint arrow (RXPG_ARROW),
-- quest item window (RXPItemFrame), target window (RXPTargetFrame) and level
-- splits. Ready = its guide window up with a guide loaded and its arrow
-- pointing somewhere. The item and target windows come only on steps that
-- have an item or a mob to target, and the splits only with its Enable
-- Level Splits option: those are in the notes, not here. No test of its own
-- yet. Dev copy only.
local _, ns = ...

-- Its settings: the live AceDB profile of its saved table RXPSettings, found
-- through AceDB's own list of databases (a value set here is seen at once by
-- its code, and unset ones read as its defaults). Not the saved table's own
-- profiles: AceDB only writes a profile there once a value differs from the
-- defaults, so a fresh setup has none (2026-11-25, run q7e75: "settings
-- aren't loaded yet" for good, with its guide and arrow up).
local function Profile()
	local saved = _G.RXPSettings
	local AceDB = type(saved) == "table" and _G.LibStub and _G.LibStub("AceDB-3.0", true)
	if not (AceDB and type(AceDB.db_registry) == "table") then return nil end
	for db in pairs(AceDB.db_registry) do
		if type(db) == "table" and rawget(db, "sv") == saved then
			local ok, profile = pcall(function() return db.profile end)
			return ok and type(profile) == "table" and profile or nil
		end
	end
	return nil
end

-- Its /rxp command (AceConsole names it ACECONSOLE_RXP). "show" and "hide"
-- both flip its on/off switch (showEnabled), so only call it to flip.
local function Slash(text)
	local slash = SlashCmdList and SlashCmdList.ACECONSOLE_RXP
	if type(slash) == "function" then pcall(slash, text) end
end

local function Guide() return _G.RXPFrame end
local function Arrow() return _G.RXPG_ARROW end

local function GuideName()
	local name = _G.RXPCData and _G.RXPCData.currentGuideName
	return type(name) == "string" and name ~= "" and name or nil
end

-- Its guide window shows while it's switched on (showEnabled, /rxp) and its
-- Hide Window option is off. A guide is kept per character
-- (RXPCData.currentGuideName); the call that loads one is inside the addon
-- (not global), so that's your clicks. Its arrow shows on a step that goes
-- to a place, outside instances, with its Hide waypoint arrow option off.
ns.TestKit.DefineAddonReady("RXPGuides", {
	about = "its guide window open, a guide loaded, its arrow pointing somewhere",
	ready = function()
		local profile = Profile()
		if not profile then return false, "RestedXP's settings aren't loaded yet" end
		if profile.enableBetaFeatures and profile.enableV2Interface then
			return false, "its new (V2) guide window is on: our rows cover the classic one"
		end
		if profile.showEnabled == false then return false, "RestedXP is switched off (/rxp hide)" end
		if profile.hideGuideWindow then return false, "its Hide Window option is on" end
		if not (Guide() and ns.Flag(Guide():IsShown())) then return false, "its guide window is hidden" end
		if not GuideName() then return false, "no guide loaded" end
		if profile.disableArrow then return false, "its Hide waypoint arrow option is on" end
		if IsInInstance() then return false, "its arrow hides in instances: step outside" end
		if not Arrow() then return false, "no arrow made" end
		return ns.Flag(Arrow():IsShown()), "the arrow is hidden (the current step goes nowhere)"
	end,
	make = function(r)
		local profile = Profile()
		if not profile then return end
		if profile.showEnabled == false then
			r:Keep("RXPGuidesWasOff", true)
			Slash("show")
			r:Log("switched RestedXP on (as /rxp show does)")
		end
		if profile.hideGuideWindow and Guide() then
			r:Keep("RXPGuidesWindowWasHidden", true)
			profile.hideGuideWindow = false
			Guide():Show()
			r:Log("turned its Hide Window option off and showed its guide window")
		end
		r:Sleep(1)
	end,
	putBack = function(extra)
		local profile = Profile()
		if not profile then return nil end
		local said = {}
		if extra.RXPGuidesWindowWasHidden and not profile.hideGuideWindow then
			profile.hideGuideWindow = true
			if Guide() then Guide():Hide() end
			said[#said + 1] = "its guide window hidden again (Hide Window on)"
		end
		if extra.RXPGuidesWasOff and profile.showEnabled ~= false then
			Slash("hide")
			said[#said + 1] = "RestedXP switched off again"
		end
		return #said > 0 and table.concat(said, "; ") or nil
	end,
	guide = {
		"Right-click the top bar of the RestedXP guide window (it reads \"Welcome to RestedXP Guides\" or the guide's name).",
		"In the menu, point at RestedXP Forever Guide (A) or (H), your faction's.",
		"Click any guide in the list beside it.",
		"Arrow still not up? Right-click a step in the guide window that says to go to a place.",
		"Click Go to step in the menu.",
		"Inside a dungeon or raid? Step outside (its arrow hides there).",
	},
})
