-- /cine debug selftextstyle (Dev/SelfTextStyleTest.lua), offline (Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/selftextstyletest.lua < /dev/null
-- One run, one thing to do: the command starts it, the page goes on and
-- CineMode off, steps 1-2 draw samples by themselves, step 3 waits (no time
-- limit) for one message from the game, step 4 gives the game's back, every
-- step gets a verdict and its own screenshot second, your settings and
-- CineMode come back; typed again it stops. Says PASS or FAIL per check.
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
hooksecurefunc = function(obj, name, fn)
	if type(obj) == "string" then obj, name, fn = _G, obj, name end
	local old = obj[name]
	obj[name] = function(...)
		local a, b, c, d = old(...)
		fn(...)
		return a, b, c, d
	end
end
local shots = {}
Screenshot = function() shots[#shots + 1] = math.floor(now) end
local cine = true
ns.IsCineModeOn = function() return cine end
_G.Cinematic_ToggleCineMode = function() cine = not cine end
local box = ""
ns.PadTestBox = function(text, sub) box = tostring(text) .. " | " .. tostring(sub) end
ns.PadTestBoxHide = function() end
local ct = CreateFrame("Frame")
ct._alpha = 1
ct.SetAlpha = function(self, a) self._alpha = a end
ct.GetAlpha = function(self) return self._alpha end
_G.CombatText = ct
local text = ct:CreateFontString()
text.GetTextColor = function() return 1, 0.1, 0.1 end
-- luacheck: pop

local function Tick(seconds)
	for _ = 1, math.floor((seconds or 0.1) / 0.1 + 0.5) do
		now = now + 0.1
		for i = #timers, 1, -1 do if timers[i].at <= now then table.remove(timers, i).fn() end end
		for _, frame in ipairs(ns.selfTextFrames) do
			local update = frame._scripts.OnUpdate
			if update and frame._shown then pcall(update, frame, 0.1) end
		end
		if ticker and not ticker.cancelled then ticker.fn() end
	end
end
local function Has(want)
	for _, line in ipairs(CinematicDB.selfTextStyleLog or {}) do if line:find(want, 1, true) then return line end end
end
-- The game's own message: its event, its text drawn.
local function Message()
	wow.Fire("COMBAT_TEXT_UPDATE", "HEAL")
	text:SetText("+120")
	Tick(0.3)
end

Check("the command is on ns", type(ns.SelfTextStyleTest) == "function")
local real, called = ns.SelfTextStyleTest, nil
ns.SelfTextStyleTest = function() called = true end
ns.HandleSlash("debug selftextstyle")
Check("/cine debug selftextstyle starts it", called == true)
ns.SelfTextStyleTest = real

local db = ns.db
db.styleGeneral, db.selfTextStyle, db.selfTextSide = false, false, "over"
local beforeColor, beforeBy = db.selfText_damageColor, db.selfTextBy
ns.SelfTextStyleTest()
Check("CineMode off", cine == false)
Check("page on for the run", db.styleGeneral == true and db.selfTextStyle == true)
Tick(4)
Check("verdict 1: samples drawn", Has("verdict 1 samples: PASS: 6 of 6 drawn") ~= nil)
Tick(5)
Check("verdict 2: looks drawn", Has("verdict 2 looks: PASS: 6 of 6 drawn") ~= nil)
Check("step 3 asks for one heal or hit", box:find("HEAL YOURSELF ONCE", 1, true) ~= nil, box)
Check("the game's hidden while waiting", ct._alpha == 0)
Tick(30)
Check("no time limit: still waiting", box:find("HEAL YOURSELF ONCE", 1, true) ~= nil and not Has("verdict 3"))
Message()
Tick(3)
Check("verdict 3: the real one copied", Has("verdict 3 real: PASS: 1 copied, 1 shown, the game's hidden true") ~= nil)
Tick(3)
Check("verdict 4: the game's back", Has("verdict 4 game's: PASS") ~= nil)
Check("done box: all pass", box:find("done: 4 of 4 PASS", 1, true) ~= nil, box)
Check("your settings back", db.styleGeneral == false and db.selfTextStyle == false and db.selfTextSide == "over"
	and db.selfText_damageColor == beforeColor and db.selfTextBy == beforeBy)
Check("CineMode back", cine == true)
Check("the game's frame as it was", ct._alpha == 1)
Check("nothing errored", not Has("error:"))
-- (Each shot in its own second, so each is its own file.)
local seconds = {}
local apart = #shots == 3
for _, second in ipairs(shots) do
	if seconds[second] then apart = false end
	seconds[second] = true
end
Check("three screenshots, each its own second", apart, table.concat(shots, " "))

-- An error during a step: that step FAILs.
ticker = nil
ns.SelfTextStyleTest()
Tick(0.5)
ns.Log("deverror", "boom")
Tick(4)
Check("an error fails its step", Has("verdict 1 samples: FAIL: ERRORS 1 (first: boom)") ~= nil)
ns.SelfTextStyleTest()
Check("stopped", Has("stopped") ~= nil and box:find("stopped", 1, true) ~= nil, box)
Check("settings back after a stop", db.selfTextStyle == false and cine == true and ct._alpha == 1)

for _, warning in ipairs(wow.warnings) do
	if warning:find("SelfText", 1, true) then Check("load: " .. warning, false) end
end
print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
