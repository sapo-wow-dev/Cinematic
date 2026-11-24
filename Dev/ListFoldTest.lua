-- /cine debug listfold [steps]: our settings' left list (Options.lua Fold,
-- menu.FoldBeforeClick). On the test kit (Dev/TestKit.lua) since 2026-11-21.
-- Steps 1-4 need nothing from you: the test opens the settings and clicks the
-- lines itself (button:Click, which runs the line's PreClick and OnClick as a
-- mouse click does).
--   1 open      settings opened at Profiles (the game's OpenToCategory); Style
--               and a group line under it with lines of its own (Interface)
--               found; our lines' PreClick hooked (PASS/FAIL)
--   2 control   our PreClick off (ns.testNoFoldBeforeClick): the game's click
--               alone on folded Style marks it open and draws none of its
--               lines (the bug of 2026-11-21, rule
--               settings.categorylist.pick-redraws-only-if-open) (PASS/FAIL)
--   3 clicks    our PreClick on, three rounds: Profiles, Style (its lines
--               drawn), the group line (its lines drawn); then Profiles folds
--               both away (PASS/FAIL), a screenshot of the list
--   4 close     the settings closed; the left list's tainted fields before and
--               after the clicks said (our clicks are addon code: INFO)
-- Steps 5-9: the list never made again in a fight (2041 yellow "Interface
-- action failed" lines in one fight, 2026-11-20). You start a fight and end it:
--   5 calm      pages in three hubs picked out of a fight: nothing blocked
--   6 fight     waits for you to start a fight (no time limit)
--   7 made      the list made again once by hand in the fight: how many lines
--               it blocks, to show the trigger is live (INFO, blocks on purpose)
--   8 picks     the same pages picked 6 times in the fight: list never made
--               again, the fold waiting for the end (PASS/FAIL)
--   9 after     waits for the fight to end: the waiting fold done (PASS/FAIL)
-- Into CinematicDB.listFoldTestLog. Dev copy only.
local _, ns = ...

local L = ns.L or {}
-- (Interface, Visions and Style hubs in turn, two pages a hub: each pick a new page there.)
local PAGES = { "Chat", "Card Vision", "Style General", "Nameplates", "Death Vision", "Style Themes" }

local made = 0 -- (times the game's list was made)
local hooked
local function List()
	local panel = _G.SettingsPanel
	return panel and panel.GetCategoryList and panel:GetCategoryList()
end
local function Hook()
	local list = List()
	if hooked or not (list and list.CreateCategories) then return end
	hooked = true
	hooksecurefunc(list, "CreateCategories", function() made = made + 1 end)
end

local function CategoryOfData(data)
	local d = type(data) == "table" and data.data
	return type(d) == "table" and d.category or nil
end
-- (Is category a line in the list? Its data, from the data provider: all lines, scrolled to or not.)
local function DataOf(category)
	local list = List()
	local box = list and list.ScrollBox
	local provider = box and box.GetDataProvider and box:GetDataProvider()
	local found
	if provider and provider.ForEach then
		provider:ForEach(function(data) if CategoryOfData(data) == category then found = data end end)
	end
	return found
end
local function Drawn(category) return category ~= nil and DataOf(category) ~= nil end
local function ButtonOf(category)
	local box = List() and List().ScrollBox
	local found
	if box and box.ForEachFrame then
		box:ForEachFrame(function(button)
			local data = button.GetElementData and button:GetElementData()
			if CategoryOfData(data) == category then found = button end
		end)
	end
	return found
end
local function NameOf(category) return category and (category.GetName and category:GetName() or category.name) or "nil" end
local function Open(category) return category ~= nil and (category.IsExpanded and category:IsExpanded() or category.expanded) and true or false end
local function Child(parent, name)
	for _, c in ipairs(parent and parent.GetSubcategories and parent:GetSubcategories() or {}) do
		if NameOf(c) == name then return c end
	end
end
local function Kids(c) return c and c.GetSubcategories and c:GetSubcategories() or {} end

-- The lines the click steps use, found once.
local lines = {}
local function Find()
	local root = ns.settingsCategory
	lines.root = root
	lines.style = Child(root, L["Style"] or "Style")
	lines.page = Child(root, L["Profiles"] or "Profiles")
	lines.group = nil
	for _, c in ipairs(Kids(lines.style)) do
		if #Kids(c) > 0 then
			if not lines.group or NameOf(c) == (L["Interface"] or "Interface") then lines.group = c end
		end
	end
	return lines.style and lines.page and lines.group
end

-- A click on a line, as a mouse click (PreClick, then OnClick). Scrolled to first if need be.
local function Click(r, category, label)
	local button = ButtonOf(category)
	if not button then
		local data = DataOf(category)
		local box = List() and List().ScrollBox
		if data and box and box.ScrollToElementData then pcall(box.ScrollToElementData, box, data) end
		r:Sleep(0.3)
		button = ButtonOf(category)
	end
	if not button then
		r:Log(("  click %s: no line drawn for it"):format(label))
		return false
	end
	local made0 = made
	button:Click("LeftButton")
	r:Sleep(0.4)
	r:Log(("  clicked %s (%s): open %s, list made %d time(s)"):format(label, NameOf(category), tostring(Open(category)),
		made - made0))
	return true
end

local function TaintCount()
	if not ns.SettingsTaintScan then return nil end
	-- (label, none shown, said nowhere: FavLinesTest.lua's call; with none it errored, run 1)
	local ok, total, places = pcall(ns.SettingsTaintScan, "listfold", 0, function() end)
	if not ok then return nil end
	return type(places) == "table" and places["SettingsPanel.CategoryList"] or total
end

local function Pick(r, times)
	for _ = 1, times do
		r.picked = (r.picked or 0) + 1
		local name = PAGES[(r.picked - 1) % #PAGES + 1]
		local ok, hub = pcall(ns.ShowHubPage, name)
		if not ok or not hub then r:Log(("  %s: not picked (%s)"):format(name, tostring(hub))) end
	end
end

ns.TestKit.Define({
	name = "listfold",
	key = "listFoldTest",
	title = "Left list test",
	about = "settings left list: group lines open on every click (1-4, nothing to do); never made again in a fight (5-9)",
	needs = "An enemy or training dummy to fight",
	context = function()
		return ("left list: %s, gamepad UI %s"):format(List() and "found" or "NOT found",
			_G.SmartNavigation and "there" or "not there")
	end,
	finish = function() ns.testNoFoldBeforeClick = nil end,
	steps = {
		{ key = "open", title = "settings opened, lines found", run = function(r)
			if InCombatLockdown() then return r:Skip("in a fight: start it out of one") end
			Hook()
			r.taint0 = TaintCount()
			ns.OpenOptions("Profiles")
			r:Sleep(1)
			local found = Find()
			r:Fields("lines", {
				style = function() return NameOf(lines.style) end,
				group = function() return NameOf(lines.group) end,
				groupLines = function() return #Kids(lines.group) end,
				page = function() return NameOf(lines.page) end,
				shown = function() return _G.SettingsPanel and _G.SettingsPanel:IsShown() end,
			})
			r:Verdict(found ~= nil and List() ~= nil, "Style, a group line under it and Profiles found")
			-- (Our lines hooked as the arrows are painted, a few times a second.)
			local hookedLine = false
			local box = List() and List().ScrollBox
			if box and box.ForEachFrame then
				box:ForEachFrame(function(button) if button.cineFoldHooked then hookedLine = true end end)
			end
			r:Verdict(hookedLine, "our lines have the fold PreClick: " .. tostring(hookedLine))
		end },
		{ key = "control", title = "control: the game's click alone", run = function(r)
			if not lines.style then return r:Skip("lines not found (step 1)") end
			-- (Profiles clicked with the fix on: Style folded and its lines really gone first.)
			Click(r, lines.page, "Profiles")
			local wasOpen = Open(lines.style) or Drawn(lines.group)
			ns.testNoFoldBeforeClick = true
			Click(r, lines.style, "Style")
			local open, shown = Open(lines.style), Drawn(lines.group)
			ns.testNoFoldBeforeClick = nil
			r:Shot("control: Style clicked, no fold PreClick", { behind = _G.SettingsPanel })
			r:Verdict(not wasOpen and open and not shown,
				("the game's click alone: Style folded (lines gone) before %s, open after %s, its lines drawn %s (the bug: open, not drawn)")
					:format(tostring(not wasOpen), tostring(open), tostring(shown)))
		end },
		{ key = "clicks", title = "the lines clicked, three rounds", run = function(r)
			if not lines.style then return r:Skip("lines not found (step 1)") end
			local first = Kids(lines.group)[1]
			for round = 1, 3 do
				Click(r, lines.page, "Profiles")
				local folded = not Drawn(lines.group)
				Click(r, lines.style, "Style")
				local styleShown = Drawn(lines.group)
				Click(r, lines.group, NameOf(lines.group))
				local groupShown = Drawn(first)
				if round == 1 then r:Shot("Style > " .. NameOf(lines.group) .. " clicked", { behind = _G.SettingsPanel }) end
				r:Verdict(folded and styleShown and groupShown and Open(lines.group),
					("round %d: folded at Profiles %s, Style's lines drawn %s, %s's lines drawn %s"):format(round,
						tostring(folded), tostring(styleShown), NameOf(lines.group), tostring(groupShown)))
			end
			Click(r, lines.page, "Profiles")
			r:Verdict(not Drawn(lines.group) and not Drawn(first),
				("Profiles clicked after: Style's lines gone %s, the group's gone %s"):format(
					tostring(not Drawn(lines.group)), tostring(not Drawn(first))))
		end },
		{ key = "close", title = "settings closed, taint said", run = function(r)
			local after = TaintCount()
			r:Log(("  left list tainted fields: before %s, after the clicks %s (INFO: our clicks are addon code; a mouse click isn't)")
				:format(tostring(r.taint0), tostring(after)))
			if _G.SettingsPanel and _G.SettingsPanel:IsShown() and HideUIPanel then pcall(HideUIPanel, _G.SettingsPanel) end
			r:Sleep(0.5)
			r:Verdict(not (_G.SettingsPanel and _G.SettingsPanel:IsShown()), "settings closed")
		end },
		{ key = "calm", title = "pages picked out of a fight", run = function(r)
			if InCombatLockdown() then return r:Skip("in a fight already") end
			Hook()
			if _G.SettingsPanel and _G.SettingsPanel:IsShown() and HideUIPanel then pcall(HideUIPanel, _G.SettingsPanel) end
			local made0 = made
			Pick(r, 3)
			r:Sleep(1)
			r:Shot("pages picked out of a fight", { behind = _G.SettingsPanel })
			r:Log(("  list made again %d time(s) (by the game's OpenToCategory)"):format(made - made0))
			r:Pass("picked; the step's blocked count says if anything was blocked")
		end },
		{ key = "fight", title = "a fight started", run = function(r)
			r:WaitFor("Start a fight: attack any enemy or a training dummy. The test waits.",
				{ check = function() return InCombatLockdown() end })
			r:Pass("in a fight")
		end },
		{ key = "made", title = "control: list made again by hand in the fight", blockedOk = true, run = function(r)
			if not InCombatLockdown() then return r:Skip("not in a fight") end
			r:Prompt("Keep fighting, the test is working.", nil, 3)
			local list = List()
			if list and list.CreateCategories then pcall(list.CreateCategories, list) end
			r:Sleep(0.5)
			r:Log("  (the step end line says how many lines it blocked: the trigger is live if > 0)")
			r:Shot("list made again by hand in the fight", { behind = _G.SettingsPanel })
		end },
		{ key = "picks", title = "pages picked 6 times in the fight", run = function(r)
			if not InCombatLockdown() then return r:Skip("not in a fight") end
			r:Prompt("Keep fighting, the test is working.", nil, 3)
			local made0 = made
			Pick(r, 6)
			r:Sleep(1)
			r:Shot("pages picked in the fight", { behind = _G.SettingsPanel })
			local waiting = ns.LeftListFoldWaiting and ns.LeftListFoldWaiting()
			r:Verdict(made == made0 and waiting ~= nil and InCombatLockdown(),
				("list made again %d time(s) (0 wanted), fold waiting for the end: %s, still fighting %s")
					:format(made - made0, waiting and "yes" or "NO", tostring(InCombatLockdown())))
		end },
		{ key = "after", title = "the fight ended", run = function(r)
			r:WaitFor("End the fight now (win it or run off). The test waits.",
				{ check = function() return not InCombatLockdown() end })
			r:Sleep(1)
			local waiting = ns.LeftListFoldWaiting and ns.LeftListFoldWaiting()
			r:Verdict(waiting == nil, ("fold waiting: %s (none wanted)"):format(waiting and "still" or "none"))
		end },
	},
})
