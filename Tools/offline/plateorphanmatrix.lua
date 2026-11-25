-- Plate parts held on a plate that isn't up (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-plate-orphan-parts.md):
--   python -I Tools/offline/run.py Tools/offline/plateorphanmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/plateorphanmatrix.lua forever --base <ref>
-- A plate's parts faded (to 0 or 0.4), then the plate still up, or gone with
-- no removal heard (not in C_NamePlate.GetNamePlates any more), then the
-- keeper's half-second sweep. Each cell: the part still held (and at what
-- alpha) or let go back to the game's own. The rule: a part no shown plate
-- has is let go, as a removed plate's are (the in-game gating test run 7, 2026-11-25:
-- 54 parts held at 0 on plates no longer up, the keeper on for them for good).
local client = arg and arg[1] or "forever"
local shown = {}
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	C_NamePlate = C_NamePlate or {}
	C_NamePlate.GetNamePlates = function()
		local list = {}
		for plate in pairs(shown) do list[#list + 1] = plate end
		return list
	end
	-- luacheck: pop
end
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local kept = ns.platePartsKept
local now = 100
GetTime = function() return now end -- luacheck: ignore 121

local function Part()
	local f = { a = 1 }
	f.GetAlpha = function(self) return self.a end
	f.SetAlpha = function(self, a) self.a = a end
	f.IsShown = function() return true end
	f.IsForbidden = function() return false end
	return f
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "plate-orphan-parts",
	fixed = { client = client },
	dims = {
		{ "plate", { "up", "gone" } },
		{ "faded", { "0", "0.4" } },
	},
	cell = function(c)
		wipe(shown)
		for frame in pairs(kept.held) do kept.Fade(frame, 1) end
		local unitFrame = { HealthBarsContainer = Part(), name = Part() }
		local plate = { UnitFrame = unitFrame }
		shown[plate] = true
		local level = tonumber(c.faded)
		for _, frame in ipairs(ns.PlatePartFrames(unitFrame, "Health")) do kept.Fade(frame, level) end
		if c.plate == "gone" then shown[plate] = nil end
		now = now + 1
		kept.Tick(kept.keeper)
		local frame = unitFrame.HealthBarsContainer
		if kept.held[frame] then return ("held %.1f"):format(frame.a) end
		return ("let go %.1f"):format(frame.a)
	end,
	pins = {
		{ "plate=up faded=0", "held 0.0" },
		{ "plate=up faded=0.4", "held 0.4" },
		{ "plate=gone", "let go 1.0" },
	},
})
