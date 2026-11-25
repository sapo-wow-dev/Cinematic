-- Only the words a rule names (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/factswords.lua < /dev/null
-- Frames.lua's ns.RuleFacts (2026-11-25): each full working out (every 0.1 s)
-- read every rule word from the game, weather, time of day, bosses, roles,
-- NPC windows and the rest, whether a rule named them or not. Now only the
-- words some compiled rule names (ns.factsUsed), all of them while the rule
-- editor is up or ns.RuleFactsAll asks, and the words ticks and other code
-- read straight from the facts always. On a stand-in game (Forever, then
-- retail), both builds: nothing read for words no rule names, a rule naming
-- one reads it right the first time (no frame late), a row's rule too, the
-- editor's dots, ns.RuleFactsAll, and the always words. PASS or FAIL per check.
-- luacheck: push ignore 111 112 113 121 122 212 431
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

-- (Words gated, each with the ns reader behind it, counted.)
local GATED = {
	{ word = "rain", reader = "WeatherNow", value = function() return "rain", 0.9 end },
	{ word = "dawn", reader = "TimeOfDayWord", value = function() return "dawn" end },
	{ word = "interacting", reader = "NPCWindowOpen", value = function() return true end },
	{ word = "tank", reader = "PlayerRole", value = function() return "TANK" end },
	{ word = "fast", reader = "PlayerSpeedNow", value = function() return 20 end },
}

local function RunClient(client, toc)
	print("== " .. client .. " " .. toc)
	local ns = dofile("Tools/offline/load.lua")(client, toc)
	local now = 100
	GetTime = function() return now end
	InCombatLockdown = function() return false end
	UnitAffectingCombat = function() return false end
	local function Step(seconds) now = now + (seconds or 1) end
	local reads = {}
	for _, g in ipairs(GATED) do
		reads[g.reader] = 0
		ns[g.reader] = function(...)
			reads[g.reader] = reads[g.reader] + 1
			return g.value(...)
		end
	end
	-- (Rules the load compiled already name some words: those left out.)
	local free = {}
	for _, g in ipairs(GATED) do
		if not ns.factsUsed[g.word] then free[#free + 1] = g end
	end
	local named = {}
	for word in pairs(ns.factsUsed) do named[#named + 1] = word end
	table.sort(named)
	print("  named at login: " .. (#named > 0 and table.concat(named, " ") or "none"))
	Check("some gated words free to test", #free >= 3, #free .. " of " .. #GATED)

	-- 1. No rule names them: not read, false.
	Step()
	local facts = ns.RuleFacts(false)
	for _, g in ipairs(free) do
		Check(g.word .. ", named by no rule: not read", reads[g.reader] == 0, reads[g.reader] .. " reads")
		Check(g.word .. ", named by no rule: false", facts[g.word] == false, tostring(facts[g.word]))
	end

	-- 2. The words other code reads straight from the facts: worked out anyway.
	IsMounted = function() return true end
	Step()
	facts = ns.RuleFacts(false)
	Check("mounted (Shoulder Cam reads it): worked out with no rule", facts.mounted == true, tostring(facts.mounted))
	Check("always, nocombat, world: worked out", facts.always == true and facts.nocombat == true
		and facts.world ~= nil, tostring(facts.world))

	-- 3. A rule names one: read at once, right on its first test.
	local g = free[1]
	local test = ns.CompileRule(g.word)
	Check(g.word .. ": the rule compiled", test ~= nil)
	Check(g.word .. ": in ns.factsUsed", ns.factsUsed[g.word] == true)
	Check(g.word .. ": read the moment the rule compiled", reads[g.reader] > 0, reads[g.reader] .. " reads")
	Check(g.word .. ": the first test reads true (not a frame late)", test and test(ns.sharedFacts) == true,
		tostring(ns.sharedFacts[g.word]))
	Step()
	facts = ns.RuleFacts(false)
	Check(g.word .. ": still read in later workings out", facts[g.word] == true, tostring(facts[g.word]))
	-- (The others still not read.)
	for i = 2, #free do
		Check(free[i].word .. ": still not read", reads[free[i].reader] == 0, reads[free[i].reader] .. " reads")
	end

	-- 4. A row's rule naming another: ns.RuleShows right the first time.
	local g2 = free[2]
	ns.db.frameRules = ns.db.frameRules or {}
	ns.db.frameRules["check:facts"] = "not " .. g2.word
	Step()
	facts = ns.RuleFacts(false)
	Check(g2.word .. ": a row's rule 'not " .. g2.word .. "' reads false at once",
		ns.RuleShows("check:facts", facts) == false, tostring(facts[g2.word]))
	ns.db.frameRules["check:facts"] = nil

	-- 5. The rule editor up: every word, for its dots; closed, back to the named.
	local g3 = free[3]
	local shown = true
	_G.CinematicRuleEditor = { IsShown = function() return shown end }
	Step()
	facts = ns.RuleFacts(false)
	Check(g3.word .. ": read while the rule editor is up", facts[g3.word] == true and reads[g3.reader] > 0,
		tostring(facts[g3.word]))
	shown = false
	Step()
	facts = ns.RuleFacts(false)
	Check(g3.word .. ": false again once the editor closes", facts[g3.word] == false, tostring(facts[g3.word]))
	_G.CinematicRuleEditor = nil

	-- 6. ns.RuleFactsAll: every word now, the named ones only after.
	reads[g3.reader] = 0
	facts = ns.RuleFactsAll(false)
	Check(g3.word .. ": ns.RuleFactsAll reads it", facts[g3.word] == true and reads[g3.reader] > 0,
		tostring(facts[g3.word]))
	Step()
	facts = ns.RuleFacts(false)
	Check(g3.word .. ": the next working out leaves it out again", facts[g3.word] == false, tostring(facts[g3.word]))
	Check("ns.factsEvery cleared after ns.RuleFactsAll", ns.factsEvery == nil)

	-- 7. The facts' stamp: a newly named word moving true moved it (rows read again).
	local gen = ns.factsGen
	ns.CompileRule(g3.word .. " or " .. g2.word)
	Check("a newly named word changing: the stamp moved", ns.factsGen ~= gen)
end

RunClient("forever", "CinematicDev.toc")
RunClient("retail", "CinematicDev.toc")
RunClient("forever", "Cinematic.toc")
-- luacheck: pop
print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
