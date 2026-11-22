-- /cine debug resetpopup: does "Delete everything in Cinematic?" open where
-- "Reset Cinematic?" was, instead of lower down (it looked like the window
-- moving, 2026-11-22)? Nothing to do: it runs and says DONE. Nothing is
-- reset: the confirm is closed, never clicked. Steps:
--   1 old    A/B, the way it was: the confirm shown while Reset Cinematic? is
--            still up. Logs how far down the game puts it (it stacks it in
--            the next slot): proves the cause (PASS when it lands lower)
--   2 click  the real path: Reset addon's popup, its Reset EVERYTHING button
--            clicked, the confirm a frame later. PASS when its top and middle
--            are within 1 px of where Reset Cinematic? was, and Reset
--            Cinematic? has gone; a screenshot of each
--   3 welcome the welcome window open, Reset Cinematic? shown: the window
--            doesn't move (it went down under each box) and the box draws
--            over it; still in place once the box is gone (PASS/FAIL)
-- Into CinematicDB.resetPopupTestLog. Dev copy only.
local _, ns = ...

local FIRST, SECOND = "CINEMATIC_ADDON_RESET", "CINEMATIC_ADDON_RESET_ALL"

local function FindPopup(which)
	if StaticPopup_FindVisible then return StaticPopup_FindVisible(which) end
	for i = 1, (_G.STATICPOPUP_NUMDIALOGS or 4) do
		local dialog = _G["StaticPopup" .. i]
		if dialog and dialog:IsShown() and dialog.which == which then return dialog end
	end
end
local function PopupButton(dialog, index)
	return dialog["button" .. index] or (dialog.GetButton and dialog:GetButton(index))
		or (dialog.ButtonContainer and dialog.ButtonContainer["Button" .. index])
end
local function HideBoth()
	for _, which in ipairs({ SECOND, FIRST }) do
		local dialog = FindPopup(which)
		if dialog then dialog:Hide() end
	end
end
-- Top and middle, in UIParent's units.
local function Place(dialog)
	local s = dialog:GetEffectiveScale() / UIParent:GetEffectiveScale()
	local top, left, right = dialog:GetTop(), dialog:GetLeft(), dialog:GetRight()
	if not (top and left and right) then return nil end
	return top * s, (left + right) / 2 * s, dialog:GetName() or "?"
end
local function PlaceText(top, mid, name)
	if not top then return "unreadable" end
	return ("%s top %.1f middle %.1f"):format(name, top, mid)
end
-- Polls check() up to seconds, giving its last answer.
local function Within(r, seconds, check)
	local untilAt = GetTime() + seconds
	local answer = check()
	while not answer and GetTime() < untilAt do
		r:Sleep(0.1)
		answer = check()
	end
	return answer
end
-- Reset Cinematic? up and settled (it widens itself a frame after showing).
local function ShowFirst(r)
	HideBoth()
	r:Sleep(0.2)
	ns.ShowResetPopup()
	r:Sleep(0.5)
	return FindPopup(FIRST)
end

ns.TestKit.Define({
	name = "resetpopup",
	key = "resetPopupTest",
	title = "Reset popups open in one spot",
	about = "the Delete everything confirm opens where Reset Cinematic? was, nothing to do, nothing reset",
	context = function()
		local open = {}
		for i = 1, (_G.STATICPOPUP_NUMDIALOGS or 4) do
			local dialog = _G["StaticPopup" .. i]
			if dialog and dialog:IsShown() then open[#open + 1] = ("%d=%s"):format(i, tostring(dialog.which)) end
		end
		return ("popups up at start: %s, UI scale %.3f"):format(#open > 0 and table.concat(open, " ") or "none",
			UIParent:GetEffectiveScale())
	end,
	steps = {
		{ key = "old", title = "A/B: the confirm shown with Reset Cinematic? still up", run = function(r)
			if ns.OpenOptions then pcall(ns.OpenOptions) end
			r:Sleep(0.5)
			local first = ShowFirst(r)
			if not first then return r:Fail("Reset Cinematic? didn't open") end
			local t1, m1, n1 = Place(first)
			StaticPopup_Show(SECOND)
			r:Sleep(0.3)
			local second = FindPopup(SECOND)
			local t2, m2, n2
			if second then t2, m2, n2 = Place(second) end
			r:Log(("Reset Cinematic? %s; confirm (shown at once) %s"):format(PlaceText(t1, m1, n1),
				PlaceText(t2, m2, n2)))
			r:Verdict(t1 and t2 and t2 < t1 - 1, ("shown at once it lands lower (by %s): the cause"):format(
				t1 and t2 and ("%.1f"):format(t1 - t2) or "?"))
			r:Shot("old way: both up, the confirm lower", { behind = { first, second } })
			HideBoth()
		end },
		{ key = "click", title = "the real path: Reset EVERYTHING clicked", run = function(r)
			local first = ShowFirst(r)
			if not first then return r:Fail("Reset Cinematic? didn't open") end
			local t1, m1, n1 = Place(first)
			r:Shot("Reset Cinematic?", { behind = first })
			local button = PopupButton(first, 1)
			if not button then return r:Fail("no Reset EVERYTHING button on the popup") end
			r:Log(("Reset Cinematic? %s; clicking %s"):format(PlaceText(t1, m1, n1), tostring(button:GetText())))
			button:Click()
			local second = Within(r, 2, function() return FindPopup(SECOND) end)
			if not second then HideBoth(); return r:Fail("the confirm didn't open within 2 s") end
			r:Sleep(0.3)
			local t2, m2, n2 = Place(second)
			r:Log(("confirm %s"):format(PlaceText(t2, m2, n2)))
			r:Verdict(not FindPopup(FIRST), "Reset Cinematic? has gone")
			r:Verdict(t1 and t2 and math.abs(t1 - t2) <= 1 and math.abs(m1 - m2) <= 1,
				("confirm opens where Reset Cinematic? was (top off by %s, middle by %s)"):format(
				t1 and t2 and ("%.1f"):format(t1 - t2) or "?", m1 and m2 and ("%.1f"):format(m1 - m2) or "?"))
			r:Shot("the confirm, in its place", { behind = second })
			HideBoth()
			if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
		end },
		{ key = "welcome", title = "the welcome window stays put under a box", run = function(r)
			HideBoth()
			if not ns.ShowWelcome then return r:Skip("no welcome window in this copy") end
			ns.ShowWelcome()
			r:Sleep(0.5)
			local welcome = rawget(_G, "CinematicWelcome")
			if not (welcome and welcome:IsShown()) then return r:Fail("the welcome window didn't open") end
			local before = welcome:GetTop()
			ns.ShowResetPopup()
			r:Sleep(0.5)
			local box = FindPopup(FIRST)
			if not box then welcome:Hide(); return r:Fail("Reset Cinematic? didn't open") end
			local after = welcome:GetTop()
			r:Log(("window top %.1f before the box, %.1f with it; box bottom %.1f; layers: window %s, box %s"):format(
				before or -1, after or -1, box:GetBottom() or -1, welcome:GetFrameStrata(), box:GetFrameStrata()))
			r:Verdict(before and after and math.abs(before - after) < 1 or false, "the welcome window didn't move")
			local layer = { HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7 }
			r:Verdict((layer[box:GetFrameStrata()] or 0) > (layer[welcome:GetFrameStrata()] or 0),
				"the box draws over the window")
			r:Shot("the box over the welcome window", { behind = { box, welcome } })
			HideBoth()
			r:Sleep(0.5)
			r:Verdict(math.abs((welcome:GetTop() or -1) - (before or -1)) < 1, "box gone: the window still in place")
			welcome:Hide()
		end },
	},
})
