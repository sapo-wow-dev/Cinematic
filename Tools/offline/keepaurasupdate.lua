-- Heal Vision's Debuffs: Show while hidden, the update for players from before
-- (dev tool, offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/keepaurasupdate.lua < /dev/null
-- The tick is on for a new install and Reset (healauras.lua checks those) and
-- off for a player who had Cinematic before it (Migrations.lua's
-- keepAurasOffV1): loads with saved settings from before (a saved profile copy
-- and a reset point too), then checks it's off in each, a copy that had it on
-- keeps it, a role tab reads it off too, and the update runs once. Says PASS
-- or FAIL per check. (Optional first argument: another .toc, for older code.)
-- (healVisionDefaultsV1: an old update every player from before has run, which
-- puts every Heal Vision setting back to its default; left out, it'd tick
-- this one here before this update.)
-- luacheck: push ignore 111 112 113
CinematicDB = {
	profile = "Cinema", liveProfile = "Cinema", handleHealVision = true, plateNameFriendsV2 = true,
	healVisionDefaultsV1 = true,
	profiles = { Mine = { handleHealVision = true }, Theirs = { healVisionKeepAuras = true },
		Wrapped = { settings = { handleHealVision = true } } },
	profileResetPoints = { Cinema = { handleHealVision = true } },
}
-- luacheck: pop
local ns = dofile("Tools/offline/load.lua")("forever", arg and arg[1])

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local db = ns.db
Check("not taken for a new install", ns.newInstall ~= true, tostring(ns.newInstall))
Check("the default is on (new installs, Reset)", ns.DEFAULTS.healVisionKeepAuras == true,
	tostring(ns.DEFAULTS.healVisionKeepAuras))
Check("player from before: off", db.healVisionKeepAuras == false, tostring(db.healVisionKeepAuras))
Check("...Heal Vision reads it off", ns.HealVisionKeepAuras and ns.HealVisionKeepAuras() == false)
db.healVisionOwn_HEALER = true -- (a role on its own settings: no copy of its own yet, reads this one)
local role = ns.PlayerRole
ns.PlayerRole = function() return "HEALER" end
Check("...a role tab on its own settings reads it off", ns.HealVisionSetting("healVisionKeepAuras") == false,
	tostring(ns.HealVisionSetting("healVisionKeepAuras")))
ns.PlayerRole, db.healVisionOwn_HEALER = role, nil
Check("...in a saved profile copy", db.profiles.Mine.healVisionKeepAuras == false,
	tostring(db.profiles.Mine.healVisionKeepAuras))
Check("...in a wrapped profile copy", db.profiles.Wrapped.settings.healVisionKeepAuras == false,
	tostring(db.profiles.Wrapped.settings.healVisionKeepAuras))
Check("...a copy that had it on keeps it", db.profiles.Theirs.healVisionKeepAuras == true,
	tostring(db.profiles.Theirs.healVisionKeepAuras))
Check("...in a reset point", db.profileResetPoints.Cinema.healVisionKeepAuras == false,
	tostring(db.profileResetPoints.Cinema.healVisionKeepAuras))
Check("the update marked done", db.keepAurasOffV1 == true)
-- (Ticked by them after: the update doesn't come back.)
db.healVisionKeepAuras = true
ns.RunMigrations()
Check("ticked after the update: stays on", db.healVisionKeepAuras == true)

print(fails == 0 and "ALL PASS" or (fails .. " FAIL"))
os.exit(fails == 0 and 0 or 1)
