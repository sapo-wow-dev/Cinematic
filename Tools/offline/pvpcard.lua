-- PvP combat card check (dev tool, offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/pvpcard.lua < /dev/null
-- Entering a PvP fight (Cards.lua's combatPvp, CombatVision.lua's FightCard):
-- as a fight starts, which card plays. On the stand-in game with made-up
-- units: on for a new install (off for players from before: pvpcardupdate.lua); with its row on, a fight against a mob keeps
-- Entering combat's card; an enemy player as target, as a plate whose target
-- is you, or a battleground / arena plays the PvP card with its own words; a
-- friendly player, a secret GUID with UnitIsPlayer false, or the row off: the
-- usual card. Its look follows Entering combat's until it has its own. Says
-- PASS or FAIL per check.
-- (Optional first argument: another .toc to load, to run it on older code.)
local now = 100
local units = {}       -- unit -> { guid, player, enemy, targetsMe, secretGuid }
local instance = { false, "none" }

-- luacheck: push ignore 111 112 113 121 122 212
local ns = dofile("Tools/offline/load.lua")("forever", arg and arg[1], function()
	GetTime = function() return now end
	C_Timer.After = function() end
	issecretvalue = function(v) return type(v) == "table" and v.secret == true end
	IsInInstance = function() return instance[1], instance[2] end
	UnitExists = function(unit)
		local base = unit:match("^(.-)target$")
		if base and base ~= "" then return units[base] and units[base].targetsMe and true or false end
		return units[unit] ~= nil
	end
	UnitGUID = function(unit)
		local u = units[unit]
		if not u then return nil end
		if u.secretGuid then return { secret = true } end
		return u.guid
	end
	UnitIsPlayer = function(unit) return units[unit] and units[unit].player or false end
	UnitCanAttack = function(_, unit) return units[unit] and units[unit].enemy or false end
	UnitIsUnit = function(a, b)
		local base = a:match("^(.-)target$")
		return b == "player" and base ~= nil and units[base] ~= nil and units[base].targetsMe == true
	end
end)
-- luacheck: pop

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

-- Which card the fight's start fires (and its words), caught at Fire.
local fired
local Fire = ns.Cards.Fire
ns.Cards.Fire = function(id, card, ...)
	if id == "combatIn" or id == "combatPvp" then fired = { id = id, name = card and card.name } end
	return Fire(id, card, ...)
end
local function Start()
	fired = nil
	ns.CardFightCard(true)
	return fired and fired.id, fired and fired.name
end
local function Reset()
	for k in pairs(units) do units[k] = nil end
	instance[1], instance[2] = false, "none"
end

Check("on by default", ns.DEFAULTS.cardCombatPvpOn == true)
Check("a new install has it on", ns.db.cardCombatPvpOn == true, tostring(ns.db.cardCombatPvpOn))
Check("its words have a default", ns.DEFAULTS.combatTextPvp == "Rival")
local listed = false
for _, event in ipairs(ns.CardEventsGrouped()) do
	if event.id == "combatPvp" then listed = event.group == "Combat" end
end
Check("on the Events tab, in the Combat group", listed)
Check("its look follows Entering combat's", ns.CardBase("combatPvp") == ns.CardBase("combatIn"),
	ns.CardBase("combatPvp") .. " vs " .. ns.CardBase("combatIn"))
Check("...its bar fallback too", ns.CardValue("combatPvp", "BarFallback") == ns.CardValue("combatIn", "BarFallback"),
	tostring(ns.CardValue("combatPvp", "BarFallback")))

ns.db.cards = true
ns.db.combatOnEnter = true

-- Row off: an enemy player still gets the usual card.
ns.db.cardCombatPvpOn = false
Reset()
units.target = { guid = "Player-1-0001", player = true, enemy = true }
Check("row off: enemy player -> Entering combat", Start() == "combatIn", fired and fired.id)

ns.db.cardCombatPvpOn = true

Reset()
units.target = { guid = "Creature-0-1-2-3-4-5", player = false, enemy = true }
Check("a mob -> Entering combat", Start() == "combatIn", fired and fired.id)

Reset()
units.target = { guid = "Player-1-0001", player = true, enemy = true }
local id, words = Start()
Check("enemy player targeted -> PvP card", id == "combatPvp", id)
Check("...with its own words", words == "Rival", words)

ns.db.combatTextPvp = "LET'S ROCK!"
Check("...words you set", select(2, Start()) == "LET'S ROCK!", fired and fired.name)
ns.db.combatTextPvp = "Rival"

Reset()
units.target = { guid = "Player-1-0002", player = true, enemy = false }
Check("friendly player -> Entering combat", Start() == "combatIn", fired and fired.id)

Reset()
units.target = { guid = "Player-1-0003", player = false, enemy = true }
Check("Forever's UnitIsPlayer false, GUID says player -> PvP card", Start() == "combatPvp", fired and fired.id)

Reset()
units.target = { secretGuid = true, player = false, enemy = true }
Check("secret GUID, UnitIsPlayer false -> Entering combat", Start() == "combatIn", fired and fired.id)

Reset()
units.target = { secretGuid = true, player = true, enemy = true }
Check("secret GUID, UnitIsPlayer true -> PvP card", Start() == "combatPvp", fired and fired.id)

Reset()
units.nameplate7 = { guid = "Player-1-0004", player = true, enemy = true, targetsMe = true }
Check("enemy player plate targeting you -> PvP card", Start() == "combatPvp", fired and fired.id)

Reset()
units.nameplate7 = { guid = "Player-1-0004", player = true, enemy = true, targetsMe = false }
Check("enemy player plate not on you -> Entering combat", Start() == "combatIn", fired and fired.id)

Reset()
instance[1], instance[2] = true, "pvp"
Check("in a battleground -> PvP card", Start() == "combatPvp", fired and fired.id)

Reset()
instance[1], instance[2] = true, "arena"
Check("in an arena -> PvP card", Start() == "combatPvp", fired and fired.id)

Reset()
instance[1], instance[2] = true, "party"
Check("in a dungeon, no player -> Entering combat", Start() == "combatIn", fired and fired.id)

-- Its Show in row saying no: the usual card.
Reset()
units.target = { guid = "Player-1-0001", player = true, enemy = true }
local RowOnNow = ns.RowOnNow
ns.RowOnNow = function(row, ...)
	if row == "card:combatPvp" then return false end
	return RowOnNow(row, ...)
end
Check("its Show in row says no -> Entering combat", Start() == "combatIn", fired and fired.id)
ns.RowOnNow = RowOnNow

print(fails == 0 and "ALL PASS" or (fails .. " FAIL"))
os.exit(fails == 0 and 0 or 1)
