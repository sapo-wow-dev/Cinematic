-- The minimap let go in a fight while parked off the screen full size
-- (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/minimapfightpark.lua < /dev/null
-- Audit 2026-11-22: kept full size while faded (a quest area, the dots
-- sweep), the minimap is parked off the right edge. Let go in a fight with
-- it protected (an addon's secure button on it), a shrunk one waited for the
-- fight's end, a full-size one had no waiter: off the screen till a reload.
-- On a stand-in minimap with real anchors: not moved in the fight, back on
-- its own spot as the fight ends; out of a fight, back at once. PASS or FAIL.

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local fight = false
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	InCombatLockdown = function() return fight end
	-- luacheck: pop
end
local ns, wow = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc", Install)

-- (The minimap's anchors kept, and protected with an addon's secure button on it.)
local points = {}
local moves = 0
rawset(Minimap, "ClearAllPoints", function() points = {} moves = moves + 1 end)
rawset(Minimap, "SetPoint", function(_, point, relativeTo, relativePoint, x, y)
	points[#points + 1] = { point, relativeTo, relativePoint, x, y }
end)
rawset(Minimap, "GetPoint", function(_, i)
	local p = points[i or 1]
	if p then return p[1], p[2], p[3], p[4], p[5] end
end)
rawset(Minimap, "GetNumPoints", function() return #points end)
rawset(Minimap, "IsProtected", function() return true end)

local function Spot()
	local p = points[1]
	return p and ("%s %s %s"):format(p[1], tostring(p[4]), tostring(p[5])) or "none"
end
local function Park()
	points = { { "TOPRIGHT", UIParent, "TOPRIGHT", -10, -12 } }
	local entry = { frame = Minimap, name = "Minimap", baseAlpha = 1 }
	table.insert(ns.managed, entry)
	ns.ParkFullSize(entry)
	return entry
end

-- 1: let go in a fight.
local entry = Park()
Check("1 parked off the screen", ns.IsParked(entry), Spot())
fight, moves = true, 0
ns.StopFading("Minimap")
Check("1 not moved in the fight", moves == 0 and ns.IsParked(entry), Spot())
fight = false
wow.Fire("PLAYER_REGEN_ENABLED")
Check("1 back on its own spot as the fight ends", Spot() == "TOPRIGHT -10 -12", Spot())

-- 2: let go out of a fight: back at once, as before.
ns.db.ignoredFrames.Minimap = nil
Park()
ns.StopFading("Minimap")
Check("2 out of a fight: back at once", Spot() == "TOPRIGHT -10 -12", Spot())

-- 3: its anchor count secret (a fight on WoW Forever, another addon's anchors):
-- left where it is, never cleared to none. (Release review 2026-11-22: since
-- ns.NumPoints gives 0 there, it was parked with no anchors saved and given
-- none back, off the screen till a reload.)
ns.db.ignoredFrames.Minimap = nil
points = { { "TOPRIGHT", UIParent, "TOPRIGHT", -10, -12 } }
local count = Minimap.GetNumPoints
rawset(Minimap, "GetNumPoints", function() error("secret") end)
local secretEntry = { frame = Minimap, name = "Minimap", baseAlpha = 1 }
moves = 0
ns.ParkFullSize(secretEntry)
Check("3 a secret anchor count: not moved", moves == 0 and Spot() == "TOPRIGHT -10 -12", Spot())
rawset(Minimap, "GetNumPoints", count)
-- 4: parked with no anchors saved: not cleared on the way back.
points = { { "TOPLEFT", UIParent, "TOPRIGHT", 20000, 0 } }
moves = 0
ns.UnparkShrunk({ frame = Minimap, savedPoints = {} })
Check("4 none saved: not cleared to none", moves == 0 and #points == 1, Spot())

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
