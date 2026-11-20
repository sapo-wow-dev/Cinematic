-- The Shoulder Cam's stand-in target frame of you in your Style theme
-- (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/selfframetheme.lua <forever|retail> < /dev/null
-- Keep the shoulder when selecting yourself clears your target and shows a
-- target frame of you drawn by us (ShoulderCam.lua); it carries the game's
-- target frame's part names, so Style's unit frames dress it as your target
-- frame (UnitStyle.lua's TARGET list). On the style lab's game-like frames
-- (Tools/style-lab/frames.lua): a theme on, you select yourself through the
-- option's own button, and the stand-in's health bar, power bar and name are
-- dressed as the game's target frame is; no error on the way; the game's
-- plain look with the theme off. Both clients. Says PASS or FAIL per check.
local F = dofile("Tools/style-lab/frames.lua")
local client = ... or "forever"

-- luacheck: push ignore 111 112 113 121 122 212
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function(w)
	F.Install(w)
	rawset(_G, "CreateFontFamily", false)
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

-- Stand-in game frames, laid out as the game's (as unitmatch.lua's): the
-- frame art over the whole frame, the portrait to one side, the bars by it.
local function GameFrame(name, flip)
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
	frame.name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.name:SetPoint("BOTTOMLEFT", frame.healthbar, "TOPLEFT", 0, 4)
	frame.name:SetText("Sapo")
	return frame
end
GameFrame("PlayerFrame", false)
GameFrame("TargetFrame", true)

local db = ns.db
db.shoulderCam, db.shoulderCamFakeSelf = true, true
db.ufStyle, db.styleGeneral = true, true
-- (Every switch above Unit Frames on too: a Style look needs the whole chain.)
local up, steps = ns.PageSwitchOf and ns.PageSwitchOf("ufStyle"), 0
while up and steps < 10 do db[up], up, steps = true, ns.PageSwitchOf(up), steps + 1 end
db.styleTheme = "forge"
-- (A custom health color: both frames' bars must come out this red.)
db.ufHealthColor, db.ufHealthR, db.ufHealthG, db.ufHealthB = "custom", 0.8, 0.1, 0.1
wow.Fire("PLAYER_REGEN_ENABLED") -- (the option's check: keys and the button)
local state = ns.ShoulderFakeSelfState()
Check("the option's on", state.want, state.why)

-- You select yourself: the button's click (its macro clears the target; then ours).
local click = state.button and state.button:GetScript("OnClick")
Check("the button has its click", click ~= nil)
if click then click(state.button, "LeftButton", true) end
local stand = ns.ShoulderSelfTargetFrame and ns.ShoulderSelfTargetFrame()
Check("the stand-in is up", stand ~= nil and stand:IsShown())

-- Both dressed by Style now (the stand-in came up through RefreshUnitStyle).
local real = _G.TargetFrame
if stand and real then
	local function Fill(bar)
		local fill = bar and bar.GetStatusBarTexture and bar:GetStatusBarTexture()
		return fill and (fill.GetTexture and fill:GetTexture() or fill.GetAtlas and fill:GetAtlas())
	end
	local function Color(bar)
		if not (bar and bar.GetStatusBarColor) then return "none" end
		local r, g, b = bar:GetStatusBarColor()
		return ("%.2f %.2f %.2f"):format(r or -1, g or -1, b or -1)
	end
	local function Font(text)
		-- (Not "a and b and GetFont()": that keeps the file only, never the size.)
		if not (text and text.GetFont) then return "none" end
		local file, size = text:GetFont()
		return tostring(file) .. " " .. tostring(size)
	end
	Check("health bar art as your target frame's", Fill(stand.healthbar) == Fill(real.healthbar),
		tostring(Fill(stand.healthbar)) .. " vs " .. tostring(Fill(real.healthbar)))
	Check("power bar art as your target frame's", Fill(stand.manabar) == Fill(real.manabar),
		tostring(Fill(stand.manabar)) .. " vs " .. tostring(Fill(real.manabar)))
	Check("name font as your target frame's", Font(stand.name) == Font(real.name),
		Font(stand.name) .. " vs " .. Font(real.name))
	-- (The theme makes a custom color a touch more vivid: 0.85 0.08 0.08.)
	local r, g, b = real.healthbar:GetStatusBarColor()
	Check("the theme's on (your target frame's health bar in the custom red)", r and r > 0.7 and g < 0.2 and b < 0.2,
		Color(real.healthbar))
	Check("health bar in the custom red, as your target frame's", Color(stand.healthbar) == Color(real.healthbar),
		Color(stand.healthbar) .. " vs " .. Color(real.healthbar))
end
Check("no errors", #caught == 0, caught[1])

-- The theme off: the game's plain look back on it.
db.ufStyle = false
if ns.RefreshUnitStyle then ns.RefreshUnitStyle() end
Check("no errors with the theme off", #caught == 0, caught[1])

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
