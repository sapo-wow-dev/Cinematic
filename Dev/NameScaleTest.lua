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

-- /cine debug namescale ruler (the user 2026-11-23: names "jump" a little
-- past 28 yards). No API reads an NPC's distance on Forever (engine rule
-- forever.unit.checkinteractdistance), so the ruler marks your own spot -
-- stand by the NPC - and shows, live, how far you've walked from it on a
-- 0-50 yard bar, the game's range band, the zoom, and what our name and the
-- game's plate do. Every change is listed with its yards (on screen, and
-- in CinematicDB.nameScaleLog with a screenshot, one a second at most), and
-- a line every 2 yards. Typed again, or Stop: ends. Mark here: marks again.
local RULER_MAX, RULER_W, RULER_EVERY = 50, 480, 2
local RULER_TICKS = { 10, 20, 28, 30, 40, 50 }
-- What's watched: key, its name in the list, the step a number is rounded to.
-- (Plate scale: Far names smaller's one step, Effects.lua FAR_NAME_CVARS,
-- 0.64 -> 0.416 past ~28 yd in the ledger's Q13. near: PlateParts' sight
-- check, asked only within 28 yd.)
local RULER_WATCH = {
	{ "band", "game's range" }, { "plate", "target plate" }, { "plateAlpha", "plate alpha", 0.1 },
	{ "plateScale", "plate scale", 0.01 }, { "near", "sight check near" },
	{ "ourShown", "our name shown" }, { "ourAlpha", "our name alpha", 0.1 },
	{ "size", "our size" }, { "y", "our height" },
	{ "gameShown", "game's name shown" }, { "gameAlpha", "game's name alpha", 0.1 },
}
local ruler -- { at, frame, ticker, mark, last, events, shotAt, lineAt, opts }

local function RulerSay(text)
	-- (Run by the name jump test, Dev/NameJumpTest.lua: into its log.)
	if ruler and ruler.opts.say then return ruler.opts.say(text) end
	local log = CinematicDB and CinematicDB.nameScaleLog
	if log then log[#log + 1] = ("%.1f %s"):format(ruler and GetTime() - ruler.at or 0, text) end
end

local function RulerYards()
	local x, y = Position()
	if not (x and ruler.mark) then return nil end
	return math.sqrt((x - ruler.mark.x) ^ 2 + (y - ruler.mark.y) ^ 2)
end

-- A unit's range band (Forever: no distance for NPCs; bands out of fights).
local function UnitBand(unit)
	for _, band in ipairs({ { 3, "<10yd" }, { 2, "<11yd" }, { 4, "<28yd" } }) do
		if Call(CheckInteractDistance, unit, band[1]) == true then return band[2] end
	end
	return ">28yd"
end

-- The NPC marked (its GUID) when it's no longer your target: its plate's
-- unit, found among the plates (a target's plate isn't shrunk by distance,
-- rule forever.plate.selected-no-distance-scale, so the test walks with it
-- untargeted).
local function MarkedUnit()
	local guid = ruler.guid
	if UnitExists("target") and (not guid or Plain(Call(UnitGUID, "target")) == guid) then return "target" end
	if not (guid and C_NamePlate and C_NamePlate.GetNamePlates) then return nil end
	for _, plate in ipairs(Call(C_NamePlate.GetNamePlates) or {}) do
		local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
		if unit and Plain(Call(UnitGUID, unit)) == guid then return unit, plate end
	end
	return nil
end

-- The marked NPC's state now: range band, zoom, its plate, ours and the game's name.
local function RulerState()
	local unit, plate = MarkedUnit()
	local s = { unit = unit, zoom = Plain(Call(GetCameraZoom)) }
	s.band = unit and UnitBand(unit) or (ruler.guid and "no plate" or "no target")
	plate = plate or (unit and C_NamePlate and Call(C_NamePlate.GetNamePlateForUnit, unit))
	s.plate = plate and true or false
	if plate then
		s.plateAlpha = Plain(Call(plate.GetAlpha, plate))
		s.plateScale = Plain(Call(plate.GetEffectiveScale, plate))
		s.near = ns.plateSightNear and ns.plateSightNear.is[plate]
		-- (GetAlpha, not GetEffectiveAlpha: that read nothing on these texts,
		-- namejump run 14 and DescribePlateSight.)
		local game = plate.UnitFrame and plate.UnitFrame.name
		if type(game) == "table" then
			s.gameShown = Call(game.IsVisible, game) and true or false
			s.gameAlpha = Plain(Call(game.GetAlpha, game))
		end
		if ns.PlateNameState then
			local _, _, size, y, text = Call(ns.PlateNameState, plate)
			if type(text) == "table" then
				s.ourShown = Call(text.IsVisible, text) and true or false
				s.ourAlpha = Plain(Call(text.GetAlpha, text))
				s.size, s.y = size, y
			end
		end
	end
	return s
end

local function RulerValue(s, watch)
	if type(watch) == "string" then
		for _, each in ipairs(RULER_WATCH) do if each[1] == watch then watch = each end end
	end
	local value = s[watch[1]]
	if watch[3] and type(value) == "number" then return math.floor(value / watch[3] + 0.5) * watch[3] end
	return value
end

local function RulerText(value)
	if value == nil then return "-" end
	return tostring(value)
end

local RulerStop -- (below)

local function RulerFrame()
	if ruler.frame then return ruler.frame end
	local f = CreateFrame("Frame", nil, UIParent)
	f:SetSize(RULER_W + 40, 210)
	-- (Low on the screen: the test box sits at the top.)
	f:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 200)
	f:SetFrameStrata("DIALOG")
	local back = f:CreateTexture(nil, "BACKGROUND")
	back:SetAllPoints()
	back:SetColorTexture(0, 0, 0, 0.7)
	f.big = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
	f.big:SetPoint("TOP", 0, -10)
	-- The bar: 0 to RULER_MAX yards, ticks (28 in red), a fill and a marker.
	local bar = CreateFrame("Frame", nil, f)
	bar:SetSize(RULER_W, 16)
	bar:SetPoint("TOP", 0, -46)
	local track = bar:CreateTexture(nil, "BACKGROUND")
	track:SetAllPoints()
	track:SetColorTexture(0.2, 0.2, 0.2, 1)
	f.fill = bar:CreateTexture(nil, "ARTWORK")
	f.fill:SetPoint("TOPLEFT")
	f.fill:SetPoint("BOTTOMLEFT")
	f.fill:SetWidth(1)
	for _, yards in ipairs(RULER_TICKS) do
		local x = yards / RULER_MAX * RULER_W
		local tick = bar:CreateTexture(nil, "OVERLAY")
		tick:SetSize(yards == 28 and 3 or 1, 24)
		tick:SetPoint("CENTER", bar, "LEFT", x, 0)
		if yards == 28 then tick:SetColorTexture(1, 0.2, 0.2, 1) else tick:SetColorTexture(1, 1, 1, 0.6) end
		local label = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		label:SetPoint("TOP", bar, "BOTTOMLEFT", x, -6)
		label:SetText(yards)
	end
	f.marker = bar:CreateTexture(nil, "OVERLAY")
	f.marker:SetSize(4, 28)
	f.marker:SetColorTexture(1, 1, 1, 1)
	f.info = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	f.info:SetPoint("TOP", 0, -84)
	f.ours = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	f.ours:SetPoint("TOP", 0, -102)
	f.events = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.events:SetPoint("TOP", 0, -124)
	f.events:SetJustifyH("LEFT")
	f.events:SetWidth(RULER_W)
	local stop = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	stop:SetSize(80, 22)
	stop:SetPoint("BOTTOMRIGHT", -8, 8)
	stop:SetText("Stop")
	stop:SetScript("OnClick", function() RulerStop() end)
	local mark = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	mark:SetSize(100, 22)
	mark:SetPoint("RIGHT", stop, "LEFT", -6, 0)
	mark:SetText("Mark here")
	mark:SetScript("OnClick", function() ns.NameRulerMark() end)
	f.stop, f.markButton = stop, mark
	-- (In the test the kit's own buttons stop it.)
	if ruler.opts.test then stop:Hide() mark:Hide() end
	ruler.frame = f
	return f
end

function ns.NameRulerMark()
	if not ruler then return end
	local x, y = Position()
	ruler.mark = x and { x = x, y = y } or nil
	ruler.guid = UnitExists("target") and Plain(Call(UnitGUID, "target")) or nil
	ruler.events, ruler.lineAt = {}, nil
	RulerSay(("mark: %s, target %s, %s"):format(ruler.mark and ("%.1f,%.1f"):format(x, y) or "position unreadable",
		tostring(UnitName("target")), UnitExists("target") and (TargetDistance()) or "no target"))
end

local function RulerTick()
	if not ruler then return end
	local f = RulerFrame()
	local yards, s = RulerYards(), RulerState()
	-- Changes, each with its yards.
	for _, watch in ipairs(RULER_WATCH) do
		local value = RulerValue(s, watch)
		local was = ruler.last[watch[1]]
		if ruler.started and was ~= value then
			local line = ("%s: %s %s -> %s"):format(yards and ("%.1f yd"):format(yards) or "?? yd", watch[2],
				RulerText(was), RulerText(value))
			table.insert(ruler.events, 1, line)
			ruler.events[6] = nil
			RulerSay("  " .. line)
			if ruler.opts.onChange then ruler.opts.onChange(watch[1], was, value, yards, line) end
			if GetTime() - (ruler.shotAt or -99) >= 1 then
				ruler.shotAt = GetTime()
				pcall(Screenshot)
			end
		end
		ruler.last[watch[1]] = value
	end
	ruler.started = true
	-- A line every RULER_EVERY yards.
	if yards then
		local step = math.floor(yards / RULER_EVERY)
		if step ~= ruler.lineAt then
			ruler.lineAt = step
			RulerSay(("  %.1f yd: range %s, zoom %s, plate %s alpha %s scale %s near %s, ours shown %s alpha %s size %s y %s, "
				.. "game's shown %s alpha %s"):format(yards, s.band, RulerText(s.zoom and ("%.1f"):format(s.zoom)),
				RulerText(s.plate), RulerText(RulerValue(s, "plateAlpha")), RulerText(RulerValue(s, "plateScale")),
				RulerText(s.near), RulerText(s.ourShown), RulerText(RulerValue(s, "ourAlpha")),
				RulerText(s.size), RulerText(s.y), RulerText(s.gameShown), RulerText(RulerValue(s, "gameAlpha"))))
		end
	end
	-- The screen.
	if yards then
		f.big:SetText(("%.1f yd from the mark"):format(yards))
	else
		f.big:SetText("Your position can't be read here")
	end
	local shown = math.min(yards or 0, RULER_MAX)
	local x = shown / RULER_MAX * RULER_W
	f.fill:SetWidth(math.max(1, x))
	if shown < 28 then f.fill:SetColorTexture(0.2, 0.8, 0.2, 0.8)
	elseif shown < 35 then f.fill:SetColorTexture(1, 0.6, 0.1, 0.8)
	else f.fill:SetColorTexture(0.9, 0.2, 0.2, 0.8) end
	f.marker:ClearAllPoints()
	f.marker:SetPoint("CENTER", f.fill:GetParent(), "LEFT", x, 0)
	f.info:SetText(("%s: game says %s   zoom %s"):format(s.unit and UnitName(s.unit) or "no target", s.band,
		s.zoom and ("%.1f"):format(s.zoom) or "?"))
	f.ours:SetText(not s.plate and "No plate on the target" or
		("Ours: %s alpha %s size %s y %s   Game's: %s alpha %s   Plate alpha %s scale %s"):format(
		s.ourShown and "shown" or "hidden", RulerText(RulerValue(s, "ourAlpha")), RulerText(s.size), RulerText(s.y),
		s.gameShown and "shown" or "hidden", RulerText(RulerValue(s, "gameAlpha")), RulerText(RulerValue(s, "plateAlpha")),
		RulerText(RulerValue(s, "plateScale"))))
	f.events:SetText(#ruler.events > 0 and table.concat(ruler.events, "\n") or
		"Stand by the NPC, target it, Mark here. Walk BACKWARD (S) so you keep watching its name.")
end

RulerStop = function()
	if not ruler then return end
	if ruler.ticker then ruler.ticker:Cancel() end
	if ruler.frame then ruler.frame:Hide() end
	RulerSay("ruler stopped")
	local test = ruler.opts.test
	ruler = nil
	if not test then ns.Print("name ruler stopped: /reload, then say \"check log\"") end
end

-- Typed again while running: stops. opts (the name jump test): test = true
-- (no Stop / Mark buttons, no chat lines), say = fn(text) for its log,
-- onChange = fn(key, was, now, yards, line).
function ns.NameRuler(opts)
	if ruler then
		RulerStop()
		if not opts then return end
	end
	opts = opts or {}
	if not opts.say then CinematicDB.nameScaleLog = {} end
	ruler = { at = GetTime(), last = {}, events = {}, opts = opts }
	RulerSay(("ruler: %s (game %s), Name Style %s, close %s/%s far %s/%s"):format(ns.isRetail and "retail" or "not retail",
		tostring((select(4, GetBuildInfo()))), tostring(ns.db and ns.db.plateNameStyle),
		tostring(ns.db and ns.db.plateNameCloseSize), tostring(ns.db and ns.db.plateNameCloseY),
		tostring(ns.db and ns.db.plateNameFarSize), tostring(ns.db and ns.db.plateNameFarY)))
	ns.NameRulerMark()
	RulerFrame():Show()
	ruler.ticker = C_Timer.NewTicker(TICK, function()
		local ok, err = pcall(RulerTick)
		if not ok then
			RulerSay("error: " .. tostring(err))
			RulerStop()
		end
	end)
	RulerTick()
	if not opts.test then ns.Print("name ruler: your spot is marked (type it again, or Stop, to end)") end
end

-- For the name jump test: yards from the mark now (nil: unreadable), stop.
function ns.NameRulerYards() return ruler and RulerYards() end
function ns.NameRulerUnit() if ruler then return MarkedUnit() end end
function ns.NameRulerState() if ruler then return RulerState() end end
function ns.NameRulerStop() if ruler then RulerStop() end end

-- Typed again while running: stops.
function ns.NameScaleTest(arg)
	if arg == "ruler" then return ns.NameRuler() end
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

-- /cine debug namejump (a kit test, here so no new file needs a restart):
-- what makes NPC names over heads "jump" a little past 28 yards (the user,
-- 2026-11-23, Forever, CineMode). The ruler above marks your spot by the NPC
-- and measures from it; every change to the target's plate, our name and the
-- game's is logged with its yards, with a screenshot (the ruler on screen
-- says the yards). Steps:
--   1 setup  CineMode on; stand next to a friendly NPC at your usual zoom,
--            target it, still: the spot and the NPC marked; then Escape
--            (untargeted: run 14 found the target's plate never shrinks,
--            rule forever.plate.selected-no-distance-scale), its plate
--            found again by its GUID (PASS: position reads, plate found)
--   2 away   walk BACKWARD (S) to 46 yards, Far names smaller as Cinematic
--            has it (Effects.lua FAR_NAME_CVARS: one plate shrink step at
--            ~41 yards from the camera, so ~41 - zoom from you)
--   3 back   Far names smaller OFF (ns.farNamesTestOff), walk FORWARD (W)
--            back to the NPC: A/B, the same line crossed without it
--   4 result what changed from 24 yards out each walk (the range band and
--            sight check flip at ~30 both ways: not counted as a jump),
--            our size held (zoom only), and which walk you saw it in
-- Put back at the end or a stop: Far names smaller as it was. Into
-- CinematicDB.nameJumpTestLog.
local WALK_TO, BACK_TO = 46, 6 -- yards from the mark
local JUMP_LOW, JUMP_HIGH = 24, 46 -- "a little after 28" at the user's zoom, out past the shrink at zoom 0
local NOT_A_JUMP = { band = true, near = true } -- (nothing on screen: run 14)

local function JumpZoom()
	local zoom = Plain(Call(GetCameraZoom))
	if type(zoom) == "number" then return math.floor(zoom * 10 + 0.5) / 10 end
end

local function FarSet()
	return ns.plates and ns.plates.FAR_NAME_CVARS
end

-- Far names smaller's settings as they are now, for the log.
local function FarLine()
	local set = FarSet()
	local parts = { "Far names smaller " .. (set and (set.active and "ON" or "off") or "missing") }
	for _, name in ipairs({ "nameplateMinScale", "nameplateMaxScale", "nameplateMinScaleDistance",
		"nameplateMaxScaleDistance", "nameplateMaxDistance" }) do
		parts[#parts + 1] = name .. "=" .. tostring(GetCVar(name))
	end
	return table.concat(parts, " ")
end

-- The changes a walk logged between JUMP_LOW and JUMP_HIGH yards.
local function InWindow(changes, key)
	local found = {}
	for _, change in ipairs(changes or {}) do
		if (key and change.key == key or not key and not NOT_A_JUMP[change.key]) and change.yards and change.yards >= JUMP_LOW and change.yards <= JUMP_HIGH then
			found[#found + 1] = change
		end
	end
	return found
end

local function Lines(list)
	local lines = {}
	for _, change in ipairs(list) do lines[#lines + 1] = change.line end
	return #lines > 0 and table.concat(lines, "; ") or "none"
end

if ns.TestKit then ns.TestKit.Define({
	name = "namejump",
	key = "nameJumpTest",
	title = "Name jump past 28 yards",
	about = "what makes names over heads jump a little past 28 yards: a walk away and back, Far names smaller on then off",
	needs = "CineMode on, out of combat, by a friendly NPC with ~40 yards of open ground behind you",
	cineMode = true,
	cvars = { "nameplateMinScale", "nameplateMaxScale", "nameplateMinScaleDistance", "nameplateMaxScaleDistance",
		"nameplateMaxDistance", "nameplateOccludedAlphaMult", "nameplateSelectedScale", "UnitNameNPC" },
	context = function()
		return ("%s, Name Style %s, close %s/%s far %s/%s, hide delay %s"):format(FarLine(),
			tostring(ns.db.plateNameStyle), tostring(ns.db.plateNameCloseSize), tostring(ns.db.plateNameCloseY),
			tostring(ns.db.plateNameFarSize), tostring(ns.db.plateNameFarY), tostring(ns.db.plateNameHideDelay))
	end,
	putBack = function(extra)
		ns.NameRulerStop()
		local was = ns.farNamesTestOff
		ns.farNamesTestOff = nil
		local set = FarSet()
		if was and set and extra.farWas ~= nil then
			ns.ApplyCVarSet(set, extra.farWas == true)
			return "Far names smaller back " .. (extra.farWas == true and "on" or "off")
		end
		return "Far names smaller untouched"
	end,
	steps = {
		{ key = "setup", title = "by the NPC, spot marked", run = function(r)
			r.jump = { changes = { A = {}, B = {} } }
			if not ns.IsCineModeOn() then
				r:WaitFor("Turn CineMode ON (the names over heads are CineMode's).", {
					check = function() return ns.IsCineModeOn() end,
					buttons = { { label = "Turn CineMode on", fn = function()
						if not ns.IsCineModeOn() then Cinematic_ToggleCineMode() end
					end } } })
			end
			-- What it's still waiting for: on the box and, on each change, in the
			-- log (run 16: "does not recognize when i filled out its
			-- requirements", and the log couldn't say which one was missing).
			-- Within 11 yards counts (CheckInteractDistance 2 or 3).
			local still, lastWhy
			local function Missing()
				if InCombatLockdown() then return "out of combat" end
				if not UnitExists("target") then return "a target" end
				if UnitIsPlayer("target") then return "an NPC as your target, not a player" end
				if not (Near() or Call(CheckInteractDistance, "target", 2) == true) then
					return ("closer to %s: within 10 yards (the game says %s)"):format(UnitName("target") or "it",
						(TargetDistance()))
				end
				if Moving() then return "standing still" end
			end
			-- Its name must show untargeted (a target's plate never shrinks: run
			-- 14). Run 17's Steven Black showed ours only while targeted (your
			-- rows), so the walk had nothing to watch: asked again, 3 tries.
			local npc, unit, state
			for try = 1, 3 do
				still, lastWhy = nil, nil
				npc = r:WaitFor((try == 1 and "" or "That NPC's name doesn't show untargeted. Pick ANOTHER one. ")
					.. "Stand RIGHT NEXT to a friendly NPC whose name shows over its head WITHOUT targeting it "
					.. "(a vendor or trainer), with about 50 yards of open ground behind you. Target it, face it, "
					.. "zoom to your USUAL zoom (not all the way in), and stand still.", { check = function()
					local why = Missing()
					if why ~= lastWhy then
						lastWhy = why
						r:Log("  waiting for: " .. tostring(why or "nothing: 2 seconds still"))
						local box = ns.padTestBox
						if box and box.sub then box.sub:SetText(why and ("Waiting for: " .. why) or "Got it: hold still...") end
					end
					if why then
						still = nil
						return false
					end
					still = still or GetTime()
					return GetTime() - still >= 2 and (UnitName("target") or "the NPC")
				end })
				r.jump.npc, r.jump.zoom = npc, JumpZoom()
				r:Log(("try %d: by %s, zoom %s, %s"):format(try, tostring(npc), tostring(r.jump.zoom), FarLine()))
				ns.NameRuler({ test = true, say = function(text) r:Log(text) end,
					onChange = function(key, was, now, yards, line)
						local list = r.jump.walk and r.jump.changes[r.jump.walk]
						if list then
							list[#list + 1] = { key = key, was = was, now = now, yards = yards, line = line, zoom = JumpZoom() }
						end
					end })
				r:WaitFor(("Press ESCAPE to clear your target (%s stays marked)."):format(tostring(npc)),
					{ check = function() return not UnitExists("target") and "cleared" end })
				r:Sleep(1) -- (the plate settles: our name hides a beat after, run 17)
				unit = ns.NameRulerUnit()
				state = ns.NameRulerState()
				if unit and state and state.ourShown then break end
				r:Log(("try %d: %s's name not shown untargeted (plate %s, ours shown %s)"):format(try, tostring(npc),
					tostring(unit), tostring(state and state.ourShown)))
				ns.NameRulerStop()
			end
			r:Verdict(ns.NameRulerYards() ~= nil, "your position reads: the ruler can measure from here")
			r:Verdict(unit ~= nil and unit ~= "target" and state and state.ourShown == true,
				"the NPC's plate found again by its GUID, untargeted, its name showing: " .. tostring(unit))
			r:Log(("the shrink expected ~%.0f yd from you (41 from the camera, zoom %s)"):format(
				41 - (r.jump.zoom or 0), tostring(r.jump.zoom)))
		end },
		{ key = "away", title = "walk away, Far names smaller as it is", run = function(r)
			if not (r.jump and ns.NameRulerYards()) then return r:Skip("no mark (step 1 didn't mark a spot)") end
			r.jump.walk = "A"
			r:Log("walk 1: " .. FarLine())
			r:WaitFor(("Walk BACKWARD (hold S) straight away from %s, watching its name. Don't turn or zoom. "
				.. "Stop when this box says so (%d yards)."):format(r.jump.npc, WALK_TO), { check = function()
					local yards = ns.NameRulerYards()
					return yards and yards >= WALK_TO and "far enough"
				end })
			r.jump.walk = nil
			r:Prompt("STOP and stand still.", nil, 2)
			r:Sleep(2)
			r:Log(("walk 1 done at %.1f yd: %d changes"):format(ns.NameRulerYards() or -1, #r.jump.changes.A))
		end },
		{ key = "back", title = "walk back, Far names smaller off", run = function(r)
			if not (r.jump and ns.NameRulerYards()) then return r:Skip("no mark (step 1 didn't mark a spot)") end
			local set = FarSet()
			r:Keep("farWas", set and set.active or false)
			ns.farNamesTestOff = true
			if set then ns.ApplyCVarSet(set, false) end
			r:Sleep(1)
			r:Log("walk 2: " .. FarLine())
			r.jump.walk = "B"
			r:WaitFor(("Far names smaller is OFF now. Walk FORWARD (hold W) back to %s, watching its name. Don't turn "
				.. "or zoom. Stop when this box says so."):format(r.jump.npc), { check = function()
					local yards = ns.NameRulerYards()
					return yards and yards <= BACK_TO and "back"
				end })
			r.jump.walk = nil
			r:Log(("walk 2 done at %.1f yd: %d changes"):format(ns.NameRulerYards() or -1, #r.jump.changes.B))
		end },
		{ key = "result", title = "what jumped", run = function(r)
			if not r.jump then return r:Skip("no walks") end
			local A, B = r.jump.changes.A, r.jump.changes.B
			r:Log(("walk 1 (Far names smaller as it was), %d-%d yd: %s"):format(JUMP_LOW, JUMP_HIGH, Lines(InWindow(A))))
			r:Log(("walk 2 (Far names smaller off), %d-%d yd: %s"):format(JUMP_LOW, JUMP_HIGH, Lines(InWindow(B))))
			-- Our size follows the zoom only (the user's rule): a size change at
			-- the starting zoom is a resize while walking.
			local resized = {}
			for _, list in ipairs({ A, B }) do
				for _, change in ipairs(list) do
					-- (A plate coming back (nil to a value) or float noise isn't a
					-- resize: run 15's 0.83333366 -> 0.83333335.)
					if (change.key == "size" or change.key == "y") and change.zoom == r.jump.zoom
						and type(change.was) == "number" and type(change.now) == "number"
						and math.abs(change.now - change.was) > 0.005 then
						resized[#resized + 1] = change
					end
				end
			end
			r:Verdict(#resized == 0, "our size and height held while walking (zoom only): " .. Lines(resized))
			r:Verdict(#InWindow(A) > 0, ("walk 1 caught a change on screen between %d and %d yards (not the range "
				.. "band or sight check)"):format(JUMP_LOW, JUMP_HIGH))
			-- (Steps only: a plate going or coming back (nil) isn't one, and past
			-- nameplateMaxDistance 45 every plate fades and shrinks away, the
			-- game's, both walks: run 15.)
			local function Steps(list)
				local steps = {}
				for _, change in ipairs(list) do
					if type(change.was) == "number" and type(change.now) == "number" and change.now < change.was
						and change.yards < 44 then
						steps[#steps + 1] = change
					end
				end
				return steps
			end
			local scaleA, scaleB = Steps(InWindow(A, "plateScale")), Steps(InWindow(B, "plateScale"))
			local ourA = InWindow(A, "ourAlpha")
			for _, change in ipairs(InWindow(A, "ourShown")) do ourA[#ourA + 1] = change end
			local cause
			if #scaleA > 0 and #scaleB == 0 then
				cause = "Far names smaller's plate shrink (" .. Lines(scaleA) .. "): gone with it off"
			elseif #ourA > 0 then
				cause = "our name fading or hiding (" .. Lines(ourA) .. "), sight check: " .. Lines(InWindow(A, "near"))
			elseif #scaleA > 0 then
				cause = "a plate scale step with Far names smaller on AND off: the game's own (" .. Lines(scaleA) .. ")"
			else
				cause = "nothing the ruler watches: see the shots"
			end
			r:Log("cause by the log: " .. cause)
			local _, answer = r:WaitFor("Which walk had the jump you see past 28 yards?", {
				buttons = { "Walk 1 (away)", "Walk 2 (back)", "Both", "Neither" } })
			r:Log("you saw the jump in: " .. tostring(answer))
		end },
	},
}) end

-- /cine debug namesize: the Name Style page's Size choices (2026-11-23, the
-- user's A/B: Size by Zoom / Fixed, Far names Same size / A bit smaller /
-- Smaller / Much smaller), WoW Forever. Nothing to do. Steps:
--   1 page    the page open on its Size tab, switch on: the six choices
--             shown, inside the view, nothing over them, no off card; a shot
--   2 tabs    the Look tab: the choices out of sight; the Size tab: shown;
--             a shot of each (the page in tabs since 2026-11-23)
--   3 off     the page's switch off: the choices greyed; a screenshot
--   4 picks   each choice clicked: its setting saved, Far names smaller's
--             min scale follows at once (and in CineMode the game's
--             nameplateMinScale: Same size lets it go); Fixed keeps one size
--             at any zoom
-- Settings put back after. Into CinematicDB.nameSizeTestLog.
local SIZE_PAGE = "Name Style"

local function SizeChoices(r)
	ns.OpenOptions(SIZE_PAGE)
	r:Sleep(0.8)
	-- (On the page's Size tab since 2026-11-23.)
	if ns.nameStylePickTab then
		ns.nameStylePickTab(2)
		r:Sleep(0.3)
	end
	-- (Drawn again as the settings are now: an r:Set doesn't, and run 1 saw
	-- nothing greyed with the switch just turned off.)
	if ns.lowHealthKit and ns.lowHealthKit.Refresh then ns.lowHealthKit.Refresh() end
	r:Sleep(0.2)
	return ns.nameSizeChoices or {}
end

local function SizeInView(frame)
	local panel = SettingsPanel or UIParent
	local l, rt = frame:GetLeft(), frame:GetRight()
	local pl, pr = panel:GetLeft(), panel:GetRight()
	for _, n in ipairs({ l, rt, pl, pr }) do
		if type(n) ~= "number" then return false end
	end
	return l >= pl and rt <= pr
end

local function SizeScrollTo(frame)
	local scroll = frame:GetParent()
	while scroll and not scroll.SetVerticalScroll do scroll = scroll:GetParent() end
	local content = scroll and scroll.GetScrollChild and scroll:GetScrollChild()
	local top, frameTop = content and content:GetTop(), frame:GetTop()
	if not (top and frameTop) then return end
	local range = scroll:GetVerticalScrollRange() or 0
	scroll:SetVerticalScroll(math.max(0, math.min(range, top - frameTop - 120)))
end

if ns.TestKit and not ns.isRetail then ns.TestKit.Define({
	name = "namesize",
	key = "nameSizeTest",
	title = "Name size choices",
	about = "the Name Style page's Size by and Far names choices: on the page, greyed when off, each one working",
	cineMode = true,
	settings = { "plateNameStyle", "plateNameSizeBy", "plateNameFarStep" },
	cvars = { "nameplateMinScale", "nameplateMaxScaleDistance", "nameplateMinScaleDistance" },
	context = function()
		local set = ns.plates and ns.plates.FAR_NAME_CVARS
		return ("Size by %s, Far names %s, set held %s at %s, CineMode %s"):format(tostring(ns.db.plateNameSizeBy),
			tostring(ns.db.plateNameFarStep), tostring(set and set.active), tostring(set and set.values.nameplateMinScale),
			tostring(ns.IsCineModeOn()))
	end,
	steps = {
		{ key = "page", title = "the choices on the page", run = function(r)
			r:Set("plateNameStyle", true)
			local choices = SizeChoices(r)
			r:Verdict(#choices == 6, ("six choices made (%d)"):format(#choices))
			if #choices == 0 then return end
			SizeScrollTo(choices[1])
			r:Sleep(0.4)
			r:Verdict(ns.PageOffCardWanted(SIZE_PAGE) == false, "no off card over the page")
			local shown, inside, clear = 0, 0, 0
			for i, choice in ipairs(choices) do
				if choice:IsVisible() then shown = shown + 1 end
				if SizeInView(choice) then inside = inside + 1
				else r:Log(("choice %d (%s) runs out of the view"):format(i, tostring(choice.value))) end
				local hits = r:Overlaps(choice, SettingsPanel or UIParent)
				if #hits == 0 then clear = clear + 1
				else r:Log(("choice %d (%s) overlaps: %s"):format(i, tostring(choice.value), table.concat(hits, ", "))) end
			end
			local where = ("%d shown, %d inside the view, %d with nothing over them, of %d"):format(shown, inside, clear,
				#choices)
			-- (Offline the stand-in has no layout: every frame at one spot.)
			if ns.noRealLayout then r:Log("no layout offline: " .. where)
			else r:Verdict(shown == #choices and inside == #choices and clear == #choices, where) end
			r:Shot("Size choices on the Name Style page", { behind = SettingsPanel })
		end },
		{ key = "tabs", title = "the Look and Size tabs", run = function(r)
			-- (The page in tabs since 2026-11-23: Look has all it had, Size the
			-- choices; each tab shows only its own.)
			local choices = SizeChoices(r)
			if not ns.nameStylePickTab or #choices == 0 then return r:Fail("no tabs or no choices on the page") end
			ns.nameStylePickTab(1)
			r:Sleep(0.5)
			local hidden = 0
			for _, choice in ipairs(choices) do if not choice:IsVisible() then hidden = hidden + 1 end end
			local where = ("Look tab: the Size choices out of sight (%d of %d)"):format(hidden, #choices)
			-- (Offline a frame's IsVisible doesn't follow its parent's.)
			if ns.noRealLayout then r:Log("offline: " .. where) else r:Verdict(hidden == #choices, where) end
			r:Shot("Name Style, Look tab", { behind = SettingsPanel })
			ns.nameStylePickTab(2)
			r:Sleep(0.5)
			local shown = 0
			for _, choice in ipairs(choices) do if choice:IsVisible() then shown = shown + 1 end end
			r:Verdict(shown == #choices, ("Size tab: the choices shown (%d of %d)"):format(shown, #choices))
			r:Shot("Name Style, Size tab", { behind = SettingsPanel })
		end },
		{ key = "off", title = "greyed with the page off", run = function(r)
			r:Set("plateNameStyle", false)
			local choices = SizeChoices(r)
			if #choices == 0 then return r:Skip("no choices made") end
			local grey = 0
			for _, choice in ipairs(choices) do
				if choice.IsEnabled and not choice:IsEnabled() then grey = grey + 1 end
			end
			if ns.noRealLayout then r:Log(("no greying offline: %d of %d"):format(grey, #choices))
			else r:Verdict(grey == #choices, ("greyed with the page off: %d of %d"):format(grey, #choices)) end
			SizeScrollTo(choices[1])
			r:Shot("Size choices, page off", { behind = SettingsPanel })
			r:Set("plateNameStyle", true)
		end },
		{ key = "picks", title = "each choice works", run = function(r)
			-- (Yours saved for the put back first: the clicks save through the
			-- page, not r:Set, and nothing would have been kept.)
			r:Set("plateNameSizeBy", ns.db.plateNameSizeBy)
			r:Set("plateNameFarStep", ns.db.plateNameFarStep)
			local choices = SizeChoices(r)
			if #choices == 0 then return r:Skip("no choices made") end
			local set = ns.plates.FAR_NAME_CVARS
			local cine = ns.IsCineModeOn()
			for _, choice in ipairs(choices) do
				local value = choice.value
				-- (Its click script, as a click runs it: the stand-in's Click does nothing.)
				local click = choice:GetScript("OnClick")
				if click then click(choice, "LeftButton") else choice:Click() end
				r:Sleep(0.5)
				if type(value) == "number" then
					-- (Since 2026-11-23 Far names is our own step (from you): the
					-- game's plates stay held one size whatever it says, min = 1.)
					local held, cvar = set.active, GetCVar("nameplateMinScale")
					local okSaved = ns.db.plateNameFarStep == value and ns.plates.FarStep() == value
					local okGame = not held or tonumber(cvar) == 1
					r:Verdict(okSaved and okGame, ("Far names %s: saved %s, our step %s, plates held one size %s (game's %s)")
						:format(tostring(value), tostring(ns.db.plateNameFarStep), tostring(ns.plates.FarStep()), tostring(held),
						tostring(cvar)))
				else
					local near = ns.PlateNameSizeAt and ns.PlateNameSizeAt()
					r:Verdict(ns.db.plateNameSizeBy == value, ("Size by %s saved (a name's size now %s)"):format(
						tostring(value), tostring(near)))
				end
			end
			if not cine then r:Log("CineMode was off: the game's nameplateMinScale not checked (Far names smaller is CineMode's)") end
		end },
	},
}) end

-- /cine debug zoomstep: proof that Far names smaller's step hangs on the
-- camera, not on where you stand (the user, 2026-11-23: "i dont believe
-- that distance between you and an npc is based off of your location and
-- zoom"). You stand still 28-40 yards from an NPC; the test zooms the camera
-- all the way in, then out a yard at a time to all the way out, logging at
-- each zoom where you are (you never move), the NPC's plate scale and our
-- name's size. Steps:
--   1 setup   CineMode on; an NPC whose name shows untargeted, past 28
--             yards (the game's range band) and under ~40; you still
--   2 step    Far names Much smaller (0.65, the clearest): the sweep; PASS
--             when you never moved and zooming changed neither the plate's
--             scale nor our name's size (run 1, before 2026-11-23's change,
--             proved the old way: the game's step came by zoom alone; Far
--             names is our own step from you now); a shot
--   3 control Far names Same size: the same sweep; PASS when nothing stepped
-- Your zoom, Far names and Size by put back after. Into CinematicDB.zoomStepTestLog.
local SWEEP_WAIT = 0.8 -- (the camera glides ~0.5 s to a new zoom: rule forever.zoom.getcamerazoom-is-end)

local function ZoomBy(yards)
	local zoom = ns.GAME_ZOOM or {}
	local out, into = zoom.CameraZoomOut or CameraZoomOut, zoom.CameraZoomIn or CameraZoomIn
	if yards > 0 then out(yards) elseif yards < 0 then into(-yards) end
end

-- One sweep: all the way in, then out a yard a step till the zoom stops
-- growing. Each step: { zoom, moved, scale, size, shown }.
local function Sweep(r, label)
	local sx, sy = Position()
	local function Moved()
		local x, y = Position()
		if not (x and sx) then return nil end
		return math.sqrt((x - sx) ^ 2 + (y - sy) ^ 2)
	end
	ZoomBy(-50)
	r:Sleep(1.2)
	local rows, last = {}, -1
	for _ = 1, 60 do
		local zoom = Plain(Call(GetCameraZoom)) or -1
		local state = ns.NameRulerState() or {}
		local row = { zoom = zoom, moved = Moved(), scale = state.plateScale, size = state.size, shown = state.ourShown }
		rows[#rows + 1] = row
		r:Log(("  %s: zoom %.1f, moved %s, plate scale %s, our size %s, shown %s"):format(label, zoom,
			row.moved and ("%.2f yd"):format(row.moved) or "?", tostring(row.scale), tostring(row.size), tostring(row.shown)))
		if zoom <= last + 0.1 then break end
		last = zoom
		ZoomBy(1)
		r:Sleep(SWEEP_WAIT)
	end
	return rows
end

-- The sweep's steps in plate scale (a change of more than 3%).
local function ScaleSteps(rows)
	local steps = {}
	for i = 2, #rows do
		local a, b = rows[i - 1].scale, rows[i].scale
		-- (Only between real sizes: a plate shrinking away at its draw limit
		-- (to ~0.01, namejump run 15) isn't the far step, and would show in
		-- the control sweep too.)
		if type(a) == "number" and type(b) == "number" and a >= 0.3 and b >= 0.3 and math.abs(b - a) > a * 0.03 then
			steps[#steps + 1] = { from = a, to = b, atZoom = rows[i].zoom, before = rows[i - 1].zoom }
		end
	end
	return steps
end

local function MostMoved(rows)
	local most, known = 0, 0
	for _, row in ipairs(rows) do
		if row.moved then
			known = known + 1
			most = math.max(most, row.moved)
		end
	end
	return most, known
end

if ns.TestKit and not ns.isRetail then ns.TestKit.Define({
	name = "zoomstep",
	key = "zoomStepTest",
	title = "Far step follows the camera",
	about = "you stand still, the test zooms: does an NPC's far step come and go with the zoom alone?",
	needs = "CineMode on, out of combat, 30-40 yards from a friendly NPC whose name shows without targeting it",
	cineMode = true,
	settings = { "plateNameFarStep", "plateNameSizeBy" },
	cvars = { "nameplateMinScale", "nameplateMaxScale", "nameplateMinScaleDistance", "nameplateMaxScaleDistance",
		"nameplateMaxDistance", "cameraDistanceMaxZoomFactor" },
	context = function()
		return ("zoom %s, Far names %s, Size by %s, %s"):format(tostring(Plain(Call(GetCameraZoom))),
			tostring(ns.db.plateNameFarStep), tostring(ns.db.plateNameSizeBy), FarLine())
	end,
	putBack = function(extra)
		ns.NameRulerStop()
		local was = tonumber(extra.zoom)
		local now = Plain(Call(GetCameraZoom))
		if was and type(now) == "number" then ZoomBy(was - now) end
		return was and ("zoom back to %.1f"):format(was) or "zoom untouched"
	end,
	steps = {
		{ key = "setup", title = "still, 30-40 yards from an NPC", run = function(r)
			r:Keep("zoom", Plain(Call(GetCameraZoom)))
			r:Set("plateNameSizeBy", "fixed") -- (our own sizing out of it: the plate's scale is what's measured)
			if not ns.IsCineModeOn() then
				r:WaitFor("Turn CineMode ON (Far names smaller is CineMode's).", {
					check = function() return ns.IsCineModeOn() end,
					buttons = { { label = "Turn CineMode on", fn = function()
						if not ns.IsCineModeOn() then Cinematic_ToggleCineMode() end
					end } } })
			end
			local still, lastWhy
			local function Missing()
				if InCombatLockdown() then return "out of combat" end
				if not UnitExists("target") then return "a target" end
				if UnitIsPlayer("target") then return "an NPC as your target, not a player" end
				if Call(CheckInteractDistance, "target", 4) == true then
					return ("farther from %s: past 28 yards (the game says %s)"):format(UnitName("target") or "it",
						(TargetDistance()))
				end
				if Moving() then return "standing still" end
			end
			local npc = r:WaitFor("Stand STILL 30 to 40 yards from a friendly NPC whose name shows over its head WITHOUT "
				.. "targeting it (a vendor or trainer), facing it. Target it. Then don't move: the test does the rest.",
				{ check = function()
					local why = Missing()
					if why ~= lastWhy then
						lastWhy = why
						r:Log("  waiting for: " .. tostring(why or "nothing: 2 seconds still"))
						local box = ns.padTestBox
						if box and box.sub then box.sub:SetText(why and ("Waiting for: " .. why) or "Got it: hold still...") end
					end
					if why then
						still = nil
						return false
					end
					still = still or GetTime()
					return GetTime() - still >= 2 and (UnitName("target") or "the NPC")
				end })
			ns.NameRuler({ test = true, say = function(text) r:Log(text) end })
			r:WaitFor(("Press ESCAPE to clear your target (%s stays marked). Then don't touch anything."):format(tostring(npc)),
				{ check = function() return not UnitExists("target") and "cleared" end })
			r:Sleep(1)
			local unit, state = ns.NameRulerUnit(), ns.NameRulerState()
			r:Verdict(unit ~= nil and state ~= nil and state.ourShown == true,
				("%s's plate found untargeted, its name showing (%s)"):format(tostring(npc), tostring(unit)))
		end },
		{ key = "step", title = "the sweep, Far names Much smaller", run = function(r)
			if not ns.NameRulerState() then return r:Skip("no NPC marked") end
			r:Set("plateNameFarStep", 0.65)
			ns.plates.FarStepChanged()
			-- (Names drawn again with the new step before the sweep: run 2's first
			-- zoom still had the old size, so it counted two sizes.)
			if ns.RefreshAllPlates then pcall(ns.RefreshAllPlates) end
			r:Sleep(2)
			r:Log("sweep 1: " .. FarLine())
			r:Prompt("HANDS OFF: the test zooms the camera in and out. Don't move.", nil, 50)
			local rows = Sweep(r, "sweep 1")
			local most, known = MostMoved(rows)
			r:Verdict(known > 0 and most < 0.3, ("you never moved: at most %.2f yd from where you stood, %d of %d zooms read")
				:format(most, known, #rows))
			-- (Run 1, the game's camera step: 0.64 -> 0.42 between zoom 4 and 5,
			-- you never moved. Since then Far names is our own step from you:
			-- zooming must change neither the plate nor our name, and the NPC,
			-- past 28 yards, has our name a step smaller the whole sweep.)
			local steps = ScaleSteps(rows)
			local lines, sizes, past = {}, {}, true
			for _, step in ipairs(steps) do
				lines[#lines + 1] = ("%.2f -> %.2f between zoom %.1f and %.1f"):format(step.from, step.to, step.before, step.atZoom)
			end
			for _, row in ipairs(rows) do
				if type(row.size) == "number" then sizes[("%.3f"):format(row.size)] = true end
			end
			local sizeCount = 0
			for _ in pairs(sizes) do sizeCount = sizeCount + 1 end
			local state = ns.NameRulerState() or {}
			local out = ns.plateSightNear and ns.plateSightNear.out
			for plate, isOut in pairs(out or {}) do
				if plate.namePlateUnitToken == state.unit and isOut ~= true then past = false end
			end
			r:Verdict(#steps == 0 and sizeCount == 1 and most < 0.3, ("standing still, zooming changed neither the plate "
				.. "(steps: %s) nor our name (%d size(s))"):format(#lines > 0 and table.concat(lines, "; ") or "none", sizeCount))
			r:Log(("its name past 28 yards (our step on): %s"):format(tostring(past)))
			r:Shot("Far names Much smaller: the NPC past 28 yards, any zoom")
		end },
		{ key = "control", title = "the same sweep, Far names Same size", run = function(r)
			if not ns.NameRulerState() then return r:Skip("no NPC marked") end
			r:Set("plateNameFarStep", 1)
			ns.plates.FarStepChanged()
			if ns.RefreshAllPlates then pcall(ns.RefreshAllPlates) end
			r:Sleep(2)
			r:Log("sweep 2: " .. FarLine())
			r:Prompt("HANDS OFF: the same zooming, the far step off. Don't move.", nil, 50)
			local rows = Sweep(r, "sweep 2")
			local most = MostMoved(rows)
			local steps = ScaleSteps(rows)
			r:Verdict(#steps == 0 and most < 0.3, ("with Far names Same size, no step over the same zooms (%d)"):format(#steps))
		end },
	},
}) end
