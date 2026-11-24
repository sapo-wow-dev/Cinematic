-- The once-only haze update (Migrations.lua: ns.HazeToOneStrength, dofScaleV2)
-- on an old save, every state (the audit kit's matrix, Tools/offline/matrix.lua;
-- fix card Tools/audits/2026-11-23-haze-keep-picked.md):
--   python -I Tools/offline/run.py Tools/offline/hazekeepmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/hazekeepmatrix.lua --base <ref>
-- v2.1.27's haze: each camera mode's own strength (dofIdle... 2.5%, Walk and
-- Run 0) times Haze strength (dofScale, 100%), the haze seen = their product.
-- Now one Haze strength (0-100%, 0 to start with). The rule (the user,
-- 2026-11-23: "keep hand-picked haze"): a save at the old defaults gets the
-- new default, no haze; a haze you'd picked yourself is kept, the strongest
-- one you saw (at most 100%); the modes' own keys go either way.
-- (dev: the dev copy's dofStrengthV1 had raised the 2.5% to 15%, never in a
-- release; 15% there is a default too. The old code takes no second argument.)

local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")

local function Fmt(v)
	if v == nil then return "nil" end
	return ("%.4g"):format(v)
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "haze-keep-picked",
	fixed = { client = client },
	dims = {
		-- (Haze strength saved: none, the old default 100%, lowered 50%, raised 200%, off.)
		{ "scale", { "nil", "1", "0.5", "2", "0" } },
		-- (Standing still's own: none, 2.5%, 15% (dev), raised 30%, off.)
		{ "idle", { "nil", "0.025", "0.15", "0.3", "0" } },
		-- (Walk's own: the old default 0, or raised 10%.)
		{ "walk", { "0", "0.1" } },
		{ "dev", { "no", "yes" } },
	},
	cell = function(c)
		local t = { depthOfField = true, dofCozy = 0.025, dofVista = 0.025, dofFish = 0.025, dofFlight = 0.025,
			dofRun = 0 }
		if c.scale ~= "nil" then t.dofScale = tonumber(c.scale) end
		if c.idle ~= "nil" then t.dofIdle = tonumber(c.idle) end
		t.dofWalk = tonumber(c.walk)
		ns.HazeToOneStrength(t, c.dev == "yes")
		local left = {}
		for _, key in ipairs(ns.OLD_DOF_MODE_KEYS) do
			if t[key] ~= nil then left[#left + 1] = key end
		end
		return ("haze=%s modes=%s switch=%s"):format(Fmt(t.dofScale), #left == 0 and "gone" or table.concat(left, ","),
			tostring(t.depthOfField))
	end,
	pins = {
		-- (Nothing picked: the new default, no haze.)
		{ "", "haze=0 modes=gone switch=true" },
		-- (Walk raised to 10%, scale at 100% or none: 10%, the strongest picked.)
		{ "walk=0.1", "haze=0.1 modes=gone switch=true" },
		-- (Idle raised to 30%: 30% beats Walk's 10%.)
		{ "idle=0.3", "haze=0.3 modes=gone switch=true" },
		-- (15% outside the dev copy: picked by hand, kept; Walk's 10% under it.)
		{ "idle=0.15 dev=no", "haze=0.15 modes=gone switch=true" },
		-- (Idle off by hand, scale untouched: nothing raised, no haze; Walk's 10% if raised.)
		{ "idle=0 walk=0", "haze=0 modes=gone switch=true" },
		-- (Scale lowered to 50%: every mode at half, the strongest kept.)
		{ "scale=0.5", "haze=0.0125 modes=gone switch=true" },
		{ "scale=0.5 walk=0.1", "haze=0.05 modes=gone switch=true" },
		{ "scale=0.5 idle=0.15", "haze=0.075 modes=gone switch=true" },
		{ "scale=0.5 idle=0.3", "haze=0.15 modes=gone switch=true" },
		-- (Scale raised to 200%.)
		{ "scale=2", "haze=0.05 modes=gone switch=true" },
		{ "scale=2 idle=0.15", "haze=0.3 modes=gone switch=true" },
		{ "scale=2 walk=0.1", "haze=0.2 modes=gone switch=true" },
		{ "scale=2 walk=0.1 idle=0.15", "haze=0.3 modes=gone switch=true" },
		{ "scale=2 idle=0.3", "haze=0.6 modes=gone switch=true" },
		-- (Scale off: no haze anywhere, kept off.)
		{ "scale=0", "haze=0 modes=gone switch=true" },
	},
})
