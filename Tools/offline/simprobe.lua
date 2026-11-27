-- The simulation probe (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/simprobe.lua < /dev/null
-- Dev/SimProbeTest.lua (/cine debug simprobe) on a stand-in game (Forever,
-- then retail) with a small pretend world: game settings that hold their
-- values, plates sent while plates are on, soft target events while soft
-- targeting is on, a city's chat, fights with secret reads and the combat
-- log. Every step runs; the A/B finds the settings that change what's sent
-- and no others; everything is put back and Cinematic resumed; with
-- RegisterAllEvents blocked it falls back to way B. PASS or FAIL per check.
-- luacheck: push ignore 111 112 113 121 122 212 431
local SECRET = setmetatable({}, { __tostring = function() return "secret" end })
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end
local function Has(log, pattern)
	for _, line in ipairs(log or {}) do
		if line:find(pattern) then return line end
	end
end
local function Count(log, pattern)
	local n = 0
	for _, line in ipairs(log or {}) do
		if line:find(pattern) then n = n + 1 end
	end
	return n
end

local function RunClient(client, blockAll)
	print("== " .. client .. (blockAll and " (RegisterAllEvents blocked)" or ""))
	local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function(w)
		issecretvalue = function(value) return value == SECRET end
		local M = w.Methods
		M.RegisterAllEvents = function(self)
			if blockAll then error("blocked on purpose") end
			self._events = setmetatable({}, { __index = function() return true end })
		end
	end)
	local now = 100
	local timers, tickers = {}, {}
	GetTime = function() return now end
	C_Timer.After = function(delay, fn) timers[#timers + 1] = { at = now + delay, fn = fn } end
	C_Timer.NewTicker = function(every, fn)
		local t = { every = every, next = now + every, fn = fn, Cancel = function(self) self.cancelled = true end }
		tickers[#tickers + 1] = t
		return t
	end

	-- The world. Game settings hold what's written; writing one sends CVAR_UPDATE.
	local cvars = {}
	for _, set in ipairs(ns.cvarSets or {}) do
		for cvar in pairs(set.values) do cvars[cvar] = "0" end
	end
	cvars.SoftTargetInteract = "1" -- (yours: on at 1, Quest Vision's 3)
	local original = {}
	for k, v in pairs(cvars) do original[k] = v end
	local function Get(name) return cvars[name] end
	local function Set(name, value)
		if cvars[name] == nil then return false end
		cvars[name] = tostring(value)
		wow.Fire("CVAR_UPDATE", name, tostring(value))
		return true
	end
	GetCVar, SetCVar = Get, Set
	C_CVar = { GetCVar = Get, SetCVar = Set }
	local fight = false
	InCombatLockdown = function() return fight end
	UnitAffectingCombat = function() return fight end
	local plates = 0
	UnitExists = function(unit)
		if unit == "player" then return true end
		if unit == "target" then return fight end
		local n = tonumber((unit or ""):match("^nameplate(%d+)$") or "")
		return n ~= nil and n <= plates
	end
	UnitIsUnit = function(a, b) return a == b end
	UnitHealth = function(unit) return (fight and client == "forever" and unit ~= "player") and SECRET or 100 end
	UnitHealthMax = function() return 100 end
	UnitName = function(unit) return unit end
	UnitGUID = function(unit) return "guid-" .. unit end
	CombatLogGetCurrentEventInfo = function() return now, "SWING_DAMAGE", false, "src", SECRET end
	-- The console: every setting above, plus a command and a secure one.
	ConsoleGetAllCommands = function()
		local list = { { command = "reloadui", commandType = 1, help = "Reloads the UI" } }
		for name in pairs(cvars) do list[#list + 1] = { command = name, commandType = 0, help = "help\tfor " .. name } end
		return list
	end
	C_CVar.GetCVarInfo = function(name)
		if cvars[name] == nil then return nil end
		return cvars[name], "0", false, false, false, name:find("^SoftTarget") ~= nil, false
	end

	-- What the game sends, by the settings.
	local function World(dt)
		local platesOn = cvars.nameplateShowAll == "1" or cvars.nameplateShowEnemies == "1"
		plates = platesOn and 5 or 0
		if math.random() < 2 * dt then wow.Fire("CHAT_MSG_CHANNEL", "hello", "Player17") end
		if platesOn and math.random() < 3 * dt then
			wow.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
			wow.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
		end
		if cvars.SoftTargetInteract == "3" and math.random() < 1 * dt then
			wow.Fire("PLAYER_SOFT_INTERACT_CHANGED", "a", "b")
		end
		if fight then
			if math.random() < 5 * dt then wow.Fire("UNIT_HEALTH", "target", SECRET) end
			if math.random() < 8 * dt then wow.Fire("COMBAT_LOG_EVENT_UNFILTERED") end
		end
	end
	-- The frames the test makes get their OnUpdate each step while shown up
	-- their parent chain (Cinematic's own are left alone here: the replay
	-- bench, Tools/sim/bench.lua, is what runs those).
	local firstOwn = math.huge
	local function Visible(frame)
		while type(frame) == "table" do
			if rawget(frame, "_shown") == false then return false end
			frame = rawget(frame, "_parent")
		end
		return true
	end
	local function Frames(dt)
		for i = firstOwn, #wow.frames do
			local frame = wow.frames[i]
			local fn = frame._scripts.OnUpdate
			if fn and Visible(frame) then fn(frame, dt) end
		end
	end
	local function Advance(seconds)
		local stop = now + seconds
		while now < stop do
			now = now + 0.1
			World(0.1)
			Frames(0.1)
			local due = {}
			for i = #timers, 1, -1 do
				if timers[i].at <= now then due[#due + 1] = table.remove(timers, i) end
			end
			for i = #due, 1, -1 do due[i].fn() end
			for _, t in ipairs(tickers) do
				if not t.cancelled and t.next <= now then
					t.next = now + t.every
					t.fn(t)
				end
			end
		end
	end
	math.randomseed(7)
	local cine = true
	ns.IsCineModeOn = function() return cine end
	Cinematic_ToggleCineMode = function() cine = not cine end
	local box = ""
	ns.PadTestBox = function(text, sub) box = tostring(text) .. " | " .. tostring(sub) end
	ns.PadTestBoxHide = function() end

	-- You: answer what the box asks.
	local function Click(button) button:GetScript("OnClick")(button, "LeftButton") end
	firstOwn = #wow.frames + 1
	ns.HandleSlash("debug simprobe")
	local asked = {}
	for _ = 1, 4000 do
		Advance(0.5)
		local run = ns.TestKit.Running()
		if not run then break end
		if box:find("Ready", 1, true) and run.buttons and run.buttons.Ready and not asked[box] then
			asked[box] = true
			Click(run.buttons.Ready)
		elseif (box:find("Pull", 1, true) or box:find("Find mobs", 1, true) or box:find("Keep fighting", 1, true))
			and not fight then
			fight = true
			wow.Fire("PLAYER_REGEN_DISABLED")
		elseif box:find("Out of the fight", 1, true) and fight then
			fight = false
			wow.Fire("PLAYER_REGEN_ENABLED")
		end
		-- (Fights end now and then, as they do.)
		if fight and math.random() < 0.01 then
			fight = false
			wow.Fire("PLAYER_REGEN_ENABLED")
		end
	end
	fight = false
	local log = CinematicDB.simProbeTestLog
	local done = Has(log, "DONE: ")
	Check("finished DONE", done ~= nil, done or tostring(ns.TestKit.Running() and ns.TestKit.Running().step
		and ns.TestKit.Running().step.key))
	local vis = Has(log, "simprobe engine|onupdate|")
	Check("engine: OnUpdate only up a shown chain", vis and vis:find("hidden parent 0|hidden itself 0|", 1, true) ~= nil
		and not vis:find("|shown 0|", 1, true), vis)
	local order = Has(log, "simprobe engine|order|")
	Check("engine: OnUpdate order logged", order and order:find("ABC", 1, true) ~= nil, order)
	Check("engine: After(0) placed", Has(log, "simprobe engine|after0|same frame") ~= nil, Has(log, "after0"))
	local console = Has(log, "simprobe engine|console|")
	Check("engine: console settings saved", console and CinematicDB.simCVarsLog and #CinematicDB.simCVarsLog > 50, console)
	local secureLine
	for _, line in ipairs(CinematicDB.simCVarsLog or {}) do
		if line:find("^cvar\tSoftTargetInteract\t") then secureLine = line end
	end
	Check("engine: a secure setting's line: value, default, flags, help without tabs",
		secureLine and secureLine:find("\tsecure\thelp for SoftTargetInteract$") ~= nil, secureLine)
	Check("engine: header names the client", (CinematicDB.simCVarsLog or {})[1] and CinematicDB.simCVarsLog[1]:find("^client " .. client) ~= nil,
		(CinematicDB.simCVarsLog or {})[1])
	local events = Has(log, "simprobe events|all")
	Check("step 1: the events line", events ~= nil, events)
	if blockAll then
		Check("blocked: way B for the rest", Has(log, "way B %(") ~= nil, Has(log, "way B"))
	else
		Check("way A for the rest", Has(log, "way A for the rest") ~= nil)
	end
	Check("step 2: a line per set", Count(log, "^.-simprobe setting|") == #(ns.cvarSets or {}),
		Count(log, "simprobe setting|") .. " of " .. #(ns.cvarSets or {}))
	Check("step 2: every setting took", Has(log, " 0 didn't, ") ~= nil, Has(log, "settings: "))
	local bulk = Has(log, "simprobe set|bulk")
	Check("bulk: nothing sent changes", bulk and bulk:find("|nothing|", 1, true) ~= nil, bulk)
	Check("bulk: no plate set in it", bulk and not (Has(log, "bulk sets:") or ""):find("Friendly player bars", 1, true), Has(log, "bulk sets:"))
	Check("dev test sets marked, not tested", Has(log, "simprobe setting|NPC title test: far|dev|") ~= nil and Has(log, "simprobe set|NPC title") == nil)
	Check("names bundled", Has(log, "simprobe set|Names over heads %(%d+ sets%)|plates|") ~= nil, Has(log, "Names over heads"))
	local all = Has(log, "simprobe set|All plates on|plates|")
	Check("All plates on: changes, with plate events", all and all:find("|changes|", 1, true) ~= nil
		and all:find("NAME_PLATE_UNIT_ADDED", 1, true) ~= nil, all)
	Check("no plate set unreliable", Has(log, "simprobe set|[^|]+|plates|unreliable") == nil,
		Has(log, "simprobe set|[^|]+|plates|unreliable"))
	local soft = Has(log, "simprobe set|Quest soft targeting|soft|")
	Check("Quest soft targeting: changes, soft target events", soft and soft:find("PLAYER_SOFT_INTERACT_CHANGED", 1, true) ~= nil,
		soft)
	local size = Has(log, "simprobe size|city")
	Check("the city minute weighed", size and size:find("KB a minute", 1, true) ~= nil and size:find("All plates on", 1, true) ~= nil,
		size)
	local target = Has(log, "simprobe reads|target|")
	Check("fight reads: target health secret on Forever only", target and (target:find("UnitHealth=SECRET", 1, true) ~= nil)
		== (client == "forever"), target)
	Check("fight: secret arguments named", Has(log, "simprobe secretargs|.*UNIT_HEALTH") ~= nil, Has(log, "secretargs"))
	local clog = Has(log, "simprobe combatlog|")
	if blockAll and client == "forever" then
		Check("way B on Forever: combat log never registered by name", clog and clog:find("heard 0", 1, true) ~= nil, clog)
	else
		Check("combat log heard and read, payload secret", clog and not clog:find("heard 0|", 1, true)
			and not clog:find("secret payloads 0", 1, true), clog)
	end
	local changed = {}
	for k, v in pairs(original) do
		if cvars[k] ~= v then changed[#changed + 1] = k .. "=" .. cvars[k] end
	end
	Check("every game setting put back", #changed == 0, table.concat(changed, ", "))
	Check("Cinematic resumed", not ns.IsSuspended())
	Check("CineMode back on", cine == true)
	Check("no FAIL lines", Count(log, "FAIL ") == 0, Has(log, "FAIL "))
	if os.getenv("SIMPROBE_LOG") then
		for _, line in ipairs(log) do print("  | " .. line) end
	end
end

RunClient("forever")
RunClient("retail")
RunClient("forever", true)
print(fails == 0 and "all passed" or (fails .. " failed"))
if fails > 0 then os.exit(1) end
-- luacheck: pop
