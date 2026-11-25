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

-- (The addon kit: Guidelime needs Questie, which loads with it and puts its
-- own quest tracker in the game's place.)
ns.AddonKitExpect("Guidelime", "frame.quests", "ObjectiveTrackerFrame.*", "Questie (it needs it) hides the game's tracker")
ns.AddonKitExpect("Guidelime", "touch.ObjectiveTrackerFrame", "*", "Questie (it needs it) hides the game's tracker")
