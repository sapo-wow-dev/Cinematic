-- Favorites lines probe check (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/favlines.lua < /dev/null
-- /cine debug favlines (Dev/FavLinesTest.lua, dev copy) run on a stand-in
-- settings window whose left list is drawn from the categories' subcategories
-- each time a page is picked. Checked: a clean run gives 7 PASS and 0 FAIL
-- through all 7 steps (the fight one too: you start it and open the window);
-- a list that keeps every line it was ever given gives FAILs (the probe can
-- fail); a list with blocked lines in the fight fails step 7; typed again
-- mid-run, it stops. Says PASS or FAIL per check.
-- luacheck: push ignore 111 112 113 121 122 212 432
local ns = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc")

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

-- Timers run as the clock moves.
local now, timers = 0, {}
GetTime = function() return now end
C_Timer.After = function(seconds, fn) timers[#timers + 1] = { at = now + seconds, fn = fn } end
local function Run(seconds)
	local stop = now + seconds
	while true do
		local soon, at
		for i, t in ipairs(timers) do if t.at <= stop and (not at or t.at < at) then soon, at = i, t.at end end
		if not soon then break end
		local t = table.remove(timers, soon)
		now = math.max(now, t.at)
		t.fn()
	end
	now = stop
end
hooksecurefunc = function(t, name, after)
	local old = t[name]
	t[name] = function(...) local a, b, c = old(...) after(...) return a, b, c end
end
Screenshot = function() end
ns.TestPrompt = function() end
ns.Print = function() end

local combat, sticky, fightBlocks = false, false, 0
InCombatLockdown = function() return combat end

-- Categories: a name, children, a parent.
local Category = {}
Category.__index = Category
function Category:GetName() return self.name end
function Category:GetParentCategory() return self.parent end
function Category:GetSubcategories() return self.subcategories end
function Category:SetExpanded(open) self.expanded = open end
function Category:IsExpanded() return self.expanded end
local function NewCategory(name, parent)
	local c = setmetatable({ name = name, subcategories = {}, parent = parent, expanded = true }, Category)
	if parent then table.insert(parent.subcategories, c) end
	return c
end
local everGiven = {}
Settings = {
	RegisterCanvasLayoutSubcategory = function(parent, frame, name)
		local c = NewCategory(name, parent)
		c.expanded = false -- (a new line comes folded, as on retail)
		c.frame = frame
		everGiven[#everGiven + 1] = c
		return c
	end,
	RegisterAddOnCategory = function() end,
}
local root = NewCategory("Cinematic")
for _, name in ipairs({ "Profiles", "UI Manager", "Keybinds", "Help" }) do
	local c = NewCategory(name, root)
	c.frame = CreateFrame("Frame")
	c.frame:Hide()
end
ns.settingsCategory = root

-- The window and its list: drawn again from the tree as a page is picked.
local drawn = {}
local list = { ScrollBox = {} }
function list:CreateCategories()
	drawn = {}
	local function Walk(c)
		for _, kid in ipairs(c.subcategories) do
			drawn[#drawn + 1] = kid
			if kid.expanded then Walk(kid) end
		end
	end
	drawn[1] = root
	Walk(root)
	if sticky then
		-- (a list that keeps every line it was ever given)
		for _, c in ipairs(everGiven) do
			local seen
			for _, d in ipairs(drawn) do if d == c then seen = true end end
			if not seen then drawn[#drawn + 1] = c end
		end
	end
end
list.ScrollBox.GetDataProvider = function()
	return { ForEach = function(_, fn)
		for _, c in ipairs(drawn) do
			fn({ GetData = function() return { data = { category = c } } end })
		end
	end }
end
local shown
local panel = CreateFrame("Frame")
panel:Hide()
panel.GetCategoryList = function() return list end
_G.SettingsPanel = panel
HideUIPanel = function(p) p:Hide() end
local function Pick(category)
	-- (picking a line opens the lines it's under, as the game does)
	local up = category.parent
	while up do up.expanded = true; up = up.parent end
	if shown and shown.frame then shown.frame:Hide() end
	panel:Show()
	list:CreateCategories()
	shown = category
	if category.frame then category.frame:Show() end
end
ns.PickSettingsCategory = function(_, category) Pick(category) end
ns.OpenOptions = function(page)
	for _, c in ipairs(root.subcategories) do if c.name == page then return Pick(c) end end
end
ns.ShownOptionsPage = function() return shown and shown.name end
local blocked = 0
ns.DevErrorCount = function(kind) return kind == "blocked (no event)" and blocked or 0 end
ns.SettingsTaintScan = function() return 0, { ["SettingsPanel.CategoryList"] = 0 } end

local function Verdicts()
	local pass, fail, failText = 0, 0, {}
	for _, line in ipairs(CinematicDB.favLinesTestLog or {}) do
		if line:find("verdict PASS") then pass = pass + 1 end
		if line:find("verdict FAIL") then fail = fail + 1; failText[#failText + 1] = line end
	end
	return pass, fail, table.concat(failText, " | ")
end
local function Log() return table.concat(CinematicDB.favLinesTestLog or {}, "\n") end

-- The whole run: steps 1-6 alone, then the fight you start and the window you open.
local function FullRun()
	combat = false
	panel:Hide()
	ns.FavLinesTest()
	Run(30)
	combat = true
	Run(1)
	blocked = blocked + fightBlocks
	panel:Show()
	Run(5)
	combat = false
	panel:Hide()
	Run(2)
end

Check("the probe is loaded", type(ns.FavLinesTest) == "function")

FullRun()
local pass, fail, failText = Verdicts()
Check("clean list: 7 PASS, 0 FAIL", pass == 7 and fail == 0, ("%d pass, %d fail %s"):format(pass, fail, failText))
Check("clean list: run says DONE", Log():find("DONE: 7 pass, 0 fail") ~= nil)
Check("step 5 renames by .name (no SetName here)", Log():find("renamed by .name", 1, true) ~= nil)
Check("step 7: Favorites shown again first, at the top", Log():find("Favorites drawn at 1, slot 1 drawn yes", 1, true) ~= nil)
Check("a node's data is logged once", select(2, Log():gsub("a node's data: ", "")) == 1)

sticky = true
FullRun()
pass, fail = Verdicts()
Check("list that keeps lines: the probe FAILs", fail >= 2, ("%d pass, %d fail"):format(pass, fail))
sticky = false

fightBlocks = 3
FullRun()
_, fail, failText = Verdicts()
Check("blocked lines in the fight fail step 7", fail == 1 and failText:find("blocked %+3") ~= nil, failText)
fightBlocks = 0

ns.FavLinesTest()
Run(2)
ns.FavLinesTest()
Run(40)
Check("typed again mid-run: stopped", Log():find("stopped: ") ~= nil and not Log():find("DONE"))

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
-- luacheck: pop
