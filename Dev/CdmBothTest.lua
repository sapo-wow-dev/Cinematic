-- /cine debug cdmboth: the probe for the Cooldown Manager's "Both" looks (a
-- spell with a cooldown and a DoT: the DoT on the game's swipe, the cooldown
-- in pips, a ring, a bar or a number; ledger Tools/tests/cdm-both.md). In a
-- fight the cooldown's time left is secret, so each way to draw it from the
-- game's duration object (C_Spell.GetSpellCooldownDuration) is tried at once,
-- on a stand-in icon above your character:
--   A  row pips: 8 squares, each one's alpha from a step curve
--      (EvaluateRemainingPercent: the game compares, not us)
--   B  ring pips: the drain ring (UI/CooldownRing.lua) fed GetRemainingPercent
--   C  a StatusBar on SetTimerDuration (the game drains it by itself)
--   D  the seconds: SetFormattedText of GetRemainingDuration
--   E  the DoT's time apart from the game's swipe, from the times the game's
--      icon keeps (GetAuraDuration errors in fights, run 1): E1 our own
--      Cooldown frame's numbers, E2 a bar from the aura's start to its end,
--      E3 a copy of the game's countdown text on that icon
-- Steps:
--   1 find   a DoT in your bars, the shortest 8 s+ cooldown in your spellbook
--            (never an item: run 1 took Healthstone)
--   2 fight  you cast the cooldown out of a fight, then pull a mob and put the
--            DoT on it (both seen by the test, no clicks); every way drawn
--            for 6 s, errors counted per way, two shots
--   3 after  the fight over, the cooldown still running: the same reads
--            plain, so the percent's scale (0-1 or 0-100) is known; a shot
--   (steps 2-3 proven by run 3: left out of plain runs)
-- The built feature (UI/CooldownBoth.lua):
--   4 page   Style > Cooldown Manager's Cooldown + DoT tab: its preview in
--            each look (shots), what it overlaps, the tab off (defaults),
--            the page off; hands off
--   5 built  in a fight, each of the five looks on the DoT's real icon (it's
--            given the cooldown spell's time: no spell of yours has both),
--            drawn with no errors, a shot each
-- Into CinematicDB.cdmBothTestLog. Dev copy only.
local _, ns = ...

local PIPS = 8
local RUN_FOR = 6 -- seconds drawn in the fight

local function Secret(v) return issecretvalue and issecretvalue(v) or false end
local function SpellName(id)
	local ok, name = pcall(C_Spell.GetSpellName, id)
	return ok and type(name) == "string" and not Secret(name) and name or ("spell " .. tostring(id))
end
local function Base(id)
	local ok, base = pcall(GetSpellBaseCooldown, id)
	return ok and type(base) == "number" and not Secret(base) and base or nil
end

local state -- { cd, dot, dotIcon, stand, errs, lastErr, ticks, ms }

-- (The Cooldown + DoT folder tab's saved switch, UI/CooldownBoth.lua.)
local function TAB_KEY() return ("tabOn:%s:%d"):format(ns.CDM_STYLE_TABS, ns.CDM_STYLE_BOTH_TAB or 3) end

-- A DoT (no cooldown of its own) from the Essential or Utility bar, and a
-- spell with a cooldown (8 s or more) from your spellbook: the shortest, so
-- it comes back soon. Never an item from the bars (run 1 took Healthstone,
-- which costs one: the user, 2026-11-25). The duration object works on any
-- spell, not only the bars'.
local function Find()
	local cd, cdBase, dot, dotIcon, all, book = nil, math.huge, nil, nil, {}, {}
	ns.EachCooldownIcon(function(icon, id, bar)
		if bar ~= "EssentialCooldownViewer" and bar ~= "UtilityCooldownViewer" then return end
		if Secret(id) then return end
		local base = Base(id)
		all[#all + 1] = ("%s %d (%s ms)"):format(SpellName(id), id, tostring(base))
		if base == 0 and not dot then dot, dotIcon = id, icon end
	end, true)
	pcall(function()
		local bank = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
		for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
			local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
			for i = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
				local item = C_SpellBook.GetSpellBookItemInfo(i, bank)
				local id = item and not item.isPassive and item.spellID
				local base = id and Base(id)
				if base and base >= 8000 then
					book[#book + 1] = ("%s %d (%d ms)"):format(SpellName(id), id, base)
					if base < cdBase then cd, cdBase = id, base end
				end
			end
		end
	end)
	return cd, dot, dotIcon, all, book
end

-- A step curve: 0 below the threshold, 1 from it on (percent 0-1).
local function StepCurve(threshold)
	local curve = C_CurveUtil.CreateCurve()
	curve:SetType(Enum.LuaCurveType.Step)
	curve:AddPoint(0, 0)
	curve:AddPoint(threshold, 1)
	curve:AddPoint(1, 1)
	return curve
end

local function Label(parent, text, point, rel, relPoint, x, y)
	local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	fs:SetPoint(point, rel, relPoint, x, y)
	fs:SetText(text)
	return fs
end

-- The stand-ins, once.
local function Stand()
	if state.stand then state.stand.frame:Show() return state.stand end
	local s = {}
	local f = CreateFrame("Frame", nil, UIParent)
	f:SetSize(300, 190)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 170)
	f:SetFrameStrata("HIGH")
	s.frame = f
	-- The cooldown's icon: ring pips (B) and the seconds (D) on it.
	local icon = CreateFrame("Frame", nil, f)
	icon:SetSize(56, 56)
	icon:SetPoint("TOPLEFT", f, "TOPLEFT", 40, -26)
	icon.Icon = icon:CreateTexture(nil, "ARTWORK")
	icon.Icon:SetAllPoints(icon)
	icon.Icon:SetTexture(C_Spell.GetSpellTexture(state.cd) or 134400)
	s.icon = icon
	Label(f, "B ring / D seconds", "BOTTOM", icon, "TOP", 0, 10)
	s.secs = icon:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
	s.secs:SetPoint("CENTER", icon, "CENTER", 0, 0)
	-- A: a row of square pips under it.
	s.pips, s.curves = {}, {}
	for i = 1, PIPS do
		local p = f:CreateTexture(nil, "OVERLAY")
		p:SetColorTexture(0.94, 0.62, 0.15, 1)
		p:SetSize(6, 6)
		p:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", (i - 1) * 7, -14)
		s.pips[i] = p
		local back = f:CreateTexture(nil, "ARTWORK")
		back:SetColorTexture(0.2, 0.2, 0.2, 0.8)
		back:SetAllPoints(p)
		s.curves[i] = StepCurve((i - 1) / PIPS + 0.0001)
	end
	Label(f, "A row pips", "LEFT", s.pips[PIPS], "RIGHT", 8, 0)
	-- C: a timer bar.
	local bar = CreateFrame("StatusBar", nil, f)
	bar:SetSize(56, 6)
	bar:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -28)
	bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
	bar:SetStatusBarColor(0.94, 0.62, 0.15)
	local barBack = bar:CreateTexture(nil, "BACKGROUND")
	barBack:SetAllPoints(bar)
	barBack:SetColorTexture(0.2, 0.2, 0.2, 0.8)
	s.bar = bar
	Label(f, "C timer bar", "LEFT", bar, "RIGHT", 8, 0)
	-- E: the DoT's icon copy: its time as a number and a bar.
	local dot = CreateFrame("Frame", nil, f)
	dot:SetSize(56, 56)
	dot:SetPoint("TOPRIGHT", f, "TOPRIGHT", -40, -26)
	local art = dot:CreateTexture(nil, "ARTWORK")
	art:SetAllPoints(dot)
	art:SetTexture(state.dot and C_Spell.GetSpellTexture(state.dot) or 134400)
	Label(f, "E1 timer / E3 copy", "BOTTOM", dot, "TOP", 0, 10)
	-- E1: our own Cooldown frame on the game's icon's times (secret), numbers
	-- only, no swipe: the DoT's seconds for the corner-number look.
	local timer = CreateFrame("Cooldown", nil, dot, "CooldownFrameTemplate")
	timer:SetAllPoints(dot)
	timer:SetDrawSwipe(false)
	timer:SetDrawEdge(false)
	timer:SetHideCountdownNumbers(false)
	s.dotTimer = timer
	s.dotCopy = dot:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	s.dotCopy:SetPoint("BOTTOM", dot, "BOTTOM", 0, 4)
	s.dotCopy:SetTextColor(0.7, 0.9, 1)
	-- E2: a bar from the aura's start to its end (both secret), set to now:
	-- the dark fill is the time gone, the purple left the time left.
	local dotBar = CreateFrame("StatusBar", nil, f)
	dotBar:SetSize(56, 6)
	dotBar:SetPoint("TOPLEFT", dot, "BOTTOMLEFT", 0, -14)
	dotBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
	dotBar:SetStatusBarColor(0.12, 0.12, 0.14)
	dotBar:SetReverseFill(true)
	local dotBack = dotBar:CreateTexture(nil, "BACKGROUND")
	dotBack:SetAllPoints(dotBar)
	dotBack:SetColorTexture(0.5, 0.47, 0.87, 1)
	dotBar:SetMinMaxValues(0, 1)
	dotBar:SetValue(1)
	s.dotBar = dotBar
	Label(f, "E2 DoT bar", "LEFT", dotBar, "RIGHT", 8, 0)
	state.stand = s
	return s
end

local function Err(way, err)
	state.errs[way] = (state.errs[way] or 0) + 1
	state.lastErr[way] = tostring(err)
end
local function Try(way, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then Err(way, err) end
	return ok
end

-- One pass: every way drawn from the objects of now.
local timerSet = {}
local function Draw()
	local s, t0 = state.stand, debugprofilestop()
	state.ticks = state.ticks + 1
	local okDur, dur = pcall(C_Spell.GetSpellCooldownDuration, state.cd, true)
	if not okDur then Err("get", dur) dur = nil end
	if dur then
		Try("A", function()
			for i, p in ipairs(s.pips) do p:SetAlpha(dur:EvaluateRemainingPercent(s.curves[i])) end
		end)
		Try("B", function()
			local look = setmetatable({ cdmRingStyle = "pips" }, { __index = ns.CooldownRingLook() })
			local ring = ns.CooldownRingDraw(s.icon, look, 1, dur:GetRemainingPercent())
			ring.text:Hide() -- (its own amount, the raw percent, sat over D: run 2's shot)
		end)
		-- (C: set once per object; the game drains it.)
		if timerSet.C ~= dur then
			if Try("C", s.bar.SetTimerDuration, s.bar, dur, 0, 1) then timerSet.C = dur end
		end
		Try("D", function() s.secs:SetFormattedText("%.0f", dur:GetRemainingDuration()) end)
	else
		state.noDur = (state.noDur or 0) + 1
	end
	local icon = state.dotIcon
	if icon and type(icon.auraInstanceID) ~= "nil" then
		local unit = "target"
		if type(icon.GetAuraDataUnit) == "function" then
			local okU, u = pcall(icon.GetAuraDataUnit, icon)
			if okU and type(u) == "string" and not Secret(u) then unit = u end
		end
		state.dotUnit = unit
		-- (GetAuraDuration on the icon's aura errors in fights: "Auras cannot
		-- be accessed when secret while tainted", run 1. The game's own icon
		-- keeps the times: CooldownViewer.lua's cooldownStartTime /
		-- cooldownDuration, and auraDataCached.expirationTime.)
		local start, length = icon.cooldownStartTime, icon.cooldownDuration
		local cached = icon.auraDataCached
		local finish = type(cached) == "table" and cached.expirationTime or nil
		if type(start) == "nil" or type(length) == "nil" then
			state.noAura = (state.noAura or 0) + 1
		else
			-- (Set again only when the aura changes: a refresh.)
			if timerSet.E1 ~= icon.auraInstanceID then
				if Try("E1 timer", s.dotTimer.SetCooldown, s.dotTimer, start, length) then
					timerSet.E1 = icon.auraInstanceID
				end
			end
			if type(finish) ~= "nil" then
				Try("E2 bar", function()
					s.dotBar:SetMinMaxValues(start, finish)
					s.dotBar:SetValue(GetTime())
				end)
			else
				Err("E2 bar", "no expirationTime on the icon's auraDataCached")
			end
		end
		Try("E3 copy", function()
			local fs = icon.Cooldown:GetCountdownFontString()
			state.copyShown = fs:IsShown()
			s.dotCopy:SetText(fs:GetText())
		end)
	end
	state.ms = state.ms + (debugprofilestop() - t0)
end

local driver = CreateFrame("Frame")
driver:Hide()
local since = 0
driver:SetScript("OnUpdate", function(_, elapsed)
	since = since + elapsed
	if since < 0.1 then return end
	since = 0
	if state and state.stand then Draw() end
end)

local function Start()
	state.errs, state.lastErr, state.ticks, state.ms = {}, {}, 0, 0
	state.noDur, state.noAura = 0, 0
	Stand()
	driver:Show()
end
local function Report(r, label)
	driver:Hide()
	local ways = { "get", "A", "B", "C", "D", "E1 timer", "E2 bar", "E3 copy" }
	local parts = {}
	for _, way in ipairs(ways) do
		parts[#parts + 1] = ("%s %d"):format(way, state.errs[way] or 0)
	end
	r:Log(("%s: %d passes, %.3f ms each; no cooldown object %d, DoT times nil %d, DoT unit %s, game's DoT text " ..
		"shown %s, CVar countdownForCooldowns %s; errors: %s"):format(
		label, state.ticks, state.ticks > 0 and state.ms / state.ticks or 0, state.noDur, state.noAura,
		tostring(state.dotUnit), Secret(state.copyShown) and "secret" or tostring(state.copyShown),
		tostring(GetCVar("countdownForCooldowns")), table.concat(parts, ", ")))
	for way, err in pairs(state.lastErr) do r:Log(("  %s last error: %s"):format(way, err)) end
	for _, way in ipairs({ "A", "B", "C", "D" }) do
		r:Verdict(state.ticks > 0 and (state.errs[way] or 0) == 0 and state.noDur < state.ticks,
			("%s way %s: drawn with no errors (look at the shot for whether it moves)"):format(label, way))
	end
	if state.dotIcon and label == "fight" then
		-- (E1, our own Cooldown frame, refuses secret times: answered NO in
		-- run 3, rule forever.cdm.dot-time-from-icon-fields. Logged, not a
		-- verdict: the full run q686c counted it as a FAIL.)
		r:Log(("%s E1 timer: errors %d (expected: it refuses secret times)"):format(label,
			state.errs["E1 timer"] or 0))
		for _, way in ipairs({ "E2 bar", "E3 copy" }) do
			r:Verdict(state.ticks > state.noAura and (state.errs[way] or 0) == 0,
				("%s %s: the DoT's time drawn with no errors (shot: does it count down?)"):format(label, way))
		end
	end
end

-- The duration object's reads, each on its own line.
local function Reads(r, label)
	local ok, dur = pcall(C_Spell.GetSpellCooldownDuration, state.cd, true)
	r:Log(("%s: GetSpellCooldownDuration ok %s type %s secret %s"):format(label, tostring(ok), type(dur),
		tostring(Secret(dur))))
	if not ok or not dur then return end
	r:Probe(label .. " HasSecretValues", dur.HasSecretValues, dur)
	r:Probe(label .. " GetRemainingPercent", dur.GetRemainingPercent, dur)
	r:Probe(label .. " GetRemainingDuration", dur.GetRemainingDuration, dur)
	r:Probe(label .. " GetTotalDuration", dur.GetTotalDuration, dur)
	r:Probe(label .. " HasExpired", dur.HasExpired, dur)
	r:Probe(label .. " IsZero", dur.IsZero, dur)
	r:Probe(label .. " EvaluateRemainingPercent(step 0.5)", dur.EvaluateRemainingPercent, dur, StepCurve(0.5))
	local okCd, info = pcall(C_Spell.GetSpellCooldown, state.cd)
	if okCd and type(info) == "table" then
		r:Log(("%s: GetSpellCooldown start %s duration %s"):format(label,
			Secret(info.startTime) and "secret" or tostring(info.startTime),
			Secret(info.duration) and "secret" or tostring(info.duration)))
	end
	local icon = state.dotIcon
	if icon then
		r:Log(("%s: DoT icon aura id type %s secret %s"):format(label, type(icon.auraInstanceID),
			tostring(Secret(icon.auraInstanceID))))
	end
end

ns.TestKit.Define({
	name = "cdmboth",
	key = "cdmBothTest",
	title = "Cooldown and DoT: Both probe",
	about = "which ways draw a spell's cooldown time in a fight (pips, ring, bar, seconds) and the DoT's time",
	needs = "A spell with a cooldown (8 s+) and a DoT in your Essential or Utility bars, and a mob to fight",
	cvars = { "countdownForCooldowns" },
	-- (Its feature's files: the kit's error inspection says whose each error is.)
	files = { "UI/CooldownBoth.lua", "Style/CdmStyle.lua", "UI/CooldownGrid.lua", "Dev/CdmBothTest.lua" },
	settings = { "cdmStyle", "cdmBothLook", "cdmBothPips", "cooldownRowSettings" },
	putBack = function(extra)
		driver:Hide()
		ns.cooldownBothStandIn = nil
		C_Timer.After(0, function() if ns.ApplyCooldownBoth then ns.ApplyCooldownBoth() end end)
		if state and state.stand then state.stand.frame:Hide() end
		state = nil
		local was = type(extra) == "table" and extra.countdownForCooldowns
		if was ~= nil and was ~= "<nil>" then pcall(SetCVar, "countdownForCooldowns", was) end
		return "stand-ins hidden, countdownForCooldowns back to " .. tostring(was)
	end,
	steps = {
		{ key = "find", title = "the spells", run = function(r)
			state = {}
			local cd, dot, dotIcon, all, book = Find()
			state.cd, state.dot, state.dotIcon = cd, dot, dotIcon
			r:Log("bar spells: " .. (#all > 0 and table.concat(all, ", ") or "none"))
			r:Log("spellbook cooldowns (8 s+): " .. (#book > 0 and table.concat(book, ", ") or "none"))
			-- (The game's countdown numbers on, for E1 and E3; put back after.)
			local cvar = GetCVar("countdownForCooldowns")
			r:Keep("countdownForCooldowns", cvar)
			r:Log("CVar countdownForCooldowns was " .. tostring(cvar) .. ", on for the run")
			pcall(SetCVar, "countdownForCooldowns", "1")
			r:Verdict(cd ~= nil, "a cooldown spell from the spellbook: "
				.. (cd and ("%s %d (%d ms)"):format(SpellName(cd), cd, Base(cd)) or "none"))
			if dot then r:Log(("DoT: %s %d"):format(SpellName(dot), dot)) else r:Log("no DoT in the bars: E left out") end
			if not cd then return end
			Reads(r, "before")
		end },
		{ key = "fight", proven = "cdmboth run 3 (2026-11-25, warlock): PASS, A-D drawn in a fight, 0 errors, shots 150/146",
			title = "the fight: every way drawn", run = function(r)
			if not (state and state.cd) then return r:Skip("no cooldown spell (step 1)") end
			-- (No button: run 2 sat on "click Both cast", the user: "stuck. i did
			-- what it asked". The cooldown is seen running out of a fight, where
			-- it reads plain (cast it first, or it's still running from before);
			-- then the fight and the DoT on its icon.)
			local seen = false
			local ask = ("Cast %s now, out of a fight. Then pull a mob and put %s on it."):format(
				SpellName(state.cd), state.dot and SpellName(state.dot) or "a DoT")
			r:WaitFor(ask, { check = function()
				if not InCombatLockdown() and not seen then
					local ok, dur = pcall(C_Spell.GetSpellCooldownDuration, state.cd, true)
					local okE, expired = false, nil
					if ok and dur then okE, expired = pcall(dur.HasExpired, dur) end
					if okE and expired == false then seen = true end
				end
				local dotOn = not state.dotIcon or type(state.dotIcon.auraInstanceID) ~= "nil"
				return seen and InCombatLockdown() and dotOn and "ready"
			end })
			r:Log(("seen: cooldown running before the fight, in combat %s, DoT on its icon %s"):format(
				tostring(InCombatLockdown()), tostring(state.dotIcon and type(state.dotIcon.auraInstanceID) ~= "nil")))
			Start()
			Reads(r, "fight")
			r:Prompt("Recording: keep fighting a few seconds", "", RUN_FOR)
			r:Sleep(2)
			r:Shot("fight, early", { behind = state.stand.frame })
			r:Sleep(1.5)
			r:Shot("fight, 3 s later", { behind = state.stand.frame })
			r:Log("in combat at the end: " .. tostring(InCombatLockdown()))
			Report(r, "fight")
		end },
		{ key = "after", proven = "cdmboth run 3 (2026-11-25, warlock): PASS, percent 0-1, read plain after the fight",
			title = "after the fight: the reads plain", run = function(r)
			if not (state and state.cd) then return r:Skip("no cooldown spell (step 1)") end
			r:WaitFor(("End the fight (kill it or run), while %s is still cooling down."):format(SpellName(state.cd)),
				{ check = function() return not InCombatLockdown() and "out" end })
			Reads(r, "after")
			-- (The cooldown must still be running for the reads to say anything:
			-- run 1's never ran, the spell wasn't cast.)
			local ok, dur = pcall(C_Spell.GetSpellCooldownDuration, state.cd, true)
			local okP, left = false, nil
			if ok and dur then okP, left = pcall(dur.GetRemainingPercent, dur) end
			local plain = okP and type(left) == "number" and not Secret(left)
			r:Verdict(plain and left > 0, ("the cooldown still running, read plain: %s (%s)"):format(
				tostring(plain and left), plain and (left > 1 and "percent is 0-100" or "percent is 0-1")
				or "not running: cast it in the fight"))
			Start()
			r:Sleep(1.5)
			r:Shot("after the fight", { behind = state.stand.frame })
			Report(r, "after")
			state.stand.frame:Hide()
		end },
		-- The built feature (UI/CooldownBoth.lua, Style/CdmStyle.lua's third tab).
		{ key = "page", proven = "cdmboth run 4 (2026-11-25, warlock): PASS, opened, no overlaps, 6 looks drawn right in the preview (shots), tab off = Ring 8",
			title = "Style > Cooldown Manager: the Cooldown + DoT tab, each look", run = function(r)
			if InCombatLockdown() then return r:Skip("in a fight: the settings stay shut") end
			if not ns.CreateCdmStylePanel then return r:Skip("Style left out (Modules): no page, the defaults' look") end
			r:Set("cdmStyle", true)
			r:Set(TAB_KEY(), true)
			local ok, err = pcall(ns.OpenOptionsAt, "Cooldown Manager Style")
			r:Verdict(ok and SettingsPanel and SettingsPanel:IsShown(), "the page opened: " .. tostring(err or "ok"))
			r:Sleep(0.5)
			if ns.CdmStyleOpenTab then ns.CdmStyleOpenTab(3) end
			r:Sleep(0.3)
			local preview = ns.cdmBothPreview
			r:Verdict(preview and preview:IsVisible(), "the Cooldown + DoT tab shows its preview")
			local hits = preview and r:Overlaps(preview, SettingsPanel) or { "no preview" }
			r:Verdict(#hits == 0, "the preview overlaps nothing: " .. (#hits > 0 and table.concat(hits, "; ") or "clear"))
			for _, look in ipairs({ { "ring", 8 }, { "edge", 8 }, { "edge", 12 }, { "row", 4 }, { "bar", 8 }, { "corner", 8 } }) do
				r:Set("cdmBothLook", look[1])
				r:Set("cdmBothPips", look[2])
				if ns.RefreshOptions then pcall(ns.RefreshOptions) end
				if preview then preview:Refresh() end
				r:Sleep(0.3)
				r:Shot(("look %s %d"):format(look[1], look[2]), { behind = SettingsPanel })
			end
			-- The tab right-clicked off: the defaults' look (Ring 8), the rows greyed.
			r:Set("cdmBothLook", "edge")
			r:Set(TAB_KEY(), false)
			if ns.RefreshOptions then pcall(ns.RefreshOptions) end
			local look = ns.CooldownBothLook()
			r:Verdict(look.cdmBothLook == "ring" and tonumber(look.cdmBothPips) == 8,
				("tab off: the defaults' look (%s %s)"):format(tostring(look.cdmBothLook), tostring(look.cdmBothPips)))
			r:Sleep(0.3)
			r:Shot("tab off (greyed)", { behind = SettingsPanel })
			r:Set(TAB_KEY(), true)
			r:Set("cdmStyle", false)
			if ns.RefreshOptions then pcall(ns.RefreshOptions) end
			r:Sleep(0.3)
			r:Shot("page off (greyed)", { behind = SettingsPanel })
			r:Set("cdmStyle", true)
			pcall(HideUIPanel, SettingsPanel)
		end },
		-- (Run 5 passed, the full runs q686c / qd5a0 found the size missing or
		-- another bar's; fixed, proven in q93e0.)
		{ key = "built", proven = "cdmboth q93e0 (2026-11-25, warlock): PASS, its own size (50) read before the fight, 5 looks drawn, 0 errors",
			title = "the built feature in a fight: each look on the real icon", run = function(r)
			if not (state and state.cd and state.dotIcon) then return r:Skip("no cooldown spell or DoT icon (step 1)") end
			-- (No spell of yours has both: the DoT's icon given the cooldown's.)
			local function Copy(t)
				if type(t) ~= "table" then return t end
				local c = {}
				for k, v in pairs(t) do c[k] = Copy(v) end
				return c
			end
			r:Set("cooldownRowSettings", Copy(ns.db.cooldownRowSettings) or {})
			ns.SetCooldownRow(state.dot, "notBuff", "both")
			ns.cooldownBothStandIn = { [state.dot] = state.cd }
			r:Set("cdmBothPips", 8)
			ns.ApplyCooldownBoth()
			local seen = false
			r:WaitFor(("Cast %s out of a fight (or let it keep cooling down). Then pull a mob and put %s on it."):format(
				SpellName(state.cd), SpellName(state.dot)), { check = function()
				if not InCombatLockdown() and not seen then
					local ok, dur = pcall(C_Spell.GetSpellCooldownDuration, state.cd, true)
					local okE, expired = false, nil
					if ok and dur then okE, expired = pcall(dur.HasExpired, dur) end
					if okE and expired == false then seen = true end
				end
				return seen and InCombatLockdown() and type(state.dotIcon.auraInstanceID) ~= "nil" and "ready"
			end })
			-- (Its size read before the fight, the bar hidden or not: the full
			-- run q686c had none, the walk took shown icons only.)
			local own, last = ns.CooldownBothWidth(state.dotIcon, "EssentialCooldownViewer")
			r:Log(("size before the fight: its own %s, its bar's %s; the bar shown %s"):format(tostring(own),
				tostring(last), tostring(_G.EssentialCooldownViewer and _G.EssentialCooldownViewer:IsVisible())))
			r:Verdict(own ~= nil, "the DoT's icon's own size read before the fight: " .. tostring(own))
			local stats = ns.CooldownBothStats
			local errors, shown = stats.errors, stats.shown
			r:Prompt("Recording: keep fighting (about 15 s)", "", 16)
			local viewer = _G.EssentialCooldownViewer
			for _, look in ipairs({ "ring", "edge", "row", "bar", "corner" }) do
				r:Set("cdmBothLook", look)
				ns.ApplyCooldownBoth()
				r:Sleep(0.6)
				local d = ns.CooldownBothOf(state.dotIcon)
				-- (Sized too: run 4's ring, edge and row were shown with no size,
				-- nothing on screen, and this verdict passed.)
				local sized = d and (look == "bar" or look == "corner" or d.width ~= nil)
				r:Verdict(d and d.kind == look and d.holder:IsShown() and sized,
					("%s drawn on the DoT's icon, sized %s"):format(look, tostring(d and d.width)))
				r:Shot("in the fight: " .. look, { behind = viewer })
			end
			r:Verdict(stats.errors == errors and stats.shown > shown, ("%d draws, %d errors (last: %s)"):format(
				stats.shown - shown, stats.errors - errors, tostring(stats.lastError)))
			r:Log(("the game's DoT kept on the icon (no swap): %s"):format(
				tostring(not ns.CooldownNoBuffOn(state.dot, "essential"))))
			ns.cooldownBothStandIn = nil
		end },
	},
})
