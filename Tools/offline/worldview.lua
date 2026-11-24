-- /cine debug worldview (Dev/WorldViewTest.lua) offline, Lua 5.1 via run.py:
--   python -I Tools/offline/run.py Tools/offline/worldview.lua < /dev/null
-- A stand-in WorldFrame that keeps its points: steps 1-4 pass (squeezed
-- between the bars, the ease in follows every frame, put back), a pretend
-- fight takes steps 5-7 through PLAYER_REGEN_DISABLED / _ENABLED, and the
-- whole screen is put back at the end. Then step 9 (top and bottom bars
-- apart, the Letterbox Style page's link) on its own, the letterbox ticked
-- here as Core.lua's loop does. PASS or FAIL per check.
-- luacheck: push ignore 111 112 113 121 122 212 431
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local function Count(log, pattern)
	local n = 0
	for _, line in ipairs(log or {}) do if line:find(pattern) then n = n + 1 end end
	return n
end

local function RunClient(client)
	print("== " .. client)
	local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
	local now = 100
	local timers, tickers, updaters = {}, {}, {}
	GetTime = function() return now end
	debugprofilestop = function() return now * 1000 end
	C_Timer.After = function(delay, fn) timers[#timers + 1] = { at = now + delay, fn = fn } end
	C_Timer.NewTicker = function(every, fn)
		local t = { every = every, next = now + every, fn = fn, Cancel = function(self) self.cancelled = true end }
		tickers[#tickers + 1] = t
		return t
	end
	local make = CreateFrame
	CreateFrame = function(...)
		local f = make(...)
		updaters[#updaters + 1] = f
		return f
	end
	local function Advance(seconds)
		local stop = now + seconds
		while now < stop do
			now = now + 0.05
			for _, f in ipairs(updaters) do
				local fn = f:GetScript("OnUpdate")
				if fn then fn(f, 0.05) end
			end
			-- (Step 9: the letterbox ticked as Core.lua's loop does, out of CineMode.)
			if ns.driveLetterbox then
				local on = ns.IsCineModeOn()
				ns.UpdateLetterbox(ns.LetterboxExtra(on, InCombatLockdown(), on), 0.05)
			end
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
		end
	end
	local cine = false
	ns.IsCineModeOn = function() return cine end
	Screenshot = function() end
	ns.PadTestBox = function() end
	ns.PadTestBoxHide = function() end
	local lockdown = false
	InCombatLockdown = function() return lockdown end

	-- The screen: 768 high; WorldFrame keeps its offsets.
	local H = 768
	UIParent.GetHeight = function() return H end
	UIParent.GetTop = function() return H end
	UIParent.GetBottom = function() return 0 end
	local wf = { top = 0, bottom = 0, n = 2 }
	WorldFrame.ClearAllPoints = function() wf.n = 0 end
	WorldFrame.SetAllPoints = function() wf.top, wf.bottom, wf.n = 0, 0, 2 end
	WorldFrame.SetPoint = function(_, p, _, _, _, y)
		if p == "TOPLEFT" then wf.top = y or 0 elseif p == "BOTTOMRIGHT" then wf.bottom = y or 0 end
		wf.n = wf.n + 1
	end
	WorldFrame.GetTop = function() return H + wf.top end
	WorldFrame.GetBottom = function() return wf.bottom end
	WorldFrame.GetRect = function() return 0, wf.bottom, 1024, H + wf.top - wf.bottom end
	WorldFrame.GetNumPoints = function() return wf.n end
	WorldFrame.IsIgnoringParentScale = function() return true end

	ns.HandleSlash("debug worldview 1 2 3 4 5 6 7") -- (the probe; 8 and 10, the switch: letterboxworld.lua; 9 below)
	Advance(30) -- steps 1-4, then waiting for the fight
	local log = CinematicDB.worldViewTestLog
	Check("steps 1-4 pass, waiting on the fight", Count(log, "^%s*FAIL") == 0 and Count(log, "PASS") >= 7,
		("%d PASS, %d FAIL"):format(Count(log, "PASS"), Count(log, "^%s*FAIL")))
	Check("squeezed before the fight", math.abs(wf.bottom - H * 0.12) < 0.5, wf.bottom)
	lockdown = true
	wow.Fire("PLAYER_REGEN_DISABLED")
	Check("put back in the fight's first event", wf.bottom == 0 and wf.top == 0)
	Advance(5)
	lockdown = false
	wow.Fire("PLAYER_REGEN_ENABLED")
	Advance(10)
	log = CinematicDB.worldViewTestLog
	local fail = Count(log, "^%s*FAIL")
	Check("the whole run: no FAIL with nothing blocked", fail == 0, fail .. " FAIL")
	Check("DONE line", Count(log, "DONE") + Count(log, "done") > 0)
	Check("whole screen at the end", wf.bottom == 0 and wf.top == 0 and wf.n == 2)
	if fail > 0 then for _, line in ipairs(log) do print("  | " .. line) end end

	-- Step 9, apart (top and bottom bars apart, the page's link): its own run.
	UIParent.GetWidth = function() return 1835 end
	local bars = {}
	for _, side in ipairs({ "top", "bottom" }) do
		local tex = ns.letterbox and ns.letterbox[side]
		if tex then
			tex.SetHeight = function(_, h) bars[side] = h end
			tex.GetHeight = function() return bars[side] or 0 end
		end
	end
	CinematicDB.worldViewTestLog = nil
	ns.driveLetterbox = true
	ns.noRealLayout = true -- (the stand-in places every frame alike: r:Overlaps can't judge them)
	-- (As run 1 in game, qafed: CineMode's bars up as the step starts, CineMode
	-- off at once. The key would flip them out, not in, and the step hung.)
	ns.db.letterbox, cine = true, true
	Advance(2)
	Check("step 9 apart: CineMode's bars up before it", ns.LetterboxUp(),
		("shown %s, top %s, letterbox %s"):format(tostring(ns.letterbox:IsShown()), tostring(bars.top), tostring(ns.db.letterbox)))
	cine = false
	ns.HandleSlash("debug worldview 9")
	Advance(30)
	log = CinematicDB.worldViewTestLog or {}
	fail = Count(log, "^%s*FAIL")
	Check("step 9 apart: passes", fail == 0 and Count(log, "PASS") >= 8,
		("%d PASS, %d FAIL"):format(Count(log, "PASS"), fail))
	Check("step 9 apart: whole screen at the end", wf.bottom == 0 and wf.top == 0)
	if fail > 0 or Count(log, "PASS") < 8 then
		for _, line in ipairs(log) do print("  | " .. line) end
		print(("  bars %s / %s, world top %s bottom %s, shown %s"):format(tostring(bars.top), tostring(bars.bottom),
			wf.top, wf.bottom, tostring(ns.letterbox and ns.letterbox:IsShown())))
	end
end

RunClient("forever")
RunClient("retail")
print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
-- luacheck: pop
