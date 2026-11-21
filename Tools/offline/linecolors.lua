-- /cine debug linecolors (Dev/LineColorProbe.lua), offline (Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/linecolors.lua < /dev/null
-- On a stand-in fight under a filter shaped as MSBT's (you and your pet,
-- every event its own color): the command starts it, CineMode goes off,
-- filtered events go on if off, the filter is read, lines and hits are
-- recorded (one per instant, old replayed lines skipped), a swing's line
-- pairs with its hit landing later, colors are named by the filter, the
-- fight's end finishes it with its verdicts, and everything comes back.
-- A run with no fight, typed again, stops. Says PASS or FAIL per check.
-- luacheck: push ignore 111 112 113 121 122 212 213
local ns, wow = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc")

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local now = 100
GetTime = function() return now end
local timers = {}
C_Timer.After = function(seconds, fn) timers[#timers + 1] = { at = now + seconds, fn = fn } end
local cine = true
ns.IsCineModeOn = function() return cine end
_G.Cinematic_ToggleCineMode = function() cine = not cine end
local box = ""
ns.PadTestBox = function(text, sub) box = tostring(text) .. " | " .. tostring(sub) end
ns.PadTestBoxHide = function() end
local filtered = false
C_CombatLog = { AreFilteredEventsEnabled = function() return filtered end,
	SetFilteredEventsEnabled = function(on) filtered = on end }
Enum = Enum or {}
Enum.CombatLogMessageOrder = { Newest = 0, Oldest = 1 }
UnitIsUnit = function(a, b) return b == "target" and (a == "target" or a == "nameplate1") end
UnitExists = function() return false end
InCombatLockdown = function() return false end
local function C(r, g, b) return { a = 1, r = r, g = g, b = b } end
Blizzard_CombatLog_Filters = {
	currentFilter = 2,
	filters = {
		{ name = "My actions", colors = {}, settings = {} },
		{ name = "MSBT combat",
			filters = { { sourceFlags = { [17681] = true, [12561] = true } } },
			settings = { lineColoring = true, lineColorPriority = 3, unitColoring = false },
			colors = { eventColoring = { SWING_DAMAGE = C(1, 1, 1), SPELL_DAMAGE = C(1, 1, 0),
				SPELL_PERIODIC_DAMAGE = C(0.8, 0.6, 1) }, unitColoring = { [17681] = C(0.7, 0.7, 0.7) } } },
	},
}
-- luacheck: pop

local function Tick(seconds)
	for _ = 1, math.floor(seconds / 0.05 + 0.5) do
		now = now + 0.05
		for i = #timers, 1, -1 do if timers[i].at <= now then table.remove(timers, i).fn() end end
	end
end
local function Has(want)
	for _, line in ipairs(CinematicDB.lineColorLog or {}) do if line:find(want, 1, true) then return line end end
end
local function Line(r, g, b, order) wow.Fire("COMBAT_LOG_MESSAGE", "|Ky1|k", r, g, b, order or 0) end
local function Hit(unit, action, school) wow.Fire("UNIT_COMBAT", unit, action, "", 12, school) end

Check("the command is on ns", type(ns.LineColorProbe) == "function")
local real, called = ns.LineColorProbe, nil
ns.LineColorProbe = function() called = true end
ns.HandleSlash("debug linecolors")
Check("/cine debug linecolors starts it", called == true)
ns.LineColorProbe = real

ns.db.combatTextStyle, ns.db.combatTextDamageBy = false, "game"
ns.LineColorProbe()
Check("CineMode off", cine == false)
Check("page on for the run, yours kept", ns.db.combatTextStyle == true and ns.db.combatTextDamageBy == "ours"
	and CinematicDB.lineColorKept and CinematicDB.lineColorKept.combatTextStyle == false)
Check("filtered events turned on", filtered == true)
Check("filter read", Has("filters: plain table, current 2.000 of [1=My actions, 2=MSBT combat]") ~= nil)
Check("filter's sources and coloring", Has("current \"MSBT combat\": sources [12561 17681]") ~= nil
	and Has("lineColorPriority 3.000") ~= nil)
Check("event colors listed", Has("SWING_DAMAGE=255/255/255") ~= nil and Has("SPELL_DAMAGE=255/255/0") ~= nil)
Check("box: kill one mob", box:find("KILL ONE MOB", 1, true) ~= nil, box)
Tick(5)
Check("no time limit before the fight", Has("done") == nil)

wow.Fire("PLAYER_REGEN_DISABLED")
Check("box: fighting", box:find("FIGHTING", 1, true) ~= nil, box)
-- A swing: its line, then its hit 0.5 s later (plate and target: one hit).
wow.Fire("PLAYER_SWING", 2.4, 0)
Line(1, 1, 1)
Tick(0.5)
Hit("nameplate1", "WOUND", 1)
Hit("target", "WOUND", 1)
Tick(0.5)
-- A spell: its line and hit in one instant.
Line(1, 1, 0)
Hit("nameplate1", "WOUND", 4)
Tick(0.5)
-- A tick, the same.
Line(0.8, 0.6, 1)
Hit("nameplate1", "WOUND", 32)
Tick(0.5)
-- A line with no hit (your pet's?), and an old replayed line (skipped).
Line(0.7, 0.7, 0.7)
Line(1, 1, 1, 1)
Tick(0.5)
-- A hit on you: not counted.
Hit("player", "WOUND", 1)
wow.Fire("PLAYER_REGEN_ENABLED")
Tick(1.5)

Check("verdict: filter", Has("VERDICT filter: readable, current \"MSBT combat\", sources 12561 17681") ~= nil)
Check("verdict: colors", Has("VERDICT colors: 4 colors over 4 lines; 3 of them came with one kind of hit only") ~= nil)
Check("swing line paired with its later hit", Has("color 255/255/255: 1 lines | hits with it: swing x1") ~= nil)
Check("spell line named by the filter", Has("color 255/255/0: 1 lines | hits with it: spell x1 | no hit near: 0 | the filter's events of this color: SPELL_DAMAGE") ~= nil)
Check("filter match count", Has("VERDICT filter match: 3 lines' colors are colors the filter gives events, 1 not") ~= nil)
Check("line with no hit", Has("VERDICT lines with no hit near: 1 of 4") ~= nil)
Check("hits deduplicated (per school)", Has("hits with no line: 0 of 3") ~= nil)
Check("swings counted", Has("VERDICT swings: 1 PLAYER_SWING, 1 hits marked a swing of yours") ~= nil)
Check("done box", box:find("Combat colors test done: 4 colors over 4 lines", 1, true) ~= nil, box)
Check("CineMode back", cine == true)
Check("page settings back", ns.db.combatTextStyle == false and ns.db.combatTextDamageBy == "game"
	and CinematicDB.lineColorKept == nil)
Check("page counts logged", Has("page counts: lines swing") ~= nil)
Check("page verdict written", Has("VERDICT page step 1: ") ~= nil, Has("VERDICT page step 1: "))
Check("pet verdict written", Has("VERDICT pet: SKIP: your pet cast nothing") ~= nil)
Check("gaps per hit", Has("gaps: hit ") ~= nil)
Check("filtered events back off", filtered == false)
Check("nothing errored", not Has("error"))

-- A /reload mid-run: your page settings put back at the next login.
ns.db.combatTextStyle = false
ns.LineColorProbe()
Check("mid-run: page on", ns.db.combatTextStyle == true)
-- (The run's gone with the /reload; its saved settings stay.)
local kept = CinematicDB.lineColorKept
ns.LineColorProbe() -- (ends it here; put the saved copy back as a reload would leave it)
CinematicDB.lineColorKept = kept
ns.db.combatTextStyle = true
wow.Fire("PLAYER_LOGIN")
Check("after a /reload: put back at login", ns.db.combatTextStyle == false and CinematicDB.lineColorKept == nil)

-- No fight, typed again: stops.
ns.LineColorProbe()
Tick(1)
ns.LineColorProbe()
Check("stopped with no fight", box:find("stopped (no fight)", 1, true) ~= nil, box)
Check("CineMode back after a stop", cine == true)

for _, warning in ipairs(wow.warnings) do
	if warning:find("LineColor", 1, true) then Check("load: " .. warning, false) end
end
print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
