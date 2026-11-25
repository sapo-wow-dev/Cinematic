-- The test kit: what every self-running in-game test needs, done once, so a
-- test only says its steps (dev copy only). The /test skill's rules
-- (.claude/skills/test/SKILL.md) are built in:
--   * one command, /cine debug <name> [full | step numbers | restore]; typed again
--     while it runs, it stops;
--   * each step in the big lasting box (ns.PadTestBox), no hidden time limit
--     (WaitFor waits as long as it takes), a DONE box at the end;
--   * buttons above the box, never a typed command: Skip step and Stop on
--     every step, a prompt's own answers (WaitFor buttons = { "Yes", "No" }),
--     and the game's own actions by a secure click: { kind = "editmode" }
--     opens Edit Mode, { kind = "reload" } reloads and the run picks up at
--     the next step (Kit.ShowButtons for old tests too);
--   * CineMode off for the run (kept off), back after;
--   * the settings a test changes saved in CinematicDB.<key>Undo before the
--     first change, put back at the end or, after a /reload mid-run, at the
--     next login;
--   * a context line first (client, build, zone, combat, group, addons,
--     settings, CVars), a state line and the dev error / BLOCKED counts per
--     step, probe lines (type, secret, value, error, rule id) and PASS /
--     FAIL / SKIP verdicts, the game console's lines and CVar changes as
--     they come (console: / cvar: lines, repeats counted), paced screenshots (one a second at most: the
--     file is named by the second), r:Shot(label, { behind = frame }) puts
--     a solid background behind the frame(s) the shot is about, for that
--     shot only: use it on every shot of a frame or text;
--   * the log in CinematicDB.<key>Log, the run before in <key>PrevLog, so a
--     rerun doesn't lose it before .claude/skills/test/read_log.py archives it;
--   * every box opens with YOUR TURN (orange, a sound, again while it waits)
--     or HANDS OFF (blue, quiet): a wait the user does nothing for takes
--     handsOff = true (r:WaitFor opts, r:Prompt's 5th, a step's own);
--   * each step's errors on their own lines, each error stamped with the
--     test and step it came in (ns.DevErrorContext); the red error window
--     held till the run ends, out of every shot.
--
-- Focused runs (the user, 2026-11-22: "once we know something works ...
-- test just what we need", one full test at the end): what's proven
-- isn't asked again while working on something else.
--   * a step with proven = "what proved it (ledger run)" is left out of a
--     run; the start line says which and why;
--   * inside a step, `if not r:Proven("what proved it") then <check> end`
--     leaves out one check or question (a Reload box asked about, a shot
--     already looked at) the same way;
--   * /cine debug <name> full runs everything, proven or not: the final
--     test before a commit or release. Step numbers run just those.
--
-- A test:
--   ns.TestKit.Define({
--     name = "example", key = "exampleTest", title = "Example test",
--     about = "what it checks, one line",        -- /cine debug kit lists it
--     settings = { "someSetting" },              -- ns.db keys it may change
--     cvars = { "nameplateShowAll" },            -- logged in the context line
--     consoleWords = { "camera" },               -- every CVar/command with the word: value, default, flags
--     console = false,                           -- (only to leave out the live console: / cvar: lines)
--     cineMode = true,                           -- (only to leave CineMode alone)
--     needs = "be in a city",                    -- where to be / what to have: the test queue shows it
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
-- Timers on the box all run long: time on this step, on the whole run, and
-- a countdown when it's known how long it takes: a step's seconds = N (the
-- test's own hands-off steps), or r:Prompt(text, sub, seconds) and
-- r:WaitFor(text, { seconds = N }). (The user, 2026-11-21: "i want timers".)
-- Inside a step (it runs in a coroutine): r:Log, r:Verdict, r:Pass, r:Fail,
-- r:Skip, r:Probe, r:Set (setting, undo saved), r:Sleep, r:Shot, r:Prompt,
-- r:Overlaps(control, page) (what a placed control covers: check every new one),
-- r:WaitFor, r:Fields, r:Click (a call the game takes from a click only:
-- SendChatMessage...; from a step it's "blocked: resume()"). Never call r:Sleep / r:Shot / r:WaitFor from inside
-- a pcall (Lua 5.1 can't yield across it).
local _, ns = ...

local Kit = {}
ns.TestKit = Kit
local defs, order = {}, {}
local current -- the run going now (one at a time)
local NIL = "<nil>" -- (SavedVariables keeps no nils in a table)
local backs, HideBacks -- (the screenshot backgrounds, below)
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

-- (run.copyKey: the test queue's copy of this log, Dev/TestQueue.lua, taken
-- at the run's end: what's said after that, the errors after the test, goes
-- into the copy too, or the queue's session never sees them.)
local function Say(run, text)
	local line = date("%H:%M:%S") .. " " .. text
	local log = CinematicDB and CinematicDB[run.def.key .. "Log"]
	if log then log[#log + 1] = line end
	local copy = run.copyKey and CinematicDB and CinematicDB[run.copyKey]
	if type(copy) == "table" and copy ~= log then copy[#copy + 1] = line end
end

-- Error inspection (the user, 2026-11-25: "add it to the test kit. inspect
-- errors"; a blocked call fired 2 times in a cdmboth run and x36 after its
-- DONE, and the counts alone never said what it was). Each red-window entry's
-- count is kept at the start; at the end every entry that grew gets a line:
-- its kind, how many, its first Cinematic file:line and whether that's in the
-- test's own files (def.files, paths like "UI/CooldownBoth.lua") or another
-- feature's. Then watched on to the /reload: what fires after DONE is logged
-- too ("after the test"), into the same log, before it's saved.
local function Snapshot()
	local counts = {}
	for _, entry in ipairs(ns.DevErrorEntries and ns.DevErrorEntries() or {}) do counts[entry] = entry.count end
	return counts
end
local function Where(stack)
	if type(stack) ~= "string" then return nil end
	return stack:match("Cinematic%w*[/\\]([^:%]]+%.lua%]?:%d+)")
end
local function Inspect(run, before, label)
	local lines, grown = {}, {}
	for _, entry in ipairs(ns.DevErrorEntries and ns.DevErrorEntries() or {}) do
		local grew = entry.count - (before[entry] or 0)
		if grew > 0 then
			local where = Where(entry.stack)
			where = where and where:gsub("%]", "") or nil
			local mine
			for _, file in ipairs(run.def.files or {}) do
				-- (gsub's count in parens out: it'd be find's start, lua-multireturn-traps.)
				local pattern = (file:gsub("%.", "%%."):gsub("/", "[/\\]"))
				if where and where:find(pattern) then mine = true end
			end
			local owner = not where and ("(no Cinematic line: " .. tostring(entry.source) .. ")")
				or mine and "THIS TEST'S FEATURE"
				or (run.def.files and "another feature: say whose and get it fixed" or "owner: check the file")
			-- (Which step it first came in: the per-step inspections, StepErrors.)
			local first = run.errorFirst and run.errorFirst[entry]
			lines[#lines + 1] = ("  %s %s x%d: %s | at %s | %s%s"):format(label, entry.kind, grew,
				tostring(entry.message):sub(1, 140), tostring(where), owner, first and (" | first in " .. first) or "")
			grown[#grown + 1] = { entry = entry, kind = entry.kind, count = grew, where = where, owner = owner,
				mine = mine and true or false, message = tostring(entry.message):sub(1, 140), first = first }
		end
	end
	return lines, grown
end

-- Each step's own errors (the user, 2026-11-25: "make sure we know what step
-- opened the error"): a snapshot when a step (or the setup) starts; when it
-- ends, every error that grew in it gets a "step 3 probe error:" line, and the
-- first step each came in is kept for the run's closing lines and the queue.
local function StepLabel(run)
	if run.step then return ("step %d %s"):format(run.stepNumber or 0, tostring(run.step.key)) end
	return "setup"
end
local function StepErrorsClose(run)
	local snap = run.stepSnap
	run.stepSnap = nil
	if not snap then return end
	local label = run.stepLabel or "setup"
	local lines, grown = Inspect(run, snap, label .. " error:")
	run.errorFirst = run.errorFirst or {}
	for _, g in ipairs(grown) do
		if not run.errorFirst[g.entry] then run.errorFirst[g.entry] = label end
	end
	for _, line in ipairs(lines) do Say(run, line) end
	run.stepErrors = (run.stepErrors or 0) + #grown
end
local function StepErrorsOpen(run)
	run.stepSnap, run.stepLabel = Snapshot(), StepLabel(run)
end
Kit.InspectErrors = Inspect
Kit.ErrorSnapshot = Snapshot
local afterWatch -- { run, snap }: the last finished run, watched to the /reload
-- The after-watch's lines, written once: at the /reload, or when the next run
-- starts (in the test queue that's seconds later; it used to drop them, so a
-- queued test's errors after its DONE were never seen, 2026-11-25).
local function FlushAfter(upTo)
	local watch = afterWatch
	afterWatch = nil
	if not watch then return end
	local lines = Inspect(watch.run, watch.snap, "after the test:")
	Say(watch.run, ("errors after the test (DONE to %s): %d kind(s)%s"):format(upTo, #lines,
		#lines > 0 and "; list each in the reply with its owner" or ""))
	for _, line in ipairs(lines) do Say(watch.run, line) end
end
Kit.FlushAfterErrors = FlushAfter

-- The red error window held back while a run (or the test queue, between its
-- tests too) goes: it opened over the test's screenshots (the user,
-- 2026-11-25: "ruins the test"). Errors are still counted and logged; the
-- window opens when the run, or the whole queue, ends.
function ns.DevErrorWindowHeld()
	return (current and not current.stopped) or (CinematicDB and CinematicDB.testQueueRun) and true or false
end

-- Where an error came (ErrorWindow.lua stamps each one with it, in the window
-- and its saved deverror line): the test and step going, or between tests.
function ns.DevErrorContext()
	local run = current
	if run and not run.stopped then
		if run.step then
			return ("%s step %d/%d %s"):format(run.def.name, run.stepNumber or 0, #run.def.steps, tostring(run.step.key))
		end
		return run.def.name .. " setup"
	end
	if afterWatch then return "after " .. afterWatch.run.def.name .. "'s DONE" end
	if CinematicDB and CinematicDB.testQueueRun then return "test queue, between tests" end
	return nil
end
do
	local logout = CreateFrame("Frame")
	logout:RegisterEvent("PLAYER_LOGOUT")
	logout:SetScript("OnEvent", function()
		FlushAfter("/reload")
		-- (A run going at the reload, its Reload button: the error window
		-- starts empty after it, so what came before is inspected now.)
		local run = current
		if run and not run.stopped and run.errorSnap then
			local lines = Inspect(run, run.errorSnap, "during the test:")
			Say(run, ("errors during the test, to this reload: %d kind(s)"):format(#lines))
			for _, line in ipairs(lines) do Say(run, line) end
		end
	end)
end

-- The game's console, live: what the engine says while a run goes ------------
-- (CONSOLE_MESSAGE: Lua errors with their stack, Blizzard's own too, warnings,
-- "Test CVar test_cameraOverShoulder has been set to 0.02", "CVar ... failed
-- validation"; CVAR_UPDATE: each CVar change) as console: / cvar: lines in
-- the step they came in. Blizzard_Console gets them without -console too
-- (retail's saved history held our errors, 2026-11-20). The same line again
-- is counted, not logged (the counts at the end); at most CONSOLE_CAP lines a
-- run. A test's console = false leaves it out. (Tools/console-findings.md)
local CONSOLE_CAP = 150
local CONSOLE_KIND = { [3] = "console error: ", [4] = "console warning: " }
local consoleWatch = CreateFrame("Frame")

local function Plain(value)
	if IsSecret(value) then return "secret" end
	local text = tostring(value):gsub("\r?\n+$", ""):gsub("\r?\n", " | ")
	return #text > 400 and (text:sub(1, 400) .. "...") or text
end

-- (key: what makes two lines "the same". A CVar's changes are one key per
-- CVar, a console line's one per its words with the numbers taken out: Shoulder
-- Cam wrote test_cameraOverShoulder ~80 times in one wait (platematch,
-- 2026-11-23), each value its own line before. The first is logged, the rest
-- counted, the last kept for the end line.)
local function ConsoleLine(run, text, key)
	key = key or text
	local seen = run.consoleSeen
	run.consoleLast[key] = text
	if seen[key] then
		seen[key] = seen[key] + 1
		run.consoleRepeats = run.consoleRepeats + 1
		return
	end
	seen[key] = 1
	if run.consoleLines >= CONSOLE_CAP then
		run.consoleOver = run.consoleOver + 1
		return
	end
	run.consoleLines = run.consoleLines + 1
	Say(run, "  " .. text)
end

consoleWatch:SetScript("OnEvent", function(_, event, a, b)
	local run = current
	if not (run and run.consoleSeen and not run.stopped) then return end
	if event == "CVAR_UPDATE" then
		ConsoleLine(run, ("cvar: %s = %s"):format(Plain(a), Plain(b)), "cvar: " .. Plain(a))
	else
		local text = (CONSOLE_KIND[b] or "console: ") .. Plain(a)
		ConsoleLine(run, text, (text:gsub("%-?%d+%.?%d*", "#")))
	end
end)

local function ConsoleStart(run)
	if run.def.console == false then return end
	run.consoleSeen, run.consoleLast, run.consoleLines, run.consoleRepeats, run.consoleOver = {}, {}, 0, 0, 0
	pcall(consoleWatch.RegisterEvent, consoleWatch, "CONSOLE_MESSAGE")
	pcall(consoleWatch.RegisterEvent, consoleWatch, "CVAR_UPDATE")
end

-- The end: how many, and the lines that came more than once.
local function ConsoleEnd(run)
	consoleWatch:UnregisterAllEvents()
	if not run.consoleSeen then return end
	local text = ("console: %d line(s) logged, %d repeat(s) counted, %d over the cap"):format(run.consoleLines,
		run.consoleRepeats, run.consoleOver)
	local many = {}
	for key, n in pairs(run.consoleSeen) do
		if n > 1 then many[#many + 1] = { line = run.consoleLast[key] or key, n = n } end
	end
	table.sort(many, function(x, y) return x.n > y.n end)
	-- (Each with its last value: "x80 cvar: test_cameraOverShoulder = 0.02".)
	for i = 1, math.min(5, #many) do text = text .. ("; x%d %s"):format(many[i].n, many[i].line:sub(1, 120)) end
	Say(run, text)
end

-- The console's own words for a test's consoleWords (context line): each
-- CVar or command whose name has the word, a CVar with its value, default
-- and flags (C_CVar.GetCVarInfo), its help line if it has one.
local CONSOLE_WORD_CAP = 40
local function ConsoleWords(words, parts)
	local all = _G.ConsoleGetAllCommands
	if not all then
		parts[#parts + 1] = "console words: no ConsoleGetAllCommands on this client"
		return
	end
	local ok, list = pcall(all)
	if not ok or type(list) ~= "table" then
		parts[#parts + 1] = "console words: ConsoleGetAllCommands failed: " .. tostring(list)
		return
	end
	local info = (C_CVar and C_CVar.GetCVarInfo) or _G.GetCVarInfo
	for _, word in ipairs(words) do
		local want, found = tostring(word):lower(), {}
		for _, c in ipairs(list) do
			if type(c) == "table" and type(c.command) == "string" and c.command:lower():find(want, 1, true) then
				found[#found + 1] = c
			end
		end
		table.sort(found, function(x, y) return x.command:lower() < y.command:lower() end)
		parts[#parts + 1] = ("console word %q: %d match(es)%s"):format(want, #found,
			#found > CONSOLE_WORD_CAP and (", first " .. CONSOLE_WORD_CAP) or "")
		for i = 1, math.min(#found, CONSOLE_WORD_CAP) do
			local c = found[i]
			local line
			if c.commandType == 0 and info then
				local got = { pcall(info, c.command) }
				if got[1] then
					local flags = {}
					local names = { "account", "character", "locked", "secure", "read-only" }
					for k = 4, 8 do if got[k] then flags[#flags + 1] = names[k - 3] end end
					line = ("  %s = %s (default %s%s)"):format(c.command, Plain(got[2]), Plain(got[3]),
						#flags > 0 and (", " .. table.concat(flags, ", ")) or "")
				else
					line = ("  %s (CVar, info failed)"):format(c.command)
				end
			else
				line = ("  %s (%s)"):format(c.command, c.commandType == 0 and "CVar" or "command")
			end
			if type(c.help) == "string" and c.help ~= "" then line = line .. " " .. ("%q"):format(Plain(c.help)) end
			parts[#parts + 1] = line
		end
	end
end
Kit.ConsoleWords = ConsoleWords

-- Undo: saved before the first change, put back at the end or next login ---

local function UndoKey(def) return def.key .. "Undo" end

local readyRecipes = {} -- (other addons' ready recipes: Kit.DefineAddonReady, below)

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
	-- (What an addon's ready recipe changed, whichever test made it ready.)
	for key in pairs(undo.extra or {}) do
		local addon = type(key) == "string" and key:match("^ready:(.+)$")
		local recipe = addon and readyRecipes[addon]
		if recipe and recipe.putBack then
			local ok, text = pcall(recipe.putBack, undo.extra)
			said[#said + 1] = ok and tostring(text or (addon .. " put back")) or (addon .. " put back failed: " .. tostring(text))
		end
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

-- Another addon set up for a test (the user, 2026-11-25: "even just getting
-- the addon to work or set it up for a test can take me hours ... the test
-- kits should set that up for me or guide me"). /addon-support learns how
-- the addon works (Tools/addon-kit/addons/<Addon>.md) and writes its recipe
-- once, next to its support test:
--   ns.TestKit.DefineAddonReady("Guidelime", {
--     about = "a guide loaded with a step the arrow points to", -- what "ready" means
--     ready = function() return ok, "why not" end,  -- set up, so its frames show
--     make = function(r) ... end,   -- sets it up itself: its own calls, its saved
--                                   -- settings (r:Keep what it changes, putBack it)
--     putBack = function(extra) ... end, -- undoes make (gets the run's r:Keep values)
--     guide = { "Open its window: ...", "Click ..." }, -- your clicks, when make can't
--   })
-- r:AddonReady(addon) in a step: ready already, or made ready, or the guide's
-- numbered clicks in the box till ready() says so (Can't do it = a FAIL that
-- says why). Every addon test calls it before it checks frames: the addon
-- kit's stages, each support test's setup. Its putBack runs at the end of
-- whichever test made it ready.
function Kit.DefineAddonReady(addon, recipe)
	assert(type(addon) == "string" and type(recipe) == "table" and recipe.ready, "DefineAddonReady needs an addon and ready()")
	readyRecipes[addon:lower()] = recipe
end
function Kit.AddonReadyRecipe(addon) return addon and readyRecipes[addon:lower()] end

function Run:AddonReady(addon)
	local recipe = Kit.AddonReadyRecipe(addon)
	if not recipe then
		Say(self, ("  ready %s: no ready recipe (run /addon-support %s to write one: its frames may not show)"):format(addon, addon))
		return nil
	end
	local function Ready()
		local ok, yes, why = pcall(recipe.ready)
		if not ok then return false, "ready() error: " .. tostring(yes) end
		return yes and true or false, why
	end
	if ns.AddonUp and not ns.AddonUp(addon) then
		return self:Fail(("%s ready: it isn't loaded"):format(addon))
	end
	local yes, why = Ready()
	if yes then
		Say(self, ("  ready %s: already (%s)"):format(addon, recipe.about or "set up"))
		return self:Pass(addon .. " ready: " .. (recipe.about or "set up"))
	end
	Say(self, ("  ready %s: not yet (%s)"):format(addon, tostring(why)))
	if recipe.make then
		self:Keep("ready:" .. addon:lower(), true) -- (so its putBack runs after this test)
		recipe.make(self)
		yes, why = Ready()
		Say(self, ("  ready %s: after its setup %s (%s)"):format(addon, yes and "ready" or "not yet", tostring(why)))
	end
	if not yes and recipe.guide then
		local lines = {}
		for i, line in ipairs(recipe.guide) do lines[#lines + 1] = i .. ". " .. line end
		local _, label = self:WaitFor(("Set %s up for the test (%s):\n%s\nIt goes on by itself once it's done."):format(
			addon, recipe.about or "so its frames show", table.concat(lines, "\n")),
			{ check = function() return (Ready()) end, buttons = { "Can't do it" } })
		if label == "Can't do it" then
			return self:Fail(("%s ready: you couldn't (%s; still %s)"):format(addon, recipe.about or "set up", tostring(select(2, Ready()))))
		end
		yes, why = Ready()
	end
	return self:Verdict(yes, ("%s ready: %s%s"):format(addon, recipe.about or "set up", yes and "" or (" (" .. tostring(why) .. ")")))
end

-- Buttons under the box ---------------------------------------------------------
-- Clicks instead of typed commands (the user, 2026-11-21: "instead of type
-- /cine debug skip add a button"). A row at a fixed spot just above the box
-- (anchored to the screen, not the box: a secure button hung on our frame
-- would lock it in fights). Every step has Skip step and Stop; a prompt adds
-- its own. An entry: "Yes" (an answer: the wait returns "button", "Yes"),
-- { label = , fn = } (does something, the wait goes on), or a game action
-- the player's click does through a secure button, so nothing is tainted:
--   { kind = "editmode" }  opens Edit Mode (/editmode as a macro)
--   { kind = "reload" }    /reload; the run picks up again at the next step
--   { kind = "targetself" } targets you (/target player; TargetUnit is protected)
-- Secure buttons are made, shown and hidden out of fights only (protected).
local BAR_Y, GAP = -78, 8
local holder, plain, secure = nil, {}, {}
local SECURE = {
	editmode = { label = "Open Edit Mode", macro = "/editmode" },
	reload = { label = "Reload", macro = "/reload" },
	targetself = { label = "Target yourself", macro = "/target player" },
}
local function Holder()
	if holder then return holder end
	holder = CreateFrame("Frame")
	holder:SetFrameStrata("FULLSCREEN_DIALOG")
	holder:SetSize(10, 30)
	holder:SetPoint("TOP", UIParent, "TOP", 0, BAR_Y)
	return holder
end
local function SecureButton(kind)
	if secure[kind] then return secure[kind] end
	if InCombatLockdown() then return nil end
	local want = SECURE[kind]
	local ok, button = pcall(CreateFrame, "Button", nil, Holder(), "SecureActionButtonTemplate, UIPanelButtonTemplate")
	if not ok or not button then return nil end
	button:SetAttribute("type", "macro")
	button:SetAttribute("macrotext", want.macro)
	button:SetAttribute("useOnKeyDown", false)
	button:RegisterForClicks("LeftButtonUp")
	button:SetText(want.label)
	button:SetScript("PreClick", function(self) if self.preClick then pcall(self.preClick) end end)
	button:Hide()
	secure[kind] = button
	return button
end
local function PlainButton(i)
	if plain[i] then return plain[i] end
	local button = CreateFrame("Button", nil, Holder(), "UIPanelButtonTemplate")
	button:SetScript("OnClick", function(self) if self.onClick then self.onClick() end end)
	plain[i] = button
	return button
end
-- What you're asked to click (Reload, Open Edit Mode, a prompt's answers):
-- big, under the box, a pulsing orange glow behind each (the user,
-- 2026-11-25: "reload needs to be more obvious ... when you need me to hit a
-- button it needs to be easily readable"; it was one of six small red
-- buttons above the box). Skip step / Stop / Stop queue... stay up top, small.
local BIG_W, BIG_H, BIG_FONT = 240, 46, 20
local bigHolder, glows = nil, {}
local function BigHolder()
	if bigHolder then return bigHolder end
	bigHolder = CreateFrame("Frame")
	bigHolder:SetFrameStrata("FULLSCREEN_DIALOG")
	bigHolder:SetFrameLevel(50)
	bigHolder:SetSize(10, BIG_H)
	bigHolder.t = 0
	bigHolder:SetScript("OnUpdate", function(self, dt)
		self.t = self.t + dt
		local a = 0.45 + 0.35 * math.sin(self.t * 4)
		for _, glow in pairs(glows) do if glow:IsShown() then glow:SetAlpha(a) end end
		-- (Under the box, wherever it sits: it moves down for a popup.)
		local box = ns.padTestBox
		local want = box and box:IsShown() and box or nil
		if self.anchor ~= want then
			self.anchor = want
			self:ClearAllPoints()
			if want then self:SetPoint("TOP", want, "BOTTOM", 0, -18) else self:SetPoint("TOP", UIParent, "TOP", 0, -300) end
		end
	end)
	bigHolder:SetPoint("TOP", UIParent, "TOP", 0, -300)
	return bigHolder
end
local function Glow(button)
	if glows[button] then return glows[button] end
	local glow = button:CreateTexture(nil, "BACKGROUND", nil, -8)
	glow:SetPoint("TOPLEFT", -7, 7)
	glow:SetPoint("BOTTOMRIGHT", 7, -7)
	glow:SetColorTexture(1, 0.6, 0.15, 1)
	glows[button] = glow
	return glow
end
local function Style(button, big)
	local label = button.GetFontString and button:GetFontString()
	if label then
		if not button.kitFont then
			local ok, font, size, flags = pcall(label.GetFont, label)
			if ok and font then button.kitFont = { font, size, flags } end
		end
		local f = button.kitFont
		if f then pcall(label.SetFont, label, f[1], big and BIG_FONT or f[2], f[3]) end
	end
	local glow = big and Glow(button) or glows[button]
	if glow then glow:SetShown(big and true or false) end
	local width = (label and label:GetStringWidth() or 60) + (big and 60 or 32)
	button:SetSize(big and math.max(BIG_W, width) or math.max(90, width), big and BIG_H or 26)
end

local function HideButtons()
	for _, button in ipairs(plain) do button:Hide() end
	if not InCombatLockdown() then for _, button in pairs(secure) do button:Hide() end end
	if holder then holder:Hide() end
	if bigHolder then bigHolder:Hide() end
end
Kit.HideButtons = HideButtons
-- (Whether this client has /editmode: logged on the context line.)
function Kit.HasEditModeSlash()
	local list = _G.hash_SlashCmdList
	return (list and list["/EDITMODE"]) ~= nil
end

-- The row: entries as above, laid left to right, centered. Returns the
-- buttons by label (offline checks click them). Old tests can use it too.
-- An entry is big (one you're asked to click) when it's a secure kind
-- (Reload, Open Edit Mode, Target yourself), or says big = true (a prompt's
-- answers, r:Click's button, the queue's Start anyway); the rest are the
-- small controls up top.
function Kit.ShowButtons(entries)
	HideButtons()
	local bar, bigBar = Holder(), BigHolder()
	bar:SetScale(UIParent:GetEffectiveScale())
	bigBar:SetScale(UIParent:GetEffectiveScale())
	local small, big, byLabel, n = {}, {}, {}, 0
	local fight = InCombatLockdown()
	for _, entry in ipairs(entries or {}) do
		if type(entry) == "string" then entry = { label = entry, big = true } end
		local button
		local isBig = entry.big or (entry.kind and SECURE[entry.kind]) and true or false
		if entry.kind and SECURE[entry.kind] then
			button = SecureButton(entry.kind)
			if button then button.preClick = entry.preClick end
		else
			n = n + 1
			button = PlainButton(n)
			button:SetText(entry.label or "?")
			button.onClick = entry.fn
		end
		if button then
			-- (A secure button moves between the rows out of fights only.)
			local parent = isBig and bigBar or bar
			if button:GetParent() ~= parent and not (fight and button.IsProtected and button:IsProtected()) then
				button:SetParent(parent)
			end
			isBig = button:GetParent() == bigBar
			Style(button, isBig)
			local list = isBig and big or small
			list[#list + 1] = button
			byLabel[entry.label or (SECURE[entry.kind] and SECURE[entry.kind].label) or "?"] = button
		end
	end
	local function Lay(row, buttons, gap)
		local width = 0
		for _, button in ipairs(buttons) do width = width + button:GetWidth() + gap end
		local x = -width / 2 + gap / 2
		for _, button in ipairs(buttons) do
			button:ClearAllPoints()
			button:SetPoint("LEFT", row, "CENTER", x, 0)
			x = x + button:GetWidth() + gap
			button:Show()
		end
		if #buttons > 0 then row:Show() end
	end
	Lay(bar, small, GAP)
	Lay(bigBar, big, 22)
	Kit.bigLabels = {}
	for label, button in pairs(byLabel) do
		if button:GetParent() == bigBar then Kit.bigLabels[#Kit.bigLabels + 1] = label end
	end
	table.sort(Kit.bigLabels)
	return byLabel
end

-- Your turn or hands off: said on every box, first, in its own color, the
-- box's edge in it too, and a sound only when it's your turn (the user,
-- 2026-11-25: "make sure it gives clear indication if it needs me to do
-- something"). run.mode is read by the test queue's panel.
local MODES = {
	you = { tag = "|cffffa733YOUR TURN|r", edge = { 1, 0.6, 0.15 } },
	off = { tag = "|cff7ab8ffHANDS OFF|r", edge = { 0.42, 0.66, 1 } },
}
Kit.MODES = MODES
local NAG_EVERY, NAG_TIMES = 45, 3
local function Ding()
	if PlaySound then pcall(PlaySound, type(SOUNDKIT) == "table" and SOUNDKIT.READY_CHECK or 8960) end
end
-- (The box's gold edge, found once: Frames.lua's ns.PadTestBox keeps no
-- handle to it; it's the box's one texture on BACKGROUND -1.)
local function BoxEdge(box)
	if not box then return nil end
	if box.kitEdge == nil then
		box.kitEdge = false
		local ok, regions = pcall(function() return { box:GetRegions() } end)
		for _, region in ipairs(ok and regions or {}) do
			local ok2, layer, sub = pcall(region.GetDrawLayer, region)
			if ok2 and layer == "BACKGROUND" and sub == -1 and region.SetColorTexture then box.kitEdge = region end
		end
	end
	return box.kitEdge or nil
end
local function SetMode(run, mode)
	if run.nag then run.nag:Cancel() run.nag = nil end
	run.mode = mode
	if Kit.onMode then pcall(Kit.onMode, run, mode) end
end

local function Box(run, text, sub, r, g, b, mode)
	ns.debugNoCopyWindow = true
	-- (A run from the test queue: which of the queue's tests this is, always.)
	if Kit.boxPrefix then
		local ok, prefix = pcall(Kit.boxPrefix)
		if ok and prefix then text = prefix .. text end
	end
	if mode and MODES[mode] then text = MODES[mode].tag .. "   " .. text end
	if ns.PadTestBox then
		ns.PadTestBox(text, sub, r, g, b)
		ns.padTestRun = run
		local edge = BoxEdge(ns.padTestBox)
		local color = (mode and MODES[mode] or { edge = { 1, 0.82, 0 } }).edge
		if edge then pcall(edge.SetColorTexture, edge, color[1], color[2], color[3], 1) end
	elseif ns.TestPrompt then
		ns.TestPrompt(text, 3600)
	end
end

-- The timers' line: this step's time, the run's, and what's left of a known length.
function Kit.Clock(run)
	local now = GetTime()
	local line = ("step %s    run %s"):format(ns.PadTestTime(now - (run.stepBegan or run.began or now)),
		ns.PadTestTime(now - (run.began or now)))
	if run.expectEnd then
		local left = run.expectEnd - now
		line = line .. (left > 0 and ("    about %s left"):format(ns.PadTestTime(left)) or "    any moment now")
	end
	return line
end

-- The run's row: the prompt's own buttons, then Skip step and Stop.
function Run:Buttons(extra)
	local run, entries = self, {}
	for _, entry in ipairs(extra or {}) do
		if type(entry) == "string" then entry = { label = entry, answer = entry } end
		local mine = {}
		for k, v in pairs(entry) do mine[k] = v end
		-- (What the prompt asks you to click: big, under the box.)
		if mine.answer or mine.click or mine.kind then mine.big = true end
		if mine.answer then
			mine.fn = function()
				Say(run, "  clicked: " .. mine.answer)
				if run.waiting and run.waiting.answer then run.waiting.answer("button", mine.answer) end
			end
		elseif mine.click then
			-- (r:Click: its call runs in the click itself, a hardware event,
			-- then the wait resumes with what it returned.)
			local click = mine.click
			mine.fn = function()
				Say(run, "  clicked: " .. tostring(mine.label))
				local results = { pcall(click, run) }
				if not results[1] then Say(run, "  its call failed: " .. tostring(results[2])) end
				if run.waiting and run.waiting.answer then run.waiting.answer("button", mine.label, results) end
			end
		elseif mine.kind == "reload" then
			mine.preClick = function() run:SaveResume() end
		elseif mine.kind then
			mine.preClick = function() Say(run, "  clicked: " .. mine.kind) end
		elseif mine.fn then
			local fn = mine.fn
			mine.fn = function()
				Say(run, "  clicked: " .. tostring(mine.label))
				local ok, err = pcall(fn, run)
				if not ok then Say(run, "  its button failed: " .. tostring(err)) end
			end
		end
		entries[#entries + 1] = mine
	end
	if run.step then entries[#entries + 1] = { label = "Skip step", fn = function() run:SkipStep() end } end
	entries[#entries + 1] = { label = "Stop", fn = function() Kit.Finish(run, false) end }
	-- (A run from the test queue, Dev/TestQueue.lua: stops the rest too.)
	if Kit.queueStop then entries[#entries + 1] = { label = "Stop queue", fn = function() Kit.queueStop(run) end } end
	-- (Messed it up: this one stopped, unrecorded, and run again at the queue's end.)
	if Kit.queueRequeue then entries[#entries + 1] = { label = "Requeue", fn = function() Kit.queueRequeue(run) end } end
	-- (Something wrong with the test itself: say so, with its step. The
	-- report box is the test queue's, Dev/TestQueue.lua.)
	if Kit.reportIssue then entries[#entries + 1] = { label = "Report issue", fn = function() Kit.reportIssue(run) end } end
	self.buttons = Kit.ShowButtons(entries)
	local labels = {}
	for label in pairs(self.buttons) do labels[#labels + 1] = label end
	table.sort(labels)
	return labels
end

-- handsOff: the box only says what the test does (a wait on the game, a
-- timed watch); words saying "hands off" count too. Else it's your turn.
function Run:Prompt(text, sub, seconds, buttons, handsOff)
	if seconds then self.expectEnd = GetTime() + seconds else self.expectEnd = nil end
	text = tostring(text)
	local mode = (handsOff or text:lower():find("hands off", 1, true)) and "off" or "you"
	SetMode(self, mode)
	if mode == "you" then
		-- (A sound, so it's not missed (the side-by-side run 10 waited 2.5
		-- minutes for a click nobody knew was due), and again every 45 s while
		-- it waits on you with no time limit, three times at most.)
		Ding()
		if not seconds and C_Timer.NewTicker then
			local run, times = self, 0
			self.nag = C_Timer.NewTicker(NAG_EVERY, function()
				times = times + 1
				if current ~= run or run.stopped or run.mode ~= "you" or not run.waiting or times > NAG_TIMES then
					if run.nag then run.nag:Cancel() run.nag = nil end
					return
				end
				Ding()
			end)
		end
	end
	local n = self.step and self.stepNumber or 0
	-- (Out of all the test's steps, not the ones left: after a reload it's
	-- picked up with those only, and showed "step 4/2", loadparts 2026-11-22.)
	local labels = self:Buttons(buttons)
	local default = mode == "you" and "Your turn. No time limit." or "Nothing to do: the test does this. No time limit."
	if mode == "off" and seconds then default = "Nothing to do: the test does this." end
	-- (The big buttons named on the box: "Your turn: click Reload below.")
	local big = Kit.bigLabels or {}
	if #big > 0 and mode == "off" then
		-- (A button to click is never hands off.)
		mode = "you"
		SetMode(self, mode)
		Ding()
	end
	if #big > 0 then
		default = ("Your turn: click %s below."):format(#big == 1 and big[1]
			or (table.concat(big, ", ", 1, #big - 1) .. " or " .. big[#big]))
	end
	Box(self, ("%s, step %d/%d: %s"):format(self.def.title, n, #self.def.steps, text), sub or default,
		mode == "you" and 1 or 0.6, mode == "you" and 0.82 or 0.9, mode == "you" and 0 or 1, mode)
	Say(self, ("  %s: %s%s"):format(mode == "you" and "asked" or "hands off", text,
		buttons and (" [buttons: " .. table.concat(labels, ", ") .. "]") or ""))
	self.asked = text -- (the report box shows it)
end

-- A call the game only takes from your click (a hardware event):
-- SendChatMessage and other protected-from-timers calls. Made from a step
-- they run in a timer's resume() and the game blocks them ("blocked:
-- resume()", levelemote run 2). The box asks for the click; fn(r) runs in
-- the click; returns pcall's results (ok, ...). No time limit.
function Run:Click(text, fn, label)
	label = label or "Do it"
	local _, _, results = self:WaitFor(text, { buttons = { { label = label, click = fn } } })
	if type(results) ~= "table" then return false, "skipped" end
	return unpack(results)
end

-- Skip step: the step's wait or sleep dropped, a SKIP, on to the next one.
function Run:SkipStep()
	if self.stopped or not self.step then return end
	if self.waiting then
		if self.waiting.frame then self.waiting.frame:UnregisterAllEvents() end
		if self.waiting.ticker then self.waiting.ticker:Cancel() end
		self.waiting = nil
	end
	HideBacks()
	self.co = nil
	self:Skip("skipped by you (the Skip step button)")
	self:Next()
end

-- Before a Reload click: the rest of the steps kept, picked up at login.
function Run:SaveResume()
	local rest = {}
	for i = (self.index or 0) + 1, #self.steps do rest[#rest + 1] = self.steps[i].number end
	CinematicDB[self.def.key .. "Resume"] = { steps = table.concat(rest, " "), pass = self.pass, fail = self.fail,
		skip = self.skip, verdicts = self.verdicts, full = self.full or nil }
	Say(self, ("  reload clicked: picks up at login with step(s) %s"):format(#rest > 0 and table.concat(rest, " ") or "none"))
end

-- Waits (yields) the step's coroutine; the C_Timer resumes it.
function Run:Sleep(seconds)
	local co = self.co
	C_Timer.After(seconds, function() if current == self and not self.stopped and self.co == co then self:Resume(co) end end)
	return coroutine.yield()
end

-- A plain solid panel behind the frames a shot is about, so they read
-- clearly against the busy world (the user, 2026-11-21: "this helps a lot").
-- Anchored to each frame (nothing read off it: works with secret places),
-- one strata under it, padded; hidden again right after the shot.
backs = {}
local BACK_COLOR = { 0.08, 0.08, 0.1, 1 }
local STRATA_BELOW = { TOOLTIP = "FULLSCREEN_DIALOG", FULLSCREEN_DIALOG = "FULLSCREEN", FULLSCREEN = "DIALOG",
	DIALOG = "HIGH", HIGH = "MEDIUM", MEDIUM = "LOW", LOW = "BACKGROUND" }
local function ShowBacks(frames, pad, color)
	local shown = 0
	for i, frame in ipairs(frames) do
		local back = backs[i]
		if not back then
			back = CreateFrame("Frame", nil, UIParent)
			back.fill = back:CreateTexture(nil, "BACKGROUND")
			back.fill:SetAllPoints(back)
			backs[i] = back
		end
		local ok = pcall(function()
			back:ClearAllPoints()
			back:SetPoint("TOPLEFT", frame, "TOPLEFT", -pad, pad)
			back:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", pad, -pad)
			local strata = frame:GetFrameStrata()
			back:SetFrameStrata(STRATA_BELOW[strata] or strata)
			if not STRATA_BELOW[strata] then back:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1)) end
			back.fill:SetColorTexture(unpack(color))
			back:Show()
		end)
		if ok then shown = shown + 1 else back:Hide() end
	end
	return shown
end
HideBacks = function()
	for _, back in ipairs(backs) do back:Hide() back:ClearAllPoints() end
end

-- A paced screenshot. opts (optional):
--   behind = frame or { frames }  a solid panel behind each, for this shot only
--   pad = 12, color = { r, g, b, a }
function Run:Shot(label, opts)
	opts = opts or {}
	local behind = opts.behind
	if behind and type(behind) ~= "table" or (behind and behind.GetObjectType) then behind = { behind } end
	local backed = behind and ShowBacks(behind, opts.pad or 12, opts.color or BACK_COLOR) or 0
	-- (Out of the shot: the test queue's panel and the red error window.)
	if Kit.onShot then pcall(Kit.onShot, true) end
	if ns.DevErrorWindowHide then pcall(ns.DevErrorWindowHide) end
	self:Sleep(SHOT_BEFORE)
	local ok = pcall(function() Screenshot() end)
	Say(self, ("  screenshot %s: WoWScrnShot_%s%s%s"):format(tostring(label), date("%m%d%y_%H%M%S"),
		ok and "" or " (failed)", behind and (" (background behind %d of %d frame(s))"):format(backed, #behind) or ""))
	self:Sleep(SHOT_AFTER)
	if Kit.onShot then pcall(Kit.onShot, false) end
	if behind then HideBacks() end
end

-- Waits for the user (or the game) with no time limit. opts:
--   events = { "UNIT_COMBAT", ... }  resume on one of these (filter(event, ...)
--                                    returning true picks which)
--   check = function() ... end       or polled every 0.2 s till it's truthy
--   buttons = { "Yes", "No", { kind = "editmode" }, ... }  on the row (see
--                                    Kit.ShowButtons); an answer wakes it
-- Returns what woke it: the event and its args, check's value, or "button", label.
function Run:WaitFor(text, opts)
	opts = opts or {}
	if text then self:Prompt(text, nil, opts.seconds, opts.buttons, opts.handsOff)
	elseif opts.buttons then self:Buttons(opts.buttons) end
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
	self.waiting = { frame = waiter, ticker = ticker, answer = Done }
	local started = GetTime()
	local results = { coroutine.yield() }
	Say(self, ("  got it after %.1f s: %s"):format(GetTime() - started, Shown(results[1])))
	return unpack(results)
end

function Run:Resume(co, ...)
	if co ~= self.co or coroutine.status(co) ~= "suspended" then return end
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		local stack = ""
		pcall(function() stack = debugstack(co, 0, 6, 0) or "" end)
		self.fail = self.fail + 1
		self.verdicts[#self.verdicts + 1] = "FAIL Lua error: " .. tostring(err)
		Say(self, "  verdict FAIL Lua error in the test: " .. tostring(err) .. " " .. stack:gsub("\n", " | "))
		Kit.Finish(self, false)
	elseif coroutine.status(co) == "dead" and current == self and not self.stopped and self.co == co then
		self:Next()
	end
end

-- The next picked step, in a coroutine of its own (so Skip step can drop one).
function Run:Next()
	if self.stopped or current ~= self then return end
	StepErrorsClose(self) -- (the step just ended, or the setup)
	self.index = (self.index or 0) + 1
	local picked = self.steps[self.index]
	if not picked then
		self.step, self.co = nil, nil
		return Kit.Finish(self, true)
	end
	local run, step = self, picked.step
	run.step, run.stepNumber = step, picked.number
	run.stepBegan, run.expectEnd = GetTime(), step.seconds and (GetTime() + step.seconds) or nil
	StepErrorsOpen(run)
	run.co = coroutine.create(function()
		local e0, b0 = Counts()
		Say(run, ("step %d %s: %s | %s"):format(picked.number, step.key, step.title or step.say or "", StateLine()))
		if step.say then run:Prompt(step.say, nil, step.seconds, step.buttons, step.handsOff) else
			SetMode(run, "off")
			Box(run, ("%s, step %d/%d: %s"):format(run.def.title, picked.number, #run.def.steps, step.title or step.key),
				"Nothing to do: the test does this one.", 0.6, 0.9, 1, "off")
			run:Buttons(step.buttons)
		end
		step.run(run)
		local e1, b1 = Counts()
		Say(run, ("  step %s end: errors +%d, blocked +%d"):format(step.key, e1 - e0, b1 - b0))
		if b1 > b0 and step.blockedOk then
			-- (A step that blocks on purpose, a control: said, not failed.)
			Say(run, ("  %d blocked action(s), on purpose in this step (blockedOk)"):format(b1 - b0))
		elseif b1 > b0 then
			run:Fail(("%d blocked action(s) in this step"):format(b1 - b0))
			-- (The game names the blocked call resume() when a step made a
			-- click-only call from a timer: say what to use instead.)
			if run.blockedResume then
				Say(run, "  (blocked resume(): a call that needs your click ran from the step; give it r:Click)")
			end
		end
		run.blockedResume = nil
	end)
	run:Resume(run.co)
end

-- Running ----------------------------------------------------------------------

-- (And no AFK camera while a test runs: standing through a hands-off step
-- started it, and it paused what the test checked (Keep the shoulder, the
-- side-by-side run 8, 2026-11-21). Its still timer kept fresh each second.)
local function KeepCineOff(run)
	if ns.stillSince then ns.stillSince = GetTime() end
	-- (run.cineAllowed: a step that turns CineMode on itself, to test in it.)
	if run.def.cineMode or run.cineAllowed or not ns.IsCineModeOn then return end
	if ns.IsCineModeOn() and Cinematic_ToggleCineMode then
		pcall(Cinematic_ToggleCineMode)
		Say(run, "  CineMode came on: turned off again for the test")
	end
end

-- The context lines (def: settings, cvars, context; run: for its context
-- function). Dev/TestKitWrap.lua puts them on the old tests' logs too.
function Kit.ContextLines(def, run)
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
	parts[#parts + 1] = "kit buttons: /editmode slash " .. tostring(Kit.HasEditModeSlash())
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
	if _G.ConsoleIsActive then parts[#parts + 1] = "console window open " .. Try(_G.ConsoleIsActive) end
	if def.consoleWords then ConsoleWords(def.consoleWords, parts) end
	if def.context then
		local ok, text = pcall(def.context, run)
		parts[#parts + 1] = ok and tostring(text) or ("own context failed: " .. tostring(text))
	end
	return parts
end
Kit.Counts = Counts

local function ContextLine(run)
	for _, part in ipairs(Kit.ContextLines(run.def, run)) do Say(run, part) end
end

-- Every window closed (the game's, the settings, bags, Cinematic's that Escape
-- closes), as a test starts and as it ends: each test opens what it needs,
-- the next starts clean (the user, 2026-11-25: Reload's "keep windows open"
-- brought the last test's windows back). Not in a fight (Forever's gamepad
-- code blocks panels hidden from our code there): left as they are.
local function CloseWindows(run, when)
	if InCombatLockdown() then
		Say(run, ("  windows left as they are (%s): in a fight"):format(when))
		return
	end
	if SettingsPanel and SettingsPanel:IsShown() then pcall(HideUIPanel, SettingsPanel)
	elseif InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then pcall(HideUIPanel, InterfaceOptionsFrame) end
	if CloseAllWindows then pcall(CloseAllWindows) end
	if CloseAllBags then pcall(CloseAllBags) end
	Kit.windowsClosed = (Kit.windowsClosed or 0) + 1 -- (the offline check's)
end

-- (QoL/Reload.lua: a run or the test queue going, its "keep windows open"
-- keeps nothing for after a reload.)
function ns.TestKitHoldsWindows()
	return (current and not current.stopped) and true or (CinematicDB and CinematicDB.testQueueRun) and true or false
end

function Kit.Finish(run, done)
	if current ~= run or run.stopped then return end
	run.stopped = true
	if run.waiting then
		if run.waiting.frame then run.waiting.frame:UnregisterAllEvents() end
		if run.waiting.ticker then run.waiting.ticker:Cancel() end
	end
	if run.cineTicker then run.cineTicker:Cancel() end
	if run.nag then run.nag:Cancel() run.nag = nil end
	HideBacks() -- (a stop in the middle of a shot)
	HideButtons()
	StepErrorsClose(run) -- (the last step's, or a stopped one's)
	if run.def.finish then
		run.stepSnap, run.stepLabel = Snapshot(), "finish"
		local ok, err = pcall(run.def.finish, run)
		if not ok then Say(run, "  own finish failed: " .. tostring(err)) end
		StepErrorsClose(run)
	end
	CloseWindows(run, "end")
	ConsoleEnd(run)
	Say(run, "put back: " .. PutBack(run.def))
	local errors, blocked = Counts()
	local summary = ("%s: %d pass, %d fail, %d skip; errors +%d, blocked +%d"):format(done and "DONE" or "STOPPED",
		run.pass, run.fail, run.skip, errors - run.errors0, blocked - run.blocked0)
	Say(run, summary)
	-- Which errors, and whose (each entry that grew during the run).
	local inspected, grown = Inspect(run, run.errorSnap or {}, "during the test:")
	Say(run, ("errors during the test: %d kind(s)%s"):format(#inspected,
		#inspected > 0 and "; read each, list them in the reply, get every one fixed (whoever's it is)" or ""))
	for _, line in ipairs(inspected) do Say(run, line) end
	-- (For the test queue's panel and summary: each error, its count, place, owner and step.)
	run.errorList = {}
	for i, g in ipairs(grown) do
		run.errorList[i] = { kind = g.kind, count = g.count, where = g.where and tostring(g.where) or nil,
			mine = g.mine, message = g.message, first = g.first }
	end
	afterWatch = { run = run, snap = Snapshot() }
	Say(run, "verdicts: " .. table.concat(run.verdicts, "; "))
	current = nil
	local title = run.def.title
	-- (The timers stop on the run's time.)
	local took = ns.PadTestTime(GetTime() - (run.began or GetTime()))
	if ns.PadTestBoxClock then ns.PadTestBoxClock(function() return "took " .. took end) end
	if Kit.queueStop then
		-- (In the test queue: its own box says what's next; "/reload" here
		-- read as the end of the queue while more were to come, 2026-11-23.)
	elseif done then
		Box(run, ("%s DONE: %d pass, %d fail, %d skip."):format(title, run.pass, run.fail, run.skip),
			"/reload, then say \"check log\".", run.fail > 0 and 1 or 0.3, run.fail > 0 and 0.4 or 1, 0.3)
	else
		Box(run, title .. " stopped.", "Your settings are put back. /reload, then say \"check log\".", 1, 0.6, 0.3)
	end
	ns.Print(("%s %s"):format(title, summary))
	-- (The held error window, if errors came: not in the queue, which opens it at its end.)
	if not Kit.queueStop and ns.DevErrorWindowRelease then ns.DevErrorWindowRelease() end
	C_Timer.After(60, function() if not current and ns.PadTestBoxHide then ns.PadTestBoxHide(run) end end)
	-- (The test queue, Dev/TestQueue.lua: records it and starts the next.)
	if Kit.onFinish then
		local ok, err = pcall(Kit.onFinish, run, done, summary)
		if not ok then ns.Print("test queue: " .. tostring(err)) end
	end
end

-- The steps to run: the numbers given, else every step not proven (all with
-- "full"). Also whether it's a full run, and the proven ones left out.
local function Pick(def, arg)
	local wanted, steps, left = {}, {}, {}
	local full = (arg or ""):find("full") ~= nil
	-- (Whole words only: an addon kit run's "Bartender4" isn't step 4.)
	for word in (arg or ""):gmatch("%S+") do
		if word:match("^%d+$") then wanted[tonumber(word)] = true end
	end
	for i, step in ipairs(def.steps) do
		if next(wanted) then
			if wanted[i] then steps[#steps + 1] = { step = step, number = i } end
		elseif step.proven and not full then
			left[#left + 1] = ("%s (%s)"):format(step.key, step.proven)
		else
			steps[#steps + 1] = { step = step, number = i }
		end
	end
	return steps, full, left
end

-- The steps a run of this test with these words would take: { { number, key } },
-- for the test queue's "needs you" (only the steps that run count).
function Kit.StepPlan(name, arg)
	local def = defs[name]
	if not def then return nil end
	local steps = Pick(def, arg)
	local out = {}
	for i, picked in ipairs(steps) do out[i] = { number = picked.number, key = picked.step.key } end
	return out
end

-- What a control on a settings page overlaps there (or runs past root's
-- edges): every other visible
-- control (button, tab, check box, slider, edit box) and every visible line
-- of text under root, with its name or words. Its own parts and the frames
-- it sits in don't count. (Load Style sat on the Themes tab, 2026-11-22, and
-- no test looked: every placed control gets this, in every state of its page.)
-- Returns a list of "what (where)" strings; empty: clear.
local OVERLAP_KINDS = { Button = true, CheckButton = true, Slider = true, EditBox = true }
function Run:Overlaps(frame, root, also)
	local hits = {}
	if not (frame and root and frame.GetLeft) then return { "nothing to check" } end
	-- (Offline stand-ins place every frame alike: no layout to judge there.)
	if ns.noRealLayout then
		Say(self, "  overlaps: no real layout here (offline), not judged")
		return hits
	end
	local function Box(f)
		local l, r, tp, b = f:GetLeft(), f:GetRight(), f:GetTop(), f:GetBottom()
		if not (l and r and tp and b) then return nil end
		local s = f:GetEffectiveScale()
		return l * s, r * s, tp * s, b * s
	end
	local mine = {}
	local function Mark(f)
		if not f or mine[f] then return end
		mine[f] = true
		-- (A font string or texture given: it has no regions or children.)
		if not f.GetChildren then return end
		for _, region in ipairs({ f:GetRegions() }) do mine[region] = true end
		for _, child in ipairs({ f:GetChildren() }) do Mark(child) end
	end
	Mark(frame)
	for _, extra in ipairs(also or {}) do Mark(extra) end
	local up = frame:GetParent()
	while up do mine[up] = true; up = up:GetParent() end
	local L1, R1, T1, B1 = Box(frame)
	if not L1 then return { "the control has no place yet" } end
	-- (Its own label beside it: a check box's Text reaches past the box.)
	for _, extra in ipairs(also or {}) do
		local l, r, tp, b = Box(extra)
		if l then L1, R1, T1, B1 = math.min(L1, l), math.max(R1, r), math.max(T1, tp), math.min(B1, b) end
	end
	local function Hit(f)
		local l, r, tp, b = Box(f)
		return l and l < R1 - 1 and r > L1 + 1 and b < T1 - 1 and tp > B1 + 1
	end
	local function Name(f)
		local text = f.GetText and f:GetText()
		if type(text) == "string" and text ~= "" then return ("%q"):format(text:sub(1, 30)) end
		return f:GetName() or f:GetObjectType()
	end
	local function Walk(f)
		for _, region in ipairs({ f:GetRegions() }) do
			if not mine[region] and region:GetObjectType() == "FontString" and region:IsVisible()
				and (region:GetText() or "") ~= "" and Hit(region) then
				hits[#hits + 1] = "text " .. Name(region)
			end
		end
		for _, child in ipairs({ f:GetChildren() }) do
			if child:IsVisible() and not mine[child] then
				if OVERLAP_KINDS[child:GetObjectType()] and Hit(child) then
					hits[#hits + 1] = child:GetObjectType():lower() .. " " .. Name(child)
				end
				Walk(child)
			elseif child:IsVisible() and child ~= frame then
				Walk(child)
			end
		end
	end
	Walk(root)
	-- (And past the edge of what it's checked in: Load Style on an off card
	-- hung over the card's bottom border, 2026-11-22, and nothing it covered.)
	local l, rr, tp, b = Box(root)
	if l and (L1 < l - 1 or R1 > rr + 1 or T1 > tp + 1 or B1 < b - 1) then
		hits[#hits + 1] = ("past the edge of %s (by %d px)"):format(Name(root),
			math.floor(math.max(l - L1, R1 - rr, T1 - tp, b - B1) + 0.5))
	end
	return hits
end

-- In a step: true (and logged) when this check is proven and the run isn't
-- full, so the caller leaves it out; false when it should run.
function Run:Proven(what)
	if self.full then return false end
	Say(self, "  proven, not checked again: " .. tostring(what))
	return true
end

function Kit.Start(name, arg, resume)
	local def = defs[name]
	if not (def and CinematicDB and ns.db) then return end
	if current and current.stopped then current = nil end -- (one that ended without Finish)
	if current then
		local same = current.def == def
		Kit.Finish(current, false)
		if same then return end -- (typed again: that was the stop)
	end
	if arg == "restore" then
		ns.Print(def.title .. ": " .. PutBack(def))
		return
	end
	-- The last run's errors after its DONE, into its own log (before this run
	-- clears it: the same test queued twice).
	FlushAfter("the next test's start")
	if ns.DevErrorWindowHide then ns.DevErrorWindowHide() end -- (out of the shots)
	-- The run before kept, so a rerun doesn't lose it; a cut-off run's undo first.
	local logKey = def.key .. "Log"
	if not resume then
		if CinematicDB[logKey] and #CinematicDB[logKey] > 0 then CinematicDB[def.key .. "PrevLog"] = CinematicDB[logKey] end
		CinematicDB[logKey] = {}
	end
	CinematicDB[logKey] = CinematicDB[logKey] or {}
	local run = setmetatable({ def = def, pass = resume and resume.pass or 0, fail = resume and resume.fail or 0,
		skip = resume and resume.skip or 0, verdicts = resume and resume.verdicts or {}, began = GetTime() }, Run)
	if ns.PadTestBoxClock then ns.PadTestBoxClock(function() return Kit.Clock(run) end) end
	local left
	run.steps, run.full, left = Pick(def, arg)
	-- (What was typed after the name, for a test that takes words of its own:
	-- the addon kit's addon names. After a reload it's the steps left.)
	run.arg = arg
	if resume then run.full = resume.full and true or false end
	current = run
	Say(run, ("start: /cine debug %s%s, %s, %d of %d step(s)%s"):format(def.name, arg and arg ~= "" and (" " .. arg) or "",
		date("%Y-%m-%d"), #run.steps, #def.steps, run.full and ", full run" or ""))
	if #left > 0 then
		Say(run, ("proven, left out (/cine debug %s full runs them): %s"):format(def.name, table.concat(left, "; ")))
	end
	if resume then
		-- (After the Reload button: the same run's undo kept, CineMode as it was.)
		local undo = CinematicDB[UndoKey(def)] or {}
		CinematicDB[UndoKey(def)] = undo
		run.cineWas = undo.cineWas or false
		Say(run, "after the reload: picked up, the undo kept")
	else
		if CinematicDB[UndoKey(def)] then Say(run, "a cut-off run's settings first: " .. PutBack(def)) end
		run.cineWas = ns.IsCineModeOn and ns.IsCineModeOn() or false
		CinematicDB[UndoKey(def)] = { cineWas = run.cineWas or nil }
	end
	ContextLine(run)
	ConsoleStart(run)
	run.errors0, run.blocked0 = Counts()
	run.errorSnap = Snapshot() -- (the inspection at the end: which errors, whose)
	-- (Each second: CineMode kept off, unless the test leaves it alone, and
	-- the AFK camera's still timer fresh either way.)
	KeepCineOff(run)
	run.cineTicker = C_Timer.NewTicker(1, function() if current == run then KeepCineOff(run) end end)
	-- The setup in a coroutine of its own (it may wait), then the steps one by one.
	run.index = 0
	Kit.WrapTestPrompt()
	StepErrorsOpen(run) -- ("setup" till the first step)
	CloseWindows(run, "start")
	run.co = coroutine.create(function() if def.setup then def.setup(run) end end)
	run:Resume(run.co)
end

-- An older test's own big prompt (ns.TestPrompt, UI/TooltipParts.lua) while
-- a kit run goes: its words go on the kit's box, under the step, not in a
-- second box of its own (the addon kit's run showed two, one under the
-- other, 2026-11-25). Wrapped at the first run: TooltipParts loads after us.
function Kit.WrapTestPrompt()
	local base = ns.TestPrompt
	if Kit.testPromptWrapped or type(base) ~= "function" then return end
	Kit.testPromptWrapped = true
	ns.TestPrompt = function(msg, seconds)
		local run, box = current, ns.padTestBox
		if run and not run.stopped and box and box.sub and box:IsShown() then
			ns.debugNoCopyWindow = true
			Say(run, "  its own prompt: " .. tostring(msg))
			box.sub:SetText(tostring(msg))
			if box.Fit then box:Fit() end
			return
		end
		return base(msg, seconds)
	end
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
function Kit.Has(name) return defs[name] end
function Kit.Names()
	local names = {}
	for i, name in ipairs(order) do names[i] = name end
	return names
end
-- (A block named resume() while a run goes: the step's own call, see Run:Click.)
do
	local watch = CreateFrame("Frame")
	watch:RegisterEvent("ADDON_ACTION_BLOCKED")
	watch:SetScript("OnEvent", function(_, _, _, fn)
		if current and type(fn) == "string" and fn:find("^resume") then current.blockedResume = true end
	end)
end

-- /cine debug <name> [args] for a kit test (Slash.lua asks before its own
-- fallback); /cine debug kit lists them. Returns true when it was one.
function ns.TestKitRun(arg)
	local name, rest = (arg or ""):match("^(%S+)%s*(.-)$")
	if name == "kit" then
		ns.Print("test kit tests (/cine debug <name> [full | steps | restore]; proven steps left out unless full):")
		for _, each in ipairs(order) do
			local def = defs[each]
			print(("  %s - %s (%d steps)"):format(each, def.about or def.title, #def.steps))
		end
		if Kit.ListWrapped then Kit.ListWrapped() end
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
	-- (Offline checks: a second "login" in one load.)
	Kit.ResetLogin = function() login:RegisterEvent("PLAYER_ENTERING_WORLD") end
	login:SetScript("OnEvent", function(self, _, isLogin, isReload)
		if isLogin == false and isReload == false then return end -- (a zone change: a run goes on)
		self:UnregisterAllEvents()
		if not CinematicDB then return end
		for _, name in ipairs(order) do
			local def = defs[name]
			local resume = CinematicDB[def.key .. "Resume"]
			CinematicDB[def.key .. "Resume"] = nil
			if type(resume) == "table" and resume.steps ~= "" and CinematicDB[UndoKey(def)] then
				ns.Print(def.title .. ": picking up after the reload in 2 s.")
				C_Timer.After(2, function() Kit.Start(name, resume.steps, resume) end)
			elseif CinematicDB[UndoKey(def)] then
				local said = PutBack(def)
				local log = CinematicDB[def.key .. "Log"]
				if log then log[#log + 1] = date("%H:%M:%S") .. " login: the run was cut off (a /reload?): " .. said end
				ns.Print(def.title .. " was cut off: " .. said)
			end
		end
	end)
end
