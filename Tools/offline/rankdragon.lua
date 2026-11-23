-- The elite, rare or boss dragon round a theme's portrait (Style/UnitStyle.lua
-- PlaceRank), offline, Lua 5.1 via run.py:
--   python -I Tools/offline/run.py Tools/offline/rankdragon.lua <forever|retail> < /dev/null
-- On a stand-in TargetFrame laid out as the game's XML (portrait 58 at TOPRIGHT
-- -26,-19, the dragon hung on the container's TOPRIGHT):
--   a theme's shape on, the game placing each dragon as it does (rare, boss,
--   elite, the client's own offsets): it sits about the portrait's middle as
--   the game's sat about its own, grown with the shape;
--   the game placing it again (a new target): moved once more, not stacked;
--   the game's shape again: back on the game's spot at the game's size.
-- (The Discord report: Forever's winged silver rare dragon small and off to the
-- side under a theme's portrait.)
-- Says PASS or FAIL per check; exits 1 on any FAIL.
local F = dofile("Tools/style-lab/frames.lua")
local client = ... or "forever"

-- luacheck: push ignore 111 112 113 121 122 212
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function(w)
	F.Install(w)
	rawset(_G, "CreateFontFamily", false)
end)
C_Timer.After = function(_, fn) fn() end
UnitExists = function(unit) return unit == "player" or unit == "target" end
UnitClassification = function() return "rare" end
InCombatLockdown = function() return false end
-- luacheck: pop

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print(("%s %s: %s%s"):format(ok and "PASS" or "FAIL", client, name, detail and (" (" .. tostring(detail) .. ")") or ""))
end

-- The game's target frame (TargetFrame.xml).
local frame = CreateFrame("Button", "TargetFrame", UIParent)
frame:SetSize(232, 100)
frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 300, -200)
frame:Show()
frame.PlayerFrameContainer, frame.TargetFrameContent = false, false
frame.FrameTexture, frame.HealthBar, frame.ManaBar, frame.Name, frame.Portrait = false, false, false, false, false
local holder = CreateFrame("Frame", nil, frame)
holder:SetAllPoints()
frame.TargetFrameContainer = holder
holder.FrameTexture = holder:CreateTexture(nil, "BORDER")
holder.FrameTexture:SetAllPoints()
holder.AlternatePowerFrameTexture, holder.VehicleFrameTexture = false, false
local rank = holder:CreateTexture(nil, "ARTWORK", nil, 2)
rank:SetSize(80, 79) -- (the gold elite atlas, as the XML loads it)
rank:SetPoint("TOPRIGHT", -11, -8)
rank:Hide()
holder.BossPortraitFrameTexture = rank
frame.portrait = holder:CreateTexture(nil, "BACKGROUND")
frame.portrait:SetSize(58, 58)
frame.portrait:SetPoint("TOPRIGHT", -26, -19)
frame.healthbar = CreateFrame("StatusBar", nil, frame)
frame.healthbar:SetSize(124, 20)
frame.healthbar:SetPoint("TOPLEFT", 22, -40)
frame.manabar = CreateFrame("StatusBar", nil, frame)
frame.manabar:SetSize(124, 10)
frame.manabar:SetPoint("TOP", frame.healthbar, "BOTTOM", 0, -1)
frame.name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
frame.name:SetPoint("BOTTOMLEFT", frame.healthbar, "TOPLEFT", 0, 4)
frame.name:SetText("Zopilote")
frame.levelText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
frame.levelText:SetPoint("BOTTOMRIGHT", frame.healthbar, "TOPRIGHT", 0, 4)
frame.unit = "target"

-- Each dragon as the client's GetBossPortraitFrameData gives it (atlas size, TOPRIGHT offset).
local DRAGONS = client == "forever" and {
	{ "rare", 99, 81, 8, -7 }, { "boss", 106, 82, 11, -4 }, { "elite", 80, 79, 0, 1 },
} or {
	{ "rare", 80, 79, -11, -8 }, { "boss", 99, 81, 8, -8 }, { "elite", 80, 79, -11, -8 },
}
local function GamePlaces(d) -- (TargetFrameMixin:CheckClassification)
	rank:SetSize(d[2], d[3])
	rank:SetPoint("TOPRIGHT", holder, "TOPRIGHT", d[4], d[5])
	rank:Show()
end
local function Mid(r)
	local x, y = r:GetCenter()
	return x, y
end
-- (Stock: the dragon's middle from the portrait's middle, both on the game's spots.)
local function StockOffset(d)
	local px, py = -26 - 29, -19 - 29
	return (d[4] - d[2] / 2) - px, (d[5] - d[3] / 2) - py
end

-- Stock first: the game's own shape, nothing moved.
local stockRight = {}
for _, d in ipairs(DRAGONS) do
	GamePlaces(d)
	local rx, ry = Mid(rank)
	local px, py = Mid(frame.portrait)
	local sx, sy = StockOffset(d)
	Check(d[1] .. ": no theme, the game's spot", math.abs(rx - px - sx) < 0.01 and math.abs(ry - py - sy) < 0.01,
		("%.1f,%.1f vs %.1f,%.1f"):format(rx - px, ry - py, sx, sy))
	stockRight[d[1]] = rank:GetRight()
end

-- A theme with a shape of its own.
for _, key in ipairs({ "styleGeneral", "ufStyle" }) do ns.db[key] = true end
ns.db.styleTheme = "game"
ns.ApplyStyleTheme("neon", true)
local view = ns.UnitFrameLook and ns.UnitFrameLook("target")
Check("the theme gives the target a shape", view and view.ufShape and view.ufShape ~= "game", view and view.ufShape)
local wide = frame.portrait:GetWidth()
Check("the theme's portrait is bigger than the game's", wide > 58, wide)

for _, d in ipairs(DRAGONS) do
	for pass = 1, 2 do
		GamePlaces(d) -- (twice: a new target, the game placing it again)
		local rx, ry = Mid(rank)
		local px, py = Mid(frame.portrait)
		local sx, sy = StockOffset(d)
		local w = rank:GetWidth()
		local size = w / d[2]
		Check(("%s (%d): grown with the portrait"):format(d[1], pass), size >= wide / 58 - 0.001,
			("x%.3f, portrait x%.3f"):format(size, wide / 58))
		Check(("%s (%d): as far off the portrait's middle as the game's, grown"):format(d[1], pass),
			math.abs((rx - px) - sx * size) < 0.05 and math.abs((ry - py) - sy * size) < 0.05,
			("%.1f,%.1f vs %.1f,%.1f"):format(rx - px, ry - py, sx * size, sy * size))
		Check(("%s (%d): one point, on the portrait"):format(d[1], pass),
			rank:GetNumPoints() == 1 and select(2, rank:GetPoint(1)) == frame.portrait, rank:GetNumPoints())
	end
end

-- Back to the game's look.
ns.ApplyStyleTheme("game", true)
local last = DRAGONS[#DRAGONS]
local rx, ry = Mid(rank)
local px, py = Mid(frame.portrait)
local sx, sy = StockOffset(last)
Check("no theme: back on the game's spot", math.abs(rx - px - sx) < 0.01 and math.abs(ry - py - sy) < 0.01,
	("%.1f,%.1f vs %.1f,%.1f"):format(rx - px, ry - py, sx, sy))
Check("no theme: the game's size", math.abs(rank:GetWidth() - last[2]) < 0.01, rank:GetWidth())
Check("no theme: on the container", select(2, rank:GetPoint(1)) == holder)
GamePlaces(DRAGONS[1])
Check("no theme, the game places it: untouched", math.abs(rank:GetRight() - stockRight[DRAGONS[1][1]]) < 0.01)

print(fails == 0 and "all passed" or (fails .. " failed"))
if fails > 0 then os.exit(1) end
