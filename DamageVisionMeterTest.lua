-- /cine debug dvmeter: one run checking Damage Vision's two meter settings,
-- Only while it's faded out (it crossfades with the game's damage meter) and
-- Sits: Over the damage meter. Both turned on for the run (put back after),
-- Damage Vision's made-up test fight up the whole time, crossfading as the
-- real thing does. Timed steps in the big test box (Frames.lua's
-- ns.PadTestBox):
--   1 out:  CineMode off, the meter showing: Damage Vision should be hidden;
--   2 in:   CineMode turned on: the meter fades out (its row unticked) and
--           Damage Vision fades in over its middle, at the same time;
--   3 back: CineMode off again: the meter back, Damage Vision gone.
-- Every quarter second the log gets the meter's alpha, Damage Vision's, the
-- two added up (1 while they crossfade), the window it sits on and how far
-- its middle is from the meter's; a screenshot before each change and 3
-- seconds into it (the box hidden for them); and a verdict per step. Steps
-- as arguments (dvmeter 2 3) redo just those. Into its own saved list,
-- CinematicDB.dvMeterLog. Dev copy only (CinematicDev.toc).
local _, ns = ...

local SETUP, STEP, WAIT = 10, 12, 4 -- seconds: the setup, each step's, before the change
local STEPS = {
	{ key = "out", cine = false, say = "%d/%d: CineMode is OFF. The DAMAGE METER window should be SHOWING, " ..
		"and the gold and teal Damage Vision bar NOT over it. Just watch for %d sec." },
	{ key = "in", cine = true, say = "%d/%d: In %d sec CineMode turns ON. Watch the DAMAGE METER: it should " ..
		"FADE OUT while the Damage Vision bar FADES IN over its middle." },
	{ key = "back", cine = false, say = "%d/%d: In %d sec CineMode turns OFF. The DAMAGE METER should FADE " ..
		"BACK IN while the Damage Vision bar FADES OUT." },
}

local run -- { at, steps, step, notes, kept = { settings, cine } }

local function Say(text)
	local log = CinematicDB and CinematicDB.dvMeterLog
	if log then log[#log + 1] = ("%.2f %s"):format(run and GetTime() - run.at or 0, text) end
end

local function Num(value)
	if value == nil then return "nil" end
	if issecretvalue and issecretvalue(value) then return "secret" end
	if type(value) == "number" then return ("%.2f"):format(value) end
	return tostring(value)
end

-- A screenshot, the box hidden for it (back on the next tick). Called from
-- our own function: handed to a timer itself it was refused on Forever.
local function Shot(what)
	ns.PadTestBoxHide()
	local ok, err = pcall(function() Screenshot() end)
	return ok and ("screenshot %s at %s"):format(what, date("%m%d%y_%H%M%S")) or ("screenshot failed: " .. tostring(err))
end

-- Showing now (the log's), and on as the CineMode key sees it (what the
-- test turns, as the key does).
local function CineOn()
	return ns.lastCinematic and true or false
end
local function CineKeyOn()
	return ns.IsCineModeOn and ns.IsCineModeOn() or false
end

local function SetCine(on)
	if CineKeyOn() ~= on and Cinematic_ToggleCineMode then
		local ok, err = pcall(Cinematic_ToggleCineMode)
		Say(("  CineMode %s by the test%s"):format(on and "on" or "off", ok and "" or (": error " .. tostring(err))))
	end
end

-- The meter's frames as Cinematic fades them (its "meters" row).
local function MeterEntries()
	local parts = {}
	for _, entry in ipairs(ns.managed or {}) do
		if entry.group == "meters" then
			local okShown, shown = pcall(entry.frame.IsShown, entry.frame)
			parts[#parts + 1] = ("%s a%s %s"):format(tostring(entry.name or "?"), Num(entry.alpha),
				okShown and (shown and "shown" or "hidden") or "?")
		end
	end
	return #parts > 0 and table.concat(parts, ", ") or "none managed"
end

local function Snapshot(probe)
	local gap = probe.x and probe.wx and math.sqrt((probe.x - probe.wx) ^ 2 + (probe.y - probe.wy) ^ 2)
	local sum = probe.alpha and probe.alpha / math.max(probe.opacity, 0.01) + probe.meter
	return ("meter %s, vision %s (opacity %s), sum %s, window %s, on it %s, off center %s, cine %s, combat %s"):format(
		Num(probe.meter), Num(probe.alpha), Num(probe.opacity), Num(sum), tostring(probe.name or "none"),
		tostring(probe.over ~= nil and probe.over == probe.window), Num(gap), tostring(CineOn()),
		tostring(InCombatLockdown())), gap, sum
end

local function Verdicts()
	local lines = {}
	for _, index in ipairs(run.steps) do
		local step, note = STEPS[index], run.notes[STEPS[index].key]
		local text
		if not note or not note.last then
			text = "not run"
		else
			local last = note.last
			local vision = (last.alpha or 0) / math.max(last.opacity, 0.01)
			if step.key == "out" then
				text = (last.meter >= 0.95 and vision <= 0.05) and "PASS" or "FAIL"
				text = text .. (" (meter %s, vision %s)"):format(Num(last.meter), Num(vision))
				if last.meter < 0.95 then text = text .. ": the meter isn't showing (open its window?)" end
			elseif step.key == "in" then
				-- (In: never faster than its own 0.4 sec fade, the meter snapping out or not.)
				local took = note.fullAt and note.startAt and note.fullAt - note.startAt
				local ok = last.meter <= 0.05 and vision >= 0.9 and (note.gap or 99) <= 2 and took and took >= 0.2
				text = (ok and "PASS" or "FAIL") .. (" (meter %s, vision %s, off center %s px, faded in over %s sec)")
					:format(Num(last.meter), Num(vision), Num(note.gap), Num(took))
				if took and took < 0.2 then text = text .. ": it POPPED in" end
				if last.meter > 0.05 then text = text .. ": the meter didn't fade (its row shows it in CineMode?)" end
			else
				text = (last.meter >= 0.95 and vision <= 0.05) and "PASS" or "FAIL"
				text = text .. (" (meter %s, vision %s, crossfade worst %s)"):format(Num(last.meter), Num(vision),
					Num(note.worst))
			end
			if step.key ~= "in" and note.worst and note.worst > 0.15 then text = text .. "; NOT a clean crossfade (sum off 1)" end
		end
		lines[#lines + 1] = ("step %d %s: %s"):format(index, step.key, text)
	end
	return lines
end

local function Finish(done)
	if run.ticker then run.ticker:Cancel() end
	local kept = run.kept
	for key, value in pairs(kept.settings) do ns.db[key] = value end
	if ns.StopDamageVisionTest then pcall(ns.StopDamageVisionTest) end
	SetCine(kept.cine)
	if ns.RefreshDamageVision then pcall(ns.RefreshDamageVision) end
	for _, line in ipairs(Verdicts()) do
		Say("verdict " .. line)
		ns.Print(line)
	end
	run = nil
	ns.PadTestBox(done and "Test done. Your settings and CineMode are back as they were." or "Test stopped.",
		"Say \"check log\" (/reload first)", 1, 0.82, 0)
	C_Timer.After(15, function() if not run then ns.PadTestBoxHide() end end)
end

local function Tick()
	local now = GetTime() - run.at
	local probe = ns.DamageVisionProbe()
	local line, gap, sum = Snapshot(probe)
	if now < SETUP then
		ns.PadTestBox("Open the game's DAMAGE METER window so it's on screen, then stand still, out of a fight.",
			probe.window and ("Meter window found. Starts in %d"):format(math.ceil(SETUP - now))
				or ("No meter window on screen yet. Starts in %d"):format(math.ceil(SETUP - now)),
			probe.window and 0.3 or 1, probe.window and 1 or 0.3, 0.3)
		if run.step ~= 0 then
			run.step = 0
			Say("--- setup --- meter frames: " .. MeterEntries())
		end
		Say(line)
		return
	end
	local index = math.floor((now - SETUP) / STEP) + 1
	if index > #run.steps then
		Finish(true)
		return
	end
	local step = STEPS[run.steps[index]]
	local into = now - SETUP - (index - 1) * STEP
	if index ~= run.step then
		run.step = index
		run.notes[step.key] = {}
		Say(("--- step %d: %s --- meter frames: %s"):format(run.steps[index], step.key, MeterEntries()))
		-- (Each step alone: the one before it set up for it, step 1's setting the change.)
		SetCine(step.key == "back")
		ns.TestDamageVision(true, STEP * (#run.steps - index + 1) + 5)
	end
	local note = run.notes[step.key]
	local wait = step.key == "out" and 0 or WAIT
	if into < wait then
		ns.PadTestBox(step.say:format(index, #run.steps, math.ceil(wait - into)), "GET READY: keep watching",
			1, 0.82, 0)
	else
		ns.PadTestBox(step.say:format(index, #run.steps, math.ceil(STEP - into)),
			("RECORDING: %d sec left"):format(math.ceil(STEP - into)), 0.3, 1, 0.3)
		if not note.changed then
			note.changed = true
			if step.key ~= "out" then SetCine(step.cine) end
		end
		-- (The crossfade: how far off 1 the two add up, once the change is in.)
		if sum and into >= wait + (step.key == "out" and 0.75 or 0.25) then note.worst = math.max(note.worst or 0, math.abs(sum - 1)) end
		note.last, note.gap = probe, gap
		-- (When it started coming in and when it was all in: step 2's fade-in time.)
		local vision = (probe.alpha or 0) / math.max(probe.opacity, 0.01)
		if not note.startAt and vision > 0.02 then note.startAt = GetTime() end
		if note.startAt and not note.fullAt and vision >= 0.95 then note.fullAt = GetTime() end
	end
	if not note.shotBefore and into >= wait - 0.5 and step.key ~= "out" then
		note.shotBefore = true
		Say("  " .. Shot(("step %d %s BEFORE"):format(run.steps[index], step.key)))
	elseif not note.shotAfter and into >= wait + 3 then
		note.shotAfter = true
		Say("  " .. Shot(("step %d %s AFTER"):format(run.steps[index], step.key)))
	end
	Say(line)
end

-- Typed again while running: stops.
function ns.DamageVisionMeterTest(args)
	if run then
		Finish(false)
		return
	end
	if not ns.DamageVisionProbe then
		ns.Print("dvmeter: Damage Vision isn't loaded.")
		return
	end
	local steps = {}
	for number in (args or ""):gmatch("%d+") do
		number = tonumber(number)
		if STEPS[number] then steps[#steps + 1] = number end
	end
	if #steps == 0 then
		for i = 1, #STEPS do steps[i] = i end
	end
	local db = ns.db
	CinematicDB.dvMeterLog = {}
	run = { at = GetTime(), steps = steps, step = -1, notes = {},
		kept = { cine = CineKeyOn(), settings = { damageVisionMeterHidden = db.damageVisionMeterHidden,
			damageVisionSpot = db.damageVisionSpot } } }
	db.damageVisionMeterHidden, db.damageVisionSpot = true, "meter"
	ns.RefreshDamageVision()
	local okCine, cineShow = pcall(ns.IsCineShowOn, "meters")
	local okFight, fightShow = pcall(ns.IsCombatShowOn, "meters")
	Say(("start: %s (game %s), CineMode %s, combat %s, Damage Vision page %s, meter CVar %s, meters row: " ..
		"CineMode %s, combat %s, steps %s"):format(ns.isRetail and "retail" or "not retail",
		tostring((select(4, GetBuildInfo()))), tostring(CineOn()), tostring(InCombatLockdown()),
		tostring(db.damageVision), tostring(C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("damageMeterEnabled")),
		okCine and tostring(cineShow) or "?", okFight and tostring(fightShow) or "?",
		table.concat(steps, " ")))
	run.ticker = C_Timer.NewTicker(0.25, function()
		local ok, err = pcall(Tick)
		if not ok then
			Say("error: " .. tostring(err))
			if run then Finish(false) end
		end
	end)
	ns.Print(("damage vision meter test: %d sec, follow the box (type it again to stop)"):format(SETUP + #steps * STEP))
end
