-- Exit CineMode's Show in row, tick by tick (offline, Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/exitrowtick.lua <forever|retail>
-- Core.lua's ShouldBeCinematic called straight (taken from ns.ProfileName as
-- it loads), with pretend time, a few seconds after a /reload (lastBusy
-- fresh): the row's Always takes CineMode off ("row"); unticked, CineMode
-- comes back at once and stays, not just one tick before the Back into
-- CineMode after wait (in game run 2, 2026-11-21). PASS or FAIL per check.
-- luacheck: push ignore 111 112 113 121 122
local client = arg and arg[1] or "forever"
package.path = "Tools/offline/?.lua;" .. package.path
local wow = dofile("Tools/offline/wow.lua")
wow.Install(client)
local now = 1000
local ns = setmetatable({}, { __newindex = function(t, k, v)
	if k == "ProfileName" then
		rawset(t, k, function(fn, name)
			if name == "ShouldBeCinematic" then rawset(t, "_ShouldBeCinematic", fn) end
			return v(fn, name)
		end)
	else
		rawset(t, k, v)
	end
end })
for line in io.lines("Cinematic.toc") do
	line = line:gsub("\r", "")
	if line ~= "" and not line:find("^#") then
		local chunk = loadfile((line:gsub("\\", "/")))
		if chunk then
			local ok, err = pcall(chunk, "Cinematic", ns)
			if not ok then wow.Warn(line .. ": " .. tostring(err)) end
		end
	end
end
wow.Fire("ADDON_LOADED", "Cinematic")
wow.Fire("PLAYER_LOGIN")
GetTime = function() return now end
-- luacheck: pop

local failed = 0
local function Check(ok, text)
	print((ok and "PASS " or "FAIL ") .. text)
	if not ok then failed = failed + 1 end
end
local Should = ns._ShouldBeCinematic
Check(Should ~= nil, "ShouldBeCinematic found")
if not Should then return print("1 FAILED") end
ns.db.enabled, ns.db.fadeUI = true, true
ns.ProfileChosen = function() return true end
ns.RestartTimers() -- (lastBusy now, as a /reload has it)
local function Tick()
	now = now + 0.5
	return Should(now)
end
Check(Tick() == true, "CineMode on to start with")
ns.db.exitByRow, ns.db.cineExitAlways = true, true
local off = Tick()
Check(off == false and ns.cineOffCode == "row", "row Always: off for the row (" .. tostring(ns.cineOffCode) .. ")")
ns.db.cineExitAlways = false
local back = { Tick(), Tick(), Tick(), Tick() }
Check(back[1] and back[2] and back[3] and back[4],
	"row unticked: back at once and stays (" .. tostring(ns.cineOffWhy) .. ")")
ns.db.exitByRow = false
Check(Tick() == true, "the row off: CineMode stays on")
print(failed == 0 and "ALL PASS" or (failed .. " FAILED"))
