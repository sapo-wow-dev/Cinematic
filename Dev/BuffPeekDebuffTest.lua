-- /cine debug peekdebuffs: buff and debuff peeks, on the test kit. In
-- CineMode (turned on for the run if off, off again after). Steps:
--   1 buff       a buff peek leaves the debuffs faded (a player's rested XP
--                debuff, moved to the middle of the screen, came up with
--                every kill's buff)
--   2 debuff     a debuff peek brings the debuffs up
--   3 hold       "Keep them up until the debuff is gone": a debuff (a stand-in
--                answer, ns.debuffHoldTestHas) keeps them up past the peek's
--                time, and they fade once it's gone (ns.RecheckDebuffHold)
--   4 real       the same with a real debuff, a fight too: up while you have
--                it, faded once it's gone and the fight is over (the fight's
--                end checks again: an ignored or long debuff left on you held
--                them up after a fight until some aura next changed)
-- Log: CinematicDB.peekDebuffTestLog. Dev copy only (CinematicDev.toc).
local _, ns = ...

local function AlphaOf(name)
	for _, entry in ipairs(ns.managed or {}) do
		if entry.name == name then return type(entry.alpha) == "number" and entry.alpha or 0, true end
	end
	return 0, false
end

local function Fighting()
	return InCombatLockdown() or ns.Flag(UnitAffectingCombat("player"))
end

local function State()
	local buff = AlphaOf("BuffFrame")
	local debuff, managed = AlphaOf("DebuffFrame")
	return ("BuffFrame %.2f, DebuffFrame %.2f%s, held %s, debuffs %s, icons %s, fight %s, CineMode %s"):format(
		buff, debuff, managed and "" or " (not managed)", tostring(ns.DebuffHeld and ns.DebuffHeld()),
		tostring(ns.DebuffCount()), tostring(ns.DebuffIconCount()), tostring(Fighting()), tostring(ns.lastCinematic))
end

-- Waits for the buffs and debuffs to fade (15 sec at most).
local function Settle(r)
	local until_ = GetTime() + 15
	r:WaitFor("Hands off: waiting for the buffs and debuffs to fade (keep the mouse off them)", { handsOff = true,
		check = function()
			return (GetTime() > until_ or (AlphaOf("BuffFrame") < 0.02 and AlphaOf("DebuffFrame") < 0.02)) and true
		end })
	r:Log("settled: " .. State())
end

-- Records the highest alphas for seconds, logging each change of state.
local function Record(r, seconds)
	local maxBuff, maxDebuff, last = 0, 0, nil
	local stop = GetTime() + seconds
	while GetTime() < stop do
		-- (Parenthesized: AlphaOf's second value would go to max too.)
		maxBuff, maxDebuff = math.max(maxBuff, (AlphaOf("BuffFrame"))), math.max(maxDebuff, (AlphaOf("DebuffFrame")))
		local line = State()
		if line ~= last then last = line; r:Log(line) end
		r:Sleep(0.2)
	end
	return maxBuff, maxDebuff
end

local function DebuffShot(r, label)
	r:Shot(label, _G.DebuffFrame and { behind = _G.DebuffFrame } or nil)
end

ns.TestKit.Define({
	name = "peekdebuffs",
	key = "peekDebuffTest",
	cineMode = true,
	title = "Buff and debuff peeks",
	about = "a buff peek leaves the debuffs faded, a debuff peek brings them, and Keep them up until the debuff is gone",
	needs = "Step 4: a mob that puts a debuff on you (or any debuff you can get)",
	settings = { "handleFrames", "handleBuffs", "buffPeek", "debuffPeek", "buffPeekAfterCombat",
		"debuffPeekAfterCombat", "debuffPeekUntilGone" },
	context = function()
		return ("DebuffFrame managed %s, ignore list '%s', not long ones %s (%s min)"):format(
			tostring(select(2, AlphaOf("DebuffFrame"))), tostring(ns.db.buffPeekIgnore or ""),
			tostring(ns.db.buffPeekIgnoreLong), tostring(ns.db.buffPeekLongMinutes))
	end,
	putBack = function(extra)
		ns.debuffHoldTestHas = nil
		if ns.RecheckDebuffHold then ns.RecheckDebuffHold() end
		if extra.cineOff == "true" and ns.IsCineModeOn and ns.IsCineModeOn() and Cinematic_ToggleCineMode then
			Cinematic_ToggleCineMode()
			return "stand-in debuff answer cleared, CineMode turned off again"
		end
		return "stand-in debuff answer cleared"
	end,
	setup = function(r)
		for key, value in pairs({ handleFrames = true, handleBuffs = true, buffPeek = true, debuffPeek = true,
			buffPeekAfterCombat = false, debuffPeekAfterCombat = false, debuffPeekUntilGone = false }) do
			r:Set(key, value)
		end
		if ns.IsCineModeOn and not ns.IsCineModeOn() and Cinematic_ToggleCineMode then
			r:Keep("cineOff", "true")
			Cinematic_ToggleCineMode()
			r:Log("CineMode turned on for the run (put back at the end)")
		end
	end,
	steps = {
		{ key = "buff", title = "a buff peek leaves the debuffs faded",
			proven = "peekdebuffs run q7138 (2026-11-26, Forever): buffs 1.00, debuffs 0.00",
			run = function(r)
			if not select(2, AlphaOf("DebuffFrame")) then
				r:Skip("DebuffFrame isn't one of the faded frames on this client")
				return
			end
			Settle(r)
			r:Prompt("Hands off: BUFF PEEK, only your buffs should come up", nil, 5, nil, true)
			ns.StartBuffPeek(4, {})
			local buff, debuff = Record(r, 5)
			r:Verdict(buff > 0.5 and debuff < 0.05, ("buffs up to %.2f, debuffs up to %.2f"):format(buff, debuff))
		end },
		{ key = "debuff", title = "a debuff peek brings the debuffs up",
			proven = "peekdebuffs run q7138 (2026-11-26, Forever): debuffs 1.00",
			run = function(r)
			Settle(r)
			r:Prompt("Hands off: DEBUFF PEEK, your debuffs should come up", nil, 5, nil, true)
			ns.StartDebuffPeek(4)
			local _, debuff = Record(r, 5)
			r:Verdict(debuff > 0.5, ("debuffs up to %.2f"):format(debuff))
		end },
		{ key = "hold", title = "until the debuff is gone (stand-in debuff)", run = function(r)
			if not (ns.DebuffHeld and ns.RecheckDebuffHold) then
				r:Fail("Frames.lua has no ns.DebuffHeld / ns.RecheckDebuffHold")
				return
			end
			r:Set("debuffPeekUntilGone", true)
			Settle(r)
			r:Prompt("Hands off: a stand-in debuff with a 1 sec peek, held till it's gone", nil, 10, nil, true)
			ns.debuffHoldTestHas = true
			ns.StartDebuffPeek(1)
			r:Verdict(ns.DebuffHeld(), "the peek started the hold")
			-- (Past the peek's 1 sec: still up, held by the debuff.)
			local _, debuff = Record(r, 4)
			r:Verdict(ns.DebuffHeld() and AlphaOf("DebuffFrame") > 0.5,
				("3 sec past the peek's time: held %s, debuffs at %.2f (up to %.2f)"):format(
				tostring(ns.DebuffHeld()), AlphaOf("DebuffFrame"), debuff))
			DebuffShot(r, "held past the peek's time")
			-- (Gone: the next aura change lets go.)
			ns.debuffHoldTestHas = false
			ns.RecheckDebuffHold()
			r:Verdict(not ns.DebuffHeld(), "the debuff gone: hold let go")
			Record(r, 1)
			local faded = GetTime() + 10
			r:WaitFor(nil, { handsOff = true, check = function()
				return (AlphaOf("DebuffFrame") < 0.05 or GetTime() > faded) and true
			end })
			r:Verdict(AlphaOf("DebuffFrame") < 0.05, ("debuffs faded after: %.2f"):format(AlphaOf("DebuffFrame")))
			ns.debuffHoldTestHas = nil
		end },
		{ key = "real", title = "until the debuff is gone (a real one, a fight)",
			proven = "peekdebuffs run q7138 (2026-11-26, Forever): held through a fight and after, faded once gone",
			run = function(r)
			r:Set("debuffPeekUntilGone", true)
			ns.debuffHoldTestHas = nil
			ns.RecheckDebuffHold()
			Settle(r)
			-- (The one real action: a debuff on you; a mob's brings a fight too.)
			r:WaitFor("Get a debuff on you (a mob that puts one on you), then let it run out. "
				.. "The test follows on its own", { check = function() return ns.DebuffHeld() end })
			r:Log("held: " .. State())
			local sawFight, upOutOfFight, last = false, 0, nil
			local goneAt -- (when the debuffs and the fight were both over)
			local stop = GetTime() + 600
			r:Prompt("Hands off now: let the debuff run out (the fight too)", "up to 10 minutes", nil, nil, true)
			while GetTime() < stop do
				local line = State()
				if line ~= last then last = line; r:Log(line) end
				local fight, count = Fighting(), ns.DebuffCount()
				sawFight = sawFight or fight
				if not fight and ns.DebuffHeld() then
					upOutOfFight = math.max(upOutOfFight, (AlphaOf("DebuffFrame")))
				end
				-- (Over: out of the fight, and the debuffs gone, or left with ones
				-- that don't count: the hold must have let go 3 sec on.)
				if not fight and (count == 0 or not ns.DebuffHeld()) then
					goneAt = goneAt or GetTime()
					if GetTime() - goneAt > 3 then break end
				else
					goneAt = nil
				end
				r:Sleep(0.2)
			end
			r:Log("after: " .. State())
			r:Verdict(goneAt ~= nil and not ns.DebuffHeld(), ("hold let go once the debuff and fight were over " ..
				"(fight seen %s, debuffs left %s)"):format(tostring(sawFight), tostring(ns.DebuffCount())))
			if upOutOfFight > 0 then
				r:Verdict(upOutOfFight > 0.5, ("held out of a fight: debuffs up to %.2f"):format(upOutOfFight))
			else
				r:Log("never held out of a fight with the debuff on: the up check needs a debuff that outlasts the fight")
			end
			local faded = GetTime() + 10
			r:WaitFor(nil, { handsOff = true, check = function()
				return (AlphaOf("DebuffFrame") < 0.05 or GetTime() > faded) and true
			end })
			r:Verdict(AlphaOf("DebuffFrame") < 0.05, ("debuffs faded after: %.2f"):format(AlphaOf("DebuffFrame")))
			DebuffShot(r, "after the debuff and the fight")
		end },
	},
})
