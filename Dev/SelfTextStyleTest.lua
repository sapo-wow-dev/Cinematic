-- /cine debug selftextstyle: the Text on You page (Style/SelfTextStyle.lua)
-- in game, one run, ONE thing to do (2026-11-21, the user: no more test after
-- test): heal yourself once, or take one hit. The rest it does itself, paced
-- so each screenshot is its own (a wait, the shot, a wait past the second):
--   1 samples  the page on, Free side, Up: a sample of each kind drawn by us
--              at your spot (PASS: drawn)
--   2 looks    Split, Arc, Damage taken pink: samples again (PASS: drawn,
--              the shot shows the look)
--   3 real     "heal yourself once (or take a hit)": waits for the game's own
--              message, no time limit; copied into ours, the game's hidden
--              (PASS: copied, shown, its frame at 0)
--   4 game's   Who draws The game's: its frame back, our copying stopped
--              (PASS: state)
-- Your settings and CineMode put back at the end. Errors counted per step.
-- Into CinematicDB.selfTextStyleLog. Typed again: stops. Dev copy only.
local _, ns = ...

local KEYS = { "styleGeneral", "selfTextStyle", "selfTextBy", "selfTextSide", "selfTextMotion", "selfText_damageColor",
	"selfText_damageR", "selfText_damageG", "selfText_damageB", "selfTextFollow" }
local SAMPLES = { { "-26", "damage" }, { "+120", "heal" }, { "Dodge", "miss" }, { "-74", "damage", true },
	{ "<2 Combo Points>", "combo" }, { "Mana Low", "low" } }

local run
local logHooked = false

local function Say(text)
	local log = CinematicDB and CinematicDB.selfTextStyleLog
	if log then log[#log + 1] = ("%s %.1f %s"):format(date("%H:%M:%S"), run and GetTime() - run.at or 0, text) end
end
local function Shot(what)
	local ok = pcall(function() Screenshot() end)
	Say(("screenshot %s at %s%s"):format(what, date("%m%d%y_%H%M%S"), ok and "" or " (failed)"))
end
local function Counts()
	local state = ns.SelfTextState()
	return { copied = state.stats.copied, shown = state.stats.shown }, state
end
local function StateLine(state)
	local kinds = {}
	for kind, count in pairs(state.stats.kinds) do kinds[#kinds + 1] = kind .. "=" .. count end
	table.sort(kinds)
	local frame = _G.CombatText
	return ("by %s hidden %s (game's alpha %s) hooked %d live %d spot %.0f | kinds %s"):format(tostring(state.by),
		tostring(state.hidden), type(frame) == "table" and tostring(frame:GetAlpha()) or "-", state.hooked, state.live,
		state.spot or 0, #kinds > 0 and table.concat(kinds, " ") or "none")
end
local function Set(values)
	for key, value in pairs(values) do ns.db[key] = value end
	ns.RefreshSelfTextStyle()
end
local function Verdict(step, pass, detail)
	if run.errors > run.errorsAt then
		pass, detail = false, ("ERRORS %d (first: %s)"):format(run.errors - run.errorsAt, run.firstError or "?")
	end
	run.errorsAt, run.firstError = run.errors, nil
	run.results[#run.results + 1] = pass and "PASS" or "FAIL"
	Say(("verdict %s: %s: %s | %s"):format(step, pass and "PASS" or "FAIL", detail, StateLine(select(2, Counts()))))
end
local function Box(text, sub, waiting)
	ns.PadTestBox(text, sub or "", waiting and 0.3 or 1, waiting and 1 or 0.82, waiting and 0.3 or 0)
end

-- The steps, in a coroutine: Wait(seconds), WaitFor(test) yield to the ticker.
local function Wait(seconds)
	local til = GetTime() + seconds
	while GetTime() < til do coroutine.yield() end
end
local function WaitFor(test)
	while not test() do coroutine.yield() end
end
local function Samples()
	for index, sample in ipairs(SAMPLES) do
		ns.SelfTextSample(sample[1], sample[2], sample[3])
		if index < #SAMPLES then Wait(0.15) end
	end
end

local function Drive()
	-- 1. Samples, as it starts.
	Box("Text on You test: watch, nothing to do yet.", "1 of 4: samples beside you")
	Set({ selfTextBy = "ours", selfTextSide = "free", selfTextMotion = "up" })
	Say("--- step 1 samples | " .. StateLine(select(2, Counts())))
	local before = Counts()
	Samples()
	Wait(0.6)
	Shot("1 samples")
	local drawn = Counts().shown - before.shown
	Verdict("1 samples", drawn == #SAMPLES, ("%d of %d drawn"):format(drawn, #SAMPLES))
	Wait(2)

	-- 2. Another look.
	Box("Text on You test: watch, nothing to do yet.", "2 of 4: hits pink on one side, heals on the other, arcing")
	Set({ selfTextSide = "split", selfTextMotion = "arc", selfText_damageColor = "custom", selfText_damageR = 1,
		selfText_damageG = 0.3, selfText_damageB = 1 })
	Say("--- step 2 looks | " .. StateLine(select(2, Counts())))
	before = Counts()
	Samples()
	Wait(0.6)
	Shot("2 looks")
	drawn = Counts().shown - before.shown
	Verdict("2 looks", drawn == #SAMPLES, ("%d of %d drawn"):format(drawn, #SAMPLES))
	Wait(1.5)

	-- 3. The one thing to do: a real message from the game.
	Set({ selfTextSide = "free", selfTextMotion = "up", selfText_damageColor = run.kept.selfText_damageColor or "game" })
	Say("--- step 3 real | " .. StateLine(select(2, Counts())))
	before = Counts()
	Box("Text on You test: HEAL YOURSELF ONCE\n(or take one hit).", "3 of 4: waiting for the game's own text", true)
	WaitFor(function() return Counts().shown > before.shown end)
	Wait(0.4)
	Shot("3 real")
	local now, state = Counts()
	Verdict("3 real", now.copied > before.copied and state.hidden,
		("%d copied, %d shown, the game's hidden %s"):format(now.copied - before.copied, now.shown - before.shown,
			tostring(state.hidden)))
	Wait(1.5)

	-- 4. The game's own back (state only: nothing more to do).
	Box("Text on You test: almost done, nothing to do.", "4 of 4: the game's own text back")
	Set({ selfTextBy = "game" })
	local frame = _G.CombatText
	state = select(2, Counts())
	Verdict("4 game's", not state.hidden and state.by == "game" and (type(frame) ~= "table" or frame:GetAlpha() > 0),
		("hidden %s, by %s"):format(tostring(state.hidden), tostring(state.by)))
end

local function Finish(done)
	if not run then return end
	for _, key in ipairs(KEYS) do ns.db[key] = run.kept[key] end
	ns.RefreshSelfTextStyle()
	if run.ticker then run.ticker:Cancel() end
	if run.cineWasOn and ns.IsCineModeOn and not ns.IsCineModeOn() and Cinematic_ToggleCineMode then
		Cinematic_ToggleCineMode()
	end
	local passed = 0
	for _, result in ipairs(run.results) do if result == "PASS" then passed = passed + 1 end end
	Say(("%s: %d of %d PASS | your settings back"):format(done and "done" or "stopped", passed, #run.results))
	run = nil
	Box(done and ("Text on You test done: %d of 4 PASS.\n/reload, then say \"check log\"."):format(passed)
		or "Text on You test stopped.")
	C_Timer.After(12, function() if not run then ns.PadTestBoxHide() end end)
end

function ns.SelfTextStyleTest()
	if run then
		Finish(false)
		return
	end
	ns.debugNoCopyWindow = true
	if not logHooked then
		logHooked = true
		hooksecurefunc(ns, "Log", function(kind, text)
			if kind == "deverror" and run then
				run.errors = run.errors + 1
				run.firstError = run.firstError or tostring(text):sub(1, 160)
				Say("  ERROR " .. tostring(text):sub(1, 300))
			end
		end)
	end
	CinematicDB.selfTextStyleLog = {}
	run = { at = GetTime(), kept = {}, results = {}, errors = 0, errorsAt = 0,
		cineWasOn = ns.IsCineModeOn and ns.IsCineModeOn() or false }
	for _, key in ipairs(KEYS) do run.kept[key] = ns.db[key] end
	if run.cineWasOn and Cinematic_ToggleCineMode then Cinematic_ToggleCineMode() end
	ns.db.styleGeneral, ns.db.selfTextStyle, ns.db.selfTextFollow = true, true, true
	Say(("start: %s (game %s), Shoulder Cam %s, CineMode was %s, enableFloatingCombatText %s"):format(
		ns.isRetail and "retail" or "Forever", tostring((select(4, GetBuildInfo()))), tostring(ns.db.shoulderCam),
		tostring(run.cineWasOn), tostring(GetCVar("enableFloatingCombatText"))))
	local this = run
	local co = coroutine.create(Drive)
	run.ticker = C_Timer.NewTicker(0.1, function()
		if run ~= this then return end
		local ok, err = coroutine.resume(co)
		if not ok then
			Say("error: " .. tostring(err))
			Finish(false)
		elseif coroutine.status(co) == "dead" then
			Finish(true)
		end
	end)
end
