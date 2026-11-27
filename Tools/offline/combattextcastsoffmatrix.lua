-- Combat Text Style's Spells tab: casts made while our numbers are off (the
-- audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-25-combat-text-casts-off.md):
--   python -I Tools/offline/run.py Tools/offline/combattextcastsoffmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/combattextcastsoffmatrix.lua forever --base <ref>
-- A Shadow Bolt (2.5 s cast) whose hit was taken once before or never; then
-- our numbers off by the page, its General tab, the numbers switch, Forever
-- Combat Text loaded, or not off at all; 0, 1 or 2 bolts cast with no hit
-- taken (each waits out its 2.5 s); then all on again and either a new bolt
-- cast and its hit, or a hit with no new cast (one bolt cast just before
-- turning on, still in flight).
-- Each cell: the spell the hit took (its look) and its cast time (its size).
-- The rule (2026-11-25): a cast made while our numbers are off isn't kept or
-- counted at all; turning them on starts clean. Two casts with no hit while
-- ON is a spell that never hits on its own (a DoT): its casts wait for none.
local client = arg and arg[1] or "forever"
local now = 100
local NAMES = { [686] = "Shadow Bolt" }
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function()
	-- luacheck: push ignore 111 112 113 121 122
	GetTime = function() return now end
	issecretvalue = function() return false end
	C_Spell = C_Spell or {}
	C_Spell.GetSpellName = function(id) return NAMES[id] end
	C_Spell.GetSpellTexture = function(id) return 1000 + id end
	C_Spell.IsSpellHarmful = function(id) return NAMES[id] ~= nil end
	C_Spell.IsSpellHelpful = function() return false end
	C_Spell.GetSpellDescription = function() return "Sends a shadowy bolt at the enemy, causing 13 Shadow damage." end
	STRING_SCHOOL_FIRE, STRING_SCHOOL_SHADOW, STRING_SCHOOL_HOLY = "Fire", "Shadow", "Holy"
	STRING_SCHOOL_NATURE, STRING_SCHOOL_FROST, STRING_SCHOOL_ARCANE = "Nature", "Frost", "Arcane"
	UnitGUID = function(unit) if unit == "target" then return "Creature-1" end end
	C_Timer.After = function(_, fn) fn() end
	-- luacheck: pop
end)
local M = ns.CombatTextSpellMatch
local TAB = "tabOn:Combat Text Style/page:1"

local function AllOn()
	ns.db.styleGeneral, ns.db.combatTextStyle, ns.db.combatTextNumbers = true, true, true
	ns.db[TAB] = nil
	ns.combatTextBlocked = nil
end
local function TurnOff(by)
	if by == "page" then ns.db.combatTextStyle = false
	elseif by == "tab" then ns.db[TAB] = false
	elseif by == "numbers" then ns.db.combatTextNumbers = false
	elseif by == "blocked" then ns.combatTextBlocked = "ForeverCombatText" end
end
local function Cast()
	M.OnCast(nil, "UNIT_SPELLCAST_START", "player", "guid", 686)
	now = now + 2.5
	M.OnCast(nil, "UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 686)
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "combat-text-casts-off",
	fixed = { client = client },
	dims = {
		{ "learned", { "no", "yes" } },
		{ "off", { "none", "page", "tab", "numbers", "blocked" } },
		{ "offCasts", { 0, 1, 2 } },
		{ "then", { "cast", "hit" } },
	},
	cell = function(c)
		M.Reset()
		now = now + 100
		AllOn()
		if c.learned == "yes" then
			Cast()
			now = now + 0.5
			M.TakeCast(32, now, false)
			now = now + 5
		end
		TurnOff(c.off)
		for _ = 1, c.offCasts do
			Cast()
			now = now + 3 -- (its 2.5 s wait over, no hit taken)
		end
		if c["then"] == "hit" then Cast() end
		AllOn()
		if c["then"] == "cast" then Cast() end
		now = now + 0.5
		local secs, from = M.TakeCast(32, now, false)
		return ("spell=%s secs=%s"):format(from and from.name or "none", secs and ("%.1f"):format(secs) or "none")
	end,
	pins = {
		-- (On the whole time: what was. A bolt's hit takes its cast.)
		{ "", "spell=Shadow Bolt secs=2.5" },
		-- (Two casts with no hit while ON, never hit before: a spell that never
		-- hits (a DoT's): its next cast waits for none.)
		{ "learned=no off=none offCasts=2", "spell=none secs=none" },
		-- (A cast made while off isn't kept: a hit just after turning on, with
		-- no cast since, isn't its.)
		{ "off=page then=hit", "spell=none secs=none" },
		{ "off=tab then=hit", "spell=none secs=none" },
		{ "off=numbers then=hit", "spell=none secs=none" },
		{ "off=blocked then=hit", "spell=none secs=none" },
	},
})
