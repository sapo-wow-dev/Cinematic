-- /cine debug addonlist: with "Default Addon list opening to All" on
-- (QoL/AddonListAll.lua), does the game's AddOns window open on All, and does
-- a change made there survive the window's own Reload UI? (2026-11-21: with
-- our secure cover over Reload UI on Forever, nothing was ever saved; the
-- cover's gone.) One addon is the test's (the first that isn't Cinematic or
-- Blizzard's); the test flips its tick itself, for All characters:
--   1 open     the window opened: PASS when its dropdown says All, put there by
--              our code, and no cover of ours is on the window. Its tick
--              flipped; then YOU click Reload UI (the window's own).
--   2 saved    after that reload: PASS when the flip was kept. Flipped back;
--              YOU click Reload UI once more.
--   3 back     after that reload: PASS when it's back as it was.
-- Logs any ADDON_ACTION_BLOCKED / ADDON_ACTION_FORBIDDEN in between. Into
-- CinematicDB.addonListLog, with screenshots. The setting and CineMode put back
-- at the end. Run again to stop (the window closed without saving). Dev copy only.
local _, ns = ...

local function State() return CinematicDB and CinematicDB.addonListTest end

local function Say(text)
	local log = CinematicDB and CinematicDB.addonListLog
	if log then log[#log + 1] = ("%s %s"):format(date("%H:%M:%S"), text) end
end
local function Shot(what)
	local ok = pcall(function() Screenshot() end)
	Say(("  screenshot %s at %s%s"):format(what, date("%m%d%y_%H%M%S"), ok and "" or " (failed)"))
end
local function Verdict(state, name, problems)
	if #problems == 0 then
		state.pass = state.pass + 1
		Say(("  %s verdict PASS"):format(name))
	else
		state.fail = state.fail + 1
		Say(("  %s verdict FAIL: %s"):format(name, table.concat(problems, "; ")))
	end
end

-- Enabled for All characters: 0 none, 1 some, 2 all. And for you.
local function Enabled(name, character)
	local ok, value = pcall(C_AddOns.GetAddOnEnableState, name, character)
	return ok and value or nil
end
local function Flip(name, on)
	if on then C_AddOns.EnableAddOn(name) else C_AddOns.DisableAddOn(name) end
end
local function StateText(name)
	return ("All %s, you %s, loaded %s"):format(tostring(Enabled(name, nil)), tostring(Enabled(name, UnitName("player"))),
		tostring(C_AddOns.IsAddOnLoaded(name)))
end

local function DropdownText(list)
	local dropdown = list and list.Dropdown
	if not dropdown then return nil end
	local ok, text = pcall(function()
		return (dropdown.GetText and dropdown:GetText()) or (dropdown.Text and dropdown.Text:GetText())
	end)
	return ok and text or nil
end

local function Window()
	if not _G.AddonList and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_AddOnList") end
	return _G.AddonList
end

local function Finish(text)
	local state = State()
	if not state then return end
	CinematicDB.addonListTest = nil
	if ns.db then ns.db.addonListAll = state.settingWas end
	if state.cineWasOn and ns.IsCineModeOn and not ns.IsCineModeOn() and Cinematic_ToggleCineMode then
		Cinematic_ToggleCineMode()
	end
	local line = ("%s: %d pass, %d fail"):format(text, state.pass, state.fail)
	Say(line)
	ns.TestPrompt(("AddOns list test %s. Say \"check log\"."):format(line), 15)
end

local function AskReload(state, what)
	ns.TestPrompt(("AddOns list test: %s Click Reload UI in the AddOns list (bottom right)."):format(what), 3600)
	state.waiting = true
end

-- Step 1: opened on All, the test addon flipped, waits for your Reload UI.
local function StepOpen(state)
	Say("step 1 open")
	local list = Window()
	if not list then
		Verdict(state, "open", { "no AddonList window on this client" })
		return Finish("DONE")
	end
	if list:IsShown() then list:Hide() end
	ns.AddonListAllRestart()
	ShowUIPanel(list)
	C_Timer.After(1, function()
		if not State() then return end
		local problems = {}
		local text = DropdownText(list)
		local secure, by = true, nil
		if issecurevariable then secure, by = issecurevariable(list, "shouldReload") end
		Say(("  window shown %s, put on All by us %s, dropdown says %s (ALL %s), cover of ours %s"):format(
			tostring(list:IsShown()), tostring(ns.AddonListAllState().cleared), tostring(text), tostring(ALL),
			tostring(_G.CinematicAddonListReload ~= nil)))
		Say(("  INFO shouldReload secure %s%s"):format(tostring(secure), by and (", by " .. by) or ""))
		if not list:IsShown() then problems[#problems + 1] = "window didn't open" end
		if not ns.AddonListAllState().cleared then problems[#problems + 1] = "our code didn't put it on All" end
		if text ~= ALL then problems[#problems + 1] = "dropdown doesn't say All" end
		if _G.CinematicAddonListReload then problems[#problems + 1] = "a cover of ours is still made" end
		Verdict(state, "open", problems)
		-- The test's addon flipped, for All characters.
		local name
		for i = 1, C_AddOns.GetNumAddOns() do
			local each = C_AddOns.GetAddOnInfo(i)
			if each and each ~= "Cinematic" and each ~= "CinematicDev" and not each:find("^Blizzard_") then
				name = each
				break
			end
		end
		if not name then
			Say("  no other addon to flip: nothing more to check (INFO)")
			list:Hide()
			return Finish("DONE")
		end
		local before = Enabled(name, nil)
		state.addon, state.before, state.want = name, before, (before == 2) and 0 or 2
		Say(("  test addon %s before: %s"):format(name, StateText(name)))
		Flip(name, state.want == 2)
		if AddonList_Update then pcall(AddonList_Update) end
		Say(("  flipped to %s: %s; button says %s"):format(state.want == 2 and "on" or "off", StateText(name),
			tostring(list.OkayButton and list.OkayButton:GetText())))
		Shot("open")
		state.step = "saved"
		AskReload(state, ("%s was turned %s for All characters."):format(name, state.want == 2 and "on" or "off"))
	end)
end

-- Steps 2 and 3, after each reload.
local function AfterReload(state)
	local name = state.addon
	state.waiting = nil
	Say(("after reload (%s): %s; blocked lines so far %d"):format(state.step, StateText(name), state.blocked or 0))
	if state.step == "saved" then
		Verdict(state, "saved", Enabled(name, nil) == state.want and {} or
			{ ("the change wasn't kept: All %s, wanted %s"):format(tostring(Enabled(name, nil)), tostring(state.want)) })
		local list = Window()
		ShowUIPanel(list)
		C_Timer.After(1, function()
			if not State() then return end
			Flip(name, state.before == 2)
			if AddonList_Update then pcall(AddonList_Update) end
			Say(("  flipped back: %s; dropdown says %s; button says %s"):format(StateText(name), tostring(DropdownText(list)),
				tostring(list.OkayButton and list.OkayButton:GetText())))
			Shot("back")
			state.step = "back"
			AskReload(state, ("putting %s back as it was."):format(name))
		end)
	elseif state.step == "back" then
		Verdict(state, "back", Enabled(name, nil) == state.before and {} or
			{ ("not back: All %s, was %s"):format(tostring(Enabled(name, nil)), tostring(state.before)) })
		Finish("DONE")
	end
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:RegisterEvent("ADDON_ACTION_BLOCKED")
watcher:RegisterEvent("ADDON_ACTION_FORBIDDEN")
watcher:SetScript("OnEvent", function(_, event, who, what)
	local state = State()
	if not state then return end
	if event == "PLAYER_LOGIN" then
		if state.step then
			C_Timer.After(3, function()
				if State() then AfterReload(State()) end
			end)
		end
	else
		state.blocked = (state.blocked or 0) + 1
		Say(("  %s: %s %s"):format(event, tostring(who), tostring(what)))
	end
end)

function ns.AddonListAllTest()
	local state = State()
	if state then
		if _G.AddonList and _G.AddonList:IsShown() then
			if AddonList_Hide then pcall(AddonList_Hide, false) else _G.AddonList:Hide() end
		end
		return Finish("stopped")
	end
	if not CinematicDB then return end
	if InCombatLockdown() then return ns.Print("/cine debug addonlist: not in a fight.") end
	local cineWasOn = ns.IsCineModeOn and ns.IsCineModeOn() or false
	if cineWasOn and Cinematic_ToggleCineMode then Cinematic_ToggleCineMode() end
	CinematicDB.addonListLog = {}
	state = { pass = 0, fail = 0, cineWasOn = cineWasOn, settingWas = ns.db and ns.db.addonListAll }
	CinematicDB.addonListTest = state
	local build, _, _, toc = GetBuildInfo()
	Say(("start: client %s (build %s, toc %s), you %s, setting was %s, Quality of life page %s, CineMode was %s"):format(
		ns.isRetail and "retail" or ns.isClassicEra and "Classic Era" or "Forever", tostring(build), tostring(toc),
		tostring(UnitName("player")), tostring(state.settingWas), tostring(ns.db and ns.db.handleQuality),
		tostring(cineWasOn)))
	if ns.db then ns.db.addonListAll = true end
	if ns.db and ns.db.handleQuality == false then
		Say("  the Quality of life page is off: the setting can't work (FAIL)")
		state.fail = state.fail + 1
		return Finish("DONE")
	end
	StepOpen(state)
end
