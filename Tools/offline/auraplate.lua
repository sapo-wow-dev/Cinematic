-- /cine debug auraplate (Dev/AuraPlateTest.lua) offline, Lua 5.1 via run.py:
--   python -I Tools/offline/run.py Tools/offline/auraplate.lua <forever|retail> < /dev/null
-- On the style lab's real-layout stand-in (Tools/style-lab/frames.lua) with a
-- stand-in TargetFrame laid out as the game's and one buff on top of it:
--   the run goes through every step to DONE with no Lua error;
--   each step's measure line is written, the row's place read;
--   Neon Coast's plate is found and measured (a top, an overlap number);
--   it waits for Edit Mode to close before its looks;
--   with Neon Coast the fix (Style/UnitAuraLift.lua) lifts the row clear of
--   the plate, in and out of a fight; no theme leaves it where the game puts it;
--   your theme and the Style switches are put back at the end.
-- Says PASS or FAIL per check; exits 1 on any FAIL.
local F = dofile("Tools/style-lab/frames.lua")
local client = ... or "forever"

-- luacheck: push ignore 111 112 113 121 122 212
local SECRET = setmetatable({}, { __tostring = function() return "secret" end })
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function(w)
	F.Install(w)
	rawset(_G, "CreateFontFamily", false)
	issecretvalue = function(value) return value == SECRET end
end)
C_UnitAuras = { GetAuraDataByIndex = function(_, i) return i == 1 and SECRET or nil end }
Enum = Enum or {}
Enum.EditModeUnitFrameSetting = nil -- (Forever's had none, run 1: the ontop step skips)
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
UnitExists = function(unit) return unit == "player" or unit == "target" end
UnitIsUnit = function() return false end
UnitName = function() return "Frozen Soul" end
UnitReaction = function() return 2 end
local fighting = false
InCombatLockdown = function() return fighting end
local cine = false
ns.IsCineModeOn = function() return cine end
Cinematic_ToggleCineMode = function() cine = not cine end
ns.PadTestBox = function() end
ns.PadTestBoxHide = function() end
-- luacheck: pop

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print(("%s %s: %s%s"):format(ok and "PASS" or "FAIL", client, name, detail and (" (" .. tostring(detail) .. ")") or ""))
end
local function Has(log, pattern)
	for _, line in ipairs(log or {}) do
		if line:find(pattern) then return line end
	end
end

-- The game's target frame, retail's layout (as unitmatch.lua builds it).
local frame = CreateFrame("Button", "TargetFrame", UIParent)
frame:SetSize(232, 100)
frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 300, -200)
frame:Show()
frame.PlayerFrameContainer, frame.TargetFrameContent = false, false
frame.FrameTexture, frame.HealthBar, frame.ManaBar, frame.Name, frame.Portrait = false, false, false, false, false
frame.GetAuraContainer, frame.auraPools, frame.UpdateAuras, frame.UpdateAuraPositions = false, false, false, false
frame.buffsOnTop = true
local holder = CreateFrame("Frame", nil, frame)
holder:SetAllPoints()
frame.TargetFrameContainer = holder
holder.FrameTexture = holder:CreateTexture(nil, "BORDER")
holder.FrameTexture:SetAllPoints()
holder.FrameTexture:SetAtlas("UI-HUD-UnitFrame-Target-PortraitOn")
holder.AlternatePowerFrameTexture, holder.VehicleFrameTexture, holder.BossPortraitFrameTexture = false, false, false
frame.portrait = holder:CreateTexture(nil, "BACKGROUND")
frame.portrait:SetSize(60, 60)
frame.portrait:SetPoint("TOPRIGHT", -24, -19)
frame.healthbar = CreateFrame("StatusBar", nil, frame)
frame.healthbar:SetSize(124, 20)
frame.healthbar:SetPoint("TOPLEFT", 22, -40)
frame.manabar = CreateFrame("StatusBar", nil, frame)
frame.manabar:SetSize(124, 10)
frame.manabar:SetPoint("TOP", frame.healthbar, "BOTTOM", 0, -1)
frame.name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
frame.name:SetPoint("BOTTOMLEFT", frame.healthbar, "TOPLEFT", 0, 4)
frame.name:SetWidth(116)
frame.name:SetText("Frozen Soul")
-- (The game's name strip: on the health bar's top, 14 high.)
rawset(_G, "TargetFrameNameBackground", frame:CreateTexture(nil, "BACKGROUND"))
_G.TargetFrameNameBackground:SetPoint("BOTTOMLEFT", frame.healthbar, "TOPLEFT", 0, 0)
_G.TargetFrameNameBackground:SetSize(124, 14)
frame.levelText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
frame.levelText:SetPoint("BOTTOMRIGHT", frame.healthbar, "TOPRIGHT", 0, 4)
frame.unit = "target"
-- (A buff on top, low enough to reach the name row: the report's look.
-- Forever: in one container, the icon's place secret, as run 1 found it;
-- retail: a numbered buff of its own.)
local buff, row
if client == "forever" then
	row = CreateFrame("Frame", nil, frame)
	row:SetSize(60, 19)
	row:SetPoint("BOTTOMLEFT", frame.healthbar, "TOPLEFT", 0, 15) -- (just over the game's 14 high strip)
	frame.GetAuraContainer = function() return row end
	buff = CreateFrame("Frame", nil, row)
	buff:SetAllPoints()
	buff.GetBottom = function() return SECRET end
	buff.GetTop = function() return SECRET end
else
	buff = CreateFrame("Frame", "TargetFrameBuff1", frame)
	buff:SetSize(19, 19)
	buff:SetPoint("BOTTOMLEFT", frame.healthbar, "TOPLEFT", 0, 15) -- (just over the game's 14 high strip)
	row = buff
	frame.auraPools = { EnumerateActive = function()
		local done = false
		return function() if not done then done = true return buff end end
	end }
end
-- (AdjustPointsOffset: the engine sums it into the points, past any hook.)
local rawClear, rawSet = row.ClearAllPoints, row.SetPoint
row.AdjustPointsOffset = function(self, dx, dy)
	local p, rel, rp, x, y = self:GetPoint(1)
	rawClear(self)
	rawSet(self, p, rel, rp, x + dx, y + dy)
end
frame.UpdateAuras = function() end
-- (Edit Mode still open as the test starts its looks: it waits for the close.)
local edit = CreateFrame("Frame", "EditModeManagerFrame", UIParent)
edit:Show()
buff:Show()

ns.db.styleTheme = "game"
local was = { styleGeneral = ns.db.styleGeneral, ufStyle = ns.db.ufStyle }
local row0 = row:GetBottom()

ns.HandleSlash("debug auraplate")
Advance(5)
local log = CinematicDB.auraPlateTestLog
Check("waits for Edit Mode to close", Has(log, "asked: Close Edit Mode") ~= nil and Has(log, "step 5 neon") == nil)
edit:Hide()
Advance(30) -- (steps 4-5)
log = CinematicDB.auraPlateTestLog
Check("waits in the fight step", Has(log, "asked: Hit a mob once") ~= nil)
fighting = true
wow.Fire("PLAYER_REGEN_DISABLED")
Advance(15)
fighting = false
wow.Fire("PLAYER_REGEN_ENABLED")
Advance(5)
log = CinematicDB.auraPlateTestLog
for _, line in ipairs(log or {}) do print("  | " .. line) end
Check("DONE, nothing failed", Has(log, "DONE: %d+ pass, 0 fail") ~= nil, Has(log, "DONE: "))
Check("no Lua error in the test", Has(log, "Lua error") == nil, Has(log, "Lua error"))
Check("game look: no lift", Has(log, "PASS game: no theme") ~= nil, Has(log, "lift game"))
Check("Neon: lifted", Has(log, "PASS neon: Neon with buffs on top: the row lifted") ~= nil, Has(log, "lift neon"))
Check("Neon: row clear of the plate (readable here)", Has(log, "PASS neon: row clear of the plate, not far off") ~= nil,
	Has(log, "measure neon"))
Check("fight: still lifted", Has(log, "PASS fight: in a fight: the row's lift") ~= nil, Has(log, "lift in a fight"))
Check("row back where the game put it", math.abs(row:GetBottom() - row0) < 0.01, row:GetBottom() .. " vs " .. row0)
Check("theme put back", ns.db.styleTheme == "game", ns.db.styleTheme)
Check("Style switches put back", ns.db.styleGeneral == was.styleGeneral and ns.db.ufStyle == was.ufStyle)
Check("screenshots taken", shots >= 3, shots)
print(fails == 0 and "all passed" or (fails .. " failed"))
if fails > 0 then os.exit(1) end
