-- The campfire watch (QoL/Campfire.lua) and who wants it (the audit kit's
-- matrix, Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-qol-campfire-loop.md):
--   python -I Tools/offline/run.py Tools/offline/campfireloopmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/campfireloopmatrix.lua forever --base <ref>
-- Enable Cameras on or off, the Campfire scene's row on or off (its cozy
-- camera looks for your tent), the campfire card's Fire button on or off, and
-- something listening for the cursor resting on a fire (CAMPFIRE_REST: Emote
-- Vision's card, a trigger) or not. Each cell: whether its update loop runs,
-- and whether a world tooltip showing is read (its OnShow hook).
-- The rule: both only while one of those wants it.
local client = arg and arg[1] or "forever"
local made = {}
local function Install()
	local create = CreateFrame
	CreateFrame = function(...) -- luacheck: ignore 121
		local frame = create(...)
		local info = debug.getinfo(2, "Sl")
		if info then made[#made + 1] = { frame = frame, at = tostring(info.source):gsub("\\", "/") .. ":" .. info.currentline } end
		return frame
	end
	local No = function() return false end
	for _, name in ipairs({ "UnitOnTaxi", "UnitAffectingCombat", "InCombatLockdown", "UnitIsAFK", "IsMounted",
		"UnitIsDeadOrGhost", "UnitIsDead", "IsFlying", "IsSwimming", "UnitInVehicle", "UnitCastingInfo",
		"UnitChannelInfo", "IsMouselooking", "IsMouseButtonDown", "UnitExists", "IsResting", "IsFalling",
		"IsStealthed", "issecretvalue" }) do
		_G[name] = No
	end
end
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db
db.enabled = true
-- (The loop's frame: made on its line.)
local driver
do
	local n = 0
	for line in io.lines("QoL/Campfire.lua") do
		n = n + 1
		if line:find("^local driver = CreateFrame") then
			for _, each in ipairs(made) do
				if each.at:find("QoL/Campfire.lua:" .. n, 1, true) then driver = each.frame end
			end
		end
	end
end
-- (The tooltip hook's reads counted: its LookAtTooltip, swapped for a counter.)
local reads = 0
local function Find(fn, depth)
	if type(fn) ~= "function" or depth > 200 then return nil end
	local info = debug.getinfo(fn, "S")
	if info and tostring(info.source):gsub("\\", "/"):find("QoL/Campfire.lua", 1, true) then return fn end
	local i = 1
	while true do
		local name, value = debug.getupvalue(fn, i)
		if not name then return nil end
		-- (Down the stand-in's HookScript chain only: each hook keeps old and fn.)
		local found = (name == "old" or name == "fn") and Find(value, depth + 1)
		if found then return found end
		i = i + 1
	end
end
local hook = Find(GameTooltip._scripts.OnShow, 0)
assert(driver and hook, "matrix: the campfire loop or tooltip hook not found")
-- (Hooked through a gate of its own: the OnTooltipShow it calls.)
do
	local i = 1
	while true do
		local name, value = debug.getupvalue(hook, i)
		if not name then break end
		if name == "OnTooltipShow" then hook = value break end
		i = i + 1
	end
end
do
	local i = 1
	while true do
		local name, value = debug.getupvalue(hook, i)
		if not name then break end
		if name == "LookAtTooltip" then
			debug.setupvalue(hook, i, function(...)
				reads = reads + 1
				return value(...)
			end)
		end
		i = i + 1
	end
end
local row = ns.TriggerRowIds("Campfire")[1]
db.cameraRows[row .. ".always"] = true
local button, listening = false, false
ns.CampfireButtonOn = function() return button end
ns.listeners.CAMPFIRE_REST = { { fn = function() end, wanted = function() return listening end } }

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "campfire-loop",
	fixed = { client = client },
	dims = {
		{ "cameras", { "on", "off" } },
		{ "scene", { "on", "off" } },
		{ "button", { "on", "off" } },
		{ "listen", { "yes", "no" } },
	},
	cell = function(c)
		db.cameraModes, db.cameraScenes = c.cameras == "on", true
		ns.SetCameraRowOn(row, c.scene == "on")
		ns.CameraRowsChanged()
		button, listening = c.button == "on", c.listen == "yes"
		ns.SyncFeatureLoops()
		reads = 0
		GameTooltip._scripts.OnShow(GameTooltip)
		return ("loop %s, tooltip %s"):format(driver._scripts.OnUpdate and "on" or "off", reads > 0 and "read" or "skipped")
	end,
	pins = {
		{ "", "loop off, tooltip skipped" },
		{ "cameras=on scene=on", "loop on, tooltip read" },
		{ "button=on", "loop on, tooltip read" },
		{ "listen=yes", "loop on, tooltip read" },
	},
})
