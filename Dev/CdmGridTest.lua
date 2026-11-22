-- /cine debug cdmgrid: the Cooldown Manager page's grid (UI/CooldownGrid.lua,
-- place groups across: UI/CooldownRules.lua, 2026-11-22), in game. Nothing
-- to do: stand still out of a fight; it runs and says DONE. It picks a
-- spell in your Essential or Utility bar, sets it Always on its own, adds
-- two test groups (the place you're in, and Anywhere) and checks:
--   1 cell     the spell's cell Never in your place's group: its icon fades
--   2 bar      its cell cleared, its bar's cell Never: it fades (the bar's
--              cell before the spell's own Always)
--   3 order    Anywhere first with Always: it shows (the first group that
--              fits decides), and your place's group is flagged never used
--   4 page     the page opens on the spell's bar: the grid, its rows and
--              columns, the green dot on the group in use (a screenshot)
--   5 choices  the spell's cell clicked: its choices under its row; When
--              ready picked: set, its When ready parts shown (a screenshot)
--   6 editor   the group's heading clicked: its editor (a screenshot)
--   7 ticked   the spell's row ticked: the bar to set them all (a screenshot)
--   8 look     Look: the looks' columns, the bar's own looks under (a screenshot)
--   9 button   Open CDM clicked: the game's window opens, Close CDM; again: shut
-- Its settings and CineMode are put back after (and at the next login if a
-- /reload cuts it short). Offline: Tools/offline/cooldowngrid.lua. Into
-- CinematicDB.cdmGridTestLog. Dev copy only.
local _, ns = ...

local KEYS = { "cooldownPlaceGroups", "cooldownSpellCells", "cooldownBuffCells", "cooldownGroupCells",
	"cooldownReadyOnly", "cooldownEarlyOn", "cooldownReadyEarly", "cooldownNeedsPower", "cooldownReadyAnyTime",
	"cooldownRechargeOnly", "cooldownProcOnly", "cooldownAlwaysShow", "cooldownNeverShow", "cooldownGroupDefaults",
	"cooldownFlashReady", "cooldownRowSettings" }
local PLACES = { "world", "city", "inn", "dungeon", "raid", "bg" }

local function Copy(value)
	if type(value) ~= "table" then return value end
	local copy = {}
	for k, v in pairs(value) do copy[k] = Copy(v) end
	return copy
end

local test = {} -- this run's spell, its bar, name, place, and the two groups

-- The place you're in now (the one a group with it alone fits).
local function PlaceNow()
	local facts = ns.RuleFactsNow()
	for _, place in ipairs(PLACES) do
		if ns.CooldownGroupFits({ places = { [place] = true }, combat = "any" }, facts) then return place end
	end
	return "world"
end

-- A spell in the Essential or Utility bar with an icon (the first), its bar and name.
local function PickSpell()
	local GetName = (C_Spell and C_Spell.GetSpellName) or function(id) return (GetSpellInfo(id)) end
	for _, spell in ipairs(ns.CooldownManagerSpells()) do
		if (spell.group == "essential" or spell.group == "utility") and ns.ReadyIconProbe(spell.id) then
			local okName, name = pcall(GetName, spell.id)
			return spell.id, spell.group, okName and type(name) == "string" and name or ("spell " .. spell.id)
		end
	end
end

local function Fresh()
	ns.CooldownRuleFactsStale()
	ns.readyPace.due = true
end

-- The icon now: PASS when it's as wanted ("shown" or "faded").
local function Look(r, want)
	local _, probe = r:Probe("ReadyIconProbe", ns.ReadyIconProbe, test.spell)
	if type(probe) ~= "table" then
		r:Fail("the spell's icon isn't in the Essential or Utility bar")
		return
	end
	local mode, own = ns.CooldownSpellMode(test.spell, test.group)
	local _, index = ns.CooldownGroupNow()
	local shown = probe.target ~= 0
	r:Verdict((want == "shown") == shown, ("want %s: target %s, alpha %.2f, mode %s (own %s), group in use %s"):format(
		want, tostring(probe.target), probe.alpha or -1, tostring(mode), tostring(own), tostring(index)))
end

local function Click(frame, mouse)
	local click = frame and frame:GetScript("OnClick")
	if click then click(frame, mouse or "LeftButton") end
end
-- (Every value: "ns.CdmPageGrid and ns.CdmPageGrid()" gave the first alone, so
-- run 1 lost the button (step 9 skipped) and the shots' backgrounds, 2026-11-22.)
local function Grid()
	if not ns.CdmPageGrid then return nil end
	return ns.CdmPageGrid()
end
local function RowOf(grid, key)
	for _, row in ipairs(grid.rows) do
		if row.key == key then return row end
	end
end
-- The page open on the spell's bar (out of a fight), its grid.
local function OpenPage(r)
	-- (Its spell picked here too: steps 1-3 proven, the run may start here.)
	if not test.group then test.spell, test.group, test.name = PickSpell() end
	if InCombatLockdown() then
		r:Skip("in a fight: the settings stay shut")
		return nil
	end
	local ok, err = pcall(ns.OpenOptionsAt, "Cooldown Manager")
	if not ok then
		r:Fail("couldn't open the page: " .. tostring(err))
		return nil
	end
	r:Sleep(0.4)
	pcall(ns.CdmShowSpells, test.group)
	r:Sleep(0.3)
	local grid, _, panel = Grid()
	if not (grid and grid:IsVisible()) then
		r:Fail("the grid isn't shown")
		return nil
	end
	return grid, panel
end

-- The run's spell Always on its own and a test group for where you are,
-- with its cell Never (step 1's; any later step makes it when the run starts
-- there, the steps before proven). Gives false (and skips) when it can't.
local function Setup(r)
	if not ns.PageOn("handleCooldowns") then
		r:Skip("the Cooldown Manager page is off")
		return false
	end
	test.spell, test.group, test.name = PickSpell()
	if not test.spell then
		r:Skip("no spell in your Essential or Utility bar (is the game's Cooldown Manager on?)")
		return false
	end
	-- (Each table copied before a change: the undo keeps the one from before.)
	for _, key in ipairs(KEYS) do r:Set(key, Copy(ns.db[key]) or {}) end
	ns.db.cooldownPlaceGroups = {}
	local id = test.spell
	for _, key in ipairs({ "cooldownReadyOnly", "cooldownRechargeOnly", "cooldownProcOnly", "cooldownNeverShow" }) do
		ns.db[key][id] = nil
	end
	ns.db.cooldownAlwaysShow[id] = true
	test.place = PlaceNow()
	test.here = ns.AddCooldownGroup()
	test.here.places, test.here.name = { [test.place] = true }, "Test: here"
	ns.SetCooldownCell("spell", id, test.here.id, "never")
	Fresh()
	r:Log(("spell %s %d (%s), here %s"):format(test.name, id, test.group, test.place))
	return true
end

ns.TestKit.Define({
	name = "cdmgrid",
	key = "cdmGridTest",
	title = "Cooldown Manager grid",
	about = "the CDM page's grid: groups, cells, the bar's row, choices, editor, ticks, Look, nothing to do",
	settings = KEYS,
	context = function()
		-- (A new run: nothing kept from the last one, whose groups were put back.)
		wipe(test)
		local spell, group, name = PickSpell()
		return ("spell %s %s (%s), place %s, groups %d"):format(tostring(name), tostring(spell), tostring(group),
			PlaceNow(), #ns.CooldownPlaceGroups())
	end,
	steps = {
		{ key = "cell", proven = "cdmgrid run 1 (2026-11-22): PASS (faded, own cell)", title = "the spell's cell: Never where you are", seconds = 4, run = function(r)
			if not Setup(r) then return end
			r:Sleep(1.5)
			Look(r, "faded")
		end },
		{ key = "bar", proven = "cdmgrid run 1 (2026-11-22): PASS (faded, bar cell)", title = "its bar's cell before its own Always", seconds = 4, run = function(r)
			if not test.here and not Setup(r) then return end
			ns.SetCooldownCell("spell", test.spell, test.here.id, nil)
			ns.SetCooldownCell("group", test.group, test.here.id, "never")
			Fresh()
			r:Sleep(1.5)
			Look(r, "faded")
		end },
		{ key = "order", proven = "cdmgrid run 1 (2026-11-22): PASS (shown; dead group + Otherwise flagged)", title = "Anywhere first decides; the other flagged", seconds = 4, run = function(r)
			if not test.here and not Setup(r) then return end
			ns.SetCooldownCell("spell", test.spell, test.here.id, "never")
			test.any = ns.AddCooldownGroup()
			test.any.places, test.any.name = { any = true }, "Test: anywhere"
			ns.MoveCooldownGroup(test.any.id, -1)
			ns.SetCooldownCell("spell", test.spell, test.any.id, "always")
			Fresh()
			r:Sleep(1.5)
			Look(r, "shown")
			local trouble, otherDead = ns.CooldownGroupTrouble()
			r:Verdict(trouble[2] and trouble[2].kind == "dead" and otherDead,
				("here's group never used %s, Otherwise never used %s"):format(tostring(trouble[2] and trouble[2].kind),
				tostring(otherDead)))
		end },
		{ key = "page", proven = "cdmgrid run 8 (2026-11-22, full): PASS, grid, no-scenes card in the shots", title = "the page: the grid on the spell's bar", run = function(r)
			if not test.here and not Setup(r) then return end
			local grid, panel = OpenPage(r)
			if not grid then return end
			local cols = grid.Columns()
			local row = RowOf(grid, test.spell)
			r:Verdict(row ~= nil and grid.rows[1].key == test.group, ("bar's row first, spell's row %s"):format(tostring(row ~= nil)))
			-- (2 at least: the test group and Otherwise. It wanted 3 in run 5, counting step 3's
			-- Anywhere group, left out with step 3 proven: the test's fault, 2026-11-22.)
			r:Verdict(#cols >= 2 and cols[#cols].other, ("%d columns, Otherwise last"):format(#cols))
			r:Log(("grid %dx%d, rows %d, troubles shown %s"):format(math.floor(grid:GetWidth()), math.floor(grid:GetHeight()),
				#grid.state.ids + 1, tostring(grid.troubleLines[1] and grid.troubleLines[1]:IsShown())))
			r:Shot("the grid", { behind = panel })
			-- The look (the user, 2026-11-22: "something about it doesn't look right").
			local barRow = grid.rows[1]
			local other = #cols
			r:Verdict(grid.layout.colW <= 120 and barRow.cells[other].style == "bar"
				and barRow.label:GetText() == ns.L["%s bar"]:format(ns.L[test.group == "utility" and "Utility" or "Essential"]),
				("columns %d wide, bar's Otherwise %s, bar's row %s"):format(grid.layout.colW,
				tostring(barRow.cells[other].style), tostring(barRow.label:GetText())))
			-- (With no groups: the add column wide and saying what a group is, no dot.)
			local kept = ns.db.cooldownPlaceGroups
			ns.db.cooldownPlaceGroups = {}
			ns.CooldownRuleFactsStale()
			grid.Changed()
			r:Sleep(0.3)
			r:Verdict(grid.addCard:IsVisible() and not grid.plus:IsVisible(),
				("no groups: the card shown %s, the small + Add group hidden %s"):format(tostring(grid.addCard:IsVisible()),
				tostring(not grid.plus:IsVisible())))
			r:Shot("no groups yet", { behind = panel })
			ns.db.cooldownPlaceGroups = kept
			ns.CooldownRuleFactsStale()
			grid.Changed()
		end },
		{ key = "choices", proven = "cdmgrid run 8 (2026-11-22, full): PASS, pills in the shot", title = "a cell's choices", run = function(r)
			if not test.here and not Setup(r) then return end
			local grid, panel = OpenPage(r)
			if not grid then return end
			local row = RowOf(grid, test.spell)
			local j
			for k, col in ipairs(grid.Columns()) do
				if col.id == test.here.id then j = k end
			end
			if not (row and j) then return r:Fail("the spell's row or the group's column isn't there") end
			Click(row.cells[j])
			r:Sleep(0.3)
			local ready
			for _, box in ipairs(grid.choices) do
				if box:IsShown() and box.value == "ready" then ready = box end
			end
			r:Verdict(grid.chooser:IsVisible() and ready ~= nil, "choices shown under the row")
			Click(ready)
			r:Sleep(0.3)
			r:Verdict(ns.CooldownCell("spell", test.spell, test.here.id) == "ready" and grid.readyParts.power:IsVisible(),
				("cell %s, When ready parts shown %s"):format(tostring(ns.CooldownCell("spell", test.spell, test.here.id)),
				tostring(grid.readyParts.power:IsVisible())))
			r:Shot("the choices, When ready picked", { behind = panel })
			Click(row.cells[j])
		end },
		{ key = "editor", proven = "cdmgrid run 8 (2026-11-22, full): PASS, editor in the shot", title = "a group's editor", run = function(r)
			if not test.here and not Setup(r) then return end
			local grid, panel = OpenPage(r)
			if not grid then return end
			local head
			for _, child in ipairs({ grid:GetChildren() }) do
				if child.col and child.col.id == test.here.id and child.sub then head = child end
			end
			Click(head)
			r:Sleep(0.3)
			r:Verdict(grid.editor:IsVisible() and grid.state.editing == test.here.id, "editor open under the headings")
			r:Shot("the group editor", { behind = panel })
			Click(head)
		end },
		{ key = "ticked", proven = "cdmgrid run 8 (2026-11-22, full): PASS, bar in the shot", title = "ticked rows: set them all", run = function(r)
			local grid, panel = OpenPage(r)
			if not grid then return end
			local row = RowOf(grid, test.spell)
			Click(row and row.check)
			r:Sleep(0.3)
			r:Verdict(grid.bulk:IsVisible() and grid.bulkButtons.copy:IsVisible(), "the ticked rows' bar, with Copy row")
			r:Shot("one row ticked", { behind = panel })
			Click(grid.bulkButtons.clear)
		end },
		{ key = "look", proven = "cdmgrid run 8 (2026-11-22, full): PASS, Look and back in the shots", title = "Look", run = function(r)
			local grid, panel = OpenPage(r)
			if not grid then return end
			Click(grid.lookSwitch)
			r:Sleep(0.3)
			local cols = grid.Columns()
			r:Verdict(#cols == 4 and cols[1].look == "numbers" and grid.extraParts.center and grid.extraParts.center.box:IsVisible(),
				("%d look columns, the bar's own looks under %s"):format(#cols,
				tostring(grid.extraParts.center and grid.extraParts.center.box:IsVisible())))
			r:Shot("Look", { behind = panel })
			Click(grid.showsSwitch)
			r:Sleep(0.3)
			-- (Run 2's shot: "This bar:" was left under the grid after Look.)
			r:Verdict(not grid.extras:IsShown(), "back to When it shows: the bar's looks line gone")
			r:Shot("back from Look", { behind = panel })
		end },
		{ key = "button", proven = "cdmgrid run 2 (2026-11-22): PASS, Close CDM and the window in the shot", title = "Open CDM", run = function(r)
			local grid = OpenPage(r)
			if not grid then return end
			local _, button = Grid()
			if not (button and button:IsVisible()) then return r:Skip("no Open CDM button (no game window on this client)") end
			button:Click()
			r:Sleep(0.5)
			local window = _G.CooldownViewerSettings
			r:Verdict(button:GetText() == ns.L["Close CDM"] and window and window:IsShown(),
				("after a click: %s, window %s"):format(tostring(button:GetText()), tostring(window and window:IsShown())))
			r:Shot("Close CDM")
			button:Click()
			r:Sleep(0.5)
			r:Verdict(button:GetText() == ns.L["Open CDM"] and not (window and window:IsShown()),
				("clicked again: %s"):format(tostring(button:GetText())))
		end },
	},
})
