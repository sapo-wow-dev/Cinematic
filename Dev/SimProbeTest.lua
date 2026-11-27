-- /cine debug simprobe: the simulation recorder's probe (Tools/sim-plan.md
-- step 1, ledger Tools/tests/sim-probe.md). What the game sends, and how
-- Cinematic's game settings change it, before the recorder is built.
-- Cinematic is paused for the run (ns.Suspend, quietly: it lets go of every
-- game setting it holds), so the settings switched are the test's alone.
-- Steps:
--   1 events    every event heard (RegisterAllEvents) for 8 s: kinds, the
--               combat log, BLOCKED? If it's blocked or hears nothing, the
--               steps after use way B: each event Cinematic's code names,
--               registered on its own (Dev/SimEvents.lua)
--   2 settings  every set in ns.cvarSets: on this client, takes, read back,
--               CVAR_UPDATE from our own write, put back
--   3 bulk      the sets expected to change nothing sent, all on vs yours:
--               3 rounds of 6 s each way, events counted
--   4 city      in a busy city: each plate set alone, on vs yours (A/B, 3
--               rounds), then a minute with every set that sent more on:
--               events a second by kind, bytes a minute, the recorder's cost
--   5 soft      by quest objects and NPCs: the soft targeting sets, A/B
--   6 fight     in fights: what reads as secret (player, target, a plate),
--               the fight sets A/B, events with secret arguments, the
--               combat log's payload
-- Each A/B set gets one line "simprobe set|label|group|verdict|changes" for
-- Tools/sim/cvars.lua to read. Every setting changed is kept (r:Keep) and put
-- back at the end, on a stop, or at the next login after a /reload. Into
-- CinematicDB.simProbeTestLog. Dev copy only.
local _, ns = ...

local Core = ns.SimCore
local ROUNDS, SECONDS, SETTLE = 3, 6, 1 -- (A/B: rounds, seconds a side, the switch's burst)
local SIZE_SECONDS, SNAPSHOT_EVERY = 60, 0.2

local state = { mode = nil } -- (way A "all" or way B "list", from step 1)

local function Fighting()
	return InCombatLockdown() or (ns.Flag and ns.Flag(UnitAffectingCombat("player")) and true) or false
end

local function Mode()
	return state.mode or "all"
end

-- The combat log by name is forbidden on Forever (rule forever.combatlog.cleu-forbidden).
local function SkipByName(name)
	return not ns.isRetail and name:find("^COMBAT_LOG_EVENT") ~= nil
end

local function Listen()
	if Mode() == "all" then return Core.Listen("all") end
	return Core.Listen("list", ns.SIM_EVENTS, SkipByName)
end

local function BlockedCount()
	if not ns.DevErrorCount then return 0 end
	local n = 0
	for _, kind in ipairs({ "blocked", "forbidden", "blocked (no event)", "blocked (chat line only)" }) do
		n = n + (ns.DevErrorCount(kind) or 0)
	end
	return n
end

-- Cinematic paused (quietly) so it holds no game setting while we switch them.
local function Pause(r)
	if ns.Suspend and ns.IsSuspended and not ns.IsSuspended() then
		r:Keep("paused", true)
		ns.suspendQuiet = true
		ns.Suspend("simulation probe: paused so it holds no game settings")
		ns.suspendQuiet = nil
		r:Log("Cinematic paused (every game setting it held let go)")
	end
end

-- Sets ---------------------------------------------------------------------------
-- The dev copy's own tests make sets too ("NPC title test: far", "Rule
-- check: enemy plates"): not Cinematic's settings, left out.
local function DevOnly(set)
	local label = (set.label or ""):lower()
	return label:find("%f[%a]test%f[%A]") ~= nil or label:find("probe", 1, true) ~= nil
		or label:find("^rule check") ~= nil
end

-- By the settings' own names (a label can say nothing: "Friendly player
-- bars on" is a plate setting), then the label for a raid's.
local function GroupOf(set)
	if (set.label or ""):lower():find("^raid ") then return "raid" end
	local plates, fight = false, false
	for cvar in pairs(set.values or {}) do
		local name = cvar:lower()
		if name:find("^softtarget") then return "soft" end
		if name:find("^nameplate") or name:find("^unitname") then plates = true end
		if name:find("combattext", 1, true) or name:find("^objectselectioncircle") or name:find("^findyourself") then
			fight = true
		end
	end
	return plates and "plates" or (fight and "fight" or "bulk")
end

local function Secure(set)
	if set.secure then return true end
	for cvar in pairs(set.values or {}) do
		if cvar:lower():find("^softtarget") then return true end -- (rule forever.softtarget.cvars-protected-combat)
	end
	return false
end

local function SetsIn(group)
	local list = {}
	for _, set in ipairs(ns.cvarSets or {}) do
		if not DevOnly(set) and GroupOf(set) == group then list[#list + 1] = set end
	end
	table.sort(list, function(a, b) return tostring(a.label) < tostring(b.label) end)
	return list
end

-- Sets tested together, so a step stays minutes, not a quarter hour: alike
-- ones in one bundle (if a bundle changes what's sent, run 2 splits it).
local BUNDLES = {
	{ pattern = "^Names: ", label = "Names over heads" },
	{ pattern = "^Instance plates off: ", label = "Instance plates off" },
	{ pattern = "^Class color names$", label = "Plate looks" },
	{ pattern = "^Nameplate style$", label = "Plate looks" },
	{ pattern = "^Plates one size$", label = "Plate looks" },
	{ pattern = "^Game's .* numbers on$", label = "Game's numbers on" },
	{ pattern = "^Game's .* numbers off$", label = "Game's numbers off" },
}
local SKIP = { ["Offscreen plates off"] = "no longer used: let go only" }

-- What a step tests: { label, values, secure, sets = { labels }, clash = { cvars } }.
-- A bundle's values: the first set's where two want one setting differently.
local function Units(r, group)
	local units, byLabel = {}, {}
	for _, set in ipairs(SetsIn(group)) do
		local label = tostring(set.label)
		if SKIP[label] then
			r:Log(("simprobe set|%s|%s|skipped|%s"):format(label, group, SKIP[label]))
		else
			local name = label
			for _, bundle in ipairs(BUNDLES) do
				if label:find(bundle.pattern) then name = bundle.label break end
			end
			local unit = byLabel[name]
			if not unit then
				unit = { label = name, values = {}, secure = false, sets = {}, clash = {} }
				byLabel[name] = unit
				units[#units + 1] = unit
			end
			unit.sets[#unit.sets + 1] = label
			unit.secure = unit.secure or Secure(set)
			for cvar, value in pairs(set.values) do
				if unit.values[cvar] == nil then
					unit.values[cvar] = value
				elseif not Core.Same(unit.values[cvar], value) then
					unit.clash[#unit.clash + 1] = cvar
				end
			end
		end
	end
	for _, unit in ipairs(units) do
		if #unit.sets > 1 then
			unit.label = ("%s (%d sets)"):format(unit.label, #unit.sets)
			r:Log(("  %s: %s%s"):format(unit.label, table.concat(unit.sets, ", "),
				#unit.clash > 0 and ("; set differently by two, the first kept: " .. table.concat(unit.clash, ", ")) or ""))
		end
	end
	return units
end

local function Names(values)
	local names = {}
	for cvar in pairs(values) do
		if Core.Read(cvar) ~= nil then names[#names + 1] = cvar end
	end
	table.sort(names)
	return names
end

-- Writes values for names; gives the ones that didn't read back as written.
local function Apply(names, values)
	local missed = {}
	for _, cvar in ipairs(names) do
		local ok, err, back = Core.Write(cvar, values[cvar])
		if not Core.Same(back, values[cvar]) then
			missed[#missed + 1] = ("%s=%s (want %s%s)"):format(cvar, tostring(back), tostring(values[cvar]),
				ok and "" or (", " .. tostring(err)))
		end
	end
	return missed
end

-- A/B ------------------------------------------------------------------------------
local function Rates(windows, event)
	local rates, sum = {}, 0
	for i, w in ipairs(windows) do
		local n = w.counts[event] or 0
		rates[i] = n / math.max((w.seconds or SECONDS) - SETTLE, 0.1)
		sum = sum + n
	end
	return rates, sum
end
local function MinMax(list)
	local lo, hi = math.huge, -math.huge
	for _, v in ipairs(list) do lo, hi = math.min(lo, v), math.max(hi, v) end
	return lo, hi
end
local function Mean(list)
	local s = 0
	for _, v in ipairs(list) do s = s + v end
	return #list > 0 and s / #list or 0
end

-- Which events differ, every round the same way (each A window above every B
-- one, or below), by 3 or more in all.
local function Compare(A, B)
	local events = {}
	for _, list in ipairs({ A, B }) do
		for _, w in ipairs(list) do
			for event in pairs(w.counts) do events[event] = true end
		end
	end
	local changed = {}
	for event in pairs(events) do
		if event ~= "CVAR_UPDATE" then
			local a, sa = Rates(A, event)
			local b, sb = Rates(B, event)
			local aLo, aHi = MinMax(a)
			local bLo, bHi = MinMax(b)
			if (aLo > bHi or bLo > aHi) and math.abs(sa - sb) >= 3 then
				changed[#changed + 1] = { event = event, a = Mean(a), b = Mean(b) }
			end
		end
	end
	table.sort(changed, function(x, y) return math.abs(x.a - x.b) > math.abs(y.a - y.b) end)
	return changed
end

local function Bursts(windows)
	local sum = {}
	for _, w in ipairs(windows) do
		for event, n in pairs(w.burst) do sum[event] = (sum[event] or 0) + n end
	end
	return sum
end

local function TotalRate(windows)
	local n, s = 0, 0
	for _, w in ipairs(windows) do
		n = n + w.total
		s = s + math.max((w.seconds or SECONDS) - SETTLE, 0.1)
	end
	return n / s
end

-- One set (or a bundle of sets): Cinematic's values (A) against yours (B),
-- ROUNDS rounds of SECONDS each way. opts.fight: each window in a fight.
local function ABTest(r, label, group, values, opts)
	opts = opts or {}
	local names = Names(values)
	if #names == 0 then
		r:Log(("simprobe set|%s|%s|absent|"):format(label, group))
		return { verdict = "absent" }
	end
	local base = {}
	local differs = false
	for _, cvar in ipairs(names) do
		base[cvar] = Core.Read(cvar)
		r:Keep("cvar:" .. cvar, base[cvar])
		if not Core.Same(base[cvar], values[cvar]) then differs = true end
	end
	if not differs then
		r:Log(("simprobe set|%s|%s|same|already at Cinematic's values here: nothing to compare"):format(label, group))
		return { verdict = "same" }
	end
	local A, B, notes, interfered = {}, {}, {}, {}
	for round = 1, ROUNDS do
		for _, side in ipairs({ "A", "B" }) do
			if opts.before then opts.before() end -- (the fight step: a fight on first)
			if opts.secure and InCombatLockdown() then
				r:WaitFor("Out of the fight, please: these settings can't change in one (hands off till then)",
					{ events = { "PLAYER_REGEN_ENABLED" }, handsOff = true })
			end
			local want = side == "A" and values or base
			local missed = Apply(names, want)
			if #missed > 0 then notes[#notes + 1] = side .. round .. " didn't take: " .. table.concat(missed, ", ") end
			Core.Window(label .. " " .. side .. round, SETTLE)
			local fightTicks, ticks = 0, 0
			for _ = 1, SECONDS * 2 do
				r:Sleep(0.5)
				ticks = ticks + 1
				if Fighting() then fightTicks = fightTicks + 1 end
				for _, cvar in ipairs(names) do
					if not interfered[cvar] and not Core.Same(Core.Read(cvar), want[cvar]) then
						interfered[cvar] = true
						notes[#notes + 1] = ("interference: %s is %s, wanted %s (%s%d)"):format(cvar,
							tostring(Core.Read(cvar)), tostring(want[cvar]), side, round)
					end
				end
			end
			local w = Core.Window(nil)
			w.fight = fightTicks / ticks
			table.insert(side == "A" and A or B, w)
		end
	end
	Apply(names, base)
	local changed = Compare(A, B)
	local parts = {}
	for i = 1, math.min(#changed, 8) do
		local c = changed[i]
		parts[#parts + 1] = ("%s %.2f>%.2f"):format(c.event, c.b, c.a)
	end
	local burstA, burstB = Bursts(A), Bursts(B)
	local bursts = {}
	for event, n in pairs(burstA) do
		if n >= 3 and (burstB[event] or 0) == 0 then bursts[#bursts + 1] = ("%s x%d on"):format(event, n) end
	end
	for event, n in pairs(burstB) do
		if n >= 3 and (burstA[event] or 0) == 0 then bursts[#bursts + 1] = ("%s x%d off"):format(event, n) end
	end
	table.sort(bursts)
	local verdict = next(interfered) and "unreliable" or (#changed > 0 and "changes" or "nothing")
	local a, b = TotalRate(A), TotalRate(B)
	r:Log(("simprobe set|%s|%s|%s|%s"):format(label, group, verdict, table.concat(parts, ", ")))
	r:Log(("  %s: all events %.1f/s yours, %.1f/s Cinematic's; switch bursts: %s"):format(label, b, a,
		#bursts > 0 and table.concat(bursts, ", ") or "none"))
	if opts.fight then
		local share = 0
		for _, w in ipairs(A) do share = share + w.fight end
		for _, w in ipairs(B) do share = share + w.fight end
		r:Log(("  %s: in a fight %.0f%% of the time"):format(label, share / (#A + #B) * 100))
	end
	for _, note in ipairs(notes) do r:Log("  " .. note) end
	return { verdict = verdict, a = a, b = b, changed = changed, windows = { A = A, B = B } }
end

local function Seconds(sets)
	return #sets * ROUNDS * SECONDS * 2 + 5
end

-- Fight reads -------------------------------------------------------------------
local READS = {
	{ "UnitHealth", function(u) return UnitHealth(u) end },
	{ "UnitHealthMax", function(u) return UnitHealthMax(u) end },
	{ "UnitPower", function(u) return UnitPower(u) end },
	{ "UnitPowerMax", function(u) return UnitPowerMax(u) end },
	{ "UnitAffectingCombat", function(u) return UnitAffectingCombat(u) end },
	{ "UnitCastingInfo", function(u) return UnitCastingInfo(u) end },
	{ "UnitChannelInfo", function(u) return UnitChannelInfo(u) end },
	{ "UnitIsDeadOrGhost", function(u) return UnitIsDeadOrGhost(u) end },
	{ "UnitReaction", function(u) return UnitReaction("player", u) end },
	{ "UnitLevel", function(u) return UnitLevel(u) end },
	{ "UnitName", function(u) return UnitName(u) end },
	{ "UnitGUID", function(u) return UnitGUID(u) end },
	{ "UnitThreatSituation", function(u) return UnitThreatSituation and UnitThreatSituation("player", u) end },
	{ "UnitClassification", function(u) return UnitClassification and UnitClassification(u) end },
	{ "aura 1 name", function(u)
		if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
			local data = C_UnitAuras.GetAuraDataByIndex(u, 1, "HELPFUL")
			return data and data.name
		end
		return UnitAura and (UnitAura(u, 1, "HELPFUL"))
	end },
	{ "debuff 1 expires", function(u)
		if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
			local data = C_UnitAuras.GetAuraDataByIndex(u, 1, "HARMFUL")
			return data and data.expirationTime
		end
		return UnitAura and select(6, UnitAura(u, 1, "HARMFUL"))
	end },
}
local PLAYER_READS = {
	{ "GetUnitSpeed", function() return GetUnitSpeed("player") end },
	{ "UnitPosition", function() return UnitPosition("player") end },
	{ "IsMounted", function() return IsMounted() end },
	{ "GetShapeshiftForm", function() return GetShapeshiftForm and GetShapeshiftForm() end },
}

local function FirstPlate()
	for i = 1, 40 do
		local unit = "nameplate" .. i
		if UnitExists(unit) and not UnitIsUnit(unit, "target") then return unit end
	end
end

-- Every read on each unit, SAMPLES times in the fight: how often plain,
-- secret, nil or an error. One line per unit.
local function SecretReads(r, samples)
	local tally = {}
	local function Note(unit, name, ok, value)
		local key = unit .. "|" .. name
		local t = tally[key] or { plain = 0, secret = 0, none = 0, err = 0, unit = unit, name = name }
		tally[key] = t
		if not ok then t.err = t.err + 1
		elseif value == nil then t.none = t.none + 1
		elseif issecretvalue and issecretvalue(value) then t.secret = t.secret + 1
		else t.plain = t.plain + 1 end
	end
	for _ = 1, samples do
		if not Fighting() then
			r:WaitFor("Keep fighting (or pull the next mob): the reads are taken in a fight",
				{ events = { "PLAYER_REGEN_DISABLED" } })
		end
		local plate = FirstPlate()
		for _, unit in ipairs({ "player", "target", plate or "nameplate1" }) do
			local label = unit:find("^nameplate") and "plate" or unit
			if UnitExists(unit) then
				for _, read in ipairs(READS) do Note(label, read[1], pcall(read[2], unit)) end
			end
		end
		for _, read in ipairs(PLAYER_READS) do Note("player", read[1], pcall(read[2])) end
		r:Sleep(1)
	end
	local byUnit = {}
	for _, t in pairs(tally) do
		byUnit[t.unit] = byUnit[t.unit] or {}
		local word = t.secret > 0 and (t.plain > 0 and "MIXED" or "SECRET") or (t.err > 0 and "ERROR" or
			(t.plain > 0 and "plain" or "nil"))
		table.insert(byUnit[t.unit], ("%s=%s(%d/%d/%d/%d)"):format(t.name, word, t.plain, t.secret, t.none, t.err))
	end
	for _, unit in ipairs({ "player", "target", "plate" }) do
		if byUnit[unit] then
			table.sort(byUnit[unit])
			r:Log(("simprobe reads|%s|%s"):format(unit, table.concat(byUnit[unit], " ")))
		else
			r:Log(("simprobe reads|%s|not seen in the fight"):format(unit))
		end
	end
	r:Log("  (each: plain/secret/nil/error counts over " .. samples .. " looks)")
end

-- The test -------------------------------------------------------------------------
ns.TestKit.Define({
	name = "simprobe",
	key = "simProbeTest",
	title = "Simulation probe",
	about = "what the game sends and how Cinematic's game settings change it, for the recorder (about 15 min of play)",
	needs = "a busy city, quest objects or NPCs nearby, then mobs to fight (about 15 minutes of play)",
	files = { "Dev/SimCore.lua", "Dev/SimProbeTest.lua" },
	cvars = { "nameplateShowAll", "nameplateShowEnemies", "nameplateShowFriends", "SoftTargetInteract" },
	context = function()
		return ("probe: %d game settings sets, way B list %d names, RegisterAllEvents %s, CombatLogGetCurrentEventInfo %s")
			:format(#(ns.cvarSets or {}), #(ns.SIM_EVENTS or {}), tostring(CreateFrame("Frame").RegisterAllEvents ~= nil),
				type(CombatLogGetCurrentEventInfo))
	end,
	putBack = function(extra)
		local back, waiting = 0, 0
		local later = {}
		for key, value in pairs(extra) do
			local cvar = type(key) == "string" and key:match("^cvar:(.+)$")
			if cvar and type(value) == "string" then
				if InCombatLockdown() and cvar:lower():find("^softtarget") then
					later[cvar] = value
					waiting = waiting + 1
				else
					Core.Write(cvar, value)
					back = back + 1
				end
			end
		end
		if next(later) then
			local f = CreateFrame("Frame")
			f:RegisterEvent("PLAYER_REGEN_ENABLED")
			f:SetScript("OnEvent", function(self)
				self:UnregisterAllEvents()
				for cvar, value in pairs(later) do Core.Write(cvar, value) end
			end)
		end
		Core.Stop()
		local resumed = false
		if extra.paused and ns.IsSuspended and ns.IsSuspended() and ns.Resume then
			ns.suspendQuiet = true
			ns.Resume()
			ns.suspendQuiet = nil
			resumed = true
		end
		return ("%d game settings put back%s%s"):format(back,
			waiting > 0 and (", " .. waiting .. " after the fight") or "", resumed and ", Cinematic resumed" or "")
	end,
	steps = {
		{ key = "events", title = "every event heard, the combat log, blocked?", blockedOk = true, seconds = 10,
			run = function(r)
				if InCombatLockdown() then
					r:WaitFor("Out of the fight, please (hands off till then)",
						{ events = { "PLAYER_REGEN_ENABLED" }, handsOff = true })
				end
				Pause(r)
				local blocked0 = BlockedCount()
				Core.readCombatLog = true
				Core.onCombatLog = function(n, info)
					local types = {}
					for i = 2, math.min(#info, 13) do
						local v = info[i]
						types[#types + 1] = (issecretvalue and issecretvalue(v)) and "secret" or type(v)
					end
					r:Log(("  combat log payload %d: call ok=%s, %d fields: %s"):format(n, tostring(info[1]),
						#info - 1, table.concat(types, ",")))
				end
				local ok, err = pcall(Core.Listen, "all")
				Core.Window("all events", 0)
				r:Sleep(8)
				local w = Core.Window(nil)
				local kinds = 0
				for _ in pairs(w.counts) do kinds = kinds + 1 end
				local blocked = BlockedCount() - blocked0
				r:Log(("simprobe events|all|call ok=%s %s|kinds %d|events %d|combat log %d (secret payloads %d)|blocked +%d|cost %.2f ms")
					:format(tostring(ok), err and tostring(err) or "", kinds, w.total, w.counts.COMBAT_LOG_EVENT_UNFILTERED or 0,
						w.combatLogSecret, blocked, w.cost))
				if ok and kinds > 0 and blocked == 0 then
					state.mode = "all"
					r:Pass("RegisterAllEvents: " .. kinds .. " kinds heard, no BLOCKED: way A for the rest")
				else
					state.mode = "list"
					Listen()
					r:Pass(("answered NO: RegisterAllEvents ok %s, %d kinds, blocked +%d: way B (%d names registered, %d unknown) for the rest")
						:format(tostring(ok), kinds, blocked, Core.registered or 0, Core.unknown or 0))
				end
				r:Verdict(type(CombatLogGetCurrentEventInfo) == "function",
					"CombatLogGetCurrentEventInfo is " .. type(CombatLogGetCurrentEventInfo))
				local top = {}
				for event, n in pairs(w.counts) do top[#top + 1] = { event, n } end
				table.sort(top, function(a, b) return a[2] > b[2] end)
				local parts = {}
				for i = 1, math.min(#top, 15) do parts[#parts + 1] = top[i][1] .. " " .. top[i][2] end
				r:Log("  most heard (8 s): " .. table.concat(parts, ", "))
			end },
		{ key = "settings", title = "every game settings set: there, takes, CVAR_UPDATE, put back", seconds = 15,
			run = function(r)
				if InCombatLockdown() then
					r:WaitFor("Out of the fight, please (hands off till then)",
						{ events = { "PLAYER_REGEN_ENABLED" }, handsOff = true })
				end
				Pause(r)
				Listen()
				local sets = ns.cvarSets or {}
				local took, missed, absent, total = 0, 0, 0, 0
				local groups = {}
				for _, set in ipairs(sets) do
					local group = DevOnly(set) and "dev" or GroupOf(set)
					groups[group] = (groups[group] or 0) + 1
					local parts = {}
					local cvars = {}
					for cvar in pairs(set.values or {}) do cvars[#cvars + 1] = cvar end
					table.sort(cvars)
					for _, cvar in ipairs(cvars) do
						total = total + 1
						local want = set.values[cvar]
						local was = Core.Read(cvar)
						if was == nil then
							absent = absent + 1
							parts[#parts + 1] = cvar .. " ABSENT"
						else
							r:Keep("cvar:" .. cvar, was)
							local at = GetTime()
							local _, err, back = Core.Write(cvar, want)
							r:Sleep(0.1)
							local updated = Core.CVarUpdatedSince(cvar, at)
							local ok = Core.Same(back, want)
							if ok then took = took + 1 else missed = missed + 1 end
							Core.Write(cvar, was)
							local backAgain = Core.Read(cvar)
							parts[#parts + 1] = ("%s %s->%s %s upd=%s back=%s%s"):format(cvar, tostring(was), tostring(want),
								ok and "took" or ("NO(" .. tostring(back) .. ")"), updated and "y" or "n",
								Core.Same(backAgain, was) and "y" or ("NO(" .. tostring(backAgain) .. ")"),
								err and (" err=" .. tostring(err)) or "")
						end
					end
					r:Log(("simprobe setting|%s|%s|%s|%s"):format(tostring(set.label), group,
						Secure(set) and "secure" or "-", table.concat(parts, "; ")))
				end
				local g = {}
				for group, n in pairs(groups) do g[#g + 1] = group .. " " .. n end
				table.sort(g)
				r:Log(("  %d sets (%s), %d settings: %d took, %d didn't, %d not on this client"):format(#sets,
					table.concat(g, ", "), total, took, missed, absent))
				r:Verdict(#sets > 0, #sets .. " sets found")
				r:Verdict(missed == 0, missed .. " settings didn't read back as written")
			end },
		{ key = "bulk", title = "the sets expected to change nothing sent: all on vs yours", seconds = 45,
			run = function(r)
				if InCombatLockdown() then
					r:WaitFor("Out of the fight, please (hands off till then)",
						{ events = { "PLAYER_REGEN_ENABLED" }, handsOff = true })
				end
				Pause(r)
				Listen()
				local values, labels, clash = {}, {}, {}
				for _, unit in ipairs(Units(r, "bulk")) do
					for _, label in ipairs(unit.sets) do labels[#labels + 1] = label end
					for cvar, value in pairs(unit.values) do
						if values[cvar] ~= nil and not Core.Same(values[cvar], value) then clash[#clash + 1] = cvar end
						if values[cvar] == nil then values[cvar] = value end
					end
				end
				r:Log("  bulk sets: " .. table.concat(labels, ", "))
				if #clash > 0 then r:Log("  two bulk sets want different values (the first kept): " .. table.concat(clash, ", ")) end
				r:Prompt("Hands off: switching the camera and cursor settings back and forth (about 40 s)", nil,
					ROUNDS * SECONDS * 2, nil, true)
				local result = ABTest(r, "bulk (" .. #labels .. " sets)", "bulk", values)
				r:Verdict(result.verdict ~= "unreliable", "bulk A/B " .. result.verdict)
			end },
		{ key = "city", title = "a busy city: each plate set A/B, then a minute with every send-more set on", run = function(r)
			local sets = Units(r, "plates")
			r:WaitFor("Go to a busy city (players and NPCs around), out of fights, then click Ready. "
				.. "Stand still there for about " .. math.ceil((Seconds(sets) + SIZE_SECONDS) / 60) .. " minutes.",
				{ buttons = { "Ready" } })
			Pause(r)
			Listen()
			r:Prompt("Hands off: stand still in the city while the plate settings switch back and forth", nil,
				Seconds(sets) + SIZE_SECONDS, nil, true)
			local more = {}
			for _, set in ipairs(sets) do
				local result = ABTest(r, set.label, "plates", set.values, { secure = set.secure })
				if result.verdict == "changes" and result.a > result.b then more[#more + 1] = set end
			end
			-- A minute with every set that sent more on (the first set's value where two want one setting).
			local values, labels = {}, {}
			for _, set in ipairs(more) do
				labels[#labels + 1] = set.label
				for cvar, value in pairs(set.values) do
					if values[cvar] == nil then values[cvar] = value end
				end
			end
			local names = Names(values)
			for _, cvar in ipairs(names) do r:Keep("cvar:" .. cvar, Core.Read(cvar)) end
			local base = {}
			for _, cvar in ipairs(names) do base[cvar] = Core.Read(cvar) end
			Apply(names, values)
			Core.ForgetSnapshots()
			Core.Snapshot()
			Core.Window("city minute", 0)
			local plates, platesMax, looks = 0, 0, 0
			local stop = GetTime() + SIZE_SECONDS
			while GetTime() < stop do
				r:Sleep(SNAPSHOT_EVERY)
				local _, units = Core.Snapshot()
				plates, platesMax, looks = plates + units, math.max(platesMax, units), looks + 1
			end
			local w = Core.Window(nil)
			Apply(names, base)
			local top = {}
			for event, n in pairs(w.counts) do top[#top + 1] = { event, n } end
			table.sort(top, function(a, b) return a[2] > b[2] end)
			local parts = {}
			for i = 1, math.min(#top, 15) do parts[#parts + 1] = ("%s %.1f/s"):format(top[i][1], top[i][2] / w.seconds) end
			r:Log(("simprobe size|city|%.0f s|events %.1f/s|%.0f KB a minute (events and snapshots)|recorder %.3f ms/s|plates avg %.1f max %d|send-more sets: %s")
				:format(w.seconds, w.total / w.seconds, w.bytes / w.seconds * 60 / 1024, w.cost / w.seconds,
					looks > 0 and plates / looks or 0, platesMax, #labels > 0 and table.concat(labels, ", ") or "none"))
			r:Log("  most heard: " .. table.concat(parts, ", "))
			r:Verdict(w.total > 0, "events heard in the city minute: " .. w.total)
		end },
		{ key = "soft", title = "quest objects and NPCs: the soft targeting sets A/B", run = function(r)
			local sets = Units(r, "soft")
			r:WaitFor("Stand by quest objects or NPCs you can talk to (a few around you), out of fights, then click "
				.. "Ready and walk slowly among them for about " .. math.ceil(Seconds(sets) / 60) .. " minutes.",
				{ buttons = { "Ready" } })
			Pause(r)
			Listen()
			r:Prompt("Walk slowly among the objects and NPCs (no fights): soft targeting switching back and forth", nil,
				Seconds(sets))
			for _, set in ipairs(sets) do
				ABTest(r, set.label, "soft", set.values, { secure = true })
			end
			r:Verdict(#sets > 0, #sets .. " soft targeting sets tested")
		end },
		{ key = "fight", title = "fights: secret reads, the fight sets A/B, the combat log", run = function(r)
			local sets = Units(r, "fight")
			local raid = SetsIn("raid")
			r:WaitFor("Find mobs to fight (a few, one after another, or a training dummy) and pull the first one. "
				.. "Keep fighting for about " .. math.ceil((Seconds(sets) + 20) / 60) .. " minutes.",
				{ events = { "PLAYER_REGEN_DISABLED" } })
			Pause(r)
			Listen()
			Core.readCombatLog = true
			SecretReads(r, 12)
			for _, set in ipairs(sets) do
				if set.secure then
					r:Log(("simprobe set|%s|fight|skipped|secure: can't switch in a fight"):format(set.label))
				else
					ABTest(r, set.label, "fight", set.values, { fight = true, before = function()
						if not Fighting() then
							r:WaitFor("Pull the next mob: the test goes on once you're in a fight",
								{ events = { "PLAYER_REGEN_DISABLED" } })
						end
					end })
				end
			end
			for _, set in ipairs(raid) do
				r:Log(("simprobe set|%s|raid|skipped|raid frames: needs a raid"):format(tostring(set.label)))
			end
			-- The fight's events: which carry secret arguments, the combat log.
			Core.Window("fight events", 0)
			for _ = 1, 20 do
				if not Fighting() then
					r:WaitFor("Pull one more mob: the last look at the fight's events",
						{ events = { "PLAYER_REGEN_DISABLED" } })
				end
				r:Sleep(0.5)
			end
			local w = Core.Window(nil)
			local secret = {}
			for event, n in pairs(w.secretArgs) do secret[#secret + 1] = ("%s %d/%d"):format(event, n, w.counts[event] or n) end
			table.sort(secret)
			r:Log(("simprobe secretargs|%s"):format(#secret > 0 and table.concat(secret, ", ") or "none"))
			r:Log(("simprobe combatlog|heard %d|read %d|secret payloads %d|mode %s"):format(
				w.counts.COMBAT_LOG_EVENT_UNFILTERED or 0, w.combatLog, w.combatLogSecret, Mode()))
			r:Verdict(w.total > 0, "events in the fight: " .. w.total)
		end },
	},
})
