-- /cine debug pace: one run on the lighter update loops (PR 5, merged
-- 2026-11-21): the update tick waits longer while nothing happens, the
-- frames' pass slows once a fight's fade in is done, and the mouse-over
-- check asks only about the frame the mouse is on. Steps on screen, each
-- waiting as long as it takes (type the command again to stop):
--   1 still    normal UI, hands off the mouse and keys, 6 s: ticks a second
--   2 cine     the test turns CineMode on: how soon the UI starts fading
--   3 cstill   CineMode, hands off, 6 s: ticks a second
--   4 hover    mouse onto your faded player frame: how soon it comes up
--   5 off      the test turns CineMode off: how soon the UI starts coming back
--   6 fight    the test turns CineMode on; attack any enemy: how soon your
--              frames start coming up, then 5 s in the fight: the frames'
--              pass a second and whether the nameplate pass rests
--   7 after    the fight over: 8 s, the UI back as after any fight
-- Logged: each step's ticks, frames passes and nameplate passes a second,
-- the addon's ms a frame (the profiler), the pace's answer (quiet, wait)
-- sampled, and your player frame's opacity as it changes. A RESULT line per
-- check at the end, and on screen. CineMode and mouse-over (Show on
-- mouse-over) put back as they were. Into CinematicDB.paceLog. Dev copy
-- only (CinematicDev.toc).
local _, ns = ...

local STILL = 6 -- seconds hands off, measured
local SETTLE = 4 -- seconds first, for a change's fades to end (fades 1.5 s, music and zone tint 3 s, +0.5)
local FIGHT_SAMPLE = 5 -- seconds measured in the fight, once its fade in is done
local FIGHT_SETTLE = 3 -- seconds into the fight before measuring
local AFTER = 8 -- seconds after the fight
local QUICK = 0.25 -- seconds: the most a change may take to start fading
local MOVED = 0.05 -- opacity: a change this big counts as the fade starting

local run

local function Say(text)
	local log = CinematicDB and CinematicDB.paceLog
	if log then log[#log + 1] = ("%.2f %s"):format(run and GetTime() - run.at or 0, text) end
end

local function Secret(value)
	return issecretvalue ~= nil and issecretvalue(value)
end
-- Your player frame's opacity (nil if it can't be read).
local function Alpha()
	local frame = _G.PlayerFrame
	if not frame or not frame.GetAlpha then return nil end
	local ok, alpha = pcall(frame.GetAlpha, frame)
	if not ok or Secret(alpha) or type(alpha) ~= "number" then return nil end
	return alpha
end
local function OverPlayer()
	local frame = _G.PlayerFrame
	if not frame or not frame.IsMouseOver then return false end
	local ok, over = pcall(frame.IsMouseOver, frame)
	return ok and not Secret(over) and over and true or false
end

local function CineOn()
	return ns.IsCineModeOn and ns.IsCineModeOn() and true or false
end
local function SetCine(on)
	if CineOn() ~= on and _G.Cinematic_ToggleCineMode then
		_G.Cinematic_ToggleCineMode()
		Say("  CineMode turned " .. (on and "ON" or "OFF") .. " by the test")
	end
end

local function Prompt(text, sub)
	ns.PadTestBox(text, sub or "", 1, 0.82, 0)
end

local function Result(key, ok, text)
	run.results[#run.results + 1] = (ok == nil and "" or ok and "PASS " or "FAIL ") .. text
	Say("RESULT " .. key .. ": " .. (ok == nil and "" or ok and "PASS " or "FAIL ") .. text)
end

-- Counters: the update tick (its letterbox step runs every tick), the
-- frames' pass and the nameplate pass, wrapped for the run.
local WRAPPED = { tick = "UpdateLetterbox", frames = "UpdateFrames", plates = "UpdatePlates" }
local function Wrap()
	run.count, run.orig = { tick = 0, frames = 0, plates = 0 }, {}
	for key, name in pairs(WRAPPED) do
		local orig = ns[name]
		if type(orig) == "function" then
			run.orig[name] = orig
			ns[name] = function(...)
				if run then run.count[key] = run.count[key] + 1 end
				return orig(...)
			end
		end
	end
end
local function Unwrap()
	for name, orig in pairs(run.orig or {}) do ns[name] = orig end
end

-- A measured stretch: counts from now, the profiler on, pace sampled.
local function Begin()
	for key in pairs(run.count) do run.count[key] = 0 end
	run.span = { at = GetTime(), samples = 0, quiet = 0, waitSum = 0, platesQuiet = 0, why = {} }
	if ns.StartProfile then run.profiling = ns.StartProfile(600, true) end
end
local function Sample()
	local span = run.span
	if not span then return end
	span.samples = span.samples + 1
	local p = ns.Pace and ns.Pace()
	if p and p.quiet then
		span.quiet = span.quiet + 1
		span.waitSum = span.waitSum + p.wait
	elseif p then
		-- (Why not quiet, as ns.Pace asks; "busy" = none of these: a change's
		-- fades still under way, Core.lua's idleTick.busyUntil.)
		local why = {}
		local function Add(on, name) if on then why[#why + 1] = name end end
		Add(p.fight, "fight")
		Add(not ns.framesSettled, "frames not settled")
		Add(ns.framesFadeOnly, "frames fading")
		Add(CineOn() and ns.framesWake, "woken by " .. tostring(ns.framesWake))
		Add(ns.previewRows or ns.layoutFadeUntil or ns.fadeDemo or ns.effectsDemo or ns.plateDemo, "preview or demo")
		Add(ns.playerMoving or ns.stopWhileGliding, "moving")
		Add(ns.OnTaxi and ns.OnTaxi(), "flight")
		Add(IsModifierKeyDown(), "modifier key")
		Add(ns.IsChatActive and ns.IsChatActive(), "chat typing")
		Add(ns.Flag(GameTooltip:IsShown()), "tooltip")
		Add(ns.ChatCamImmersive and ns.ChatCamImmersive(), "chat camera")
		local x, y = ns.CursorPosition()
		Add(span.x and (x ~= span.x or y ~= span.y), "mouse moved")
		span.x, span.y = x, y
		local key = #why > 0 and table.concat(why, " + ") or "busy (a change's fades)"
		span.why[key] = (span.why[key] or 0) + 1
	end
	if ns.plates and ns.plates.quiet then span.platesQuiet = span.platesQuiet + 1 end
end
-- Ends it: per second, the addon's ms a frame, how often quiet.
local function End(label)
	local span = run.span
	run.span = nil
	local seconds = math.max(GetTime() - span.at, 0.001)
	local ms
	if run.profiling and ns.StopProfile then
		-- (Its "done" line in chat would bring chat up through CineMode for
		-- 15 s, and the next step would measure that, not standing still.)
		local print, peek = ns.Print, ns.PeekChat
		ns.Print, ns.PeekChat = function() end, nil
		pcall(ns.StopProfile)
		ns.Print, ns.PeekChat = print, peek
		run.profiling = false
		ms = ns.lastProfile and ns.lastProfile.total
	end
	local whys = {}
	for why, n in pairs(span.why) do whys[#whys + 1] = { why, n } end
	table.sort(whys, function(a, b) return a[2] > b[2] end)
	for i, item in ipairs(whys) do
		whys[i] = ("%s %d%%"):format(item[1], math.floor(item[2] * 100 / math.max(span.samples, 1)))
	end
	Say("  not quiet because: " .. (#whys > 0 and table.concat(whys, ", ") or "(always quiet)"))
	local m = {
		ticks = run.count.tick / seconds, frames = run.count.frames / seconds, plates = run.count.plates / seconds,
		quiet = span.samples > 0 and span.quiet / span.samples or 0,
		wait = span.quiet > 0 and span.waitSum / span.quiet or 0,
		platesQuiet = span.samples > 0 and span.platesQuiet / span.samples or 0, ms = ms,
	}
	Say(("  %s: %.1f s, ticks %.1f/s, frames pass %.1f/s, nameplate pass %.1f/s, quiet %d%% (wait %.2f s),"
		.. " plates resting %d%%, addon %s ms a frame, fps %.0f"):format(label, seconds, m.ticks, m.frames, m.plates,
		m.quiet * 100, m.wait, m.platesQuiet * 100, ms and ("%.3f"):format(ms) or "?", GetFramerate()))
	return m
end

local function Go(step)
	run.step, run.stepAt = step, GetTime()
	run.alphaAt = Alpha()
	Say(("--- step %s (CineMode %s, fight %s, player frame opacity %s) ---"):format(step, tostring(CineOn()),
		tostring(InCombatLockdown()), tostring(run.alphaAt)))
end

-- Seconds since the step began for the player frame's opacity to move
-- MOVED from where it was (up: true, down: false); nil while it hasn't.
local function Moved(up)
	local now, from = Alpha(), run.alphaAt
	if not now or not from then return nil end
	if (up and now >= from + MOVED) or (not up and now <= from - MOVED) then
		return GetTime() - run.stepAt
	end
end

local function Finish(done)
	if run.ticker then run.ticker:Cancel() end
	run.events:UnregisterAllEvents()
	run.events:SetScript("OnEvent", nil)
	if run.profiling and ns.StopProfile then
		local print, peek = ns.Print, ns.PeekChat
		ns.Print, ns.PeekChat = function() end, nil
		pcall(ns.StopProfile)
		ns.Print, ns.PeekChat = print, peek
	end
	Unwrap()
	if ns.db then ns.db.mouseover = run.mouseoverWas end
	SetCine(run.cineWas)
	Say(done and "done" or "stopped early")
	local lines = run.results
	run = nil
	ns.PadTestBox(done and "Pace test DONE. /reload, then say \"check log\"." or "Pace test stopped.",
		table.concat(lines, "\n"), 1, 1, 1)
	C_Timer.After(30, function() if not run then ns.PadTestBoxHide() end end)
end

local function Tick()
	Sample()
	local step, since = run.step, GetTime() - run.stepAt
	local alpha = Alpha()
	if alpha ~= run.alphaLogged then
		run.alphaLogged = alpha
		Say(("  player frame opacity %s"):format(tostring(alpha)))
	end
	if step == "still" then
		if not run.span and since >= SETTLE then Begin() end
		if run.span and GetTime() - run.span.at >= STILL then
			local m = End("normal UI, hands off")
			-- (Out of CineMode with nothing kept up outside it: a second apart, was 33 a second.)
			Result("still", m.ticks > 0 and m.ticks <= 12, ("normal UI, hands off: the update tick ran %.1f times a second"
				.. " (was about 33), quiet %d%% of the time"):format(m.ticks, m.quiet * 100))
			Go("cine")
			SetCine(true)
			Prompt("Pace test 2/7: CineMode on", "The test turned it on. Keep your hands off for a moment.")
		end
	elseif step == "cine" then
		local took = Moved(false)
		if took or since > 5 then
			Result("cine", took ~= nil and took <= QUICK, took and ("CineMode on: your frame started fading %.2f s after"
				):format(took) or "CineMode on: your frame didn't fade within 5 s (its row may keep it up)")
			Go("cstill")
			Prompt("Pace test 3/7: hands off", ("Don't touch the mouse or keys for %d seconds."):format(SETTLE + STILL))
		end
	elseif step == "cstill" then
		if not run.span and since >= SETTLE then Begin() end
		if run.span and GetTime() - run.span.at >= STILL then
			local m = End("CineMode, hands off")
			Result("cstill", m.ticks > 0 and m.ticks <= 15, ("CineMode, hands off: the update tick ran %.1f times a second"
				.. " (about 10 when nothing moves), quiet %d%%"):format(m.ticks, m.quiet * 100))
			Go("hover")
			Prompt("Pace test 4/7: mouse onto your portrait",
				"Move the mouse onto your own portrait and name (top left), where your player frame was, and hold it there.")
		end
	elseif step == "hover" then
		if not run.overAt and OverPlayer() then
			run.overAt, run.alphaAt = GetTime(), Alpha()
			Say("  the mouse is on your player frame")
		end
		if run.overAt then
			local now, from = Alpha(), run.alphaAt
			local took = now and from and now >= from + MOVED and GetTime() - run.overAt
			if took or GetTime() - run.overAt > 3 then
				Result("hover", took and took <= QUICK or (from ~= nil and from >= 0.95),
					took and ("mouse on your faded player frame: it started coming up %.2f s after"):format(took)
					or ("mouse on your player frame: its opacity stayed %s (already up: it wasn't faded)"):format(
						tostring(from)))
				Go("off")
				SetCine(false)
				Prompt("Pace test 5/7: CineMode off", "The test turned it off. You can move the mouse away.")
			end
		end
	elseif step == "off" then
		local took = Moved(true)
		if took or since > 5 then
			Result("off", took ~= nil and took <= QUICK, took and ("CineMode off: your frame started coming back %.2f s"
				.. " after"):format(took) or "CineMode off: your frame didn't come back within 5 s")
			Go("fight")
			SetCine(true)
			Prompt("Pace test 6/7: start a fight", "Attack any enemy (a training dummy is fine) and keep fighting"
				.. " till the box says it's done.")
		end
	elseif step == "fight" then
		if run.fightAt then
			local now, from = Alpha(), run.fightAlpha
			if not run.fightUp and now and from and now >= from + MOVED then
				run.fightUp = GetTime() - run.fightAt
				Say(("  your frame started coming up %.2f s into the fight"):format(run.fightUp))
			end
			local inFight = GetTime() - run.fightAt
			if inFight >= FIGHT_SETTLE and not run.span and not run.fightMeasured then Begin() end
			if run.span and inFight >= FIGHT_SETTLE + FIGHT_SAMPLE then
				run.fightMeasured = true
				local m = End("in the fight, its fade in done")
				Result("fightup", run.fightUp ~= nil and run.fightUp <= QUICK or nil, run.fightUp
					and ("fight started: your frame started coming up %.2f s after"):format(run.fightUp)
					or "fight started: your frame didn't come up (it may not be ticked to show in fights)")
				Result("fightpass", m.frames > 0 and m.frames <= 4, ("in the fight: the frames' pass ran %.1f times a second (about 2"
					.. " once settled, was 8)"):format(m.frames))
				Result("fightplates", m.platesQuiet >= 0.5 or m.plates <= 4, ("in the fight: the nameplate pass resting"
					.. " %d%% of the time, %.1f passes a second"):format(m.platesQuiet * 100, m.plates))
				Prompt("Pace test 6/7: end the fight", "Done measuring. Finish the fight (kill it or walk away).")
			end
		end
	elseif step == "after" then
		if since >= AFTER then
			Result("after", nil, ("%d s after the fight: your frame's opacity %s, CineMode %s"):format(AFTER,
				tostring(Alpha()), tostring(CineOn())))
			Finish(true)
		end
	end
end

local function OnEvent(_, event)
	if event == "PLAYER_REGEN_DISABLED" then
		Say("  fight started (PLAYER_REGEN_DISABLED)")
		if run.step == "fight" and not run.fightAt then
			run.fightAt, run.fightAlpha = GetTime(), run.alphaAt
			for _, entry in ipairs(ns.managed or {}) do
				if entry.frame == _G.PlayerFrame then
					local row = entry.row or (ns.HoverRowFor and ns.HoverRowFor(entry))
					Say(("  your player frame: group %s, row %s, shown in fights %s"):format(tostring(entry.group),
						tostring(row), tostring(row and ns.IsCombatShowOn and ns.IsCombatShowOn(row))))
				end
			end
			Prompt("Pace test 6/7: keep fighting", ("Measuring. Keep fighting about %d seconds."):format(
				FIGHT_SETTLE + FIGHT_SAMPLE))
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		Say("  fight ended (PLAYER_REGEN_ENABLED)")
		if run.step == "fight" and run.fightAt then
			if not run.fightMeasured then
				if run.span then End("in the fight (cut short)") end
				Result("fightpass", nil, "the fight ended before it could be measured: start a longer one next time")
			end
			Go("after")
			Prompt("Pace test 7/7: fight over", ("Stand still for %d seconds."):format(AFTER))
		end
	end
end

function ns.PaceTest()
	ns.debugNoCopyWindow = true
	if run then
		Say("stopped: command typed again")
		Finish(false)
		return
	end
	if InCombatLockdown() then
		ns.Print("pace test: not in a fight")
		return
	end
	if not ns.Pace then
		ns.Print("pace test: this copy has no idle pace (ns.Pace): update first")
		return
	end
	CinematicDB.paceLog = {}
	run = { at = GetTime(), results = {} }
	Say(("start: %s (game %s), version %s, fps %.0f"):format(ns.isRetail and "retail" or "Forever",
		tostring((select(4, GetBuildInfo()))), tostring(ns.Version and ns.Version()), GetFramerate()))
	run.cineWas = CineOn()
	run.mouseoverWas = ns.db.mouseover
	ns.db.mouseover = true -- (step 4: the mouse brings frames up)
	Wrap()
	run.events = CreateFrame("Frame")
	run.events:RegisterEvent("PLAYER_REGEN_DISABLED")
	run.events:RegisterEvent("PLAYER_REGEN_ENABLED")
	run.events:SetScript("OnEvent", function(...)
		local ok, err = pcall(OnEvent, ...)
		if not ok and run then Say("event error: " .. tostring(err)) end
	end)
	SetCine(false)
	Go("still")
	Prompt("Pace test 1/7: hands off", ("Stand still and don't touch the mouse or keys for %d seconds."):format(
		SETTLE + STILL))
	run.ticker = C_Timer.NewTicker(0.05, function()
		if not run then return end
		local ok, err = pcall(Tick)
		if not ok then
			Say("error: " .. tostring(err))
			if run then Finish(false) end
		end
	end)
	ns.TestPrompt("Pace test: follow the box (type it again to stop)")
end
