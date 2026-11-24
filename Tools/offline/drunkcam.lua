-- /cine debug drunkcam offline (Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/drunkcam.lua < /dev/null
-- Dev/DrunkCamTest.lua on the Forever stand-in with pretend time: a sober
-- auto-run (steady facing), the drunk line from the game, three drunk
-- auto-runs (facing wobbling) and a held-forward one. Every step records its
-- time and summary, "It jumped" dumps the last frames, Q1 reads true,
-- runSwingBehind and CineMode are put back. PASS or FAIL per check.
-- luacheck: push ignore 111 112 113 121 122 212 431
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end
local function Has(log, pattern)
	for _, line in ipairs(log or {}) do
		if line:find(pattern) then return line end
	end
end
local function Count(log, pattern)
	local n = 0
	for _, line in ipairs(log or {}) do if line:find(pattern) then n = n + 1 end end
	return n
end

local ns, wow = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc")
local now = 100
local timers, tickers = {}, {}
GetTime = function() return now end
C_Timer.After = function(delay, fn) timers[#timers + 1] = { at = now + delay, fn = fn } end
C_Timer.NewTicker = function(every, fn)
	local t = { every = every, next = now + every, fn = fn, Cancel = function(self) self.cancelled = true end }
	tickers[#tickers + 1] = t
	return t
end
local firstFrame = #wow.frames + 1
local function Advance(seconds)
	local stop = now + seconds
	while now < stop do
		now = now + 0.1
		local due = {}
		for i = #timers, 1, -1 do
			if timers[i].at <= now then due[#due + 1] = table.remove(timers, i) end
		end
		for i = #due, 1, -1 do due[i].fn() end
		for _, t in ipairs(tickers) do
			if not t.cancelled and t.next <= now then
				t.next = now + t.every
				t.fn(t)
			end
		end
		-- (Only the test's own recorder frame: made after load, with an OnUpdate.)
		for i = firstFrame, #wow.frames do
			local f = wow.frames[i]
			local script = f.GetScript and f:GetScript("OnUpdate")
			if script then script(f, 0.1) end
		end
	end
end

local cine = true
ns.IsCineModeOn = function() return cine end
Cinematic_ToggleCineMode = function() cine = not cine end
ns.PadTestBox = function() end
ns.PadTestBoxHide = function() end
Screenshot = function() end
DRUNK_MESSAGE_SELF3 = "You feel drunk.  Whoa!"
local autorun, speed, drunk = false, 0, false
ns.IsAutoRunning = function() return autorun end
GetUnitSpeed = function() return speed end
local facing = 1
GetPlayerFacing = function()
	if drunk then facing = facing + (math.random() - 0.5) * 0.3 end -- (+-8.6 degrees a frame)
	return facing
end
-- Real post-hooks (the stand-in's do nothing), and a stack naming the dev
-- copy's camera code: the writer and "ours" must read it as Cinematic's.
local cvars = {}
SetCVar = function(name, value) cvars[name] = tostring(value) end
GetCVar = function(name) return cvars[name] end
hooksecurefunc = function(a, b, c)
	local t, name, hook = _G, a, b
	if type(a) == "table" then t, name, hook = a, b, c end
	local orig = t[name]
	t[name] = function(...) local r = { orig(...) } hook(...) return unpack(r) end
end
debugstack = function()
	return "[string \"@Interface/AddOns/CinematicDev/Camera/Camera.lua\"]:3080: in function <x>\n"
end
local function Writes() -- (a crawl and back, as run 1 saw)
	SetCVar("cameraPitchMoveSpeed", "1.00")
	SetCVar("cameraPitchMoveSpeed", "90")
	SetCVar("cameraPitchMoveSpeed", "90")
end

ns.HandleSlash("debug drunkcam")
Check("CineMode left alone at the start (on)", cine == true)
autorun, speed = true, 7
Advance(5)
Writes()
Advance(18)
local log = CinematicDB.drunkCamTestLog
Check("sober recorded", Has(log, "sober CineMode on: 2%d s recorded") ~= nil, Has(log, "sober CineMode on"))
Check("a setting change logged with its writer", Has(log, "cvar cameraPitchMoveSpeed .* %-> 1%.00 by CinematicDev/Camera/Camera%.lua:3080") ~= nil,
	Has(log, "cvar cameraPitchMoveSpeed"))
Check("writes counted, the repeat too", Has(log, "setting writes sober CineMode on: cameraPitchMoveSpeed x3; changes 2") ~= nil,
	Has(log, "setting writes sober"))
Check("our calls not called OTHER", Has(log, "OTHER") == nil, Has(log, "OTHER"))
Check("step 2 turned CineMode off", cine == false)
Advance(23)
Check("sober CineMode off recorded", Has(log, "sober CineMode off: 2%d s recorded") ~= nil)
autorun, speed = false, 0
Advance(1)
drunk = true
wow.Fire("CHAT_MSG_SYSTEM", DRUNK_MESSAGE_SELF3)
Advance(1)
Check("drunk line woke the drink step", Has(log, "drunk by CHAT_MSG_SYSTEM") ~= nil, Has(log, "drunk by"))
Check("the drunk strings logged", Has(log, "game's drunk strings: .*3=You feel drunk") ~= nil
	and Has(log, "last system/emote lines: SYSTEM: You feel drunk") ~= nil)
autorun, speed = true, 7
Advance(10)
Writes()
local run = ns.TestKit.Running()
local mark = run and run.buttons and run.buttons["It jumped"]
Check("It jumped button shown", mark ~= nil)
if mark and mark.onClick then mark.onClick() end
Check("a mark dumps the last frames", Has(log, "MARK: you saw") ~= nil and Has(log, " d%-?%d") ~= nil)
Check("a mark lists the setting changes near it", Has(log, "setting changes in those 1%.5 s: .*cameraPitchMoveSpeed") ~= nil,
	Has(log, "setting changes in those"))
Advance(14)
Check("step 5 turned CineMode off", cine == false)
Advance(24)
autorun = false
Check("four summaries", Count(log, "summary ") == 4, Count(log, "summary "))
Check("per-second lines", Count(log, " sec: frames ") >= 70, Count(log, " sec: frames "))
Check("facing jumps logged while drunk", Has(log, "facing jump") ~= nil)
Check("compare lines", Count(log, "compare ") == 4, Count(log, "compare "))
local done = Has(log, "DONE: ")
Check("finished DONE, no fail", done and done:find(" 0 fail", 1, true) ~= nil, done)
Check("CineMode back on", cine == true)
Check("undo cleared", CinematicDB.drunkCamTestUndo == nil)

-- No drinks: the drink step skipped, the drunk steps skip too. (Sober again:
-- the drunk line from the run above would say drunk.)
ns.drunkCamLevel = nil
ns.HandleSlash("debug drunkcam 3 4 5")
Advance(1)
run = ns.TestKit.Running()
local skip = run and run.buttons and run.buttons["Skip step"]
if skip and skip.onClick then skip.onClick() end
Advance(2)
log = CinematicDB.drunkCamTestLog
local skips = Count(log, "verdict SKIP .*not drunk")
Check("no drinks: drunk steps skip", skips == 2, skips)
if skips ~= 2 then for _, line in ipairs(log) do print("  log: " .. line) end end
for _, line in ipairs(log) do if line:find("FAIL") or line:find("error") then print("  log: " .. line) end end
print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
-- luacheck: pop
