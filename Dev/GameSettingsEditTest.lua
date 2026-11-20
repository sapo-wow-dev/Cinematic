-- /cine debug gsedit: Help > Game Settings sets Yours right there, filters
-- its rows and links to what decides them (a player's ask, 2026-11-20).
-- Hands off, about 25 s; CineMode off meanwhile; out of fights only; every
-- setting put back as it was at the end. Screenshots at each step:
--   1 page     the page opens with its rows: each one's kind logged
--   2 held     a test hold on Target circle; its Yours switch clicked: ours
--              stays on screen, yours saved, still held; let go: yours (the
--              clicked one) comes back (PASS/FAIL)
--   3 free     its switch clicked again with nothing holding it: written now
--   4 style    Forever: Nameplate style's Yours set to another style: written,
--              or saved while the Style page holds it; then back (PASS/FAIL)
--   5 filter   "target circle" typed: only its row; a nonsense word: Nothing
--              found; the state menu's Cinematic's now: only those (PASS/FAIL)
--   6 links    /cine find cvar:ObjectSelectionCircle, Target circle's Used for
--              and a HUD row's "set by its row" link: each found (PASS/FAIL)
--   7 back     every setting as it was at the start (PASS/FAIL)
-- Into CinematicDB.gsEditLog. Dev copy only.
local _, ns = ...

local CVAR = "ObjectSelectionCircle"
local WAIT = 1.5
local run
local holdSet -- (made once: a set stays listed for the session)

local function Log(text)
	local log = CinematicDB and CinematicDB.gsEditLog
	if log then log[#log + 1] = ("%s %s"):format(date("%H:%M:%S"), text) end
end
local function CVar(name)
	local ok, value = pcall(GetCVar, name)
	return ok and value or nil
end
local function Verdict(ok, text)
	if ok then run.pass = run.pass + 1 else run.fail = run.fail + 1 end
	Log(("  verdict %s: %s"):format(ok and "PASS" or "FAIL", text))
end
local function Shot(label)
	local ok = pcall(function() Screenshot() end)
	Log(("  screenshot %s: %s"):format(label, ok and "taken" or "failed"))
end
local function CineOn() return ns.IsCineModeOn and ns.IsCineModeOn() and true or false end
local function SetCine(on)
	if Cinematic_ToggleCineMode and CineOn() ~= on then Cinematic_ToggleCineMode() end
end
local function Page() return ns.GameSettingsPage end
local function LineOf(cvar)
	for _, line in ipairs(Page() and Page().lines or {}) do
		if line:IsShown() and line.row and line.row.cvar == cvar then return line end
	end
end
local function State(label, cvar)
	cvar = cvar or CVAR
	local line = LineOf(cvar)
	Log(("  %s: %s now %s, held %s, saved %s, kept %s, on page %s (kind %s, Yours text %q)"):format(label, cvar,
		tostring(CVar(cvar)), tostring(ns.IsCVarHeld(cvar)), tostring(ns.db.savedCVars[cvar]),
		tostring(ns.db.cvarsLeftAlone[cvar]), tostring(line ~= nil), tostring(line and line.row.kind),
		tostring(line and line.cells[4]:GetText())))
end
local function ShownCVars()
	local list = {}
	for _, line in ipairs(Page() and Page().lines or {}) do
		if line:IsShown() and line.row then list[#list + 1] = line.row.cvar end
	end
	return list
end

local function PutBack()
	if not run or run.putBack then return end
	run.putBack = true
	if holdSet and holdSet.active then ns.ApplyCVarSet(holdSet, false) end
	if Page() then Page().SetFilter("") end
	for cvar, value in pairs(run.start) do
		if run.keptStart[cvar] then
			ns.KeepYourCVar(cvar)
		else
			ns.db.cvarsLeftAlone[cvar] = nil
		end
		if run.savedStart[cvar] ~= nil then
			ns.db.savedCVars[cvar] = run.savedStart[cvar]
		elseif CVar(cvar) ~= value then
			ns.db.savedCVars[cvar] = nil
			SetCVar(cvar, value)
		end
	end
	SetCine(run.cineWasOn)
end

local function Finish()
	State("after putting back")
	local same = true
	for cvar, value in pairs(run.start) do
		if run.savedStart[cvar] == nil and CVar(cvar) ~= value then
			same = false
			Log(("  %s is %s, was %s"):format(cvar, tostring(CVar(cvar)), tostring(value)))
		end
	end
	Verdict(same, "every setting as it was at the start")
	local line = ("done: %d pass, %d fail"):format(run.pass, run.fail)
	Log(line)
	run = nil
	ns.TestPrompt(("Game Settings edit test DONE: %s. Say \"check log\"."):format(line), 15)
end

-- The steps as one coroutine: each coroutine.yield(label) waits for the
-- screen to draw what it set, takes its screenshot, then waits past that
-- second (a screenshot's file is named by the second: several in one second
-- left only the last, and all showed the screen at the end of the frame).
local function Drive(fn)
	local co = coroutine.create(fn)
	local function Step()
		if not run then return end
		local ok, label = coroutine.resume(co)
		if not ok then
			Log("  verdict FAIL: Lua error: " .. tostring(label))
			PutBack()
			return Finish()
		end
		if coroutine.status(co) == "dead" then return end
		C_Timer.After(WAIT, function()
			if not run then return end
			Shot(label)
			C_Timer.After(1.2, Step)
		end)
	end
	C_Timer.After(WAIT, Step)
end

function ns.GameSettingsEditTest()
	if not CinematicDB then return end
	if run then
		PutBack()
		run = nil
		ns.TestPrompt("Game Settings edit test stopped; your settings are back.", 4)
		return
	end
	if InCombatLockdown() then
		ns.TestPrompt("Game Settings edit test: run it out of a fight.", 6)
		return
	end
	CinematicDB.gsEditLog = {}
	run = { pass = 0, fail = 0, start = {}, savedStart = {}, keptStart = {}, cineWasOn = CineOn() }
	for _, cvar in ipairs({ CVAR, "nameplateStyle" }) do
		run.start[cvar] = CVar(cvar)
		run.savedStart[cvar] = ns.db.savedCVars[cvar]
		run.keptStart[cvar] = ns.db.cvarsLeftAlone[cvar] or false
	end
	Log(("start: %s (game %s), CineMode %s, Target circle %s, Nameplate style %s"):format(
		ns.isRetail and "retail" or "Forever", tostring((select(4, GetBuildInfo()))), tostring(run.cineWasOn),
		tostring(run.start[CVAR]), tostring(run.start.nameplateStyle)))
	if run.start[CVAR] == nil then
		Log("  verdict INFO: no Target circle setting on this client: nothing to test")
		run = nil
		ns.TestPrompt("Game Settings edit test: nothing to test here. Say \"check log\".", 10)
		return
	end
	SetCine(false)
	ns.TestPrompt("Game Settings edit test: hands off, about 25 seconds.", 15)

	Log("--- 1 of 7: the page ---")
	ns.OpenOptions("Game settings")
	ns.db.cvarsLeftAlone[CVAR] = nil
	Drive(function()
		if not Page() then
			Verdict(false, "the Game Settings page is built")
			PutBack()
			return Finish()
		end
		Page().SetFilter("")
		local kinds = {}
		for _, line in ipairs(Page().lines) do
			if line:IsShown() and line.row then kinds[#kinds + 1] = line.row.cvar .. "=" .. tostring(line.row.kind) end
		end
		Log("  rows: " .. table.concat(kinds, ", "))
		Verdict(#kinds > 0, "the page lists its rows")
		coroutine.yield("page")

		Log("--- 2 of 7: held, Yours clicked ---")
		local start = run.start[CVAR]
		local ours = start == "1" and "0" or "1"
		holdSet = holdSet or ns.CVarSet("Test: Game Settings edit", "/cine debug gsedit",
			{ playerWins = true, values = { [CVAR] = ours } })
		ns.ApplyCVarSet(holdSet, true)
		Page().SetFilter("target circle") -- (its row on screen for the screenshots)
		State("held")
		local line = LineOf(CVAR)
		Verdict(line ~= nil and line.row.kind == "switch" and line.check:IsShown(), "its Yours is a switch")
		if line then line.check:Click() end
		State("switch clicked")
		Verdict(CVar(CVAR) == ours, "ours stays on screen (" .. ours .. ")")
		Verdict(ns.db.savedCVars[CVAR] == ours, "yours saved as the clicked one (" .. ours .. ")")
		Verdict(ns.IsCVarHeld(CVAR), "still held (not read as your own change)")
		coroutine.yield("held")
		ns.ApplyCVarSet(holdSet, false)
		Page().Refresh()
		State("let go")
		Verdict(CVar(CVAR) == ours, "let go: yours (the clicked one) back")

		Log("--- 3 of 7: free, Yours clicked ---")
		line = LineOf(CVAR)
		if line then line.check:Click() end
		State("switch clicked again")
		Verdict(CVar(CVAR) == start, "written now (" .. tostring(start) .. ")")

		Log("--- 4 of 7: Nameplate style ---")
		Page().SetFilter("nameplateStyle")
		local styleLine = LineOf("nameplateStyle")
		if not (ns.GamePlateStyles and ns.GamePlateStyles()) then
			Log("  verdict INFO: this client has no nameplate styles")
		else
			State("style before", "nameplateStyle")
			Verdict(styleLine ~= nil and styleLine.row.kind == "style" and styleLine.style ~= nil
				and styleLine.style:IsShown(), "its Yours is the styles' menu")
			local yours = styleLine and styleLine.row.yours or run.start.nameplateStyle
			local other = yours == "1" and "2" or "1"
			ns.SetYourCVar("nameplateStyle", other)
			Page().Refresh()
			State("style set to " .. other, "nameplateStyle")
			local held = ns.IsCVarHeld("nameplateStyle")
			Verdict((held and ns.db.savedCVars.nameplateStyle == other) or (not held and CVar("nameplateStyle") == other),
				held and "held by the Style page: saved" or "free: written now")
			coroutine.yield("style")
			ns.SetYourCVar("nameplateStyle", yours)
			Page().Refresh()
			State("style back", "nameplateStyle")
		end

		Log("--- 5 of 7: filter ---")
		Page().SetFilter("target circle")
		local shown = ShownCVars()
		Log("  shown: " .. table.concat(shown, ", "))
		Verdict(#shown == 1 and shown[1] == CVAR, "\"target circle\": just its row")
		coroutine.yield("filter")
		Page().SetFilter("zzqqx")
		Verdict(#ShownCVars() == 0, "a nonsense word: no rows (Nothing found)")
		coroutine.yield("nothing found")
		Page().SetFilter("", "ours")
		local allOurs = true
		for _, l in ipairs(Page().lines) do
			if l:IsShown() and l.row and l.row.state ~= "ours" then allOurs = false end
		end
		Log("  Cinematic's now: " .. table.concat(ShownCVars(), ", "))
		Verdict(allOurs, "the state menu's Cinematic's now: only those")
		Page().SetFilter("")

		Log("--- 6 of 7: links ---")
		local text, pageName = ns.FindSetting("cvar:" .. CVAR)
		Log(("  /cine find cvar:%s -> %s on %s"):format(CVAR, tostring(text), tostring(pageName)))
		Verdict(text ~= nil, "/cine find cvar:" .. CVAR .. " finds its row")
		line = LineOf(CVAR)
		if line and line.row.find then
			text, pageName = ns.FindSetting(line.row.find)
			Log(("  Used for (%s) -> %s on %s"):format(line.row.find, tostring(text), tostring(pageName)))
			Verdict(text ~= nil, "Target circle's Used for opens its setting")
		else
			Verdict(false, "Target circle's Used for has a setting to open")
		end
		local owned
		for _, row in ipairs(ns.GameSettingsRows()) do
			if row.owner then owned = row break end
		end
		if owned then
			text, pageName = ns.FindSetting("row:" .. owned.owner)
			Log(("  %s set by row:%s -> %s on %s"):format(owned.cvar, owned.owner, tostring(text), tostring(pageName)))
			Verdict(text ~= nil, "a HUD row's link opens the row")
		else
			Log("  verdict INFO: no setting here is set by a HUD row (Names and Nameplates rows untouched)")
		end
		coroutine.yield("link opened")
		ns.OpenOptions("Game settings")
		Log("--- 7 of 7: your settings back ---")
		PutBack()
		coroutine.yield("back")
		Finish()
	end)
end
