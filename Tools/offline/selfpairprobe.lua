-- The side-by-side test's probe of every part (/cine debug shoulder selfpair,
-- Dev/ShoulderCamTest.lua) on game-like frames (offline, Lua 5.1 via
-- Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/selfpairprobe.lua < /dev/null
-- You targeted, the run going through a few themes on its own: each shot
-- logs a line per part for both frames (the game's target frame of you and
-- ours), found on both, with their place, alpha and holds. Runs 3 and 4
-- each lacked the probe their answer needed (2026-11-21); this checks the
-- probe finds every part, so a run can't come back blind. Says PASS or FAIL.
local F = dofile("Tools/style-lab/frames.lua")
-- Stand-in game frames, laid out as the game's (as unitmatch.lua's): the
-- frame art over the whole frame, the portrait to one side, the bars by it.
function GameFrame(name, flip) -- luacheck: ignore 111
	local frame = CreateFrame("Button", name, UIParent)
	frame:SetSize(232, 100)
	frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", flip and 300 or 20, -20)
	frame:Show()
	frame.unit = flip and "target" or "player"
	local holder = CreateFrame("Frame", nil, frame)
	holder:SetAllPoints()
	-- (The stand-in answers any unknown key with a stub: the other layout's keys none.)
	frame.PlayerFrameContainer, frame.TargetFrameContainer, frame.TargetFrameContent = false, false, false
	frame.FrameTexture, frame.HealthBar, frame.ManaBar, frame.Name, frame.Portrait = false, false, false, false, false
	frame[flip and "TargetFrameContainer" or "PlayerFrameContainer"] = holder
	holder.FrameTexture = holder:CreateTexture(nil, "BORDER")
	holder.FrameTexture:SetAllPoints()
	holder.FrameTexture:SetAtlas("UI-HUD-UnitFrame-" .. (flip and "Target" or "Player") .. "-PortraitOn")
	frame.portrait = holder:CreateTexture(nil, "BACKGROUND")
	frame.portrait:SetSize(60, 60)
	frame.portrait:SetPoint(flip and "TOPRIGHT" or "TOPLEFT", flip and -24 or 24, -19)
	frame.healthbar = CreateFrame("StatusBar", nil, frame)
	frame.healthbar:SetSize(124, 20)
	frame.healthbar:SetPoint(flip and "TOPLEFT" or "TOPRIGHT", flip and 22 or -22, -40)
	frame.healthbar:SetStatusBarTexture("UI-HUD-UnitFrame-" .. (flip and "Target" or "Player") .. "-PortraitOn-Bar-Health")
	frame.healthbar:SetStatusBarColor(1, 1, 1)
	frame.manabar = CreateFrame("StatusBar", nil, frame)
	frame.manabar:SetSize(124, 10)
	frame.manabar:SetPoint("TOP", frame.healthbar, "BOTTOM", 0, -1)
	frame.manabar:SetStatusBarTexture("UI-HUD-UnitFrame-" .. (flip and "Target" or "Player") .. "-PortraitOn-Bar-Mana")
	-- (Each bar's numbers, as the game's: TextString, in the middle.)
	for _, bar in ipairs({ frame.healthbar, frame.manabar }) do
		bar.TextString = bar:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
		bar.TextString:SetPoint("CENTER", bar, "CENTER", 0, 0)
	end
	frame.name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.name:SetPoint("BOTTOMLEFT", frame.healthbar, "TOPLEFT", 0, 4)
	frame.name:SetText("Sapo")
	-- (The target frame's level ring and level, as Forever's: where a theme
	-- with a shaped portrait lifts them onto a badge and shrinks them.)
	if flip then
		local content = CreateFrame("Frame", nil, frame)
		content:SetAllPoints()
		local main = CreateFrame("Frame", nil, content)
		main:SetAllPoints()
		frame.TargetFrameContent, content.TargetFrameContentMain = content, main
		main.LevelBackgroundCircle = main:CreateTexture(nil, "ARTWORK")
		main.LevelBackgroundCircle:SetSize(39, 39)
		main.LevelBackgroundCircle:SetPoint("TOPLEFT", frame, "TOPLEFT", 180, -54)
		main.LevelText = main:CreateFontString(nil, "OVERLAY", "GameNormalNumberFont")
		main.LevelText:SetPoint("CENTER", main.LevelBackgroundCircle, "CENTER", 0, 0)
		main.LevelText:SetText("11")
		main.ReputationColor = main:CreateTexture(nil, "ARTWORK")
		main.ReputationColor:SetSize(135, 18)
		main.ReputationColor:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -26)
	end
	return frame
end

local client = ...
client = client or "forever"

-- luacheck: push ignore 111 112 113 121 122 212
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function(w)
	F.Install(w)
	rawset(_G, "CreateFontFamily", false)
	GameFrame("PlayerFrame", false)
	GameFrame("TargetFrame", true)
end)
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. client .. ": " .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end
-- (Errors Cinematic catches, from the stand-in's build and Style's dressing.)
local caught = {}
local report = ns.ReportError
ns.ReportError = function(err, ...)
	caught[#caught + 1] = tostring(err)
	if report then return report(err, ...) end
end
local target = false
UnitExists = function(unit) return unit == "player" or (unit == "target" and target) end
UnitIsUnit = function(a, b) return a == b end
InCombatLockdown = function() return false end
GetCVar = function(name) if name == "autoSelfCast" then return "1" end end
ns.ShoulderCamUnlocked = function() return true end
-- (The Shoulder Cam on: its page switch sits under the Camera hub's own.)
local setting = ns.Setting
ns.Setting = function(key, ...) if key == "shoulderCam" then return true end return setting(key, ...) end
-- luacheck: pop

-- luacheck: push ignore 111 112 113 121 122
local db = ns.db
db.shoulderCam, db.shoulderCamFakeSelf = true, false
db.ufStyle, db.styleGeneral = true, true
local up, steps = ns.PageSwitchOf and ns.PageSwitchOf("ufStyle"), 0
while up and steps < 10 do db[up], up, steps = true, ns.PageSwitchOf(up), steps + 1 end
-- (You targeted, as the run asks; a few themes, the screen, a clock.)
target = true
UnitIsUnit = function(a, b) if a == "target" and b == "player" then return target end return a == b end
local now = 100
GetTime = function() return now end
GetPhysicalScreenSize = function() return 3440, 1440 end
Screenshot = function() end
SetCVar = function() end
local themes = ns.StyleThemeList
ns.StyleThemeList = function() local all = themes() return { all[1], all[2], all[3] } end
ns.ShoulderSelfTargetIconCrop = ns.ShoulderSelfTargetIconCrop or function() end
-- (Its update loop, driven here.)
local update
local set = ns.SetOnUpdate
ns.SetOnUpdate = function(frame, fn) if fn then update = fn end return set(frame, fn) end
-- luacheck: pop
-- (The game's health text's anchor secret, as with health on it in game:
-- logging it broke run 12, the probe's join erroring on it.)
local SECRET_POINT = "CENTER<secret>"
local secretWas = issecretvalue
issecretvalue = function(v) return v == SECRET_POINT or (secretWas and secretWas(v)) or false end -- luacheck: ignore 121
do
	local text = _G.TargetFrame.healthbar and _G.TargetFrame.healthbar.TextString
	if text then
		text.GetPoint = function() return SECRET_POINT, _G.TargetFrame.healthbar, SECRET_POINT, 0, 0 end
	end
end
-- (A contextual layer on the game's frame, its PvP flag shown: the probe
-- lists its shown parts by name, run 14.)
do
	local content = _G.TargetFrame.TargetFrameContent
	if content then
		local context = CreateFrame("Frame", nil, _G.TargetFrame)
		context:SetAllPoints()
		context.PvpIcon = context:CreateTexture(nil, "ARTWORK")
		context.PvpIcon:SetSize(24, 24)
		context.PvpIcon:SetPoint("TOPLEFT", _G.TargetFrame, "TOPLEFT", 170, -40)
		context.PrestigePortrait = context:CreateTexture(nil, "ARTWORK")
		context.PrestigePortrait:SetSize(30, 30)
		context.PrestigePortrait:SetPoint("TOPLEFT", _G.TargetFrame, "TOPLEFT", 170, -40)
		context.PrestigePortrait:Hide()
		content.TargetFrameContentContextual = context
	end
end
ns.ShoulderSelfPair()
for _ = 1, 400 do
	now = now + 0.1
	if update then pcall(update) end
	-- (It waits at Buffs on Top for you: stop there, the sweep's done.)
	local lines = db.shoulderSelfPair or {}
	if lines[#lines] and lines[#lines]:find("asked: Buffs on Top") then break end
end
local lines = db.shoulderSelfPair or {}
local parts, found, missing = 0, {}, {}
for _, line in ipairs(lines) do
	local part, game, ours = line:match("^[%d.]+ part %S+ (.-) | game (.-) | ours (.*)$")
	if part then
		parts = parts + 1
		found[part] = found[part] or { game = 0, ours = 0 }
		if game ~= "none" then found[part].game = found[part].game + 1 end
		if ours ~= "none" then found[part].ours = found[part].ours + 1 end
		if game:find("error=") or ours:find("error=") then missing[#missing + 1] = part .. " errored" end
	end
end
Check("part lines logged for every shot", parts >= 11 * 3, parts .. " lines")
for _, part in ipairs({ "art", "strip", "name", "level", "level ring", "health", "power", "health text", "power text", "portrait" }) do
	local f = found[part]
	Check(("%s found on both frames"):format(part), f and f.game > 0 and f.ours > 0,
		f and ("game %d, ours %d"):format(f.game, f.ours) or "no line")
end
Check("no part's read errored", #missing == 0, missing[1])
local ended = lines[#lines] or ""
Check("the run not stopped by an error", not ended:find("end: error"), ended)
local secretLine
for _, line in ipairs(lines) do if line:find(" part %S+ health text |") then secretLine = line break end end
Check("a secret anchor logged as secret", secretLine and secretLine:find("anchor=secret>") ~= nil, secretLine)
local listed, hidden = false, false
for _, line in ipairs(lines) do
	if line:find(" context %S+ game PvpIcon |") then listed = true end
	if line:find(" context %S+ game PrestigePortrait |") then hidden = true end
end
Check("the contextual layer's shown parts listed by name", listed)
Check("its hidden parts left out", not hidden)
-- (Each bar's numbers' drawn height on both frames: the "looks right" check
-- of Tools/selfpair.py needs it.)
local heights = 0
for _, line in ipairs(lines) do
	if line:find(" part %S+ health text |") or line:find(" part %S+ power text |") then
		local _, n = line:gsub(" th=[%d.]+", "")
		if n == 2 then heights = heights + 1 end
	end
end
Check("bar numbers' heights read on both frames", heights > 0, heights .. " lines with both")
-- (A sample: the art's place is its own origin, 0,0, on both.)
local art
for _, line in ipairs(lines) do if line:find(" part %S+ art |") then art = line break end end
Check("the art at 0,0 on both", art and select(2, art:gsub("x=0%.0 y=0%.0", "")) == 2, art)
Check("no errors", #caught == 0, caught[1])
if ns.ShoulderSelfPair then ns.ShoulderSelfPair() end -- (stopped: puts things back)
print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
