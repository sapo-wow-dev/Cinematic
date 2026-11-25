-- /cine debug addonkit (Dev/AddonKitTest.lua) through the test kit on the
-- stand-in, with pretend installed addons: the plan (named addons, and none
-- named: every installed supported addon, parts with their core), the solo
-- step setting the list and waiting on its Reload button, then (as after
-- the reload) the probes step for the baseline and for an addon, with the
-- addon test's run waited on and its log kept, and the logs diff.py reads.
--
--   python -I Tools/offline/run.py Tools/offline/addonkittest.lua < /dev/null
-- Exit 1 on any problem.
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

-- (Before the files load: Dev/AddonTest.lua keeps its own copy of these.)
-- The pretend addon list: name -> { enabled, loaded }.
local addons = {
	{ name = "CinematicDev", enabled = true, loaded = true },
	{ name = "DaylightUI", enabled = true, loaded = true },
	{ name = "DaylightUI_Chat", enabled = true, loaded = true },
	{ name = "Questie", enabled = true, loaded = true },
	{ name = "SomeOtherAddon", enabled = true, loaded = true },
}
local function Find(x)
	for i, a in ipairs(addons) do if a.name == x or i == x then return a end end
end
local function Fakes()
	C_AddOns.GetNumAddOns = function() return #addons end
	C_AddOns.GetAddOnInfo = function(x)
		local a = Find(x)
		if not a then return nil end
		return a.name, a.name, "", true, a.enabled and "" or "DISABLED", "INSECURE", false
	end
	C_AddOns.IsAddOnLoaded = function(x) local a = Find(x) return a and a.loaded or false end
	rawset(_G, "IsAddOnLoaded", C_AddOns.IsAddOnLoaded)
	C_AddOns.GetAddOnEnableState = function(a, b) local x = Find(type(a) == "string" and a or b) return x and (x.enabled and 2 or 0) or 0 end
	C_AddOns.EnableAddOn = function(x) local a = Find(x) if a then a.enabled = true end end
	C_AddOns.DisableAddOn = function(x) local a = Find(x) if a then a.enabled = false end end
	C_AddOns.SaveAddOns = function() end
	C_AddOns.GetAddOnDependencies = function() return nil end
	C_AddOns.GetAddOnOptionalDependencies = function() return nil end
	C_AddOns.DoesAddOnExist = function(x) return Find(x) ~= nil end
end

local ns = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc", Fakes)
local now = 100
local timers, tickers = {}, {}
GetTime = function() return now end
C_Timer.After = function(delay, fn) timers[#timers + 1] = { at = now + delay, fn = fn } end
-- (WaitFor's checks run on a ticker.)
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
Screenshot = function() end

-- (Which of them our Support files set up: the real list, through ns.HasAddonSetup.)
Check("DaylightUI has support here", ns.HasAddonSetup("DaylightUI") or ns.HasAddonSetup("DaylightUI_Chat"))

-- 1 plan with none named: the installed supported addons, a part with its core.
ns.HandleSlash("debug addonkit")
Advance(5)
local plan = CinematicDB.addonKitPlan
local targets = plan and table.concat(plan.targets, ",") or "none made"
Check("none named: baseline first, then the supported installed addons, a part with its core",
	targets == "none,DaylightUI,Questie", targets)
ns.HandleSlash("debug addonkit") -- (typed again: stops)
Advance(3)

-- 2 named: just those, and the solo step sets the list and waits for its Reload.
ns.HandleSlash("debug addonkit DaylightUI")
Advance(5)
plan = CinematicDB.addonKitPlan
Check("named: none then DaylightUI", plan and table.concat(plan.targets, ",") == "none,DaylightUI",
	plan and table.concat(plan.targets, ","))
local log = CinematicDB.addonKitTestLog
if os.getenv("KIT_DEBUG") then for _, line in ipairs(log or {}) do print("  2| " .. line) end end
Check("the solo step set the list for no other addon",
	type(CinematicDB.soloAddons) == "table" and table.concat(CinematicDB.soloAddons.keep, ",") == "CinematicDev",
	CinematicDB.soloAddons and table.concat(CinematicDB.soloAddons.keep or {}, ","))
Check("and waits on its Reload button", Has(log, "Reload, for no other addon alone") ~= nil)
Check("nobody else left on", not Find("DaylightUI").enabled and not Find("SomeOtherAddon").enabled)
ns.HandleSlash("debug addonkit") -- (stops)
Advance(3)

-- 3 after that reload (what's loaded is what was left on): the probes step for the baseline (step 3).
for _, a in ipairs(addons) do a.loaded = a.enabled end
-- (CineMode on at login, as in run qb556: the probes wait till it's off and
-- the frames' fade back in is over.)
local cineOn, cineOffAt, probedAt, cineAtProbe = true, nil, nil, nil
local IsOn, Toggle, KitRun = ns.IsCineModeOn, Cinematic_ToggleCineMode, ns.AddonKit.Run
ns.IsCineModeOn = function() return cineOn end
Cinematic_ToggleCineMode = function() cineOn = not cineOn if not cineOn then cineOffAt = now end end
ns.AddonKit.Run = function(...)
	probedAt, cineAtProbe = now, cineOn
	return KitRun(...)
end
ns.HandleSlash("debug addonkit 3")
Advance(8)
Check("CineMode on at login: off before the probes", probedAt ~= nil and cineAtProbe == false, tostring(cineAtProbe))
Check("and the fade back in over first", probedAt and cineOffAt
	and probedAt - cineOffAt >= (ns.db.fadeInTime or 1.5), probedAt and cineOffAt and (probedAt - cineOffAt))
ns.IsCineModeOn, Cinematic_ToggleCineMode, ns.AddonKit.Run = IsOn, Toggle, KitRun
log = CinematicDB.addonKitTestLog
-- (Each run's logs under its own keys: addonKitR<run>_<Target>Log.)
local function RunLog(target, rows)
	return CinematicDB[ns.AddonKitLogKey(target, rows)]
end
local base = RunLog("none")
Check("baseline: no other addon loaded", Has(log, "PASS.*no other addon loaded") ~= nil, Has(log, "FAIL"))
Check("baseline: every probe ran, kept under this run's key", base and base[1]:find("^H ") and Has(log, "PASS.-none: every probe ran"),
	base and base[#base])

-- (Its ready recipe asks for clicks in game: here it's ready as it is.)
if ns.TestKit.DefineAddonReady then
	ns.TestKit.DefineAddonReady("DaylightUI", { ready = function() return true end })
end
-- 4 an addon's turn (step 5): solo for DaylightUI, as its solo step sets it,
-- reloaded; its probes, then the addon test, waited on.
ns.SoloAddons("off", true)
ns.SoloAddons("DaylightUI", true)
for _, a in ipairs(addons) do a.loaded = a.enabled end
Check("solo for DaylightUI keeps its part", Find("DaylightUI_Chat").loaded and not Find("SomeOtherAddon").loaded)
local testRunning = false
ns.AddonTest = function(words)
	testRunning = true
	CinematicDB.addonTestLog = { "start " .. words, "VERDICT its rows: PASS" }
	C_Timer.After(2, function() testRunning = false end)
end
ns.AddonTestRunning = function() return testRunning end
ns.HandleSlash("debug addonkit 5")
Advance(10)
log = CinematicDB.addonKitTestLog
local run = RunLog("DaylightUI")
Check("DaylightUI: its probes kept under this run's key, with it in the addons list",
	run and run[1]:find("addons=DaylightUI,DaylightUI_Chat") ~= nil, run and run[1])
Check("DaylightUI: the addon test ran quick and its log was kept",
	RunLog("DaylightUI", true) and RunLog("DaylightUI", true)[1] == "start DaylightUI quick")
Check("the run's keys carry its stamp (two runs can't share them)", ns.AddonKitLogKey("none"):find("^addonKitR%d+_noneLog$") ~= nil,
	ns.AddonKitLogKey("none"))
Check("DaylightUI: the step passed", Has(log, "PASS.-DaylightUI: its rows hide") ~= nil, Has(log, "FAIL"))
Check("the run finished", Has(log, "DONE") ~= nil)
-- The chat probe tells the two apart: the miss behind the kit.
local function Field(lines, probe, field)
	for _, line in ipairs(lines or {}) do
		local p, f, v = line:match("^R (%S+)\t(%S+)\t(%S+)")
		if p == probe and f == field then return v end
	end
end
Check("chat.linesOnly: on with no addon, off with DaylightUI's chat",
	Field(base, "chat.linesOnly", "linesOnly") == "true" and Field(run, "chat.linesOnly", "linesOnly") == "false")

-- 5 solo's list didn't take (qcbb3, 2026-11-25): another addon still loaded
-- at an addon's stage. The stage fails and keeps no probes, so another
-- addon's frames are never judged as this one's.
CinematicDB[ns.AddonKitLogKey("DaylightUI")] = nil
Find("SomeOtherAddon").loaded = true
ns.HandleSlash("debug addonkit 5")
Advance(10)
log = CinematicDB.addonKitTestLog
Check("an addon solo didn't keep, still loaded: the stage FAILs and names it",
	Has(log, "FAIL.-nothing loaded that solo didn't keep: SomeOtherAddon") ~= nil, Has(log, "FAIL"))
Check("and keeps no probes for it", RunLog("DaylightUI") == nil)

-- 6 the first time, it tries again (qe822, 2026-11-25: every character's addon
-- list rewritten between solo and the reload): solo's list set again, one more
-- Reload asked, and the stage's probes in the step after that Reload.
Check("the first time: solo's list set again", Has(log, "isn't solo's: solo again, one more Reload") ~= nil)
Check("and one more Reload asked", Has(log, "Reload, for DaylightUI alone") ~= nil)
Check("and the stage noted for the step after it", CinematicDB.addonKitRetry == 2, CinematicDB.addonKitRetry)
Check("SomeOtherAddon turned off by that solo", not Find("SomeOtherAddon").enabled)
ns.HandleSlash("debug addonkit") -- (stops, as the Reload would)
Advance(3)
for _, a in ipairs(addons) do a.loaded = a.enabled end -- (the Reload)
ns.HandleSlash("debug addonkit 6") -- (the step it picks up at: solo3, no target 3 here)
Advance(10)
log = CinematicDB.addonKitTestLog
Check("after it: the stage's probes, in the step the run picks up at", RunLog("DaylightUI") ~= nil
	and Has(log, "again: target 2's probes") ~= nil, Has(log, "FAIL"))
Check("and no retry left noted", CinematicDB.addonKitRetry == nil)

-- 7 the second time, it gives up: FAIL, no probes.
CinematicDB[ns.AddonKitLogKey("DaylightUI")] = nil
Find("SomeOtherAddon").loaded = true
ns.HandleSlash("debug addonkit 5")
Advance(10)
log = CinematicDB.addonKitTestLog
Check("a second time for the same stage: FAIL, left out", Has(log, "FAIL.-the addon list isn't solo's") ~= nil
	and RunLog("DaylightUI") == nil and CinematicDB.addonKitRetry == nil, Has(log, "FAIL"))
Find("SomeOtherAddon").loaded = false

if fails > 0 then
	for _, line in ipairs(CinematicDB.addonKitTestLog or {}) do print("  | " .. line) end
end
print(fails == 0 and "addonkittest: all passed" or ("addonkittest: %d FAIL"):format(fails))
os.exit(fails == 0 and 0 or 1)
-- luacheck: pop
