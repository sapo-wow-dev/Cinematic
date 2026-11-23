-- /cine debug namescale: one run to calibrate the size of names over heads
-- on WoW Forever (2026-11-20). Its plates don't scale, so ours are sized by
-- the camera's zoom plus a fixed guess at the unit's distance (PlateParts'
-- Look, UNIT_YARDS): walking up to an NPC, the game's own name grows and
-- ours may not. The run walks the same path twice, in the big test box
-- (Frames.lua's ns.PadTestBox):
--   setup   target a friendly NPC ~40 yards straight ahead, zoom set;
--   far     hands off: ours shot, Cinematic paused, the game's shot, back
--           on (the same spot and camera: the fairest pair; run 3 found
--           run 2's heights wrong, its walks' camera differed);
--   1 game  ("full" only) Cinematic paused: walk up to the NPC and stop;
--   back    ("full" only) walk back to the start spot;
--   2 ours  Cinematic running: the walk;
--   near    hands off by the NPC: Cinematic paused, the game's shot (ours:
--           the walk's last), back on;
--   ui      ("full" only, proven run 3: the game's names stay the same at
--           any UI scale, ours too with the fix) standing there, hands off: the other UI scale (1 or 0.64),
--           ours shot, Cinematic paused, the game's shot, the UI scale
--           back, the game's shot (PlateParts keeps ours the same on
--           screen at any UI scale: right only if the game's don't move).
--   cam     ("full" only, proven run 3: ours and the game's the same with it
--           off, within ~10%) still there: Cinematic running, Shoulder Cam switched off,
--           ours shot, paused, the game's shot; Shoulder Cam back on (runs
--           1-2 were all with it on: does the fit hold without?). Skipped
--           if it was off.
-- Every shot logs the camera's settings (CAMERA_CVARS, Shoulder Cam on), and
-- the file it was saved as (SCREENSHOT_SUCCEEDED's time: a second after the
-- call at times, run 3). Paused quietly (ns.suspendQuiet): no red "stopped"
-- line or dev error window (run 3's "errors").
-- Zoom only since 2026-11-23 (PlateParts' Look: the user didn't want names
-- resizing as they walk): a plain run is far, the walk and near, its
-- verdict that our name kept one size the whole walk; the far and near
-- pairs show it against the game's (ours: the game's at ~8 yards since 2026-11-23, 16 before). "full"
-- adds walk 1, UI scale and Shoulder Cam (proven, runs 1-8).
-- Walk 1 and back are proven (runs 1 and 2, 2026-11-23: the game's names
-- measured twice, the same within 5%, Tools/tests/name-scale.md): left out
-- unless "full" (/cine debug namescale full).
-- A screenshot every SHOT_YARDS walked (from the start spot, UnitPosition;
-- every SHOT_SECONDS walking where it can't be read), so the two walks give
-- pairs at the same spots. Each shot's log line: yards walked, the target's
-- distance (exact if readable, else its interact band), the camera's zoom,
-- our Look (size, height) and the facing. Into CinematicDB.nameScaleLog.
-- Dev copy only (CinematicDev.toc).
local _, ns = ...

local SETUP, SHOT_YARDS, SHOT_SECONDS, STILL = 10, 3, 1.5, 1.5
local HOME_YARDS = 1.5 -- this near the start spot counts as back on it
local TICK = 0.1

local UiScaleStep -- (below)
local run -- { at, phase, phaseAt, start, shots, walked, lastShotAt, nextShot, stillSince, near, paused }

local function Say(text)
	local log = CinematicDB and CinematicDB.nameScaleLog
	if log then log[#log + 1] = ("%.1f %s"):format(run and GetTime() - run.at or 0, text) end
end

-- (Every return passed on: ns.PlateNameState's text is its 5th; a cap of
-- four dropped it, the smooth step's offline run.)
local function Returns(ok, ...)
	if ok then return ... end
	return nil
end
local function Call(f, ...)
	if not f then return nil end
	return Returns(pcall(f, ...))
end

local function Plain(value)
	if issecretvalue and issecretvalue(value) then return nil end
	return value
end

local function Position()
	local y, x = Call(UnitPosition, "player")
	y, x = Plain(y), Plain(x)
	if type(y) == "number" and type(x) == "number" then return x, y end
	return nil
end

local function FromStart()
	local x, y = Position()
	if not (x and run.start) then return nil end
	return math.sqrt((x - run.start.x) ^ 2 + (y - run.start.y) ^ 2)
end

local function Moving()
	local speed = Plain(Call(GetUnitSpeed, "player"))
	return type(speed) == "number" and speed > 0
end

local function TargetDistance()
	local squared, checked = Call(UnitDistanceSquared, "target")
	squared, checked = Plain(squared), Plain(checked)
	if type(squared) == "number" and checked then return ("%.1fyd"):format(math.sqrt(squared)), true end
	-- (Bands: 3 = 10 yards, 2 = 11, 4 = 28.)
	for _, band in ipairs({ { 3, "<10yd" }, { 2, "<11yd" }, { 4, "<28yd" } }) do
		if Call(CheckInteractDistance, "target", band[1]) == true then return band[2], false end
	end
	return ">28yd", false
end

local function Near()
	return Call(CheckInteractDistance, "target", 3) == true
end

-- The box and the dev error window (ns.Suspend's "stopped" line opens it,
-- over the NPC: run 1, 2026-11-23) hide a tick before the shot: hidden in
-- the same tick, the box was still in every shot.
local function Clear()
	ns.PadTestBoxHide()
	if _G.CinematicDevErrorWindow then _G.CinematicDevErrorWindow:Hide() end
end

-- The camera settings the game's names and ours may hang on.
local CAMERA_CVARS = { "test_cameraOverShoulder", "cameraFov", "test_cameraDynamicPitch",
	"test_cameraDynamicPitchBaseFovPad", "test_cameraDynamicPitchBaseFovPadFlying", "CameraKeepCharacterCentered" }
local function CameraLine()
	local parts = { "shoulderCam " .. tostring(ns.db and ns.db.shoulderCam) }
	for _, name in ipairs(CAMERA_CVARS) do
		local value = Call(GetCVar, name)
		if value ~= nil then parts[#parts + 1] = name .. "=" .. tostring(value) end
	end
	return table.concat(parts, " ")
end

-- The file each shot was saved as (the game names it as it saves).
local saved = CreateFrame("Frame")
saved:RegisterEvent("SCREENSHOT_SUCCEEDED")
saved:RegisterEvent("SCREENSHOT_FAILED")
saved:SetScript("OnEvent", function(_, event)
	if run then
		Say(event == "SCREENSHOT_SUCCEEDED" and ("    saved WoWScrnShot_%s.jpg"):format(date("%m%d%y_%H%M%S"))
			or "    screenshot FAILED")
	end
end)

local function Shot(why)
	Clear()
	local ok, err = pcall(function() Screenshot() end)
	-- (The target's own name as sized: band, eased yards, size, height.)
	local plate = C_NamePlate and Call(C_NamePlate.GetNamePlateForUnit, "target")
	local band, yards, size, y
	if plate and ns.PlateNameState then band, yards, size, y = Call(ns.PlateNameState, plate) end
	local plateScale = plate and Plain(Call(plate.GetEffectiveScale, plate))
	local walked = FromStart()
	run.shots[run.phase] = (run.shots[run.phase] or 0) + 1
	if run.phase == "ours" and type(size) == "number" then
		run.firstSize = run.firstSize or size
		run.lastSize = size
		run.sizesSeen = run.sizesSeen or {}
		run.sizesSeen[size] = true
	end
	Say(("  shot %s #%d %s: walked %s, target %s, zoom %.1f, our band %s yards %s size %s y %s, plate scale %s " ..
		"(UI %.2f), facing %s, %s"):format(run.phase, run.shots[run.phase], why,
		walked and ("%.1fyd"):format(walked) or "?", (TargetDistance()), Plain(Call(GetCameraZoom)) or -1,
		tostring(band), yards and ("%.1f"):format(yards) or "nil", tostring(size), tostring(y), tostring(plateScale),
		UIParent:GetEffectiveScale(), tostring(Plain(Call(GetPlayerFacing)) and ("%.2f"):format(GetPlayerFacing()) or "?"),
		ok and date("%m%d%y_%H%M%S") or ("failed: " .. tostring(err))))
	Say("    camera: " .. CameraLine())
end

local function Box(text, sub, r, g, b)
	ns.PadTestBox(text, sub, r or 1, g or 0.82, b or 0)
end

local function Phase(name)
	run.phase, run.phaseAt = name, GetTime()
	run.nextShot, run.lastShotAt, run.stillSince, run.near = 0, 0, nil, false
	run.uiStep, run.uiCleared = nil, nil
	Say(("--- %s ---"):format(name))
end

-- Cinematic paused and back, quietly (ns.suspendQuiet: a test line, no red
-- chat line or dev error window).
local function Pause(why)
	if ns.Suspend and not ns.IsSuspended() then
		ns.suspendQuiet = true
		ns.Suspend(why)
		ns.suspendQuiet = nil
		run.paused = true
	end
end
local function Resume()
	if run.paused and ns.Resume then
		ns.suspendQuiet = true
		ns.Resume()
		ns.suspendQuiet = nil
		run.paused = false
	end
end

local function PutScaleBack()
	if run.uiOld then
		for name, value in pairs(run.uiOld) do pcall(SetCVar, name, value) end
		run.uiOld = nil
		Say(("  UI scale put back: %.2f"):format(UIParent:GetEffectiveScale()))
	end
end

local function Finish(done)
	if run.ticker then run.ticker:Cancel() end
	ns.plateNameSteps, ns.plateNameSizeTest = nil, nil
	if ns.TestKit and ns.TestKit.HideButtons then ns.TestKit.HideButtons() end
	PutScaleBack()
	-- (Stopped mid step: Cinematic running and Shoulder Cam back first.)
	if run.paused then
		Resume()
		Say("  Cinematic started again")
	end
	if run.shoulderWas and ns.db then
		ns.db.shoulderCam = true
		if ns.ApplyShoulderCam then pcall(ns.ApplyShoulderCam) end
		run.shoulderWas = nil
		Say("  Shoulder Cam back on")
	end
	if run.full then
		Say(("verdict: game walk %d shots, ours %d shots, position %s"):format(run.shots.game or 0, run.shots.ours or 0,
			run.start and "read" or "unreadable (shots by time)"))
	end
	-- Ours stays one size the whole walk (zoom only, the user 2026-11-23:
	-- per-distance sizes popping every second were too much).
	if run.firstSize then
		local count = 0
		for _ in pairs(run.sizesSeen or {}) do count = count + 1 end
		Say(("verdict %s: our name kept one size walking in (%d size(s) seen, %.3f)"):format(
			count == 1 and "PASS" or "FAIL", count, run.firstSize))
	elseif run.phase ~= "setup" then
		Say("verdict FAIL: no size of ours read on the walk (no target plate, or not Name Style's)")
	end
	run = nil
	Box(done and "Name scale test done." or "Name scale test stopped.", "/reload, then say \"check log\"")
	C_Timer.After(15, function() if not run then ns.PadTestBoxHide() end end)
end

-- A walk: a shot at the start, every SHOT_YARDS (or SHOT_SECONDS walking),
-- one more on stopping by the NPC; done once stood still that near.
local function Walk(title)
	local name = UnitName("target") or "the NPC"
	if run.pending then
		local why = run.pending
		run.pending = nil
		Shot(why)
		return why == "end"
	end
	local walked = FromStart()
	if run.nextShot == 0 then
		run.pending = "start"
		run.nextShot, run.lastShotAt = SHOT_YARDS, GetTime()
	elseif walked and walked >= run.nextShot then
		run.pending = ""
		run.nextShot = run.nextShot + SHOT_YARDS
	elseif not walked and Moving() and GetTime() - run.lastShotAt >= SHOT_SECONDS then
		run.pending = ""
		run.lastShotAt = GetTime()
	end
	if Near() then run.near = true end
	if run.near and not Moving() then
		run.stillSince = run.stillSince or GetTime()
		if GetTime() - run.stillSince >= STILL then run.pending = "end" end
	else
		run.stillSince = nil
	end
	if run.pending then
		Clear()
		return false
	end
	Box(("%s: WALK slowly straight to %s and stop next to them. Don't zoom or turn the camera."):format(title, name),
		run.near and "Close enough: STOP" or "Walking...", 0.3, 1, 0.3)
	return false
end

-- Standing next to the NPC: the other UI scale, ours and the game's shot.
-- Each shot's tick clears the screen first, the next takes it.
local UI_STEPS = {
	{ at = 1, act = "scale" }, { at = 3, act = "shot", why = "ui ours other scale" },
	{ at = 4, act = "pause" }, { at = 6, act = "shot", why = "ui game other scale" },
	{ at = 7, act = "back" }, { at = 9, act = "shot", why = "ui game own scale" },
	{ at = 10, act = "resume" }, { at = 11, act = "shoulder off" }, { at = 14, act = "shot", why = "cam ours shoulder off" },
	{ at = 15, act = "pause" }, { at = 17, act = "shot", why = "cam game shoulder off" },
	{ at = 18, act = "shoulder on" }, { at = 19, act = "done" },
}

-- Shoulder Cam on or off, as its key does (Cinematic_ToggleShoulderCam).
local function SetShoulder(on)
	if not ns.db then return end
	ns.db.shoulderCam = on
	if ns.ApplyShoulderCam then pcall(ns.ApplyShoulderCam) end
	Say(("  Shoulder Cam %s: %s"):format(on and "on" or "off", CameraLine()))
end
-- Standing still: ours, then the game's, from the same spot and camera.
local FAR_PAIR = {
	{ at = 1, act = "shot", why = "far ours" }, { at = 2, act = "pause" }, { at = 4, act = "shot", why = "far game" },
	{ at = 5, act = "resume" }, { at = 7, act = "done" },
}
local NEAR_PAIR = {
	{ at = 1, act = "pause" }, { at = 3, act = "shot", why = "near game" }, { at = 4, act = "resume" },
	{ at = 5, act = "done" },
}

-- Runs a list of timed acts (into: seconds since its phase began); its
-- "done" calls onDone.
UiScaleStep = function(into, list, text, onDone)
	list = list or UI_STEPS
	local step = list[run.uiStep or 1]
	if not step then return end
	if into < step.at then
		Box(text or "HANDS OFF, stay next to the NPC: checking names at another UI scale.",
			("%d sec"):format(math.ceil(list[#list].at - into)))
		return
	end
	if step.act == "shot" and not run.uiCleared then
		if step.why:find("^cam") and not run.shoulderWas then
			run.uiStep = run.uiStep + 1 -- (Shoulder Cam was off: no shot)
			return
		end
		run.uiCleared = true
		Clear()
		return
	end
	run.uiCleared = nil
	run.uiStep = (run.uiStep or 1) + 1
	if step.act == "scale" then
		local was = UIParent:GetEffectiveScale()
		run.uiOld = { useUiScale = GetCVar("useUiScale"), uiScale = GetCVar("uiScale") }
		local other = was < 0.8 and "1" or "0.64"
		pcall(SetCVar, "useUiScale", "1")
		pcall(SetCVar, "uiScale", other)
		Say(("  UI scale %.2f -> %s: UIParent now %.2f"):format(was, other, UIParent:GetEffectiveScale()))
	elseif step.act == "shot" then
		Shot(step.why)
	elseif step.act == "pause" then
		Pause("name scale test, " .. (step.why or "pair"))
	elseif step.act == "back" then
		PutScaleBack()
	elseif step.act == "resume" then
		Resume()
	elseif step.act == "shoulder off" then
		if not (ns.db and ns.db.shoulderCam) then
			Say("  Shoulder Cam was off: its step skipped")
			run.uiStep = #list -- (on to done)
		else
			run.shoulderWas = true
			SetShoulder(false)
		end
	elseif step.act == "shoulder on" then
		Resume()
		if run.shoulderWas then
			SetShoulder(true)
			run.shoulderWas = nil
		end
	elseif step.act == "done" then
		if onDone then onDone() else Finish(true) end
	end
end

local function Tick()
	if not run then return end
	local now = GetTime()
	if run.phase == "setup" then
		local left = SETUP - (now - run.phaseAt)
		local target = UnitExists("target") and not UnitIsPlayer("target")
		if left > 0 or not target then
			Box(run.full and ("Out of combat, TARGET a friendly NPC about 40 yards STRAIGHT AHEAD, open ground between " ..
				"you. Set your zoom and leave it. Stand still.") or
				"Out of combat, TARGET a friendly NPC 10 to 20 yards ahead, its name on screen. Then stand still.",
				target and ("Starts in %d"):format(math.ceil(math.max(0, left))) or "Target an NPC to start")
			return
		end
		local x, y = Position()
		run.start = x and { x = x, y = y } or nil
		Say("  camera at start: " .. CameraLine())
		-- (The game's shots compare with ITS name over the head: a character whose
		-- settings show NPC plates instead drew a full target plate when paused,
		-- run 13, so those shots had no name to compare.)
		Say(("  game's own: UnitNameNPC %s, nameplateShowFriendlyNPCs %s, nameplateSelectedScale %s%s"):format(
			tostring(GetCVar("UnitNameNPC")), tostring(GetCVar("nameplateShowFriendlyNPCs")),
			tostring(GetCVar("nameplateSelectedScale")),
			GetCVar("UnitNameNPC") == "0" and " (NPC names over heads OFF: the game shots show a plate, not a name)" or ""))
		Say(("start: target %s, %s, position %s, zoom %.1f, Name Style %s, close %s/%s far %s/%s"):format(
			tostring(UnitName("target")), (TargetDistance()), run.start and ("%.1f,%.1f"):format(x, y) or "unreadable",
			Plain(Call(GetCameraZoom)) or -1, tostring(ns.db and ns.db.plateNameStyle),
			tostring(ns.db and ns.db.plateNameCloseSize), tostring(ns.db and ns.db.plateNameCloseY),
			tostring(ns.db and ns.db.plateNameFarSize), tostring(ns.db and ns.db.plateNameFarY)))
		Phase("far")
	elseif run.phase == "far" then
		UiScaleStep(now - run.phaseAt, FAR_PAIR, "HANDS OFF, stand still: ours and the game's name from here.", function()
			if not run.full then
				Say("walk 1, UI scale, Shoulder Cam: proven (runs 1-8), left out; \"full\" runs them")
				Phase("ours")
				return
			end
			Pause("name scale test, walk 1")
			Phase("game")
		end)
	elseif run.phase == "game" then
		if Walk("1/2 GAME'S NAMES (Cinematic paused)") then Phase("back") end
	elseif run.phase == "back" then
		local away = FromStart()
		local home
		if away then
			home = away <= HOME_YARDS
		else
			home = not Near() and Call(CheckInteractDistance, "target", 4) ~= true
		end
		if home and not Moving() then
			run.stillSince = run.stillSince or now
			if now - run.stillSince >= STILL then
				Resume()
				Phase("ours")
				return
			end
			Box("Back on the start spot. FACE the NPC as before and stand still.", "Starting walk 2...", 0.3, 1, 0.3)
		else
			run.stillSince = nil
			Box("Walk BACK to where you started, then face the NPC again (keep it targeted, same zoom).",
				away and ("%.1f yards from the start spot"):format(away) or "Past 28 yards from the NPC")
		end
	elseif run.phase == "ours" then
		if Walk(run.full and "2/2 CINEMATIC'S NAMES" or "CINEMATIC'S NAMES") then Phase("near") end
	elseif run.phase == "near" then
		UiScaleStep(now - run.phaseAt, NEAR_PAIR, "HANDS OFF, stay next to the NPC: the game's name from here.",
			function()
				if run.full then Phase("ui") else Finish(true) end
			end)
	elseif run.phase == "ui" then
		UiScaleStep(now - run.phaseAt)
	end
end

-- Typed again while running: stops.
function ns.NameScaleTest(arg)
	if run then
		Finish(false)
		return
	end
	if InCombatLockdown() then
		ns.Print("name scale test: out of combat please.")
		return
	end
	CinematicDB.nameScaleLog = {}
	run = { at = GetTime(), shots = {}, full = arg == "full" }
	Phase("setup")
	Say(("start: %s (game %s), Cinematic %s"):format(ns.isRetail and "retail" or "not retail",
		tostring((select(4, GetBuildInfo()))),
		tostring(C_AddOns and C_AddOns.GetAddOnMetadata and Call(C_AddOns.GetAddOnMetadata, "Cinematic", "Version"))))
	run.ticker = C_Timer.NewTicker(TICK, function()
		local ok, err = pcall(Tick)
		if not ok then
			Say("error: " .. tostring(err))
			if run then Finish(false) end
		end
	end)
	ns.Print("name scale test: follow the box (type it again to stop)")
end
