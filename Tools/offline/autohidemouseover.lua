-- Auto-Hide UI's Mouseover groups (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/autohidemouseover.lua < /dev/null
-- Off in the profile from 2026-11-20, on again 2026-11-22 (user's ask).
-- Checks the profile's base has it on (both clients' module lists), and the
-- once-only update turns the live switch back on for a player on it, and
-- only then: not on another profile, not before a profile's picked, once.
-- PASS or FAIL per check.

-- luacheck: push ignore 111 112 113 121 122 212
local ns = dofile("Tools/offline/load.lua")("forever", arg and arg[1])
-- luacheck: pop

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local NAME = "Auto-Hide UI"
Check("base has mouseover on", ns.ProfileBase(NAME).mouseover == true, tostring(ns.ProfileBase(NAME).mouseover))
local found = false
for _, profile in ipairs(ns.BUILTIN_PROFILES or {}) do
	if profile.name == NAME then
		local has = false
		for _, key in ipairs(ns.BuiltinModules(profile)) do
			if key == "mouseover-off" then has = true end
		end
		Check("no mouseover-off module", not has)
		Check("tip no longer says no mouseover", not tostring(profile.tip):find("no mouseover"))
		found = true
	end
end
Check("profile found", found)
-- (The base does apply modules: Blank Slate's every-page-off has it off.)
Check("Blank Slate base has it off", ns.ProfileBase("Blank Slate").mouseover == false)
-- (And its Cooldown Manager page off, the user 2026-11-22; Balanced keeps it.)
Check("Auto-Hide UI base has the Cooldown Manager page off", ns.ProfileBase(NAME).handleCooldowns == false,
	tostring(ns.ProfileBase(NAME).handleCooldowns))
Check("Balanced base keeps the Cooldown Manager page", ns.ProfileBase("Balanced").handleCooldowns ~= false,
	tostring(ns.ProfileBase("Balanced").handleCooldowns))

local db = ns.db
db.profiles = db.profiles or {}
local function Run(live, mouseover, extra)
	db.autoHideMouseoverV1 = nil
	db.liveProfile, db.mouseover, db.offUntilPicked = live, mouseover, extra and extra.offUntilPicked
	db.profiles[NAME] = extra and extra.saved or {}
	ns.RunMigrations()
end
Run(NAME, false)
Check("on Auto-Hide UI: back on", db.mouseover == true)
Check("runs once", db.autoHideMouseoverV1 == true)
db.mouseover = false
ns.RunMigrations()
Check("not again (your own off later)", db.mouseover == false)
Run("Balanced", false)
Check("another profile: left alone", db.mouseover == false)
Run(NAME, false, { offUntilPicked = { mouseover = true } })
Check("before a profile's picked: left alone", db.mouseover == false)
Run(NAME, false, { saved = { mouseover = false } })
Check("saved off in the profile: left alone", db.mouseover == false)
db.profiles[NAME], db.offUntilPicked = nil, nil

-- Its Cooldown Manager page: kept on for players who'd used the profile
-- (their saved copy had nothing for it, the base had it on), once; off with
-- a fresh pick. (The user, 2026-11-22: "keep it on for them".)
db.profileResetPoints = db.profileResetPoints or {}
local function RunCooldowns(saved, point)
	db.autoHideCooldownsV1 = nil
	db.profiles[NAME], db.profileResetPoints[NAME] = saved, point
	ns.RunMigrations()
end
RunCooldowns({}, {})
Check("used it: its saved copy keeps the Cooldown Manager", db.profiles[NAME].handleCooldowns == true)
Check("and its reset point", db.profileResetPoints[NAME].handleCooldowns == true)
Check("the cooldowns update runs once", db.autoHideCooldownsV1 == true)
RunCooldowns({ handleCooldowns = false })
Check("turned off yourself: left off", db.profiles[NAME].handleCooldowns == false)
RunCooldowns(nil)
Check("never used it: nothing saved", db.profiles[NAME] == nil)
-- (Loaded, a saved value wins over the base (Profiles.lua's Load): the kept copy on, a fresh pick the base's off.)
local function Loaded(saved)
	if saved and saved.handleCooldowns ~= nil then return saved.handleCooldowns end
	return ns.ProfileBase(NAME).handleCooldowns
end
RunCooldowns({}, nil)
Check("loading the kept copy: on", Loaded(db.profiles[NAME]) == true)
Check("a fresh pick: off", Loaded(nil) == false)

-- The wheels and the Keyboard Map, off in Auto-Hide UI and Blank Slate from
-- 2026-11-22: kept as they were in a saved copy from before, once; a fresh
-- pick gets them off. (Release review, 2026-11-22.)
for _, name in ipairs({ NAME, "Blank Slate" }) do
	local base = ns.ProfileBase(name)
	Check(name .. ": base has the Keyboard Map off", base.keyboardMap == false, tostring(base.keyboardMap))
	db.profileKeysOffV1 = nil
	db.profiles[name], db.profileResetPoints[name] = { keyboardMap = false }, {}
	ns.RunMigrations()
	local saved, point = db.profiles[name], db.profileResetPoints[name]
	Check(name .. ": saved copy keeps its wheels", saved.wheelMasterOn == ns.DEFAULTS.wheelMasterOn
		and saved.wheelMarkerOn == ns.DEFAULTS.wheelMarkerOn, tostring(saved.wheelMasterOn))
	Check(name .. ": turned off yourself: left off", saved.keyboardMap == false)
	Check(name .. ": its reset point too", point.wheelMasterOn == ns.DEFAULTS.wheelMasterOn
		and point.keyboardMap == ns.DEFAULTS.keyboardMap, tostring(point.keyboardMap))
	Check(name .. ": once", db.profileKeysOffV1 == true)
end

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
