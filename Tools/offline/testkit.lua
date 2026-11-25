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
	Check("row: answers, Edit Mode, Skip step, Stop, Report issue", table.concat(labels, ",") == "No,Open Edit Mode,Report issue,Skip step,Stop,Yes",
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

	-- Proven: a proven step left out of a run (the start line says so), a
	-- proven check left out in a step; "full" runs both (2026-11-22).
	local ranProven, checked = false, nil
	ns.TestKit.Define({ name = "kitproven", key = "kitProvenTest", title = "Kit proven", steps = {
		{ key = "new", title = "the new check", run = function(r)
			checked = not r:Proven("seen in run 1")
			r:Pass("the new check")
		end },
		{ key = "old", title = "a proven step", proven = "run 1", run = function(r)
			ranProven = true
			r:Pass("the old check")
		end },
	} })
	ns.HandleSlash("debug kitproven")
	Advance(3)
	local pLog = CinematicDB.kitProvenTestLog
	Check("proven: the step left out", ranProven == false and Has(pLog, "proven, left out") ~= nil
		and Has(pLog, "old %(run 1%)") ~= nil, Has(pLog, "proven"))
	Check("proven: the check left out", checked == false and Has(pLog, "not checked again: seen in run 1") ~= nil)
	Check("proven: the run done", Has(pLog, "DONE: 1 pass") ~= nil, Has(pLog, "DONE"))
	ns.HandleSlash("debug kitproven full")
	Advance(3)
	pLog = CinematicDB.kitProvenTestLog
	Check("full: the proven step runs", ranProven == true and Has(pLog, "full run") ~= nil)
	Check("full: the proven check runs", checked == true and Has(pLog, "DONE: 2 pass") ~= nil, Has(pLog, "DONE"))

	-- The console (2026-11-23): its lines and CVar changes logged live in the
	-- step they came in, an error / warning named, repeats counted not logged,
	-- secret text kept out, nothing after the run; consoleWords on the context
	-- line with value, default and flags; console = false leaves it out.
	ConsoleGetAllCommands = function()
		return { { command = "test_cameraOverShoulder", commandType = 0, help = "" },
			{ command = "cameraSmoothStyle", commandType = 0, help = "Camera follow style" },
			{ command = "ActionCam", commandType = 1, help = "" },
			{ command = "nameplateShowAll", commandType = 0, help = "" } }
	end
	ConsoleIsActive = function() return false end
	C_CVar = C_CVar or {}
	C_CVar.GetCVarInfo = function(name)
		if name == "cameraSmoothStyle" then return "4", "0", true, false, false, true, false end
		return "0", "0", false, false, false, false, false
	end
	ns.TestKit.Define({ name = "kitconsole", key = "kitConsoleTest", title = "Kit console", consoleWords = { "Camera" },
		steps = {
			{ key = "talk", title = "the console talks", run = function(r)
				wow.Fire("CONSOLE_MESSAGE", "Test CVar test_cameraOverShoulder has been set to 0.02 (default 0.000000)", 0)
				wow.Fire("CONSOLE_MESSAGE", "Test CVar test_cameraOverShoulder has been set to 0.02 (default 0.000000)", 0)
				wow.Fire("CONSOLE_MESSAGE", "Lua Error: Blizzard_UnitFrame/CompactUnitFrame.lua:1557: bad argument\n[C]: in function 'UnitWidgetSet'\n", 3)
				wow.Fire("CONSOLE_MESSAGE", "Overlay is disabled.", 4)
				wow.Fire("CONSOLE_MESSAGE", SECRET, 0)
				wow.Fire("CVAR_UPDATE", "cameraSmoothStyle", "4")
				-- (One CVar written over and over with new values, the engine's
				-- line for each too: one line each, the rest counted, the last kept.)
				for i = 1, 4 do
					wow.Fire("CVAR_UPDATE", "test_cameraOverShoulder", tostring(i / 10))
					wow.Fire("CONSOLE_MESSAGE", ("Test CVar test_cameraOverShoulder has been set to %.2f (default 0.000000)"):format(i / 10), 0)
				end
				r:Pass("talked")
			end },
		} })
	ns.HandleSlash("debug kitconsole")
	Advance(3)
	local cLog = CinematicDB.kitConsoleTestLog
	Check("console: a plain line, in its step", Has(cLog, "^%S+   console: Test CVar test_cameraOverShoulder has been set to 0.02") ~= nil,
		Has(cLog, "console: Test"))
	local repeats = 0
	for _, line in ipairs(cLog or {}) do if line:find("^%S+   console: Test CVar") then repeats = repeats + 1 end end
	Check("console: the same line logged once", repeats == 1, repeats)
	Check("console: an error named, its stack on one line",
		Has(cLog, "console error: Lua Error: .*CompactUnitFrame.lua:1557: bad argument | %[C%]: in function 'UnitWidgetSet'$") ~= nil,
		Has(cLog, "console error"))
	Check("console: a warning named", Has(cLog, "console warning: Overlay is disabled%.") ~= nil)
	Check("console: secret text kept out", Has(cLog, "console: secret$") ~= nil, Has(cLog, "console: s"))
	Check("cvar: a CVar change", Has(cLog, "cvar: cameraSmoothStyle = 4") ~= nil, Has(cLog, "cvar:"))
	Check("console: the end counts, the repeats named with their last value",
		Has(cLog, "console: 6 line%(s%) logged, 8 repeat%(s%) counted, 0 over the cap; "
			.. "x6 console: Test CVar test_cameraOverShoulder has been set to 0%.40 %(default 0%.000000%); "
			.. "x4 cvar: test_cameraOverShoulder = 0%.4$") ~= nil,
		Has(cLog, "line%(s%) logged"))
	local cvarLines = 0
	for _, line in ipairs(cLog or {}) do if line:find("^%S+   cvar: test_cameraOverShoulder") then cvarLines = cvarLines + 1 end end
	Check("cvar: one CVar written 4 times, one line", cvarLines == 1 and Has(cLog, "cvar: test_cameraOverShoulder = 0%.1$") ~= nil,
		cvarLines)
	Check("console words: matches, case-blind", Has(cLog, "console word \"camera\": 2 match%(es%)") ~= nil,
		Has(cLog, "console word"))
	Check("console words: value, default, flags, help",
		Has(cLog, "cameraSmoothStyle = 4 %(default 0, account, secure%) \"Camera follow style\"") ~= nil,
		Has(cLog, "cameraSmoothStyle ="))
	Check("console words: no non-matches", Has(cLog, "nameplateShowAll") == nil and Has(cLog, "  ActionCam") == nil)
	Check("console window state in the context", Has(cLog, "console window open false") ~= nil)
	local before = #cLog
	wow.Fire("CONSOLE_MESSAGE", "after the run", 0)
	Check("console: nothing logged after the run", #CinematicDB.kitConsoleTestLog == before)
	ns.TestKit.Define({ name = "kitquiet", key = "kitQuietTest", title = "Kit quiet", console = false, steps = {
		{ key = "talk", title = "talks", run = function(r)
			wow.Fire("CONSOLE_MESSAGE", "not for this test", 0)
			r:Pass("talked")
		end },
	} })
	ns.HandleSlash("debug kitquiet")
	Advance(3)
	Check("console = false: no console lines", Has(CinematicDB.kitQuietTestLog, "console:") == nil
		and Has(CinematicDB.kitQuietTestLog, "DONE: 1 pass") ~= nil)
	-- (Over the cap: counted, not logged.)
	local function Word(i) return "line " .. string.char(97 + math.floor(i / 26), 97 + i % 26) end
	ns.TestKit.Define({ name = "kitflood", key = "kitFloodTest", title = "Kit flood", steps = {
		{ key = "flood", title = "floods", run = function(r)
			-- (Words, not numbers: lines that differ only by a number count as one.)
			for i = 1, 160 do wow.Fire("CONSOLE_MESSAGE", Word(i), 0) end
			r:Pass("flooded")
		end },
	} })
	ns.HandleSlash("debug kitflood")
	Advance(3)
	Check("console: capped at 150, the rest counted", Has(CinematicDB.kitFloodTestLog, "console: " .. Word(150) .. "$") ~= nil
		and Has(CinematicDB.kitFloodTestLog, "console: " .. Word(151) .. "$") == nil
		and Has(CinematicDB.kitFloodTestLog, "150 line%(s%) logged, 0 repeat%(s%) counted, 10 over the cap") ~= nil,
		Has(CinematicDB.kitFloodTestLog, "logged"))
	ConsoleGetAllCommands, ConsoleIsActive = nil, nil

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

	-- Error inspection (2026-11-25): which errors grew in a run, and whose.
	local blocked = { kind = "blocked", message = "CinematicDev: UNKNOWN() (in combat)", count = 2, source = "CinematicDev",
		stack = "      [C]: ?\n      [CinematicDev/Frames.lua]:4936: in function <CinematicDev/Frames.lua:4928>\n"
			.. "      [CinematicDev/Plates/PlateParts.lua]:2825: in function" }
	local mine = { kind = "error", message = "attempt to index nil", count = 1, source = "CinematicDev",
		stack = "      [CinematicDev/UI/CooldownBoth.lua]:120: in function <CinematicDev/UI/CooldownBoth.lua:100>" }
	local old = { kind = "error", message = "an old one", count = 5, source = "CinematicDev", stack = nil }
	local entries = { blocked, mine, old }
	ns.DevErrorEntries = function() return entries end
	local snap = ns.TestKit.ErrorSnapshot()
	blocked.count, mine.count = 38, 3 -- (old didn't grow)
	local lines = ns.TestKit.InspectErrors({ def = { files = { "UI/CooldownBoth.lua" } } }, snap, "during:")
	local text = table.concat(lines, "\n")
	Check("inspect: only the errors that grew (2 of 3)", #lines == 2, #lines)
	Check("inspect: the blocked call, x36, at Frames.lua:4936, another feature's",
		text:find("blocked x36", 1, true) and text:find("Frames.lua:4936", 1, true)
		and text:find("another feature", 1, true) ~= nil, text)
	Check("inspect: the test's own file named THIS TEST'S FEATURE",
		text:find("error x2", 1, true) and text:find("UI/CooldownBoth.lua:120 | THIS TEST'S FEATURE", 1, true) ~= nil, text)
	ns.DevErrorEntries = nil
end

RunClient("forever")
RunClient("retail")
print(fails == 0 and "all passed" or (fails .. " failed"))
if fails > 0 then os.exit(1) end
-- luacheck: pop
