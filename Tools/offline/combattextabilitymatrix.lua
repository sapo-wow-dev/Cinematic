-- Combat Text Style's Spells tab: physical abilities' hits (the audit kit's
-- matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-25-combat-text-ability-cast.md):
--   python -I Tools/offline/run.py Tools/offline/combattextabilitymatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/combattextabilitymatrix.lua forever --base <ref>
-- A hit on your target's plate, driven as the game sends it (your cast as
-- UNIT_SPELLCAST_SUCCEEDED, the hit as the plate's UNIT_COMBAT, a frame on):
-- a Mortal Strike landing in its cast's frame; one cast just after a Charge
-- (no hit of its own); a white swing with no cast; a swing landing while a
-- Mortal Strike's cast still waits (its hit dodged a moment before, no
-- dodge sent); a Mortal Strike dodged; a Searing Pain (Fire) as a spell's
-- hit. A crit or not; the spells on the Spells tab's list (each its own
-- color) or not; the combat log's lines coming (Forever's) or none.
-- Each cell: the look the number drew in (the listed spell's own color, the
-- text's plain look, or none drawn) and the spell the hit was learned as
-- ("Your spells that hit", the Add list's first part).
-- The rule (2026-11-25): a physical ability's hit takes its cast (the one in
-- its frame) and shows its Spells look; a white swing never takes one.
local client = arg and arg[1] or "forever"
local now = 1000
local timers = {}
local logOn = false
local NAMES = { [12294] = "Mortal Strike", [100] = "Charge", [5676] = "Searing Pain" }
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function(stub)
	-- luacheck: push ignore 111 112 113 121 122
	GetTime = function() return now end
	issecretvalue = function() return false end
	C_Timer.After = function(seconds, fn) timers[#timers + 1] = { at = now + (seconds or 0), fn = fn } end
	C_Spell = C_Spell or {}
	C_Spell.GetSpellName = function(id) return NAMES[id] end
	C_Spell.GetSpellTexture = function(id) return 1000 + id end
	C_Spell.IsSpellHarmful = function(id) return NAMES[id] ~= nil end
	C_Spell.IsSpellHelpful = function() return false end
	C_Spell.GetSpellDescription = function(id)
		return ({ [12294] = "A vicious strike that deals weapon damage plus 85 and wounds the target.",
			[100] = "Charge an enemy, generate 9 rage, and stun it for 1 sec.",
			[5676] = "Inflict searing pain on the enemy target, causing 38 Fire damage." })[id] or ""
	end
	STRING_SCHOOL_FIRE, STRING_SCHOOL_SHADOW, STRING_SCHOOL_HOLY = "Fire", "Shadow", "Holy"
	STRING_SCHOOL_NATURE, STRING_SCHOOL_FROST, STRING_SCHOOL_ARCANE = "Nature", "Frost", "Arcane"
	C_CombatLog = { AreFilteredEventsEnabled = function() return logOn end, SetFilteredEventsEnabled = function() end }
	UnitClass = function() return "Someone", "SOMEONE" end -- (a class not in off.CLASS: every school its)
	UnitGUID = function(unit) if unit == "target" or unit == "nameplate1" then return "Creature-1" end end
	UnitCanAttack = function(_, unit) return unit == "target" or unit == "nameplate1" end
	UnitIsUnit = function(a, b)
		if a == b then return true end
		return (a == "nameplate1" and b == "target") or (a == "target" and b == "nameplate1")
	end
	UnitExists = function(unit) return unit == "target" or unit == "nameplate1" end
	IsInGroup, IsInRaid = function() return false end, function() return false end
	InCombatLockdown = function() return false end
	local plate = stub.CreateFrame("Frame", nil, UIParent)
	C_NamePlate = C_NamePlate or {}
	C_NamePlate.GetNamePlateForUnit = function(unit) if unit == "nameplate1" then return plate end end
	C_NamePlate.GetNamePlates = function() return { plate } end
	-- (Unit events kept with their units, so a plate's hit goes to that
	-- plate's listener only, a player's cast to the player's.)
	local methods = stub.Methods
	methods.RegisterUnitEvent = function(self, event, ...)
		self._events[event] = true
		self._units = self._units or {}
		self._units[event] = { ... }
	end
	-- luacheck: pop
end)
local CT = ns.CombatTexts

-- An event as the game sends it: a unit event only to frames listening for that unit.
local function Send(event, unit, ...)
	for _, frame in ipairs(wow.frames) do
		local handler = frame._events[event] and frame._scripts.OnEvent
		local units = frame._units and frame._units[event]
		local wants = not units
		for _, each in ipairs(units or {}) do if each == unit then wants = true end end
		if handler and wants then
			local ok, err = pcall(handler, frame, event, unit, ...)
			if not ok then print("event error: " .. tostring(err)) end
		end
	end
end
local function Run(seconds)
	local stop = now + seconds
	repeat
		now = now + 0.02
		-- (Due ones in the order they were made; one the addon's other parts
		-- left at login that errors here isn't this test's.)
		local due, left = {}, {}
		for _, timer in ipairs(timers) do
			if timer.at <= now then due[#due + 1] = timer else left[#left + 1] = timer end
		end
		timers = left
		for _, timer in ipairs(due) do pcall(timer.fn) end
	until now >= stop
end
Run(5) -- (what login left waiting)
local function Cast(spell) Send("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-" .. spell, spell) end
local function Line() wow.Fire("COMBAT_LOG_MESSAGE", "|Ky1|k", 1, 1, 0.3, 0) end
local function Hit(action, school, crit)
	wow.Fire("DAMAGE_METER_COMBAT_SESSION_UPDATED", 0, 1)
	Send("UNIT_COMBAT", "nameplate1", action, crit and "CRITICAL" or "", 120, school)
end

local COLORS = { ["Mortal Strike"] = { 0.11, 0.22, 0.33 }, ["Charge"] = { 0.44, 0.55, 0.66 },
	["Searing Pain"] = { 0.77, 0.88, 0.99 } }
local function List(on)
	for name, color in pairs(COLORS) do
		if on then
			CT.AddSpell(name, { kind = "damage" })
			local id = CT.SpellId(name)
			for i, part in ipairs({ "R", "G", "B" }) do ns.db[CT.Key(id, part)] = color[i] end
		else
			CT.RemoveSpell(name)
		end
	end
end
local function Hits()
	local counts = {}
	for name, entry in pairs(CT.Seen()) do counts[name] = entry.hits end
	return counts
end

local drawn = {}
ns.combatTextRecord = function(text) drawn[#drawn + 1] = tostring(text) end
local M = ns.CombatTextSpellMatch

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "combat-text-ability-cast",
	fixed = { client = client },
	dims = {
		{ "hit", { "ability", "abilityAfterCharge", "swing", "swingWhileCastWaits", "abilityDodged", "spell" } },
		{ "crit", { "no", "yes" } },
		{ "listed", { "yes", "no" } },
		{ "log", { "on", "off" } },
	},
	cell = function(c)
		ns.db.styleGeneral, ns.db.combatTextStyle, ns.db.combatTextNumbers = true, true, true
		ns.db.combatTextDamageBy = "ours"
		ns.combatTextBlocked = nil
		M.Reset()
		List(c.listed == "yes")
		logOn = c.log == "on"
		now = now + 100
		Run(0.1)
		local before = Hits()
		wipe(drawn)
		local crit = c.crit == "yes"
		if c.hit == "ability" then
			Cast(12294)
			if logOn then Line() end
			Hit("WOUND", 1, crit)
		elseif c.hit == "abilityAfterCharge" then
			Cast(100)
			Run(0.5)
			Cast(12294)
			if logOn then Line() end
			Hit("WOUND", 1, crit)
		elseif c.hit == "swing" then
			if logOn then Line() Run(0.5) end
			Hit("WOUND", 1, crit)
		elseif c.hit == "swingWhileCastWaits" then
			Cast(12294)
			Run(0.5)
			if logOn then Line() Run(0.5) end
			Hit("WOUND", 1, crit)
		elseif c.hit == "abilityDodged" then
			Cast(12294)
			if logOn then Line() end
			Hit("DODGE", 1, false)
		elseif c.hit == "spell" then
			Cast(5676)
			if logOn then Line() end
			Hit("WOUND", 4, crit)
		end
		Run(0.1)
		-- (What drew: its color against each listed spell's.)
		local look = "none"
		for _, line in ipairs(drawn) do
			local r, g, b = line:match("^DRAWN .- color=([%d%.]+),([%d%.]+),([%d%.]+)")
			if r then
				look = "plain"
				for name, color in pairs(COLORS) do
					if math.abs(tonumber(r) - color[1]) < 0.01 and math.abs(tonumber(g) - color[2]) < 0.01
						and math.abs(tonumber(b) - color[3]) < 0.01 then look = name end
				end
				break
			end
		end
		local seen = {}
		for name, hits in pairs(Hits()) do
			if hits ~= (before[name] or 0) then seen[#seen + 1] = name end
		end
		table.sort(seen)
		Run(1) -- (its 0.3 s record, and anything held, done before the next cell)
		return ("look=%s seen=%s"):format(look, #seen > 0 and table.concat(seen, ",") or "none")
	end,
	pins = {
		-- (An ability's hit: its cast's spell, its Spells look when listed.)
		{ "hit=ability", "look=Mortal Strike seen=Mortal Strike" },
		{ "hit=ability listed=no", "look=plain seen=Mortal Strike" },
		-- (Just after a Charge, no hit of its own: the cast in the hit's frame, Mortal Strike's.)
		{ "hit=abilityAfterCharge", "look=Mortal Strike seen=Mortal Strike" },
		{ "hit=abilityAfterCharge listed=no", "look=plain seen=Mortal Strike" },
		-- (A white swing never takes an ability's cast, waiting or not.)
		{ "hit=swing", "look=plain seen=none" },
		{ "hit=swingWhileCastWaits", "look=plain seen=none" },
		-- (A miss is its word, never a spell's look.)
		{ "hit=abilityDodged", "look=plain seen=none" },
		-- (A spell's hit, as before.)
		{ "hit=spell", "look=Searing Pain seen=Searing Pain" },
		{ "hit=spell listed=no", "look=plain seen=Searing Pain" },
	},
})
