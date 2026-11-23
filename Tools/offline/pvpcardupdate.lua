-- PvP combat card update check (dev tool, offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/pvpcardupdate.lua < /dev/null
-- Entering a PvP fight's card is on for a new install (pvpcard.lua) and off
-- for a player who had Cinematic before it (Migrations.lua's pvpCardOffV1):
-- loads with saved settings from before (a saved profile copy and a reset
-- point too), then checks the row's off in each, a profile copy that had it
-- on keeps it, and the update runs once. Says PASS or FAIL per check.
-- (Optional first argument: another .toc to load, to run it on older code.)
-- luacheck: push ignore 111 112 113
CinematicDB = {
	profile = "Cinema", liveProfile = "Cinema", combatOnEnter = true, plateNameFriendsV2 = true,
	profiles = { Mine = { combatOnEnter = true }, Theirs = { cardCombatPvpOn = true } },
	profileResetPoints = { Cinema = { combatOnEnter = true } },
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
Check("player from before: the row off", db.cardCombatPvpOn == false, tostring(db.cardCombatPvpOn))
Check("...in a saved profile copy", db.profiles.Mine.cardCombatPvpOn == false, tostring(db.profiles.Mine.cardCombatPvpOn))
Check("...a copy that had it on keeps it", db.profiles.Theirs.cardCombatPvpOn == true,
	tostring(db.profiles.Theirs.cardCombatPvpOn))
Check("...in a reset point", db.profileResetPoints.Cinema.cardCombatPvpOn == false,
	tostring(db.profileResetPoints.Cinema.cardCombatPvpOn))
Check("the update marked done", db.pvpCardOffV1 == true)
-- (Ticked by them after: the update doesn't come back.)
db.cardCombatPvpOn = true
ns.RunMigrations()
Check("ticked after the update: stays on", db.cardCombatPvpOn == true)

print(fails == 0 and "ALL PASS" or (fails .. " FAIL"))
os.exit(fails == 0 and 0 or 1)
