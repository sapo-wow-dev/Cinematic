-- Cinematic: Guidelime, a leveling guide (needs Questie). Its guide window,
-- its small window of ongoing steps and its waypoint arrow are a row each on
-- the Addons page. The two windows stand in for the game's quest tracker, so
-- until set they take the Quest tracker row's ticks (follows); the arrow
-- starts as a new row does, so players keep it up to find their way while
-- the guide fades (a player's wish, 2026-11-25).
--
-- Guidelime hides its arrow whenever its guide window is closed: our fade
-- only makes the window see-through, so the arrow keeps working with the
-- guide faded. Its target and quest item buttons are the guide window's
-- children and fade with it (secure buttons: alpha only, fine in fights).
--
-- The arrow sets its own alpha from its opacity setting, so it's hooked:
-- faded, it's ours times its own. The guide window has no name of its own:
-- it's the UIParent child holding the steps list, the pinned steps and a
-- lock button Guidelime names "lockBtn".
local _, ns = ...
local L = ns.L

local function IsGuideWindow(frame)
	local lock = rawget(frame, "lockBtn")
	if type(lock) ~= "table" or rawget(frame, "scrollChild") == nil
		or rawget(frame, "pinnedStepsFrame") == nil or not ns.Reachable(lock) then
		return false
	end
	return lock:GetName() == "lockBtn"
end
-- (For its test, Dev/GuidelimeSupportTest.lua.)
ns.IsGuidelimeWindow = IsGuideWindow

for _, known in ipairs({
	{ key = "glGuide", label = "Guidelime guide", about = L["its guide window"], match = IsGuideWindow,
		follows = "quests" },
	{ key = "glOngoing", label = "Guidelime ongoing steps", about = L["its ongoing steps window"],
		names = { "GuidelimeOngoingWindow" }, follows = "quests" },
	{ key = "glArrow", label = "Guidelime arrow", about = L["its waypoint arrow"], names = { "GuidelimeArrow" },
		hookAlpha = true },
}) do
	known.addon, known.suite, known.short = "Guidelime", "Guidelime", known.label
	table.insert(ns.ADDON_FRAMES, known)
end

-- Its windows (the guides list, the editor, its question boxes): its own
-- popups, unnamed, on UIParent, each with an okBtn and a backdrop from its
-- own folder (Guidelime's F.createPopupFrame). Windows a player opens, so
-- left alone, with the buttons and boxes inside them. (The addon kit's run
-- q3814, 2026-11-25: its guides window was NOT COVERED.) Each frame looked
-- at once.
local function IsGuidelimePopup(frame)
	if rawget(frame, "okBtn") == nil or type(frame.GetBackdrop) ~= "function" then return false end
	local ok, backdrop = pcall(frame.GetBackdrop, frame)
	local bg = ok and type(backdrop) == "table" and backdrop.bgFile
	return type(bg) == "string" and bg:lower():find("/guidelime/icons/", 1, true) ~= nil
end
ns.IsGuidelimePopup = IsGuidelimePopup
ns.WhenAddonLoads("Guidelime", function()
	local looked = setmetatable({}, { __mode = "k" })
	ns.AddScanner(function()
		for _, child in ipairs({ UIParent:GetChildren() }) do
			if not looked[child] then
				looked[child] = true
				if ns.Reachable(child) and not child:GetName() and IsGuidelimePopup(child) then
					ns.LeaveAloneFrame(child)
				end
			end
		end
	end)
end)

-- (The addon kit: Guidelime needs Questie, which loads with it and puts its
-- own quest tracker in the game's place.)
ns.AddonKitExpect("Guidelime", "frame.quests", "ObjectiveTrackerFrame.*", "Questie (it needs it) hides the game's tracker")
ns.AddonKitExpect("Guidelime", "touch.ObjectiveTrackerFrame", "*", "Questie (it needs it) hides the game's tracker")
