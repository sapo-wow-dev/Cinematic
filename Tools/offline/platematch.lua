-- /cine debug platematch (Dev/PlateMatchTest.lua) on the stand-in, Forever,
-- pretend time, the confirm run's steps: the proven templates step left out;
-- the preview made with the game's plate (the template's parts from
-- Tools/offline/gameplate_parts.lua), nothing up at rest, each sample and each
-- state by its pill with a shot, the pills' layout at three widths; the Combat
-- Text Style page opened with its switch on and off; the compare with a real
-- plate on your target, one texture through the same code on both, the real
-- plate put back. PASS or FAIL per check.
--   python -I Tools/offline/run.py Tools/offline/platematch.lua < /dev/null
-- luacheck: ignore 111 112 113 121 122 212 431
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
	for _, line in ipairs(log or {}) do if line:find(pattern) then n = n + 1 end end
	return n
end

local calls = {}
local parts = dofile("Tools/offline/gameplate_parts.lua")(function(text) calls[#calls + 1] = text end)
local ns, wow = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc", function()
	issecretvalue = function() return false end
	parts.Install()
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
-- (ns.HookOnUpdate kept for Advance to run: the plates' cast loops, an interrupted cast's.)
local updates = {}
local realHook = ns.HookOnUpdate
ns.HookOnUpdate = function(frame, fn)
	updates[#updates + 1] = { frame, fn }
	return realHook(frame, fn)
end
local function Advance(seconds)
	local stop = now + seconds
	while now < stop do
		now = now + 0.1
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
		-- (The game plates' own update loops: their casts and auras run on them.)
		for _, each in ipairs(updates) do
			if each[1]:IsShown() then pcall(each[2], each[1], 0.1) end
		end
	end
end
local shots = 0
Screenshot = function() shots = shots + 1 end
local cine = false
ns.IsCineModeOn = function() return cine end
Cinematic_ToggleCineMode = function() cine = not cine end
ns.PadTestBox = function() end
ns.PadTestBoxHide = function() end

local fight = false
InCombatLockdown = function() return fight end
UnitExists = function(unit) return unit == "target" or unit == "player" end
UnitName = function() return "Gnoll Brute" end
_G.C_XMLUtil = { GetTemplateInfo = function() return { type = "Button" } end }

-- The settings window: Combat Text Style's page holding a preview, as the page
-- builds one.
local panel = CreateFrame("Frame", "SettingsPanel", UIParent)
local opened = {}
ns.OpenOptions = function(page)
	opened[#opened + 1] = page
	if page == "Nameplate Style" then
		-- (The real page, made as on first open, hung under the window.)
		if not panel.stylePage then
			for _, entry in ipairs(ns.lazySettingsPages or {}) do
				if entry.name == "Nameplate Style" and not entry.made then entry.Make("test") end
			end
			for _, frame in ipairs(wow.frames) do
				-- (The page's content, by its Style Studio editor: 2026-11-25.)
				if rawget(frame, "plateEditor") ~= nil then
					local top = frame
					while top:GetParent() and top:GetParent() ~= UIParent do top = top:GetParent() end
					top:SetParent(panel)
					panel.stylePage = top
				end
			end
		end
	elseif page == "Nameplate Layout" then
		-- (The Layout tab's page, built at login: shown in the window.)
		local layout = ns.plateLayoutPage
		if layout then
			layout.canvas:SetParent(panel)
			layout.canvas:Show()
		end
	elseif not panel.page then
		local canvas = CreateFrame("Frame", nil, panel)
		panel.page = ns.MakePlateRowLookPreview(canvas, 480, "others")
	end
	panel:Show()
end
HideUIPanel = function(frame) frame:Hide() end

-- A real plate on your target, its fill the game's.
local plate = CreateFrame("Frame")
plate.UnitFrame = CreateFrame("Button", "LivePlate", plate, "NamePlateUnitFrameTemplate")
local liveBar = plate.UnitFrame.HealthBarsContainer.healthBar
liveBar:SetStatusBarTexture("UI-HUD-CoolDownManager-Bar")
C_NamePlate.GetNamePlateForUnit = function(unit) return unit == "target" and plate or nil end
C_NamePlate.GetNamePlates = function() return { plate } end -- (the plates up: the layout puts its own on each)
plate.UnitFrame.unit = "target"
calls = {}

-- (The off card as the page's own switch decides it: the stand-in's Style switches above it start off.)
ns.PageOffCardWanted = function(page)
	if page == "Combat Text Style" then return not ns.db.combatTextStyle end
	if page == "Nameplate Style" then return not ns.db.handlePlateStyle end
	if page == "Nameplate Layout" then return not ns.db.plateLayout end
	return false
end
-- (No Look panel since 2026-11-25: Customize became the Style Studio's editor.)
ns.LookPanelOpen = function() return nil end
ns.noRealLayout = true -- (as the kit's other offline checks: the stand-in places every frame alike)
ns.HandleSlash("debug platematch full") -- (every step, proven or not: what each still does)
Advance(400) -- (19 states shot on two previews, paced)

local log = CinematicDB.plateMatchTestLog
local done = Has(log, "DONE: ")
-- (16 skips: the preview's 11, and the layout steps' 5 measured ones (offline places nothing, no fight).)
Check("finished DONE, nothing failed", done ~= nil and done:find(" 0 fail", 1, true) ~= nil and done:find(" 17 skip", 1, true) ~= nil, -- (+1: the editor beside the preview, not measured offline, 2026-11-25)
	done or Has(log, "verdict FAIL") or Has(log, "STOPPED"))
Check("no Lua error in the test", Has(log, "FAIL Lua error") == nil, Has(log, "FAIL Lua error"))
Check("full: the proven steps run too", Has(log, "proven, left out") == nil and Has(log, "step 1 templates") ~= nil)
Check("the preview built the game's plate", Has(log, "PASS preview: the preview built the game's plate") ~= nil)
Check("nothing up at rest (run 3's marker sheet)", Count(log, "verdict PASS preview: .* hidden at rest") == 3)
Check("four samples, each with its level box", Count(log, "  SAMPLE %d") == 4 and Count(log, "verdict PASS .*level box shown") == 4)
for _, state in ipairs(ns.GAME_PLATE_STATES) do
	Check("state " .. state .. " shown by its pill", Has(log, "PASS preview: state " .. state .. ":") ~= nil,
		Has(log, "state " .. state .. ":"))
end
Check("debuffs only, the buff list left out", Has(log, "PASS preview: debuffs only") ~= nil)
-- (The stand-in has no places: each width SKIPs, never passes with nothing read.)
Check("the picks' layout tried at three widths, skipped with no places", Count(log, "verdict SKIP .*no pick places read") == 3,
	Count(log, "LAYOUT"))
local combat, style = 0, 0
for _, page in ipairs(opened) do
	if page == "Combat Text Style" then combat = combat + 1 elseif page == "Nameplate Style" then style = style + 1 end
end
Check("Combat Text Style and Nameplate Style opened, each with its switch on and off", combat == 2 and style == 2,
	combat .. ", " .. style)
Check("Nameplate Style: one big game plate, its lists, every unit and state on it",
	Has(log, "verdict PASS stylepage: one game plate, as big as the stage allows") ~= nil -- (was "drawn bigger": 2026-11-25)
	and Count(log, "verdict PASS stylepage: %a+ list shown on the preview") == 1 -- (one Preview list, 2026-11-25)
	and Count(log, "verdict SKIP stylepage: %a+: places not read") == 4
	and Count(log, "verdict PASS stylepage: page state %a+: as your settings draw it") == #ns.GAME_PLATE_STATES)
-- (The Theme list and Customize: the Style Studio's editor since 2026-11-25.)
Check("Nameplate Style: the editor right of the preview",
	Has(log, "verdict PASS stylepage: the editor shown") ~= nil
	and (Has(log, "verdict PASS stylepage: the editor right of the preview") ~= nil
		or Has(log, "verdict SKIP stylepage: the editor right of the preview") ~= nil))
Check("Nameplate Style: a theme pointed at leaves the saved one alone", Has(log, "verdict PASS stylepage: a theme pointed at") ~= nil)
Check("Nameplate Style off: the off card", Has(log, "verdict PASS stylepage: page switch off: the off card") ~= nil)
-- (The stand-in has no real layout: the overlap check SKIPs, never a pass.)
Check("the page: on, the preview and its picks tried; off, the off card", Count(log, "verdict PASS page: page switch on: the preview on the page") == 1
	and Count(log, "verdict PASS page: page switch off: the off card shows") == 1
	and Count(log, "verdict SKIP page: no real layout to measure") == 1)
Check("a shot per sample, per state, the open dropdown, per page state, the compare and the layout",
	shots == 4 + #ns.GAME_PLATE_STATES + 1 + 2 + (4 + #ns.GAME_PLATE_STATES + 3) + 1 + 7 + 4, shots)
	-- (+1: the State dropdown open; Nameplate Style's page: a shot per unit, per state, the theme, Customize, off;
	-- +7: the Layout tab's game places, a kind's bottom row (2026-11-25), nudge (the game's place), Custom,
	-- Balanced, popped out and off; +4: the
	-- target's plate as the game has it,
	-- with the layout, after the game's re-layout, the switch off.)
Check("the Layout tab built, opened, its switch on and off", Has(log, "verdict PASS layoutpage: the Layout page built and shown") ~= nil
	and Has(log, "verdict PASS layoutpage: switch off: the off card") ~= nil)
Check("the Layout tab holds no keyboard (the first build took every key)",
	Count(log, "verdict PASS layoutpage: .*no keyboard") == 2, Count(log, "no keyboard"))
Check("a layout on the target's plate: no errors, all back with the switch off",
	Has(log, "verdict PASS layoutlive: 0 plate layout errors") ~= nil and Has(log, "verdict PASS layoutlive: switch off: nothing moved") ~= nil)
Check("the compare's sizes logged", Count(log, "  SIZE ") == 10, Count(log, "  SIZE "))
Check("one texture through the same code: the same fill", Has(log, "PASS compare: the same look gives the same fill") ~= nil,
	Has(log, "FILL"))
Check("the real plate's own fill back", Has(log, "PASS compare: the real plate's own fill back") ~= nil, Has(log, "put back"))
Check("the setting put back", ns.db.combatTextStyle == nil or ns.db.combatTextStyle == ns.DEFAULTS.combatTextStyle,
	tostring(ns.db.combatTextStyle))
for _, line in ipairs(log or {}) do if os.getenv("PLATEMATCH_LOG") then print("  | " .. line) end end

-- A plain run (the user, 2026-11-23: "this test testing everything is costing
-- me a lot of time"): the proven steps left out, Nameplate Style's page only,
-- its two states that reach past the plate, no off pass, theme or Customize.
local openedBefore = #opened
ns.HandleSlash("debug platematch")
Advance(200)
log = CinematicDB.plateMatchTestLog
done = Has(log, "DONE: ")
Check("plain: finished, nothing failed", done ~= nil and done:find(" 0 fail", 1, true) ~= nil, done or Has(log, "verdict FAIL"))
-- (The page's step only: the three layout steps proven 2026-11-25, runs q57bf and q2431.)
Check("plain: the page's step only, of eight", Has(log, "start: /cine debug platematch, .*1 of 8 step") ~= nil
	and Has(log, "step %d stylepage") ~= nil and Has(log, "step %d preview") == nil, Has(log, "start:"))
Check("plain: each unit with its debuffs and crowd control, no state loop", Count(log, "verdict PASS stylepage: page state %a+:") == 0
	and Count(log, "verdict SKIP stylepage: %a+: places not read") == 4, Count(log, "places not read"))
Check("plain: the theme pointed at checked (new on the previewer)", Has(log, "verdict PASS stylepage: a theme pointed at") ~= nil)
-- (Opened once: Nameplate Style. The Layout tab's step is proven, left out.)
Check("plain: the off pass, the state loop and Customize left out", #opened - openedBefore == 1
	and Has(log, "verdict PASS stylepage: page switch off") == nil and Has(log, "verdict PASS stylepage: Customize opens") == nil
	-- (2026-11-25 Style Studio: 2 proven lines, was 3; the Customize button is gone, its proven check with it.
	-- OK'd by the user.)
	and Count(log, "  proven, not checked again") == 2, Count(log, "  proven, not checked again"))
for _, line in ipairs(log or {}) do if os.getenv("PLATEMATCH_LOG") then print("  | " .. line) end end
print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
os.exit(fails == 0 and 0 or 1)
