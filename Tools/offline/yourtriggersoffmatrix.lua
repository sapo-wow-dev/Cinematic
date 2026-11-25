-- Your own triggers with their pages off (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-cameras-your-triggers-off.md):
--   python -I Tools/offline/run.py Tools/offline/yourtriggersoffmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/yourtriggersoffmatrix.lua forever --base <ref>
-- Two scenes of yours, one started by Scene key 1, one by a buff (aura); then
-- the Triggers page, the Scenes page and Enable Cameras each on or off, the
-- scenes brought in line as the 1 s check does (ns.SyncCustomTriggers), and
-- Scene key 1 pressed. Each cell: whether the triggers' 0.1 s update loop
-- runs, whether their game events are registered, whether the key's scene
-- started ("fired" in the Triggers log).
-- The rule: any of the three off, none of your triggers runs, listens or fires.
local client = arg and arg[1] or "forever"
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local db = ns.db
local now = 100
GetTime = function() return now end -- luacheck: ignore 121
db.enabled, db.cameraModes, db.cameraScenes, db.cameraTriggers = true, true, true, true
-- (Their loop and event frames: the ones that change as the scenes come in.)
local before = {}
for _, frame in ipairs(wow.frames) do
	before[frame] = { shown = frame._shown, aura = frame._events.UNIT_AURA }
end
ns.AddCustomTrigger("key:1", "move", "cozy", "key scene")
ns.AddCustomTrigger("aura:774", "ends", "cozy", "buff scene")
local ticker, watcher
for _, frame in ipairs(wow.frames) do
	local was = before[frame]
	if was and not was.shown and frame._shown and frame._scripts.OnUpdate then ticker = frame end
	if was and not was.aura and frame._events.UNIT_AURA then watcher = frame end
end
assert(ticker and watcher, "matrix: the triggers' loop and event frames not found")
local fired = 0
local logAdd = ns.TriggerLogAdd
ns.TriggerLogAdd = function(what, ...)
	if what == "fired" then fired = fired + 1 end
	if logAdd then return logAdd(what, ...) end
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "your-triggers-off",
	fixed = { client = client },
	dims = {
		{ "triggers", { "on", "off" } },
		{ "scenes", { "on", "off" } },
		{ "cameras", { "on", "off" } },
	},
	cell = function(c)
		-- (Each cell from all on, nothing playing.)
		db.cameraModes, db.cameraScenes, db.cameraTriggers = true, true, true
		ns.SyncCustomTriggers()
		Cinematic_CustomTrigger(1)
		Cinematic_CustomTrigger(1) -- (pressed again: off)
		db.cameraTriggers = c.triggers == "on"
		db.cameraScenes = c.scenes == "on"
		db.cameraModes = c.cameras == "on"
		ns.CameraRowsChanged()
		ns.SyncCustomTriggers()
		now = now + 10
		fired = 0
		Cinematic_CustomTrigger(1)
		local outcome = ("loop %s, events %s, key %s"):format(ticker._shown and "on" or "off",
			watcher._events.UNIT_AURA and "on" or "off", fired > 0 and "fired" or "no")
		Cinematic_CustomTrigger(1)
		return outcome
	end,
	pins = {
		{ "", "loop off, events off, key no" },
		{ "triggers=on scenes=on cameras=on", "loop on, events on, key fired" },
	},
})
