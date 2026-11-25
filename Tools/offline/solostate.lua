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
	C_AddOns.EnableAddOn = function(name) calls[#calls + 1] = "on " .. name Find(name)[2] = 2 end
	C_AddOns.DisableAddOn = function(name) calls[#calls + 1] = "off " .. name Find(name)[2] = 0 end
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

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
