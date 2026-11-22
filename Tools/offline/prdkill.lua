-- /cine debug prdkill (Dev/PrdKillTest.lua) on the stand-in, Forever, pretend
-- time: a fight, the power bar hidden mid-fight with its stand-in at 1 (a
-- DROP line, a FAIL verdict naming it), it back (a BACK line), your own
-- plate added (an ADDED (YOU) line), the fight's end and 40 s watched, then
-- Always and CineMode put back as they were. PASS or FAIL per check.
--   python -I Tools/offline/run.py Tools/offline/prdkill.lua < /dev/null
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

local ns, wow = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc", function()
	issecretvalue = function() return false end
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
UnitAffectingCombat = function() return fight end
UnitExists = function() return true end
UnitIsDeadOrGhost = function() return false end
UnitIsUnit = function(a, b) return a == b end
GetCVar = function(name) return name == "nameplateShowSelf" and "1" or "0" end

-- The bars: plain tables answering what the test reads.
local function Bar(name)
	return { name = name, visible = true, alpha = 1,
		IsVisible = function(self) return self.visible end, GetAlpha = function(self) return self.alpha end,
		GetEffectiveAlpha = function(self) return self.visible and self.alpha or 0 end,
		IsIgnoringParentAlpha = function() return false end, GetParent = function() return nil end,
		GetName = function(self) return self.name end }
end
local power, health = Bar("PowerBar"), Bar("HealthBarsContainer")
-- (In game a bar's effective alpha came back nil, run 3: the samples must live.)
local alternate = Bar("AlternatePowerBar")
alternate.visible = false
health.GetEffectiveAlpha = function() return nil end
local displayAlpha = 1
_G.PersonalResourceDisplayFrame = { PowerBar = power, HealthBarsContainer = health, AlternatePowerBar = alternate,
	IsShown = function() return true end, IsVisible = function() return true end,
	GetAlpha = function() return displayAlpha end,
	GetName = function() return "PersonalResourceDisplayFrame" end }
local plate = { UnitFrame = { GetAlpha = function() return 1 end }, IsShown = function() return true end,
	GetAlpha = function() return 1 end, GetName = function() return "NamePlate1" end }
C_NamePlate = C_NamePlate or {}
C_NamePlate.GetNamePlateForUnit = function(unit) return unit == "player" and plate or nil end
ns.managed = ns.managed or {}
table.insert(ns.managed, { name = "CinematicPersonalPower", alpha = 1 })
table.insert(ns.managed, { name = "CinematicPersonalResource", alpha = 1 })
ns.db.cineShow = ns.db.cineShow or {}
ns.db.cineShow.prdpower = nil
local alwaysWas = ns.IsCineShowOn("prdpower")

ns.HandleSlash("debug prdkill")
Advance(8) -- step 1 and its shot
Check("CineMode turned on for the run", cine == true)
Check("Always ticked for the run", ns.IsCineShowOn("prdpower") == true)
fight = true
Advance(3)
wow.Fire("NAME_PLATE_UNIT_ADDED", "player")
power.visible = false
Advance(4)
power.visible = true
Advance(2)
-- (Let go: shown, not ignoring its parent, the display frame faded.)
displayAlpha = 0.5
Advance(2)
displayAlpha = 1
Advance(1)
fight = false
Advance(45)
local log = CinematicDB.prdKillTestLog
local done = Has(log, "DONE: ")
Check("finished DONE", done ~= nil, done or Has(log, "FAIL Lua") or Has(log, "STOPPED"))
Check("a DROP line for the power bar in the fight", Has(log, "DROP power bar not drawn .*fight true") ~= nil)
Check("a BACK line", Has(log, "BACK power bar drawn again") ~= nil)
Check("your plate added logged", Has(log, "ADDED player %(YOU%) plate NamePlate1") ~= nil, Has(log, "ADDED"))
Check("the drop's FAIL verdict", Has(log, "FAIL .*power bar dropped at") ~= nil)
Check("state lines logged", Has(log, "state fight") ~= nil)
Check("screenshots: before, at the drop, after", shots == 3, shots)
Check("Always put back", ns.IsCineShowOn("prdpower") == alwaysWas)
Check("CineMode off again", cine == false)
Check("no sample error", Has(log, "SAMPLE ERROR") == nil, Has(log, "SAMPLE ERROR"))
Check("a let-go DROP line", Has(log, "DROP power bar let go, fading with the display frame") ~= nil)
Check("state lines through the fight's end", Has(log, "state fight false") ~= nil)
Check("no Lua error", Has(log, "Lua error") == nil, Has(log, "Lua error"))
for _, line in ipairs(log or {}) do if os.getenv("PRDKILL_LOG") then print("  | " .. line) end end
print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
os.exit(fails == 0 and 0 or 1)
