-- Names over heads sized like the game's own (offline, Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/namescale.lua forever
-- Plates/PlateParts.lua's Look (ns.PlateNameSizeAt) against the game's names measured by
-- /cine debug namescale (Stormwind 2026-11-23, Tools/tests/name-scale.md):
-- width ~ 3510 px / (camera to unit + 3.4 yd), where our size 1 was 241 px:
-- so size ~ 14.6 / (camera to unit + 3.4). Checked: the size within 10% of
-- the game's from 8 to 50 yards from the camera; the height -45 to -38 (run
-- 3); the same on screen at another UI scale; walking never resizes a name
-- (the size follows the zoom only, the user 2026-11-23: per-distance sizes
-- popping every second were too much); zooming in and out, every font set at
-- a whole pixel, once per pixel, never flickering at a line; and the
-- migration clears a close/far size and height saved for an older curve (the
-- account's and a saved profile's). PASS or FAIL.
-- luacheck: push ignore 111 112 113 121 122
local client = arg and arg[1] or "forever"
package.path = "Tools/offline/?.lua;" .. package.path
local wow = dofile("Tools/offline/wow.lua")
wow.Install(client)
CinematicDB = { plateNameCloseSize = 1.6, plateNameFarSize = 0.3, plateNameCloseY = 7, plateNameFarY = -86,
	nameScaleV1 = true, nameScaleV2 = true,
	profiles = { Mine = { plateNameCloseSize = 2, plateNameFarSize = 0.3, other = 1 } } }
local ns = {}
for line in io.lines("Cinematic.toc") do
	line = line:gsub("\r", "")
	if line ~= "" and not line:find("^#") then
		local chunk = loadfile((line:gsub("\\", "/")))
		if chunk then
			local ok, err = pcall(chunk, "Cinematic", ns)
			if not ok then wow.Warn(line .. ": " .. tostring(err)) end
		end
	end
end
wow.Fire("ADDON_LOADED", "Cinematic")
wow.Fire("PLAYER_LOGIN")
-- luacheck: pop

local failed = 0
local function Check(ok, text)
	print((ok and "PASS " or "FAIL ") .. text)
	if not ok then failed = failed + 1 end
end

local Look = ns.PlateNameSizeAt
-- (The curve and zoom checks below are Size by Zoom's: Fixed is the default
-- since 2026-11-23, checked with the Size by checks further down.)
ns.db.plateNameSizeBy = "zoom"
Check(Look ~= nil and ns.PlateNameReach == nil, "ns.PlateNameSizeAt found; no per-distance guess (ns.PlateNameReach) any more")
if not Look then return print("1 FAILED") end

-- The migration (ADDON_LOADED ran it).
local db = CinematicDB
-- (Cleared, then filled with the new defaults as every missing setting is.)
Check(db.plateNameCloseSize == ns.DEFAULTS.plateNameCloseSize and db.plateNameFarSize == ns.DEFAULTS.plateNameFarSize
	and db.plateNameCloseSize == 1.3 and db.plateNameCloseY == -45 and db.plateNameFarY == -38
	and db.nameScaleV3 == true and db.nameScaleV1 == nil and db.nameScaleV2 == nil,
	"migration (V3, after V1/V2 ran): the old close/far sizes and heights replaced by the new defaults, once")
Check(db.profiles.Mine.plateNameCloseSize == nil and db.profiles.Mine.other == 1,
	"migration: a saved profile's cleared, its other settings kept")

-- Retail: its plates scale themselves, ours stay size 1 at any distance.
if client == "retail" then
	local same = true
	for yards = 2, 50, 4 do if Look(yards) ~= 1 then same = false end end
	Check(same, "retail: size 1 at every distance (unchanged)")
	print(failed == 0 and "ALL PASS" or (failed .. " FAILED"))
	return
end

-- The curve (zoom 0 offline: camera to unit = the unit's distance), at the
-- UI scale it was measured at (the stand-in's is 1: the fix off here).
ns.plateNameNoUiFix = true
local worst, at = 0, nil
for yards = 8, 50, 2 do
	local size = Look(yards)
	local game = 14.6 / (yards + 3.4)
	local off = math.abs(size / game - 1)
	if off > worst then worst, at = off, yards end
end
Check(worst <= 0.10, ("size within 10%% of the game's from 8 to 50 yards (worst %.0f%% at %s yd)"):format(worst * 100,
	tostring(at)))
Check(Look(2) == Look(8), "no bigger than the close point (8 yards, camera right in)")
-- Height (run 3, by the gap over the unit's head: about the same at any
-- distance): -45 close to -38 far, never past them.
local lowY, highY = 0, -999
for yards = 2, 60, 2 do
	local _, y = Look(yards)
	lowY, highY = math.min(lowY, y), math.max(highY, y)
end
Check(lowY >= -45 and highY <= -38, ("height between -45 and -38 at any distance (%d to %d)"):format(lowY, highY))
-- At UI scale 1 (the stand-in's), the same on screen: size and height times 0.64.
local size64, y64 = Look(20)
ns.plateNameNoUiFix = nil
local size1, y1 = Look(20)
Check(math.abs(size1 / size64 - 0.64) < 0.04 and math.abs(y1 - y64 * 0.64) <= 1,
	("UI scale 1: size %.3f and height %d (at 0.64: %.3f, %d)"):format(size1, y1, size64, y64))
ns.plateNameNoUiFix = true

-- Zoom only: walking (any distance, any time) never resizes a name; zooming
-- in and out does, a whole pixel at a time, held against flicker.
local Update = ns.PlateNameUpdateLook
Check(Update ~= nil and ns.PlateNameZoom ~= nil, "ns.PlateNameUpdateLook and ns.PlateNameZoom found")
if Update and ns.PlateNameZoom then
	local PX_PER = 14 * 1.2 -- (a 14 pt font at UI 0.64 on 1440p: 1.2 px a point)
	ns.PlateNameZoom(8)
	local shown = { pxPer = PX_PER }
	Update(shown)
	shown.dirty = nil
	local resized = 0
	for _ = 1, 600 do -- (ten seconds of walking: nothing but time passes)
		Update(shown)
		if shown.dirty then resized, shown.dirty = resized + 1, nil end
	end
	Check(resized == 0, ("walking: no resize in 10 s at one zoom (%d)"):format(resized))
	-- Zooming out 2 to 30 yards and back in, a little each frame.
	local sets, offPixel, turns, lastSize, lastPx = 0, 0, 0, shown.size, nil
	local function Zoom(z, dir)
		ns.PlateNameZoom(z)
		Update(shown)
		if shown.dirty then
			shown.dirty = nil
			if shown.size ~= lastSize then
				sets = sets + 1
				local px = shown.size * PX_PER
				if math.abs(px - math.floor(px + 0.5)) > 1e-6 then offPixel = offPixel + 1 end
				local pxNow = math.floor(px + 0.5)
				if lastPx and (pxNow > lastPx and 1 or -1) ~= dir then turns = turns + 1 end
				lastPx = pxNow
			end
			lastSize = shown.size
		end
	end
	for z = 2, 30, 0.05 do Zoom(z, -1) end
	local out = sets
	for z = 30, 2, -0.05 do Zoom(z, 1) end
	Check(offPixel == 0, ("zooming: every font set at a whole pixel height (%d off)"):format(offPixel))
	Check(turns == 0, ("zooming: the size only ever goes the way of the zoom (%d flickers)"):format(turns))
	-- (Once a pixel: no more sets than pixel heights crossed, zoom 2 to 30.)
	ns.PlateNameZoom(2)
	local big = Look()
	ns.PlateNameZoom(30)
	local small = Look()
	local span = math.ceil((big - small) * PX_PER) + 1
	Check(out <= span and sets - out <= span, ("zooming: font set %d times out, %d back in (once a pixel: %d or fewer)")
		:format(out, sets - out, span))
	-- Hovering: the zoom wobbling at a pixel line (the camera gliding).
	local hover = { pxPer = PX_PER }
	local flips, lastHover, clock = 0, nil, 0
	ns.plateNameSizeTest = function(text)
		if text ~= hover then return nil end
		return (10.5 + 0.3 * math.sin(clock * 7)) / PX_PER
	end
	for _ = 1, 180 do
		clock = clock + 1 / 60
		Update(hover)
		if hover.dirty then
			hover.dirty = nil
			if lastHover and hover.size ~= lastHover then flips = flips + 1 end
			lastHover = hover.size
		end
	end
	ns.plateNameSizeTest = nil
	Check(flips == 0, ("zooming: a size hovering at a pixel line holds one height (%d flips in 3 s)"):format(flips))
	-- A plate measured while still scaling in (2026-11-24, a merchant's
	-- title many times its size): its name back to the zoom's size once the
	-- plate is its size, and never past it meanwhile.
	ns.PlateNameZoom(8)
	local want = Look()
	local effective = 0.001
	GetPhysicalScreenSize = function() return 2560, 1440 end -- luacheck: ignore 111 121
	local stuck = { pxBase = 14, GetEffectiveScale = function() return effective end }
	ns.PlateNamePxPer(stuck)
	Update(stuck)
	local early = stuck.size
	stuck.pxPer = 0.05 -- (a measure taken before the guard: the old way in)
	stuck.px = nil
	Update(stuck)
	local tiny = stuck.size
	effective = 0.64
	for _ = 1, 3 do
		ns.PlateNamePxPer(stuck)
		Update(stuck)
	end
	local late = stuck.size
	Check(early <= want * 1.25 and tiny <= want * 1.25,
		("scaling in: the name no bigger than the zoom's size (%.2f, %.2f; zoom's %.2f)"):format(early, tiny, want))
	Check(math.abs(late / want - 1) < 0.1 and stuck.px ~= nil,
		("scaling in: at its size, the zoom's size on a whole pixel (%.2f; zoom's %.2f)"):format(late, want))
	-- Walking with plates not held at one size (CineMode off, your own scale
	-- CVars): the plate's scale drifts a little each draw. Once settled, the
	-- name keeps its size (no new font set, no steps while walking: the
	-- user's rule, 2026-11-23); a 10x wrong measure still comes undone above.
	local steps, last = 0, stuck.size
	for i = 1, 60 do
		effective = 0.64 * (1 + 0.25 * math.sin(i / 6))
		ns.PlateNamePxPer(stuck)
		Update(stuck)
		if stuck.size ~= last then steps = steps + 1 end
		last = stuck.size
	end
	Check(steps == 0, ("walking: the name's size held while its plate's scale drifts 25%% (%d steps)"):format(steps))
	ns.PlateNameZoom(0)
end

-- Size by (the Name Style page, 2026-11-23): Zoom follows the camera, Fixed
-- keeps one size at any zoom (as at a middle zoom), and back.
if ns.PlateNameZoom then
	Check(ns.DEFAULTS.plateNameSizeBy == "fixed", "Size by: Fixed to start (the user, 2026-11-23)")
	ns.plateNameNoUiFix = true
	ns.PlateNameZoom(2)
	local zoomedIn = Look()
	ns.PlateNameZoom(30)
	local zoomedOut = Look()
	Check(zoomedIn > zoomedOut,
		("Size by Zoom: bigger zoomed in (%.3f) than out (%.3f)"):format(zoomedIn, zoomedOut))
	ns.db.plateNameSizeBy = "fixed"
	ns.PlateNameZoom(2)
	local fixedIn = Look()
	ns.PlateNameZoom(30)
	local fixedOut = Look()
	ns.PlateNameZoom(ns.PLATE_NAME_REACH.FIXED_ZOOM)
	ns.db.plateNameSizeBy = "zoom"
	local middle = Look()
	Check(fixedIn == fixedOut and fixedIn == middle, ("Size by Fixed: one size at any zoom (%.3f, %.3f), the middle "
		.. "zoom's (%.3f)"):format(fixedIn, fixedOut, middle))
	-- (Its size: about v2.1.27's at a usual zoom, 0.84-1.10 at zoom 4-8;
	-- 0.76 at FIXED_ZOOM 8 was "too small", the user 2026-11-24.)
	Check(ns.PLATE_NAME_REACH.FIXED_ZOOM == 4 and fixedIn >= 0.9 and fixedIn <= 1.0,
		("Size by Fixed: as at zoom 4, about v2.1.27's size (%.3f, 0.90-1.00)"):format(fixedIn))
	ns.PlateNameZoom(0)
end

-- Far names from you (2026-11-23, "from your character"): past 28 yards a
-- name is FarStep smaller, whatever the zoom; the first reading at once, a
-- change after a second; never the game's camera step any more.
if Update and ns.plateSightNear and ns.plateSightNear.Decide then
	local near, Decide = ns.plateSightNear, ns.plateSightNear.Decide
	local plateA = {}
	Check(Decide(plateA, true, 10) == false and near.out[plateA] == true, "first reading (past 28) taken at once")
	Check(Decide(plateA, false, 10.2) == false and near.out[plateA] == true, "a change waits: still past at 0.2 s")
	Check(Decide(plateA, true, 10.6) == false and near.outAt[plateA] == nil, "the change undone before 1 s: nothing, wait reset")
	Decide(plateA, false, 11)
	Check(Decide(plateA, false, 12.1) == true and near.out[plateA] == false, "a change held 1 s: applied, its name to size again")
	-- The size: past 28 a step smaller at any zoom, within full; Same size: none.
	ns.plateNameNoUiFix = true
	local PX = 14 * 1.2
	local inText, outText = { pxPer = PX, plate = {} }, { pxPer = PX, plate = {} }
	near.out[inText.plate], near.out[outText.plate] = false, true
	ns.db.plateNameFarStep = 0.8
	local ratios = {}
	for _, z in ipairs({ 2, 8, 15 }) do
		ns.PlateNameZoom(z)
		inText.px, outText.px = nil, nil
		Update(inText)
		Update(outText)
		ratios[#ratios + 1] = outText.size / inText.size
	end
	local good = true
	for _, ratio in ipairs(ratios) do if math.abs(ratio - 0.8) > 0.08 then good = false end end
	Check(good, ("past 28 yards 0.8 of near at zoom 2, 8, 15 (%.2f, %.2f, %.2f; whole pixels)"):format(ratios[1], ratios[2],
		ratios[3]))
	ns.db.plateNameFarStep = 1
	inText.px, outText.px = nil, nil
	Update(inText)
	Update(outText)
	Check(inText.size == outText.size, "Far names Same size: past 28 the same size")
	ns.db.plateNameFarStep = nil
	ns.PlateNameZoom(0)
end

-- Plates one size (since 2026-11-23): while wanted, the game's plates held at
-- min = max = 1 whatever Far names says (our step is our own); yours back
-- when let go; the old set's leftover distances 41 / 5 put back to the
-- game's defaults once.
do
	-- luacheck: push ignore 111 112 113 121 122
	local cvars = { nameplateMinScale = "0.8", nameplateMaxScale = "1", nameplateMaxScaleDistance = "41",
		nameplateMinScaleDistance = "5" }
	local defaults = { nameplateMaxScaleDistance = "10", nameplateMinScaleDistance = "10" }
	local oldGet, oldSet, oldCSet, oldDefault = GetCVar, SetCVar, C_CVar, GetCVarDefault
	GetCVar = function(name) return cvars[name] end
	SetCVar = function(name, value) if cvars[name] ~= nil then cvars[name] = tostring(value) end end
	GetCVarDefault = function(name) return defaults[name] end
	C_CVar = { SetCVar = SetCVar, GetCVar = GetCVar }
	local far = ns.plates.FAR_NAME_CVARS
	local wanted = true
	local oldWanted = ns.plates.FarWanted
	ns.plates.FarWanted = function() return wanted end
	-- (V1 already ran and skipped, a 41 saved as yours: farnames run 14's case.)
	ns.db.farNamesLeftoversV1, ns.db.farNamesLeftoversV2 = true, nil
	ns.db.savedCVars = { nameplateMaxScaleDistance = "41" }
	ns.plates.FarStepChanged()
	Check(cvars.nameplateMaxScaleDistance == "10" and cvars.nameplateMinScaleDistance == "10" and ns.db.farNamesLeftoversV2
		and ns.db.savedCVars.nameplateMaxScaleDistance == "10",
		("the old set's leftovers 41 / 5 put back to the game's 10 / 10 (%s / %s, saved %s), V1 run or not"):format(
		cvars.nameplateMaxScaleDistance, cvars.nameplateMinScaleDistance, tostring(ns.db.savedCVars.nameplateMaxScaleDistance)))
	Check(cvars.nameplateMinScale == "1" and cvars.nameplateMaxScale == "1" and far.active,
		"wanted: plates held one size (min " .. cvars.nameplateMinScale .. ", max " .. cvars.nameplateMaxScale .. ")")
	for _, step in ipairs({ 1, 0.9, 0.65 }) do
		ns.db.plateNameFarStep = step
		ns.plates.FarStepChanged()
		Check(cvars.nameplateMinScale == "1" and far.active, ("Far names %s: plates still one size (%s)"):format(step,
			cvars.nameplateMinScale))
	end
	wanted = false
	ns.plates.FarStepChanged()
	Check(cvars.nameplateMinScale == "0.8" and not far.active, "not wanted (CineMode off): let go, yours back ("
		.. cvars.nameplateMinScale .. ")")
	cvars.nameplateMaxScaleDistance = "41"
	cvars.nameplateMinScaleDistance = "5"
	ns.plates.FarStepChanged()
	Check(cvars.nameplateMaxScaleDistance == "41", "the leftovers cleanup runs once only (a later 41 is yours)")
	ns.db.plateNameFarStep = 0.3
	Check(ns.plates.FarStep() == 0.8, "a value out of range reads as 0.8")
	ns.db.plateNameFarStep, ns.db.farNamesLeftoversV1, ns.db.farNamesLeftoversV2 = nil, nil, nil
	ns.plates.FarWanted = oldWanted
	GetCVar, SetCVar, C_CVar, GetCVarDefault = oldGet, oldSet, oldCSet, oldDefault
	-- luacheck: pop
end

-- The ruler (/cine debug namescale ruler): marks your spot, shows yards
-- walked from it, and logs what our name does with its yards. A walk 0 to
-- 32 yards, our name dimming at 29.
-- luacheck: push ignore 111 112 113 121 122
do
	local px, py, now, shots, tick = 0, 0, 100, 0, nil
	local oldTicker, oldTime = C_Timer.NewTicker, GetTime
	C_Timer.NewTicker = function(_, fn) tick = fn return { Cancel = function() tick = nil end } end
	GetTime = function() return now end
	UnitPosition = function() return py, px end
	UnitExists = function() return true end
	UnitName = function() return "Fishing Supplier" end
	UnitDistanceSquared = function() return nil, false end
	CheckInteractDistance = function(_, n) return px < (n == 4 and 28 or 10) end
	GetCameraZoom = function() return 12 end
	Screenshot = function() shots = shots + 1 end
	local ourAlpha = 1
	local ours = { IsVisible = function() return true end, GetAlpha = function() return ourAlpha end }
	local plate = { GetAlpha = function() return 1 end, UnitFrame = {} }
	C_NamePlate = { GetNamePlateForUnit = function() return plate end }
	local oldState = ns.PlateNameState
	ns.PlateNameState = function() return nil, 8, 0.69, -41, ours end
	local chunk = assert(loadfile("Dev/NameScaleTest.lua"))
	chunk("Cinematic", ns)
	ns.NameScaleTest("ruler")
	Check(tick ~= nil, "ruler: started, ticking")
	for x = 0, 32, 0.5 do
		px, now = x, now + 0.1
		if x >= 29 then ourAlpha = 0.4 end
		if tick then tick() end
	end
	local log = table.concat(CinematicDB.nameScaleLog, "\n")
	Check(log:find("29.0 yd: our name alpha 1 %-> 0.4") ~= nil, "ruler: our name dimming logged at 29.0 yd")
	Check(log:find("28.0 yd: game's range <28yd %-> >28yd") ~= nil, "ruler: the game's 28-yard band logged where it changed")
	Check(log:find("  30.0 yd: range >28yd", 1, true) ~= nil and log:find("  31.0 yd: range", 1, true) == nil,
		"ruler: a line every 2 yards")
	Check(shots == 2, ("ruler: a screenshot per change (%d)"):format(shots))
	ns.NameScaleTest("ruler")
	Check(tick == nil and log ~= "" and CinematicDB.nameScaleLog[#CinematicDB.nameScaleLog] :find("ruler stopped") ~= nil,
		"ruler: typed again, stops")
	C_Timer.NewTicker, GetTime, ns.PlateNameState = oldTicker, oldTime, oldState
end
-- luacheck: pop

print(failed == 0 and "ALL PASS" or (failed .. " FAILED"))
