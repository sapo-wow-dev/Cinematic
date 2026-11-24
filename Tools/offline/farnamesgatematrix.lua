-- Plates one size (Effects.lua ns.plates.FarWanted / FAR_NAME_CVARS) by the
-- Style switch tree, every state (the audit kit's matrix, Tools/offline/matrix.lua;
-- fix card Tools/audits/2026-11-23-far-names-style-gate.md):
--   python -I Tools/offline/run.py Tools/offline/farnamesgatematrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/farnamesgatematrix.lua --base <ref>
-- CineMode on or off, the Nameplates page (every plate on: platesForced) on or
-- off, Enable Style on or off, the Style part loaded or left out (ns.Module),
-- Name Style on, off or never set, the name jump test's walk without it
-- (ns.farNamesTestOff). Each cell: whether the set is held after a plate pass.
-- The rule: held only where our names over heads are drawn (PlateParts styles
-- them on ns.StyleOn() and Name Style, its default when unset), every plate
-- on, Forever, the test not holding it off. A page switch off gates all.

local client = arg and arg[1] or "forever"
local cvars = { nameplateMinScale = "0.8", nameplateMaxScale = "1", nameplateMaxScaleDistance = "10",
	nameplateMinScaleDistance = "10" }

local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	C_CVar = {
		SetCVar = function(name, value) if cvars[name] ~= nil then cvars[name] = tostring(value) end end,
		GetCVar = function(name) return cvars[name] end,
		GetCVarDefault = function() return "10" end,
	}
	SetCVar = function(name, value) return C_CVar.SetCVar(name, value) end
	GetCVar = function(name) return cvars[name] end
	InCombatLockdown = function() return false end
	IsInInstance = function() return false, "none" end
	C_Timer.NewTicker = function() return { Cancel = function() end } end
	-- luacheck: pop
end

local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db
local far = ns.plates.FAR_NAME_CVARS
ns.PlateSuffix = function() return "World" end
db.farNamesLeftoversV2 = true -- (the leftovers cleanup aside: its own matrix)

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = client == "retail" and "far-names-gate-retail" or "far-names-gate",
	fixed = { client = client },
	dims = {
		{ "cine", { "on", "off" } },
		{ "plates", { "on", "off" } },
		{ "styleGeneral", { "on", "off" } },
		{ "module", { "loaded", "out" } },
		{ "nameStyle", { "on", "off", "unset" } },
		{ "testOff", { "no", "yes" } },
	},
	cell = function(c)
		for _, set in ipairs(ns.cvarSets) do
			if set.active then ns.ApplyCVarSet(set, false) end
		end
		db.savedCVars = {}
		cvars.nameplateMinScale, cvars.nameplateMaxScale = "0.8", "1"
		db.handlePlates = c.plates == "on"
		db.styleGeneral = c.styleGeneral == "on"
		ns.LEFT_OUT_SWITCHES.styleGeneral = c.module == "out" or nil
		if c.nameStyle == "unset" then db.plateNameStyle = nil else db.plateNameStyle = c.nameStyle == "on" end
		ns.farNamesTestOff = c.testOff == "yes" or nil
		ns.plates.settled, ns.plates.quiet, ns.plates.rollOnly = nil, nil, nil
		local ok, err = pcall(ns.UpdatePlates, c.cine == "on", 0)
		ns.LEFT_OUT_SWITCHES.styleGeneral, ns.farNamesTestOff = nil, nil
		if not ok then return "error: " .. tostring(err) end
		return ("held=%s min=%s"):format(tostring(far.active or false), cvars.nameplateMinScale)
	end,
	pins = {
		{ "", "held=false min=0.8" },
		{ "client=forever cine=on plates=on styleGeneral=on module=loaded nameStyle=on testOff=no", "held=true min=1" },
		{ "client=forever cine=on plates=on styleGeneral=on module=loaded nameStyle=unset testOff=no", "held=true min=1" },
	},
})
