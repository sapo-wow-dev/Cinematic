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
Check("a new scene named on its own", g1.name == ns.L["Scene %d"]:format(1) and g2.name == ns.L["Scene %d"]:format(2),
	g2.name)
g1.name = ""
Check("no name: named by its places", ns.CooldownGroupName(g1) == ns.L["Dungeons"] .. ", " .. ns.L["Raids"] .. " · " .. ns.L["In combat"],
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
-- (Moved onto the base as the page lists spells: with both holding cells, the
-- override's the base hasn't got kept, not dropped. Audit 2026-11-22.)
db.cooldownSpellCells[IMMOLATE] = { [g1.id] = "never" }
db.cooldownSpellCells[99348] = { [g1.id] = "always", [g2.id] = "proc" }
db.cooldownRowSettings = db.cooldownRowSettings or {}
db.cooldownRowSettings[99348] = { numbers = "hide" }
ns.CooldownKeysToBase()
local cellsNow = db.cooldownSpellCells[IMMOLATE] or {}
Check("keys to base: the base's own cell wins", cellsNow[g1.id] == "never", tostring(cellsNow[g1.id]))
Check("keys to base: the override's other cell kept", cellsNow[g2.id] == "proc", tostring(cellsNow[g2.id]))
Check("keys to base: the override's row setting moved", db.cooldownRowSettings[IMMOLATE]
	and db.cooldownRowSettings[IMMOLATE].numbers == "hide" and db.cooldownSpellCells[99348] == nil)
db.cooldownSpellCells[IMMOLATE], db.cooldownRowSettings[IMMOLATE] = nil, nil
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
		-- (Ghost cells since 2026-11-22: a following cell shows faint.)
		Check("a spell's cell follows (a ghost) until set", im.cells[1].style == "ghost", im.cells[1].style)
		-- The look, 2026-11-22: the bar's Otherwise gold, columns no wider than
		-- 120 from the left, the add column before Otherwise, the bar's row by a
		-- short name, ticks only under the pointer or while one's ticked.
		Check("the bar's Otherwise looks like the bar (gold), its default too", bar.cells[3].style == "bar", bar.cells[3].style)
		Check("columns 190 at most", grid.layout.colW <= 190, grid.layout.colW)
		-- The bar's tab warns when a cell on it never takes effect (2026-11-22).
		do
			local tabs = select(4, ns.CdmPageGrid())
			local tab = tabs and tabs[1]
			Check("no warning on the tab to start", tab and not (tab.warnMark and tab.warnMark:IsShown()))
			local dead = ns.AddCooldownGroup()
			dead.places, dead.combat = { dungeon = true }, "in" -- (Group content, first, takes it all)
			ns.SetCooldownCell("spell", CORRUPTION, dead.id, "proc")
			grid.Changed()
			Check("a cell in a scene that never applies: ! on the tab", tab and tab.warnMark and tab.warnMark:IsShown()
				and tab.warnLines and tab.warnLines[1]:find(dead.name, 1, true) ~= nil, tab and tab.warnLines and tab.warnLines[1])
			ns.SetCooldownCell("spell", CORRUPTION, dead.id, nil)
			grid.Changed()
			Check("cleared: no ! on the tab", tab and not tab.warnMark:IsShown())
			ns.RemoveCooldownGroup(dead.id)
			grid.Changed()
		end
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
		Check("a following cell: a ghost (its icon faint in an outline, no band, no word)", not im.cells[1].band.mid:IsShown()
			and im.cells[1].icon:IsShown() and not im.cells[1].text:IsShown() and im.cells[1].ring.mid:IsShown())
		Check("the bar on a card of its own, no SPELLS label", grid.barCard:IsShown() and not grid.spellsLabel:IsShown())
		Check("the bar's row: its name alone", not bar.sub:IsShown())
		-- (The tab's name, no "bar": the user, 2026-11-22.)
		Check("bar's row: Essentials", bar.label:GetText() == ns.L["Essentials"], bar.label:GetText())
		local function NotOver(row)
			for _, frame in ipairs({ row.name, row.check, unpack(row.cells) }) do
				frame.IsMouseOver = function() return false end
			end
		end
		NotOver(im)
		im.ShowTick()
		-- The previewer: a dungeon fight from anywhere; the grid rings what decides; back to live.
		do
			-- (The stand-in is in a fight at load: the previewer won't start in one.)
			local lockdown = InCombatLockdown
			InCombatLockdown = function() return false end -- luacheck: ignore 121
			Be("city", false)
			ns.SetCooldownCell("spell", IMMOLATE, g1.id, "proc")
			ns.SetCooldownPreview("dungeon", "in")
			grid.Layout()
			local _, at = ns.CooldownGroupNow()
			Check("previewing a dungeon fight: Group content in use, though we're in a city", at == 1, at)
			Check("the CDM reads it too", (ns.CooldownSpellMode(IMMOLATE, "essential")) == "proc")
			Check("the banner shows, Immolate's Group content cell decides", grid.banner:IsShown() and im.cells[1].decides == true
				and not im.cells[2].decides)
			Check("a following spell: Otherwise rings, filled faint", RowOf(CORRUPTION).cells[3].ringed == true
				and RowOf(CORRUPTION).cells[3].style == "inherited")
			ns.SetCooldownPreview(nil)
			grid.Layout()
			local _, live = ns.CooldownGroupNow()
			Check("back to live: the city again, no banner, no rings", live ~= 1 and not grid.banner:IsShown() and not im.cells[1].ringed)
			-- (Place and combat each on its own, 2026-11-22.)
			ns.SetCooldownPreview("dungeon", nil)
			Check("a place alone: your own fight state kept", ns.CooldownPreview().combat == nil
				and ns.CooldownPreview().label == ns.L["Dungeon"], ns.CooldownPreview().label)
			ns.SetCooldownPreview(nil, "out")
			Check("combat alone: where you are, out of combat", ns.CooldownRuleFacts().nocombat == true
				and ns.CooldownPreview().place == nil)
			local menuBox
			for _, b in ipairs(grid.previewItems) do
				if b.which == "place" and b.value == "raid" then menuBox = b end
			end
			Click(menuBox)
			Check("picking a place keeps the combat picked", ns.cdmPreview.place == "raid" and ns.cdmPreview.combat == "out")
			Check("no Town to preview", (function()
				for _, b in ipairs(grid.previewItems) do
					if b.value == "town" then return false end
				end
				return true
			end)())
			ns.SetCooldownPreview("dungeon", "in")
			grid:GetScript("OnHide")(grid)
			Check("the page hidden: back to live", ns.cdmPreview == nil)
			InCombatLockdown = function() return true end -- luacheck: ignore 121
			ns.SetCooldownPreview("dungeon", "in")
			Check("no preview in a fight", ns.cdmPreview == nil)
			InCombatLockdown = lockdown -- luacheck: ignore 121
			ns.SetCooldownCell("spell", IMMOLATE, g1.id, nil)
			Be("dungeon", true)
			grid.Layout()
		end
		Check("tick boxes hidden till Select", im.tickSeen == false)
		Click(grid.selectButton)
		Check("Select shows the tick boxes (not the bar's)", im.tickSeen == true and grid.rows[1].tickSeen == false)
		Click(grid.selectButton)
		Check("Done hides them again", im.tickSeen == false)
		-- When ready's label says it's the spell's everywhere; Out of fights too only while on.
		ns.SetCooldownCell("spell", IMMOLATE, g1.id, "ready")
		grid.Layout()
		Click(im.cells[1])
		Check("When ready parts say for this spell everywhere", grid.readyParts.power:IsShown()
			and not grid.readyParts.anyTime:IsShown())
		Click(im.cells[1])
		ns.SetCooldownCell("spell", IMMOLATE, g1.id, nil)
		grid.Layout()
		Check("the editor says every bar uses a scene", (function()
			grid.state.editing = g1.id
			grid.Layout()
			local ok = grid.editor:IsShown()
			grid.state.editing = nil
			grid.Layout()
			return ok
		end)())
		do
			local kept = db.cooldownPlaceGroups
			db.cooldownPlaceGroups = {}
			grid.Layout()
			local otherHead
			for _, child in ipairs({ grid:GetChildren() }) do
				if child.col and child.col.other and child.sub and child:IsShown() then otherHead = child end
			end
			Check("no groups: no card, just + Add scene", not grid.addCard:IsShown() and grid.plus:IsShown())
			Check("no groups: no in-use dot on Otherwise", otherHead and not otherHead.dot:IsShown())
			Check("no scenes: the column is headed Shows, not Otherwise", otherHead and otherHead.text:GetText() == ns.L["Shows"],
				otherHead and otherHead.text:GetText())
			-- (A leftover tab warning goes on the page's next refresh.)
			local tab = select(4, ns.CdmPageGrid())[1]
			if tab and tab.warnMark then
				tab.warnMark:Show()
				tab.warnLines = { "stale" }
				grid.Refresh()
				Check("a stale tab warning cleared on refresh", not tab.warnMark:IsShown())
			end
			db.cooldownPlaceGroups = kept
			ns.CooldownRuleFactsStale()
			grid.Layout()
		end
		-- A cell: click opens its choices under the row; a choice sets it.
		Click(im.cells[1])
		Check("click opens its choices", grid.chooser:IsShown() and grid.state.open and grid.state.open.key == IMMOLATE)
		-- (Names what it really follows: the bar has no cell here, so its own Otherwise. Audit, 2026-11-22.)
		Check("first choice: what it follows (no bar cell: Same as everywhere else)", grid.choices[1].value == nil
			and grid.choices[1].text:GetText():find(ns.L["As everywhere else (%s)"]:match("^[^(]+"), 1, true) ~= nil,
			grid.choices[1].text:GetText())
		local readyChoice
		for _, box in ipairs(grid.choices) do
			if box:IsShown() and box.value == "ready" then readyChoice = box end
		end
		Click(readyChoice)
		Check("choosing When ready sets its cell", ns.CooldownCell("spell", IMMOLATE, g1.id) == "ready"
			and im.cells[1].style == "own", im.cells[1].style)
		Check("When ready's parts show in the strip", grid.readyParts.power:IsShown() and grid.readyParts.early:IsShown())
		-- (A toggle chip now: one click turns it on, 2026-11-22.)
		Click(grid.readyParts.power)
		Check("Wait for resources sets its own part", db.cooldownNeedsPower[IMMOLATE] == true)
		Click(im.cells[1], "RightButton")
		Check("right-click: back to following", ns.CooldownCell("spell", IMMOLATE, g1.id) == nil and im.cells[1].style == "ghost")
		Click(im.cells[1])
		Click(im.cells[1])
		Check("clicking the open cell shuts it", not grid.chooser:IsShown())
		-- The pop-up (2026-11-22): over the grid, a pick closes it, a click away too.
		Click(im.cells[1])
		local neverChoice
		for _, box in ipairs(grid.choices) do
			if box:IsShown() and box.value == "never" then neverChoice = box end
		end
		Click(neverChoice)
		Check("a pick (not When ready) closes the pop-up", not grid.chooser:IsShown()
			and ns.CooldownCell("spell", IMMOLATE, g1.id) == "never")
		ns.SetCooldownCell("spell", IMMOLATE, g1.id, nil)
		Click(im.cells[1])
		local catcher
		for _, child in ipairs({ grid:GetChildren() }) do
			if child ~= grid.chooser and child:IsShown() and child:GetScript("OnClick") and not child.col and not child.text
				and not child.check then catcher = catcher or child end
		end
		Check("a click away closes it", catcher ~= nil and (function()
			catcher:GetScript("OnClick")(catcher)
			return not grid.chooser:IsShown()
		end)())
		-- Five scenes: each cell its icon alone, the places under the names hidden,
		-- one line for the three with no places.
		local more = {}
		for i = 1, 3 do more[i] = ns.AddCooldownGroup() end
		grid.Layout()
		local subs = 0
		for _, child in ipairs({ grid:GetChildren() }) do
			if child.col and child.sub and child:IsShown() and child.sub:IsShown() then subs = subs + 1 end
		end
		local lines = 0
		for _, line in ipairs(grid.troubleLines) do
			if line:IsShown() then lines = lines + 1 end
		end
		Check("five scenes: icons alone", grid.layout.compact and im.cells[1].compact and not im.cells[1].text:IsShown())
		Check("five scenes: no notes under names (cut short; the lines under say it)", subs == 0, subs)
		Check("three with no places: one line for them", lines == 1 and grid.troubleLines[1]:GetText():find(more[3].name, 1, true) ~= nil,
			lines)
		Check("+ Add scene gone at five", not grid.plus:IsShown())
		for i = 1, 3 do ns.RemoveCooldownGroup(more[i].id) end
		grid.Layout()
		Check("back to two: not narrow again", not grid.layout.compact and not im.cells[1].compact)
		-- (A following cell: its faint icon alone; a set one: its word too.)
		ns.SetCooldownCell("spell", IMMOLATE, g1.id, "proc")
		grid.Layout()
		Check("a set cell shows its word, a following one its faint icon alone", im.cells[1].text:IsShown()
			and not im.cells[2].text:IsShown() and im.cells[2].icon:IsShown())
		ns.SetCooldownCell("spell", IMMOLATE, g1.id, nil)
		grid.Layout()
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
			-- (The standard Show in row since 2026-11-22: Combat and Location
			-- dropdowns of ticks, the pen for a rule.)
			local function Tick(entries, field, value)
				for _, entry in ipairs(entries) do
					if entry[field] == value then entry[3]() end
				end
				grid.Layout()
			end
			local function On(entries, field, value)
				for _, entry in ipairs(entries) do
					if entry[field] == value then return entry[2]() end
				end
			end
			Check("the standard row shown, no rule", grid.whenRow:IsShown() and not grid.cqlButton:IsShown())
			-- (The Location list, 2026-11-22: Open world takes cities and inns
			-- with it, Instances is dungeons and raids, no Cities or Inns but on
			-- an old scene that has them without the open world.)
			local function Names()
				local out = {}
				for _, entry in ipairs(grid.placeEntries) do out[#out + 1] = entry.place end
				return table.concat(out, " ")
			end
			Check("a town scene still lists its towns", Names() == "world instance dungeon raid bg city inn", Names())
			Tick(grid.placeEntries, "place", "world")
			Check("Open world: the open world, cities and inns", g2.places.world and g2.places.city and g2.places.inn)
			Check("no town items once the open world has them", Names() == "world instance dungeon raid bg", Names())
			Check("its name says Open world alone", ns.CooldownGroupWhere(g2):find("^" .. ns.L["Open world"] .. " ·") ~= nil or ns.CooldownGroupWhere(g2) == ns.L["Open world"], ns.CooldownGroupWhere(g2))
			Tick(grid.placeEntries, "place", "world")
			Check("and taken out, towns with it", not g2.places.world and not g2.places.city and not g2.places.inn)
			Tick(grid.placeEntries, "place", "instance")
			Check("Instances: dungeons and raids", g2.places.dungeon and g2.places.raid and not g2.places.bg)
			Check("Dungeons and Raids show ticked with it", On(grid.placeEntries, "place", "dungeon") and On(grid.placeEntries, "place", "raid"))
			Tick(grid.placeEntries, "place", "raid")
			Check("Raids off: Instances off, Dungeons kept", not On(grid.placeEntries, "place", "instance") and g2.places.dungeon and not g2.places.raid)
			Tick(grid.placeEntries, "place", "world")
			Tick(grid.placeEntries, "place", "instance")
			Tick(grid.placeEntries, "place", "bg")
			Check("every item ticked: Anywhere", g2.places.any == true)
			Tick(grid.placeEntries, "place", "raid")
			Check("one off Anywhere: the rest", g2.places.world and g2.places.city and g2.places.dungeon and not g2.places.raid and not g2.places.any)
			Tick(grid.placeEntries, "place", "raid")
			Check("back to Anywhere", g2.places.any == true)
			g2.places = { city = true, inn = true }
			g2.combat = "any"
			grid.Layout()
			Check("any time: both ticked", On(grid.combatEntries, "combat", "in") and On(grid.combatEntries, "combat", "out"))
			Tick(grid.combatEntries, "combat", "out")
			Check("Out of combat off: In combat", g2.combat == "in")
			Tick(grid.combatEntries, "combat", "in")
			Check("the last one ticked stays", g2.combat == "in")
			Tick(grid.combatEntries, "combat", "out")
			Check("both again: any time", g2.combat == "any")
			Tick(grid.combatEntries, "combat", "out")
			Check("combat picked", g2.combat == "in")
			ns.SetCooldownGroupText(g2, "boss")
			grid.Layout()
			Check("a rule: its words in the dropdowns' place", grid.cqlButton:IsShown() and not grid.whenRow:IsShown())
			Click(grid.penButton)
			Check("the pen on a rule: back to the dropdowns", g2.cql == nil and grid.whenRow:IsShown())
			g2.places = { city = true, inn = true }
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
		local flagged = false
		for _, child in ipairs({ grid:GetChildren() }) do
			if child.col and child.col.id == added.id and child.sub and child.sub:GetText() == ns.L["pick places"] then flagged = true end
		end
		Check("a new scene with no place says pick places under its name (no second line)", flagged
			and not (grid.troubleLines[1] and grid.troubleLines[1]:IsShown()))
		Click(grid.deleteButton)
		Check("Delete asks first", ns.CooldownPlaceGroup(added.id) ~= nil and grid.deleteButton.text:GetText() == ns.L["Sure?"])
		Click(grid.deleteButton)
		Check("then deletes", ns.CooldownPlaceGroup(added.id) == nil and not grid.editor:IsShown())
		-- Ticked rows: set one column of them all; copy one onto another.
		Click(RowOf(CORRUPTION).check)
		Check("the name doesn't tick the row", RowOf(AGONY).name:GetScript("OnClick") == nil)
		Click(RowOf(AGONY).check)
		Check("two ticked: the bar shows", grid.bulk:IsShown() and grid.state.selected[CORRUPTION] and grid.state.selected[AGONY])
		local b = grid.bulkButtons
		-- (Lists to pick from, not the next each click: the user, 2026-11-22.)
		local function Menu(button)
			local kept, radios = ns.ContextMenu, {}
			ns.ContextMenu = function(_, make)
				make(nil, { CreateRadio = function(_, text, isOn, set)
					radios[#radios + 1] = { text = text, isOn = isOn, set = set }
				end })
			end
			Click(button)
			ns.ContextMenu = kept
			return radios
		end
		local function Pick(button, text)
			for _, radio in ipairs(Menu(button)) do
				if radio.text == text then radio.set() return true end
			end
		end
		local colWas = grid.state.bulkCol
		Check("the column chip opens a list of the columns", #Menu(b.col) == #grid.Columns() and grid.state.bulkCol == colWas)
		Check("the value chip: a list, picked from", Pick(b.value, ns.L["Ready"]))
		Click(b.set)
		Check("Set: both get When ready in Group content", ns.CooldownCell("spell", CORRUPTION, g1.id) == "ready"
			and ns.CooldownCell("spell", AGONY, g1.id) == "ready")
		Check("Copy row only with one ticked", not b.copy:IsShown())
		Click(RowOf(AGONY).check)
		ns.SetCooldownCell("spell", CORRUPTION, g2.id, "never")
		Click(b.copy)
		-- (Something shows it happened: the user, 2026-11-22.)
		Check("Copy says Copied, its row lit", b.copy.text:GetText() == ns.L["Copied"] and RowOf(CORRUPTION).flash:IsShown(),
			b.copy.text:GetText())
		Check("no Paste while only the copied row is ticked", not b.paste:IsShown())
		Click(RowOf(CORRUPTION).check)
		Click(RowOf(IMMOLATE).check)
		Check("Paste names what it puts", b.paste:IsShown() and b.paste.text:GetText():find("Paste", 1, true) ~= nil
			and b.paste.text:GetText():find(grid.state.clip.name:sub(1, 6), 1, true) ~= nil, b.paste.text:GetText())
		Click(b.paste)
		Check("Paste row: its cells copied", ns.CooldownCell("spell", IMMOLATE, g1.id) == "ready"
			and ns.CooldownCell("spell", IMMOLATE, g2.id) == "never")
		Check("Paste says how many, the row lit", b.paste.text:GetText() == ns.L["Pasted on %d"]:format(1)
			and RowOf(IMMOLATE).flash:IsShown(), b.paste.text:GetText())
		Click(b.clear)
		Check("x unticks all", not grid.bulk:IsShown() and next(grid.state.selected) == nil)
		-- Look: each click the next value, a spell's round to following.
		Click(grid.lookSwitch)
		cols = grid.Columns()
		Check("Look columns", cols[1].look == "numbers" and cols[4].look == "flash" and #cols == 4)
		im = RowOf(IMMOLATE)
		db.cooldownFlashReady[IMMOLATE] = nil
		local flashMenu = Menu(im.cells[4])
		Check("Flash: a list, following first, then its choices", #flashMenu == 3 and flashMenu[1].isOn(), #flashMenu)
		flashMenu[2].set()
		local picked = db.cooldownFlashReady[IMMOLATE]
		Check("Flash picked from the list", picked ~= nil, tostring(picked))
		Check("the bar's own looks under the grid", grid.extraParts.center and grid.extraParts.center.box:IsShown())
		local was = ns.CooldownGroupCentered("essential")
		local gaps = Menu(grid.extraParts.center.box)
		if #gaps > 0 then
			for _, radio in ipairs(gaps) do
				if not radio.isOn() then radio.set() break end
			end
		end
		Check("Close the gaps changed (a switch or a list)", ns.CooldownGroupCentered("essential") ~= was)
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

-- The update: numbered lines into scenes, done exactly (audit, 2026-11-22):
-- each spell decides in every place as its old lines did.
local function Lines()
	return {
		-- (The audit's: a bar's line, and a spell with a setting of its own.)
		cooldownGroupRules = { essential = { { show = "never", combat = "in", place = "dungeon" } } },
		cooldownAlwaysShow = { [IMMOLATE] = true },
		cooldownSpellRules = {
			-- (The audit's: each row's line order kept.)
			[100] = { { show = "ready", combat = "in", place = "any" } },
			[200] = { { show = "never", combat = "any", place = "dungeon" }, { show = "always", combat = "in", place = "any" } },
			[300] = { { show = "proc", cql = "boss" } },
			-- (The audit's: a place line before a CQL line beats it there, as before.)
			[400] = { { show = "never", combat = "in", place = "dungeon" }, { show = "always", cql = "group" } },
			[CORRUPTION] = { { show = "", combat = "any", place = "none" } },
		},
		cooldownBuffRules = { [1126] = { { show = "hidden", combat = "out", place = "city" } } },
	}
end
local function Fresh()
	for _, name in ipairs({ "cooldownPlaceGroups", "cooldownSpellCells", "cooldownBuffCells", "cooldownGroupCells",
		"cooldownReadyOnly", "cooldownRechargeOnly", "cooldownProcOnly", "cooldownAlwaysShow", "cooldownNeverShow",
		"cooldownBuffMode", "cooldownGroupDefaults" }) do db[name] = {} end
end
Fresh()
for k, v in pairs(Lines()) do db[k] = v end
db.profiles = db.profiles or {}
db.profiles.GridTest = Lines()
db.cooldownGridV1 = nil
ns.RunMigrations()
Check("lines dropped", db.cooldownSpellRules == nil and db.cooldownGroupRules == nil and db.profiles.GridTest.cooldownSpellRules == nil)
local function In(place, fight, extra) Be(place, fight, extra) end
In("dungeon", true)
Check("old order kept: spell 200 Never in a dungeon fight", (ns.CooldownSpellMode(200, "utility")) == "never",
	(ns.CooldownSpellMode(200, "utility")))
Check("spell 100 When ready in a dungeon fight", (ns.CooldownSpellMode(100, "utility")) == "ready")
Check("a spell's own Always beats its bar's old line, as before", (ns.CooldownSpellMode(IMMOLATE, "essential")) == "always",
	(ns.CooldownSpellMode(IMMOLATE, "essential")))
Check("a spell with nothing of its own takes its bar's line", (ns.CooldownSpellMode(AGONY, "essential")) == "never",
	(ns.CooldownSpellMode(AGONY, "essential")))
In("world", true)
Check("spell 200 Always in an open-world fight", (ns.CooldownSpellMode(200, "utility")) == "always")
In("world", false)
Check("spell 200 no line out of fights in the open world: its default", (ns.CooldownSpellMode(200, "utility")) ~= "always"
	and (ns.CooldownSpellMode(200, "utility")) ~= "never")
In("city", false)
Check("the buff hidden in a city out of fights", (ns.CooldownBuffMode(1126, "buffs")) == "hidden")
local hasCql = false
for _, group in ipairs(db.cooldownPlaceGroups) do hasCql = hasCql or group.cql == "boss" end
Check("a CQL line keeps a scene of its own", hasCql)
In("dungeon", true, { group = true })
Check("a place line before a rule still wins there: 400 Never in a dungeon fight in a group",
	(ns.CooldownSpellMode(400, "utility")) == "never", (ns.CooldownSpellMode(400, "utility")))
In("world", true, { group = true })
Check("the rule elsewhere: 400 Always in an open-world fight in a group",
	(ns.CooldownSpellMode(400, "utility")) == "always", (ns.CooldownSpellMode(400, "utility")))
In("dungeon", false, { group = true })
Check("and in a dungeon out of fights", (ns.CooldownSpellMode(400, "utility")) == "always",
	(ns.CooldownSpellMode(400, "utility")))
Check("an unfinished line adds nothing", db.cooldownSpellCells[CORRUPTION] == nil)
Check("no more scenes than the grid draws", #db.cooldownPlaceGroups <= ns.COOLDOWN_GROUP_LIMIT, #db.cooldownPlaceGroups)
local saved = db.profiles.GridTest
Check("saved profile converted too", saved.cooldownPlaceGroups and #saved.cooldownPlaceGroups == #db.cooldownPlaceGroups)
Check("done flag set", db.cooldownGridV1 == true)

-- More different wheres than the grid draws: the first nine kept, the rest left out.
do
	local many = {}
	for i = 1, 12 do many[i] = { show = "never", cql = "level > " .. i } end
	Fresh()
	db.cooldownSpellRules = { [IMMOLATE] = many }
	db.cooldownGroupRules, db.cooldownBuffRules = nil, nil
	db.cooldownGridV1 = nil
	ns.RunMigrations()
	Check("twelve wheres: nine scenes kept", #db.cooldownPlaceGroups == ns.COOLDOWN_GROUP_LIMIT, #db.cooldownPlaceGroups)
end

-- The release review's cases (2026-11-22): the rules the situations update
-- wrote are places again, a spell's own setting still beats its bar's, and
-- one row's rule doesn't take over the other rows' places.
do
	Fresh()
	db.cooldownGroupRules = { essential = { { show = "never", combat = "in", place = "dungeon" } } }
	db.cooldownSpellRules = {
		[300] = { { show = "always", cql = "(dungeon or raid) and (combat or calm)" } },
		[900] = { { show = "proc", cql = "boss" } },
	}
	db.cooldownBuffRules = nil
	db.cooldownAlwaysShow = { [IMMOLATE] = true }
	db.cooldownGroupRules.utility = { { show = "ready", cql = "(dungeon or raid) and (combat or calm)" } }
	db.cooldownNeverShow = { [700] = true }
	db.cooldownGridV1 = nil
	ns.RunMigrations()
	local generated = false
	for _, group in ipairs(db.cooldownPlaceGroups) do
		generated = generated or (group.cql and group.cql:find("dungeon or raid", 1, true) ~= nil)
	end
	Check("review: the situations' rule made places again", not generated)
	In("dungeon", true)
	Check("review: another spell's rule leaves the bar's Never on Agony in a dungeon fight",
		(ns.CooldownSpellMode(AGONY, "essential")) == "never", (ns.CooldownSpellMode(AGONY, "essential")))
	Check("review: and spell 300 Always there", (ns.CooldownSpellMode(300, "utility")) == "always")
	In("raid", true)
	Check("review: a spell's own Never beats its bar's situation line in a raid fight",
		(ns.CooldownSpellMode(700, "utility")) == "never", (ns.CooldownSpellMode(700, "utility")))
	In("dungeon", true, { boss = true })
	Check("review: a real rule (boss) keeps the bar's Never on Agony",
		(ns.CooldownSpellMode(AGONY, "essential")) == "never", (ns.CooldownSpellMode(AGONY, "essential")))
	Check("review: and its own row's answer there", (ns.CooldownSpellMode(900, "utility")) == "proc")
	Check("review: and the spell's own Always beats its bar there", (ns.CooldownSpellMode(IMMOLATE, "essential")) == "always")
	Check("review: no more scenes than the grid draws", #db.cooldownPlaceGroups <= ns.COOLDOWN_GROUP_LIMIT,
		#db.cooldownPlaceGroups)
	-- (A line with no place: Anywhere, as the old page read it.)
	Fresh()
	db.cooldownSpellRules = { [500] = { { show = "never", combat = "any" } } }
	db.cooldownGroupRules, db.cooldownBuffRules = nil, nil
	db.cooldownGridV1 = nil
	ns.RunMigrations()
	In("city", false)
	Check("review: a line with no place is Anywhere", (ns.CooldownSpellMode(500, "utility")) == "never",
		(ns.CooldownSpellMode(500, "utility")))
end

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
os.exit(fails == 0 and 0 or 1)
