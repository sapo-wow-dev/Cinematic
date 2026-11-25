-- /cine debug addonkit [Addon Addon ...]: the addon kit in game
-- (Tools/addon-kit-plan.md, step 5), one self-running test. Dev copy only.
--
-- For each target in turn: none (no other addon: the baseline) and then
-- each addon named (none named: every installed addon with a Support file):
--   solo     the addon list set to just that addon with Cinematic
--            (/cine debug solo), and one Reload button: your one action each
--   probes   every addon kit probe (Dev/AddonKit.lua), CineMode off, into
--            CinematicDB.addonKit<Target>Log
--   rows     for an addon: the addon test, quick (/cine debug addontest
--            <Addon> quick: each of its rows hidden and shown, a fight with
--            our fade, every frame on screen covered), its log kept as
--            CinematicDB.addonKit<Target>RowsLog
-- Then your addon list back as it was, and a last Reload.
-- After it: python -I Tools/addon-kit/diff.py all <client> (the baseline
-- saved from the none run, each addon judged against it).
local _, ns = ...

local MAX = 12 -- (targets in one run: none and 11 addons; run it again for more)

local function Plan() return CinematicDB.addonKitPlan end

local function LogKey(target, rows)
	return "addonKit" .. target:gsub("[^%w]", "") .. (rows and "Rows" or "") .. "Log"
end
ns.AddonKitLogKey = LogKey

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
		CinematicDB.addonKitPlan = { targets = targets, at = date("%Y-%m-%d %H:%M") }
		-- (A setting saved for the run, so a reload picks the run up again: the kit's undo.)
		r:Set("handleChat", ns.db.handleChat)
		r:Log("plan: " .. table.concat(targets, ", "))
		r:Verdict(#targets > 1 or #words == 0, "something to compare with the baseline")
	end },
}

for i = 1, MAX do
	steps[#steps + 1] = { key = "solo" .. i, title = "target " .. i .. ": that addon alone", run = function(r)
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
		if alone then
			r:Log("already alone: " .. (#loaded > 0 and table.concat(loaded, ", ") or "no other addon"))
			return
		end
		if type(solo) == "table" then ns.SoloAddons("off", true) end
		ns.SoloAddons(target == "none" and "none" or table.concat(want, " "), true)
		r:Log(("solo for %s: %s"):format(target, table.concat(CinematicDB.soloAddons and CinematicDB.soloAddons.keep or {}, ", ")))
		r:WaitFor(("Reload, for %s alone with Cinematic (%d of %d)"):format(target == "none" and "no other addon" or target,
			i, #plan.targets), { check = function() return false end, buttons = { { kind = "reload" } } })
	end }
	steps[#steps + 1] = { key = "probes" .. i, title = "target " .. i .. ": probes and rows", run = function(r)
		local plan = Plan()
		local target = plan and plan.targets[i]
		if not target then return r:Skip("no target " .. i) end
		local loaded = ns.AddonKit.Loaded()
		if target == "none" then
			r:Verdict(#loaded == 0, "no other addon loaded" .. (#loaded > 0 and (": " .. table.concat(loaded, ", ")) or ""))
		else
			r:Verdict(Loaded(target), target .. " loaded")
		end
		local lines = ns.AddonKit.Run(target)
		CinematicDB[LogKey(target)] = lines
		local errors = 0
		for _, line in ipairs(lines) do
			if line:find("^E ") then errors = errors + 1 r:Log("probe error: " .. line:sub(3)) end
		end
		r:Verdict(errors == 0, ("%s: every probe ran (%s)"):format(target, lines[#lines]:sub(3)))
		if target ~= "none" and Loaded(target) and ns.AddonTest then
			ns.AddonTest(target .. " quick")
			r:WaitFor("The addon test is hiding and showing " .. target .. "'s rows: hands off", {
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
	end }
end

steps[#steps + 1] = { key = "back", title = "your addon list back", run = function(r)
	if type(CinematicDB.soloAddons) ~= "table" then return r:Log("solo wasn't on") end
	ns.SoloAddons("off", true)
	r:Log("addon list put back")
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
	steps = steps,
})
