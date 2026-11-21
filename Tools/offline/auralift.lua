-- Buffs on top kept off a theme's name plate (Style/UnitAuraLift.lua), offline,
-- Lua 5.1 via run.py:
--   python -I Tools/offline/run.py Tools/offline/auralift.lua <forever|retail> < /dev/null
-- On the style lab's real-layout stand-in with a stand-in TargetFrame and its
-- buff row on top, reaching into the name row (the Discord report's look):
--   Neon Coast + Buffs On Top: the row is lifted clear of the plate's top;
--   the game placing the row again (ClearAllPoints + SetPoint), or laying out
--   its auras with nothing moved: lifted once, never twice;
--   Buffs On Top off, or no theme: the row back where the game put it;
--   retail: only each row's first aura moved, the rest follow it.
-- Forever's row is one container whose icons' places are secret (rule
-- forever.targetframe.aura-container-place-secret): nothing reads them.
-- Says PASS or FAIL per check; exits 1 on any FAIL.
local F = dofile("Tools/style-lab/frames.lua")
local client = ... or "forever"

-- luacheck: push ignore 111 112 113 121 122 212
local SECRET = setmetatable({}, { __tostring = function() return "secret" end })
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function(w)
	F.Install(w)
	rawset(_G, "CreateFontFamily", false)
	issecretvalue = function(value) return value == SECRET end
end)
C_Timer.After = function(_, fn) fn() end
UnitExists = function(unit) return unit == "player" or unit == "target" end
InCombatLockdown = function() return false end
-- luacheck: pop

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print(("%s %s: %s%s"):format(ok and "PASS" or "FAIL", client, name, detail and (" (" .. tostring(detail) .. ")") or ""))
end

-- The game's target frame, retail's layout (as unitmatch.lua builds it).
local frame = CreateFrame("Button", "TargetFrame", UIParent)
frame:SetSize(232, 100)
frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 300, -200)
frame:Show()
frame.PlayerFrameContainer, frame.TargetFrameContent = false, false
frame.FrameTexture, frame.HealthBar, frame.ManaBar, frame.Name, frame.Portrait = false, false, false, false, false
frame.GetAuraContainer, frame.auraPools, frame.UpdateAuraPositions = false, false, false
frame.buffsOnTop = true
local holder = CreateFrame("Frame", nil, frame)
holder:SetAllPoints()
frame.TargetFrameContainer = holder
holder.FrameTexture = holder:CreateTexture(nil, "BORDER")
holder.FrameTexture:SetAllPoints()
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

local function Adjust(self, dx, dy) -- (AdjustPointsOffset: the game sums it into the points)
	local p, rel, rp, x, y = self:GetPoint(1)
	self:ClearAllPoints()
	self:SetPoint(p, rel, rp, x + dx, y + dy)
end
-- (The game's own place for the row: just over its strip, 1 high gap.)
local START_Y = 15
local row, second, auras
local function Place()
	row:ClearAllPoints()
	row:SetPoint("BOTTOMLEFT", frame.healthbar, "TOPLEFT", 0, START_Y)
	if second then
		second:ClearAllPoints()
		second:SetPoint("LEFT", row, "RIGHT", 2, 0)
	end
end
if client == "forever" then
	row = CreateFrame("Frame", nil, frame)
	row:SetSize(60, 19)
	frame.GetAuraContainer = function() return row end
	local icon = CreateFrame("Frame", nil, row)
	icon:SetAllPoints()
	icon.GetBottom = function() return SECRET end
	icon.GetTop = function() return SECRET end
else
	row = CreateFrame("Frame", nil, frame)
	row:SetSize(19, 19)
	second = CreateFrame("Frame", nil, frame)
	second:SetSize(19, 19)
	second.AdjustPointsOffset = Adjust
	auras = { row, second }
	frame.auraPools = { EnumerateActive = function()
		local i = 0
		return function() i = i + 1 return auras[i] end
	end }
end
row.AdjustPointsOffset = Adjust
-- (The adjust's own ClearAllPoints / SetPoint must not look like the game's:
-- done on the raw methods, as the engine's own sum is.)
local rawClear, rawSet = row.ClearAllPoints, row.SetPoint
row.AdjustPointsOffset = function(self, dx, dy)
	local p, rel, rp, x, y = self:GetPoint(1)
	rawClear(self)
	rawSet(self, p, rel, rp, x + dx, y + dy)
end
Place()
row:Show()
local laid = 0
frame.UpdateAuras = function() laid = laid + 1 end -- (hooked by UnitAuraLift once a plate is laid)

local function Px(r, side)
	local v = side == "top" and r:GetTop() or r:GetBottom()
	return v * r:GetEffectiveScale()
end
local gameBottom = Px(row, "bottom")
local function PlateTop()
	local best
	for _, part in ipairs(ns.UnitThemeArt(frame)) do
		if part.cell and part:IsShown() then
			best = part:GetTop()
			for _, region in ipairs({ part:GetRegions() }) do
				if region:IsShown() and region:GetTop() > best then best = region:GetTop() end
			end
			best = best * part:GetEffectiveScale()
		end
	end
	return best
end

-- Style on, Neon Coast picked.
for _, key in ipairs({ "styleGeneral", "ufStyle" }) do ns.db[key] = true end
ns.db.styleTheme = "game"
ns.ApplyStyleTheme("neon", true)
local plateTop = PlateTop()
Check("Neon plate drawn on the target", plateTop ~= nil)
Check("the stand-in reproduces the report: the plate reaches into the row", plateTop and plateTop > gameBottom,
	("plate top %s, game's row bottom %s"):format(tostring(plateTop), tostring(gameBottom)))
local bottom = Px(row, "bottom")
Check("row lifted clear of the plate", plateTop and bottom >= plateTop + 0.5 and bottom <= plateTop + 3,
	("row bottom %.1f, plate top %s"):format(bottom, tostring(plateTop)))

-- The game places it again: lifted once, not twice.
Place()
local again = Px(row, "bottom")
Check("game's SetPoint again: lifted once", math.abs(again - bottom) < 0.01, ("%.1f vs %.1f"):format(again, bottom))
frame:UpdateAuras()
frame:UpdateAuras()
local still = Px(row, "bottom")
Check("auras laid out with nothing moved: not doubled", math.abs(still - bottom) < 0.01, ("%.1f vs %.1f"):format(still, bottom))
Check("the game's UpdateAuras still runs", laid == 2, laid)
if second then
	Check("retail: the second aura follows the first (not moved itself)",
		math.abs(Px(second, "bottom") - Px(row, "bottom")) < 0.01)
end

-- Buffs On Top off: back where the game puts them.
frame.buffsOnTop = false
frame:UpdateAuras()
Check("buffs on top off: row back to the game's place", math.abs(Px(row, "bottom") - gameBottom) < 0.01,
	("%.1f vs %.1f"):format(Px(row, "bottom"), gameBottom))
frame.buffsOnTop = true
frame:UpdateAuras()
Check("buffs on top again: lifted again", math.abs(Px(row, "bottom") - bottom) < 0.01)

-- A strip read off something outside the frame: no wild lift.
local realStrip = _G.TargetFrameNameBackground
local stray = UIParent:CreateTexture(nil, "BACKGROUND")
stray:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
stray:SetSize(10, 10)
rawset(_G, "TargetFrameNameBackground", stray)
frame:UpdateAuras()
local lift = ns.UnitAuraLiftNow(frame)
Check("a strip outside the frame: lift kept as it was, not hundreds", lift > 0 and lift <= 20, lift)
rawset(_G, "TargetFrameNameBackground", realStrip)
frame:UpdateAuras()

-- No theme: no plate, no lift.
ns.ApplyStyleTheme("game", true)
Check("no theme: row back to the game's place", math.abs(Px(row, "bottom") - gameBottom) < 0.01,
	("%.1f vs %.1f"):format(Px(row, "bottom"), gameBottom))
Place()
Check("no theme, game places it again: untouched", math.abs(Px(row, "bottom") - gameBottom) < 0.01)

print(fails == 0 and "all passed" or (fails .. " failed"))
if fails > 0 then os.exit(1) end
