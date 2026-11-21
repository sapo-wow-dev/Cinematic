-- Left list group lines open on a click (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/listclick.lua < /dev/null
-- Bug (2026-11-21): clicking a line with lines under it (Style > Interface)
-- turned its arrow open but showed none of its lines, now and then. The
-- game's pick (SettingsCategoryListMixin:SetCurrentCategory, mirrored here
-- from its source) makes the list again only if the line picked is open or
-- a line above it was folded; our fold ran after that (Settings.CategoryChanged).
-- Now folded on the line's PreClick, before the game's click (menu.FoldBeforeClick).
-- Checked on the real menu (Options.lua's lines), the game's click stood in for:
-- a group line clicked shows its lines; another page clicked folds it again;
-- a control with our PreClick taken off shows the old bug; in a fight a click
-- never makes the list again; the in-game check (/cine debug listfold 1-4)
-- run through the kit here says 0 fail. Says PASS or FAIL per check.
-- luacheck: push ignore 111 112 113 121 122 212 432
local made = 0 -- (times the list was made)
local drawn = {}
local combat = false

local ns, wowStub = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc", function(wow)
	InCombatLockdown = function() return combat end
	debugstack = function() return "" end
	local gameHook = hooksecurefunc
	hooksecurefunc = function(t, name, after)
		-- (Only hooks on a table: the list's CreateCategories.)
		if type(t) ~= "table" then return gameHook(t, name, after) end
		local old = t[name]
		t[name] = function(...) local a, b, c = old(...) after(...) return a, b, c end
	end
	-- Categories: SettingsCategoryMixin's parts (SetExpanded only sets expanded).
	local Cat = {}
	function Cat:GetName() return self.name end
	function Cat:GetID() return self.id end
	function Cat:GetParentCategory() return self.parent end
	function Cat:GetSubcategories() return self.subcategories end
	function Cat:HasSubcategories() return #self.subcategories > 0 end
	function Cat:SetExpanded(open) self.expanded = open end
	function Cat:IsExpanded() return self.expanded end
	function Cat:GetCategorySet() return 2 end
	local catMeta = { __index = function(_, k)
		if Cat[k] then return Cat[k] end
		if type(k) == "string" and k:find("^%u") then return function() end end
	end }
	local ids = 0
	local function New(name, parent)
		ids = ids + 1
		local c = setmetatable({ name = name, id = ids, subcategories = {}, parent = parent, expanded = false }, catMeta)
		if parent then table.insert(parent.subcategories, c) end
		return c
	end
	local roots = {}
	Settings = setmetatable({
		RegisterCanvasLayoutCategory = function(_, name) local c = New(name) roots[#roots + 1] = c return c end,
		RegisterCanvasLayoutSubcategory = function(parent, _, name) return New(name, parent) end,
		RegisterAddOnCategory = function() end,
	}, { __index = wow.Stub })
	EventRegistry = { callbacks = {} }
	function EventRegistry:RegisterCallback(event, fn, owner)
		self.callbacks[event] = self.callbacks[event] or {}
		table.insert(self.callbacks[event], { fn = fn, owner = owner })
	end
	function EventRegistry:TriggerEvent(event, ...)
		for _, each in ipairs(self.callbacks[event] or {}) do each.fn(each.owner, ...) end
	end
	-- The list: its lines from the tree (open lines' children drawn), a
	-- button a line, buttons kept and handed out again as the game's pool.
	local panel = CreateFrame("Frame", "SettingsPanel")
	panel:Show()
	local list = { ScrollBox = {} }
	local pool = {}
	function list:CreateCategories()
		made = made + 1
		drawn = {}
		local function Walk(c)
			drawn[#drawn + 1] = c
			if c.expanded then for _, kid in ipairs(c.subcategories) do Walk(kid) end end
		end
		for _, c in ipairs(roots) do Walk(c) end
		for i, c in ipairs(drawn) do
			local button = pool[i]
			if not button then
				button = CreateFrame("Button")
				button.Toggle = CreateFrame("Button", nil, button)
				button:SetScript("OnClick", function(self)
					-- (the game's: OnCategorySelected > SettingsPanel:SelectCategory)
					panel:SelectCategory(self.elementData.data.category)
				end)
				-- (A click: PreClick, then OnClick, as the game runs them.)
				button.Click = function(self)
					local pre = self:GetScript("PreClick")
					if pre then pre(self, "LeftButton", false) end
					self:GetScript("OnClick")(self, "LeftButton", false)
				end
				pool[i] = button
			end
			button.elementData = { data = { category = c } }
			button.GetElementData = function(self) return self.elementData end
			if c:HasSubcategories() then button.Toggle:Show() else button.Toggle:Hide() end
		end
	end
	function list.ScrollBox:GetDataProvider()
		return { ForEach = function(_, fn) for i = 1, #drawn do fn(pool[i].elementData) end end }
	end
	function list.ScrollBox:ForEachFrame(fn)
		for i = 1, #drawn do fn(pool[i]) end
	end
	-- SettingsCategoryListMixin:SetCurrentCategory, as in the game's source.
	function list:SetCurrentCategory(category)
		self.currentCategory = category
		local recreate = false
		local parent = category:GetParentCategory()
		while parent do
			if not parent:IsExpanded() then
				parent:SetExpanded(true)
				recreate = true
			end
			parent = parent:GetParentCategory()
		end
		if recreate or category:IsExpanded() then self:CreateCategories() end
	end
	panel.GetCategoryList = function() return list end
	panel.GetCurrentCategory = function(self) return self.current end
	-- SettingsPanelMixin:SelectCategory: pick, then Settings.CategoryChanged.
	function panel:SelectCategory(category)
		if self.current ~= category then
			self.current = category
			list:SetCurrentCategory(category)
			EventRegistry:TriggerEvent("Settings.CategoryChanged", category)
		end
	end
	_G.SettingsPanel = panel
	ns_list = list
end)

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end
local list = ns_list
for _, w in ipairs(wowStub.warnings or {}) do print("WARN " .. w) end

-- A user's click on a drawn line: PreClick, then OnClick (as the game runs them).
local function ButtonOf(category)
	local found
	list.ScrollBox:ForEachFrame(function(b) if b.elementData.data.category == category then found = b end end)
	return found
end
local function Click(category)
	local b = ButtonOf(category)
	if not b then return false end
	local pre = b:GetScript("PreClick")
	if pre then pre(b, "LeftButton", false) end
	b:GetScript("OnClick")(b, "LeftButton", false)
	return true
end
local function Drawn(category)
	for _, c in ipairs(drawn) do if c == category then return true end end
	return false
end
local function FindNamed(parent, name)
	for _, c in ipairs(parent.subcategories) do if c.name == name then return c end end
end

list:CreateCategories()
local root = drawn[1]
if root then root.expanded = true list:CreateCategories() end -- (Cinematic's own line open)
Check("the addon's settings tree was made", root and #root.subcategories > 3, root and #root.subcategories)
local style = root and FindNamed(root, ns.L and ns.L["Style"] or "Style")
-- (A group line under Style with lines of its own: Interface in the screenshot.)
local group
for _, c in ipairs(style and style.subcategories or {}) do
	if c:HasSubcategories() then group = group or c end
	if c.name == (ns.L and ns.L["Interface"] or "Interface") and c:HasSubcategories() then group = c end
end
local page = root and FindNamed(root, ns.L and ns.L["Profiles"] or "Profiles")
Check("Style has a group line with lines under it", group ~= nil, group and group.name)
Check("a plain page line (Profiles) to go to", page ~= nil)
if not (group and page and style) then print(fails .. " FAILED") return end

local function Scenario(label)
	-- (Style picked: open, its lines drawn, the group folded.)
	Check(label .. ": Style line clicked", Click(style))
	Check(label .. ": Style's lines drawn", Drawn(group))
	Check(label .. ": the group starts folded", not group.expanded and not Drawn(group.subcategories[1]))
	Click(group)
	return group.expanded, Drawn(group.subcategories[1])
end

-- Control: our PreClick off, the game's click alone shows the old bug.
local kept = {}
list.ScrollBox:ForEachFrame(function(b) kept[b] = b:GetScript("PreClick") b:SetScript("PreClick", nil) end)
Click(page)
Click(style)
local open, shown = style.expanded, Drawn(group)
Check("control (no PreClick): Style's arrow open but no lines under it (the bug)", open and not shown,
	("open %s, lines drawn %s"):format(tostring(open), tostring(shown)))
for b, fn in pairs(kept) do b:SetScript("PreClick", fn) end

-- The fix: the group line clicked shows its lines.
Click(page)
list:CreateCategories() -- (painted: every drawn line hooked)
open, shown = Scenario("fix")
Check("group line clicked: open and its lines drawn", open and shown,
	("open %s, lines drawn %s"):format(tostring(open), tostring(shown)))
-- Another page clicked: the group and Style fold, their lines gone.
Click(page)
Check("another page clicked: Style's lines folded away", not Drawn(group), ("style open %s"):format(tostring(style.expanded)))
-- Clicked again from there: it opens again (each time, not now and then).
Click(style)
Click(group)
Check("clicked a second time: its lines drawn again", Drawn(group.subcategories[1]))

-- In a fight: no list made by a click on a folded group (Fold waits for the end).
Click(page)
Click(style)
combat = true
local made0 = made
Click(group)
Check("in a fight: a group click makes no list", made == made0, ("made %d time(s)"):format(made - made0))
combat = false

-- The in-game check, /cine debug listfold 1 2 3 4 (Dev/ListFoldTest.lua),
-- through the kit on this stand-in with pretend time: it clicks the lines
-- itself and must say 0 fail, the control seeing the bug.
local now, timers, tickers = 100, {}, {}
GetTime = function() return now end
C_Timer.After = function(delay, fn) timers[#timers + 1] = { at = now + delay, fn = fn } end
C_Timer.NewTicker = function(every, fn)
	local t = { every = every, next = now + every, fn = fn, Cancel = function(self) self.cancelled = true end }
	tickers[#tickers + 1] = t
	return t
end
local function Advance(seconds)
	local stop = now + seconds
	while now < stop do
		now = now + 0.1
		local due = {}
		for i = #timers, 1, -1 do if timers[i].at <= now then due[#due + 1] = table.remove(timers, i) end end
		for i = #due, 1, -1 do due[i].fn() end
		for _, t in ipairs(tickers) do
			if not t.cancelled and t.next <= now then t.next = now + t.every t.fn(t) end
		end
	end
end
Screenshot = function() end
HideUIPanel = function(p) p:Hide() end
ns.PadTestBox = function() end
ns.PadTestBoxHide = function() end
ns.IsCineModeOn = function() return false end
ns.HandleSlash("debug listfold 1 2 3 4")
Advance(60)
local kitLog = CinematicDB.listFoldTestLog or {}
local done
for _, line in ipairs(kitLog) do if line:find("DONE: ", 1, true) then done = line end end
Check("/cine debug listfold 1-4 offline: DONE, 0 fail", done ~= nil and done:find(" 0 fail", 1, true) ~= nil, done)
local controlLine
for _, line in ipairs(kitLog) do if line:find("the game's click alone", 1, true) then controlLine = line end end
Check("its control step saw the bug (PASS)", controlLine ~= nil and controlLine:find("PASS", 1, true) ~= nil, controlLine)
if not (done and done:find(" 0 fail", 1, true)) then
	for _, line in ipairs(kitLog) do if line:find("FAIL") then print("  " .. line) end end
end

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
-- luacheck: pop
