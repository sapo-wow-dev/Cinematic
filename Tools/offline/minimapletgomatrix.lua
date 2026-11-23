-- The minimap let go while Cinematic has it parked off the screen, every
-- state (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-22-frames-minimap-fight-letgo.md):
--   python -I Tools/offline/run.py Tools/offline/minimapletgomatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/minimapletgomatrix.lua --base <ref>
-- Parked shrunk (faded, shrunk to hide its arrow), parked full size (faded,
-- kept full size for a quest area or the dots sweep) or not parked; let go
-- (its Fade switch off: ns.StopFading) in a fight or not, protected (an
-- addon's secure button on it) or not, clamped to the screen or not, and laid
-- out again elsewhere by another addon before the fight ends or not.
-- Each cell: where it is right after it's let go (now), and once the fight's
-- over (end): parked (off the screen), home (its own spot), elsewhere (where
-- the other addon put it); its scale at the end (full/small) and whether it's
-- clamped again. The rule: never left off the screen. In a fight a protected
-- one can't be moved: it waits, and comes back as the fight ends.
-- (7c3e0c1: the full-size one had no waiter, off the screen till a reload.)

local client = arg and arg[1] or "forever"
local fight = false
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	InCombatLockdown = function() return fight end
	-- luacheck: pop
end
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)

-- (The minimap's anchors, scale and clamp kept; its protection per cell.)
local points, scale, clamped, protected = {}, 1, false, false
rawset(Minimap, "ClearAllPoints", function() points = {} end)
rawset(Minimap, "SetPoint", function(_, point, relativeTo, relativePoint, x, y)
	points[#points + 1] = { point, relativeTo, relativePoint, x, y }
end)
rawset(Minimap, "GetPoint", function(_, i)
	local p = points[i or 1]
	if p then return p[1], p[2], p[3], p[4], p[5] end
end)
rawset(Minimap, "GetNumPoints", function() return #points end)
rawset(Minimap, "IsProtected", function() return protected end)
rawset(Minimap, "SetScale", function(_, s) scale = s end)
rawset(Minimap, "GetScale", function() return scale end)
rawset(Minimap, "IsClampedToScreen", function() return clamped end)
rawset(Minimap, "SetClampedToScreen", function(_, on) clamped = on and true or false end)

local function Spot()
	local p = points[1]
	if not p then return "none" end
	if p[1] == "TOPLEFT" and p[3] == "TOPRIGHT" and type(p[4]) == "number" and p[4] > 10000 then return "parked" end
	if p[1] == "TOPRIGHT" and p[4] == -10 and p[5] == -12 then return "home" end
	if p[1] == "BOTTOM" then return "elsewhere" end
	return "other"
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "minimap-letgo",
	fixed = { client = client },
	dims = {
		{ "park", { "shrunk", "fullsize", "none" } },
		{ "fight", { "yes", "no" } },
		{ "protected", { "yes", "no" } },
		{ "clamped", { "yes", "no" } },
		{ "meanwhile", { "nothing", "laidout" } },
	},
	cell = function(c)
		ns.db.ignoredFrames.Minimap = nil
		fight, protected, clamped, scale = false, c.protected == "yes", c.clamped == "yes", 1
		points = { { "TOPRIGHT", UIParent, "TOPRIGHT", -10, -12 } }
		local entry = { frame = Minimap, name = "Minimap", baseAlpha = 1 }
		table.insert(ns.managed, entry)
		if c.park == "shrunk" then
			entry.shrunk, entry.savedScale = true, 1
			scale = 0.001
			ns.ParkShrunk(entry)
		elseif c.park == "fullsize" then
			ns.ParkFullSize(entry)
		end
		if c.park ~= "none" and Spot() ~= "parked" then return "not parked first: " .. Spot() end
		fight = c.fight == "yes"
		ns.StopFading("Minimap")
		local now = Spot()
		if c.meanwhile == "laidout" then
			points = { { "BOTTOM", UIParent, "BOTTOM", 0, 0 } }
		end
		fight = false
		wow.Fire("PLAYER_REGEN_ENABLED")
		local out = ("now=%s end=%s scale=%s"):format(now, Spot(), scale >= 0.5 and "full" or "small")
		if c.clamped == "yes" then out = out .. " clamp=" .. (clamped and "on" or "off") end
		-- (Whatever's left managed, out: the next cell starts clean.)
		for i = #ns.managed, 1, -1 do
			if ns.managed[i] == entry then table.remove(ns.managed, i) end
		end
		return out
	end,
	pins = {
		-- (Let go out of a fight, or not protected: back on its spot at once.)
		{ "", "now=home end=home scale=full" },
		{ "clamped=yes", "now=home end=home scale=full clamp=on" },
		-- (Never parked: not moved, and an addon laying it out wins.)
		{ "meanwhile=laidout", "now=home end=elsewhere scale=full" },
		{ "meanwhile=laidout clamped=yes", "now=home end=elsewhere scale=full clamp=on" },
		-- (Protected in a fight: not moved there; back as the fight ends.)
		{ "park=shrunk fight=yes protected=yes", "now=parked end=home scale=full" },
		{ "park=shrunk fight=yes protected=yes clamped=yes", "now=parked end=home scale=full clamp=on" },
		{ "park=fullsize fight=yes protected=yes", "now=parked end=home scale=full" },
		{ "park=fullsize fight=yes protected=yes clamped=yes", "now=parked end=home scale=full clamp=on" },
		-- (Laid out elsewhere meanwhile by another addon: left there, not pulled
		-- back to the spot saved before.)
		{ "park=shrunk fight=yes protected=yes meanwhile=laidout", "now=parked end=elsewhere scale=full" },
		{ "park=shrunk fight=yes protected=yes meanwhile=laidout clamped=yes",
			"now=parked end=elsewhere scale=full clamp=on" },
		{ "park=fullsize fight=yes protected=yes meanwhile=laidout", "now=parked end=elsewhere scale=full" },
		{ "park=fullsize fight=yes protected=yes meanwhile=laidout clamped=yes",
			"now=parked end=elsewhere scale=full clamp=on" },
	},
})
