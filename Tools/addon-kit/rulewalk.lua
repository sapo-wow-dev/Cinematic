-- The rule walk (addon kit step 2, Tools/addon-kit-plan.md part C, offline):
-- every row's show logic through the real path that decides what fades
-- (ns.CombatShownFrames, then ns.RowOnNow for the grid rows), with the rule
-- facts forced, so no fight, target or place is needed. From the repo root:
--
--   python -I Tools/offline/run.py Tools/addon-kit/rulewalk.lua <forever|retail> [--update] < /dev/null
--
-- 1 words    every word and alias in ns.RULE_WORDS compiles, alone and with
--            "not", and "a and b" / "a or b" read as they say
-- 2 facts    every word's fact is worked out by ns.RuleFactsAll (a word added
--            to RULE_WORDS with nothing setting its fact reads nil: never
--            true, a rule that can't work)
-- 3 rows     every Standard Frames and other-addon row (ns.COMBAT_SHOW,
--            read now: new rows join by themselves), every word as its
--            rule: the row's frames (or its group) shown with the word's fact
--            true, hidden with it false, the other way with "not <word>"
-- 4 grid     the same through ns.RowOnNow (the Chat, Bubbles, Effects,
--            Camera grids and the like), on every row key above and the
--            grid rows the code names
-- 5 follow   a row set to follow another (db.rowFollow) takes its rule and
--            ticks; set back, its own again
-- 6 ticks    rules cleared, each row's ticks (Always, In combat, Enemy,
--            Friendly, none) in each state (calm, fight with CineMode staying
--            or not, an enemy or a friend targeted), and each row that
--            follows another's ticks till set (ROW_FALLBACK): one CELL a row,
--            compared with Tools/addon-kit/rulewalk-<client>.txt. A changed
--            cell FAILs (--update saves this run as the baseline: an
--            expectation change, the user's OK). Rows whose ticks don't do
--            what the column says are listed as notes, for a look.
-- PASS or FAIL per check; exit 1 on a FAIL.
-- luacheck: push ignore 111 112 113 121 122
local client, flag, mutant = ...
assert(client == "forever" or client == "retail", "usage: rulewalk.lua <forever|retail> [--update | --mutant <name>]")
local update = flag == "--update"
mutant = flag == "--mutant" and mutant or nil
local BASELINE = ("Tools/addon-kit/rulewalk-%s.txt"):format(client)
local FORMAT = 1

local ns = dofile("Tools/offline/load.lua")(client, "Cinematic.toc")
local now = 1000
GetTime = function() return now end
local locked, target, enemy = false, false, false
InCombatLockdown = function() return locked end
UnitAffectingCombat = function() return locked end
UnitIsDeadOrGhost = function() return false end
UnitExists = function(unit) return unit == "target" and target end
ns.HasTarget = function() return target end
ns.IsEnemyUnit = function(unit) if unit == "target" and target then return enemy end return false end
ns.IsGamePadOn = function() return false end
ns.SpellbookOpen = function() return false end
ns.HostileCastLeft = function() return nil end

-- Mutants (Tools/addon-kit/rulewalk.py --selftest): one break each, which
-- the walk must FAIL on, or it can't see that kind of bug.
local MUTANTS = {
	-- a row whose rule is never read (its consumer skips ns.RuleShows)
	ruleignored = function()
		local RuleShows = ns.RuleShows
		ns.RuleShows = function(key, facts) if key == "target" then return nil end return RuleShows(key, facts) end
	end,
	-- a word that reads the wrong fact
	wrongfact = function() ns.RULE_WORDS.mounted = "flying" end,
	-- a word added with nothing working its fact out
	nofact = function() ns.RULE_WORDS.zzznofact = "zzznofact" end,
	-- a follow row that no longer follows
	follow = function() ns.FollowKey = function(key) return key end end,
	-- a tick column that does nothing for one row
	tick = function()
		local IsCombatShowOn = ns.IsCombatShowOn
		ns.IsCombatShowOn = function(key) if key == "focus" then return false end return IsCombatShowOn(key) end
	end,
}
if mutant then
	assert(MUTANTS[mutant], "no mutant " .. tostring(mutant))
	MUTANTS[mutant]()
	print("mutant: " .. mutant)
end
-- luacheck: pop

local fails = 0
local function Check(ok, text)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. text)
end
local function Note(text) print("note " .. text) end

local db = ns.db
for _, name in ipairs({ "frameRules", "rowFollow", "cineShow", "combatShow", "enemyShow", "friendlyShow", "camShow",
	"bgShow", "worldShow", "cityShow", "groupShow", "instanceShow" }) do
	if type(db[name]) ~= "table" then db[name] = {} end
end
db.calmTime = 0

-- The words' facts: each field of the facts table a word names.
local fields, aliases = {}, {}
for word, field in pairs(ns.RULE_WORDS) do
	fields[field] = true
	aliases[#aliases + 1] = word
end
table.sort(aliases)
local fieldList = {}
for field in pairs(fields) do fieldList[#fieldList + 1] = field end
table.sort(fieldList)

-- 2 facts, first (on the real facts, before they're forced below).
do
	local ok, real = pcall(ns.RuleFactsAll, false)
	Check(ok and type(real) == "table", "2 facts: ns.RuleFactsAll works out the facts" ..
		(ok and "" or (": " .. tostring(real))))
	if ok and type(real) == "table" then
		local missing = {}
		local UnitClassWas = UnitClass
		-- (The game's classes, by file name: a new class is a FAIL here till added.)
		local CLASSES = { warrior = true, paladin = true, hunter = true, rogue = true, priest = true, deathknight = true,
			shaman = true, mage = true, warlock = true, monk = true, druid = true, demonhunter = true, evoker = true }
		for _, field in ipairs(fieldList) do
			if type(real[field]) ~= "boolean" and not CLASSES[field] then
				missing[#missing + 1] = field .. "=" .. tostring(real[field])
			elseif type(real[field]) ~= "boolean" then
				-- (The class words: only your own class's fact is set, the others
				-- left nil. Each counts once a player of that class gets it.)
				UnitClass = function() return field, field:upper(), 1 end -- luacheck: ignore 121
				local okClass, asClass = pcall(ns.RuleFactsAll, false)
				UnitClass = UnitClassWas -- luacheck: ignore 121
				if not (okClass and asClass[field] == true) then
					missing[#missing + 1] = field .. "=" .. tostring(real[field])
				end
			end
		end
		pcall(ns.RuleFactsAll, false)
		-- (And the other way: a fact worked out that no word reads. A word
		-- pointed at the wrong fact leaves its own fact with none.)
		local unread = {}
		for field, value in pairs(real) do
			if type(field) == "string" and type(value) == "boolean" and not fields[field] and not CLASSES[field] then
				unread[#unread + 1] = field
			end
		end
		table.sort(unread)
		Check(#unread == 0, "2 facts: every fact worked out has a word reading it" ..
			(#unread > 0 and (": " .. table.concat(unread, " ")) or ""))
		Check(#missing == 0, ("2 facts: every word's fact is worked out (%d facts)%s"):format(#fieldList,
			#missing > 0 and (": not set: " .. table.concat(missing, " ")) or ""))
	end
end

-- The facts, forced: every field false but always, one made true.
local forced = {}
local stamp = 0
local function Facts(trueField)
	for _, field in ipairs(fieldList) do forced[field] = false end
	forced.always = true
	if trueField then forced[trueField] = true end
	stamp = stamp + 1
	return forced
end
ns.RuleFacts = function()
	ns.factsStamp = stamp
	return forced
end
ns.RuleFactsNow = ns.RuleFacts

-- The list worked out afresh (its kept copy goes past every hold).
local function Shown()
	now = now + 100
	return ns.CombatShownFrames()
end

-- 1 words
do
	local bad = {}
	for _, word in ipairs(aliases) do
		local field = ns.RULE_WORDS[word]
		local test = ns.CompileRule(word)
		local notTest = ns.CompileRule("not " .. word)
		if not (test and notTest) then
			bad[#bad + 1] = word .. " (doesn't compile)"
		elseif field ~= "always" and field ~= "never" then
			if test(Facts(field)) ~= true or notTest(Facts(field)) ~= false
				or test(Facts(nil)) ~= false or notTest(Facts(nil)) ~= true then
				bad[#bad + 1] = word
			end
		end
	end
	Check(#bad == 0, ("1 words: each of %d words and aliases reads its fact, and not reads the other way%s"):format(
		#aliases, #bad > 0 and (": " .. table.concat(bad, " ")) or ""))
	local a, b = fieldList[1] == "always" and fieldList[2] or fieldList[1], "combat"
	local wordOf = {}
	for word, field in pairs(ns.RULE_WORDS) do
		if not wordOf[field] or #word < #wordOf[field] then wordOf[field] = word end
	end
	local andTest = ns.CompileRule(wordOf[a] .. " and " .. wordOf[b])
	local orTest = ns.CompileRule(wordOf[a] .. " or " .. wordOf[b])
	Facts(a)
	local one = andTest and andTest(forced)
	local either = orTest and orTest(forced)
	Check(one == false and either == true, ("1 words: \"%s and %s\" needs both, \"or\" either"):format(wordOf[a],
		wordOf[b]))
	Check(ns.CompileRule("always")(Facts(nil)) == true and ns.CompileRule("never")(Facts(nil)) == false,
		"1 words: always and never")
	-- (A word named as a fact reads that fact: "mounted" reading flying
	-- would pass every check above, which take the table's word for it.)
	local crossed = {}
	for _, word in ipairs(aliases) do
		if fields[word] and ns.RULE_WORDS[word] ~= word then
			crossed[#crossed + 1] = word .. "->" .. ns.RULE_WORDS[word]
		end
	end
	local orphan = {}
	for _, field in ipairs(fieldList) do
		if ns.RULE_WORDS[field] ~= field then orphan[#orphan + 1] = field end
	end
	Check(#crossed == 0 and #orphan == 0, "1 words: each fact has the word of its own name, reading it" ..
		((#crossed + #orphan) > 0 and (": " .. table.concat(crossed, " ") .. " " .. table.concat(orphan, " ")) or ""))
end

-- The rows: every row of ns.COMBAT_SHOW that applies with no gamepad, by
-- what it puts in the shown list (its frames' names, or its group's key).
local rows, keys = {}, {}
for _, item in ipairs(ns.COMBAT_SHOW) do
	if not item.gamepadOnly and item.key then
		local marks = {}
		for _, name in ipairs(item.frames or {}) do marks[#marks + 1] = name end
		for _, group in ipairs(item.groups or {}) do marks[#marks + 1] = "group:" .. group end
		if #marks > 0 and not keys[item.key] then
			rows[#rows + 1] = { key = item.key, marks = marks }
			keys[item.key] = true
		end
	end
end
Check(#rows > 50, ("rows: %d rows to walk"):format(#rows))

-- A row's marks all in the list (true), none (false), or some (nil).
local function RowState(list, row)
	local n = 0
	for _, mark in ipairs(row.marks) do
		if list[mark] then n = n + 1 end
	end
	if n == #row.marks then return true end
	if n == 0 then return false end
	return nil
end

local function ClearRules()
	for k in pairs(db.frameRules) do db.frameRules[k] = nil end
end
local function RuleAll(text)
	for _, row in ipairs(rows) do db.frameRules[row.key] = text end
end
-- (A row's marks can be shared with another row: the list shows a name when
-- any of its rows does. All rows carry the same rule here, so they agree.)

-- 3 rows
do
	local wordOf = {}
	for word, field in pairs(ns.RULE_WORDS) do
		if not wordOf[field] or #word < #wordOf[field] then wordOf[field] = word end
	end
	local badRows, tested = {}, 0
	for _, field in ipairs(fieldList) do
		if field ~= "always" and field ~= "never" then
			local word = wordOf[field]
			for _, text in ipairs({ word, "not " .. word }) do
				RuleAll(text)
				Facts(field)
				local up = Shown()
				local upState = {}
				for _, row in ipairs(rows) do upState[row.key] = RowState(up, row) end
				Facts(nil)
				local down = Shown()
				local want = text == word
				for _, row in ipairs(rows) do
					tested = tested + 1
					local a, b = upState[row.key], RowState(down, row)
					if a ~= want or b ~= not want then
						local list = badRows[row.key] or {}
						badRows[row.key] = list
						if #list < 4 then
							list[#list + 1] = ("%s: %s with it, %s without"):format(text, tostring(a), tostring(b))
						end
					end
				end
			end
		end
	end
	ClearRules()
	local names = {}
	for key in pairs(badRows) do names[#names + 1] = key end
	table.sort(names)
	for _, key in ipairs(names) do print(("      %s: %s"):format(key, table.concat(badRows[key], "; "))) end
	Check(#names == 0, ("3 rows: every row follows every word as its rule, and not (%d row-word checks)%s"):format(
		tested, #names > 0 and (": %d rows don't: %s"):format(#names, table.concat(names, " ")) or ""))
end

-- 4 grid: ns.RowOnNow, every row key and the grid rows the code names.
do
	local gridKeys = {}
	for _, row in ipairs(rows) do gridKeys[#gridKeys + 1] = row.key end
	for _, key in ipairs({ "tooltip:All", "music", "chat:typing", "targetcircle", "selfhighlight", ns.EXIT_ROW,
		"bubble:Say", "bubble:Yell", "bubble:Party", "bubble:NPC" }) do
		if key and not keys[key] then gridKeys[#gridKeys + 1] = key end
	end
	local wordOf = {}
	for word, field in pairs(ns.RULE_WORDS) do
		if not wordOf[field] or #word < #wordOf[field] then wordOf[field] = word end
	end
	local bad, tested = {}, 0
	for _, field in ipairs(fieldList) do
		if field ~= "always" and field ~= "never" then
			local word = wordOf[field]
			for _, key in ipairs(gridKeys) do
				db.frameRules[key] = word
				Facts(nil)
				local down = ns.RowOnNow(key, false, true)
				Facts(field)
				local up = ns.RowOnNow(key, false, true)
				tested = tested + 1
				if up ~= true or down ~= false then
					bad[#bad + 1] = ("%s/%s"):format(key, word)
				end
				db.frameRules[key] = nil
			end
		end
	end
	Check(#bad == 0, ("4 grid: ns.RowOnNow follows every word on %d row keys (%d checks)%s"):format(#gridKeys, tested,
		#bad > 0 and (": " .. table.concat(bad, " ", 1, math.min(#bad, 12))) or ""))
end

-- 5 follow: db.rowFollow
do
	local lead, follower
	for _, row in ipairs(rows) do
		if row.key == "player" then lead = row end
		if row.key == "target" then follower = row end
	end
	if lead and follower then
		ClearRules()
		db.frameRules.player = "combat"
		db.frameRules.target = "never"
		db.rowFollow.target = "player"
		Facts("combat")
		local withLead = RowState(Shown(), follower)
		db.rowFollow.target = nil
		local own = RowState(Shown(), follower)
		Check(withLead == true and own == false, ("5 follow: a row set to follow takes its leader's rule (%s), and its" ..
			" own once set back (%s)"):format(tostring(withLead), tostring(own)))
		ClearRules()
		for _, list in ipairs({ "cineShow", "combatShow", "enemyShow", "friendlyShow" }) do
			db[list].player, db[list].target = false, false
		end
		db.cineShow.player = true
		db.rowFollow.target = "player"
		Facts(nil)
		local ticksLead = RowState(Shown(), follower)
		db.rowFollow.target = nil
		local ticksOwn = RowState(Shown(), follower)
		Check(ticksLead == true and ticksOwn == false, ("5 follow: and its leader's ticks (%s), its own once set back (%s)")
			:format(tostring(ticksLead), tostring(ticksOwn)))
		db.cineShow.player, db.cineShow.target = nil, nil
		for _, list in ipairs({ "combatShow", "enemyShow", "friendlyShow" }) do db[list].player, db[list].target = nil, nil end
	else
		Check(false, "5 follow: the player and target rows found")
	end
end

-- 6 ticks: a CELL per row, compared with the baseline.
local TICKS = { "none", "always", "combat", "enemy", "friendly" }
local STATES = { "calm", "fight-stays", "fight-goes", "enemy", "friend" }
local function SetState(state)
	locked = state == "fight-stays" or state == "fight-goes"
	db.stayInCombat = state ~= "fight-goes"
	db.exitByRow = false
	target = state == "enemy" or state == "friend"
	enemy = state == "enemy"
	Facts(locked and "combat" or nil)
end
local function SetTicks(tick, which)
	for _, row in ipairs(which) do
		db.cineShow[row.key] = tick == "always"
		-- (A row whose Always is a setting of its own: the minimap's, the waypoint's.)
		local own = ns.CINE_SHOW_SETTING and ns.CINE_SHOW_SETTING[row.key]
		if own then db[own] = tick == "always" end
		db.combatShow[row.key] = tick == "combat"
		db.enemyShow[row.key] = tick == "enemy"
		db.friendlyShow[row.key] = tick == "friendly"
		db.camShow[row.key] = false
		for _, list in ipairs({ "bgShow", "worldShow", "cityShow", "groupShow", "instanceShow" }) do db[list][row.key] = false end
	end
end
local function ClearTicks()
	for _, list in ipairs({ "cineShow", "combatShow", "enemyShow", "friendlyShow", "camShow", "bgShow", "worldShow",
		"cityShow", "groupShow", "instanceShow" }) do
		for k in pairs(db[list]) do db[list][k] = nil end
	end
	for _, own in pairs(ns.CINE_SHOW_SETTING or {}) do db[own] = false end
end
-- The usual: what each tick column means.
local function Usual(tick, state)
	if tick == "always" then return true end
	if tick == "combat" then return state == "fight-stays" end
	if tick == "enemy" then return state == "enemy" end
	if tick == "friendly" then return state == "friend" end
	return false
end
local function Mark(v) return v == true and "+" or (v == false and "-" or "~") end

ClearRules()
local cells, odd = {}, {}
local results = {} -- [key] = { [tick] = "....." }
for _, tick in ipairs(TICKS) do
	ClearTicks()
	SetTicks(tick, rows)
	for _, state in ipairs(STATES) do
		SetState(state)
		local list = Shown()
		for _, row in ipairs(rows) do
			local r = results[row.key] or {}
			results[row.key] = r
			local v = RowState(list, row)
			r[tick] = (r[tick] or "") .. Mark(v)
			if v ~= Usual(tick, state) then odd[row.key] = true end
		end
	end
end
-- Rows that follow another's ticks till set (ROW_FALLBACK): their own lists
-- left unset, the leader's Always ticked.
local fallback = {}
for child, leader in pairs(ns.ROW_FALLBACK or {}) do
	if keys[child] and keys[leader] then fallback[#fallback + 1] = { child = child, leader = leader } end
end
table.sort(fallback, function(a, b) return a.child < b.child end)
local byKey = {}
for _, row in ipairs(rows) do byKey[row.key] = row end
for _, pair in ipairs(fallback) do
	ClearTicks()
	SetTicks("none", { byKey[pair.leader] })
	db.cineShow[pair.leader] = true
	local own = ns.CINE_SHOW_SETTING and ns.CINE_SHOW_SETTING[pair.leader]
	if own then db[own] = true end
	SetState("calm")
	local r = results[pair.child]
	r.follows = pair.leader .. Mark(RowState(Shown(), byKey[pair.child]))
end
ClearTicks()
locked, target, enemy = false, false, false

for _, row in ipairs(rows) do
	local r = results[row.key]
	local parts = {}
	for _, tick in ipairs(TICKS) do parts[#parts + 1] = tick .. "=" .. r[tick] end
	if r.follows then parts[#parts + 1] = "follows=" .. r.follows end
	cells[#cells + 1] = ("CELL %s %s"):format(row.key, table.concat(parts, " "))
end
table.sort(cells)
local oddKeys = {}
for key in pairs(odd) do oddKeys[#oddKeys + 1] = key end
table.sort(oddKeys)
if #oddKeys > 0 then
	Note(("6 ticks: %d rows whose ticks don't do what the column says (states %s; + shown, - hidden, ~ part): %s")
		:format(#oddKeys, table.concat(STATES, ","), table.concat(oddKeys, " ")))
end

if update then
	local out = assert(io.open(BASELINE, "w"))
	out:write(("# addon-kit rule walk, format %d, client %s. States: %s. Saved by --update: never by hand.\n")
		:format(FORMAT, client, table.concat(STATES, ",")))
	for _, line in ipairs(cells) do out:write(line, "\n") end
	out:close()
	print(("rulewalk %s: %d rows saved as the baseline (%s)"):format(client, #cells, BASELINE))
else
	local known, head = {}, nil
	local file = io.open(BASELINE, "r")
	if file then
		head = file:read("*l")
		for line in file:lines() do
			line = line:gsub("\r", "")
			local key = line:match("^CELL (%S+)")
			if key then known[key] = line end
		end
		file:close()
	end
	local fmt = head and tonumber(head:match("format (%d+)"))
	if fmt ~= FORMAT then
		Check(false, ("6 ticks: a baseline of format %d (%s): --update"):format(FORMAT, head and "another format" or "none"))
	else
		local changed, new = {}, {}
		for _, line in ipairs(cells) do
			local key = line:match("^CELL (%S+)")
			if not known[key] then
				new[#new + 1] = key
			elseif known[key] ~= line then
				changed[#changed + 1] = key
				print(("      was: %s\n      now: %s"):format(known[key], line))
			end
			known[key] = nil
		end
		local gone = {}
		for key in pairs(known) do gone[#gone + 1] = key end
		table.sort(gone)
		Check(#changed == 0, ("6 ticks: every row's ticks as in the baseline (%d rows)%s"):format(#cells,
			#changed > 0 and (": changed: " .. table.concat(changed, " ")) or ""))
		Check(#new == 0, "6 ticks: no row the baseline doesn't have" ..
			(#new > 0 and (": new: " .. table.concat(new, " ") .. " (--update once checked)") or ""))
		Check(#gone == 0, "6 ticks: no row gone from the baseline" .. (#gone > 0 and (": " .. table.concat(gone, " ")) or ""))
	end
end

print(("rulewalk %s: %d FAIL"):format(client, fails))
os.exit(fails == 0 and 0 or 1)
