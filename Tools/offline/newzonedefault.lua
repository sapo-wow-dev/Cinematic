-- New zone card off by default (dev tool, offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/newzonedefault.lua < /dev/null
-- 2026-11-23, the user's screenshot: Dun Morogh new to a character, with
-- Discovered ticked, slammed the big New zone card ("DUN MOROGH") where the
-- small Discovered card was wanted. New zone is off to start with now, and
-- turned off once for everyone (Migrations.lua newZoneOffV1). On the
-- stand-in: a fresh install's new zone gets Discovered's card; the update
-- turns New zone off here and in saved profiles and reset points, once; ticked
-- again it stays on, and the big card comes back. PASS or FAIL per check.
-- (Optional first argument: another .toc to load, to run it on older code.)
local now = 100
local timers = {}
local zone = "Coldridge Valley"

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
	C_Map = { GetBestMapForUnit = function() return 27 end }
	-- (One area explored: the game says the zone is new to you.)
	C_MapExplorationInfo = { GetExploredMapTextures = function() return { {} } end }
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

-- 1: a fresh install: New zone off.
Check("New zone off to start with (DEFAULTS)", ns.DEFAULTS.cardNewZoneOn == false, tostring(ns.DEFAULTS.cardNewZoneOn))
Check("New zone off in a fresh install's settings", not ns.db.cardNewZoneOn, tostring(ns.db.cardNewZoneOn))

local fired = {}
local Fire = ns.Cards.Fire
ns.Cards.Fire = function(id, card, ...)
	fired[#fired + 1] = id .. " \"" .. tostring(card and card.name) .. "\""
	return Fire(id, card, ...)
end
local function Fired() return #fired == 0 and "none" or table.concat(fired, ", ") end
local function NewZone(name)
	for _, id in ipairs({ "discover", "newZone" }) do pcall(ns.Cards.Cut, id) end
	Advance(40)
	fired = {}
	zone = name
	wow.Fire("ZONE_CHANGED_NEW_AREA")
	Advance(5)
end

-- 2: Discovered ticked, a whole new zone: Discovered's small card.
ns.db.cards = true
ns.db.cardDiscoverOn = true
ns.chardb.cardSeen = { zones = { ["Coldridge Valley"] = true }, instances = {} }
NewZone("Dun Morogh")
Check("a new zone with New zone off: Discovered's card", fired[1] == "discover \"Dun Morogh\"", Fired())

-- 3: the update, on a player who had it on (here, a profile, a reset point).
ns.db.cardNewZoneOn, ns.db.newZoneOffV1 = true, nil
ns.db.profiles = ns.db.profiles or {}
ns.db.profiles.TestNewZone = { cardNewZoneOn = true }
ns.db.profileResetPoints = ns.db.profileResetPoints or {}
ns.db.profileResetPoints.TestNewZone = { cardNewZoneOn = true }
ns.db.profiles.TestNoKey = { cards = true }
ns.RunMigrations()
Check("the update turns it off", ns.db.cardNewZoneOn == false, tostring(ns.db.cardNewZoneOn))
Check("...in a saved profile", ns.db.profiles.TestNewZone.cardNewZoneOn == false)
Check("...in a reset point", ns.db.profileResetPoints.TestNewZone.cardNewZoneOn == false)
Check("...a profile without the key left without it", ns.db.profiles.TestNoKey.cardNewZoneOn == nil)
Check("...marked done", ns.db.newZoneOffV1 == true)

-- 4: ticked again, it stays: the update runs once.
ns.db.cardNewZoneOn = true
ns.RunMigrations()
Check("ticked again after the update: stays on", ns.db.cardNewZoneOn == true)
NewZone("Loch Modan")
Check("and the big New zone card comes back", fired[1] == "newZone \"Loch Modan\"", Fired())

ns.db.profiles.TestNewZone, ns.db.profiles.TestNoKey, ns.db.profileResetPoints.TestNewZone = nil, nil, nil
print(fails == 0 and "ALL PASS" or (fails .. " FAIL"))
if fails > 0 then os.exit(1) end
