-- /cine debug pagecost (Dev/PageCostTest.lua) through the kit on the
-- stand-in, both clients: every step passes, the login build's numbers are
-- there, every page made on first open gets made, and the sum is worked out.
-- (Memory here is the stand-in's Lua memory: only the run is checked, not the numbers.)
--
--   python -I Tools/offline/run.py Tools/offline/pagecosttest.lua
-- Exit 1 on any problem.
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

local function RunClient(client)
	print("== " .. client)
	local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
	local now = 100
	local timers, tickers = {}, {}
	GetTime = function() return now end
	C_Timer.After = function(delay, fn) timers[#timers + 1] = { at = now + delay, fn = fn } end
	C_Timer.NewTicker = function(every, fn)
		local t = { every = every, next = now + every, fn = fn, Cancel = function(self) self.cancelled = true end }
		tickers[#tickers + 1] = t
		return t
	end
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
		end
	end
	UpdateAddOnMemoryUsage = function() end
	GetAddOnMemoryUsage = function() return collectgarbage("count") end
	EnumerateFrames = function(after)
		local list = wow.frames
		if not after then return list[1] end
		for i, frame in ipairs(list) do
			if frame == after then return list[i + 1] end
		end
	end
	Screenshot = function() end
	local waiting = 0
	for _, entry in ipairs(ns.lazySettingsPages or {}) do
		if not entry.made then waiting = waiting + 1 end
	end
	Check("pages wait to be made on first open", waiting > 0, waiting)
	ns.HandleSlash("debug pagecost")
	Advance(60)
	local log = CinematicDB.pageCostTestLog
	Check("the run finished", Has(log, "DONE: ") ~= nil)
	Check("no FAIL", Has(log, "FAIL") == nil, Has(log, "FAIL"))
	Check("the login build's numbers", Has(log, "login build: %d+ ms") ~= nil)
	Check("a line per page made", Has(log, "Nameplates%s+%d+ ms") ~= nil)
	Check("every page made", Has(log, "PASS.*every page made %(0 left%)") ~= nil)
	Check("the sum", Has(log, "KB per object") ~= nil)
	for _, entry in ipairs(ns.lazySettingsPages or {}) do
		if not entry.made then Check("made: " .. tostring(entry.name), false) end
	end
	if fails > 0 then
		for _, line in ipairs(log or {}) do print("  | " .. line) end
	end
end

RunClient("forever")
RunClient("retail")
print(fails == 0 and "pagecost test: 0 problems" or ("pagecost test: %d problems"):format(fails))
os.exit(fails == 0 and 0 or 1)
-- luacheck: pop
