-- The addon test's own judgment (Dev/AddonTest.lua), offline (Lua 5.1 via
-- Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/addontestsmarts.lua < /dev/null
-- Its first Questie run (2026-11-21) said PASS with 0 rows tested: Questie's
-- tracker was off in Questie's own options, so the frame never existed. And
-- its fight step showed nothing new in three runs. Now: a frame's kind
-- (numbers as #), steps skipped when the last run on the same version showed
-- no new kind in them ("full" asks again), and the frames our support names
-- that were never made. Says PASS or FAIL per check.
local ns, wow = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc")

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

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
