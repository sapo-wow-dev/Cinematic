-- The frames shown out of CineMode's fade (Show in rows): how long the
-- worked-out list is kept (offline, Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/combatshownhold.lua <forever|retail>
-- With the "in case" checks slowed (ns.SlowChecks) the list is kept up to
-- 10 s while nothing it goes by changes (it was 2 s: worked out again on every
-- other frames pass, ~0.8 of its 3.3 ms, Tools/perf/ledger.md 2026-11-22).
-- Checked with pretend time: kept 10 s slowed, 2 s not, worked out at once
-- when a rule fact or the target changes, and every 0.3 s with the settings
-- open; and the rows' ticks kept through a fight and its Calm Timer. PASS or
-- FAIL per check.
-- luacheck: push ignore 111 112 113 121 122
local client = arg and arg[1] or "forever"
package.path = "Tools/offline/?.lua;" .. package.path
local wow = dofile("Tools/offline/wow.lua")
wow.Install(client)
-- (A real clock for the profiler and the parts: the stand-in's is a stub.)
debugprofilestop = function() return os.clock() * 1000 end
local now = 1000
local ns = {}
for line in io.lines("Cinematic.toc") do
	line = line:gsub("\r", "")
	if line ~= "" and not line:find("^#") then
		local chunk = loadfile((line:gsub("\\", "/")))
		if chunk then
			local ok, err = pcall(chunk, "Cinematic", ns)
			if not ok then wow.Warn(line .. ": " .. tostring(err)) end
		end
	end
end
wow.Fire("ADDON_LOADED", "Cinematic")
wow.Fire("PLAYER_LOGIN")
GetTime = function() return now end
local locked = false
InCombatLockdown = function() return locked end
UnitAffectingCombat = function() return locked end
local hasTarget = false
UnitExists = function(unit) return unit == "target" and hasTarget end
-- luacheck: pop

local failed = 0
local function Check(ok, text)
	print((ok and "PASS " or "FAIL ") .. text)
	if not ok then failed = failed + 1 end
end
local Shown = ns.CombatShownFrames
Check(Shown ~= nil, "ns.CombatShownFrames found")
if not Shown then return print("1 FAILED") end

-- (Worked out = Compute ran: it asks each row's rule, ns.RuleShows; the
-- kept-list check doesn't. Counted once an Ask, however many rows.)
local computes, asked = 0, false
local RuleShows = ns.RuleShows
ns.RuleShows = function(...)
	if not asked then asked, computes = true, computes + 1 end
	return RuleShows(...)
end
local slow, settingsOpen, stamp = true, false, 1
ns.SlowChecks = function() return slow end
ns.SettingsPanelShown = function() return settingsOpen end
local RuleFacts = ns.RuleFacts
ns.RuleFacts = function(...)
	local facts = RuleFacts(...)
	ns.factsStamp = stamp
	return facts
end
ns.db.calmTime = 0

local function Ask(at)
	now = 1000 + at
	asked = false
	Shown()
	return computes
end
local function Count(from, times)
	local before = computes
	for _, at in ipairs(times) do Ask(from + at) end
	return computes - before
end

-- Slowed: kept 10 s.
Ask(0)
Check(computes >= 1, "worked out the first time")
local n = Count(0, { 0.5, 1, 2.5, 4, 6, 8, 9.5 })
Check(n == 0, ("slowed checks: kept for 9.5 s (worked out %d times)"):format(n))
n = Count(0, { 10.5 })
Check(n == 1, ("slowed checks: worked out again after 10 s (%d)"):format(n))

-- Not slowed: kept 2 s, as before.
slow = false
Ask(20)
n = Count(20, { 1, 1.9 })
Check(n == 0, ("not slowed: kept under 2 s (%d)"):format(n))
n = Count(20, { 2.5 })
Check(n == 1, ("not slowed: worked out again past 2 s (%d)"):format(n))

-- Slowed, but an input changes: at once.
slow = true
Ask(40)
stamp = 2
n = Count(40, { 0.5 })
Check(n == 1, ("a rule fact changed (where you are, mounted...): worked out at once (%d)"):format(n))
hasTarget = true
n = Count(41, { 0 })
hasTarget = false
Check(n == 1, ("a target: worked out at once (%d)"):format(n))

-- Settings open: only the 0.3 s hold.
settingsOpen = true
Ask(60)
n = Count(60, { 0.5, 1.0, 1.5 })
Check(n == 3, ("settings open: worked out every pass past 0.3 s (%d of 3)"):format(n))
settingsOpen = false

-- The rows' ticks kept for a fight, and through its Calm Timer after: the
-- same In combat rows. (Kept only while locked down, each Calm Timer pass
-- worked every row out again: 4-6 ms, 8 a second, 2026-11-22 fight run.)
-- Rows worked out = ns.IsCineShowOn asked (Ticked asks it once a row).
local rowsAsked = 0
local IsCineShowOn = ns.IsCineShowOn
ns.IsCineShowOn = function(...) rowsAsked = rowsAsked + 1 return IsCineShowOn(...) end
-- (CineMode stays on in fights: the In combat rows count. Its setting, not
-- ns.StaysInCombat: the list read it either way over 2026-11-22.)
ns.db.stayInCombat = true
ns.db.exitByRow = false
ns.FightHold = function() return false end
ns.db.calmTime = 30
slow = false
local function Rows(at)
	stamp = stamp + 1 -- (a fact changed: worked out again, not the kept list)
	local before = rowsAsked
	Ask(at)
	return rowsAsked - before
end
locked = true
wow.Fire("PLAYER_REGEN_DISABLED")
local first = Rows(80)
local again = Rows(80.5)
Check(first > 0 and again == 0, ("in a fight: the rows worked out once (%d), then kept (%d)"):format(first, again))
locked = false
wow.Fire("PLAYER_REGEN_ENABLED")
local atEnd = Rows(81)
local calm1, calm2 = Rows(82), Rows(85)
Check(atEnd > 0, ("the fight over: worked out afresh once (%d), for a setting changed in it"):format(atEnd))
Check(calm1 == 0 and calm2 == 0, ("in the Calm Timer: kept (%d, %d rows worked out)"):format(calm1, calm2))
local after1 = Rows(115)
local after2 = Rows(116)
Check(after1 > 0 and after2 > 0, ("the Calm Timer over: worked out each time again (%d, %d)"):format(after1, after2))

-- The list's parts timed for the profiler (ns.ProfileAdd), and only while
-- profiling: its 4-10 ms calls in fights weren't its rows' ticks (2026-11-22).
local adds = 0
local ProfileAdd = ns.ProfileAdd
Check(ProfileAdd ~= nil, "ns.ProfileAdd found")
ns.ProfileAdd = function(...) adds = adds + 1 return ProfileAdd(...) end
Rows(200)
Check(adds == 0, ("not profiling: no part timed (%d)"):format(adds))
Check(ns.StartProfile and ns.StartProfile(30, true, false), "a recording started")
locked = true
Rows(201)
Rows(201.5)
ns.StopProfile()
locked = false
local sections = ns.lastProfile and ns.lastProfile.sections or {}
local list, parts = nil, {}
for _, row in ipairs(sections) do
	if row.name == "GetCombatShownFrames" then list = row end
end
for _, child in ipairs(list and list.children or {}) do parts[child.name] = child end
Check(list ~= nil, "the list is a section of the recording")
local want = { "combat list: fight target and cast", "combat list: place lists", "combat list: fight ticks and rule facts",
	"combat list: rows' rules", "combat list: rows' ticks", "combat list: rows' fight hold", "combat list: rows other",
	"combat list: spellbook bars", "combat list: added frames", "combat list: change check" }
local missing, sum = {}, 0
for _, name in ipairs(want) do
	if parts[name] then
		if name ~= "combat list: change check" then sum = sum + parts[name].ms end
	else
		missing[#missing + 1] = name
	end
end
Check(#missing == 0, "every part listed under it" .. (#missing > 0 and (": missing " .. table.concat(missing, ", ")) or ""))
-- (os.clock here ticks in whole ms: each timed part can round up a tick.)
Check(list and list.ms > 0 and sum > 0 and sum <= list.ms * 1.05 + #want, ("the parts add up to no more than the list (%.4f of %.4f ms a frame)"):format(
	sum, list and list.ms or 0))
adds = 0
Rows(210)
Check(adds == 0, ("recording over: no part timed (%d)"):format(adds))

print(failed == 0 and "ALL PASSED" or (failed .. " FAILED"))
