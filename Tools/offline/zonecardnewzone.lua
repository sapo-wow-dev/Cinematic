-- /cine debug zonecard 10 on the stand-in (dev tool, offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/zonecardnewzone.lua < /dev/null
-- The game step for the New zone card off by default (2026-11-23, "DUN
-- MOROGH" slammed big): run through the kit with pretend time, on Forever then
-- retail. Its checks all pass on the fix, it doesn't pass by accident (a
-- player with New zone still on in a profile: FAIL), and it puts New zone,
-- Discovered and the seen zones back as they were. PASS or FAIL per check.
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

local function RunClient(client)
	print("== " .. client)
	local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function() end)
	local now = 100
	local timers = {}
	GetTime = function() return now end
	C_Timer.After = function(delay, fn) timers[#timers + 1] = { at = now + (delay or 0), fn = fn } end
	local tickers = {}
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
			for i = #due, 1, -1 do pcall(due[i].fn) end
			-- (The card's fades: its frame's OnUpdate, as the game runs it.)
			local card = _G.CinematicCard
			local onUpdate = card and card:GetScript("OnUpdate")
			if onUpdate then pcall(onUpdate, card, 0.1) end
			for _, t in ipairs(tickers) do
				if not t.cancelled and t.next <= now then
					t.next = now + t.every
					pcall(t.fn, t)
				end
			end
		end
	end
	local shots = 0
	Screenshot = function() shots = shots + 1 end
	ns.PadTestBox = function() end
	ns.PadTestBoxHide = function() end

	local function Run(label)
		CinematicDB.zoneCardTestLog = nil
		shots = 0
		ns.HandleSlash("debug zonecard 10")
		Advance(40)
		local log = CinematicDB.zoneCardTestLog
		local done = Has(log, "DONE: ")
		print("   " .. label .. ": " .. tostring(done))
		return log, done
	end

	-- 1: a player after the update, as it leaves them.
	ns.db.newZoneOffV1, ns.db.cardNewZoneOn, ns.db.cardDiscoverOn = true, false, nil
	ns.chardb.cardSeen = { zones = { ["Elwynn Forest"] = true }, instances = {} }
	local log, done = Run("after the update")
	Check("finished", done ~= nil, done)
	Check("no FAIL", done and done:find(" 0 fail", 1, true) ~= nil, done)
	Check("8 checks pass", done and done:find("8 pass", 1, true) ~= nil, done)
	Check("the small card for a new zone", Has(log, "verdict PASS newzoneoff: New zone off, a new zone: discover") ~= nil,
		Has(log, "New zone off, a new zone"))
	Check("the big card once ticked", Has(log, "verdict PASS newzoneoff: New zone ticked again, a new zone: newZone") ~= nil,
		Has(log, "New zone ticked again"))
	Check("two screenshots", shots == 2, shots)
	Check("New zone put back off", ns.db.cardNewZoneOn == false, tostring(ns.db.cardNewZoneOn))
	Check("Discovered put back (was unset)", ns.db.cardDiscoverOn == nil, tostring(ns.db.cardDiscoverOn))
	Check("made-up zones not left in the seen list", not ns.chardb.cardSeen.zones["Cinematic Test Vale"]
		and not ns.chardb.cardSeen.zones["Cinematic Test Heights"])
	Check("the player's own seen zones kept", ns.chardb.cardSeen.zones["Elwynn Forest"] == true)

	-- 2: can't pass by accident: New zone still on in a saved profile.
	ns.db.profiles = ns.db.profiles or {}
	ns.db.profiles.TestStillOn = { cardNewZoneOn = true }
	log = Run("a profile still on")
	Check("a profile with New zone on: FAIL names it", Has(log, "verdict FAIL newzoneoff: no saved profile .*TestStillOn") ~= nil,
		Has(log, "no saved profile"))
	ns.db.profiles.TestStillOn = nil

	-- 3: can't pass by accident: New zone still on in your settings.
	ns.db.cardNewZoneOn = true
	log = Run("still on")
	Check("New zone on in your settings: FAIL", Has(log, "verdict FAIL newzoneoff: New zone off in your settings") ~= nil,
		Has(log, "New zone off in your settings"))
	Check("...and the new zone gets the big card: FAIL", Count(log, "verdict FAIL newzoneoff: New zone off, a new zone: newZone") == 1,
		Has(log, "New zone off, a new zone"))
	Check("put back on as it was", ns.db.cardNewZoneOn == true)
	ns.db.cardNewZoneOn = false
end

RunClient("forever")
RunClient("retail")
print(fails == 0 and "ALL PASS" or (fails .. " FAIL"))
if fails > 0 then os.exit(1) end
-- luacheck: pop
