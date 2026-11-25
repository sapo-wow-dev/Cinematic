-- The test queue (dev copy only): kit tests queued by several Claude sessions
-- at once, run one after another from one click, each session's results kept
-- apart for it to read.
--   * Sessions queue a test with Tools/testqueue.py add; it writes
--     Dev/TestQueueList.lua (git-ignored), read at /reload as ns.TestQueueList:
--     { id = "q1a2b", test = "<kit test name>", args = "", session = "...", note = "...", added = "..." }
--   * After a /reload with tests waiting, the picker opens: the queued tests,
--     then every other kit test, each with whose it is and what it needs from
--     you (Hands off, or what it asks / where to be: testqueue.py scans each
--     test's prompts into ns.TestQueueCatalog; a test's or entry's needs = "..."
--     says more). Check what to run (Hands off / Needs me / Queued / None pick
--     groups), Run checked. /cine debug testqueue opens it any time;
--     "testqueue clear" drops what's queued.
--   * Each runs as /cine debug <test> <args> would; the kit's Stop ends that
--     test and the queue goes on, Stop queue ends the rest too (they wait for
--     the next /reload). A Lua error in one test fails it; the queue goes on.
--     Requeue (you messed a test up) stops it with no result and runs it
--     again at the end of the queue.
--   * Its result is a line in CinematicDB.testQueueLog
--     ("id=q1a2b test=... session=... result=DONE pass=3 fail=0 skip=1 ..."),
--     its log copied to CinematicDB.testQueue_<id>Log (read_log.py reads it),
--     its id kept in CinematicDB.testQueueDone so it isn't run again.
--   * A test's own Reload button: the run picks up after the reload, the
--     queue with it. A /reload of your own mid-test cuts the queue off; what's
--     left is offered again.
--   * Older tests (before the kit, Dev/TestKitWrap.lua) can be queued and
--     picked too. They never say when they're done: the queue starts the
--     command, and a strip at the top of the screen (its own spot: an older
--     test's box and buttons would cover ours) says Done when its box says
--     it's finished; Done copies its log apart and goes on.
--   * Per client (the user, 2026-11-23: "tracking for tests needing to be
--     ran on retail"): an entry's client = "forever" / "retail" / "both" /
--     "" (either). Each client runs only its own; the picker lists the rest
--     as waiting for the other client. Each client's saved file keeps its
--     own done marks, so "both" runs once on each. Result lines say client=.
--   * Report issue (on every kit test's row and the older-test strip; the
--     user, 2026-11-23: "if i have an issue with a test ... report the test
--     + step and allow me to send a message"): a box with the test and step,
--     a message, Send (keep going) or Send and skip step. It goes into the
--     test's log (ISSUE line) and the queue log ("issue client= id= test=
--     step= msg="), which testqueue.py wait prints with the result. The game
--     saves at a reload, so the session reads it after the queue's Reload.
--   * At the end: a Reload button, which saves the results for the sessions
--     (Tools/testqueue.py wait <id> sees them then).
local _, ns = ...
local Kit = ns.TestKit
if not Kit then return end

local Q = {}
ns.TestQueue = Q
local LOG_CAP = 300
local GAP = 3 -- (seconds between tests: the next one's name on the box)

local function Entries()
	return type(ns.TestQueueList) == "table" and ns.TestQueueList or {}
end

local CLIENT = ns.isRetail and "retail" or (ns.isClassicEra and "classic_era" or "forever")
Q.client = CLIENT
local CLIENT_NAME = { forever = "WoW Forever", retail = "retail", classic_era = "Classic Era", both = "both clients" }

-- Whether an entry runs on this client.
local function ForHere(entry)
	local want = entry.client or ""
	return want == "" or want == "both" or want == Q.client
end
Q.ForHere = ForHere

local function DoneIds()
	CinematicDB.testQueueDone = CinematicDB.testQueueDone or {}
	return CinematicDB.testQueueDone
end

-- (Tests picked in the panel that no session queued: kept here for the run,
-- a reload pickup too.)
local function Extra()
	CinematicDB.testQueueExtra = CinematicDB.testQueueExtra or {}
	return CinematicDB.testQueueExtra
end

local function ById(id)
	if not id then return nil end
	for _, entry in ipairs(Entries()) do
		if entry.id == id then return entry end
	end
	for _, entry in ipairs(CinematicDB.testQueueExtra or {}) do
		if entry.id == id then return entry end
	end
end

-- What a test needs from you: "off" (nothing), "you" or "unknown", and the
-- words: where to be first (the entry's or test's needs), then what it asks
-- (the first prompt, scanned by testqueue.py), then a Reload click.
function Q.Needs(name, entry)
	local def = Kit.Has(name)
	if not def and Kit.OldTest and Kit.OldTest(name) then
		local where = entry and (entry.needs or "") ~= "" and entry.needs
		return "older", (where and (where .. "; ") or "") .. "click Done when its box says it's finished"
	end
	if not def then return "unknown", "Not a kit test" end
	local cat = type(ns.TestQueueCatalog) == "table" and ns.TestQueueCatalog[name]
	local where = (entry and entry.needs ~= "" and entry.needs) or def.needs
	local parts = {}
	if where and where ~= "" then parts[#parts + 1] = tostring(where) end
	if cat then
		local asks = tonumber(cat.asks) or 0
		if asks > 0 then
			local first = tostring(cat.first or "")
			if #first > 70 then first = first:sub(1, 68) .. "..." end
			parts[#parts + 1] = (first ~= "" and ("asks: \"%s\""):format(first) or "asks you something")
				.. (asks > 1 and (" +%d more"):format(asks - 1) or "")
		end
		if (tonumber(cat.reloads) or 0) > 0 then parts[#parts + 1] = "a Reload click" end
	end
	if #parts > 0 then return "you", table.concat(parts, "; ") end
	if not cat then return "unknown", "Not scanned yet (testqueue.py catalog)" end
	return "off", "Nothing to do"
end

-- The entries not run yet, in the order queued.
function Q.Pending()
	local done, out = DoneIds(), {}
	for _, entry in ipairs(Entries()) do
		if type(entry) == "table" and entry.id and entry.test and not done[entry.id] and ForHere(entry) then
			out[#out + 1] = entry
		end
	end
	return out
end

-- Queued for the other client only: listed, not run here.
function Q.Elsewhere()
	local out = {}
	for _, entry in ipairs(Entries()) do
		if type(entry) == "table" and entry.id and entry.test and not ForHere(entry) then out[#out + 1] = entry end
	end
	return out
end

local function Note(text)
	local log = CinematicDB.testQueueLog or {}
	CinematicDB.testQueueLog = log
	log[#log + 1] = date("%Y-%m-%d %H:%M:%S") .. " " .. text
	while #log > LOG_CAP do table.remove(log, 1) end
end

local began -- (GetTime when Run all was clicked: the box's clock)
local function Box(text, sub, r, g, b)
	ns.debugNoCopyWindow = true
	if ns.PadTestBox then ns.PadTestBox(text, sub, r or 1, g or 0.82, b or 0) end
	ns.padTestRun = nil -- (the last test's timed hide leaves this box alone)
	Note("box: " .. tostring(text) .. " | " .. tostring(sub) .. (Kit.boxPrefix and (" [kit boxes: " .. tostring(Kit.boxPrefix()) .. "]") or ""))
	-- (Not the last test's "took 0:00": the queue's own time.)
	if ns.PadTestBoxClock and ns.PadTestTime then
		local from = began
		ns.PadTestBoxClock(function() return from and ("queue " .. ns.PadTestTime(GetTime() - from)) or "" end)
	end
end

local function Title(entry)
	local def = entry and Kit.Has(entry.test)
	if not entry then return "?" end
	local args, extra = entry.args or "", ""
	if args:find("full") then extra = " (every step)"
	elseif args:find("%d") then
		local steps = (args:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", ", "))
		extra = (" (step%s %s)"):format(steps:find(",") and "s" or "", steps)
	elseif args ~= "" then extra = " (" .. args .. ")" end
	local old = not def and Kit.OldTest and Kit.OldTest(entry.test)
	return (def and def.title or entry.test) .. extra .. (old and " (older test)" or "")
end

local function Short(name)
	name = tostring(name or "?")
	return #name > 34 and (name:sub(1, 32) .. "...") or name
end

local function Sessions(list)
	local seen, names = {}, {}
	for _, entry in ipairs(list) do
		local name = entry.session or "?"
		if not seen[name] then seen[name] = true; names[#names + 1] = name end
	end
	return names
end

-- One result: the line, the id kept as done, the log copied under its id.
local function Record(entry, result, run, oldKey)
	DoneIds()[entry.id] = true
	local logKey = run and (run.def.key .. "Log") or oldKey
	if logKey and type(CinematicDB[logKey]) == "table" then
		local copy = {}
		for i, line in ipairs(CinematicDB[logKey]) do copy[i] = line end
		CinematicDB["testQueue_" .. entry.id .. "Log"] = copy
	end
	Note(("client=%s id=%s test=%s session=%q result=%s log=testQueue_%sLog"):format(Q.client, entry.id, entry.test,
		tostring(entry.session or "?"), result, entry.id))
end

-- Old copies: dropped once their entry is out of the list (the session read it).
local function Tidy()
	local keep = {}
	for _, entry in ipairs(Entries()) do if entry.id then keep[entry.id] = true end end
	for key in pairs(CinematicDB) do
		local id = type(key) == "string" and key:match("^testQueue_(.+)Log$")
		if id and not keep[id] then CinematicDB[key] = nil end
	end
	local done = CinematicDB.testQueueDone
	if done then for id in pairs(done) do if not keep[id] then done[id] = nil end end end
	if not CinematicDB.testQueueRun then CinematicDB.testQueueExtra = nil end
end

local function State() return CinematicDB.testQueueRun end

-- The queue moved on since this login (a test resumed by its Reload button
-- ended, the next one started): it's going, not cut off. (The kit resumes a
-- test 2 s after the reload, Q.Login looks at 5 s: a test whose last steps
-- took under 3 s had ended by then, and Login wiped the queue under its own
-- "Wrapping up...", which then never wrapped up. The user, 2026-11-25.)
local live

-- "Queue 2/3 (Name scaling calibration)": where the queue is and whose test
-- it is (the user, 2026-11-23: "see also the session name ... so i can tell
-- what we are testing"). A long name cut to fit the box.
local function Where(state, entry)
	local name = tostring(entry and entry.session or "?")
	if #name > 34 then name = name:sub(1, 32) .. "..." end
	return ("Queue %d/%d (%s)"):format(state.index or 0, #state.ids, name)
end

-- While a queue runs: the kit's Stop queue button, and every kit box starts
-- with where the queue is (the user, 2026-11-23: "always shows what test it
-- is on"; a test's own DONE box read as the end of the queue).
local function Hook(on)
	Kit.queueStop = on and function(run) Q.Stop(run) end or nil
	Kit.queueRequeue = on and function(run) Q.Requeue(run) end or nil
	Kit.boxPrefix = on and function()
		local state = State()
		if state and state.index and state.index > 0 then return Where(state, ById(state.ids[state.index])) .. " - " end
	end or nil
end

-- The kit's run going now (one cut off by a /reload is still "current" there
-- until the next starts: not going).
local function Going()
	local run = Kit.Running()
	if run and not run.stopped then return run end
end

-- The end's buttons: Reload is a secure button (Forever blocks an addon's
-- ReloadUI), and the game neither makes nor shows one in a fight. Ended in a
-- fight (the user, 2026-11-23: "no reload button?", wolves on them), the box
-- says so and the button comes once the fight is over.
local endWatch = CreateFrame("Frame")
local function EndButtons(sub)
	endWatch:UnregisterAllEvents()
	local function Close()
		endWatch:UnregisterAllEvents()
		Kit.HideButtons()
		if ns.PadTestBoxHide then ns.PadTestBoxHide() end
	end
	if Q.InFight() then
		Q.buttons = Kit.ShowButtons({ { label = "Close", fn = Close } })
		Q.endSub = sub .. " The Reload button comes when your fight is over."
		if ns.padTestBox and ns.padTestBox.sub then ns.padTestBox.sub:SetText(Q.endSub) if ns.padTestBox.Fit then ns.padTestBox:Fit() end end
		endWatch:RegisterEvent("PLAYER_REGEN_ENABLED")
		endWatch:SetScript("OnEvent", function() EndButtons(sub) end)
		return
	end
	Q.endSub = sub
	if ns.padTestBox and ns.padTestBox.sub then ns.padTestBox.sub:SetText(sub) if ns.padTestBox.Fit then ns.padTestBox:Fit() end end
	Q.buttons = Kit.ShowButtons({ { kind = "reload" }, { label = "Close", fn = Close } })
end

function Q.Finish(how)
	local state = State()
	CinematicDB.testQueueRun = nil
	Hook(false)
	if not state then return end
	-- (Each test once: a requeued one is in ids twice.)
	local fails, ran, total, done, seen = 0, 0, 0, DoneIds(), {}
	for _, id in ipairs(state.ids) do
		if not seen[id] then
			seen[id] = true
			total = total + 1
			if state.failed and state.failed[id] then fails = fails + 1 end
			if done[id] then ran = ran + 1 end
		end
	end
	Note(("queue %s: %d of %d run, %d with a FAIL"):format(how, ran, total, fails))
	local left = #Q.Pending()
	local sub = "Reload to save the results for the sessions." .. (left > 0 and (" %d left for later."):format(left) or "")
	Box(("Test queue %s: %d of %d run, %d with a FAIL."):format(how, ran, total, fails), sub,
		fails > 0 and 1 or 0.3, fails > 0 and 0.4 or 1, 0.3)
	EndButtons(sub)
	ns.Print(("test queue %s; reload to save the results."):format(how))
end

-- Not in a fight: each test starts out of one (the user, 2026-11-23: a test
-- that needs no fight, started while you're still in the last one's, fails
-- on what the game blocks in fights). A test that needs a fight asks for
-- one after it starts. Start anyway on the box skips the wait.
local fightWatch = CreateFrame("Frame")
function Q.InFight()
	local ok, lock = pcall(InCombatLockdown)
	local ok2, combat = pcall(UnitAffectingCombat, "player")
	return (ok and lock == true) or (ok2 and combat == true)
end

local function FightOver(force)
	fightWatch:UnregisterAllEvents()
	local state = State()
	if not state or state.stopped or not state.waitingFight then return end
	Note(("%s: id=%s"):format(force and "started anyway in the fight" or "fight over, starting", state.waitingFight))
	state.waitingFight = nil
	state.fightOk = force or nil
	Kit.HideButtons()
	state.index = state.index - 1 -- (Next takes the same one again)
	Q.Next()
end

function Q.WaitFight(state, entry)
	state.waitingFight = entry.id
	Note(("waiting for the fight to end before id=%s (%d/%d)"):format(entry.id, state.index, #state.ids))
	Box(("%s - %s"):format(Where(state, entry), Title(entry)),
		"Waiting for your fight to end: it starts as soon as you're out of combat.", 1, 0.6, 0.3)
	Q.buttons = Kit.ShowButtons({ { label = "Start anyway", fn = function() FightOver(true) end },
		{ label = "Stop queue", fn = function() Q.Stop() end } })
	fightWatch:RegisterEvent("PLAYER_REGEN_ENABLED")
	fightWatch:SetScript("OnEvent", function() FightOver(false) end)
end

function Q.Next()
	local state = State()
	if not state or state.stopped then return end
	if Going() then return end -- (one at a time)
	live = true
	state.index = (state.index or 0) + 1
	local id = state.ids[state.index]
	if not id then return Q.Finish("done") end
	local entry = ById(id)
	if not entry then return Q.Next() end
	if (Kit.Has(entry.test) or (Kit.OldTest and Kit.OldTest(entry.test))) and not state.fightOk and Q.InFight() then
		return Q.WaitFight(state, entry)
	end
	state.fightOk = nil
	if not Kit.Has(entry.test) and Kit.OldTest and Kit.OldTest(entry.test) then
		return Q.StartOld(state, entry)
	end
	if not Kit.Has(entry.test) then
		Record(entry, "NOT-A-KIT-TEST")
		state.failed = state.failed or {}
		state.failed[id] = true
		return Q.Next()
	end
	state.current = id
	local kind, words = Q.Needs(entry.test, entry)
	Box(("%s - %s"):format(Where(state, entry), Title(entry)),
		-- (Unknown said as unknown, not "Needs you": the 10:31 run, no catalog.)
		("%s. From %s%s. Starting..."):format(kind == "off" and "Hands off: nothing to do"
			or kind == "you" and ("Needs you: " .. words) or ("Not known if it needs you (" .. words .. ")"),
			entry.session or "?", entry.note and entry.note ~= "" and (" (" .. entry.note .. ")") or ""),
		kind == "off" and 0.4 or 1, kind == "off" and 1 or 0.82, kind == "off" and 0.55 or 0)
	Kit.ShowButtons({ { label = "Stop queue", fn = function() Q.Stop() end } })
	C_Timer.After(GAP, function()
		local now = State()
		if now ~= state or state.stopped or state.current ~= id or Going() then return end
		Kit.HideButtons()
		Note(("start id=%s test=%s args=%q (%d/%d)"):format(id, entry.test, entry.args or "", state.index, #state.ids))
		Kit.Start(entry.test, entry.args or "")
		-- (A test with nothing to wait for ends inside Kit.Start: onFinish
		-- recorded it and cleared current, the next is on its way. kitcheck
		-- 1 2 got a second, DID-NOT-START line, 2026-11-23.)
		if state.current == id and not Going() then
			Record(entry, "DID-NOT-START")
			state.current = nil
			Q.Next()
		end
	end)
end

-- An older test going: the strip at the top --------------------------------------
local strip
local function Strip()
	if strip then return strip end
	strip = CreateFrame("Frame")
	strip:SetFrameStrata("FULLSCREEN_DIALOG")
	strip:SetSize(940, 40)
	strip:SetPoint("TOP", UIParent, "TOP", 0, -14)
	local edge = strip:CreateTexture(nil, "BACKGROUND", nil, -8)
	edge:SetPoint("TOPLEFT", -2, 2)
	edge:SetPoint("BOTTOMRIGHT", 2, -2)
	edge:SetColorTexture(0.55, 0.7, 1, 1)
	local fill = strip:CreateTexture(nil, "BACKGROUND", nil, -7)
	fill:SetAllPoints()
	fill:SetColorTexture(0.035, 0.035, 0.045, 1)
	strip.text = strip:CreateFontString(nil, "OVERLAY")
	local ok, font = pcall(function() return (_G.GameFontNormal:GetFont()) end)
	strip.text:SetFont(ok and font or "Fonts\\FRIZQT__.TTF", 13, "")
	strip.text:SetJustifyH("LEFT")
	strip.text:SetPoint("LEFT", 14, 0)
	strip.text:SetWidth(560)
	strip.done = CreateFrame("Button", nil, strip, "UIPanelButtonTemplate")
	strip.done:SetSize(110, 26)
	strip.done:SetText("Done")
	strip.done:SetScript("OnClick", function() Q.OldDone() end)
	strip.stop = CreateFrame("Button", nil, strip, "UIPanelButtonTemplate")
	strip.stop:SetSize(104, 26)
	strip.stop:SetText("Stop queue")
	strip.stop:SetPoint("RIGHT", strip, "RIGHT", -8, 0)
	strip.stop:SetScript("OnClick", function() Q.Stop() end)
	strip.done:SetPoint("RIGHT", strip.stop, "LEFT", -6, 0)
	strip.report = CreateFrame("Button", nil, strip, "UIPanelButtonTemplate")
	strip.report:SetSize(110, 26)
	strip.report:SetText("Report issue")
	strip.report:SetPoint("RIGHT", strip.done, "LEFT", -6, 0)
	strip.report:SetScript("OnClick", function()
		local state = State()
		local entry = state and state.old and ById(state.current)
		if entry then Q.OpenReport({ entry = entry }) end
	end)
	return strip
end
local function ShowStrip(state, entry)
	local bar = Strip()
	bar:SetScale(UIParent:GetEffectiveScale())
	bar.text:SetText(("%s - |cffffffff%s|r\n|cff9fb8ffWhen its box says it's finished, click Done.|r"):format(
		Where(state, entry), Title(entry)))
	bar:Show()
	Q.strip = bar
end
local function HideStrip() if strip then strip:Hide() end end
Q.HideStrip = HideStrip

-- Report an issue -----------------------------------------------------------------
local report
local function ReportBox()
	if report then return report end
	report = CreateFrame("Frame")
	report:SetFrameStrata("FULLSCREEN_DIALOG")
	report:SetFrameLevel(200)
	report:SetSize(580, 250)
	report:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
	report:EnableMouse(true)
	local edge = report:CreateTexture(nil, "BACKGROUND", nil, -8)
	edge:SetPoint("TOPLEFT", -2, 2)
	edge:SetPoint("BOTTOMRIGHT", 2, -2)
	edge:SetColorTexture(1, 0.45, 0.35, 1)
	local fill = report:CreateTexture(nil, "BACKGROUND", nil, -7)
	fill:SetAllPoints()
	fill:SetColorTexture(0.035, 0.035, 0.045, 1)
	local ok, font = pcall(function() return (_G.GameFontNormal:GetFont()) end)
	font = ok and font or "Fonts\\FRIZQT__.TTF"
	report.title = report:CreateFontString(nil, "OVERLAY")
	report.title:SetFont(font, 18, "")
	report.title:SetPoint("TOPLEFT", 20, -16)
	report.title:SetText("Report an issue with this test")
	report.what = report:CreateFontString(nil, "OVERLAY")
	report.what:SetFont(font, 13, "")
	report.what:SetTextColor(0.75, 0.75, 0.75)
	report.what:SetJustifyH("LEFT")
	report.what:SetWidth(540)
	report.what:SetPoint("TOPLEFT", 20, -44)
	-- (The typing box sits under the "what" text, however many lines it wraps to;
	-- Q.OpenReport grows the box to fit.)
	local back = report:CreateTexture(nil, "BORDER")
	back:SetColorTexture(1, 1, 1, 0.07)
	back:SetPoint("TOPLEFT", report.what, "BOTTOMLEFT", 0, -10)
	back:SetSize(540, 86)
	report.back = back
	report.input = CreateFrame("EditBox", nil, report)
	report.input:SetMultiLine(true)
	report.input:SetFont(font, 14, "")
	report.input:SetTextColor(1, 1, 1)
	report.input:SetAutoFocus(false)
	report.input:SetMaxLetters(400)
	report.input:SetSize(528, 80)
	report.input:SetPoint("TOPLEFT", back, "TOPLEFT", 6, -4)
	report.input:SetScript("OnEscapePressed", function() Q.CloseReport() end)
	report.hint = report:CreateFontString(nil, "OVERLAY")
	report.hint:SetFont(font, 12, "")
	report.hint:SetTextColor(0.5, 0.5, 0.5)
	report.hint:SetPoint("TOPLEFT", back, "BOTTOMLEFT", 0, -6)
	report.hint:SetText("What's wrong? The session that made the test reads it after your next reload.")
	report.buttons = {}
	local function Button(label, width, fn)
		local button = CreateFrame("Button", nil, report, "UIPanelButtonTemplate")
		button:SetSize(width, 28)
		button:SetText(label)
		button:SetScript("OnClick", fn)
		report.buttons[label] = button
		return button
	end
	local cancel = Button("Cancel", 90, function() Q.CloseReport() end)
	cancel:SetPoint("BOTTOMRIGHT", report, "BOTTOMRIGHT", -16, 14)
	local skip = Button("Send and skip step", 160, function() Q.SendReport(true) end)
	skip:SetPoint("RIGHT", cancel, "LEFT", -8, 0)
	local send = Button("Send, keep going", 150, function() Q.SendReport(false) end)
	send:SetPoint("RIGHT", skip, "LEFT", -8, 0)
	return report
end

-- ctx: { run = a kit run } or { entry = an older test's queue entry }.
function Q.OpenReport(ctx)
	local box = ReportBox()
	box.ctx = ctx
	local what
	local run = ctx.run
	if run then
		what = ("|cffffffff%s|r, step %s/%d%s"):format(run.def.title or run.def.name, tostring(run.stepNumber or "-"),
			#run.def.steps, run.step and (" (" .. tostring(run.step.key) .. ")") or "")
		if run.asked then what = what .. "\n|cff9a9a9aIt asked: " .. run.asked .. "|r" end
	else
		what = ("|cffffffff%s|r, an older test (no steps the queue can see)"):format(Title(ctx.entry))
	end
	local state = State()
	local entry = ctx.entry or (state and state.current and ById(state.current))
	if entry then what = what .. ("\n|cff9a9a9aQueued by %s|r"):format(tostring(entry.session or "?")) end
	box.entry = entry
	box.what:SetText(what)
	-- 44 above the text, 10 gap, 86 typing box, ~20 hint, ~54 buttons and margin.
	box:SetHeight(math.max(250, 44 + (box.what:GetStringHeight() or 0) + 10 + 86 + 20 + 54))
	box.input:SetText("")
	box.buttons["Send and skip step"]:SetShown(run ~= nil and run.step ~= nil)
	box:SetScale(UIParent:GetEffectiveScale())
	box:Show()
	box.input:SetFocus()
	Q.reportBox = box
	return box
end

function Q.CloseReport()
	if report then
		report.input:ClearFocus()
		report:Hide()
	end
end

function Q.SendReport(skip)
	local box = report
	if not (box and box.ctx) then return end
	local msg = (box.input:GetText() or ""):gsub("[\r\n]+", " "):gsub("^%s+", ""):gsub("%s+$", "")
	if msg == "" then msg = "(no message)" end
	local run, entry = box.ctx.run, box.entry
	local test = run and run.def.name or (entry and entry.test) or "?"
	local step = run and (("%s/%d:%s"):format(tostring(run.stepNumber or "-"), #run.def.steps,
		tostring(run.step and run.step.key or "-"))) or "older"
	if run and Kit.Running() == run then
		run:Log(("ISSUE reported by you at step %s: %s%s"):format(step, msg,
			run.asked and (" (it asked: " .. run.asked .. ")") or ""))
	end
	Note(("issue client=%s id=%s test=%s step=%s msg=%q"):format(Q.client, entry and entry.id or "-", test, step, msg))
	Q.CloseReport()
	ns.Print("issue noted for " .. test .. (entry and (", " .. tostring(entry.session or "")) or "")
		.. ": the session reads it after your next reload.")
	if skip and run and Kit.Running() == run and not run.stopped then run:SkipStep() end
end

Kit.reportIssue = function(run) Q.OpenReport({ run = run }) end

-- (Its run, through Slash.lua like a typed command. Offline checks swap it.)
Q.RunOld = function(test, args)
	if ns.HandleSlash then ns.HandleSlash("debug " .. test .. (args ~= "" and (" " .. args) or "")) end
end

function Q.StartOld(state, entry)
	state.current, state.old = entry.id, true
	local _, words = Q.Needs(entry.test, entry)
	Box(("%s - %s"):format(Where(state, entry), Title(entry)),
		("Older test: %s. From %s%s. Starting..."):format(words, entry.session or "?",
			entry.note and entry.note ~= "" and (" (" .. entry.note .. ")") or ""), 0.55, 0.7, 1)
	Kit.ShowButtons({ { label = "Stop queue", fn = function() Q.Stop() end } })
	C_Timer.After(GAP, function()
		local now = State()
		if now ~= state or state.stopped or state.current ~= entry.id then return end
		Kit.HideButtons()
		Note(("start id=%s test=%s args=%q (%d/%d, older test)"):format(entry.id, entry.test, entry.args or "",
			state.index, #state.ids))
		ShowStrip(state, entry)
		local ok, err = pcall(Q.RunOld, entry.test, entry.args or "")
		if not ok then Note("  its command failed: " .. tostring(err)) end
	end)
end

-- Done on the strip: its log copied apart (PASS / FAIL counted), on to the next.
local function OldResult(entry, how)
	local old = Kit.OldTest(entry.test) or {}
	local pass, fail = 0, 0
	for _, line in ipairs(old.logKey and CinematicDB[old.logKey] or {}) do
		if type(line) == "string" and not line:find("verdicts:", 1, true) then
			if line:find("%f[%w]PASS%f[%W]") then pass = pass + 1 end
			if line:find("%f[%w]FAIL%f[%W]") then fail = fail + 1 end
		end
	end
	Record(entry, ("%s pass=%d fail=%d (older test, %s)"):format(how == "done" and "RAN" or "STOPPED", pass, fail,
		how == "done" and "Done clicked" or "the queue stopped; it may still be going: type its command again to stop it"),
		nil, old.logKey)
	return pass, fail
end

function Q.OldDone()
	local state = State()
	if not (state and state.old and state.current) then HideStrip() return end
	local entry = ById(state.current)
	state.current, state.old = nil, nil
	HideStrip()
	if not entry then return Q.Next() end
	local pass, fail = OldResult(entry, "done")
	if fail > 0 then state.failed = state.failed or {}; state.failed[entry.id] = true end
	local nextEntry = ById(state.ids[(state.index or 0) + 1])
	Box(("%s - %s done: %d PASS, %d FAIL lines."):format(Where(state, entry), Title(entry), pass, fail),
		nextEntry and ("Next: %s, from %s. Starting in a moment..."):format(Title(nextEntry), tostring(nextEntry.session or "?"))
			or "That was the last one. Wrapping up...",
		fail > 0 and 1 or 0.3, fail > 0 and 0.4 or 1, 0.3)
	C_Timer.After(GAP, Q.Next)
end

function Q.Stop(run)
	local state = State()
	if not state then return end
	state.stopped = true
	fightWatch:UnregisterAllEvents()
	state.waitingFight = nil
	if state.old and state.current then
		local entry = ById(state.current)
		state.current, state.old = nil, nil
		HideStrip()
		if entry then OldResult(entry, "stopped") end
	end
	if run and Going() == run then
		Kit.Finish(run, false) -- (onFinish records it, then sees stopped)
	end
	Q.Finish("stopped")
end

-- Requeue (the user, 2026-11-23: "in case i mess up a test"): the test going
-- is stopped with no result line and no done mark, and put back at the end of
-- this queue; the next one starts. Stop queue before it comes round leaves it
-- waiting for the next /reload, like any test not run.
function Q.Requeue(run)
	local state = State()
	if not (state and state.current and not state.stopped) then return end
	local entry = ById(state.current)
	if not entry or (run and entry.test ~= run.def.name) then return end
	state.current = nil -- (onFinish passes it by: nothing recorded)
	state.ids[#state.ids + 1] = entry.id
	Note(("requeued by you: id=%s test=%s at step %s (%d/%d), runs again at the end"):format(entry.id, entry.test,
		tostring(run and run.stepNumber or "-"), state.index or 0, #state.ids))
	if run and Going() == run then
		run:Log("REQUEUED by you at step " .. tostring(run.stepNumber or "-") .. ": this run doesn't count")
		Kit.Finish(run, false)
	end
	local nextEntry = ById(state.ids[(state.index or 0) + 1])
	Box(("%s - %s requeued: it runs again at the end."):format(Where(state, entry), Title(entry)),
		nextEntry and nextEntry ~= entry and ("Next: %s, from %s. Starting in a moment..."):format(Title(nextEntry),
			tostring(nextEntry.session or "?")) or "Running it again in a moment...", 1, 0.82, 0)
	Kit.ShowButtons({ { label = "Stop queue", fn = function() Q.Stop() end } })
	C_Timer.After(GAP, Q.Next)
end

-- The kit's end of a run: this queue's, if it's the one going.
Kit.onFinish = function(run, done, summary)
	local state = State()
	if not (state and state.current) then return end
	local entry = ById(state.current)
	if not entry or entry.test ~= run.def.name then return end
	state.current = nil
	live = true
	if run.fail > 0 then state.failed = state.failed or {}; state.failed[entry.id] = true end
	Record(entry, ("%s pass=%d fail=%d skip=%d (%s)"):format(done and "DONE" or "STOPPED", run.pass, run.fail, run.skip,
		tostring(summary or "")), run)
	if state.stopped then return end
	-- (Between tests: this one's result and what comes next, never "/reload".)
	local nextEntry = ById(state.ids[(state.index or 0) + 1])
	Box(("%s - %s %s: %d pass, %d fail, %d skip."):format(Where(state, entry), Title(entry),
		done and "done" or "stopped", run.pass, run.fail, run.skip),
		nextEntry and ("Next: %s, from %s (%s). Starting in a moment..."):format(Title(nextEntry), tostring(nextEntry.session or "?"),
			({ off = "hands off", you = "needs you" })[Q.Needs(nextEntry.test, nextEntry)] or "not known if it needs you")
			or "That was the last one. Wrapping up...",
		run.fail > 0 and 1 or 0.3, run.fail > 0 and 0.4 or 1, 0.3)
	Kit.ShowButtons(nextEntry and { { label = "Stop queue", fn = function() Q.Stop() end } } or {})
	C_Timer.After(GAP, Q.Next)
end

-- Runs the given entries (default: every queued one) in order.
function Q.Start(list)
	if Going() or State() then
		ns.Print("test queue: a test is running; stop it first.")
		return
	end
	list = list or Q.Pending()
	if #list == 0 then
		ns.Print("test queue: nothing to run.")
		return
	end
	local ids = {}
	for i, entry in ipairs(list) do ids[i] = entry.id end
	CinematicDB.testQueueRun = { ids = ids, index = 0 }
	began = GetTime()
	Hook(true)
	Note(("queue start: %d test(s) from %s"):format(#ids, table.concat(Sessions(list), ", ")))
	Q.Next()
end

-- The picker -------------------------------------------------------------------
-- (The user, 2026-11-23: "let justified", "say if i need any input or need to
-- be in a place", "show all possible test", "run groups of tests ... ones that
-- dont require any input or ... one that does", "really make it look nice".)
-- A panel of its own: the queued tests first, then every other kit test, one
-- row each: a check box, the test, whose it is, a Hands off / Needs you pill,
-- and under it what it needs (where to be, what it asks). Check groups with
-- the buttons at the bottom, Run checked.
local W, ROW_H, VISIBLE, TOP, BOTTOM = 800, 40, 9, 76, 60
local PILL = {
	off = { "Hands off", 0.35, 0.85, 0.45 },
	you = { "Needs you", 1, 0.72, 0.2 },
	unknown = { "Unknown", 0.6, 0.6, 0.6 },
	older = { "Older test", 0.55, 0.7, 1 },
	elsewhere = { "Other client", 0.75, 0.55, 1 },
}
local panel, open
local model = { items = {}, checked = {}, offset = 0 }

local function FontPath()
	local ok, path = pcall(function() return (_G.GameFontNormal:GetFont()) end)
	return ok and path or "Fonts\\FRIZQT__.TTF"
end

local function Text(parent, size, r, g, b, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	fs:SetFont(FontPath(), size, "")
	fs:SetTextColor(r, g, b)
	fs:SetJustifyH("LEFT")
	if fs.SetWordWrap then fs:SetWordWrap(false) end
	return fs
end

-- (sub: the draw order inside a layer. The gold edge and the dark fill both
-- sat on BACKGROUND 0 and the edge drew on top: a yellow panel, 2026-11-23.)
local function Fill(parent, layer, r, g, b, a, sub)
	local tex = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
	tex:SetColorTexture(r, g, b, a or 1)
	return tex
end

local function Key(item) return item.entry and item.entry.id or ("t:" .. item.name) end

local function CheckedCount()
	local n = 0
	for _, item in ipairs(model.items) do
		if item.kind == "test" and model.checked[Key(item)] then n = n + 1 end
	end
	return n
end

local Refresh -- (below)

local function MakeRow(i)
	local row = CreateFrame("Button", nil, panel)
	row:SetSize(W - 24, ROW_H)
	row:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, -(TOP + (i - 1) * ROW_H))
	row.hl = Fill(row, "HIGHLIGHT", 1, 1, 1, 0.05)
	row.hl:SetAllPoints()
	row.line = Fill(row, "BORDER", 1, 1, 1, 0.06)
	row.line:SetPoint("BOTTOMLEFT", 10, 0)
	row.line:SetPoint("BOTTOMRIGHT", -4, 0)
	row.line:SetHeight(1)
	row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
	row.check:SetSize(24, 24)
	row.check:SetPoint("LEFT", row, "LEFT", 10, 0)
	row.title = Text(row, 15, 1, 1, 1)
	row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 42, -5)
	row.title:SetWidth(W - 170)
	row.detail = Text(row, 12, 0.55, 0.55, 0.55)
	row.detail:SetPoint("TOPLEFT", row, "TOPLEFT", 42, -23)
	row.detail:SetWidth(W - 80)
	row.pill = CreateFrame("Frame", nil, row)
	row.pill:SetSize(84, 20)
	row.pill:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -4)
	row.pill.back = Fill(row.pill, "BACKGROUND", 1, 1, 1, 0.15)
	row.pill.back:SetAllPoints()
	row.pill.text = Text(row.pill, 12, 1, 1, 1)
	row.pill.text:SetPoint("CENTER")
	if row.pill.text.SetJustifyH then row.pill.text:SetJustifyH("CENTER") end
	row.header = Text(row, 13, 1, 0.82, 0)
	row.header:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 12, 7)
	local function Toggle()
		local item = row.item
		if not item or item.kind == "header" then return end
		local key = Key(item)
		model.checked[key] = not model.checked[key] or nil
		Refresh()
	end
	row.Toggle = Toggle
	row:SetScript("OnClick", Toggle)
	row.check:SetScript("OnClick", Toggle)
	row:SetScript("OnEnter", function(self)
		local item = self.item
		if not item or item.kind == "header" or not GameTooltip then return end
		local def = Kit.Has(item.name)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(Title(item.entry or { test = item.name }), 1, 1, 1)
		if def and def.about then GameTooltip:AddLine(def.about, 0.8, 0.8, 0.8, true) end
		local _, words = Q.Needs(item.name, item.entry)
		GameTooltip:AddLine(words, 1, 0.82, 0, true)
		GameTooltip:AddLine("/cine debug " .. item.name .. (item.entry and (item.entry.args or "") ~= "" and (" " .. item.entry.args) or ""),
			0.5, 0.5, 0.5)
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	return row
end

local function ShowRow(row, item)
	row.item = item
	if not item then row:Hide() return end
	row:Show()
	if item.kind == "elsewhere" then
		-- (Queued for the other client: shown, not checkable here.)
		row:Show()
		row.header:Hide()
		row.check:Hide()
		row.title:Show()
		row.detail:Show()
		row.pill:Show()
		row.line:Show()
		row:EnableMouse(false)
		row.title:SetText("|cff9a9a9a" .. Title(item.entry) .. "|r")
		row.detail:SetText(("|cffc8c8c8from %s|r  |cff4a4a4a-|r  |cffb48cffrun it on %s|r%s"):format(Short(item.entry.session),
			CLIENT_NAME[item.entry.client] or item.entry.client,
			(item.entry.note or "") ~= "" and ("  |cff4a4a4a-|r  |cff6e6e6e" .. item.entry.note .. "|r") or ""))
		local name = item.entry.client == "retail" and "Retail" or item.entry.client == "forever" and "Forever"
			or tostring(item.entry.client)
		row.pill.text:SetText(name)
		row.pill.text:SetTextColor(0.75, 0.55, 1)
		row.pill.back:SetColorTexture(0.75, 0.55, 1, 0.16)
		return
	end
	local header = item.kind == "header"
	row.header:SetShown(header)
	row.check:SetShown(not header)
	row.title:SetShown(not header)
	row.detail:SetShown(not header)
	row.pill:SetShown(not header)
	row.line:SetShown(not header)
	if header then
		row.header:SetText(item.text)
		row:EnableMouse(false)
		return
	end
	row:EnableMouse(true)
	row.check:SetChecked(model.checked[Key(item)] and true or false)
	row.title:SetText(Title(item.entry or { test = item.name }))
	local kind, words = Q.Needs(item.name, item.entry)
	local def = Kit.Has(item.name)
	if kind == "off" and def then words = ("Nothing to do, %d step%s"):format(#def.steps, #def.steps == 1 and "" or "s") end
	if kind == "older" then
		local old = Kit.OldTest(item.name)
		words = words .. (old and old.file and ("  |cff5a5a5a" .. old.file .. "|r") or "")
	end
	-- (Line 2: whose, what it needs, the session's note.)
	local parts = {}
	if item.entry then parts[#parts + 1] = "|cffc8c8c8from " .. Short(item.entry.session) .. "|r" end	parts[#parts + 1] = (kind == "you" and "|cffe6b85a" or "|cff8c8c8c") .. words .. "|r"
	if item.entry and (item.entry.note or "") ~= "" then parts[#parts + 1] = "|cff6e6e6e" .. item.entry.note .. "|r" end
	row.detail:SetText(table.concat(parts, "  |cff4a4a4a-|r  "))
	local pill = PILL[kind]
	row.pill.text:SetText(pill[1])
	row.pill.text:SetTextColor(pill[2], pill[3], pill[4])
	row.pill.back:SetColorTexture(pill[2], pill[3], pill[4], 0.16)
end

Refresh = function()
	if not panel then return end
	local items = model.items
	local maxOffset = math.max(0, #items - VISIBLE)
	model.offset = math.max(0, math.min(model.offset, maxOffset))
	for i, row in ipairs(panel.rows) do ShowRow(row, items[model.offset + i]) end
	-- (The scroll bar: only when there's more than fits.)
	local track = panel.track
	if maxOffset > 0 then
		local height = VISIBLE * ROW_H
		local thumb = math.max(24, height * VISIBLE / #items)
		panel.thumb:SetHeight(thumb)
		panel.thumb:ClearAllPoints()
		panel.thumb:SetPoint("TOP", track, "TOP", 0, -(height - thumb) * model.offset / maxOffset)
		track:Show()
		panel.thumb:Show()
	else
		track:Hide()
		panel.thumb:Hide()
	end
	local n = CheckedCount()
	panel.run:SetText(n > 0 and ("Run checked (%d)"):format(n) or "Run checked")
	if panel.run.SetEnabled then panel.run:SetEnabled(n > 0) end
	local queued, offs = 0, 0
	local olds = 0
	for _, item in ipairs(items) do if item.kind == "test" and not Kit.Has(item.name) and Kit.OldTest(item.name) then olds = olds + 1 end end
	for _, item in ipairs(items) do
		if item.kind == "test" then
			if item.entry then queued = queued + 1 end
			if Q.Needs(item.name, item.entry) == "off" then offs = offs + 1 end
		end
	end
	local away = #Q.Elsewhere()
	panel.sub:SetText(("|cffffffff%s|r  |cff4a4a4a|||r  %d queued here%s  |cff4a4a4a|||r  %d kit tests, %d older  |cff4a4a4a|||r  %d hands off  |cff4a4a4a|||r  |cffffd100%d checked|r")
		:format(CLIENT_NAME[Q.client] or Q.client, queued, away > 0 and (", |cffb48cff%d for the other client|r"):format(away) or "",
			#Kit.Names(), olds, offs, n))
end

local function Build()
	panel = CreateFrame("Frame")
	panel:SetFrameStrata("FULLSCREEN_DIALOG")
	panel:SetSize(W, TOP + VISIBLE * ROW_H + BOTTOM)
	panel:SetPoint("TOP", UIParent, "TOP", 0, -100)
	panel:EnableMouse(true)
	panel:SetMovable(true)
	panel:RegisterForDrag("LeftButton")
	panel:SetScript("OnDragStart", panel.StartMoving)
	panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
	local edge = Fill(panel, "BACKGROUND", 1, 0.82, 0, 1, -8)
	edge:SetPoint("TOPLEFT", -2, 2)
	edge:SetPoint("BOTTOMRIGHT", 2, -2)
	local fill = Fill(panel, "BACKGROUND", 0.035, 0.035, 0.045, 1, -7)
	fill:SetAllPoints()
	local band = Fill(panel, "BORDER", 1, 1, 1, 0.04)
	band:SetPoint("TOPLEFT")
	band:SetPoint("TOPRIGHT")
	band:SetHeight(TOP - 8)
	local foot = Fill(panel, "BORDER", 1, 1, 1, 0.04)
	foot:SetPoint("BOTTOMLEFT")
	foot:SetPoint("BOTTOMRIGHT")
	foot:SetHeight(BOTTOM - 6)
	panel.title = Text(panel, 22, 1, 1, 1)
	panel.title:SetPoint("TOPLEFT", 20, -14)
	panel.title:SetText("Test queue")
	panel.sub = Text(panel, 13, 0.62, 0.62, 0.62)
	panel.sub:SetPoint("TOPLEFT", 20, -44)
	local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -2, -2)
	close:SetScript("OnClick", function() Q.Close() end)
	panel.rows = {}
	for i = 1, VISIBLE do panel.rows[i] = MakeRow(i) end
	panel.track = Fill(panel, "ARTWORK", 1, 1, 1, 0.06)
	panel.track:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -TOP)
	panel.track:SetSize(4, VISIBLE * ROW_H)
	panel.thumb = Fill(panel, "OVERLAY", 1, 0.82, 0, 0.7)
	panel.thumb:SetWidth(4)
	panel:EnableMouseWheel(true)
	Q.panelWheel = function(delta)
		model.offset = model.offset - delta
		Refresh()
	end
	panel:SetScript("OnMouseWheel", function(_, delta) Q.panelWheel(delta) end)
	-- The groups: each checks just those.
	local label = Text(panel, 13, 0.62, 0.62, 0.62)
	label:SetPoint("BOTTOMLEFT", 20, 22)
	label:SetText("Check:")
	panel.buttons = {}
	local function Pick(fn)
		for _, item in ipairs(model.items) do
			if item.kind == "test" then model.checked[Key(item)] = fn(item) or nil end
		end
		Refresh()
	end
	local groups = {
		{ "Hands off", function(item) return Q.Needs(item.name, item.entry) == "off" end },
		{ "Needs me", function(item) return Q.Needs(item.name, item.entry) == "you" end },
		{ "Queued", function(item) return item.entry ~= nil end },
		{ "None", function() return false end },
	}
	local x = 70
	for _, group in ipairs(groups) do
		local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
		button:SetSize(96, 24)
		button:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", x, 17)
		button:SetText(group[1])
		local fn = group[2]
		button:SetScript("OnClick", function() Pick(fn) end)
		panel.buttons[group[1]] = button
		x = x + 102
	end
	panel.run = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	panel.run:SetSize(170, 30)
	panel.run:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -18, 14)
	panel.run:SetScript("OnClick", function() Q.RunChecked() end)
	panel.buttons["Run checked"] = panel.run
	local later = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	later:SetSize(96, 30)
	later:SetPoint("RIGHT", panel.run, "LEFT", -8, 0)
	later:SetText("Not now")
	later:SetScript("OnClick", function() Q.Close() end)
	panel.buttons["Not now"] = later
end

function Q.Close()
	open = false
	if panel then panel:Hide() end
end
function Q.IsOpen() return open and true or false end

-- The checked ones, in the panel's order, then run.
function Q.RunChecked()
	local list = {}
	for _, item in ipairs(model.items) do
		if item.kind == "test" and model.checked[Key(item)] then
			if item.entry then
				list[#list + 1] = item.entry
			else
				local entry = { id = ("u%04x"):format(math.random(0, 0xffff)), test = item.name, args = "",
					session = "You (picked in game)" }
				local extra = Extra()
				extra[#extra + 1] = entry
				list[#list + 1] = entry
			end
		end
	end
	if #list == 0 then return end
	Q.Close()
	Q.Start(list)
end

-- Opens the picker (not while a run goes). Returns its buttons by label.
function Q.Open(sound)
	if Going() or State() then return nil end
	if not panel then Build() end
	Kit.HideButtons()
	if ns.PadTestBoxHide then ns.PadTestBoxHide() end
	local items, queuedNames = {}, {}
	local pending = Q.Pending()
	items[#items + 1] = { kind = "header", text = ("QUEUED FOR %s  (%d)"):format((CLIENT_NAME[Q.client] or Q.client):upper(), #pending) }
	model.checked = {}
	for _, entry in ipairs(pending) do
		items[#items + 1] = { kind = "test", name = entry.test, entry = entry }
		model.checked[entry.id] = true
		queuedNames[entry.test] = true
	end
	if #pending == 0 then items[#items + 1] = { kind = "header", text = "|cff7a7a7aNothing queued here: pick any test below.|r" } end
	local away = Q.Elsewhere()
	if #away > 0 then
		local clients = {}
		for _, entry in ipairs(away) do clients[CLIENT_NAME[entry.client] or entry.client] = true end
		local names = {}
		for name in pairs(clients) do names[#names + 1] = name end
		table.sort(names)
		items[#items + 1] = { kind = "header", text = ("WAITING FOR %s  (%d)"):format(table.concat(names, ", "):upper(), #away) }
		for _, entry in ipairs(away) do
			items[#items + 1] = { kind = "elsewhere", name = entry.test, entry = entry }
			queuedNames[entry.test] = true
		end
	end
	local others = {}
	for _, name in ipairs(Kit.Names()) do
		if not queuedNames[name] then others[#others + 1] = name end
	end
	table.sort(others, function(a, b) return tostring(Kit.Has(a).title):lower() < tostring(Kit.Has(b).title):lower() end)
	items[#items + 1] = { kind = "header", text = ("ALL OTHER KIT TESTS  (%d)"):format(#others) }
	for _, name in ipairs(others) do items[#items + 1] = { kind = "test", name = name } end
	-- (The older tests last: each needs a Done click, so no group checks them.)
	local olds = {}
	for _, old in ipairs(Kit.OldTests and Kit.OldTests() or {}) do
		if not queuedNames[old.cmd] and not Kit.Has(old.cmd) then olds[#olds + 1] = old.cmd end
	end
	table.sort(olds)
	if #olds > 0 then
		items[#items + 1] = { kind = "header", text = ("OLDER TESTS  (%d)  |cff7a7a7aclick Done on each when its box says it's finished|r"):format(#olds) }
		for _, name in ipairs(olds) do items[#items + 1] = { kind = "test", name = name } end
	end
	model.items, model.offset = items, 0
	panel:SetScale(UIParent:GetEffectiveScale())
	Refresh()
	panel:Show()
	open = true
	if sound and PlaySound then pcall(PlaySound, type(SOUNDKIT) == "table" and SOUNDKIT.READY_CHECK or 8960) end
	Q.buttons, Q.rows, Q.model = panel.buttons, panel.rows, model
	return panel.buttons
end
Q.Offer = Q.Open

-- After a /reload: a run picked up by its test's Reload button goes on; a
-- run cut off otherwise ends here and what's left is offered again.
function Q.Login()
	if not CinematicDB then return end
	Tidy()
	local state = State()
	if state then
		local running = Going()
		local entry = state.current and ById(state.current)
		if running and entry and running.def.name == entry.test then
			Hook(true)
			Note(("picked up after the reload: id=%s (%d/%d)"):format(entry.id, state.index or 0, #state.ids))
			return
		end
		if live then
			Hook(true)
			Note(("after the reload, the queue had already moved on: %d/%d"):format(state.index or 0, #state.ids))
			return
		end
		if entry and state.old then
			-- (An older test may reload on its own: it goes on, the strip back.)
			Hook(true)
			ShowStrip(state, entry)
			Note(("after a reload, older test still going: id=%s (%d/%d)"):format(entry.id, state.index or 0, #state.ids))
			return
		end
		if entry then Record(entry, "CUT-OFF (a /reload mid-test)") end
		Note("queue cut off by a /reload")
		CinematicDB.testQueueRun = nil
		Hook(false)
	end
	if #Q.Pending() > 0 then Q.Open(true) end
end

do
	local login = CreateFrame("Frame")
	login:RegisterEvent("PLAYER_ENTERING_WORLD")
	Q.ResetLogin = function() live = nil login:RegisterEvent("PLAYER_ENTERING_WORLD") end
	login:SetScript("OnEvent", function(self, _, isLogin, isReload)
		if isLogin == false and isReload == false then return end -- (a zone change)
		self:UnregisterAllEvents()
		-- (After the kit's own pickup, 2 s: a test resumed by its Reload button.)
		C_Timer.After(5, Q.Login)
	end)
end

-- /cine debug testqueue [clear]: the offer again, or every waiting test dropped.
local KitRun = ns.TestKitRun
function ns.TestKitRun(arg)
	local name, rest = (arg or ""):match("^(%S+)%s*(.-)$")
	if name == "testqueue" then
		if rest == "clear" then
			for _, entry in ipairs(Q.Pending()) do Record(entry, "CLEARED") end
			ns.Print("test queue: cleared.")
		elseif not Q.Open() then
			ns.Print("test queue: a run is going.")
		end
		return true
	end
	return KitRun(arg)
end
