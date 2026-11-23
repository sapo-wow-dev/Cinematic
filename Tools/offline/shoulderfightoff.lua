-- Shoulder Cam turned off in a fight (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/shoulderfightoff.lua < /dev/null
-- Audit 2026-11-22: turning it off in a fight (its key) wrote the soft target
-- and Outline Mode back there, an ADDON_ACTION_BLOCKED (protected in fights),
-- then forgot yours: the game saved the held 3/2/45 and Outline 0 for good.
-- A logout in a fight dropped them the same way. On a stand-in CVar store
-- that refuses those in fights: nothing protected written in the fight, the
-- rest given back at once, the soft ones as the fight ends; at a logout in a
-- fight they're kept for the next login. Says PASS or FAIL per check.

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local PROTECTED = { SoftTargetEnemy = true, SoftTargetEnemyArc = true, SoftTargetEnemyRange = true,
	OutlineEngineMode = true, RAIDOutlineEngineMode = true }
local cvars = {}
local fight = false
local blocked = 0

local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	GetCVar = function(name) return cvars[name] or "0" end
	SetCVar = function(name, value)
		if fight and PROTECTED[name] then
			blocked = blocked + 1 -- (the game's ADDON_ACTION_BLOCKED: no write)
			return
		end
		cvars[name] = tostring(value)
	end
	InCombatLockdown = function() return fight end
	-- luacheck: pop
end

local ns, wow = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc", Install)

local function Held()
	cvars.SoftTargetEnemy, cvars.SoftTargetEnemyArc, cvars.SoftTargetEnemyRange = "3", "2", "45"
	cvars.OutlineEngineMode, cvars.CameraKeepCharacterCentered = "0", "0"
	ns.db.shoulderCamYours = { SoftTargetEnemy = "1", SoftTargetEnemyArc = "0", SoftTargetEnemyRange = "20",
		OutlineEngineMode = "2", CameraKeepCharacterCentered = "1" }
end

-- 1: off by its key in a fight, mid-glide.
Held()
ns.db.shoulderCamNoticed = true
ns.db.shoulderCam = false
fight, blocked = true, 0
ns.ApplyShoulderCam()
Check("1 nothing protected written in the fight", blocked == 0, blocked)
Check("1 Keep Character Centered back at once", cvars.CameraKeepCharacterCentered == "1",
	cvars.CameraKeepCharacterCentered)
local yours = ns.db.shoulderCamYours
Check("1 soft target kept to give back", yours and yours.SoftTargetEnemy == "1" and yours.OutlineEngineMode == "2")
Check("1 the given-back one no longer kept", yours and yours.CameraKeepCharacterCentered == nil)

-- 2: the fight ends: given back, nothing kept.
fight = false
wow.Fire("PLAYER_REGEN_ENABLED")
Check("2 soft target back", cvars.SoftTargetEnemy == "1" and cvars.SoftTargetEnemyArc == "0"
	and cvars.SoftTargetEnemyRange == "20", ("%s/%s/%s"):format(cvars.SoftTargetEnemy, cvars.SoftTargetEnemyArc,
	cvars.SoftTargetEnemyRange))
Check("2 Outline Mode back", cvars.OutlineEngineMode == "2", cvars.OutlineEngineMode)
Check("2 nothing kept after", ns.db.shoulderCamYours == nil)

-- 3: off out of a fight: all back at once, as before.
Held()
ns.ApplyShoulderCam()
Check("3 out of a fight: all back at once", cvars.SoftTargetEnemy == "1" and cvars.OutlineEngineMode == "2"
	and ns.db.shoulderCamYours == nil)

-- 4: a logout in a fight mid-glide: kept for the next login, not dropped.
Held()
fight, blocked = true, 0
wow.Fire("PLAYER_LOGOUT")
Check("4 nothing protected written at a logout in a fight", blocked == 0, blocked)
yours = ns.db.shoulderCamYours
Check("4 soft target kept for the next login", yours and yours.SoftTargetEnemy == "1" and yours.OutlineEngineMode == "2")
-- (Next login, out of a fight, Shoulder Cam off: given back.)
fight = false
ns.ApplyShoulderCam()
Check("4 given back at the next login", cvars.SoftTargetEnemy == "1" and ns.db.shoulderCamYours == nil)

-- 5: a logout out of a fight: given back and dropped, as before.
Held()
wow.Fire("PLAYER_LOGOUT")
yours = ns.db.shoulderCamYours
Check("5 logout out of a fight: soft target back", cvars.SoftTargetEnemy == "1" and yours
	and yours.SoftTargetEnemy == nil)

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
