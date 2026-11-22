-- /cine debug perf [steps]: performance without playing (dev copy only). The
-- user, 2026-11-22: "getting tired of all these 2 min tests that turn out
-- wrong". Each step puts the game in the state it measures itself and times
-- the real code there, in a second or two: no fight to find, no quest to
-- kill for, no profiler run to wait out. Steps:
--   1 cine        CineMode on (Start in CineMode; stand still if it waits)
--   2 frames      the frames pass, ns.UpdateFrames, one a frame x 60, and
--                 its parts (frames pass: targets, applying...)
--   3 listfull    the combat list worked out afresh, x 60 (its parts too)
--   4 listkept    the combat list as kept between passes, x 60
--   5 plates      the plates pass, ns.UpdatePlates, x 60
--   6 friendrows  the friendly plate rows, ns.plates.FriendRowsTicked, x 60
--   7 questwalk   the tracker's first quest revealed alone (no kill): the
--                 quest walk, ns.QuestFocusTick, x 60 once settled
--   8 questlive   that focus held 10 s with the profiler on: whether the game
--                 puts the tracker's alphas back itself (the walk's probe)
-- Every timing is one call a frame (a frame's caches start fresh, as in
-- play), with its garbage counted exactly (collection paused around the call).
-- Results: CinematicDB.perfResults[step] (the latest) and perfHistory (every
-- run); Tools/perf/analyze.py compares each with the last on this client.
-- Into CinematicDB.perfTestLog. Offline: Tools/offline/perftest.lua.
local _, ns = ...

local CALLS = 60
local HISTORY_KEEP = 300

local function Within(r, seconds, check)
	local untilAt = GetTime() + seconds
	local answer = check()
	while not answer and GetTime() < untilAt do
		r:Sleep(0.25)
		answer = check()
	end
	return answer
end

-- (The client as the addon names it, ns.CLIENT, and its build number.)
local function Client()
	return ns.CLIENT or (ns.isRetail and "retail" or "forever"), select(4, GetBuildInfo())
end

-- The test's own profile stopped without its report in the log or chat,
-- and ns.lastProfile put back as it was: that's the Profiler page's last
-- recording, saved at logout and read by Tools/perf/analyze.py. Its summary.
local function StopQuiet(before)
	local log, print = ns.Log, ns.Print
	ns.Log = function(category, ...) if category ~= "cpu" then return log(category, ...) end end
	ns.Print = function() end
	pcall(ns.StopProfile)
	ns.Log, ns.Print = log, print
	local mine = ns.lastProfile
	ns.lastProfile = before
	return mine
end

-- The profiler's parts of the calls just timed: rows under the bench's own
-- section.
local function PartsOf(profile, section)
	local out = {}
	for _, row in ipairs(profile and profile.sections or {}) do
		if row.name == section then
			for _, child in ipairs(row.children or {}) do
				out[#out + 1] = { name = child.name, average = child.average, worst = child.worst, calls = child.calls }
			end
		end
	end
	table.sort(out, function(a, b) return (a.average or 0) * (a.calls or 0) > (b.average or 0) * (b.calls or 0) end)
	return out
end

local function Save(result)
	local db = ns.db
	db.perfResults = db.perfResults or {}
	db.perfHistory = db.perfHistory or {}
	db.perfResults[result.step] = result
	local history = db.perfHistory
	history[#history + 1] = result
	while #history > HISTORY_KEEP do table.remove(history, 1) end
end

-- fn timed CALLS times, one a frame. before(i) runs first each time, not
-- timed nor counted. With parts: the profiler on (normal, not deep) around
-- it, so ns.ProfileAdd's parts inside are read back. A result line logged
-- and saved; the result handed back (nil: it errored, logged).
local function Bench(r, step, label, fn, opts)
	opts = opts or {}
	local calls = opts.calls or CALLS
	local section = "perf: " .. step
	local timed = ns.Profiled(section, fn)
	local profiling = opts.parts and ns.StartProfile and not (ns.IsProfiling and ns.IsProfiling())
	local before = ns.lastProfile
	if profiling then ns.StartProfile(calls / 10 + 30, true, false) end
	local times, kb, gcs, failed = {}, 0, 0, nil
	for i = 1, calls do
		if opts.before then opts.before(i) end
		collectgarbage("stop")
		local m0, t0 = collectgarbage("count"), debugprofilestop()
		local ok, err = pcall(timed, i)
		local t1, m1 = debugprofilestop(), collectgarbage("count")
		collectgarbage("restart")
		if not ok then
			failed = tostring(err)
			break
		end
		times[#times + 1] = t1 - t0
		if m1 >= m0 then kb = kb + (m1 - m0) else gcs = gcs + 1 end
		r:Sleep(0)
	end
	local parts = {}
	if profiling then
		parts = PartsOf(StopQuiet(before), section)
	end
	if failed then
		r:Fail(("%s: errored after %d calls: %s"):format(label, #times, failed))
		return nil
	end
	table.sort(times)
	local n, sum = #times, 0
	for _, t in ipairs(times) do sum = sum + t end
	local client, build = Client()
	local result = {
		step = step, label = label, at = time(), client = client, build = build, calls = n,
		avg = n > 0 and sum / n or 0, p50 = times[math.max(1, math.floor(n * 0.5))] or 0,
		p95 = times[math.max(1, math.floor(n * 0.95))] or 0, worst = times[n] or 0,
		kbCall = n > 0 and kb / n or 0, note = opts.note, inCine = ns.lastCinematic and true or false,
		managed = #(ns.managed or {}), plates = C_NamePlate and C_NamePlate.GetNamePlates
			and #C_NamePlate.GetNamePlates() or 0, parts = {},
	}
	for i = 1, math.min(#parts, 12) do result.parts[i] = parts[i] end
	r:Log(("%s: %.3f ms a call (p50 %.3f, p95 %.3f, worst %.2f), %.2f KB a call, %d calls%s"):format(label,
		result.avg, result.p50, result.p95, result.worst, result.kbCall, n,
		gcs > 0 and (", %d with a collection step (their memory left out)"):format(gcs) or ""))
	for _, part in ipairs(result.parts) do
		r:Log(("    %s: %.3f ms a call, worst %.2f"):format(part.name, part.average or 0, part.worst or 0))
	end
	Save(result)
	r:Pass(("%s timed (%.3f ms a call)"):format(label, result.avg))
	return result
end

local function TrackerEntry()
	local tracker = _G.ObjectiveTrackerFrame
	for _, entry in ipairs(ns.managed or {}) do
		if entry.frame == tracker then return entry end
	end
end

ns.TestKit.Define({
	name = "perf",
	key = "perfTest",
	title = "Performance, without playing",
	about = "times the hot code in the state it needs, set up by the test: frames pass, combat list, plates, "
		.. "quest walk (nothing to do but stand still)",
	cineMode = true,
	settings = { "enabled", "fadeUI", "questRevealOnProgress", "questRevealOnlyThat", "handleQuests", "questRevealTime" },
	context = function()
		local client, build = Client()
		return ("client %s %s, in CineMode %s, managed frames %d, plates %d, fps %.0f, tracked quests %s"):format(
			client, tostring(build), tostring(ns.lastCinematic), #(ns.managed or {}),
			C_NamePlate and C_NamePlate.GetNamePlates and #C_NamePlate.GetNamePlates() or 0, GetFramerate(),
			tostring(C_QuestLog and C_QuestLog.GetNumQuestWatches and C_QuestLog.GetNumQuestWatches()))
	end,
	steps = {
		{ key = "cine", title = "CineMode on", run = function(r)
			if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
			r:Set("enabled", true)
			r:Set("fadeUI", true)
			local on = Within(r, 8, function() return ns.lastCinematic end)
			if not on then
				r:WaitFor("Stand still a moment: CineMode comes on", {
					check = function() return ns.lastCinematic end })
				on = ns.lastCinematic
			end
			-- (Why it's off only when it is: ns.cineOffWhy keeps its "an error"
			-- placeholder while CineMode is on.)
			r:Verdict(on, on and "CineMode on" or ("CineMode on (why off: %s)"):format(tostring(ns.cineOffWhy)))
			r:Sleep(1.5) -- (its fade done: the passes settled)
		end },
		{ key = "frames", title = "frames pass", seconds = 3, run = function(r)
			if not ns.lastCinematic then return r:Skip("CineMode not on") end
			Bench(r, "frames", "frames pass (ns.UpdateFrames)", function() ns.UpdateFrames(true, 1 / 60) end,
				{ parts = true })
		end },
		{ key = "listfull", title = "combat list, worked out afresh", seconds = 3, run = function(r)
			if not ns.CombatShownFrames then return r:Skip("ns.CombatShownFrames missing") end
			Bench(r, "listfull", "combat list afresh (GetCombatShownFrames)", function() ns.CombatShownFrames() end,
				{ parts = true, before = function() if ns.ForgetCombatShown then ns.ForgetCombatShown() end end })
		end },
		{ key = "listkept", title = "combat list, kept", seconds = 3, run = function(r)
			if not ns.CombatShownFrames then return r:Skip("ns.CombatShownFrames missing") end
			ns.CombatShownFrames()
			Bench(r, "listkept", "combat list kept (GetCombatShownFrames)", function() ns.CombatShownFrames() end)
		end },
		{ key = "plates", title = "plates pass", seconds = 3, run = function(r)
			if not ns.UpdatePlates then return r:Skip("ns.UpdatePlates missing") end
			Bench(r, "plates", "plates pass (ns.UpdatePlates)", function()
				ns.UpdatePlates(ns.PlatesCinematic and ns.PlatesCinematic(true) or true, 1 / 60)
			end, { note = "plates shown: " .. (C_NamePlate and #C_NamePlate.GetNamePlates() or 0) })
		end },
		{ key = "friendrows", title = "friendly plate rows", seconds = 3, run = function(r)
			local p = ns.plates
			if not (p and p.FriendRowsTicked) then return r:Skip("FriendRowsTicked missing") end
			local suffix = ns.PlateSuffix and ns.PlateSuffix() or ""
			Bench(r, "friendrows", "friendly plate rows (FriendRowsTicked)", function() p.FriendRowsTicked(suffix) end)
		end },
		{ key = "questwalk", title = "quest walk, a quest shown alone", seconds = 5, run = function(r)
			if not (ns.PerfQuestReveal and ns.QuestFocusTick) then return r:Skip("the quest hooks are missing") end
			local entry = TrackerEntry()
			if not entry then return r:Skip("the quest tracker isn't a managed frame here") end
			if not ns.lastCinematic then return r:Skip("CineMode not on: the tracker isn't faded") end
			r:Set("handleQuests", true)
			r:Set("questRevealOnProgress", true)
			r:Set("questRevealOnlyThat", true)
			r:Set("questRevealTime", 60) -- (held through the steps: no reveal again, which walks for 2 s)
			local id = ns.PerfQuestReveal()
			if not id then return r:Skip("no quest drawn in the tracker (track one)") end
			local on = Within(r, 3, function() return (ns.PerfQuestFocusState()) end)
			r:Verdict(on, ("quest %s revealed alone (focus on %s)"):format(tostring(id), tostring(on)))
			local settled = Within(r, 4, function() local _, others = ns.PerfQuestFocusState() return others == 0 end)
			local _, others = ns.PerfQuestFocusState()
			r:Log(("the others faded: %s (alpha %s)"):format(tostring(settled), tostring(others)))
			r.questID = id
			-- (Past the 2 s a reveal walks for: the settled passes, walked once a
			-- second since 2026-11-22.)
			r:Sleep(2.5)
			Bench(r, "questwalk", "quest walk settled (ns.QuestFocusTick)", function()
				ns.QuestFocusTick(entry, false, 1 / 60, false)
			end, { parts = true, note = "quest " .. tostring(id) })
		end },
		{ key = "questlive", title = "quest walk held 10 s: does the game put alphas back?", seconds = 12,
			run = function(r)
			if not (ns.PerfQuestReveal and ns.StartProfile and r.questID) then
				return r:Skip("no quest walk to hold (step questwalk first)")
			end
			if not ns.lastCinematic then return r:Skip("CineMode not on") end
			if ns.IsProfiling and ns.IsProfiling() then return r:Skip("a profiler recording is already running") end
			local before = ns.lastProfile
			ns.StartProfile(30, true, false)
			r:Sleep(10) -- (the reveal held by questRevealTime: walked as play would)
			local profile = StopQuiet(before)
			local counts = {}
			for _, line in ipairs(profile and profile.lines or {}) do
				local name, n = line:match("^count (quest .+): ([%d.]+) a frame")
				if name then counts[name] = tonumber(n) end
			end
			local frames = (profile and profile.fps or 0) * (profile and profile.seconds or 0)
			local function Total(name) return (counts[name] or 0) * frames end
			local changed, set, same = Total("quest tracker walk: the game changed it"),
				Total("quest tracker walk: set"), Total("quest tracker walk: already so")
			local walks, settledWalks = Total("quest focus walks: a quest shown alone"), Total("quest focus walks: settled")
			local walked, skipped = Total("quest focus: walked"), Total("quest focus: walk skipped")
			local client, build = Client()
			local result = { step = "questlive", label = "quest walk held 10 s", at = time(), client = client,
				build = build, walks = walks, settledWalks = settledWalks, gameChanged = changed, set = set,
				alreadySo = same, seconds = profile and profile.seconds, quest = r.questID, walked = walked,
				skipped = skipped }
			Save(result)
			r:Log(("passes %.0f (settled %.0f): the tracker walked %.0f, skipped %.0f; parts: the game changed it "
				.. "%.0f, set %.0f, already so %.0f"):format(walks, settledWalks, walked, skipped, changed, set, same))
			for name, n in pairs(counts) do
				if name:find("^quest focus: walked for ") then r:Log(("    %s: %.0f"):format(name, n * frames)) end
			end
			r:Verdict(walks > 0, "the walk ran while the quest was held")
			-- (Settled, it should walk about once a second, not every pass.)
			r:Verdict(skipped > walked, ("settled: the tracker walked %.0f of %.0f passes"):format(walked, walked + skipped))
			-- (The answer the skip-when-settled fix needs: not a pass or fail.)
			if walks == 0 then
				r:Log("ANSWER: none (no walk ran)")
			elseif changed == 0 then
				r:Log(("ANSWER: in %.0f walks (of %.0f passes) the game never put a part's alpha back (%.0f set, "
					.. "%.0f already so): walking only while something changes is safe"):format(
					walked > 0 and walked or walks, walks, set, same))
			else
				r:Log(("ANSWER: the game put %.0f parts' alpha back in 10 s (%.0f walks): walk on its redraws too")
					:format(changed, walks))
			end
		end },
	},
})
