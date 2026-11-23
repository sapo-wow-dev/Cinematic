-- A tab switched off turns its settings off before its page is ever opened,
-- and Graphics+'s tabs do (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/lazytabs.lua [forever|retail] < /dev/null
-- Audit 2026-11-22: since pages are made on first open (lazyPages), a tab's
-- settings were put under its switch only by that build (ns.MapTabContainers),
-- so after a /reload a tab off (Nameplates' Enemy) read on till the page was
-- opened. And Graphics+ read each tick's own value, never its tab's switch,
-- and a tab's flip didn't write the game's settings again. Checks: the
-- switch tree from LazyPageDefaults.lua at login, the Graphics+ page unbuilt
-- and built, and a tab's flip writing the game's setting back. PASS or FAIL.

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local client = arg and arg[1] or "forever"
local cvars = { skyCloudLod = "1" }
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	GetCVar = function(name) return cvars[name] end
	SetCVar = function(name, value) cvars[name] = tostring(value) end
	-- luacheck: pop
end
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db

local function Waiting(name)
	for _, entry in ipairs(ns.lazySettingsPages or {}) do
		if entry.name == name then return entry end
	end
end
local plates, graphics = Waiting("Nameplates"), Waiting("Graphics+")
Check(client .. ": Nameplates waits to be made", plates and not plates.made)
Check(client .. ": Graphics+ waits to be made", graphics and not graphics.made)

-- 1: Nameplates' Enemy tab off, its page never opened.
db.handlePlates = true
db.plateOwnPartsEnemies = true
db["tabOn:Nameplates:Enemy"] = false
Check(client .. ": 1 a setting on a tab that's off reads off", not ns.Setting("plateOwnPartsEnemies"),
	tostring(ns.Setting("plateOwnPartsEnemies")))
db["tabOn:Nameplates:Enemy"] = true
Check(client .. ": 1 and on with the tab", ns.Setting("plateOwnPartsEnemies") == true)

-- 2: Graphics+ on with its Sky tick, the page never opened; Sky and water's tab off.
db.visualEffects, db.graphicsPlus = true, true
db.graphicsPlusSkyOn, db.graphicsPlusSky = true, 3
ns.ApplyGraphicsPlus()
Check(client .. ": 2 Sky written with its tab on", cvars.skyCloudLod == "3", cvars.skyCloudLod)
db["tabOn:Graphics+/tab:2"] = false
ns.ApplyGraphicsPlus()
Check(client .. ": 2 its tab off: the game's own back", cvars.skyCloudLod == "1", cvars.skyCloudLod)

-- 3: the page made, the tab flipped on by its switch (a right-click on the tab): written at once.
if graphics then graphics.Make("lazytabs") end
if ns.MapTabContainers then ns.MapTabContainers() end -- (a timer in game)
Check(client .. ": 3 still off once the page is made", cvars.skyCloudLod == "1", cvars.skyCloudLod)
local flipped = ns.FlipSettingKey("tabOn:Graphics+/tab:2")
Check(client .. ": 3 the tab's switch flipped", flipped and db["tabOn:Graphics+/tab:2"] == true)
Check(client .. ": 3 its flip writes Sky again", cvars.skyCloudLod == "3", cvars.skyCloudLod)
ns.FlipSettingKey("tabOn:Graphics+/tab:2")
Check(client .. ": 3 flipped off: the game's own back", cvars.skyCloudLod == "1", cvars.skyCloudLod)

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
