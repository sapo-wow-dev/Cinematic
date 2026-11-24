-- Far names smaller (Effects.lua ns.plates.FAR_NAME_CVARS), every state (the
-- audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-23-far-names-step.md):
--   python -I Tools/offline/run.py Tools/offline/farnamesmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/farnamesmatrix.lua --base <ref>
-- CineMode on or off, Name Style on or off, the Nameplates page (handlePlates)
-- on or off, outside or in an instance (plates not forced there), in a fight
-- or not (the set is secure: it waits for the fight's end). Each cell: the
-- plate settings the far step uses, as they are after a plate pass. The rule
-- (since 2026-11-23, "from your character"): in CineMode with every plate on,
-- names styled, Forever, the game's plates held one size (min = max = 1, the
-- distances yours); yours everywhere else. Far names is our own step past 28
-- yards from you. (Before: the game's camera step held there, min 0.65, 41 / 5.)

local client = arg and arg[1] or "forever"
local cvars = { nameplateMinScale = "1", nameplateMaxScale = "1", nameplateMaxScaleDistance = "10",
	nameplateMinScaleDistance = "10" }
local fighting, inside = false, false

local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	C_CVar = {
		SetCVar = function(name, value) if cvars[name] ~= nil then cvars[name] = tostring(value) end end,
		GetCVar = function(name) return cvars[name] end,
	}
	SetCVar = function(name, value) return C_CVar.SetCVar(name, value) end
	GetCVar = function(name) return cvars[name] end
	InCombatLockdown = function() return fighting end
	IsInInstance = function() return inside, inside and "party" or "none" end
	C_Timer.NewTicker = function() return { Cancel = function() end } end
	-- luacheck: pop
end

local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db
local far = ns.plates.FAR_NAME_CVARS
-- (The place, as the plate pass reads it: once a frame in the game, so
-- cached here where time stands still; the instance stand-in.)
ns.PlateSuffix = function() return inside and "Instances" or "World" end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	-- (Its own name on retail: the set is Forever's, no retail cell can change.)
	name = client == "retail" and "far-names-step-retail" or "far-names-step",
	fixed = { client = client },
	dims = {
		{ "cine", { "on", "off" } },
		{ "style", { "on", "off" } },
		{ "plates", { "on", "off" } },
		{ "place", { "outside", "instance" } },
		{ "fight", { "no", "yes" } },
	},
	cell = function(c)
		fighting, inside = false, false
		for _, set in ipairs(ns.cvarSets) do
			if set.active then ns.ApplyCVarSet(set, false) end
		end
		db.savedCVars = {}
		cvars.nameplateMinScale, cvars.nameplateMaxScale = "1", "1"
		cvars.nameplateMaxScaleDistance, cvars.nameplateMinScaleDistance = "10", "10"
		-- (style=on: names styled for real, Enable Style on too; with it off no
		-- names are drawn and nothing is held, the user OK'd 2026-11-23,
		-- Tools/audits/2026-11-23-far-names-style-gate.md.)
		db.plateNameStyle = c.style == "on"
		db.styleGeneral = c.style == "on"
		db.handlePlates = c.plates == "on"
		inside = c.place == "instance"
		fighting = c.fight == "yes"
		ns.plates.settled, ns.plates.quiet, ns.plates.rollOnly = nil, nil, nil
		local ok, err = pcall(ns.UpdatePlates, c.cine == "on", 0)
		if not ok then return "error: " .. tostring(err) end
		return ("min=%s max=%s maxDist=%s minDist=%s held=%s"):format(cvars.nameplateMinScale,
			cvars.nameplateMaxScale, cvars.nameplateMaxScaleDistance, cvars.nameplateMinScaleDistance,
			tostring(far.active or false))
	end,
	-- (Since 2026-11-23: the game's plates held ONE size in CineMode (its
	-- step went by the camera, so zooming moved it); Far names is our own step
	-- from you now, PlateParts. Yours everywhere else.)
	pins = {
		{ "", "min=1 max=1 maxDist=10 minDist=10 held=false" },
		{ "client=forever cine=on style=on plates=on place=outside fight=no", "min=1 max=1 maxDist=10 minDist=10 held=true" },
	},
})
