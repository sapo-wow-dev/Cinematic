-- /cine debug addonlist: does the game's AddOns window open on All with
-- "Default Addon list opening to All" on (QoL/AddonListAll.lua), and on
-- Forever is the secure Reload UI laid over its button once a tick changes?
-- Runs itself, no clicks:
--   1 open    the setting on for the run, the window opened: PASS when its
--             dropdown says All (and our code put it there). Logs whether its
--             shouldReload is tainted (INFO: why Forever needs the cover).
--   2 cover   one other addon's tick flipped for All characters (the game's
--             own C_AddOns call): Forever PASS when Reload UI shows and the
--             cover is up within 1 px of it; retail PASS when no cover is made
--             (its ReloadUI isn't blocked).
--   3 close   the window closed without saving (its Cancel path:
--             C_AddOns.ResetAddOns): PASS when the cover's gone and the
--             addon's tick is back as it was.
-- FAIL on any new AddonListAll.lua error in the log. Into
-- CinematicDB.addonListLog, with screenshots. The setting and CineMode put
-- back after. Run again to stop. Dev copy only.
local _, ns = ...

local run

local function Say(text)
	local log = CinematicDB and CinematicDB.addonListLog
	if log then log[#log + 1] = ("%s %s"):format(date("%H:%M:%S"), text) end
end
local function Shot(what)
	local ok = pcall(function() Screenshot() end)
	Say(("  screenshot %s at %s%s"):format(what, date("%m%d%y_%H%M%S"), ok and "" or " (failed)"))
end
local function Verdict(name, problems)
	if #problems == 0 then
		run.pass = run.pass + 1
		Say(("  %s verdict PASS"):format(name))
	else
		run.fail = run.fail + 1
		Say(("  %s verdict FAIL: %s"):format(name, table.concat(problems, "; ")))
	end
end

local function Rect(frame)
	local ok, l, b, w, h, s = pcall(function()
		return frame:GetLeft(), frame:GetBottom(), frame:GetWidth(), frame:GetHeight(),
			frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	end)
	if not (ok and l and b and w and h) then return nil end
	return l * s, b * s, w * s, h * s
end

local function NewErrors()
	local log, found = ns.db and ns.db.log, {}
	if not log then return found end
	for i = (run.logFrom or #log) + 1, #log do
		local line = log[i]
		if type(line) == "string" and (line:find("AddonListAll") or line:find("CinematicAddonListReload")) then
			found[#found + 1] = line:sub(1, 300)
		end
	end
	run.logFrom = #log
	return found
end

local function DropdownText(list)
	local dropdown = list and list.Dropdown
	if not dropdown then return nil end
	local ok, text = pcall(function()
		return (dropdown.GetText and dropdown:GetText()) or (dropdown.Text and dropdown.Text:GetText())
	end)
	return ok and text or nil
end

-- Enabled for All characters? (nil character = All.)
local function EnabledForAll(index)
	local ok, state = pcall(C_AddOns.GetAddOnEnableState, index, nil)
	return ok and state or nil
end

local function Finish(text)
	if not run then return end
	local done = run
	run = nil
	CinematicDB.addonListTest = nil
	if ns.db then ns.db.addonListAll = done.settingWas end
	if _G.AddonList and _G.AddonList:IsShown() then
		if AddonList_Hide then pcall(AddonList_Hide, false) else _G.AddonList:Hide() end
	end
	if done.cineWasOn and ns.IsCineModeOn and not ns.IsCineModeOn() and Cinematic_ToggleCineMode then
		Cinematic_ToggleCineMode()
	end
	local line = ("%s: %d pass, %d fail"):format(text, done.pass, done.fail)
	Say(line)
	ns.TestPrompt(("AddOns list test %s. Say \"check log\"."):format(line), 15)
end

local function After(seconds, fn)
	C_Timer.After(seconds, function()
		if not run then return end
		if InCombatLockdown() then
			ns.TestPrompt("AddOns list test: end the fight first; the test waits.", 3600)
			return After(1, fn)
		end
		fn()
	end)
end

-- 3: closed without saving; the cover goes, the tick comes back.
local function StepClose(index, before)
	ns.TestPrompt("AddOns list test: step 3 of 3, closing without saving. Nothing to click.", 3600)
	Say("step 3 close")
	if AddonList_Hide then pcall(AddonList_Hide, false) else _G.AddonList:Hide() end
	After(1, function()
		local problems = {}
		local state = ns.AddonListAllState()
		Say(("  window shown %s, cover shown %s"):format(tostring(_G.AddonList:IsShown()),
			tostring(state.cover and state.cover:IsShown())))
		if state.cover and state.cover:IsShown() then problems[#problems + 1] = "cover still up" end
		if index then
			local now = EnabledForAll(index)
			Say(("  addon %d tick for All: was %s, now %s"):format(index, tostring(before), tostring(now)))
			if now ~= before then problems[#problems + 1] = "the addon's tick wasn't put back" end
		end
		for _, line in ipairs(NewErrors()) do problems[#problems + 1] = "error: " .. line end
		Verdict("close", problems)
		Finish("DONE")
	end)
end

-- 2: a tick flipped; Reload UI shows, covered on Forever.
local function StepCover()
	ns.TestPrompt("AddOns list test: step 2 of 3, one addon's tick flipped for a moment. Nothing to click.", 3600)
	Say("step 2 cover")
	local list, index = _G.AddonList, nil
	for i = 1, C_AddOns.GetNumAddOns() do
		local name = C_AddOns.GetAddOnInfo(i)
		if name and name ~= "Cinematic" and name ~= "CinematicDev" and not name:find("^Blizzard_") then
			index = i
			break
		end
	end
	if not index then
		Say("  no other addon to flip: skipped (INFO)")
		return StepClose(nil, nil)
	end
	local before = EnabledForAll(index)
	Say(("  flipping addon %d (%s), enabled-for-All state %s"):format(index, tostring(C_AddOns.GetAddOnInfo(index)),
		tostring(before)))
	if before and before > 0 then C_AddOns.DisableAddOn(index) else C_AddOns.EnableAddOn(index) end
	if AddonList_Update then pcall(AddonList_Update) end
	After(1, function()
		local problems = {}
		local state = ns.AddonListAllState()
		local okay = list.OkayButton
		local okayText = okay and okay:GetText()
		Say(("  button says %s (RELOADUI %s), shouldReload %s, reloadBlocked %s"):format(tostring(okayText),
			tostring(RELOADUI), tostring(list.shouldReload), tostring(ns.reloadBlocked)))
		local cover = state.cover
		if ns.reloadBlocked then
			local tl, tb, tw, th = Rect(okay)
			local cl, cb, cw, ch
			if cover then cl, cb, cw, ch = Rect(cover) end
			Say(("  cover %s, shown %s, protected %s, at %s,%s %sx%s; button at %s,%s %sx%s"):format(
				cover and "made" or "NOT made", tostring(cover and cover:IsShown()),
				tostring(cover and cover:IsProtected()), tostring(cl), tostring(cb), tostring(cw), tostring(ch),
				tostring(tl), tostring(tb), tostring(tw), tostring(th)))
			if okayText ~= RELOADUI then problems[#problems + 1] = "button doesn't say Reload UI" end
			if not (cover and cover:IsShown()) then
				problems[#problems + 1] = "no cover shown"
			elseif not (tl and cl) then
				problems[#problems + 1] = "places unreadable"
			elseif math.abs(tl - cl) > 1 or math.abs(tb - cb) > 1 or math.abs(tw - cw) > 1 or math.abs(th - ch) > 1 then
				problems[#problems + 1] = "cover not on the button"
			end
		else
			Say(("  cover %s (none wanted: this client reloads from addon code)"):format(cover and "made" or "not made"))
			if cover and cover:IsShown() then problems[#problems + 1] = "cover shown where none is needed" end
		end
		Shot("cover")
		for _, line in ipairs(NewErrors()) do problems[#problems + 1] = "error: " .. line end
		Verdict("cover", problems)
		After(0.5, function() StepClose(index, before) end)
	end)
end

-- 1: opened with the setting on: says All.
local function StepOpen()
	ns.TestPrompt("AddOns list test: step 1 of 3, opening the AddOns list. Nothing to click.", 3600)
	Say("step 1 open")
	if not _G.AddonList and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_AddOnList") end
	local list = _G.AddonList
	if not list then
		Verdict("open", { "no AddonList window on this client" })
		return Finish("DONE")
	end
	if list:IsShown() then
		if AddonList_Hide then pcall(AddonList_Hide, false) else list:Hide() end
	end
	ns.AddonListAllRestart()
	ShowUIPanel(list)
	After(1, function()
		local problems = {}
		local state = ns.AddonListAllState()
		local text = DropdownText(list)
		local secure, taintedBy = true, nil
		if issecurevariable then secure, taintedBy = issecurevariable(list, "shouldReload") end
		Say(("  window shown %s, hooked %s, put on All by us %s, dropdown says %s (ALL %s)"):format(
			tostring(list:IsShown()), tostring(state.hooked), tostring(state.cleared), tostring(text), tostring(ALL)))
		Say(("  INFO shouldReload secure %s%s"):format(tostring(secure), taintedBy and (", tainted by " .. taintedBy) or ""))
		if not list:IsShown() then problems[#problems + 1] = "window didn't open" end
		if not state.cleared then problems[#problems + 1] = "our code didn't put it on All" end
		if text ~= ALL then problems[#problems + 1] = "dropdown doesn't say All" end
		Shot("open")
		for _, line in ipairs(NewErrors()) do problems[#problems + 1] = "error: " .. line end
		Verdict("open", problems)
		After(0.5, StepCover)
	end)
end

function ns.AddonListAllTest()
	if run then return Finish("stopped") end
	if not CinematicDB then return end
	if InCombatLockdown() then return ns.Print("/cine debug addonlist: not in a fight.") end
	local cineWasOn = ns.IsCineModeOn and ns.IsCineModeOn() or false
	if cineWasOn and Cinematic_ToggleCineMode then Cinematic_ToggleCineMode() end
	CinematicDB.addonListLog = {}
	CinematicDB.addonListTest = true
	run = { pass = 0, fail = 0, cineWasOn = cineWasOn, settingWas = ns.db and ns.db.addonListAll,
		logFrom = ns.db and ns.db.log and #ns.db.log }
	local build, _, _, toc = GetBuildInfo()
	Say(("start: client %s (build %s, toc %s), reloadBlocked %s, setting was %s, Quality of life page %s, CineMode was %s")
		:format(ns.isRetail and "retail" or ns.isClassicEra and "Classic Era" or "Forever", tostring(build), tostring(toc),
		tostring(ns.reloadBlocked), tostring(run.settingWas), tostring(ns.db and ns.db.handleQuality), tostring(cineWasOn)))
	if ns.db then ns.db.addonListAll = true end
	if ns.db and ns.db.handleQuality == false then
		Say("  the Quality of life page is off: the setting can't work (FAIL)")
		run.fail = run.fail + 1
		return Finish("DONE")
	end
	StepOpen()
end
