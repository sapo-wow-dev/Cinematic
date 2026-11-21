-- Map pin reveal check (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/mappin.lua < /dev/null
-- The game's map pin heard on the minimap ("Map Pin", MAP_PIN) is its own
-- kind, not Other icons: Reveal's Map pin box decides it, and with Shortest
-- Path Forever loaded and guiding a journey, Not for Shortest Path (on to
-- start with) keeps it from bringing the minimap up. Never a quest giver.
-- Says PASS or FAIL per check.
-- luacheck: push ignore 111 112 113 121 122 212
local ns = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc")

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail ~= nil and (" (" .. tostring(detail) .. ")") or ""))
end

MAP_PIN = "Map Pin"
GetNumGroupMembers = function() return 0 end
IsInRaid = function() return false end
UnitName = function(unit) return unit == "player" and "Sapo" or nil end
local spfLoaded, spfActive = false, false
C_AddOns = C_AddOns or {}
local oldLoaded = C_AddOns.IsAddOnLoaded
C_AddOns.IsAddOnLoaded = function(name)
	if name == "ShortestPathForever" then return spfLoaded end
	return oldLoaded and oldLoaded(name) or false
end
ShortestPathForever = { API = { Active = function() return spfActive end } }

local db = ns.GetDB and ns.GetDB() or ns.db
ns.db = db
local entry = { list = { 0, 0 } } -- (heard in the middle, not at the rim)
local function Reveals() return ns.NameRevealsMinimap("Map Pin", entry) == true end

Check("Map Pin is its own kind", ns.NodeKind("Map Pin") == "mappin", ns.NodeKind("Map Pin"))
Check("defaults: Map pin on", db.minimapRevealMapPin == true and ns.DEFAULTS.minimapRevealMapPin == true)
Check("defaults: Not for Shortest Path on", ns.DEFAULTS.minimapRevealMapPinSkipSPF == true)

db.minimapRevealIcons = false
db.minimapRevealMapPin = true
Check("your pin reveals with Other icons off", Reveals())
db.minimapRevealIcons = true
db.minimapRevealMapPin = false
Check("Map pin off: no reveal, Other icons on", not Reveals())
db.minimapRevealMapPin = true

spfLoaded, spfActive = true, false
Check("SPF loaded, no journey: your pin reveals", Reveals())
spfActive = true
Check("SPF guiding a journey: its pin doesn't reveal", not Reveals())
db.minimapRevealMapPinSkipSPF = false
Check("Not for Shortest Path off: SPF's pin reveals", Reveals())
db.minimapRevealMapPinSkipSPF = true
spfLoaded = false
Check("SPF not loaded: a pin reveals (API left behind ignored)", Reveals())

ShortestPathForever.API.Active = function() error("boom") end
spfLoaded = true
Check("SPF's API erroring: counts as yours", Reveals())

-- The cursor sweep (Forever since 2026-11-12: names secret) leaves the pin's
-- dot out as a known spot by the same boxes.
ShortestPathForever.API.Active = function() return spfActive end
spfLoaded, spfActive = false, false
db.minimapRevealMapPin = true
Check("cursor sweep: your pin is a dot (reveals)", ns.MapPinIsKnownDot() == false)
db.minimapRevealMapPin = false
Check("cursor sweep: Map pin off, pin left out", ns.MapPinIsKnownDot() == true)
db.minimapRevealMapPin = true
spfLoaded, spfActive = true, true
Check("cursor sweep: SPF's pin left out", ns.MapPinIsKnownDot() == true)
db.minimapRevealMapPinSkipSPF = false
Check("cursor sweep: Not for Shortest Path off, SPF's pin a dot", ns.MapPinIsKnownDot() == false)
db.minimapRevealMapPinSkipSPF = true

-- Where it is: yards north and west of you, from the world positions.
local function V(x, y) return { x = x, y = y } end
local world = { [1429] = { continent = 0, pin = V(110, 205), you = V(100, 200) },
	[1411] = { continent = 1, you = V(5, 5) } }
local playerMap, pinMap = 1429, 1429
C_Map = C_Map or {}
C_Map.GetUserWaypoint = function() return pinMap and { uiMapID = pinMap, position = "pin" } or nil end
C_Map.GetBestMapForUnit = function() return playerMap end
C_Map.GetPlayerMapPosition = function() return "you" end
C_Map.GetWorldPosFromMapPos = function(map, pos)
	local m = world[map]
	return m.continent, m[pos]
end
local spot = ns.MapPinSpot()
Check("spot: 10 yd north, 5 yd west", spot and spot.north == 10 and spot.west == 5,
	spot and (spot.north .. ", " .. spot.west))
playerMap = 1411
Check("spot: pin on another continent = none", ns.MapPinSpot() == nil)
playerMap, pinMap = 1429, nil
Check("spot: no pin = none", ns.MapPinSpot() == nil)

-- Quest cam's quest givers: other and turn-ins only.
Check("Map Pin isn't Other", ns.NodeKind("Map Pin") ~= "other")
Check("another icon still Other", ns.NodeKind("Flight Master") == "other", ns.NodeKind("Flight Master"))

print(fails == 0 and "ALL PASS" or (fails .. " FAIL"))
-- luacheck: pop
