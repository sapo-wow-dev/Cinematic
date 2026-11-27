-- The event rule words' kit test, played offline (Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/eventfactstest.lua < /dev/null
-- Dev/EventFactsTest.lua (/cine debug eventfacts) on the stand-in game,
-- Forever then retail: pretend timers, the player mounting and getting off
-- with the game's event (step 3), then its log: DONE, 0 fail, the mount
-- counted twice. Then a stale word on purpose (IsMounted changed with no
-- event, as a game that didn't send it): the test must FAIL it, naming the
-- word and the events before. PASS or FAIL per check.
-- luacheck: push ignore 111 112 113 121 122 212 431
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local function RunClient(client)
	print("== " .. client)
	local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
	local now = 100
	GetTime = function() return now end
	debugprofilestop = function() return now * 1000 end
	InCombatLockdown = function() return false end
	UnitAffectingCombat = function() return false end
	local mounted = false
	IsMounted = function() return mounted end
	UnitIsAFK = function() return false end
	UnitIsDeadOrGhost = function() return false end
	UnitCastingInfo = function() return nil end
	UnitChannelInfo = function() return nil end
	IsResting = function() return false end
	IsInInstance = function() return false, "none" end
	GetRealZoneText = function() return "Elwynn Forest" end
	ns.OnTaxi = function() return false end
	wow.Fire("PLAYER_ENTERING_WORLD") -- (before the pretend timers: login's own timers stay the stand-in's)
	local timers, tickers = {}, {}
	C_Timer.After = function(delay, fn) timers[#timers + 1] = { at = now + delay, fn = fn } end
	C_Timer.NewTicker = function(every, fn)
		local t = { every = every, next = now + every, fn = fn, Cancel = function(self) self.cancelled = true end }
		tickers[#tickers + 1] = t
		return t
	end
	local firstNew = #wow.frames + 1
	local function Advance(seconds)
		local stop = now + seconds
		while now < stop do
			now = now + 0.05
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
			for i = firstNew, #wow.frames do
				local f = wow.frames[i]
				local onUpdate = f._scripts and f._scripts.OnUpdate
				if onUpdate then onUpdate(f, 0.05) end
			end
		end
	end
	ns.noRealLayout = true
	ns.IsCineModeOn = function() return false end
	ns.PadTestBox, ns.PadTestBoxHide, ns.TestPrompt = function() end, function() end, function() end
	Screenshot = function() end
	local function Mount(on)
		mounted = on
		wow.Fire("PLAYER_MOUNT_DISPLAY_CHANGED")
	end
	local function Log() return CinematicDB.eventFactsTestLog or {} end
	local function Has(text)
		for _, line in ipairs(Log()) do if line:find(text, 1, true) then return line end end
	end

	-- 1. The run as the player does it: hands off, then mount and get off.
	CinematicDB.eventFactsTestLog = nil
	ns.HandleSlash("debug eventfacts full")
	Advance(12) -- (rest 6 s, fake group 3 s)
	Mount(true)
	Advance(2)
	Mount(false)
	Advance(8)
	local done = Has("DONE: ")
	Check("finished DONE", done ~= nil, done or Log()[#Log()])
	Check("0 fail", done and done:find(" 0 fail", 1, true) ~= nil, done)
	local bad = {}
	for _, line in ipairs(Log()) do
		if line:find("FAIL", 1, true) then bad[#bad + 1] = line end
	end
	if #bad > 0 then for i = 1, math.min(6, #bad) do print("    " .. bad[i]) end end
	Check("the mount counted each way", Has("PLAYER_MOUNT_DISPLAY_CHANGED 2 time(s)") ~= nil,
		Has("PLAYER_MOUNT_DISPLAY_CHANGED"))
	Check("the cost logged", Has(" ms now, ") ~= nil, Has(" ms now, "))
	Check("/cine debug group put back", ns.fakeGroup == nil, tostring(ns.fakeGroup))

	-- 2. A word gone stale on purpose (IsMounted changed, no event): the test
	-- must catch it, naming the word and the events before.
	CinematicDB.eventFactsTestLog = nil
	ns.HandleSlash("debug eventfacts 1")
	Advance(1)
	mounted = true -- (no PLAYER_MOUNT_DISPLAY_CHANGED: a game that didn't send it)
	Advance(8)
	local stale = Has("mounted stale")
	Check("a stale word FAILs, named", stale ~= nil and stale:find("the game says on, the rules read off", 1, true) ~= nil,
		stale)
	Check("the stale line lists the events before", stale ~= nil and stale:find("events since 3 s before", 1, true) ~= nil)
	mounted = false
	wow.Fire("PLAYER_MOUNT_DISPLAY_CHANGED")
	Advance(2)
end

RunClient("forever")
RunClient("retail")
-- luacheck: pop
print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
