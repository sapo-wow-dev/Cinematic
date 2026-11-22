-- Cooldown Manager grid test (dev tool, offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/cooldowngrid.lua < /dev/null
-- The Cooldown Manager page's place groups and grid (2026-11-22, in place of
-- each row's numbered lines: UI/CooldownRules.lua, UI/CooldownGrid.lua): a
-- group fits by its places (any number) and combat, or its CQL rule; the
-- first that fits is in use; a row's cell for it decides, else (a spell) its
-- bar's cell, else the row's Otherwise, else its bar's; groups never in use
-- are found; the page's grid opens a cell's choices, edits groups, sets
-- ticked rows at once, copies a row, steps the looks; the ready pass fades by
-- a cell; and the update turns old lines into groups and cells. Says PASS or
-- FAIL per check. (Optional first argument: another .toc to load.)
local now = 100

-- luacheck: push ignore 111 112 113 121 122 212
local ns = dofile("Tools/offline/load.lua")("retail", arg and arg[1], function()
	GetTime = function() return now end
	InCombatLockdown = function() return true end
end)
-- luacheck: pop

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local db = ns.db
for _, start in ipairs({ "handleCooldowns", ns.CDM_TABS.essential, ns.CDM_TABS.utility, ns.CDM_TABS.buffs }) do
	local switch = start
	while switch do
		db[switch] = true
		switch = ns.PageSwitchOf(switch)
	end
end
Check("tables made at load", type(db.cooldownPlaceGroups) == "table" and type(db.cooldownSpellCells) == "table"
	and type(db.cooldownBuffCells) == "table" and type(db.cooldownGroupCells) == "table")
Check("numbered lines gone", db.cooldownSpellRules == nil and ns.CooldownRuleLines == nil and ns.CooldownRules == nil)

-- Where you are: faked facts.
local facts
local function Be(place, fight, extra)
	facts = { nocombat = not fight, combat = fight, calm = false }
	if place ~= "world" then facts[place] = true end
	for k, v in pairs(extra or {}) do facts[k] = v end
	facts.nocombat = not facts.combat and not facts.calm -- (as the real facts: Frames.lua's RuleFacts)
	ns.CooldownRuleFactsStale()
end
ns.RuleFactsNow = function() return facts end
Be("dungeon", true)

local IMMOLATE, CORRUPTION, AGONY = 348, 172, 980
local function Fits(group) return ns.CooldownGroupFits(group, facts) end

-- Fitting.
Check("Dungeons+Raids, In combat fits in a dungeon fight", Fits({ places = { dungeon = true, raid = true }, combat = "in" }))
Check("Raids alone doesn't", not Fits({ places = { raid = true }, combat = "any" }))
Check("Out of combat doesn't", not Fits({ places = { dungeon = true }, combat = "out" }))
Check("Anywhere fits", Fits({ places = { any = true }, combat = "any" }))
Check("no place picked never fits", not Fits({ places = {}, combat = "any" }))
Be("dungeon", false, { calm = true })
Check("Calm Timer counts as In combat", Fits({ places = { any = true }, combat = "in" }))
Be("dungeon", true)
Check("CQL group fits", Fits({ cql = "dungeon and not group" }))
Check("CQL that doesn't read never fits", not Fits({ cql = "dungeon and (" }))

-- Groups: add, the most, move, remove (its cells with it).
local g1 = ns.AddCooldownGroup()
g1.places, g1.combat = { dungeon = true, raid = true }, "in"
local g2 = ns.AddCooldownGroup()
g2.places, g2.combat = { city = true, inn = true }, "out"
Check("two groups, ids apart", g1 and g2 and g1.id ~= g2.id and #ns.CooldownPlaceGroups() == 2)
Check("names from places", ns.CooldownGroupName(g1) == ns.L["Dungeons"] .. ", " .. ns.L["Raids"] .. " · " .. ns.L["In combat"],
	ns.CooldownGroupName(g1))
g1.name = "Group content"
Check("own name wins", ns.CooldownGroupName(g1) == "Group content")
local extra = {}
for i = 1, 4 do extra[i] = ns.AddCooldownGroup() end
Check("no more than the most", extra[3] and extra[4] == nil and #ns.CooldownPlaceGroups() == ns.COOLDOWN_GROUP_MAX)
ns.SetCooldownCell("spell", IMMOLATE, extra[1].id, "never")
ns.RemoveCooldownGroup(extra[1].id)
Check("removed with its cells", ns.CooldownPlaceGroup(extra[1].id) == nil and ns.CooldownCell("spell", IMMOLATE, extra[1].id) == nil
	and db.cooldownSpellCells[IMMOLATE] == nil)
ns.RemoveCooldownGroup(extra[2].id)
ns.RemoveCooldownGroup(extra[3].id)

-- In use: the first that fits; a row's cell, else (a spell) its bar's cell,
-- else its own Otherwise, else its bar's.
local _, index = ns.CooldownGroupNow()
Check("Group content in use in a dungeon fight", index == 1, index)
db.cooldownProcOnly[IMMOLATE] = true
ns.SetCooldownCell("spell", IMMOLATE, g1.id, "ready")
local mode, own = ns.CooldownSpellMode(IMMOLATE, "essential")
Check("its own cell decides", mode == "ready" and own == true, mode)
ns.SetCooldownCell("spell", IMMOLATE, g1.id, nil)
ns.SetCooldownCell("group", "essential", g1.id, "never")
mode, own = ns.CooldownSpellMode(IMMOLATE, "essential")
Check("its bar's cell next, before its own Otherwise", mode == "never" and own == false, mode)
ns.SetCooldownCell("group", "essential", g1.id, nil)
Check("no cell: its own Otherwise (When it procs)", (ns.CooldownSpellMode(IMMOLATE, "essential")) == "proc")
db.cooldownProcOnly[IMMOLATE] = nil
db.cooldownGroupDefaults.essential = { mode = "recharge" }
Check("then its bar's Otherwise", (ns.CooldownSpellMode(IMMOLATE, "essential")) == "recharge")
db.cooldownGroupDefaults.essential = nil
ns.SetCooldownCell("spell", IMMOLATE, g2.id, "never")
Check("a later group's cell doesn't count while an earlier one's in use",
	(ns.CooldownSpellMode(IMMOLATE, "essential")) ~= "never")
Be("city", false)
Check("in a city out of fights: Town's cell", (ns.CooldownSpellMode(IMMOLATE, "essential")) == "never")
Check("page view (own false) skips cells", (ns.CooldownSpellMode(IMMOLATE, "essential", false)) ~= "never")
ns.SetCooldownCell("spell", IMMOLATE, g2.id, nil)
Be("dungeon", true)
ns.SetCooldownCell("group", "utility", g1.id, "never")
Check("bar's cell in CooldownGroupSettings", (ns.CooldownGroupSettings("utility")) == "never")
ns.SetCooldownCell("group", "utility", g1.id, nil)

-- Its base spell's cells.
local baseSpell = ns.BaseSpell
ns.BaseSpell = function(id) return id == 99348 and IMMOLATE or baseSpell(id) end
ns.SetCooldownCell("spell", IMMOLATE, g1.id, "never")
Check("override reads its base's cells", (ns.CooldownSpellMode(99348, "essential")) == "never")
ns.SetCooldownCell("spell", IMMOLATE, g1.id, nil)
ns.BaseSpell = baseSpell

-- When ready parts: its own (set from the grid's strip) or its bar's.
ns.SetCooldownCell("spell", CORRUPTION, g1.id, "ready")
db.cooldownGroupDefaults.essential = { power = true, early = 3, anyTime = true }
local m, _, power, earlyOn, early, anyTime = ns.CooldownSpellMode(CORRUPTION, "essential")
Check("ready cell takes its bar's parts", m == "ready" and power == true and earlyOn == true and early == 3 and anyTime == true,
	("%s %s %s %s"):format(tostring(m), tostring(power), tostring(early), tostring(anyTime)))
ns.CooldownSetReadyPart("spell", CORRUPTION, "essential", "early", 7)
local _, _, power2, _, early2 = ns.CooldownSpellMode(CORRUPTION, "essential")
Check("its own parts once one's set (seeded from its bar's)", power2 == true and early2 == 7,
	("%s %s"):format(tostring(power2), tostring(early2)))
Check("its Otherwise untouched by its parts", db.cooldownReadyOnly[CORRUPTION] == nil)
for _, key in ipairs({ "cooldownEarlyOn", "cooldownReadyEarly", "cooldownNeedsPower", "cooldownReadyAnyTime" }) do
	db[key][CORRUPTION] = nil
end
ns.SetCooldownCell("spell", CORRUPTION, g1.id, nil)
db.cooldownGroupDefaults.essential = nil

-- Tracked buffs: its cell, its bar's cell, its own.
ns.SetCooldownCell("buff", 1126, g1.id, "hidden")
Check("buff's cell decides", (ns.CooldownBuffMode(1126, "buffs")) == "hidden")
ns.SetCooldownCell("buff", 1126, g1.id, nil)
ns.SetCooldownCell("group", "buffs", g1.id, "quiet")
db.cooldownBuffMode[1126] = "always"
Check("bar's cell before the buff's own", (ns.CooldownBuffMode(1126, "buffs")) == "quiet")
ns.SetCooldownCell("group", "buffs", g1.id, nil)
Check("then its own", (ns.CooldownBuffMode(1126, "buffs")) == "always")
db.cooldownBuffMode[1126] = nil

-- Trouble: a group never in use, one with no place, Otherwise never in use; CQL not judged.
local g3 = ns.AddCooldownGroup()
g3.places, g3.combat = { raid = true }, "in"
local trouble, otherDead = ns.CooldownGroupTrouble()
Check("Raids in combat after Group content: never used", trouble[3] and trouble[3].kind == "dead"
	and trouble[3].by[1] == "Group content", trouble[3] and trouble[3].kind)
Check("the first two fine", trouble[1] == nil and trouble[2] == nil)
Check("Otherwise still used", not otherDead)
ns.MoveCooldownGroup(g3.id, -1)
ns.MoveCooldownGroup(g3.id, -1)
trouble = ns.CooldownGroupTrouble()
Check("moved first: it's fine, Group content still has Dungeons", trouble[1] == nil and trouble[2] == nil,
	trouble[2] and trouble[2].kind)
g3.places = {}
trouble = ns.CooldownGroupTrouble()
Check("no place: not finished", trouble[1] and trouble[1].kind == "todo")
g3.places, g3.combat = { any = true }, "any"
trouble, otherDead = ns.CooldownGroupTrouble()
Check("Anywhere first: the rest and Otherwise never used", trouble[2] and trouble[2].kind == "dead"
	and trouble[3] and otherDead)
g3.places, g3.combat = nil, nil
g3.cql = "boss"
trouble = ns.CooldownGroupTrouble()
Check("a CQL group isn't judged", trouble[1] == nil and trouble[2] == nil)
ns.RemoveCooldownGroup(g3.id)

-- A rule typed for a group.
local probe = { id = 99, name = "", places = { dungeon = true }, combat = "in" }
Check("its places as a rule", ns.CooldownGroupText(probe) == "dungeon and (combat or calm)", ns.CooldownGroupText(probe))
probe.places = { dungeon = true, raid = true }
Check("two places as a rule", ns.CooldownGroupText(probe) == "(dungeon or raid) and (combat or calm)")
ns.SetCooldownGroupText(probe, "(dungeon or raid) and (combat or calm)")
Check("the same words keep its places", probe.cql == nil and probe.places.raid)
ns.SetCooldownGroupText(probe, "raid and boss")
Check("other words: its rule", probe.cql == "raid and boss" and probe.places == nil)
Check("a rule that doesn't read is refused", ns.SetCooldownGroupText(probe, "raid and (") == false and probe.cql == "raid and boss")
ns.SetCooldownGroupText(probe, " ")
Check("emptied: back to places, none picked", probe.cql == nil and probe.places and next(probe.places) == nil)

-- The page's grid.
do
	local cdmSpells = ns.CooldownManagerSpells
	ns.CooldownManagerSpells = function()
		return { { id = IMMOLATE, group = "essential" }, { id = CORRUPTION, group = "essential" }, { id = AGONY, group = "essential" } }
	end
	local okShow, err = pcall(ns.CdmShowSpells, "essential")
	Check("page shows the Essential grid", okShow, err)
	local grid, button = ns.CdmPageGrid()
	Check("grid made", grid ~= nil and grid.state.tab == "essential")
	local function Click(frame, mouse) frame:GetScript("OnClick")(frame, mouse or "LeftButton") end
	local function RowOf(key)
		for _, row in ipairs(grid.rows) do
			if row.key == key then return row end
		end
	end
	if grid then
		local cols = grid.Columns()
		Check("columns: two groups, then Otherwise", #cols == 3 and cols[1].id == g1.id and cols[3].other, #cols)
		local bar, im = RowOf("essential"), RowOf(IMMOLATE)
		Check("the bar's row first, then the spells", grid.rows[1] == bar and grid.rows[2] == im and RowOf(AGONY) ~= nil)
		Check("no tick box on the bar's row", not bar.check:IsShown() and im.check:IsShown())
		Check("a spell's cell follows (grey) until set", im.cells[1].style == "follow", im.cells[1].style)
		-- The look, 2026-11-22: the bar's Otherwise gold, columns no wider than
		-- 120 from the left, the add column before Otherwise, the bar's row by a
		-- short name, ticks only under the pointer or while one's ticked.
		Check("the bar's Otherwise looks like the bar (gold), its default too", bar.cells[3].style == "bar", bar.cells[3].style)
		Check("columns 120 at most", grid.layout.colW <= 120, grid.layout.colW)
		Check("+ Add group: a small pill at the headings' end with groups", grid.layout.plusShown and grid.plus:IsShown()
			and not grid.addCard:IsShown() and grid.plus.text:GetText() == ns.L["Add scene"], grid.plus.text:GetText())
		-- The restyle (2026-11-22): pills in each choice's color, a band only when set.
		Check("a set cell has its band in its color", (function()
			ns.SetCooldownCell("spell", IMMOLATE, g1.id, "ready")
			grid.Layout()
			local c = im.cells[1]
			local ok = c.style == "own" and c.band.mid:IsShown() and c.icon:IsShown() and c.mode == "ready"
			ns.SetCooldownCell("spell", IMMOLATE, g1.id, nil)
			grid.Layout()
			return ok
		end)())
		Check("a following cell: no band, still its icon", not im.cells[1].band.mid:IsShown() and im.cells[1].icon:IsShown())
		Check("the bar's row: its gold band and what it is", bar.band:IsShown() and bar.sub:IsShown() and not im.sub:IsShown())
		Check("bar's row: Essential bar", bar.label:GetText() == ns.L["%s bar"]:format(ns.L["Essential"]), bar.label:GetText())
		local function NotOver(row)
			for _, frame in ipairs({ row.name, row.check, unpack(row.cells) }) do
				frame.IsMouseOver = function() return false end
			end
		end
		NotOver(im)
		im.ShowTick()
		Check("tick box unseen with no pointer and none ticked", im.tickSeen == false)
		im.name.IsMouseOver = function() return true end
		im.ShowTick()
		Check("seen under the pointer", im.tickSeen == true)
		im.name.IsMouseOver = function() return false end
		im.ShowTick()
		do
			local kept = db.cooldownPlaceGroups
			db.cooldownPlaceGroups = {}
			grid.Layout()
			local otherHead
			for _, child in ipairs({ grid:GetChildren() }) do
				if child.col and child.col.other and child.sub then otherHead = child end
			end
			Check("no groups: the card saying what a group is, no pill", grid.addCard:IsShown() and not grid.plus:IsShown()
				and grid.addCard.title:GetText() == ns.L["Icons show the same in every scene"])
			Check("no groups: no in-use dot on Otherwise", otherHead and not otherHead.dot:IsShown())
			db.cooldownPlaceGroups = kept
			ns.CooldownRuleFactsStale()
			grid.Layout()
		end
		-- A cell: click opens its choices under the row; a choice sets it.
		Click(im.cells[1])
		Check("click opens its choices", grid.chooser:IsShown() and grid.state.open and grid.state.open.key == IMMOLATE)
		Check("first choice: Same as bar", grid.choices[1].value == nil
			and grid.choices[1].text:GetText():find(ns.L["Same as bar (%s)"]:match("^[^(]+"), 1, true) ~= nil,
			grid.choices[1].text:GetText())
		local readyChoice
		for _, box in ipairs(grid.choices) do
			if box:IsShown() and box.value == "ready" then readyChoice = box end
		end
		Click(readyChoice)
		Check("choosing When ready sets its cell", ns.CooldownCell("spell", IMMOLATE, g1.id) == "ready"
			and im.cells[1].style == "own", im.cells[1].style)
		Check("When ready's parts show in the strip", grid.readyParts.power:IsShown() and grid.readyParts.early:IsShown())
		Click(grid.readyParts.power)
		-- (The stand-in's tick doesn't toggle itself: GetChecked as it was, so set first.)
		grid.readyParts.power:SetChecked(true)
		Click(grid.readyParts.power)
		Check("Wait for resources sets its own part", db.cooldownNeedsPower[IMMOLATE] == true)
		Click(im.cells[1], "RightButton")
		Check("right-click: back to following", ns.CooldownCell("spell", IMMOLATE, g1.id) == nil and im.cells[1].style == "follow")
		Click(im.cells[1])
		Click(im.cells[1])
		Check("clicking the open cell shuts it", not grid.chooser:IsShown())
		-- The bar's Otherwise has no "follow": its first choice is the built-in default.
		Click(bar.cells[3])
		Check("bar's Otherwise: a Default choice first", grid.choices[1].value == nil
			and grid.choices[1].text:GetText():find("Default", 1, true) ~= nil, grid.choices[1].text:GetText())
		Click(bar.cells[3])
		-- A group's heading: its editor.
		local head
		for _, child in ipairs({ grid:GetChildren() }) do
			if child.col and child.col.id == g2.id and child.sub then head = child end
		end
		Check("Town's heading found", head ~= nil)
		if head then
			Click(head)
			Check("heading opens the editor", grid.editor:IsShown() and grid.state.editing == g2.id)
			local function PlaceButton(place)
				for _, b in ipairs(grid.placeButtons) do
					if b.place == place then return b end
				end
			end
			Click(PlaceButton("world"))
			Check("a place added (any number)", g2.places.world and g2.places.city and g2.places.inn)
			Click(PlaceButton("world"))
			Check("and taken out", not g2.places.world and g2.places.city)
			Click(PlaceButton("any"))
			Check("Anywhere alone", g2.places.any and not g2.places.city)
			Click(PlaceButton("raid"))
			Check("a place off Anywhere: every other one", g2.places.city and g2.places.dungeon and not g2.places.raid
				and not g2.places.any)
			Click(PlaceButton("raid"))
			Check("all of them: Anywhere again", g2.places.any == true)
			g2.places = { city = true, inn = true }
			for _, b in ipairs(grid.combatButtons) do
				if b.combat == "in" then Click(b) end
			end
			Check("combat picked", g2.combat == "in")
			g2.combat = "out"
			Click(grid.moveButtons[1])
			Check("moved left", ns.CooldownPlaceGroups()[1] == g2)
			Click(grid.moveButtons[2])
			Check("moved back", ns.CooldownPlaceGroups()[2] == g2)
			Click(head)
			Check("heading again shuts it", not grid.editor:IsShown())
		end
		-- + adds a group, its editor open; Delete twice removes it.
		Click(grid.plus)
		local added = ns.CooldownPlaceGroups()[3]
		Check("+ adds a group with its editor open", added and grid.state.editing == added.id and grid.editor:IsShown())
		Check("a new group with no place is flagged", grid.troubleLines[1] and grid.troubleLines[1]:IsShown())
		Click(grid.deleteButton)
		Check("Delete asks first", ns.CooldownPlaceGroup(added.id) ~= nil and grid.deleteButton.text:GetText() == ns.L["Sure?"])
		Click(grid.deleteButton)
		Check("then deletes", ns.CooldownPlaceGroup(added.id) == nil and not grid.editor:IsShown())
		-- Ticked rows: set one column of them all; copy one onto another.
		Click(RowOf(CORRUPTION).check)
		Click(RowOf(AGONY).name)
		Check("two ticked: the bar shows", grid.bulk:IsShown() and grid.state.selected[CORRUPTION] and grid.state.selected[AGONY])
		local b = grid.bulkButtons
		Click(b.value)
		Click(b.value)
		Click(b.set)
		Check("Set: both get When ready in Group content", ns.CooldownCell("spell", CORRUPTION, g1.id) == "ready"
			and ns.CooldownCell("spell", AGONY, g1.id) == "ready")
		Check("Copy row only with one ticked", not b.copy:IsShown())
		Click(RowOf(AGONY).check)
		ns.SetCooldownCell("spell", CORRUPTION, g2.id, "never")
		Click(b.copy)
		Click(RowOf(CORRUPTION).check)
		Click(RowOf(IMMOLATE).check)
		Click(b.paste)
		Check("Paste row: its cells copied", ns.CooldownCell("spell", IMMOLATE, g1.id) == "ready"
			and ns.CooldownCell("spell", IMMOLATE, g2.id) == "never")
		Click(b.clear)
		Check("x unticks all", not grid.bulk:IsShown() and next(grid.state.selected) == nil)
		-- Look: each click the next value, a spell's round to following.
		Click(grid.lookSwitch)
		cols = grid.Columns()
		Check("Look columns", cols[1].look == "numbers" and cols[4].look == "flash" and #cols == 4)
		im = RowOf(IMMOLATE)
		db.cooldownFlashReady[IMMOLATE] = nil
		local seen = {}
		for i = 1, 3 do
			Click(im.cells[4])
			seen[i] = tostring(db.cooldownFlashReady[IMMOLATE])
		end
		Check("Flash steps following -> On -> Off -> following", table.concat(seen, " ") == "true false nil", table.concat(seen, " "))
		Check("the bar's own looks under the grid", grid.extraParts.center and grid.extraParts.center.box:IsShown())
		local was = ns.CooldownGroupCentered("essential")
		Click(grid.extraParts.center.box)
		Check("Close the gaps steps", ns.CooldownGroupCentered("essential") ~= was)
		Click(grid.extraParts.center.box)
		Click(grid.showsSwitch)
		Check("back to When it shows", not grid.state.look)
		Check("the bar's looks line gone with Look", not grid.extras:IsShown())
	end
	-- Open CDM: says Close CDM while the game's window is open, however it was opened.
	Check("Open CDM button found", button ~= nil)
	if button then
		local window = CreateFrame("Frame", "CooldownViewerSettings")
		window:Hide()
		button:GetScript("OnShow")(button)
		Check("shut: Open CDM", button:GetText() == ns.L["Open CDM"], button:GetText())
		button:GetScript("OnClick")(button)
		Check("clicked: window open, Close CDM", window:IsShown() and button:GetText() == ns.L["Close CDM"], button:GetText())
		button:GetScript("OnClick")(button)
		Check("clicked again: shut, Open CDM", not window:IsShown() and button:GetText() == ns.L["Open CDM"], button:GetText())
		_G.CooldownViewerSettings = nil
	end
	ns.CooldownManagerSpells = cdmSpells
	for _, name in ipairs({ "cooldownSpellCells", "cooldownGroupCells" }) do wipe(db[name]) end
	db.cooldownNeedsPower[IMMOLATE], db.cooldownEarlyOn[IMMOLATE], db.cooldownReadyEarly[IMMOLATE] = nil, nil, nil
	db.cooldownReadyAnyTime[IMMOLATE] = nil
end

-- The ready pass on the stand-in: Corruption Never in Group content, Agony
-- with no cell; in a dungeon fight Corruption fades, Agony stays.
local function Icon(id)
	local icon = CreateFrame("Frame")
	icon.GetSpellID = function() return id end
	icon:Show()
	return icon
end
local cor, agony = Icon(CORRUPTION), Icon(AGONY)
local viewer = CreateFrame("Frame", "EssentialCooldownViewer")
viewer:Show()
viewer.itemFramePool = { EnumerateActive = function()
	local all, i = { cor, agony }, 0
	return function() i = i + 1 return all[i] end
end }
viewer.GetChildren = function() return cor, agony end
ns.managed[#ns.managed + 1] = { frame = viewer, name = "EssentialCooldownViewer", group = "cooldowns", alpha = 1,
	baseAlpha = 1 }
db.cooldownAlwaysShow[CORRUPTION], db.cooldownAlwaysShow[AGONY] = true, true
ns.SetCooldownCell("spell", CORRUPTION, g1.id, "never")
local function Pass()
	ns.CooldownRuleFactsStale()
	ns.readyPace.due = true
	now = now + 1
	local okPass, err = pcall(ns.UpdateReadyOnly, 0.1)
	if not okPass then return nil, err end
	return ns.ReadyIconProbe(CORRUPTION), ns.ReadyIconProbe(AGONY)
end
Be("dungeon", true)
local pc, pa = Pass()
Check("ready pass: in a dungeon fight, the cell's Never fades it", pc and pc.target == 0, pc and tostring(pc.target) or pa)
Check("ready pass: the one with no cell stays", pa and pa.target ~= 0, pa and tostring(pa.target))
Be("world", true)
pc = Pass()
Check("ready pass: in the open world, its own Always", pc and pc.target ~= 0, pc and tostring(pc.target))
ns.SetCooldownCell("spell", CORRUPTION, g1.id, nil)

-- The update: numbered lines into groups and cells (here and in a saved profile).
local function Lines()
	return {
		cooldownGroupRules = { utility = { { show = "ready", combat = "in", place = "dungeon" } } },
		cooldownSpellRules = {
			[IMMOLATE] = { { show = "proc", combat = "in", place = "dungeon" }, { show = "always", cql = "raid and boss" },
				{ show = "never", combat = "in", place = "dungeon" } },
			[CORRUPTION] = { { show = "", combat = "any", place = "none" } },
		},
		cooldownBuffRules = { [1126] = { { show = "hidden", combat = "out", place = "city" } } },
	}
end
for k, v in pairs(Lines()) do db[k] = v end
db.profiles = db.profiles or {}
db.profiles.GridTest = Lines()
db.cooldownGridV1 = nil
ns.RunMigrations()
local groups = db.cooldownPlaceGroups
Check("lines dropped", db.cooldownSpellRules == nil and db.cooldownGroupRules == nil and db.profiles.GridTest.cooldownSpellRules == nil)
Check("three wheres, three groups (the bar's first)", #groups == 3 and groups[1].places.dungeon and groups[1].combat == "in"
	and groups[2].cql == "raid and boss" and groups[3].places.city and groups[3].combat == "out", #groups)
Check("bar's cell", db.cooldownGroupCells.utility and db.cooldownGroupCells.utility[1] == "ready")
Check("a row's first line for a where wins", db.cooldownSpellCells[IMMOLATE][1] == "proc"
	and db.cooldownSpellCells[IMMOLATE][2] == "always")
Check("an unfinished line adds nothing", db.cooldownSpellCells[CORRUPTION] == nil)
Check("buff's cell", db.cooldownBuffCells[1126] and db.cooldownBuffCells[1126][3] == "hidden")
local saved = db.profiles.GridTest
Check("saved profile converted too", saved.cooldownPlaceGroups and #saved.cooldownPlaceGroups == 3
	and saved.cooldownSpellCells[IMMOLATE][1] == "proc")
Check("done flag set", db.cooldownGridV1 == true)

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
os.exit(fails == 0 and 0 or 1)
