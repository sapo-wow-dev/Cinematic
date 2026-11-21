-- /cine debug selftextmerge (Dev/SelfTextMergeTest.lua, a test kit test),
-- offline (Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/selftextmerge.lua < /dev/null
-- On a stand-in fight: the game's CombatText draws each hit on you with
-- secret words, two seconds apart. The command starts it, the page goes on,
-- the run's 3 s merge window catches real hits, the verdict passes only on
-- merged secret words shown with their count; with hits too far apart (no
-- merge) it keeps waiting, no false PASS; the usual window, your settings
-- and CineMode come back. Says PASS or FAIL per check.
-- luacheck: push ignore 111 112 113 121 122 212 213
local now = 100
local ns, wow = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc", function()
	GetTime = function() return now end
end)
local SECRET = {}
local function S(v) local t = { v = v } SECRET[t] = true return t end
issecretvalue = function(v) return SECRET[v] == true end
hooksecurefunc = function(obj, name, fn)
	if type(obj) == "string" then obj, name, fn = _G, obj, name end
	local old = obj[name]
	obj[name] = function(...)
		local a, b, c, d = old(...)
		fn(...)
		return a, b, c, d
	end
end
local M = wow.Methods
function M:SetFont(file, size, flags) self._font = { file, size, flags } return true end
function M:GetFont() return self._font and self._font[1] end
function M:SetTextColor(r, g, b) self._color = { r, g, b } end
function M:GetTextColor() return unpack(self._color or { 1, 1, 1 }) end
function M:SetFormattedText(fmt, words, count)
	-- (As the game: a secret word goes in whole, the line it makes is secret.)
	self._text = SECRET[words] and S(fmt) or fmt:format(tostring(words), count)
end
local cvars = { enableFloatingCombatText = "1" }
GetCVar = function(name) return cvars[name] end
local timers, tickers = {}, {}
C_Timer.After = function(seconds, fn) timers[#timers + 1] = { at = now + seconds, fn = fn } end
C_Timer.NewTicker = function(every, fn)
	local t = { every = every, next = now + every, fn = fn, Cancel = function(self) self.cancelled = true end }
	tickers[#tickers + 1] = t
	return t
end
local shots = 0
Screenshot = function() shots = shots + 1 end
local cine = true
ns.IsCineModeOn = function() return cine end
_G.Cinematic_ToggleCineMode = function() cine = not cine end
ns.PadTestBox = function() end
ns.PadTestBoxHide = function() end
-- The game's floating combat text: its frame and texts.
local ct = CreateFrame("Frame")
ct.SetAlpha = function(self, a) self._alpha = a end
ct.GetAlpha = function(self) return self._alpha or 1 end
_G.CombatText = ct
local gameText = ct:CreateFontString()
-- luacheck: pop

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end
for _, frame in ipairs(ns.selfTextFrames) do frame._isEngine = true end
local function Tick(seconds)
	for _ = 1, math.floor(seconds / 0.1 + 0.5) do
		now = now + 0.1
		local due = {}
		for i = #timers, 1, -1 do if timers[i].at <= now then due[#due + 1] = table.remove(timers, i) end end
		for i = #due, 1, -1 do due[i].fn() end
		for _, frame in ipairs(wow.frames) do
			local update = frame._scripts.OnUpdate
			if update and frame._shown and frame._isEngine then pcall(update, frame, 0.1) end
		end
		for _, t in ipairs(tickers) do
			if not t.cancelled and t.next <= now then t.next = now + t.every t.fn(t) end
		end
	end
end
local function Has(want)
	for _, line in ipairs(CinematicDB.selfTextMergeTestLog or {}) do if line:find(want, 1, true) then return line end end
end
-- A hit on you, as the game draws it: its event, then its secret words.
local function Hit(words)
	wow.Fire("COMBAT_TEXT_UPDATE", "DAMAGE")
	gameText:SetText(S(words))
end

local db = ns.db
db.selfTextStyle, db.selfTextMerge, db.selfTextLife = false, false, 1.6
ns.HandleSlash("debug selftextmerge")
Tick(1)
Check("started: the page on for the run", db.selfTextStyle == true and db.selfTextMerge == true and db.selfTextBy == "ours")
Check("the run's merge window", ns.selfTextMergeWindow == 3)
Check("CineMode off", cine == false)
Tick(20)
Check("no hits: still waiting, no verdict", not Has("verdict"))
for i = 1, 3 do
	Hit("-" .. (10 + i))
	Tick(2)
end
Tick(10)
Check("fight step: PASS", Has("verdict PASS fight:") ~= nil, Has(" fight:") or Has("verdict"))
Check("its words probed secret", Has("probe the merged text's words: ok=true type=table secret=true") ~= nil,
	Has("probe the merged text's words"))
Check("a screenshot of it", shots >= 1)
Check("back step: PASS", Has("verdict PASS back:") ~= nil, Has(" back:"))
Check("DONE: 2 pass", Has("DONE: 2 pass, 0 fail") ~= nil, Has("DONE"))
Check("the usual window again", ns.selfTextMergeWindow == nil)
Check("your settings back", db.selfTextStyle == false and db.selfTextMerge == false and db.selfTextLife == 1.6)
Check("CineMode back", cine == true)

-- Hits too far apart to merge (5 s): it keeps waiting, never a PASS.
CinematicDB.selfTextMergeTestLog = {}
ns.HandleSlash("debug selftextmerge")
Tick(1)
for i = 1, 4 do
	Hit("-" .. (20 + i))
	Tick(5)
end
Check("no merge: no PASS, still waiting", not Has("verdict PASS fight:") and not Has("DONE"))
ns.HandleSlash("debug selftextmerge") -- (stops it)
Tick(1)
Check("stopped: the window and settings back", ns.selfTextMergeWindow == nil and db.selfTextStyle == false and cine == true)

for _, warning in ipairs(wow.warnings) do
	if warning:find("SelfText", 1, true) then Check("load: " .. warning, false) end
end
print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
