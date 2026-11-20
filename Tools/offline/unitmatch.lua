-- Preview Match, unit frames' run (dev tool, offline, Lua 5.1 via
-- Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/unitmatch.lua <forever|retail> < /dev/null
-- /cine debug previewmatch units (Dev/PreviewMatchUnits.lua) on the style
-- lab's real-layout stand-in (Tools/style-lab/frames.lua), with stand-in game
-- frames laid out as the game's (PlayerFrame, TargetFrame: their health and
-- power bars, name, level, portrait, frame art):
--   it reads both looks' frames and the preview's mock-ups, part by part;
--   it compares them and scores each pair, naming what differs;
--   the page's switch is put back after (on, and off);
--   with no target it waits for one, then runs.
-- Says PASS or FAIL per check; exits 1 on any FAIL.
local F = dofile("Tools/style-lab/frames.lua")
local client = ... or "forever"

-- luacheck: push ignore 111 112 113 121 122 212
local timers = {}
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function(w)
	F.Install(w)
	rawset(_G, "CreateFontFamily", false)
end)
-- (Timers run when the test says: in order, each one's own new ones after.)
C_Timer.After = function(_, fn) timers[#timers + 1] = fn end
local function RunTimers()
	for _ = 1, 50 do
		if #timers == 0 then return end
		local list = timers
		timers = {}
		for _, fn in ipairs(list) do fn() end
	end
end
local shots = 0
Screenshot = function() shots = shots + 1 end
local target = true
local petOut, focusSet, totUp = false, false, false
UnitExists = function(unit) return unit == "player" or (unit == "target" and target)
	or (unit == "pet" and petOut) or (unit == "focus" and focusSet)
	or ((unit == "targettarget" or unit == "focustarget") and totUp) end
local fighting = false
InCombatLockdown = function() return fighting end
local targetIsYou = false
UnitIsUnit = function(a, b) return a == "target" and b == "player" and targetIsYou end
-- luacheck: pop

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print(("%s %s: %s%s"):format(ok and "PASS" or "FAIL", client, name, detail and (" (" .. tostring(detail) .. ")") or ""))
end

-- Stand-in game frames, retail's layout (both clients have it): the frame
-- art over the whole frame, the portrait at its left, the bars right of it.
local function GameFrame(name, flip)
	local frame = CreateFrame("Button", name, UIParent)
	frame:SetSize(232, 100)
	frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", flip and 300 or 20, -20)
	frame:Show()
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
	frame.name:SetWidth(116) -- (the game's name box, a fixed width)
	frame.name:SetText("Sapo")
	local level = frame:CreateFontString(flip and nil or "PlayerLevelText", "OVERLAY", "GameFontNormalSmall")
	level:SetPoint("BOTTOMRIGHT", frame.healthbar, "TOPRIGHT", 0, 4)
	level:SetText("60")
	if flip then frame.levelText = level else rawset(_G, "PlayerLevelText", level) end
	return frame
end
GameFrame("PlayerFrame", false)
GameFrame("TargetFrame", true)
-- A target of target: a frame of its own on its frame's lower right, as the game's.
local function TotFrame(name, parent)
	local tot = CreateFrame("Button", name, parent)
	tot:SetSize(110, 45)
	tot:SetPoint("TOPRIGHT", parent, "BOTTOMRIGHT", -10, 20)
	tot.PlayerFrameContainer, tot.TargetFrameContainer, tot.TargetFrameContent, tot.PlayerFrameContent = false, false, false, false
	-- (Its parts in capitals, as the game's target of target has them: no healthbar, name...)
	tot.healthbar, tot.manabar, tot.name, tot.portrait, tot.totFrame = false, false, false, false, false
	tot.FrameTexture = tot:CreateTexture(nil, "BORDER")
	tot.FrameTexture:SetAllPoints()
	tot.FrameTexture:SetAtlas("UI-HUD-UnitFrame-TargetofTarget-PortraitOn")
	tot.Portrait = tot:CreateTexture(nil, "BACKGROUND")
	tot.Portrait:SetSize(34, 34)
	tot.Portrait:SetPoint("TOPLEFT", 5, -5)
	tot.HealthBar = CreateFrame("StatusBar", nil, tot)
	tot.HealthBar:SetSize(64, 9)
	tot.HealthBar:SetPoint("TOPLEFT", 42, -18)
	tot.HealthBar:SetStatusBarTexture("UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Health")
	tot.ManaBar = CreateFrame("StatusBar", nil, tot)
	tot.ManaBar:SetSize(64, 5)
	tot.ManaBar:SetPoint("TOP", tot.HealthBar, "BOTTOM", 0, -1)
	tot.ManaBar:SetStatusBarTexture("UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Mana")
	tot.Name = tot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	tot.Name:SetPoint("BOTTOMLEFT", tot.HealthBar, "TOPLEFT", 0, 2)
	tot.Name:SetWidth(50)
	tot.Name:SetText("Wolf")
	parent.totFrame = tot
	tot:Hide()
	return tot
end
local targetTot = TotFrame("TargetFrameToT", _G.TargetFrame)

-- The focus: the target's template, smaller (as a small focus frame is).
local focusFrame = GameFrame("FocusFrame", true)
focusFrame:SetScale(0.8)
focusFrame:Hide()
local focusTot = TotFrame("FocusFrameToT", focusFrame)
-- The pet: no container, its art a texture of its own (found as the biggest
-- unit frame art), and a piece of extra art.
-- (A child of the player frame, as the game's: its art must never be read as the player's.)
local pet = CreateFrame("Button", "PetFrame", _G.PlayerFrame)
pet:SetSize(120, 49)
pet:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 60, -130)
pet.PlayerFrameContainer, pet.TargetFrameContainer, pet.TargetFrameContent, pet.PlayerFrameContent = false, false, false, false
pet.FrameTexture, pet.HealthBar, pet.ManaBar, pet.Name, pet.Portrait = false, false, false, false, false
local petArt = pet:CreateTexture(nil, "BORDER")
petArt:SetAllPoints()
petArt:SetAtlas("UI-HUD-UnitFrame-Party-PortraitOn")
pet.extraArt = pet:CreateTexture(nil, "OVERLAY")
pet.extraArt:SetSize(16, 16)
pet.extraArt:SetPoint("TOPLEFT", 4, -4)
pet.extraArt:SetAtlas("UI-HUD-UnitFrame-Pet-Happiness")
pet.portrait = pet:CreateTexture(nil, "BACKGROUND")
pet.portrait:SetSize(37, 37)
pet.portrait:SetPoint("TOPLEFT", 6, -6)
pet.healthbar = CreateFrame("StatusBar", nil, pet)
pet.healthbar:SetSize(70, 8)
pet.healthbar:SetPoint("TOPLEFT", 46, -20)
pet.healthbar:SetStatusBarTexture("UI-HUD-UnitFrame-Party-PortraitOn-Bar-Health")
pet.manabar = CreateFrame("StatusBar", nil, pet)
pet.manabar:SetSize(70, 6)
pet.manabar:SetPoint("TOP", pet.healthbar, "BOTTOM", 0, -1)
pet.manabar:SetStatusBarTexture("UI-HUD-UnitFrame-Party-PortraitOn-Bar-Mana")
pet.name = pet:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
pet.name:SetPoint("BOTTOMLEFT", pet.healthbar, "TOPLEFT", 0, 2)
pet.name:SetWidth(68)
pet.name:SetText("Wolf")
-- (A state, not its look: never copied.)
pet.restArt = pet:CreateTexture(nil, "OVERLAY")
pet.restArt:SetSize(16, 16)
pet.restArt:SetPoint("TOPRIGHT", -4, -4)
pet.restArt:SetAtlas("UI-HUD-UnitFrame-Player-Rest-Flipbook")
pet:Hide()

local db = ns.GetDB()
Check("run there", ns.PreviewMatchUnits ~= nil and ns.PreviewMatchKit ~= nil)
if not ns.PreviewMatchUnits then os.exit(1) end

local function Run(styleOn)
	db.ufStyle = styleOn
	db.styleGeneral = true
	shots = 0
	ns.PreviewMatch("units")
	RunTimers()
	ns.PreviewMatch("units skip") -- (no focus, no pet here)
	RunTimers()
	local store = CinematicDB.previewMatch[client .. "-units"]
	local got = {}
	for _, pair in ipairs(store and store.pairs or {}) do got[pair.name] = pair end
	local which = styleOn and "page on" or "page off"
	for _, name in ipairs({ "Player frame", "Target frame" }) do
		local pair = got[name]
		Check(("%s: %s compared, scored"):format(which, name), pair and type(pair.score) == "number",
			pair and ("%s, %d differences"):format(tostring(pair.score), #pair.findings))
		local read = store and store.reads[pair and pair.real or ""]
		local ours = store and store.reads[pair and pair.ours or ""]
		Check(("%s: %s game parts read"):format(which, name), read and read.parts.health and read.parts.art
			and read.parts.portrait and read.parts.name and read.parts.level and (name ~= "Player frame" or read.parts.power) and true,
			read and read.unread)
		Check(("%s: %s preview parts read"):format(which, name), ours and ours.parts.health and ours.parts.name
			and ours.parts.portrait and true, ours and ours.unread)
		-- (The game's art is a frame of its own; the preview's is drawn metal: it says so.)
		local artLine = false
		for _, line in ipairs(pair and pair.findings or {}) do
			if line:find("^ART art") or line:find("^MISSING art") or line:find("^ART health") then artLine = true end
		end
		Check(("%s: %s difference in its art named"):format(which, name), artLine)
		-- (The game look is the copy: the game's frame art and fill atlases, Style/UnitFrameCopy.lua.
		-- The stand-in's game bar keeps an atlas as its file: names compared.)
		local gameArt = read and read.parts.art and read.parts.art.art
		Check(("%s: %s preview's frame art is the game's"):format(which, name),
			ours and ours.parts.art and ours.parts.art.art == gameArt, ours and ours.parts.art and ours.parts.art.art)
		Check(("%s: %s preview's health fill is the game's"):format(which, name),
			ours and ours.parts.health and read.parts.health
			and tostring(ours.parts.health.art):gsub("^atlas:", "") == tostring(read.parts.health.art):gsub("^atlas:", ""),
			ours and ours.parts.health and ours.parts.health.art)
	end
	Check(which .. ": yours read only with the page on", (got["Player frame (your style)"] ~= nil) == styleOn)
	Check(which .. ": screenshots", shots == (styleOn and 2 or 1), shots)
	Check(which .. ": the page's switch put back", db.ufStyle == styleOn and CinematicDB.previewMatchUnitsKept == nil,
		tostring(db.ufStyle))
	local trees = 0
	for _, line in ipairs(store and store.lines or {}) do if line:find(" TREE PLAYER ") then trees = trees + 1 end end
	Check(which .. ": the game frame's tree logged", trees >= 5, trees)
end
-- The target read with no power bar (a mob without mana) and another level's
-- color: the unit's, not the look's, so neither counts.
_G.TargetFrame.manabar:Hide()
_G.TargetFrame.levelText:SetTextColor(0.5, 0.5, 0.5)
Run(true)
Run(false)
do
	local store = CinematicDB.previewMatch[client .. "-units"]
	local target
	for _, pair in ipairs(store.pairs) do if pair.name == "Target frame" then target = pair end end
	local counted = {}
	for _, line in ipairs(target and target.findings or {}) do
		if line:find("power", 1, true) or line:find("COLOR level", 1, true) then counted[#counted + 1] = line end
	end
	Check("target: no power bar and its level's color not counted", target and #counted == 0, table.concat(counted, "; "))
end
_G.TargetFrame.manabar:Show()

-- The pet: drawn until its frame has been seen; then the copy, its extra art
-- too, kept after the pet's gone. The focus: its own frame read, not the target's.
do
	db.ufStyle, db.styleGeneral = false, true
	CinematicDB.unitFrameRecipes = nil
	local preview = ns.MakeUnitStylePreview(UIParent, 480)
	preview:Refresh()
	local unit = preview.units.PET
	Check("pet never seen: drawn, no copy", not (unit.copy and unit.copy.on) and ns.UnitFrameRecipe("PET") == nil)
	petOut = true
	pet:Show()
	preview:Refresh()
	local recipe = ns.UnitFrameRecipe("PET")
	Check("pet out: its recipe read", recipe and recipe.art and recipe.art.atlas == "UI-HUD-UnitFrame-Party-PortraitOn"
		and recipe.health and recipe.power and recipe.name, recipe and recipe.art and recipe.art.atlas)
	local extras = recipe and recipe.extras or {}
	Check("pet out: its extra art read", #extras == 1 and extras[1].atlas == "UI-HUD-UnitFrame-Pet-Happiness", #extras)
	Check("pet out: the preview's pet is the copy", unit.copy and unit.copy.on and unit.copy.art:IsShown()
		and unit.copy.art:GetAtlas() == "UI-HUD-UnitFrame-Party-PortraitOn")
	Check("pet out: its extra art drawn", unit.copy and unit.copy.extras[1] and unit.copy.extras[1]:IsShown()
		and unit.copy.extras[1]:GetAtlas() == "UI-HUD-UnitFrame-Pet-Happiness")
	petOut = false
	pet:Hide()
	preview:Refresh()
	Check("pet gone: the copy kept (saved)", unit.copy.on and unit.copy.art:IsShown())
	local player = ns.UnitFrameRecipe("PLAYER")
	local leaked = {}
	for _, extra in ipairs(player and player.extras or {}) do leaked[#leaked + 1] = tostring(extra.atlas) end
	Check("the pet frame's art not in your frame's (it's the player frame's child)", #leaked == 0, table.concat(leaked, ", "))
	focusSet = true
	focusFrame:Show()
	preview:Refresh()
	local saved = CinematicDB.unitFrameRecipes.classic or CinematicDB.unitFrameRecipes.retail
	Check("focus up: its own frame read", saved and saved.FOCUS and saved.FOCUS.art ~= nil)
	focusSet = false
	focusFrame:Hide()
	preview:Hide()
end

-- The targets of target: their own recipe (read off the target's), each
-- mock-up placed off its frame as the game hangs it, the target's art without it.
do
	db.ufStyle, db.styleGeneral = false, true
	CinematicDB.unitFrameRecipes = nil
	focusSet, totUp = true, true
	focusFrame:Show()
	targetTot:Show()
	focusTot:Show()
	local preview = ns.MakeUnitStylePreview(UIParent, 480)
	preview:Refresh()
	local recipe = ns.UnitFrameRecipe("TOT")
	Check("ToT: its own recipe read", recipe and recipe.art and recipe.art.atlas == "UI-HUD-UnitFrame-TargetofTarget-PortraitOn",
		recipe and recipe.art and recipe.art.atlas)
	local target = ns.UnitFrameRecipe("TARGET")
	Check("ToT: its place on the target's frame read", target and target.tot and target.tot.w and target.tot.w > 0)
	local leaked = false
	for _, extra in ipairs(target and target.extras or {}) do
		if tostring(extra.atlas):find("TargetofTarget", 1, true) then leaked = true end
	end
	Check("ToT: not in the target's own art", not leaked)
	for _, pair in ipairs({ { "TOT", "TARGET" }, { "FOCUSTOT", "FOCUS" } }) do
		local unit, over = preview.units[pair[1]], preview.units[pair[2]]
		local _, relative = unit:GetPoint(1)
		Check(("%s: the copy, hung off the %s copy"):format(pair[1], pair[2]:lower()), unit.copy and unit.copy.on
			and relative == over and unit.copy.art:GetAtlas() == "UI-HUD-UnitFrame-TargetofTarget-PortraitOn")
		-- (As big against its frame as the game's: its art's width over its frame's art's.)
		local want = target.tot.w / target.art.w
		local got = unit.copy.art:GetWidth() / over.copy.art:GetWidth()
		Check(("%s: sized against its frame as the game's"):format(pair[1]), math.abs(got - want) < 0.02,
			("%.3f vs %.3f"):format(got, want))
	end
	-- (Drawn before it's on the screen, as a page builds it: laid out once it's shown.)
	do
		local early = ns.MakeUnitStylePreview(UIParent, 480)
		early:SetHeight(ns.StylePreviewHeight())
		early:Refresh()
		early:SetPoint("CENTER")
		early:Hide()
		early:Show()
		local problems = ns.UnitPreviewLayoutCheck(early)
		Check("drawn before shown: laid out when shown, clean", #problems == 0 and not early.layoutPending,
			table.concat(problems, "; "))
		early:Hide()
	end
	-- (Quality control at the Style screens' size: every frame inside, none on another, no text cut.)
	for _, width in ipairs({ 480, 760 }) do
		local screen = ns.MakeUnitStylePreview(UIParent, width)
		screen:SetPoint("CENTER")
		screen:SetSize(width, ns.StylePreviewHeight())
		screen:Refresh()
		local problems = ns.UnitPreviewLayoutCheck(screen)
		Check(("layout at %dx%d, every frame copied: clean"):format(width, ns.StylePreviewHeight()), #problems == 0,
			table.concat(problems, "; "))
		db.ufShape = "circle"
		db.ufStyle = true
		screen:Refresh()
		problems = ns.UnitPreviewLayoutCheck(screen)
		Check(("layout at %dx%d, drawn (a theme's shape): clean"):format(width, ns.StylePreviewHeight()), #problems == 0,
			table.concat(problems, "; "))
		db.ufShape = "game"
		db.ufStyle = false
		screen:Refresh()
		-- (The checks catch what the user saw: a frame on another, one cut off at the edge.)
		local target, focus = screen.units.TARGET, screen.units.FOCUS
		focus:ClearAllPoints()
		focus:SetPoint("TOPLEFT", target, "TOPLEFT", 10, -5)
		local seen = table.concat(ns.UnitPreviewLayoutCheck(screen), "; ")
		Check(("layout check at %d: catches a frame on another"):format(width), seen:find("OVERLAP", 1, true) ~= nil, seen)
		screen:Refresh()
		screen.units.PARTY:ClearAllPoints()
		screen.units.PARTY:SetPoint("TOPLEFT", screen, "BOTTOMLEFT", 10, 20)
		seen = table.concat(ns.UnitPreviewLayoutCheck(screen), "; ")
		Check(("layout check at %d: catches a frame cut off"):format(width), seen:find("CUT PARTY", 1, true) ~= nil, seen)
		screen:Hide()
	end
	-- (The test compares both.)
	petOut = false
	ns.PreviewMatch("units")
	RunTimers()
	ns.PreviewMatch("units skip")
	RunTimers()
	local store = CinematicDB.previewMatch[client .. "-units"]
	local got = {}
	for _, p in ipairs(store.pairs or {}) do got[p.name] = p end
	for _, name in ipairs({ "Target's target of target", "Focus's target of target" }) do
		Check(("test: %s compared"):format(name), got[name] and type(got[name].score) == "number",
			got[name] and ("%s, %s"):format(tostring(got[name].score), table.concat(got[name].findings, "; ")))
	end
	focusSet, totUp = false, false
	focusFrame:Hide()
	targetTot:Hide()
	focusTot:Hide()
	preview:Hide()
end

-- In a fight: the target of target read then too (it's mostly up in one);
-- the power bar mana's art whatever power the frame showed when read.
do
	db.ufStyle, db.styleGeneral = false, true
	CinematicDB.unitFrameRecipes = nil
	totUp, fighting = true, true
	targetTot:Show()
	local preview = ns.MakeUnitStylePreview(UIParent, 480)
	preview:Refresh()
	Check("in a fight: the target of target read, copied", ns.UnitFrameRecipe("TOT") ~= nil
		and preview.units.TOT.copy and preview.units.TOT.copy.on, preview.units.TOT.copyWhy)
	fighting = false
	local saved = CinematicDB.unitFrameRecipes.classic or CinematicDB.unitFrameRecipes.retail
	target = false -- (the target's frame not read live now: the saved one stands)
	saved.PLAYER = saved.PLAYER or {}
	_G.PlayerFrame:Hide()
	saved.PLAYER.power = { x = 70, y = 46.7, w = 124, h = 10, atlas = "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Energy" }
	preview:Refresh()
	local fill = preview.units.PLAYER.power:GetStatusBarTexture()
	local atlas = fill:GetAtlas() or fill:GetTexture()
	Check("power read as energy: drawn as mana's art", tostring(atlas):find("Bar%-Mana") ~= nil, atlas)
	_G.PlayerFrame:Show()
	target = true
	totUp = false
	targetTot:Hide()
	preview:Hide()
end

-- Retail's cases (2026-11-20): your frame in its class resource art with a
-- third bar and no level (top level); a name whose place is secret (read off
-- its anchor); parts the game hides kept hidden, not filled in from Forever's.
do
	db.ufStyle, db.styleGeneral = false, true
	CinematicDB.unitFrameRecipes = nil
	local player = _G.PlayerFrame
	local holder = player.PlayerFrameContainer
	local plain = holder.FrameTexture
	plain:Hide()
	local tall = player:CreateTexture(nil, "BORDER")
	tall:SetPoint("TOPLEFT", plain, "TOPLEFT")
	tall:SetSize(232, 110)
	tall:SetAtlas("UI-HUD-UnitFrame-Player-PortraitOn-ClassResource")
	holder.AlternatePowerFrameTexture = tall
	local second = CreateFrame("StatusBar", nil, player)
	second:SetSize(124, 8)
	second:SetPoint("TOP", player.manabar, "BOTTOM", 0, -2)
	second:SetStatusBarTexture("UI-HUD-UnitFrame-Player-PortraitOn-Bar-Mana")
	rawset(_G, "AlternatePowerBar", second)
	_G.PlayerLevelText:Hide()
	-- (The target's name: its place secret, its anchor readable.)
	local name = _G.TargetFrame.name
	local realRect = name.GetRect
	name.GetRect = function() return nil end
	local preview = ns.MakeUnitStylePreview(UIParent, 480)
	preview:SetPoint("CENTER")
	preview:SetHeight(ns.StylePreviewHeight())
	preview:Refresh()
	local recipe = ns.UnitFrameRecipe("PLAYER")
	Check("retail: your frame's class resource art read", recipe.art and recipe.art.atlas == "UI-HUD-UnitFrame-Player-PortraitOn-ClassResource",
		recipe.art and recipe.art.atlas)
	Check("retail: its third bar read and drawn", recipe.power2 and not recipe.power2.hidden and preview.units.PLAYER.copy.power2
		and preview.units.PLAYER.copy.power2:IsShown())
	Check("retail: your level hidden there, hidden here (not Forever's)", recipe.level and recipe.level.hidden
		and not preview.units.PLAYER.badge.text:IsShown())
	local target = ns.UnitFrameRecipe("TARGET")
	Check("retail: a name with a secret place read off its anchor", target.name and target.name.anchor ~= nil,
		target.name and tostring(target.name.anchor))
	local point, relative = preview.units.TARGET.name:GetPoint(1)
	Check("retail: that name placed on its anchor point", point == target.name.anchor.point and relative == preview.units.TARGET)
	local problems = ns.UnitPreviewLayoutCheck(preview)
	Check("retail: layout clean", #problems == 0, table.concat(problems, "; "))
	-- (Back to Forever's stand-ins for the checks after.)
	name.GetRect = realRect
	tall:Hide()
	holder.AlternatePowerFrameTexture = false
	plain:Show()
	second:Hide()
	rawset(_G, "AlternatePowerBar", nil)
	_G.PlayerLevelText:Show()
	CinematicDB.unitFrameRecipes = nil
	preview:Hide()
end

-- Retail's target of target: its name's place and anchor both secret: its
-- side read, the copy sets it on the health bar's top edge on that side.
do
	db.ufStyle, db.styleGeneral = false, true
	CinematicDB.unitFrameRecipes = nil
	totUp = true
	targetTot:Show()
	local name = targetTot.Name
	name:SetJustifyH("LEFT")
	local realRect, realPoint = name.GetRect, name.GetPoint
	name.GetRect = function() return nil end
	name.GetPoint = function() return nil end
	local preview = ns.MakeUnitStylePreview(UIParent, 480)
	preview:SetPoint("CENTER")
	preview:SetHeight(ns.StylePreviewHeight())
	preview:Refresh()
	local recipe = ns.UnitFrameRecipe("TOT")
	Check("ToT name all secret: its side read", recipe and recipe.name and recipe.name.onBar and recipe.name.justify == "LEFT",
		recipe and recipe.name and tostring(recipe.name.justify))
	local unit = preview.units.TOT
	local point, relative, relativePoint = unit.name:GetPoint(1)
	Check("ToT name all secret: on the health bar's top edge, left", point == "BOTTOMLEFT" and relative == unit.health
		and relativePoint == "TOPLEFT" and unit.name:GetJustifyH() == "LEFT", tostring(point) .. " " .. tostring(relativePoint))
	name.GetRect, name.GetPoint = realRect, realPoint
	totUp = false
	targetTot:Hide()
	CinematicDB.unitFrameRecipes = nil
	preview:Hide()
end

-- A name measured out of a fight, then read in one with its place secret:
-- the measured place stays (it sat on the target's level when the weaker read
-- took over, retail 2026-11-20).
do
	db.ufStyle, db.styleGeneral = false, true
	CinematicDB.unitFrameRecipes = nil
	local first = ns.UnitFrameRecipe("TARGET")
	local placedX = first and first.name and first.name.x
	local name = _G.TargetFrame.name
	local realRect, realPoint = name.GetRect, name.GetPoint
	name.GetRect = function() return nil end
	name.GetPoint = function() return nil end
	name:SetJustifyH("LEFT")
	local after = ns.UnitFrameRecipe("TARGET")
	Check("measured name kept over a weaker read in a fight", placedX ~= nil and after.name.x == placedX
		and not after.name.onBar and after.name.justify == "LEFT", tostring(after.name.x) .. " " .. tostring(after.name.onBar))
	name.GetRect, name.GetPoint = realRect, realPoint
	name:SetJustifyH("CENTER")
	CinematicDB.unitFrameRecipes = nil
end

-- Retail: the target's name never measured (its place and anchor secret):
-- retail's built-in place (after the level on the strip), not the bar edge.
if client == "retail" then
	db.ufStyle, db.styleGeneral = false, true
	CinematicDB.unitFrameRecipes = nil
	local name = _G.TargetFrame.name
	local realRect, realPoint = name.GetRect, name.GetPoint
	name.GetRect = function() return nil end
	name.GetPoint = function() return nil end
	name:SetJustifyH("LEFT")
	local recipe = ns.UnitFrameRecipe("TARGET")
	Check("retail: unmeasured target name on retail's built-in place", recipe.name.x == 31 and not recipe.name.onBar
		and recipe.circle and recipe.circle.hidden, tostring(recipe.name.x))
	name.GetRect, name.GetPoint = realRect, realPoint
	name:SetJustifyH("CENTER")
	CinematicDB.unitFrameRecipes = nil
end

-- A power bar read in the game's plain tinted art ("-Bar-Mana-Status", a mob's
-- energy on retail): drawn as mana's colored art, not the plain one untinted (grey).
do
	db.ufStyle, db.styleGeneral = false, true
	CinematicDB.unitFrameRecipes = nil
	_G.TargetFrame.manabar:Show()
	_G.TargetFrame.manabar:SetStatusBarTexture("UI-HUD-UnitFrame-Target-PortraitOn-Bar-Mana-Status")
	local preview = ns.MakeUnitStylePreview(UIParent, 480)
	preview:SetPoint("CENTER")
	preview:Refresh()
	local fill = preview.units.TARGET.power:GetStatusBarTexture()
	local atlas = fill:GetAtlas() or fill:GetTexture()
	Check("a power bar read in its plain tinted art: drawn as mana's", atlas == "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Mana",
		tostring(atlas))
	_G.TargetFrame.manabar:SetStatusBarTexture("UI-HUD-UnitFrame-Target-PortraitOn-Bar-Mana")
	CinematicDB.unitFrameRecipes = nil
	preview:Hide()
end

-- A frame a HUD rule has faded out: said so, not compared. Another unit's
-- power bar art (a warrior's rage): the unit's, noted, not counted.
do
	db.ufStyle, db.styleGeneral = false, true
	_G.PlayerFrame:SetAlpha(0)
	_G.TargetFrame.manabar:Show()
	_G.TargetFrame.manabar:SetStatusBarTexture("UI-HUD-UnitFrame-Target-PortraitOn-Bar-Rage")
	ns.PreviewMatch("units")
	RunTimers()
	ns.PreviewMatch("units skip")
	RunTimers()
	local store = CinematicDB.previewMatch[client .. "-units"]
	local faded, player, rage = false, nil, nil
	for _, line in ipairs(store.lines or {}) do
		if line:find("PLAYER: shown but faded out", 1, true) then faded = true end
	end
	for _, pair in ipairs(store.pairs or {}) do
		if pair.name == "Player frame" then player = pair end
		if pair.name == "Target frame" then
			for _, line in ipairs(pair.findings) do if line:find("ART power", 1, true) then rage = line end end
		end
	end
	Check("a faded-out frame: said so, not compared", faded and player == nil)
	Check("another unit's rage bar art: not counted", rage == nil, rage)
	_G.PlayerFrame:SetAlpha(1)
	_G.TargetFrame.manabar:SetStatusBarTexture("UI-HUD-UnitFrame-Target-PortraitOn-Bar-Mana")
end

-- Another shape: the drawn mock-up back, nothing of the copy left on it.
do
	db.ufStyle, db.styleGeneral = true, true
	local preview = ns.MakeUnitStylePreview(UIParent, 480)
	preview:Refresh()
	local unit = preview.units.PLAYER
	local fill = unit.health:GetStatusBarTexture()
	Check("game shape: copy on, health masked", unit.copy and unit.copy.on and unit.copy.masked[fill] ~= nil)
	db.ufShape = "circle"
	preview:Refresh()
	Check("circle shape: copy off", unit.copy and not unit.copy.on and not unit.copy.art:IsShown())
	Check("circle shape: masks off, ring and portrait back", next(unit.copy.masked) == nil and unit.ring:IsShown()
		and unit.portrait:GetNumPoints() == 1)
	Check("circle shape: health fill not the game's atlas", unit.health:GetStatusBarTexture():GetAtlas() == nil,
		unit.health:GetStatusBarTexture():GetAtlas())
	db.ufShape = "game"
	preview:Refresh()
	Check("game shape again: copy on", unit.copy.on and unit.copy.art:IsShown())
	preview:Hide()
end

-- A fight: the game's look read in it (put on before); yours waits for its
-- end, then reads with what's up.
do
	db.ufStyle, db.styleGeneral = true, true
	ns.PreviewMatch("units")
	RunTimers()
	Check("start: the game's look on before any waiting", db.ufStyle == false)
	fighting = true
	ns.PreviewMatch("units skip")
	RunTimers()
	local store = CinematicDB.previewMatch[client .. "-units"]
	-- (Its reads are saved at the end: its log says what it read so far.)
	local function Logged(text)
		for _, line in ipairs(store and store.lines or {}) do if line:find(text, 1, true) then return true end end
		return false
	end
	Check("in a fight: the game's look read", Logged("game:game:PLAYER: read"))
	Check("in a fight: your look not put on, not read", db.ufStyle == false and not Logged("yours:game:PLAYER"))
	fighting = false
	wow.Fire("PLAYER_REGEN_ENABLED")
	RunTimers()
	store = CinematicDB.previewMatch[client .. "-units"]
	local yours = false
	for _, pair in ipairs(store.pairs or {}) do if pair.name == "Player frame (your style)" then yours = true end end
	Check("fight over: your look read, the run done, the page back", yours and db.ufStyle == true
		and CinematicDB.previewMatchUnitsKept == nil)
end

-- A target but no focus or pet: waits for them, names them; skip goes without.
do
	ns.PreviewMatch("units")
	RunTimers()
	local store = CinematicDB.previewMatch[client .. "-units"]
	Check("no focus or pet: waits", store and (store.pairs == nil or #store.pairs == 0))
	ns.PreviewMatch("units skip")
	RunTimers()
	store = CinematicDB.previewMatch[client .. "-units"]
	local named = false
	for _, line in ipairs(store.lines or {}) do if line:find("skipped waiting for: a FOCUS", 1, true) and line:find("PET", 1, true) then named = true end end
	Check("skip: runs, says what it went without", store.pairs and #store.pairs >= 2 and named)
end
petOut, focusSet, totUp = true, true, true -- (from here the waits are for the target only)
-- Yourself targeted: waits for someone else (Forever keeps your own target frame's places secret).
targetIsYou = true
ns.PreviewMatch("units")
RunTimers()
local mine = CinematicDB.previewMatch[client .. "-units"]
Check("yourself targeted: waits", mine and (mine.pairs == nil or #mine.pairs == 0))
targetIsYou = false
wow.Fire("PLAYER_TARGET_CHANGED")
RunTimers()
mine = CinematicDB.previewMatch[client .. "-units"]
Check("yourself targeted: runs once it's someone else", mine and mine.pairs and #mine.pairs >= 2)

-- No target: waits for one, then runs.
target = false
ns.PreviewMatch("units")
RunTimers()
local store = CinematicDB.previewMatch[client .. "-units"]
Check("no target: waits", store and (store.pairs == nil or #store.pairs == 0))
target = true
ns.PreviewMatch("units") -- (already running: says so, starts nothing)
wow.Fire("PLAYER_TARGET_CHANGED")
RunTimers()
store = CinematicDB.previewMatch[client .. "-units"]
Check("no target: runs once there is one", store and store.pairs and #store.pairs >= 2, store and store.pairs and #store.pairs)

-- The masks probe (/cine debug previewmatch units masks) runs through, shot taken.
do
	CinematicDB.previewMatchMaskShot = nil
	local ok, err = pcall(ns.PreviewMatchUnits, "masks")
	RunTimers()
	Check("masks probe runs, shot taken", ok and CinematicDB.previewMatchMaskShot ~= nil, err)
end

if fails > 0 then
	print(("%d FAIL"):format(fails))
	os.exit(1)
end
print("all PASS")
