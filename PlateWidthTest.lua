-- /cine debug platewidth [steps]: one run finding out whether WoW Forever's
-- nameplates can be made narrower (a player asked for half/third/quarter
-- width enemy plates without names). Retail's per-row Width works by moving
-- the cast bar container in from the plate's sides (PlateParts ApplySize);
-- on Forever it was never tried, only distance scaling was (it does nothing).
-- So, on your target's plate, three ways in turn, each for a timed step in
-- the big test box (Frames.lua's ns.PadTestBox), put back after:
--   1 inset: retail's way, the cast bar container held further in, the
--     health bar container sitting on it follows;
--   2 bar:   the health bar itself re-anchored half as wide, centered;
--   3 scale: the health bar container at half scale.
-- Each step waits 4 seconds (read the box), then changes the bar, so the
-- change is seen as it happens. Every half second the log gets the plate's
-- widths, points, scale, alpha and how often the game laid the plate out
-- again (UpdateAnchors), and a verdict per step: did the width change, did
-- the game put it back; a screenshot just before each change and 2 seconds
-- into it (the box hidden for them), named in the log, so the
-- Screenshots folder shows what the numbers say. Steps as arguments (platewidth 2 3) redo just those.
-- Into its own saved list, CinematicDB.plateWidthLog. Dev copy only
-- (CinematicDev.toc).
local _, ns = ...

local SETUP, STEP, WAIT = 10, 12, 4 -- seconds: the first step, each way's, before the change
local METHODS = {
	{ key = "inset", say = "%d/%d: Watch your target's HEALTH BAR. In %d sec it should get HALF AS WIDE " ..
		"(the cast bar's spot pulled in)." },
	{ key = "bar", say = "%d/%d: Watch your target's HEALTH BAR. In %d sec it should get HALF AS WIDE " ..
		"(the bar itself narrowed)." },
	{ key = "scale", say = "%d/%d: Watch your target's HEALTH BAR. In %d sec it should get HALF AS BIG " ..
		"(narrower and thinner)." },
}

local run -- { at, steps = { method index... }, step, applied = { plate, undo }, notes, layouts }

-- A screenshot, the box hidden for it (it's back on the next tick), named
-- in the log by its time, as the game names the file (WoWScrnShot_MMDDYY_
-- HHMMSS). Screenshot called from our own function: handed to a timer
-- itself it was refused on Forever.
local function Shot(what)
	ns.PadTestBoxHide()
	local ok, err = pcall(function() Screenshot() end)
	ns.Log("platewidth", "screenshot " .. what)
	return ok and ("screenshot %s at %s"):format(what, date("%m%d%y_%H%M%S")) or ("screenshot failed: " .. tostring(err))
end

local function Say(text)
	local log = CinematicDB and CinematicDB.plateWidthLog
	if log then
		log[#log + 1] = ("%.1f %s"):format(run and GetTime() - run.at or 0, text)
	end
end

local function Num(value)
	if value == nil then return "nil" end
	if issecretvalue and issecretvalue(value) then return "secret" end
	if type(value) == "number" then return ("%.1f"):format(value) end
	return tostring(value)
end
-- A number that can be used (not secret, not nil), else nil.
local function Known(ok, value)
	if ok and type(value) == "number" and not (issecretvalue and issecretvalue(value)) then return value end
	return nil
end
local function Ask(frame, method)
	if not (frame and frame[method]) then return nil end
	return Known(pcall(frame[method], frame))
end
local function Usable(frame)
	return frame and not (frame.IsForbidden and frame:IsForbidden())
end
local function Name(frame)
	if not frame then return "nil" end
	if frame.IsForbidden and frame:IsForbidden() then return "<forbidden>" end
	local ok, name = pcall(frame.GetName, frame)
	if ok and type(name) == "string" and not (issecretvalue and issecretvalue(name)) then return name end
	return "<anon>"
end
-- Its points, as SetPoint takes them; nil and why when they can't be read.
local function Points(frame)
	local okN, count = pcall(frame.GetNumPoints, frame)
	if not okN then return nil, "GetNumPoints: " .. tostring(count) end
	local points = {}
	for i = 1, Known(true, count) or 0 do
		local ok, point, relative, relativePoint, x, y = pcall(frame.GetPoint, frame, i)
		if not ok then return nil, "GetPoint: " .. tostring(point) end
		points[#points + 1] = { point, relative, relativePoint, x, y }
	end
	return points
end
local function PointsText(frame)
	local points, why = Points(frame)
	if not points then return "unreadable (" .. why .. ")" end
	local out = {}
	for _, p in ipairs(points) do
		out[#out + 1] = ("%s>%s.%s %s,%s"):format(tostring(p[1]), Name(p[2]), tostring(p[3]), Num(p[4]), Num(p[5]))
	end
	return #out > 0 and table.concat(out, "; ") or "none"
end

-- Your target's plate and its parts, nil when there's none to use.
local function Parts()
	local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit("target")
	if not Usable(plate) then return nil, plate and "plate forbidden" or "no plate for your target" end
	local unitFrame = plate.UnitFrame
	if not Usable(unitFrame) then return nil, "no usable UnitFrame" end
	return { plate = plate, frame = unitFrame, container = unitFrame.HealthBarsContainer,
		bar = unitFrame.healthBar or (unitFrame.HealthBarsContainer and unitFrame.HealthBarsContainer.healthBar),
		cast = unitFrame.CastBarsContainer }
end

-- Counts the game laying a plate out again, while a run's on.
local hookedLayout = {}
local function HookLayout(unitFrame)
	if hookedLayout[unitFrame] or not unitFrame.UpdateAnchors then return end
	hookedLayout[unitFrame] = true
	pcall(hooksecurefunc, unitFrame, "UpdateAnchors", function()
		if run then
			run.layouts = run.layouts + 1
			Say("  game laid the plate out again (UpdateAnchors)")
		end
	end)
end

local function Snapshot(parts)
	return ("plate %s: frame w %s, container w %s h %s scale %s, bar w %s h %s, cast w %s, plate alpha %s, " ..
		"shown %s"):format(Name(parts.plate), Num(Ask(parts.frame, "GetWidth")), Num(Ask(parts.container, "GetWidth")),
		Num(Ask(parts.container, "GetHeight")), Num(Ask(parts.container, "GetScale")), Num(Ask(parts.bar, "GetWidth")),
		Num(Ask(parts.bar, "GetHeight")), Num(Ask(parts.cast, "GetWidth")), Num(Ask(parts.plate, "GetEffectiveAlpha")),
		tostring(parts.bar and parts.bar:IsVisible()))
end

-- Each way: does it, returning how to undo it (nil and why when it can't).
local APPLY = {}
function APPLY.inset(parts)
	local frameWidth, castWidth = Ask(parts.frame, "GetWidth"), Ask(parts.cast, "GetWidth")
	if not (parts.cast and frameWidth and castWidth) then
		return nil, ("no cast bar container or widths unreadable (frame %s, cast %s)"):format(Num(frameWidth),
			Num(castWidth))
	end
	local barWidth = Ask(parts.container, "GetWidth")
	Say(("  inset: frame %s, cast %s, health container %s (retail's layout: cast = health)"):format(Num(frameWidth),
		Num(castWidth), Num(barWidth)))
	Say("  cast points before: " .. PointsText(parts.cast))
	local oldPoints = Points(parts.cast)
	local inset = (frameWidth - castWidth) / 2
	local function Set(value)
		pcall(parts.cast.ClearAllPoints, parts.cast)
		local okL, errL = pcall(parts.cast.SetPoint, parts.cast, "BOTTOMLEFT", parts.frame, "BOTTOMLEFT", value, 0)
		local okR, errR = pcall(parts.cast.SetPoint, parts.cast, "BOTTOMRIGHT", parts.frame, "BOTTOMRIGHT", -value, 0)
		if not (okL and okR) then Say("  SetPoint failed: " .. tostring(errL) .. " / " .. tostring(errR)) end
	end
	Set(inset + castWidth / 4)
	return function()
		if oldPoints then
			pcall(parts.cast.ClearAllPoints, parts.cast)
			for _, p in ipairs(oldPoints) do pcall(parts.cast.SetPoint, parts.cast, unpack(p, 1, 5)) end
		else
			Set(inset)
		end
	end, barWidth
end
function APPLY.bar(parts)
	local width = Ask(parts.container, "GetWidth") or Ask(parts.bar, "GetWidth")
	if not (parts.bar and parts.container and width) then
		return nil, ("no health bar or width unreadable (%s)"):format(Num(width))
	end
	Say("  bar points before: " .. PointsText(parts.bar))
	local oldPoints = Points(parts.bar)
	pcall(parts.bar.ClearAllPoints, parts.bar)
	local okT, errT = pcall(parts.bar.SetPoint, parts.bar, "TOP", parts.container, "TOP", 0, 0)
	local okB, errB = pcall(parts.bar.SetPoint, parts.bar, "BOTTOM", parts.container, "BOTTOM", 0, 0)
	local okW, errW = pcall(parts.bar.SetWidth, parts.bar, width / 2)
	if not (okT and okB and okW) then
		Say("  failed: " .. tostring(errT) .. " / " .. tostring(errB) .. " / " .. tostring(errW))
	end
	return function()
		pcall(parts.bar.ClearAllPoints, parts.bar)
		if oldPoints and #oldPoints > 0 then
			for _, p in ipairs(oldPoints) do pcall(parts.bar.SetPoint, parts.bar, unpack(p, 1, 5)) end
		else
			pcall(parts.bar.SetAllPoints, parts.bar, parts.container)
		end
	end, width
end
function APPLY.scale(parts)
	local scale = Ask(parts.container, "GetScale")
	if not scale then return nil, "no health bar container or scale unreadable" end
	local before = (Ask(parts.container, "GetWidth") or 0) * scale
	local ok, err = pcall(parts.container.SetScale, parts.container, scale / 2)
	if not ok then Say("  SetScale failed: " .. tostring(err)) end
	return function() pcall(parts.container.SetScale, parts.container, scale) end, before
end
-- What each way changed, to tell whether it took: the width (or scale) now.
local MEASURE = {
	inset = function(parts) return Ask(parts.container, "GetWidth") end, -- (the health bar following)
	bar = function(parts) return Ask(parts.bar, "GetWidth") end,
	-- (On screen: a frame held by two sides stretches as its scale drops, so
	-- its width times its scale, not the scale alone. Tested on Forever.)
	scale = function(parts)
		local width, scale = Ask(parts.container, "GetWidth"), Ask(parts.container, "GetScale")
		return width and scale and width * scale
	end,
}

local function Undo()
	local applied = run and run.applied
	if applied then
		local ok, err = pcall(applied.undo)
		Say(("  put back %s%s"):format(applied.key, ok and "" or (": " .. tostring(err))))
		run.applied = nil
	end
end

local function Verdict(key)
	local note = run.notes[key]
	if not note then return key .. ": not run" end
	if note.skipped then return ("%s: COULDN'T TRY (%s)"):format(key, note.skipped) end
	local took = note.before and note.after and math.abs(note.after - note.before / 2) < note.before * 0.1
	return ("%s: before %s, wanted %s, after %s -> %s%s; game re-laid it out %d times while on"):format(key,
		Num(note.before), Num(note.before and note.before / 2), Num(note.after), took and "CHANGED" or "NOT CHANGED",
		note.undone and (", put back by the game at " .. note.undone .. " sec") or "", note.layouts or 0)
end

local function Finish(done)
	if run.ticker then run.ticker:Cancel() end
	Undo()
	local lines = {}
	for _, index in ipairs(run.steps) do lines[#lines + 1] = Verdict(METHODS[index].key) end
	for _, line in ipairs(lines) do
		Say("verdict " .. line)
		ns.Print(line)
	end
	run = nil
	ns.PadTestBox(done and "Test done. Which steps made the health bar narrower?" or "Test stopped.",
		"Say the step numbers (or none) and \"check log\" (/reload first)", 1, 0.82, 0)
	C_Timer.After(15, function() if not run then ns.PadTestBoxHide() end end)
end

local function Tick()
	local now = GetTime() - run.at
	local parts, why = Parts()
	if parts then HookLayout(parts.frame) end
	-- Setup first, then the ways.
	if now < SETUP then
		ns.PadTestBox("Target a hostile mob (red name) with its NAMEPLATE ON SCREEN, then stand still, out of a fight.",
			parts and ("Plate found. Starts in %d"):format(math.ceil(SETUP - now))
				or ("No plate yet (%s). Starts in %d"):format(why, math.ceil(SETUP - now)),
			parts and 0.3 or 1, parts and 1 or 0.3, 0.3)
		if run.step ~= 0 then
			run.step = 0
			Say("--- setup ---")
		end
		Say(parts and Snapshot(parts) or ("no plate: " .. why))
		return
	end
	local index = math.floor((now - SETUP) / STEP) + 1
	if index > #run.steps then
		Finish(true)
		return
	end
	local method = METHODS[run.steps[index]]
	local into = now - SETUP - (index - 1) * STEP
	if index ~= run.step then
		Undo()
		run.step = index
		run.notes[method.key] = { layouts = 0 }
		Say(("--- step %d: %s ---"):format(run.steps[index], method.key))
	end
	local note = run.notes[method.key]
	if into < WAIT then
		ns.PadTestBox(method.say:format(index, #run.steps, math.ceil(WAIT - into)),
			"GET READY: keep watching the bar", 1, 0.82, 0)
	else
		ns.PadTestBox(method.say:format(index, #run.steps, 0),
			("RECORDING: %d sec left. Did it get narrower?"):format(math.ceil(STEP - into)), 0.3, 1, 0.3)
		if not run.applied and not note.tried then
			note.tried = true
			if not parts then
				note.skipped = why
			else
				Say("  before: " .. Snapshot(parts))
				local layoutsBefore = run.layouts
				local ok, undo, before = pcall(APPLY[method.key], parts)
				if not ok then
					note.skipped = "error: " .. tostring(undo)
				elseif not undo then
					note.skipped = before
				else
					run.applied = { key = method.key, undo = undo, parts = parts }
					note.before, note.layoutsAt = before, layoutsBefore
				end
			end
			if note.skipped then Say("  couldn't: " .. note.skipped) end
		end
	end
	-- (Screenshots: just before the change, and 2 seconds into it.)
	if not note.shotBefore and into >= WAIT - 0.6 and into < WAIT then
		note.shotBefore = true
		Say("  " .. Shot(("step %d %s BEFORE"):format(run.steps[index], method.key)))
	elseif not note.shotAfter and run.applied and into >= WAIT + 2 then
		note.shotAfter = true
		Say("  " .. Shot(("step %d %s AFTER"):format(run.steps[index], method.key)))
	end
	if parts then Say(Snapshot(parts)) end
	local applied = run.applied
	if applied then
		local value = MEASURE[method.key](applied.parts)
		note.after = value
		note.layouts = run.layouts - (note.layoutsAt or run.layouts)
		if value and note.before and math.abs(value - note.before) >= 0.5 then
			note.changed = true
		elseif value and note.changed and not note.undone then
			note.undone = ("%.1f"):format(into - WAIT)
			Say("  back at its own size: the game put it back")
		end
		if parts and parts.plate ~= applied.parts.plate then Say("  target's plate changed (new target or plate)") end
	end
end

-- Typed again while running: stops.
function ns.PlateWidthTest(args)
	if run then
		Finish(false)
		return
	end
	local steps = {}
	for number in (args or ""):gmatch("%d+") do
		number = tonumber(number)
		if METHODS[number] then steps[#steps + 1] = number end
	end
	if #steps == 0 then
		for i = 1, #METHODS do steps[i] = i end
	end
	CinematicDB.plateWidthLog = {}
	run = { at = GetTime(), steps = steps, step = -1, notes = {}, layouts = 0 }
	Say(("start: %s (game %s), CineMode %s, in combat %s, nameplateShowEnemies %s, steps %s"):format(
		ns.isRetail and "retail" or "not retail", tostring((select(4, GetBuildInfo()))), tostring(ns.lastCinematic),
		tostring(InCombatLockdown()), tostring(GetCVar("nameplateShowEnemies")), table.concat(steps, " ")))
	run.ticker = C_Timer.NewTicker(0.5, function()
		local ok, err = pcall(Tick)
		if not ok then
			Say("error: " .. tostring(err))
			if run then Finish(false) end
		end
	end)
	ns.Print(("plate width test: %d sec, follow the box (type it again to stop)"):format(SETUP + #steps * STEP))
end
