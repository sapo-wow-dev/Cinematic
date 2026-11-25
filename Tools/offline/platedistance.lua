-- Smart rows within / past any yards (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/platedistance.lua < /dev/null
-- Tools/plate-distance-plan.md. On a stand-in game (Forever, then retail):
-- Core's row ids (In<N>y / Past<N>y with Whos and copy numbers, the old
-- fixed ones unchanged, out-of-range yards refused), ns.MarkDistanceYards,
-- a row setting's default for a y id, and Frames' ns.UnitWithinYards: the
-- ring nearest X answers (a tie: the nearer one), Past is its opposite, an
-- attack can't say for a friend so the next ring does, interact rings not
-- asked in retail fights (rule retail.checkinteractdistance.blocked-in-combat)
-- but asked in Forever ones (rule forever.range.plates-in-combat), one call
-- per plate and ring per pass, and ns.YardsRingInfo for the page. The old
-- fixed bands still go their own way. PASS or FAIL per check.
-- luacheck: push ignore 111 112 113 121 122 212 431
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

-- A stand-in world: units at yards from you, enemy or friend; spells with ranges.
local SPELLS = {
	[101] = { name = "Bolt", max = 30, harmful = true },
	[102] = { name = "Shock", max = 20, harmful = true },
	[103] = { name = "Charge", min = 8, max = 25, harmful = true }, -- (a least range: never a ring)
	[201] = { name = "Heal", max = 40, helpful = true },
}

local function RunClient(client, toc)
	print("== " .. client .. " " .. toc)
	local now, fight = 100, false
	local units = { nameplate1 = { yards = 15, enemy = true }, nameplate2 = { yards = 35, enemy = true },
		nameplate3 = { yards = 12, enemy = false } }
	local calls = { interact = 0, spell = 0 }
	-- (The game stand-ins before the files load: Frames keeps C_Spell's
	-- harmful / helpful tests from load time.)
	local ns = dofile("Tools/offline/load.lua")(client, toc, function()
		GetTime = function() return now end
		InCombatLockdown = function() return fight end
		CheckInteractDistance = function(unit, index)
			calls.interact = calls.interact + 1
			local u = units[unit]
			if not u then return nil end
			return u.yards <= (index == 4 and 28 or 11)
		end
		GetActionInfo = function(slot)
			local ids = { 101, 102, 103, 201 }
			if ids[slot] then return "spell", ids[slot] end
		end
		C_SpellBook = nil
		C_Spell = C_Spell or {}
		C_Spell.GetSpellInfo = function(id)
			local s = SPELLS[id]
			return s and { name = s.name, minRange = s.min or 0, maxRange = s.max }
		end
		C_Spell.GetSpellName = function(id) return SPELLS[id] and SPELLS[id].name end
		C_Spell.IsSpellHarmful = function(id) return SPELLS[id] and SPELLS[id].harmful or false end
		C_Spell.IsSpellHelpful = function(id) return SPELLS[id] and SPELLS[id].helpful or false end
		C_Spell.IsSpellInRange = function(id, unit)
			calls.spell = calls.spell + 1
			local s, u = SPELLS[id], units[unit]
			if not (s and u) then return nil end
			if s.harmful and not u.enemy or s.helpful and u.enemy then return nil end
			return u.yards <= s.max
		end
	end)
	ns.IsEnemyUnit = function(unit) return units[unit] and units[unit].enemy end

	-- Row ids --------------------------------------------------------------
	local function Split(id) return { ns.MarkRowBase(id) } end
	local s = Split("npcEnemyIn20y")
	Check("npcEnemyIn20y reads", s[1] == "npc" and s[2] == "Enemy" and s[3] == nil and s[4] == "In20y",
		table.concat({ tostring(s[1]), tostring(s[2]), tostring(s[3]), tostring(s[4]) }, ","))
	s = Split("allPast35y2")
	Check("allPast35y2: copy 2", s[1] == "all" and s[3] == 2 and s[4] == "Past35y", tostring(s[3]) .. " " .. tostring(s[4]))
	s = Split("npcEnemyIn282")
	Check("old npcEnemyIn282 still In28 copy 2", s[4] == "In28" and s[3] == 2, tostring(s[4]) .. " " .. tostring(s[3]))
	s = Split("allPast40")
	Check("old allPast40 unchanged", s[1] == "all" and s[4] == "Past40" and s[3] == nil)
	Check("In5y and In45y valid", ns.MarkRowValid("allIn5y") and ns.MarkRowValid("allIn45y"))
	Check("In4y, In46y, In020y refused", not ns.MarkRowValid("allIn4y") and not ns.MarkRowValid("allIn46y")
		and not ns.MarkRowValid("allIn020y"))
	local side, yards = ns.MarkDistanceYards("In20y")
	Check("MarkDistanceYards In20y", side == "In" and yards == 20)
	side, yards = ns.MarkDistanceYards("Past28")
	Check("MarkDistanceYards old Past28", side == "Past" and yards == 28)
	Check("MarkDistanceYards OutOfRange: none", ns.MarkDistanceYards("OutOfRange") == nil)
	Check("a y row's setting default is its kind's",
		ns.MarkRowDefault("npcEnemyIn20yMarkStyle") == ns.DEFAULTS.npcMarkStyle,
		tostring(ns.MarkRowDefault("npcEnemyIn20yMarkStyle")))

	-- Measuring ------------------------------------------------------------
	local function Within(unit, x, past)
		now = now + 1 -- (a new pass: no kept answers)
		return ns.UnitWithinYards(unit, x, past)
	end
	-- Your spells first, the one nearest X (20 Shock, 30 Bolt; Charge out),
	-- the same in fights and out; the interact distances (11, 28) only for a
	-- unit no spell can say for (2026-11-25, "the closest spell we can").
	Check("enemy at 15, within 20 (Shock) = true", Within("nameplate1", 20) == true)
	Check("enemy at 15, within 11: Shock 20, the nearest spell = true", Within("nameplate1", 11) == true)
	Check("enemy at 15, past 20 = false", Within("nameplate1", 20, true) == false)
	Check("enemy at 35, within 30 (Bolt) = false", Within("nameplate2", 30) == false)
	Check("enemy at 35, past 29 (Bolt 30) = true", Within("nameplate2", 29, true) == true)
	Check("enemy at 15, within 13: Shock 20 = true", Within("nameplate1", 13) == true)
	-- ~30, the page's one distance: Bolt, out of fights and in.
	units.nameplate5 = { yards = 29, enemy = true }
	Check("~30: enemy at 29 within (Bolt), not the 28 interact", Within("nameplate5", 30) == true)
	fight = true
	Check("~30 in a fight: the same answer", Within("nameplate5", 30) == true)
	fight = false
	-- (24: 20 and 28 are 4 off each: the nearer ring, 20.)
	Check("tie 24 -> 20: enemy at 15 within", Within("nameplate1", 24) == true)
	units.nameplate4 = { yards = 22, enemy = true }
	Check("tie 24 -> 20 not 28: enemy at 22 not within", Within("nameplate4", 24) == false)
	-- A friend: attacks can't say; Heal 40 and the interact rings do.
	Check("friend at 12, within 30: Heal 40, its only spell = true", Within("nameplate3", 30) == true)
	Check("friend at 12, within 40 (Heal) = true", Within("nameplate3", 40) == true)
	-- (No spell that can say: the interact distances, out of fights.)
	units.nameplate6 = { yards = 12, enemy = nil }
	Check("a unit no spell answers for, within 11 by the interact distance = false",
		Within("nameplate6", 11) == false)
	-- One call per unit and ring per pass.
	now = now + 1
	calls.interact, calls.spell = 0, 0
	for _ = 1, 10 do ns.UnitWithinYards("nameplate1", 20) end
	Check("ten rows, one pass: one call", calls.interact + calls.spell == 1, calls.interact .. "+" .. calls.spell)
	-- In a fight.
	fight = true
	calls.interact = 0
	local inFight = Within("nameplate1", 11)
	-- (No interact distance in fights on either client: Forever blocks it on
	-- some plates too, 36 blocked actions in one fight, 2026-11-25.)
	Check(client .. " fight: no interact asked", calls.interact == 0, calls.interact)
	Check(client .. " fight: 11 goes by Shock 20 (enemy at 15: within)", inFight == true, tostring(inFight))
	-- (A list made out of a fight, asked in one: still no interact.)
	fight = false
	now = now + 1
	ns.UnitWithinYards("nameplate1", 11)
	fight, calls.interact = true, 0
	now = now + 1
	ns.UnitWithinYards("nameplate1", 11)
	Check(client .. " fight: a ring list from before it still asks no interact", calls.interact == 0, calls.interact)
	fight = false
	-- The page's info.
	local calmY, calmName = ns.YardsRingInfo(24)
	Check("YardsRingInfo 24: 20 Shock", calmY == 20 and calmName == "Shock", tostring(calmY) .. " " .. tostring(calmName))
	local fightY
	calmY, _, fightY = ns.YardsRingInfo(12)
	Check("YardsRingInfo 12: Shock 20, in fights too", calmY == 20 and fightY == 20,
		tostring(calmY) .. " " .. tostring(fightY))
	local nearY, nearName, nearFightY = ns.YardsRingInfo(ns.NEAR_YARDS)
	Check("YardsRingInfo ~30: Bolt 30, in fights too", nearY == 30 and nearName == "Bolt" and nearFightY == 30,
		tostring(nearY) .. " " .. tostring(nearName) .. " " .. tostring(nearFightY))
	-- The old fixed bands, through UnitInBand.
	Check("UnitInBand In20y as UnitWithinYards", (now + 1) and ns.UnitInBand("nameplate1", "In20y") == true)
	Check("UnitInBand old In11 still interact 2", ns.UnitInBand("nameplate1", "In11") == false)
	Check("UnitInBand old Past28 still interact 4", ns.UnitInBand("nameplate2", "Past28") == true)

	-- Enemies within (the Nameplates page's NearbyEnemies row) ---------------
	Check("NearbyEnemies is a plate unit row", (function()
		for _, row in ipairs(ns.PLATE_UNIT_ROWS) do if row == "NearbyEnemies" then return true end end
	end)() == true)
	Check("fresh install: Always on, ~30 yards, no yards setting", ns.DEFAULTS.plateAlwaysNearbyEnemies == true
		and ns.NEAR_YARDS == 30 and ns.DEFAULTS.plateNearbyYards == nil)
	Check("fresh install: the migration left it alone", ns.db.plateAlwaysNearbyEnemies == nil
		or ns.db.plateAlwaysNearbyEnemies == true, tostring(ns.db.plateAlwaysNearbyEnemies))
	local old = { plateAlwaysEnemies = true, profiles = { A = { x = 1 }, B = { plateAlwaysNearbyEnemies = true } },
		profileResetPoints = { R = { settings = {} } } }
	ns.NearbyEnemiesOffForOld(old)
	Check("setups from before: off in the settings, a profile and a reset point",
		old.plateAlwaysNearbyEnemies == false and old.profiles.A.plateAlwaysNearbyEnemies == false
		and old.profileResetPoints.R.settings.plateAlwaysNearbyEnemies == false)
	Check("a profile that had it on keeps it", old.profiles.B.plateAlwaysNearbyEnemies == true)
	SetCVar("nameplateShowEnemies", "0")
	SetCVar("nameplateShowEnemyPlayers", "0")
	ns.EnablePlateRow("NearbyEnemies")
	-- (Recorded as the addon's own value: written now, or once a hold on it lets go.)
	local ours = (ns.chardb or ns.db).cvarsOurs or {}
	Check("its plates on in the game's options: enemies and enemy players",
		ours.nameplateShowEnemies == "1" and ours.nameplateShowEnemyPlayers == "1",
		tostring(ours.nameplateShowEnemies) .. " " .. tostring(ours.nameplateShowEnemyPlayers))
	Check("the page's settings switch knows it", ns.HasPlateSettings("NearbyEnemies") == true)

	-- Its plates fade in and out (ns.plates.NearUpdate), not pop -------------
	-- (A hostile NPC's plate; the plate itself not touched here: Reachable
	-- says no, so only its level is checked.)
	UnitIsFriend = function() return false end
	UnitIsPlayer = function() return false end
	UnitPlayerControlled = function() return false end
	UnitReaction = function() return 2 end
	UnitClassification = function() return "normal" end
	UnitGUID = function(unit) return "Creature-0-0-0-0-1-" .. tostring(unit) end
	local plate = { namePlateUnitToken = "nameplate1", UnitFrame = { unit = "nameplate1" } }
	C_NamePlate.GetNamePlates = function() return { plate } end
	local reachable = ns.Reachable
	ns.Reachable = function(f) return f ~= plate and reachable(f) end
	ns.db.handlePlates, ns.db.plateAlwaysNearbyEnemies = true, true
	ns.plates.nearYards = 20 -- (the test's own distance: Shock 20 tells 15 from 35)
	units.nameplate1 = { yards = 15, enemy = true }
	for _ = 1, 40 do now = now + 0.1 pcall(ns.UpdatePlates, true, 0.1) end -- (CineMode: the row's own level up)
	local Step = ns.plates.nearFrame:GetScript("OnUpdate")
	local function Run(seconds)
		for _ = 1, math.floor(seconds / 0.05 + 0.5) do now = now + 0.05 Step(ns.plates.nearFrame, 0.05) end
		return ns.plates.nearLevels.nameplate1 or 0
	end
	local first = Run(0.1)
	Check("within 20 yd: eased in, not at once", first > 0 and first < 1, ("%.2f after 0.1 s"):format(first))
	local full = Run(ns.db.fadeInTime + 1)
	Check("within 20 yd: fully up after the Fade in time", full == 1, ("%.2f"):format(full))
	units.nameplate1.yards = 35
	local going = Run(0.35)
	Check("walked past 20 yd: eased out, not at once", going > 0 and going < 1, ("%.2f after 0.35 s"):format(going))
	local gone = Run(ns.db.fadeOutTime + 1)
	Check("past 20 yd: gone after the Fade out time", gone == 0, ("%.2f"):format(gone))
	ns.plates.nearFrame:GetScript("OnEvent")(ns.plates.nearFrame, "NAME_PLATE_UNIT_REMOVED", "nameplate1")
	Check("a plate's unit leaving forgets its level", ns.plates.nearLevels.nameplate1 == nil)
	ns.Reachable = reachable
	ns.plates.nearYards = nil
end

RunClient("forever", "CinematicDev.toc")
RunClient("retail", "CinematicDev.toc")
print(fails == 0 and "all passed" or (fails .. " failed"))
-- luacheck: pop
