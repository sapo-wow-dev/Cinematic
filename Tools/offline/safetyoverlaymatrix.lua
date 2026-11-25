-- A safety stop (ns.Suspend: an error that kept repeating, /cine panic) and
-- what's left on screen, every state (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-safety-stop-overlays.md):
--   python -I Tools/offline/run.py Tools/offline/safetyoverlaymatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/safetyoverlaymatrix.lua --base <ref>
-- An overlay showing as the stop comes: Teleport Vision's test, Death
-- Vision's test, a Zone card; or none.
-- Each cell: whether it's on screen right after the stop, and a few seconds
-- after /cine resume.
-- The rule (overlay audit 2026-11-25, from a player's stuck teleport filter):
-- a safety stop puts away everything Cinematic draws, tests included; after
-- /cine resume nothing comes back that its own moment hasn't brought again.

local client = arg and arg[1] or "forever"
local now = 100
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function(stand)
	-- luacheck: push ignore 111 112 113 121 122
	GetTime = function() return now end
	-- (The frames these files make, to run only their loops.)
	local Create = CreateFrame
	CreateFrame = function(...)
		local frame = Create(...)
		local source = debug and debug.getinfo and debug.getinfo(2, "S")
		local file = source and tostring(source.source) or ""
		if file:find("TeleportVision.lua", 1, true) or file:find("/Cards.lua", 1, true)
			or file:find("CombatVision.lua", 1, true) then
			stand.ours = stand.ours or {}
			stand.ours[#stand.ours + 1] = frame
		end
		return frame
	end
	-- luacheck: pop
end)
ns.suspendQuiet = true
local db = ns.db
db.enabled, db.teleportVision, db.deathScreen, db.cards, db.storyZoneCard = true, true, true, true, true

local function Run(seconds)
	ns.SyncFeatureLoops()
	for _ = 1, math.floor(seconds * 10 + 0.5) do
		now = now + 0.1
		for _, frame in ipairs(wow.ours or {}) do
			local update = frame._scripts and frame._scripts.OnUpdate
			if update then pcall(update, frame, 0.1) end
		end
	end
	-- (The death screen is drawn by the tint's step: once, all the way. Every
	-- tick took minutes.)
	if ns.UpdateTint then pcall(ns.UpdateTint, ns.lastCinematic, 1e6) end
end

local function Card()
	local screen = _G.CinematicCard
	local over = screen and screen.cue and screen.cue.over
	return over and over:IsShown() and screen:GetScript("OnUpdate") ~= nil
end
local SHOWN = {
	teleport = function() return ns.TeleportVisionShown() end,
	death = function() local f = ns.DeathScreenFrame and ns.DeathScreenFrame() return f and f:IsShown() end,
	card = Card,
	none = function() return false end,
}

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "safety-stop-overlays",
	fixed = { client = client },
	dims = {
		{ "overlay", { "teleport", "death", "card", "none" } },
	},
	cell = function(c)
		now = now + 100
		if ns.IsSuspended() then ns.Resume() end
		Run(2)
		if c.overlay == "teleport" then
			ns.TestTeleportVision(2, true)
		elseif c.overlay == "death" then
			ns.TestDeathVision()
		elseif c.overlay == "card" then
			-- (A plain card: the sample's stand-in name hung the card offline.)
			ns.Cards.Fire("zone", { name = "Elwynn Forest", sub = "" }, true)
		end
		Run(1)
		local Shown = SHOWN[c.overlay]
		if c.overlay ~= "none" and not Shown() then return "never shown" end
		ns.Suspend("matrix")
		local stopped = Shown() and "shown" or "hidden"
		ns.Resume()
		Run(2)
		local out = ("stop=%s resume=%s"):format(stopped, Shown() and "shown" or "hidden")
		-- (Whatever's left ended for the next cell.)
		if ns.TeleportVisionTesting() then ns.TestTeleportVision() end
		if ns.DeathVisionTesting and ns.DeathVisionTesting() then ns.TestDeathVision() end
		Run(5)
		return out
	end,
	pins = {
		{ "", "stop=hidden resume=hidden" },
	},
})
