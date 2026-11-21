-- /cine debug linecolors: step 0 of Tools/combat-log-color-plan.md. Can a
-- combat log line's color (COMBAT_LOG_MESSAGE's plain 2nd-4th values) say
-- what kind of line it is, so Combat Text Style pairs a line only with a hit
-- of the same kind? One thing to do: kill one mob. It ends by itself when
-- the fight does (no time limit before it starts).
--   - the Combat Log's filters (Blizzard_CombatLog_Filters): plain or
--     secret, the current one's name, whose lines it lists (you, your pet),
--     how it colors (lineColoring, lineColorPriority, per-event colors)
--   - every line (its time, color, order) and every hit around it (which
--     unit, action, flag, school; your target's; your swings by
--     PLAYER_SWING; your casts), deduplicated per instant
--   - each line paired with the hit of its instant, or a swing's hit
--     0.2-0.9 s after it, and named by its color from the filter's own
--     per-event colors
-- Verdicts: the filter readable; how many colors; per color, the events the
-- filter gives that color and the hits seen with it (one kind only =
-- usable); colors matching the filter; lines with no hit of yours near
-- (your pet's?); swings seen. Your filter is left as it is. CineMode off
-- for the run. Into CinematicDB.lineColorLog. Typed again: stops. Dev copy only.
--
-- Run 2 (2026-11-21, Tools/tests/combat-log-colors.md): the same fight also
-- confirms step 1 in Combat Text Style (its line kinds by color). The page is
-- turned on for the run (your numbers ours, your pet's ours; your settings
-- kept and put back, even after a /reload), its own pairing is logged
-- ("page ..." lines), and its counts go in the verdicts: kill lines skipped,
-- lines of unknown kind, your hits drawn and left out, your pet's, dev
-- errors. Each hit's gap to your last cast and your pet's last cast is logged
-- (are your pet's hits taking lines now?). One screenshot 3 s into the fight.
local _, ns = ...

local PAGE_KEYS = { styleGeneral = true, combatTextStyle = true, combatTextNumbers = true, combatTextDamageBy = "ours",
	combatTextPetBy = "ours", combatTextHealBy = "ours" }

local SAME = 0.06            -- seconds: a line and a hit this close are one instant
local SWING_AFTER = { 0.2, 0.9 } -- a swing's hit lands this long after its line (2026-11-11 recording)
local KEY_EVENTS = { "SWING_DAMAGE", "SWING_MISSED", "RANGE_DAMAGE", "SPELL_DAMAGE", "SPELL_PERIODIC_DAMAGE",
	"SPELL_MISSED", "SPELL_HEAL", "SPELL_PERIODIC_HEAL", "SPELL_ENERGIZE", "SPELL_CAST_SUCCESS", "SPELL_AURA_APPLIED",
	"DAMAGE_SHIELD", "SPELL_INTERRUPT", "PARTY_KILL", "UNIT_DIED" }

local run
local logHooked = false

local function Secret(v) return issecretvalue and issecretvalue(v) end
local function Say(text)
	local log = CinematicDB and CinematicDB.lineColorLog
	if log then log[#log + 1] = ("%s %.2f %s"):format(date("%H:%M:%S"), run and GetTime() - run.at or 0, text) end
end
local function T(v)
	if Secret(v) then return "secret" end
	if type(v) == "number" then return ("%.3f"):format(v) end
	return tostring(v)
end
-- A color as a key: 0-255 per channel ("179/179/179").
local function Key(r, g, b)
	if Secret(r) or Secret(g) or Secret(b) or type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
		return "secret"
	end
	return ("%d/%d/%d"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end
local function Box(text, sub, waiting)
	ns.PadTestBox(text, sub or "", waiting and 0.3 or 1, waiting and 1 or 0.82, waiting and 0.3 or 0)
end

-- The filters: what's readable, and each event's color by the current one.
local function ReadFilters()
	local filters = _G.Blizzard_CombatLog_Filters
	if Secret(filters) then
		Say("filters: Blizzard_CombatLog_Filters is SECRET")
		return nil
	end
	if type(filters) ~= "table" then
		Say("filters: Blizzard_CombatLog_Filters is " .. type(filters) .. " (Blizzard_CombatLog loaded "
			.. tostring(C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_CombatLog")) .. ")")
		return nil
	end
	local names = {}
	for i, filter in ipairs(type(filters.filters) == "table" and filters.filters or {}) do
		names[#names + 1] = ("%d=%s"):format(i, T(type(filter) == "table" and filter.name))
	end
	local index = filters.currentFilter
	local current = type(filters.filters) == "table" and filters.filters[index]
	Say(("filters: plain table, current %s of [%s]"):format(T(index), table.concat(names, ", ")))
	if type(current) ~= "table" then
		Say("  current filter not a table")
		return nil
	end
	local settings = type(current.settings) == "table" and current.settings or {}
	local colors = type(current.colors) == "table" and current.colors or {}
	local sources = {}
	for _, filter in ipairs(type(current.filters) == "table" and current.filters or {}) do
		if type(filter) == "table" and type(filter.sourceFlags) == "table" then
			for flags, on in pairs(filter.sourceFlags) do
				if on then sources[#sources + 1] = tostring(flags) end
			end
		end
	end
	table.sort(sources)
	local eventColors = {}
	local count = 0
	for event, color in pairs(type(colors.eventColoring) == "table" and colors.eventColoring or {}) do
		if type(color) == "table" then
			count = count + 1
			eventColors[event] = Key(color.r, color.g, color.b)
		end
	end
	local units = {}
	for flags, color in pairs(type(colors.unitColoring) == "table" and colors.unitColoring or {}) do
		if type(color) == "table" then units[#units + 1] = ("%s=%s"):format(tostring(flags), Key(color.r, color.g, color.b)) end
	end
	table.sort(units)
	Say(("  current \"%s\": sources [%s] (17681 you, 12561 your pet), lineColoring %s, lineColorPriority %s,"
		.. " unitColoring %s, %d event colors"):format(T(current.name), table.concat(sources, " "),
		T(settings.lineColoring), T(settings.lineColorPriority), T(settings.unitColoring), count))
	Say("  unit colors: " .. (#units > 0 and table.concat(units, " ") or "none"))
	local shown = {}
	for _, event in ipairs(KEY_EVENTS) do shown[#shown + 1] = event .. "=" .. (eventColors[event] or "-") end
	Say("  event colors: " .. table.concat(shown, " "))
	return { name = current.name, events = eventColors, sources = sources }
end

-- The events the filter gives a color (several can share one).
local function EventsOf(key)
	local list = {}
	for event, color in pairs(run.filter and run.filter.events or {}) do
		if color == key then list[#list + 1] = event end
	end
	table.sort(list)
	return list
end

-- A hit's kind, as Combat Text Style would see it.
local function KindOf(hit)
	if hit.action == "HEAL" then return hit.periodic and "heal tick" or "heal" end
	if hit.action ~= "WOUND" then return "miss" end
	if hit.swing then return "swing" end
	if hit.school == 1 then return "physical" end
	return "spell"
end

local function Analyze()
	local hits, lines = run.hits, run.lines
	-- (Each line to the hit of its instant, else a swing's hit landing after it.)
	local used = {}
	for _, line in ipairs(lines) do
		local best, bestGap
		for index, hit in ipairs(hits) do
			if not used[index] then
				local gap = hit.at - line.at
				if math.abs(gap) <= SAME and (not bestGap or math.abs(gap) < bestGap) then best, bestGap = index, math.abs(gap) end
			end
		end
		if not best then
			for index, hit in ipairs(hits) do
				local gap = hit.at - line.at
				if not used[index] and hit.swing and gap >= SWING_AFTER[1] and gap <= SWING_AFTER[2] then
					best = index
					break
				end
			end
		end
		if best then
			used[best] = true
			hits[best].lined = true
			line.kind = KindOf(hits[best])
		end
	end
	-- Per color: lines, the hit kinds with them, the filter's events of that color.
	local byColor, order = {}, {}
	for _, line in ipairs(lines) do
		local entry = byColor[line.key]
		if not entry then
			entry = { lines = 0, kinds = {}, none = 0 }
			byColor[line.key] = entry
			order[#order + 1] = line.key
		end
		entry.lines = entry.lines + 1
		if line.kind then entry.kinds[line.kind] = (entry.kinds[line.kind] or 0) + 1 else entry.none = entry.none + 1 end
	end
	table.sort(order, function(a, b) return byColor[a].lines > byColor[b].lines end)
	local usable, matched, unmatched = 0, 0, 0
	for _, key in ipairs(order) do
		local entry = byColor[key]
		local kinds, distinct = {}, 0
		for kind, count in pairs(entry.kinds) do
			kinds[#kinds + 1] = kind .. " x" .. count
			distinct = distinct + 1
		end
		table.sort(kinds)
		local events = EventsOf(key)
		if #events > 0 then matched = matched + entry.lines else unmatched = unmatched + entry.lines end
		if distinct == 1 then usable = usable + 1 end
		Say(("color %s: %d lines | hits with it: %s | no hit near: %d | the filter's events of this color: %s%s"):format(
			key, entry.lines, #kinds > 0 and table.concat(kinds, ", ") or "none", entry.none,
			#events > 0 and table.concat(events, " ", 1, math.min(#events, 8)) or "none",
			#events > 8 and (" +" .. (#events - 8)) or ""))
	end
	local orphans = 0
	for index in ipairs(hits) do if not used[index] then orphans = orphans + 1 end end
	Say(("VERDICT filter: %s"):format(run.filter and ("readable, current \"" .. T(run.filter.name) .. "\", sources "
		.. table.concat(run.filter.sources, " ")) or "NOT readable"))
	Say(("VERDICT colors: %d colors over %d lines; %d of them came with one kind of hit only"):format(#order, #lines, usable))
	Say(("old lines sent again (Oldest order, not counted): %d"):format(run.oldLines or 0))
	Say(("VERDICT filter match: %d lines' colors are colors the filter gives events, %d not"):format(matched, unmatched))
	local none = 0
	for _, line in ipairs(lines) do if not line.kind then none = none + 1 end end
	Say(("VERDICT lines with no hit near: %d of %d (your pet's, a buff, a cast?) | hits with no line: %d of %d")
		:format(none, #lines, orphans, #hits))
	Say(("VERDICT swings: %d PLAYER_SWING, %d hits marked a swing of yours; your pet: %s, pet hits seen %d")
		:format(run.swings, run.swingHits, tostring(run.hadPet), run.petHits))
	-- Each hit's gap to the last cast of yours and of your pet before it.
	for _, hit in ipairs(hits) do
		local mine, pet
		for _, cast in ipairs(run.castTimes) do
			if cast.at <= hit.at + 0.01 then
				if cast.pet then pet = cast.at else mine = cast.at end
			end
		end
		Say(("gaps: hit %.2f school %s line %s | your cast %s s before | your pet's %s s before"):format(hit.at - run.at,
			T(hit.school), tostring(hit.lined or false), mine and ("%.2f"):format(hit.at - mine) or "-",
			pet and ("%.2f"):format(hit.at - pet) or "-"))
	end
	-- Step 1 in the page (run 2).
	local page = run.page
	local kinds = ns.combatTextLineKinds or {}
	local whose = ns.combatTextWhose or {}
	local function Delta(key, now, before) return (now[key] or 0) - (before[key] or 0) end
	local skipColored = 0
	for _, line in ipairs(lines) do
		local events = EventsOf(line.key)
		local hitLike = false
		for _, event in ipairs(events) do
			if event:find("^SWING_") or event:find("DAMAGE") or event:find("MISSED") or event:find("HEAL")
				or event:find("^RANGE_") or event:find("LEECH") or event:find("DRAIN") then
				hitLike = true
			end
		end
		if #events > 0 and not hitLike then skipColored = skipColored + 1 end
	end
	local skipped, unknown = Delta("skip", kinds, page.kinds), Delta("unknown", kinds, page.kinds)
	local drawn, others = Delta("mine", whose, page.whose), Delta("others", whose, page.whose)
	Say(("page counts: lines swing %d spell %d heal %d skip %d unknown %d | yours drawn %d, left out %d | page said LEFT OUT %d, PET'S %d, TOTEM'S %d"):format(
		Delta("swing", kinds, page.kinds), Delta("spell", kinds, page.kinds), Delta("heal", kinds, page.kinds), skipped,
		unknown, drawn, others, page.leftOut, page.pets, page.totems))
	local verdict
	if run.errors > 0 then
		verdict = ("FAIL: %d dev errors (first: %s)"):format(run.errors, run.firstError or "?")
	elseif skipped ~= skipColored then
		verdict = ("FAIL: %d lines had a non-hit color, the page skipped %d"):format(skipColored, skipped)
	elseif run.filter and next(run.filter.events) and unknown > 0 then
		verdict = ("FAIL: %d lines of unknown kind under a filter that colors events"):format(unknown)
	elseif drawn == 0 then
		verdict = "FAIL: the page drew none of your hits"
	elseif skipColored == 0 then
		verdict = ("PASS (kill-line skip NOT exercised: no non-hit line came): every line's kind known, %d of your hits drawn, %d left out")
			:format(drawn, others)
	else
		verdict = ("PASS: %d non-hit lines skipped, every line's kind known, %d of your hits drawn, %d left out")
			:format(skipped, drawn, others)
	end
	Say("VERDICT page step 1: " .. verdict)
	-- (1b: your pet's spell hits, with lines now, drawn as your pet's.)
	local petLike = 0
	for _, hit in ipairs(hits) do
		local mine, pet
		for _, cast in ipairs(run.castTimes) do
			if cast.at <= hit.at + 0.01 then
				if cast.pet then pet = cast.at else mine = cast.at end
			end
		end
		if pet and hit.at - pet <= 0.6 and not (mine and hit.at - mine <= 0.3) and hit.school ~= 1 then petLike = petLike + 1 end
	end
	local petVerdict
	if run.petCasts == 0 then
		petVerdict = "SKIP: your pet cast nothing"
	elseif page.pets == 0 then
		petVerdict = ("FAIL: %d of your pet's casts, %d hits look like its, the page called none your pet's"):format(run.petCasts, petLike)
	else
		petVerdict = ("PASS: the page called %d hits your pet's (%d look like its by timing, %d pet casts)"):format(page.pets,
			petLike, run.petCasts)
	end
	Say("VERDICT pet: " .. petVerdict .. (" | %d lines with no hit near"):format(none))
	return #order, #lines
end

local watcher = CreateFrame("Frame")
watcher:SetScript("OnEvent", function(_, event, ...)
	if not run then return end
	local now = GetTime()
	if event == "COMBAT_LOG_MESSAGE" then
		local text, r, g, b, order = ...
		local old = Enum and Enum.CombatLogMessageOrder and order == Enum.CombatLogMessageOrder.Oldest
		if old then run.oldLines = (run.oldLines or 0) + 1 return end
		local line = { at = now, key = Key(r, g, b) }
		run.lines[#run.lines + 1] = line
		if #run.lines <= 60 then
			Say(("line %s order %s text %s"):format(line.key, T(order), Secret(text) and "secret" or "plain"))
		end
	elseif event == "UNIT_COMBAT" then
		local unit, action, flag, _, school = ...
		if Secret(unit) or Secret(action) then return end
		if unit == "pet" then return end -- (hits on your pet)
		if unit == "player" then return end -- (hits on you: no lines)
		if not (unit == "target" or tostring(unit):find("^nameplate%d+$") or unit == "softenemy") then return end
		local isTarget = UnitIsUnit and ns.Check and ns.Check.True(UnitIsUnit(unit, "target"))
		-- (One per instant: the same hit comes once per unit token.)
		for i = #run.hits, math.max(1, #run.hits - 6), -1 do
			local hit = run.hits[i]
			-- (Same school too: a Fire and a Shadow hit in one instant are two, run 2.)
			if hit.at == now and hit.action == action and hit.flag == (Secret(flag) and "secret" or flag)
				and hit.school == (not Secret(school) and tonumber(school) or nil) then
				hit.target = hit.target or isTarget
				return
			end
		end
		local hit = { at = now, unit = unit, action = action, flag = Secret(flag) and "secret" or flag,
			school = not Secret(school) and tonumber(school) or nil, target = isTarget }
		-- (A swing of yours: PLAYER_SWING within the last 0.9 s, physical, on your target.)
		if hit.school == 1 and run.lastSwing and now - run.lastSwing <= SWING_AFTER[2] and isTarget then
			hit.swing = true
			run.swingHits = run.swingHits + 1
		end
		if UnitExists("pet") and UnitIsUnit and ns.Check and ns.Check.True(UnitIsUnit(unit, "pettarget")) then
			run.petHits = run.petHits + 1
		end
		run.hits[#run.hits + 1] = hit
		if #run.hits <= 60 then
			Say(("hit %s %s %s school %s target %s swing %s"):format(unit, action, tostring(hit.flag), T(hit.school),
				tostring(isTarget), tostring(hit.swing or false)))
		end
	elseif event == "PLAYER_SWING" then
		run.swings = run.swings + 1
		run.lastSwing = now
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		local unit = ...
		run.casts = run.casts + 1
		local pet = unit == "pet"
		if pet then run.petCasts = run.petCasts + 1 end
		run.castTimes[#run.castTimes + 1] = { at = now, pet = pet }
		if run.casts <= 30 then Say(("cast by %s"):format(T(unit))) end
	elseif event == "PLAYER_REGEN_DISABLED" then
		run.fought = true
		Box("Combat colors test: FIGHTING. Kill it.", "it ends by itself when the fight does", true)
		Say("fight started")
		-- (One look at the numbers, 3 s in: a second of its own.)
		C_Timer.After(3, function()
			if run then
				local ok = pcall(function() Screenshot() end)
				Say(("screenshot fight at %s%s"):format(date("%m%d%y_%H%M%S"), ok and "" or " (failed)"))
			end
		end)
	elseif event == "PLAYER_REGEN_ENABLED" then
		Say("fight ended")
		if run.fought then
			C_Timer.After(1, function() if run then ns.LineColorProbe() end end) -- (late lines, then finish)
		end
	end
end)

-- The page's settings put back (kept in CinematicDB so a /reload mid-run
-- still puts them back at the next login).
local function PutPageBack()
	local kept = CinematicDB and CinematicDB.lineColorKept
	if type(kept) ~= "table" then return end
	for key in pairs(PAGE_KEYS) do ns.db[key] = kept[key] end
	CinematicDB.lineColorKept = nil
	if ns.RefreshCombatTextStyle then pcall(ns.RefreshCombatTextStyle) end
end
local loginWatch = CreateFrame("Frame")
loginWatch:RegisterEvent("PLAYER_LOGIN")
loginWatch:SetScript("OnEvent", function()
	if not run and CinematicDB and CinematicDB.lineColorKept then
		PutPageBack()
		local log = CinematicDB.lineColorLog
		if type(log) == "table" then log[#log + 1] = date("%H:%M:%S") .. " unfinished run: your Combat Text settings put back at login" end
	end
end)

local function Finish()
	watcher:UnregisterAllEvents()
	if run.turnedOn then pcall(C_CombatLog.SetFilteredEventsEnabled, false) end
	ns.combatTextRecord = run.keptRecord
	if run.cineWasOn and ns.IsCineModeOn and not ns.IsCineModeOn() and Cinematic_ToggleCineMode then
		Cinematic_ToggleCineMode()
	end
	local ok, colors, lines = pcall(Analyze)
	if not ok then Say("analysis error: " .. tostring(colors)) end
	PutPageBack()
	Say("done | your Combat Text settings back")
	local fought = run.fought
	run = nil
	if not fought then
		Box("Combat colors test stopped (no fight).")
	else
		Box(("Combat colors test done: %s colors over %s lines.\n/reload, then say \"check log\"."):format(
			tostring(colors or "?"), tostring(lines or "?")))
	end
	C_Timer.After(12, function() if not run then ns.PadTestBoxHide() end end)
end

function ns.LineColorProbe()
	if run then
		Finish()
		return
	end
	ns.debugNoCopyWindow = true
	CinematicDB.lineColorLog = {}
	run = { at = GetTime(), lines = {}, hits = {}, swings = 0, swingHits = 0, casts = 0, petHits = 0, petCasts = 0,
		castTimes = {}, errors = 0, hadPet = UnitExists and UnitExists("pet") or false,
		cineWasOn = ns.IsCineModeOn and ns.IsCineModeOn() or false }
	if run.cineWasOn and Cinematic_ToggleCineMode then Cinematic_ToggleCineMode() end
	-- (Combat Text Style on for the run, yours kept; its pairing logged.)
	local kept = {}
	for key in pairs(PAGE_KEYS) do kept[key] = ns.db[key] end
	CinematicDB.lineColorKept = CinematicDB.lineColorKept or kept
	for key, value in pairs(PAGE_KEYS) do ns.db[key] = value end
	if ns.RefreshCombatTextStyle then pcall(ns.RefreshCombatTextStyle) end
	local function Copy(t) local c = {} for k, v in pairs(t or {}) do c[k] = v end return c end
	run.page = { kinds = Copy(ns.combatTextLineKinds), whose = Copy(ns.combatTextWhose), leftOut = 0, pets = 0, totems = 0 }
	run.keptRecord = ns.combatTextRecord
	local pageLines = 0
	ns.combatTextRecord = function(text)
		if not run then return end
		text = tostring(text)
		if text:find("LEFT OUT", 1, true) then run.page.leftOut = run.page.leftOut + 1 end
		if text:find("PET'S", 1, true) then run.page.pets = run.page.pets + 1 end
		if text:find("TOTEM'S", 1, true) then run.page.totems = run.page.totems + 1 end
		pageLines = pageLines + 1
		if pageLines <= 150 then Say("page " .. text) end
	end
	if not logHooked then
		logHooked = true
		hooksecurefunc(ns, "Log", function(kind, text)
			if run and (kind == "deverror" or kind == "BLOCKED") then
				run.errors = run.errors + 1
				run.firstError = run.firstError or tostring(text):sub(1, 160)
				Say("ERROR " .. tostring(text):sub(1, 300))
			end
		end)
	end
	Say(("page: Combat Text Style on for the run (was %s, numbers %s, your damage %s, your pet's %s)"):format(
		tostring(kept.combatTextStyle), tostring(kept.combatTextNumbers), tostring(kept.combatTextDamageBy),
		tostring(kept.combatTextPetBy)))
	local class = select(2, UnitClass("player"))
	Say(("start: %s (game %s), class %s, level %s, pet %s, in a group %s, nameplates %s"):format(
		ns.isRetail and "retail" or "Forever", tostring((select(4, GetBuildInfo()))), tostring(class),
		tostring(UnitLevel("player")), tostring(run.hadPet), tostring(IsInGroup and IsInGroup() or false),
		tostring(GetCVar("nameplateShowEnemies"))))
	local okFilter, filter = pcall(ReadFilters)
	run.filter = okFilter and filter or nil
	if not okFilter then Say("filters: read error " .. tostring(filter)) end
	-- (Lines come only while filtered events are on; on if we must, off again after.)
	if C_CombatLog and C_CombatLog.AreFilteredEventsEnabled then
		local okOn, on = pcall(C_CombatLog.AreFilteredEventsEnabled)
		if okOn and not Secret(on) and not on then
			pcall(C_CombatLog.SetFilteredEventsEnabled, true)
			run.turnedOn = true
		end
		Say("filtered events were on: " .. tostring(okOn and T(on)))
	end
	for _, event in ipairs({ "COMBAT_LOG_MESSAGE", "UNIT_COMBAT", "PLAYER_SWING", "PLAYER_REGEN_DISABLED",
		"PLAYER_REGEN_ENABLED" }) do
		local ok = pcall(watcher.RegisterEvent, watcher, event)
		if not ok then Say("could not listen to " .. event) end
	end
	pcall(watcher.RegisterUnitEvent, watcher, "UNIT_SPELLCAST_SUCCEEDED", "player", "pet")
	if InCombatLockdown() then
		run.fought = true
		Box("Combat colors test: FIGHTING. Kill it.", "it ends by itself when the fight does", true)
	else
		Box("Combat colors test: KILL ONE MOB.", "it ends by itself when the fight does", true)
	end
end
