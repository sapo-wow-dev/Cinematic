-- The Shoulder Cam's form read (offline, Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/shoulderformread.lua <forever|retail>
-- Camera/ShoulderCam.lua's FormNow made a new function every read (~100 a
-- second with the Shoulder Cam on: 6.6 KB/s of garbage, Tools/perf/ledger.md
-- 2026-11-23). Now one function. Checked through ns.ShoulderModelKey: on foot,
-- a form's key, a secret form id keeps the last one, back on foot, and no
-- memory made per read. PASS or FAIL.
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
local form
UnitRace = function() return "Night Elf", "NightElf" end
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
local Key = ns.ShoulderModelKey
Check(Key ~= nil, "ns.ShoulderModelKey found")
if not Key then return print("1 FAILED") end

-- (A new form counts once its model's in: here, the wait for the model's
-- event run out.)
local function Settled() Key() now = now + 1 return Key() end
Check(Settled() == "NightElf-2", "on foot: " .. tostring(Key()))
form = 1 -- (cat)
Check(Settled() == "NightElf-2-form1", "in cat form: " .. tostring(Key()))
-- A secret form id (in a fight): arithmetic on it errors; the last one's kept.
form = setmetatable({}, { __add = function() error("secret") end })
Check(Settled() == "NightElf-2-form1", "a secret form id: the last one kept: " .. tostring(Key()))
form = nil
Check(Settled() == "NightElf-2", "back on foot: " .. tostring(Key()))

form = 1
collectgarbage("collect")
collectgarbage("stop")
local before = collectgarbage("count")
for _ = 1, 1000 do Key() end
local kb = collectgarbage("count") - before
collectgarbage("restart")
Check(kb < 10, ("1000 reads in a form made %.2f KB (the game's profiler had ~0.06 KB a read: a new function each)"):format(kb))

print(failed == 0 and "ALL PASSED" or (failed .. " FAILED"))
