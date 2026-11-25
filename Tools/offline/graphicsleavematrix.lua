-- Graphics+ as Atmosphere is left out (the audit kit's matrix, Tools/offline/matrix.lua;
-- fix card Tools/audits/2026-11-25-graphics-plus-leave.md):
--   python -I Tools/offline/run.py Tools/offline/graphicsleavematrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/graphicsleavematrix.lua forever --base <ref>
-- A Graphics+ setting written (Terrain detail up), then Load Atmosphere kept
-- or unticked with Later picked (the part still running till the reload),
-- Graphics Boost's page on or off, then what comes next before the reload: a
-- fight ending or the settings applied again (a page, a profile). Each cell:
-- the game's setting, "ours" (still raised) or "game" (its own value back).
-- The rule: unticked, the game's own value is back and stays back, as after
-- the reload no Atmosphere code is there to put it back.
local client = arg and arg[1] or "forever"
local cvars = {}
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	GetCVar = function(name) return cvars[name] or "0" end
	SetCVar = function(name, value) cvars[name] = tostring(value) end
	C_CVar = C_CVar or {}
	C_CVar.GetCVar = GetCVar
	C_CVar.SetCVar = SetCVar
	InCombatLockdown = function() return false end
	-- luacheck: pop
end
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db
local CVAR, GAME, OURS = "terrainLodDist", "650", "1500"

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "graphicsplus-leave",
	fixed = { client = client },
	dims = {
		{ "load", { "kept", "unticked" } },
		{ "page", { "on", "off" } },
		{ "next", { "fightEnds", "applied" } },
	},
	cell = function(c)
		-- (Every cell from the same start: ours written over the game's own.)
		if ns.GraphicsPlusPutBack then ns.GraphicsPlusPutBack() end
		ns.SetModuleWanted("atmosphere", true)
		cvars[CVAR] = GAME
		db.visualEffects, db.graphicsPlus = true, true
		db.graphicsPlusTerrainOn, db.graphicsPlusTerrain = true, tonumber(OURS)
		ns.ApplyGraphicsPlus()
		if cvars[CVAR] ~= OURS then return "not written: " .. tostring(cvars[CVAR]) end
		if c.load == "unticked" then ns.SetModuleWanted("atmosphere", false) end
		if c.page == "off" then
			db.graphicsPlus = false
			ns.ApplyGraphicsPlus()
		end
		if c.next == "fightEnds" then
			wow.Fire("PLAYER_REGEN_ENABLED")
		else
			ns.ApplyGraphicsPlus()
		end
		local now = cvars[CVAR]
		return now == OURS and "ours" or now == GAME and "game" or ("other " .. tostring(now))
	end,
	pins = {
		{ "", "game" }, -- (unticked or the page off: the game's own)
		{ "load=kept page=on", "ours" },
	},
})
ns.SetModuleWanted("atmosphere", true)
