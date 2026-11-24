-- A dungeon named like the place at its door, every state (the audit kit's
-- matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-23-discover-same-name.md):
--   python -I Tools/offline/run.py Tools/offline/discoversamenamematrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/discoversamenamematrix.lua --base <ref>
-- Zul'Farrak is a subzone of Tanaris (the game's "Discovered: Zul'Farrak"
-- line at its door) and a dungeon of the same name. The outdoor place's line
-- first or the dungeon first, the other 10 s on (within Discovered's 30 s
-- skip) or 60 s on (after it), the dungeon new to you or seen before.
-- Each cell: the Discovered cards that played, the outdoor place's and the
-- dungeon's. The rule (release review 2026-11-23): an instance and a
-- same-named outdoor place each get their card once; a dungeon seen before
-- none.
local client = arg and arg[1] or "forever"
local now = 100
local timers = {}
local zone, inside, instanceName, instanceID = "Tanaris", false, nil, nil

-- luacheck: push ignore 111 112 113 121 122 212
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function()
	GetTime = function() return now end
	C_Timer.After = function(seconds, fn) timers[#timers + 1] = { at = now + (seconds or 0), fn = fn } end
	ERR_ZONE_EXPLORED = "Discovered: %s"
	ERR_ZONE_EXPLORED_XP = "Discovered %s: %d experience gained"
	GetRealZoneText = function() return zone end
	GetSubZoneText = function() return "" end
	IsInInstance = function() return inside, inside and "party" or "none" end
	GetInstanceInfo = function() return instanceName, inside and "party" or "none", 1, "Normal", 5, 0, false, instanceID end
	C_Map = { GetBestMapForUnit = function() return 71 end }
	C_MapExplorationInfo = { GetExploredMapTextures = function() return { 1, 2, 3 } end }
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

ns.db.cards = true
ns.db.cardDiscoverOn = true
ns.db.cardNewZoneOn = true
local fired = {}
local Fire = ns.Cards.Fire
ns.Cards.Fire = function(id, card, ...)
	fired[#fired + 1] = { id = id, sub = card and card.sub or "" }
	return Fire(id, card, ...)
end
local function Loading(newZone, isInside, name, id)
	zone, inside, instanceName, instanceID = newZone, isInside, name, id
	wow.Fire("PLAYER_ENTERING_WORLD", false, false)
	Advance(3)
end
local function Outdoor()
	zone = "Tanaris"
	wow.Fire("UI_INFO_MESSAGE", 372, "Discovered: Zul'Farrak")
	Advance(2)
end
local function Instance()
	Loading("Zul'Farrak", true, "Zul'Farrak", 209)
	Loading("Tanaris", false)
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "discover-samename",
	fixed = { client = client },
	dims = {
		{ "first", { "outdoor", "instance" } },
		{ "gap", { "within", "after" } },
		{ "dungeon", { "new", "seen" } },
	},
	cell = function(c)
		for _, id in ipairs({ "discover", "newZone" }) do pcall(ns.Cards.Cut, id) end
		Advance(100) -- (Discovered's 30 s skip over from the cell before)
		ns.chardb.cardSeen = { zones = { Tanaris = true }, instances = c.dungeon == "seen" and { [209] = true } or {} }
		fired = {}
		local outdoor, instance = 0, 0
		local function Count()
			for _, f in ipairs(fired) do
				if f.id ~= "discover" then
					outdoor = outdoor + 100 -- (any other card: shows in the outcome)
				elseif f.sub == "Dungeon" then
					instance = instance + 1
				else
					outdoor = outdoor + 1
				end
			end
			fired = {}
		end
		if c.first == "outdoor" then Outdoor() else Instance() end
		Count()
		Advance(c.gap == "within" and 10 or 60)
		for _, id in ipairs({ "discover", "newZone" }) do pcall(ns.Cards.Cut, id) end
		if c.first == "outdoor" then Instance() else Outdoor() end
		Count()
		return ("outdoor=%d instance=%d"):format(outdoor, instance)
	end,
	pins = {
		-- (Each its card once: the outdoor place's line and the new dungeon.)
		{ "", "outdoor=1 instance=1" },
		-- (A dungeon seen before: no card for it, the outdoor place's still.)
		{ "dungeon=seen", "outdoor=1 instance=0" },
	},
})
