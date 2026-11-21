-- The test kit (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/testkit.lua < /dev/null
-- Dev/TestKit.lua on a stand-in game (Forever, then retail), driven through
-- /cine debug kitcheck (Dev/KitCheckTest.lua) with pretend time: every step
-- runs and passes, the context line and probe lines are written, the secret
-- mana read is "secret" on Forever, the setting is put back, CineMode is kept
-- off and comes back on; typed again it stops and puts back; a run cut off
-- (a /reload) is put back at the next login; step numbers pick steps;
-- /cine debug kit lists it. PASS or FAIL per check.
-- luacheck: push ignore 111 112 113 121 122 212 431
local SECRET = setmetatable({}, { __tostring = function() return "secret" end })
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

local function RunClient(client)
	print("== " .. client)
	local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function()
		issecretvalue = function(value) return value == SECRET end
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
	UnitPower = function() return client == "forever" and SECRET or 500 end
	UnitLevel = function() return 60 end
	local shots = 0
	Screenshot = function() shots = shots + 1 end
	-- CineMode as a switch the kit can see and flip.
	local cine = true
	ns.IsCineModeOn = function() return cine end
	Cinematic_ToggleCineMode = function() cine = not cine end
	ns.PadTestBox = function() end
	ns.PadTestBoxHide = function() end

	CinematicDB.kitCheckStandInLog = nil -- (another client's run, no reload between)
	-- A whole run.
	ns.HandleSlash("debug kitcheck")
	Check("CineMode off at once", cine == false)
	Advance(30)
	local log = CinematicDB.kitCheckTestLog
	local done = Has(log, "DONE: ")
	Check("finished DONE", done ~= nil, done)
	Check("first run: 9 pass, 0 fail, 2 skip (no last run yet)", done and done:find("9 pass, 0 fail, 2 skip", 1, true) ~= nil, done)
	Check("context line", Has(log, "context: Cinematic .*" .. client) ~= nil, Has(log, "context:"))
	Check("settings and cvars in the context", Has(log, "settings kitCheckProbe=") ~= nil and Has(log, "cvars ") ~= nil)
	Check("a state line per step", Has(log, "step 1 probe: .*| combat") ~= nil, Has(log, "step 1"))
	local mana = Has(log, "probe UnitPower%(player,0%)")
	Check("mana probe line names its rule", mana and mana:find("rule=forever.unitpower.mana-secret", 1, true) ~= nil, mana)
	Check("mana secret per client", mana and mana:find(client == "forever" and "secret=true" or "secret=false", 1, true) ~= nil, mana)
	Check("error probe logged", Has(log, "probe error on purpose: ok=false") ~= nil, Has(log, "probe error"))
	Check("two screenshots taken", shots == 2, shots)
	Check("setting put back (was unset)", ns.db.kitCheckProbe == nil, ns.db.kitCheckProbe)
	Check("undo cleared", CinematicDB.kitCheckTestUndo == nil)
	Check("CineMode back on", cine == true)

	-- Typed again while it runs: stopped and put back; the last run kept.
	ns.HandleSlash("debug kitcheck 2 4")
	Advance(0.5)
	Check("step numbers pick steps", Has(CinematicDB.kitCheckTestLog, "2 of 7 step") ~= nil)
	Check("previous run kept", CinematicDB.kitCheckTestPrevLog and Has(CinematicDB.kitCheckTestPrevLog, "DONE: ") ~= nil)
	Check("setting changed mid-run", ns.db.kitCheckProbe == "kit check", ns.db.kitCheckProbe)
	ns.HandleSlash("debug kitcheck")
	Check("typed again: STOPPED", Has(CinematicDB.kitCheckTestLog, "STOPPED: ") ~= nil)
	Check("stopped: setting put back", ns.db.kitCheckProbe == nil, ns.db.kitCheckProbe)
	Check("stopped: CineMode back on", cine == true)
	Advance(10)
	Check("nothing runs after the stop", Has(CinematicDB.kitCheckTestLog, "got it after") == nil
		and Has(CinematicDB.kitCheckTestLog, "DONE: ") == nil)

	-- Cut off by a /reload: put back at the next login. (Step 3 waits, so
	-- the run is still going.)
	ns.HandleSlash("debug kitcheck 2 3")
	ns.TestKit.Running().stopped = true -- (the reload: nothing more runs)
	Check("cut-off run left its undo", CinematicDB.kitCheckTestUndo ~= nil)
	cine = false
	wow.Fire("PLAYER_ENTERING_WORLD")
	Check("login put the setting back", ns.db.kitCheckProbe == nil, ns.db.kitCheckProbe)
	Check("login put CineMode back", cine == true)
	Check("login said so in the log", Has(CinematicDB.kitCheckTestLog, "login: the run was cut off") ~= nil)

	-- A /reload, then a whole run again: the last run's closing line found.
	for i = #timers, 1, -1 do timers[i] = nil end -- (the login step's own timers: other code the stand-in can't run)
	ns.TestKit.CloseOld() -- (the wrapper's part of PLAYER_LOGOUT)
	ns.HandleSlash("debug kitcheck")
	Advance(30)
	local again = Has(CinematicDB.kitCheckTestLog, "DONE: ")
	Check("after a reload: 10 pass, 0 fail, 1 skip", again and again:find("10 pass, 0 fail, 1 skip", 1, true) ~= nil, again)
	Check("closing line verdict", Has(CinematicDB.kitCheckTestLog, "PASS old: the last run's closing line") ~= nil)

	-- The list.
	local printed = {}
	local oldPrint = print
	print = function(...) printed[#printed + 1] = table.concat({ ... }, " ") end
	ns.Print = function(text) printed[#printed + 1] = text end
	ns.TestKitRun("kit")
	print = oldPrint
	local listed = false
	for _, line in ipairs(printed) do if line:find("kitcheck", 1, true) then listed = true end end
	Check("/cine debug kit lists kitcheck", listed)
end

RunClient("forever")
RunClient("retail")
print(fails == 0 and "all passed" or (fails .. " failed"))
if fails > 0 then os.exit(1) end
-- luacheck: pop
