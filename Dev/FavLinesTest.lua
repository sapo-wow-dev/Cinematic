-- /cine debug favlines: can our settings' left list take Favorites lines that
-- come and go while you play? Probes both plans, one run:
--   A  live lines   a line added after setup, then taken out again
--   B  placeholders a Favorites line and 3 empty slots under it, made once and
--                   hidden; a slot shown, renamed (as a page is starred), picked,
--                   and hidden again (un-starred); the Favorites line with it
-- Lines are taken out by pulling their category from its parent's
-- subcategories (our own categories, written by us already) and put back at
-- their spot; the game makes its list again as a page is picked out of a fight
-- (Settings.OpenToCategory, ns.PickSettingsCategory), never from our code.
-- Each step: is the line in the list the game drew (its data, read only), dev
-- box blocked lines +0; the left list's tainted fields are said, not judged.
-- Steps:
--   1 look      what this client's categories and list have (INFO), taint scan
--               then 4 page picks with no line changed: blocked lines (INFO,
--               the control for the later steps' counts)
--   2 A add     a line added: drawn (PASS/FAIL)
--   3 A remove  taken out: not drawn (PASS/FAIL)
--   4 B hidden  Favorites + 3 slots made and hidden: none drawn (PASS/FAIL)
--   5 B star    Favorites and slot 1 shown at the top, slot 1 renamed: drawn,
--               first under Cinematic, new name (PASS/FAIL); picked: its page
--               shows (PASS/FAIL)
--   6 B unstar  slot 1 and Favorites hidden again: neither drawn (PASS/FAIL)
--   7 fight     Favorites and slot 1 shown again, then you start a fight and
--               open Escape > Options: blocked lines +0 (PASS/FAIL; the old way
--               of making the list gave 1756)
-- Into CinematicDB.favLinesTestLog, a screenshot a step. The probe lines stay
-- till a /reload. Run again to stop. Dev copy only.
local _, ns = ...

local HOOK, CHAT = "blocked (no event)", "blocked (chat line only)"
-- (two plain pages to pick in turn: each pick makes the game draw its list again)
local PAGES = { "Profiles", "Keybinds" }

local run
local made = 0 -- (times the game made its list again while a run is on)

local function Say(text)
	local log = CinematicDB and CinematicDB.favLinesTestLog
	if log then log[#log + 1] = ("%s %.1f %s"):format(date("%H:%M:%S"), run and GetTime() - run.at or 0, text) end
end
local function Shot(what)
	local ok = pcall(function() Screenshot() end)
	Say(("  screenshot %s at %s%s"):format(what, date("%m%d%y_%H%M%S"), ok and "" or " (failed)"))
end
local function Blocked() return (ns.DevErrorCount(HOOK)) + (ns.DevErrorCount(CHAT)) end
local function Panel() return _G.SettingsPanel end
local function PanelShown()
	local panel = Panel()
	return panel and panel:IsShown() and true or false
end
local function List()
	local panel = Panel()
	return panel and panel.GetCategoryList and panel:GetCategoryList()
end
local function Verdict(ok, text)
	if ok then run.pass = run.pass + 1 else run.fail = run.fail + 1 end
	Say(("  verdict %s: %s"):format(ok and "PASS" or "FAIL", text))
end
local function Info(text)
	run.info = run.info + 1
	Say("  verdict INFO: " .. text)
end
-- Tainted fields in the left list (BlockedLineTest's scan, quiet), -1 if none.
local function ListTaint(label)
	if not ns.SettingsTaintScan then return -1 end
	local ok, total, groups = pcall(ns.SettingsTaintScan, label, 0, function() end)
	if not ok or not total then return -1 end
	return groups and groups["SettingsPanel.CategoryList"] or 0, total
end

-- The root category's children table (the one the game reads), and how found.
local function Kids(category)
	if type(category) ~= "table" then return nil, "no category" end
	if type(category.subcategories) == "table" then return category.subcategories, "subcategories" end
	if category.GetSubcategories then
		local ok, kids = pcall(category.GetSubcategories, category)
		if ok and type(kids) == "table" then return kids, "GetSubcategories()" end
	end
	return nil, "none found"
end
local function IndexIn(kids, category)
	for i, kid in ipairs(kids or {}) do if kid == category then return i end end
end
local function Hide(category)
	local kids = Kids(category.cineProbeParent)
	local i = IndexIn(kids, category)
	if i then table.remove(kids, i) end
	return i ~= nil
end
local function ShowAt(category, index)
	local kids = Kids(category.cineProbeParent)
	if not kids or IndexIn(kids, category) then return false end
	table.insert(kids, math.min(index, #kids + 1), category)
	return true
end
local function NameOf(category)
	if type(category) ~= "table" then return tostring(category) end
	local ok, name = pcall(function() return category.GetName and category:GetName() or category.name end)
	return ok and tostring(name) or "?"
end
local function Rename(category, name)
	if category.SetName then
		local ok = pcall(category.SetName, category, name)
		if ok and NameOf(category) == name then return "SetName" end
	end
	category.name = name
	return NameOf(category) == name and ".name" or "neither"
end

-- The categories the game drew, in order (its data provider, read only).
local function Drawn()
	local list = List()
	local box = list and list.ScrollBox
	local provider = box and box.GetDataProvider and box:GetDataProvider()
	local order = {}
	if not provider then return order, "no data provider" end
	-- (A node's category, however deep the list wraps it: retail 2026-11-20
	-- read 13 lines but never ours at the top level of node data.)
	local function CategoryOf(x, depth)
		if type(x) ~= "table" or depth > 4 then return nil end
		if type(x.GetParentCategory) == "function" and type(x.GetName) == "function" then return x end
		if type(x.GetData) == "function" then
			local ok, data = pcall(x.GetData, x)
			local found = ok and data ~= x and CategoryOf(data, depth + 1)
			if found then return found end
		end
		for _, key in ipairs({ "category", "Category", "data", "elementData" }) do
			local found = rawget(x, key) ~= nil and CategoryOf(x[key], depth + 1)
			if found then return found end
		end
	end
	local function Take(node)
		if run and not run.nodeShape then
			-- (what one node holds, once a run, so a failing read can be fixed)
			local data = type(node) == "table" and node.GetData and select(2, pcall(node.GetData, node)) or node
			local keys = {}
			if type(data) == "table" then
				for key, value in pairs(data) do keys[#keys + 1] = tostring(key) .. "=" .. type(value) end
			end
			table.sort(keys)
			run.nodeShape = "a node's data: " .. table.concat(keys, ", ")
			Say("  " .. run.nodeShape)
		end
		local category = CategoryOf(node, 0)
		if category then order[#order + 1] = category end
	end
	local how
	for _, way in ipairs({ "ForEach", "Enumerate", "EnumerateEntireRange" }) do
		local fn = provider[way]
		if type(fn) == "function" then
			local ok = pcall(function()
				if way == "ForEach" then
					fn(provider, Take, false)
				else
					for _, node in fn(provider) do Take(node) end
				end
			end)
			if ok and #order > 0 then how = way break end
			order = {}
		end
	end
	return order, how or "nothing read"
end
-- Where a category is drawn: its place among its drawn siblings (1 = first
-- under its parent), -1 drawn with no parent read, nil not drawn.
local function ParentOf(c)
	local ok, parent = pcall(function() return c.GetParentCategory and c:GetParentCategory() or c.parentCategory end)
	return ok and parent or nil
end
local function DrawnSpot(category)
	local n = 0
	for _, c in ipairs((Drawn())) do
		local sibling = ParentOf(c) == category.cineProbeParent
		if sibling then n = n + 1 end
		if c == category then return sibling and n or -1 end
	end
end

-- Has the game draw its list again (a page picked), then after() a second on.
local pickNext = 0
local function Redraw(after)
	pickNext = pickNext % #PAGES + 1
	local made0 = made
	local ok, err = pcall(ns.OpenOptions, PAGES[pickNext])
	if not ok then Say("  OpenOptions error: " .. tostring(err)) end
	C_Timer.After(1, function()
		if not run then return end
		Say(("  page %s picked, list made again %d time(s)"):format(PAGES[pickNext], made - made0))
		after()
	end)
end

-- A probe line: a page frame with a line of text on it, under parent.
local function NewLine(label, parent)
	local frame = CreateFrame("Frame")
	frame.name = label
	local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	text:SetPoint("TOPLEFT", 16, -16)
	text:SetText("Favorites probe page: " .. label)
	frame:Hide() -- (the settings show it as its line is picked)
	local category = Settings.RegisterCanvasLayoutSubcategory(parent, frame, label)
	Settings.RegisterAddOnCategory(category)
	category.cineProbeParent, category.cineProbeFrame = parent, frame
	return category
end

local function Finish(done)
	if not run then return end
	local this = run
	run = nil
	local line = ("%s: %d pass, %d fail, %d info"):format(done and "DONE" or "stopped", this.pass, this.fail, this.info)
	Say(line)
	ns.TestPrompt(("Favorites lines test %s. /reload, then say \"check log\"."):format(line), 12)
end

-- Polls (no time limit) till check() is true.
local function WaitFor(prompt, check, after)
	ns.TestPrompt(prompt, 3600)
	local token = {}
	run.wait = token
	local function Poll()
		if not run or run.wait ~= token then return end
		if check() then return after() end
		C_Timer.After(0.25, Poll)
	end
	Poll()
end

-- A step: do(), then the list drawn again, then check(); counts around it.
local function Step(title, prompt, doIt, check, nextStep)
	if not run then return end
	Say("--- " .. title .. " ---")
	ns.TestPrompt("Favorites lines test: " .. prompt .. " Just watch.", 3)
	local blocked0, taint0 = Blocked(), ListTaint("before")
	local ok, err = pcall(doIt)
	if not ok then Say("  error: " .. tostring(err)) end
	Redraw(function()
		Shot(title:match("^(%d+)") or title)
		local blocked = Blocked() - blocked0
		if blocked > 0 then
			local _, stack = ns.DevErrorCount(HOOK)
			if stack then Say("  newest blocked stack:\n" .. stack) end
		end
		local taint = ListTaint("after")
		local fine, why = pcall(check, blocked, taint0 >= 0 and taint >= 0 and taint - taint0 or nil)
		if not fine then Say("  check error: " .. tostring(why)) end
		C_Timer.After(0.5, nextStep)
	end)
end
-- (Tainted fields only said, not judged: retail 2026-11-20 went +170, +9, -22
-- as lines came and went, from 31 before, and still 0 blocked lines in the
-- fight. Blocked lines are what players see, so they're the verdict.)
local function Counts(blocked, taint)
	return ("blocked +%d (0 wanted), left list tainted fields %s (said only)"):format(blocked,
		taint and ("%+d"):format(taint) or "unread"), blocked == 0
end

local Fight

local function PlanB()
	local root = ns.settingsCategory
	local fav, slots = nil, {}
	Step("4 of 7: B, Favorites line and 3 slots made and hidden", "making hidden slots.", function()
		fav = NewLine("Probe Favorites", root)
		for i = 1, 3 do slots[i] = NewLine("Probe slot " .. i, fav) end
		run.fav, run.slot = fav, slots[1]
		Say(("  made: Favorites at %s, slots under it %s"):format(tostring(IndexIn(Kids(root), fav)),
			tostring(#(Kids(fav) or {}))))
		for i = 3, 1, -1 do Hide(slots[i]) end
		Hide(fav)
	end, function(blocked, taint)
		local any = DrawnSpot(fav) or DrawnSpot(slots[1]) or DrawnSpot(slots[2]) or DrawnSpot(slots[3])
		local text, clean = Counts(blocked, taint)
		Verdict(not any and clean, ("Favorites and slots drawn: %s (none wanted), %s"):format(any and "SOME" or "none", text))
	end, function()
		Step("5 of 7: B, a page starred: Favorites and slot 1 shown, renamed", "starring a page.", function()
			ShowAt(fav, 1)
			ShowAt(slots[1], 1)
			Say("  renamed by " .. Rename(slots[1], "Probe fav: Camera"))
			-- (opened before the redraw, as Favorites will be: a new line comes
			-- folded, its slot not drawn till clicked open; retail 2026-11-20)
			Say(("  Favorites open before: %s"):format(tostring(fav.IsExpanded and fav:IsExpanded())))
			if fav.SetExpanded then pcall(fav.SetExpanded, fav, true) end
		end, function(blocked, taint)
			local favSpot, slotSpot = DrawnSpot(fav), DrawnSpot(slots[1])
			local name = NameOf(slots[1])
			local text, clean = Counts(blocked, taint)
			Verdict(favSpot == 1 and slotSpot ~= nil and name == "Probe fav: Camera" and clean,
				("Favorites drawn at %s (1 wanted), slot 1 drawn %s, named %q, slots 2-3 drawn %s (no wanted), %s"):format(
					tostring(favSpot), slotSpot and "yes" or "NO", name,
					(DrawnSpot(slots[2]) or DrawnSpot(slots[3])) and "YES" or "no", text))
			-- picked as you'd click it: its page shows
			local blocked0 = Blocked()
			local ok, err = pcall(ns.PickSettingsCategory, Panel(), slots[1])
			if not ok then Say("  pick error: " .. tostring(err)) end
			C_Timer.After(1, function()
				if not run then return end
				Shot("5 picked")
				local shown = slots[1].cineProbeFrame:IsVisible()
				Verdict(shown and Blocked() == blocked0, ("slot 1 picked: its page %s, blocked +%d (0 wanted)"):format(
					shown and "shows" or "NOT shown", Blocked() - blocked0))
			end)
		end, function()
			C_Timer.After(1, function()
				if not run then return end
				Step("6 of 7: B, the page unstarred: slot 1 and Favorites hidden", "unstarring it.", function()
					-- (off the slot's page first: the line shown isn't the one taken out)
					pcall(ns.OpenOptions, PAGES[pickNext])
					Hide(slots[1])
					Hide(fav)
				end, function(blocked, taint)
					local any = DrawnSpot(fav) or DrawnSpot(slots[1])
					local text, clean = Counts(blocked, taint)
					Verdict(not any and clean, ("Favorites and slot 1 drawn: %s (none wanted), page now %q, %s"):format(
						any and "STILL" or "none", tostring(ns.ShownOptionsPage and ns.ShownOptionsPage()), text))
				end, Fight)
			end)
		end)
	end)
end

local function PlanA()
	local root = ns.settingsCategory
	local line
	Step("2 of 7: A, a line added after setup", "adding a line.", function()
		line = NewLine("Probe live line", root)
	end, function(blocked, taint)
		local spot = DrawnSpot(line)
		local text, clean = Counts(blocked, taint)
		Verdict(spot ~= nil and clean, ("line drawn at %s (any spot wanted), %s"):format(tostring(spot or "NO spot"), text))
	end, function()
		Step("3 of 7: A, the line taken out", "taking it out.", function()
			Say("  taken out of its parent's list: " .. tostring(Hide(line)))
		end, function(blocked, taint)
			local spot = DrawnSpot(line)
			local text, clean = Counts(blocked, taint)
			Verdict(spot == nil and clean, ("line drawn: %s (no wanted), %s"):format(spot and "STILL" or "no", text))
		end, PlanB)
	end)
end

function Fight()
	if not run then return end
	Say("--- 7 of 7: Escape > Options opened by you in a fight, a favorite shown ---")
	-- (starred again first: in play the Favorites lines are there in fights)
	if run.fav and run.slot then
		ShowAt(run.fav, 1)
		ShowAt(run.slot, 1)
		pcall(ns.OpenOptions, PAGES[pickNext % #PAGES + 1])
		Say(("  Favorites drawn at %s, slot 1 drawn %s"):format(tostring(DrawnSpot(run.fav)),
			DrawnSpot(run.slot) and "yes" or "NO"))
	end
	local panel = Panel()
	if PanelShown() and HideUIPanel then pcall(HideUIPanel, panel) end
	WaitFor("Favorites lines test: 7 of 7. Start a fight (a training dummy or any enemy). The test waits.",
		InCombatLockdown, function()
			local blocked0 = Blocked()
			WaitFor("Favorites lines test: in the fight press Escape, then click Options. The test waits.", PanelShown,
				function()
					local inFight = InCombatLockdown()
					ns.TestPrompt("Favorites lines test: got it, keep fighting a moment.", 3)
					C_Timer.After(3, function()
						if not run then return end
						Shot("7")
						local new = Blocked() - blocked0
						if new > 0 then
							local _, stack = ns.DevErrorCount(HOOK)
							if stack then Say("  newest blocked stack:\n" .. stack) end
						end
						Verdict(inFight and new == 0, ("Escape > Options in a fight: blocked +%d (0 wanted), opened %s"):format(
							new, inFight and "in the fight" or "NOT in a fight"))
						WaitFor("Favorites lines test: close the settings and end the fight. The test waits.",
							function() return not InCombatLockdown() and not PanelShown() end, function() Finish(true) end)
					end)
				end)
		end)
end

-- 1: what this client has, logged so a failing step can be read.
local function Look()
	Say("--- 1 of 7: what the categories and list have ---")
	local root = ns.settingsCategory
	local kids, how = Kids(root)
	Info(("Cinematic's lines read by %s: %d; GetSubcategories the same table %s"):format(how, kids and #kids or 0,
		tostring(root.GetSubcategories and select(2, pcall(root.GetSubcategories, root)) == root.subcategories)))
	local function Methods(t, label)
		local names, seen = {}, {}
		local probe = t
		while type(probe) == "table" and #names < 80 do
			for key, value in pairs(probe) do
				if type(key) == "string" and not seen[key] and (type(value) == "function" or
					key:find("[Nn]ame") or key:find("[Ss]ub") or key:find("[Ss]how") or key:find("[Hh]id")
					or key:find("[Ee]xpand") or key:find("[Vv]isib")) then
					seen[key] = true
					names[#names + 1] = key
				end
			end
			local meta = getmetatable(probe)
			probe = meta and type(meta.__index) == "table" and meta.__index or nil
		end
		table.sort(names)
		Say(("  %s: %s"):format(label, table.concat(names, ", ")))
	end
	if kids and kids[1] then Methods(kids[1], "a line's fields") end
	local list = List()
	if list then Methods(list, "the list's fields") end
	local order, way = Drawn()
	Info(("the game's drawn list read by %s: %d lines"):format(way, #order))
	local listTaint, total = ListTaint("before")
	Info(("tainted fields before: left list %s, all %s"):format(tostring(listTaint), tostring(total)))
	-- Control: the same page picks with no probe line changed, blocked lines
	-- counted. (Forever 2026-11-20: from step 3 on every pick from our code
	-- got one gamepad blocked line, out of combat; this says whether picks do
	-- that alone, or only once a line was taken out.)
	local blocked0, picks = Blocked(), 0
	local function Control()
		if not run then return end
		if picks < 4 then
			picks = picks + 1
			return Redraw(Control)
		end
		Info(("control, 4 page picks by our code, no line changed: blocked +%d"):format(Blocked() - blocked0))
		C_Timer.After(0.5, PlanA)
	end
	Say("--- 1 of 7: control picks ---")
	Control()
end

function ns.FavLinesTest()
	if run then return Finish(false) end
	if not (CinematicDB and ns.DevErrorCount and ns.OpenOptions and ns.PickSettingsCategory and ns.settingsCategory
		and Settings and Settings.RegisterCanvasLayoutSubcategory) then
		ns.Print("/cine debug favlines: this client's settings or the dev error box aren't there.")
		return
	end
	if InCombatLockdown() then
		ns.Print("/cine debug favlines: start it out of a fight.")
		return
	end
	local list = List()
	if not (list and list.CreateCategories) then
		ns.Print("/cine debug favlines: this client's settings have no left list.")
		return
	end
	if not list.cineFavTestHooked then
		list.cineFavTestHooked = true
		hooksecurefunc(list, "CreateCategories", function() if run then made = made + 1 end end)
	end
	CinematicDB.favLinesTestLog = {}
	run = { at = GetTime(), pass = 0, fail = 0, info = 0 }
	Say(("start: %s (game %s), gamepad UI %s, box has %d blocked entries"):format(ns.isRetail and "retail" or "Forever",
		tostring((select(4, GetBuildInfo()))), _G.SmartNavigation and "there" or "not there", Blocked()))
	-- (opened first so the game has drawn its list before step 1 reads it)
	Redraw(Look)
end
