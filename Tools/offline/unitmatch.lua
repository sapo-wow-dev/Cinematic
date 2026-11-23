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
-- (A buff on it, as the game shows one: its first buff measured off it.)
do
	local buff = CreateFrame("Frame", "TargetFrameBuff1", _G.TargetFrame)
	buff:SetSize(19, 19)
	buff:SetPoint("TOPLEFT", _G.TargetFrame, "BOTTOMLEFT", 8, 18)
	buff:Show()
	buff.Icon = buff:CreateTexture(nil, "ARTWORK")
	buff.Icon:SetAllPoints()
	buff.Icon:SetTexture("Interface\\Icons\\Spell_Holy_WordFortitude")
end
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
	ns.PreviewMatch("units nothemes")
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
	-- (Never seen, it's the copy of the built-in small frame, hung under yours as the game hangs it.)
	Check("pet never seen: the built-in small frame's copy, under yours", unit.copy and unit.copy.on
		and unit.hungOn == preview.units.PLAYER)
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
	-- (Together as the game has them (user 2026-11-20): your pet right under your
	-- frame, each target of target right under its frame, the party named.)
	local function Together(screen, look, width)
		for _, pair in ipairs({ { "PET", "PLAYER" }, { "TOT", "TARGET" }, { "FOCUSTOT", "FOCUS" } }) do
			local unit, over = screen.units[pair[1]], screen.units[pair[2]]
			-- (On the screen: each frame's own units times its scale; a measured target of
			-- target has a scale of its own.)
			local ku, ko = unit:GetEffectiveScale(), over:GetEffectiveScale()
			local gap = over:GetBottom() and unit:GetTop() and over:GetBottom() * ko - unit:GetTop() * ku
			local across = math.min(unit:GetRight() * ku, over:GetRight() * ko) - math.max(unit:GetLeft() * ku, over:GetLeft() * ko)
			-- (Its frame's buffs row between them: that much more room.)
			local row = over.auras and over.auras[1] and over.auras[1]:IsShown() and over.auras[1]:GetHeight() + 6 or 0
			Check(("%s at %d: %s right under %s"):format(look, width, pair[1], pair[2]),
				unit.hungOn == over and gap and gap > -30 and gap < 14 + row and across > 10,
				("hung %s, gap %s, side by side %s"):format(tostring(unit.hungOn == over), tostring(gap and math.floor(gap)),
				tostring(math.floor(across))))
		end
		local party = screen.units.PARTY
		Check(("%s at %d: the party named"):format(look, width), party.label and party.label:IsVisible()
			and party.label:GetText() == ns.L["Party"])
		-- (The game's look: the party a copy of the game's small frame, not the drawn slab of metal.)
		if look == "copied" then
			Check(("copied at %d: the party the small frame's copy"):format(width), party.copy and party.copy.on
				and party.copy.art:GetAtlas() == "UI-HUD-UnitFrame-TargetofTarget-PortraitOn" and not party.box:IsShown(),
				party.copyWhy)
		end
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
		Together(screen, "copied", width)
		-- (A target of target right where the focus's buffs run: they wrap before it, as the game's.)
		do
			local focus, tot = screen.units.FOCUS, screen.units.FOCUSTOT
			-- (Since 2026-11-23 the debuffs take a line of their own, as the game's:
			-- the target of target goes where a third icon on the first line would.)
			local second = focus.auras and focus.auras[2]
			local third = focus.auras and focus.auras[3]
			if second and second:IsShown() and third and third:IsShown() then
				-- (Fixed there: not hung on a buff, which moves when it wraps.)
				local step = second:GetLeft() - focus.auras[1]:GetLeft()
				local dx = second:GetLeft() + step - focus.health:GetLeft()
				local dy = second:GetTop() - focus.health:GetTop()
				tot:ClearAllPoints()
				tot:SetPoint("TOPLEFT", focus.health, "TOPLEFT", dx, dy)
				ns.WrapUnitAuras(focus, tot)
				local touching = 0
				local function Box(f)
					local k = f:GetEffectiveScale()
					return f:GetLeft() * k, f:GetRight() * k, f:GetTop() * k, f:GetBottom() * k
				end
				local tl, tr, tt, tb = Box(tot)
				for _, aura in ipairs(focus.auras) do
					local al, ar, at, ab = Box(aura)
					if ar > tl + 1 and al < tr - 1 and at > tb + 1 and ab < tt - 1 then touching = touching + 1 end
				end
				Check(("copied at %d: buffs wrap before a target of target on their row"):format(width), touching == 0, touching)
				screen:Refresh()
			end
		end
		db.ufShape = "circle"
		db.ufStyle = true
		screen:Refresh()
		problems = ns.UnitPreviewLayoutCheck(screen)
		Check(("layout at %dx%d, drawn (a theme's shape): clean"):format(width, ns.StylePreviewHeight()), #problems == 0,
			table.concat(problems, "; "))
		Together(screen, "drawn", width)
		-- (Measured frames drawn again and again: every part still has a place, no anchor loop.)
		for _ = 1, 3 do screen:Refresh() end
		local lost = {}
		for key, unit in pairs(screen.units) do
			for _, part in ipairs({ unit, unit.health, unit.power, unit.portrait, unit.name }) do
				if unit:IsShown() and part:IsShown() and not part:GetLeft() then lost[#lost + 1] = key end
			end
		end
		Check(("drawn at %d: drawn again three times, every part placed"):format(width), #lost == 0, table.concat(lost, ", "))
		-- (Its bars and portrait where the live frame has them, measured.)
		do
			local hangs = ns.UnitHangs("PLAYER", ns.UnitLookKey("PLAYER"))
			local player = screen.units.PLAYER
			local hw = player.health:GetWidth()
			local h = hangs and hangs.healthSize and hangs.healthSize.h
			Check(("drawn at %d: your health bar as thick as measured"):format(width), h and math.abs(player.health:GetHeight() / hw - h) < 0.01,
				("%.3f vs %s"):format(player.health:GetHeight() / hw, tostring(h)))
			local p = hangs and hangs.portrait
			local px = p and (player.portrait:GetLeft() - player.health:GetLeft()) / hw
			Check(("drawn at %d: your portrait where measured"):format(width), p and math.abs(px - p.x) < 0.02
				and math.abs(player.portrait:GetWidth() / hw - p.w) < 0.02, p and ("%.2f vs %.2f"):format(px, p.x))
		end
		-- (Measured, not guessed: the theme's target of target and first buff where the
		-- live frames put them, in widths of the target's health bar.)
		do
			local hangs = ns.UnitHangs("TARGET", ns.UnitLookKey("TARGET"))
			local target = screen.units.TARGET
			local function Spot(region)
				local k, kh = region:GetEffectiveScale(), target.health:GetEffectiveScale()
				local hw = target.health:GetWidth() * kh
				return (region:GetLeft() * k - target.health:GetLeft() * kh) / hw,
					(target.health:GetTop() * kh - region:GetTop() * k) / hw, region:GetWidth() * k / hw
			end
			for _, part in ipairs({ { "tot", screen.units.TOT.health }, { "aura", target.auras and target.auras[1] } }) do
				local want, region = hangs and hangs[part[1]], part[2]
				if want and region then
					local x, y, w = Spot(region)
					Check(("drawn at %d: %s where measured"):format(width, part[1]),
						math.abs(x - want.x) < 0.03 and math.abs(y - want.y) < 0.03 and math.abs(w - want.w) < 0.03,
						("%.2f,%.2f %.2f wide vs %.2f,%.2f %.2f"):format(x, y, w, want.x, want.y, want.w))
				else
					Check(("drawn at %d: %s measured off the live frame"):format(width, part[1]), want ~= nil)
				end
			end
		end
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
	ns.PreviewMatch("units nothemes")
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
	-- (Its side read; its place the built-in small frame's, not the bar edge.)
	Check("ToT name all secret: its side read, on the built-in place", recipe and recipe.name and recipe.name.justify == "LEFT"
		and not recipe.name.onBar and recipe.name.x == 44, recipe and recipe.name and tostring(recipe.name.justify))
	local unit = preview.units.TOT
	local point, relative = unit.name:GetPoint(1)
	Check("ToT name all secret: placed there, left", point == "TOPLEFT" and relative == unit
		and unit.name:GetJustifyH() == "LEFT", tostring(point))
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
	ns.PreviewMatch("units nothemes")
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

-- A buff button with no name (Forever's: neither "auraPools" nor "...Buff1"; the
-- test waited for a debuff that was there, 2026-11-20): found by what it is.
do
	focusFrame:Show()
	local holder = CreateFrame("Frame", nil, focusFrame)
	holder:SetAllPoints()
	local button = CreateFrame("Button", nil, holder)
	button:SetSize(17, 17)
	button:SetPoint("TOPLEFT", focusFrame, "BOTTOMLEFT", 6, 16)
	button.Icon = button:CreateTexture(nil, "ARTWORK")
	button.Icon:SetAllPoints()
	button.Icon:SetTexture("Interface\\Icons\\Spell_Shadow_AbominationExplosion")
	button:Show()
	Check("a buff button with no name found by what it is", ns.UnitFirstAura and ns.UnitFirstAura(focusFrame) == button)
	-- (In a fight on Forever its size and place are secret: still found, no error,
	-- as there but not measured. Comparing its size errored 19 times, 2026-11-21.)
	do
		local SECRET = setmetatable({}, { __lt = function() error("compared a secret") end,
			__le = function() error("compared a secret") end, __sub = function() error("did math on a secret") end })
		local realSecret = rawget(_G, "issecretvalue")
		rawset(_G, "issecretvalue", function(v) return v == SECRET end)
		local size, rect = button.GetSize, button.GetRect
		button.GetSize = function() return SECRET, SECRET end
		button.GetRect = function() return SECRET, SECRET, SECRET, SECRET end
		local ok, got = pcall(ns.UnitFirstAura, focusFrame)
		Check("in a fight (its size and place secret): found, no error", ok and got == button, not ok and got or nil)
		local okHangs, hangs = pcall(ns.ReadUnitHangs, "FOCUS")
		Check("in a fight: not measured, no error", okHangs and not (hangs and hangs.aura), not okHangs and hangs or nil)
		button.GetSize, button.GetRect = size, rect
		rawset(_G, "issecretvalue", realSecret)
	end
	-- (Not a bigger frame with an icon, a target of target's portrait, say.)
	button:SetSize(60, 60)
	Check("a 60 px frame with an icon isn't a buff", ns.UnitFirstAura(focusFrame) == nil)
	button:Hide()
	focusFrame:Hide()
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

-- Your run as you play it (Forever, 2026-11-21): your look on; out of a fight
-- a target with a buff; then the pull: a focus, your pet summoned in the
-- fight, both targeting someone, the buffs' places secret; the mob dies, its
-- frames gone. Nothing typed, no skip: every goal kept once met, your look
-- read in the fight, the game's after it, the run done.
local auraButton
do
	db.ufStyle, db.styleGeneral = true, true
	ns.db.unitFrameHangs = nil
	petOut, focusSet, totUp, target, targetIsYou, fighting = false, false, false, true, false, false
	pet:Hide()
	focusFrame:Hide()
	targetTot:Hide()
	focusTot:Hide()
	_G.TargetFrameBuff1:Hide() -- (no buff on your first target)
	-- (The game's say: a buff only while one is drawn.)
	local realAuras = rawget(_G, "C_UnitAuras")
	rawset(_G, "C_UnitAuras", { GetAuraDataByIndex = function(unit, i, filter)
		return (unit == "target" and i == 1 and filter == "HELPFUL" and auraButton and auraButton:IsShown()) and {} or nil end })
	local function Store() return CinematicDB.previewMatch[client .. "-units"] end
	local function Logged(text)
		for _, line in ipairs(Store() and Store().lines or {}) do if line:find(text, 1, true) then return line end end
		return nil
	end
	local function Pair(name)
		for _, pair in ipairs(Store() and Store().pairs or {}) do if pair.name == name then return pair end end
		return nil
	end
	ns.PreviewMatch("units nothemes")
	RunTimers()
	Check("your run: your look left on at the start", db.ufStyle == true)
	Check("your run: waits for the frames and the buffs, says both", Logged("FRAMES: a FOCUS") and Logged("BUFFS: out of a fight"))
	-- (Out of a fight: your target has a buff. Its button drawn after the event:
	-- found on the next once-a-second check.)
	local holder = CreateFrame("Frame", nil, _G.TargetFrame)
	holder:SetAllPoints()
	auraButton = CreateFrame("Button", nil, holder)
	auraButton:SetSize(17, 17)
	auraButton:SetPoint("TOPLEFT", _G.TargetFrame, "BOTTOMLEFT", 6, 16)
	auraButton.Icon = auraButton:CreateTexture(nil, "ARTWORK")
	auraButton.Icon:SetAllPoints()
	auraButton.Icon:SetTexture("Interface\\Icons\\Spell_Nature_Regeneration")
	auraButton:Show()
	RunTimers()
	Check("your run: the buff measured out of a fight, kept", Logged("BUFFS: the target's first buff measured"))
	local theme = ns.UnitLookKey("TARGET")
	local hangs = ns.db.unitFrameHangs and ns.db.unitFrameHangs[ns.isRetail and "retail" or "classic"]
	Check("your run: measured in your look, not the game's", theme ~= "game" and hangs and hangs[theme]
		and hangs[theme].TARGET and hangs[theme].TARGET.aura ~= nil, theme)
	Check("your run: still waits for the frames, not the buffs", Logged("waiting for: FRAMES:") and not Pair("Target frame (your style)"))
	-- (The pull: in a fight, the buffs' places secret, the rest comes up one by one.)
	fighting = true
	local SECRET = setmetatable({}, { __lt = function() error("compared a secret") end,
		__le = function() error("compared a secret") end, __sub = function() error("did math on a secret") end })
	local realSecret = rawget(_G, "issecretvalue")
	rawset(_G, "issecretvalue", function(v) return v == SECRET end)
	local size, rect = auraButton.GetSize, auraButton.GetRect
	auraButton.GetSize = function() return SECRET, SECRET end
	auraButton.GetRect = function() return SECRET, SECRET, SECRET, SECRET end
	focusSet = true
	focusFrame:Show()
	RunTimers()
	totUp = true
	targetTot:Show()
	focusTot:Show()
	RunTimers()
	Check("your run: no pet yet, waits for it", Logged("FRAMES: your PET") and not Pair("Target frame (your style)"))
	petOut = true
	pet:Show()
	RunTimers()
	Check("your run: in the fight, your look read with every frame up", Logged("yours:game:TARGET: read")
		and Logged("yours:game:TOT: read") and Logged("yours:game:FOCUSTOT: read") and Logged("yours:game:PET: read"))
	Check("your run: your target of target measured in the fight", hangs and hangs[theme] and hangs[theme].TARGET.tot ~= nil)
	Check("your run: the game's look not put on in the fight", db.ufStyle == true and not Logged("game:game:PLAYER"))
	Check("your run: no secret compared", not Logged("errored"), Logged("errored"))
	auraButton.GetSize, auraButton.GetRect = size, rect
	rawset(_G, "issecretvalue", realSecret)
	-- (The mob dies: target, focus and their targets gone; the fight ends.)
	target, focusSet, totUp = false, false, false
	auraButton:Hide()
	focusFrame:Hide()
	targetTot:Hide()
	focusTot:Hide()
	fighting = false
	wow.Fire("PLAYER_REGEN_ENABLED")
	RunTimers()
	Check("your run: done, your look's frames compared", Pair("Target frame (your style)") and Pair("Target's target of target (your style)")
		and Pair("Pet frame (your style)"))
	Check("your run: the game's look read after the fight", Logged("game:game:PLAYER: read"))
	Check("your run: your page put back", db.ufStyle == true and CinematicDB.previewMatchUnitsKept == nil)
	Check("your run: what's measured per look logged", Logged("HANGS " .. theme .. " look, TARGET:")
		and Logged("HANGS " .. theme .. " look, TARGET:"):find("aura", 1, true) and Logged("HANGS " .. theme .. " look, TARGET:"):find("tot", 1, true),
		Logged("HANGS " .. theme .. " look, TARGET:"))
	target, petOut = true, false
	pet:Hide()
	_G.TargetFrameBuff1:Show()
	rawset(_G, "C_UnitAuras", realAuras)
end

-- Forever's buffs (2026-11-21): the game says your target has one, but every
-- call on its button is secret, out of a fight too (its place, its size,
-- whether it shows). Probed and logged, not waited for: the run ends.
do
	db.ufStyle = true
	ns.db.unitFrameHangs = nil
	petOut, focusSet, totUp, target, fighting = true, true, true, true, false
	pet:Show()
	focusFrame:Show()
	targetTot:Show()
	focusTot:Show()
	_G.TargetFrameBuff1:Hide()
	local SECRET = setmetatable({}, { __lt = function() error("compared a secret") end,
		__le = function() error("compared a secret") end, __sub = function() error("did math on a secret") end,
		__eq = function() error("compared a secret") end })
	local realSecret, realAuras = rawget(_G, "issecretvalue"), rawget(_G, "C_UnitAuras")
	rawset(_G, "issecretvalue", function(v) return v == SECRET end)
	rawset(_G, "C_UnitAuras", { GetAuraDataByIndex = function(unit, i, filter)
		return (unit == "target" and i == 1 and filter == "HELPFUL") and {} or nil end })
	local secretButton = CreateFrame("Button", nil, _G.TargetFrame)
	secretButton.Icon = secretButton:CreateTexture()
	for _, method in ipairs({ "GetSize", "GetRect", "IsVisible", "IsShown", "GetLeft", "GetTop", "GetWidth", "GetHeight" }) do
		secretButton[method] = function() return SECRET, SECRET, SECRET, SECRET end
	end
	ns.PreviewMatch("units nothemes")
	RunTimers()
	local store = CinematicDB.previewMatch[client .. "-units"]
	local function Logged(text)
		for _, line in ipairs(store and store.lines or {}) do if line:find(text, 1, true) then return line end end
		return nil
	end
	Check("secret buffs: probed", Logged("AURAPROBE the game: target") and Logged("AURAPROBE frames found on screen under it"))
	Check("secret buffs: not waited for, the run done", Logged("BUFFS: your target has some, but this client doesn't say where")
		and store.pairs and #store.pairs >= 10 and db.ufStyle == true and CinematicDB.previewMatchUnitsKept == nil,
		store.pairs and #store.pairs)
	Check("secret buffs: no secret compared", not Logged("errored") and not Logged("compared a secret"), Logged("errored"))
	-- (On its own, /cine debug previewmatch units auras: the same probe, no error.)
	-- (No target yet: it waits for one with a buff, then probes. Run at once it
	-- probed no target, 2026-11-21.)
	target = false
	local ok, err = pcall(ns.PreviewMatchUnits, "auras")
	RunTimers()
	store = CinematicDB.previewMatch[client .. "-units"]
	Check("buffs probe on its own: no target, waits", ok and not Logged("AURAPROBE"), err)
	target = true
	RunTimers()
	Check("buffs probe on its own: probes once there's one with a buff", Logged("AURAPROBE the game: target")
		and Logged("AURAPROBE TargetFrame:"))
	Check("buffs probe on its own: anchors tried, shot taken with the frame's pixels",
		Logged("AURAPROBE TargetFrame points") and Logged("AURAPROBE shot: screen") and Logged("AURAPROBE SHOT "))
	secretButton:Hide()
	secretButton.IsVisible = function() return false end
	secretButton.IsShown = function() return false end
	rawset(_G, "issecretvalue", realSecret)
	rawset(_G, "C_UnitAuras", realAuras)
	_G.TargetFrameBuff1:Show()
	petOut, focusSet, totUp = false, false, false
	pet:Hide()
	focusFrame:Hide()
	targetTot:Hide()
	focusTot:Hide()
end

-- Forever's buff row worked out (its place secret, 2026-11-21): from the
-- frame's place, Buffs On Top and Cinematic's lift, as the game's layout was
-- measured off screenshots (first icon 24 in, 5 under the top on top, 75 under
-- it below (the game's code: 74 was a pixel short), 17 square). Retail reads its own buttons: never worked out.
do
	local frame = _G.TargetFrame
	_G.TargetFrameBuff1:Hide()
	local container = CreateFrame("Frame", nil, frame)
	frame.GetAuraContainer = function() return container end
	local realLift = ns.UnitAuraLiftNow
	local lift = 0
	ns.UnitAuraLiftNow = function() return lift end
	local scale = frame:GetEffectiveScale()
	local health = frame.healthbar
	local hl, ht, hw = health:GetLeft() * health:GetEffectiveScale(), health:GetTop() * health:GetEffectiveScale(),
		health:GetWidth() * health:GetEffectiveScale()
	local fl, ft = frame:GetLeft() * scale, frame:GetTop() * scale
	local function Want(top)
		return (fl + 24 * scale - hl) / hw, (ht - (ft - top * scale)) / hw, 17 * scale / hw
	end
	local function Near(a, b) return a and b and math.abs(a - b) < 0.006 end
	for _, case in ipairs({ { false, 0, 75 }, { true, 0, 5 }, { true, 6, -1 } }) do
		frame.buffsOnTop, lift = case[1], case[2]
		local hangs = ns.ReadUnitHangs("TARGET")
		local spot = hangs and hangs.aura
		local x, y, w = Want(case[3])
		local name = ("buff row worked out, %s%s"):format(case[1] and "Buffs On Top" or "below",
			case[2] > 0 and (", lifted " .. case[2]) or "")
		if ns.isRetail then
			Check(name .. ": not on retail (its buttons are read)", not (spot and spot.workedOut))
		else
			Check(name .. ": where the game puts it", spot and spot.workedOut and Near(spot.x, x) and Near(spot.y, y)
				and Near(spot.w, w) and (spot.up == true) == case[1],
				spot and ("%s,%s %s want %.3f,%.3f %.3f"):format(tostring(spot.x), tostring(spot.y), tostring(spot.w), x, y, w))
		end
	end
	-- (The preview: its row over the health bar with Buffs On Top, a second row above the first.)
	if not ns.isRetail then
		frame.buffsOnTop, lift = true, 0
		db.ufStyle, db.styleGeneral = false, true
		ns.db.unitFrameHangs = nil
		local preview = ns.MakeUnitStylePreview(UIParent, 480)
		preview:SetPoint("CENTER")
		preview:SetSize(480, 200)
		preview:Refresh()
		local unit = preview.units.TARGET
		local first = unit.auras and unit.auras[1]
		Check("preview, Buffs On Top: its row over the health bar", first and first:IsShown()
			and first:GetBottom() > unit.health:GetTop(), first and first:GetBottom())
		local row = unit.auraRow
		Check("preview, Buffs On Top: rows grow up", row and row[6] == true)
		local problems = ns.UnitPreviewLayoutCheck(preview)
		Check("preview, Buffs On Top: nothing cut or overlapping", #problems == 0, table.concat(problems, "; "))
		frame.buffsOnTop = false
		ns.db.unitFrameHangs = nil
		preview:Refresh()
		first = unit.auras and unit.auras[1]
		Check("preview, below: its row under the health bar", first and first:GetTop() < unit.health:GetBottom(),
			first and first:GetTop())
		preview:Hide()
	end
	frame.buffsOnTop = nil
	frame.GetAuraContainer = nil
	ns.UnitAuraLiftNow = realLift
	ns.db.unitFrameHangs = nil
	_G.TargetFrameBuff1:Show()
end

-- Looks switched back and forth with a portrait measured in each (a theme test
-- switched themes, then Style General's preview hung its health bar on a
-- portrait hung on it: "Cannot anchor to a region dependent on it", 2026-11-21).
do
	db.ufStyle, db.styleGeneral = true, true
	local client = ns.isRetail and "retail" or "classic"
	local spot = { x = -0.5, y = -0.2, w = 0.45, h = 0.45 }
	ns.db.unitFrameHangs = { [client] = {} }
	for _, shape in ipairs({ "game", "cut", "circle", "square" }) do
		db.ufShape = shape
		local look = ns.UnitLookKey("PLAYER")
		ns.db.unitFrameHangs[client][look] = { PLAYER = { portrait = spot, power = { x = 0, y = 0.15, w = 1, h = 0.08 },
			healthSize = { h = 0.16 } }, TARGET = { portrait = spot } }
	end
	local preview = ns.MakeUnitStylePreview(UIParent, 480)
	preview:SetPoint("CENTER")
	preview:SetSize(480, 200)
	ns.previewLoops = 0
	local errors = {}
	for _, shape in ipairs({ "cut", "cut", "game", "cut", "circle", "game", "square", "cut" }) do
		db.ufShape = shape
		local ok, err = pcall(preview.Refresh, preview)
		if not ok then errors[#errors + 1] = shape .. ": " .. tostring(err) end
	end
	Check("looks switched, portraits measured: no anchor loop", ns.previewLoops == 0 and #errors == 0,
		("%d loops; %s"):format(ns.previewLoops or -1, table.concat(errors, "; ")))
	db.ufShape = "game"
	ns.db.unitFrameHangs = nil
	preview:Hide()
end

-- The buffs measured before (a past run): not asked again. Your page off:
-- one read, the game's look, nothing changed.
do
	db.ufStyle = false
	petOut, focusSet, totUp = true, true, true
	pet:Show()
	focusFrame:Show()
	targetTot:Show()
	focusTot:Show()
	ns.PreviewMatch("units nothemes")
	RunTimers()
	local store = CinematicDB.previewMatch[client .. "-units"]
	local yours = false
	for _, pair in ipairs(store.pairs or {}) do if pair.name:find("your style", 1, true) then yours = true end end
	Check("page off: one read, done, no waiting", store.pairs and #store.pairs >= 5 and not yours and db.ufStyle == false,
		store.pairs and #store.pairs)
	db.ufStyle = true
	ns.PreviewMatch("units nothemes")
	RunTimers()
	store = CinematicDB.previewMatch[client .. "-units"]
	local asked = false
	for _, line in ipairs(store.lines or {}) do if line:find("BUFFS: out of a fight", 1, true) then asked = true end end
	Check("buffs measured before: not asked again, both looks read", not asked and store.pairs and #store.pairs >= 10,
		store.pairs and #store.pairs)
	-- (A fight begun right after your look's read: the game's waits for its end.)
	ns.PreviewMatch("units nothemes")
	fighting = true
	RunTimers()
	store = CinematicDB.previewMatch[client .. "-units"]
	local waited = false
	for _, line in ipairs(store.lines or {}) do if line:find("in a fight: the game's look goes on", 1, true) then waited = true end end
	Check("fight after your read: the game's look waits", waited and db.ufStyle == true and CinematicDB.previewMatchUnitsKept ~= nil)
	fighting = false
	wow.Fire("PLAYER_REGEN_ENABLED")
	RunTimers()
	Check("fight after your read: done once it ends, page back", db.ufStyle == true and CinematicDB.previewMatchUnitsKept == nil)
	petOut, focusSet, totUp = false, false, false
	pet:Hide()
	focusFrame:Hide()
	targetTot:Hide()
	focusTot:Hide()
end

-- A target but no focus or pet: waits for them, names them; skip goes without.
do
	ns.PreviewMatch("units nothemes")
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
ns.PreviewMatch("units nothemes")
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
ns.PreviewMatch("units nothemes")
RunTimers()
local store = CinematicDB.previewMatch[client .. "-units"]
Check("no target: waits", store and (store.pairs == nil or #store.pairs == 0))
target = true
ns.PreviewMatch("units nothemes") -- (already running: says so, starts nothing)
wow.Fire("PLAYER_TARGET_CHANGED")
RunTimers()
store = CinematicDB.previewMatch[client .. "-units"]
Check("no target: runs once there is one", store and store.pairs and #store.pairs >= 2, store and store.pairs and #store.pairs)

-- Step 3, the themes (2026-11-21): out of a fight, a player as target and
-- focus, your pet: every built-in theme put on the real frames, read and
-- compared, one shot each; your theme back after. A fight in the middle waits
-- and goes on with the same theme; no target waits; skip goes without the
-- rest; a reload in the middle puts your theme back at the next login.
do
	local themes = {}
	for _, theme in ipairs(ns.StyleThemeList()) do if theme.key ~= "game" then themes[#themes + 1] = theme.key end end
	Check("themes: the list there", #themes >= 10, #themes)
	db.ufStyle, db.styleGeneral = true, true
	ns.ApplyStyleTheme("fel", true)
	local mineTheme = db.styleTheme
	target, targetIsYou, petOut, focusSet, totUp, fighting = true, false, true, true, true, false
	pet:Show()
	focusFrame:Show()
	targetTot:Show()
	focusTot:Show()
	local function Store() return CinematicDB.previewMatch[client .. "-units"] end
	local function Logged(text)
		for _, line in ipairs(Store() and Store().lines or {}) do if line:find(text, 1, true) then return line end end
		return nil
	end
	local function Themed()
		local got = {}
		for _, pair in ipairs(Store() and Store().pairs or {}) do
			local name = pair.name:match("^Target frame %(theme (.+)%)$")
			if name then got[#got + 1] = name end
		end
		return got
	end
	shots = 0
	-- (A fight as the 3rd theme goes on: waited out, that theme again.)
	local realApply, applied = ns.ApplyStyleTheme, 0
	ns.ApplyStyleTheme = function(key, noUndo)
		local ok = realApply(key, noUndo)
		if key ~= mineTheme then
			applied = applied + 1
			if applied == 3 then fighting = true end
		end
		return ok
	end
	ns.PreviewMatch("units")
	RunTimers()
	Check("themes: a fight in the middle waits", fighting and Logged("in a fight: this theme goes on again") ~= nil,
		Logged("in a fight"))
	fighting = false
	wow.Fire("PLAYER_REGEN_ENABLED")
	RunTimers()
	RunTimers()
	ns.ApplyStyleTheme = realApply
	local got = Themed()
	Check("themes: every theme read and compared", #got == #themes, ("%d of %d"):format(#got, #themes))
	Check("themes: one shot each, and the two looks'", shots == #themes + 2, shots)
	Check("themes: your theme back, your page back", db.styleTheme == mineTheme and db.ufStyle == true
		and CinematicDB.previewMatchUnitsKept == nil, tostring(db.styleTheme))
	Check("themes: the log not cut short", Logged("BUFFS ") ~= nil and #Store().lines < 4000, #Store().lines)
	Check("themes: no error", not Logged("errored"), Logged("errored"))
	Check("themes: the hidden target of target probed", Logged("TOTPROBE") ~= nil or Logged("themes:") ~= nil)
	-- (What the first themed run found, 2026-11-21, each gone.)
	local found = { color = {}, circle = {}, level = {}, overlap = {}, pet = {} }
	for _, pair in ipairs(Store().pairs or {}) do
		local theme = pair.name:match("%(theme (.+)%)$")
		if theme then
			for _, line in ipairs(pair.findings or {}) do
				if line:find("^COLOR health") then found.color[#found.color + 1] = theme .. ": " .. pair.name:match("^(%S+)") end
				if line:find("^ART levelBack") then found.circle[#found.circle + 1] = theme end
				if line:find("^EXTRA level") then found.level[#found.level + 1] = theme .. ": " .. line end
				if pair.name:find("^Pet") and (line:find("^SIZE health") or line:find("^JUSTIFY name")) then
					found.pet[#found.pet + 1] = theme .. ": " .. line
				end
			end
		end
	end
	for phase, problems in pairs(Store().layout or {}) do
		if phase:find("^theme:") and #problems > 0 then found.overlap[#found.overlap + 1] = phase .. " " .. problems[1] end
	end
	Check("themes: health colored as the real frame", #found.color == 0, table.concat(found.color, "; "))
	Check("themes: the level circle read as drawn", #found.circle == 0, table.concat(found.circle, "; "))
	-- (The stand-in's frames have no level circle and keep their level under
	-- another key, so the slab themes' hidden level is checked on its own below.)
	Check("themes: no buffs over a target of target", #found.overlap == 0, table.concat(found.overlap, "; "))
	Check("themes: the pet's bars and name measured", #found.pet == 0, table.concat(found.pet, "; "))
	-- (No target once the fight's over: waits for one; then goes on.)
	target, totUp = false, false
	targetTot:Hide()
	focusTot:Hide()
	ns.PreviewMatch("units skip") -- (not running: nothing)
	ns.PreviewMatch("units")
	RunTimers()
	ns.PreviewMatch("units skip") -- (step 1: no target, no targets of target)
	RunTimers()
	Check("themes: no target, waits for one", Logged("themes: waiting for a TARGET") ~= nil and #Themed() == 0)
	target = true
	RunTimers()
	RunTimers()
	Check("themes: a target, goes on", #Themed() == #themes, #Themed())
	-- (Skip in the themes step: the rest gone without, your theme back.)
	target = false
	ns.PreviewMatch("units")
	RunTimers()
	ns.PreviewMatch("units skip")
	RunTimers()
	ns.PreviewMatch("units skip")
	RunTimers()
	Check("themes: skip goes without them, your theme back", Logged("themes: skipped") ~= nil
		and db.styleTheme == mineTheme and CinematicDB.previewMatchUnitsKept == nil, tostring(db.styleTheme))
	-- (A reload in the middle: your theme back at the next login.)
	CinematicDB.previewMatchUnitsKept = { ufStyle = true, theme = ns.StyleSnapshot() }
	realApply("neon", true)
	wow.Fire("PLAYER_LOGIN")
	RunTimers()
	Check("themes: cut short by a reload, your theme back at login", db.styleTheme == mineTheme
		and CinematicDB.previewMatchUnitsKept == nil, tostring(db.styleTheme))
	target, petOut, focusSet = true, false, false
	pet:Hide()
	focusFrame:Hide()
	realApply("game", true)
end

-- A look that hides the level and its circle on the live frame (the slab
-- themes, in game 2026-11-21: ours showed both): the preview hides them too;
-- the circle alone (the level a number): only the circle; the copy as well.
do
	db.styleGeneral, db.ufStyle = true, true
	ns.ApplyStyleTheme("slate", true)
	local client = ns.isRetail and "retail" or "classic"
	local look = ns.UnitLookKey("PLAYER")
	local level = { x = -0.5, y = 0.2, w = 0.1, h = 0.1, font = 0.1 }
	local function Hangs(hidden, backHidden)
		ns.db.unitFrameHangs = { [client] = { [look] = {
			PLAYER = { level = not hidden and level or nil, levelHidden = hidden, levelBackHidden = backHidden },
			TARGET = { level = level, levelHidden = false, levelBackHidden = backHidden } } } }
	end
	local realRead = ns.ReadUnitHangs
	ns.ReadUnitHangs = function() return nil end -- (the saved ones only: the stand-in's live frames aside)
	local preview = ns.MakeUnitStylePreview(UIParent, 480)
	preview:SetPoint("CENTER")
	preview:SetSize(480, 200)
	Hangs(true, true)
	preview:Refresh()
	local badge = preview.units.PLAYER.badge
	Check("a look hiding both: our level and circle hidden", not (badge:IsShown() and (badge.text:IsShown()
		or badge.ring:IsShown() or badge.back:IsShown())))
	badge = preview.units.TARGET.badge
	Check("a look hiding the circle only: the level shown, no circle", badge:IsShown() and badge.text:IsShown()
		and not badge.ring:IsShown() and not badge.back:IsShown())
	-- (The copy: the game's shape under a theme, Gilded Codex's kind.)
	ns.ApplyStyleTheme("codex", true)
	look = ns.UnitLookKey("PLAYER")
	ns.db.unitFrameHangs = { [client] = { [look] = { PLAYER = { levelBackHidden = true, levelHidden = false } } } }
	preview:Refresh()
	local unit = preview.units.PLAYER
	Check("the copy, a look hiding the circle: no circle", unit.copy and unit.copy.on and not unit.copy.circle:IsShown(),
		unit.copyWhy)
	ns.ReadUnitHangs = realRead
	ns.db.unitFrameHangs = nil
	preview:Hide()
	ns.ApplyStyleTheme("game", true)
end

-- Your pet's own power: a warlock's imp has mana, the sample wolf focus (in
-- game every theme's pet bar was yellow against the imp's blue, 2026-11-21).
do
	db.styleGeneral, db.ufStyle = true, false
	petOut = true
	local realType = rawget(_G, "UnitPowerType")
	rawset(_G, "UnitPowerType", function(unit) if unit == "pet" then return 0, "MANA" end return 0, "MANA" end)
	local preview = ns.MakeUnitStylePreview(UIParent, 480)
	preview:SetPoint("CENTER")
	preview:SetSize(480, 200)
	preview:Refresh()
	local r, g, b = preview.units.PET.power:GetStatusBarColor()
	Check("your pet out: its power bar its own (mana blue, not the wolf's yellow)", r and b and b > r and b > g,
		("%.2f,%.2f,%.2f"):format(r or -1, g or -1, b or -1))
	petOut = false
	preview:Refresh()
	r, g, b = preview.units.PET.power:GetStatusBarColor()
	Check("no pet: the sample's own (yellow)", r and g and r > 0.9 and g > 0.9 and b < 0.1,
		("%.2f,%.2f,%.2f"):format(r or -1, g or -1, b or -1))
	rawset(_G, "UnitPowerType", realType)
	preview:Hide()
end

-- A level faded out, still shown (a slab theme's, in game 2026-11-21): hidden
-- in this look, as the game shows it; faded back in, shown.
do
	db.styleGeneral, db.ufStyle = true, false
	ns.db.unitFrameHangs = nil
	local level = _G.PlayerFrame.levelText or _G.PlayerLevelText
	if level then
		level:SetAlpha(0)
		local hangs = ns.ReadUnitHangs("PLAYER")
		Check("a level faded to nothing: hidden in this look", hangs and hangs.levelHidden == true and hangs.level == nil,
			hangs and tostring(hangs.levelHidden))
		level:SetAlpha(1)
		hangs = ns.ReadUnitHangs("PLAYER")
		Check("faded back in: shown", hangs and hangs.levelHidden == false and hangs.level ~= nil)
	else
		Check("a level faded to nothing: the stand-in's level there", false)
	end
	ns.db.unitFrameHangs = nil
end

-- The page off under a slab theme (Slate): the preview is the game's frame,
-- as the real one is then; it drew Slate's slab, 2026-11-21.
do
	db.styleGeneral = true
	ns.ApplyStyleTheme("slate", true)
	db.ufStyle = false
	local preview = ns.MakeUnitStylePreview(UIParent, 480)
	preview:SetPoint("CENTER")
	preview:SetSize(480, 200)
	preview:Refresh()
	for _, id in ipairs({ "PLAYER", "TARGET" }) do
		local unit = preview.units[id]
		Check(("page off, Slate on: %s the game's frame"):format(id), unit.copy and unit.copy.on, unit.copyWhy)
	end
	preview:Hide()
	ns.ApplyStyleTheme("game", true)
end

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
