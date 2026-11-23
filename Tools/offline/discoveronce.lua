-- A place's Discovered card once, whichever says it's new (dev tool, offline,
-- Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/discoveronce.lua < /dev/null
-- 2026-11-23, the user's log: "Discovered: Redridge Mountains (a zone)" at
-- 16:35:53 and again at 16:36:50. The game's line and the zone-entered check
-- (the map's explored count) only shared a 30 s skip, so the second, 57 s
-- on, carded it again. On the stand-in game with a clock of its own: the
-- line then a border crossing back in, one card; a zone entered then its
-- line 57 s on, one card; a zone the game's explore count says discovered,
-- no card; a new subzone's line after all that still gets its card. PASS
-- or FAIL per check. (Optional first argument: another .toc to load.)
local now = 100
local timers = {}
local zone = "Elwynn Forest"

-- luacheck: push ignore 111 112 113 121 122 212
local ns, wow = dofile("Tools/offline/load.lua")("forever", arg and arg[1], function()
	GetTime = function() return now end
	C_Timer.After = function(seconds, fn) timers[#timers + 1] = { at = now + (seconds or 0), fn = fn } end
	ERR_ZONE_EXPLORED = "Discovered: %s"
	ERR_ZONE_EXPLORED_XP = "Discovered %s: %d experience gained"
	GetRealZoneText = function() return zone end
	GetSubZoneText = function() return "" end
	IsInInstance = function() return false, "none" end
	GetInstanceInfo = function() return zone, "none", 0, "", 0, 0, false, 0 end
	C_Map = { GetBestMapForUnit = function() return 49 end }
	-- (One area explored: the zone counts as new to you.)
	C_MapExplorationInfo = { GetExploredMapTextures = function() return { 1 } end }
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
ns.chardb.cardSeen = { zones = { ["Elwynn Forest"] = true }, instances = {} }
local fired = {}
local Fire = ns.Cards.Fire
ns.Cards.Fire = function(id, card, ...)
	fired[#fired + 1] = id .. " \"" .. tostring(card and card.name) .. "\""
	return Fire(id, card, ...)
end
local function Fired() return #fired == 0 and "none" or table.concat(fired, ", ") end
local function Reset()
	for _, id in ipairs({ "discover", "newZone" }) do pcall(ns.Cards.Cut, id) end
	Advance(5)
	fired = {}
end
local function Enter(place)
	zone = place
	wow.Fire("ZONE_CHANGED_NEW_AREA")
	Advance(2)
end
local function Line(place)
	wow.Fire("UI_INFO_MESSAGE", 372, "Discovered: " .. place)
	Advance(2)
end
Check("Discovered card allowed on the stand-in", ns.CardAllowed("discover"))

-- 1: the game's line first (Redridge), then out over the border and back 57 s on.
Reset()
zone = "Redridge Mountains"
Line("Redridge Mountains")
Check("the game's line for a new zone: one card", #fired == 1 and fired[1] == "discover \"Redridge Mountains\"", Fired())
Advance(55)
Reset()
Enter("Elwynn Forest")
Enter("Redridge Mountains")
Check("back over the border 57 s on: no second card", #fired == 0, Fired())

-- 2: the zone entered first (Duskwood), then the game's line 57 s on.
Reset()
Enter("Duskwood")
Check("a new zone entered: one card", #fired == 1 and fired[1] == "discover \"Duskwood\"", Fired())
Advance(55)
Reset()
Line("Duskwood")
Check("its line 57 s on: no second card", #fired == 0, Fired())

-- 3: the map says new, the game's Exploration achievement says discovered.
Reset()
local PlaceExplored = ns.PlaceExplored
ns.PlaceExplored = function(place) if place == "Stranglethorn Vale" then return true end return PlaceExplored(place) end
Enter("Stranglethorn Vale")
ns.PlaceExplored = PlaceExplored
Check("a zone the game's explore count says discovered: no card", #fired == 0, Fired())

-- 4: a new subzone's line after all that still gets its card.
Reset()
zone = "Duskwood"
Line("Darkshire")
Check("a new subzone's line: its card", fired[1] == "discover \"Darkshire\"", Fired())

-- 5: kept per character: the places had a card are saved.
local found = ns.chardb.cardSeen.found or {}
Check("the places had a card saved", found["Redridge Mountains"] and found.Duskwood and found.Darkshire,
	"found " .. tostring(found["Redridge Mountains"]) .. "/" .. tostring(found.Duskwood) .. "/" .. tostring(found.Darkshire))

print(fails == 0 and "ALL PASS" or (fails .. " FAIL"))
if fails > 0 then os.exit(1) end
