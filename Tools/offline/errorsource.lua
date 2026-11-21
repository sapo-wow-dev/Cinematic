-- Whose error or warning the dev error window says it is (offline, Lua 5.1
-- via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/errorsource.lua < /dev/null
-- A warning from ShortestPathForever's error handler came with its path cut
-- short ("...ortestPathForever/...") and showed as "?, tainted by
-- ShortestPathForever" (Forever 2026-11-21). Now another addon's taint with
-- no folder found names that addon; our own lines read as before.
-- Says PASS or FAIL per check.
local ns = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc")

local fails = 0
local function Check(name, got, want)
	local ok = got == want
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. " (" .. tostring(got) .. ")")
end

local Source = ns.DevErrorSource
Check("test hook there", type(Source), "function")
if type(Source) ~= "function" then os.exit(1) end

Check("foreign, path cut short",
	Source("...ortestPathForever/Libs/ForeverCore/Core/SafeCall.lua:300: attempt to index local 'text' "
		.. "(a secret string value, while execution tainted by 'ShortestPathForever')"),
	"ShortestPathForever, another addon's")
Check("ours, path cut short, our taint",
	Source("...nematicDev/Style/UnitStyle.lua:12: boom (a secret number value, while execution tainted by 'CinematicDev')"),
	"?, tainted by CinematicDev")
Check("ours, full path",
	Source("Interface/AddOns/CinematicDev/Style/UnitStyle.lua:12: boom"),
	"CinematicDev")
Check("game file tainted by us",
	Source("Interface/AddOns/Blizzard_UnitFrame/UnitFrame.lua:250: compare (while execution tainted by 'CinematicDev')"),
	"Blizzard_UnitFrame, tainted by CinematicDev")
Check("folder in the stack wins over taint",
	Source("...cut/Foo.lua:1: x (tainted by 'Other')", "[Interface/AddOns/Other/Foo.lua]:1: in main chunk"),
	"Other")
Check("nothing to go on", Source("something broke"), "?")

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
