-- /cine debug selftext check (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/selftext.lua < /dev/null
-- The Shoulder Cam text-on-you probe (Dev/SelfTextProbe.lua) on a stand-in
-- of the game's CombatText: the command starts it, CineMode goes off, each
-- step waits for 4 hits (no time limit) and moves on, its setup is done and
-- put back (pink hook, font object, frame alpha, the CVar), our stand-in
-- text takes the amount, errors are counted per step, the verdicts are
-- written, and typed again mid-run it stops with everything put back.
-- luacheck: push ignore 111 112 113 121 122 212 213
local ns, wow = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc")

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local now = 100
GetTime = function() return now end
local timers, ticker = {}, nil
C_Timer.After = function(seconds, fn) timers[#timers + 1] = { at = now + seconds, fn = fn } end
C_Timer.NewTicker = function(_, fn) ticker = { fn = fn, Cancel = function(self) self.cancelled = true end } return ticker end
local cvars = { enableFloatingCombatText = "1", floatingCombatTextFloatMode = "1" }
GetCVar = function(name) return cvars[name] end
SetCVar = function(name, value) cvars[name] = tostring(value) end
C_Console = { GetAllCommands = function()
	return { { command = "enableFloatingCombatText" }, { command = "floatingCombatTextFloatMode" }, { command = "other" } }
end }
-- (A real hooksecurefunc: the stand-in's does nothing.)
hooksecurefunc = function(obj, name, fn)
	if type(obj) == "string" then obj, name, fn = _G, obj, name end
	local old = obj[name]
	obj[name] = function(...)
		local a, b, c, d = old(...)
		fn(...)
		return a, b, c, d
	end
end
Screenshot = function() end
local info = { "COMBO_POINTS", 3 }
C_CombatText = { GetCurrentEventInfo = function() return unpack(info) end, GetActiveUnit = function() return "player" end }
local cine = true
ns.IsCineModeOn = function() return cine end
_G.Cinematic_ToggleCineMode = function() cine = not cine end
local box = ""
ns.PadTestBox = function(text, sub) box = tostring(text) .. " | " .. tostring(sub) end
ns.PadTestBoxHide = function() end

-- The game's CombatText: a frame with three texts, its font object.
local ct = CreateFrame("Frame")
local ctAlpha = 1
ct.SetAlpha = function(_, a) ctAlpha = a end
ct.GetAlpha = function() return ctAlpha end
_G.CombatText = ct
local texts = {}
for i = 1, 3 do
	local fs = ct:CreateFontString()
	fs._color = { 1, 1, 1 }
	fs.SetTextColor = function(self, r, g, b) self._color = { r, g, b } end
	fs.GetTextColor = function(self) return unpack(self._color) end
	fs.GetFont = function() return "Fonts\\FRIZQT__.TTF", 25, "" end
	fs.GetFontObject = function() return _G.CombatTextFont end
	texts[i] = fs
end
local font = { file = "Fonts\\FRIZQT__.TTF", size = 25, flags = "" }
_G.CombatTextFont = {
	GetFont = function() return font.file, font.size, font.flags end,
	SetFont = function(_, file, size, flags) font.file, font.size, font.flags = file, size, flags end,
	GetName = function() return "CombatTextFont" end,
}
-- luacheck: pop

local function Tick(seconds)
	for _ = 1, math.floor((seconds or 0.2) / 0.2 + 0.5) do
		now = now + 0.2
		for i = #timers, 1, -1 do
			if timers[i].at <= now then
				local fn = table.remove(timers, i).fn
				fn()
			end
		end
		if ticker and not ticker.cancelled then ticker.fn() end
	end
end
local function Log() return CinematicDB.selfTextLog or {} end
local function Has(text)
	for _, line in ipairs(Log()) do if line:find(text, 1, true) then return line end end
end
local function Fire(event, ...) wow.Fire(event, ...) end
local function Hits(n, action)
	for _ = 1, n do
		Fire("UNIT_COMBAT", "player", action or "WOUND", "", 50, 1)
		Tick(0.4)
	end
	Tick(1.4)
end

Check("the command is on ns", type(ns.SelfTextProbe) == "function")
local real, called = ns.SelfTextProbe, nil
ns.SelfTextProbe = function(args) called = args or "" end
ns.HandleSlash("debug selftext")
Check("/cine debug selftext starts it", called == "")
ns.HandleSlash("debug selftext mirror")
Check("step names passed on", called == "mirror", called)
ns.SelfTextProbe = real

-- 1. A whole run.
ns.SelfTextProbe()
Check("CineMode off for the run", cine == false)
Check("start logged", Has("start: Forever") ~= nil)
Check("survey: font object", Has("CombatTextFont table: Fonts\\FRIZQT__.TTF, 25.00") ~= nil)
Check("survey: the CVars", Has("cvar floatingCombatTextFloatMode = 1") ~= nil)
Check("survey: C_CombatText", Has("C_CombatText: GetActiveUnit GetCurrentEventInfo") ~= nil)
Check("step 1 asks for hits", box:find("Step 1 of 7", 1, true) ~= nil, box)
Tick(5)
Check("no time limit: still step 1 with no hits", box:find("Step 1 of 7", 1, true) ~= nil, box)
Fire("COMBAT_TEXT_UPDATE", "COMBO_POINTS")
Check("event info logged", Has("COMBAT_TEXT_UPDATE COMBO_POINTS | info COMBO_POINTS, 3.00") ~= nil)
Hits(4)
Check("hit logged", Has("UNIT_COMBAT player WOUND  amount 50.00 school 1.00") ~= nil)
Check("texts read at a screenshot", Has("screenshot step 1 watch hit 1") ~= nil)
Check("verdict 1", Has("verdict 1 watch: no errors") ~= nil)
Check("on to step 2", box:find("Step 2 of 7", 1, true) ~= nil, box)
texts[1]:SetTextColor(1, 1, 1)
Check("step 2: the game's color turns pink", texts[1]._color[3] == 1 and texts[1]._color[2] == 0.3,
	table.concat(texts[1]._color, " "))
Hits(4)
Check("verdict 2: recolored", Has("verdict 2 color: no errors, 1 recolored") ~= nil)
Check("step 3: font object bigger", font.size == 40 and font.flags == "THICKOUTLINE", font.size .. " " .. font.flags)
texts[1]:SetTextColor(1, 1, 1)
Check("pink hook idle after its step", texts[1]._color[2] == 1)
ns.Log("deverror", "CombatText.lua:364: compare boom")
Hits(4)
Check("verdict 3: error counted", Has("verdict 3 font: ERRORS 1 (first: CombatText.lua:364: compare boom)") ~= nil)
Check("font put back", font.size == 25 and font.flags == "", font.size)
Check("step 4: frame hidden", ctAlpha == 0)
Hits(4)
Check("alpha put back", ctAlpha == 1)
Check("step 5: the game's text off", cvars.enableFloatingCombatText == "0")
Fire("COMBAT_TEXT_UPDATE", "AURA_START")
Hits(4)
Check("verdict 5: events still come", Has("verdict 5 off: PASS: COMBAT_TEXT_UPDATE still comes") ~= nil)
Check("CVar put back", cvars.enableFloatingCombatText == "1")
Fire("COMBAT_TEXT_UPDATE", "COMBO_POINTS")
Hits(3)
Hits(1, "DODGE")
Check("verdict 6: ours drawn", Has("verdict 6 ours: PASS: drew 4 hits, 1 other kinds") ~= nil)
Check("step 7: the game's frame hidden", ctAlpha == 0)
Check("step 7 box", box:find("Step 7 of 7", 1, true) ~= nil, box)
-- (The game draws each hit: color, then its words.)
for _ = 1, 4 do
	texts[2]:SetTextColor(1, 0.1, 0.1)
	texts[2]:SetText("-12")
	Fire("UNIT_COMBAT", "player", "WOUND", "", 12, 1)
	Tick(0.4)
end
Tick(1.4)
Check("verdict 7: copied", Has("verdict 7 mirror: PASS: copied 4 of 4 drawn (2 from the words given, 2 read back), 4 colored") ~= nil)
Check("alpha put back after the mirror", ctAlpha == 1)
Check("done box", box:find("Combat text test done", 1, true) ~= nil, box)
Check("CineMode put back", cine == true)
Check("ticker stopped", ticker.cancelled == true)
Check("nothing errored", not Has("error:") and not Has("survey error"))

-- 1b. Only the mirror step, named.
ticker = nil
ns.SelfTextProbe("mirror")
Check("named step only", box:find("Step 1 of 1", 1, true) ~= nil and Has("--- step 7 mirror") ~= nil, box)
Check("no other step", not Has("--- step 1 watch"))
texts[3]:SetText("Mana Low")
Hits(4)
Check("one-step run done", box:find("Combat text test done", 1, true) ~= nil and Has("verdict 7 mirror: PASS: copied 1 of 1") ~= nil, box)

-- 2. Typed again mid-run (in the hide step): stops, all put back.
ticker = nil
ns.SelfTextProbe()
Hits(4)
Hits(4)
Hits(4)
Check("mid-run: frame hidden", ctAlpha == 0)
ns.SelfTextProbe()
Check("stopped", Has("stopped") ~= nil and box:find("stopped", 1, true) ~= nil, box)
Check("alpha put back after a stop", ctAlpha == 1)
Check("CineMode put back after a stop", cine == true)
Hits(4)
Check("no step after a stop", not Has("--- step 5"))

for _, warning in ipairs(wow.warnings) do
	if warning:find("SelfText", 1, true) then Check("load: " .. warning, false) end
end
print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
