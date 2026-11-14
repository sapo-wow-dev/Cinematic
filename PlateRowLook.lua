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
function ns.PlateRowLookFor(kind)
	if not kind then return nil end
	local function Get(key)
		local value = Own(key, kind)
		if value == nil and kind ~= "others" then value = Own(key, "others") end
		return value
	end
	local look, any = {}, false
	local texture = Get("LookTexture")
	if texture ~= nil then look.texture, any = texture, true end
	local border = Get("LookBorder")
	if border ~= nil then
		-- (Custom's size and color from the same row as the border's kind.)
		local from = Own("LookBorder", kind) ~= nil and kind or "others"
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
