-- Reach fight test, offline (Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/reachfight.lua < /dev/null
-- /cine debug reachfight (Dev/ReachFightTest.lua) on a stand-in game with
-- pretend time and a pretend fight: a plain frame Cinematic fades, a
-- forbidden one, one that refuses GetParent only in fights, one with a secret
-- GetNumPoints in fights, a nameplate with its UnitFrame. Run 1: every step
-- runs, DONE with 0 fail, the refusal is counted in the fight and gone after.
-- Run 2, the nameplate's UnitFrame refusing too: the "nothing skipped"
-- verdict FAILs (it can't pass by accident). PASS or FAIL per check.
-- luacheck: push ignore 111 112 113 121 122 212 431
local SECRET = setmetatable({}, { __tostring = function() return "secret" end })
local fight = false
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end
local function Has(log, pattern)
	for _, line in ipairs(log or {}) do
		if line:find(pattern) then return line end
	end
end
-- (The check and its detail from one pattern: the line it found, or what it looked for.)
local function Line(name, log, pattern)
	local line = Has(log, pattern)
	Check(name, line ~= nil, line or ("no line like: " .. pattern))
end

local ns, wow = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc", function()
	issecretvalue = function(value) return value == SECRET end
	InCombatLockdown = function() return fight end
	debugprofilestop = function() return os.clock() * 1000 end
end)
local now = 100
local timers, tickers = {}, {}
GetTime = function() return now end
C_Timer.After = function(delay, fn) timers[#timers + 1] = { at = now + delay, fn = fn } end
C_Timer.NewTicker = function(every, fn)
	local t = { every = every, next = now + every, fn = fn, Cancel = function(self) self.cancelled = true end }
	tickers[#tickers + 1] = t
	return t
end
local function Advance(seconds)
	local stop = now + seconds
	while now < stop do
		now = now + 0.1
		local due = {}
		for i = #timers, 1, -1 do
			if timers[i].at <= now then due[#due + 1] = table.remove(timers, i) end
		end
		for i = #due, 1, -1 do due[i].fn() end
		for _, t in ipairs(tickers) do
			if not t.cancelled and t.next <= now then
				t.next = now + t.every
				t.fn(t)
			end
		end
	end
end
local cine = true
ns.IsCineModeOn = function() return cine end
Cinematic_ToggleCineMode = function() cine = not cine end
ns.PadTestBox = function() end
ns.PadTestBoxHide = function() end
Screenshot = function() end

-- The stand-in world.
local function Refuse() error("Attempt to access forbidden object from code tainted by an AddOn") end
local world = {}
local function Frame(forbidden)
	local f = CreateFrame("Frame", nil, UIParent)
	f.IsForbidden = function() return forbidden end
	world[#world + 1] = f
	return f
end
local faded = Frame(false)
Frame(true)
local shy = Frame(false)
shy.GetParent = function(self) if fight then Refuse() end return UIParent end
local secretPoints = Frame(false)
secretPoints.GetNumPoints = function() return fight and SECRET or 1 end
local plate = Frame(false)
plate.UnitFrame = Frame(false)
local plateRefuses = false
plate.UnitFrame.GetParent = function(self) if fight and plateRefuses then Refuse() end return plate end
EnumerateFrames = function(after)
	if after == nil then return world[1] end
	for i, f in ipairs(world) do if f == after then return world[i + 1] end end
end
C_NamePlate = C_NamePlate or {}
C_NamePlate.GetNamePlates = function() return { plate } end
ns.managed = ns.managed or {}
table.insert(ns.managed, { frame = faded, name = "StandInFaded", group = "test" })

local function Fight(on)
	fight = on
	wow.Fire(on and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED")
end
local function Run()
	ns.HandleSlash("debug reachfight")
	Advance(5)
	Fight(true)
	Advance(5)
	Fight(false)
	Advance(10)
	return CinematicDB.reachFightTestLog
end

-- Run 1: one object refuses in the fight, nothing we fade.
local log = Run()
local done = Has(log, "DONE: ")
Check("run 1 finished DONE with no fail", done and done:find(" 0 fail", 1, true) ~= nil, done)
Line("out of a fight: nothing refuses", log, "out of a fight: %d+ objects, 1 forbidden, 0 with a secret IsForbidden, 0 refuse")
Line("in the fight: the one refusal counted", log, "in the fight: %d+ objects, 1 forbidden, 0 with a secret IsForbidden, 1 refuse GetParent, ns.Reachable differs from a fresh probe on 0")
Line("in the fight: the secret count, and ns.NumPoints 0 for it", log, "GetNumPoints secret on 1, ns.NumPoints not 0 on 0")
Check("cost lines for both", Has(log, "cost out of a fight: ns.Reachable") ~= nil and Has(log, "cost in the fight: ns.Reachable") ~= nil)
Line("after the fight: refusals gone", log, "verdict PASS after: refusals gone after the fight: 0 still refuse")

-- Run 2: the nameplate's UnitFrame refuses too.
plateRefuses = true
log = Run()
local skipped = Has(log, "nothing Cinematic fades and no nameplate refuses")
Check("run 2: a refusing plate part FAILs the nothing-skipped verdict", skipped and skipped:find("FAIL", 1, true) ~= nil
	and skipped:find("1 plate parts", 1, true) ~= nil, skipped)
Line("run 2: the example says NAMEPLATE", log, "examples: .*NAMEPLATE")

-- Run 3: EllesmereUI installed but off. The setup step turns it on for this
-- character and waits for the Reload click; stopped there, it's turned off.
local enabled, disabled = {}, {}
C_AddOns = C_AddOns or {}
C_AddOns.GetNumAddOns = function() return 3 end
C_AddOns.GetAddOnInfo = function(i) return ({ "CinematicDev", "EllesmereUI", "EllesmereUIChat" })[i] end
C_AddOns.IsAddOnLoaded = function(name) return name == "CinematicDev" end
C_AddOns.EnableAddOn = function(name, character) enabled[#enabled + 1] = name .. (character and "@" .. character or "") end
C_AddOns.DisableAddOn = function(name, character) disabled[#disabled + 1] = name .. (character and "@" .. character or "") end
local saves = 0
C_AddOns.SaveAddOns = function() saves = saves + 1 end
C_AddOns.GetAddOnEnableState = function() return 2 end
UnitName = function() return "Tester" end
ns.HandleSlash("debug reachfight")
Advance(3)
log = CinematicDB.reachFightTestLog
Check("run 3: both EllesmereUI addons turned on", table.concat(enabled, ",") == "EllesmereUI,EllesmereUIChat", table.concat(enabled, ","))
Check("run 3: turned on with no character, then saved (rule forever.addons.enable-no-character)", saves == 1, saves)
Line("run 3: it asks for the Reload click", log, "asked: Click Reload%. EllesmereUI comes on")
Check("run 3: still waiting on step 1 (no fight yet)", Has(log, "step 2 before") == nil)
ns.HandleSlash("debug reachfight") -- (typed again: stops)
Advance(2)
Check("run 3: stopped, both turned off again (no character), and saved", table.concat(disabled, ",") == "EllesmereUI,EllesmereUIChat"
	and saves == 2, table.concat(disabled, ",") .. ", saves " .. saves)
Line("run 3: the put back line says so", CinematicDB.reachFightTestLog, "turned off again for this character: EllesmereUI, EllesmereUIChat")

-- Run 4: picked up after the Reload but EllesmereUIChat still not loaded:
-- the setup check FAILs (run 2 in game went on without it, unseen).
C_AddOns.GetAddOnInfo = function(i)
	if i == "EllesmereUIChat" then return "EllesmereUIChat", "EllesmereUIChat", "", false, "DISABLED" end
	return ({ "CinematicDev", "EllesmereUI", "EllesmereUIChat" })[i]
end
ns.HandleSlash("debug reachfight 2")
Advance(3)
local loaded = Has(CinematicDB.reachFightTestLog, "EllesmereUIChat loaded for the fight")
Check("run 4: not loaded after the Reload FAILs, with the game's reason", loaded and loaded:find("FAIL", 1, true) ~= nil
	and loaded:find("reason DISABLED", 1, true) ~= nil, loaded)
ns.HandleSlash("debug reachfight")
Advance(2)

-- luacheck: pop
print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
