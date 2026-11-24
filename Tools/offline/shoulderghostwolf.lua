-- The Shoulder Cam's Ghost Wolf size (offline, Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/shoulderghostwolf.lua <forever|retail>
-- Ghost Wolf (form 16) is the same spirit wolf for every race, so a size
-- measured as one race (a calibrate run, db.shoulderCamScales) is every
-- race's (Camera/ShoulderCam.lua, ONE_MODEL_FORMS). Druid forms stay per race
-- (a Tauren's cat isn't an elf's). PASS or FAIL.
-- luacheck: push ignore 111 112 113 121 122
local client = arg and arg[1] or "forever"
package.path = "Tools/offline/?.lua;" .. package.path
local wow = dofile("Tools/offline/wow.lua")
wow.Install(client)
local ns = {}
for line in io.lines("Cinematic.toc") do
	line = line:gsub("\r", "")
	if line ~= "" and not line:find("^#") then
		local chunk, loadErr = loadfile((line:gsub("\\", "/")))
		if not chunk then print("FAIL " .. line .. " doesn't compile: " .. tostring(loadErr)) end
		if chunk then
			local ok, err = pcall(chunk, "Cinematic", ns)
			if not ok then wow.Warn(line .. ": " .. tostring(err)) end
		end
	end
end
wow.Fire("ADDON_LOADED", "Cinematic")
wow.Fire("PLAYER_LOGIN")
local form, race = nil, "Orc"
UnitRace = function() return race, race end
UnitSex = function() return 2 end
IsMounted = function() return false end
GetShapeshiftFormID = function() return form end
local now = 100
GetTime = function() return now end
-- luacheck: pop

local failed = 0
local function Check(ok, text)
	print((ok and "PASS " or "FAIL ") .. text)
	if not ok then failed = failed + 1 end
end
local Key, Scale = ns.ShoulderModelKey, ns.ShoulderModelScale
Check(Key ~= nil and Scale ~= nil, "ns.ShoulderModelKey and ns.ShoulderModelScale found")
if not (Key and Scale) then return print("1 FAILED") end
local function Settled() Key() now = now + 1 return Key() end

ns.db.shoulderCamScales = {}
form = 16
Check(Settled() == "Orc-2-form16", "an Orc in Ghost Wolf: " .. tostring(Key()))
local scale, from = Scale()
Check(scale == 1.78 and from == "built in, every race's",
	("an Orc goes by the built-in wolf (a Dwarf's run, 2026-11-24): %s (%s)"):format(tostring(scale), tostring(from)))

-- A calibrate run as the Orc: the Orc's, and the Tauren's too (same wolf).
ns.db.shoulderCamScales["Orc-2-form16"] = 1.41
scale, from = Scale()
Check(scale == 1.41 and from == "measured here", ("the Orc's own run: %s (%s)"):format(scale, from))
race = "Tauren"
Settled()
scale, from = Scale()
Check(scale == 1.41 and from:find("as Orc") ~= nil, ("a Tauren in Ghost Wolf goes by the Orc's run: %s (%s)"):format(scale, from))

-- Not for druid forms: a Tauren's cat doesn't take an elf's measured cat.
form = 1
Settled()
ns.db.shoulderCamScales["NightElf-2-form1"] = 1.99
scale, from = Scale()
Check(scale ~= 1.99, ("a Tauren's cat doesn't borrow the elf's saved cat: %s (%s)"):format(scale, from))

-- Back on foot: the race's own size, no wolf.
form = nil
Settled()
scale, from = Scale()
Check(scale ~= 1.41, ("back on foot: %s (%s)"):format(scale, from))

print(failed == 0 and "ALL PASSED" or (failed .. " FAILED"))
