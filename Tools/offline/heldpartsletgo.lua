-- Unit frame parts held hidden, then their frame let go; and a feature loop
-- turned off by its breaker, then its feature started over (offline, Lua 5.1
-- via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/heldpartsletgo.lua < /dev/null
-- Audit 2026-11-22:
-- - A Hover group with Portrait unticked holds the player frame's portrait
--   hidden while the frame's up (FRAMES.held). Only the pass over managed
--   frames let go of it, so a frame let go meanwhile (its Show in switch off,
--   a profile, /cine keep) kept its portrait hidden till a reload.
-- - ns.FeatureLoop's wrapper was made once: after 5 errors in 3 s it was dead
--   for the session, its feature off and on again or not.
-- PASS or FAIL per check.

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local ns, wow = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc")

-- 1: held parts let go with their frame. (FRAMES: HoldUnitParts' upvalue.)
local FRAMES
for i = 1, 20 do
	local name, value = debug.getupvalue(ns.HoldUnitParts, i)
	if not name then break end
	if name == "FRAMES" then FRAMES = value end
end
Check("1 the unit frame parts table found", FRAMES ~= nil)
if FRAMES then
	local frame = _G.PlayerFrame or wow.CreateFrame("Frame", "PlayerFrame")
	FRAMES.off.PlayerFrame = { portrait = true }
	ns.HoldUnitParts("PlayerFrame", true)
	Check("1 the portrait held while it's up", FRAMES.held.PlayerFrame and FRAMES.held.PlayerFrame.portrait == true)
	table.insert(ns.managed, { frame = frame, name = "PlayerFrame", baseAlpha = 1 })
	ns.StopFading("PlayerFrame")
	Check("1 let go with its frame", FRAMES.held.PlayerFrame == nil)
	FRAMES.off.PlayerFrame = nil
end

-- 2: a feature loop that kept failing, back with its feature.
local frame = wow.CreateFrame("Frame")
local on, broken, runs = true, true, 0
ns.FeatureLoop(frame, function()
	runs = runs + 1
	if broken then error("audit test: a loop that keeps failing") end
end, function() return on end)
local function Run(times)
	for _ = 1, times do
		local update = frame._scripts.OnUpdate
		if update then update(frame, 0.1) end
	end
end
Run(8)
Check("2 turned off by its breaker", frame._scripts.OnUpdate == nil and runs == 5, runs)
on = false
ns.SyncFeatureLoops()
on, broken, runs = true, false, 0
ns.SyncFeatureLoops()
Run(3)
Check("2 its feature off and on: running again", runs == 3, runs)

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
