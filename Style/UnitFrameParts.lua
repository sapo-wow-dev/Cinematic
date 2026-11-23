-- The unit frames' other parts in the Unit Frames preview and the Cast Bars
-- pages' frames (UnitStyle.lua's mock-ups): a row of buffs and debuffs, the
-- health and power texts, the level as the game writes it, the boss dragon.
-- Its own file: UnitStyle.lua is at Lua's 200 locals.
local _, ns = ...
ns.Module("style", function() -- (the rest of this file: only with Style loaded, Modules.lua)

local function Readable(value)
	return value ~= nil and not (issecretvalue and issecretvalue(value))
end
-- The frames' other parts, as the game shows them (user 2026-11-20: "think of
-- all possible unit frame parts"): a row of buffs and debuffs under the
-- target's, focus's and a boss's, the health and power texts as the game's
-- Status Text setting shows them, the boss dragon round a boss's portrait, and
-- the level as the game writes it (a skull for a boss, or 10 levels over
-- yours). Sample values, the game's art.
local AURAS = {
	{ "Interface\\Icons\\Spell_Holy_WordFortitude", nil, 3 },
	{ "Interface\\Icons\\Spell_Nature_Regeneration" },
	{ "Interface\\Icons\\Spell_Shadow_ShadowWordPain", "Magic" },
	{ "Interface\\Icons\\Spell_Nature_CorrosiveBreath", "Poison" },
}
local AURA_SIZE, AURA_GAP = 17, 3 -- (the game's target frame's, in its own units)
local DEBUFF_BORDER = "Interface\\Buttons\\UI-Debuff-Overlays"
-- (The game's own border colors, AuraUtil.GetAuraBorderColor: Forever has no
-- DebuffTypeColor, so until 2026-11-23 these were always our own.)
local function DebuffColor(kind)
	local util = _G.AuraUtil
	local ok, color = pcall(function() return util and util.GetAuraBorderColor and util.GetAuraBorderColor(kind) end)
	if ok and type(color) == "table" and color.GetRGB then return color:GetRGB() end
	local colors = _G.DebuffTypeColor
	color = colors and colors[kind]
	if color then return color.r, color.g, color.b end
	if kind == "Poison" then return 0, 0.6, 0 end
	return 0.2, 0.6, 1
end
-- (The game's row: debuffs first on a hostile unit, buffs first on a friendly
-- one, the second kind on a line of its own (TargetFrameAuraContainer,
-- rule forever.targetframe.aura-anchor-flow).)
local function AuraOrder(sample)
	local hostile = sample.reaction and sample.reaction <= 4 and not sample.class
	local first, second = {}, {}
	for _, info in ipairs(AURAS) do
		local debuff = info[2] ~= nil
		if debuff == (hostile and true or false) then first[#first + 1] = info else second[#second + 1] = info end
	end
	local list = {}
	for _, info in ipairs(first) do list[#list + 1] = info end
	for i, info in ipairs(second) do list[#list + 1] = { info = info, newLine = i == 1 and #first > 0 } end
	return list
end
local function Auras(unit, on, scale, spot)
	unit.auras = unit.auras or {}
	if not on then
		for _, aura in ipairs(unit.auras) do aura:Hide() end
		return
	end
	local size = AURA_SIZE * scale
	-- (Measured off the live frame in this look: its first buff's place and size.)
	local hw = spot and unit.health:GetWidth()
	if hw and hw > 0 and spot.w and spot.w > 0 then size = spot.w * hw end
	local col, line = 0, 0
	for i, entry in ipairs(AuraOrder(unit.sample or {})) do
		local info = entry.info or entry
		local aura = unit.auras[i]
		if not aura then
			aura = CreateFrame("Frame", nil, unit)
			-- (The whole icon, its own edge too, as the game's aura buttons show it:
			-- cropped until 2026-11-23.)
			aura.icon = aura:CreateTexture(nil, "ARTWORK")
			aura.icon:SetAllPoints()
			aura.border = aura:CreateTexture(nil, "OVERLAY")
			aura.border:SetPoint("TOPLEFT", -1, 1)
			aura.border:SetPoint("BOTTOMRIGHT", 1, -1)
			aura.count = aura:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
			aura.count:SetPoint("BOTTOMRIGHT", 1, 0)
			unit.auras[i] = aura
		end
		aura.newLine = entry.newLine or nil
		if aura.newLine then col, line = 0, line + 1 end
		aura:SetSize(size, size)
		aura:ClearAllPoints()
		local step = size * (1 + AURA_GAP / AURA_SIZE)
		if hw and hw > 0 and spot.w and spot.w > 0 then
			-- (Its 6th: rows grow up, over the frame, with Buffs On Top.)
			unit.auraRow = { unit.health, "TOPLEFT", spot.x * hw, -spot.y * hw, step, spot.up }
		else
			unit.auraRow = { unit, "BOTTOMLEFT", 5 * scale, -2 * scale, step }
		end
		local row = unit.auraRow
		aura:SetPoint("TOPLEFT", row[1], row[2], row[3] + col * step, row[4] + (row[6] and line or -line) * step)
		col = col + 1
		aura.icon:SetTexture(info[1])
		aura.border:SetShown(info[2] ~= nil)
		if info[2] then
			aura.border:SetTexture(DEBUFF_BORDER)
			aura.border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
			aura.border:SetVertexColor(DebuffColor(info[2]))
		end
		-- (A count only over 1, as the game's.)
		aura.count:SetText(info[3] and info[3] > 1 and tostring(info[3]) or "")
		aura:Show()
	end
end

-- Your pet's power's color, while it's out (nil: none, or not readable).
function ns.LivePetPower()
	if not (UnitExists and UnitExists("pet") and UnitPowerType) then return nil end
	local ok, kind, token = pcall(UnitPowerType, "pet")
	if not ok or (issecretvalue and (issecretvalue(kind) or issecretvalue(token))) then return nil end
	if token == "MANA" or kind == 0 then return { 0, 0, 1 } end
	local colors = _G.PowerBarColor
	local color = colors and (colors[token] or colors[kind])
	if type(color) == "table" and type(color.r) == "number" then return { color.r, color.g, color.b } end
	return nil
end

-- The game's Status Text setting: on, and how (BOTH: percent left, value right;
-- NUMERIC: value of most; PERCENT: percent). Off: none (they show on hover only).
local function StatusTextHow()
	local get = C_CVar and C_CVar.GetCVar or GetCVar
	local okOn, on = pcall(get, "statusText")
	local okHow, how = pcall(get, "statusTextDisplay")
	if not (okOn and on == "1") then return nil end
	how = okHow and type(how) == "string" and how or "NUMERIC"
	if how == "NONE" then return nil end
	return how
end
-- (The client's own way of shortening, as the game's bar texts use it.)
local function Short(value)
	value = math.floor(value + 0.5)
	local abbreviate = _G.AbbreviateLargeNumbers
	if type(abbreviate) == "function" then
		local ok, text = pcall(abbreviate, value)
		if ok and type(text) == "string" then return text end
	end
	if value >= 1e6 then return ("%.1f M"):format(value / 1e6) end
	if value >= 1e4 then return ("%d K"):format(math.floor(value / 1e3 + 0.5)) end
	return tostring(value)
end
-- (Rounded up, as the game's: TextStatusBar's math.ceil.)
local function Percent(share) return ("%d%%"):format(math.ceil(share * 100 - 1e-9)) end
-- (Where each frame's game code puts its texts, in its own units: Forever's
-- Camelot TargetFrame.lua and PetFrame.xml; the rest the template's 2.)
local TEXT_PLACES = {
	TARGET = { healthTexts = { LEFT = 2, RIGHT = -3, CENTER = 0 }, powerTexts = { LEFT = 6, RIGHT = -7, CENTER = 0 } },
	PET = { healthTexts = { LEFT = 0, RIGHT = 0, CENTER = 0 }, powerTexts = { LEFT = 4, RIGHT = 0, CENTER = 2 } },
}
TEXT_PLACES.FOCUS = TEXT_PLACES.TARGET
local TEXT_PLACE = { LEFT = 2, RIGHT = -2, CENTER = 0 }
local function BarTexts(unit, bar, key, share, most, how, scale, noPercent)
	local texts = unit[key]
	if not texts then
		texts = {}
		for _, side in ipairs({ "LEFT", "RIGHT", "CENTER" }) do
			texts[side] = unit.nameTop:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
			texts[side].searchSkip = true
		end
		unit[key] = texts
	end
	local places = TEXT_PLACES[unit.id] and TEXT_PLACES[unit.id][key] or TEXT_PLACE
	for side, text in pairs(texts) do
		text:Hide()
		text:ClearAllPoints()
		text:SetPoint(side, bar, side, places[side] * scale, 0)
		-- (Its font object's three values: "a and b:GetFont()" would keep the first only.)
		local object, file, size, flags = _G.TextStatusBarText, nil, nil, nil
		if object and object.GetFont then file, size, flags = object:GetFont() end
		if file and size then text:SetFont(file, math.max(6, size * scale), flags or "") end
	end
	if not (how and bar:IsShown() and most) then return end
	local value = most * share
	if how == "BOTH" then
		-- (The percent on the left only on health and mana bars, as the game's.)
		texts.LEFT:SetText(Percent(share))
		texts.RIGHT:SetText(Short(value))
		texts.LEFT:SetShown(not noPercent)
		texts.RIGHT:Show()
	elseif how == "PERCENT" then
		texts.CENTER:SetText(Percent(share))
		texts.CENTER:Show()
	else
		texts.CENTER:SetText(Short(value) .. " / " .. Short(most))
		texts.CENTER:Show()
	end
end

-- The level as the game writes it: a skull for a boss, or a unit 10 levels or
-- more over yours; else its number in how hard it is for you.
local SKULL_ATLAS = "UI-HUD-UnitFrame-Target-HighLevelTarget_Icon"
local SKULL_FILE = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"
local function Skull(unit, sample)
	if unit.id == "PLAYER" or not sample.level then return false end
	if sample.boss then return true end
	local ok, mine = pcall(UnitLevel, "player")
	return ok and Readable(mine) and type(mine) == "number" and mine > 0 and sample.level >= mine + 10
end
local function DressLevel(unit, sample, scale)
	local badge = unit.badge
	if not badge then return end
	local skull = Skull(unit, sample)
	if not unit.skull then
		unit.skull = badge:CreateTexture(nil, "OVERLAY", nil, 2)
		local ok, done = pcall(unit.skull.SetAtlas, unit.skull, SKULL_ATLAS)
		if not (ok and done ~= false) then unit.skull:SetTexture(SKULL_FILE) end
	end
	unit.skull:SetShown(skull and badge.text:IsShown())
	if skull and badge.text:IsShown() then
		-- (The copy: at the atlas's own size, centered on the level circle, as the
		-- game's (rule forever.targetframe.level-skull-boss). Drawn: by the text.)
		local circle = unit.copy and unit.copy.on and unit.copy.circle
		local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(SKULL_ATLAS)
		unit.skull:ClearAllPoints()
		if circle and circle:IsShown() and type(info) == "table" and type(info.width) == "number" then
			unit.skull:SetPoint("CENTER", circle, "CENTER", 0, 0)
			unit.skull:SetSize(info.width * scale, info.height * scale)
		else
			local h = math.max(badge.text:GetHeight() or 0, 8)
			unit.skull:SetPoint("CENTER", badge.text, "CENTER", 0, 0)
			unit.skull:SetSize(h * 1.25, h * 1.25)
		end
		badge.text:SetAlpha(0)
	else
		badge.text:SetAlpha(1)
	end
end

-- The boss dragon round a boss's portrait (the copy: the game's art where it
-- reads it, retail 2026-11-20; a theme's drawn frame has its own).
local BOSS_ATLAS = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold"
local FOREVER_BOSS_ATLAS = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold-Winged"
local function Classification(unit, sample, recipe, scale)
	local on = sample.boss and unit.copy and unit.copy.on and recipe and recipe.classification
		and not recipe.classification.hidden and recipe.classification.w
	if not unit.dragon then unit.dragon = unit:CreateTexture(nil, "ARTWORK", nil, 2) end
	local shown = false
	-- (Forever's own boss art and place, from its Camelot GetBossPortraitFrameData:
	-- the winged gold dragon, its top right +11,-4 off the 232x100 frame's,
	-- whose art sits 19,16 in; at the atlas's size. Until 2026-11-23 the plain
	-- elite dragon at retail's spot.)
	local forever = on and not ns.isRetail
	if on then
		local atlas = forever and FOREVER_BOSS_ATLAS or BOSS_ATLAS
		local ok, done = pcall(unit.dragon.SetAtlas, unit.dragon, atlas)
		if not (ok and done ~= false) and forever then
			forever = false
			ok, done = pcall(unit.dragon.SetAtlas, unit.dragon, BOSS_ATLAS)
		end
		if ok and done ~= false then
			local e = recipe.classification
			local info = forever and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
			unit.dragon:ClearAllPoints()
			if forever then
				unit.dragon:SetPoint("TOPRIGHT", unit, "TOPLEFT", (213 + 11) * scale, (16 - 4) * scale)
			else
				unit.dragon:SetPoint("TOPLEFT", unit, "TOPLEFT", e.x * scale, -e.y * scale)
			end
			if type(info) == "table" and type(info.width) == "number" and info.width > 0 then
				unit.dragon:SetSize(info.width * scale, info.height * scale)
			else
				unit.dragon:SetSize(e.w * scale, e.h * scale)
			end
			shown = true
		end
	end
	unit.dragon:SetShown(shown)
end

-- (A theme's drawn frame: its bars, portrait and name as the live frame has them in
-- this look, measured (user 2026-11-20: the real themed frames kept the game's bar
-- thickness, name size and side; the drawn ones had their own).)
local function MeasuredBody(unit, hangs)
	-- (Its portrait back on its own spot first: the drawn frame has just hung its
	-- health bar off it again, and a portrait still hung off that bar is a loop.)
	if unit.portraitMeasured then
		local side = unit.sample.flip and "RIGHT" or "LEFT"
		unit.portrait:ClearAllPoints()
		unit.portrait:SetPoint(side, unit, side, 0, 0)
		unit.portraitMeasured = nil
	end
	if not hangs or (unit.copy and unit.copy.on) then return end
	local hw = unit.health:GetWidth()
	if not (hw and hw > 0) then return end
	local function At(region, spot)
		region:ClearAllPoints()
		region:SetPoint("TOPLEFT", unit.health, "TOPLEFT", spot.x * hw, -spot.y * hw)
		region:SetSize(spot.w * hw, spot.h * hw)
	end
	if hangs.healthSize and hangs.healthSize.h then unit.health:SetHeight(hangs.healthSize.h * hw) end
	if hangs.power and hangs.power.w then At(unit.power, hangs.power) end
	-- (The drawn frame hangs its health bar off the portrait: pinned to the frame
	-- where it is first, or the portrait hung off it would make a loop.)
	if hangs.portrait and hangs.portrait.w then
		local hx = unit.health:GetLeft() and unit:GetLeft() and unit.health:GetLeft() - unit:GetLeft()
		local hy = unit.health:GetTop() and unit:GetTop() and unit:GetTop() - unit.health:GetTop()
		if hx and hy then
			unit.health:ClearAllPoints()
			unit.health:SetPoint("TOPLEFT", unit, "TOPLEFT", hx, -hy)
			unit.health:SetWidth(hw)
			At(unit.portrait, hangs.portrait)
			unit.portraitMeasured = true
		end
	end
	local name = hangs.name
	if name and name.w then
		local justify = name.justify or "CENTER"
		local x = justify == "LEFT" and name.x or justify == "RIGHT" and name.x + name.w or name.x + name.w / 2
		unit.name:ClearAllPoints()
		unit.name:SetSize(0, 0)
		unit.name:SetPoint(justify == "LEFT" and "LEFT" or justify == "RIGHT" and "RIGHT" or "CENTER", unit.health, "TOPLEFT",
			x * hw, -(name.y + name.h / 2) * hw)
		unit.name:SetJustifyH(justify)
		local file, _, flags = unit.name:GetFont()
		if file and name.font then unit.name:SetFont(file, math.max(6, name.font * hw), flags or "") end
	end
end

-- (A theme's drawn frame: its level badge where the live frame shows it in this look.)
local function MeasuredLevel(unit, hangs)
	local badge = unit.badge
	local level, back = hangs and hangs.level, hangs and hangs.levelBack
	-- (Its own drawn ring back when no measurement says the game's circle.)
	if badge and badge.ring.gameCircle then
		badge.ring:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
		badge.ring:SetDesaturated(false)
		badge.ring:ClearAllPoints()
		badge.ring:SetAllPoints(badge)
		badge.ring.gameCircle = nil
	end
	-- (This look hides them on the live frame (a slab theme): ours too.)
	if badge and hangs and not (unit.copy and unit.copy.on) and (hangs.levelHidden or hangs.levelBackHidden) then
		badge.ring:SetShown(not hangs.levelBackHidden)
		badge.back:SetShown(not hangs.levelBackHidden and not badge.ring.gameCircle)
		badge.text:SetShown(not hangs.levelHidden)
		if hangs.levelHidden and hangs.levelBackHidden then badge:Hide() end
		unit.levelHiddenByLook = hangs.levelHidden and hangs.levelBackHidden or nil
		if hangs.levelHidden or not level then return end
	else
		unit.levelHiddenByLook = nil
	end
	if not (badge and level) or (unit.copy and unit.copy.on) then return end
	local hw = unit.health:GetWidth()
	if not (hw and hw > 0) then return end
	badge:Show()
	badge:ClearAllPoints()
	local spot = back or level
	badge:SetSize(spot.w * hw, spot.h * hw)
	badge:SetPoint("CENTER", unit.health, "TOPLEFT", (spot.x + spot.w / 2) * hw, -(spot.y + spot.h / 2) * hw)
	-- (Its circle the game's art, as the themed frame keeps it, in the theme's ring color.)
	if back then
		local ok, done = pcall(badge.ring.SetAtlas, badge.ring, "UI-HUD-UnitFrame-SmallCircle")
		if ok and done ~= false then
			badge.ring:ClearAllPoints()
			badge.ring:SetAllPoints(badge)
			local ring = ns.StyleOn and ns.StyleOn("ufStyle") and ns.ThemeRing and ns.ThemeRing()
			badge.ring:SetDesaturated(ring and true or false)
			badge.ring:SetVertexColor(ring and ring[1] or 1, ring and ring[2] or 1, ring and ring[3] or 1)
			badge.ring.gameCircle = true
		end
	end
	badge.ring:SetShown(back ~= nil)
	badge.back:SetShown(back ~= nil and not badge.ring.gameCircle)
	badge.text:ClearAllPoints()
	badge.text:SetSize(0, 0)
	badge.text:SetPoint("CENTER", unit.health, "TOPLEFT", (level.x + level.w / 2) * hw, -(level.y + level.h / 2) * hw)
	badge.text:SetJustifyH(level.justify or "CENTER")
	local file, _, flags = badge.text:GetFont()
	if file and level.font then badge.text:SetFont(file, math.max(6, level.font * hw), flags or "") end
	badge.text:Show()
end

function ns.DressUnitParts(unit)
	local sample = unit.sample
	local scale = (unit.copy and unit.copy.on and unit.copyScale) or 0.84
	local hangs = ns.UnitHangs and ns.UnitLookKey and ns.UnitHangs(unit.id, ns.UnitLookKey(unit.id))
	MeasuredBody(unit, hangs)
	Auras(unit, sample.auras, scale, hangs and hangs.aura)
	MeasuredLevel(unit, hangs)
	-- (The copy too: a theme on the game's own shape (Gilded Codex) hides its circle.)
	local copy = unit.copy
	if copy and copy.on and hangs then
		if hangs.levelBackHidden and copy.circle then copy.circle:Hide() end
		if hangs.levelHidden and unit.badge then unit.badge.text:Hide() end
	end
	local how = StatusTextHow()
	BarTexts(unit, unit.health, "healthTexts", sample.health or 1, sample.maxHealth, how, scale)
	-- (Mana: the samples' blue power, else your pet's live one.)
	local power = unit.id == "PET" and ns.LivePetPower and ns.LivePetPower() or sample.power
	local mana = type(power) == "table" and power[1] == 0 and power[3] == 1
	BarTexts(unit, unit.power, "powerTexts", sample.amount or 1, sample.maxPower, how, scale, not mana)
	DressLevel(unit, sample, scale)
	Classification(unit, sample, unit.copyRecipe, scale)
end

-- A frame's buffs row wrapped before its target of target, as the game's own
-- row stops short of it when one's shown (user 2026-11-20: the focus's buffs
-- lay on its target of target). Each that would touch it goes to a row below.
function ns.WrapUnitAuras(unit, tot)
	local row = unit.auraRow
	if not (row and unit.auras and unit.auras[1] and unit.auras[1]:IsShown()) then return end
	local function Screen(region)
		local l, r, t, b = region:GetLeft(), region:GetRight(), region:GetTop(), region:GetBottom()
		if not (l and r and t and b) then return nil end
		local k = region:GetEffectiveScale()
		return l * k, r * k, t * k, b * k
	end
	local tl, tr, tt, tb
	if tot and tot:IsShown() then tl, tr, tt, tb = Screen(tot) end
	local step = row[5]
	local col, line = 0, 0
	-- (The game's rows: 122 units wide, the first two 101 while a target of
	-- target shows: 6 icons a row, 5 beside it. The second kind on its own line.)
	local totUp = tl ~= nil
	for _, aura in ipairs(unit.auras) do
		if aura:IsShown() then
			if aura.newLine and col > 0 then col, line = 0, line + 1 end
			if col >= ((totUp and line < 2) and 5 or 6) then col, line = 0, line + 1 end
			-- (Still on it: a line further, even from a line's start, where the
			-- second kind's own line begins.)
			for _ = 1, 5 do
				aura:ClearAllPoints()
				aura:SetPoint("TOPLEFT", row[1], row[2], row[3] + col * step, row[4] + (row[6] and line or -line) * step)
				local al, ar, at, ab = Screen(aura)
				local touches = tl and al and ar > tl - 2 and al < tr + 2 and at > tb - 2 and ab < tt + 2
				if touches then
					col, line = 0, line + 1
				else
					break
				end
			end
			col = col + 1
		end
	end
end
end) -- (ns.Module "style")
