-- /cine debug selftext: what a Shoulder Cam "Combat text on you" can use
-- (Tools/self-combat-text-plan.md, 2026-11-20). The game's floating combat
-- text about you (Blizzard_CombatText: "-26", "+120", "Dodge", "<Combo
-- Points>") has a secret text and place on Forever, so moving it skips
-- every message now. One run, each step just "take hits or heal yourself"
-- (it moves on after 4 of them, no time limit), screenshots after the 1st
-- and 3rd of each step, every event and every error logged:
--   1 watch  the game's text as it is; every COMBAT_TEXT_UPDATE with what
--            C_CombatText.GetCurrentEventInfo gives (plain or secret), every
--            UNIT_COMBAT on you, each showing text's font, color and alpha
--   2 color  the game's texts recolored pink as they're colored (style its own?)
--   3 font   its font object (CombatTextFont) bigger with a thick edge
--   4 hide   its CombatText frame's alpha 0 (hide it, keep its events?)
--   5 off    enableFloatingCombatText 0: do COMBAT_TEXT_UPDATE still come?
--   6 ours   our own stand-in: your hits drawn pink right of the middle,
--            climbing, with SetText of the (secret) amount, and the other
--            kinds' names (Combo Points, auras...) from GetCurrentEventInfo
--   7 mirror the game's frame hidden (alpha 0), each message it draws copied
--            into our own text right of the middle: its (secret) words as
--            the game set them (every other one read back with GetText
--            instead), its color. Every message the game makes, Low Mana and
--            ones with no event too, with our place and look (2026-11-20).
-- /cine debug selftext mirror (or any step names): only those steps.
-- Each step's errors counted (the dev error window's deverror lines).
-- CineMode off for the run; everything put back after each step and at the
-- end. Into CinematicDB.selfTextLog. Typed again: stops. Dev copy only.
local _, ns = ...

local NEED = 4      -- your hits or heals a step waits for
local GAP = 1.2     -- seconds after the last one before the next step
local PINK = { 1, 0.3, 1 }
local SHIFT = 220   -- our stand-in's place, UI units right of the middle
local CLIMB, LIFE = 90, 1.6

local STEPS = {
	{ key = "watch", say = "The game's own text, as it is." },
	{ key = "color", say = "The game's text should be PINK." },
	{ key = "font", say = "The game's text should be BIGGER, with a thick edge." },
	{ key = "hide", say = "The game's text should be GONE (hidden by us)." },
	{ key = "off", say = "The game's text should be GONE (its own setting off)." },
	{ key = "ours", say = "OUR text: PINK numbers right of the middle, climbing." },
	{ key = "mirror", say = "The game's text should be GONE from where it was,\nand the SAME words in the game's colors RIGHT of the middle, climbing.\nHeal yourself too." },
}

local run
local busy = false
local hookedColor, hookedMirror, ourPool = {}, {}, {}
local logHooked = false

local function Secret(v) return issecretvalue and issecretvalue(v) end
local function T(v)
	if Secret(v) then return "secret" end
	if type(v) == "number" then return ("%.2f"):format(v) end
	if type(v) == "table" then
		local ok, name = pcall(function() return v.GetName and v:GetName() end)
		return ok and name and not Secret(name) and tostring(name) or "table"
	end
	return tostring(v)
end
local function Say(text)
	local log = CinematicDB and CinematicDB.selfTextLog
	if log then log[#log + 1] = ("%s %.1f %s"):format(date("%H:%M:%S"), run and GetTime() - run.at or 0, text) end
end
local function All(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[i] = T((select(i, ...))) end
	return table.concat(parts, ", ")
end
local function Shot(what)
	local ok = pcall(function() Screenshot() end)
	Say(("screenshot %s at %s%s"):format(what, date("%m%d%y_%H%M%S"), ok and "" or " (failed)"))
end
local function Texts()
	local frame = _G.CombatText
	local list = {}
	if type(frame) == "table" and frame.GetRegions then
		for _, r in ipairs({ frame:GetRegions() }) do
			if r.GetObjectType and r:GetObjectType() == "FontString" then list[#list + 1] = r end
		end
	end
	return list
end

-- The texts showing now: words, font, color, alpha (each plain or "secret").
local function Showing()
	for i, r in ipairs(Texts()) do
		local shown = r:IsShown()
		if Secret(shown) or shown then
			local okText, text = pcall(r.GetText, r)
			local okFont, file, size, flags = pcall(r.GetFont, r)
			local okColor, cr, cg, cb = pcall(r.GetTextColor, r)
			local okObj, obj = pcall(r.GetFontObject, r)
			Say(("  text %d: %s | font %s %s %s (object %s) | color %s | alpha %s | scale %s"):format(i,
				okText and T(text) or "error", okFont and T(file) or "error", T(size), T(flags),
				okObj and T(obj) or "error", okColor and All(cr, cg, cb) or "error", T(r:GetAlpha()),
				T(r.GetTextScale and r:GetTextScale())))
		end
	end
end

-- What there is to work with, once at the start.
local function Survey()
	local frame = _G.CombatText
	Say(("CombatText %s, loaded %s, texts %d, alpha %s, shown %s"):format(type(frame),
		tostring(C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_CombatText")),
		#Texts(), type(frame) == "table" and T(frame:GetAlpha()) or "-", type(frame) == "table" and T(frame:IsShown()) or "-"))
	local font = _G.CombatTextFont
	Say(("CombatTextFont %s: %s"):format(type(font), type(font) == "table" and All(font:GetFont()) or "-"))
	Say(("COMBAT_TEXT_TYPE_INFO %s, COMBAT_TEXT_FLOAT_MODE %s, COMBAT_TEXT_SCROLLSPEED %s"):format(
		type(_G.COMBAT_TEXT_TYPE_INFO), T(_G.COMBAT_TEXT_FLOAT_MODE), T(_G.COMBAT_TEXT_SCROLLSPEED)))
	if type(_G.COMBAT_TEXT_TYPE_INFO) == "table" then
		local kinds = {}
		for key, info in pairs(_G.COMBAT_TEXT_TYPE_INFO) do
			kinds[#kinds + 1] = ("%s(%s)"):format(T(key), type(info) == "table" and T(info.cvar) or "")
		end
		table.sort(kinds)
		Say("  kinds: " .. table.concat(kinds, " "))
	end
	local api = {}
	for name, fn in pairs(C_CombatText or {}) do if type(fn) == "function" then api[#api + 1] = name end end
	table.sort(api)
	Say("C_CombatText: " .. (#api > 0 and table.concat(api, " ") or "none"))
	-- (The "Text on Me" ticks and Float Mode: every floatingCombatText CVar.)
	local names = {}
	local list = (C_Console and C_Console.GetAllCommands and C_Console.GetAllCommands())
		or (ConsoleGetAllCommands and ConsoleGetAllCommands()) or {}
	for _, info in ipairs(list) do
		local name = type(info) == "table" and info.command
		if type(name) == "string" and (name:lower():find("floatingcombattext") or name:lower():find("combattext")) then
			names[#names + 1] = name
		end
	end
	table.sort(names)
	for _, name in ipairs(names) do
		local ok, value = pcall(GetCVar, name)
		Say(("  cvar %s = %s"):format(name, ok and T(value) or "error"))
	end
	if #names == 0 then Say("  (no console command list on this client)") end
	Say("enableFloatingCombatText = " .. T(GetCVar("enableFloatingCombatText")))
end

-- Step 2: each text recolored pink as the game colors it.
local function HookColors()
	for _, r in ipairs(Texts()) do
		if not hookedColor[r] then
			hookedColor[r] = true
			hooksecurefunc(r, "SetTextColor", function(self)
				if busy or not (run and run.key == "color") then return end
				busy = true
				local ok = pcall(self.SetTextColor, self, PINK[1], PINK[2], PINK[3])
				busy = false
				run.note.recolored = run.note.recolored + (ok and 1 or 0)
			end)
		end
	end
end

-- Step 6: our own text, a small pool climbing right of the middle.
local ourFrame
local function OurText(text, small, color)
	if not ourFrame then
		ourFrame = CreateFrame("Frame", nil, UIParent)
		ourFrame:SetAllPoints(UIParent)
		ourFrame:SetFrameStrata("HIGH")
		ns.SetOnUpdate(ourFrame, function()
			local now, live = GetTime(), false
			for _, fs in ipairs(ourPool) do
				if fs.born then
					local t = (now - fs.born) / LIFE
					if t >= 1 then
						fs.born = nil
						fs:Hide()
					else
						live = true
						fs:SetPoint("CENTER", UIParent, "CENTER", SHIFT + fs.lane, t * CLIMB)
						fs:SetAlpha(t < 0.6 and 1 or (1 - t) / 0.4)
					end
				end
			end
			if not live then ourFrame:Hide() end
		end)
	end
	local fs
	for _, each in ipairs(ourPool) do if not each.born then fs = each break end end
	if not fs then
		fs = ourFrame:CreateFontString(nil, "OVERLAY")
		ourPool[#ourPool + 1] = fs
	end
	fs:SetFont("Fonts\\FRIZQT__.TTF", small and 18 or 30, "THICKOUTLINE")
	color = color or PINK
	fs:SetTextColor(color[1], color[2], color[3])
	local ok, err = pcall(fs.SetText, fs, text)
	fs.lane = small and -60 or 0
	fs.born = GetTime()
	fs:ClearAllPoints()
	fs:SetPoint("CENTER", UIParent, "CENTER", SHIFT + fs.lane, 0)
	fs:Show()
	ourFrame:Show()
	return ok, err, fs
end

-- Step 7: every text the game draws, copied into ours as it's set; its
-- color once the game has set that too (the next frame).
local function Mirror(region, text, via)
	local note = run.note
	local ok, err, fs
	if via == "get" then
		local okGet, got = pcall(region.GetText, region)
		if okGet then
			ok, err, fs = OurText(got)
		else
			ok, err = false, "GetText: " .. tostring(got)
		end
	else
		ok, err, fs = OurText(text)
	end
	C_Timer.After(0, function()
		local okColor, r, g, b = pcall(region.GetTextColor, region)
		if run and fs and okColor and not (Secret(r) or Secret(g) or Secret(b)) then
			fs:SetTextColor(r, g, b)
			note.colored = note.colored + 1
		end
	end)
	if ok then
		if via == "get" then note.viaGet = note.viaGet + 1 else note.viaArg = note.viaArg + 1 end
	else
		note.mirrorErr = note.mirrorErr or (Secret(err) and "secret" or tostring(err))
	end
end
local function HookMirror()
	for _, r in ipairs(Texts()) do
		if not hookedMirror[r] then
			hookedMirror[r] = true
			hooksecurefunc(r, "SetText", function(self, text)
				if not (run and run.key == "mirror" and run.note) then return end
				run.note.copies = run.note.copies + 1
				local copy, via = run.note.copies, run.note.copies % 2 == 0 and "get" or "arg"
				-- (Caught and logged: one copy of four went missing with no error
				-- logged, Forever 2026-11-20; an error inside the game's call.)
				local ok, err = pcall(Mirror, self, text, via)
				Say(("  copy %d via %s: %s"):format(copy, via, ok and "ok" or ("ERROR " .. (Secret(err) and "secret" or tostring(err)))))
				if not ok then run.note.mirrorErr = run.note.mirrorErr or (Secret(err) and "secret" or tostring(err)) end
			end)
		end
	end
end

-- A step's setup and putting it back.
local function Begin(key)
	local note = run.note
	if key == "color" then
		HookColors()
		return ("color hooks on %d texts"):format(#Texts())
	elseif key == "font" then
		local font = _G.CombatTextFont
		if type(font) ~= "table" then return "no CombatTextFont on this client" end
		run.keptFont = { font:GetFont() }
		local file, size = run.keptFont[1], run.keptFont[2]
		local ok, err = pcall(font.SetFont, font, file, (tonumber(size) or 25) * 1.6, "THICKOUTLINE")
		note.setupErr = not ok and tostring(err) or nil
		return ("CombatTextFont %s %s -> x1.6 THICKOUTLINE: %s"):format(T(file), T(size), ok and "ok" or tostring(err))
	elseif key == "hide" then
		local frame = _G.CombatText
		if type(frame) ~= "table" then return "no CombatText frame" end
		run.keptAlpha = frame:GetAlpha()
		frame:SetAlpha(0)
		return "CombatText alpha 0"
	elseif key == "off" then
		run.keptCVar = GetCVar("enableFloatingCombatText")
		SetCVar("enableFloatingCombatText", "0")
		return "enableFloatingCombatText " .. T(run.keptCVar) .. " -> " .. T(GetCVar("enableFloatingCombatText"))
	elseif key == "mirror" then
		local frame = _G.CombatText
		if type(frame) ~= "table" then return "no CombatText frame" end
		HookMirror()
		run.keptAlpha = frame:GetAlpha()
		frame:SetAlpha(0)
		return ("CombatText alpha 0, copy hooks on %d texts"):format(#Texts())
	end
	return "-"
end

local function PutBack()
	if not run then return end
	if run.keptFont then
		local font = _G.CombatTextFont
		-- (Every value it gave back: Forever's has more than three, and a
		-- partial put-back left the game's numbers spaced out, 2026-11-20.)
		pcall(font.SetFont, font, unpack(run.keptFont))
		run.keptFont = nil
	end
	if run.keptAlpha then
		_G.CombatText:SetAlpha(run.keptAlpha)
		run.keptAlpha = nil
	end
	if run.keptCVar then
		SetCVar("enableFloatingCombatText", run.keptCVar)
		run.keptCVar = nil
	end
end

local function Verdict()
	local index, note = run.step, run.note
	if not (index and note) then return end
	local key = STEPS[index].key
	local verdict
	if note.hits == 0 then
		verdict = "NO HIT OR HEAL SEEN"
	elseif note.errors > 0 then
		verdict = ("ERRORS %d (first: %s)"):format(note.errors, note.firstError or "?")
	elseif key == "off" then
		verdict = note.ctu > 0 and "PASS: COMBAT_TEXT_UPDATE still comes with the game's text off"
			or "COMBAT_TEXT_UPDATE STOPPED with it off (our text needs the game's on, hidden by alpha)"
	elseif key == "color" then
		verdict = note.recolored > 0 and ("no errors, %d recolored; see the screenshot"):format(note.recolored)
			or "NOT RECOLORED (the game never called SetTextColor on its texts)"
	elseif key == "mirror" then
		local line = ("copied %d of %d drawn (%d from the words given, %d read back), %d colored"):format(
			note.viaArg + note.viaGet, note.copies, note.viaArg, note.viaGet, note.colored)
		if note.copies == 0 then
			verdict = "NOTHING TO COPY (the game set no text on its texts)"
		elseif note.mirrorErr then
			verdict = ("COPY FAILED: %s | %s"):format(note.mirrorErr, line)
		else
			verdict = "PASS: " .. line .. "; see the screenshot"
		end
	elseif key == "ours" then
		verdict = note.ourErr and ("OUR SetText FAILED: " .. note.ourErr)
			or ("PASS: drew %d hits, %d other kinds; see the screenshot"):format(note.ours, note.ourKinds)
	else
		verdict = "no errors; see the screenshot"
	end
	Say(("verdict %d %s: %s | hits %d, COMBAT_TEXT_UPDATE %d, in combat %s; %s"):format(index, key, verdict,
		note.hits, note.ctu, tostring(note.combat), note.setup or "-"))
end

local function Box(index, got)
	ns.PadTestBox(("Step %d of %d: TAKE HITS OR HEAL YOURSELF.\n%s"):format(run.pos, #run.steps, STEPS[index].say),
		("%d of %d"):format(got, NEED), 0.3, 1, 0.3)
end

local function StartStep(pos)
	if run.step then
		Verdict()
		PutBack()
	end
	local index = run.steps[pos]
	run.pos, run.step, run.key = pos, index, STEPS[index].key
	run.note = { hits = 0, ctu = 0, errors = 0, recolored = 0, ours = 0, ourKinds = 0, copies = 0, viaArg = 0,
		viaGet = 0, colored = 0 }
	Say(("--- step %d %s (in combat %s) ---"):format(index, run.key, tostring(InCombatLockdown())))
	local ok, setup = pcall(Begin, run.key)
	run.note.setup = ok and setup or ("setup error: " .. tostring(setup))
	Say("  " .. run.note.setup)
	Box(index, 0)
end

local function Finish(done)
	if not run then return end
	Verdict()
	PutBack()
	if run.ticker then run.ticker:Cancel() end
	if run.cineWasOn and ns.IsCineModeOn and not ns.IsCineModeOn() and Cinematic_ToggleCineMode then
		Cinematic_ToggleCineMode()
	end
	Say(done and "done" or "stopped")
	run = nil
	ns.PadTestBox(done and "Combat text test done. /reload, then say \"check log\"." or "Combat text test stopped.", "",
		1, 0.82, 0)
	C_Timer.After(12, function() if not run then ns.PadTestBoxHide() end end)
end

local logged = 0
local watcher = CreateFrame("Frame")
watcher:SetScript("OnEvent", function(_, event, ...)
	if not run or not run.note then return end
	local note = run.note
	note.combat = note.combat or InCombatLockdown()
	if event == "COMBAT_TEXT_UPDATE" then
		note.ctu = note.ctu + 1
		local kind = ...
		local okInfo = C_CombatText and C_CombatText.GetCurrentEventInfo
		local info = okInfo and { pcall(C_CombatText.GetCurrentEventInfo) } or { false, "no API" }
		if logged < 150 then
			logged = logged + 1
			Say(("  COMBAT_TEXT_UPDATE %s | info %s"):format(T(kind),
				info[1] and All(unpack(info, 2, 8)) or ("error " .. T(info[2]))))
		end
		if run.key == "ours" and not Secret(kind) and type(kind) == "string"
			and kind ~= "DAMAGE" and kind ~= "HEAL" and kind ~= "SPELL_DAMAGE" then
			OurText((kind:lower():gsub("_", " ")), true)
			note.ourKinds = note.ourKinds + 1
		end
		if run.key == "color" then HookColors() end
		return
	end
	-- UNIT_COMBAT on you.
	local unit, action, flag, amount, school = ...
	note.hits = note.hits + 1
	Say(("  UNIT_COMBAT %s %s %s amount %s school %s"):format(T(unit), T(action), T(flag), T(amount), T(school)))
	if run.key == "ours" then
		local word = not Secret(action) and action ~= "WOUND" and action ~= "HEAL" and action
		local ok, err = OurText(word or amount)
		note.ours = note.ours + 1
		if not ok then note.ourErr = Secret(err) and "secret" or tostring(err) end
	end
	local index, hit = run.step, note.hits
	if hit == 1 or hit == 3 then
		C_Timer.After(0.35, function()
			if run and run.step == index then
				Say(("step %d %s, hit %d:"):format(index, run.key, hit))
				pcall(Showing)
				Shot(("step %d %s hit %d"):format(index, run.key, hit))
			end
		end)
	end
	if hit <= NEED then Box(index, hit) end
	if hit == NEED then run.nextAt = GetTime() + GAP end
end)

function ns.SelfTextProbe(args)
	if run then
		watcher:UnregisterAllEvents()
		Finish(false)
		return
	end
	ns.debugNoCopyWindow = true
	if not logHooked then
		logHooked = true
		hooksecurefunc(ns, "Log", function(kind, text)
			if kind == "deverror" and run and run.note then
				run.note.errors = run.note.errors + 1
				run.note.firstError = run.note.firstError or tostring(text):sub(1, 160)
				Say("  ERROR " .. tostring(text):sub(1, 300))
			end
		end)
	end
	CinematicDB.selfTextLog = {}
	logged = 0
	-- (Steps named: only those, in order; none named: all.)
	local steps = {}
	for word in (args or ""):gmatch("%a+") do
		for i, step in ipairs(STEPS) do if step.key == word:lower() then steps[#steps + 1] = i end end
	end
	if #steps == 0 then for i = 1, #STEPS do steps[i] = i end end
	run = { at = GetTime(), steps = steps, cineWasOn = ns.IsCineModeOn and ns.IsCineModeOn() or false }
	if run.cineWasOn and Cinematic_ToggleCineMode then Cinematic_ToggleCineMode() end
	Say(("start: %s (game %s), in combat %s, CineMode was %s"):format(ns.isRetail and "retail" or "Forever",
		tostring((select(4, GetBuildInfo()))), tostring(InCombatLockdown()), tostring(run.cineWasOn)))
	local ok, err = pcall(Survey)
	if not ok then Say("survey error: " .. tostring(err)) end
	watcher:RegisterEvent("COMBAT_TEXT_UPDATE")
	watcher:RegisterUnitEvent("UNIT_COMBAT", "player")
	StartStep(1)
	run.ticker = C_Timer.NewTicker(0.2, function()
		if not run then return end
		local okTick, errTick = pcall(function()
			if run.nextAt and GetTime() >= run.nextAt then
				run.nextAt = nil
				if run.pos < #run.steps then
					StartStep(run.pos + 1)
				else
					watcher:UnregisterAllEvents()
					Finish(true)
				end
			end
		end)
		if not okTick then
			Say("error: " .. tostring(errTick))
			watcher:UnregisterAllEvents()
			Finish(false)
		end
	end)
end
