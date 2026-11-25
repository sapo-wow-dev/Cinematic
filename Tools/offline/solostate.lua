-- /cine debug solo's addon list (Dev/AddonTest.lua ns.SoloAddons), offline:
--   python -I Tools/offline/run.py Tools/offline/solostate.lua < /dev/null
-- The addon kit's run for Journey Tracker (2026-11-25) failed "ran alone":
-- Auctionator loaded. Its first solo (none) turned Auctionator off, solo off
-- turned it back on, and the second solo read it as off: GetAddOnInfo's
-- reason stays DISABLED for the rest of the session (engine rule
-- forever.addons.enable-no-character), so it was never turned off again.
-- Now its enable state decides. Says PASS or FAIL per check.

-- (The addon list: name -> { state, reason }. Auctionator was switched back
-- on this session: state 2, reason still DISABLED.)
local list = {
	{ "CinematicDev", 2, nil },
	{ "JourneyTracker", 2, nil },
	{ "Auctionator", 2, "DISABLED" },
	{ "Questie", 0, "DISABLED" },
}
local calls = {}
local fake = {}
-- luacheck: push ignore 122
local function Install()
	local function Find(name)
		for i, each in ipairs(list) do if each[1] == name or i == name then return each end end
	end
	C_AddOns.GetNumAddOns = function() return #list end
	C_AddOns.GetAddOnInfo = function(i)
		local each = Find(i)
		if each then return each[1], each[1], "", true, each[3] end
	end
	C_AddOns.GetAddOnEnableState = function(name) local each = Find(name) return each and each[2] or 0 end
	C_AddOns.IsAddOnLoaded = function(name) local each = Find(name) return each and each[3] == nil end
	C_AddOns.GetAddOnDependencies = function() return nil end
	C_AddOns.GetAddOnOptionalDependencies = function() return nil end
	-- (Through fake.on/off: solo keeps its own copy of these from load, so a
	-- check that changes how they behave swaps the fake's, not C_AddOns'.)
	fake.on = function(name) calls[#calls + 1] = "on " .. name Find(name)[2] = 2 end
	fake.off = function(name) calls[#calls + 1] = "off " .. name Find(name)[2] = 0 end
	C_AddOns.EnableAddOn = function(...) return fake.on(...) end
	C_AddOns.DisableAddOn = function(...) return fake.off(...) end
	C_AddOns.SaveAddOns = function() end
end
-- luacheck: pop
local ns = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc", Install)

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail ~= nil and (" (" .. tostring(detail) .. ")") or ""))
end

CinematicDB.soloAddons = nil
ns.SoloAddons("JourneyTracker", true)
local did = table.concat(calls, ", ")
Check("an addon switched back on this session is turned off (its reason still says DISABLED)",
	did:find("off Auctionator", 1, true) ~= nil, did)
Check("the addon asked for and Cinematic stay on", not did:find("off JourneyTracker", 1, true)
	and not did:find("off CinematicDev", 1, true), did)
Check("an addon that's off stays off, untouched", not did:find("Questie", 1, true), did)
local turnedOff = CinematicDB.soloAddons and CinematicDB.soloAddons.turnedOff or {}
Check("solo off will turn it back on", turnedOff.Auctionator ~= nil)
Check("every switch took: nothing unconfirmed", CinematicDB.soloAddons and CinematicDB.soloAddons.unconfirmed == nil)

-- Each switch read back (run qcbb3, 2026-11-25: the opposite of solo's list
-- loaded and nothing said which switch didn't take). Stubborn ignores the
-- no-character call but takes the character one; Stuck ignores both.
ns.SoloAddons("off", true)
list[#list + 1] = { "Stubborn", 2, nil }
list[#list + 1] = { "Stuck", 2, nil }
local Disable = fake.off
fake.off = function(name, who)
	if name == "Stuck" or (name == "Stubborn" and who == nil) then
		calls[#calls + 1] = "ignored off " .. name .. (who and " for the character" or "")
		return
	end
	return Disable(name, who)
end
CinematicDB.soloBack = { on = { "Guidelime" }, off = {} }
calls = {}
ns.SoloAddons("JourneyTracker", true)
local solo = CinematicDB.soloAddons or {}
local stuck = table.concat(solo.unconfirmed or {}, ", ")
Check("an addon that ignores the plain call is switched with the character one", not stuck:find("Stubborn", 1, true)
	and table.concat(calls, ", "):find("ignored off Stubborn", 1, true) ~= nil, table.concat(calls, ", "))
Check("an addon that won't switch either way is named", stuck == "Stuck (still on)", stuck)
Check("a new solo drops the solo off's list-back check (it decides the list now)", CinematicDB.soloBack == nil)
fake.off = Disable

-- Solo off reads its own switches back too.
local Enable = fake.on
fake.on = function(name, who)
	if name == "Auctionator" then return end
	return Enable(name, who)
end
ns.SoloAddons("off", true)
local offStuck = table.concat(CinematicDB.soloOffUnconfirmed or {}, ", ")
Check("solo off names an addon it couldn't turn back on", offStuck:find("Auctionator (still off)", 1, true) ~= nil, offStuck)
fake.on = Enable

-- An addon on for this character only: loaded, but its state with no
-- character reads 0. The addon kit's no-addon stage left ElvUI on that way and
-- it loaded after the reload (run qa37c, 2026-11-25).
CinematicDB.soloAddons, CinematicDB.soloBack = nil, nil
list[#list + 1] = { "OneChar", 0, nil }
calls = {}
ns.SoloAddons("none", true)
did = table.concat(calls, ", ")
Check("an addon loaded but reading 0 (on for this character only) is turned off", did:find("off OneChar", 1, true) ~= nil, did)
Check("solo off will turn it back on", ((CinematicDB.soloAddons or {}).turnedOff or {}).OneChar ~= nil)
-- (Still loaded, now off by solo's own switch: the next solo leaves it off,
-- and its solo off doesn't turn it on.)
CinematicDB.soloAddons = nil
calls = {}
ns.SoloAddons("JourneyTracker", true)
did = table.concat(calls, ", ")
Check("an addon solo turned off this session isn't read as on", not did:find("OneChar", 1, true)
	and ((CinematicDB.soloAddons or {}).turnedOff or {}).OneChar == nil, did)

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
