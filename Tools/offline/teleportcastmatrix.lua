-- Teleport Vision as a Hearthstone cast ends, every state (the audit kit's
-- matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-25-teleport-lost-end.md):
--   python -I Tools/offline/run.py Tools/offline/teleportcastmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/teleportcastmatrix.lua --base <ref>
-- A 10-second Hearthstone cast, its scene playing; as it ends: the game's
-- SUCCEEDED, a STOP, or no end event at all (lost); a loading screen or not;
-- the game still saying you're casting or not; looked at 0.5 s or 10 s after
-- the cast's end. Each cell: the portal shown or hidden, your cast bar held
-- faded or not, the tooltip's alpha.
-- The rule (a player 2026-11-25: a gray filter stuck after a teleport to
-- Stormwind till Alt+F4): however the cast ends, or if its end never comes,
-- the portal goes and the cast bar and tooltip come back, unless the game
-- still says you're casting (and no loading screen took you away).

local client = arg and arg[1] or "forever"
local now = 100
local casting = false
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function(stand)
	-- luacheck: push ignore 111 112 113 121 122
	GetTime = function() return now end
	UnitCastingInfo = function(unit)
		if unit == "player" and casting then return "Hearthstone", "", "", 100000, 110000 end
	end
	local bar = stand.CreateFrame("StatusBar", "PlayerCastingBarFrame", UIParent)
	bar:Show()
	-- (The frames Teleport Vision's file makes, to run only their loops: all
	-- of them every tick took minutes.)
	local Create = CreateFrame
	CreateFrame = function(...)
		local frame = Create(...)
		local source = debug and debug.getinfo and debug.getinfo(2, "S")
		if source and tostring(source.source):find("TeleportVision", 1, true) then
			stand.teleFrames = stand.teleFrames or {}
			stand.teleFrames[#stand.teleFrames + 1] = frame
		end
		return frame
	end
	-- luacheck: pop
end)
local alpha = { tip = 1, bar = 1 }
rawset(GameTooltip, "SetAlpha", function(_, a) alpha.tip = a end)
local castBar = _G.PlayerCastingBarFrame
rawset(castBar, "SetAlpha", function(_, a) alpha.bar = a end)
local db = ns.db
db.teleportVision, db.teleportVisionHideCast, db.teleportVisionFadeTooltip = true, true, true

if not wow.teleFrames then error("no Teleport Vision frames found (debug.getinfo missing?)") end
-- Teleport Vision's update loops (its driver and the cast bar fader are local
-- to its file), a tenth of a second at a time.
local function Run(seconds)
	ns.SyncFeatureLoops()
	for _ = 1, math.floor(seconds * 10 + 0.5) do
		now = now + 0.1
		for _, frame in ipairs(wow.teleFrames or {}) do
			local update = frame._scripts and frame._scripts.OnUpdate
			if update then pcall(update, frame, 0.1) end
		end
	end
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "teleport-cast-end",
	fixed = { client = client },
	dims = {
		{ "ending", { "succeeded", "stop", "lost" } },
		{ "loading", { "yes", "no" } },
		{ "casting", { "yes", "no" } },
		{ "after", { "soon", "late" } },
	},
	cell = function(c)
		-- (Nothing left from the cell before.)
		now = now + 100
		ns.departCast = nil
		casting = false
		Run(3)
		alpha.tip, alpha.bar = 1, 1
		castBar.cinematicTeleHidden = nil

		local start = now
		casting = true
		wow.Fire("UNIT_SPELLCAST_START", "player", "guid", 8690)
		if not ns.departCast then return "no cast noted" end
		ns.departCast.startAt, ns.departCast.endsAt, ns.departCast.scene = start, start + 10, true
		Run(9.9)
		if not ns.TeleportVisionShown() then return "never shown" end
		-- (The cast's end.)
		casting = c.casting == "yes"
		if c.ending == "succeeded" then
			wow.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 8690)
		elseif c.ending == "stop" then
			wow.Fire("UNIT_SPELLCAST_STOP", "player", "guid", 8690)
		end
		if c.loading == "yes" then
			wow.Fire("LOADING_SCREEN_ENABLED")
			wow.Fire("PLAYER_LEAVING_WORLD")
		end
		Run(c.after == "soon" and 0.5 or 10)
		local out = ("portal=%s bar=%s tip=%s"):format(ns.TeleportVisionShown() and "shown" or "hidden",
			castBar.cinematicTeleHidden and "held" or "free", alpha.tip < 0.5 and "faded" or "full")
		casting = false
		ns.departCast = nil
		Run(3)
		return out
	end,
	pins = {
		-- (Late: gone, everything back.)
		{ "after=late", "portal=hidden bar=free tip=full" },
		-- (Still casting, no loading screen, its end not come or a STOP the
		-- game ignores while casting: the cast goes on.)
		{ "ending=stop loading=no casting=yes after=late", "portal=shown bar=held tip=faded" },
		{ "ending=lost loading=no casting=yes after=late", "portal=shown bar=held tip=faded" },
		-- (Soon after: still on its way out, or still on.)
		{ "after=soon", "portal=shown bar=held tip=faded" },
		-- (Stopped: opening back out, cast bar and tooltip given back at once.)
		{ "ending=stop casting=no after=soon", "portal=shown bar=free tip=full" },
	},
})
