-- Smart Style's Out of range Distance with a spell that has a least range
-- (a warrior's Charge, 8-25) on the bars: within 8 yards Charge says "not in
-- range", which read as far away and faded the plate (2026-11-24). Its most
-- range counts: out of fights the ~11-yard interact distance tells too close
-- from too far; in a fight the next spell (Heroic Strike, melee) answers.
--   python -I Tools/offline/run.py Tools/offline/minrangefar.lua [forever|retail] < /dev/null
-- luacheck: ignore 111 112 113 121 122

local client = arg and arg[1] or "forever"
local CHARGE, STRIKE = 100, 78
local state = { yards = 3, fight = false, bars = { CHARGE, STRIKE } }
local RANGES = { [CHARGE] = { 8, 25 }, [STRIKE] = { 0, 0 } }

local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function()
	C_Spell = C_Spell or {}
	C_Spell.GetSpellInfo = function(id)
		local r = RANGES[id]
		return r and { name = tostring(id), minRange = r[1], maxRange = r[2] }
	end
	C_Spell.IsSpellHarmful = function(id) return RANGES[id] ~= nil end
	C_Spell.IsSpellHelpful = function() return false end
	C_Spell.IsSpellInRange = function(id)
		local r = RANGES[id]
		if not r then return nil end
		local most = r[2] == 0 and 5 or r[2]
		return state.yards >= r[1] and state.yards <= most
	end
	GetActionInfo = function(slot)
		local id = state.bars[slot]
		if id then return "spell", id end
	end
	CheckInteractDistance = function(_, index)
		local yards = ({ [1] = 28, [2] = 11, [3] = 10, [4] = 28 })[index]
		return state.yards <= yards
	end
	InCombatLockdown = function() return state.fight end
end)

local failed = 0
local function Check(label, ok, got)
	print((ok and "ok   " or "FAIL ") .. label .. (ok and "" or ("  (got " .. tostring(got) .. ")")))
	if not ok then failed = failed + 1 end
end
local function Far(yards, fight)
	state.yards, state.fight = yards, fight
	return ns.UnitInBand("target", "OutOfRange")
end

Check("1 out of fight, 3 yd: in range", Far(3, false) == false, Far(3, false))
Check("2 out of fight, 6 yd (inside Charge's least): in range", Far(6, false) == false, Far(6, false))
Check("3 out of fight, 10 yd: in range", Far(10, false) == false, Far(10, false))
Check("4 out of fight, 20 yd: in range", Far(20, false) == false, Far(20, false))
Check("5 out of fight, 27 yd: out of range", Far(27, false) == true, Far(27, false))
Check("6 out of fight, 40 yd: out of range", Far(40, false) == true, Far(40, false))
Check("7 fight, 3 yd: in range (Heroic Strike)", Far(3, true) == false, Far(3, true))
Check("8 fight, 20 yd: in range", Far(20, true) == false, Far(20, true))
Check("9 fight, 40 yd: out of range", Far(40, true) == true, Far(40, true))
-- (In a fight 5-8 yards can't be told from past 25: Charge and Heroic Strike
-- both say no, so it reads as far. Pinned so a change shows.)
Check("10 fight, 6 yd: reads far (known gap)", Far(6, true) == true, Far(6, true))

-- Charge alone on the bars.
state.bars = { CHARGE }
local wait = GetTime
GetTime = function() return 100 end -- (look at the bars again)
Check("11 Charge alone, out of fight, 3 yd: in range", Far(3, false) == false, Far(3, false))
Check("12 Charge alone, out of fight, 40 yd: out of range", Far(40, false) == true, Far(40, false))
Check("13 Charge alone, fight, 3 yd: can't say", Far(3, true) == nil, Far(3, true))
GetTime = wait

print(failed == 0 and "minrangefar: all passed" or ("minrangefar: " .. failed .. " failed"))
if failed > 0 then os.exit(1) end
