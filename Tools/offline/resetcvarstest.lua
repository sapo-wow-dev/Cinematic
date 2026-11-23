-- /cine debug resetcvars (Dev/ResetCvarsTest.lua) on the stand-in game,
-- through both reloads (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/resetcvarstest.lua [forever|retail] < /dev/null
-- Each reload is a fresh load of the addon keeping the saved tables
-- (CinematicDB, CinematicCharDB) and the game's settings, as the game does.
-- Checks the test's own verdicts all pass, that your setup comes back (a
-- profile and a setting of yours made before it), and that the copy is gone.
-- PASS or FAIL per check.
-- luacheck: ignore 111 112 113 121 122 212 431

local client = arg and arg[1] or "forever"
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

local cvars = { floatingCombatTextCombatDamage_v2 = "1", floatingCombatTextCombatDamage = "1",
	enableFloatingCombatText = "1", floatingCombatTextCombatHealing_v2 = "1", Sound_MusicVolume = "1",
	Sound_EnableMusic = "1" }
local now, timers, tickers = 100, {}, {}
local cine = false
local savedDB, savedChar

local function Load()
	local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function()
		-- luacheck: push ignore 111 112 113 121 122
		CinematicDB, CinematicCharDB = savedDB, savedChar
		C_CVar = {
			SetCVar = function(name, value) if cvars[name] ~= nil then cvars[name] = tostring(value) end end,
			GetCVar = function(name) return cvars[name] end,
		}
		SetCVar = function(name, value) return C_CVar.SetCVar(name, value) end
		GetCVar = function(name) return cvars[name] end
		GetTime = function() return now end
		C_Timer.After = function(delay, fn) timers[#timers + 1] = { at = now + delay, fn = fn } end
		C_Timer.NewTicker = function(every, fn)
			local t = { every = every, next = now + every, fn = fn, Cancel = function(self) self.cancelled = true end }
			tickers[#tickers + 1] = t
			return t
		end
		Screenshot = function() end
		Cinematic_ToggleCineMode = function() cine = not cine end
		-- luacheck: pop
	end)
	ns.IsCineModeOn = function() return cine end
	ns.PadTestBox = function() end
	ns.PadTestBoxHide = function() end
	return ns, wow
end
local function Advance(seconds)
	local stop = now + seconds
	while now < stop do
		now = now + 0.1
		local due = {}
		for i = #timers, 1, -1 do
			if timers[i].at <= now then due[#due + 1] = table.remove(timers, i) end
		end
		for i = #due, 1, -1 do pcall(due[i].fn) end
		for _, t in ipairs(tickers) do
			if not t.cancelled and t.next <= now then
				t.next = now + t.every
				pcall(t.fn, t)
			end
		end
	end
end
local function CineSet(ns)
	for _, set in ipairs(ns.cvarSets) do
		if set.label == "Combat text off" then return set end
	end
end
-- The Reload button's click: the rest kept, then a fresh load and login.
local function Reload(ns, wow)
	local run = ns.TestKit.Running()
	if run then
		run:SaveResume()
		run.stopped = true
	end
	wow.Fire("PLAYER_LOGOUT")
	savedDB, savedChar = CinematicDB, CinematicCharDB
	timers, tickers = {}, {}
	cine = false
	local ns2, wow2 = Load()
	wow2.Fire("PLAYER_ENTERING_WORLD", false, true)
	return ns2, wow2
end

-- A setup of yours first: your own profile, one setting of yours in it.
local ns, wow = Load()
ns.db.mineMark = "yours"
local profile = ns.ActiveProfile()
local profiles = 0
for _ in pairs(CinematicDB.profiles or {}) do profiles = profiles + 1 end

ns.HandleSlash("debug resetcvars full")
Advance(1)
-- Step 1 waits for CineMode: on, its set holding Damage numbers (the stand-in
-- has no CineMode loop: its set taken by hand, as CineMode's would).
cine = true
ns.ApplyCVarSet(CineSet(ns), true)
ns.RefreshCombatTextStyle()
Advance(3)
local log = CinematicDB.resetCvarsTestLog
Check("step 1: both hold", Has(log, "verdict PASS .*both hold Damage numbers") ~= nil, Has(log, "both hold"))
Check("step 2: the reset ran", Has(log, "verdict PASS .*Reset Settings ran") ~= nil, Has(log, "Reset Settings ran"))
Check("step 2: yours right after", Has(log, "verdict FAIL .*right after the reset") == nil, Has(log, "right after"))
Check("step 2: every set let go", Has(log, "verdict PASS .*every set let go") ~= nil, Has(log, "every set let go"))
Check("step 2: nothing saved", Has(log, "verdict PASS .*nothing of yours left saved") ~= nil, Has(log, "left saved"))
Check("step 2: your copy rides in what the reset kept", type(CinematicDB.resetCvarsTestBackup) == "table")
Check("step 2: the kept table isn't yours yet", CinematicDB.mineMark == nil, CinematicDB.mineMark)

-- Reload 1: Cinematic as the reset left it.
ns, wow = Reload(ns, wow)
Advance(4)
log = CinematicDB.resetCvarsTestLog
Check("step 3: picked up after the reload", Has(log, "after the reload: picked up") ~= nil)
Check("step 3: Damage numbers yours", Has(log, "verdict FAIL .*after the reload: yours") == nil
	and Has(log, "verdict PASS .*after the reload: yours") ~= nil, Has(log, "after the reload: yours"))
Check("step 3: copy put back", Has(log, "verdict PASS .*your saved settings copy put back") ~= nil)
Check("step 3: the saved settings are yours again", CinematicDB.mineMark == "yours", CinematicDB.mineMark)

-- Reload 2: your setup.
ns = Reload(ns, wow)
Advance(10)
log = CinematicDB.resetCvarsTestLog
local done = Has(log, "DONE: ")
Check("finished DONE, no FAIL", done ~= nil and done:find(" 0 fail", 1, true) ~= nil, done)
Check("your setting back", ns.db.mineMark == "yours", ns.db.mineMark)
Check("your profile back", ns.ActiveProfile() == profile, ns.ActiveProfile())
Check("no copy left", CinematicDB.resetCvarsTestBackup == nil)
Check("the run's settings put back", ns.db.combatTextStyle == false or ns.db.combatTextStyle == nil,
	tostring(ns.db.combatTextStyle))
Check("undo cleared", CinematicDB.resetCvarsTestUndo == nil)
for _, line in ipairs(log or {}) do
	if line:find("FAIL") or line:find("DONE") or line:find("game settings yours") then print("  log: " .. line) end
end
print(fails == 0 and "all passed" or (fails .. " FAILED"))
