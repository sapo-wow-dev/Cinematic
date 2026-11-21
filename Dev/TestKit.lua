-- The test kit: what every self-running in-game test needs, done once, so a
-- test only says its steps (dev copy only). The /test skill's rules
-- (.claude/skills/test/SKILL.md) are built in:
--   * one command, /cine debug <name> [step numbers | restore]; typed again
--     while it runs, it stops;
--   * each step in the big lasting box (ns.PadTestBox), no hidden time limit
--     (WaitFor waits as long as it takes), a DONE box at the end;
--   * CineMode off for the run (kept off), back after;
--   * the settings a test changes saved in CinematicDB.<key>Undo before the
--     first change, put back at the end or, after a /reload mid-run, at the
--     next login;
--   * a context line first (client, build, zone, combat, group, addons,
--     settings, CVars), a state line and the dev error / BLOCKED counts per
--     step, probe lines (type, secret, value, error, rule id) and PASS /
--     FAIL / SKIP verdicts, paced screenshots (one a second at most: the
--     file is named by the second);
--   * the log in CinematicDB.<key>Log, the run before in <key>PrevLog, so a
--     rerun doesn't lose it before .claude/skills/test/read_log.py archives it.
--
-- A test:
--   ns.TestKit.Define({
--     name = "example", key = "exampleTest", title = "Example test",
--     about = "what it checks, one line",        -- /cine debug kit lists it
--     settings = { "someSetting" },              -- ns.db keys it may change
--     cvars = { "nameplateShowAll" },            -- logged in the context line
--     cineMode = true,                           -- (only to leave CineMode alone)
--     context = function(run) return "..." end,  -- more for the context line
--     putBack = function(extra) return "..." end, -- puts back run.undo.extra
--     steps = {
--       { key = "read", title = "mana read", run = function(r)
--           local ok, v = r:Probe("UnitPower(player,0)", UnitPower, "player", 0)
--           r:Verdict(ok, "UnitPower read")
--       end },
--       { key = "hit", title = "one hit", run = function(r)
--           r:WaitFor("Hit any mob once", { events = { "UNIT_COMBAT" } })
--           r:Shot("after the hit")
--       end },
--     },
--   })
-- Inside a step (it runs in a coroutine): r:Log, r:Verdict, r:Pass, r:Fail,
-- r:Skip, r:Probe, r:Set (setting, undo saved), r:Sleep, r:Shot, r:Prompt,
-- r:WaitFor, r:Fields. Never call r:Sleep / r:Shot / r:WaitFor from inside
-- a pcall (Lua 5.1 can't yield across it).
local _, ns = ...

local Kit = {}
ns.TestKit = Kit
local defs, order = {}, {}
local current -- the run going now (one at a time)
local NIL = "<nil>" -- (SavedVariables keeps no nils in a table)
local SHOT_BEFORE, SHOT_AFTER = 1.5, 1.2

-- A value for the log: a secret one as "secret" (one secret piece makes the
-- whole line secret, and the log keeps only "secret" for it).
local function Shown(value)
	if issecretvalue and issecretvalue(value) then return "secret" end
	local kind = type(value)
	if kind == "table" then return "table" end
	if kind == "string" then return ("%q"):format(#value > 120 and value:sub(1, 120) .. "..." or value) end
	local ok, text = pcall(tostring, value)
	return ok and text or "?"
end
Kit.Shown = Shown

local function IsSecret(value)
	return (issecretvalue and issecretvalue(value)) and true or false
end

local function Client()
	if ns.isRetail then return "retail" end
	return ns.isClassicEra and "classic_era" or "forever"
end

local function Try(fn, ...)
	local ok, value = pcall(fn, ...)
	if ok and type(value) == "string" and not IsSecret(value) then return value end
	return ok and Shown(value) or "?"
end

-- Where you are and what's going on: on the context line and each step's.
local function StateLine()
	local inside, kind = false, "?"
	pcall(function() inside, kind = IsInInstance() end)
	return ("combat %s, lockdown %s, %s (%s), group %s, mounted %s, dead %s, CineMode %s"):format(
		Try(UnitAffectingCombat, "player"), Try(InCombatLockdown), Try(GetZoneText),
		inside and tostring(kind) or "outside", Try(GetNumGroupMembers), Try(IsMounted),
		Try(UnitIsDeadOrGhost, "player"), Try(ns.IsCineModeOn))
end
Kit.StateLine = StateLine

local function Counts()
	if not ns.DevErrorCount then return 0, 0 end
	local function Sum(kinds)
		local n = 0
		for _, kind in ipairs(kinds) do n = n + (ns.DevErrorCount(kind) or 0) end
		return n
	end
	-- (The kinds Dev/ErrorWindow.lua taps.)
	return Sum({ "error", "error (BugGrabber)" }),
		Sum({ "blocked", "forbidden", "blocked (no event)", "blocked (chat line only)" })
end

local function Addons()
	local names = {}
	local ok, count = pcall(C_AddOns and C_AddOns.GetNumAddOns or GetNumAddOns or function() return 0 end)
	count = ok and type(count) == "number" and count or 0
	local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
	local info = C_AddOns and C_AddOns.GetAddOnInfo or GetAddOnInfo
	for i = 1, count do
		local name = info and info(i)
		if name and loaded and loaded(i) and not name:find("^Blizzard_") then names[#names + 1] = name end
	end
	return #names .. ": " .. table.concat(names, ", ")
end

-- The log ------------------------------------------------------------------

local function Say(run, text)
	local log = CinematicDB and CinematicDB[run.def.key .. "Log"]
	if log then log[#log + 1] = date("%H:%M:%S") .. " " .. text end
end

-- Undo: saved before the first change, put back at the end or next login ---

local function UndoKey(def) return def.key .. "Undo" end

local function PutBack(def)
	local undo = CinematicDB and CinematicDB[UndoKey(def)]
	if not undo then return "nothing to put back" end
	local said = {}
	local db = ns.db
	if db and undo.settings then
		local n = 0
		for key, value in pairs(undo.settings) do
			if value == NIL then value = nil end
			db[key] = value
			n = n + 1
		end
		said[#said + 1] = n .. " setting(s) put back"
	end
	if def.putBack then
		local ok, text = pcall(def.putBack, undo.extra or {})
		said[#said + 1] = ok and tostring(text or "own state put back") or ("own put back failed: " .. tostring(text))
	end
	if undo.cineWas and ns.IsCineModeOn and not ns.IsCineModeOn() and Cinematic_ToggleCineMode then
		pcall(Cinematic_ToggleCineMode)
		said[#said + 1] = "CineMode back on"
	end
	CinematicDB[UndoKey(def)] = nil
	if ns.RefreshOptions then pcall(ns.RefreshOptions) end
	return table.concat(said, ", ")
end
Kit.PutBack = function(name) return defs[name] and PutBack(defs[name]) end

-- A run's methods ------------------------------------------------------------

local Run = {}
Run.__index = Run

function Run:Log(text) Say(self, "  " .. tostring(text)) end

function Run:Verdict(ok, text)
	local step = self.step
	if ok then self.pass = self.pass + 1 else self.fail = self.fail + 1 end
	local line = ("%s %s: %s"):format(ok and "PASS" or "FAIL", step and step.key or "run", tostring(text))
	self.verdicts[#self.verdicts + 1] = line
	Say(self, "  verdict " .. line)
	return ok
end
function Run:Pass(text) return self:Verdict(true, text) end
function Run:Fail(text) return self:Verdict(false, text) end
function Run:Skip(why)
	self.skip = self.skip + 1
	local line = ("SKIP %s: %s"):format(self.step and self.step.key or "run", tostring(why))
	self.verdicts[#self.verdicts + 1] = line
	Say(self, "  verdict " .. line)
end

-- One fact read, logged in one greppable line:
--   probe <label>: ok=true type=number secret=false value=42 err=nil [more=...] [rule=<id>]
-- The label can be { label = "...", rule = "<engine rule id>" }: the line
-- then names the rule it checks, for check log to update.
function Run:Probe(label, fn, ...)
	local rule
	if type(label) == "table" then label, rule = label.label, label.rule end
	local results = { pcall(fn, ...) }
	local ok, value = results[1], results[2]
	local line = ("probe %s: ok=%s type=%s secret=%s value=%s err=%s"):format(tostring(label), tostring(ok),
		ok and type(value) or "-", ok and tostring(IsSecret(value)) or "-", ok and Shown(value) or "-",
		ok and "nil" or Shown(value))
	if ok and #results > 2 then
		local more = {}
		for i = 3, #results do more[#more + 1] = Shown(results[i]) end
		line = line .. " more=" .. table.concat(more, ",")
	end
	if rule then line = line .. " rule=" .. rule end
	Say(self, "  " .. line)
	return ok, value, select(3, unpack(results))
end

-- Several fields of one thing in one line, each read on its own (a secret or
-- erroring one doesn't lose the rest): r:Fields("plate 1", { alpha = fn, ... }).
function Run:Fields(label, readers)
	local keys, parts = {}, {}
	for key in pairs(readers) do keys[#keys + 1] = key end
	table.sort(keys)
	for _, key in ipairs(keys) do
		local ok, value = pcall(readers[key])
		parts[#parts + 1] = key .. "=" .. (ok and Shown(value) or "error")
	end
	Say(self, ("  fields %s: %s"):format(label, table.concat(parts, " ")))
end

-- A setting changed for the run: its value before saved in the undo first.
function Run:Set(key, value)
	local undo = CinematicDB[UndoKey(self.def)]
	undo.settings = undo.settings or {}
	if undo.settings[key] == nil then
		local was = ns.db[key]
		undo.settings[key] = was == nil and NIL or was
	end
	ns.db[key] = value
	Say(self, ("  set %s = %s"):format(key, Shown(value)))
end

-- Something of the test's own to put back (the def's putBack gets it).
function Run:Keep(key, value)
	local undo = CinematicDB[UndoKey(self.def)]
	undo.extra = undo.extra or {}
	if undo.extra[key] == nil then undo.extra[key] = value == nil and NIL or value end
end

local function Box(run, text, sub, r, g, b)
	ns.debugNoCopyWindow = true
	if ns.PadTestBox then
		ns.PadTestBox(text, sub, r, g, b)
		ns.padTestRun = run
	elseif ns.TestPrompt then
		ns.TestPrompt(text, 3600)
	end
end

function Run:Prompt(text, sub)
	local n = self.step and self.stepNumber or 0
	Box(self, ("%s, step %d/%d: %s"):format(self.def.title, n, #self.steps, text),
		sub or ("No time limit. /cine debug %s again stops it."):format(self.def.name), 1, 0.82, 0)
	Say(self, "  asked: " .. text)
end

-- Waits (yields) the step's coroutine; the C_Timer resumes it.
function Run:Sleep(seconds)
	local co = self.co
	C_Timer.After(seconds, function() if current == self and not self.stopped then self:Resume(co) end end)
	return coroutine.yield()
end

function Run:Shot(label)
	self:Sleep(SHOT_BEFORE)
	local ok = pcall(function() Screenshot() end)
	Say(self, ("  screenshot %s: WoWScrnShot_%s%s"):format(tostring(label), date("%m%d%y_%H%M%S"),
		ok and "" or " (failed)"))
	self:Sleep(SHOT_AFTER)
end

-- Waits for the user (or the game) with no time limit. opts:
--   events = { "UNIT_COMBAT", ... }  resume on one of these (filter(event, ...)
--                                    returning true picks which)
--   check = function() ... end       or polled every 0.2 s till it's truthy
-- Returns what woke it: the event and its args, or check's value.
function Run:WaitFor(text, opts)
	opts = opts or {}
	if text then self:Prompt(text) end
	local co, run = self.co, self
	local waiter, ticker
	local function Done(...)
		if waiter then waiter:UnregisterAllEvents() end
		if ticker then ticker:Cancel() end
		run.waiting = nil
		if current == run and not run.stopped then run:Resume(co, ...) end
	end
	if opts.events then
		waiter = CreateFrame("Frame")
		for _, event in ipairs(opts.events) do pcall(waiter.RegisterEvent, waiter, event) end
		waiter:SetScript("OnEvent", function(_, event, ...)
			if not opts.filter or opts.filter(event, ...) then Done(event, ...) end
		end)
	end
	if opts.check then
		ticker = C_Timer.NewTicker(0.2, function()
			local ok, value = pcall(opts.check)
			if ok and value then Done(value) end
		end)
	end
	self.waiting = { frame = waiter, ticker = ticker }
	local started = GetTime()
	local results = { coroutine.yield() }
	Say(self, ("  got it after %.1f s: %s"):format(GetTime() - started, Shown(results[1])))
	return unpack(results)
end

function Run:Resume(co, ...)
	if coroutine.status(co) ~= "suspended" then return end
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		local stack = ""
		pcall(function() stack = debugstack(co, 0, 6, 0) or "" end)
		self.fail = self.fail + 1
		self.verdicts[#self.verdicts + 1] = "FAIL Lua error: " .. tostring(err)
		Say(self, "  verdict FAIL Lua error in the test: " .. tostring(err) .. " " .. stack:gsub("\n", " | "))
		Kit.Finish(self, false)
	elseif coroutine.status(co) == "dead" and current == self and not self.stopped then
		Kit.Finish(self, true)
	end
end

-- Running ----------------------------------------------------------------------

local function KeepCineOff(run)
	if run.def.cineMode or not ns.IsCineModeOn then return end
	if ns.IsCineModeOn() and Cinematic_ToggleCineMode then
		pcall(Cinematic_ToggleCineMode)
		Say(run, "  CineMode came on: turned off again for the test")
	end
end

local function ContextLine(run)
	local def = run.def
	local version, build, _, toc = "?", "?", nil, "?"
	pcall(function() version, build, _, toc = GetBuildInfo() end)
	local parts = { ("context: Cinematic %s, %s, game %s (%s) toc %s, %s, level %s %s"):format(
		ns.Version and Try(ns.Version) or "?",
		Client(), tostring(version), tostring(build), tostring(toc), Try(GetLocale), Try(UnitLevel, "player"),
		Try(function() return select(2, UnitClass("player")) end)) }
	parts[#parts + 1] = "state: " .. StateLine()
	parts[#parts + 1] = "ui scale " .. Try(function() return UIParent:GetEffectiveScale() end)
		.. ", screen " .. Try(function() return ("%dx%d"):format(_G.GetPhysicalScreenSize()) end)
	parts[#parts + 1] = "addons " .. Addons()
	if def.settings then
		local s = {}
		for _, key in ipairs(def.settings) do s[#s + 1] = key .. "=" .. Shown(ns.db[key]) end
		parts[#parts + 1] = "settings " .. table.concat(s, " ")
	end
	if def.cvars then
		local c = {}
		for _, name in ipairs(def.cvars) do c[#c + 1] = name .. "=" .. Try(GetCVar, name) end
		parts[#parts + 1] = "cvars " .. table.concat(c, " ")
	end
	if def.context then
		local ok, text = pcall(def.context, run)
		parts[#parts + 1] = ok and tostring(text) or ("own context failed: " .. tostring(text))
	end
	for _, part in ipairs(parts) do Say(run, part) end
end

function Kit.Finish(run, done)
	if current ~= run or run.stopped then return end
	run.stopped = true
	if run.waiting then
		if run.waiting.frame then run.waiting.frame:UnregisterAllEvents() end
		if run.waiting.ticker then run.waiting.ticker:Cancel() end
	end
	if run.cineTicker then run.cineTicker:Cancel() end
	if run.def.finish then
		local ok, err = pcall(run.def.finish, run)
		if not ok then Say(run, "  own finish failed: " .. tostring(err)) end
	end
	Say(run, "put back: " .. PutBack(run.def))
	local errors, blocked = Counts()
	local summary = ("%s: %d pass, %d fail, %d skip; errors +%d, blocked +%d"):format(done and "DONE" or "STOPPED",
		run.pass, run.fail, run.skip, errors - run.errors0, blocked - run.blocked0)
	Say(run, summary)
	Say(run, "verdicts: " .. table.concat(run.verdicts, "; "))
	current = nil
	local title = run.def.title
	if done then
		Box(run, ("%s DONE: %d pass, %d fail, %d skip."):format(title, run.pass, run.fail, run.skip),
			"/reload, then say \"check log\".", run.fail > 0 and 1 or 0.3, run.fail > 0 and 0.4 or 1, 0.3)
	else
		Box(run, title .. " stopped.", "Your settings are put back. /reload, then say \"check log\".", 1, 0.6, 0.3)
	end
	ns.Print(("%s %s"):format(title, summary))
	C_Timer.After(60, function() if not current and ns.PadTestBoxHide then ns.PadTestBoxHide(run) end end)
end

local function Pick(def, arg)
	local wanted, steps = {}, {}
	for number in (arg or ""):gmatch("%d+") do wanted[tonumber(number)] = true end
	for i, step in ipairs(def.steps) do
		if not next(wanted) or wanted[i] then steps[#steps + 1] = { step = step, number = i } end
	end
	return steps
end

function Kit.Start(name, arg)
	local def = defs[name]
	if not (def and CinematicDB and ns.db) then return end
	if current then
		local same = current.def == def
		Kit.Finish(current, false)
		if same then return end -- (typed again: that was the stop)
	end
	if arg == "restore" then
		ns.Print(def.title .. ": " .. PutBack(def))
		return
	end
	-- The run before kept, so a rerun doesn't lose it; a cut-off run's undo first.
	local logKey = def.key .. "Log"
	if CinematicDB[logKey] and #CinematicDB[logKey] > 0 then CinematicDB[def.key .. "PrevLog"] = CinematicDB[logKey] end
	CinematicDB[logKey] = {}
	local run = setmetatable({ def = def, pass = 0, fail = 0, skip = 0, verdicts = {} }, Run)
	run.steps = Pick(def, arg)
	current = run
	Say(run, ("start: /cine debug %s%s, %s, %d of %d step(s)"):format(def.name, arg and arg ~= "" and (" " .. arg) or "",
		date("%Y-%m-%d"), #run.steps, #def.steps))
	if CinematicDB[UndoKey(def)] then Say(run, "a cut-off run's settings first: " .. PutBack(def)) end
	run.cineWas = ns.IsCineModeOn and ns.IsCineModeOn() or false
	CinematicDB[UndoKey(def)] = { cineWas = run.cineWas or nil }
	ContextLine(run)
	run.errors0, run.blocked0 = Counts()
	if not def.cineMode then
		KeepCineOff(run)
		run.cineTicker = C_Timer.NewTicker(1, function() if current == run then KeepCineOff(run) end end)
	end
	run.co = coroutine.create(function()
		if def.setup then def.setup(run) end
		for _, picked in ipairs(run.steps) do
			local step = picked.step
			run.step, run.stepNumber = step, picked.number
			local e0, b0 = Counts()
			Say(run, ("step %d %s: %s | %s"):format(picked.number, step.key, step.title or step.say or "",
				StateLine()))
			if step.say then run:Prompt(step.say) else
				Box(run, ("%s, step %d/%d: %s"):format(def.title, picked.number, #run.steps, step.title or step.key),
					"Nothing to do: the test does this one.", 0.6, 0.9, 1)
			end
			step.run(run)
			local e1, b1 = Counts()
			Say(run, ("  step %s end: errors +%d, blocked +%d"):format(step.key, e1 - e0, b1 - b0))
			if b1 > b0 then run:Fail(("%d blocked action(s) in this step"):format(b1 - b0)) end
		end
		run.step = nil
	end)
	run:Resume(run.co)
end

-- Defining and finding tests -----------------------------------------------------

function Kit.Define(def)
	assert(def.name and def.key and def.steps, "TestKit.Define needs name, key and steps")
	def.title = def.title or def.name
	if not defs[def.name] then order[#order + 1] = def.name end
	defs[def.name] = def
	return def
end

function Kit.Running() return current end

-- /cine debug <name> [args] for a kit test (Slash.lua asks before its own
-- fallback); /cine debug kit lists them. Returns true when it was one.
function ns.TestKitRun(arg)
	local name, rest = (arg or ""):match("^(%S+)%s*(.-)$")
	if name == "kit" then
		ns.Print("test kit tests (/cine debug <name> [steps | restore]):")
		for _, each in ipairs(order) do
			local def = defs[each]
			print(("  %s - %s (%d steps)"):format(each, def.about or def.title, #def.steps))
		end
		return true
	end
	if not (name and defs[name]) then return false end
	Kit.Start(name, rest)
	return true
end

-- A run cut off by a /reload: its settings put back at the next login.
do
	local login = CreateFrame("Frame")
	login:RegisterEvent("PLAYER_ENTERING_WORLD")
	login:SetScript("OnEvent", function(self)
		self:UnregisterAllEvents()
		if not CinematicDB then return end
		for _, name in ipairs(order) do
			local def = defs[name]
			if CinematicDB[UndoKey(def)] then
				local said = PutBack(def)
				local log = CinematicDB[def.key .. "Log"]
				if log then log[#log + 1] = date("%H:%M:%S") .. " login: the run was cut off (a /reload?): " .. said end
				ns.Print(def.title .. " was cut off: " .. said)
			end
		end
	end)
end
