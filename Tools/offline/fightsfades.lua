-- Audit fixes for cameras, fights and fades (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/fightsfades.lua [forever|retail] < /dev/null
-- Audit 2026-11-22, on a stand-in CVar store and clock:
-- 1 a safety stop lets go of every set still holding game settings (only the
--   flight's and recenter's were: the death camera's and fly-by's kept camera
--   follow at 0 for the session);
-- 2 the max zoom raised by the idle zoom and by a camera script: put back
--   only once neither holds it (either lowered it under the other);
-- 3 Forever's raid aura stand-in waits out a fight to switch the game's
--   aura setting (each switch rebuilds the secure raid frames);
-- 5 a detached part refusing our code isn't written to as it's let go, and
--   the detached-part walker's update loop is set once, not every call;
-- 6 Damage Vision: a boss's end with a secret result queues no recap;
-- 8 Death Vision: the body's place looked at by the clock, not by adding up
--   the tint loop's single-frame times (5 looks a second: 12 times late).
-- PASS or FAIL per check.

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local client = arg and arg[1] or "forever"
local cvars = { cameraSmoothStyle = "4", cameraDistanceMaxZoomFactor = "1.9", raidFramesDisplayBuffs = "1",
	raidFramesDisplayDebuffs = "1" }
local fight, now, clock = false, 100, 0
local secretMode = false
local afters = 0
local deadChecks = 0
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	GetCVar = function(name) return cvars[name] end
	SetCVar = function(name, value) cvars[name] = tostring(value) end
	InCombatLockdown = function() return fight end
	GetTime = function() return now end
	debugprofilestop = function() return clock end
	IsInGroup = function() return true end
	issecretvalue = function(v) return secretMode and (v == 1 or v == "Ragnaros") end
	-- (Counted only from the body's place check: CorpseRunLevel.)
	UnitIsDead = function()
		local caller = debug.getinfo(2, "n")
		if caller and caller.name == "CorpseRunLevel" then deadChecks = deadChecks + 1 end
		return true
	end
	UnitIsGhost = function() return false end
	CompactUnitFrame_UtilSetBuff = false -- (Forever: aura icons out of reach)
	-- luacheck: pop
end
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
ns.db.enabled = true
local realAfter = C_Timer.After
C_Timer.After = function(...) afters = afters + 1 return realAfter(...) end -- luacheck: ignore 122
-- (Real hooks from here on, for the stand-ins and parts made below: at load
-- the addon's own hooks on the game's globals would run on stubs.)
hooksecurefunc = function(a, b, c) -- luacheck: ignore 121
	local tbl, name, fn = a, b, c
	if type(a) == "string" then tbl, name, fn = _G, a, b end
	local orig = tbl[name]
	if type(orig) ~= "function" then return end
	rawset(tbl, name, function(...)
		local r = { orig(...) }
		fn(...)
		return unpack(r)
	end)
end

-- 1: a safety stop with the death camera's follow held.
local death = ns.CVarSet("Audit death follow", "test", { values = { cameraSmoothStyle = "0" } })
ns.ApplyCVarSet(death, true)
Check(client .. ": 1 held", cvars.cameraSmoothStyle == "0", cvars.cameraSmoothStyle)
ns.Suspend("audit test")
Check(client .. ": 1 a safety stop lets it go", not death.active and cvars.cameraSmoothStyle == "4",
	cvars.cameraSmoothStyle)
-- 1b: stopped, the style refreshes on their timers don't write the game's
-- settings again; /cine resume writes them back. (Release review 2026-11-22:
-- the 2 s refreshes undid the stop, and after resume the ones written only
-- as a setting changes stayed the game's till a reload.)
local applies = 0
local realApply = ns.ApplyCVarSet
ns.ApplyCVarSet = function(...) applies = applies + 1 return realApply(...) end
for _, name in ipairs({ "RefreshCombatTextStyle", "RefreshSelfTextStyle", "RefreshPlateHealthStyle" }) do
	if ns[name] then pcall(ns[name]) end
end
ns.ApplyCVarSet = realApply
Check(client .. ": 1b stopped: the style refreshes write nothing", applies == 0, applies)
local refreshed = {}
for _, name in ipairs({ "RefreshCombatTextStyle", "RefreshSelfTextStyle", "RefreshPlateHealthStyle" }) do
	local real = ns[name]
	ns[name] = function(...) refreshed[name] = true return real(...) end
end
ns.Resume()
Check(client .. ": 1b resume writes them back", refreshed.RefreshCombatTextStyle and refreshed.RefreshSelfTextStyle
	and refreshed.RefreshPlateHealthStyle)

-- 2: the max zoom, held by a script and by the idle zoom.
if ns.ZoomMaxHolds then
	local users = ns.ZoomMaxHolds()
	ns.RaiseZoomMax() -- (a script's Past max)
	Check(client .. ": 2 raised by a script", cvars.cameraDistanceMaxZoomFactor == "2.6")
	ns.RestoreZoomLimit() -- (the quest cam putting the idle zoom's back)
	Check(client .. ": 2 the idle zoom's let-go leaves the script's", cvars.cameraDistanceMaxZoomFactor == "2.6",
		cvars.cameraDistanceMaxZoomFactor)
	users.idle = true -- (the idle zoom raising it too)
	ns.LowerZoomMax() -- (the script done)
	Check(client .. ": 2 the script's let-go leaves the idle zoom's", cvars.cameraDistanceMaxZoomFactor == "2.6",
		cvars.cameraDistanceMaxZoomFactor)
	ns.RestoreZoomLimit()
	Check(client .. ": 2 back once neither holds it", cvars.cameraDistanceMaxZoomFactor == "1.9",
		cvars.cameraDistanceMaxZoomFactor)
else
	Check(client .. ": 2 ns.ZoomMaxHolds there (Cameras loaded)", false)
end

-- 3: the raid aura stand-in (Forever's), faded in a fight.
if client == "forever" then
	local scanners
	for i = 1, 10 do
		local name, value = debug.getupvalue(ns.AddScanner, i)
		if name == "scanners" then scanners = value end
	end
	for _, fn in ipairs(scanners or {}) do
		for i = 1, 30 do
			local name = debug.getupvalue(fn, i)
			if not name then break end
			if name == "AURA_CVAR_ROWS" then pcall(fn) end
		end
	end
	local set, standIn
	for _, each in ipairs(ns.cvarSets) do
		if each.label == "Raid raidbuffs off" then set = each end
	end
	for _, frame in ipairs(wow.frames) do
		if frame.cvarSet == set and set then standIn = frame end
	end
	Check("forever: 3 the stand-in made", standIn ~= nil)
	if standIn then
		local alpha = 1
		rawset(standIn, "GetAlpha", function() return alpha end)
		-- (Its SetAlpha hook can't go on the stand-in's stub method: a group
		-- change asks it the same way, Apply.)
		fight, alpha = true, 0
		wow.Fire("GROUP_ROSTER_UPDATE")
		Check("forever: 3 not switched in a fight", cvars.raidFramesDisplayBuffs == "1", cvars.raidFramesDisplayBuffs)
		fight = false
		wow.Fire("PLAYER_REGEN_ENABLED")
		Check("forever: 3 switched as the fight ends", cvars.raidFramesDisplayBuffs == "0", cvars.raidFramesDisplayBuffs)
		alpha = 1
		wow.Fire("GROUP_ROSTER_UPDATE")
		Check("forever: 3 back out of a fight at once", cvars.raidFramesDisplayBuffs == "1", cvars.raidFramesDisplayBuffs)
	end
end

-- 5: a detached part let go while it refuses our code; the walker set once.
do
	local function NotIgnoring() return false end
	local function NoWrite() end
	local root = wow.CreateFrame("Frame", nil, UIParent)
	rawset(root, "SetAlpha", NoWrite)
	rawset(root, "GetEffectiveAlpha", function() return 0.5 end)
	rawset(root, "IsIgnoringParentAlpha", NotIgnoring)
	local part = wow.CreateFrame("Frame", nil, root)
	local writes = 0
	rawset(part, "IsIgnoringParentAlpha", function() return true end)
	rawset(part, "SetAlpha", function() writes = writes + 1 end)
	ns.SyncDetached(root)
	local took = writes
	Check(client .. ": 5 the part taken while its root's faded", took > 0, took)
	rawset(part, "IsForbidden", function() return true end)
	ns.OnIgnoreParentAlpha(part, false)
	Check(client .. ": 5 not written to while it refuses us", writes == took, writes - took)
	rawset(part, "IsForbidden", function() return false end)
	ns.OnIgnoreParentAlpha(part, false)
	Check(client .. ": 5 given back once reachable", writes == took + 1, writes - took)

	-- (Each walk 5 ms of a 1.5 ms budget: one root a frame.)
	local sets = 0
	local SetOnUpdate = ns.SetOnUpdate
	ns.SetOnUpdate = function(frame, fn) sets = sets + 1 return SetOnUpdate(frame, fn) end
	local roots = {}
	for i = 1, 4 do
		roots[i] = wow.CreateFrame("Frame", nil, UIParent)
		rawset(roots[i], "GetEffectiveAlpha", function() return 0.5 end)
		rawset(roots[i], "IsIgnoringParentAlpha", NotIgnoring)
		rawset(roots[i], "SetAlpha", NoWrite)
	end
	-- (The walker: Drain's frame, through SyncDetached's upvalues.)
	local function Up(fn, wanted)
		for i = 1, 40 do
			local name, value = debug.getupvalue(fn, i)
			if not name then return end
			if name == wanted then return value end
		end
	end
	local realStop = debugprofilestop
	debugprofilestop = function() clock = clock + 5 return clock end -- luacheck: ignore 121
	for i = 1, 4 do ns.SyncDetached(roots[i]) end
	local drain = Up(ns.SyncDetached, "Drain")
	local walker = drain and Up(drain, "walker")
	Check(client .. ": 5 the walker found", walker ~= nil)
	for _ = 1, 5 do
		now = now + 0.02
		local update = walker and walker._scripts.OnUpdate
		if update then update(walker, 0.02) end
	end
	debugprofilestop = realStop -- luacheck: ignore 121
	ns.SetOnUpdate = SetOnUpdate
	Check(client .. ": 5 the walker's loop set once and cleared once", sets == 2, sets)
end

-- 6: Damage Vision, a boss's end with a secret result and name.
ns.db.damageVision, ns.db.damageVisionRecapBoss = true, true
afters = 0
secretMode = true
wow.Fire("ENCOUNTER_END", 1, "Ragnaros", 1, 20, 1)
secretMode = false
Check(client .. ": 6 no recap queued on a secret result", afters == 0, afters)

-- 8: Death Vision, dead and not released, the tint looking 5 times a second.
if ns.UpdateDeathVision then
	deadChecks = 0
	for _ = 1, 5 do
		now = now + 0.2
		ns.UpdateDeathVision(0.016) -- (one frame's time, as the tint hands over)
	end
	Check(client .. ": 8 the body's place looked at each 0.25 s, by the clock", deadChecks >= 3, deadChecks)
end

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
