-- No other addon's support runs while that addon isn't loaded (offline, Lua
-- 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/noaddons.lua <forever|retail> [--all]
-- The addon loads with no other addon in (their globals all missing), then
-- every update loop, timer and event it set up runs for a while in pretend
-- time, with stand-in nameplates. Counted: each call into a function from a
-- Support/*.lua file, and each call to a function named after a supported
-- addon (FindQuestieIcon, ns.EQoLMark...) elsewhere. Any one is a leak: its
-- caller has to ask first whether the addon is in (ns.AddonUp). The few
-- functions that are the asking itself are listed in GATES.
-- Then each supported addon "loads" late (after Cinematic, after login, as a
-- load-on-demand addon or one later in the alphabet does): ns.AddonUp must
-- say so at once, and its support's setups must run.
-- --all: every leaking call with its caller, not just the first per function.
-- PASS or FAIL lines; exit 1 on a FAIL.
-- luacheck: push ignore 111 112 113 121 122 143
local client = arg and arg[1] or "forever"
local showAll = false
local SECONDS = tonumber(os.getenv("NOADDONS_SECONDS") or "") or 3
for _, a in ipairs(arg or {}) do if a == "--all" then showAll = true end end
package.path = "Tools/offline/?.lua;" .. package.path
local wow = dofile("Tools/offline/wow.lua")
wow.Install(client)

-- The supported addons: Support's file names, plus folder names and the
-- globals their code goes by (read below from what Support registers too).
local ADDON_WORDS = {
	"Questie", "EQoL", "EnhanceQoL", "Ellesmere", "ElvUI", "TRP3", "TotalRP", "Plater", "Platynator",
	"ThreatPlates", "TidyPlates", "Daylight", "Chattynator", "Glass", "Bartender", "Details", "WeakAuras",
	"DBM", "BigWigs", "RestedXP", "MSBT", "MikSBT", "Prat", "Leatrix", "HealBot", "TitanPanel", "TomTom",
	"ShamanPower", "DynamicCam", "RareScanner", "Immersion", "DialogueUI", "Spoken", "LoreForever", "FlareUI",
	"HorizonSuite", "NaowhForever", "ClassicUI", "FramesForever", "BattleText", "MinimapButtonButton", "MBB",
	"CooldownManagerCentered", "ECM", "HereBeDragons",
}
for line in io.lines("Cinematic.toc") do
	local name = line:match("^Support[\\/](.-)%.lua")
	if name then ADDON_WORDS[#ADDON_WORDS + 1] = name end
end
-- (Addon names that are plain words too: a function of ours named Details or
-- Glass isn't that addon's. Those count only by their Support file.)
local PLAIN_WORDS = { Details = true, Glass = true, Spoken = true, Immersion = true, Prat = true }
local wordOf = {} -- [name] = its addon word, or false (asked millions of times)
local function AddonWord(name)
	if type(name) ~= "string" then return nil end
	local known = wordOf[name]
	if known ~= nil then return known or nil end
	known = false
	for _, word in ipairs(ADDON_WORDS) do
		if not PLAIN_WORDS[word] and name:find(word, 1, true) then known = word break end
	end
	wordOf[name] = known
	return known or nil
end

-- No addon's globals: the stand-in hands every CamelCase name back as a stub,
-- which would count as that addon being in (_G.QuestieLoader, _G.ElvUI...).
local globalMeta = getmetatable(_G)
local baseIndex = globalMeta.__index
local addonGlobalReads = {} -- [name] = reads, while driving
local counting = false
globalMeta.__index = function(t, key)
	if AddonWord(key) or (type(key) == "string" and PLAIN_WORDS[key:match("^%u%l+")]) then
		if counting then addonGlobalReads[key] = (addonGlobalReads[key] or 0) + 1 end
		return nil
	end
	return baseIndex(t, key)
end

-- Pretend time and timers that run.
local now = 1000
local timers = {}
GetTime = function() return now end
GetTimePreciseSec = GetTime
debugprofilestop = function() return now * 1000 end
local function Ticker(delay, fn, times)
	local t = { at = now + (delay or 0), fn = fn, every = delay, times = times }
	function t.Cancel() t.cancelled = true end
	function t.IsCancelled() return t.cancelled end
	timers[#timers + 1] = t
	return t
end
C_Timer = {
	After = function(delay, fn) Ticker(delay, fn, 1) end,
	NewTimer = function(delay, fn) return Ticker(delay, fn, 1) end,
	NewTicker = function(delay, fn, times) return Ticker(delay, fn, times or math.huge) end,
}
InCombatLockdown = function() return false end
IsLoggedIn = function() return true end
-- (A stub frame has no parent: a walk up the parents ends, as in the game.)
rawset(wow.Stub, "GetParent", function() return nil end)
GetUnitSpeed = function() return 0, 7, 7, 4.7 end
-- (A stub answer counts as yes: standing in the open world instead.)
for _, name in ipairs({ "UnitOnTaxi", "IsMounted", "IsFlying", "IsSwimming", "IsFalling", "IsResting",
	"UnitAffectingCombat", "UnitIsDeadOrGhost", "UnitInVehicle", "IsStealthed", "IsIndoors", "UnitIsAFK",
	"IsInCinematicScene", "InCinematic", "UnitIsGhost", "UnitIsDead", "IsPlayerMoving", "SpellIsTargeting" }) do
	_G[name] = function() return false end
end
for _, name in ipairs({ "UnitCastingInfo", "UnitChannelInfo", "GetCursorInfo" }) do
	_G[name] = function() return nil end
end

-- Stand-in nameplates, each with the game's unit frame.
local plates, plateOf = {}, {}
for i = 1, 8 do
	local plate = wow.CreateFrame("Frame", "NamePlate" .. i, WorldFrame)
	plate.UnitFrame = wow.CreateFrame("Button", nil, plate)
	plate.UnitFrame.name = plate.UnitFrame:CreateFontString()
	plate.namePlateUnitToken = "nameplate" .. i
	plates[i] = plate
	plateOf["nameplate" .. i] = plate
end
C_NamePlate = {
	GetNamePlates = function() return plates end,
	GetNamePlateForUnit = function(unit) return plateOf[unit] end,
}
UnitExists = function(unit) return plateOf[unit] ~= nil or unit == "player" end
UnitIsUnit = function(a, b) return a == b end
UnitCanAttack = function(_, unit) return unit == "nameplate1" or unit == "nameplate2" end
UnitIsPlayer = function(unit) return unit == "player" or unit == "nameplate3" end
UnitIsFriend = function(_, unit) return not UnitCanAttack("player", unit) end
UnitHealth = function() return 50 end
UnitHealthMax = function() return 100 end

-- Which addons the stand-in has in (none to start with).
local loadedNow = {}
local function IsLoaded(name) return loadedNow[name] == true end
IsAddOnLoaded = IsLoaded
C_AddOns.IsAddOnLoaded = IsLoaded

-- Load.
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
wow.Fire("PLAYER_ENTERING_WORLD", true, false)
-- luacheck: pop

-- The stand-in's stubs make errors of their own: kept to a list, never a
-- stop (ns.Suspend would end the drive after a repeating one).
local errorsSeen, errorOrder = {}, {}
ns.ReportError = function(message)
	local line = tostring(message):match("^[^\n]*")
	if not errorsSeen[line] then
		errorsSeen[line] = 0
		errorOrder[#errorOrder + 1] = line
	end
	errorsSeen[line] = errorsSeen[line] + 1
end
ns.Suspend = function() end
ns.Print = function() end

local failed = 0
local function Check(ok, text)
	print((ok and "PASS " or "FAIL ") .. text)
	if not ok then failed = failed + 1 end
end

-- Names of ns's functions, for the report (and to find ns.EQoLMark and the like).
local nsName = {}
local function NameNs(t, prefix, seen)
	if seen[t] then return end
	seen[t] = true
	for key, value in pairs(t) do
		if type(key) == "string" then
			if type(value) == "function" and not nsName[value] then
				nsName[value] = prefix .. key
			elseif type(value) == "table" and prefix == "ns." and not getmetatable(value) then
				NameNs(value, prefix .. key .. ".", seen)
			end
		end
	end
end
NameNs(ns, "ns.", {})

-- The asking itself: whether an addon is in. Called anywhere, anytime.
local GATES = {
	["ns.AddonUp"] = true,
	["ns.AddOnLoaded"] = true,
	["ns.AddOnInstalled"] = true,
	["ns.AddOnWillLoad"] = true,
	["ns.AddonSupportOn"] = true,
	["ns.HasAddonSetup"] = true,
	["ns.IsSupportedAddon"] = true,
}

-- What a call is: its file, the line it starts on, its name.
local infoOf = {}
local function Describe(fn, level)
	local info = infoOf[fn]
	if info == nil then
		local i = debug.getinfo(fn, "S")
		local source = (i.source or ""):gsub("^@", ""):gsub("\\", "/")
		info = { source = source, line = i.linedefined, support = source:find("^Support/") ~= nil }
		infoOf[fn] = info
	end
	local name = nsName[fn]
	if not name then
		local n = debug.getinfo(level, "n")
		name = n and n.name
	end
	return info, name
end

local fileCalls = {} -- [file] = calls, to see what the drive reached
-- The hot paths the drive has to reach, each called at least once.
local REACH = { ["ns.UpdateFrames"] = 0, ["ns.UpdatePlates"] = 0, ["ns.SetPlateAlpha"] = 0,
	["ns.IsMinimapRevealed"] = 0 }
local leaks = {} -- [key] = { count, info, name, word, callers = {} }
local leakOrder = {}
local function Hook()
	local fnInfo = debug.getinfo(3, "f") -- (1 Hook, 2 OnHook, 3 the call)
	local fn = fnInfo and fnInfo.func
	if not fn then return end
	local cached = infoOf[fn]
	if cached and cached.skip then return end
	local info, name = Describe(fn, 4) -- (one deeper: Describe)
	if info.source == "=[C]" or info.source:find("^Tools/") then
		info.skip = true
		return
	end
	fileCalls[info.source] = (fileCalls[info.source] or 0) + 1
	if name and REACH[name] then REACH[name] = REACH[name] + 1 end
	if name and GATES[name] then return end
	local word = info.support and info.source:match("^Support/(.-)%.lua$") or AddonWord(name)
	if not word then return end
	local key = info.source .. ":" .. tostring(info.line)
	local leak = leaks[key]
	if not leak then
		leak = { count = 0, info = info, name = name, word = word, callers = {}, callerOrder = {} }
		leaks[key] = leak
		leakOrder[#leakOrder + 1] = key
	end
	leak.count = leak.count + 1
	local c = debug.getinfo(4, "Sl")
	local caller = c and ((c.source or ""):gsub("^@", ""):gsub("\\", "/") .. ":" .. tostring(c.currentline)) or "?"
	if not leak.callers[caller] then
		leak.callers[caller] = 0
		leak.callerOrder[#leak.callerOrder + 1] = caller
	end
	leak.callers[caller] = leak.callers[caller] + 1
end

-- A handler stuck in a loop (the stand-in's stubs never end a walk up
-- parents) is stopped after a budget of instructions, and named.
local CHUNK = 10000
local budget, stuck = 1e9, {} -- (no limit outside a handler)
local hookCalls = false
local calls = 0
-- (Once over, every call and chunk errors till the handler is left: a loop
-- that catches its own errors still ends, at its next call.)
local aborting = false
local stuckWhere = nil -- (where the last stuck handler was, for the report)
local function OnHook(event)
	if event == "count" then
		budget = budget - 1
		if budget < 0 and not aborting then
			aborting = true
			local where = {}
			for level = 2, 40 do
				local i = debug.getinfo(level, "Sl")
				if not i then break end
				if i.currentline and i.currentline > 0 then where[#where + 1] = i.short_src .. ":" .. i.currentline end
				if #where >= 6 then break end
			end
			stuckWhere = table.concat(where, " < ")
		end
		if aborting then error("stuck", 2) end
		return
	end
	if aborting then error("stuck", 2) end
	if hookCalls then
		calls = calls + 1
		Hook()
		if calls % 1000000 == 0 and os.getenv("NOADDONS_PROGRESS") then
			local i = debug.getinfo(2, "Sl")
			io.stderr:write(("  %dM calls, in %s:%s\n"):format(calls / 1000000, tostring(i and i.short_src),
				tostring(i and i.currentline)))
		end
	end
end
local spent = {} -- [label] = seconds, for a slow run
local function Run(label, fn, ...)
	budget, aborting = 300, false -- (3M instructions)
	local t0 = os.clock()
	local ok, err = pcall(fn, ...)
	local wasStuck = aborting
	aborting, budget = false, 1e9
	spent[label] = (spent[label] or 0) + os.clock() - t0
	if os.getenv("NOADDONS_PROGRESS") and os.clock() - t0 > 0.3 then io.stderr:write(("  %s took %.1f s%s\n"):format(label, os.clock() - t0, wasStuck and " (stuck)" or "")) end
	if wasStuck then stuck[label] = (stuck[label] or 0) + 1 end
	return ok, err
end
debug.sethook(OnHook, "c", CHUNK)

-- Everything the addon set up runs: OnUpdate scripts each frame, timers when
-- due, and every event a frame of it listens to, now and then.
local SKIP_EVENTS = { ADDON_LOADED = true, PLAYER_LOGIN = true, PLAYER_LOGOUT = true, PLAYER_LEAVING_WORLD = true }
local UNIT_ARGS = { "player", "target", "nameplate1", "nameplate3", "party1" }
local function RunTimers()
	local due = {}
	for i = #timers, 1, -1 do
		local t = timers[i]
		if t.cancelled then
			table.remove(timers, i)
		elseif t.at <= now then
			due[#due + 1] = t
			t.times = t.times - 1
			if t.times <= 0 then table.remove(timers, i) else t.at = now + math.max(t.every or 0, 0.01) end
		end
	end
	for _, t in ipairs(due) do Run("a timer", t.fn, t) end
end
local function RunUpdates(dt)
	for _, frame in ipairs(wow.frames) do
		local fn = frame._scripts.OnUpdate
		-- (As in the game: only a frame shown, with its parents shown.)
		local shown = fn ~= nil
		local up = frame
		while shown and type(up) == "table" and rawget(up, "_shown") ~= nil do
			shown = up._shown
			up = rawget(up, "_parent")
		end
		if shown then Run("OnUpdate of " .. tostring(frame._name or frame._kind), fn, frame, dt) end
		if shown and stuckWhere then
			stuck["  in " .. stuckWhere] = (stuck["  in " .. stuckWhere] or 0) + 1
			stuckWhere = nil
		end
	end
end
local function FireAll(step)
	local events = {}
	for _, frame in ipairs(wow.frames) do
		for event in pairs(frame._events) do events[event] = true end
	end
	local list = {}
	for event in pairs(events) do if not SKIP_EVENTS[event] then list[#list + 1] = event end end
	table.sort(list)
	for i, event in ipairs(list) do
		local unit = UNIT_ARGS[(i + step) % #UNIT_ARGS + 1]
		for _, frame in ipairs(wow.frames) do
			local handler = frame._events[event] and frame._scripts.OnEvent
			if handler then Run(event, handler, frame, event, unit, unit) end
		end
	end
end
local function Drive(seconds, cinematic)
	-- (CineMode by its key: on with a profile chosen, as a player has it.)
	ns.cineKeyOn = cinematic
	if cinematic then ns.ProfileChosen = function() return true end end
	for step = 1, math.floor(seconds / 0.05) do
		if os.getenv("NOADDONS_PROGRESS") then io.stderr:write(("step %d %.1f s\n"):format(step, os.clock())) end
		now = now + 0.05
		RunTimers()
		RunUpdates(0.05)
		if step % 20 == 1 then
			for unit in pairs(plateOf) do
				for _, frame in ipairs(wow.frames) do
					local handler = frame._events.NAME_PLATE_UNIT_ADDED and frame._scripts.OnEvent
					if handler then Run("NAME_PLATE_UNIT_ADDED", handler, frame, "NAME_PLATE_UNIT_ADDED", unit) end
				end
			end
			FireAll(step)
		end
	end
end

-- Every page on (a fresh install has some off till a profile's chosen), so
-- each feature's passes run.
for key, value in pairs(ns.DEFAULTS or {}) do
	if type(key) == "string" and key:find("^handle") and type(value) == "boolean" then ns.db[key] = true end
end
for key, value in pairs(ns.db) do
	if type(key) == "string" and key:find("^handle") and value == false then ns.db[key] = true end
end

-- Settle first (setups, the first passes), then count.
local clock = os.clock()
Drive(2, false)
io.stderr:write(("settled in %.1f s\n"):format(os.clock() - clock))
counting, hookCalls = true, true
debug.sethook(OnHook, "c", CHUNK)
Drive(SECONDS, false)
Drive(SECONDS, true)
debug.sethook(OnHook, "c", CHUNK)
counting, hookCalls = false, false
io.stderr:write(("drove in %.1f s\n"):format(os.clock() - clock))
if os.getenv("NOADDONS_PROGRESS") then
	local list = {}
	for label, t in pairs(spent) do list[#list + 1] = { label, t } end
	table.sort(list, function(a, b) return a[2] > b[2] end)
	for i = 1, math.min(10, #list) do io.stderr:write(("slow: %s %.2f s\n"):format(list[i][1], list[i][2])) end
end
for label, n in pairs(stuck) do print(("info: stuck on the stand-in, stopped: %s (%d)"):format(label, n)) end

Check(calls > 100000, ("drove the addon: %d calls in %d s of pretend time"):format(calls, SECONDS * 2))
print(("info: CineMode %s (%s), plates %s, minimap %s, suspended %s"):format(tostring(ns.lastCinematic),
	tostring(ns.cineOffWhy), tostring(ns.db and ns.db.handlePlates), tostring(ns.db and ns.db.handleMinimap),
	tostring(ns.IsSuspended and ns.IsSuspended())))
local reached = {}
for _, file in ipairs({ "Core.lua", "Frames.lua", "Effects.lua", "Plates/PlateParts.lua", "UI/NodeSweep.lua",
	"Visions/QuestGlow.lua" }) do
	reached[#reached + 1] = file .. " " .. (fileCalls[file] or 0)
end
for i, line in ipairs(errorOrder) do
	if i > 8 then print(("info: %d more stand-in errors"):format(#errorOrder - 8)) break end
	print(("info: stand-in error (%d): %s"):format(errorsSeen[line], line))
end
print("info: calls per file: " .. table.concat(reached, ", "))
local reachList = {}
for name, n in pairs(REACH) do reachList[#reachList + 1] = name .. " " .. n end
table.sort(reachList)
local missed = {}
for name, n in pairs(REACH) do if n == 0 then missed[#missed + 1] = name end end
table.sort(missed)
Check(#missed == 0, "the drive reached every hot path: " .. table.concat(reachList, ", "))
local ranUpdates = false
for _, frame in ipairs(wow.frames) do if frame._scripts.OnUpdate then ranUpdates = true break end end
Check(ranUpdates, "update loops found to run")

table.sort(leakOrder, function(a, b) return leaks[a].count > leaks[b].count end)
for _, key in ipairs(leakOrder) do
	local leak = leaks[key]
	print(("LEAK %s (%s) %s: %d calls with %s not loaded"):format(leak.name or "?", key, leak.word, leak.count,
		leak.word))
	for i, caller in ipairs(leak.callerOrder) do
		if i > 3 and not showAll then break end
		print(("       from %s (%d)"):format(caller, leak.callers[caller]))
	end
end
Check(#leakOrder == 0, ("no other addon's support ran with none loaded (%d leaking functions)"):format(#leakOrder))

if next(addonGlobalReads) then
	local names = {}
	for name, n in pairs(addonGlobalReads) do names[#names + 1] = { name, n } end
	table.sort(names, function(a, b) return a[2] > b[2] end)
	local parts = {}
	for i = 1, math.min(#names, 12) do parts[i] = names[i][1] .. " " .. names[i][2] end
	print("info: addon globals looked up while driving (gates, fine if cheap): " .. table.concat(parts, ", "))
end

-- Late loads: each addon in after Cinematic and after login.
if ns.AddonUp then
	local late = { "Questie", "EnhanceQoL", "Plater", "ElvUI", "EllesmereUI", "Glass", "DaylightUI" }
	local wrong = {}
	for _, name in ipairs(late) do
		local before = ns.AddonUp(name)
		loadedNow[name] = true
		wow.Fire("ADDON_LOADED", name)
		local after = ns.AddonUp(name)
		if before or not after then wrong[#wrong + 1] = name .. (before and " (up before)" or " (not up after)") end
	end
	Check(#wrong == 0, "ns.AddonUp follows addons loading late: " .. (#wrong == 0 and "all" or table.concat(wrong, ", ")))

	-- With Questie in late, its support runs again on the same paths: the
	-- gates open (no "not loaded" kept from login), and the count above can
	-- see such calls at all.
	for key in pairs(leaks) do leaks[key] = nil end
	for i = #leakOrder, 1, -1 do leakOrder[i] = nil end
	hookCalls = true
	Drive(1, true)
	hookCalls = false
	local questieRan = {}
	for _, key in ipairs(leakOrder) do
		if leaks[key].word:find("Questie") then questieRan[#questieRan + 1] = leaks[key].name or key end
	end
	Check(#questieRan > 0, ("Questie in late: its support runs on the hot paths (%s)"):format(
		#questieRan > 0 and table.concat(questieRan, ", ", 1, math.min(#questieRan, 5)) or "none ran"))
else
	Check(false, "ns.AddonUp found")
end

print(failed == 0 and "ALL PASSED" or (failed .. " FAILED"))
if failed > 0 then os.exit(1) end
