-- The unit words (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/unitwords.lua < /dev/null
-- Tools/cql-words-plan.md phase 1 (2026-11-25): one fact a word. hostile,
-- neutral, player and npc for your target (targethostile... too), the
-- mouse's (hover..., in hoverwords.lua) and your focus's (focus..., with
-- focusnear and focusnear28). Checked on a stand-in game, Forever then
-- retail: every kind of unit as target and as focus, each old kind word
-- equal to its pair of atoms (enemyplayer = hostile and player...), your
-- focus not read until a rule names a focus word, you and a dead unit as
-- focus, secret reads in a fight, the aliases, and the rule editor's lines
-- (atoms on them, the old kind words off them but still colored).
-- luacheck: push ignore 111 112 113 121 122 212 431
local SECRET = setmetatable({}, { __tostring = function() return "secret" end })
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

-- Each kind of unit: how the game answers for it, its old kind word and its atoms.
local KINDS = {
	{ name = "hostile NPC", unit = { attack = true, reaction = 2 }, kind = "hostilenpc", atoms = { "hostile", "npc" } },
	{ name = "neutral NPC", unit = { attack = true, reaction = 4 }, kind = "neutralnpc", atoms = { "neutral", "npc" } },
	{ name = "friendly NPC", unit = { attack = false, friend = true, reaction = 5 }, kind = "friendlynpc",
		atoms = { "npc" } },
	{ name = "enemy player", unit = { attack = true, player = true, friend = false }, kind = "enemyplayer",
		atoms = { "hostile", "player" } },
	{ name = "neutral player (enemy, not attackable)", unit = { attack = false, player = true, friend = false,
		canAttackFromIt = false }, kind = "neutralplayer", atoms = { "neutral", "player" } },
	{ name = "friendly player", unit = { attack = false, player = true, friend = true }, kind = "friendlyplayer",
		atoms = { "player" } },
	{ name = "dead hostile NPC", unit = { attack = true, reaction = 2, dead = true }, kind = "friendlynpc",
		atoms = { "npc" } },
}
local OLD_KINDS = { "enemyplayer", "hostilenpc", "neutralplayer", "neutralnpc", "friendlyplayer", "friendlynpc" }
local ATOMS = { "hostile", "neutral", "player", "npc" }

local function RunClient(client)
	print("== " .. client)
	local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function()
		issecretvalue = function(value) return value == SECRET end
	end)
	local now, combat = 100, false
	GetTime = function() return now end
	InCombatLockdown = function() return combat end
	UnitAffectingCombat = function(unit) return unit == "player" and combat end
	-- The game: the units ("target", "focus"), nil for none.
	local units, reads = {}, 0
	local function Read(field, unit)
		if unit == "focus" then reads = reads + 1 end
		local u = units[unit]
		return u and u[field]
	end
	UnitExists = function(unit)
		if unit == "player" then return true end
		if unit == "focus" then reads = reads + 1 end
		return units[unit] ~= nil
	end
	UnitGUID = function(unit) return Read("guid", unit) end
	UnitIsDeadOrGhost = function(unit) return Read("dead", unit) or false end
	UnitIsUnit = function(a, b) return b == "player" and units[a] ~= nil and units[a].me or false end
	UnitIsPlayer = function(unit) return Read("player", unit) or false end
	UnitCanAttack = function(_, unit) local v = Read("attack", unit) return v == nil and false or v end
	UnitIsFriend = function(_, unit) local v = Read("friend", unit) return v == nil and true or v end
	UnitReaction = function(unit) return Read("reaction", unit) or 5 end
	CheckInteractDistance = function(unit, index)
		local u = units[unit]
		if combat then return nil end
		return u ~= nil and u.yards ~= nil and u.yards <= (index == 2 and 11 or 28)
	end
	local function Step(seconds) now = now + (seconds or 1) end
	local function Facts() Step() return ns.RuleFactsNow() end
	local function Want(facts, prefix, want, what)
		local wrong = {}
		for field, value in pairs(want) do
			if (facts[prefix .. field] and true or false) ~= value then
				wrong[#wrong + 1] = prefix .. field .. "=" .. tostring(facts[prefix .. field])
			end
		end
		Check(what, #wrong == 0, table.concat(wrong, ", "))
	end

	-- 0. No rule names a focus word: your focus isn't read, every focus word false.
	ns.focusState.used = nil
	units.focus = { guid = "Creature-0", attack = true, reaction = 2 }
	reads = 0
	local facts = Facts()
	Check("no focus rule: your focus not read", reads == 0, reads .. " reads")
	Check("no focus rule: focus false", facts.focus == false, tostring(facts.focus))
	ns.CompileRule("focushostile and not combat")
	Check("a rule with a focus word compiled: read from then on", ns.focusState.used == true)

	-- 1. Every kind as your target, then as your focus: the atoms, and the old
	-- kind word equal to its atoms joined with and (friendly: neither hostile
	-- nor neutral, as the kind's row has it).
	local PAIRS = { enemyplayer = "hostile and player", hostilenpc = "hostile and npc",
		neutralplayer = "neutral and player", neutralnpc = "neutral and npc",
		friendlyplayer = "not hostile and not neutral and player", friendlynpc = "not hostile and not neutral and npc" }
	local compared, hits, mismatched = 0, 0, {}
	for _, k in ipairs(KINDS) do
		local u = {}
		for key, value in pairs(k.unit) do u[key] = value end
		u.guid = "Unit-" .. k.name
		units.target, units.focus = u, u
		facts = Facts()
		local on = {}
		for _, atom in ipairs(k.atoms) do on[atom] = true end
		local want = {}
		for _, atom in ipairs(ATOMS) do want[atom] = on[atom] or false end
		Want(facts, "", want, "target " .. k.name .. ": " .. table.concat(k.atoms, " and "))
		Want(facts, "focus", want, "focus " .. k.name .. ": focus" .. table.concat(k.atoms, ", focus"))
		Check("focus " .. k.name .. ": focus on", facts.focus == true)
		Check("focus " .. k.name .. ": focusdead " .. tostring(k.unit.dead == true),
			facts.focusdead == (k.unit.dead == true))
		for old, text in pairs(PAIRS) do
			local test, oldTest = ns.CompileRule(text), ns.CompileRule(old)
			compared = compared + 1
			if not (test and oldTest) or test(facts) ~= oldTest(facts) then
				mismatched[#mismatched + 1] = ("%s: %s %s, %s %s"):format(k.name, old,
					tostring(oldTest and oldTest(facts)), text, tostring(test and test(facts)))
			end
			if oldTest and oldTest(facts) then hits = hits + 1 end
		end
	end
	Check(("every old kind word equals its atoms, %d compared"):format(compared),
		#mismatched == 0 and compared == #KINDS * 6, table.concat(mismatched, "; "))
	Check("each kind is one old kind word exactly", hits == #KINDS, hits .. " of " .. #KINDS)

	-- 2. You as your focus; nothing as focus.
	units.focus = { guid = "Player-1", me = true, player = true }
	facts = Facts()
	Want(facts, "focus", { [""] = true, self = true, friendly = true, player = false, hostile = false, near = false },
		"you as focus: focus, focusself, focusfriendly, no kind")
	units.focus = nil
	facts = Facts()
	Want(facts, "focus", { [""] = false, self = false, enemy = false, friendly = false, npc = false },
		"no focus: every focus word false")

	-- 3. Distance: focusnear within 11 yards, focusnear28 within 28.
	units.focus = { guid = "Creature-9", attack = true, reaction = 2, yards = 20 }
	facts = Facts()
	Want(facts, "focus", { near = false, near28 = true, enemy = true }, "focus at 20 yards: focusnear28, not focusnear")
	units.focus.yards = 5
	facts = Facts()
	Want(facts, "focus", { near = true, near28 = true }, "focus at 5 yards: focusnear and focusnear28")

	-- 4. A fight: the game's answers secret. No error; what it won't say reads false.
	combat = true
	units.focus = { guid = SECRET, attack = SECRET, friend = SECRET, player = SECRET, reaction = SECRET, dead = SECRET }
	local okRun, got = pcall(Facts)
	Check("secret focus reads: no error", okRun, not okRun and got or nil)
	if okRun then
		Want(got, "focus", { [""] = true, enemy = false, hostile = false, player = false, near = false },
			"secret focus reads: focus only")
	end
	combat = false

	-- 5. The aliases.
	units.target = { guid = "Creature-10", attack = true, player = true, friend = false }
	units.focus = units.target
	facts = Facts()
	for text, want in pairs({ targethostile = true, targetplayer = true, targetnpc = false, anynpc = false,
		["hostile and player"] = true, enemyplayer = true, focushostile = true, ["focusplayer and not focusnpc"] = true,
		mouseoverplayer = false }) do
		local test, err = ns.CompileRule(text)
		Check(("rule \"%s\" reads %s"):format(text, tostring(want)), test ~= nil and test(facts) == want, err)
	end

	-- 6. The rule editor: atoms on the Target and Mouse over lines, the old
	-- kind words off them but colored as their line; a Focus line where the
	-- client has a focus frame.
	local lines = {}
	for _, group in ipairs(ns.RulePieces()) do lines[group[1]] = group end
	local function Words(group)
		local have = {}
		for _, piece in ipairs(group and group[3] or {}) do have[piece[1]] = true end
		return have
	end
	local target, hover = Words(lines[ns.L["Target"]]), Words(lines[ns.L["Mouse over"]])
	local missing, stale = {}, {}
	for _, atom in ipairs(ATOMS) do
		if not target[atom] then missing[#missing + 1] = atom end
		if not hover["hover" .. atom] then missing[#missing + 1] = "hover" .. atom end
	end
	for _, old in ipairs(OLD_KINDS) do
		if target[old] then stale[#stale + 1] = old end
		if hover["hover" .. old] then stale[#stale + 1] = "hover" .. old end
	end
	Check("rule editor: the atoms on Target and Mouse over", #missing == 0, table.concat(missing, ", "))
	Check("rule editor: no old kind word on them", #stale == 0, table.concat(stale, ", "))
	-- (Red, an unknown word's colour, as ColoredRule writes it.)
	local red = ns.ColoredRule("nosuchword"):match("|c%x%x%x%x%x%x%x%x")
	local colored = ns.ColoredRule("enemyplayer and hoverhostilenpc")
	Check("rule editor: an unknown word is red (" .. tostring(red) .. ")", red ~= nil)
	Check("rule editor: old kind words colored as known words, not red", red ~= nil and not colored:find(red, 1, true),
		colored)
	Check("rule editor: a Focus line with a focus frame (" .. tostring(_G.FocusFrame ~= nil) .. ")",
		(lines[ns.L["Focus"]] ~= nil) == (_G.FocusFrame ~= nil))
	local saved = _G.FocusFrame
	_G.FocusFrame = saved == nil and CreateFrame("Frame") or nil
	local flipped = false
	for _, group in ipairs(ns.RulePieces()) do if group[1] == ns.L["Focus"] then flipped = true end end
	Check("rule editor: the Focus line follows the focus frame both ways", flipped == (_G.FocusFrame ~= nil))
	_G.FocusFrame = saved
end

RunClient("forever")
RunClient("retail")
-- luacheck: pop
print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
