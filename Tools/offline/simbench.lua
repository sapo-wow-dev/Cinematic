-- The replay bench (Tools/sim/bench.lua) checked (Lua 5.1, or Tools/offline/run.py):
--   lua5.1 Tools/offline/simbench.lua
-- Its game behaviours one by one (each from an engine rule where one says:
-- OnUpdate only up a shown chain, the combat log forbidden by name on
-- Forever, SoftTarget settings blocked in a fight, secrets erroring on
-- arithmetic; timers; unit-filtered events), then Cinematic through the
-- synthetic scenarios in real profiles: no errors, no safety stop, every loop
-- named by who set it, CineMode as the profile says in a fight, and the same
-- report twice (counts, not chance). PASS or FAIL per check.
-- luacheck: push ignore 111 112 113 121 122 212 431
local Bench = dofile("Tools/sim/bench.lua")
local Synthetic = dofile("Tools/sim/synthetic.lua")
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end
local function Blocked(bench, word)
	for key, n in pairs(bench.count.blocked) do
		if key:find(word, 1, true) then return n end
	end
	return 0
end

-- The engine, piece by piece (a bench with nothing played: counting on).
for _, client in ipairs({ "forever", "retail" }) do
	print("== engine, " .. client)
	local bench = Bench.New({ client = client, fps = 10 })
	bench.counting = true
	local rules = 0
	for _ in pairs(bench.data.rules) do rules = rules + 1 end
	Check("engine rules read", rules > 300, rules)
	-- OnUpdate: shown under a hidden parent none, hidden none, shown and no parent yes.
	local parent = CreateFrame("Frame", nil, UIParent)
	parent:Hide()
	local ran = { under = 0, self = 0, shown = 0, orphan = 0 }
	local frames = { under = CreateFrame("Frame", nil, parent), self = CreateFrame("Frame", nil, UIParent),
		shown = CreateFrame("Frame", nil, UIParent), orphan = CreateFrame("Frame") }
	frames.self:Hide()
	for key, f in pairs(frames) do f:SetScript("OnUpdate", function() ran[key] = ran[key] + 1 end) end
	for _ = 1, 5 do bench:Step(0.1) end
	Check("OnUpdate only up a shown chain (rule all.frame.onupdate-visible-only)",
		ran.under == 0 and ran.self == 0 and ran.shown == 5 and ran.orphan == 5,
		("%d %d %d %d"):format(ran.under, ran.self, ran.shown, ran.orphan))
	for _, f in pairs(frames) do f:SetScript("OnUpdate", nil) end
	-- Timers: After(0) next step, a ticker repeating, a cancelled one never.
	local fired = { after = 0, ticker = 0, cancelled = 0 }
	C_Timer.After(0, function() fired.after = fired.after + 1 end)
	local ticker = C_Timer.NewTicker(0.1, function() fired.ticker = fired.ticker + 1 end)
	local gone = C_Timer.NewTimer(0.1, function() fired.cancelled = fired.cancelled + 1 end)
	gone:Cancel()
	for _ = 1, 3 do bench:Step(0.1) end
	ticker:Cancel()
	for _ = 1, 3 do bench:Step(0.1) end
	Check("timers: After(0) once, a ticker each step till cancelled, a cancelled one never",
		fired.after == 1 and fired.ticker == 3 and fired.cancelled == 0,
		("%d %d %d"):format(fired.after, fired.ticker, fired.cancelled))
	-- Unit-filtered events.
	local got = {}
	local f = CreateFrame("Frame")
	f:RegisterUnitEvent("UNIT_HEALTH", "target")
	f:SetScript("OnEvent", function(_, _, unit) got[#got + 1] = unit end)
	bench:Fire("UNIT_HEALTH", "player")
	bench:Fire("UNIT_HEALTH", "target")
	Check("RegisterUnitEvent: only its unit", #got == 1 and got[1] == "target", table.concat(got, ","))
	f:UnregisterAllEvents()
	bench:Fire("UNIT_HEALTH", "target")
	Check("UnregisterAllEvents: none after", #got == 1, #got)
	local all = CreateFrame("Frame")
	local heard = 0
	all:RegisterAllEvents()
	all:SetScript("OnEvent", function() heard = heard + 1 end)
	bench:Fire("SOME_EVENT")
	Check("RegisterAllEvents hears any event", heard == 1, heard)
	all:UnregisterAllEvents()
	-- The combat log by name: forbidden on Forever (rule), not retail's.
	local log = CreateFrame("Frame")
	log:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	local blocked = Blocked(bench, "forever.combatlog.cleu-forbidden")
	Check("combat log by name: " .. (client == "forever" and "blocked (rule forever.combatlog.cleu-forbidden)" or "allowed"),
		(blocked == 1) == (client == "forever") and log:IsEventRegistered("COMBAT_LOG_EVENT_UNFILTERED") == (client ~= "forever"),
		blocked)
	-- SoftTarget settings in a fight: blocked on both (rule forever.softtarget.cvars-protected-combat).
	bench.state.player.combat = true
	SetCVar("SoftTargetInteract", "3")
	bench.state.player.combat = false
	Check("SoftTarget setting in a fight blocked, not written", Blocked(bench, "softtarget") == 1
		and GetCVar("SoftTargetInteract") ~= "3", Blocked(bench, "softtarget"))
	SetCVar("SoftTargetInteract", "3")
	Check("out of the fight it's written", GetCVar("SoftTargetInteract") == "3")
	-- Secrets: arithmetic and joining error, as in the game.
	local S = Bench.SECRET
	Check("a secret errors on arithmetic", not pcall(function() return S + 1 end))
	Check("a secret errors on joining", not pcall(function() return "x" .. S end))
	Check("issecretvalue there (clients with secret values)", issecretvalue ~= nil and issecretvalue(S) == true)
	-- The world from snapshots: "?" reads as a secret.
	bench:Apply({ 0, "s", "target", "exists", true })
	bench:Apply({ 0, "s", "target", "hp", "?" })
	Check("a snapshot's ? reads as a secret", issecretvalue(UnitHealth("target")) == true)
	-- A nameplate: its frame made before the event, gone after.
	bench:Apply({ 0, "e", "NAME_PLATE_UNIT_ADDED", "nameplate3" })
	local plate = C_NamePlate.GetNamePlateForUnit("nameplate3")
	Check("a plate's frame for its unit", plate ~= nil and UnitExists("nameplate3") and plate.UnitFrame ~= nil)
	bench:Apply({ 0, "e", "NAME_PLATE_UNIT_REMOVED", "nameplate3" })
	Check("a plate gone", C_NamePlate.GetNamePlateForUnit("nameplate3") == nil and not UnitExists("nameplate3"))
	Check("the report says what game data is missing", bench:Report():find("console settings: ", 1, true) ~= nil)
end

-- Cinematic through the scenarios.
local function Play(client, profile, scenario)
	local bench = Bench.New({ client = client, fps = 30 })
	bench:Play(scenario, { profile = profile })
	return bench
end
local function NoErrors(bench)
	local list = {}
	for e, n in pairs(bench.count.errors) do list[#list + 1] = n .. "x " .. e end
	for r in pairs(bench.count.stops) do list[#list + 1] = "STOP " .. r end
	return #list == 0, table.concat(list, "; ")
end
for _, client in ipairs({ "forever", "retail" }) do
	for _, profile in ipairs({ "Balanced", "Cinema", "Subtle" }) do
		print("== " .. client .. ", " .. profile)
		local idle = Play(client, profile, Synthetic.idle({ length = 6 }))
		Check("idle: no errors, no safety stop", NoErrors(idle))
		Check("idle: the update tick runs (Core.lua's OnUpdate)", (function()
			for name in pairs(idle.count.onupdate) do if name:find("Core.lua:4017", 1, true) then return true end end
		end)() == true)
		local unnamed = 0
		for name in pairs(idle.count.onupdate) do if name:find("made at ?", 1, true) then unnamed = unnamed + 1 end end
		Check("idle: every loop named by who set it", unnamed == 0, unnamed)
		local city = Play(client, profile, Synthetic.city({ length = 8, plates = 12 }))
		Check("city: no errors, no safety stop", NoErrors(city))
		Check("city: plate events reached handlers", (city.count.events.NAME_PLATE_UNIT_ADDED or 0) > 0 and (function()
			for name in pairs(city.count.handlers) do if name:find("<- NAME_PLATE_UNIT_ADDED", 1, true) then return true end end
		end)() == true)
		Check("city: chat lines in the chat window", #city.chatFrames[1]._lines > 0, #city.chatFrames[1]._lines)
		local fight = Play(client, profile, Synthetic.fight({ length = 10 }))
		Check("fight: no errors, no safety stop", NoErrors(fight))
		local stays = fight.ns.StaysInCombat()
		local share = fight.count.cineFrames / fight.count.frames
		if profile ~= "Subtle" then
			Check("fight: CineMode kept through it (the profile stays in fights)", stays and share == 1, share)
		else
			Check("fight: CineMode not on through it (Subtle: triggers only)", not stays and share < 1, share)
		end
	end
end

-- The same input, the same report.
print("== determinism")
local a = Play("forever", "Cinema", Synthetic.city({ length = 6 })):Report()
local b = Play("forever", "Cinema", Synthetic.city({ length = 6 })):Report()
Check("the same scenario twice: the same report", a == b)

print(fails == 0 and "all passed" or (fails .. " failed"))
if fails > 0 then os.exit(1) end
-- luacheck: pop
