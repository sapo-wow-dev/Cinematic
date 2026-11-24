-- /cine debug drunkcam: does the auto-run camera jump (a player's clip,
-- 2026-11-23, Forever: the view snapped round in one frame while they ran
-- drunk)? Ledger: Tools/tests/drunk-camera.md. Run 1 ruled out the turn hold
-- (it never pushed) and saw jumps only with the auto-run camera on; it also
-- saw the camera speed and zoom settings written over and over. Run 2 asks
-- whether it happens sober too, and times every such write. Steps:
--   1 sober     auto-run 20 s sober, CineMode on
--   2 soberoff  the same with CineMode off
--   3 drunk     drink till drunk (skip it with no drinks: 4-5 skip too)
--   4 cine      auto-run 20 s drunk, CineMode on
--   5 nocine    the same with CineMode off
-- Each recording logs, per second: facing change and top turn rate, the turn
-- hold's push, view calls and setting writes, the camera mode; as they
-- happen: facing jumps of 3+ degrees in a frame, every change of a camera
-- speed / zoom / shoulder setting with the file:line that wrote it, another
-- addon's MoveView calls. "It jumped" marks the moment you saw a snap and
-- dumps the last 1.5 s frame by frame, with the setting changes in it.
-- Into CinematicDB.drunkCamTestLog. Dev copy only.
local _, ns = ...

local RECORD_RUN = 20  -- seconds of auto-running per step
local JUMP_DEG = 3     -- a facing change this big in one frame is logged
local FAST_YAW = 90    -- degrees per second of yaw push logged as fast
local TURN_RATE = 20   -- degrees per second: Camera.lua's IsTurning threshold
local MAX_LINES = 250  -- event lines per step, at most
local RING = 120       -- frames kept for a mark's dump

local rec -- the recording now (nil: none)

local function Facing()
	local ok, f = pcall(GetPlayerFacing)
	if not ok or type(f) ~= "number" or (issecretvalue and issecretvalue(f)) then return nil end
	return f
end

local function Event(text)
	if not rec then return end
	rec.lines = rec.lines + 1
	if rec.lines > MAX_LINES then
		rec.dropped = rec.dropped + 1
		return
	end
	rec.r:Log(("%.2f %s"):format(GetTime() - rec.began, text))
end

-- MoveView / SetView calls while recording, and whose (our camera code or another's).
local VIEW_CALLS = { "MoveViewLeftStart", "MoveViewLeftStop", "MoveViewRightStart", "MoveViewRightStop",
	"SetView", "ResetView", "FlipCameraYaw" }
local function HookViews()
	if ns.drunkCamHooked then return end
	ns.drunkCamHooked = true
	for _, name in ipairs(VIEW_CALLS) do
		if type(_G[name]) == "function" then
			hooksecurefunc(name, function(...)
				if not rec then return end
				-- (This file's own lines left out: it's in Cinematic's folder too.)
				local stack = (debugstack(2, 8, 0) or ""):gsub("[^\n]*DrunkCamTest[^\n]*\n?", "")
				-- (Cinematic or CinematicDev: run 1 took the dev copy's own calls for another addon's.)
				local ours = stack:find("AddOns[/\\]Cinematic") ~= nil
				local key = name .. (ours and "" or " (other)")
				rec.calls[key] = (rec.calls[key] or 0) + 1
				rec.secCalls = rec.secCalls + 1
				-- Ours are counted (the sway sends one most frames); another's logged with its stack.
				if not ours then
					Event(("call %s(%s) OTHER: %s"):format(name, tostring((...)), stack:gsub("\n", " | "):sub(1, 200)))
				end
			end)
		end
	end
end

-- Camera setting writes while recording (run 1: cameraZoomSpeed written 1498
-- times, cameraPitchMoveSpeed 112, cameraYawMoveSpeed 10, test_cameraOverShoulder
-- 318, untimed). Each change logged with its time and the writer's file:line;
-- a move started at a crawl speeds up with its setting.
local WATCH = { cameraYawMoveSpeed = true, cameraPitchMoveSpeed = true, cameraZoomSpeed = true,
	test_cameraOverShoulder = true, cameraSmoothStyle = true, cameraDistanceMaxZoomFactor = true,
	cameraYawSmoothSpeed = true, cameraPitchSmoothSpeed = true }
local function Writer()
	local stack = (debugstack(3, 8, 0) or ""):gsub("[^\n]*DrunkCamTest[^\n]*\n?", "")
	-- (Lines read [Interface/AddOns/X/f.lua]:67: or [string "@Interface/AddOns/X/f.lua"]:67:.)
	local file, line = stack:match("AddOns[/\\](Cinematic[^\"%]]-%.lua)[\"%]]*:(%d+)")
	if not file then file, line = stack:match("AddOns[/\\]([^\"%]]-%.lua)[\"%]]*:(%d+)") end
	return file and (file .. ":" .. line) or "?"
end
local function OnCVarWrite(name, value)
	if not rec or type(name) ~= "string" or not WATCH[name] then return end
	value = tostring(value)
	local count = rec.cvarCounts[name] or 0
	rec.cvarCounts[name] = count + 1
	rec.secCvars = rec.secCvars + 1
	local was = rec.cvarLast[name]
	rec.cvarLast[name] = value
	if was == value then return end -- (same value again: counted only)
	local line = ("%.2f %s %s -> %s by %s"):format(GetTime() - rec.began, name, tostring(was), value, Writer())
	local ring = rec.cvarRing
	ring[#ring + 1] = { at = GetTime(), line = line }
	if #ring > 40 then table.remove(ring, 1) end
	rec.cvarChanges = rec.cvarChanges + 1
	if rec.cvarChanges <= 120 then Event("cvar " .. line:gsub("^%S+ ", "")) end
end
local function HookCVars()
	if ns.drunkCamCVarHooked then return end
	ns.drunkCamCVarHooked = true
	hooksecurefunc("SetCVar", OnCVarWrite)
	if C_CVar and C_CVar.SetCVar then hooksecurefunc(C_CVar, "SetCVar", OnCVarWrite) end
end

local function NewSecond()
	return { frames = 0, change = 0, maxRate = 0, turning = 0, maxExtra = 0, maxOffset = 0, styles = {}, jumps = 0 }
end

local function FlushSecond()
	local s = rec.sec
	if s.frames == 0 then return end
	local styles = {}
	for v in pairs(s.styles) do styles[#styles + 1] = v end
	table.sort(styles)
	Event(("sec: frames %d, facing moved %.1f deg, top rate %.0f deg/s, turning %d/%d frames, jumps %d, "
		.. "yaw push max %.0f, offset max %.1f, smoothStyle %s, view calls %d, cvar writes %d, cam %s, orbit %s, autorun %s, cine %s, speed %.1f"):format(
		s.frames, s.change, s.maxRate, s.turning, s.frames, s.jumps, s.maxExtra, s.maxOffset,
		table.concat(styles, "/"), rec.secCalls, rec.secCvars, tostring(ns.activeCam), tostring(ns.camGates and ns.camGates.prefix),
		tostring(ns.IsAutoRunning and ns.IsAutoRunning() or false), tostring(ns.lastCinematic),
		(GetUnitSpeed("player")) or 0))
	rec.secCalls, rec.secCvars = 0, 0
end

local function OnUpdate(_, elapsed)
	if not rec then return end
	local now = GetTime()
	local f = Facing()
	local d = 0
	if f and rec.lastFacing then
		d = f - rec.lastFacing
		if d > math.pi then d = d - 2 * math.pi elseif d < -math.pi then d = d + 2 * math.pi end
		d = math.deg(d)
	end
	rec.lastFacing = f
	local rate = elapsed > 0 and d / elapsed or 0
	local t = ns.GetTurnDebug and ns.GetTurnDebug() or {}
	local extra, offset = t.extra or 0, t.offset or 0
	local style = tostring(t.smoothStyle or GetCVar("cameraSmoothStyle"))
	local counts = rec.counting()
	if counts then rec.counted = rec.counted + elapsed end

	local s = rec.sec
	s.frames = s.frames + 1
	s.change = s.change + math.abs(d)
	s.maxRate = math.max(s.maxRate, math.abs(rate))
	if math.abs(rate) > TURN_RATE then s.turning = s.turning + 1 end
	s.maxExtra = math.max(s.maxExtra, math.abs(extra))
	s.maxOffset = math.max(s.maxOffset, math.abs(offset))
	s.styles[style] = true
	if math.abs(d) >= JUMP_DEG then
		s.jumps = s.jumps + 1
		rec.jumps = rec.jumps + 1
		Event(("facing jump %.1f deg in %.0f ms (keys %s)"):format(d, elapsed * 1000, tostring(t.keys)))
	end
	rec.maxRate = math.max(rec.maxRate, math.abs(rate))
	if math.abs(rate) > TURN_RATE then rec.turnFrames = rec.turnFrames + 1 end
	rec.frames = rec.frames + 1
	if math.abs(extra) >= FAST_YAW then
		rec.fast = rec.fast + 1
		if now - rec.lastFastAt > 0.25 then
			Event(("fast yaw push %.0f deg/s (offset %.1f, axis %s)"):format(extra, offset, tostring(t.axis)))
			rec.lastFastAt = now
		end
	end
	if style ~= rec.style then
		if rec.style then rec.styleFlips = rec.styleFlips + 1 end
		Event(("cameraSmoothStyle %s -> %s (turn hold follow-off %s)"):format(tostring(rec.style), style, tostring(t.followOff)))
		rec.style = style
	end
	local mode = tostring(ns.activeCam) .. "/" .. tostring(ns.camGates and ns.camGates.prefix)
	if mode ~= rec.mode then
		Event(("camera %s -> %s"):format(tostring(rec.mode), mode))
		rec.mode = mode
	end
	local ring = rec.ring
	ring[#ring + 1] = ("%.2f d%.1f r%.0f push%.0f off%.1f %s s%s"):format(now - rec.began, d, rate, extra, offset,
		tostring(t.axis), style)
	if #ring > RING then table.remove(ring, 1) end
	if now - rec.secAt >= 1 then
		FlushSecond()
		rec.sec, rec.secAt = NewSecond(), now
	end
end

local frame
-- Records until `seconds` of counting() time (auto-running, or holding forward).
local function Record(r, label, seconds, counting, ask)
	HookViews()
	HookCVars()
	frame = frame or CreateFrame("Frame")
	rec = { r = r, began = GetTime(), lines = 0, dropped = 0, calls = {}, secCalls = 0, ring = {},
		sec = NewSecond(), secAt = GetTime(), counted = 0, counting = counting, jumps = 0, fast = 0,
		styleFlips = 0, marks = 0, maxRate = 0, turnFrames = 0, frames = 0, lastFastAt = 0,
		cvarCounts = {}, cvarLast = {}, cvarRing = {}, cvarChanges = 0, secCvars = 0 }
	for name in pairs(WATCH) do rec.cvarLast[name] = tostring(GetCVar(name)) end
	frame:SetScript("OnUpdate", OnUpdate)
	r:Log(("recording %s: drunk level now %s"):format(label, tostring(ns.drunkCamLevel)))
	local mark = { label = "It jumped", fn = function()
		if not rec then return end
		rec.marks = rec.marks + 1
		Event("MARK: you saw the camera jump. The last 1.5 s, frame by frame (d facing change, r rate, push yaw, off offset):")
		local from = math.max(1, #rec.ring - 90)
		for i = from, #rec.ring, 6 do
			Event("  " .. table.concat({ unpack(rec.ring, i, math.min(#rec.ring, i + 5)) }, " ; "))
		end
		-- The setting changes in those 1.5 s (most likely the jump's cause).
		local near = {}
		for _, c in ipairs(rec.cvarRing) do
			if GetTime() - c.at <= 1.5 then near[#near + 1] = c.line end
		end
		Event("  setting changes in those 1.5 s: " .. (#near > 0 and table.concat(near, " ; ") or "none"))
	end }
	r:WaitFor(ask, { seconds = seconds + 5, buttons = { mark },
		check = function() return rec and rec.counted >= seconds and "recorded" end })
	FlushSecond()
	frame:SetScript("OnUpdate", nil)
	local calls = {}
	for k, v in pairs(rec.calls) do calls[#calls + 1] = k .. " x" .. v end
	table.sort(calls)
	local writes = {}
	for k, v in pairs(rec.cvarCounts) do writes[#writes + 1] = k .. " x" .. v end
	table.sort(writes)
	r:Log(("setting writes %s: %s; changes %d"):format(label, #writes > 0 and table.concat(writes, ", ") or "none",
		rec.cvarChanges))
	local res = rec
	rec = nil
	r:Log(("summary %s: %d frames, top facing rate %.0f deg/s, turning frames %d (%.0f%%), facing jumps %d, "
		.. "fast yaw frames %d, smoothStyle flips %d, marks %d, lines dropped %d, view calls: %s"):format(
		label, res.frames, res.maxRate, res.turnFrames, res.frames > 0 and 100 * res.turnFrames / res.frames or 0,
		res.jumps, res.fast, res.styleFlips, res.marks, res.dropped, #calls > 0 and table.concat(calls, ", ") or "none"))
	r:Verdict(res.counted >= seconds, ("%s: %.0f s recorded"):format(label, res.counted))
	return res
end

local function AutoRunning() return ns.IsAutoRunning and ns.IsAutoRunning() and true or false end

-- Drunk level from the game's system lines (no API for it).
local DRUNK_WORDS = { "sober", "tipsy", "drunk", "smashed" }
local function DrunkLevel(msg)
	if type(msg) ~= "string" then return nil end
	for i = 1, 4 do
		local text = _G["DRUNK_MESSAGE_SELF" .. i]
		if text and msg == text then return i end
	end
	local lower = msg:lower()
	if lower:find("^you feel") or lower:find("^you are") then
		for i = #DRUNK_WORDS, 1, -1 do
			if lower:find(DRUNK_WORDS[i], 1, true) then return i end
		end
	end
	return nil
end
-- (Run 1 caught no drunk line at all: the last few system and emote lines
-- are kept raw, so the drink step can log what Forever really says.)
local recentLines = {}
local listener = CreateFrame("Frame")
listener:RegisterEvent("CHAT_MSG_SYSTEM")
listener:RegisterEvent("CHAT_MSG_TEXT_EMOTE")
listener:SetScript("OnEvent", function(_, event, msg)
	recentLines[#recentLines + 1] = event:gsub("CHAT_MSG_", "") .. ": " .. tostring(msg)
	if #recentLines > 6 then table.remove(recentLines, 1) end
	local level = DrunkLevel(msg)
	if level then
		ns.drunkCamLevel = level .. " (" .. tostring(msg) .. ")"
		if rec then Event("drunk level: " .. ns.drunkCamLevel) end
	end
end)
local function LogDrunkStrings(r)
	local known = {}
	for i = 1, 4 do known[#known + 1] = i .. "=" .. tostring(_G["DRUNK_MESSAGE_SELF" .. i]) end
	r:Log("game's drunk strings: " .. table.concat(known, " | "))
	r:Log("last system/emote lines: " .. (#recentLines > 0 and table.concat(recentLines, " | ") or "none"))
end

local function CineOn(r, on)
	if not (ns.IsCineModeOn and Cinematic_ToggleCineMode) then return false end
	if ns.IsCineModeOn() ~= on then
		r:Keep("cineWas", tostring(ns.IsCineModeOn()))
		Cinematic_ToggleCineMode()
	end
	r:Log("CineMode " .. tostring(ns.IsCineModeOn()))
	return ns.IsCineModeOn() == on
end

local results = {}

ns.TestKit.Define({
	name = "drunkcam",
	key = "drunkCamTest",
	title = "Drunk camera",
	about = "auto-running sober and drunk: does the camera's turn hold jump about? (player clip 2026-11-23)",
	needs = "Open flat ground, and 3-4 alcoholic drinks (an innkeeper sells them)",
	cineMode = true, -- (steps turn it on and off themselves; put back at the end)
	cvars = { "cameraSmoothStyle", "cameraYawMoveSpeed", "cameraYawSmoothSpeed" },
	context = function()
		local db = ns.db or {}
		return ("runCamera %s, runCameraDelay %s, runSwingBehind %s, runGlideDelay %s, runOrbit %s, outsideCineCameras %s, drunk %s"):format(
			tostring(db.runCamera), tostring(db.runCameraDelay), tostring(db.runSwingBehind), tostring(db.runGlideDelay),
			tostring(db.runOrbit), tostring(db.outsideCineCameras), tostring(ns.drunkCamLevel))
	end,
	putBack = function(extra)
		if extra.cineWas and ns.IsCineModeOn and Cinematic_ToggleCineMode
			and tostring(ns.IsCineModeOn()) ~= extra.cineWas then
			Cinematic_ToggleCineMode()
		end
		return "CineMode as it was (" .. tostring(extra.cineWas or "unchanged") .. ")"
	end,
	steps = {
		{ key = "sober", title = "auto-run sober, CineMode on", run = function(r)
			results = {} -- (a fresh run)
			CineOn(r, true)
			local answer = r:WaitFor("Sober: start auto-running on open ground (Num Lock) and let it run. "
				.. "Already drunk? Click Already drunk.", { buttons = { "Already drunk" },
				check = function() return AutoRunning() and "running" end })
			if answer == "button" then results.drunkFirst = true r:Skip("already drunk: no sober run") return end
			results.sober = Record(r, "sober CineMode on", RECORD_RUN, AutoRunning,
				"Keep auto-running (steer as you like). Click It jumped each time the camera snaps.")
		end },
		{ key = "soberoff", title = "auto-run sober, CineMode off", run = function(r)
			if results.drunkFirst then r:Skip("already drunk: no sober run") return end
			CineOn(r, false)
			r:WaitFor("Still sober: keep (or start) auto-running.", { check = function() return AutoRunning() and "running" end })
			results.soberoff = Record(r, "sober CineMode off", RECORD_RUN, AutoRunning,
				"Keep auto-running. Click It jumped each time the camera snaps.")
		end },
		{ key = "drunk", title = "get drunk", run = function(r)
			results.drunk = nil -- (set below only: skipped, the drunk steps skip)
			local level = ns.drunkCamLevel and tonumber(ns.drunkCamLevel:match("^%d"))
			if results.drunkFirst or (level and level >= 3) then
				results.drunk = true
				r:Log("already drunk: " .. tostring(ns.drunkCamLevel))
				r:Pass("drunk")
				return
			end
			local event, msg = r:WaitFor("Drink till you're drunk (Skip step if you have no drinks). Stop auto-running first.",
				{ buttons = { "I'm drunk" }, events = { "CHAT_MSG_SYSTEM" },
				filter = function(_, m) local l = DrunkLevel(m) return l and l >= 3 end })
			r:Log(("drunk by %s: %s"):format(tostring(event), tostring(msg)))
			LogDrunkStrings(r)
			results.drunk = true
			r:Pass("drunk")
		end },
		{ key = "cine", title = "auto-run drunk, CineMode on", run = function(r)
			if not results.drunk then r:Skip("not drunk (the drink step was skipped)") return end
			CineOn(r, true)
			r:WaitFor("Drunk: start auto-running on open ground again.", { check = function() return AutoRunning() and "running" end })
			results.cine = Record(r, "drunk CineMode on", RECORD_RUN, AutoRunning,
				"Keep auto-running. Click It jumped each time the camera snaps.")
		end },
		-- (Run 1's turn hold off and held-forward steps are gone: the turn hold
		-- never pushed, and nothing jumped without the auto-run camera.)
		{ key = "nocine", title = "auto-run drunk, CineMode off", run = function(r)
			if not results.drunk then r:Skip("not drunk (the drink step was skipped)") return end
			CineOn(r, false)
			r:WaitFor("Still drunk: keep (or start) auto-running.", { check = function() return AutoRunning() and "running" end })
			results.nocine = Record(r, "drunk CineMode off", RECORD_RUN, AutoRunning,
				"Keep auto-running. Click It jumped each time the camera snaps.")
			-- What the run says, side by side.
			local function Line(name)
				local s = results[name]
				local writes = 0
				for _, n in pairs(s and s.cvarCounts or {}) do writes = writes + n end
				return s and ("%s: turning %.0f%%, jumps %d, setting writes %d, changes %d, marks %d"):format(name,
					s.frames > 0 and 100 * s.turnFrames / s.frames or 0, s.jumps, writes, s.cvarChanges, s.marks)
					or (name .. ": not recorded")
			end
			for _, name in ipairs({ "sober", "soberoff", "cine", "nocine" }) do r:Log("compare " .. Line(name)) end
		end },
	},
})
