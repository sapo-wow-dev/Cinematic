-- /cine debug addonkit [Addon Addon ...]: the addon kit in game
-- (Tools/addon-kit-plan.md, step 5), one self-running test. Dev copy only.
--
-- For each target in turn: none (no other addon: the baseline) and then
-- each addon named (none named: every installed addon with a Support file):
--   solo     the addon list set to just that addon with Cinematic
--            (/cine debug solo), and one Reload button: your one action each
--   ready    the addon set up by its recipe (ns.TestKit.DefineAddonReady),
--            or its clicks in the box when it can't do it itself
--   probes   every addon kit probe (Dev/AddonKit.lua), CineMode off, into
--            CinematicDB.addonKit<Target>Log
--   rows     for an addon: the addon test, quick (/cine debug addontest
--            <Addon> quick: each of its rows hidden and shown, a fight with
--            our fade, every frame on screen covered), its log kept as
--            CinematicDB.addonKit<Target>RowsLog
-- Then your addon list back as it was, and a last Reload (in the test queue:
-- the queue's own at the end, and every queued addon kit test runs as one).
-- After it: python -I Tools/addon-kit/diff.py all <client> (the baseline
-- saved from the none run, each addon judged against it).
local _, ns = ...

local MAX = 12 -- (targets in one run: none and 11 addons; run it again for more)

local function Plan() return CinematicDB.addonKitPlan end

-- Each run's logs under its own keys (addonKitR<run>_<Target>Log), so two
-- runs in one test queue can't overwrite each other's baseline: one session's
-- run took the none stage after another's and the first was judged against
-- it (qcbb3, 2026-11-25). The run: its plan's time, digits only.
local KEEP_RUNS = 4
local function RunStamp(at) return (tostring(at or ""):gsub("%D", "")) end
local function LogKey(target, rows)
	local plan = Plan()
	local stamp = plan and RunStamp(plan.at) or ""
	return "addonKitR" .. stamp .. "_" .. (target:gsub("[^%w]", "")) .. (rows and "Rows" or "") .. "Log"
end
ns.AddonKitLogKey = LogKey
-- The newest KEEP_RUNS runs' logs kept, older ones dropped (each run is ~600
-- lines a stage in the saved file).
local function PruneRuns(stamp)
	local runs = type(CinematicDB.addonKitRuns) == "table" and CinematicDB.addonKitRuns or {}
	runs[#runs + 1] = stamp
	while #runs > KEEP_RUNS do
		local old = table.remove(runs, 1)
		for key in pairs(CinematicDB) do
			if type(key) == "string" and key:find("^addonKitR" .. old .. "_") then CinematicDB[key] = nil end
		end
	end
	CinematicDB.addonKitRuns = runs
end

-- An installed addon's folder name as typed in any case (slash commands
-- come lower case: "daylightui"), or nil.
local function Installed(typed)
	local GetNum = C_AddOns and C_AddOns.GetNumAddOns or _G.GetNumAddOns
	local GetInfo = C_AddOns and C_AddOns.GetAddOnInfo or _G.GetAddOnInfo
	local want = typed:lower()
	for i = 1, GetNum() do
		local name = GetInfo(i)
		if type(name) == "string" and name:lower() == want then return name end
	end
	return nil
end

-- Every installed addon our Support files set up (none named).
local function SupportedInstalled()
	local out, seen = {}, {}
	local GetNum = C_AddOns and C_AddOns.GetNumAddOns or _G.GetNumAddOns
	local GetInfo = C_AddOns and C_AddOns.GetAddOnInfo or _G.GetAddOnInfo
	for i = 1, GetNum() do
		local name = GetInfo(i)
		if type(name) == "string" and not seen[name] and ns.HasAddonSetup(name) and not name:find("^Cinematic") then
			seen[name] = true
			out[#out + 1] = name
		end
	end
	table.sort(out)
	-- (A part, DaylightUI_Chat, comes with its core: solo keeps a core's parts.)
	local cores = {}
	for _, name in ipairs(out) do
		local core = name:match("^(.-)_")
		if not (core and seen[core]) then cores[#cores + 1] = name end
	end
	return cores
end

local function Has(list, value)
	for _, each in ipairs(list) do if each == value then return true end end
	return false
end

local function Loaded(name)
	local IsLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or _G.IsAddOnLoaded
	return IsLoaded(name) and true or false
end

local steps = {
	{ key = "plan", title = "what to run", run = function(r)
		local words = {}
		for word in (r.arg or ""):gmatch("%S+") do
			if word ~= "full" and not word:match("^%d+$") then words[#words + 1] = word end
		end
		local targets = { "none" }
		local list = #words > 0 and words or SupportedInstalled()
		for _, name in ipairs(list) do
			local folder = Installed(name)
			if folder then
				targets[#targets + 1] = folder
			else
				r:Fail(name .. " isn't installed: left out")
			end
		end
		while #targets > MAX do r:Log("left out (more than " .. MAX .. "): " .. table.remove(targets)) end
		CinematicDB.addonKitPlan = { targets = targets, at = date("%Y-%m-%d %H:%M:%S") }
		PruneRuns(RunStamp(CinematicDB.addonKitPlan.at))
		CinematicDB.addonKitRetry, CinematicDB.addonKitRetried = nil, nil
		-- (A setting saved for the run, so a reload picks the run up again: the kit's undo.)
		r:Set("handleChat", ns.db.handleChat)
		r:Log("plan: " .. table.concat(targets, ", "))
		r:Verdict(#targets > 1 or #words == 0, "something to compare with the baseline")
	end },
}

-- One target's solo: its addon list set, then a Reload (again: a retry's,
-- set even if it looks alone already).
local SoloFor
-- One target's probes and rows, after its Reload.
local function ProbesFor(r, i)
	local plan = Plan()
	local target = plan and plan.targets[i]
	if not target then return r:Skip("no target " .. i) end
	-- (The addon list as solo meant it: no kept addon without a part of it,
	-- no load errors from one. Known error solo-split-companion, 2026-11-25.)
	if ns.SoloCheck then
		local problems = ns.SoloCheck(CinematicDB.soloAddons)
		for _, line in ipairs(problems) do r:Log("solo check: " .. line) end
		r:Verdict(#problems == 0, ("%s: the addon list as solo meant it%s"):format(target,
			#problems > 0 and (" (" .. table.concat(problems, "; ") .. ")") or ""))
	end
	local loaded = ns.AddonKit.Loaded()
	if target == "none" then
		r:Verdict(#loaded == 0, "no other addon loaded" .. (#loaded > 0 and (": " .. table.concat(loaded, ", ")) or ""))
	else
		r:Verdict(Loaded(target), target .. " loaded")
		-- (And nothing else: solo set MikScrollingBattleText_Forever on and
		-- Guidelime off, and after the reload Guidelime was loaded and it
		-- wasn't, qcbb3 2026-11-25. Its probes were Guidelime's.)
		local keep = type(CinematicDB.soloAddons) == "table" and CinematicDB.soloAddons.keep or {}
		local extra = {}
		for _, name in ipairs(loaded) do
			if name ~= target and not Has(keep, name) then extra[#extra + 1] = name end
		end
		r:Verdict(#extra == 0, target .. ": nothing loaded that solo didn't keep" ..
			(#extra > 0 and (": " .. table.concat(extra, ", ") .. " (solo's addon list didn't take)") or ""))
		if not Loaded(target) or #extra > 0 then
			-- (Once: solo's list again, one more Reload, and its probes in the
			-- step after it. Something outside the addon rewrote every
			-- character's addon list between solo and the reload, run qe822
			-- 2026-11-25, Glass loaded in Guidelime's place.)
			local retried = CinematicDB.addonKitRetried or {}
			CinematicDB.addonKitRetried = retried
			if not retried[i] then
				retried[i] = true
				CinematicDB.addonKitRetry = i
				r:Log(target .. ": the addon list after the reload isn't solo's: solo again, one more Reload")
				return SoloFor(r, i, true)
			end
			return r:Fail(target .. ": the addon list isn't solo's, so its probes would be another addon's: left out")
		end
	end
	-- (CineMode can come on at login before the kit's own check turns it
	-- off, a moment later: probes taken then read its fades as the addon's,
	-- 85 FAILs in EllesmereUI's stage of run qb556, 2026-11-25, while the
	-- baseline's stage never came on. Off, then the frames' fade back in
	-- over, before the probes, every stage alike.)
	if ns.IsCineModeOn and ns.IsCineModeOn() and Cinematic_ToggleCineMode then
		pcall(Cinematic_ToggleCineMode)
		r:Log("CineMode came on at login: off before the probes")
	end
	-- (Set up as its recipe says, so its frames are up for the probes and
	-- rows: Guidelime with no guide loaded shows no arrow to test.)
	if target ~= "none" and Loaded(target) then r:AddonReady(target) end
	r:Sleep(((ns.db and tonumber(ns.db.fadeInTime)) or 1.5) + 1)
	local lines = ns.AddonKit.Run(target, plan.at)
	CinematicDB[LogKey(target)] = lines
	local errors = 0
	for _, line in ipairs(lines) do
		if line:find("^E ") then errors = errors + 1 r:Log("probe error: " .. line:sub(3)) end
	end
	r:Verdict(errors == 0, ("%s: every probe ran (%s)"):format(target, lines[#lines]:sub(3)))
	if target ~= "none" and Loaded(target) and ns.AddonTest then
		ns.AddonTest(target .. " quick")
		r:WaitFor("The addon test is hiding and showing " .. target .. "'s rows", { handsOff = true,
			check = function() return not ns.AddonTestRunning() end })
		CinematicDB[LogKey(target, true)] = CinematicDB.addonTestLog
		local fails, log = 0, CinematicDB.addonTestLog or {}
		for _, line in ipairs(log) do
			-- (A FAIL verdict or a frame's own "  NOT COVERED <frame>" line, not the
			-- "0 NOT COVERED" a PASS verdict says. Each one counted is logged:
			-- 2026-11-25's run said FAIL with a rows log of PASS lines only.)
			if line:find("VERDICT .*: FAIL") or line:find("%s%sNOT COVERED %S") then
				fails = fails + 1
				r:Log("counted as a fail: " .. line)
			end
		end
		r:Log(("rows log: %d lines, its last: %s"):format(#log, tostring(log[#log])))
		r:Verdict(fails == 0, ("%s: its rows hide, stay hidden and come back, every frame covered (%s)"):format(target,
			fails > 0 and (fails .. " FAIL or NOT COVERED lines: read " .. LogKey(target, true)) or "none failed"))
	end
end

SoloFor = function(r, i, again)
	local plan = Plan()
	local target = plan and plan.targets[i]
	if not target then return r:Skip("no target " .. i) end
	local solo = CinematicDB.soloAddons
	local want = target == "none" and {} or { target }
	-- (Alone by what's loaded now, not by the solo setting: that one counts
	-- only after a reload, and a run stopped before it left it set.)
	local loaded = ns.AddonKit.Loaded()
	local keep = type(solo) == "table" and solo.keep or {}
	local alone = target == "none" and #loaded == 0
	if target ~= "none" and Loaded(target) and #keep > 0 then
		alone = true
		for _, name in ipairs(loaded) do
			if not Has(keep, name) then alone = false end
		end
	end
	if alone and not again then
		r:Log("already alone: " .. (#loaded > 0 and table.concat(loaded, ", ") or "no other addon"))
		return
	end
	if type(solo) == "table" then ns.SoloAddons("off", true) end
	ns.SoloAddons(target == "none" and "none" or table.concat(want, " "), true)
	r:Log(("solo for %s: %s"):format(target, table.concat(CinematicDB.soloAddons and CinematicDB.soloAddons.keep or {}, ", ")))
	-- (Each switch read back by solo itself: one that didn't take is named
	-- now, not found after the reload as another addon's probes.)
	local stuck = CinematicDB.soloAddons and CinematicDB.soloAddons.unconfirmed
	r:Verdict(not stuck, ("%s: every addon switched as solo asked%s"):format(target,
		stuck and (": didn't switch: " .. table.concat(stuck, ", ")) or ""))
	r:WaitFor(("Reload, for %s alone with Cinematic (%d of %d)"):format(target == "none" and "no other addon" or target,
		i, #plan.targets), { check = function() return false end, buttons = { { kind = "reload" } } })
end

-- A stage whose list didn't take, set again before the Reload: its probes
-- now, in whichever step the run picks up at.
local function RetryPending(r)
	local i = CinematicDB.addonKitRetry
	if not i then return end
	CinematicDB.addonKitRetry = nil
	r:Log("again: target " .. i .. "'s probes, after its second Reload")
	ProbesFor(r, i)
end

for i = 1, MAX do
	steps[#steps + 1] = { key = "solo" .. i, title = "target " .. i .. ": that addon alone", run = function(r)
		RetryPending(r)
		return SoloFor(r, i)
	end }
	steps[#steps + 1] = { key = "probes" .. i, title = "target " .. i .. ": probes and rows", run = function(r)
		return ProbesFor(r, i)
	end }
end

steps[#steps + 1] = { key = "back", title = "your addon list back", run = function(r)
	RetryPending(r)
	if type(CinematicDB.soloAddons) ~= "table" then return r:Log("solo wasn't on") end
	ns.SoloAddons("off", true)
	r:Log("addon list put back")
	-- (Last in a test queue: the queue's own Reload at the end brings them
	-- back, one Reload less. The user, 2026-11-25: "so many reloads".)
	local queue = ns.TestQueue
	if queue and queue.FoldReload and queue.FoldReload("get your addons back") then
		return r:Log("your addons come back at the test queue's Reload at the end")
	end
	r:WaitFor("Reload, to get your addons back", { check = function() return false end, buttons = { { kind = "reload" } } })
end }
steps[#steps + 1] = { key = "done", title = "next", run = function(r)
	r:Log(("next: python -I Tools/addon-kit/diff.py all %s"):format(ns.isRetail and "retail" or "forever"))
end }

ns.TestKit.Define({
	name = "addonkit", key = "addonKitTest", title = "Addon kit",
	about = "every addon kit probe with no other addon (the baseline) and with each addon alone, plus each one's rows",
	settings = { "handleChat" },
	needs = "anywhere quiet; one Reload click per addon",
	-- (In the test queue: every queued addon kit test runs as one, one
	-- baseline for all, and last, its put-back Reload the queue's own.)
	mergeArgs = true, lastInQueue = true,
	steps = steps,
})
