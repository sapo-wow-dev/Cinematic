-- Combat Text Style's line kinds by color (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/linekinds.lua < /dev/null
-- Step 1 of Tools/combat-log-color-plan.md: a combat log line's color, read
-- against the Combat Log's current filter, says its kind. Checked on the
-- stand-in (ns.CombatTextLines, CombatTextStyle.lua), with the colors the
-- probe saw under MSBT's filter (2026-11-21): events sorted into kinds; a
-- kill's line skipped (not a hit's); a swing's line kept for a white swing
-- and not taken by an ability or spell; a spell's line not taken by a swing;
-- a waiting hit of the right kind found behind one of another; a heal on you
-- not paid with a spell's line; Blizzard's one-grey filter (and no filter)
-- exactly as before; a filter changed: read again. Says PASS or FAIL per check.
-- luacheck: push ignore 111 112 113 121 122 212
local now = 100
local ns, wow = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc", function()
	GetTime = function() return now end
end)
-- luacheck: pop

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local L = ns.CombatTextLines
Check("the pieces are on ns", type(L) == "table" and type(L.OnLine) == "function")

-- 1. Events to kinds.
Check("SWING_DAMAGE swing", L.EventKind("SWING_DAMAGE") == "swing")
Check("SWING_MISSED_DODGE swing", L.EventKind("SWING_MISSED_DODGE") == "swing")
Check("SPELL_PERIODIC_DAMAGE tick", L.EventKind("SPELL_PERIODIC_DAMAGE") == "tick")
Check("RANGE_DAMAGE spell", L.EventKind("RANGE_DAMAGE") == "spell")
Check("SPELL_MISSED_RESIST spell", L.EventKind("SPELL_MISSED_RESIST") == "spell")
Check("SPELL_HEAL heal", L.EventKind("SPELL_PERIODIC_HEAL") == "heal")
Check("PARTY_KILL skip", L.EventKind("PARTY_KILL") == "skip")
Check("SPELL_AURA_APPLIED skip", L.EventKind("SPELL_AURA_APPLIED") == "skip")
Check("SPELL_CAST_SUCCESS skip", L.EventKind("SPELL_CAST_SUCCESS") == "skip")

-- The filter MSBT writes (colors as the probe read them), current.
local function C(r, g, b) return { a = 1, r = r / 255, g = g / 255, b = b / 255 } end
local MSBT = { name = "MSBT combat", colors = { eventColoring = {
	SWING_DAMAGE = C(230, 230, 230), SWING_MISSED = C(153, 153, 153), SPELL_DAMAGE = C(255, 204, 77),
	SPELL_BUILDING_DAMAGE = C(255, 204, 77), SPELL_LEECH = C(255, 204, 77), SPELL_PERIODIC_DAMAGE = C(204, 153, 255),
	SPELL_HEAL = C(89, 255, 115), PARTY_KILL = C(255, 255, 255), SPELL_INTERRUPT = C(255, 115, 26),
	-- (one color shared by a hit and a non-hit: unknown)
	SPELL_DISPEL = C(10, 20, 30), RANGE_DAMAGE = C(10, 20, 30) } } }
local MINE = { name = "My actions", colors = { unitColoring = {} } }
-- luacheck: push ignore 111
Blizzard_CombatLog_Filters = { currentFilter = 2, filters = { MINE, MSBT } }
-- luacheck: pop
local function Fresh() L.colors.at = -100 end
local function Line(r, g, b) L.OnLine(r / 255, g / 255, b / 255) end
local function Reset()
	wipe(L.lines) wipe(L.swingLines) wipe(L.pending) wipe(L.owed)
	now = now + 10
end
-- A hit waiting for its line (an id no text has: drawing skipped, counted as yours).
local function Wait(via, melee)
	L.pending[#L.pending + 1] = { nil, nil, 5, id = "none", via = via, melee = melee, at = now }
	return L.pending[#L.pending]
end
local function Mine() return ns.combatTextWhose.mine end

ns.db.styleGeneral, ns.db.combatTextStyle, ns.db.combatTextNumbers = true, true, true
Fresh()
Check("spell color", L.Kind(1, 204 / 255, 77 / 255) == "spell")
Check("tick color", L.Kind(204 / 255, 153 / 255, 1) == "tick")
Check("swing color", L.Kind(230 / 255, 230 / 255, 230 / 255) == "swing")
Check("swing miss color", L.Kind(153 / 255, 153 / 255, 153 / 255) == "swing")
Check("heal color", L.Kind(89 / 255, 1, 115 / 255) == "heal")
Check("kill color skip", L.Kind(1, 1, 1) == "skip")
Check("shared by a hit and a non-hit: unknown", L.Kind(10 / 255, 20 / 255, 30 / 255) == nil)
Check("a grey no event has: unknown", L.Kind(179 / 255, 179 / 255, 179 / 255) == nil)
Check("a secret: unknown", L.Kind(nil, nil, nil) == nil)
Check("this filter tells swings apart", L.colors.kinds == true)

-- 2. A kill's line: skipped, so a hit still waits for its own.
Reset()
Wait("fire", false)
local before = Mine()
Line(255, 255, 255)
Check("kill line: the waiting hit not taken", Mine() == before and #L.pending == 1)
Check("kill line: not kept", #L.lines == 0 and #L.swingLines == 0)
Line(255, 204, 77)
Check("its own line then takes it", Mine() == before + 1 and #L.pending == 0)

-- 3. A swing's line waits for a white swing; an ability doesn't take it.
Reset()
Line(230, 230, 230)
Check("swing line kept apart", #L.swingLines == 1 and #L.lines == 0)
now = now + 0.4
Check("an ability doesn't take a swing's line", L.TakeLine(now, true, "ability") == false and #L.swingLines == 1)
Check("a spell doesn't take it", L.TakeLine(now, false, "fire") == false)
Check("the swing takes it", L.TakeLine(now, true, "swing") and #L.swingLines == 0)

-- 4. A spell's line isn't taken by a swing.
Reset()
Line(255, 204, 77)
Check("spell line kept with the rest", #L.lines == 1)
Check("a swing doesn't take a spell's line", L.TakeLine(now, true, "swing") == false and #L.lines == 1)
Check("an ability (physical) does", L.TakeLine(now, true, "ability") ~= false)

-- 5. The right waiting hit, behind one of another kind.
Reset()
local swing = Wait("swing", true)
local spell = Wait("shadow", false)
before = Mine()
Line(255, 204, 77)
Check("spell line took the spell, not the swing before it", Mine() == before + 1 and L.pending[1] == swing
	and L.pending[2] == nil and spell ~= nil)
Line(230, 230, 230)
Check("swing line took the swing", Mine() == before + 2 and #L.pending == 0)

-- 6. A heal on you isn't paid with a spell's line; a heal's line pays it.
Reset()
L.owed[1] = now
Line(255, 204, 77)
Check("spell line: the heal on you still owed", #L.owed == 1 and #L.lines == 1)
Line(89, 255, 115)
Check("heal line pays it", #L.owed == 0)

-- 6b. A tick's line still pairs with a spell hit, and its kind is kept for the hit.
Reset()
Line(204, 153, 255)
Check("tick line kept, its kind by its time", #L.lines == 1 and L.kindAt[L.lines[1]] == "tick")
Check("a spell hit takes a tick's line", L.TakeLine(now, false, "shadow") ~= false)

-- 6c. 1b: your pet's spell hit (no cast of yours waiting, its cast just
-- finished) drawn as your pet's; your tick and a late one not.
Reset()
local drawn = {}
local realSpawnCount = ns.combatTextWhose.mine
ns.combatTextRecord = function(text) drawn[#drawn + 1] = tostring(text) end
local function Said(want) for _, line in ipairs(drawn) do if line:find(want, 1, true) then return true end end end
UnitExists = function(unit) return unit == "pet" end -- luacheck: ignore 121
L.NotePetCast()
now = now + 0.26
local hit = Wait("fire", false)
hit.school = 4
Line(255, 204, 77)
Check("pet's Firebolt: called your pet's", Said("PET'S: a line came") and ns.combatTextWhose.mine == realSpawnCount)
drawn = {}
L.NotePetCast()
now = now + 0.26
hit = Wait("fire", false)
hit.school = 4
Line(204, 153, 255)
Check("a tick's line: yours, even just after a pet cast", not Said("PET'S") and ns.combatTextWhose.mine == realSpawnCount + 1)
drawn = {}
now = now + 3
L.NotePetCast()
now = now + 1
hit = Wait("fire", false)
hit.school = 4
Line(255, 204, 77)
Check("a pet cast a second earlier: yours", not Said("PET'S") and ns.combatTextWhose.mine == realSpawnCount + 2)
ns.combatTextRecord = nil

-- 7. Blizzard's My actions (one grey, no event colors): exactly as before.
Blizzard_CombatLog_Filters.currentFilter = 1 -- luacheck: ignore 112
Fresh()
Reset()
Line(179, 179, 179)
Check("one-grey filter: kind unknown, line kept", #L.lines == 1 and L.colors.kinds == false)
Check("a swing takes any line, as before", L.TakeLine(now, true, "swing") ~= false)
Wait("swing", true)
before = Mine()
Line(179, 179, 179)
Check("and a waiting swing takes the next", Mine() == before + 1)
Check("a counted unknown", ns.combatTextLineKinds.unknown >= 2)

-- 8. No filter table at all (Blizzard_CombatLog not loaded): as before.
Blizzard_CombatLog_Filters = nil -- luacheck: ignore 111
Fresh()
Reset()
Line(230, 230, 230)
Check("no filter: unknown, kept with the rest", #L.lines == 1 and #L.swingLines == 0)

-- 9. Back to MSBT's: read again (within 5 s it keeps what it read).
Blizzard_CombatLog_Filters = { currentFilter = 2, filters = { MINE, MSBT } } -- luacheck: ignore 111
now = now + 6
Check("filter read again", L.Kind(1, 1, 1) == "skip")

-- 10. Old lines sent again (Oldest order), through the page's own log
-- frame: not counted, nothing paired; a new one pairs.
do
	Enum = Enum or {} -- luacheck: ignore 121
	Enum.CombatLogMessageOrder = { Newest = 0, Oldest = 1 } -- luacheck: ignore 122
	Reset()
	local spell = Wait("fire", false)
	local before, old = Mine(), ns.combatTextLineKinds.old or 0
	wow.Fire("COMBAT_LOG_MESSAGE", "|Ky1|k", 1, 204 / 255, 77 / 255, 1)
	Check("an old line: not counted, the hit still waits", Mine() == before
		and (ns.combatTextLineKinds.old or 0) == old + 1 and L.pending[1] == spell)
	wow.Fire("COMBAT_LOG_MESSAGE", "|Ky2|k", 1, 204 / 255, 77 / 255, 0)
	Check("a new line: pairs", Mine() == before + 1)
end

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
