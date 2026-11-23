-- The raised max zoom distance shared by the idle zoom and camera scripts,
-- every state (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-22-cameras-zoom-max.md):
--   python -I Tools/offline/run.py Tools/offline/zoommaxmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/zoommaxmatrix.lua --base bdb2e1d^ --new bdb2e1d
-- The max (cameraDistanceMaxZoomFactor) is raised to 2.6 by the idle zoom's
-- Past max (and the quest cam taking its zoom over), by a camera script's
-- Past max step, or both, in either order; or yours is already past it
-- (Graphics+, 3.0: never raised). Then one lets go first: the idle zoom's
-- side (ns.RestoreZoomLimit, as the quest cam puts it back), the script's
-- (ns.LowerZoomMax, its Finish), or a safety stop / logout (StopIdleZoomNow).
-- Then the rest let go. Each cell: the max after the first let-go and at the
-- end. The rule: raised while anyone still holds it (lowering it under the
-- other's camera, still out past your max, snaps it in), yours once nobody
-- does or after a stop; a Graphics+ max is never touched. (bdb2e1d: either
-- let-go put it back under the other.)

local client = arg and arg[1] or "forever"
local cvars = {}
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	GetCVar = function(name) return cvars[name] end
	SetCVar = function(name, value) cvars[name] = tostring(value) end
	GetCameraZoom = function() return 10 end
	-- luacheck: pop
end
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
ns.db.enabled = true

-- The idle zoom's raise: Camera.lua's own RaiseZoomMax (local), as its
-- StartIdleZoom calls it. Since bdb2e1d ns.RaiseZoomMax wraps it ("script");
-- before, ns.RaiseZoomMax was that same function.
local function Upvalue(fn, wanted)
	for i = 1, 40 do
		local name, value = debug.getupvalue(fn, i)
		if not name then return nil end
		if name == wanted and type(value) == "function" then return value end
	end
end
local RaiseIdle = Upvalue(ns.RaiseZoomMax, "RaiseZoomMax") or ns.RaiseZoomMax
local RAISE = {
	idle = function() RaiseIdle() end,
	script = function() ns.RaiseZoomMax() end,
}
local LETGO = {
	idle = function() ns.RestoreZoomLimit() end,
	script = function() ns.LowerZoomMax() end,
	stop = function() ns.StopIdleZoomNow() end,
}

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "zoom-max",
	fixed = { client = client },
	dims = {
		{ "yours", { "1.9", "3.0" } },
		{ "raised", { "idle", "script", "idle+script", "script+idle" } },
		{ "first", { "idle", "script", "stop" } },
	},
	cell = function(c)
		-- (Nobody holding it, yours in place.)
		ns.StopIdleZoomNow()
		ns.db.savedCVars.cameraDistanceMaxZoomFactor = nil
		cvars.cameraDistanceMaxZoomFactor = c.yours
		local who = {}
		for name in c.raised:gmatch("[^+]+") do
			who[#who + 1] = name
			RAISE[name]()
		end
		local function Max()
			local max = cvars.cameraDistanceMaxZoomFactor
			return max == c.yours and "yours" or max == "2.6" and "raised" or tostring(max)
		end
		LETGO[c.first]()
		local first = Max()
		-- (The rest let go too: each that raised it.)
		for _, name in ipairs(who) do
			if name ~= c.first then LETGO[name]() end
		end
		return ("first=%s end=%s"):format(first, Max())
	end,
	pins = {
		-- (One that held it let go and nobody else holds it, or a stop: yours.)
		{ "", "first=yours end=yours" },
		-- (The other still holds it: kept raised till it lets go.)
		{ "raised=idle first=script", "first=raised end=yours" },
		{ "raised=script first=idle", "first=raised end=yours" },
		{ "raised=idle+script first=idle", "first=raised end=yours" },
		{ "raised=idle+script first=script", "first=raised end=yours" },
		{ "raised=script+idle first=idle", "first=raised end=yours" },
		{ "raised=script+idle first=script", "first=raised end=yours" },
		-- (Yours already past it (Graphics+): never raised, never lowered.)
		{ "yours=3.0", "first=yours end=yours" },
	},
})
