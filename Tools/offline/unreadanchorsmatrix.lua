-- The minimap parked off the screen and put back when its anchors can't be
-- read, every state (the audit kit's matrix, Tools/offline/matrix.lua; fix
-- card Tools/audits/2026-11-23-frames-unread-anchors.md):
--   python -I Tools/offline/run.py Tools/offline/unreadanchorsmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/unreadanchorsmatrix.lua --base <ref>
-- Faded and parked shrunk or full size; its anchors readable, their count
-- secret (a fight on WoW Forever, another addon's anchors), the count refused
-- (an error), an anchor refused (GetPoint errors) or none at all (zero); that
-- as it's parked (park) or as it's let go (letgo); and, unreadable as it's
-- parked, the pass trying again once they read (retry yes) or not.
-- Each cell: where it is while faded (fade), right after it's let go (end),
-- and once it reads again and a fight's end has fired (later): parked (off
-- the screen), home (its own spot), none (no anchors at all: lost).
-- The rule: never cleared to no anchors, never left off the screen once let
-- go. (ae2cda8: a secret count read as 0 parked it with no anchors saved and
-- gave it none back: off the screen till a reload.)

local client = arg and arg[1] or "forever"
local SECRET = setmetatable({}, { __tostring = function() return "secret" end })
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	issecretvalue = function(v) return v == SECRET end
	-- luacheck: pop
end
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)

-- (The minimap's anchors, and how they read now.)
local points, mode = {}, "readable"
rawset(Minimap, "ClearAllPoints", function() points = {} end)
rawset(Minimap, "SetPoint", function(_, point, relativeTo, relativePoint, x, y)
	points[#points + 1] = { point, relativeTo, relativePoint, x, y }
end)
rawset(Minimap, "GetPoint", function(_, i)
	if mode == "pointrefused" then error("refused") end
	local p = points[i or 1]
	if p then return p[1], p[2], p[3], p[4], p[5] end
end)
rawset(Minimap, "GetNumPoints", function()
	if mode == "countsecret" then return SECRET end
	if mode == "countrefused" then error("refused") end
	return #points
end)
rawset(Minimap, "IsProtected", function() return false end)
rawset(Minimap, "SetScale", function() end)

local function Spot()
	local p = points[1]
	if not p then return "none" end
	if p[1] == "TOPLEFT" and p[3] == "TOPRIGHT" and type(p[4]) == "number" and p[4] > 10000 then return "parked" end
	if p[1] == "TOPRIGHT" and p[4] == -10 and p[5] == -12 then return "home" end
	return "other"
end

local function Park(c, entry)
	if c.park == "shrunk" then
		-- (The pass's re-park: ns.ParkShrunk once it's undone, or as it shrinks.)
		if not entry.shrunk then
			entry.shrunk, entry.savedScale = true, 1
			ns.ParkShrunk(entry)
		elseif ns.ParkUndone(entry) then
			ns.ParkShrunk(entry)
		end
	else
		ns.ParkFullSize(entry)
	end
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "unread-anchors",
	fixed = { client = client },
	dims = {
		{ "park", { "shrunk", "fullsize" } },
		{ "anchors", { "readable", "countsecret", "countrefused", "pointrefused", "zero" } },
		{ "when", { "park", "letgo" } },
		{ "retry", { "yes", "no" } },
	},
	cell = function(c)
		ns.db.ignoredFrames.Minimap = nil
		mode = "readable"
		points = { { "TOPRIGHT", UIParent, "TOPRIGHT", -10, -12 } }
		local entry = { frame = Minimap, name = "Minimap", baseAlpha = 1 }
		table.insert(ns.managed, entry)
		local function Unread()
			if c.anchors == "zero" then points = {} else mode = c.anchors end
		end
		if c.when == "park" then Unread() end
		local ok, err = pcall(Park, c, entry)
		if not ok then return "park error: " .. tostring(err) end
		mode = "readable"
		if c.retry == "yes" then
			ok, err = pcall(Park, c, entry)
			if not ok then return "retry error: " .. tostring(err) end
		end
		local fade = Spot()
		if c.when == "letgo" then Unread() end
		ok, err = pcall(ns.StopFading, "Minimap")
		mode = "readable"
		if not ok then return "letgo error: " .. tostring(err) end
		local out = ("fade=%s end=%s"):format(fade, Spot())
		wow.Fire("PLAYER_REGEN_ENABLED")
		out = out .. " later=" .. Spot()
		for i = #ns.managed, 1, -1 do
			if ns.managed[i] == entry then table.remove(ns.managed, i) end
		end
		return out
	end,
	pins = {
		-- (Read fine: off the screen while faded, home once let go.)
		{ "", "fade=parked end=home later=home" },
		-- (Unread as it's parked: left where it is, never cleared...)
		{ "when=park retry=no", "fade=home end=home later=home" },
		-- (...and parked once they read again.)
		{ "when=park retry=yes", "fade=parked end=home later=home" },
		{ "anchors=readable", "fade=parked end=home later=home" },
		-- (No anchors at all: nothing to park it from or put back; left so.)
		{ "anchors=zero when=park", "fade=none end=none later=none" },
		-- (Its anchors cleared by someone else while it's faded: left so.)
		{ "anchors=zero when=letgo", "fade=parked end=none later=none" },
		-- (An anchor refused as it's let go: it can't be moved then; back once
		-- it can.)
		{ "anchors=pointrefused when=letgo", "fade=parked end=parked later=home" },
	},
})
