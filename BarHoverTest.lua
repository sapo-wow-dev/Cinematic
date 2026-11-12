-- /cine debug bartest: one run recording why an action bar addon's bars
-- (ClassicUI Forever, Bartender4) stay invisible and can't be clicked while
-- their tooltips still show. Three timed steps in the big test box (Frames.lua's
-- ns.PadTestBox): mouse away, mouse on a button, click a button. Every half
-- second the log ("bartest") gets the mouse focus and its parents, the
-- watched buttons' parents, alpha and clicks, and each faded action bar's
-- alpha, mouse-over and whether Cinematic counts it hovered; a verdict per
-- step at the end. Dev copy only (CinematicDev.toc).
local _, ns = ...

local STEP = 8 -- seconds a step lasts
local STEPS = {
	{ key = "away", say = "1/3: Move the mouse AWAY from your action bars (onto the world) and wait" },
	{ key = "hover", say = "2/3: Hold the mouse STILL over one of your action buttons" },
	{ key = "click", say = "3/3: CLICK that action button a few times (one with a spell on it)" },
}

local run -- the run going: { at, step, clicks, ticker, notes = { step -> facts } }

local function Say(text)
	ns.Log("bartest", text)
end

local function Name(frame)
	if not frame then return "nil" end
	if frame.IsForbidden and frame:IsForbidden() then return "<forbidden>" end
	local ok, name = pcall(frame.GetName, frame)
	if ok and type(name) == "string" and not (issecretvalue and issecretvalue(name)) then return name end
	return "<anon " .. tostring(frame):gsub("^table: ", "") .. ">"
end
local function Num(value)
	if value == nil then return "nil" end
	if issecretvalue and issecretvalue(value) then return "secret" end
	if type(value) == "number" then return ("%.2f"):format(value) end
	return tostring(value)
end
-- frame and up to depth of its parents: name(alpha).
local function Chain(frame, depth)
	local out = {}
	for _ = 1, depth do
		if not frame then break end
		local ok, alpha = pcall(frame.GetAlpha, frame)
		out[#out + 1] = Name(frame) .. "(" .. (ok and Num(alpha) or "?") .. ")"
		local okParent, parent = pcall(frame.GetParent, frame)
		frame = okParent and parent or nil
	end
	return table.concat(out, " < ")
end
local function Focus()
	if GetMouseFoci then
		local foci = GetMouseFoci()
		return foci and foci[1]
	end
	return GetMouseFocus and GetMouseFocus()
end
local function IsActionButton(frame)
	if not frame or (frame.IsForbidden and frame:IsForbidden()) then return false end
	local name = Name(frame)
	return name:find("ActionButton%d") or name:find("^BT4Button") or name:find("^MultiBar.-Button%d")
		or (frame.action ~= nil and frame.icon ~= nil)
end
-- The buttons watched: the one under the mouse, else the first of each kind there is.
local function Watched()
	local list, seen = {}, {}
	local focus = Focus()
	if IsActionButton(focus) then list[1], seen[focus] = focus, true end
	for _, name in ipairs({ "ActionButton1", "BT4Button1", "MultiBarBottomLeftButton1" }) do
		local button = _G[name]
		if button and not seen[button] then list[#list + 1], seen[button] = button, true end
	end
	return list
end
local function ButtonLine(button)
	local function Ask(method)
		local fn = button[method]
		if not fn then return "-" end
		local ok, value = pcall(fn, button)
		return ok and Num(value) or "err"
	end
	return ("%s: shown %s, alpha %s, effective %s, clicks %s, mouse %s, over %s; parents %s"):format(Name(button),
		Ask("IsShown"), Ask("GetAlpha"), Ask("GetEffectiveAlpha"), Ask("IsMouseClickEnabled"), Ask("IsMouseEnabled"),
		Ask("IsMouseOver"), Chain(button:GetParent(), 4))
end

local function Tick()
	if not run then return end
	local now = GetTime() - run.at
	local index = math.min(#STEPS, math.floor(now / STEP) + 1)
	local step = STEPS[index]
	if index ~= run.step then
		run.step = index
		Say(("--- step %s ---"):format(step.key))
	end
	local left = STEP - (now - (index - 1) * STEP)
	ns.PadTestBox(step.say, ("%d sec  (clicks counted: %d)"):format(math.max(0, math.ceil(left)), run.clicks))
	local notes = run.notes[step.key] or { hovered = 0, ticks = 0, effective = 0, effectiveN = 0 }
	run.notes[step.key] = notes
	notes.ticks = notes.ticks + 1
	Say(("%.1f focus: %s"):format(now, Chain(Focus(), 6)))
	for _, button in ipairs(Watched()) do
		Say("  " .. ButtonLine(button))
		local ok, effective = pcall(button.GetEffectiveAlpha, button)
		if ok and type(effective) == "number" and not (issecretvalue and issecretvalue(effective)) then
			notes.effective, notes.effectiveN = notes.effective + effective, notes.effectiveN + 1
		end
	end
	local anyHovered = false
	for _, entry in ipairs(ns.managed or {}) do
		local frame = entry.frame
		if (entry.group == "bars" or entry.group == "sidebars") and frame and ns.Flag(frame:IsVisible()) then
			local okOver, over = pcall(frame.IsMouseOver, frame)
			local okHover, hovered = pcall(ns.IsEntryHovered, entry)
			hovered = okHover and hovered and true or false
			anyHovered = anyHovered or hovered
			Say(("  bar %s [%s]: alpha %s, mouse over %s, hovered %s, clicks off %s, mouse %s"):format(Name(frame),
				tostring(entry.row), Num(frame:GetAlpha()), okOver and Num(over) or "err", tostring(hovered),
				entry.clicksOff and #entry.clicksOff or 0, Num(frame:IsMouseEnabled())))
		end
	end
	if anyHovered then notes.hovered = notes.hovered + 1 end
	if now >= #STEPS * STEP then ns.BarHoverTest(true) end
end

-- Every action button there is, for the click count.
local hooked = {}
local function HookClicks()
	local function Hook(button)
		if button and not hooked[button] and button.HookScript then
			hooked[button] = true
			button:HookScript("PostClick", function(self)
				if run then
					run.clicks = run.clicks + 1
					Say(("  CLICK on %s"):format(Name(self)))
				end
			end)
		end
	end
	for i = 1, 12 do
		for _, prefix in ipairs({ "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
			"MultiBarRightButton", "MultiBarLeftButton" }) do
			Hook(_G[prefix .. i])
		end
	end
	for i = 1, 180 do Hook(_G["BT4Button" .. i]) end
end

local function Verdicts()
	local function Average(notes)
		return notes and notes.effectiveN > 0 and notes.effective / notes.effectiveN or nil
	end
	local away, hover = run.notes.away, run.notes.hover
	local lines = {}
	local awayAlpha, hoverAlpha = Average(away), Average(hover)
	lines[#lines + 1] = ("away: buttons faded %s (alpha %s)"):format(awayAlpha and awayAlpha < 0.1 and "YES" or "NO",
		Num(awayAlpha))
	lines[#lines + 1] = ("hover: Cinematic saw it %s (%d of %d checks); buttons came up %s (alpha %s)"):format(
		hover and hover.hovered > 0 and "YES" or "NO", hover and hover.hovered or 0, hover and hover.ticks or 0,
		hoverAlpha and hoverAlpha > 0.5 and "YES" or "NO", Num(hoverAlpha))
	lines[#lines + 1] = ("click: %d clicks reached a button"):format(run.clicks)
	return lines
end

-- Typed again while running: stops. done: the last step ended.
function ns.BarHoverTest(done)
	if run then
		if run.ticker then run.ticker:Cancel() end
		local lines = Verdicts()
		for _, line in ipairs(lines) do
			Say("verdict " .. line)
			ns.Print(line)
		end
		run = nil
		ns.PadTestBox(done and "Test done." or "Test stopped.", "Say \"check log\" (and /reload first)", 1, 0.82, 0)
		C_Timer.After(10, function() if not run then ns.PadTestBoxHide() end end)
		return
	end
	if done then return end
	HookClicks()
	local addons = {}
	for _, name in ipairs({ "ClassicUIForever", "Bartender4", "Dominos", "ElvUI", "EllesmereUI" }) do
		local loaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(name)
		if loaded then addons[#addons + 1] = name end
	end
	Say(("start: bar addons loaded: %s; CineMode %s; in combat %s"):format(
		#addons > 0 and table.concat(addons, ", ") or "none", tostring(ns.lastCinematic),
		tostring(InCombatLockdown())))
	run = { at = GetTime(), step = 0, clicks = 0, notes = {} }
	run.ticker = C_Timer.NewTicker(0.5, function()
		local ok, err = pcall(Tick)
		if not ok then Say("error: " .. tostring(err)) end
	end)
	ns.Print("bar test: 24 sec, follow the box (type it again to stop)")
end
