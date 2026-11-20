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
UnitExists = function(unit) return unit == "player" or (unit == "target" and target) end
InCombatLockdown = function() return false end
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
	frame.name:SetText("Sapo")
	local level = frame:CreateFontString(flip and nil or "PlayerLevelText", "OVERLAY", "GameFontNormalSmall")
	level:SetPoint("BOTTOMRIGHT", frame.healthbar, "TOPRIGHT", 0, 4)
	level:SetText("60")
	if flip then frame.levelText = level else rawset(_G, "PlayerLevelText", level) end
	return frame
end
GameFrame("PlayerFrame", false)
GameFrame("TargetFrame", true)

local db = ns.GetDB()
Check("run there", ns.PreviewMatchUnits ~= nil and ns.PreviewMatchKit ~= nil)
if not ns.PreviewMatchUnits then os.exit(1) end

local function Run(styleOn)
	db.ufStyle = styleOn
	db.styleGeneral = true
	shots = 0
	ns.PreviewMatch("units")
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

if fails > 0 then
	print(("%d FAIL"):format(fails))
	os.exit(1)
end
print("all PASS")
