-- The Cast Bars pages' unit frames (offline, Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/castframe.lua <forever|retail> < /dev/null
-- Unit Frames > Cast Bars shows each sample cast bar under its unit frame as
-- the Unit Frames preview draws it (user 2026-11-20: the drawn green and blue
-- bars over it looked nothing like the target frame), on the style lab's
-- real-layout stand-in (Tools/style-lab/frames.lua):
--   each sample has its unit frame, the game's frame copied in the game's look;
--   the cast bar hung off it where the game's code hangs it (target with
--   no target of target: +18,-10 off its aura row); the target's alone
--   (2026-11-25: no boss for now), all inside the preview;
--   joined to the frame (a theme's look), the bar right under its bars;
--   Your Cast Bar's: yours alone, no frame, unless joined.
-- Says PASS or FAIL per check; exits 1 on any FAIL.
local F = dofile("Tools/style-lab/frames.lua")
local client = ... or "forever"

-- luacheck: push ignore 111 112 113 121 122 212
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function(w)
	F.Install(w)
	rawset(_G, "CreateFontFamily", false)
end)
-- luacheck: pop

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print(("%s %s: %s%s"):format(ok and "PASS" or "FAIL", client, name, detail and (" (" .. tostring(detail) .. ")") or ""))
end

-- (The game's player frame, as both clients have it: its frames are copyable.)
local player = CreateFrame("Frame", "PlayerFrame", UIParent)
player.PlayerFrameContainer = CreateFrame("Frame", nil, player)
if ns.MakeLazyPages then ns.MakeLazyPages("castframe test") end
local db = ns.GetDB()
local function Shown(preview)
	local up = preview
	while up and up ~= UIParent do
		up:Show()
		if up:GetNumPoints() == 0 and up:GetParent() then
			up:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
			if (up:GetWidth() or 0) <= 0 then up:SetSize(800, 2000) end
		end
		up = up:GetParent()
	end
end
-- (Edges on the screen: each frame's own units times its scale.)
local function Box(f)
	local k = f:GetEffectiveScale()
	return f:GetLeft() * k, f:GetRight() * k, f:GetTop() * k, f:GetBottom() * k
end
local function Inside(a, b, slack)
	slack = slack or 1
	local al, ar, at, ab = Box(a)
	local bl, br, bt, bb = Box(b)
	return al >= bl - slack and ar <= br + slack and at <= bt + slack and ab >= bb - slack
end
local function Apart(a, b)
	local al, ar, at, ab = Box(a)
	local bl, br, bt, bb = Box(b)
	return ar <= bl + 1 or br <= al + 1 or ab >= bt - 1 or bb >= at - 1
end

local preview = ns.castPreviews and ns.castPreviews["Unit Cast Style"]
Check("the Cast Bars page's preview is there", preview ~= nil)
if not preview then os.exit(1) end
Shown(preview)

-- (Everything a sample draws: its frame, auras, dragon, copy's art, target of
-- target and cast bar.)
local function Drawn(plate, bar)
	local unit, list = plate.unitFrame.unit, { bar, plate.unitFrame.tot }
	list[#list + 1] = unit
	for _, aura in ipairs(unit.auras or {}) do list[#list + 1] = aura end
	list[#list + 1] = unit.dragon
	if unit.copy and unit.copy.on then
		for _, texture in ipairs(unit.copy.textures) do list[#list + 1] = texture end
	end
	local shown = {}
	for _, part in pairs(list) do if part and part:IsShown() and part:GetLeft() then shown[#shown + 1] = part end end
	return shown
end
-- (At the page's own size too, user 2026-11-25: at 606x300 the target's frame
-- and dragon ran into the boss's, its target of target over the boss's auras.)
for _, size in ipairs({ { 480, 150 }, { 606, 300 }, { 760, 300 } }) do
	preview:SetSize(size[1], size[2])
	for _, look in ipairs({ "game", "theme" }) do
		db.styleGeneral = true
		db.ufStyle = look == "theme"
		db.ufShape = look == "theme" and "circle" or "game"
		preview:Refresh()
		local tag = ("%dx%d %s look"):format(size[1], size[2], look)
		local within = true
		for i, plate in ipairs(preview.plates) do
			for _, part in ipairs(Drawn(plate, preview.samples[i])) do
				if not Inside(part, plate, 2) then within = false end
				if not Inside(part, preview, 2) then within = false end
			end
		end
		Check(tag .. ": every drawn part inside its sample and the preview", within)
		-- (The target's alone for now, user 2026-11-25: no boss beside it.)
		Check(tag .. ": the target's sample alone", #preview.plates == 1, #preview.plates)
	end
end
preview:SetSize(480, 150)

for _, look in ipairs({ "game", "theme" }) do
	db.styleGeneral = true
	db.ufStyle = look == "theme"
	db.ufShape = look == "theme" and "circle" or "game"
	preview:Refresh()
	for i, plate in ipairs(preview.plates) do
		local frame, bar = plate.unitFrame, preview.samples[i]
		Check(("%s look, sample %d: its unit frame shown"):format(look, i), frame and frame:IsShown())
		if frame then
			if look == "game" then
				Check(("game look, sample %d: the game's frame copied"):format(i), frame.unit.copy and frame.unit.copy.on,
					frame.unit.copyWhy)
			end
			local _, joinedTo = bar:GetPoint(1)
			local unit = frame.unit
			if joinedTo ~= unit.power then
				-- (Hung where the game's code hangs it (rule all.castbar.target-boss-place):
				-- the target, no target of target, buffs under it: its TOPLEFT off the
				-- aura row's BOTTOMLEFT +18,-10; a boss's TOPRIGHT off its 232x100
				-- frame's BOTTOMRIGHT -100,+17, that frame round the art (the recipe's).)
				local point, relative, relativePoint, x, y = bar:GetPoint(1)
				local got = ("%s>%s %.1f,%.1f"):format(tostring(point), tostring(relativePoint), x or 0, y or 0)
				local box = unit.copy and unit.copy.on and unit.copyRecipe and unit.copyRecipe.frame
				local s = box and unit.copyScale or 1
				local want, onIt
				if i == 1 then
					want = ("TOPLEFT>BOTTOMLEFT %.1f,%.1f"):format(18 * s, -10 * s)
					for _, aura in ipairs(unit.auras or {}) do if aura == relative then onIt = true end end
				elseif box then
					want = ("TOPRIGHT>TOPLEFT %.1f,%.1f"):format((box.x + box.w - 100) * s, -(box.y + box.h - 17) * s)
					onIt = relative == unit
				else
					want = "TOPRIGHT>BOTTOMRIGHT -100.0,17.0"
					onIt = relative == unit
				end
				Check(("%s look, sample %d: the cast bar where the game hangs it"):format(look, i), onIt and got == want,
					got .. " want " .. want)
			end
			Check(("%s look, sample %d: all inside the preview"):format(look, i), Inside(plate, preview, 2))
			local shown = 0
			for _, aura in ipairs(unit.auras or {}) do if aura:IsShown() then shown = shown + 1 end end
			-- (The target's: a row of buffs and debuffs. The boss's none, as the
			-- game's boss frames (maxBuffs, maxDebuffs 0), user 2026-11-25: its
			-- cast bar sat on them.)
			Check(("%s look, sample %d: %s"):format(look, i, i == 1 and "a row of buffs and debuffs" or "no auras, as a boss frame"),
				shown == (i == 1 and 4 or 0), shown)
			Check(("%s look, sample %d: a boss's level a skull"):format(look, i), unit.skull and unit.skull:IsShown()
				and unit.badge.text:GetAlpha() == 0)
			if look == "game" and i == 1 then
				Check("game look, the target: the boss dragon round its portrait", unit.dragon and unit.dragon:IsShown())
			elseif look == "game" then
				-- (The game's boss frame (BossTargetFrameMixin:OnLoad): its small art,
				-- no portrait, no dragon (no showClassification).)
				Check("game look, the boss: the game's small boss frame art",
					unit.copy.art:GetAtlas() == "UI-HUD-UnitFrame-Target-Boss-Small-PortraitOff", unit.copy.art:GetAtlas())
				Check("game look, the boss: no portrait", not unit.face:IsShown() and not unit.portrait:IsShown())
				Check("game look, the boss: no dragon", not (unit.dragon and unit.dragon:IsShown()))
			end
			if i == 1 then
				-- (No target of target: the game's common case, user 2026-11-25.)
				Check(("%s look: the target with no target of target"):format(look), not (frame.tot and frame.tot:IsShown()))
				-- (The cast bar under the buffs, none on it.)
				local clear = true
				for _, aura in ipairs(unit.auras or {}) do
					if aura:IsShown() and not Apart(aura, bar) then clear = false end
				end
				Check(("%s look: the target's cast bar clear of its buffs"):format(look), clear)
			end
		end
	end
	if #preview.plates == 2 then
		Check(("%s look: the two samples apart"):format(look), Apart(preview.plates[1], preview.plates[2]))
	end
end

-- The health and power texts, as the game's Status Text setting shows them:
-- off, none; Both, percent left and value right; Numeric, value of most.
do
	local cvars = { statusText = "0", statusTextDisplay = "BOTH" }
	local realGet, realC = GetCVar, C_CVar
	rawset(_G, "GetCVar", function(name) return cvars[name] or realGet(name) end)
	rawset(_G, "C_CVar", setmetatable({ GetCVar = function(name) return cvars[name] or realGet(name) end }, { __index = realC }))
	db.ufStyle, db.ufShape = false, "game"
	local frame = preview.plates[1].unitFrame
	local function Texts()
		local list = {}
		for side, text in pairs(frame.unit.healthTexts or {}) do
			if text:IsShown() then list[#list + 1] = side .. "=" .. tostring(text:GetText()) end
		end
		table.sort(list)
		return table.concat(list, " ")
	end
	preview:Refresh()
	Check("Status Text off: no bar texts", Texts() == "", Texts())
	cvars.statusText = "1"
	preview:Refresh()
	Check("Status Text Both: percent left, value right", Texts() == "LEFT=62% RIGHT=343 K", Texts())
	cvars.statusTextDisplay = "NUMERIC"
	preview:Refresh()
	Check("Status Text Numeric: value of most", Texts() == "CENTER=343 K / 554 K", Texts())
	rawset(_G, "GetCVar", realGet)
	rawset(_G, "C_CVar", realC)
end

-- The frames' parts as the game's own code draws them (Forever's export,
-- 2026-11-23; rules forever.targetframe.*, all.statustext.format).
do
	db.ufStyle, db.ufShape = false, "game"
	preview:Refresh()
	local target = preview.plates[1].unitFrame.unit
	local recipe = ns.UNIT_FRAME_RECIPES.TARGET
	Check("target recipe: power bar 134 wide, masked", recipe.power.w == 134 and recipe.powerMask
		and recipe.powerMask.atlas == "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Mana-Mask", recipe.power.w)
	Check("pet recipe: mana bar 77 wide, the target of target's 78", ns.UNIT_FRAME_RECIPES.PET.power.w == 77
		and ns.UNIT_FRAME_RECIPES.TOT.power.w == 78)
	local auras = target.auras or {}
	local first, last = auras[1], auras[#auras]
	Check("hostile target: debuffs first", first and first.border:IsShown())
	Check("hostile target: buffs on a line of their own", last and not last.border:IsShown() and last.newLine ~= nil
		or (auras[3] and auras[3].newLine == true), tostring(auras[3] and auras[3].newLine))
	local cropped = false
	for _, aura in ipairs(auras) do
		local l, _, t = aura.icon:GetTexCoord()
		if l and l > 0 or t and t > 0 then cropped = true end
	end
	Check("aura icons whole, not cropped", not cropped)
	local counts = {}
	for _, aura in ipairs(auras) do counts[#counts + 1] = aura.count:GetText() or "" end
	Check("a stack count only over 1", table.concat(counts, ",") == ",,3," or table.concat(counts, ","):find("3") ~= nil,
		table.concat(counts, ","))
	local r, g, b
	if target.copy then r, g, b = target.copy.reaction:GetVertexColor() end
	Check("hostile target's name strip red (selection color)", r == 1 and g == 0 and b == 0,
		("%s,%s,%s"):format(tostring(r), tostring(g), tostring(b)))
	if not ns.isRetail then
		Check("Forever boss: the winged dragon", target.dragon and target.dragon:IsShown()
			and target.dragon:GetAtlas() == "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold-Winged",
			target.dragon and target.dragon:GetAtlas())
	end
	-- A friendly player's level in gold, not its difficulty color.
	local focus = ns.MakeUnitFrameSample(UIParent, "FOCUS", "FOCUS")
	focus:Show()
	focus:Refresh()
	local fr, fg, fb = focus.unit.badge.text:GetTextColor()
	Check("friendly focus's level gold", math.abs(fr - 1) < 0.01 and math.abs(fg - 0.82) < 0.01 and fb < 0.01,
		("%s,%s,%s"):format(tostring(fr), tostring(fg), tostring(fb)))
	-- Status text Both: the percent rounded up, and on mana and health only.
	local cvars = { statusText = "1", statusTextDisplay = "BOTH" }
	local realGet, realC = GetCVar, C_CVar
	rawset(_G, "GetCVar", function(name) return cvars[name] or realGet(name) end)
	rawset(_G, "C_CVar", setmetatable({ GetCVar = function(name) return cvars[name] or realGet(name) end }, { __index = realC }))
	local pet = ns.MakeUnitFrameSample(UIParent, "PET", "PET")
	pet:Show()
	pet:Refresh()
	local petTexts = pet.unit.powerTexts
	Check("pet's energy: no percent on the left", petTexts and not petTexts.LEFT:IsShown() and petTexts.RIGHT:IsShown())
	local petHealth = pet.unit.healthTexts
	Check("pet's health texts shown", petHealth and petHealth.LEFT:IsShown() and petHealth.LEFT:GetText() == "100%",
		petHealth and petHealth.LEFT:GetText())
	local you = ns.MakeUnitFrameSample(UIParent, "PLAYER", "PLAYER")
	you:Show()
	you:Refresh()
	-- (0.86 of its health: 86%; 0.4 of its mana: 40%.)
	Check("your health texts shown", you.unit.healthTexts and you.unit.healthTexts.LEFT:GetText() == "86%",
		you.unit.healthTexts and you.unit.healthTexts.LEFT:GetText())
	rawset(_G, "GetCVar", realGet)
	rawset(_G, "C_CVar", realC)
end

-- Your Cast Bar: yours alone, no frame over it.
local mine = ns.castPreviews["Player Cast Style"]
Check("Your Cast Bar's preview is there", mine ~= nil)
if mine then
	Shown(mine)
	db.ufStyle, db.ufShape = false, "game"
	mine:Refresh()
	local plate = mine.plates[1]
	Check("Your Cast Bar: alone, no frame over it", plate.unitFrame and not plate.unitFrame:IsShown())
	Check("Your Cast Bar: inside its preview", Inside(plate, mine, 2))
end

-- Yours locked to your player frame in Edit Mode: the game's unit frame look
-- (150x10), hung under your frame at -24,+12 off its right, and back when
-- unlocked (rule all.castbar.player-look-attached).
do
	local real = rawget(_G, "PlayerCastingBarFrame")
	rawset(_G, "PlayerCastingBarFrame", { attachedToPlayerFrame = true })
	local locked = mine
	if locked then
		locked:Refresh()
		local bar, plate = locked.samples[1], locked.plates[1]
		Check("locked to your frame: 150x10", bar.attached and math.abs(bar:GetWidth() - 150) < 0.01
			and math.abs(bar:GetHeight() - 10) < 0.01, bar:GetWidth() .. "x" .. bar:GetHeight())
		Check("locked to your frame: your frame shown over it", plate.unitFrame and plate.unitFrame:IsShown())
		local point, relative, relativePoint, x, y = bar:GetPoint(1)
		Check("locked to your frame: hung off its right, -24,+12", relative == plate.unitFrame.unit and point == "TOPRIGHT"
			and relativePoint == "BOTTOMRIGHT" and x == -24 and y == 12, ("%s %s %s,%s"):format(tostring(point),
			tostring(relativePoint), tostring(x), tostring(y)))
	end
	rawset(_G, "PlayerCastingBarFrame", real)
	if locked then
		locked:Refresh()
		local bar = locked.samples[1]
		Check("unlocked again: alone at 208x11", not bar.attached and math.abs(bar:GetWidth() - 208) < 0.01
			and not locked.plates[1].unitFrame:IsShown(), bar:GetWidth())
	end
end

if fails > 0 then
	print(("%d FAIL"):format(fails))
	os.exit(1)
end
print("all PASS")
