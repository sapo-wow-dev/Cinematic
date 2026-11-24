-- What was open, opened again after a /reload, with or without a fight, every
-- state (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-23-reload-fight-lift.md):
--   python -I Tools/offline/run.py Tools/offline/reloadfightmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/reloadfightmatrix.lua forever --base <ref>
-- QoL/Reload.lua's restore (reloadKeepWindows): a reload in a fight or out of
-- one; the game's combat restriction (C_RestrictedActions, Combat) lifted with
-- PLAYER_REGEN_ENABLED or a moment after it (ADDON_RESTRICTION_STATE_CHANGED);
-- "Windows you have open reopen" left on or turned off during the fight.
-- Then a second fight starts and ends.
-- Each cell: how many things (a window, the bags) opened at the reload, at
-- REGEN_ENABLED, when the restriction lifted, and at the next fight's end.
-- Right: out of a fight, at once; in one, once the restriction is off (no
-- later than its lifting), and nothing if the tick was turned off meanwhile;
-- never at the next fight.

local client = arg and arg[1] or "forever"
local inFight, restricted = false, false
local opened = 0
local keep = true
-- luacheck: push ignore 111 112 113 121 122 212
local ns, wow = dofile("Tools/offline/load.lua")(client, nil, function()
	InCombatLockdown = function() return inFight end
	C_Timer.After = function(_, fn) fn() end
	OpenAllBags = function() opened = opened + 1 end
	ToggleFriendsFrame = function() opened = opened + 1 end
	C_RestrictedActions = { IsAddOnRestrictionActive = function(kind) return kind == 0 and restricted end }
	Enum = Enum or {}
	Enum.AddOnRestrictionType = { Combat = 0 }
	GetBindingKey = function() end
end)
-- luacheck: pop
local setting = ns.Setting
ns.Setting = function(key) if key == "reloadKeepWindows" then return keep end return setting(key) end
local fire = wow.Fire

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = client == "retail" and "reload-fight-lift-retail" or "reload-fight-lift",
	fixed = { client = client },
	dims = {
		{ "reloadIn", { "fight", "calm" } },
		{ "lift", { "withregen", "late" } },
		{ "keep", { "on", "turnedoff" } },
	},
	cell = function(c)
		keep, opened = true, 0
		inFight = c.reloadIn == "fight"
		restricted = inFight
		ns.db.reloadState = { at = time(), windows = { "FriendsFrame" }, bags = true }
		fire("PLAYER_ENTERING_WORLD", false, true)
		local atReload = opened
		if c.keep == "turnedoff" then keep = false end
		-- The fight ends (or, after a calm reload, one comes and goes).
		if not inFight then
			inFight, restricted = true, true
			fire("PLAYER_REGEN_DISABLED")
		end
		opened = 0
		inFight = false
		restricted = c.lift == "late"
		fire("PLAYER_REGEN_ENABLED")
		local atRegen = opened
		opened = 0
		if restricted then
			restricted = false
			fire("ADDON_RESTRICTION_STATE_CHANGED", 0, 0)
		end
		local atLift = opened
		-- The next fight.
		opened = 0
		inFight, restricted = true, true
		fire("PLAYER_REGEN_DISABLED")
		inFight, restricted = false, false
		fire("PLAYER_REGEN_ENABLED")
		fire("ADDON_RESTRICTION_STATE_CHANGED", 0, 0)
		local nextFight = opened
		keep = true
		return ("reload=%d regen=%d lift=%d next=%d"):format(atReload, atRegen, atLift, nextFight)
	end,
	pins = {
		-- (A calm reload: both at once, nothing later.)
		{ "reloadIn=calm", "reload=2 regen=0 lift=0 next=0" },
		-- (In a fight: once the restriction is off.)
		{ "reloadIn=fight lift=withregen keep=on", "reload=0 regen=2 lift=0 next=0" },
		{ "reloadIn=fight lift=late keep=on", "reload=0 regen=0 lift=2 next=0" },
		-- (The tick turned off in the fight: nothing.)
		{ "reloadIn=fight keep=turnedoff", "reload=0 regen=0 lift=0 next=0" },
	},
})
