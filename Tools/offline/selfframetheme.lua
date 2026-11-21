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

local client, theme = ...
client = client or "forever"

-- luacheck: push ignore 111 112 113 121 122 212
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function(w)
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


local db = ns.db
db.shoulderCam, db.shoulderCamFakeSelf = true, true
db.ufStyle, db.styleGeneral = true, true
-- (Every switch above Unit Frames on too: a Style look needs the whole chain.)
local up, steps = ns.PageSwitchOf and ns.PageSwitchOf("ufStyle"), 0
while up and steps < 10 do db[up], up, steps = true, ns.PageSwitchOf(up), steps + 1 end
-- (Applied as the theme picker does, its settings written: setting its name
-- alone drew no shape, and the level badge went untested, 2026-11-20.)
ns.ApplyStyleTheme(theme or "forge", true)
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

-- The level badge as the theme makes your target frame's: its ring lifted onto
-- the theme's badge and shrunk by the same share, the level with it. Not done
-- to ours, the parts probe found (Neon, 2026-11-20): a big ring at the
-- portrait's other corner.
-- (Forever only: retail's target frame has no level ring, and ours hides it there.)
if stand and real and client ~= "retail" then
	local function Level(frame)
		local main = frame.TargetFrameContent and frame.TargetFrameContent.TargetFrameContentMain
		local ring, text = main and main.LevelBackgroundCircle, main and main.LevelText
		if not (ring and text) then return nil end
		local _, size = text:GetFont()
		return { w = ring:GetWidth(), lifted = ring:GetParent() ~= main and ring:GetParent() ~= frame.top,
			textLifted = text:GetParent() ~= main and text:GetParent() ~= frame.top, size = size }
	end
	local game, ours = Level(real), Level(stand)
	Check("both have a level ring", game and ours)
	if game and ours then
		local lifted = game.lifted == ours.lifted and game.textLifted == ours.textLifted
		Check("level ring and level lifted onto the theme's badge as your target frame's", lifted,
			("game %s/%s, ours %s/%s"):format(tostring(game.lifted), tostring(game.textLifted), tostring(ours.lifted),
				tostring(ours.textLifted)))
		-- (Shrunk by the same share: each against its own unthemed size.)
		local share = function(lvl, base) return math.floor(lvl.w / base * 100 + 0.5) end
		Check("level ring shrunk as your target frame's", share(game, 39) == share(ours, ours.base or 38),
			("game %.1f of 39, ours %.1f of 38"):format(game.w, ours.w))
		-- (On the same corner of the portrait, the level in its middle: ours went
		-- on the other corner, the level beside it, the 2026-11-21 run.)
		local function Corner(frame)
			local main = frame.TargetFrameContent.TargetFrameContentMain
			local ring, text = main.LevelBackgroundCircle, main.LevelText
			local rx, ry = ring:GetCenter()
			local px = frame.portrait:GetCenter()
			local tx, ty = text:GetCenter()
			local wide = text.GetStringWidth and text:GetStringWidth() or 0
			-- (The words' middle: a box wider than its words sits them by its justify.)
			local left = text:GetLeft()
			local justify = text:GetJustifyH()
			local words = justify == "RIGHT" and text:GetRight() - wide / 2 or justify == "LEFT" and left + wide / 2 or tx
			return rx > px and "right" or "left", math.abs(words - rx), math.abs(ty - ry)
		end
		local gameSide = Corner(real)
		local ourSide, dx, dy = Corner(stand)
		Check("level ring on the portrait's same corner as your target frame's", gameSide == ourSide,
			("game %s, ours %s"):format(gameSide, ourSide))
		-- (A slab theme puts the level on the bar with no ring: nothing to center in.)
		if ns.ThemeLayout and ns.ThemeLayout() == "slab" then
			Check("level on the bar, no ring (a slab theme)", true)
		else
			Check("level in the middle of its ring", dx <= 2 and dy <= 2, ("off by %.1f,%.1f"):format(dx, dy))
		end
	end
end

-- Up a second time, the theme's look kept: each time it came up its parts were
-- put back at the game's spots, the theme's name and level badge undone (Fel,
-- "check log. i had a diff theme", 2026-11-20).
if stand then
	local function Look()
		local parts = {}
		local function Spots(region)
			if not (region and region.GetNumPoints) then return "none" end
			local out = {}
			for i = 1, region:GetNumPoints() do
				local p, to, rp, x, y = region:GetPoint(i)
				out[#out + 1] = ("%s>%s %s %.1f,%.1f"):format(tostring(p), tostring(to and to.GetName and to:GetName() or to),
					tostring(rp), x or 0, y or 0)
			end
			return table.concat(out, "; ")
		end
		local main = stand.TargetFrameContent and stand.TargetFrameContent.TargetFrameContentMain
		local circle, level = main and main.LevelBackgroundCircle, main and main.LevelText
		parts[#parts + 1] = "name " .. tostring(stand.name:GetJustifyH()) .. " " .. Spots(stand.name)
		if circle then parts[#parts + 1] = ("circle %.1fx%.1f %s"):format(circle:GetWidth(), circle:GetHeight(), Spots(circle)) end
		if level then
			local _, size = level:GetFont()
			parts[#parts + 1] = ("level %s %s"):format(tostring(size), Spots(level))
		end
		return table.concat(parts, " | ")
	end
	-- (Its level parts found as the target frame's: none found, the theme
	-- took it for a frame without a level badge.)
	local found = ns.UnitPartRegions and #ns.UnitPartRegions(stand, "Level") or 0
	Check("the theme finds its level parts", found >= 2, found .. " found")
	local first = Look()
	target = true
	wow.Fire("PLAYER_TARGET_CHANGED")
	Check("down for a target", not stand:IsShown())
	target = false
	click(state.button, "LeftButton", true)
	wow.Fire("PLAYER_TARGET_CHANGED")
	Check("up again", stand:IsShown())
	local second = Look()
	Check("the theme's look kept the second time up", first == second, first .. "  VS  " .. second)
end

-- Its bars' numbers dressed as the game's: Style sizes them to their bar
-- (the power bar's smaller) and a slab theme moves the health one to its end
-- and hides the power one. Ours had a name of its own and got neither, the
-- side-by-side run, 2026-11-21.
if stand and real then
	local function Numbers(frame)
		local function One(bar)
			local text = bar and bar.TextString
			if not text then return "none" end
			local _, size = text:GetFont()
			local p, _, rp, x, y = text:GetPoint(1)
			return ("size %s %s>%s %.1f,%.1f alpha %.2f"):format(tostring(size), tostring(p), tostring(rp), x or 0, y or 0,
				text:GetAlpha())
		end
		return One(frame.healthbar) .. " | " .. One(frame.manabar)
	end
	for _, key in ipairs({ theme or "forge", "slate" }) do
		ns.ApplyStyleTheme(key, true)
		if ns.RefreshUnitStyle then ns.RefreshUnitStyle() end
		local game, ours = Numbers(real), Numbers(stand)
		Check(("bars' numbers dressed as your target frame's (%s)"):format(key), game == ours, "game " .. game .. "  VS  ours " .. ours)
	end
end

-- Its name strip over its frame art, as the game's (its content over its
-- container): under it, the art's dark band dulled ours, 2026-11-21.
if stand then
	local main = stand.TargetFrameContent and stand.TargetFrameContent.TargetFrameContentMain
	local strip, art = main and main.ReputationColor, stand.TargetFrameContainer and stand.TargetFrameContainer.FrameTexture
	local over = strip and art and strip:GetParent():GetFrameLevel() > art:GetParent():GetFrameLevel()
	-- (Its bars over the art too, and its level ring in the game's OVERLAY
	-- layer: the side-by-side probe, 2026-11-21.)
	local artLevel = art and art:GetParent():GetFrameLevel()
	Check("its bars drawn over its frame art", artLevel and stand.healthbar:GetFrameLevel() > artLevel
		and stand.manabar:GetFrameLevel() > artLevel, artLevel and ("bars %d/%d, art %d"):format(stand.healthbar:GetFrameLevel(),
		stand.manabar:GetFrameLevel(), artLevel))
	Check("its power bar over its health bar, as the game's", stand.manabar:GetFrameLevel() > stand.healthbar:GetFrameLevel(),
		("power %d, health %d"):format(stand.manabar:GetFrameLevel(), stand.healthbar:GetFrameLevel()))
	local ring = main and main.LevelBackgroundCircle
	Check("its level ring in the OVERLAY layer", ring and ring:GetDrawLayer() == "OVERLAY", ring and ring:GetDrawLayer())
	Check("its name strip drawn over its frame art", over,
		strip and art and ("strip's frame level %d, art's %d"):format(strip:GetParent():GetFrameLevel(), art:GetParent():GetFrameLevel()))
end

-- The theme off: the game's plain look back on it.
db.ufStyle = false
if ns.RefreshUnitStyle then ns.RefreshUnitStyle() end
Check("no errors with the theme off", #caught == 0, caught[1])

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
