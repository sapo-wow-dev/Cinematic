-- The name jump test (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/namejump.lua < /dev/null
-- /cine debug namejump (Dev/NameScaleTest.lua) on the stand-in, with pretend
-- time and a pretend walk: stand by an NPC, walk 0 -> 38 yards and back.
-- The plate shrinks 0.64 -> 0.42 past 29 yards only while Far names smaller
-- is on, as the ledger's Q13 found. Checked: the spot marks, the shrink is
-- logged at its yards in walk 1 and not in walk 2 (Far names smaller off
-- then), the cause line names it, the answer is logged, and Far names
-- smaller is back on after. PASS or FAIL per check.
-- luacheck: push ignore 111 112 113 121 122 212
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end
local function Has(log, pattern)
	for _, line in ipairs(log or {}) do
		if line:find(pattern, 1, true) then return line end
	end
end

local ns = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc")
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
local function Click(button) button:GetScript("OnClick")(button, "LeftButton") end

-- The world: you at px yards from the NPC (at 0), walking at speed.
local px, speed, shots = 0, 0, 0
local far = ns.plates.FAR_NAME_CVARS
ns.ApplyCVarSet(far, true) -- (CineMode with every plate on: held)
UnitPosition = function() return 0, px end
GetUnitSpeed = function() return speed end
-- (Targeted until you press Escape; then found among the plates by GUID.)
local targeted = true
UnitExists = function(unit) return unit ~= "target" or targeted end
UnitGUID = function(unit) return (unit ~= "target" or targeted) and "Creature-0-1-2-3-4-NPC" or nil end
UnitIsPlayer = function() return false end
UnitName = function() return "Fishing Supplier" end
UnitDistanceSquared = function() return nil, false end
CheckInteractDistance = function(_, n) return px < (n == 4 and 28 or 10) end
GetCameraZoom = function() return 12 end
Screenshot = function() shots = shots + 1 end
ns.IsCineModeOn = function() return true end
ns.PadTestBox = function() end
ns.PadTestBoxHide = function() end
-- (Far names smaller: shrunk past 41 yards from the camera, zoom 12: 29 from you; never the target's.)
local plate = { GetAlpha = function() return 1 end, UnitFrame = {}, namePlateUnitToken = "nameplate3",
	GetEffectiveScale = function()
		-- (Past 45, every plate shrinks away, both walks: run 15. Not the jump.)
		if px > 45 then return 0.01 end
		return (far.active and not targeted and px > 29) and 0.416 or 0.64
	end }
C_NamePlate = { GetNamePlateForUnit = function() return plate end, GetNamePlates = function() return { plate } end }
local oursUntargeted = false
local ours = { IsVisible = function() return targeted or oursUntargeted end, GetAlpha = function() return 1 end }
ns.PlateNameState = function() return nil, 8, 0.69, -41, ours end

local function Walk(to, step)
	speed = 7
	while (step > 0 and px < to) or (step < 0 and px > to) do
		px = px + step
		Advance(0.1)
	end
	speed = 0
	Advance(4) -- (STOP 2 s, then the next step's 1 s)
end

-- (Too far first: the box and log say what's missing, run 16's report.)
px = 15
ns.HandleSlash("debug namejump")
Advance(1)
local log = CinematicDB.nameJumpTestLog
Check("too far: says it's waiting to be closer", Has(log, "waiting for: closer to Fishing Supplier: within 10 yards")
	~= nil, Has(log, "waiting for"))
px = 0
Advance(3) -- (standing by the NPC: marked after 2 s still)
Check("asks for Escape", Has(log, "asked: Press ESCAPE") ~= nil)
-- (First NPC: its name shows only while targeted, run 17's Steven Black.)
targeted = false
Advance(2)
Check("a name hidden untargeted: asks for another NPC", Has(log, "name not shown untargeted") ~= nil
	and Has(log, "asked: That NPC's name doesn't show untargeted. Pick ANOTHER one.") ~= nil, Has(log, "try 1"))
oursUntargeted, targeted = true, true
Advance(3)
targeted = false
Advance(2)
Check("step 1: the spot marked", Has(log, "PASS setup: your position reads") ~= nil)
Check("the plate found again untargeted, name showing",
	Has(log, "PASS setup: the NPC's plate found again by its GUID, untargeted, its name showing: nameplate3") ~= nil,
	Has(log, "found again"))
Check("the shrink's expected yards logged", Has(log, "the shrink expected ~29 yd from you") ~= nil)
Walk(46.5, 0.25)
Check("walk 1: the shrink logged past 29 yd", Has(log, "29.2 yd: plate scale 0.64 -> 0.42") ~= nil,
	Has(log, "plate scale"))
Check("walk 1 done", Has(log, "walk 1 done") ~= nil and Has(log, "walk 2: Far names smaller off") ~= nil,
	Has(log, "walk 2:"))
Walk(5, -0.25)
-- (The game's range band flips at 28 both ways, nothing on screen: left out of the window.)
local window = Has(log, "walk 2 (Far names smaller off), 24-46 yd:")
Check("walk 2: no shrink in the window, the band flip left out of it", window ~= nil
	and not window:find("-> 0.42", 1, true) and not window:find("game's range", 1, true)
	and Has(log, "game's range >28yd -> <28yd") ~= nil, window)
Check("cause: Far names smaller", Has(log, "cause by the log: Far names smaller's plate shrink") ~= nil,
	Has(log, "cause by"))
Check("our size held (zoom only)", Has(log, "PASS result: our size and height held") ~= nil)
Check("screenshots on changes", shots > 0, shots)
local run = ns.TestKit.Running()
Check("asks which walk", run and run.buttons and run.buttons.Both ~= nil)
if run and run.buttons and run.buttons.Both then Click(run.buttons.Both) end
Advance(3)
Check("answer logged", Has(log, "you saw the jump in: Both") ~= nil)
local done = Has(log, "DONE: ")
Check("DONE, no fail", done ~= nil and done:find(" 0 fail", 1, true) ~= nil, done)
Check("put back: Far names smaller on again, test flag cleared", far.active == true and ns.farNamesTestOff == nil,
	tostring(far.active))
Check("ruler stopped", ns.NameRulerYards() == nil)

-- /cine debug namesize (the Name Style page's Size choices), on the stand-in:
-- every step runs, each pick saved and Far names smaller following, put back.
-- (No layout or off card here: the page's place on screen is the game run's.)
ns.PageOffCardWanted = function() return false end
SettingsPanel = UIParent
ns.noRealLayout = true
C_NamePlate = { GetNamePlates = function() return {} end, GetNamePlateForUnit = function() return nil end }
ns.db.plateNameFarStep, ns.db.plateNameSizeBy = nil, nil
ns.HandleSlash("debug namesize")
Advance(30)
local sizeLog = CinematicDB.nameSizeTestLog
Check("namesize: six choices made", Has(sizeLog, "PASS page: six choices made (6)") ~= nil, Has(sizeLog, "choices made"))
-- (Since 2026-11-23 each pick is our own step; plates one size isn't held here:
-- no plate pass has CineMode's every plate on.)
for _, word in ipairs({ "Far names 1: saved 1, our step 1", "Far names 0.9: saved 0.9, our step 0.9",
	"Far names 0.8: saved 0.8, our step 0.8", "Far names 0.65: saved 0.65, our step 0.65", "Size by fixed saved",
	"Size by zoom saved" }) do
	Check("namesize picks: " .. word, Has(sizeLog, "PASS picks: " .. word) ~= nil, Has(sizeLog, word:match("^%S+ %S+ %S+")))
end
local sizeDone = Has(sizeLog, "DONE: ")
Check("namesize DONE, 0 fail (tabs picked: Size shown)", sizeDone ~= nil and sizeDone:find(" 0 fail", 1, true) ~= nil
	and Has(sizeLog, "PASS tabs: Size tab: the choices shown (6 of 6)") ~= nil, sizeDone)
if not sizeDone then -- (what it got to instead)
	for _, line in ipairs(sizeLog or {}) do
		if line:find("verdict") or line:find("error") or line:find("step ") or line:find("clicked") then print("  log: " .. line) end
	end
end
Check("namesize put back: Far names and Size by unset", ns.db.plateNameFarStep == nil and ns.db.plateNameSizeBy == nil,
	tostring(ns.db.plateNameFarStep) .. " " .. tostring(ns.db.plateNameSizeBy))

-- /cine debug zoomstep: you stand still 32 yards out, the test zooms (a pretend
-- camera, 0 to 20). Since 2026-11-23 the game's camera step is never held, so
-- the plate stays 0.64 at any zoom (the stand-in steps only while the set
-- is held, as the game did: it never is now), and our name keeps its size.
do
	local zoomNow = 7
	ns.GAME_ZOOM = {
		CameraZoomOut = function(y) zoomNow = math.min(20, zoomNow + y) end,
		CameraZoomIn = function(y) zoomNow = math.max(0, zoomNow - y) end,
	}
	GetCameraZoom = function() return zoomNow end
	px, speed, targeted, oursUntargeted = 32, 0, true, true
	local stepping = function() return ns.plates.FAR_NAME_CVARS.active end
	local zplate = { GetAlpha = function() return 1 end, UnitFrame = {}, namePlateUnitToken = "nameplate4",
		GetEffectiveScale = function() return (stepping() and zoomNow + px > 41) and 0.416 or 0.64 end }
	C_NamePlate = { GetNamePlateForUnit = function() return zplate end, GetNamePlates = function() return { zplate } end }
	ns.db.plateNameFarStep = 0.8
	ns.HandleSlash("debug zoomstep")
	Advance(3)
	local zlog = CinematicDB.zoomStepTestLog
	Check("zoomstep: asks for Escape once still past 28 yards", Has(zlog, "asked: Press ESCAPE") ~= nil, Has(zlog, "waiting for"))
	targeted = false
	Advance(70)
	Check("zoomstep: never moved", Has(zlog, "PASS step: you never moved") ~= nil, Has(zlog, "never moved"))
	Check("zoomstep: zooming changed neither the plate nor our name",
		Has(zlog, "PASS step: standing still, zooming changed neither the plate (steps: none) nor our name (1 size(s))")
		~= nil, Has(zlog, "zooming changed neither"))
	Check("zoomstep: a shot", Has(zlog, "screenshot Far names Much smaller") ~= nil)
	Advance(60)
	Check("zoomstep control: no step with Same size", Has(zlog, "PASS control: with Far names Same size, no step") ~= nil,
		Has(zlog, "control:"))
	local zdone = Has(zlog, "DONE: ")
	Check("zoomstep DONE, 0 fail", zdone ~= nil and zdone:find(" 0 fail", 1, true) ~= nil, zdone)
	Check("zoomstep put back: zoom 7, Far names 0.8", zoomNow == 7 and ns.db.plateNameFarStep == 0.8,
		("zoom %s, Far names %s"):format(tostring(zoomNow), tostring(ns.db.plateNameFarStep)))
	if not zdone then
		for _, line in ipairs(zlog or {}) do
			if line:find("verdict") or line:find("error") then print("  zlog: " .. line) end
		end
	end
end

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
-- luacheck: pop
