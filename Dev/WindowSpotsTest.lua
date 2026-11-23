-- /cine debug windowspots: where the game's windows open (QoL/CenterPanels.lua)
-- and the General page grouped (2026-11-23). A player asked for the windows
-- truly in the middle (Discord, 2026-11-23): Dead center, under "Open windows
-- clear of your character".
-- A test kit test (Dev/TestKit.lua), NOTHING to do (out of combat). Steps:
--   1 page    Quality of life > General open: its group headers, the Dead
--             center row under the windows row, nothing over either; greyed
--             with the windows row off; the page off: its off card. Shots.
--   2 side    windows row on, Dead center off: the character window opens
--             in from the left (as before); a shot
--   3 middle  Dead center on: the character window in the very middle, then
--             with the friends window too: the pair in the middle; shots
--   4 dropped the friends window dropped in the middle (a saved spot), then
--             the character window opened: beside it, not over it; a shot
--   5 off     the windows row off: Dead center does nothing (the game's spot)
-- Every setting it touches put back at the end (the kit's undo), your
-- dropped spots too (panelSpots). Into CinematicDB.windowSpotsTestLog. Dev
-- copy only.
local _, ns = ...

local function FindText(root, words)
	local function Walk(frame, depth)
		if depth > 30 then return nil end
		for _, region in ipairs({ frame:GetRegions() }) do
			if region.GetText then
				local text = region:GetText()
				if type(text) == "string" and not (issecretvalue and issecretvalue(text)) and text == words
					and region:IsVisible() then
					return region
				end
			end
		end
		for _, child in ipairs({ frame:GetChildren() }) do
			local hit = Walk(child, depth + 1)
			if hit then return hit end
		end
	end
	return Walk(root, 0)
end

-- A window's edges in UIParent's units, or nil.
local function Box(frame)
	if not (frame and frame:IsShown()) then return nil end
	local l, r, t, b = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
	if not (l and r and t and b) then return nil end
	local k = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	return { l * k, r * k, t * k, b * k }
end
local function Said(box)
	return box and ("%.0f-%.0f x %.0f-%.0f"):format(box[1], box[2], box[4], box[3]) or "not shown"
end
local function Mid(box)
	return (box[1] + box[2]) / 2, (box[3] + box[4]) / 2
end

local function CloseAll()
	if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
	if FriendsFrame and FriendsFrame:IsShown() then HideUIPanel(FriendsFrame) end
	if CharacterFrame and CharacterFrame:IsShown() then HideUIPanel(CharacterFrame) end
end
local function Open(r, frame)
	ShowUIPanel(frame)
	r:Sleep(0.4)
end

local function Line(r, label)
	r:Log(("%s: screen %.0f x %.0f, character %s, friends %s"):format(label, UIParent:GetWidth(), UIParent:GetHeight(),
		Said(Box(CharacterFrame)), Said(Box(FriendsFrame))))
end

ns.TestKit.Define({
	name = "windowspots",
	key = "windowSpotsTest",
	title = "Where windows open (Dead center)",
	about = "the General page's groups, then the character and friends windows beside you, dead center, beside a dropped one; nothing to do",
	needs = "be out of combat",
	settings = { "handleQuality", "centerPanels", "centerPanelsMiddle", "dragPanels", "panelSpots" },
	context = function()
		local db = ns.db
		return ("centerPanels %s, centerPanelsMiddle %s, dragPanels %s, Quest Vision talk %s, UI scale %s"):format(
			tostring(db.centerPanels), tostring(db.centerPanelsMiddle), tostring(db.dragPanels), tostring(db.questTalk),
			tostring(UIParent:GetEffectiveScale()))
	end,
	putBack = function() CloseAll() end,
	steps = {
		{ key = "page", title = "the General page: its groups and the Dead center row", run = function(r)
			r:Set("handleQuality", true)
			r:Set("centerPanels", true)
			r:Set("centerPanelsMiddle", false)
			ns.OpenOptions("General")
			r:Sleep(0.8)
			local panel = SettingsPanel or UIParent
			for _, header in ipairs({ "Windows", "Gear and talents", "Chat", "Login and reload", "Text on screen",
				"Hide error messages" }) do
				r:Verdict(FindText(panel, ns.L[header]) ~= nil, "header " .. header)
			end
			local row = FindText(panel, ns.L["Open windows clear of your character"])
			local middle = FindText(panel, ns.L["Dead center instead"])
			r:Verdict(row ~= nil, "the windows row")
			r:Verdict(middle ~= nil, "the Dead center row")
			if row and middle then
				r:Verdict(middle:GetTop() < row:GetTop() and middle:GetLeft() > row:GetLeft(), "Dead center under it, in a step")
				r:Verdict(#r:Overlaps(row:GetParent(), panel) == 0, "nothing over the windows row")
				r:Verdict(#r:Overlaps(middle:GetParent(), panel) == 0, "nothing over the Dead center row")
				local box = middle:GetParent()
				r:Verdict(box.IsEnabled == nil or box:IsEnabled(), "Dead center usable with the windows row on")
			end
			r:Shot("General page, grouped", { behind = panel })
			r:Set("centerPanels", false)
			if ns.RefreshOptions then ns.RefreshOptions() end
			r:Sleep(0.4)
			if middle then
				local box = middle:GetParent()
				r:Verdict(box.IsEnabled ~= nil and not box:IsEnabled(), "Dead center greyed with the windows row off")
			end
			r:Shot("windows row off: Dead center greyed", { behind = panel })
			r:Set("handleQuality", false)
			if ns.RefreshOptions then ns.RefreshOptions() end
			r:Sleep(0.4)
			r:Shot("General page off: its off card", { behind = panel })
			r:Set("handleQuality", true)
			r:Set("centerPanels", true)
			if ns.RefreshOptions then ns.RefreshOptions() end
			CloseAll()
		end },
		{ key = "side", title = "beside your character (Dead center off)", run = function(r)
			r:Set("panelSpots", {})
			r:Set("centerPanels", true)
			r:Set("centerPanelsMiddle", false)
			CloseAll()
			Open(r, CharacterFrame)
			Line(r, "side")
			local box = Box(CharacterFrame)
			if not box then return r:Fail("character window didn't open") end
			-- (Narrow, under 560: in from the left; wider, as Forever's 631 one
			-- with its stats: to the right. Off the middle either way, as before.)
			local x = Mid(box)
			local wide = box[2] - box[1] >= 560
			r:Verdict(math.abs(x - UIParent:GetWidth() / 2) > 20 and (x > UIParent:GetWidth() / 2) == wide,
				("off the middle, %s as before (%.0f wide)"):format(wide and "to the right" or "in from the left", box[2] - box[1]))
			r:Shot("character window beside you", { behind = CharacterFrame })
			CloseAll()
		end },
		{ key = "middle", title = "Dead center on", run = function(r)
			r:Set("centerPanelsMiddle", true)
			CloseAll()
			Open(r, CharacterFrame)
			Line(r, "dead center, one")
			local box = Box(CharacterFrame)
			if not box then return r:Fail("character window didn't open") end
			local x, y = Mid(box)
			r:Verdict(math.abs(x - UIParent:GetWidth() / 2) < 2 and math.abs(y - UIParent:GetHeight() / 2) < 2,
				("character window dead center (%.0f, %.0f)"):format(x, y))
			r:Shot("character window dead center", { behind = CharacterFrame })
			Open(r, FriendsFrame)
			Line(r, "dead center, two")
			local a, b = Box(CharacterFrame), Box(FriendsFrame)
			if a and b then
				local mid = (math.min(a[1], b[1]) + math.max(a[2], b[2])) / 2
				r:Verdict(math.abs(mid - UIParent:GetWidth() / 2) < 2, ("the pair in the middle (%.0f)"):format(mid))
				r:Verdict(a[2] <= b[1] + 1 or b[2] <= a[1] + 1, "side by side, not over each other")
			else
				r:Log("friends window didn't open beside it: pair not judged")
			end
			r:Shot("two windows dead center")
			CloseAll()
		end },
		{ key = "dropped", title = "a window dropped in the middle: the next opens beside it", run = function(r)
			r:Set("dragPanels", true)
			r:Set("centerPanelsMiddle", true)
			CloseAll()
			local w, h = FriendsFrame:GetWidth(), FriendsFrame:GetHeight()
			local k = UIParent:GetEffectiveScale() / FriendsFrame:GetEffectiveScale()
			local left = (UIParent:GetWidth() * k - w) / 2
			local top = (UIParent:GetHeight() * k + h) / 2
			ns.SavePanelSpot("FriendsFrame", { "TOPLEFT", "BOTTOMLEFT", left, top }, w, h)
			Open(r, FriendsFrame)
			Open(r, CharacterFrame)
			Line(r, "dropped")
			local a, b = Box(CharacterFrame), Box(FriendsFrame)
			if not (a and b) then return r:Fail("a window didn't open") end
			local over = a[1] < b[2] - 1 and a[2] > b[1] + 1 and a[4] < b[3] - 1 and a[3] > b[4] + 1
			r:Verdict(not over, "character window beside the dropped friends window, not over it")
			r:Shot("character window beside a dropped one")
			CloseAll()
		end },
		{ key = "off", title = "windows row off: Dead center does nothing", run = function(r)
			r:Set("panelSpots", {})
			r:Set("centerPanels", false)
			r:Set("centerPanelsMiddle", true)
			CloseAll()
			Open(r, CharacterFrame)
			Line(r, "off")
			local box = Box(CharacterFrame)
			if not box then return r:Fail("character window didn't open") end
			r:Verdict(box[1] < 60, ("the game's own spot at the left edge (%.0f)"):format(box[1]))
			r:Shot("windows row off: the game's spot", { behind = CharacterFrame })
			CloseAll()
		end },
	},
})
