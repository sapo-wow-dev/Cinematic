-- /cine debug selftextall: every kind of combat text message about you the
-- game can show (Tools/self-combat-text-plan.md, 2026-11-20), collected
-- while you play. The first probe (/cine debug selftext) saw only DAMAGE,
-- SPELL_MISS and ENERGIZE; the page needs every kind, its look and what
-- comes with it. While it runs:
--   - every "Text on Me" setting of the game's is on (put back at the end),
--     so no kind is held back; CineMode off
--   - each COMBAT_TEXT_UPDATE: its kind, what GetCurrentEventInfo gives
--     (each value plain / secret, and its type), the UNIT_COMBAT on you in
--     the same instant (action, flag), and the color the game drew it in
--   - a message the game draws with no event (Low Health, Low Mana): caught
--     by its color with no event, logged as "no event"
--   - the first of each kind: a screenshot
--   - a kind not on the list: logged as NEW, screenshot too
-- The big box keeps the count and what to try next for the kinds still
-- missing. Kept across runs (CinematicDB.selfTextCatalog: run it on more
-- characters and classes and it adds up). Typed again: stops, writes the
-- summary (seen, missing, new), DONE box. Log: CinematicDB.selfTextAllLog.
-- Dev copy only.
local _, ns = ...

-- The kinds, by group, with what to do to get them.
local GROUPS = {
	{ "Hits on you", "let a mob hit you", { "DAMAGE", "DAMAGE_CRIT", "SPLIT_DAMAGE" } },
	{ "Spells on you", "fight a caster; get a damage-over-time on you",
		{ "SPELL_DAMAGE", "SPELL_DAMAGE_CRIT", "PERIODIC_DAMAGE", "DAMAGE_SHIELD" } },
	{ "Missed you", "fight in melee (dodge, parry, block...)",
		{ "MISS", "DODGE", "PARRY", "BLOCK", "DEFLECT", "EVADE", "IMMUNE", "REFLECT", "RESIST", "ABSORB" } },
	{ "Spells missed you", "fight a caster (resists, absorbs...)",
		{ "SPELL_MISS", "SPELL_DODGE", "SPELL_PARRY", "SPELL_BLOCK", "SPELL_DEFLECT", "SPELL_EVADE", "SPELL_IMMUNE",
			"SPELL_REFLECT", "SPELL_RESIST", "SPELL_ABSORB", "PROC_RESISTED" } },
	{ "Heals", "heal yourself, a heal over time, a potion, food",
		{ "HEAL", "HEAL_CRIT", "PERIODIC_HEAL", "PERIODIC_HEAL_CRIT" } },
	{ "Shields", "a shield on you (Power Word: Shield, Ice Barrier...)",
		{ "ABSORB_ADDED", "HEAL_ABSORB", "HEAL_CRIT_ABSORB", "PERIODIC_HEAL_ABSORB" } },
	{ "Power", "gain mana/rage/energy, combo points",
		{ "ENERGIZE", "PERIODIC_ENERGIZE", "COMBO_POINTS", "RUNE" } },
	{ "Auras", "gain a buff, let it end; get a debuff",
		{ "SPELL_AURA_START", "SPELL_AURA_END", "SPELL_AURA_START_HARMFUL", "SPELL_AURA_END_HARMFUL" } },
	{ "Alerts", "a proc or reactive skill (Overpower, Revenge...)", { "SPELL_ACTIVE", "SPELL_CAST" } },
	{ "Combat", "start and end a fight", { "ENTERING_COMBAT", "LEAVING_COMBAT" } },
	{ "Rewards", "kill for reputation or honor", { "FACTION", "HONOR_GAINED" } },
	{ "Low", "drop under ~20% health or mana", { "no event" } },
}
local KNOWN = {}
for _, group in ipairs(GROUPS) do for _, kind in ipairs(group[3]) do KNOWN[kind] = group end end

-- The game's "Text on Me" settings (and the rest of its self text ones),
-- on for the run.
local CVARS = { "enableFloatingCombatText", "floatingCombatTextAuras_v2", "floatingCombatTextAuraFade_v2",
	"floatingCombatTextCombatState_v2", "floatingCombatTextComboPoints_v2", "floatingCombatTextDamageReduction_v2",
	"floatingCombatTextDodgeParryMiss_v2", "floatingCombatTextEnergyGains_v2", "floatingCombatTextFriendlyHealers_v2",
	"floatingCombatTextHonorGains_v2", "floatingCombatTextLowManaHealth_v2", "floatingCombatTextPeriodicEnergyGains_v2",
	"floatingCombatTextReactives_v2", "floatingCombatTextRepChanges_v2", "floatingCombatTextSpellMechanics_v2",
	"floatingCombatTextSpellMechanicsOther_v2", "floatingCombatTextCombatHealingAbsorbSelf_v2" }

local SAME = 0.05     -- seconds: an event, a hit and a color this close are one message
local SETTLE = 0.25   -- seconds before a color with no event counts as "no event"
local KEEP = 3        -- messages logged in full per kind

local run
local hooked = {}

local function Secret(v) return issecretvalue and issecretvalue(v) end
local function Say(text)
	local log = CinematicDB and CinematicDB.selfTextAllLog
	if log then log[#log + 1] = ("%s %.1f %s"):format(date("%H:%M:%S"), run and GetTime() - run.at or 0, text) end
end
local function T(v)
	if Secret(v) then return "secret" end
	if type(v) == "number" then return ("%.2f"):format(v) end
	return tostring(v)
end
-- One value's shape: "nil", "secret number", "plain string 'x'".
local function Shape(v)
	if v == nil then return "nil" end
	local ok, kind = pcall(type, v)
	kind = ok and kind or "?"
	if Secret(v) then return "secret " .. kind end
	return ("plain %s %s"):format(kind, T(v))
end
local function Catalog()
	CinematicDB.selfTextCatalog = CinematicDB.selfTextCatalog or {}
	return CinematicDB.selfTextCatalog
end
local function Seen(kind) return Catalog()[kind] ~= nil end
local function Counts()
	local seen, all = 0, 0
	for kind in pairs(KNOWN) do
		all = all + 1
		if Seen(kind) then seen = seen + 1 end
	end
	return seen, all
end
local function Shot(what)
	local ok = pcall(function() Screenshot() end)
	Say(("screenshot %s at %s%s"):format(what, date("%m%d%y_%H%M%S"), ok and "" or " (failed)"))
end

-- Groups with at least one kind seen: done (the rest of a group takes its
-- look, 2026-11-20, user: categories, not every kind). The box asks only for
-- groups with none, so nothing already had is asked for again.
local function GroupsDone()
	local done, open = 0, {}
	for _, group in ipairs(GROUPS) do
		local any = false
		for _, kind in ipairs(group[3]) do if Seen(kind) then any = true break end end
		if any then done = done + 1 else open[#open + 1] = group end
	end
	return done, open
end

local function ShowBox()
	if not run then return end
	local seen, all = Counts()
	local done, open = GroupsDone()
	local new = run.newCount > 0 and (" (+%d new kinds)"):format(run.newCount) or ""
	local names = {}
	for i = 2, #open do names[#names + 1] = open[i][1] end
	ns.PadTestBox(("Combat text catalog: %d of %d groups (%d of %d kinds%s).\nPlay as normal; every message is recorded.\nTry next: %s")
		:format(done, #GROUPS, seen, all, new, open[1] and ("%s: %s"):format(open[1][1], open[1][2])
			or "every group seen! Rare kinds still count."),
		("still none: %s\n/cine debug selftextall again to finish"):format(#names > 0 and table.concat(names, ", ") or "-"),
		0.3, 1, 0.3)
end

-- The first probe's kinds (/cine debug selftext, its log), into the catalog
-- once: kind and info shape (no color or hit was matched there).
local function FromFirstProbe()
	local catalog, added = Catalog(), {}
	for _, line in ipairs(CinematicDB.selfTextLog or {}) do
		local kind, shape = line:match("COMBAT_TEXT_UPDATE (%S+) | info (.*)$")
		if kind and not catalog[kind] then
			-- (Its shape as this one writes it: "secret" values, trailing nils off.)
			shape = shape:gsub("secret", "secret ?")
			local cut
			repeat shape, cut = shape:gsub(", nil$", "") until cut == 0
			catalog[kind] = { count = 1, shapes = { [shape] = true }, colors = {}, actions = {}, from = "selftext" }
			added[#added + 1] = kind
		end
	end
	return added
end

-- A message: an event's kind (or "no event"), what came with it.
local function Record(kind, message)
	local catalog = Catalog()
	local entry = catalog[kind]
	local first = entry == nil
	if first then
		entry = { count = 0, shapes = {}, colors = {}, actions = {} }
		catalog[kind] = entry
	end
	entry.count = entry.count + 1
	entry.shapes[message.shape or "-"] = true
	if message.color then entry.colors[message.color] = true end
	if message.action then entry.actions[message.action] = true end
	entry.drawn = entry.drawn or { yes = 0, no = 0 }
	local drawnKey = message.drawn and "yes" or "no"
	entry.drawn[drawnKey] = entry.drawn[drawnKey] + 1
	entry.withs = entry.withs or {}
	if message.with then entry.withs[message.with] = true end
	if not KNOWN[kind] and first then
		run.newCount = run.newCount + 1
		Say("NEW kind: " .. kind)
	end
	local seenRun = (run.counts[kind] or 0) + 1
	run.counts[kind] = seenRun
	if seenRun <= KEEP then
		Say(("%s #%d: info %s | drawn %s, color %s | your hit %s | with %s | in combat %s"):format(kind, entry.count,
			message.shape or "-", message.drawn and "yes" or "NO", message.color or "-", message.action or "none",
			message.with or "nothing", tostring(InCombatLockdown())))
	end
	if first and not run.ending then
		local name = kind
		C_Timer.After(0.3, function() if run then Shot("first " .. name) end end)
	end
	ShowBox()
end

-- A drawn text's color, read once it settled (plain on Forever, run 1).
local function ColorOf(region)
	local ok, r, g, b = pcall(region.GetTextColor, region)
	if not ok then return "error" end
	if Secret(r) or Secret(g) or Secret(b) then return "secret" end
	return ("%.2f %.2f %.2f"):format(tonumber(r) or -1, tonumber(g) or -1, tonumber(b) or -1)
end
-- What else happened in that instant (your power's type, your health, a
-- fight starting or ending): tells combo points from mana, Low Health from
-- Low Mana, +Combat from -Combat.
local function With(at)
	local seen, list = {}, {}
	for _, ctx in ipairs(run.ctx) do
		if math.abs(ctx.at - at) <= SAME and not seen[ctx.text] then
			seen[ctx.text] = true
			list[#list + 1] = ctx.text
		end
	end
	table.sort(list)
	return #list > 0 and table.concat(list, " + ") or nil
end

-- Messages waiting a moment for their drawn text and hit to come in.
-- all: settle everything now (the run ending).
local function Match(all)
	if not run then return end
	local now = GetTime()
	local function Settled(at) return all or now - at >= SETTLE end
	-- (Each drawn text to the event of the same instant; one with none, settled: "no event".)
	for i = #run.drawn, 1, -1 do
		local drawn = run.drawn[i]
		local owner
		for _, message in ipairs(run.pending) do
			if not message.drawn and math.abs(message.at - drawn.at) <= SAME then owner = message break end
		end
		if owner then
			owner.drawn, owner.region = true, drawn.region
			table.remove(run.drawn, i)
		elseif Settled(drawn.at) then
			table.remove(run.drawn, i)
			Record("no event", { shape = "-", drawn = true, color = ColorOf(drawn.region), with = With(drawn.at) })
		end
	end
	for i = #run.hits, 1, -1 do
		local hit = run.hits[i]
		for _, message in ipairs(run.pending) do
			if not message.action and math.abs(message.at - hit.at) <= SAME then
				message.action = hit.text
				table.remove(run.hits, i)
				break
			end
		end
		if run.hits[i] == hit and Settled(hit.at) then table.remove(run.hits, i) end
	end
	for i = #run.pending, 1, -1 do
		local message = run.pending[i]
		if Settled(message.at) then
			table.remove(run.pending, i)
			if message.region then message.color = ColorOf(message.region) end
			message.with = With(message.at)
			Record(message.kind, message)
		end
	end
	-- (Old context gone.)
	for i = #run.ctx, 1, -1 do
		if now - run.ctx[i].at > 1 then table.remove(run.ctx, i) end
	end
end

local function HookTexts()
	local frame = _G.CombatText
	if type(frame) ~= "table" or not frame.GetRegions then return end
	for _, region in ipairs({ frame:GetRegions() }) do
		if region.GetObjectType and region:GetObjectType() == "FontString" and not hooked[region] then
			hooked[region] = true
			-- (Every message the game draws gets its text set, whatever its
			-- color: drawn or not. Its color is read once settled.)
			hooksecurefunc(region, "SetText", function(self)
				if run then run.drawn[#run.drawn + 1] = { at = GetTime(), region = self } end
			end)
		end
	end
end

local CONTEXT = { PLAYER_REGEN_DISABLED = "fight start", PLAYER_REGEN_ENABLED = "fight end", UNIT_HEALTH = "health" }
local watcher = CreateFrame("Frame")
watcher:SetScript("OnEvent", function(_, event, ...)
	if not run then return end
	if event == "COMBAT_TEXT_UPDATE" then
		local kind = ...
		kind = Secret(kind) and "secret kind" or tostring(kind)
		local values = { pcall(C_CombatText.GetCurrentEventInfo) }
		local shape
		if values[1] then
			local parts = {}
			for i = 2, 7 do parts[#parts + 1] = Shape(values[i]) end
			-- (Trailing nils trimmed.)
			while #parts > 1 and parts[#parts] == "nil" do parts[#parts] = nil end
			shape = table.concat(parts, ", ")
		else
			shape = "error " .. T(values[2])
		end
		run.pending[#run.pending + 1] = { at = GetTime(), kind = kind, shape = shape }
		HookTexts()
	elseif event == "UNIT_COMBAT" then
		local _, action, flag = ...
		run.hits[#run.hits + 1] = { at = GetTime(), text = ("%s %s"):format(T(action), T(flag)) }
	elseif event == "UNIT_POWER_UPDATE" then
		local _, power = ...
		run.ctx[#run.ctx + 1] = { at = GetTime(), text = "power " .. T(power) }
	else
		run.ctx[#run.ctx + 1] = { at = GetTime(), text = CONTEXT[event] or event }
	end
end)

-- What a run changed is saved as it starts, so a /reload, a logout or a
-- crash mid-run still gets it all put back (the first catalog run was
-- ended by a /reload and left the game's Text on Me settings on, 2026-11-20).
local function PutBack(kept)
	for name, value in pairs(kept.cvars or {}) do pcall(SetCVar, name, value) end
	if kept.cine and ns.IsCineModeOn and not ns.IsCineModeOn() and Cinematic_ToggleCineMode then
		Cinematic_ToggleCineMode()
	end
	CinematicDB.selfTextAllKept = nil
end

local function Summary()
	local catalog = Catalog()
	local function List(set)
		local list = {}
		for key in pairs(set or {}) do list[#list + 1] = key end
		table.sort(list)
		return #list > 0 and table.concat(list, " / ") or "none"
	end
	Say("=== summary (all runs) ===")
	for _, group in ipairs(GROUPS) do
		local have, lack = {}, {}
		for _, kind in ipairs(group[3]) do
			local entry = catalog[kind]
			if entry then
				local drawn = entry.drawn and ("%d yes %d no"):format(entry.drawn.yes, entry.drawn.no) or "?"
				have[#have + 1] = ("%s x%d [info %s | drawn %s | color %s | hit %s | with %s]"):format(kind, entry.count,
					List(entry.shapes), drawn, List(entry.colors), List(entry.actions), List(entry.withs))
			else
				lack[#lack + 1] = kind
			end
		end
		Say(("%s %s: missing %s"):format(#have > 0 and "[done]" or "[NONE]", group[1],
			#lack > 0 and table.concat(lack, ", ") or "none"))
		for _, line in ipairs(have) do Say("  " .. line) end
	end
	for kind, entry in pairs(catalog) do
		if not KNOWN[kind] then Say(("NEW %s x%d"):format(kind, entry.count)) end
	end
	local seen, all = Counts()
	Say(("seen %d of %d groups, %d of %d known kinds"):format((GroupsDone()), #GROUPS, seen, all))
	return seen, all
end

-- quiet: ended by a /reload or logout (no box, no timers).
local function Finish(quiet)
	run.ending = true
	Match(true)
	PutBack(CinematicDB.selfTextAllKept or {})
	if run.ticker then run.ticker:Cancel() end
	watcher:UnregisterAllEvents()
	if quiet then Say("ended by a /reload or logout: settings put back") end
	local seen, all = Summary()
	Say("done")
	run = nil
	if quiet then return end
	ns.PadTestBox(("Combat text catalog done: %d of %d kinds seen.\n/reload, then say \"check log\"."):format(seen, all),
		"", 1, 0.82, 0)
	C_Timer.After(15, function() if not run then ns.PadTestBoxHide() end end)
end

local ender = CreateFrame("Frame")
ender:RegisterEvent("PLAYER_LOGOUT")
ender:RegisterEvent("PLAYER_LOGIN")
ender:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGOUT" then
		if run then pcall(Finish, true) end
		return
	end
	if not CinematicDB then return end
	local log = CinematicDB.selfTextAllLog
	-- (A run that never finished, a crash: its saved changes put back.)
	if CinematicDB.selfTextAllKept then
		PutBack(CinematicDB.selfTextAllKept)
		if type(log) == "table" then log[#log + 1] = date("%H:%M:%S") .. " unfinished run: settings put back at login" end
		return
	end
	-- (The first run, before they were saved: ended by a /reload with its
	-- Text on Me settings left on. Every one it turned on was 0 before: the
	-- first probe's survey, 2026-11-20.)
	if type(log) == "table" and #log > 0 and not tostring(log[#log]):find("done", 1, true)
		and not tostring(log[#log]):find("put back", 1, true) then
		for _, line in ipairs(log) do
			local list = line:match("turned on for the run: (.+)$")
			if list and list ~= "none" then
				for name in list:gmatch("%S+") do pcall(SetCVar, name, "0") end
				log[#log + 1] = date("%H:%M:%S") .. " unfinished first run: put back to 0: " .. list
				return
			end
		end
	end
end)

function ns.SelfTextCatalog()
	if run then
		Finish()
		return
	end
	ns.debugNoCopyWindow = true
	CinematicDB.selfTextAllLog = {}
	run = { at = GetTime(), pending = {}, drawn = {}, hits = {}, ctx = {}, counts = {}, newCount = 0 }
	local kept = { cvars = {}, cine = ns.IsCineModeOn and ns.IsCineModeOn() or false }
	if kept.cine and Cinematic_ToggleCineMode then Cinematic_ToggleCineMode() end
	local added = FromFirstProbe()
	local seen, all = Counts()
	local done = GroupsDone()
	if #added > 0 then Say("from the first probe's log: " .. table.concat(added, " ")) end
	Say(("groups seen before %d of %d"):format(done, #GROUPS))
	Say(("start: %s (game %s), class %s, level %s, kinds seen before %d of %d"):format(
		ns.isRetail and "retail" or "Forever", tostring((select(4, GetBuildInfo()))), tostring(select(2, UnitClass("player"))),
		tostring(UnitLevel("player")), seen, all))
	local turned = {}
	for _, name in ipairs(CVARS) do
		local ok, value = pcall(GetCVar, name)
		if ok and value ~= nil and value ~= "1" then
			kept.cvars[name] = value
			pcall(SetCVar, name, "1")
			turned[#turned + 1] = name
		end
	end
	CinematicDB.selfTextAllKept = kept
	Say("turned on for the run: " .. (#turned > 0 and table.concat(turned, " ") or "none"))
	HookTexts()
	watcher:RegisterEvent("COMBAT_TEXT_UPDATE")
	watcher:RegisterUnitEvent("UNIT_COMBAT", "player")
	watcher:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
	watcher:RegisterUnitEvent("UNIT_HEALTH", "player")
	watcher:RegisterEvent("PLAYER_REGEN_DISABLED")
	watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
	run.ticker = C_Timer.NewTicker(0.1, function()
		local ok, err = pcall(Match)
		if not ok and run then Say("error: " .. tostring(err)) end
	end)
	ShowBox()
end
