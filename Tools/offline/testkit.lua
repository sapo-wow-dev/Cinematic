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
	ns.stillSince = now - 500 -- (standing still a long while: the AFK camera's due)
	ns.HandleSlash("debug kitcheck")
	Check("CineMode off at once", cine == false)
	Advance(5)
	Check("no AFK camera mid-run: its still timer kept fresh", ns.stillSince >= now - 1.5,
		("still since %.1f, now %.1f"):format(ns.stillSince, now))
	Advance(25)
	local log = CinematicDB.kitCheckTestLog
	local done = Has(log, "DONE: ")
	Check("finished DONE", done ~= nil, done)
	Check("first run: 10 pass, 0 fail, 2 skip (no last run yet)", done and done:find("10 pass, 0 fail, 2 skip", 1, true) ~= nil, done)
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
	Check("after a reload: 11 pass, 0 fail, 1 skip", again and again:find("11 pass, 0 fail, 1 skip", 1, true) ~= nil, again)
	Check("closing line verdict", Has(CinematicDB.kitCheckTestLog, "PASS old: the last run's closing line") ~= nil)

	-- The buttons: an answer wakes the wait, Skip step drops a step, Stop
	-- stops, the Reload button's click picks the run up at the next login.
	local got
	-- (The stand-in keeps no attributes: these do, for the secure buttons.)
	local M = wow.Methods
	M.SetAttribute = function(self, k, v) self._attr = self._attr or {} self._attr[k] = v end
	M.GetAttribute = function(self, k) return self._attr and self._attr[k] end
	local function Click(button) button:GetScript("OnClick")(button, "LeftButton") end
	ns.TestKit.Define({ name = "kitbuttons", key = "kitButtonsTest", title = "Kit buttons", settings = { "kitCheckProbe" },
		steps = {
			{ key = "ask", title = "an answer", run = function(r)
				local _, label = r:WaitFor("Pick one", { buttons = { "Yes", "No", { kind = "editmode" } } })
				got = label
				r:Verdict(label == "Yes", "answered " .. tostring(label))
			end },
			{ key = "wait", title = "a wait to skip", run = function(r)
				r:WaitFor("Never comes", { check = function() return false end })
				r:Fail("should have been skipped")
			end },
			{ key = "reload", title = "a reload", run = function(r)
				r:Set("kitCheckProbe", "before reload")
				r:WaitFor("Reload", { buttons = { { kind = "reload" } } })
			end },
			{ key = "after", title = "after the reload", run = function(r)
				r:Verdict(ns.db.kitCheckProbe == "before reload", "the undo kept: " .. tostring(ns.db.kitCheckProbe))
			end },
		} })
	ns.HandleSlash("debug kitbuttons")
	Advance(0.5)
	local run = ns.TestKit.Running()
	local labels = {}
	for label in pairs(run.buttons or {}) do labels[#labels + 1] = label end
	table.sort(labels)
	Check("row: answers, Edit Mode, Skip step, Stop", table.concat(labels, ",") == "No,Open Edit Mode,Skip step,Stop,Yes",
		table.concat(labels, ","))
	Click(run.buttons.Yes)
	Advance(0.5)
	Check("Yes clicked: the wait returned it", got == "Yes", got)
	Click(run.buttons["Skip step"])
	Advance(0.5)
	Check("Skip step: a SKIP, on to step 3", Has(CinematicDB.kitButtonsTestLog, "SKIP wait: skipped by you") ~= nil
		and run.step and run.step.key == "reload", run.step and run.step.key)
	Advance(20)
	Check("the skipped step's code never ran on", Has(CinematicDB.kitButtonsTestLog, "should have been skipped") == nil)
	local reload = run.buttons.Reload
	Check("Reload is a secure /reload button", reload and reload:GetAttribute("macrotext") == "/reload",
		reload and reload:GetAttribute("macrotext"))
	reload:GetScript("PreClick")(reload)
	Check("Reload click: the rest saved", CinematicDB.kitButtonsTestResume and CinematicDB.kitButtonsTestResume.steps == "4",
		CinematicDB.kitButtonsTestResume and CinematicDB.kitButtonsTestResume.steps)
	run.stopped = true -- (the reload)
	ns.TestKit.ResetLogin()
	wow.Fire("PLAYER_ENTERING_WORLD", false, true)
	Advance(3)
	local after = Has(CinematicDB.kitButtonsTestLog, "DONE: ")
	Check("picked up after the reload: step 4 passes, the totals carried", after and after:find("2 pass, 0 fail, 1 skip", 1, true) ~= nil,
		after)
	Check("then put back", ns.db.kitCheckProbe == nil and CinematicDB.kitButtonsTestUndo == nil, ns.db.kitCheckProbe)
	Check("same log, not a new one", Has(CinematicDB.kitButtonsTestLog, "SKIP wait") ~= nil)
	ns.HandleSlash("debug kitbuttons")
	Advance(0.5)
	Click(ns.TestKit.Running().buttons.Stop)
	Check("Stop button: STOPPED", Has(CinematicDB.kitButtonsTestLog, "STOPPED: ") ~= nil and ns.TestKit.Running() == nil)

	-- r:Click: its call runs in the click (a hardware event), not before,
	-- and the wait gets what it returned; a step's own blocked resume()
	-- (levelemote run 2: an /e line from a timer) gets the hint.
	local inClick, ranIn, back
	ns.TestKit.Define({ name = "kitclick", key = "kitClickTest", title = "Kit click", steps = {
		{ key = "click", title = "a call in the click", run = function(r)
			local ok, value = r:Click("Send it", function() ranIn = inClick; return "sent" end, "Send")
			back = tostring(ok) .. " " .. tostring(value)
		end },
		{ key = "blocked", title = "a blocked resume()", run = function()
			wow.Fire("ADDON_ACTION_BLOCKED", "CinematicDev", "resume()")
		end },
	} })
	ns.HandleSlash("debug kitclick")
	Advance(0.5)
	Check("Click: nothing ran before the click", ranIn == nil and back == nil)
	local send = ns.TestKit.Running() and ns.TestKit.Running().buttons.Send
	Check("Click: its button on the row", send ~= nil)
	inClick = true
	if send then Click(send) end
	inClick = false
	Advance(0.5)
	Check("Click: ran inside the click", ranIn == true, tostring(ranIn))
	Check("Click: the wait got its results", back == "true sent", back)
	Advance(3)
	Check("blocked resume(): the hint", Has(CinematicDB.kitClickTestLog, "give it r:Click") ~= nil
		and Has(CinematicDB.kitClickTestLog, "FAIL blocked: 1 blocked") ~= nil)

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
