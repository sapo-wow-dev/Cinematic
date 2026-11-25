-- Combat Text Style's Spells tab (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/combattextspells.lua < /dev/null
-- The Combat Text by Spell plan (2026-11-25): a spell on the tab's list
-- draws in its own look; the game never says which spell hit, so the hit
-- takes your cast (CombatTextStyle.lua's TakeCast, TakeTick). Checked here,
-- driven as the game would (casts as UNIT_SPELLCAST_* events, hits by school
-- and time, ticks on a mob):
--   A matching: a cast's hit, an instant, an area spell's hits, a channel's
--     ticks, a DoT's ticks (no hit of its own: never takes a bolt's hit), a
--     direct hit and its ticks (Immolate), two of one school (left as the
--     school's), a proc (none), a tick on a mob you never cast at.
--   B looks: nothing of its own = its school's (every setting); its color,
--     crits' color, size, ticks smaller, switch off; the tab off; a spell
--     not listed; a pet's spell; a heal's.
--   C saving: profile and sharing keys, the list's shape, Reset (the list
--     stays), Remove, the Add list's "hit with" (school learned, capped).
--   D the page: the tab builds, lines for the list, the Look panel opens.
-- Says PASS or FAIL per check.
-- luacheck: push ignore 111 112 113 121 122 212
local now = 100
local target = "Creature-1"
local NAMES = { [686] = "Shadow Bolt", [172] = "Corruption", [980] = "Curse of Agony", [348] = "Immolate",
	[5676] = "Searing Pain", [5740] = "Rain of Fire", [689] = "Drain Life", [3110] = "Firebolt", [5185] = "Healing Touch",
	[52127] = "Water Shield" }
-- (Which spells hurt or help: a buff's cast took a damage hit in game, run q1b8f.)
local HELPFUL = { [52127] = true, [5185] = true }
local channelInfo
local ns, wow = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc", function()
	GetTime = function() return now end
	issecretvalue = function() return false end
	C_Spell = C_Spell or {}
	C_Spell.GetSpellName = function(id) return NAMES[id] end
	C_Spell.GetSpellTexture = function(id) return 1000 + id end
	C_Spell.IsSpellHarmful = function(id) return NAMES[id] ~= nil and not HELPFUL[id] end
	C_Spell.IsSpellHelpful = function(id) return HELPFUL[id] == true end
	-- (Descriptions as the game's: each names its school, a bolt and a DoT alike.)
	C_Spell.GetSpellDescription = function(id)
		return ({ [172] = "Corrupts the target, causing 40 Shadow damage over 12 sec.",
			[348] = "Burns the enemy for 11 Fire damage and then an additional 20 Fire damage over 15 sec.",
			[686] = "Sends a shadowy bolt at the enemy, causing 13 Shadow damage." })[id] or ""
	end
	STRING_SCHOOL_FIRE, STRING_SCHOOL_SHADOW, STRING_SCHOOL_HOLY = "Fire", "Shadow", "Holy"
	STRING_SCHOOL_NATURE, STRING_SCHOOL_FROST, STRING_SCHOOL_ARCANE = "Nature", "Frost", "Arcane"
	UnitGUID = function(unit) if unit == "target" then return target end end
	UnitChannelInfo = function() if channelInfo then return unpack(channelInfo) end end
	C_Timer.After = function(_, fn) fn() end
end)
-- luacheck: pop

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local CT, M = ns.CombatTexts, ns.CombatTextSpellMatch
Check("the pieces are on ns", type(CT) == "table" and type(M) == "table" and type(CT.AddSpell) == "function"
	and type(M.TakeTick) == "function")
ns.db.styleGeneral, ns.db.combatTextStyle, ns.db.combatTextNumbers = true, true, true

local function Cast(spell, secs)
	if secs then
		M.OnCast(nil, "UNIT_SPELLCAST_START", "player", "guid", spell)
		now = now + secs
	end
	M.OnCast(nil, "UNIT_SPELLCAST_SUCCEEDED", "player", "guid", spell)
end
local function Name(from) return type(from) == "table" and from.name or nil end
local function Hit(school) return select(2, M.TakeCast(school, now)) end
local function Tick(school, mob) return select(2, M.TakeTick(school, mob or target, now)) end
local function Fresh()
	M.Reset()
	now = now + 100
end

-- A. Matching ------------------------------------------------------------------
Fresh()
Cast(686, 2.5)
now = now + 0.8
local secs, from = M.TakeCast(32, now)
Check("A1 a cast's hit takes it: its spell", Name(from) == "Shadow Bolt", Name(from))
Check("A1 and its cast time, as before", secs and math.abs(secs - 2.5) < 0.01, secs)
Check("A1 its school", from and from.school == 32, from and from.school)

Fresh()
Cast(5676)
Check("A2 an instant, the same instant", Name(Hit(4)) == "Searing Pain")

Fresh()
Cast(5740)
now = now + 0.5
local first = Hit(4)
local second = Hit(4)
Check("A3 an area spell's hits in one instant: both its", Name(first) == "Rain of Fire" and Name(second) == "Rain of Fire")

Fresh()
channelInfo = { "Drain Life", nil, nil, now * 1000, (now + 5) * 1000 }
M.OnCast(nil, "UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 689)
now = now + 1
Check("A4 a channel's tick (a tick line)", Name(Tick(32)) == "Drain Life")
now = now + 1
Check("A4 and a hit while it lasts", Name(Hit(32)) == "Drain Life")
M.OnCast(nil, "UNIT_SPELLCAST_CHANNEL_STOP", "player", "guid", 689)
channelInfo = nil

-- A DoT: Corruption, no hit of its own. Its casts expire untaken; then its ticks.
Fresh()
Cast(172)
now = now + 3
local tick = Tick(32)
Check("A5 a DoT's tick: its spell (cast on this mob, never took a hit)", Name(tick) == "Corruption", Name(tick))
Check("A5 marked a tick", tick and tick.tick == true)
-- A Shadow Bolt in flight isn't a tick's: the tick takes Corruption, the bolt's cast waits.
Cast(686, 2.5)
now = now + 0.3
Check("A6 a tick while a bolt is in flight: still the DoT's", Name(Tick(32)) == "Corruption")
now = now + 0.4
Check("A6 the bolt's hit then takes the bolt's cast", Name(Hit(32)) == "Shadow Bolt")
-- Learned: Corruption never hits, Shadow Bolt hits in Shadow. Corruption
-- cast just before a bolt: the bolt's hit takes the bolt's cast.
Cast(172)
now = now + 3 -- (expires: Corruption's second cast no hit took)
Cast(172)
now = now + 0.1
Cast(686, 2.5)
now = now + 0.5
Check("A7 a bolt's hit skips the DoT's cast before it (learned: it never hits)", Name(Hit(32)) == "Shadow Bolt")

-- Immolate: a direct hit, then its ticks.
Fresh()
Cast(348, 2)
Check("A8 Immolate's hit", Name(Hit(4)) == "Immolate")
now = now + 3
Check("A8 its tick: the one Fire spell of yours on it", Name(Tick(4)) == "Immolate")
Cast(5676)
Check("A8 Searing Pain's hit", Name(Hit(4)) == "Searing Pain")
now = now + 3
Check("A8 a Fire tick after: Immolate (its ticks learned)", Name(Tick(4)) == "Immolate")

Fresh()
Cast(348, 2)
Hit(4)
now = now + 1
Cast(5676)
Hit(4)
now = now + 3
Check("A9 two Fire spells, neither ticked yet: not known (its school's look)", Tick(4) == nil)

-- Run q0530: Immolate and Corruption on one mob, Immolate's Fire tick first:
-- it went to Corruption (no hit of its own: any school), Corruption Fire for good.
Fresh()
Cast(348, 2)
Check("A13 Immolate's hit", Name(Hit(4)) == "Immolate")
Cast(172)
now = now + 3
Check("A13 a Fire tick with Corruption on: Immolate's, not Corruption's (its description says Shadow)",
	Name(Tick(4)) == "Immolate", Name(Tick(4)))
Check("A13 then a Shadow tick: Corruption's", Name(Tick(32)) == "Corruption")

Fresh()
Cast(52127)
now = now + 0.5
Check("A12 a buff's cast (Water Shield) never takes a damage hit", select(2, M.TakeCast(8, now, false)) == nil)
Cast(5185, 2.5)
now = now + 0.1
Check("A12 a heal takes a heal's cast", Name(select(2, M.TakeCast(8, now, true))) == "Healing Touch")
Cast(686, 2.5)
now = now + 0.5
Check("A12 a heal never takes a harmful spell's cast", select(2, M.TakeCast(32, now, true)) == nil)
Check("A12 the damage hit then takes it", Name(select(2, M.TakeCast(32, now, false))) == "Shadow Bolt")

Fresh()
Check("A10 a proc (no cast): not known", Hit(4) == nil)
Cast(172)
now = now + 3
Check("A11 a tick on a mob you never cast at: not known", Tick(32, "Creature-2") == nil)

-- B. Looks -----------------------------------------------------------------------
local drawn = {}
ns.combatTextRecord = function(text) drawn[#drawn + 1] = tostring(text) end
local frame = CreateFrame("Frame", nil, UIParent)
frame:SetSize(140, 30)
local layer = CreateFrame("Frame", nil, UIParent)
-- Draws a sample, gives { r, g, b, size } as recorded, or nil (not drawn).
local function Draw(id, spell, tick, via)
	wipe(drawn)
	local number = ns.CombatTextSample(frame, id, layer, via, 0, spell, tick)
	if not number then return nil end
	for _, line in ipairs(drawn) do
		local r, g, b, size = line:match("^DRAWN .- color=([%d%.]+),([%d%.]+),([%d%.]+) crit=%a+ size=([%d%.]+)")
		if r then return { tonumber(r), tonumber(g), tonumber(b), tonumber(size) } end
	end
	return { 0, 0, 0, 0 }
end
local function Near(a, b) return a and b and math.abs(a - b) < 0.02 end
local function SameColor(a, b) return a and b and Near(a[1], b[1]) and Near(a[2], b[2]) and Near(a[3], b[3]) end
local function Words(c) return c and ("%.2f,%.2f,%.2f size %.1f"):format(c[1], c[2], c[3], c[4]) or "not drawn" end

-- (Shadow by school, so the spell's own color shows apart.)
ns.db[CT.Key("spellShadow", "R")], ns.db[CT.Key("spellShadow", "G")], ns.db[CT.Key("spellShadow", "B")] = 0.65, 0.4, 1
CT.AddSpell("Shadow Bolt", { school = 32, kind = "damage", icon = 1686 })
local id = CT.SpellId("Shadow Bolt")
Check("B1 on the list, under Shadow", CT.SpellBase("Shadow Bolt") == "spellShadow")
local same = true
for _, setting in ipairs(CT.LOOK_SETTINGS) do
	local a, b = CT.Get(id, setting), CT.Get("spellShadow", setting)
	if a ~= b then same = false print("  differs: " .. setting .. " " .. tostring(a) .. " vs " .. tostring(b)) end
end
Check("B1 nothing of its own: every setting its school's", same)
local plain = Draw("spellShadow")
local asSpell = Draw("spellShadow", "Shadow Bolt")
Check("B1 drawn as its school with nothing of its own", SameColor(plain, asSpell) and Near(plain[4], asSpell[4]),
	Words(plain) .. " / " .. Words(asSpell))
Check("B1 the tab's grey values: its school's", Near(CT.Usual(id, "Size"), CT.Get("spellShadow", "Size")))

CT.Field(id, "R").set(0.9)
local color = CT.Color(id)
Check("B2 a color of its own: all three set together", ns.db[CT.Key(id, "G")] ~= nil and ns.db[CT.Key(id, "B")] ~= nil)
Check("B2 drawn in it", SameColor(Draw("spellShadow", "Shadow Bolt"), { color[1], color[2], color[3] }),
	Words(Draw("spellShadow", "Shadow Bolt")))
Check("B2 the school itself unchanged", SameColor(Draw("spellShadow"), plain))
Check("B2 another spell's hit of the school unchanged", SameColor(Draw("spellShadow", "Curse of Agony"), plain))

local crit = Draw("spellCritShadow", "Shadow Bolt")
Check("B3 its crit: its color", SameColor(crit, { color[1], color[2], color[3] }), Words(crit))
CT.Field(id, "CR").set(1)
CT.Field(id, "CG").set(1)
CT.Field(id, "CB").set(1)
crit = Draw("spellCritShadow", "Shadow Bolt")
Check("B3 its crits' color of its own", SameColor(crit, { 1, 1, 1 }), Words(crit))
Check("B3 its hits keep their color", SameColor(Draw("spellShadow", "Shadow Bolt"), { color[1], color[2], color[3] }))

local before = Draw("spellShadow", "Shadow Bolt")[4]
CT.Field(id, "Size").set(1.3)
local bigger = Draw("spellShadow", "Shadow Bolt")[4]
Check("B4 its own size: 130%", Near(bigger / before, 1.3), ("%.1f -> %.1f"):format(before, bigger))
CT.Field(id, "Ticks").set("small")
Check("B5 ticks smaller: a tick 75%", Near(Draw("spellShadow", "Shadow Bolt", true)[4] / bigger, 0.75))
Check("B5 its hits not", Near(Draw("spellShadow", "Shadow Bolt")[4], bigger))

ns.db[CT.Key(id, "Show")] = false
Check("B6 its switch off: not drawn", Draw("spellShadow", "Shadow Bolt") == nil)
Check("B6 the rest of Shadow still drawn", Draw("spellShadow") ~= nil)
ns.db[CT.SPELLS_TAB] = false
local tabOff = Draw("spellShadow", "Shadow Bolt")
Check("B7 the tab off: drawn, in its school's look", tabOff ~= nil and SameColor(tabOff, plain), Words(tabOff))
ns.db[CT.SPELLS_TAB] = nil
ns.db[CT.Key(id, "Show")] = nil
Check("B8 a spell not on the list: its school's look", SameColor(Draw("spellShadow", "Death Coil"), plain))

CT.AddSpell("Firebolt", { school = 4, kind = "pet" })
Check("B9 a pet's spell: under Your pet", CT.SpellBase("Firebolt") == "pet")
local petPlain = Draw("pet", nil, nil, "spellFire")
Check("B9 nothing of its own: your pet's Fire look", SameColor(Draw("pet", "Firebolt", nil, "spellFire"), petPlain))
CT.Field(CT.SpellId("Firebolt"), "R").set(0.2)
local petOwn = CT.Color(CT.SpellId("Firebolt"))
Check("B9 its own color", SameColor(Draw("pet", "Firebolt", nil, "spellFire"), { petOwn[1], petOwn[2], petOwn[3] }))
Check("B9 still your pet's size", Near(Draw("pet", "Firebolt", nil, "spellFire")[4], petPlain[4]))
CT.AddSpell("Healing Touch", { school = 8, kind = "heal" })
Check("B10 a heal: under Heals", CT.SpellBase("Healing Touch") == "heal")
Check("B10 its crit text", CT.CritOf("heal") == "healCrit" and CT.CritOf("spellFire") == "spellCritFire"
	and CT.CritOf("pet") == "petCrit" and CT.CritOf("ability") == "spellCritAbility")

-- C. Saving --------------------------------------------------------------------
Check("C1 a spell's setting is kept with profiles", ns.MarkRowDefault(CT.Key(id, "R")) ~= nil
	and ns.MarkRowDefault(CT.Key(id, "Show")) ~= nil and ns.MarkRowDefault(CT.Key(id, "Ticks")) ~= nil)
Check("C1 any other ct_ key isn't", ns.MarkRowDefault("ct_spellFire_R") == nil and ns.MarkRowDefault("ct_sp:X_Nope") == nil)
Check("C2 sharing takes a spell's color, size, switch", ns.KnownProfileSetting(CT.Key(id, "R"), 0.5)
	and ns.KnownProfileSetting(CT.Key(id, "Size"), 1.3) and ns.KnownProfileSetting(CT.Key(id, "Show"), false)
	and ns.KnownProfileSetting(CT.Key(id, "Ticks"), "small"))
Check("C2 not a wrong type", not ns.KnownProfileSetting(CT.Key(id, "R"), "red"))
Check("C3 the list is a profile table", ns.IS_PROFILE_TABLE.combatTextSpells == true
	and ns.KnownProfileSetting("combatTextSpells", { ["Shadow Bolt"] = { school = 32, kind = "damage", icon = 5 } }))
Check("C3 a broken list isn't taken", not ns.KnownProfileSetting("combatTextSpells", { ["Shadow Bolt"] = { kind = "other" } })
	and not ns.KnownProfileSetting("combatTextSpells", { ["Shadow Bolt"] = "red" }))
Check("C4 changed parts", table.concat(CT.OwnParts(id), ",") == "Color,Text", table.concat(CT.OwnParts(id), ","))
ns.ResetCombatTextSpells()
Check("C5 Reset: looks gone, the list stays", #CT.OwnParts(id) == 0 and CT.SpellInfo("Shadow Bolt") ~= nil
	and ns.db[CT.Key(id, "CR")] == nil)
CT.Field(id, "R").set(0.9)
ns.db[CT.Key(id, "Show")] = false
CT.RemoveSpell("Shadow Bolt")
Check("C6 Remove: off the list, its look and switch gone", CT.SpellInfo("Shadow Bolt") == nil
	and ns.db[CT.Key(id, "R")] == nil and ns.db[CT.Key(id, "Show")] == nil)

CinematicDB = CinematicDB or {}
CinematicCharDB = {}
CT.AddSpell("Siphon Life", { kind = "damage", unknown = true })
Check("C7 added before its first hit: under Spells and abilities", CT.SpellBase("Siphon Life") == "spell")
CT.NoteSeen({ name = "Siphon Life", school = 32, tick = true, icon = 7 }, "damage")
Check("C7 its first tick: its school learned, it ticks", CT.SpellBase("Siphon Life") == "spellShadow"
	and CT.SpellInfo("Siphon Life").ticks == true)
Check("C7 in the hit-with list", CT.Seen()["Siphon Life"] and CT.Seen()["Siphon Life"].hits == 1)
for i = 1, CT.SEEN_MAX + 5 do CT.NoteSeen({ name = "Spell " .. i, school = 4 }, "damage") end
local count = 0
for _ in pairs(CT.Seen()) do count = count + 1 end
Check("C8 the hit-with list capped", count <= CT.SEEN_MAX, count)

-- D. The page --------------------------------------------------------------------
CT.AddSpell("Corruption", { school = 32, kind = "damage", ticks = true })
local ok, err = pcall(ns.CreateCombatTextStylePanel, ns.lowHealthKit)
Check("D1 the page builds with its Spells tab", ok and type(ns.combatTextSpellLook) == "function", err)
local okLook, errLook = pcall(ns.combatTextSpellLook, "Corruption")
Check("D2 a spell's Look panel opens", okLook, errLook)
Check("D3 the spellbook reader runs", pcall(ns.CombatTextBookSpells))
-- (Combat text's own files only: another part's load warning isn't this check's.)
local ours = {}
for _, warning in ipairs(wow.warnings or {}) do
	if tostring(warning):find("CombatText", 1, true) then ours[#ours + 1] = tostring(warning) end
end
Check("D4 no warnings from combat text's files", #ours == 0, table.concat(ours, " | "))

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
