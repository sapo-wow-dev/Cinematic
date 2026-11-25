-- /cine debug platerings: step 0 of Tools/plate-distance-plan.md (Smart rows
-- "within X yards"). Nothing measures yards to a plate; only yes/no "rings"
-- do: CheckInteractDistance's indexes, your spells' ranges, items' ranges.
-- This finds, on this client and character, which of them answer on
-- nameplate units, out of a fight and in one, and where the interact
-- indexes sit among your spells' yards. Your one action: stand where some
-- mobs and NPCs have plates (no walking), then pull something when it asks
-- (or press No fight). Steps:
--   1 checks  the rings this character has: every interact index (1-5),
--             one spellbook spell per yards (attack or helpful, none with a
--             least range), the items in your bags that have a use (PASS if
--             any spell ring)
--   2 calm    out of a fight, 20 samples over 10 s of every plate: each
--             ring's answers (true / false / nil / secret / error), whether
--             the spell rings nest (in 20 => in 30), each interact index's
--             yards bracketed by the spell rings, ms per pass
--   3 fight   the same in a fight (retail: no interact on plates, rule
--             retail.checkinteractdistance.blocked-in-combat); a blocked
--             action stops that ring at once
--   4 results RESULT lines per question (Tools/tests/plate-distance.md), and
--             CinematicDB.plateRingsProbe[client] kept for the build
-- Enemy and friendly plates on for the run and put back. Into
-- CinematicDB.plateRingsTestLog. Dev copy only (CinematicDev.toc).
local _, ns = ...

local SAMPLES, GAP = 20, 0.5 -- (per step: 10 seconds)
local MAX_UNITS = 20 -- plates asked per sample
local MAX_ITEMS = 8
local PLATES = ns.CVarSet("Plate rings probe: plates", "/cine debug platerings: enemy and friendly plates on for the run",
	-- (Forever has no nameplateShowFriends: its friendly plates are
	-- nameplateShowFriendlyNpcs / Players, run q5e93. A CVar a client
	-- hasn't got is left alone.)
	{ values = { nameplateShowEnemies = "1", nameplateShowFriends = "1", nameplateShowFriendlyNpcs = "1",
		nameplateShowFriendlyPlayers = "1" } })

local probe -- { rings = { {key, kind, yards, id, name, ask} }, calm = agg, fight = agg }

local function Client()
	if ns.isRetail then return "retail" end
	return ns.isClassicEra and "classic_era" or "forever"
end
local function Secret(v) return issecretvalue ~= nil and issecretvalue(v) end

-- Each spell's range: C_Spell.GetSpellInfo (min, max), old GetSpellInfo too.
local function Ranges(id)
	if C_Spell and C_Spell.GetSpellInfo then
		local ok, info = pcall(C_Spell.GetSpellInfo, id)
		if ok and type(info) == "table" then return info.minRange, info.maxRange, info.name end
	elseif GetSpellInfo then
		local name, _, _, _, minR, maxR = GetSpellInfo(id)
		return minR, maxR, name
	end
end
local HARM = C_Spell and C_Spell.IsSpellHarmful or IsHarmfulSpell
local HELP = C_Spell and C_Spell.IsSpellHelpful or IsHelpfulSpell
local IN_RANGE = C_Spell and C_Spell.IsSpellInRange or IsSpellInRange
local ITEM_RANGE = C_Item and C_Item.IsItemInRange or IsItemInRange

-- (Every spell you know, from the spellbook; the bars too, for spells only
-- there. Ids, each once.)
local function KnownSpells()
	local ids, seen, from = {}, {}, {}
	local function Add(id, where)
		if type(id) == "number" and not Secret(id) and not seen[id] then
			seen[id] = true
			ids[#ids + 1] = id
			from[where] = (from[where] or 0) + 1
		end
	end
	local ok, err = pcall(function()
		if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
			local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
			for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
				local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
				if info then
					for i = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
						local item = C_SpellBook.GetSpellBookItemInfo(i, bank)
						if item and not item.isPassive then Add(item.spellID or item.actionID, "book") end
					end
				end
			end
		end
	end)
	for slot = 1, 180 do
		local okA, kind, id = pcall(GetActionInfo, slot)
		if okA and kind == "spell" then Add(id, "bars") end
	end
	return ids, ("spellbook %s (%d), bars %d"):format(ok and "read" or ("error " .. tostring(err)), from.book or 0,
		from.bars or 0)
end

-- The rings: { key, kind ("interact" / "harmful" / "helpful" / "item"), yards (nil: not known), ask(unit) }.
local function Rings(r)
	local rings = {}
	for index = 1, 5 do
		rings[#rings + 1] = { key = "interact" .. index, kind = "interact", index = index,
			ask = function(unit) return CheckInteractDistance(unit, index) end }
	end
	local ids, where = KnownSpells()
	r:Log("spells known: " .. #ids .. " (" .. where .. ")")
	local byYards = { harmful = {}, helpful = {} }
	local skipped = 0
	for _, id in ipairs(ids) do
		local minR, maxR, name = Ranges(id)
		if type(maxR) == "number" and not Secret(maxR) and maxR > 0 then
			for kind, test in pairs({ harmful = HARM, helpful = HELP }) do
				local okT, is = pcall(test, id)
				if okT and is == true then
					if type(minR) == "number" and not Secret(minR) and minR > 0 then
						skipped = skipped + 1 -- (a least range: "not in range" up close too)
					elseif not byYards[kind][maxR] then
						byYards[kind][maxR] = { id = id, name = tostring(name) }
					end
				end
			end
		end
	end
	for _, kind in ipairs({ "harmful", "helpful" }) do
		local list = {}
		for yards in pairs(byYards[kind]) do list[#list + 1] = yards end
		table.sort(list)
		for _, yards in ipairs(list) do
			local spell = byYards[kind][yards]
			rings[#rings + 1] = { key = kind .. yards, kind = kind, yards = yards, id = spell.id, name = spell.name,
				ask = function(unit) return IN_RANGE(spell.id, unit) end }
		end
	end
	r:Log(("spells with a least range left out: %d"):format(skipped))
	-- (Items in your bags with a use: whether the item range call answers at
	-- all; their yards aren't known here.)
	local items, seen = 0, {}
	pcall(function()
		for bag = 0, 4 do
			for slot = 1, (C_Container and C_Container.GetContainerNumSlots(bag) or 0) do
				local id = C_Container.GetContainerItemID(bag, slot)
				if id and not seen[id] and items < MAX_ITEMS then
					local spell = C_Item and C_Item.GetItemSpell and C_Item.GetItemSpell(id)
					if spell then
						seen[id] = true
						items = items + 1
						rings[#rings + 1] = { key = "item" .. id, kind = "item", id = id, name = tostring(spell),
							ask = function(unit) return ITEM_RANGE(id, unit) end }
					end
				end
			end
		end
	end)
	return rings
end

local function Units()
	local units = {}
	local okP, plates = pcall(C_NamePlate.GetNamePlates)
	for _, plate in ipairs(okP and plates or {}) do
		local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
		if type(unit) == "string" and #units < MAX_UNITS then units[#units + 1] = unit end
	end
	return units
end

-- One step's tally: per ring, answers counted; per plate and sample the yes/no
-- answers for nesting and brackets; time per pass.
local function NewTally() return { count = {}, passes = 0, ms = 0, calls = 0, nestBad = 0, nestSeen = 0,
	lo = {}, hi = {}, units = 0, enemies = 0, friends = 0, blocked = {}, examples = {} } end

local blockedNow -- (the ring being asked when ADDON_ACTION_BLOCKED fires)
local watcher = CreateFrame("Frame")
watcher:SetScript("OnEvent", function()
	if probe and probe.tally and blockedNow then
		probe.tally.blocked[blockedNow] = (probe.tally.blocked[blockedNow] or 0) + 1
	end
end)

local function Sample(tally, rings, skipInteract)
	local start = debugprofilestop()
	for _, unit in ipairs(Units()) do
		tally.units = tally.units + 1
		local enemy = select(2, pcall(UnitCanAttack, "player", unit)) == true
		if enemy then tally.enemies = tally.enemies + 1 else tally.friends = tally.friends + 1 end
		local yes = {}
		for _, ring in ipairs(rings) do
			if not (skipInteract and ring.kind == "interact") and (tally.blocked[ring.key] or 0) == 0 then
				blockedNow = ring.key
				local ok, value = pcall(ring.ask, unit)
				blockedNow = nil
				tally.calls = tally.calls + 1
				local word = not ok and "error" or Secret(value) and "secret" or value == nil and "nil"
					or (value == true or value == 1) and "true" or "false"
				local c = tally.count[ring.key] or {}
				tally.count[ring.key] = c
				c[word] = (c[word] or 0) + 1
				if word == "true" or word == "false" then yes[ring] = word == "true" end
			end
		end
		-- Nesting: spell rings of one kind, shorter in => longer in.
		for a, inA in pairs(yes) do
			if a.yards then
				for b, inB in pairs(yes) do
					if b.yards and b.kind == a.kind and b.yards > a.yards then
						tally.nestSeen = tally.nestSeen + 1
						if inA and not inB then
							tally.nestBad = tally.nestBad + 1
							if #tally.examples < 5 then
								tally.examples[#tally.examples + 1] = ("%s in %d but not %d"):format(unit, a.yards, b.yards)
							end
						end
					end
				end
			end
		end
		-- Brackets: an interact index in where a spell's yards isn't => past
		-- them; out where it is => short of them.
		for a, inA in pairs(yes) do
			if a.kind == "interact" then
				for b, inB in pairs(yes) do
					if b.yards then
						if inA and not inB then tally.lo[a.key] = math.max(tally.lo[a.key] or 0, b.yards) end
						if not inA and inB then tally.hi[a.key] = math.min(tally.hi[a.key] or 999, b.yards) end
					end
				end
			end
		end
	end
	tally.passes = tally.passes + 1
	tally.ms = tally.ms + (debugprofilestop() - start)
end

local function Report(r, name, tally, rings)
	r:Log(("%s: %d passes, %d plate looks (%d enemy, %d friendly), %d calls, %.2f ms per pass, %.4f ms per call"):format(
		name, tally.passes, tally.units, tally.enemies, tally.friends, tally.calls,
		tally.passes > 0 and tally.ms / tally.passes or 0, tally.calls > 0 and tally.ms / tally.calls or 0))
	for _, ring in ipairs(rings) do
		local c = tally.count[ring.key]
		if c or tally.blocked[ring.key] then
			c = c or {}
			r:Log(("%s %s%s: true %d, false %d, nil %d, secret %d, error %d, blocked %d%s"):format(name, ring.key,
				ring.name and (" (" .. ring.name .. ")") or "", c["true"] or 0, c["false"] or 0, c["nil"] or 0,
				c.secret or 0, c.error or 0, tally.blocked[ring.key] or 0,
				ring.kind == "interact" and (", yards %s to %s"):format(tostring(tally.lo[ring.key] or "?"),
					tostring(tally.hi[ring.key] and tally.hi[ring.key] < 999 and tally.hi[ring.key] or "?")) or ""))
		end
	end
	r:Log(("%s nesting: %d of %d pairs broke%s"):format(name, tally.nestBad, tally.nestSeen,
		#tally.examples > 0 and (" (" .. table.concat(tally.examples, "; ") .. ")") or ""))
end

-- (Whether a kind of ring gave a plain yes/no on plates, and was never
-- blocked: "yes", "no (why)", or "not asked".)
local function KindWorks(tally, rings, kind)
	local plain, other, blocked, asked = 0, 0, 0, false
	for _, ring in ipairs(rings) do
		if ring.kind == kind then
			local c = tally and tally.count[ring.key]
			if c then
				asked = true
				plain = plain + (c["true"] or 0) + (c["false"] or 0)
				other = other + (c.secret or 0) + (c.error or 0)
			end
			blocked = blocked + (tally and tally.blocked[ring.key] or 0)
		end
	end
	if not asked and blocked == 0 then return "not asked" end
	if blocked > 0 then return ("NO, blocked %d time(s)"):format(blocked) end
	if plain == 0 then return ("NO, no plain answer (%d secret/error)"):format(other) end
	return ("yes, %d plain answers, %d secret/error"):format(plain, other)
end

local function Run(r, name, skipInteract, keepGoing)
	local tally = NewTally()
	probe.tally = tally
	watcher:RegisterEvent("ADDON_ACTION_BLOCKED")
	for i = 1, SAMPLES do
		if keepGoing and not keepGoing() then
			r:Log(("%s: stopped after %d samples (%s)"):format(name, i - 1, "the fight ended"))
			break
		end
		r:Prompt(("Sampling plates (%s): %d of %d"):format(name, i, SAMPLES), "Stay where you are.",
			(SAMPLES - i + 1) * GAP)
		local ok, err = pcall(Sample, tally, probe.rings, skipInteract)
		if not ok then r:Log("sample error: " .. tostring(err)) end
		r:Sleep(GAP)
	end
	watcher:UnregisterEvent("ADDON_ACTION_BLOCKED")
	probe.tally = nil
	Report(r, name, tally, probe.rings)
	return tally
end

ns.TestKit.Define({
	name = "platerings",
	key = "plateRingsTest",
	title = "Plate range rings probe",
	about = "which range checks answer on nameplates (interact, spells, items), out of and in a fight",
	needs = "Stand where a few mobs and NPCs have plates; a mob to pull",
	cvars = { "nameplateShowEnemies", "nameplateShowFriends", "nameplateMaxDistance" },
	context = function()
		return ("platerings: client %s, %s"):format(Client(), InCombatLockdown() and "in a fight" or "out of a fight")
	end,
	putBack = function(extra)
		if extra.plates then
			ns.ApplyCVarSet(PLATES, false)
			return "plates put back"
		end
	end,
	steps = {
		{ key = "checks", title = "the rings this character has", run = function(r)
			r:Keep("plates", true)
			ns.ApplyCVarSet(PLATES, true)
			r:Probe("C_Spell.IsSpellInRange", function() return IN_RANGE ~= nil end)
			r:Probe("C_Item.IsItemInRange", function() return ITEM_RANGE ~= nil end)
			r:Probe("CheckInteractDistance", function() return CheckInteractDistance ~= nil end)
			probe = { rings = Rings(r) }
			local spells, items, list = 0, 0, {}
			for _, ring in ipairs(probe.rings) do
				if ring.yards then
					spells = spells + 1
					list[#list + 1] = ("%s %d (%s)"):format(ring.kind, ring.yards, ring.name)
				elseif ring.kind == "item" then
					items = items + 1
				end
			end
			r:Log("spell rings: " .. (#list > 0 and table.concat(list, ", ") or "none"))
			r:Log(("item rings: %d (items in your bags with a use)"):format(items))
			r:Verdict(spells > 0, spells .. " spell ring(s) to measure the interact indexes against")
		end },
		{ key = "calm", title = "out of a fight", run = function(r)
			if not probe then return r:Skip("no rings (step 1 left out)") end
			-- (One plate is enough to go on: run q5e93 waited for 3 and stuck.
			-- More plates at more distances give tighter brackets.)
			local count = r:WaitFor("Stand where mobs or NPCs have plates, out of a fight. No need to move.", {
				check = function()
					local n = #Units()
					return not InCombatLockdown() and n >= 1 and n
				end })
			r:Log("plates up: " .. tostring(count))
			probe.calm = Run(r, "calm", false)
			r:Verdict(probe.calm.passes > 0, "sampled out of a fight")
		end },
		{ key = "fight", title = "in a fight", run = function(r)
			if not probe then return r:Skip("no rings (step 1 left out)") end
			if not ns.isRetail and r:Proven("Forever run q5e93: interact and attack spells plain on plates in a fight, items nil") then
				return r:Skip("proven on Forever (run q5e93)")
			end
			local answer, which = r:WaitFor("Pull a mob and keep fighting about 10 seconds (stay near the others).", {
				check = function() return InCombatLockdown() and #Units() >= 1 and "fighting" end,
				buttons = { "No fight" } })
			if answer == "button" and which == "No fight" then return r:Skip("no fight") end
			local skip = ns.isRetail
			if skip then
				r:Log("interact rings left out in the fight (rule retail.checkinteractdistance.blocked-in-combat)")
			end
			probe.fight = Run(r, "fight", skip, function() return InCombatLockdown() end)
			r:Verdict(probe.fight.passes > 0, "sampled in a fight")
		end },
		{ key = "results", title = "results", run = function(r)
			if not probe then return r:Skip("no rings") end
			local client = Client()
			local calm, fight = probe.calm, probe.fight
			local lines = {
				{ "Q1", "interact on plates, out of a fight", KindWorks(calm, probe.rings, "interact") },
				{ "Q2", "interact on plates, in a fight", ns.isRetail and "not asked (blocked, rule)"
					or KindWorks(fight, probe.rings, "interact") },
				{ "Q3", "attack spell ranges on plates, out of a fight", KindWorks(calm, probe.rings, "harmful") },
				{ "Q4", "attack spell ranges on plates, in a fight", KindWorks(fight, probe.rings, "harmful") },
				{ "Q5", "helpful spell ranges on plates, out of a fight", KindWorks(calm, probe.rings, "helpful") },
				{ "Q6", "helpful spell ranges on plates, in a fight", KindWorks(fight, probe.rings, "helpful") },
				{ "Q7", "item ranges on plates, out of a fight", KindWorks(calm, probe.rings, "item") },
				{ "Q8", "item ranges on plates, in a fight", KindWorks(fight, probe.rings, "item") },
			}
			-- (Brackets from both steps: a distance is a distance.)
			local brackets = {}
			for index = 1, 5 do
				local key = "interact" .. index
				local lo, hi
				for _, tally in ipairs({ calm or {}, fight or {} }) do
					if tally.lo and tally.lo[key] then lo = math.max(lo or 0, tally.lo[key]) end
					if tally.hi and tally.hi[key] then hi = math.min(hi or 999, tally.hi[key]) end
				end
				brackets[#brackets + 1] = ("%d: %s-%s"):format(index, tostring(lo or "?"),
					tostring(hi and hi < 999 and hi or "?"))
			end
			lines[#lines + 1] = { "Q9", "interact index yards (between spell rings)", table.concat(brackets, ", ") }
			lines[#lines + 1] = { "Q10", "spell rings nest", calm and ("%d of %d pairs broke"):format(calm.nestBad,
				calm.nestSeen) or "not asked" }
			lines[#lines + 1] = { "Q11", "cost", calm and ("%.2f ms per pass of %d plates"):format(
				calm.passes > 0 and calm.ms / calm.passes or 0, calm.passes > 0 and math.floor(calm.units / calm.passes) or 0)
				or "not asked" }
			CinematicDB.plateRingsProbe = CinematicDB.plateRingsProbe or {}
			local before = CinematicDB.plateRingsProbe[client] or {}
			local kept = { at = date("%Y-%m-%d %H:%M"), build = select(4, GetBuildInfo()) }
			-- (The fight left out as proven: its answers from the run that proved them.)
			if not fight then
				for _, line in ipairs(lines) do
					if line[3] == "not asked" and line[2]:find("in a fight", 1, true) and before[line[1]] then
						line[3] = before[line[1]] .. " (from the run at " .. tostring(before.at) .. ")"
					end
				end
			end
			for _, line in ipairs(lines) do
				r:Log(("RESULT %s %s (%s): %s"):format(line[1], line[2], client, line[3]))
				kept[line[1]] = line[3]
			end
			CinematicDB.plateRingsProbe[client] = kept
			r:Verdict(calm ~= nil and calm.passes > 0, "results kept in CinematicDB.plateRingsProbe." .. client)
		end },
	},
})
