-- The quest walk skipped while nothing can change (offline, Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/questwalkskip.lua <forever|retail>
-- ns.QuestFocusTick (Quest tracker's Show just that quest) walked the game's
-- whole tracker every frames pass, ~0.8 ms; settled walks changed nothing
-- (/cine debug perf 2026-11-22: 413 parts in 23 walks, none put back by the
-- game). Now it walks only while something can change: the others' fade, the
-- tracker's own alpha, 2 s after a quest log or watch change or a reveal, a
-- timer or Close the gaps up, and once a second else. Checked on a stand-in
-- tracker with pretend time, a pass every 0.1 s. PASS or FAIL per check.
-- luacheck: push ignore 111 112 113 121 122
local client = arg and arg[1] or "forever"
package.path = "Tools/offline/?.lua;" .. package.path
local wow = dofile("Tools/offline/wow.lua")
wow.Install(client)
local now = 1000
local ns = {}
for line in io.lines("Cinematic.toc") do
	line = line:gsub("\r", "")
	if line ~= "" and not line:find("^#") then
		local chunk = loadfile((line:gsub("\\", "/")))
		if chunk then
			local ok, err = pcall(chunk, "Cinematic", ns)
			if not ok then wow.Warn(line .. ": " .. tostring(err)) end
		end
	end
end
wow.Fire("ADDON_LOADED", "Cinematic")
wow.Fire("PLAYER_LOGIN")
GetTime = function() return now end
InCombatLockdown = function() return false end
-- luacheck: pop

local failed = 0
local function Check(ok, text)
	print((ok and "PASS " or "FAIL ") .. text)
	if not ok then failed = failed + 1 end
end
Check(ns.QuestFocusTick and ns.PerfQuestReveal and ns.PerfQuestFocusState, "the quest focus functions found")
if not (ns.QuestFocusTick and ns.PerfQuestReveal) then return print("1 FAILED") end

-- A stand-in tracker: one module with one quest block (and a part per walk
-- counted by its SetAlpha).
-- (Plain tables: a stand-in frame answers any field with a stub, and a
-- section with a StageBlock is taken for a scenario's.)
local sets = 0
local function Part()
	local p = { alpha = 1 }
	p.GetAlpha = function(self) return self.alpha end
	p.SetAlpha = function(self, a) self.alpha = a sets = sets + 1 end
	p.GetChildren = function() end
	return p
end
ns.Reachable = function(frame) return type(frame) == "table" end
local tracker = Part()
local section = Part()
section.usedBlocks = { quests = { [4242] = Part(), [4343] = Part() } }
tracker.modules = { section }
_G.ObjectiveTrackerFrame = tracker
local entry = { frame = tracker, alpha = 0, group = "quests", name = "ObjectiveTrackerFrame" }
ns.db.questRevealOnProgress, ns.db.questRevealOnlyThat, ns.db.handleQuests = true, true, true
-- (Close the gaps on, as the user has it: it walked every pass with it on.)
ns.db.questRevealCollapse = true
ns.db.questRevealTime = 600 -- (the reveal held through the test: Override default reveal time)

-- Walks counted by the tick's own profiling counts.
local walked, skipped = 0, 0
local ProfileCount = ns.ProfileCount
ns.ProfileCount = function(name, ...)
	if name == "quest focus: walked" then walked = walked + 1 end
	if name == "quest focus: walk skipped" then skipped = skipped + 1 end
	return ProfileCount(name, ...)
end
Check(ns.StartProfile(600, true, false), "a recording started (the counts are taken while profiling)")
local function Passes(seconds)
	walked, skipped = 0, 0
	local stop = now + seconds
	while now < stop - 1e-6 do
		now = now + 0.1
		ns.QuestFocusTick(entry, false, 0.1, false)
	end
	return walked, skipped
end

ns.QuestFocusTick(entry, false, 0.1, false) -- (its entry known to the focus)
local id = ns.PerfQuestReveal()
Check(id == 4242 or id == 4343, "a quest revealed alone: " .. tostring(id))
Check((ns.PerfQuestFocusState()), "the focus is on")
local w, s = Passes(2)
-- (The pass landing on the 2 s mark itself is past it.)
Check(w >= 19 and s <= 1, ("the 2 s after the reveal: every pass walks (%d walked, %d skipped)"):format(w, s))
w, s = Passes(5)
Check(w >= 4 and w <= 6 and s >= 44, ("then settled 5 s: once a second (%d walked, %d skipped)"):format(w, s))

wow.Fire("QUEST_LOG_UPDATE")
w, s = Passes(1)
Check(w >= 9 and s <= 1, ("a quest log change: walked again at once (%d walked, %d skipped in 1 s)"):format(w, s))
Passes(3)
entry.alpha = 0.5 -- (the tracker itself fading)
w = Passes(0.1)
Check(w == 1, "the tracker's own alpha changed: walked")
entry.alpha = 0
Passes(3)
w, s = Passes(3)
Check(s > 0, ("settled again: skipping (%d walked, %d skipped)"):format(w, s))

-- The focus ended with the tracker up (shown for something else): the others
-- fade back in over several passes, each walked, then the walking stops.
entry.alpha = 1
Passes(0.2)
ns.QuestFocusTick(entry, true, 0.1, false)
local _, others = ns.PerfQuestFocusState()
local fadeIn = ns.FadeInTime and ns.FadeInTime() or 0.5
w = Passes(fadeIn + 0.3)
local on, after = ns.PerfQuestFocusState()
Check(not on and after == 1 and w >= math.floor(fadeIn / 0.1) - 1,
	("the focus off, tracker up: walked through the others' fade (%d walked, others %.2f -> %.2f over %.1f s)"):format(
	w, others or -1, after or -1, fadeIn))
w = Passes(2)
Check(w == 0, ("then nothing to walk: the early return (%d walked)"):format(w))

ns.StopProfile()
print(failed == 0 and "ALL PASSED" or (failed .. " FAILED"))
