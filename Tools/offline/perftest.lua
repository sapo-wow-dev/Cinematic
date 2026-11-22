-- /cine debug perf (Dev/PerfTest.lua) on the stand-in (offline, Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/perftest.lua < /dev/null
-- The kit's mechanics, both clients, with pretend time: every step runs (the
-- frames pass and the quest walk stood in for: the real pass doesn't return
-- on the stand-in), each result is saved (CinematicDB.perfResults and
-- perfHistory) with its parts read back from the profiler, the Profiler
-- page's last recording (ns.lastProfile) is left as it was, the test's own
-- profiles write nothing to the log, and the quest walk's live step answers
-- from the probe's counts. PASS or FAIL per check.
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
	local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function()
		debugprofilestop = function() return os.clock() * 1000 end
	end)
	local now = 100
	local timers = {}
	GetTime = function() return now end
	GetFramerate = function() return 60 end
	C_Timer.After = function(delay, fn) timers[#timers + 1] = { at = now + delay, fn = fn } end
	local function Advance(seconds)
		local stop = now + seconds
		while now < stop do
			now = now + 0.05
			local due = {}
			for i = #timers, 1, -1 do
				if timers[i].at <= now then due[#due + 1] = table.remove(timers, i) end
			end
			for i = #due, 1, -1 do due[i].fn() end
			-- (The frames pass in the game calls the quest walk every pass.)
			if ns.QuestFocusTick then ns.QuestFocusTick() end
		end
	end
	Screenshot = function() end
	ns.PadTestBox = function() end
	ns.PadTestBoxHide = function() end
	ns.IsCineModeOn = function() return true end
	ns.lastCinematic = true

	-- Stand-ins: the frames pass (one timed part), the tracker and its walk.
	local passes, walks = 0, 0
	ns.UpdateFrames = function()
		passes = passes + 1
		if ns.profiling then ns.ProfileAdd("frames pass: targets", 0.25) end
	end
	_G.ObjectiveTrackerFrame = CreateFrame("Frame")
	ns.managed = ns.managed or {}
	table.insert(ns.managed, { frame = _G.ObjectiveTrackerFrame, alpha = 0, group = "quests", name = "ObjectiveTrackerFrame" })
	ns.PerfQuestReveal = function() return 4242 end
	ns.PerfQuestFocusState = function() return true, 0 end
	ns.QuestFocusTick = function()
		walks = walks + 1
		if ns.profiling then
			ns.ProfileCount("quest focus walks: a quest shown alone")
			ns.ProfileCount("quest focus walks: settled")
			ns.ProfileCount("quest tracker walk: already so", 3)
			-- (Settled: skipped but for the once a second walk.)
			ns.ProfileCount(walks % 20 == 0 and "quest focus: walked" or "quest focus: walk skipped")
			if walks % 20 == 0 then ns.ProfileCount("quest focus: walked for the once a second walk") end
		end
	end

	local sentinel = { lines = { "the Profiler page's last recording" }, sections = {} }
	ns.lastProfile = sentinel
	local function CpuLines()
		local n = 0
		for _, line in ipairs(CinematicDB.log or {}) do
			if type(line) == "string" and line:find(" cpu: ", 1, true) then n = n + 1 end
		end
		return n
	end
	local cpuBefore = CpuLines()
	CinematicDB.perfResults, CinematicDB.perfHistory = nil, nil

	ns.HandleSlash("debug perf")
	Advance(90)
	local log = CinematicDB.perfTestLog
	local done = Has(log, "DONE: ")
	Check("finished DONE", done ~= nil, done)
	Check("no FAIL verdict", not Has(log, "verdict FAIL"), Has(log, "verdict FAIL"))
	local results = CinematicDB.perfResults or {}
	for _, step in ipairs({ "frames", "listfull", "listkept", "plates", "friendrows", "questwalk", "questlive" }) do
		Check("result saved: " .. step, results[step] ~= nil and results[step].client == client,
			results[step] and results[step].label)
	end
	Check("the frames pass timed one a frame, 60 times", passes == 60 and (results.frames or {}).calls == 60, passes)
	local part = results.frames and results.frames.parts and results.frames.parts[1]
	Check("its part read back from the profiler (frames pass: targets)", part and part.name == "frames pass: targets",
		part and part.name)
	Check("a result has avg, p95, worst and KB a call", results.listfull and results.listfull.avg
		and results.listfull.p95 and results.listfull.worst and results.listfull.kbCall ~= nil)
	Check("history kept every result (7)", #(CinematicDB.perfHistory or {}) == 7, #(CinematicDB.perfHistory or {}))
	Check("the Profiler page's last recording left as it was", ns.lastProfile == sentinel)
	Check("the test's profiles wrote no report to the log", CpuLines() == cpuBefore, CpuLines() - cpuBefore)
	local live = results.questlive or {}
	Check("live step: the walks counted", (live.walks or 0) > 0 and walks > 60, ("%s walks, %d calls"):format(
		tostring(live.walks), walks))
	Check("live step: the answer given", Has(log, "ANSWER: in .* walks %(of .* passes%) the game never put") ~= nil,
		Has(log, "ANSWER"))
	Check("no profiler left running", not (ns.IsProfiling and ns.IsProfiling()))
end

RunClient("forever")
RunClient("retail")
-- luacheck: pop
print(fails == 0 and "ALL PASSED" or (fails .. " FAILED"))
