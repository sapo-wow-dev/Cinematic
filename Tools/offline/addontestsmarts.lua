-- The addon test's own judgment (Dev/AddonTest.lua), offline (Lua 5.1 via
-- Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/addontestsmarts.lua < /dev/null
-- Its first Questie run (2026-11-21) said PASS with 0 rows tested: Questie's
-- tracker was off in Questie's own options, so the frame never existed. And
-- its fight step showed nothing new in three runs. Now: a frame's kind
-- (numbers as #), steps skipped when the last run on the same version showed
-- no new kind in them ("full" asks again), and the frames our support names
-- that were never made. Says PASS or FAIL per check.
-- (An addon list the solo check reads, empty while loading: filled below.
-- { name, state (0 off, 2 on), loaded }.)
local addons = {}
local function Find(name)
	for i, a in ipairs(addons) do if a.name == name or i == name then return a end end
end
local ns, wow = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc", function()
	local A = _G.C_AddOns
	A.GetNumAddOns = function() return #addons end
	A.GetAddOnInfo = function(i)
		local a = Find(i)
		if a then return a.name, a.name, "", true, a.state > 0 and "" or "DISABLED" end
	end
	A.GetAddOnEnableState = function(name) local a = Find(name) return a and a.state or 0 end
	A.IsAddOnLoaded = function(name) local a = Find(name) return a and a.loaded or false end
	A.EnableAddOn = function(name) local a = Find(name) if a then a.state = 2 end end
	A.DisableAddOn = function(name) local a = Find(name) if a then a.state = 0 end end
	A.SaveAddOns = function() end
end)

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail ~= nil and (" (" .. tostring(detail) .. ")") or ""))
end

-- Kinds.
Check("QuestieFrame20 and QuestieFrame582 are one kind",
	ns.AddonTestKind("QuestieFrame20") == ns.AddonTestKind("QuestieFrame582"), ns.AddonTestKind("QuestieFrame582"))
Check("an unnamed frame's table id is dropped",
	ns.AddonTestKind("Questie_BaseFrame.2383616cdb0") == ns.AddonTestKind("Questie_BaseFrame.2383c32b310"))
Check("different frames stay different kinds",
	ns.AddonTestKind("Questie_HeaderFrame") ~= ns.AddonTestKind("Questie_BaseFrame"))
Check("a field name with few hex letters stays", ns.AddonTestKind("Bar.faded") == "Bar.faded")

-- Skips.
local record = { version = "12.11.1", target = false, fight = false }
local skip = ns.AddonTestSkips(record, "12.11.1")
Check("both steps skipped after a run that found nothing in them", skip.target and skip.fight)
skip = ns.AddonTestSkips({ version = "12.11.1", target = false, fight = true }, "12.11.1")
Check("a step that found something is kept", skip.target and not skip.fight)
skip = ns.AddonTestSkips(record, "12.12.0")
Check("a new version asks every step again", not skip.target and not skip.fight)
skip = ns.AddonTestSkips(record, "12.11.1", true)
Check("full asks every step again", not skip.target and not skip.fight)
skip = ns.AddonTestSkips(nil, "12.11.1")
Check("no run before: every step", not skip.target and not skip.fight)
skip = ns.AddonTestSkips({ version = "12.11.1" }, "12.11.1")
Check("a step not run last time (quick) isn't skipped", not skip.target and not skip.fight)

-- Frames never made: Questie's setup runs, its tracker doesn't exist yet.
rawset(C_QuestLog, "GetMaxNumQuestsCanAccept", function() return 40 end)
rawset(C_Timer, "NewTicker", function() return { Cancel = function() end } end)
wow.Fire("ADDON_LOADED", "Questie")
local missing = ns.AddonTestMissing("Questie")
local has = {}
for _, name in ipairs(missing) do has[name] = true end
Check("its tracker, never made, is named", has.Questie_BaseFrame, #missing .. " missing")
Check("its 40th item button too", has.Questie_ItemButton40)
Check("no game frame on its rows is named (ObjectiveTrackerFrame)", not has.ObjectiveTrackerFrame)
CreateFrame("Frame", "Questie_BaseFrame", UIParent)
for i = 1, 40 do CreateFrame("Button", "Questie_ItemButton" .. i, UIParent) end
local untaken
missing, untaken = ns.AddonTestMissing("Questie")
Check("all made: nothing missing", #missing == 0, table.concat(missing, ", "))
-- (Made but not ours yet: 2026-11-21's run 7, 1 of 41 on the row, our fade
-- still bringing the tracker in while the test hid it.)
local before = #untaken
ns.managed[#ns.managed + 1] = { frame = _G.Questie_BaseFrame, name = "Questie_BaseFrame", group = "quests" }
untaken = select(2, ns.AddonTestMissing("Questie"))
local stillThere = false
for _, name in ipairs(untaken) do if name == "Questie_BaseFrame" then stillThere = true end end
Check("a frame we took over leaves the not-ours list", before > 0 and not stillThere and #untaken == before - 1,
	before .. " -> " .. #untaken)

-- A frame first seen before our scan claimed it, never drawn again (the
-- addon kit's run qb025, 2026-11-25: EllesmereUIDMFrame1 stayed NOT COVERED
-- though its row hid and showed it): asked again at the end, it's covered;
-- one nothing claims stays NOT COVERED.
local meter, stray = CreateFrame("Frame", "FakeMeterFrame1", UIParent), CreateFrame("Frame", "FakeStray", UIParent)
local seenFrames = {
	[meter] = { line = "FakeMeterFrame1 (Frame, by Fake from its name) NOT COVERED: 375x150" },
	[stray] = { line = "FakeStray (Frame, by Fake from its name) NOT COVERED: 10x10" },
}
ns.AddonTestCoverAgain(seenFrames, { [meter] = { frame = meter, group = "addon:fakeMeters" } })
Check("claimed after it was first seen: covered by the end", seenFrames[meter].cover == "faded in addon:fakeMeters"
	and seenFrames[meter].line:find("covered by the end: faded in addon:fakeMeters", 1, true) ~= nil,
	seenFrames[meter].line)
Check("never claimed: still NOT COVERED", seenFrames[stray].cover == nil
	and seenFrames[stray].line:find("NOT COVERED", 1, true) ~= nil)

-- An addon's own minimap button, no Support file (Journey Tracker,
-- 2026-11-25): the minimap scan puts it on the Addon buttons row, so the test
-- must hide that row, or it said "no row to test".
-- luacheck: push ignore 111 112 113 121 122
issecurevariable = function(t, key)
	local name = key == nil and t or key
	if type(name) == "string" and name:find("^JourneyTracker") then return false, "JourneyTracker" end
	return true
end
-- luacheck: pop
ns.db.handleFrames, ns.db.showInMinimap = true, true
local button = CreateFrame("Button", "JourneyTrackerMinimapButton", Minimap)
ns.FindMinimapHeader()
local rowKeys = {}
for _, item in ipairs(ns.AddonTestRows("JourneyTracker")) do rowKeys[#rowKeys + 1] = item.key end
Check("its own minimap button's row is tested (Addon buttons)", table.concat(rowKeys, ",") == "minimapaddons",
	table.concat(rowKeys, ","))
Check("no other addon's rows come with it", #ns.AddonTestRows("Panorama") == 0)
button:SetParent(UIParent)

-- The solo check (known error solo-split-companion, 2026-11-25): Guidelime's
-- solo kept Questie but turned QuestieDB off, and Questie errored every reload.
local entries = {}
ns.DevErrorEntries = function() return entries end
addons[1] = { name = "Guidelime", state = 2, loaded = true }
addons[2] = { name = "Questie", state = 2, loaded = true }
addons[3] = { name = "QuestieDB", state = 0, loaded = false }
addons[4] = { name = "Auctionator", state = 0, loaded = false }
local solo = { keep = { "CinematicDev", "Guidelime", "Questie" }, turnedOff = { QuestieDB = 2, Auctionator = 2 } }
entries[1] = { kind = "error", source = "Questie", message = "QuestieDB.lua:130: attempt to index global 'LibQuestieDB'", count = 1 }
local problems = table.concat(ns.SoloCheck(solo), " / ")
Check("solo check: Questie loaded with its QuestieDB off is a SPLIT",
	problems:find("SPLIT: Questie is loaded but its QuestieDB is off", 1, true) ~= nil, problems)
Check("solo check: Questie's load errors named", problems:find("LOAD ERRORS: Questie had 1 error", 1, true) ~= nil, problems)
Check("solo check: an addon solo turned off on purpose isn't a split", problems:find("Auctionator", 1, true) == nil, problems)
addons[3].state, addons[3].loaded = 2, true
entries[1] = nil
Check("solo check: both on, no errors: nothing", #ns.SoloCheck(solo) == 0, table.concat(ns.SoloCheck(solo), " / "))
-- After solo off: QuestieDB and Auctionator were turned off by the solo, so on again; Guidelime was turned on, so off.
local back = { on = { "QuestieDB", "Auctionator" }, off = { "Guidelime" } }
addons[3].state, addons[3].loaded, addons[4].state = 0, false, 2 -- (after the reload: off is not loaded)
problems = table.concat(ns.SoloCheck(nil, back), " / ")
Check("solo off check: QuestieDB still off and Guidelime still on are NOT BACK",
	problems == "NOT BACK: Guidelime is still on / NOT BACK: QuestieDB is still off", problems)
addons[3].state, addons[3].loaded, addons[1].state, addons[1].loaded = 2, true, 0, false
Check("solo off check: all back: nothing", #ns.SoloCheck(nil, back) == 0, table.concat(ns.SoloCheck(nil, back), " / "))
-- Fixed by itself (2026-11-25, "do stuff for me"): QuestieDB back on, Guidelime back off.
addons[3].state, addons[3].loaded, addons[1].state, addons[1].loaded = 0, false, 2, true
local _, fixes = ns.SoloCheck(nil, back)
local fixed = table.concat(ns.SoloRepair(fixes), ", ")
Check("repair: QuestieDB on, Guidelime off", fixed == "QuestieDB on, Guidelime off" and addons[3].state == 2
	and addons[1].state == 0, fixed)
-- Any login, no solo: Questie loaded and erroring with QuestieDB off (the list a solo split before this check).
addons[3].state, addons[3].loaded = 0, false
entries[1] = { kind = "error", source = "Questie", message = "attempt to index global 'LibQuestieDB'", count = 7 }
local lines, fix2 = ns.SoloCheck(nil, nil)
Check("any login: an erroring addon with a part off is a SPLIT, fixed by turning it on",
	table.concat(lines, " / ") == "SPLIT: Questie errored at load and its QuestieDB is off"
	and table.concat(fix2.enable, ",") == "QuestieDB", table.concat(lines, " / "))
entries[1] = nil
Check("any login: no errors, nothing (a part off on purpose is left alone)", #ns.SoloCheck(nil, nil) == 0)
ns.DevErrorEntries = nil

-- Row fades: while the rows run, both fades take ns.testFadeTime (0.2 s, not
-- the player's 1.5 s), and the player's own come back once it's cleared.
ns.db.fadeInTime, ns.db.fadeOutTime, ns.db.combatFadeInTime = 1.5, 1.5, 1.5
ns.testFadeTime = 0.2
Check("rows running: fade in and out at 0.2s", ns.FadeInTime() == 0.2 and ns.FadeOutTime() == 0.2,
	ns.FadeInTime() .. "/" .. ns.FadeOutTime())
ns.testFadeTime = nil
Check("rows done: the player's fades back", ns.FadeInTime() == 1.5 and ns.FadeOutTime() == 1.5,
	ns.FadeInTime() .. "/" .. ns.FadeOutTime())

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
