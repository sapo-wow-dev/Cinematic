-- The test queue (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/testqueue.lua < /dev/null
-- Dev/TestQueue.lua on the stand-in game (Forever, then retail) with pretend
-- time, running /cine debug kitcheck as the queued test: the offer after a
-- login, Run all runs each in turn with a result line and its own log copy,
-- a name that isn't a kit test is passed over, Stop queue leaves the rest for
-- later, a test's Reload button carries the queue over the reload, a /reload
-- of your own cuts it off and offers the rest, read entries are tidied, and
-- /cine debug testqueue clear. PASS or FAIL per check.
-- luacheck: push ignore 111 112 113 121 122 212 431
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
		issecretvalue = function() return false end
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
			-- (Other code's login timers fail on the stand-in: only ours count.)
			for i = #due, 1, -1 do
				local ok, err = xpcall(due[i].fn, debug.traceback)
				if not ok and tostring(err):find("Dev/Test") then Check("no error in the kit or queue", false, err) end
			end
			for _, t in ipairs(tickers) do
				if not t.cancelled and t.next <= now then
					t.next = now + t.every
					t.fn(t)
				end
			end
		end
	end
	UnitPower = function() return 500 end
	UnitLevel = function() return 60 end
	Screenshot = function() end
	local cine = false
	ns.IsCineModeOn = function() return cine end
	Cinematic_ToggleCineMode = function() cine = not cine end
	local box, boxes = "", {}
	ns.PadTestBox = function(text, sub)
		box = tostring(text) .. " | " .. tostring(sub)
		boxes[#boxes + 1] = box
	end
	ns.PadTestBoxHide = function() end
	local M = wow.Methods
	M.SetAttribute = function(self, k, v) self._attr = self._attr or {} self._attr[k] = v end
	M.GetAttribute = function(self, k) return self._attr and self._attr[k] end
	local function Click(button) button:GetScript("OnClick")(button, "LeftButton") end
	local Q, Kit = ns.TestQueue, ns.TestKit
	Check("runner loaded", Q ~= nil and Kit.onFinish ~= nil)
	if not Q then return end
	for key in pairs(CinematicDB) do if tostring(key):find("^testQueue") then CinematicDB[key] = nil end end
	local function Login(isLogin, isReload)
		for i = #timers, 1, -1 do timers[i] = nil end -- (other code's login timers: the stand-in can't run them)
		Kit.ResetLogin()
		Q.ResetLogin()
		wow.Fire("PLAYER_ENTERING_WORLD", isLogin, isReload)
	end
	local function Result(id) return Has(CinematicDB.testQueueLog, "id=" .. id .. " test=%S+ session=.- result=") end

	-- The offer at login, Run all: each in turn.
	ns.TestQueueList = {
		{ id = "qa", test = "kitcheck", args = "", session = "Session one" },
		{ id = "qb", test = "nosuchtest", args = "", session = "Session two" },
		{ id = "qc", test = "kitcheck", args = "1 2", session = "Session two", note = "two steps" },
	}
	-- (What the tests ask: as testqueue.py's scan writes it.)
	ns.TestQueueCatalog = { kitcheck = { asks = 0, reloads = 0 }, cardevents = { asks = 0, reloads = 0 },
		cdmgrid = { asks = 2, reloads = 0, first = "Right-click one of your tracked buffs off" } }
	Login(true, false)
	Advance(6)
	local rows = Q.rows
	local function Txt(fs) return fs and fs:GetText() end
	Check("picker opened after the login", Q.IsOpen() and Q.buttons["Run checked"] ~= nil)
	Check("first row: the queued section", (Txt(rows[1].header) or ""):find("^QUEUED FOR .-  %(3%)$") ~= nil, Txt(rows[1].header))
	Check("queued row: test, whose, Hands off", Txt(rows[2].title) == "Test kit check"
		and (Txt(rows[2].detail) or ""):find("from Session one", 1, true) ~= nil
		and Txt(rows[2].pill.text) == "Hands off" and (Txt(rows[2].detail) or ""):find("Nothing to do, 7 steps", 1, true) ~= nil,
		tostring(Txt(rows[2].title)) .. " | " .. tostring(Txt(rows[2].detail)))
	Check("steps read as words, the note shown", Txt(rows[4].title) == "Test kit check (steps 1, 2)"
		and (Txt(rows[4].detail) or ""):find("two steps", 1, true) ~= nil, Txt(rows[4].title))
	Check("a name that isn't a kit test: Unknown", Txt(rows[3].pill.text) == "Unknown", Txt(rows[3].pill.text))
	Check("then every other kit test", (Txt(rows[5].header) or ""):find("ALL OTHER KIT TESTS", 1, true) ~= nil, Txt(rows[5].header))
	local function Count()
		local n = 0
		for _, item in ipairs(Q.model.items) do
			if item.kind ~= "header" and Q.model.checked[item.entry and item.entry.id or ("t:" .. item.name)] then n = n + 1 end
		end
		return n
	end
	Check("the queued ones checked", Count() == 3 and Txt(Q.buttons["Run checked"]) == "Run checked (3)", Txt(Q.buttons["Run checked"]))
	local needsRow
	for _, item in ipairs(Q.model.items) do if item.name == "cdmgrid" then needsRow = item end end
	Check("a test that asks: Needs you, with its words", needsRow and Q.Needs("cdmgrid") == "you"
		and select(2, Q.Needs("cdmgrid")):find('asks: "Right-click one of your tracked buffs off" +1 more', 1, true) ~= nil,
		select(2, Q.Needs("cdmgrid")))
	Click(Q.buttons["None"])
	Check("None: nothing checked", Count() == 0 and Txt(Q.buttons["Run checked"]) == "Run checked")
	Click(Q.buttons["Needs me"])
	local wrong
	for _, item in ipairs(Q.model.items) do
		if item.kind ~= "header" then
			local isYou = Q.Needs(item.name, item.entry) == "you"
			local on = Q.model.checked[item.entry and item.entry.id or ("t:" .. item.name)] == true
			if isYou ~= on then wrong = wrong or item.name end
		end
	end
	Check("Needs me: just the ones that ask or need a place (a test's needs =)", Q.model.checked["t:cdmgrid"] == true
		and Q.model.checked["t:cdmround"] == true and wrong == nil, wrong)
	Click(Q.buttons["Hands off"])
	Check("Hands off: the quiet ones, queued and not", Q.model.checked.qa and Q.model.checked.qc and Q.model.checked["t:cardevents"]
		and not Q.model.checked["t:cdmgrid"] and not Q.model.checked.qb, Count())
	Click(Q.buttons["Queued"])
	Check("Queued: the three again", Count() == 3 and Q.model.checked.qb == true)
	Q.panelWheel(-1)
	Check("the wheel scrolls a row", rows[1].item and rows[1].item.entry and rows[1].item.entry.id == "qa")
	rows[1].Toggle()
	Check("a row click unchecks it", not Q.model.checked.qa)
	rows[1].Toggle()
	Click(Q.buttons["Run checked"])
	Check("Run checked closes the picker", not Q.IsOpen())
	Check("first test's name on the box", box:find("Queue 1/3 (Session one) - Test kit check", 1, true) ~= nil, box)
	Advance(4)
	Check("the test's own box says where the queue is", box:find("^Queue 1/3 %(Session one%) %- Test kit check, step") ~= nil, box)
	Check("first test running", Kit.Running() and Kit.Running().def.name == "kitcheck")
	local run = Kit.Running()
	Check("the test's row has Stop queue", run and run.buttons and run.buttons["Stop queue"] ~= nil)
	Advance(120)
	local qa, qb, qc = Result("qa"), Result("qb"), Result("qc")
	Check("qa DONE with its counts", qa and qa:find("result=DONE pass=%d+ fail=%d+ skip=%d+") ~= nil, qa)
	Check("qb not a kit test, passed over", qb and qb:find("result=NOT-A-KIT-TEST", 1, true) ~= nil, qb)
	Check("qc DONE, its own steps", qc and qc:find("result=DONE", 1, true) ~= nil
		and Has(CinematicDB.testQueue_qcLog, "2 of 7 step") ~= nil, qc)
	local reloadMid, between
	for i, text in ipairs(boxes) do
		if text:find("check log", 1, true) or (text:find("reload", 1, true) and i < #boxes) then reloadMid = reloadMid or text end
		if text:find("Queue 1/3 %(Session one%) %- Test kit check done: %d+ pass") and text:find("Next: nosuchtest, from Session two", 1, true) then between = text end
	end
	Check("no box says /reload or check log before the end", reloadMid == nil, reloadMid)
	Check("between tests: the result and what's next", between ~= nil, between)
	Check("an unknown test isn't called needs you", between and between:find("(not known if it needs you)", 1, true) ~= nil, between)
	Check("the last box is the queue's end", box:find("^Test queue done") ~= nil, box)
	local qcLines = 0
	for _, line in ipairs(CinematicDB.testQueueLog) do if line:find("id=qc test=%S+ session=") then qcLines = qcLines + 1 end end
	Check("qc (ends inside its start) has one result line, not a DID-NOT-START too", qcLines == 1, qcLines)
	if qcLines ~= 1 then for _, l in ipairs(CinematicDB.testQueueLog) do print("   " .. l) end end
	Check("qa's log kept apart (qc ran the same test after)", Has(CinematicDB.testQueue_qaLog, "DONE: ") ~= nil
		and Has(CinematicDB.testQueue_qaLog, "2 of 7 step") == nil)
	Check("session names quoted on the line", qa and qa:find('session="Session one"', 1, true) ~= nil, qa)
	Check("queue done box, Reload offered", box:find("Test queue done: 3 of 3 run", 1, true) ~= nil
		and Q.buttons and Q.buttons.Reload ~= nil, box)
	Check("Reload is the secure /reload", Q.buttons.Reload and Q.buttons.Reload:GetAttribute("macrotext") == "/reload")
	Check("nothing left, no run state", #Q.Pending() == 0 and CinematicDB.testQueueRun == nil and Kit.queueStop == nil)
	Login(false, true)
	Advance(6)
	Check("not offered again after the reload", not Q.IsOpen())

	-- Stop queue: this one STOPPED, the rest left for later.
	ns.TestQueueList = { { id = "qd", test = "kitcheck", args = "", session = "S" }, { id = "qe", test = "kitcheck", args = "", session = "S" } }
	Q.Start()
	Advance(4)
	run = Kit.Running()
	Click(run.buttons["Stop queue"])
	Check("Stop queue: qd STOPPED", (Result("qd") or ""):find("result=STOPPED", 1, true) ~= nil, Result("qd"))
	Check("Stop queue: qe left", #Q.Pending() == 1 and Q.Pending()[1].id == "qe" and Result("qe") == nil)
	Check("Stop queue: box says so", box:find("Test queue stopped: 1 of 2 run", 1, true) ~= nil, box)
	Advance(40)
	Check("nothing starts after the stop", Kit.Running() == nil and Result("qe") == nil)

	-- Requeue: stopped with no result, the next runs, then it runs again at the end.
	ns.TestQueueList = { { id = "rq1", test = "kitcheck", args = "", session = "S" }, { id = "rq2", test = "kitcheck", args = "1", session = "S" } }
	Q.Start()
	Advance(4)
	run = Kit.Running()
	Check("the test's row has Requeue", run and run.buttons and run.buttons.Requeue ~= nil)
	Click(run.buttons.Requeue)
	Check("Requeue: no result line, not done", Result("rq1") == nil and not CinematicDB.testQueueDone.rq1, Result("rq1"))
	Check("Requeue: box says so and what's next", box:find("requeued: it runs again at the end.", 1, true) ~= nil
		and box:find("Next: Test kit check (step 1)", 1, true) ~= nil, box)
	Check("Requeue: its log says the run doesn't count", Has(CinematicDB[run.def.key .. "Log"], "REQUEUED by you") ~= nil)
	Advance(200)
	local orderN, orderR
	for i, line in ipairs(CinematicDB.testQueueLog) do
		if line:find("id=rq2 test=%S+ session=") then orderN = i end
		if line:find("id=rq1 test=%S+ session=") then orderR = i end
	end
	Check("Requeue: the next ran, then it again", orderN and orderR and orderN < orderR
		and (Result("rq1") or ""):find("result=DONE", 1, true) ~= nil, Result("rq1"))
	Check("Requeue: end counts each test once", box:find("Test queue done: 2 of 2 run", 1, true) ~= nil, box)
	Check("Requeue: nothing left", #Q.Pending() == 0 and CinematicDB.testQueueRun == nil and Kit.queueRequeue == nil)

	-- A test's Reload button: the queue goes on after the reload.
	ns.TestQueueList = { { id = "qe", test = "kitcheck", args = "", session = "S" }, { id = "qf", test = "kitcheck", args = "1", session = "S" } }
	Q.Start()
	Advance(4)
	run = Kit.Running()
	run:SaveResume()
	run.stopped = true -- (the reload)
	Login(false, true)
	Advance(6)
	Check("picked up after the test's Reload", Has(CinematicDB.testQueueLog, "picked up after the reload: id=qe") ~= nil
		and Kit.Running() ~= nil)
	Advance(120)
	Check("qe DONE after the reload", (Result("qe") or ""):find("result=DONE", 1, true) ~= nil, Result("qe"))
	Check("then qf ran too", (Result("qf") or ""):find("result=DONE", 1, true) ~= nil, Result("qf"))

	-- A /reload of your own mid-test: cut off, the rest offered.
	ns.TestQueueList = { { id = "qg", test = "kitcheck", args = "", session = "S" }, { id = "qh", test = "kitcheck", args = "", session = "S" } }
	Q.Start()
	Advance(4)
	Kit.Running().stopped = true
	Login(false, true)
	Advance(6)
	Check("qg CUT-OFF", (Result("qg") or ""):find("result=CUT-OFF", 1, true) ~= nil, Result("qg"))
	Check("the rest offered again", Q.IsOpen() and Q.model.items[2].entry and Q.model.items[2].entry.id == "qh"
		and CinematicDB.testQueueRun == nil)
	Q.Close()

	-- Tidy: entries the sessions took off lose their copies; clear.
	Check("tidied: qa's copy gone (off the list)", CinematicDB.testQueue_qaLog == nil and not (CinematicDB.testQueueDone or {}).qa)
	Check("kept: qg's copy-free done mark", (CinematicDB.testQueueDone or {}).qg == true)
	ns.HandleSlash("debug testqueue clear")
	Check("clear: nothing waiting", #Q.Pending() == 0 and (Result("qh") or ""):find("CLEARED", 1, true) ~= nil)
	-- An older test (no end signal): the strip's Done copies its log, goes on.
	Kit.extraOld[1] = { cmd = "fakeold", file = "FakeOld.lua", log = "fakeOldLog" }
	local oldRuns = 0
	Q.RunOld = function(test)
		oldRuns = oldRuns + 1
		CinematicDB.fakeOldLog = { "start " .. test, "PASS one", "FAIL two", "verdicts: PASS FAIL" }
	end
	ns.TestQueueList = { { id = "qo", test = "fakeold", args = "", session = "Old one" }, { id = "qk", test = "kitcheck", args = "1", session = "S" } }
	Q.Start()
	Check("older test: told on the box first", box:find("Queue 1/2 (Old one) - fakeold (older test)", 1, true) ~= nil
		and box:find("click Done when its box says it's finished", 1, true) ~= nil, box)
	Advance(4)
	Check("older test: its command run, the strip up", oldRuns == 1 and Q.strip ~= nil
		and (Txt(Q.strip.text) or ""):find("When its box says it's finished, click Done", 1, true) ~= nil, Q.strip and Txt(Q.strip.text))
	Advance(30)
	Check("older test: the queue waits for Done", Result("qo") == nil and Kit.Running() == nil or (Kit.Running() and Kit.Running().stopped))
	Click(Q.strip.done)
	local qo = Result("qo")
	Check("Done: RAN with its PASS / FAIL lines counted", qo and qo:find("result=RAN pass=1 fail=1", 1, true) ~= nil, qo)
	Check("Done: its log copied apart", CinematicDB.testQueue_qoLog and CinematicDB.testQueue_qoLog[2] == "PASS one")	Advance(40)
	Check("then the next (a kit test) ran", (Result("qk") or ""):find("result=DONE", 1, true) ~= nil, Result("qk"))
	-- Stop queue mid older test; a reload mid older test.
	ns.TestQueueList = { { id = "qs", test = "fakeold", args = "", session = "Old one" }, { id = "qt", test = "fakeold", args = "", session = "Old two" } }
	Q.Start()
	Advance(4)
	Login(false, true)
	Advance(6)
	Check("reload mid older test: it goes on, the strip back", Has(CinematicDB.testQueueLog, "older test still going: id=qs") ~= nil
		and Result("qs") == nil)
	Click(Q.strip.stop)
	Check("Stop queue mid older test: STOPPED, may still be going", (Result("qs") or ""):find("result=STOPPED", 1, true) ~= nil
		and (Result("qs") or ""):find("type its command again", 1, true) ~= nil, Result("qs"))
	Check("Stop queue: the other left", #Q.Pending() == 1 and Q.Pending()[1].id == "qt")
	ns.TestQueueList = {}
	-- The picker lists the older ones last, as Older test.
	Q.Open()
	local oldRow
	for _, item in ipairs(Q.model.items) do if item.name == "namescale" then oldRow = item end end
	Check("picker: older tests listed (namescale)", oldRow ~= nil and Q.Needs("namescale") == "older")
	Click(Q.buttons["Needs me"])
	Check("Needs me doesn't check the older ones", not Q.model.checked["t:namescale"])
	Q.Close()
	Kit.extraOld[1] = nil

	-- Per client: each client runs its own share, lists the rest as waiting.
	local here = Q.client
	local there = here == "retail" and "forever" or "retail"
	ns.TestQueueList = {
		{ id = "cm", test = "kitcheck", args = "1", session = "Mine", client = here },
		{ id = "cb", test = "kitcheck", args = "1", session = "Both", client = "both" },
		{ id = "cx", test = "kitcheck", args = "1", session = "Theirs", client = there },
	}
	local ids = {}
	for _, entry in ipairs(Q.Pending()) do ids[#ids + 1] = entry.id end
	Check("this client runs its own and both, not the other's", table.concat(ids, ",") == "cm,cb", table.concat(ids, ","))
	Check("the other's listed as elsewhere", #Q.Elsewhere() == 1 and Q.Elsewhere()[1].id == "cx")
	Q.Open()
	local awayHeader, awayRow
	for i, item in ipairs(Q.model.items) do
		if item.kind == "header" and item.text:find("WAITING FOR", 1, true) then awayHeader = item.text end
		if item.kind == "elsewhere" then awayRow = i end
	end
	Check("picker: a WAITING FOR section with it", awayHeader and awayHeader:find((there == "retail" and "RETAIL" or "WOW FOREVER"), 1, true)
		and awayRow ~= nil, awayHeader)
	Click(Q.buttons["Queued"])
	Check("the other client's can't be checked", not Q.model.checked.cx and Q.model.checked.cm and Q.model.checked.cb)
	Click(Q.buttons["Run checked"])
	Advance(40)
	local line = Result("cb")
	Check("result lines say the client", line and line:find("client=" .. here .. " id=cb", 1, true) ~= nil, line)
	Check("the other client's never ran here", Result("cx") == nil)
	ns.TestQueueList = {}

	-- In a fight: the next test waits for it to end; Start anyway skips the wait.
	local fight = true
	local lockdown, combat = InCombatLockdown, UnitAffectingCombat
	InCombatLockdown = function() return fight end
	UnitAffectingCombat = function() return fight end
	ns.TestQueueList = { { id = "fa", test = "kitcheck", args = "1", session = "Fighter" }, { id = "fb", test = "kitcheck", args = "1", session = "Fighter" } }
	Q.Start()
	Check("in a fight: the box says it waits", box:find("Waiting for your fight to end", 1, true) ~= nil
		and box:find("Queue 1/2 (Fighter)", 1, true) ~= nil, box)
	Advance(20)
	Check("in a fight: nothing starts", Result("fa") == nil and Has(CinematicDB.testQueueLog, "start id=fa") == nil)
	fight = false
	wow.Fire("PLAYER_REGEN_ENABLED")
	Advance(4)
	Check("the fight over: it starts", Has(CinematicDB.testQueueLog, "fight over, starting: id=fa") ~= nil
		and Has(CinematicDB.testQueueLog, "start id=fa") ~= nil)
	fight = true
	Advance(10)
	Check("next one, in a fight again: waits", Result("fa") ~= nil and box:find("Waiting for your fight to end", 1, true) ~= nil
		and box:find("Queue 2/2", 1, true) ~= nil, box)
	Click(Q.buttons["Start anyway"])
	Advance(10)
	Check("Start anyway: it starts in the fight", Has(CinematicDB.testQueueLog, "started anyway in the fight: id=fb") ~= nil
		and Result("fb") ~= nil, Result("fb"))
	Advance(5)
	Check("ended in a fight: no Reload yet, the box says it comes", Q.buttons and Q.buttons.Reload == nil
		and Q.buttons.Close ~= nil and (Q.endSub or ""):find("comes when your fight is over", 1, true) ~= nil, Q.endSub)
	fight = false
	wow.Fire("PLAYER_REGEN_ENABLED")
	Check("the fight over: Reload there", Q.buttons and Q.buttons.Reload ~= nil
		and not (Q.endSub or ""):find("fight", 1, true), Q.endSub)
	InCombatLockdown, UnitAffectingCombat = lockdown, combat
	ns.TestQueueList = {}

	-- Report issue: on a kit test's row, with its step and what it asked; on an older test's strip.
	ns.TestQueueList = { { id = "qr", test = "kitcheck", args = "", session = "Reporter" } }
	Q.Start()
	Advance(4)
	run = Kit.Running()
	Check("the test's row has Report issue", run and run.buttons and run.buttons["Report issue"] ~= nil)
	Click(run.buttons["Report issue"])
	local rbox = Q.reportBox
	Check("report box: the test and its step", rbox and (Txt(rbox.what) or ""):find("Test kit check|r, step %d+/7")
		and (Txt(rbox.what) or ""):find("Queued by Reporter", 1, true) ~= nil, rbox and Txt(rbox.what))
	-- A long "It asked" wraps to many lines: the typing box moves down under it and the box grows.
	local realHeight = rbox.what.GetStringHeight
	local realSetHeight, grown = rbox.SetHeight, nil
	rbox.what.GetStringHeight = function() return 90 end
	rbox.SetHeight = function(self, h) grown = h; return realSetHeight(self, h) end
	Q.OpenReport({ run = run })
	Check("report box: long text grows the box to fit it", (grown or 0) >= 44 + 90 + 10 + 86 + 20 + 54, grown)
	rbox.what.GetStringHeight, rbox.SetHeight = realHeight, realSetHeight
	rbox.input:SetText("mousing over,\n\"nothing\" happens  ")
	local stepBefore = run.stepNumber
	Click(rbox.buttons["Send and skip step"])
	local issue = Has(CinematicDB.testQueueLog, "issue client=")
	Check("queue log: the issue with id, test, step and message", issue
		and issue:find(('issue client=%s id=qr test=kitcheck step=%s/7:'):format(Q.client, tostring(stepBefore)), 1, true)
		and issue:find('msg="mousing over, \\"nothing\\" happens"', 1, true) ~= nil, issue)
	Check("the test's own log: an ISSUE line", Has(CinematicDB.kitCheckTestLog, "ISSUE reported by you at step") ~= nil)
	Check("Send and skip step: the step skipped", Has(CinematicDB.kitCheckTestLog, "SKIP .-: skipped by you") ~= nil)
	Advance(60)
	Check("the run went on to its result", (Result("qr") or ""):find("result=DONE", 1, true) ~= nil, Result("qr"))
	Check("its copied log keeps the ISSUE line", Has(CinematicDB.testQueue_qrLog, "ISSUE reported by you") ~= nil)
	Kit.extraOld[1] = { cmd = "fakeold", file = "FakeOld.lua", log = "fakeOldLog" }
	ns.TestQueueList = { { id = "qq", test = "fakeold", args = "", session = "Old reporter" } }
	Q.Start()
	Advance(4)
	Click(Q.strip.report)
	Check("older test: the report box says so, no skip", (Txt(Q.reportBox.what) or ""):find("an older test", 1, true) ~= nil)
	Q.reportBox.input:SetText("the box never said finished")
	Click(Q.reportBox.buttons["Send, keep going"])
	Check("older test: issue logged with step=older", Has(CinematicDB.testQueueLog, "issue client=%S+ id=qq test=fakeold step=older") ~= nil)
	Click(Q.strip.done)
	Advance(5) -- (the queue's end after the last one)
	Kit.extraOld[1] = nil
	ns.TestQueueList = {}

	ns.HandleSlash("debug testqueue")
	Check("/cine debug testqueue with none queued: the picker, every test", Q.IsOpen()
		and (Q.model.items[2].text or ""):find("Nothing queued", 1, true) ~= nil)
	Click(Q.buttons["None"])
	Q.model.checked["t:kitcheck"] = true
	Click(Q.buttons["Run checked"])
	Advance(60)
	local picked = Has(CinematicDB.testQueueLog, 'session="You %(picked in game%)" result=DONE')
	Check("a test picked in game, not queued, runs and is recorded", picked ~= nil, picked)
	Check("its stand-in entry dropped after", (function() Login(false, true) Advance(6) return CinematicDB.testQueueExtra == nil end)())

	-- Reset Settings / Reset Everything (the user, 2026-11-23: a test already
	-- run came back after a reset): the dev copy keeps the queue's done marks,
	-- results and logs, and the test isn't offered again.
	for _, settingsOnly in ipairs({ true, false }) do
		local what = settingsOnly and "Reset Settings" or "Reset Everything"
		local id = settingsOnly and "rs1" or "rs2"
		ns.TestQueueList = { { id = id, test = "kitcheck", args = "1", session = "Reset" } }
		Q.Start()
		Advance(40)
		Check(what .. ": " .. id .. " ran first", (Result(id) or ""):find("result=DONE", 1, true) ~= nil, Result(id))
		local reload, reloaded, layouts = ns.Reload, false, ns.ResetLayouts
		ns.Reload = function() reloaded = true end
		-- (Edit Mode's layouts: the stand-in has none to put back, not this check.)
		ns.ResetLayouts = function() return true end
		local ok, err = pcall(ns.ResetAddon, settingsOnly)
		ns.Reload, ns.ResetLayouts = reload, layouts
		Check(what .. ": ran", ok and reloaded, err)
		ns.db = CinematicDB or {} -- (the reload's new db)
		CinematicDB = ns.db
		ns.db.log = ns.db.log or {} -- (as the reload's load makes it)
		Check(what .. ": done mark kept", (CinematicDB.testQueueDone or {})[id] == true)
		Check(what .. ": result line and log kept", Result(id) ~= nil and type(CinematicDB["testQueue_" .. id .. "Log"]) == "table")
		Login(false, true)
		Advance(6)
		Check(what .. ": not offered again", not Q.IsOpen() and #Q.Pending() == 0)
		Q.Close()
	end
	ns.TestQueueList = {}
end

RunClient("forever")
RunClient("retail")
print(fails == 0 and "testqueue: all pass" or ("testqueue: " .. fails .. " FAIL"))
if fails > 0 then os.exit(1) end
-- luacheck: pop
