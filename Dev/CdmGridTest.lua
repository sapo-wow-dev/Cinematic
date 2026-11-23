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
--   9 gallery  the look, setup by setup: no scenes, one, three (every choice), five
--              (icons alone, troubles), the pop-up (and at the right edge), the
--              editor, ticked rows, Look, the buffs bar (a screenshot each)
--  10 button   Open CDM clicked: the game's window opens, Close CDM; again: shut
--  11 missing  Missing (UI/CooldownMissing.lua): a tracked buff that's off you,
--              set Missing, shows (the game hides it with Hide When Inactive)
--              and stays; one that's on you fades; put back, hidden again; a
--              stand-in of our own at a hidden icon's place (way A2), shots
--  12 missingfight  the same through a fight: shown, not refused, on/off
--              read, no errors (the one thing to do: attack something)
--  13 missinggroup  buffs that count as one: any one (Blood Pact, your imp's,
--              counts), each, none on; the group's row on the page, Ungroup
--  14 missingalts  the ready-made alternatives' names here; the hint under a
--              Missing buff on the page (nothing to do)
-- Its settings and CineMode are put back after (and at the next login if a
-- /reload cuts it short). Offline: Tools/offline/cooldowngrid.lua. Into
-- CinematicDB.cdmGridTestLog. Dev copy only.
local _, ns = ...

local KEYS = { "cooldownPlaceGroups", "cooldownSpellCells", "cooldownBuffCells", "cooldownGroupCells",
	"cooldownReadyOnly", "cooldownEarlyOn", "cooldownReadyEarly", "cooldownNeedsPower", "cooldownReadyAnyTime",
	"cooldownRechargeOnly", "cooldownProcOnly", "cooldownAlwaysShow", "cooldownNeverShow", "cooldownGroupDefaults",
	"cooldownFlashReady", "cooldownRowSettings", "cooldownBuffMode", "cooldownBuffGroups" }
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
	-- (As the page makes it: a city or inn comes with the open world, 2026-11-22.)
	local town = test.place == "city" or test.place == "inn" or test.place == "world"
	test.here.places = town and { world = true, city = true, inn = true } or { [test.place] = true }
	test.here.name = "Test: here"
	ns.SetCooldownCell("spell", id, test.here.id, "never")
	Fresh()
	r:Log(("spell %s %d (%s), here %s"):format(test.name, id, test.group, test.place))
	return true
end

-- The look, read off the frames (the user, 2026-11-22: "really check on
-- visuals, im finding stuff each time"): every shown text cut short, every
-- gold text (none of ours should be), and shown buttons that overlap each
-- other. One line each, a PASS when clean.
local function Audit(r, label, root)
	local cut, gold, boxes = {}, {}, {}
	local function Shown(region) return region.IsVisible and region:IsVisible() end
	local grid = Grid()
	local function Walk(frame, depth, inGrid)
		if depth > 14 or not Shown(frame) then return end
		inGrid = inGrid or frame == grid
		for _, region in ipairs({ frame:GetRegions() }) do
			if region.GetText and region:GetObjectType() == "FontString" and Shown(region) then
				local text = region:GetText()
				if type(text) == "string" and text ~= "" then
					-- (Its flag, and its width against its room: the flag alone missed a cut title, run 18.)
					local sw, w = region:GetStringWidth(), region:GetWidth()
					local wide = type(sw) == "number" and type(w) == "number" and w > 0 and not region:CanWordWrap() and sw > w + 1
					if (region.IsTruncated and region:IsTruncated()) or wide then cut[#cut + 1] = text end
					-- (Past the right edge of the frame it's in: the pop-up's label, 2026-11-22.)
					local left, right = region:GetLeft(), frame:GetRight()
					local fleft = frame:GetLeft()
					if left and right and fleft and type(sw) == "number" and frame:GetWidth() > 20 and frame ~= root
						and left + math.min(sw, (w and w > 4 and region:CanWordWrap()) and w or sw) > right + 1 then
						cut[#cut + 1] = text .. " (spills out)"
					end
					local cr, cg, cb = region:GetTextColor()
					-- (Gold only in the grid: the page's title and the bar tabs are the game's own.)
					if inGrid and cr and cr > 0.95 and cg > 0.75 and cg < 0.88 and cb < 0.15 then gold[#gold + 1] = text end
				end
			end
		end
		if frame:GetObjectType() == "Button" and frame ~= root and not frame.cdmCatcher and frame:GetWidth() > 4 then
			local left, bottom, width, height = frame:GetRect()
			if left then boxes[#boxes + 1] = { frame, left, bottom, width, height } end
		end
		for _, child in ipairs({ frame:GetChildren() }) do Walk(child, depth + 1, inGrid) end
	end
	Walk(root, 0, false)
	local overlaps = {}
	for i = 1, #boxes do
		for j = i + 1, #boxes do
			local a, c = boxes[i], boxes[j]
			-- (A pop-up and what's under it is meant: its own children only count with each other.)
			local sameLayer = a[1]:GetParent() == c[1]:GetParent()
			if sameLayer and a[2] < c[2] + c[4] - 1 and c[2] < a[2] + a[4] - 1 and a[3] < c[3] + c[5] - 1 and c[3] < a[3] + a[5] - 1 then
				local ta = a[1].text and a[1].text:GetText() or "?"
				local tc = c[1].text and c[1].text:GetText() or "?"
				overlaps[#overlaps + 1] = ("%s / %s"):format(tostring(ta), tostring(tc))
			end
		end
	end
	r:Verdict(#cut == 0 and #gold == 0 and #overlaps == 0, ("%s look: cut short [%s]; gold [%s]; overlapping [%s]"):format(label,
		table.concat(cut, " | "), table.concat(gold, " | "), table.concat(overlaps, " | ")))
end

-- Missing (steps 11-12): the tracked buffs bar's icons, one off you and one on.
local missing = {} -- { off = { icon, id }, on = { icon, id } }
local function BuffItems()
	local items = {}
	ns.EachCooldownIcon(function(icon, id, bar)
		if bar == "BuffIconCooldownViewer" then items[#items + 1] = { icon = icon, id = id } end
	end, true)
	return items
end
local function Plain(fn, ...)
	local ok, value = pcall(fn, ...)
	if not ok or (issecretvalue and issecretvalue(value)) then return nil end
	return value
end
local function IconLine(item)
	local icon = item.icon
	local tex = icon.Icon
	return ("spell %s cooldownID %s on=%s you=%s shown=%s alpha=%s protected=%s desat=%s here=%s"):format(
		tostring(item.id), tostring(icon.cooldownID), tostring(ns.CooldownBuffActive(icon)), tostring(ns.CooldownBuffOnYou(icon)),
		tostring(Plain(icon.IsShown, icon)), tostring(Plain(icon.GetAlpha, icon)),
		tostring(Plain(icon.IsProtected, icon)), tostring(tex and tex.IsDesaturated and Plain(tex.IsDesaturated, tex)),
		tostring(ns.CooldownMissingShownHere(icon)))
end
-- Both icons set Missing, the rest as they were; cells and scenes cleared so
-- their own mode decides. False (and skips) when it can't.
local function SetupMissing(r, onCheck)
	if not ns.PageOn("handleCooldowns") then r:Skip("the Cooldown Manager page is off") return false end
	local viewer = _G.BuffIconCooldownViewer
	if not viewer then r:Skip("no tracked buffs bar (BuffIconCooldownViewer)") return false end
	r:Fields("tracked buffs bar", { shown = function() return viewer:IsShown() end,
		hideWhenInactive = function() return viewer.hideWhenInactive end,
		protected = function() return viewer:IsProtected() end, fight = function() return InCombatLockdown() end })
	-- (Looked up fresh each time: run 1 kept the buff it found on as "on"
	-- after it was right-clicked off, one buff as both, 2026-11-23.)
	local function Find()
		wipe(missing)
		for _, item in ipairs(BuffItems()) do
			if item.icon.cooldownID ~= nil then
				if ns.CooldownBuffActive(item.icon) then missing.on = missing.on or item
				else missing.off = missing.off or item end
			end
		end
		return missing.off
	end
	-- (No tracked buff at all: nothing to right-click off. The full run on a
	-- shaman with none waited on that till a /reload, 2026-11-23.)
	local tracked = 0
	for i, item in ipairs(BuffItems()) do
		r:Log(("  item %d: %s"):format(i, IconLine(item)))
		if item.icon.cooldownID ~= nil then tracked = tracked + 1 end
	end
	if tracked == 0 then
		r:Skip("no tracked buff in your Cooldown Manager (run it on a character with one, a warlock's Demon Skin)")
		return false
	end
	for _, key in ipairs(KEYS) do r:Set(key, Copy(ns.db[key]) or {}) end
	ns.db.cooldownPlaceGroups, ns.db.cooldownBuffCells, ns.db.cooldownGroupCells = {}, {}, {}
	Find()
	-- (A buff on you, set Missing first: it fades. With one tracked buff, the
	-- same one is then right-clicked off below: no second thing to do.)
	if onCheck and missing.on then
		local on = missing.on
		ns.db.cooldownBuffMode[on.id] = "missing"
		Fresh()
		ns.CooldownMissingPass()
		r:Sleep(1.5)
		r:Log("set Missing while on you: " .. IconLine(on))
		r:Verdict((Plain(on.icon.GetAlpha, on.icon) or 1) < 0.1, "the icon of a buff on you fades, set Missing")
		r:Shot("Missing: the buff on you faded", { behind = viewer })
	elseif onCheck then
		r:Skip("no tracked buff on you: the fade while it's on isn't checked")
	end
	if not Find() then
		r:WaitFor("Right-click one of your tracked buffs off (Demon Skin...).", { check = Find })
	end
	if not missing.off then r:Skip("no tracked buff off you") return false end
	ns.db.cooldownBuffMode[missing.off.id] = "missing"
	if missing.on then ns.db.cooldownBuffMode[missing.on.id] = "missing" end
	Fresh()
	ns.CooldownMissingPass()
	r:Log(("off: %s; on: %s"):format(IconLine(missing.off), missing.on and IconLine(missing.on) or "none (every tracked buff off you)"))
	return true
end
-- Your buffs as read here (any caster, out of fights): name=who, and the
-- first aura's raw fields.
local function LogBuffRead(r, label)
	local okRead, read = pcall(ns.CooldownReadBuffs)
	local parts = {}
	for name, who in pairs(ns.CooldownReadBuffNames()) do parts[#parts + 1] = name .. "=" .. who end
	table.sort(parts)
	r:Log(("%s: read %s; %s"):format(label, tostring(okRead and read), #parts > 0 and table.concat(parts, ", ") or "none"))
	if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex and not InCombatLockdown() then
		for i = 1, 3 do
			local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
			if not ok or type(aura) ~= "table" then break end
			r:Fields(("%s aura %d"):format(label, i), { name = function() return aura.name end,
				sourceUnit = function() return aura.sourceUnit end, spellId = function() return aura.spellId end,
				isFromPlayerOrPlayerPet = function() return aura.isFromPlayerOrPlayerPet end })
		end
	end
end
-- The stand-in (way A2): our own texture at a hidden icon's place.
local standIn
local function StandIn(r, icon)
	if not standIn then
		standIn = CreateFrame("Frame", nil, UIParent)
		standIn.tex = standIn:CreateTexture(nil, "ARTWORK")
		standIn.tex:SetAllPoints()
		standIn.edge = standIn:CreateTexture(nil, "BACKGROUND")
		standIn.edge:SetPoint("TOPLEFT", -2, 2)
		standIn.edge:SetPoint("BOTTOMRIGHT", 2, -2)
		standIn.edge:SetColorTexture(1, 0.85, 0.35, 0.9)
	end
	local _, file = r:Probe("hidden icon's texture", function() return icon.Icon:GetTexture() end)
	r:Probe("hidden icon's center", function() return icon:GetCenter() end)
	r:Probe("hidden icon's size, scale", function() return icon:GetWidth(), icon:GetEffectiveScale() end)
	standIn:ClearAllPoints()
	local okPoint = pcall(standIn.SetPoint, standIn, "CENTER", icon, "CENTER")
	local w = Plain(icon.GetWidth, icon) or 36
	local scale = Plain(icon.GetEffectiveScale, icon) or 1
	local size = w * scale / UIParent:GetEffectiveScale()
	standIn:SetSize(size, size)
	pcall(standIn.tex.SetTexture, standIn.tex, file)
	standIn:Show()
	return standIn, okPoint
end

ns.TestKit.Define({
	name = "cdmgrid",
	key = "cdmGridTest",
	title = "Cooldown Manager grid",
	about = "the CDM page's grid: groups, cells, the bar's row, choices, editor, ticks, Look, nothing to do",
	needs = "A warlock (Demon Skin, imp out) and a mob or training dummy",
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
		{ key = "page", proven = "cdmgrid run 29 (2026-11-22): PASS, grid, Essentials row, Shows column", title = "the page: the grid on the spell's bar", run = function(r)
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
			r:Verdict(grid.layout.colW <= 190 and barRow.cells[other].style == "bar"
				and barRow.label:GetText() == ns.L[test.group == "utility" and "Utility" or "Essentials"],
				("columns %d wide, bar's Otherwise %s, bar's row %s"):format(grid.layout.colW,
				tostring(barRow.cells[other].style), tostring(barRow.label:GetText())))
			-- (With no groups: the add column wide and saying what a group is, no dot.)
			local kept = ns.db.cooldownPlaceGroups
			ns.db.cooldownPlaceGroups = {}
			ns.CooldownRuleFactsStale()
			grid.Changed()
			r:Sleep(0.3)
			r:Verdict(not grid.addCard:IsVisible() and grid.plus:IsVisible(),
				("no groups: no card %s, + Add scene shown %s"):format(tostring(not grid.addCard:IsVisible()),
				tostring(grid.plus:IsVisible())))
			r:Shot("no groups yet", { behind = panel })
			ns.db.cooldownPlaceGroups = kept
			ns.CooldownRuleFactsStale()
			grid.Changed()
		end },
		{ key = "choices", proven = "cdmgrid run 29 (2026-11-22): PASS, pop-up, When ready parts", title = "a cell's choices", run = function(r)
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
		{ key = "editor", proven = "cdmgrid run 33 (2026-11-22): PASS, Location list Open world/Instances/Dungeons/Raids/BGs, opens, shot", title = "a group's editor, its Location list open", run = function(r)
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
			-- (The Location list as the player sees it: Open world, Instances,
			-- Dungeons, Raids, BGs & arenas; Cities or Inns only on a scene that has
			-- them without the open world, as the test's own does in a city. 2026-11-22.)
			local names = {}
			for _, entry in ipairs(grid.placeEntries) do names[#names + 1] = entry[1] end
			r:Verdict(#grid.placeEntries >= 5 and grid.placeEntries[1].place == "world" and grid.placeEntries[2].place == "instance",
				"Location list: " .. table.concat(names, ", "))
			local locationButton
			for _, child in ipairs({ grid.whenRow:GetChildren() }) do
				if child.sweepTicks == grid.placeEntries then locationButton = child end
			end
			if locationButton and locationButton:IsVisible() then
				locationButton:Click()
				r:Sleep(0.3)
				local manager = _G.Menu and _G.Menu.GetManager and _G.Menu.GetManager()
				local menu = manager and manager.GetOpenMenu and manager:GetOpenMenu()
				r:Verdict(menu ~= nil, "the Location list opens")
				r:Shot("the Location list open", { behind = panel })
				if manager and manager.CloseMenus then manager:CloseMenus() end
			else
				r:Fail("no Location dropdown found in the editor")
			end
			Click(head)
		end },
		{ key = "ticked", proven = "cdmgrid run 29 (2026-11-22): PASS, Set/to/Apply bar, Copy row", title = "ticked rows: set them all", run = function(r)
			local grid, panel = OpenPage(r)
			if not grid then return end
			local row = RowOf(grid, test.spell)
			Click(row and row.check)
			r:Sleep(0.3)
			r:Verdict(grid.bulk:IsVisible() and grid.bulkButtons.copy:IsVisible(), "the ticked rows' bar, with Copy row")
			r:Shot("one row ticked", { behind = panel })
			Click(grid.bulkButtons.clear)
		end },
		{ key = "look", proven = "cdmgrid run 29 (2026-11-22): PASS, Look columns and the tab's own looks", title = "Look", run = function(r)
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
		{ key = "gallery", proven = "cdmgrid run 33 (2026-11-22): PASS, ghost cells + column bands, 8 setups, audits clean, shots looked at", title = "the look, setup by setup (screenshots)", run = function(r)
			-- (The user, 2026-11-22: "evaluate the look for all possible combinations,
			-- generate a few rows with different options". Each setup on your own bar,
			-- a screenshot each; everything's put back after.)
			if not test.here and not Setup(r) then return end
			local grid, panel = OpenPage(r)
			if not grid then return end
			local ids = {}
			for _, spell in ipairs(ns.CooldownManagerSpells()) do
				if spell.group == test.group then ids[#ids + 1] = spell.id end
			end
			local A, B, C, D, E = ids[1], ids[2] or ids[1], ids[3] or ids[1], ids[4] or ids[1], ids[5] or ids[1]
			r:Log(("%d spells on the %s bar"):format(#ids, tostring(test.group)))
			local db = ns.db
			local function Scenes(list)
				db.cooldownPlaceGroups = list
				wipe(db.cooldownSpellCells)
				wipe(db.cooldownGroupCells)
				for _, id in ipairs(ids) do
					for _, key in ipairs({ "cooldownReadyOnly", "cooldownRechargeOnly", "cooldownProcOnly", "cooldownNeverShow",
						"cooldownAlwaysShow" }) do db[key][id] = nil end
				end
				wipe(grid.state.selected)
				grid.state.open, grid.state.editing, grid.state.look = nil, nil, false
			end
			local function Cell(kind, key, id, mode) ns.SetCooldownCell(kind, key, id, mode) end
			local function Shoot(label)
				grid.Changed()
				r:Sleep(0.4)
				local L2 = grid.layout or {}
				r:Log(("%s: columns %s wide, icons only %s, card %s, + Add scene %s, height %d"):format(label,
					tostring(L2.colW), tostring(L2.compact), tostring(L2.cardShown), tostring(L2.plusShown),
					math.floor(grid:GetHeight() + 0.5)))
				-- (The grid's own frame: the panel is its background, it held none of it;
				-- every check passed on an empty frame, 2026-11-22.)
				Audit(r, label, grid:GetParent())
				r:Shot(label, { behind = panel })
			end
			local DUNGEON = { id = 1, name = "Dungeon fights", places = { dungeon = true, raid = true }, combat = "in" }
			local TOWN = { id = 2, name = "Town", places = { city = true, inn = true }, combat = "out" }
			local PVP = { id = 3, name = "PvP", places = { bg = true }, combat = "any" }
			-- 1 No scenes: the card; one spell Never and one Procs on their own.
			Scenes({})
			ns.CooldownSetOtherwise("spell", B, test.group, "never")
			ns.CooldownSetOtherwise("spell", C, test.group, "proc")
			Shoot("1 no scenes")
			-- 2 One scene, a few set.
			Scenes({ DUNGEON })
			Cell("spell", A, 1, "ready")
			Cell("spell", B, 1, "never")
			Cell("group", test.group, 1, "always")
			ns.CooldownSetOtherwise("spell", D, test.group, "recharge")
			Shoot("2 one scene")
			-- 3 Three scenes, every choice somewhere, the bar's row set in one.
			Scenes({ DUNGEON, TOWN, PVP })
			Cell("spell", A, 1, "ready")
			Cell("spell", B, 1, "recharge")
			Cell("spell", C, 1, "proc")
			Cell("spell", D, 2, "never")
			Cell("spell", E, 3, "always")
			Cell("group", test.group, 2, "never")
			ns.CooldownSetOtherwise("spell", C, test.group, "never")
			Shoot("3 three scenes, every choice")
			-- 3b One cell under the pointer (its hover band).
			local rowA = RowOf(grid, A)
			local hovered = rowA and rowA.cells[2]
			if hovered then
				hovered.hovered = true
				if hovered.repaint then hovered.repaint() end
				r:Sleep(0.3)
				r:Shot("3b a cell under the pointer", { behind = panel })
				hovered.hovered = false
			end
			-- 4 Five scenes: icons alone; one never used, one with no places.
			local RAID = { id = 4, name = "Raid bosses", places = { raid = true }, combat = "in" }
			local NEW = { id = 5, name = "Scene 5", places = {}, combat = "any" }
			db.cooldownPlaceGroups = { DUNGEON, TOWN, PVP, RAID, NEW }
			Cell("spell", A, 4, "never")
			Shoot("4 five scenes, icons alone, troubles")
			-- (A cell in Raid bosses, which never applies: a "!" on the bar's tab.)
			local tabs = select(4, Grid())
			local tab
			for _, each in ipairs(tabs or {}) do
				if each:IsShown() and each.warnMark then tab = tab or each end
			end
			r:Verdict(tab and tab.warnMark:IsShown() and tab.warnLines ~= nil,
				("tab warning shown %s: %s"):format(tostring(tab and tab.warnMark:IsShown()),
				tostring(tab and tab.warnLines and table.concat(tab.warnLines, "; "))))
			-- 5 The pop-up: a cell in the first column (When ready, its parts), then Otherwise's (the right edge).
			db.cooldownPlaceGroups = { DUNGEON, TOWN, PVP }
			grid.Changed()
			rowA = RowOf(grid, A)
			if rowA then
				Click(rowA.cells[1])
				r:Sleep(0.4)
				r:Verdict(grid.chooser:IsVisible(), "pop-up open under the first column's cell")
				Audit(r, "5 pop-up, When ready parts", grid:GetParent())
				r:Shot("5 pop-up, When ready parts", { behind = panel })
				Click(rowA.cells[1])
				Click(rowA.cells[4])
				r:Sleep(0.4)
				Audit(r, "5b pop-up at the right edge (Otherwise)", grid:GetParent())
				r:Shot("5b pop-up at the right edge (Otherwise)", { behind = panel })
				Click(rowA.cells[4])
			end
			-- 6 The editor open on Town.
			grid.state.editing = 2
			Shoot("6 editor open")
			grid.state.editing = nil
			-- 7 Two rows ticked: the bar to set them all.
			grid.state.selected[B] = true
			grid.state.selected[C] = true
			Shoot("7 two rows ticked")
			wipe(grid.state.selected)
			-- 8 Look with a few changed.
			ns.SetCooldownRow(A, "keybinds", true)
			db.cooldownFlashReady[B] = true
			ns.SetCooldownRow(C, "numbers", "show")
			grid.state.look = true
			Shoot("8 Look, a few changed")
			grid.state.look = false
			ns.SetCooldownRow(A, "keybinds", nil)
			ns.SetCooldownRow(C, "numbers", nil)
			db.cooldownFlashReady[B] = nil
			-- 9 The buffs bar: its own choices (In combat, Out of combat, Hidden).
			local buffs = {}
			for _, spell in ipairs(ns.CooldownManagerSpells()) do
				if spell.group == "buffs" then buffs[#buffs + 1] = spell.id end
			end
			if buffs[1] then
				Cell("buff", buffs[1], 1, "combat")
				if buffs[2] then Cell("buff", buffs[2], 2, "quiet") end
				if buffs[3] then Cell("buff", buffs[3], 3, "hidden") end
				pcall(ns.CdmShowSpells, "buffs")
				r:Sleep(0.4)
				r:Shot("9 buffs bar", { behind = panel })
				pcall(ns.CdmShowSpells, test.group)
			else
				r:Log("9 no tracked buffs in the Cooldown Manager: buffs bar not shown")
			end
			-- (Real text widths, to match the CDM lab's guesses to: it guessed
			-- narrow and missed cut chips, 2026-11-22.)
			local probe = grid:CreateFontString(nil, "OVERLAY")
			for _, font in ipairs({ "GameFontHighlightSmall", "GameFontDisableSmall", "GameFontHighlight", "GameFontNormalSmall" }) do
				probe:SetFontObject(font)
				local file, size = probe:GetFont()
				local parts = {}
				for _, words in ipairs({ "Open world", "In combat", "Out of combat", "When ready, for this spell everywhere:",
					"Dungeon fights", "MMMMMMMMMM", "iiiiiiiiii" }) do
					probe:SetText(words)
					parts[#parts + 1] = ("%s=%.1f"):format(words, probe:GetStringWidth() or -1)
				end
				r:Log(("text widths %s (%s %s): %s"):format(font, tostring(file), tostring(size), table.concat(parts, "; ")))
			end
			probe:Hide()
			r:Pass("gallery shot; look at the screenshots")
		end },
		{ key = "nine", proven = "cdmgrid run 2026-11-23 (retail): PASS, headings 1-9, words inside, warning line under, audit clean, shot", title = "nine unnamed scenes: numbered headings, warning lines under them", run = function(r)
			-- (A player's shot, 2026-11-23: nine scenes from the old lines, named by
			-- their places, covering every place: "gr...", "Cit..." over each other,
			-- the warning lines on the headings. CDM lab state 19.)
			if not test.here and not Setup(r) then return end
			local grid, panel = OpenPage(r)
			if not grid then return end
			local db = ns.db
			wipe(db.cooldownSpellCells)
			wipe(db.cooldownGroupCells)
			grid.state.open, grid.state.editing, grid.state.look = nil, nil, false
			local function S(id, places, combat) return { id = id, name = "", places = places, combat = combat } end
			db.cooldownPlaceGroups = {
				{ id = 1, name = "", cql = "group and combat" }, { id = 2, name = "", cql = "group and nocombat" },
				S(3, { world = true }, "in"), S(4, { city = true }, "any"), S(5, { city = true }, "out"),
				S(6, { inn = true, bg = true }, "any"), S(7, { dungeon = true }, "in"),
				S(8, { dungeon = true, raid = true }, "out"),
				S(9, { world = true, dungeon = true, raid = true, bg = true }, "any"),
			}
			ns.CooldownRuleFactsStale()
			grid.Changed()
			r:Sleep(0.4)
			local heads, names, lowest = {}, {}, nil
			for _, child in ipairs({ grid:GetChildren() }) do
				if child.col and child.sub and child:IsShown() then heads[#heads + 1] = child end
			end
			table.sort(heads, function(a, b) return (a:GetLeft() or 0) < (b:GetLeft() or 0) end)
			local inside = true
			for _, head in ipairs(heads) do
				names[#names + 1] = tostring(head.text:GetText())
				local bottom = head.text:GetBottom()
				if head.sub:IsShown() then bottom = math.min(bottom or 0, head.sub:GetBottom() or 0) end
				if bottom and head:GetBottom() and bottom < head:GetBottom() - 1 then inside = false end
				lowest = math.min(lowest or math.huge, head:GetBottom() or math.huge)
			end
			r:Verdict(names[1] == "1" and names[9] == "9", "headings: " .. table.concat(names, ", "))
			r:Verdict(inside, "every heading's words inside its heading")
			local line = grid.troubleLines[1]
			local top = line and line:IsShown() and line:GetTop()
			r:Verdict(top and lowest and top <= lowest + 1,
				("first warning line's top %s, headings' bottom %s"):format(tostring(top), tostring(lowest)))
			Audit(r, "nine unnamed scenes", grid:GetParent())
			r:Shot("nine unnamed scenes", { behind = panel })
		end },
		{ key = "preview", proven = "cdmgrid run 35 (2026-11-22): PASS, Where/When picker, faded, banner, back to shown", title = "the previewer: a dungeon fight from here, your icon follows", seconds = 6, run = function(r)
			if not test.here and not Setup(r) then return end
			-- (A scene for dungeon fights, the spell Never in it; you're not in one.)
			if test.place == "dungeon" then return r:Skip("you're in a dungeon: stand outside one for this step") end
			ns.db.cooldownPlaceGroups = {}
			local scene = ns.AddCooldownGroup()
			scene.places, scene.combat, scene.name = { dungeon = true }, "in", "Test: dungeon fights"
			ns.SetCooldownCell("spell", test.spell, scene.id, "never")
			-- (Always of its own, set here: the gallery before clears it, and a
			-- spell whose default is When it procs stayed hidden, a shaman's
			-- Searing Totem, cdmgrid run 29.)
			for _, name in ipairs({ "cooldownReadyOnly", "cooldownRechargeOnly", "cooldownProcOnly", "cooldownNeverShow" }) do
				ns.db[name][test.spell] = nil
			end
			ns.db.cooldownAlwaysShow[test.spell] = true
			Fresh()
			r:Sleep(1.5)
			Look(r, "shown")
			-- (The page open first, as a player has it: it goes back to live as
			-- it hides, and run alone this step opened it after, cdmgrid run 30.)
			local grid, panel = OpenPage(r)
			r:Sleep(0.5)
			ns.SetCooldownPreview("dungeon", "in")
			if grid then grid.Changed() end
			r:Sleep(1.5)
			Look(r, "faded")
			if grid then
				r:Verdict(grid.banner:IsVisible(), "the blue banner shows while previewing")
				r:Shot("previewing a dungeon fight", { behind = panel })
				-- (The picker: Where and When side by side, no Town, 2026-11-22.)
				Click(grid.previewButton)
				r:Sleep(0.3)
				r:Verdict(grid.previewMenu:IsVisible(), "the preview picker: Where and When lists")
				r:Shot("the preview picker", { behind = panel })
				Click(grid.previewButton)
			end
			ns.SetCooldownPreview(nil)
			if grid then grid.Changed() end
			Fresh()
			r:Sleep(1.5)
			Look(r, "shown")
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
		{ key = "missing", proven = "cdmgrid run 2 (2026-11-23, Forever): PASS shown, stays 8/8, put back hidden, stand-in at the slot (shot)", title = "Missing: a tracked buff's icon while the buff is off you", seconds = 4, run = function(r)
			if InCombatLockdown() then return r:Skip("in a fight: leave it first") end
			if not SetupMissing(r, true) then return end
			local viewer = _G.BuffIconCooldownViewer
			local off, on = missing.off, missing.on
			r:Sleep(1.5)
			r:Log("after 1.5 s, off: " .. IconLine(off))
			r:Verdict(Plain(off.icon.IsShown, off.icon) == true and (Plain(off.icon.GetAlpha, off.icon) or 0) > 0.9,
				"the icon of a buff off you shows, set Missing (hideWhenInactive " .. tostring(viewer.hideWhenInactive) .. ")")
			-- (Stays shown: the game hides it again on its own updates.)
			local shownCount = 0
			for _ = 1, 8 do
				r:Sleep(0.5)
				if Plain(off.icon.IsShown, off.icon) then shownCount = shownCount + 1 end
			end
			local stats = ns.cooldownMissingStats
			r:Verdict(shownCount == 8, ("stays shown: %d of 8 looks over 4 s; shown here %d times, refused %d"):format(
				shownCount, stats.shown, stats.refused))
			r:Probe("icon art", function() return off.icon.Icon:GetTexture() end)
			r:Shot("Missing: the buff off you shown", { behind = viewer })
			-- (Put back: Missing off, the game's hidden again.)
			ns.db.cooldownBuffMode[off.id] = nil
			if on then ns.db.cooldownBuffMode[on.id] = nil end
			Fresh()
			ns.CooldownMissingPass()
			r:Sleep(1.5)
			r:Log("put back, off: " .. IconLine(off))
			if viewer.hideWhenInactive then
				r:Verdict(Plain(off.icon.IsShown, off.icon) == false, "put back: hidden again, as the game has it")
			else
				r:Skip("Hide When Inactive is off: the game shows it anyway")
			end
			-- (Way A2: our own stand-in at the hidden icon's place.)
			local frame, okPoint = StandIn(r, off.icon)
			r:Sleep(0.3)
			-- (Both values: Plain gave the first alone, run 1's Lua error.)
			local fx, fy = frame:GetCenter()
			local okCenter, ix, iy = pcall(off.icon.GetCenter, off.icon)
			if not okCenter or (issecretvalue and (issecretvalue(ix) or issecretvalue(iy))) then ix, iy = nil, nil end
			local fs, is = frame:GetEffectiveScale(), Plain(off.icon.GetEffectiveScale, off.icon) or 1
			r:Verdict(okPoint and fx and fy and ix and iy and math.abs(fx * fs - ix * is) < 2 and math.abs(fy * fs - iy * is) < 2,
				("stand-in at the hidden icon's place: anchored %s, ours %s,%s theirs %s,%s"):format(tostring(okPoint),
				tostring(fx), tostring(fy), tostring(ix), tostring(iy)))
			r:Shot("the stand-in (gold edge) at the hidden icon's place", { behind = viewer })
			frame:Hide()
		end },
		{ key = "missinggroup", proven = "cdmgrid runs 4 + 6 (2026-11-23, Forever): any one / each / none on, the group's row, Ungroup clear and splits back", title = "Buffs that count as one: Missing any one / each, the group's row and Ungroup", seconds = 4, run = function(r)
			if InCombatLockdown() then return r:Skip("in a fight: leave it first") end
			local PACT, ARMOR = 6307, 706 -- (Blood Pact: your imp's; Demon Armor: not on you)
			local viewer = _G.BuffIconCooldownViewer
			local lead
			-- (Demon Skin off you, with your imp's Blood Pact on: the group of
			-- the two has one on, so any one shows nothing and each shows Skin.)
			if not r:Proven("cdmgrid run 4 (2026-11-23, Forever): any one with Blood Pact on = no reminder; each = shown; none on = Skin's icon") then
				if not SetupMissing(r, false) then return end
				local off = missing.off
				lead = ns.BaseSpell(off.id)
				ns.db.cooldownBuffMode = {}
				LogBuffRead(r, "before")
				local function Shown(icon)
					return Plain(icon.IsShown, icon) == true and (Plain(icon.GetAlpha, icon) or 0) > 0.9
				end
				local function Settle()
					Fresh()
					ns.CooldownMissingPass()
					r:Sleep(1.5)
				end
				if ns.CooldownReadBuffNames()["Blood Pact"] == "other" then
					ns.SetCooldownBuffGroup({ lead, PACT })
					ns.db.cooldownBuffMode[lead] = "missing"
					Settle()
					r:Log("any one, Blood Pact on: " .. IconLine(off))
					r:Verdict(not Shown(off.icon), "Missing: any one, Blood Pact (your imp's) on you: no reminder")
					ns.db.cooldownBuffMode[lead] = "missingeach"
					Settle()
					r:Log("each, Blood Pact on: " .. IconLine(off))
					r:Verdict(Shown(off.icon), "Missing: each: Demon Skin's own reminder shows")
					ns.UngroupCooldownBuff(lead)
			else
				r:Skip("no Blood Pact on you (summon your imp to check a group member cast by another)")
			end
			ns.db.cooldownBuffMode = {}
			ns.SetCooldownBuffGroup({ lead, ARMOR })
			ns.db.cooldownBuffMode[lead] = "missing"
			Settle()
			r:Log("any one, none on: " .. IconLine(off))
			r:Verdict(Shown(off.icon), "Missing: any one, none of the group on you: Demon Skin's icon is the reminder")
			r:Shot("a group's reminder (Demon Skin or Demon Armor)", { behind = viewer })
			else
				-- (Proven: the page alone, on the first tracked buff, its settings undone after.)
				local first
				for _, item in ipairs(BuffItems()) do
					if item.icon.cooldownID ~= nil then first = first or item end
				end
				if not first then return r:Skip("no tracked buff in your Cooldown Manager") end
				for _, key in ipairs(KEYS) do r:Set(key, Copy(ns.db[key]) or {}) end
				lead = ns.BaseSpell(first.id)
				ns.SetCooldownBuffGroup({ lead, ARMOR })
				ns.db.cooldownBuffMode[lead] = "missing"
			end
			-- The page: the group's row, its members under it; ticked: Ungroup.
			local ok, err = pcall(ns.OpenOptionsAt, "Cooldown Manager")
			if not ok then return r:Fail("couldn't open the page: " .. tostring(err)) end
			r:Sleep(0.4)
			pcall(ns.CdmShowSpells, "buffs")
			r:Sleep(0.3)
			local grid, _, panel = Grid()
			if not (grid and grid:IsVisible()) then return r:Fail("the grid isn't shown") end
			local row = RowOf(grid, lead)
			r:Verdict(row ~= nil and row.sub:IsShown() and (row.sub:GetText() or ""):find("Demon Armor", 1, true) ~= nil,
				("the group's row: %s, under it %s"):format(row and tostring(row.label:GetText()) or "none",
				row and row.sub:IsShown() and tostring(row.sub:GetText()) or "nothing"))
			r:Shot("the Buffs tab, a group's row", { behind = panel })
			-- (As the tick box's click does: Changed, which fits the panel too.
			-- Layout alone left the bar 8 px under the panel's edge, run 4.)
			grid.state.selected[lead] = true
			grid.Changed()
			r:Sleep(0.3)
			local button = grid.bulkButtons.group
			r:Verdict(button:IsShown() and button.text and button.text:GetText() == ns.L["Ungroup"],
				("ticked alone: the bar's group button says %s"):format(tostring(button.text and button.text:GetText())))
			local hits = r:Overlaps(button, panel)
			if #hits > 0 then r:Log("Ungroup covers: " .. table.concat(hits, ", ")) end
			r:Verdict(#hits == 0, "Ungroup: nothing under it")
			r:Shot("one group ticked: Ungroup", { behind = panel })
			button:Click()
			r:Sleep(0.3)
			-- (Not "no line under it": still on Missing, its ready-made
			-- alternatives show there, run 6.)
			r:Verdict(ns.CooldownBuffLead(ARMOR) == nil and not grid.IsGroup(lead),
				("Ungroup: split back, the row a single buff again (under it now: %s)"):format(
				RowOf(grid, lead) and RowOf(grid, lead).sub:IsShown() and tostring(RowOf(grid, lead).sub:GetText()) or "nothing"))
		end },
		{ key = "missingalts", proven = "cdmgrid run 6 (2026-11-23, Forever): sets' names (Salvation, Sanctuary, Light, Fel / Molten Armor, Water Shield not on Forever), the hint under Demon Skin", title = "Ready-made alternatives: their names on this client, the hint under a Missing buff", seconds = 4, run = function(r)
			if InCombatLockdown() then return r:Skip("in a fight: leave it first") end
			-- Each set's names as this client gives them (an ID it hasn't got drops out).
			local GetName = (C_Spell and C_Spell.GetSpellName) or function(id) return (GetSpellInfo(id)) end
			ns.CooldownBuffAlternativesReset()
			local missingIDs = {}
			for _, set in ipairs(ns.COOLDOWN_BUFF_ALTERNATIVES) do
				local names = {}
				for _, id in ipairs(set) do
					local ok, name = pcall(GetName, id)
					if ok and type(name) == "string" then names[#names + 1] = name
					else missingIDs[#missingIDs + 1] = tostring(id) end
				end
				r:Log("set: " .. table.concat(names, " / "))
			end
			r:Log("IDs this client hasn't got: " .. (#missingIDs > 0 and table.concat(missingIDs, ", ") or "none"))
			r:Verdict((ns.CooldownBuffAlternatives(GetName(687) or "?") or {})[1] ~= nil,
				"Demon Skin has its alternatives here: " .. table.concat(ns.CooldownBuffAlternatives(GetName(687) or "?") or { "none" }, ", "))
			-- The page: the first tracked buff with alternatives set Missing, the hint under it.
			local pick
			for _, item in ipairs(BuffItems()) do
				local okName, name = pcall(GetName, item.id)
				if not pick and item.icon.cooldownID ~= nil and okName and ns.CooldownBuffAlternatives(name) then pick = item end
			end
			if not pick then return r:Skip("no tracked buff here with ready-made alternatives") end
			for _, key in ipairs(KEYS) do r:Set(key, Copy(ns.db[key]) or {}) end
			ns.db.cooldownBuffGroups, ns.db.cooldownBuffCells, ns.db.cooldownPlaceGroups = {}, {}, {}
			local key = ns.BaseSpell(pick.id)
			ns.db.cooldownBuffMode = { [key] = "missing" }
			Fresh()
			local ok, err = pcall(ns.OpenOptionsAt, "Cooldown Manager")
			if not ok then return r:Fail("couldn't open the page: " .. tostring(err)) end
			r:Sleep(0.4)
			pcall(ns.CdmShowSpells, "buffs")
			r:Sleep(0.3)
			local grid, _, panel = Grid()
			if not (grid and grid:IsVisible()) then return r:Fail("the grid isn't shown") end
			local row = RowOf(grid, key)
			local sub = row and row.sub:IsShown() and row.sub:GetText()
			r:Verdict(type(sub) == "string" and sub ~= "" and not row.sub:IsTruncated(),
				("under %s: %s"):format(row and tostring(row.label:GetText()) or "no row", tostring(sub)))
			r:Shot("a Missing buff, its ready-made alternatives under it", { behind = panel })
		end },
		{ key = "missingfight", proven = "cdmgrid run 4 (2026-11-23, Forever): off 4/4 shown, on 17/17 faded in a 14 s fight, 0 refused, 0 errors", title = "Missing in a fight: shown while off you, faded while on, not refused, no errors", run = function(r)
			if InCombatLockdown() then return r:Skip("in a fight already: start out of one") end
			-- (The fade checked first while it's on you: run 3 asked to right-click
			-- it off and never saw it on, 2026-11-23.)
			if not SetupMissing(r, true) then return end
			local stats = ns.cooldownMissingStats
			local refusedBefore = stats.refused
			local items = { missing.off }
			if missing.on and missing.on.icon ~= missing.off.icon then items[2] = missing.on end
			-- (Any caster: your buffs read here, the icon's names, before the fight.)
			LogBuffRead(r, "before the fight")
			for _, item in ipairs(items) do
				r:Log(("names of spell %s: %s"):format(tostring(item.id), table.concat(ns.CooldownBuffNames(item.icon), ", ")))
			end
			r:Sleep(1)
			r:WaitFor("Attack something (a training dummy or any mob). In the fight, cast Demon Skin once. Fight about 10 seconds, then end it.",
				{ events = { "PLAYER_REGEN_DISABLED" } })
			-- (The lockdown comes a moment after the event: run 2 looked at once,
			-- found none, and measured nothing, 2026-11-23.)
			local function Fighting() return InCombatLockdown() or ns.Flag(UnitAffectingCombat("player")) end
			r:Sleep(0.3)
			-- Per look and icon: off you, shown in full; on you, faded. The two
			-- looks after its buff goes on or off aren't counted (the fade's time).
			local offLooks, offOk, onLooks, onOk, looks, lastLine = 0, 0, 0, 0, 0, nil
			local was, settle = {}, {}
			local started = GetTime()
			while Fighting() and GetTime() - started < 120 do
				looks = looks + 1
				for _, item in ipairs(items) do
					local icon = item.icon
					local on = ns.CooldownBuffOnYou(icon)
					if was[icon] ~= nil and was[icon] ~= on then settle[icon] = 2 end
					was[icon] = on
					if (settle[icon] or 0) > 0 then
						settle[icon] = settle[icon] - 1
					elseif on then
						onLooks = onLooks + 1
						if (Plain(icon.GetAlpha, icon) or 1) < 0.1 then onOk = onOk + 1 end
					else
						offLooks = offLooks + 1
						if Plain(icon.IsShown, icon) and (Plain(icon.GetAlpha, icon) or 0) > 0.9 then offOk = offOk + 1 end
					end
				end
				local parts = {}
				for _, item in ipairs(items) do parts[#parts + 1] = IconLine(item) end
				local line = "in the fight: " .. table.concat(parts, "; ")
				if line ~= lastLine then
					r:Log(line)
					lastLine = line
				end
				if looks == 4 then r:Shot("Missing in a fight", { behind = _G.BuffIconCooldownViewer }) end
				r:Sleep(0.5)
			end
			r:Log(("fight %.1f s, %d looks; off you %d (shown %d), on you %d (faded %d)"):format(GetTime() - started, looks,
				offLooks, offOk, onLooks, onOk))
			r:Verdict(looks >= 4, ("the fight was looked at: %d looks"):format(looks))
			if offLooks > 0 then
				r:Verdict(offOk == offLooks, ("in the fight, off you: shown %d of %d looks"):format(offOk, offLooks))
			else
				r:Skip("the buff was never off you in the fight")
			end
			if onLooks > 0 then
				r:Verdict(onOk == onLooks, ("in the fight, on you: faded %d of %d looks"):format(onOk, onLooks))
			else
				r:Skip("the buff was never on you in the fight (cast it in the fight to check the fade)")
			end
			r:Verdict(stats.refused == refusedBefore, ("Shows refused in the fight (protected icon): %d"):format(stats.refused - refusedBefore))
			r:Sleep(2)
			LogBuffRead(r, "after the fight")
			r:Log("after the fight: " .. IconLine(missing.off))
			local icon = missing.off.icon
			r:Verdict(ns.CooldownBuffOnYou(icon) and (Plain(icon.GetAlpha, icon) or 1) < 0.1
				or not ns.CooldownBuffOnYou(icon) and Plain(icon.IsShown, icon) == true,
				"after the fight: shown while off you, faded while on")
		end },
	},
})
