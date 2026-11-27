-- Testing Cinematic's support for another addon (the /addon-support skill's
-- in-game half). Dev copy only.
--
-- /cine debug solo <Addon> [more addons]: turns every other addon off and
-- reloads, so only that addon (its own parts, <Addon>* folders, and what it
-- needs to load) runs with Cinematic. /cine debug solo off puts the list back
-- as it was and reloads. While solo is on, each login says so on screen and
-- names any other addon that still loaded.
--
-- /cine debug addontest <Addon> [quick|full]: one run that tests itself,
-- logged into CinematicDB.addonTestLog (/reload, then "check log"). CineMode
-- off for the run, back as it was at the end (3 seconds to settle first, so
-- frames fading in as CineMode goes off count as already up).
--   1 target: you target anything (frames that only show with a target);
--   2 fight: you fight something, a dummy will do; it goes on once the
--     fight ends (quick skips 1 and 2). A step that showed no new kind of
--     frame is skipped the next time, on the same version of the addon
--     (CinematicDB.addonTestSteps); full asks both again;
--   3 rows: hands off. Each row the addon's frames fade with (its own rows on
--     the Addons page, and the game's rows its frames stand in for) is hidden
--     by its key, then shown, then handed back. Per row: did every frame go to
--     0 and stay there (an addon setting its alpha back fights our fade), did
--     each come back, and did it stop taking the mouse while hidden (hover
--     would need ns.HOVER_BY_RECT). A screenshot of each hidden row.
-- All along, every frame the addon made (named or not, told by the game's
-- taint record: whose code made it) that draws something on screen is
-- checked: faded by us (itself or a frame it sits in), left alone on
-- purpose, or NOT COVERED. Every NOT COVERED frame is a frame the support
-- missed. Verdicts at the end. Frames our support names for it that it never
-- made (its tracker off in its own options, say) make "its frames were made"
-- a can't tell, and so does a run with no row to test: never a PASS on a run
-- that tested nothing.
local addonName, ns = ...

local GetNum = C_AddOns and C_AddOns.GetNumAddOns or _G.GetNumAddOns
local GetInfo = C_AddOns and C_AddOns.GetAddOnInfo or _G.GetAddOnInfo
local GetDeps = C_AddOns and C_AddOns.GetAddOnDependencies or _G.GetAddOnDependencies
local GetOptDeps = C_AddOns and C_AddOns.GetAddOnOptionalDependencies or _G.GetAddOnOptionalDependencies
local IsLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or _G.IsAddOnLoaded
local EnableAddOn = C_AddOns and C_AddOns.EnableAddOn or _G.EnableAddOn
local DisableAddOn = C_AddOns and C_AddOns.DisableAddOn or _G.DisableAddOn
local SaveAddOns = C_AddOns and C_AddOns.SaveAddOns or _G.SaveAddOns
local GetMeta = C_AddOns and C_AddOns.GetAddOnMetadata or _G.GetAddOnMetadata

local function Secret(value) return issecretvalue and issecretvalue(value) end
local function Num(value)
	if value == nil then return "nil" end
	if Secret(value) then return "secret" end
	if type(value) == "number" then return ("%.2f"):format(value) end
	return tostring(value)
end
local function Call(object, method, ...)
	if not (object and object[method]) then return nil end
	local ok, a, b, c, d = pcall(object[method], object, ...)
	if not ok then return nil end
	return a, b, c, d
end

-- Every addon in the list: { name, enabled, loaded, state (0 off, 1 some
-- characters, 2 all) }. (GetAddOnEnableState's arguments swapped places
-- between clients: both tried.)
local function EnableState(name)
	local fn = C_AddOns and C_AddOns.GetAddOnEnableState
	if fn then
		local ok, state = pcall(fn, name)
		if ok and type(state) == "number" then return state end
		ok, state = pcall(fn, name, UnitName("player"))
		if ok and type(state) == "number" then return state end
	end
	if _G.GetAddOnEnableState then
		local ok, state = pcall(_G.GetAddOnEnableState, nil, name)
		if ok and type(state) == "number" then return state end
	end
	return nil
end

-- An addon switched on or off, then read back: the no-character call first
-- (engine rule forever.addons.enable-no-character), then with the character.
-- True when its enable state now says so. (The addon kit's qcbb3 run,
-- 2026-11-25: solo asked MikScrollingBattleText_Forever on and Guidelime off,
-- and after the reload the opposite had loaded; nothing said which switch
-- didn't take. Now each one is checked as it's made.)
-- (The addons solo turned off this session: still loaded till the reload,
-- and off, which AddOns below must not read as on.)
local offThisSession = {}
local function Switch(name, on)
	offThisSession[name] = not on or nil
	local function Took()
		local state = EnableState(name)
		if on then return type(state) == "number" and state > 0 end
		return state == 0
	end
	pcall(on and EnableAddOn or DisableAddOn, name)
	if Took() then return true end
	pcall(on and EnableAddOn or DisableAddOn, name, UnitName("player"))
	return Took() and true or false
end

local function AddOns()
	local out = {}
	for i = 1, (GetNum and tonumber((GetNum())) or 0) do -- (a stand-in game's stub answers a table)
		local name, _, _, _, reason = GetInfo(i)
		if name then
			-- (On or off by its enable state: GetAddOnInfo's reason stays
			-- DISABLED till the next login for one switched on this session, so
			-- the addon kit's second solo, after solo off put the list back,
			-- left Auctionator on and it loaded with Journey Tracker,
			-- 2026-11-25. Engine rule forever.addons.enable-no-character.)
			local state = EnableState(name)
			local enabled = reason ~= "DISABLED"
			if type(state) == "number" then enabled = state > 0 end
			-- (Loaded now, it's on, unless solo turned it off this session: the
			-- state with no character reads 0 for an addon on for this character
			-- only. ElvUI was, and the addon kit's no-addon stage never turned it
			-- off, run qa37c 2026-11-25. Engine rule forever.addons.state-per-character.)
			if not enabled and IsLoaded(name) and not offThisSession[name] then enabled = true end
			out[#out + 1] = {
				name = name, enabled = enabled, loaded = IsLoaded(name) and true or false, state = state,
			}
		end
	end
	return out
end

-- The installed addon whose name is this (any case), or nil.
local function Resolve(typed)
	for _, each in ipairs(AddOns()) do
		if each.name:lower() == typed:lower() then return each.name end
	end
	return nil
end

-- Whether an addon name is the target's, or one of its parts (EllesmereUI's
-- EllesmereUIResourceBars, Questie's Questie_*).
local function Belongs(name, target)
	return type(name) == "string" and name:lower():sub(1, #target) == target:lower()
end

-- A frame's kind: its name with numbers and table ids as # (QuestieFrame20
-- and QuestieFrame582 are one kind, Questie_BaseFrame.2383c32b310 too). A
-- step that only shows more of a kind seen before found nothing new.
function ns.AddonTestKind(name)
	local kind = tostring(name or "?"):gsub("%.%x%x%x%x%x%x+", ".#")
	return (kind:gsub("%d+", "#"))
end

-- The target and fight steps to skip: the ones the last run on this version
-- of the addon ran and saw no new kind of frame in. record is
-- CinematicDB.addonTestSteps[addon]: { version, target = bool, fight = bool }.
function ns.AddonTestSkips(record, version, full)
	local skip = {}
	if full or type(record) ~= "table" or record.version ~= version then return skip end
	for _, tag in ipairs({ "target", "fight" }) do
		if record[tag] == false then skip[tag] = true end
	end
	return skip
end

-- The frames our support names for the target (its frames on the game's rows,
-- every name on its Addons page rows) that don't exist: never made, so the
-- rows they're on can't be tested.
-- Second list: the ones it made that we haven't taken over yet (no
-- ns.managed entry): their row would test without them.
function ns.AddonTestMissing(target)
	local missing, untaken, seen, managed = {}, {}, {}, {}
	for _, entry in ipairs(ns.managed or {}) do
		if entry.frame then managed[entry.frame] = true end
	end
	local function Check(name, its)
		if type(name) == "string" and not seen[name] and (its or Belongs(name, target)) then
			seen[name] = true
			local frame = rawget(_G, name)
			if type(frame) ~= "table" then
				missing[#missing + 1] = name
			elseif not managed[frame] then
				untaken[#untaken + 1] = name
			end
		end
	end
	for _, item in ipairs(ns.COMBAT_SHOW or {}) do
		for _, name in ipairs(item.frames or {}) do Check(name) end
	end
	for _, known in ipairs(ns.ADDON_FRAMES or {}) do
		if Belongs(known.addon, target) then
			for _, name in ipairs(known.names or {}) do Check(name, true) end
		end
	end
	table.sort(missing)
	table.sort(untaken)
	return missing, untaken
end

-------------------------------------------------------------------- solo
-- (Libraries it can use, kept: LibSharedMedia, Ace3... Not every "!" name:
-- !KalielsTracker is a whole tracker, kept by mistake in the first run.)
local function IsLib(name)
	return (name:find("^Lib") or name:find("^Ace")) ~= nil
end

-- noReload: the addon list set, no reload asked (the addon kit's test asks
-- with its own Reload button, Dev/AddonKitTest.lua).
function ns.SoloAddons(words, noReload)
	local db = CinematicDB
	local ReloadOrAsk = noReload and function() end or ns.ReloadOrAsk
	if words == "" then
		local solo = db.soloAddons
		ns.Print(type(solo) == "table" and ("solo: on since %s for %s. /cine debug solo off brings the rest back."):format(
			tostring(solo.at), table.concat(solo.keep or {}, ", "))
			or "solo: off. /cine debug solo <Addon> [more] turns every other addon off and reloads.")
		return
	end
	if words == "off" then
		local solo = db.soloAddons
		if type(solo) ~= "table" then
			ns.Print("solo: not on. /cine debug solo <Addon> turns every other addon off.")
			return
		end
		-- (Each switch read back. The character form came first for an addon on
		-- for some characters only; on Forever it doesn't reach the character,
		-- engine rule forever.addons.enable-no-character.)
		local unconfirmed = {}
		for name in pairs(solo.turnedOff or {}) do
			if not Switch(name, true) then unconfirmed[#unconfirmed + 1] = name .. " (still off)" end
		end
		for name, state in pairs(solo.turnedOn or {}) do
			if state == 0 and not Switch(name, false) then unconfirmed[#unconfirmed + 1] = name .. " (still on)" end
		end
		table.sort(unconfirmed)
		if #unconfirmed > 0 then
			ns.Print("solo off: these didn't switch back: " .. table.concat(unconfirmed, ", "))
		end
		db.soloOffUnconfirmed = #unconfirmed > 0 and unconfirmed or nil
		-- (What the list must be after the reload: checked at login, ns.SoloCheck.
		-- A stale read once left Questie on without QuestieDB after this.)
		local back = { on = {}, off = {} }
		for name in pairs(solo.turnedOff or {}) do back.on[#back.on + 1] = name end
		for name, state in pairs(solo.turnedOn or {}) do if state == 0 then back.off[#back.off + 1] = name end end
		db.soloBack = back
		db.soloAddons = nil
		SaveAddOns()
		ns.Print("solo off: your addon list is back. Reloading.")
		ReloadOrAsk("Solo off: your addon list is back. Reload now?")
		return
	end
	if type(db.soloAddons) == "table" then
		ns.Print("solo: already on for " .. table.concat(db.soloAddons.keep or {}, ", ") ..
			". /cine debug solo off first.")
		return
	end
	local keep, turnedOff, turnedOn = {}, {}, {}
	keep[addonName] = true
	local wanted = {}
	-- ("none": no other addon at all, Cinematic alone: the addon kit's
	-- baseline, Tools/addon-kit/diff.py baseline.)
	for typed in (words == "none" and "" or words):gmatch("%S+") do
		local name = Resolve(typed)
		if not name then
			ns.Print("solo: no addon called " .. typed .. " is installed.")
			return
		end
		wanted[#wanted + 1] = name
	end
	local all = AddOns()
	-- Its parts (folders starting with its name) that were on, and what each
	-- kept one needs to load (and the libraries it can use), all the way down.
	-- An addon that was off itself brings every part of it: its parts were off
	-- with it, not picked (EllesmereUI turned off for another UI suite came back
	-- as its core alone, none of its frames made, 2026-11-20).
	for _, name in ipairs(wanted) do
		keep[name] = true
		local wasOn = false
		for _, each in ipairs(all) do
			if each.name == name then wasOn = each.enabled end
		end
		for _, each in ipairs(all) do
			if (each.enabled or not wasOn) and Belongs(each.name, name) then keep[each.name] = true end
		end
	end
	local changed = true
	while changed do
		changed = false
		-- (A copy to walk: adding to a table pairs is walking is undefined in
		-- Lua and can skip keys.)
		local names = {}
		for name in pairs(keep) do names[#names + 1] = name end
		for _, name in ipairs(names) do
			for _, dep in ipairs(GetDeps and { GetDeps(name) } or {}) do
				if dep and not keep[dep] then keep[dep], changed = true, true end
			end
			-- (A kept addon's own parts come too, on or off: a dependency's parts
			-- are its own pieces, not the player's picks. Questie, kept for
			-- Guidelime, needs its QuestieDB, only an optional dependency of it;
			-- without it Questie errored at load, 2026-11-25.)
			if not IsLib(name) then
				for _, each in ipairs(all) do
					if not keep[each.name] and Belongs(each.name, name) then
						ns.Print(("solo: %s comes with %s (its part)"):format(each.name, name))
						keep[each.name], changed = true, true
					end
				end
			end
			for _, dep in ipairs(GetOptDeps and { GetOptDeps(name) } or {}) do
				if dep and IsLib(dep) and not keep[dep] then keep[dep], changed = true, true end
			end
		end
	end
	local unconfirmed = {}
	for _, each in ipairs(all) do
		if keep[each.name] then
			if not each.enabled then
				turnedOn[each.name] = each.state or 0
				if not Switch(each.name, true) then unconfirmed[#unconfirmed + 1] = each.name .. " (still off)" end
			end
		elseif each.enabled then
			turnedOff[each.name] = each.state or 2
			if not Switch(each.name, false) then unconfirmed[#unconfirmed + 1] = each.name .. " (still on)" end
		end
	end
	table.sort(unconfirmed)
	local kept = {}
	for name in pairs(keep) do kept[#kept + 1] = name end
	table.sort(kept)
	db.soloAddons = { keep = kept, turnedOff = turnedOff, turnedOn = turnedOn, at = date("%Y-%m-%d %H:%M"),
		unconfirmed = #unconfirmed > 0 and unconfirmed or nil }
	-- (This solo decides the list now: a solo off just before it, as the addon
	-- kit does between its stages, no longer expects its list back at login.
	-- Its "NOT BACK: Guidelime is still off" in run qcbb3 was this one turning
	-- Guidelime off, as asked.)
	db.soloBack = nil
	if #unconfirmed > 0 then
		ns.Print("solo: these didn't switch: " .. table.concat(unconfirmed, ", ") .. " (the list after the reload won't be solo's)")
	end
	SaveAddOns()
	ns.Print(("solo: only %s now. Reloading; /cine debug solo off brings the rest back."):format(table.concat(kept, ", ")))
	ReloadOrAsk(("Solo: only %s now. Reload now?"):format(table.concat(kept, ", ")))
end

-- Other addons loaded besides the solo ones (and the game's own): the check.
local function Others(keep)
	local kept, out = {}, {}
	for _, name in ipairs(keep or {}) do kept[name] = true end
	for _, each in ipairs(AddOns()) do
		if each.loaded and not kept[each.name] and not each.name:find("^Blizzard_") then
			out[#out + 1] = each.name
		end
	end
	return out
end

-- After a solo or solo off reload: is the addon list what it should be?
-- (Known error solo-split-companion, Tools/errors/known.lua: Guidelime's solo
-- kept Questie but not QuestieDB, and Questie threw 7 errors every reload,
-- after solo off too, 2026-11-25.) Returns a list of problem lines:
--   SPLIT: a kept addon loaded while a part of it (a folder starting with its
--          name) that solo turned off is still off;
--   LOAD ERRORS: a kept addon (not ours) errored at load;
--   NOT BACK: after solo off, an addon that isn't as it was before the solo.
--   (no solo, no solo off) SPLIT: any loaded addon that errored since login
--          while a part of it is off (the list a solo left before this check).
-- Second return: the fixes, { enable = { names }, disable = { names } }:
-- ns.SoloRepair applies them (the user, 2026-11-25: "do stuff for me").
function ns.SoloCheck(solo, back)
	local problems, byName = {}, {}
	local fixes, fixing = { enable = {}, disable = {} }, {}
	local function Fix(list, name)
		if not fixing[name] then fixing[name] = true; list[#list + 1] = name end
	end
	local all = AddOns()
	for _, each in ipairs(all) do byName[each.name] = each end
	if type(solo) == "table" then
		for name in pairs(solo.turnedOff or {}) do
			local part = byName[name]
			for _, each in ipairs(all) do
				if part and not part.enabled and each.loaded and each.name ~= name and not IsLib(each.name)
					and Belongs(name, each.name) then
					problems[#problems + 1] = ("SPLIT: %s is loaded but its %s is off"):format(each.name, name)
					Fix(fixes.enable, name)
				end
			end
		end
		local kept = {}
		for _, name in ipairs(solo.keep or {}) do if name ~= addonName then kept[#kept + 1] = name end end
		local errors = {}
		for _, entry in ipairs(ns.DevErrorEntries and ns.DevErrorEntries() or {}) do
			for _, name in ipairs(kept) do
				if type(entry.source) == "string" and Belongs(entry.source, name) then
					errors[name] = (errors[name] or 0) + 1
				end
			end
		end
		for name, n in pairs(errors) do
			problems[#problems + 1] = ("LOAD ERRORS: %s had %d error(s) since login (a part of it off?)"):format(name, n)
		end
	end
	if type(back) == "table" then
		for _, name in ipairs(back.on or {}) do
			local each = byName[name]
			if each and not each.enabled then
				problems[#problems + 1] = ("NOT BACK: %s is still off"):format(name)
				Fix(fixes.enable, name)
			end
		end
		for _, name in ipairs(back.off or {}) do
			local each = byName[name]
			if each and each.enabled then
				problems[#problems + 1] = ("NOT BACK: %s is still on"):format(name)
				Fix(fixes.disable, name)
			end
		end
	end
	if type(solo) ~= "table" then
		-- Any loaded addon that errored since login with a part of it off.
		local errored = {}
		for _, entry in ipairs(ns.DevErrorEntries and ns.DevErrorEntries() or {}) do
			if type(entry.source) == "string" then errored[entry.source] = true end
		end
		for _, each in ipairs(all) do
			if each.loaded and errored[each.name] and each.name ~= addonName and not IsLib(each.name) then
				for _, part in ipairs(all) do
					if part.name ~= each.name and not part.enabled and Belongs(part.name, each.name) then
						problems[#problems + 1] = ("SPLIT: %s errored at load and its %s is off"):format(each.name, part.name)
						Fix(fixes.enable, part.name)
					end
				end
			end
		end
	end
	table.sort(problems)
	return problems, fixes
end

-- Puts the addon list right (the fixes ns.SoloCheck found) and saves it;
-- returns what it changed. The reload loads it.
function ns.SoloRepair(fixes)
	local done = {}
	for _, name in ipairs(fixes and fixes.enable or {}) do
		if Switch(name, true) then done[#done + 1] = name .. " on" end
	end
	for _, name in ipairs(fixes and fixes.disable or {}) do
		if Switch(name, false) then done[#done + 1] = name .. " off" end
	end
	if #done > 0 then pcall(SaveAddOns) end
	return done
end

do
	local login = CreateFrame("Frame")
	login:RegisterEvent("PLAYER_LOGIN")
	login:SetScript("OnEvent", function()
		local solo = CinematicDB and CinematicDB.soloAddons
		local back = CinematicDB and CinematicDB.soloBack
		-- (Every login, not only after a solo: a list a solo split before this
		-- check, Questie on with QuestieDB off, is caught by its load errors.)
		-- (Late enough for the kept addons' load errors to be in the error window.)
		C_Timer.After(3, function()
			local problems, fixes = ns.SoloCheck(solo, back)
			if CinematicDB then CinematicDB.soloBack = nil end
			for _, line in ipairs(problems) do if ns.Log then ns.Log("solo", line) end end
			ns.soloProblems = problems
			-- Fixed by itself, not asked: the list put right, a Reload button.
			local fixed = #problems > 0 and ns.SoloRepair(fixes) or {}
			if #fixed > 0 and ns.Log then ns.Log("solo", "fixed the addon list: " .. table.concat(fixed, ", ")) end
			local msg
			if type(solo) == "table" then
				local others = Others(solo.keep)
				msg = "SOLO: only " .. table.concat(solo.keep or {}, ", ") .. " (/cine debug solo off brings the rest back)"
				if #others > 0 then msg = msg .. "\nStill loaded too: " .. table.concat(others, ", ") end
			elseif #problems > 0 then
				msg = "Your addon list was split."
			end
			if #problems > 0 then
				msg = msg .. "\n|cffff6060" .. table.concat(problems, "\n") .. "|r"
				ns.Print("solo check: " .. table.concat(problems, "; "))
			end
			if #fixed > 0 then
				msg = msg .. "\n|cff5fdf6eFixed: " .. table.concat(fixed, ", ") .. "|r"
				ns.Print("solo check fixed it: " .. table.concat(fixed, ", ") .. ". Reload to load it.")
				-- (A big Reload button, unless a test is going: its own buttons stay,
				-- and its next reload loads the fix.)
				local kit = ns.TestKit
				if kit and kit.ShowButtons and not (kit.Running and kit.Running() and not kit.Running().stopped) then
					msg = msg .. "\nClick Reload below to load it."
					kit.ShowButtons({ { kind = "reload" }, { label = "Not now", fn = function() kit.HideButtons() end } })
				else
					msg = msg .. "\nThe next reload loads it."
				end
			end
			if msg then ns.TestPrompt(msg, #problems > 0 and 30 or 12) end
		end)
	end)
end

-------------------------------------------------------------------- the test
local MAX_LINES = 6000
local SETTLE = 4 -- seconds a row gets to reach its alpha
local HOLD = 1.5 -- seconds it must stay there (an addon setting its own back)
local MADE_WAIT = 20 -- seconds given to frames it makes late (Questie's tracker, seconds after a /reload)
local MADE_SETTLE = 3 -- then seconds for them to settle (Questie hides and shows its tracker once more)
-- Fade in and out while the rows run: a row checks it hides, stays hidden and
-- comes back, not the fade (the player's 1.5 s each way was 3 of a row's 7 s).
local ROW_FADE = 0.2
local ROW_GAP = 0.2 -- seconds between rows (one shot a row, already seconds apart)
local run

local function Log(text)
	local log = CinematicDB and CinematicDB.addonTestLog
	if not log or #log >= MAX_LINES then return end
	log[#log + 1] = ("%.2f %s %s"):format(GetTime(), run and run.stage or "-", text)
end

local function Verdict(name, ok, detail)
	Log(("VERDICT %s: %s%s"):format(name, ok == nil and "CAN'T TELL" or (ok and "PASS" or "FAIL"),
		detail and (" (" .. detail .. ")") or ""))
	if run then
		local kind = ok == nil and "unclear" or (ok and "pass" or "fail")
		run.tally[kind] = run.tally[kind] + 1
	end
end

local function Shot(what)
	local ok = pcall(function() Screenshot() end)
	Log(ok and ("screenshot %s at %s"):format(what, date("%m%d%y_%H%M%S")) or "screenshot failed")
end

local function SetCine(on)
	if not (ns.IsCineModeOn and Cinematic_ToggleCineMode) then return end
	if (ns.IsCineModeOn() and true or false) ~= on then
		Cinematic_ToggleCineMode()
		Log("CineMode turned " .. (on and "on" or "off") .. " by the test")
	end
end

local function Name(frame)
	local name = Call(frame, "GetName")
	if type(name) == "string" then return name end
	return tostring(Call(frame, "GetDebugName") or "?")
end

-- Whose code made the frame (and how that's known): a named one by its
-- global name's taint (the game's own read as secure: nil); an unnamed one
-- by a field an addon set on it, not counting ours or a hooked method (a
-- hook writes the method onto the frame: whoever hooked it, not who made
-- it). A field only says who touched it, so those are marked "field".
local owners = setmetatable({}, { __mode = "k" })
local ownedHow = setmetatable({}, { __mode = "k" })
local function Owner(frame)
	local known = owners[frame]
	if known ~= nil then return known or nil, ownedHow[frame] end
	local by, how
	local name = Call(frame, "GetName")
	if type(name) == "string" and _G[name] == frame then
		local secure, who = issecurevariable(name)
		if not secure then by, how = who, "name" end
	else
		pcall(function()
			local meta = getmetatable(frame)
			local methods = meta and type(meta.__index) == "table" and meta.__index or {}
			for key, value in pairs(frame) do
				if key ~= 0 and not (type(value) == "function" and methods[key]) then
					local secure, who = issecurevariable(frame, key)
					if not secure and who and who ~= addonName and who ~= "Cinematic" then
						by, how = who, "field"
						break
					end
				end
			end
		end)
	end
	owners[frame], ownedHow[frame] = by or false, how
	return by, how
end

local function Rect(frame)
	local left, bottom, width, height = Call(frame, "GetRect")
	if type(left) ~= "number" or Secret(left) or Secret(width) or Secret(bottom) or Secret(height) then return nil end
	local scale = (Call(frame, "GetEffectiveScale") or 1) / UIParent:GetEffectiveScale()
	return left * scale, bottom * scale, width * scale, height * scale
end

-- Whether it draws anything itself: a shown texture or text with something
-- in it, or a kind of frame that draws (a bar, a cooldown swirl, a model).
local DRAWS = { StatusBar = true, Cooldown = true, PlayerModel = true, Model = true, ModelScene = true }
local function Draws(frame)
	if DRAWS[Call(frame, "GetObjectType") or ""] then return true end
	local drawn = false
	pcall(function()
		for _, region in ipairs({ frame:GetRegions() }) do
			if region:IsShown() then
				local kind = region:GetObjectType()
				if kind == "FontString" then
					local text = region:GetText()
					if Secret(text) or (text and text ~= "") then drawn = true break end
				elseif kind == "Texture" then
					-- (A color texture has no file: any shown one at some alpha.)
					local alpha = region:GetAlpha()
					if Secret(alpha) or alpha > 0 then drawn = true break end
				end
			end
		end
	end)
	return drawn
end

local function FirstText(frame)
	local found
	pcall(function()
		for _, region in ipairs({ frame:GetRegions() }) do
			if region:GetObjectType() == "FontString" then
				local text = region:GetText()
				if text and not Secret(text) and text ~= "" then found = text:sub(1, 40) break end
			end
		end
	end)
	return found
end

-- How our side covers a frame: "faded in <group>" (it or a frame it sits
-- in), "left alone", or nil.
local function Coverage(frame, managedBy)
	local at = frame
	for _ = 1, 30 do
		if not at then break end
		local entry = managedBy[at]
		if entry then
			return at == frame and ("faded in " .. tostring(entry.group))
				or ("in %s, faded in %s"):format(Name(at), tostring(entry.group))
		end
		-- (A tooltip's parts show with the tooltip, on hover: not a HUD frame.)
		if Call(at, "GetObjectType") == "GameTooltip" then return "in a tooltip (shows on hover)" end
		local name = Call(at, "GetName")
		if type(name) == "string" and ns.IsLeftAlone and ns.IsLeftAlone(name) then return "left alone" end
		if ns.IsLeftAloneFrame and ns.IsLeftAloneFrame(at) then return "left alone" end
		-- (Ignores its parent's alpha: a faded parent doesn't take it.)
		local ignores = Call(at, "IsIgnoringParentAlpha")
		if not Secret(ignores) and ignores == true then return nil end
		at = Call(at, "GetParent")
		if at == UIParent then break end
	end
	return nil
end

local function ManagedBy()
	local map = {}
	for _, entry in ipairs(ns.managed or {}) do
		if entry.frame then map[entry.frame] = entry end
	end
	return map
end

-- At the end, each frame still NOT COVERED asked again, drawn now or not: one
-- seen once before our scan had claimed it, that never drew again after,
-- kept its first line (EllesmereUIDMFrame1 in the addon kit's run qb025,
-- 2026-11-25, though its row hid and showed it). Its line says so.
function ns.AddonTestCoverAgain(frames, managedBy)
	for frame, seen in pairs(frames) do
		if not seen.cover then
			local cover = Coverage(frame, managedBy)
			if cover then
				seen.cover = cover
				seen.line = seen.line:gsub("NOT COVERED", "covered by the end: " .. cover, 1)
				Log("frame " .. seen.line)
			end
		end
	end
end

-- One pass over every frame: the target's frames drawing on screen, each
-- logged the first time seen (and again if its cover changes).
local function Inventory()
	if not run then return end
	local managedBy = ManagedBy()
	local screenW, screenH = UIParent:GetWidth(), UIParent:GetHeight()
	local frame = EnumerateFrames()
	while frame do
		if not Call(frame, "IsForbidden") and Belongs(Owner(frame), run.target) then
			local visible = Call(frame, "IsVisible")
			local alpha = Call(frame, "GetEffectiveAlpha")
			local onScreen = (Secret(visible) or visible) and (Secret(alpha) or (type(alpha) == "number" and alpha > 0.01))
			local left, bottom, width, height = Rect(frame)
			if onScreen and left and width > 1 and height > 1 and left < screenW and left + width > 0
				and bottom < screenH and bottom + height > 0 and Draws(frame) then
				local kind = ns.AddonTestKind(Name(frame))
				if not run.kinds[kind] then run.kinds[kind] = run.stage end
				local cover = Coverage(frame, managedBy)
				local seen = run.frames[frame]
				if not seen or seen.cover ~= cover then
					local by, how = Owner(frame)
					local line = ("%s (%s, by %s from its %s) %s: %.0fx%.0f at %.0f,%.0f, %s, alpha %s, parent %s%s"):format(
						Name(frame), tostring(Call(frame, "GetObjectType")), tostring(by), tostring(how),
						cover and ("covered: " .. cover) or "NOT COVERED", width, height, left + width / 2,
						bottom + height / 2, tostring(Call(frame, "GetFrameStrata")), Num(alpha),
						Name(Call(frame, "GetParent")), FirstText(frame) and (", text \"" .. FirstText(frame) .. "\"") or "")
					Log("frame " .. line)
					run.frames[frame] = { cover = cover, line = line, stage = run.stage }
				end
			end
		end
		frame = EnumerateFrames(frame)
	end
end

-- The rows its frames fade with: its own rows (Addons page), the game's
-- rows naming one of its frames (FadeWithRow), and the game's rows whose own
-- search took one of its frames (an addon's own minimap button on the Addon
-- buttons row, found by Frames.lua's minimap scan with no Support file).
local function Rows(target)
	target = target or run.target
	local rows = {}
	local foundIn = {}
	for _, entry in ipairs(ns.managed or {}) do
		if entry.frame and entry.group and Belongs(Owner(entry.frame), target) then foundIn[entry.group] = true end
	end
	for _, item in ipairs(ns.COMBAT_SHOW or {}) do
		local mine = item.addon and Belongs(item.addon, target)
		if not mine then
			for _, name in ipairs(item.frames or {}) do
				local frame = _G[name]
				if type(frame) == "table" and Belongs(Owner(frame), target) then mine = true break end
			end
		end
		if not mine and not item.addon then
			for _, group in ipairs(item.groups or {}) do
				if foundIn[group] then mine = true break end
			end
		end
		if mine then rows[#rows + 1] = item end
	end
	return rows
end
-- (For the offline check, Tools/offline/addontestsmarts.lua.)
ns.AddonTestRows = Rows

-- The target's managed frames a row covers. (Its own rows' frames are all
-- its own, unnamed ones found by match() too, whatever the taint says.)
local function RowEntries(item)
	local groups, names, out = {}, {}, {}
	for _, group in ipairs(item.groups or {}) do groups[group] = true end
	for _, name in ipairs(item.frames or {}) do names[name] = true end
	local itsRow = item.addon and Belongs(item.addon, run.target)
	for _, entry in ipairs(ns.managed or {}) do
		if entry.frame and (groups[entry.group] or (entry.name and names[entry.name]))
			and (itsRow or Belongs(Owner(entry.frame), run.target)) then
			out[#out + 1] = entry
		end
	end
	return out
end

local function Force(key, state)
	ns.db.frameForce[key] = state
	if ns.db.frameForceAt then ns.db.frameForceAt[key] = state and GetTime() or nil end
	ns.RefreshFrameForce()
end

local function Read(entry)
	local frame = entry.frame
	return {
		visible = Call(frame, "IsVisible"), alpha = Call(frame, "GetEffectiveAlpha"),
		-- (Secret on some frames: DaylightUI's buff buttons, 2026-11-19. A
		-- secret can't be compared, so it's kept as the word.)
		mouse = (function()
			-- (Hover is the mouse moving over it: our faded bars turn only
			-- their clicks off, on purpose, so IsMouseEnabled reads false.)
			local value = frame.IsMouseMotionEnabled and Call(frame, "IsMouseMotionEnabled")
			if value == nil then value = Call(frame, "IsMouseEnabled") end
			if Secret(value) then return "secret" end
			return value
		end)(), ours = entry.alpha, base = entry.baseAlpha,
	}
end

-- Waits till every entry meets want (or SETTLE runs out), then watches HOLD
-- seconds for one leaving it; done(results) with each entry's last reading
-- and whether it held.
local function Settle(entries, want, done)
	local started, heldSince = GetTime(), nil
	local broke = {}
	local ticker
	ticker = C_Timer.NewTicker(0.2, function()
		if not run then ticker:Cancel() return end
		local all = true
		for _, entry in ipairs(entries) do
			local reading = Read(entry)
			local ok = want(reading, entry)
			-- (The first reading that left it, and when: what set it back.)
			if heldSince and ok == false and not broke[entry] then
				reading.at, reading.heldFor = GetTime() - started, GetTime() - heldSince
				broke[entry] = reading
			end
			if ok == false then all = false end
		end
		local now = GetTime()
		if all and not heldSince then heldSince = now end
		if (heldSince and now - heldSince >= HOLD) or (not heldSince and now - started >= SETTLE) then
			ticker:Cancel()
			local results = {}
			for _, entry in ipairs(entries) do
				results[#results + 1] = { entry = entry, reading = Read(entry), broke = broke[entry] }
			end
			done(results, heldSince ~= nil)
		end
	end)
end

local function Hidden(reading)
	if Secret(reading.alpha) or Secret(reading.visible) then return nil end
	-- (Its alpha unreadable, the read itself erroring: EllesmereUI's player
	-- frame on WoW Forever, 2026-11-20, hidden on screen: can't tell.)
	if reading.visible and reading.alpha == nil then return nil end
	return not reading.visible or (type(reading.alpha) == "number" and reading.alpha <= 0.05)
end
-- Back to what it showed before the row was hidden (its own fade can keep
-- it at 0: DaylightUI's mouseover bars, 2026-11-19, first read as a FAIL).
-- before: entry -> its reading then.
local before = {}
local function Up(reading, entry)
	if Secret(reading.alpha) or Secret(reading.visible) then return nil end
	if not reading.visible then return nil end -- (hidden by the addon itself: can't tell)
	if reading.alpha == nil then return nil end -- (unreadable: can't tell)
	local was = before[entry] and before[entry].alpha
	if type(was) ~= "number" or Secret(was) then
		was = type(entry.baseAlpha) == "number" and not Secret(entry.baseAlpha) and entry.baseAlpha or 1
	end
	if was < 0.05 then return nil end -- (at 0 before too: can't tell)
	return type(reading.alpha) == "number" and reading.alpha >= was * 0.85
end

local function ReadingLine(result)
	local r = result.reading
	return ("%s: visible %s, alpha %s (ours %s, its base %s), mouse %s"):format(result.entry.name or Name(result.entry.frame),
		Num(r.visible), Num(r.alpha), Num(r.ours), Num(r.base), Num(r.mouse))
end

local Finish

local function TestRow(index)
	if not run then return end
	local item = run.rows[index]
	if not item then
		Finish(true)
		return
	end
	run.stage = "row " .. item.key
	local entries = RowEntries(item)
	local label = tostring(item.label or item.key)
	if #entries == 0 then
		Verdict(label .. " has its frames", nil, "none of its frames is faded by us now: row off, page off, or not made yet")
		C_Timer.After(0.2, function() TestRow(index + 1) end)
		return
	end
	ns.TestPrompt(("Addon test: row %d/%d, %s (hands off)"):format(index, #run.rows, label), SETTLE + HOLD + 4)
	wipe(before)
	for _, entry in ipairs(entries) do before[entry] = Read(entry) end
	Force(item.key, "hide")
	Settle(entries, Hidden, function(hiddenResults)
		Shot("hidden " .. item.key)
		local fought, notHidden, mouseOff = {}, {}, {}
		for _, result in ipairs(hiddenResults) do
			Log("hidden " .. ReadingLine(result))
			local name = result.entry.name or Name(result.entry.frame)
			if result.broke then
				fought[#fought + 1] = name
				local b = result.broke
				Log(("set back %s: %.1fs after the hide (held %.1fs), visible %s, alpha %s, ours %s, its base %s"):format(
					name, b.at or 0, b.heldFor or 0, Num(b.visible), Num(b.alpha), Num(b.ours), Num(b.base)))
			end
			if Hidden(result.reading) == false then notHidden[#notHidden + 1] = name end
			if before[result.entry].mouse == true and result.reading.mouse == false
				and not (ns.HOVER_BY_RECT and result.entry.name and ns.HOVER_BY_RECT[result.entry.name]) then
				mouseOff[#mouseOff + 1] = name
			end
		end
		Verdict(label .. " hides", #notHidden == 0, #notHidden > 0 and ("still up: " .. table.concat(notHidden, ", ")) or
			(#entries .. " frames"))
		Verdict(label .. " stays hidden", #fought == 0,
			#fought > 0 and ("set its alpha back: " .. table.concat(fought, ", ")) or nil)
		if #mouseOff > 0 then
			Verdict(label .. " keeps the mouse while hidden", false,
				"turned the mouse off, hover can't bring it back (ns.HOVER_BY_RECT?): " .. table.concat(mouseOff, ", "))
		end
		Force(item.key, "show")
		Settle(entries, Up, function(upResults)
			local down, unclear = {}, 0
			for _, result in ipairs(upResults) do
				Log("shown " .. ReadingLine(result))
				local up = Up(result.reading, result.entry)
				if up == false then down[#down + 1] = result.entry.name or Name(result.entry.frame) end
				if up == nil then unclear = unclear + 1 end
			end
			Verdict(label .. " comes back", #down == 0 and (unclear < #upResults or nil),
				#down > 0 and ("still down: " .. table.concat(down, ", ")) or
				(unclear > 0 and (unclear .. " hidden or at alpha 0 by the addon itself") or nil))
			Force(item.key, run.forceBefore[item.key])
			C_Timer.After(ROW_GAP, function() TestRow(index + 1) end)
		end)
	end)
end

local STEPS = {
	{ tag = "target", say = "Addon test 1/3: TARGET anything (an NPC, a player, yourself)." },
	{ tag = "fight", say = "Addon test 2/3: FIGHT something (a target dummy works). The test goes on by itself when the fight ends." },
}

local events = CreateFrame("Frame")

-- What the target and fight steps found this run, kept for the next one.
local function KeepSteps()
	if run.quick then return end
	CinematicDB.addonTestSteps = CinematicDB.addonTestSteps or {}
	local old = CinematicDB.addonTestSteps[run.target]
	local record = { version = run.version }
	for _, step in ipairs(STEPS) do
		if run.ran[step.tag] then
			local found = {}
			for kind, stage in pairs(run.kinds) do
				if stage == step.tag then found[#found + 1] = kind end
			end
			table.sort(found)
			record[step.tag] = #found > 0
			Log(("%s step showed %d new kind(s) of frame%s"):format(step.tag, #found,
				#found > 0 and (": " .. table.concat(found, ", ")) or ": skipped next run on this version (full asks it again)"))
		elseif type(old) == "table" and old.version == run.version then
			record[step.tag] = old[step.tag]
		end
	end
	CinematicDB.addonTestSteps[run.target] = record
end

local StartRows
-- Frames our support names that it hasn't made yet, or that we haven't
-- taken over yet, are waited for (up to MADE_WAIT), then given MADE_SETTLE:
-- rows tested before then read a frame coming up as "set its alpha back"
-- (Questie's tracker after a /reload, 2026-11-21: first not made yet, then
-- made but 40 of its 41 frames not ours yet, our fade still bringing it in).
-- True while waiting.
local function WaitForMade(missing, untaken)
	local waiting = {}
	for _, name in ipairs(missing) do waiting[#waiting + 1] = name end
	for _, name in ipairs(untaken) do waiting[#waiting + 1] = name end
	if #waiting > 0 then
		if not run.madeWaitUntil then
			run.madeWaitUntil = GetTime() + MADE_WAIT
			run.stage = "waiting" -- (what it makes now isn't the last step's find)
			Log(("waiting for %d of its frames (up to %ds): %d not made yet, %d not taken over by us yet: %s%s"):format(
				#waiting, MADE_WAIT, #missing, #untaken,
				table.concat(waiting, ", ", 1, math.min(#waiting, 4)), #waiting > 4 and ", ..." or ""))
			ns.TestPrompt(("Addon test: waiting for %s to make its frames (hands off)"):format(run.target), MADE_WAIT + 2)
		end
		if GetTime() < run.madeWaitUntil then
			C_Timer.After(0.5, StartRows)
			return true
		end
		Log(("after the wait: %d still not made, %d still not taken over by us%s"):format(#missing, #untaken,
			#untaken > 0 and (": " .. table.concat(untaken, ", ", 1, math.min(#untaken, 8))) or ""))
	elseif run.madeWaitUntil and not run.madeSettled then
		run.madeSettled = true
		Log(("all made and ours, %.1fs into the wait; %ds to settle"):format(GetTime() - (run.madeWaitUntil - MADE_WAIT), MADE_SETTLE))
		C_Timer.After(MADE_SETTLE, StartRows)
		return true
	end
	return false
end

StartRows = function()
	if not run then return end
	events:UnregisterAllEvents()
	local missing, untaken = ns.AddonTestMissing(run.target)
	if WaitForMade(missing, untaken) then return end
	Inventory()
	KeepSteps()
	run.stage = "rows"
	run.rows = Rows()
	for _, name in ipairs(missing) do Log("not made: " .. name) end
	Verdict("its frames were made", #missing == 0 or nil, #missing > 0 and ("%d our support names never made (off in its own options, or made later): %s%s"):format(
		#missing, table.concat(missing, ", ", 1, math.min(#missing, 8)), #missing > 8 and ", ..." or "") or nil)
	if #run.rows == 0 then
		Verdict("rows tested", nil, "no row to test: none of its frames is on a row now (made yet? its page or row off?)")
	end
	run.forceBefore = {}
	for _, item in ipairs(run.rows) do run.forceBefore[item.key] = ns.db.frameForce[item.key] end
	Log(("%d rows to test: %s"):format(#run.rows, (function()
		local keys = {}
		for _, item in ipairs(run.rows) do keys[#keys + 1] = item.key end
		return table.concat(keys, ", ")
	end)()))
	ns.testFadeTime = ROW_FADE
	Log(("fades at %.1fs while the rows run"):format(ROW_FADE))
	TestRow(1)
end

local function Step(index)
	if not run then return end
	local step = STEPS[index]
	if not step or run.quick then
		StartRows()
		return
	end
	if run.skips[step.tag] then
		Log(("%s step skipped: the last run on %s %s showed no new frame in it (full asks it again)"):format(
			step.tag, run.target, run.version))
		Step(index + 1)
		return
	end
	run.step, run.stage = index, step.tag
	events:UnregisterAllEvents()
	if step.tag == "target" then
		events:RegisterEvent("PLAYER_TARGET_CHANGED")
	else
		events:RegisterEvent("PLAYER_REGEN_DISABLED")
		events:RegisterEvent("PLAYER_REGEN_ENABLED")
	end
	ns.TestPrompt(step.say, 3600)
end

events:SetScript("OnEvent", function(_, event)
	if not run then return end
	if event == "PLAYER_TARGET_CHANGED" and UnitExists("target") and run.step == 1 then
		run.step = "target seen"
		run.ran.target = true
		Log("target: " .. tostring(UnitName("target")))
		C_Timer.After(1.5, function()
			Inventory()
			Shot("target")
			Step(2)
		end)
	elseif event == "PLAYER_REGEN_DISABLED" then
		run.fought = true
		Log("fight started")
		C_Timer.After(2, function() Shot("fight") end)
	elseif event == "PLAYER_REGEN_ENABLED" and run.fought and run.step == 2 then
		run.step = "fight over"
		run.ran.fight = true
		Log("fight over")
		C_Timer.After(1, function() Step(3) end)
	end
end)

Finish = function(done)
	if not run then return end
	run.ticker:Cancel()
	events:UnregisterAllEvents()
	ns.testFadeTime = nil -- (before the rows go back: they fade at the player's own speed)
	-- (Rows still forced by the test go back to what they were.)
	for _, item in ipairs(run.forceBefore and run.rows or {}) do
		if ns.db.frameForce[item.key] ~= run.forceBefore[item.key] then Force(item.key, run.forceBefore[item.key]) end
	end
	if done then
		Inventory()
		ns.AddonTestCoverAgain(run.frames, ManagedBy())
		local open, covered = {}, 0
		for _, seen in pairs(run.frames) do
			if seen.cover then covered = covered + 1 else open[#open + 1] = seen.line end
		end
		table.sort(open)
		Verdict("every frame on screen covered", #open == 0,
			("%d covered, %d NOT COVERED"):format(covered, #open))
		for _, line in ipairs(open) do Log("  NOT COVERED " .. line) end
		Verdict("its parts loaded", #run.unloaded == 0, #run.unloaded > 0
			and ("not loaded, their rows untested: " .. table.concat(run.unloaded, ", ")) or nil)
		Verdict("ran alone", #run.others == 0, #run.others > 0 and ("also loaded: " .. table.concat(run.others, ", ")) or nil)
		Log(("totals: %d pass, %d fail, %d can't tell"):format(run.tally.pass, run.tally.fail, run.tally.unclear))
	end
	local cineWasOn, tally = run.cineWasOn, run.tally
	run = nil
	SetCine(cineWasOn)
	ns.TestPrompt(done and ("Addon test DONE: %d pass, %d fail, %d can't tell. Type /reload, then say \"check log\"."):format(
		tally.pass, tally.fail, tally.unclear) or "Addon test stopped.", 30)
end

-- Whether an addon test is running (the addon kit's test waits for it to end).
function ns.AddonTestRunning() return run ~= nil end

function ns.AddonTest(words)
	if run then
		Finish(false)
		return
	end
	local typed, mode = words:match("^(%S+)%s*(%S*)")
	local target = typed and Resolve(typed)
	if not target then
		ns.Print("addontest: /cine debug addontest <Addon> [quick|full] (its folder name: " .. tostring(typed) .. " isn't installed)")
		return
	end
	if not IsLoaded(target) then
		ns.Print("addontest: " .. target .. " isn't loaded. Turn it on (or /cine debug solo " .. target .. ") first.")
		return
	end
	CinematicDB.addonTestLog = {}
	local solo = CinematicDB.soloAddons
	run = {
		target = target, quick = mode == "quick", frames = {}, tally = { pass = 0, fail = 0, unclear = 0 },
		cineWasOn = ns.IsCineModeOn and ns.IsCineModeOn() or false, stage = "start",
		kinds = {}, ran = {},
	}
	run.others = Others(type(solo) == "table" and solo.keep or { addonName, target })
	-- (Its own parts and what it needs count as alone without solo too.)
	for i = #run.others, 1, -1 do
		local name = run.others[i]
		if Belongs(name, target) or name == addonName then table.remove(run.others, i) end
	end
	local function Version(name)
		local ok, value = pcall(GetMeta, name, "Version")
		return ok and tostring(value) or "?"
	end
	local parts = {}
	for _, each in ipairs(AddOns()) do
		if each.loaded and Belongs(each.name, target) then parts[#parts + 1] = each.name .. " " .. Version(each.name) end
	end
	run.version = Version(target)
	run.skips = ns.AddonTestSkips((CinematicDB.addonTestSteps or {})[target], run.version, mode == "full")
	Log(("start %s: Cinematic %s, game %s, %s; support %s; solo %s; also loaded: %s; CineMode was %s"):format(
		date("%Y-%m-%d %H:%M"), Version(addonName), tostring((GetBuildInfo())), table.concat(parts, ", "),
		ns.AddonSupportOn and tostring(ns.AddonSupportOn(target)) or "?",
		type(solo) == "table" and table.concat(solo.keep or {}, "+") or "off",
		#run.others > 0 and table.concat(run.others, ", ") or "none", run.cineWasOn and "on" or "off"))
	-- (Its parts its rows are for that aren't loaded: their rows can't be
	-- tested, so the run fails rather than passing on the rest.)
	-- (Only parts this client lists: one made for another client isn't in
	-- its list at all, as EllesmereUIMythicTimer on WoW Forever.)
	run.unloaded = {}
	local unloadedSeen, listed = {}, {}
	for _, each in ipairs(AddOns()) do listed[each.name] = true end
	for _, known in ipairs(ns.ADDON_FRAMES or {}) do
		if Belongs(known.addon, target) and listed[known.addon] and not IsLoaded(known.addon)
			and not unloadedSeen[known.addon] then
			unloadedSeen[known.addon] = true
			run.unloaded[#run.unloaded + 1] = known.addon
		end
	end
	table.sort(run.unloaded)
	for _, known in ipairs(ns.ADDON_FRAMES or {}) do
		if Belongs(known.addon, target) then
			Log(("row addon:%s (%s): %s, loaded %s"):format(known.key, tostring(known.label),
				ns.IsAddonFramesOn(known.key) and "on" or "OFF", tostring(known.loaded)))
		end
	end
	-- (Whether it's set up so its frames show: its ready recipe, which the
	-- addon kit and its support test use to set it up. This one only says.)
	local recipe = ns.TestKit and ns.TestKit.AddonReadyRecipe(target)
	if recipe then
		local ok, yes, why = pcall(recipe.ready)
		local line = ("ready: %s (%s)%s"):format(ok and yes and "yes" or "NO", tostring(recipe.about),
			ok and (yes and "" or (": " .. tostring(why))) or (": ready() error " .. tostring(yes)))
		Log(line)
		if not (ok and yes) then ns.Print("addontest: " .. target .. " isn't set up: " .. tostring(recipe.about)
			.. ". /cine debug addonkit " .. target .. " sets it up first.") end
	else
		Log("ready: no recipe for " .. target .. " (/addon-support writes one)")
	end
	SetCine(false)
	-- (Its frames as they come and go, every 2 seconds.)
	run.ticker = C_Timer.NewTicker(2, Inventory)
	Inventory()
	ns.TestPrompt("Addon test: getting ready (hands off)", 5)
	C_Timer.After(3, function()
		if not run then return end
		Inventory()
		Shot("start")
		Step(1)
	end)
end
