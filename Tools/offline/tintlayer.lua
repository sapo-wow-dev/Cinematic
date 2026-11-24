-- /cine debug tintlayer offline (Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/tintlayer.lua < /dev/null
-- Dev/TintLayerTest.lua on the Forever stand-in with pretend time: the proven
-- plates step is left out, the numbers step waits for a fight, lays each wash
-- (the old UIParent place and WorldFrame's own texture among them) with a
-- shot each, waits again when the fight ends mid-run, and every wash is hidden
-- at the end. Then `full` runs the plates step too. PASS or FAIL per check.
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

local ns = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc")
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

local cine = true
ns.IsCineModeOn = function() return cine end
Cinematic_ToggleCineMode = function() cine = not cine end
ns.PadTestBox = function() end
ns.PadTestBoxHide = function() end
local shots = 0
Screenshot = function() shots = shots + 1 end
local fight = false
UnitAffectingCombat = function() return fight end
UnitExists = function() return fight end

-- Every texture made on WorldFrame (the washes the test lays there).
local made = {}
local create = WorldFrame.CreateTexture
WorldFrame.CreateTexture = function(self, ...)
	local texture = create(self, ...)
	made[#made + 1] = texture
	return texture
end

ns.HandleSlash("debug tintlayer 2") -- (both steps proven: picked by number)
Advance(3)
local log = CinematicDB.tintLayerTestLog
Check("plates step left out (not picked)", Has(log, "plates %d/") == nil and shots == 0, shots)
Check("waits for a fight first", Has(log, "numbers 1/") == nil)
fight = true
Advance(12)
-- (The stand-in keeps no strata: the game's line says BACKGROUND 0.)
Check("the old place laid", Has(log, "numbers 2/7: UIParent frame, BACKGROUND 0 .*got %u+ %d") ~= nil,
	Has(log, "numbers 2/"))
Check("today's place laid", Has(log, "numbers 3/7: a texture of WorldFrame's own, BACKGROUND .*got WorldFrame texture BACKGROUND") ~= nil,
	Has(log, "numbers 3/"))
fight = false
Advance(15)
local before = Count(log, "^numbers %d")
Check("fight ended: it waits again", before < 7, before)
fight = true
Advance(30)
Check("all 7 number shots", Count(log, "numbers %d/7") == 7, Count(log, "numbers %d/7"))
Check("a shot each", shots >= 7, shots)
Check("CVars logged", Has(log, "number CVars: damage_v2=") ~= nil)
Check("no FAIL", Has(log, "FAIL") == nil, Has(log, "FAIL"))
local shown = 0
for _, texture in ipairs(made) do if texture:IsShown() then shown = shown + 1 end end
Check("every WorldFrame wash hidden after", #made > 0 and shown == 0, ("%d made, %d shown"):format(#made, shown))
Check("CineMode back on", cine == true)

shots = 0
ns.HandleSlash("debug tintlayer full")
Advance(60)
log = CinematicDB.tintLayerTestLog
Check("full: plates step runs, 9 places", Count(log, "plates %d/9") == 9, Count(log, "plates %d/9"))
Check("full: numbers too", Count(log, "numbers %d/7") == 7)
Check("full: no FAIL", Has(log, "FAIL") == nil, Has(log, "FAIL"))

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
-- luacheck: pop
