-- The Fishing page's right-click cast watch with the page off (the audit
-- kit's matrix, Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-cameras-fishing-loop.md):
--   python -I Tools/offline/run.py Tools/offline/fishingloopmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/fishingloopmatrix.lua forever --base <ref>
-- A fishing pole in your main hand or not, the Fishing page on or off, no key
-- of ours bound. Each cell: whether its per-frame watch runs (Camera.lua's
-- recast watcher, ns.FeatureLoop).
-- The rule: only with the page on and a pole on (or keys of ours still to
-- give back, the fish camera, a cast on).
local client = arg and arg[1] or "forever"
local pole = false
local function Install()
	local No = function() return false end
	for _, name in ipairs({ "UnitOnTaxi", "UnitAffectingCombat", "InCombatLockdown", "UnitIsAFK", "IsMounted",
		"UnitIsDeadOrGhost", "UnitIsDead", "IsFlying", "IsSwimming", "UnitInVehicle", "UnitCastingInfo",
		"UnitChannelInfo", "IsMouselooking", "IsMouseButtonDown", "UnitExists", "IsResting", "IsFalling",
		"IsStealthed" }) do
		_G[name] = No
	end
	GetInventoryItemID = function() return pole and 6256 or nil end -- luacheck: ignore 121
	C_Item = C_Item or {} -- luacheck: ignore 121
	C_Item.GetItemInfoInstant = function() return 6256, "", "", "", 0, 2, 20 end -- luacheck: ignore 122
end
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db
db.enabled = true
-- (Its watch: the frame with its events.)
local watch
for _, frame in ipairs(wow.frames) do
	local e = frame._events
	if e.PLAYER_LOGIN and e.PLAYER_REGEN_DISABLED and e.UNIT_SPELLCAST_CHANNEL_STOP then watch = frame end
end
assert(watch, "matrix: the recast watch not found")

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "fishing-loop",
	fixed = { client = client },
	dims = {
		{ "pole", { "on", "off" } },
		{ "page", { "on", "off" } },
	},
	cell = function(c)
		pole = c.pole == "on"
		db.handleFishing = c.page == "on"
		wow.Fire("PLAYER_EQUIPMENT_CHANGED")
		ns.SyncFeatureLoops()
		return watch._scripts.OnUpdate and "loop on" or "loop off"
	end,
	pins = {
		{ "", "loop off" },
		{ "pole=on page=on", "loop on" },
	},
})
