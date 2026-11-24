-- The preview watch (Dev/PreviewWatch.lua) is on by itself in the dev copy
-- (offline, Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/previewwatchon.lua
-- A fresh dev copy logs in watching (no command), the Style previews' moves
-- go to its log; "off" keeps it off after a login. Says PASS or FAIL per check.
local failed = 0
local function Check(ok, text)
	print((ok and "PASS " or "FAIL ") .. text)
	if not ok then failed = failed + 1 end
end

local ns = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc")
local db = _G.CinematicDB
Check(ns.PreviewTrace ~= nil, "a fresh login watches the previews by itself")
local log = db and db.previewWatchLog or {}
Check(log[#log] and log[#log]:find("login: watching", 1, true) ~= nil, "its log says so (" .. tostring(log[#log]) .. ")")
ns.PreviewTrace("sticky hold", nil, "test")
Check(log[#log] and log[#log]:find("sticky hold (test)", 1, true) ~= nil, "a preview move is logged")

ns.PreviewWatch("off")
Check(ns.PreviewTrace == nil and db.previewWatchOn == false, "off stops it and is kept")

-- (A login with it turned off: the saved setting as the game hands it back.)
local ns2 = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc", function()
	_G.CinematicDB = { previewWatchOn = false }
end)
Check(_G.CinematicDB.previewWatchOn == false, "the saved off is still there at login")
Check(ns2.PreviewTrace == nil, "a login with it off doesn't watch")

print(failed == 0 and "ALL PASS" or (failed .. " FAILED"))
os.exit(failed == 0 and 0 or 1)
