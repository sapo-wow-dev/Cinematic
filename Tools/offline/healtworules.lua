-- Heal Vision's two Show in rows (dev tool, offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/healtworules.lua < /dev/null
-- Its Unit Frames and Nameplates tabs each have their own rule (2026-11-20):
-- the frames start in dungeons and raids only (out in the world they faded
-- healthy party members, a player's report), the plates everywhere but
-- cities. Checks the starts, where each is on (ns.HealVisionHere), the
-- once-only update of saved rules (Migrations.lua's healVisionTwoRulesV1)
-- and the page's Reset. Says PASS or FAIL per check.
-- (Optional first argument: another .toc to load, to run it on older code.)
local ns, wow = dofile("Tools/offline/load.lua")("forever", arg and arg[1])

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local db = ns.db
local PLATES = ns.HEAL_VISION_PLATE_ROW
local FRAMES_START, PLATES_START = "(dungeon or raid) and not dead", "not city and not dead"
Check("the plates' row has a key", type(PLATES) == "string" and PLATES ~= "healVision", PLATES)

-- 1. A fresh install's starts.
Check("fresh: Unit Frames rule starts in dungeons and raids", db.frameRules.healVision == FRAMES_START,
	db.frameRules.healVision)
Check("fresh: Nameplates rule starts everywhere but cities", PLATES and db.frameRules[PLATES] == PLATES_START,
	PLATES and db.frameRules[PLATES])
local TAB = ns.HEAL_VISION_TABS.PLATES
Check("fresh: Nameplates tab starts switched off", db[TAB] == false, tostring(db[TAB]))
Check("fresh: plates off with it", ns.HealVisionPlatesShow() == "off", ns.HealVisionPlatesShow())
Check("fresh: the old on switch is gone", db.healVisionPlates == nil and ns.DEFAULTS.healVisionPlates == nil)
Check("fresh: picker starts on Nameplates", db.healVisionPlatesShow == "plates", db.healVisionPlatesShow)

-- 2. Where each is on: the facts as the rules read them, one place at a time.
-- (Its page on: the stand-in's fresh install starts on a profile with it off.)
db.handleHealVision = true
local realFacts = ns.RuleFactsNow
local function At(place)
	local facts = { world = place == "world", city = place == "city", dungeon = place == "dungeon",
		raid = place == "raid", instance = place == "dungeon" or place == "raid", dead = false, alive = true, always = true }
	ns.RuleFactsNow = function() return facts end
	local frames, plates = ns.HealVisionHere(db), ns.HealVisionHere(db, true)
	ns.RuleFactsNow = realFacts
	return frames and true or false, plates and true or false
end
local frames, plates = At("world")
Check("open world: unit frames not faded", frames == false)
Check("open world: nameplates rule on", plates == true)
frames = At("dungeon")
Check("dungeon: unit frames faded", frames == true)
frames = At("raid")
Check("raid: unit frames faded", frames == true)
frames, plates = At("city")
Check("city: unit frames not faded", frames == false)
Check("city: nameplates rule off", plates == false)
-- (Each row its own: a plates rule changed leaves the frames be.)
db.frameRules[PLATES] = "always"
frames, plates = At("world")
Check("plates rule 'always': plates on in the world", plates == true)
Check("plates rule 'always': unit frames still off in the world", frames == false)
db.frameRules[PLATES] = PLATES_START

-- 3. The once-only update of saved rules, here and in saved profiles.
local function Migrate(rule, plateRule)
	db.healVisionTwoRulesV1 = nil
	db.frameRules.healVision, db.frameRules[PLATES] = rule, plateRule
	db.profiles = db.profiles or {}
	db.profiles.twoRulesTest = { frameRules = { healVision = rule } }
	ns.RunMigrations()
	local saved = db.profiles.twoRulesTest.frameRules
	db.profiles.twoRulesTest = nil
	return db.frameRules.healVision, db.frameRules[PLATES], saved.healVision, saved[PLATES]
end
local mine, minePlates, profile, profilePlates = Migrate(PLATES_START, nil)
Check("update: v2.1.17's untouched start goes back to dungeons and raids", mine == FRAMES_START, mine)
Check("update: ... in a saved profile too", profile == FRAMES_START, profile)
Check("update: the plates' row left to its start", minePlates == nil and profilePlates == nil,
	tostring(minePlates) .. ", " .. tostring(profilePlates))
mine, minePlates, profile, profilePlates = Migrate("combat or group", nil)
Check("update: a rule the player wrote stays", mine == "combat or group", mine)
Check("update: the plates keep going by it", minePlates == "combat or group", minePlates)
Check("update: ... in a saved profile too", profile == "combat or group" and profilePlates == "combat or group",
	tostring(profile) .. ", " .. tostring(profilePlates))
mine, minePlates = Migrate("", nil)
Check("update: a cleared rule stays cleared, for both", mine == "" and minePlates == "",
	tostring(mine) .. ", " .. tostring(minePlates))
mine, minePlates = Migrate("world", "raid")
Check("update: a plates rule already there stays", mine == "world" and minePlates == "raid")
db.healVisionTwoRulesV1 = nil
db.frameRules.healVision = "world"
ns.RunMigrations()
db.frameRules.healVision = PLATES_START
ns.RunMigrations()
Check("update: once only", db.frameRules.healVision == PLATES_START)

-- 3b. The Nameplates tab's switch is the plates' on switch (2026-11-20).
db[TAB] = true
Check("tab on: the pick decides (Nameplates)", ns.HealVisionPlatesShow() == "plates", ns.HealVisionPlatesShow())
db.healVisionPlatesShow = "names"
Check("tab on: the pick decides (Names)", ns.HealVisionPlatesShow() == "names", ns.HealVisionPlatesShow())
Check("fresh: Health fill tick starts unticked", db.healVisionNameFill == false, tostring(db.healVisionNameFill))
Check("tab on, Health fill unticked: names one color", ns.PlateNameFillOn() == false)
db.plateNameHealthFill = true -- (the old key, still in profiles from before 2026-11-19: no say now)
Check("the old Health fill key doesn't turn it on", ns.PlateNameFillOn() == false)
db.plateNameHealthFill = nil
db.healVisionNameFill = true
Check("tab on, Health fill ticked: names get their health fill", ns.PlateNameFillOn() == true)
local healPage = (ns.PageSettings and ns.PageSettings() or {})["Heal Vision"]
Check("Health fill tick on the Heal Vision page (its Reset)", healPage and healPage.keys.healVisionNameFill ~= nil)
db.handleHealVision = false
Check("tab on, page off: plates off", ns.HealVisionPlatesShow() == "off", ns.HealVisionPlatesShow())
Check("tab on, page off: no health fill", ns.PlateNameFillOn() == false)
db.handleHealVision = true
db[TAB] = false
Check("tab off: plates off whatever the pick", ns.HealVisionPlatesShow() == "off", ns.HealVisionPlatesShow())
Check("tab off: no health fill on names", ns.PlateNameFillOn() == false)
-- (Flipped: the names drawn again once, not on every Apply.)
local redraws, realRefresh = 0, ns.RefreshPlateNameStyle
ns.RefreshPlateNameStyle = function() redraws = redraws + 1 end
ns.healVisionFillWas = nil
ns.ApplyHealVisionPlates()
ns.ApplyHealVisionPlates()
db[TAB] = true
ns.ApplyHealVisionPlates()
ns.ApplyHealVisionPlates()
db[TAB] = false
ns.ApplyHealVisionPlates()
ns.RefreshPlateNameStyle = realRefresh
Check("flip: names redrawn only when the fill comes or goes", redraws == 3, redraws)
db.healVisionNameFill = false
db.healVisionPlatesShow = "plates"
-- The once-only move from the picker's Off to the tab, here and in a saved profile.
local function MoveTab(on, show, tab)
	db.healVisionPlatesTabV1 = nil
	db.healVisionPlates, db.healVisionPlatesShow, db[TAB] = on, show, tab
	db.profiles = db.profiles or {}
	db.profiles.tabTest = { settings = { healVisionPlates = on, healVisionPlatesShow = show, [TAB] = tab } }
	ns.RunMigrations()
	local saved = db.profiles.tabTest
	db.profiles.tabTest = nil
	return db[TAB], db.healVisionPlatesShow, db.healVisionPlates, saved
end
local tab, show, old, saved = MoveTab(false, "off", true)
Check("move: picker Off -> tab off", tab == false, tostring(tab))
Check("move: Off pick cleared to the start (Nameplates)", show == "plates", tostring(show))
Check("move: old switch removed", old == nil)
Check("move: ... in a saved profile too", saved.settings[TAB] == false and saved.settings.healVisionPlates == nil
	and saved.settings.healVisionPlatesShow == "plates")
Check("move: a profile's wrapper left alone", saved[TAB] == nil)
tab, show = MoveTab(true, "names", true)
Check("move: on with Names -> tab on, Names kept", tab == true and show == "names", tostring(tab) .. ", " .. tostring(show))
tab = MoveTab(true, "plates", false)
Check("move: tab turned off by the player stays off", tab == false)
db.healVisionPlatesTabV1 = nil
db.healVisionPlates, db[TAB] = nil, true
ns.RunMigrations()
db.healVisionPlates, db[TAB] = false, true
ns.RunMigrations()
Check("move: once only", db[TAB] == true)
db[TAB], db.healVisionPlates, db.healVisionPlatesShow = false, nil, "plates"
-- (A saved profile, reset point or backup holds only what differs from the
-- defaults: one with Nameplates on had the old switch and no tab, the tab's
-- old default being on. It came back off, the 2026-11-21 audit.)
local Move = ns.MoveHealVisionPlates
local diff = { healVisionPlates = true, healVisionPlatesShow = "names" }
Move(diff)
Check("diff: on, no tab -> tab on written in", diff[TAB] == true and diff.healVisionPlates == nil, tostring(diff[TAB]))
Check("diff: ... the pick kept", diff.healVisionPlatesShow == "names")
diff = { healVisionPlatesShow = "names" }
Move(diff)
Check("diff: no old switch -> nothing moves (off, as the tab's start)", diff[TAB] == nil)
local fresh = { [TAB] = true }
Move(fresh)
Check("new settings: a tab on stays on (safe to run again)", fresh[TAB] == true)
db.healVisionPlatesTabV1 = nil
db.profiles = db.profiles or {}
db.profiles.diffTest = { settings = { healVisionPlates = true } }
db.profileResetPoints = db.profileResetPoints or {}
db.profileResetPoints.diffTest = { healVisionPlates = true }
db.profileBackups = { diffTest = { { settings = { healVisionPlates = true } }, { settings = { healVisionPlates = false } } } }
db.deletedProfiles = { { name = "gone", backups = { { settings = { healVisionPlates = true } } } } }
db.healVisionPlatesBackupsV1 = nil
ns.RunMigrations()
Check("migrate: saved profile with Nameplates on keeps the tab on", db.profiles.diffTest.settings[TAB] == true)
Check("migrate: reset point too", db.profileResetPoints.diffTest[TAB] == true)
Check("migrate: backups too (on and off)", db.profileBackups.diffTest[1].settings[TAB] == true
	and db.profileBackups.diffTest[2].settings[TAB] == false)
Check("migrate: a deleted profile's backups too", db.deletedProfiles[1].backups[1].settings[TAB] == true)
db.profiles.diffTest, db.profileResetPoints.diffTest, db.profileBackups, db.deletedProfiles = nil, nil, {}, {}
-- An old share string: its old switch onto the tab, not skipped.
do
	local wasSettings = ns.ProfileForSharing
	ns.ProfileForSharing = function() return { healVisionPlates = true } end
	local ok, text = pcall(ns.ExportProfile, ns.ActiveProfile())
	ns.ProfileForSharing = wasSettings
	local read = ok and text and ns.ReadSharedProfile(text)
	Check("share: an old string's Nameplates on comes in as the tab on", read and read.settings[TAB] == true
		and read.skipped == 0, read and (tostring(read.settings[TAB]) .. ", skipped " .. read.skipped) or tostring(text))
end

-- 4. The page: both rows on it, and its Reset puts both rules back.
local settings = ns.PageSettings and ns.PageSettings()
local page = settings and settings["Heal Vision"]
local rows = page and page.rows and page.rows.frameRules
Check("page: both rows recorded for its Reset", rows and rows.healVision ~= nil and rows[PLATES] ~= nil)
db.frameRules.healVision, db.frameRules[PLATES] = "combat", "world"
-- (Its Reset page button's popup, on the page's content: canvas.content.)
local accept = StaticPopupDialogs.CINEMATIC_RESET_PAGE and StaticPopupDialogs.CINEMATIC_RESET_PAGE.OnAccept
for _, frame in ipairs(accept and wow.frames or {}) do
	if frame.pageName == "Heal Vision" and frame.content then
		accept(nil, frame.content)
		break
	end
end
Check("page: Reset puts both rules back", db.frameRules.healVision == FRAMES_START
	and db.frameRules[PLATES] == PLATES_START,
	tostring(db.frameRules.healVision) .. ", " .. tostring(db.frameRules[PLATES]))

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
os.exit(fails == 0 and 0 or 1)
