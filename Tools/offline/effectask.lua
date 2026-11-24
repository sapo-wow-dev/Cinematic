-- The Visual Effects rows, how often they're asked (offline, Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/effectask.lua <forever|retail>
-- Core.lua's main tick asked every effect's Show in row (ns.RowOnNow, and with
-- it the rule facts) on every tick in CineMode: 10 effects since 2026-11-23,
-- ~6 RowOnNow a frame while the tick ran at full pace (moving, a tooltip,
-- frames fading; Tools/perf/ledger.md 2026-11-23). Now every EFFECT_ASK
-- (0.1 s) in CineMode too, and at once when CineMode comes on or goes off, a
-- fight starts or ends, and while the effects demo runs and as it ends.
-- Checked on ns.effectAsk.Due, the tick's one test of it (the whole tick
-- doesn't run on the stand-in), and that the tick asks only through it.
-- PASS or FAIL.
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
-- luacheck: pop

local failed = 0
local function Check(ok, text)
	print((ok and "PASS " or "FAIL ") .. text)
	if not ok then failed = failed + 1 end
end
local ask = ns.effectAsk
Check(ask and ask.Due, "ns.effectAsk.Due found")
if not (ask and ask.Due) then return print("1 FAILED") end

-- The tick decides only through Due (no CineMode bypass left beside it).
local file = io.open("Core.lua")
local core = file:read("*a")
file:close()
Check(core:find("if atmo and effectAsk.Due(now, inCombat, effectsOn, ns.effectsDemo) then", 1, true) ~= nil
	and not core:find("local ask = atmo and (cinematic", 1, true), "the tick asks the rows only when Due says so")

-- In CineMode at 80 fps, every tick asking (the tick at its full pace).
local now = 1000
local function Count(seconds, fight, on, demo)
	local n = 0
	for _ = 1, math.floor(seconds * 80 + 0.5) do
		now = now + 1 / 80
		if ask.Due(now, fight, on, demo) then n = n + 1 end
	end
	return n
end
Count(0.5, false, true) -- (CineMode came on)
local n = Count(2, false, true)
Check(n >= 18 and n <= 21, ("CineMode, 2 s at 80 fps: asked %d times (every 0.1 s: 20; every tick was 160)"):format(n))

-- At once on a change, not up to 0.1 s later.
Count(0.05, false, true)
Check(ask.Due(now + 0.001, true, true), "a fight starts: asked the same tick")
now = now + 0.001
Check(ask.Due(now + 0.001, false, true), "the fight ends: asked the same tick")
now = now + 0.001
Check(ask.Due(now + 0.001, false, false), "CineMode goes off: asked the same tick")
now = now + 0.001
Check(ask.Due(now + 0.001, false, true), "CineMode comes on: asked the same tick")
now = now + 0.001
Check(not ask.Due(now + 0.001, false, true), "nothing changed, 2 ms later: not asked")
now = now + 0.002
Check(Count(0.2, false, true, { tint = true }) == 16, "the effects demo: asked every tick")
Check(ask.Due(now + 0.001, false, true, nil), "the demo ends: asked the same tick")

print(failed == 0 and "ALL PASSED" or (failed .. " FAILED"))
