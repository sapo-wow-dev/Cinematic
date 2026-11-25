-- The place (ns.GetPlaceType) by the game's events (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-event-fact-place.md):
--   python -I Tools/offline/run.py Tools/offline/eventplacematrix.lua [forever|retail] < /dev/null
-- Core.lua's ns.GetPlaceType asked the game where you are (the zone's name
-- against the capitals, IsInInstance, IsResting) every frame something
-- asked, ~21 callers: the rules, the per-place options, cards. The game
-- announces each change (ZONE_CHANGED*, PLAYER_ENTERING_WORLD after a
-- loading screen, PLAYER_UPDATE_RESTING). Each cell: where you start (the
-- open world, a capital, an inn, a dungeon, a raid, a battleground), on a
-- flight path or not, then nothing new or a move (to the open world; from
-- it, into a capital) with the game's events for it. The place right after,
-- still right a while later, and whether the game was asked again with
-- nothing new (polled). Right: the game's place (a capital or an inn: none
-- on a flight path), asked again only after its events.

local client = arg and arg[1] or "forever"
local now = 100
local where, taxi = "world", false
local reads, counting = 0, false
local function Count() if counting then reads = reads + 1 end end
local INSTANCE = { dungeon = "party", raid = "raid", pvp = "pvp" }
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	GetTime = function() return now end
	InCombatLockdown = function() return false end
	UnitAffectingCombat = function() return false end
	GetRealZoneText = function() Count() return where == "city" and "Stormwind City" or "Elwynn Forest" end
	IsInInstance = function()
		Count()
		local kind = INSTANCE[where]
		return kind ~= nil, kind or "none"
	end
	IsResting = function() Count() return where == "inn" or where == "city" end
	-- luacheck: pop
end
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
ns.cityNames = { ["Stormwind City"] = true }
ns.OnTaxi = function() return taxi end

-- The game's events for a move between two places.
local function Events(from, to)
	local fired = {}
	for _, place in ipairs({ from, to }) do
		local event = (INSTANCE[place] and "PLAYER_ENTERING_WORLD") or (place == "inn" and "PLAYER_UPDATE_RESTING")
			or "ZONE_CHANGED_NEW_AREA"
		if not fired[event] then fired[event] = true wow.Fire(event) end
	end
end
local function Place()
	return tostring(ns.GetPlaceType() or "none")
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "event-place",
	fixed = { client = client },
	dims = {
		{ "start", { "world", "city", "inn", "dungeon", "raid", "pvp" } },
		{ "taxi", { "no", "yes" } },
		{ "change", { "none", "move" } },
	},
	cell = function(c)
		-- Where the cell starts, the game's events as you got there.
		Events(where, c.start)
		where, taxi = c.start, c.taxi == "yes"
		Events(c.start, c.start)
		now = now + 1
		Place()
		if c.change == "move" then
			local to = c.start == "world" and "city" or "world"
			where = to
			Events(c.start, to)
		end
		now = now + 0.6 -- (past the settle after an event)
		local after = Place()
		counting, reads = true, 0
		for _ = 1, 3 do
			now = now + 1
			Place()
		end
		counting = false
		local later = Place()
		local want = (where == "world" or ((where == "city" or where == "inn") and taxi)) and "none" or where
		return ("after=%s later=%s right=%s polled=%s"):format(after, later, tostring(after == want and later == want),
			reads > 0 and "yes" or "no")
	end,
	pins = {
		-- (Right: the game's place, none on a flight from a capital or an inn,
		-- asked again only after its events.)
		{ "change=none start=world", "after=none later=none right=true polled=no" },
		{ "change=none start=city taxi=no", "after=city later=city right=true polled=no" },
		{ "change=none start=city taxi=yes", "after=none later=none right=true polled=no" },
		{ "change=none start=inn taxi=no", "after=inn later=inn right=true polled=no" },
		{ "change=none start=inn taxi=yes", "after=none later=none right=true polled=no" },
		{ "change=none start=dungeon", "after=dungeon later=dungeon right=true polled=no" },
		{ "change=none start=raid", "after=raid later=raid right=true polled=no" },
		{ "change=none start=pvp", "after=pvp later=pvp right=true polled=no" },
		{ "change=move", "after=none later=none right=true polled=no" },
		{ "change=move start=world taxi=no", "after=city later=city right=true polled=no" },
	},
})
