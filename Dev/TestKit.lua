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
--     FAIL / SKIP verdicts, paced screenshots (one a second at most: the
--     file is named by the second), r:Shot(label, { behind = frame }) puts
--     a solid background behind the frame(s) the shot is about, for that
--     shot only: use it on every shot of a frame or text;
--   * the log in CinematicDB.<key>Log, the run before in <key>PrevLog, so a
--     rerun doesn't lose it before .claude/skills/test/read_log.py archives it.
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
-- Timers on the box all run long: time on this step, on the whole run, and
-- a countdown when it's known how long it takes: a step's seconds = N (the
-- test's own hands-off steps), or r:Prompt(text, sub, seconds) and
-- r:WaitFor(text, { seconds = N }). (The user, 2026-11-21: "i want timers".)
-- Inside a step (it runs in a coroutine): r:Log, r:Verdict, r:Pass, r:Fail,
-- r:Skip, r:Probe, r:Set (setting, undo saved), r:Sleep, r:Shot, r:Prompt,
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
local function HideButtons()
	for _, button in ipairs(plain) do button:Hide() end
	if not InCombatLockdown() then for _, button in pairs(secure) do button:Hide() end end
	if holder then holder:Hide() end
end
Kit.HideButtons = HideButtons
-- (Whether this client has /editmode: logged on the context line.)
function Kit.HasEditModeSlash()
	local list = _G.hash_SlashCmdList
	return (list and list["/EDITMODE"]) ~= nil
end

-- The row: entries as above, laid left to right, centered. Returns the
-- buttons by label (offline checks click them). Old tests can use it too.
function Kit.ShowButtons(entries)
	HideButtons()
	local bar = Holder()
	bar:SetScale(UIParent:GetEffectiveScale())
	local shown, byLabel, n = {}, {}, 0
	for _, entry in ipairs(entries or {}) do
		if type(entry) == "string" then entry = { label = entry } end
		local button
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
			local label = button:GetFontString()
			button:SetSize(math.max(90, (label and label:GetStringWidth() or 60) + 32), 26)
			shown[#shown + 1] = button
			byLabel[entry.label or (SECURE[entry.kind] and SECURE[entry.kind].label) or "?"] = button
		end
	end
	local width = 0
	for _, button in ipairs(shown) do width = width + button:GetWidth() + GAP end
	local x = -width / 2 + GAP / 2
	for _, button in ipairs(shown) do
		button:ClearAllPoints()
		button:SetPoint("LEFT", bar, "CENTER", x, 0)
		x = x + button:GetWidth() + GAP
		button:Show()
	end
	if #shown > 0 then bar:Show() end
	return byLabel
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
	self.buttons = Kit.ShowButtons(entries)
	local labels = {}
	for label in pairs(self.buttons) do labels[#labels + 1] = label end
	table.sort(labels)
	return labels
end

function Run:Prompt(text, sub, seconds, buttons)
	if seconds then self.expectEnd = GetTime() + seconds else self.expectEnd = nil end
	-- (A step for you, not a hands-off one: a sound, so it's not missed. The
	-- side-by-side run 10 waited 2.5 minutes for a click nobody knew was due.)
	if not seconds and PlaySound then pcall(PlaySound, type(SOUNDKIT) == "table" and SOUNDKIT.READY_CHECK or 8960) end
	local n = self.step and self.stepNumber or 0
	-- (Out of all the test's steps, not the ones left: after a reload it's
	-- picked up with those only, and showed "step 4/2", loadparts 2026-11-22.)
	Box(self, ("%s, step %d/%d: %s"):format(self.def.title, n, #self.def.steps, text), sub or "No time limit.", 1, 0.82, 0)
	local labels = self:Buttons(buttons)
	Say(self, "  asked: " .. text .. (buttons and (" [buttons: " .. table.concat(labels, ", ") .. "]") or ""))
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
	self:Sleep(SHOT_BEFORE)
	local ok = pcall(function() Screenshot() end)
	Say(self, ("  screenshot %s: WoWScrnShot_%s%s%s"):format(tostring(label), date("%m%d%y_%H%M%S"),
		ok and "" or " (failed)", behind and (" (background behind %d of %d frame(s))"):format(backed, #behind) or ""))
	self:Sleep(SHOT_AFTER)
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
	if text then self:Prompt(text, nil, opts.seconds, opts.buttons)
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
	self.index = (self.index or 0) + 1
	local picked = self.steps[self.index]
	if not picked then
		self.step, self.co = nil, nil
		return Kit.Finish(self, true)
	end
	local run, step = self, picked.step
	run.step, run.stepNumber = step, picked.number
	run.stepBegan, run.expectEnd = GetTime(), step.seconds and (GetTime() + step.seconds) or nil
	run.co = coroutine.create(function()
		local e0, b0 = Counts()
		Say(run, ("step %d %s: %s | %s"):format(picked.number, step.key, step.title or step.say or "", StateLine()))
		if step.say then run:Prompt(step.say, nil, step.seconds, step.buttons) else
			Box(run, ("%s, step %d/%d: %s"):format(run.def.title, picked.number, #run.def.steps, step.title or step.key),
				"Nothing to do: the test does this one.", 0.6, 0.9, 1)
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
	if run.def.cineMode or not ns.IsCineModeOn then return end
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

function Kit.Finish(run, done)
	if current ~= run or run.stopped then return end
	run.stopped = true
	if run.waiting then
		if run.waiting.frame then run.waiting.frame:UnregisterAllEvents() end
		if run.waiting.ticker then run.waiting.ticker:Cancel() end
	end
	if run.cineTicker then run.cineTicker:Cancel() end
	HideBacks() -- (a stop in the middle of a shot)
	HideButtons()
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
	-- (The timers stop on the run's time.)
	local took = ns.PadTestTime(GetTime() - (run.began or GetTime()))
	if ns.PadTestBoxClock then ns.PadTestBoxClock(function() return "took " .. took end) end
	if done then
		Box(run, ("%s DONE: %d pass, %d fail, %d skip."):format(title, run.pass, run.fail, run.skip),
			"/reload, then say \"check log\".", run.fail > 0 and 1 or 0.3, run.fail > 0 and 0.4 or 1, 0.3)
	else
		Box(run, title .. " stopped.", "Your settings are put back. /reload, then say \"check log\".", 1, 0.6, 0.3)
	end
	ns.Print(("%s %s"):format(title, summary))
	C_Timer.After(60, function() if not current and ns.PadTestBoxHide then ns.PadTestBoxHide(run) end end)
end

-- The steps to run: the numbers given, else every step not proven (all with
-- "full"). Also whether it's a full run, and the proven ones left out.
local function Pick(def, arg)
	local wanted, steps, left = {}, {}, {}
	local full = (arg or ""):find("full") ~= nil
	for number in (arg or ""):gmatch("%d+") do wanted[tonumber(number)] = true end
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
	run.errors0, run.blocked0 = Counts()
	-- (Each second: CineMode kept off, unless the test leaves it alone, and
	-- the AFK camera's still timer fresh either way.)
	KeepCineOff(run)
	run.cineTicker = C_Timer.NewTicker(1, function() if current == run then KeepCineOff(run) end end)
	-- The setup in a coroutine of its own (it may wait), then the steps one by one.
	run.index = 0
	run.co = coroutine.create(function() if def.setup then def.setup(run) end end)
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
