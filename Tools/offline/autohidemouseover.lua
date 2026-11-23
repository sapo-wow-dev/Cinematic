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

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
