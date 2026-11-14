-- A Nameplate Style row's own Look (its drawer's Look line, a Look panel as
-- the Style pages have): the health bar's texture and border, the name's
-- font, size, outline and shadow, and Forever's level box, on the plates
-- that row goes by. Each setting (keys as the row's others: MarkKey's
-- <kind>Mark<Look...>, targetArrow<Look...> for your target) starts as
-- "default": the Default row's, and the Default row's own default is the
-- plate's usual look (the Style hub's General page, else the game's).
-- PlateParts asks for a plate's row (ns.ApplyPlateRowLook, from its marks'
-- pass); PlateHealthStyle draws the bar and border (ns.PlateBarOverride);
-- PlateParts' own names and ApplyPlate read the name and level here.

local _, ns = ...

-- The settings, by their part of a key, and what each holds while it's the
-- Default row's (nil, or these).
local KEYS = { "LookTexture", "LookBorder", "LookBorderSize", "LookBorderR", "LookBorderG", "LookBorderB",
	"LookFont", "LookTextSize", "LookOutline", "LookShadow", "LookLevel" }
ns.PLATE_LOOK_KEYS = KEYS
local DEFAULT_VALUE = { LookTexture = "default", LookBorder = "default", LookFont = "default", LookTextSize = 1,
	LookOutline = -1, LookShadow = "default", LookLevel = "default", LookBorderSize = 1, LookBorderR = 0,
	LookBorderG = 0, LookBorderB = 0 }
ns.PLATE_LOOK_DEFAULTS = DEFAULT_VALUE

local function IsDefault(key, value)
	return value == nil or value == DEFAULT_VALUE[key]
end

-- A row's own setting (nil: the Default row's). Only while its Look is
-- Custom (its drawer's Look line, PlateColor): the quick colors have none.
local function Own(key, kind)
	if not ns.TargetMarkOwn or ns.TargetMarkOwn("PlateColor", kind) ~= "custom" then return nil end
	if ns.MarkRowBase(kind) == "aggro" and ns.TargetMarkOwn("AlsoSame", kind) then return nil end
	local value = ns.TargetMarkOwn(key, kind)
	if IsDefault(key, value) then return nil end
	return value
end

-- Whether a row has a look of its own (any of the main settings set).
function ns.PlateRowHasLook(kind)
	for _, key in ipairs({ "LookTexture", "LookBorder", "LookFont", "LookTextSize", "LookOutline", "LookShadow",
		"LookLevel" }) do
		if Own(key, kind) ~= nil then return true end
	end
	return false
end

-- A row's look as it shows: its own settings, else the Default row's; nil
-- fields for the plate's usual look. { texture, border = { kind, size, r,
-- g, b }, font (a file), fontValue, size, outline, shadow, level = true
-- (shown) / false (hidden) }, or nil for none at all.
-- over: { key = value } in place of the row's own (the Look panel's preview,
-- for a choice pointed at: never saved).
function ns.PlateRowLookFor(kind, over)
	if not kind then return nil end
	local function Mine(key)
		if over and over[key] ~= nil then
			if IsDefault(key, over[key]) then return nil end
			return over[key]
		end
		return Own(key, kind)
	end
	local function Get(key)
		local value = Mine(key)
		if value == nil and kind ~= "others" then value = Own(key, "others") end
		return value
	end
	local look, any = {}, false
	local texture = Get("LookTexture")
	if texture ~= nil then look.texture, any = texture, true end
	local border = Get("LookBorder")
	if border ~= nil then
		-- (Custom's size and color from the same row as the border's kind.)
		local from = Mine("LookBorder") ~= nil and kind or "others"
		local values = { b = border, bSize = ns.TargetMarkOwn("LookBorderSize", from),
			bR = ns.TargetMarkOwn("LookBorderR", from), bG = ns.TargetMarkOwn("LookBorderG", from),
			bB = ns.TargetMarkOwn("LookBorderB", from) }
		look.border = { ns.StyleBorder({ b = values.b, bSize = values.bSize, bR = values.bR, bG = values.bG,
			bB = values.bB }, "b") }
		any = true
	end
	local font = Get("LookFont")
	if font ~= nil then
		look.fontValue = font
		look.font = font ~= "game" and ns.StyleFontFile and ns.StyleFontFile(font) or nil
		any = true
	end
	local size = Get("LookTextSize")
	if size ~= nil then look.size, any = tonumber(size) or 1, true end
	local outline = Get("LookOutline")
	if outline ~= nil then look.outline, any = tonumber(outline), true end
	local shadow = Get("LookShadow")
	if shadow ~= nil then look.shadow, any = shadow, true end
	local level = Get("LookLevel")
	if level ~= nil then look.level, any = level == "show", true end
	return any and look or nil
end

-- Whether any row (or Default) has a look: none, and the marks' pass skips
-- all of this. (Worked out once a frame at most.)
local anyAt, anyNow = -1, false
function ns.PlateLooksOn()
	local now = GetTime()
	if now ~= anyAt then
		anyAt, anyNow = now, false
		for _, kind in ipairs(ns.TargetMarkOrder and ns.TargetMarkOrder() or {}) do
			if ns.PlateRowHasLook(kind) then anyNow = true break end
		end
		anyNow = anyNow or ns.PlateRowHasLook("others")
	end
	return anyNow
end

-- Each plate's look now and the row it's from (for drawing it again only
-- when it changes), and its name's own font from before (put back after).
local applied = setmetatable({}, { __mode = "k" }) -- [plate] = { sig, look }
local nameBefore = setmetatable({}, { __mode = "k" }) -- [fontstring] = { object, file, size, flags, sx, sy }

local function Signature(look)
	if not look then return "" end
	local border = look.border and table.concat(look.border, ",") or ""
	return table.concat({ tostring(look.texture), border, tostring(look.fontValue), tostring(look.size),
		tostring(look.outline), tostring(look.shadow), tostring(look.level) }, "|")
end

-- The game's name on the plate: its own font back.
local function NameBack(name)
	local before = nameBefore[name]
	if not before then return end
	nameBefore[name] = nil
	if before.object then
		pcall(name.SetFontObject, name, before.object)
	elseif before.file then
		pcall(name.SetFont, name, before.file, before.size, before.flags)
	end
	pcall(name.SetShadowOffset, name, before.sx or 0, before.sy or 0)
	pcall(function() name:SetText(name:GetText()) end)
end

-- The game's name on the plate in the look's font, size, outline and shadow.
local function NameLook(name, look)
	if not (name and name.GetFont) then return end
	if not (look and (look.font or look.fontValue == "game" or look.size or look.outline or look.shadow)) then
		NameBack(name)
		return
	end
	if not nameBefore[name] then
		local file, size, flags = name:GetFont()
		local sx, sy = name:GetShadowOffset()
		nameBefore[name] = { object = name.GetFontObject and name:GetFontObject(), file = file, size = size,
			flags = flags, sx = sx, sy = sy }
	end
	local before = nameBefore[name]
	local file = look.font or before.file
	local size = before.size or 10
	local flags = before.flags
	if look.outline and look.outline >= 0 and ns.OutlinedFlags then flags = ns.OutlinedFlags(flags, look.outline) end
	if file and ns.SetPlateNameFont then
		ns.SetPlateNameFont(name, before.object or _G.SystemFont_NamePlate or _G.GameFontNormal, file, size,
			look.size or 1, flags)
	end
	if look.shadow == "on" then
		name:SetShadowOffset(1, -1)
		name:SetShadowColor(0, 0, 0, 1)
	elseif look.shadow == "none" then
		name:SetShadowOffset(0, 0)
	elseif look.shadow == "game" then
		name:SetShadowOffset(before.sx or 0, before.sy or 0)
	end
end

-- The look a plate goes by now (nil: none), for PlateParts' level box and
-- its own drawn names.
function ns.PlateLookNow(plate)
	local entry = plate and applied[plate]
	return entry and entry.look or nil
end

-- A plate's row (kind, nil: none) as the marks' pass found it: its look on
-- the plate, drawn again only if it changed.
function ns.ApplyPlateRowLook(plate, kind)
	local look = ns.PlateRowLookFor(kind)
	local sig = Signature(look)
	local entry = applied[plate]
	if (entry and entry.sig or "") == sig then return end
	if look then applied[plate] = { sig = sig, look = look } else applied[plate] = nil end
	-- (The bar and border: PlateHealthStyle, over General's.)
	if ns.SetPlateBarOverride then
		ns.SetPlateBarOverride(plate, look and (look.texture or look.border) and look or nil)
	end
	local unitFrame = plate.UnitFrame
	pcall(NameLook, unitFrame and unitFrame.name, look)
	-- (Our own name on a faded plate, and the level box: PlateParts.)
	if ns.DirtyPlateName then ns.DirtyPlateName(plate) end
	if ns.ApplyPlateNow then ns.ApplyPlateNow(plate) end
end

-- A plate gone (or come with another unit): its look let go.
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
watcher:RegisterEvent("NAME_PLATE_UNIT_ADDED")
watcher:SetScript("OnEvent", function(_, event, unit)
	local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unit)
	if not plate then return end
	if applied[plate] then
		applied[plate] = nil
		if ns.SetPlateBarOverride then ns.SetPlateBarOverride(plate, nil) end
		local unitFrame = plate.UnitFrame
		pcall(NameBack, unitFrame and unitFrame.name)
	end
	-- (Come with a unit: its row's look, as the marks' pass finds it.)
	if event == "NAME_PLATE_UNIT_ADDED" and ns.RefreshClassIcon and ns.PlateLooksOn() then
		C_Timer.After(0, function() ns.RefreshClassIcon(plate) end)
	end
end)

-- The Look panel's preview (StylePages.lua's rows.Look, spec.preview): a plate
-- as this row's Look draws it, over the Default row's, General's and the
-- game's, in the row's color where it paints the bar or the name. Under it a
-- sample unit to pick, the lake or plain dark behind, and a closer look. (The
-- picks are kept for the next panel opened.)
local PLATE_FILL, PLATE_GROUND = "UI-HUD-CoolDownManager-Bar", "UI-HUD-CoolDownManager-Bar-BG"
local ROMAN = not ({ ruRU = true, koKR = true, zhCN = true, zhTW = true })[GetLocale and GetLocale() or ""]
-- { pick's name, unit's name, bar color, name color, level } (the Player: you).
local SAMPLES = {
	{ "Hostile", "Gnoll Brute", { 0.85, 0.12, 0.1 }, { 1, 0.25, 0.2 }, 17 },
	{ "Neutral", "Kodo Bull", { 0.9, 0.78, 0.15 }, { 1, 0.9, 0.3 }, 14 },
	{ "Friendly", "Stormwind Guard", { 0.2, 0.75, 0.2 }, { 0.4, 1, 0.4 }, 55 },
	{ "Player" },
}
local sampleNow, sceneNow, closeNow = 1, true, false

local function HasAtlas(name)
	return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

-- A small pick under the plate: gold while on.
local function Pill(parent, text, onClick)
	local pill = CreateFrame("Button", nil, parent)
	pill:SetFrameLevel(parent:GetFrameLevel() + 10)
	local back = pill:CreateTexture(nil, "BACKGROUND")
	back:SetAllPoints()
	local words = pill:CreateFontString(nil, "OVERLAY", ns.LOOK_TEXT)
	words:SetPoint("CENTER", 0, 0)
	words:SetText(text)
	pill:SetSize(words:GetStringWidth() + 16, 16)
	local glow = pill:CreateTexture(nil, "HIGHLIGHT")
	glow:SetAllPoints()
	glow:SetColorTexture(1, 1, 1, 0.12)
	function pill.SetOn(_, on)
		if on then
			back:SetColorTexture(1, 0.82, 0, 0.95)
			words:SetTextColor(0.08, 0.08, 0.08)
		else
			back:SetColorTexture(0, 0, 0, 0.65)
			words:SetTextColor(0.85, 0.82, 0.74)
		end
	end
	pill:SetScript("OnClick", onClick)
	return pill
end

function ns.MakePlateRowLookPreview(parent, width, kind)
	local L = ns.L
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(width, 112)
	if holder.SetClipsChildren then holder:SetClipsChildren(true) end
	local dark = holder:CreateTexture(nil, "BACKGROUND", nil, -7)
	dark:SetAllPoints()
	dark:SetColorTexture(0.04, 0.04, 0.05, 1)

	local plate = CreateFrame("Frame", nil, holder)
	plate:SetSize(160, 34)
	plate:SetPoint("CENTER", holder, "CENTER", 0, 9)
	local health = CreateFrame("StatusBar", nil, plate)
	health:SetSize(118, 10)
	health:SetPoint("BOTTOM", plate, "BOTTOM", 0, 4)
	health:SetMinMaxValues(0, 1)
	health:SetValue(0.72)
	local ground = health:CreateTexture(nil, "BACKGROUND")
	ground:SetPoint("TOPLEFT", -2, 2)
	ground:SetPoint("BOTTOMRIGHT", 2, -2)
	local back = health:CreateTexture(nil, "BACKGROUND", nil, -1)
	back:SetAllPoints()
	back:SetColorTexture(0, 0, 0, 0.6)
	local border = ns.MakeStyleEdges(health)
	local name = plate:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	name:SetPoint("BOTTOM", health, "TOP", 0, 3)
	name.searchSkip = true
	local own = { name:GetFont() }
	local ownX, ownY = name:GetShadowOffset()
	-- (Forever's level box at the bar's end.)
	local levelBox = CreateFrame("Frame", nil, plate)
	levelBox:SetSize(16, 12)
	levelBox:SetPoint("LEFT", health, "RIGHT", 3, 0)
	local boxEdge = levelBox:CreateTexture(nil, "BACKGROUND")
	boxEdge:SetAllPoints()
	boxEdge:SetColorTexture(0.45, 0.38, 0.22, 1)
	local boxBack = levelBox:CreateTexture(nil, "BORDER")
	boxBack:SetPoint("TOPLEFT", 1, -1)
	boxBack:SetPoint("BOTTOMRIGHT", -1, 1)
	boxBack:SetColorTexture(0, 0, 0, 1)
	local levelText = levelBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	levelText:SetPoint("CENTER", 0, 0)
	levelText.searchSkip = true

	local picks = {}
	for i, sample in ipairs(SAMPLES) do
		local pill = Pill(holder, L[sample[1]], function()
			sampleNow = i
			holder:Refresh()
		end)
		if i == 1 then
			pill:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 6, 6)
		else
			pill:SetPoint("BOTTOMLEFT", picks[i - 1], "BOTTOMRIGHT", 4, 0)
		end
		picks[i] = pill
	end
	local closeButton = Pill(holder, L["Closer"], function()
		closeNow = not closeNow
		holder:Refresh()
	end)
	closeButton:SetPoint("BOTTOMRIGHT", -6, 6)
	local sceneButton = Pill(holder, L["Scene"], function()
		sceneNow = not sceneNow
		holder:Refresh()
	end)
	sceneButton:SetPoint("BOTTOMRIGHT", closeButton, "BOTTOMLEFT", -4, 0)
	ns.lowHealthKit.Tooltip(sceneButton, L["The lake behind the plate, or plain dark."])
	ns.lowHealthKit.Tooltip(closeButton, L["The plate bigger, for a closer look."])

	-- (Over the scene's top right while a choice is only pointed at.)
	local tag = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	tag:SetPoint("TOPRIGHT", -8, -6)
	tag:SetText(L["Preview: not saved"])
	tag.searchSkip = true

	-- over: a choice pointed at in the panel ({ key = value }), shown, not saved.
	function holder.Refresh(self, over)
		local db = ns.db
		if not db then return end
		tag:SetShown(over ~= nil)
		for i, pill in ipairs(picks) do pill:SetOn(i == sampleNow) end
		sceneButton:SetOn(sceneNow)
		closeButton:SetOn(closeNow)
		-- (The lake, or the plain dark: that one over it, so hidden for the lake.)
		if sceneNow then
			ns.StyleScene(self, 0.55, 0.85)
			self.styleScene:Show()
		elseif self.styleScene then
			self.styleScene:Hide()
		end
		dark:SetShown(not sceneNow)
		plate:SetScale(closeNow and 2.4 or 1.6)

		local sample = SAMPLES[sampleNow]
		local unitName, barColor, nameColor, level = sample[2] and L[sample[2]], sample[3], sample[4], sample[5]
		if not unitName then
			unitName = UnitName("player") or L["Player"]
			local class = select(2, UnitClass("player"))
			local classColor = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
			barColor = classColor and { classColor.r, classColor.g, classColor.b } or { 0.25, 0.78, 0.92 }
			nameColor = { 1, 1, 1 }
			level = UnitLevel("player")
		end
		local look = ns.PlateRowLookFor(kind, over) or {}
		local on = db.styleGeneral
		local general = on and db or ns.DEFAULTS
		-- (The row's color, where it paints the bar or the name.)
		local paint = ns.TargetMarkOwn and ns.TargetMarkOwn("PlateColor", kind) == "custom"
		local color = paint and { ns.TargetMarkOwn("PlateR", kind) or 1, ns.TargetMarkOwn("PlateG", kind) or 1,
			ns.TargetMarkOwn("PlateB", kind) or 1 }
		if color and ns.TargetMarkOwn("ColorBar", kind) then barColor = color end
		if color and ns.TargetMarkOwn("ColorName", kind) then nameColor = color end

		-- Its fill: the row's texture, else General's, else the game's.
		local texture = look.texture
		if texture == nil then texture = on and general.styleTexture or "game" end
		if texture == "game" or not ns.SetBarTexture(health, texture) then
			health:SetStatusBarTexture(HasAtlas(PLATE_FILL) and PLATE_FILL or "Interface\\TargetingFrame\\UI-StatusBar")
			local fill = health:GetStatusBarTexture()
			if fill and fill.SetDesaturated then fill:SetDesaturated(false) end
		end
		health:SetStatusBarColor(barColor[1], barColor[2], barColor[3])
		if ns.DressThemeVeil then ns.DressThemeVeil(health, "plate") end
		-- Its border: the row's, else General's (the game's: its ground).
		local edgeKind, size, r, g, b
		if look.border then
			edgeKind, size, r, g, b = unpack(look.border)
		else
			edgeKind, size, r, g, b = ns.StyleBorder(general, "styleBorder")
		end
		local game = edgeKind == "game"
		ground:SetShown(game)
		if game then
			if HasAtlas(PLATE_GROUND) then ground:SetAtlas(PLATE_GROUND) else ground:SetColorTexture(0, 0, 0, 0.7) end
		end
		back:SetShown(not game)
		border:SetShown(edgeKind == "line")
		if edgeKind == "line" then ns.DressStyleEdges(border, size, r, g, b, 1, true) end

		-- Its name: the row's font, size, outline and shadow, else the Name
		-- Style page's and General's. (The font set before the text: else
		-- other alphabets show boxes.)
		local file, height, flags = own[1], own[2], own[3]
		if file and height then
			if ROMAN and on then file = ns.StyleFontFile(general.styleFont) or file end
			file = look.font or file
			local outline = look.outline
			if not (outline and outline >= 0) then
				outline = tonumber(db.plateNameOutline) or tonumber(ns.DEFAULTS.plateNameOutline) or 0
			end
			if outline > 0 and ns.OutlinedFlags then flags = ns.OutlinedFlags(flags, outline) end
			name:SetFont(file, height * (look.size or 1), flags or "")
		end
		name:SetText(unitName)
		local shadow = look.shadow
		if shadow == nil or shadow == "default" then
			local nameShadow = db.plateNameShadow
			if nameShadow == nil then nameShadow = ns.DEFAULTS.plateNameShadow end
			shadow = nameShadow and "on" or "game"
		end
		if shadow == "on" then
			name:SetShadowOffset(1, -1)
			name:SetShadowColor(0, 0, 0, 1)
		elseif shadow == "none" then
			name:SetShadowOffset(0, 0)
		else
			name:SetShadowOffset(ownX or 0, ownY or 0)
		end
		name:SetTextColor(nameColor[1], nameColor[2], nameColor[3])

		-- Its level box (Forever's): shown unless the row hides it.
		levelBox:SetShown(not ns.isRetail and look.level ~= false)
		levelText:SetText(level and level > 0 and tostring(level) or "??")
	end
	holder:SetScript("OnShow", function(self) self:Refresh() end)
	return holder
end

-- What a row's usual gives for one Look setting (the Look panel's Usual
-- tiles and buttons): its name and value. A row's usual is the Default row's;
-- the Default row's, General's and the Name Style page's, else the game's.
local BORDER_WORDS = { game = "The game's", none = "None", thin = "Thin", thick = "Thick", custom = "Custom" }
local OUTLINE_WORDS = { [0] = "None", "Thin", "Thick" }
local SHADOW_WORDS = { game = "The game's", on = "Shadow", none = "None" }
function ns.PlateRowUsual(kind, key)
	local L = ns.L
	local db = ns.db or {}
	local on = db.styleGeneral
	local value = kind ~= "others" and Own(key, "others") or nil
	if key == "LookTexture" then
		if value == nil then value = on and db.styleTexture or "game" end
		return value == "game" and L["The game's"] or (ns.StyleTextureName and ns.StyleTextureName(value) or value),
			value
	elseif key == "LookFont" then
		if value == nil then value = on and db.styleFont or "game" end
		return value == "game" and L["The game's"] or ns.StyleFontName(value), value
	elseif key == "LookBorder" then
		if value == nil then value = on and db.styleBorder or "game" end
		return L[BORDER_WORDS[value] or "The game's"], value
	elseif key == "LookOutline" then
		if value == nil then
			value = tonumber(db.plateNameOutline) or tonumber(ns.DEFAULTS.plateNameOutline) or 0
		end
		return L[OUTLINE_WORDS[value] or "None"], value
	elseif key == "LookShadow" then
		if value == nil then
			local shadow = db.plateNameShadow
			if shadow == nil then shadow = ns.DEFAULTS.plateNameShadow end
			value = shadow and "on" or "game"
		end
		return L[SHADOW_WORDS[value] or "The game's"], value
	elseif key == "LookLevel" then
		if value == nil then value = "show" end
		return value == "hide" and L["Hidden"] or L["Shown"], value
	end
end
