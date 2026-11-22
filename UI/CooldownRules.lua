-- Cinematic: the Cooldown Manager page's place groups (2026-11-22, in place of
-- each row's numbered lines, which came in place of situations). A group is
-- only a where: some places (or Anywhere) and a combat (any, in a fight, out
-- of one), or a CQL rule. Groups are shared by every bar and read left to
-- right: the first that fits now is the one in use. Each row (a spell, a
-- tracked buff or a bar) has a cell per group saying what its icon shows
-- there; a cell not set follows: a spell's its bar's cell, then its own
-- Otherwise (the row's own mode), then its bar's Otherwise. The page draws
-- them as a grid (UI/CooldownGrid.lua).
-- Kept in db.cooldownPlaceGroups (a list of { id, name, places = { place =
-- true } or { any = true }, combat } or { id, name, cql }) and the cells in
-- db.cooldownSpellCells (spell ID ->), cooldownBuffCells (tracked buff's
-- spell ID ->) and cooldownGroupCells (bar ->): { [group id] = mode }.
-- (Frames.lua's ns.CooldownSpellMode and the rest ask ns.CooldownRuleMode.)
local _, ns = ...
local L = ns.L

-- The places, each moment in exactly one (Spot below), and the combats.
local PLACES = {
	{ "world", L["Open world"] }, { "city", L["Cities"] }, { "inn", L["Inns"] }, { "dungeon", L["Dungeons"] },
	{ "raid", L["Raids"] }, { "bg", L["BGs & arenas"] },
}
local PLACE_NAME = { any = L["Anywhere"] }
for _, place in ipairs(PLACES) do PLACE_NAME[place[1]] = place[2] end
local COMBATS = { { "any", L["Any time"] }, { "in", L["In combat"] }, { "out", L["Out of combat"] } }
local COMBAT_NAME = {}
for _, combat in ipairs(COMBATS) do COMBAT_NAME[combat[1]] = combat[2] end
-- (In combat: the Calm Timer after a fight too, as everywhere since 2026-11-10.)
local COMBAT_WORDS = { ["in"] = "(combat or calm)", out = "nocombat" }
ns.COOLDOWN_RULE_PLACES, ns.COOLDOWN_RULE_COMBATS = PLACES, COMBATS
ns.COOLDOWN_PLACE_NAME, ns.COOLDOWN_COMBAT_NAME = PLACE_NAME, COMBAT_NAME
-- (More than this and the grid's columns are too narrow to read.)
ns.COOLDOWN_GROUP_MAX = 5

local CELLS = { spell = "cooldownSpellCells", buff = "cooldownBuffCells", group = "cooldownGroupCells" }
ns.COOLDOWN_CELL_TABLES = CELLS

-- A group as it should be (from a profile or an import: bad parts mended),
-- or nil for one that can't be.
local function Mend(group)
	if type(group) ~= "table" or type(group.id) ~= "number" then return nil end
	if type(group.name) ~= "string" then group.name = "" end
	if type(group.cql) == "string" and group.cql:find("%S") then
		group.places, group.combat = nil, nil
		return group
	end
	group.cql = nil
	if type(group.places) ~= "table" then group.places = {} end
	for place, on in pairs(group.places) do
		if not PLACE_NAME[place] or on ~= true then group.places[place] = nil end
	end
	if group.places.any then group.places = { any = true } end
	if not COMBAT_NAME[group.combat] then group.combat = "any" end
	return group
end
ns.MendCooldownGroup = Mend

-- The groups, in order (mended; the list made if missing).
function ns.CooldownPlaceGroups()
	local db = ns.db
	if not db then return {} end
	if type(db.cooldownPlaceGroups) ~= "table" then db.cooldownPlaceGroups = {} end
	local list = db.cooldownPlaceGroups
	for i = #list, 1, -1 do
		if not Mend(list[i]) then table.remove(list, i) end
	end
	return list
end

-- A group by its id, and its place in the order.
function ns.CooldownPlaceGroup(id)
	for i, group in ipairs(ns.CooldownPlaceGroups()) do
		if group.id == id then return group, i end
	end
end

-- A new group at the end (no places yet: it fits nowhere till one is
-- picked), or nil at the most.
function ns.AddCooldownGroup()
	local list = ns.CooldownPlaceGroups()
	if #list >= ns.COOLDOWN_GROUP_MAX then return nil end
	local id = 0
	for _, group in ipairs(list) do id = math.max(id, group.id) end
	local group = { id = id + 1, name = "", places = {}, combat = "any" }
	list[#list + 1] = group
	ns.CooldownRuleFactsStale()
	return group
end

-- A group gone, with every row's cell for it.
function ns.RemoveCooldownGroup(id)
	local list = ns.CooldownPlaceGroups()
	for i = #list, 1, -1 do
		if list[i].id == id then table.remove(list, i) end
	end
	for _, name in pairs(CELLS) do
		local all = ns.db[name]
		for key, row in pairs(type(all) == "table" and all or {}) do
			if type(row) == "table" then
				row[id] = nil
				if next(row) == nil then all[key] = nil end
			end
		end
	end
	ns.CooldownRuleFactsStale()
end

-- A group moved one place left (by -1) or right (by 1) in the order.
function ns.MoveCooldownGroup(id, by)
	local list = ns.CooldownPlaceGroups()
	local _, i = ns.CooldownPlaceGroup(id)
	local j = i and i + by
	if not j or j < 1 or j > #list then return false end
	list[i], list[j] = list[j], list[i]
	ns.CooldownRuleFactsStale()
	return true
end

-- The places a group has, in the page's order (any: Anywhere alone).
local function PlacesOf(group)
	local out = {}
	if not group.places then return out end
	if group.places.any then return { "any" } end
	for _, place in ipairs(PLACES) do
		if group.places[place[1]] then out[#out + 1] = place[1] end
	end
	return out
end
ns.CooldownGroupPlaces = PlacesOf

-- A group's where as words for people: "Dungeons, Raids · In combat", or its rule.
function ns.CooldownGroupWhere(group)
	if group.cql then return group.cql end
	local places = PlacesOf(group)
	if #places == 0 then return L["No place yet"] end
	local names = {}
	for i, place in ipairs(places) do names[i] = PLACE_NAME[place] end
	local text = table.concat(names, ", ")
	if group.combat ~= "any" then text = text .. " · " .. COMBAT_NAME[group.combat] end
	return text
end

-- Its name: its own, else its where.
function ns.CooldownGroupName(group)
	if group.name and group.name:find("%S") then return group.name end
	return ns.CooldownGroupWhere(group)
end

-- A group's where as a CQL rule: its own, or its places and combat ("" for anywhere, any).
function ns.CooldownGroupText(group)
	if group.cql then return group.cql end
	local words = {}
	local places = PlacesOf(group)
	if #places > 0 and places[1] ~= "any" then
		words[1] = #places == 1 and places[1] or ("(" .. table.concat(places, " or ") .. ")")
	end
	if COMBAT_WORDS[group.combat] then words[#words + 1] = COMBAT_WORDS[group.combat] end
	return table.concat(words, " and ")
end

-- A rule typed in the editor, put on a group: emptied, back to its places
-- and combat (none picked); the same as they say, kept as them; else its
-- CQL. Gives false (and why) for one that doesn't read, leaving it as it was.
local function Squash(text) return (text:lower():gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")) end
function ns.SetCooldownGroupText(group, text)
	text = text or ""
	if not text:find("%S") then
		if group.cql then group.cql, group.places, group.combat = nil, {}, "any" end
		return true
	end
	local _, err = ns.CompileRule(text)
	if err then return false, err end
	if not group.cql and Squash(text) == Squash(ns.CooldownGroupText(group)) then return true end
	group.cql, group.places, group.combat = text, nil, nil
	return true
end

-- Where you are now: one of PLACES, and whether it's a fight (the Calm Timer
-- after one too), from the rules' facts.
local function Spot(facts)
	local place = facts.bg and "bg" or facts.dungeon and "dungeon" or facts.raid and "raid"
		or facts.city and "city" or facts.inn and "inn" or "world"
	return place, not facts.nocombat
end
ns.CooldownSpot = Spot

-- The facts the groups are read against, once per moment (each icon of each
-- bar asks, every pass).
local factsAt, factsNow, nowAt, nowGroup, nowIndex
function ns.CooldownRuleFacts()
	local now = GetTime()
	if factsAt ~= now or not factsNow then
		factsAt, factsNow = now, ns.RuleFactsNow()
	end
	return factsNow
end
-- (A change on the page, or a test faking a place: read again at once.)
function ns.CooldownRuleFactsStale()
	factsAt, nowAt = nil, nil
end

-- Whether a group fits now. (A CQL rule that doesn't read, or no place picked, never fits.)
function ns.CooldownGroupFits(group, facts)
	facts = facts or ns.CooldownRuleFacts()
	if group.cql then
		local test = ns.CompileRule(group.cql)
		return test ~= nil and test(facts) and true or false
	end
	if not (group.places and next(group.places)) then return false end
	local place, fight = Spot(facts)
	if not (group.places.any or group.places[place]) then return false end
	return group.combat == "any" or (group.combat == "in") == fight
end

-- The group in use now (the first that fits) and its place in the order; nil
-- with none. facts given: read against them, not kept.
function ns.CooldownGroupNow(facts)
	if facts then
		for i, group in ipairs(ns.CooldownPlaceGroups()) do
			if ns.CooldownGroupFits(group, facts) then return group, i end
		end
		return nil
	end
	local now = GetTime()
	if nowAt ~= now then
		nowAt, nowGroup, nowIndex = now, nil, nil
		local current = ns.CooldownRuleFacts()
		for i, group in ipairs(ns.CooldownPlaceGroups()) do
			if ns.CooldownGroupFits(group, current) then
				nowGroup, nowIndex = group, i
				break
			end
		end
	end
	return nowGroup, nowIndex
end

-- A row's cells (kind "spell", "buff" or "group"; key its spell ID or bar),
-- or nil with none. make: an empty table made for it. A spell or buff's are
-- kept under its ID, else its base spell's.
local function CellRow(kind, key, make)
	local db = ns.db
	local name = CELLS[kind]
	if not (db and name) or key == nil then return nil end
	if type(db[name]) ~= "table" then db[name] = {} end
	local all = db[name]
	local row = all[key]
	if row == nil and kind ~= "group" and ns.BaseSpell then
		local base = ns.BaseSpell(key)
		if base ~= key and all[base] ~= nil then key, row = base, all[base] end
	end
	if row ~= nil and type(row) ~= "table" then
		all[key] = nil
		row = nil
	end
	if not row and make then
		row = {}
		all[key] = row
	end
	return row, all, key
end

-- What a row's cell for a group says (a mode), nil when it follows.
function ns.CooldownCell(kind, key, id)
	local row = CellRow(kind, key)
	local value = row and row[id]
	return type(value) == "string" and value ~= "" and value or nil
end

-- (mode nil: back to following.)
function ns.SetCooldownCell(kind, key, id, mode)
	local row, all, at = CellRow(kind, key, mode ~= nil)
	if not row then return end
	row[id] = mode
	if next(row) == nil then all[at] = nil end
	ns.CooldownRuleFactsStale()
	if ns.readyPace then ns.readyPace.due = true end
end

-- A row's cells as a copy (Copy row), and put on another (Paste row: its own cells replaced).
function ns.CooldownCellsOf(kind, key)
	local copy = {}
	for id, mode in pairs(CellRow(kind, key) or {}) do copy[id] = mode end
	return copy
end
function ns.SetCooldownCells(kind, key, cells)
	local row, all, at = CellRow(kind, key, true)
	wipe(row)
	for id, mode in pairs(cells or {}) do row[id] = mode end
	if next(row) == nil then all[at] = nil end
	ns.CooldownRuleFactsStale()
	if ns.readyPace then ns.readyPace.due = true end
end

-- The mode of a row's cell for the group in use now, and that group's place
-- in the order; nil when it has none (it follows: what asks goes on to the
-- next in line, Frames.lua).
function ns.CooldownRuleMode(kind, key, facts)
	local group, index = ns.CooldownGroupNow(facts)
	if not group then return nil end
	local mode = ns.CooldownCell(kind, key, group.id)
	if mode then return mode, index end
	return nil
end

-- Whether any row has a cell (the ready check runs while one does).
function ns.CooldownRulesAny()
	local db = ns.db
	if not (db and type(db.cooldownPlaceGroups) == "table" and db.cooldownPlaceGroups[1]) then return false end
	for _, name in pairs(CELLS) do
		if type(db[name]) == "table" and next(db[name]) then return true end
	end
	return false
end

-- Each group's trouble, by its place in the order: "dead" with the names of
-- the groups before it that take every place and time it has (it's never in
-- use), or "todo" (no place picked yet). And whether Otherwise is never in
-- use (the groups take everywhere). CQL groups aren't judged.
function ns.CooldownGroupTrouble()
	local trouble, taken = {}, {}
	local list = ns.CooldownPlaceGroups()
	local all = 0
	for i, group in ipairs(list) do
		if not group.cql then
			local places = PlacesOf(group)
			if #places == 0 then
				trouble[i] = { kind = "todo" }
			else
				if places[1] == "any" then
					places = {}
					for j, place in ipairs(PLACES) do places[j] = place[1] end
				end
				local combats = group.combat == "any" and { "in", "out" } or { group.combat }
				local by, fresh = {}, {}
				for _, place in ipairs(places) do
					for _, combat in ipairs(combats) do
						local spot = place .. "|" .. combat
						if taken[spot] then by[taken[spot]] = true else fresh[#fresh + 1] = spot end
					end
				end
				if #fresh == 0 then
					local names = {}
					for j = 1, i - 1 do
						if by[j] then names[#names + 1] = ns.CooldownGroupName(list[j]) end
					end
					trouble[i] = { kind = "dead", by = names }
				end
				for _, spot in ipairs(fresh) do
					taken[spot] = i
					all = all + 1
				end
			end
		end
	end
	return trouble, all >= #PLACES * 2
end

-- /cine debug cooldowns' first lines: where you are, the groups with the one
-- in use, and each row's cells.
function ns.ReportCooldownRules()
	local db = ns.db
	local facts = ns.RuleFactsNow()
	local place, fight = Spot(facts)
	ns.Print(("cooldown groups: you're in %s, %s"):format(place, fight and "in a fight" or "out of fights"))
	local _, hit = ns.CooldownGroupNow(facts)
	local trouble = ns.CooldownGroupTrouble()
	local list = ns.CooldownPlaceGroups()
	for i, group in ipairs(list) do
		print(("  %d. [%d] %s | %s%s%s"):format(i, group.id, ns.CooldownGroupName(group), ns.CooldownGroupWhere(group),
			i == hit and " [IN USE]" or "", trouble[i] and (" [" .. trouble[i].kind:upper() .. "]") or ""))
	end
	if not list[1] then print("  no groups: each row's own Otherwise") end
	for kind, name in pairs(CELLS) do
		for key, row in pairs(type(db[name]) == "table" and db[name] or {}) do
			local parts = {}
			for id, mode in pairs(type(row) == "table" and row or {}) do parts[#parts + 1] = ("%s=%s"):format(id, mode) end
			table.sort(parts)
			print(("  %s %s: %s"):format(kind, tostring(key), table.concat(parts, " ")))
		end
	end
end
