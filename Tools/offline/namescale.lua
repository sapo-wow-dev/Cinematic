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
	Check(out <= 12 and sets - out <= 12, ("zooming: font set %d times out, %d back in (once a pixel)"):format(out,
		sets - out))
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
	ns.PlateNameZoom(0)
end

print(failed == 0 and "ALL PASS" or (failed .. " FAILED"))
