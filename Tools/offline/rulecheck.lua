-- Rule check test (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/rulecheck.lua < /dev/null
-- /cine debug rulecheck (Dev/RuleCheckTest.lua, dev copy) on a stand-in game:
-- the panel read and shot, the plate walk (bgTexture first, errors counted),
-- the camera trials (view saved, blend style 1 and 0, put back), a fight with
-- secret and plain UNIT_COMBAT amounts and UNIT_AURA, the three fight probes
-- each with a blocked action put down to it, then the reload step: blocked
-- (logged, DONE) and, in a second run, reloaded (the next login logs it).
-- CineMode, enemy plates and blend style put back; typed again mid-run, it
-- stops cleanly. Says PASS or FAIL per check.
-- luacheck: push ignore 111 112 113 121 122 212
local SECRET = setmetatable({}, { __tostring = function() return "secret" end })
local ns, wow = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc", function()
	issecretvalue = function(value) return value == SECRET end
end)

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

-- The clock and the timers.
local now, combat = 100, false
local timers, tickers = {}, {}
GetTime = function() return now end
InCombatLockdown = function() return combat end
C_Timer.After = function(delay, fn) timers[#timers + 1] = { at = now + delay, fn = fn } end
C_Timer.NewTicker = function(every, fn)
	local t = { every = every, next = now + every, fn = fn, Cancel = function(self) self.cancelled = true end }
	tickers[#tickers + 1] = t
	return t
end
local function Advance(seconds)
	local stop = now + seconds
	while now < stop - 1e-9 do
		now = now + 0.01
		for _, t in ipairs(tickers) do
			if not t.cancelled and now >= t.next then
				t.next = t.next + t.every
				t.fn()
			end
		end
		local due = {}
		for i = #timers, 1, -1 do
			if now >= timers[i].at then
				due[#due + 1] = timers[i]
				table.remove(timers, i)
			end
		end
		for i = #due, 1, -1 do due[i].fn() end
	end
end

local cvars = { cameraViewBlendStyle = "1", nameplateShowEnemies = "0", SoftTargetEnemy = "1" }
GetCVar = function(name) return cvars[name] end
SetCVar = function(name, value)
	cvars[name] = tostring(value)
	if combat and name:find("^SoftTarget") then wow.Fire("ADDON_ACTION_BLOCKED", "CinematicDev", "SetCVar()") end
	return true
end
local views, view = {}, { zoom = 10 }
SaveView = function(slot) views[slot] = { zoom = view.zoom } end
SetView = function(slot) if views[slot] then view.zoom = views[slot].zoom end end
GetCameraZoom = function() return view.zoom end
CameraZoomOut = function(n) view.zoom = view.zoom + n end
MoveViewDownStart, MoveViewDownStop = function() end, function() end
local shots = 0
Screenshot = function() shots = shots + 1 end
CheckInteractDistance = function() return SECRET end
SetUIVisibility = function() if combat then wow.Fire("ADDON_ACTION_BLOCKED", "CinematicDev", "SetUIVisibility()") end end
local reloaded
ReloadUI = function() wow.Fire("ADDON_ACTION_BLOCKED", "CinematicDev", "UNKNOWN()") end

-- A plate: bgTexture's point reads, the plate's own errors.
local function Piece(readable, kids)
	return {
		GetPoint = function() if readable then return "TOPLEFT", nil, "TOPLEFT", 0, 0 end error("restricted") end,
		GetLeft = function() if readable then return 5 end error("restricted") end,
		GetChildren = function() return unpack(kids or {}) end,
		GetRegions = function() return end,
	}
end
local bgTexture = Piece(true)
local healthBar = Piece(false)
healthBar.bgTexture = bgTexture
healthBar.GetRegions = function() return bgTexture end
local unitFrame = Piece(false, { healthBar })
unitFrame.healthBar = healthBar
local plate = Piece(false, { unitFrame })
plate.UnitFrame = unitFrame
local plates = {}
C_NamePlate = { GetNamePlates = function() return plates end, GetNamePlateForUnit = function() return plates[1] end }

local box = ""
ns.PadTestBox = function(text, sub) box = tostring(text) .. " / " .. tostring(sub) end
ns.PadTestBoxHide = function() end
ns.TestPrompt = function() end
local cine = true
ns.IsCineModeOn = function() return cine end
_G.Cinematic_ToggleCineMode = function() cine = not cine end
-- luacheck: pop

local function Log() return CinematicDB.ruleCheckLog or {} end
local function Has(text)
	for _, line in ipairs(Log()) do if line:find(text, 1, true) then return line end end
end
local function Fire(event, ...) wow.Fire(event, ...) end

CinematicDB = CinematicDB or {}
Check("the command is on ns", type(ns.RuleCheckTest) == "function")
local realTest, called = ns.RuleCheckTest, nil
ns.RuleCheckTest = function() called = true end
ns.HandleSlash("debug rulecheck")
Check("/cine debug rulecheck starts the test", called == true)
ns.RuleCheckTest = realTest

-- 1. A whole run, reload blocked.
ns.RuleCheckTest()
Check("start logged", Has("start: forever") ~= nil, Log()[1])
Check("CineMode off for the run", cine == false)
Check("enemy plates held on", cvars.nameplateShowEnemies == "1")
Check("panel: color alpha read", Has("color alpha: A text alpha") ~= nil)
Check("panel: zero height read", Has("zero height: frame") ~= nil, Has("zero"))
Check("panel: cyrillic fonts read", Has("cyrillic: E (text, then font object)") ~= nil)
Check("panel: blank font read", Has("blank font: SetFont returned") ~= nil)
Advance(2)
Check("panel screenshot", Has("screenshot (panel)") ~= nil)
Check("step 2 waits for a plate", box:find("nameplate shows", 1, true) ~= nil, box)
plates[1] = plate
Advance(0.3)
Check("bgTexture point read first", Has("plate healthBar.bgTexture: point TOPLEFT") ~= nil)
Check("plate errors counted", Has("plate: 4 pieces, 1 with a readable point, 3 errors") ~= nil,
	Has("pieces,"))
Check("camera step", box:find("camera moves by itself", 1, true) ~= nil, box)
Advance(18)
Check("view saved", views[4] ~= nil)
Check("blend 1 trial shot", Has("screenshot (blend 1: 0.15 s after SetView)") ~= nil)
Check("blend 0 trial shot", Has("screenshot (blend 2: 1.3 s after SetView)") ~= nil)
Check("zoom sampled", Has("zoom after SetView, blend 1:") ~= nil)
Check("blend style put back", cvars.cameraViewBlendStyle == "1", cvars.cameraViewBlendStyle)
Check("view put back under blend 1 at the end", Has("view put back; blend style put back: 1") ~= nil)
Check("fight step", box:find("Attack an enemy", 1, true) ~= nil, box)
combat = true
Advance(0.3)
Fire("UNIT_COMBAT", "target", "WOUND", "", SECRET, 1)
Fire("UNIT_COMBAT", "player", "WOUND", "", 12, 1)
Fire("UNIT_AURA", "player", { addedAuras = SECRET })
Fire("UNIT_AURA", "player", { addedAuras = { { auraInstanceID = 7 } } })
Advance(4)
Check("interact probe blocked or not", Has("probe CheckInteractDistance target 3: blocked actions none") ~= nil)
Check("SetUIVisibility blocked put down to it",
	Has("probe SetUIVisibility(true): blocked actions ADDON_ACTION_BLOCKED SetUIVisibility()") ~= nil)
Check("SoftTarget SetCVar blocked put down to it", Has("blocked actions ADDON_ACTION_BLOCKED SetCVar()") ~= nil)
Check("fight plate walked", Has("fight plate: 4 pieces") ~= nil)
for _ = 1, 8 do Fire("UNIT_COMBAT", "target", "WOUND", "", SECRET, 1) end
Advance(0.3)
Check("waits for the fight to end", box:find("Finish it", 1, true) ~= nil, box)
combat = false
Advance(0.3)
Check("result: amounts", Has("RESULT forever.unit_combat.amount: 9 of 10 amounts secret") ~= nil,
	Has("unit_combat.amount"))
Check("result: auras", Has("RESULT forever.unit_aura.addedauras: 1 of 2 player UNIT_AURA updates had addedAuras secret (1 plain)") ~= nil,
	Has("addedauras"))
Check("result: soft cvar", Has("RESULT forever.probe.softcvar: ran true, blocked") ~= nil, Has("probe.softcvar"))
Check("result: plate", Has("RESULT forever.plate.bgtexture-getpoint: out of fights bgTexture TOPLEFT") ~= nil)
Check("CineMode back before the reload", cine == true)
Check("plates put back", cvars.nameplateShowEnemies == "0")
Advance(6)
Check("reload blocked result", Has("RESULT forever.reloadui.addon-code: ReloadUI from addon code did not reload;"
	.. " blocked ADDON_ACTION_BLOCKED UNKNOWN()") ~= nil, Has("reloadui"))
Check("done box", box:find("Rule check DONE", 1, true) ~= nil, box)
Check("no pending reload", CinematicDB.ruleCheckReload == nil)
Check("screenshots taken", shots >= 8, shots)
Check("no errors logged", not Has("error:") and not Has("panel error"), Has("error"))
Check("no timers left on", (function()
	for _, t in ipairs(tickers) do if not t.cancelled then return false end end
	return true
end)())

-- 2. A reload that went through: the next login logs it.
CinematicDB.ruleCheckLog = {}
CinematicDB.ruleCheckReload = { at = time() - 2, client = "retail" }
reloaded = dofile("Tools/offline/load.lua")("retail", "CinematicDev.toc")
Advance(4)
Check("reload logged at the next login", Has("RESULT retail.reloadui.addon-code: ReloadUI() from addon code reloaded") ~= nil,
	Log()[1])
Check("pending cleared", CinematicDB.ruleCheckReload == nil)
Check("second load has the command", reloaded and type(reloaded.RuleCheckTest) == "function")

-- 3. Typed again mid-run: stops and puts things back.
cine, plates = true, {}
ns.RuleCheckTest()
Advance(2)
ns.RuleCheckTest()
Check("stopped early", Has("stopped early") ~= nil and box:find("stopped", 1, true) ~= nil, box)
Check("CineMode back after a stop", cine == true)
Check("plates put back after a stop", cvars.nameplateShowEnemies == "0")

for _, warning in ipairs(wow.warnings) do
	if warning:find("RuleCheck", 1, true) then Check("load: " .. warning, false) end
end
print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
