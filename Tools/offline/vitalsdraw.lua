-- Vitals with secret health, how often its layers are drawn (offline, Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/vitalsdraw.lua <forever|retail>
-- Atmosphere/LowHealth.lua drew every layer every frame while your health is
-- secret (fights on WoW Forever, always): it can't tell full health from low,
-- and the game's alpha hides the frame at full. 0.09 ms a frame at 113 fps
-- (Tools/perf/ledger.md 2026-11-23). Now drawn 40 times a second then, every
-- frame with plain health. The real Update loop, its health read stood in
-- for (secret, or a plain 30%), pretend time at 120 fps. PASS or FAIL.
-- luacheck: push ignore 111 112 113 121 122
local client = arg and arg[1] or "forever"
package.path = "Tools/offline/?.lua;" .. package.path
local wow = dofile("Tools/offline/wow.lua")
wow.Install(client)
local now = 1000
local health = { share = nil } -- (nil: secret)
local applied = 0
local ns = setmetatable({}, { __newindex = function(t, k, v)
	if k == "Profiled" then
		rawset(t, k, function(name, fn)
			if name == "Vitals: apply" then
				local real = fn
				fn = function(...) applied = applied + 1 return real(...) end
			elseif name == "Vitals: health" then
				fn = function() return health.share, true, false, false end
			elseif name == "Vitals" then
				rawset(t, "_vitalsUpdate", fn)
			end
			return v(name, fn)
		end)
	else
		rawset(t, k, v)
	end
end })
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
wow.Fire("ADDON_LOADED", "Cinematic")
wow.Fire("PLAYER_LOGIN")
GetTime = function() return now end
InCombatLockdown = function() return true end
UnitAffectingCombat = function() return true end
UnitHealthPercent = function() return 0.5 end
Enum = Enum or {}
Enum.LuaCurveType = Enum.LuaCurveType or { Linear = 1 }
C_CurveUtil = { CreateCurve = function() return { SetType = function() end, AddPoint = function() end } end }
-- luacheck: pop

local failed = 0
local function Check(ok, text)
	print((ok and "PASS " or "FAIL ") .. text)
	if not ok then failed = failed + 1 end
end

local update = ns._vitalsUpdate and { CreateFrame("Frame"), ns._vitalsUpdate }
Check(update ~= nil, "Vitals' Update loop found")
if not update then return print("1 FAILED") end
local function Run(seconds)
	local dt = 1 / 120
	for _ = 1, math.floor(seconds / dt + 0.5) do
		now = now + dt
		local ok, err = pcall(update[2], update[1], dt)
		if not ok then wow.Warn("Vitals update: " .. tostring(err)) return false end
	end
	return true
end

Check(Run(2), "secret health, in a fight: 2 s run without errors") -- (the edges come in)
applied = 0
Run(1)
local secretDraws = applied
Check(secretDraws >= 36 and secretDraws <= 41,
	("secret health at 120 fps: drawn %d times in a second (40; every frame was 120)"):format(secretDraws))

-- A big hit with secret health (its amount plain): drawn that same frame.
UnitHealth = function() return nil end -- luacheck: ignore 121
UnitHealthMax = function() return 100 end -- luacheck: ignore 121
local hitFrames, drawnOnHit = 0, 0
for _ = 1, 3 do
	Run(1 / 120) -- (a frame drawn or not; then the hit lands mid-wait)
	applied = 0
	wow.Fire("UNIT_COMBAT", "player", "WOUND", "", 60)
	Run(1 / 120)
	hitFrames, drawnOnHit = hitFrames + 1, drawnOnHit + applied
end
Check(drawnOnHit == hitFrames, ("a big hit: drawn the frame it lands (%d of %d)"):format(drawnOnHit, hitFrames))

health.share = 0.3
Run(0.5)
applied = 0
Run(1)
Check(applied >= 110, ("plain health (30%%): drawn every frame (%d in a second)"):format(applied))

print(failed == 0 and "ALL PASSED" or (failed .. " FAILED"))
