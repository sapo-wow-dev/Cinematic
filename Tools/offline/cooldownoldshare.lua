-- A v2.1.23 profile string or backup with the Cooldown Manager's old numbered
-- lines (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/cooldownoldshare.lua < /dev/null
-- Release review, 2026-11-22: the old line lists weren't settings any more,
-- so a string shared from v2.1.23 came in with no Cooldown Manager scenes
-- ("from a newer Cinematic ... skipped", wrongly), and so did a backup made
-- before the update, restored. Their lines now go over as the saved ones do
-- (ns.MigrateCooldownLines): read in, restored, and stored backups converted
-- by the update, a deleted profile's too. PASS or FAIL per check.

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local ns = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc")
local db = ns.db
ns.SwitchProfileLayout = function() end -- (the stand-in has no Edit Mode)

local function OldLines()
	return {
		cooldownGroupRules = { essential = { { show = "never", combat = "in", place = "dungeon" } } },
		cooldownSpellRules = { [700] = { { show = "ready", cql = "(dungeon or raid) and (combat or calm)" } } },
		cooldownAlwaysShow = { [800] = true },
	}
end
local function Converted(t)
	return type(t) == "table" and t.cooldownSpellRules == nil and t.cooldownGroupRules == nil
		and type(t.cooldownPlaceGroups) == "table" and #t.cooldownPlaceGroups > 0
		and type(t.cooldownSpellCells) == "table" and t.cooldownSpellCells[700] ~= nil
end

-- 1: a string shared from v2.1.23.
local text = ns.PackShared("CINE", 1, { format = 1, version = "v2.1.23", name = "Old share", settings = OldLines() })
local read, why = ns.ReadSharedProfile(text)
Check("1 read", read ~= nil, why)
Check("1 its lines made scenes", read and Converted(read.settings))
Check("1 nothing skipped as from a newer version", read and read.skipped == 0, read and read.skipped)
-- (The situations' rule became places again: no rule scene for it.)
local rule = false
for _, group in ipairs(read and read.settings.cooldownPlaceGroups or {}) do rule = rule or group.cql ~= nil end
Check("1 the situations' rule made places again", not rule)

-- 2: a backup made before the update, restored.
db.profileBackups = db.profileBackups or {}
db.profileBackups.OldOne = { { time = 1763000000, settings = OldLines() } }
local restored = ns.RestoreBackup("OldOne", 1)
Check("2 restored", restored ~= nil)
Check("2 its lines made scenes", restored and Converted(db.profiles[restored]))

-- 3: the update converts stored backups, a deleted profile's too.
db.profileBackups.Stored = { { time = 1763000000, settings = OldLines() } }
db.deletedProfiles = { { name = "Gone", time = 1763000000, backups = { { time = 1763000000, settings = OldLines() } } } }
db.cooldownGridV1 = nil
ns.RunMigrations()
Check("3 a stored backup converted", Converted(db.profileBackups.Stored[1].settings))
Check("3 a deleted profile's backup converted", Converted(db.deletedProfiles[1].backups[1].settings))

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
