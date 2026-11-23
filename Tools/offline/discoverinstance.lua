-- Discovered card just out of a dungeon (dev tool, offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/discoverinstance.lua < /dev/null
-- 2026-11-23, the user's screenshot: out of the Stormwind Stockade (a dungeon
-- seen before), the game still gave the zone's name as "Stormwind Stockade"
-- for 6 s outside it, so the check a second after the loading screen took it
-- for a whole new zone: the big New zone card. On the stand-in game with a
-- clock of its own: no card leaving it while the name's the dungeon's; the
-- real name after (a city seen before) no card; a new zone after still gets
-- New zone's; a dungeon new to you still gets Discovered's. PASS or FAIL per
-- check. (Optional first argument: another .toc to load, to run it on older
-- code.)
local now = 100
local timers = {}
local zone, inside, instanceName, instanceID = "Stormwind City", false, nil, nil

-- luacheck: push ignore 111 112 113 121 122 212
local ns, wow = dofile("Tools/offline/load.lua")("forever", arg and arg[1], function()
	GetTime = function() return now end
	C_Timer.After = function(seconds, fn) timers[#timers + 1] = { at = now + (seconds or 0), fn = fn } end
	ERR_ZONE_EXPLORED = "Discovered: %s"
	ERR_ZONE_EXPLORED_XP = "Discovered %s: %d experience gained"
	GetRealZoneText = function() return zone end
	GetSubZoneText = function() return "" end
	IsInInstance = function() return inside, inside and "party" or "none" end
	GetInstanceInfo = function() return instanceName, "party", 1, "Normal", 5, 0, false, instanceID end
	C_Map = { GetBestMapForUnit = function() return 84 end }
	-- (A city: no explorable areas, the game can't say: ours counts.)
	C_MapExplorationInfo = { GetExploredMapTextures = function() return {} end }
end)
-- luacheck: pop

local function Advance(seconds)
	local stop = now + seconds
	while now < stop - 1e-9 do
		now = math.min(stop, now + 0.1)
		local due = {}
		for i = #timers, 1, -1 do
			if timers[i].at <= now + 1e-9 then
				due[#due + 1] = timers[i]
				table.remove(timers, i)
			end
		end
		table.sort(due, function(a, b) return a.at < b.at end)
		for _, timer in ipairs(due) do pcall(timer.fn) end
	end
end

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

ns.db.cards = true
ns.db.cardDiscoverOn = true
ns.db.cardNewZoneOn = true
ns.chardb.cardSeen = { zones = { ["Elwynn Forest"] = true, ["Stormwind City"] = true }, instances = { [34] = true } }
local fired = {}
local Fire = ns.Cards.Fire
ns.Cards.Fire = function(id, card, ...)
	fired[#fired + 1] = id .. " \"" .. tostring(card and card.name) .. "\""
	return Fire(id, card, ...)
end
local function Fired() return #fired == 0 and "none" or table.concat(fired, ", ") end
local function Reset()
	for _, id in ipairs({ "discover", "newZone" }) do pcall(ns.Cards.Cut, id) end
	Advance(40)
	fired = {}
end
local function Loading(newZone, isInside, name, id)
	zone, inside, instanceName, instanceID = newZone, isInside, name, id
	wow.Fire("PLAYER_ENTERING_WORLD", false, false)
end
Check("Discovered and New zone cards allowed on the stand-in", ns.CardAllowed("discover") and ns.CardAllowed("newZone"))

-- 1: into the Stockade (seen before), then out: the name's still the
-- dungeon's for 6 s, then the real one with its zone change.
Reset()
Loading("Stormwind Stockade", true, "Stormwind Stockade", 34)
Advance(5)
Check("into a dungeon seen before: no card", #fired == 0, Fired())
Loading("Stormwind Stockade", false)
Advance(5)
Check("just out, the zone's name still the dungeon's: no card", #fired == 0, Fired())
Check("the dungeon's name not counted as a zone seen", not ns.chardb.cardSeen.zones["Stormwind Stockade"])
zone = "Stormwind City"
wow.Fire("ZONE_CHANGED_NEW_AREA")
Advance(5)
Check("the real name after (a city seen before): no card", #fired == 0, Fired())

-- 2: a whole zone new to you still gets New zone's card.
Reset()
zone = "Westfall"
wow.Fire("ZONE_CHANGED_NEW_AREA")
Advance(5)
Check("a new zone after it: New zone's card", fired[1] == "newZone \"Westfall\"", Fired())
-- (/cine debug zonecard 9 reads the card straight after, with no wait.)
local playing = ns.Cards.Current()
Check("it's the card up at once", playing and playing.id == "newZone", playing and playing.id)

-- 3: a dungeon new to you still gets Discovered's (small) card, and out of it no other.
Reset()
Loading("The Deadmines", true, "The Deadmines", 36)
Advance(5)
Check("into a dungeon new to you: Discovered's card", fired[1] == "discover \"The Deadmines\"", Fired())
Reset()
Loading("The Deadmines", false)
Advance(5)
Check("out of it, the name still the dungeon's: no card", #fired == 0, Fired())

-- 4: the game's own "Discovered:" line with the dungeon's stale name: Discovered's, not New zone's.
Reset()
Loading("Stormwind Stockade", true, "Stormwind Stockade", 34)
Advance(5)
Loading("Stormwind Stockade", false)
wow.Fire("UI_INFO_MESSAGE", 372, "Discovered: Stormwind Stockade")
Advance(1)
Check("a Discovered line with the stale name: not New zone's card",
	not (fired[1] and fired[1]:find("^newZone")), Fired())

print(fails == 0 and "ALL PASS" or (fails .. " FAIL"))
if fails > 0 then os.exit(1) end
