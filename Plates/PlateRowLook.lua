-- A Nameplate Style row's own Look (its drawer's Look line, a Look panel as
-- the Style pages have): the health bar's texture and border, the name's
-- font, size, outline and shadow, and Forever's level box, on the plates
-- that row goes by. Each setting (keys as the row's others: MarkKey's
-- <kind>Mark<Look...>, targetArrow<Look...> for your target) starts as
-- "default": the Default row's, and the Default row's own default is the
-- plate's usual look: for the bar, the Style hub's General page, else the
-- game's; for the name, Name Style's All names (what it has changed from
-- how it starts), else the game's.
-- PlateParts asks for a plate's row (ns.ApplyPlateRowLook, from its marks'
-- pass); PlateHealthStyle draws the bar and border (ns.PlateBarOverride);
-- PlateParts' own names and ApplyPlate read the name and level here.

local _, ns = ...
ns.Module("style", function() -- (the rest of this file: only with Style loaded, Modules.lua)

-- The settings, by their part of a key, and what each holds while it's the
-- Default row's (nil, or these).
local KEYS = { "LookTexture", "LookBorder", "LookBorderSize", "LookBorderR", "LookBorderG", "LookBorderB",
	"LookFont", "LookTextSize", "LookOutline", "LookShadow", "LookLevel", "LookGradient", "LookGradR", "LookGradG",
	"LookGradB" }
ns.PLATE_LOOK_KEYS = KEYS
local DEFAULT_VALUE = { LookTexture = "default", LookBorder = "default", LookFont = "default", LookTextSize = 1,
	LookOutline = -1, LookShadow = "default", LookLevel = "default", LookBorderSize = 1, LookBorderR = 0,
	LookBorderG = 0, LookBorderB = 0, LookGradient = "default", LookGradR = 0.1, LookGradG = 0.1, LookGradB = 0.1 }
ns.PLATE_LOOK_DEFAULTS = DEFAULT_VALUE

local function IsDefault(key, value)
	return value == nil or value == DEFAULT_VALUE[key]
end

-- A row's own setting (nil: the Default row's). Only while its Look is
-- Custom (its drawer's Look line, PlateColor): the quick colors have none.
-- The Default row's always (2026-11-16): the Default Plate Style tab's
-- Customize sets it, the plates' own look under every row.
local function Own(key, kind)
	if not ns.TargetMarkOwn then return nil end
	if kind ~= "others" and ns.TargetMarkOwn("PlateColor", kind) ~= "custom" then return nil end
	if ns.MarkRowBase(kind) == "aggro" and ns.TargetMarkOwn("AlsoSame", kind) then return nil end
	local value = ns.TargetMarkOwn(key, kind)
	if IsDefault(key, value) then return nil end
	return value
end

-- The name on a full plate under the rows: Name Style's All names (its
-- outline and shadow, where it doesn't hand them on to the game's), with
-- that page on. nil: the game's.
local function AllNames(key)
	local db = ns.db
	if not (db and db.plateNameStyle) then return nil end
	-- (Set on All names, not handed on to the game's: NameRowLook.lua.)
	if key == "LookOutline" then
		local value, from = ns.NameLookValue("all", "Outline")
		if from ~= "game" then return tonumber(value) end
	elseif key == "LookShadow" then
		local value, from = ns.NameLookValue("all", "Shadow")
		if from ~= "game" then return value and "on" or "none" end
	end
	return nil
end

-- (The name's outline and shadow from All names, where the rows have none.)
local function NamesLayer(look)
	local any = false
	if look.outline == nil then
		local outline = AllNames("LookOutline")
		if outline ~= nil then look.outline, any = outline, true end
	end
	if look.shadow == nil then
		local shadow = AllNames("LookShadow")
		if shadow ~= nil then
			look.shadow, any = shadow, true
			local db = ns.db
			if shadow == "on" then
				look.shadowAt = { tonumber(db.plateNameShadowX) or 1, tonumber(db.plateNameShadowY) or -1,
					tonumber((ns.NameLookValue("all", "ShadowAlpha"))) or 1 }
			end
		end
	end
	return any
end

-- Whether a row has a look of its own (any of the main settings set).
-- (The list made once: built at each call, it was the top garbage maker in a
-- 40-plate city, 20 KB a second, 2026-11-15.)
local MAIN_KEYS = { "LookTexture", "LookBorder", "LookFont", "LookTextSize", "LookOutline", "LookShadow",
	"LookLevel", "LookGradient" }
function ns.PlateRowHasLook(kind)
	for _, key in ipairs(MAIN_KEYS) do
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
	-- (nil: none at all, the page off. false: a plate no row fits, All
	-- names' alone.)
	if kind == nil then return nil end
	if not kind then
		local look = {}
		return NamesLayer(look) and look or nil
	end
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
	-- (The fill fading to a second color, left to right: { r, g, b } it fades
	-- to, or false for none; its color from the same row as the setting.)
	local gradient = Get("LookGradient")
	if gradient ~= nil then
		look.gradient = false
		if gradient == "on" then
			local from = Mine("LookGradient") ~= nil and kind or "others"
			local function Part(key)
				-- (Not "a and b and c": false, not nil, when from isn't kind.)
				local value
				if from == kind and over then value = over[key] end
				if value == nil then value = ns.TargetMarkOwn(key, from) end
				return tonumber(value) or DEFAULT_VALUE[key]
			end
			look.gradient = { Part("LookGradR"), Part("LookGradG"), Part("LookGradB") }
		end
		any = true
	end
	if NamesLayer(look) then any = true end
	return any and look or nil
end

-- Whether any row (or Default) has a look: none, and the marks' pass skips
-- all of this. (Worked out once a frame at most.)
-- (Kept until a Style setting changes, ns.PlateLooksChanged, or 2 seconds
-- pass: worked out each frame a plate came, it cost 0.55 ms a time with
-- 40 plates up, 2026-11-14. Rows' looks below kept the same way.)
local KEEP = 2
local anyAt, anyNow = -100, false
local looks = {} -- [kind] = { look (false: none), sig }
local looksAt = -100
function ns.PlateLooksChanged()
	anyAt, looksAt = -100, -100
	wipe(looks)
end
function ns.PlateLooksOn()
	local now = GetTime()
	if now - anyAt > KEEP then
		anyAt, anyNow = now, false
		for _, kind in ipairs(ns.TargetMarkOrder and ns.TargetMarkOrder() or {}) do
			if ns.PlateRowHasLook(kind) then anyNow = true break end
		end
		anyNow = anyNow or ns.PlateRowHasLook("others")
		-- (All names' outline or shadow reach every plate's name.)
		anyNow = anyNow or AllNames("LookOutline") ~= nil or AllNames("LookShadow") ~= nil
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
	local gradient = look.gradient and table.concat(look.gradient, ",") or tostring(look.gradient)
	local shadowAt = look.shadowAt and table.concat(look.shadowAt, ",") or ""
	return table.concat({ tostring(look.texture), border, tostring(look.fontValue), tostring(look.size),
		tostring(look.outline), tostring(look.shadow), tostring(look.level), gradient, shadowAt }, "|")
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

-- (Russian, Korean and Chinese letters: only the game's fonts have them.)
local ROMAN = not ({ ruRU = true, koKR = true, zhCN = true, zhTW = true })[GetLocale and GetLocale() or ""]

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
	-- (Our font only where its letters show: a font family keeps the game's
	-- for other alphabets; without one, other alphabets keep the game's file.)
	local file = (ROMAN or CreateFontFamily) and look.font or before.file
	local size = before.size or 10
	local flags = before.flags
	if look.outline and look.outline >= 0 and ns.OutlinedFlags then flags = ns.OutlinedFlags(flags, look.outline) end
	if file and ns.SetPlateNameFont then
		ns.SetPlateNameFont(name, before.object or _G.SystemFont_NamePlate or _G.GameFontNormal, file, size,
			look.size or 1, flags)
	end
	if look.shadow == "on" then
		-- (All names' own place and depth, from that page.)
		local at = look.shadowAt
		name:SetShadowOffset(at and at[1] or 1, at and at[2] or -1)
		name:SetShadowColor(0, 0, 0, at and at[3] or 1)
	elseif look.shadow == "none" then
		name:SetShadowOffset(0, 0)
	elseif look.shadow == "game" then
		name:SetShadowOffset(before.sx or 0, before.sy or 0)
	end
end

-- A preview's game plate name in a look (General's screen, PlateCopy.lua).
function ns.PlateNameLook(name, look) pcall(NameLook, name, look) end


-- The look a plate goes by now (nil: none), for PlateParts' level box and
-- its own drawn names.
function ns.PlateLookNow(plate)
	local entry = plate and applied[plate]
	return entry and entry.look or nil
end

-- A plate's row (kind; false: none fits; nil: none at all, the page off) as
-- the marks' pass found it: its look on the plate, drawn again only if it
-- changed.
function ns.ApplyPlateRowLook(plate, kind)
	-- (The same for every plate on a row: kept, see KEEP.)
	local now = GetTime()
	if now - looksAt > KEEP then
		looksAt = now
		wipe(looks)
	end
	local key = kind == nil and "-" or kind == false and "+" or kind
	local kept = looks[key]
	if not kept then
		local made = ns.PlateRowLookFor(kind)
		kept = { made or false, Signature(made) }
		looks[key] = kept
	end
	local look, sig = kept[1] or nil, kept[2]
	local entry = applied[plate]
	if (entry and entry.sig or "") == sig then return end
	if look then applied[plate] = { sig = sig, look = look } else applied[plate] = nil end
	-- (The bar and border: PlateHealthStyle, over General's.)
	if ns.SetPlateBarOverride then
		ns.SetPlateBarOverride(plate, look and (look.texture or look.border or look.gradient ~= nil) and look or nil)
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
	if event == "NAME_PLATE_UNIT_ADDED" and ns.RefreshPlateLook and ns.PlateLooksOn() then
		C_Timer.After(0, function() ns.RefreshPlateLook(plate) end)
	end
end)

-- The Look panel's preview (StylePages.lua's rows.Look, spec.preview): a plate
-- as this row's Look draws it, over the Default row's, General's and the
-- game's, in the row's color where it paints the bar or the name. Under it a
-- sample unit to pick, the lake or plain dark behind, and a closer look. (The
-- picks are kept for the next panel opened.)
local PLATE_FILL, PLATE_GROUND = "UI-HUD-CoolDownManager-Bar", "UI-HUD-CoolDownManager-Bar-BG"
-- { pick's name, unit's name, bar color, name color, level } (the Player: you).
local SAMPLES = {
	{ "Hostile", "Gnoll Brute", { 0.85, 0.12, 0.1 }, { 1, 0.25, 0.2 }, 17 },
	{ "Neutral", "Kodo Bull", { 0.9, 0.78, 0.15 }, { 1, 0.9, 0.3 }, 14 },
	{ "Friendly", "Stormwind Guard", { 0.2, 0.75, 0.2 }, { 0.4, 1, 0.4 }, 55 },
	{ "Player" },
}
local sampleNow = 1
-- The game plate's states shown (PlateCopy.lua), picked on the second row of
-- pills: each preview's own (2026-11-25: the Layout tab's picks showed on the
-- Default tab's preview), a new one starting from the last one used.
local statesNow = { casting = true }
local function StatesOf(holder)
	if holder and holder.states then
		statesNow = holder.states -- (the last one used: ns.PlatePreviewStates() with none given)
		return holder.states
	end
	return statesNow
end
-- { key, its name, its tooltip, its group (a heading in the list) }. The
-- either/or sets below (EXCLUSIVE): one of a set at a time.
local STATE_PILLS = {
	{ "target", "Target", "As your target: the game's border round the bar.", "Selected" },
	{ "focus", "Focus", "As your focus: the border in the focus color.", "Selected" },
	{ "casting", "Casting", "Casting a spell.", "Cast" },
	{ "locked", "Can't interrupt", "Casting a spell you can't interrupt.", "Cast" },
	{ "channel", "Channeling", "Channeling a spell: the bar drains.", "Cast" },
	{ "interrupted", "Interrupted", "A cast cut off, as the game shows it.", "Cast" },
	{ "important", "Important cast", "An important spell: the game's glow, if your cast bar settings show it.", "Cast" },
	{ "atyou", "Casting at you", "Its spell on you: your name and the game's glow, as your settings show them.", "Cast" },
	{ "elite", "Elite", "An elite: the game's elite mark.", "Rank" },
	{ "rare", "Rare", "A rare: the game's star.", "Rank" },
	{ "rareelite", "Rare elite", "A rare elite: the silver mark.", "Rank" },
	{ "boss", "Boss", "A boss: the gold mark and a skull for its level.", "Rank" },
	{ "aggro", "Aggro", "Attacking you, as your threat setting shows it.", "Threat" },
	{ "gaining", "Pulling threat", "About to turn on you, as your threat setting shows it.", "Threat" },
	{ "marker", "Marker", "With a raid marker.", "More" },
	{ "tapped", "Tapped", "Tapped by someone else: the game's grey bar.", "More" },
	{ "debuffs", "Debuffs", "With your debuffs on it.", "More" },
	-- (Its own buffs: the Layout tab places the buff row, 2026-11-25.)
	{ "buffs", "Buffs", "With its own buffs on it, if your nameplate settings show buffs.", "More" },
	{ "crowd", "Crowd control", "Rooted, stunned...: the game's row right of the level box.", "More" },
	{ "quest", "Quest giver", "Your soft target's icon over it: the game's quest mark.", "More" },
}
local EXCLUSIVE = { { "target", "focus" }, { "locked", "channel", "interrupted" }, { "elite", "rare", "rareelite", "boss" },
	{ "aggro", "gaining" } }
local NEEDS_CAST = { locked = true, channel = true, interrupted = true, important = true, atyou = true }
local function PickState(key, holder)
	local statesNow = StatesOf(holder) -- luacheck: ignore 431 (this preview's)
	local on = not statesNow[key]
	statesNow[key] = on or nil
	if on then
		for _, set in ipairs(EXCLUSIVE) do
			local inSet = false
			for _, each in ipairs(set) do if each == key then inSet = true end end
			if inSet then for _, each in ipairs(set) do if each ~= key then statesNow[each] = nil end end end
		end
		if NEEDS_CAST[key] then statesNow.casting = true end
	elseif key == "casting" then
		for cast in pairs(NEEDS_CAST) do statesNow[cast] = nil end
	end
end

-- The game plate's states as the previews keep them (the next panel opened
-- shows the same), and a State dropdown to tick them: onToggle() after each.
-- nil on a client without the dropdown template.
-- (holder: a preview's own; none, the last one used.)
function ns.PlatePreviewStates(holder) return StatesOf(holder) end
function ns.TogglePlatePreviewState(key, holder) PickState(key, holder) end -- (what the State list's ticks do)
function ns.MakePlateStateDropdown(parent, width, onToggle)
	local L = ns.L
	local ok, drop = ns.MenuDropdown(parent)
	if not (ok and drop and drop.SetupMenu) then return nil end
	drop.zoomSkip, drop.searchSkip = true, true
	drop:SetWidth(width)
	-- (parent: a preview with states of its own, else the last one used.)
	local function States() return StatesOf(parent.states and parent or nil) end
	drop:SetupMenu(function(_, root)
		local group
		for _, info in ipairs(STATE_PILLS) do
			if info[4] ~= group then
				group = info[4]
				ns.MenuTitle(root, L[group])
			end
			local box = root:CreateCheckbox(L[info[2]], function()
				local statesNow = States() -- luacheck: ignore 431
				return statesNow[info[1]] or (info[1] == "casting" and statesNow.locked) or false
			end, function()
				PickState(info[1], parent.states and parent or nil)
				onToggle()
				return MenuResponse and MenuResponse.Refresh -- (kept open: try one after another)
			end)
			local setTitle = _G.GameTooltip_SetTitle
			if box and box.SetTooltip and setTitle then
				box:SetTooltip(function(tooltip) setTitle(tooltip, L[info[3]]) end)
			end
		end
	end)
	if drop.SetSelectionText then
		drop:SetSelectionText(function()
			local on, states = {}, States()
			for _, info in ipairs(STATE_PILLS) do
				if states[info[1]] then on[#on + 1] = L[info[2]] end
			end
			return L["State: %s"]:format(#on > 0 and table.concat(on, ", ") or L["None"])
		end)
	end
	ns.lowHealthKit.Tooltip(drop, L["What the plate shows: your target, a cast, a marker... Tick any."])
	return drop
end

-- A game plate (PlateCopy.lua) dressed as a Smart Style row draws a plate, for
-- Nameplate Style's preview: kind, the row; who, the unit ("hostile",
-- "neutral", "friendly", "player") and name; theme, a plate theme pointed at
-- (nil: the saved one). As the page's drawn plates did: the row's mark, its
-- colors where it paints the name, bar or border (its Also colors), its Look
-- (bar and name), your target's border on target and aggro rows; and the
-- states picked in the State list.
function ns.DressGamePlateForRow(plate, kind, who, name, theme)
	local copy = plate and plate.gameCopy
	if not copy then return end
	local look = ns.PlateRowLookFor(kind)
	local base = ns.MarkRowBase(kind)
	local shown = ns.TargetMarkSetting("Show", kind) and true or false
	local tintKind = ns.TargetMarkTintKind(kind)
	local r, g, b = ns.TargetPlateColour(nil, tintKind)
	local paint = shown and { r, g, b } or nil
	local barColor = paint and ns.TargetMarkAlso("ColorBar", tintKind) and paint or nil
	local nameColor = paint and ns.TargetMarkAlso("ColorName", tintKind) and paint or nil
	pcall(NameLook, copy.name, look)
	ns.SetGamePlateUnit(plate, who, name, barColor, nameColor)
	ns.SetGamePlateLevel(plate, not (look and look.level == false))
	local states = {}
	for key, on in pairs(statesNow) do states[key] = on end
	if base == "target" or base == "aggro" then states.target, states.focus = true, nil end
	ns.SetGamePlateStates(plate, states)
	local border = copy.HealthBarsContainer.healthBar.selectedBorder
	if paint and ns.TargetMarkAlso("ColorBorder", tintKind) and border then border:SetVertexColor(r, g, b) end
	if ns.StylePlateBar then ns.StylePlateBar(plate, look, theme) end
	local bar = copy.HealthBarsContainer.healthBar
	plate.rowMark = plate.rowMark or (ns.MakeTargetArrow and ns.MakeTargetArrow(bar, bar))
	if plate.rowMark and ns.StyleTargetArrow then
		ns.StyleTargetArrow(plate.rowMark, nil, kind)
		plate.rowMark:SetShown(shown and ns.TargetMarkSetting("Style", kind) ~= "none")
		plate.rowMark:SetAlpha(ns.TargetMarkSetting("Opacity", kind) or 1)
	end
	return shown
end

local function HasAtlas(name)
	return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

-- The game's own art round a real plate's health bar (Forever's border
-- pieces, retail's dark ground), measured off one on the screen: each
-- piece's art, layer, color and its edges from the bar's edges, so a copy
-- sits round a bar of any size as the game's does. Found once, then kept;
-- nil while no plate is on the screen or its places can't be read. Our own
-- pieces on the bar (style edges, a theme's veil, anything of ours) left out.
local function Known(value)
	return value ~= nil and not (issecretvalue and issecretvalue(value))
end
local function Readable(value)
	return not (issecretvalue and issecretvalue(value))
end
-- (Places on a plate can't be read (secret), but how its pieces are pinned
-- can: the game's dark ground behind the bar, bgTexture, by its points on
-- the bar. Not the target's yellow edge, nor the absorb's shadow.)
local gameTrim
local function MeasureTrim(bar)
	if not (bar and bar.GetStatusBarTexture) then return nil end
	if not ns.Reachable(bar) then return nil end
	local ground = bar.bgTexture
	if not (ground and ground.GetNumPoints) then return nil end
	local atlas, file = ground.GetAtlas and ground:GetAtlas(), ground:GetTexture()
	if not (Readable(atlas) and Readable(file)) then return nil end
	local count = ns.NumPoints(ground)
	if not (Known(count) and count > 0) then return nil end
	local points = {}
	for i = 1, count do
		local point, relativeTo, relativePoint, x, y = ground:GetPoint(i)
		if not (Known(point) and Readable(relativeTo) and Known(relativePoint) and Known(x) and Known(y)) then return nil end
		-- (Pinned to the bar (or its own parent, the bar): else not ours to copy.)
		if relativeTo ~= nil and relativeTo ~= bar then return nil end
		points[i] = { point, relativePoint, x, y }
	end
	local width, height = ground:GetSize()
	local layer, sublevel = ground:GetDrawLayer()
	return { {
		atlas = type(atlas) == "string" and atlas ~= "" and atlas or nil, file = file, layer = layer, sublevel = sublevel,
		color = { ground:GetVertexColor() }, coords = { ground:GetTexCoord() }, alpha = ground:GetAlpha(),
		points = points, width = Known(width) and width or nil, height = Known(height) and height or nil,
	} }
end
local function GameTrim()
	if gameTrim or not (C_NamePlate and C_NamePlate.GetNamePlates) then return gameTrim end
	local skip = {}
	local personal = C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit("player")
	if personal then skip[personal] = true end
	for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
		local unitFrame = not skip[plate] and plate.UnitFrame
		local container = unitFrame and unitFrame.HealthBarsContainer
		local bar = unitFrame and ((container and container.healthBar) or unitFrame.healthBar)
		local ok, pieces = pcall(MeasureTrim, bar)
		if ok and pieces then
			gameTrim = pieces
			return pieces
		end
	end
end

-- What the preview copied (/cine debug platetextures).
function ns.GamePlateTrimReport()
	if not gameTrim then return "none yet (no plate measured)" end
	local names = {}
	for _, piece in ipairs(gameTrim) do
		local points = {}
		for _, each in ipairs(piece.points) do
			points[#points + 1] = ("%s>%s %+.1f,%+.1f"):format(each[1], each[2], each[3], each[4])
		end
		names[#names + 1] = ("%s at %s"):format(tostring(piece.atlas or piece.file), table.concat(points, " "))
	end
	return table.concat(names, ", ")
end

-- The game's art round bar (a preview's), copied off a real plate (made
-- once per bar): its textures, or nil while there's no plate to copy from.
function ns.GamePlateTrim(bar)
	if bar.cineGameTrim then return bar.cineGameTrim end
	local pieces = GameTrim()
	if not pieces then return nil end
	local made = {}
	for _, piece in ipairs(pieces) do
		local texture = bar:CreateTexture(nil, piece.layer or "BACKGROUND", nil, piece.sublevel or 0)
		if piece.atlas then
			texture:SetAtlas(piece.atlas)
		else
			texture:SetTexture(piece.file)
			if piece.coords[1] then pcall(texture.SetTexCoord, texture, unpack(piece.coords)) end
		end
		pcall(texture.SetVertexColor, texture, unpack(piece.color))
		pcall(texture.SetAlpha, texture, piece.alpha or 1)
		-- (Pinned as the game pins its own; one point: its size too.)
		for _, each in ipairs(piece.points) do
			texture:SetPoint(each[1], bar, each[2], each[3], each[4])
		end
		if #piece.points == 1 and piece.width and piece.height then texture:SetSize(piece.width, piece.height) end
		made[#made + 1] = texture
	end
	bar.cineGameTrim = made
	return made
end

-- A small pick under the plate: the Style Studio's button (2026-11-25: every
-- button looks like one), lit while on; the old pill where the Studio isn't loaded.
local function Pill(parent, text, onClick)
	local C = ns.Studio and ns.Studio.C
	if C and C.Button then
		local button = C.Button(parent, text)
		button:SetFrameLevel(parent:GetFrameLevel() + 10)
		button.zoomSkip = true -- (the preview's zoom leaves its buttons be)
		function button.SetOn(self, on) self:Paint(on and "on" or nil) end
		button:SetScript("OnClick", onClick)
		return button
	end
	local pill = CreateFrame("Button", nil, parent)
	pill:SetFrameLevel(parent:GetFrameLevel() + 10)
	pill.zoomSkip = true -- (the preview's zoom leaves its buttons be)
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

-- (holder.kind: the row it dresses, changed by Nameplate Style's page as a
-- row is picked; holder.hoverTheme: a plate theme pointed at, not saved;
-- holder.gameScale, gameShift, gameLift: the game plate bigger (moved left, its
-- bottom this high), that page's.)
function ns.MakePlateRowLookPreview(parent, width, startKind)
	local L = ns.L
	local holder = CreateFrame("Frame", nil, parent)
	holder.kind = startKind
	-- (Its own picks, from the last preview's: 2026-11-25, one page's picks no longer
	-- reach another's preview.)
	holder.states = {}
	for key, on in pairs(statesNow) do holder.states[key] = on end
	holder.sample = sampleNow
	holder:SetSize(width, 112)
	if holder.SetClipsChildren then holder:SetClipsChildren(true) end
	-- (Its plate sized here (1.6): not grown to fill the preview, only its zoom's - and +.)
	holder.noAutoFit = true
	local dark = holder:CreateTexture(nil, "BACKGROUND", nil, -7)
	dark:SetAllPoints()
	dark:SetColorTexture(0.04, 0.04, 0.05, 1)

	local plate = CreateFrame("Frame", nil, holder)
	plate:SetSize(160, 34)
	plate:SetPoint("CENTER", holder, "CENTER", 0, 13) -- (up a little: the cast bar under it)
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
	-- (As the page's own preview draws a plate, 2026-11-16: its cast bar under
	-- the bar, as the nameplates' Cast Style has it (casting again and again),
	-- and the row's mark over it.)
	local cast = ns.MakePlateCastSample and ns.MakePlateCastSample(plate)
	if cast then
		cast:SetPoint("TOP", health, "BOTTOM", 0, -3)
		cast:SetScale(0.75)
		cast:SetWidth(health:GetWidth() / 0.75) -- (as wide as the plate's bar, under its scale)
	end
	-- (The game's own plate, PlateCopy.lua, where it can be built: dressed by
	-- the code that dresses real plates. Else the drawn plate above.)
	-- (Built the first time it's drawn with the game's options complete:
	-- ns.GamePlateReady. Till then, and if it fails, the drawn plate.)
	local game = ns.MakeGamePlate and ns.MakeGamePlate(holder)
	local mark = ns.MakeTargetArrow and ns.MakeTargetArrow(health, health)
	local gameMark -- (the row's mark on the game plate's bar, made with it)

	-- (The picks: what to show on the plate. Two dropdowns under it, Unit and
	-- State (the user, 2026-11-23: the two rows of pills were ugly to see);
	-- the pills only where the client has no dropdown template.)
	local function PickSample(i)
		sampleNow, holder.sample = i, i
		holder:Refresh()
	end
	-- (holder.onStates: its page drawn again instead, Nameplate Style's, which
	-- places the plate by what it shows.)
	local function StatesChanged()
		if holder.onStates then holder.onStates() else holder:Refresh() end
	end
	local function ToggleState(key)
		PickState(key, holder)
		StatesChanged()
	end
	holder.PickSample, holder.ToggleState = PickSample, ToggleState
	local ROW_H = 28
	local okUnit, unitDrop = ns.MenuDropdown(holder)
	if not (okUnit and unitDrop and unitDrop.SetupMenu) then unitDrop = nil end
	local stateDrop = unitDrop and game and ns.MakePlateStateDropdown(holder, 170, StatesChanged) or nil
	local picks = {}
	local sceneButton = Pill(holder, L["Scene"], function()
		if not ns.db then return end
		ns.db.stylePreviewBack = ns.db.stylePreviewBack ~= "scene" and "scene" or nil
		if ns.RecutStyleScene then ns.RecutStyleScene(holder) end
		holder:Refresh()
	end)
	-- (Sized to the room: one row with Scene at the usual width; a narrow one
	-- squeezes State, and past that Scene takes the row above (confirm run 8:
	-- at 300 wide State reached past the edge, at 480 Scene sat alone).)
	local unitW, stateW = 130, 170
	if stateDrop and unitW + 6 + stateW > width - 12 then
		unitW = 120
		stateW = math.max(120, width - 12 - unitW - 6)
	end
	local rowRight = 6
	if unitDrop then
		unitDrop.zoomSkip, unitDrop.searchSkip = true, true
		unitDrop:SetWidth(unitW)
		unitDrop:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 6, 6)
		unitDrop:SetupMenu(function(_, root)
			for i, sample in ipairs(SAMPLES) do
				root:CreateRadio(L[sample[1]], function() return holder.sample == i end, function() PickSample(i) end)
			end
		end)
		if unitDrop.SetSelectionText then
			unitDrop:SetSelectionText(function() return L["Unit: %s"]:format(L[SAMPLES[holder.sample][1]]) end)
		end
		ns.lowHealthKit.Tooltip(unitDrop, L["The kind of unit the plate is for."])
		rowRight = rowRight + unitW
		if stateDrop then
			stateDrop:SetWidth(stateW)
			stateDrop:SetPoint("LEFT", unitDrop, "RIGHT", 6, 0)
			rowRight = rowRight + 6 + stateW
		end
	else
		-- (No dropdown on this client: the unit pills, as before.)
		for i, sample in ipairs(SAMPLES) do
			local pill = Pill(holder, L[sample[1]], function() PickSample(i) end)
			if i == 1 then
				pill:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 6, 6)
			else
				pill:SetPoint("BOTTOMLEFT", picks[i - 1], "BOTTOMRIGHT", 4, 0)
			end
			rowRight = rowRight + pill:GetWidth() + 4
			picks[i] = pill
		end
	end
	-- (Scene: the backdrop every preview shares, stylePreviewBack, the painted
	-- scene or the dark panel; left of the zoom's - and +. A row of its own over
	-- the picks where they'd reach it: a narrow preview.)
	local sceneY = 6
	if rowRight + 8 > width - 90 - sceneButton:GetWidth() then sceneY = 6 + ROW_H end
	sceneButton:SetPoint("BOTTOMRIGHT", -90, sceneY + (unitDrop and 5 or 0))
	ns.lowHealthKit.Tooltip(sceneButton, L["The lake behind the plate, or plain dark."])
	-- (Where the plate's bottom sits: over the picks. Combat Text Style places
	-- the plate itself by it.)
	holder.plateLift = sceneY + (unitDrop and ROW_H or 20) + 4
	if game then
		-- (Room over its debuffs, which reach past the plate's frame (89 of 85):
		-- they touched the top, the user 2026-11-23.)
		holder:SetHeight(holder.plateLift + 89 + 18)
		game:SetPoint("BOTTOM", holder, "BOTTOM", 0, holder.plateLift)
	end
	holder.unitDropdown, holder.stateDropdown, holder.sceneButton = unitDrop, stateDrop, sceneButton

	-- (Over the scene's top right while a choice is only pointed at.)
	local tag = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	tag:SetPoint("TOPRIGHT", -8, -6)
	tag:SetText(L["Preview: not saved"])
	tag.searchSkip = true
	-- (The settings page's own parts, for a preview shown away from it: the
	-- welcome window's Combat Text demo hides them, CombatTextPage.lua.)
	holder.pagePieces = { tag, sceneButton }
	if unitDrop then holder.pagePieces[#holder.pagePieces + 1] = unitDrop end
	if stateDrop then holder.pagePieces[#holder.pagePieces + 1] = stateDrop end
	for _, pill in ipairs(picks) do holder.pagePieces[#holder.pagePieces + 1] = pill end

	-- over: a choice pointed at in the panel ({ key = value }), shown, not saved;
	-- note: the words over the scene for it (Preview: not saved).
	function holder.Refresh(self, over, note)
		local db = ns.db
		if not db then return end
		local kind = self.kind
		tag:SetShown(over ~= nil or self.hoverTheme ~= nil)
		tag:SetText(note or L["Preview: not saved"])
		for i, pill in ipairs(picks) do pill:SetOn(i == self.sample) end
		sceneButton:SetOn(db.stylePreviewBack == "scene")
		-- (The shared backdrop, the lake or the dark panel: StyleScene draws either.)
		ns.StyleScene(self, 0.55, 0.85)
		self.styleScene:Show()
		dark:Hide()
		plate:SetScale(1.6)

		local sample = SAMPLES[self.sample] or SAMPLES[1]
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
		-- (The row's color, where it paints the bar or the name.)
		local paint = ns.TargetMarkOwn and ns.TargetMarkOwn("PlateColor", kind) == "custom"
		local color = paint and { ns.TargetMarkOwn("PlateR", kind) or 1, ns.TargetMarkOwn("PlateG", kind) or 1,
			ns.TargetMarkOwn("PlateB", kind) or 1 }
		local paintBar = color and ns.TargetMarkOwn("ColorBar", kind) and color or nil
		local paintName = color and ns.TargetMarkOwn("ColorName", kind) and color or nil
		if paintBar then barColor = paintBar end
		if paintName then nameColor = paintName end

		-- The game's own plate: the unit and states with the game's calls, then
		-- dressed by the plates' own code (PlateHealthStyle's bar, this file's
		-- name, PlateCastStyle's cast bar). The font before the text (else
		-- other alphabets show boxes).
		local live = game and ns.GamePlateReady(game)
		plate:SetShown(not live)
		if game then game:SetShown(live and true or false) end
		-- (The plate a page draws over, the one shown: the copy not built,
		-- the drawn one. Fix card Tools/audits/2026-11-23-ct-preview-plate.md.)
		self.plate = live and game or plate
		if stateDrop then stateDrop:SetShown(live and true or false) end
		-- (Their shown words again: a pick changed them.)
		for _, drop in ipairs({ unitDrop, stateDrop }) do
			if drop and drop.GenerateMenu then pcall(drop.GenerateMenu, drop) end
		end
		if gameMark then gameMark:SetShown(false) end
		if live then
			if not gameMark and ns.MakeTargetArrow then
				local bar = game.UnitFrame.HealthBarsContainer.healthBar
				gameMark = ns.MakeTargetArrow(bar, bar)
			end
			pcall(NameLook, game.UnitFrame.name, look)
			ns.SetGamePlateUnit(game, sample[1]:lower(), unitName, paintBar, paintName)
			ns.SetGamePlateLevel(game, look.level ~= false)
			ns.SetGamePlateStates(game, StatesOf(self))
			if ns.StylePlateBar then ns.StylePlateBar(game, look, self.hoverTheme) end
			if self.gameScale then
				game:SetScale(self.gameScale)
				game:ClearAllPoints()
				game:SetPoint("BOTTOM", self, "BOTTOM", -(self.gameShift or 0), (self.gameLift or self.plateLift) / self.gameScale)
			end
			if gameMark and ns.StyleTargetArrow and ns.TargetMarkSetting then
				ns.StyleTargetArrow(gameMark, nil, kind)
				gameMark:SetShown((ns.TargetMarkSetting("Show", kind) and ns.TargetMarkSetting("Style", kind) ~= "none") and true or false)
				gameMark:SetAlpha(ns.TargetMarkSetting("Opacity", kind) or 1)
			end
			return
		end

		-- Its fill: the row's texture, else the plate theme's (General's while
		-- it follows it), else the game's.
		local themeTexture, themeEdge, themeSize, themeR, themeG, themeB = ns.PlateThemeBar()
		local texture = look.texture
		if texture == nil then texture = themeTexture or "game" end
		if texture == "game" or not ns.SetBarTexture(health, texture, true) then
			-- (Retail's plate fill. Forever has the atlas but not retail's plates:
			-- the game's plain fill there, 2026-11-17.)
			health:SetStatusBarTexture(ns.isRetail and HasAtlas(PLATE_FILL) and PLATE_FILL
				or "Interface\\TargetingFrame\\UI-StatusBar")
			local fill = health:GetStatusBarTexture()
			if fill and fill.SetDesaturated then fill:SetDesaturated(false) end
		end
		health:SetStatusBarColor(barColor[1], barColor[2], barColor[3])
		-- (Its gradient: from its color to the one it fades to.)
		-- (Else flat, set on the fill itself: the bar's color set again the
		-- same doesn't clear a gradient drawn before.)
		local fill = health:GetStatusBarTexture()
		if look.gradient and fill and fill.SetGradient and CreateColor then
			pcall(fill.SetGradient, fill, "HORIZONTAL", CreateColor(barColor[1], barColor[2], barColor[3], 1),
				CreateColor(look.gradient[1], look.gradient[2], look.gradient[3], 1))
		elseif fill then
			fill:SetVertexColor(barColor[1], barColor[2], barColor[3], 1)
		end
		-- (A full-color fill in its own colors, the bar's color on a strip, as real plates.)
		if ns.DressPlateFullColor then
			ns.DressPlateFullColor(health, not look.gradient and ns.StyleTextureFull(texture), barColor[1], barColor[2],
				barColor[3])
		end
		if ns.DressThemeVeil then ns.DressThemeVeil(health, "plate") end
		-- Its border: the row's, else the plate theme's (the game's: its ground).
		local edgeKind, size, r, g, b
		if look.border then
			edgeKind, size, r, g, b = unpack(look.border)
		else
			edgeKind, size, r, g, b = themeEdge, themeSize, themeR, themeG, themeB
		end
		local game = edgeKind == "game"
		-- (The game's: its art copied off a real plate, as it sits round the bar;
		-- with none on the screen yet, its dark ground.)
		local trim = game and ns.GamePlateTrim(health)
		for _, piece in ipairs(health.cineGameTrim or {}) do piece:SetShown(game) end
		ground:SetShown(game and not trim)
		if game and not trim then
			-- (Retail's ground. On Forever its rounded silver frame and pale middle
			-- showed round a square fill, 2026-11-17: a dark ground there.)
			if ns.isRetail and HasAtlas(PLATE_GROUND) then
				ground:SetAtlas(PLATE_GROUND)
			else
				ground:SetColorTexture(0, 0, 0, 0.7)
			end
		end
		back:SetShown(not game)
		border:SetShown(edgeKind == "line")
		if edgeKind == "line" then ns.DressStyleEdges(border, size, r, g, b, 1, true) end
		-- (A plate theme's ground and bar shape, as the plates have them.)
		local shape, themeGround
		if ns.PlateThemeExtras then shape, themeGround = ns.PlateThemeExtras() end
		if themeGround and not game then
			back:SetColorTexture(themeGround[1], themeGround[2], themeGround[3], themeGround[4] or 0.7)
		else
			back:SetColorTexture(0, 0, 0, 0.6)
		end
		if ns.DressBarShape then ns.DressBarShape(health, back, not shape, nil, nil, shape) end

		-- Its name, as the plates draw it: the row's font, size, outline and
		-- shadow, else the Default row's, else Name Style's All names (outline
		-- and shadow), else the game's. (The font set before the text: else
		-- other alphabets show boxes.)
		local file, height, flags = own[1], own[2], own[3]
		if file and height then
			if ROMAN and look.font then file = look.font end
			local outline = look.outline
			if outline and outline >= 0 and ns.OutlinedFlags then flags = ns.OutlinedFlags(flags, outline) end
			name:SetFont(file, height * (look.size or 1), flags or "")
		end
		name:SetText(unitName)
		local shadow = look.shadow
		if shadow == "on" then
			local at = look.shadowAt
			name:SetShadowOffset(at and at[1] or 1, at and at[2] or -1)
			name:SetShadowColor(0, 0, 0, at and at[3] or 1)
		elseif shadow == "none" then
			name:SetShadowOffset(0, 0)
		else
			name:SetShadowOffset(ownX or 0, ownY or 0)
		end
		name:SetTextColor(nameColor[1], nameColor[2], nameColor[3])

		-- Its level box (Forever's): shown unless the row hides it.
		levelBox:SetShown(not ns.isRetail and look.level ~= false)
		levelText:SetText(level and level > 0 and tostring(level) or "??")
		-- Its cast bar (the nameplates' look) and the row's mark, as on the plates.
		if cast and cast.Refresh then cast:Refresh() end
		if mark and ns.StyleTargetArrow and ns.TargetMarkSetting then
			ns.StyleTargetArrow(mark, nil, kind)
			mark:SetShown((ns.TargetMarkSetting("Show", kind) and ns.TargetMarkSetting("Style", kind) ~= "none") and true or false)
			mark:SetAlpha(ns.TargetMarkSetting("Opacity", kind) or 1)
		end
	end
	holder:SetScript("OnShow", function(self) self:Refresh() end)
	-- (For a page drawing over the plate, Combat Text Style's numbers: the
	-- plate, and the unit picked under it, "Hostile", "Friendly"...)
	-- (holder.plate: the one shown, set again by each Refresh; drawnPlate and
	-- gamePlate each, for a page placing both.)
	holder.plate = game or plate
	holder.gamePlate, holder.drawnPlate = game, plate
	function holder.SampleKind() return (SAMPLES[holder.sample] or SAMPLES[1])[1] end
	return holder
end

-- Nameplate Style's preview fitted (2026-11-25): the layout put on its game plate
-- when the Layout page is on (it never was: what you saw wasn't your plates), its
-- debuffs kept over its name by their measured places (they sat on the name, the
-- in-game shot that day), then sized and placed by what it measures from cast bar to
-- its highest part, not by fixed numbers. holder: MakePlateRowLookPreview's; width,
-- height: its room; lift: where its plate's bottom may start. Leaves
-- holder.previewLayout (the layout it put on) and holder.debuffLift.
local LAYOUT_KIND = { Hostile = "hostile", Neutral = "neutral", Friendly = "friendly", Player = "player" }
local FIT_PARTS = { "name", "HealthBarsContainer", "AurasFrame.DebuffListFrame", "AurasFrame.BuffListFrame",
	"AurasFrame.CrowdControlListFrame", "CastBarsContainer.castBar", "PlayerLevelDiffFrame", "RaidTargetFrame",
	"ClassificationFrame", "SoftTargetFrame.Icon" }
local LISTS = { ["AurasFrame.DebuffListFrame"] = true, ["AurasFrame.BuffListFrame"] = true,
	["AurasFrame.CrowdControlListFrame"] = true }
local function Path(root, path)
	local value = root
	for name in path:gmatch("[^.]+") do value = type(value) == "table" and value[name] or nil end
	return value
end
local function Up(frame)
	local ok, shown = pcall(frame.IsVisible, frame)
	return ok and shown
end
local function HasIcon(frame)
	local ok, kids = pcall(function() return { frame:GetChildren() } end)
	for _, kid in ipairs(ok and kids or {}) do if Up(kid) then return true end end
	return false
end
-- A part's bottom and top in plate units over the plate's bottom (nil: can't be measured).
local function Span(holder, frame)
	local game = holder.gamePlate
	local ok, b, t, eff, gb, ge = pcall(function()
		return frame:GetBottom(), frame:GetTop(), frame:GetEffectiveScale(), game:GetBottom(), game:GetEffectiveScale()
	end)
	if not (ok and type(b) == "number" and type(t) == "number" and type(gb) == "number" and eff and ge and ge > 0) then return nil end
	return (b * eff - gb * ge) / ge, (t * eff - gb * ge) / ge
end
ns.PlatePreviewSpan = Span -- (the tests read it)
function ns.PlatePreviewFit(holder, width, height, lift)
	local game = holder.gamePlate
	local copy = game and game.gameCopy
	local room = height - lift
	-- (A first draw at the size that fits its debuffs, to measure.)
	local scale = math.max(0.6, math.min(1.6, (room - 8) / 89.1, (width - 12) / 360))
	holder.gameShift, holder.gameScale, holder.gameLift = nil, scale, lift
	holder:Refresh()
	if not copy then return end
	-- The layout, when the Layout page is on (Forever): the sample unit's kind's.
	local layout = false
	if not ns.isRetail and ns.StyleOn and ns.StyleOn("plateLayout") and ns.PlateLayoutFor then
		layout = ns.PlateLayoutFor(LAYOUT_KIND[holder.SampleKind()] or "hostile") or false
	end
	if ns.PlateLayoutApply then ns.PlateLayoutApply(game, layout) end
	-- Debuffs where the game hangs them (on the name) kept over it: lifted by what overlaps.
	holder.debuffLift = 0
	local debuffs = Path(copy, "AurasFrame.DebuffListFrame")
	local own = layout and ns.PlateLayoutPart and ns.PlateLayoutPart(layout, "debuffs")
	local moved = own and (own.to or (own.x or 0) ~= 0 or (own.y or 0) ~= 0)
	if debuffs and Up(debuffs) and HasIcon(debuffs) and not moved then
		local _, nameTop = Span(holder, copy.name)
		local debuffBottom = Span(holder, debuffs)
		if nameTop and debuffBottom and debuffBottom < nameTop + 1 then
			holder.debuffLift = math.ceil(nameTop + 1 - debuffBottom)
			local stacked = { center = layout and layout.center, cx = layout and layout.cx, cy = layout and layout.cy, parts = {} }
			for key, p in pairs(layout and layout.parts or {}) do
				local each = {}
				for k, v in pairs(p) do each[k] = v end
				stacked.parts[key] = each
			end
			stacked.parts.debuffs = stacked.parts.debuffs or {}
			stacked.parts.debuffs.y = (stacked.parts.debuffs.y or 0) + holder.debuffLift
			layout = stacked
			if ns.PlateLayoutApply then ns.PlateLayoutApply(game, layout) end
		end
	end
	holder.previewLayout = layout
	-- Sized and placed by what shows: cast bar to its highest part.
	local low, high
	for _, path in ipairs(FIT_PARTS) do
		local frame = Path(copy, path)
		if frame and Up(frame) and (not LISTS[path] or HasIcon(frame)) then
			local b, t = Span(holder, frame)
			if b and t and t > b then low, high = math.min(low or b, b), math.max(high or t, t) end
		end
	end
	if not (low and high and high - low > 4) then return end
	-- (Steady as debuffs come and go: never sized for less than the plate with its debuffs.)
	local tall = math.max(high - low, 89.1)
	scale = math.max(0.6, math.min(1.6, (room - 8) / tall, (width - 12) / 360))
	holder.gameScale = scale
	holder.gameLift = lift + (room - (high - low) * scale) / 2 - low * scale
	holder:Refresh()
	if ns.PlateLayoutApply then ns.PlateLayoutApply(game, layout) end
end

-- What a row's usual gives for one Look setting (the Look panel's Inherit
-- tiles and buttons): its name and value. A row's usual is the Default row's;
-- the Default row's: for the bar, General's; for the name's outline and
-- shadow, Name Style's All names; else the game's.
local BORDER_WORDS = { game = "The game's", none = "None", thin = "Thin", thick = "Thick", custom = "Custom" }
local OUTLINE_WORDS = { [0] = "None", "Thin", "Thick" }
local SHADOW_WORDS = { game = "The game's", on = "Shadow", none = "None" }
function ns.PlateRowUsual(kind, key)
	local L = ns.L
	local db = ns.db or {}
	local on = db.styleGeneral
	local value = kind ~= "others" and Own(key, "others") or nil
	-- (Under the rows: the plate theme's bar, General's while it follows it.)
	local plateTheme = on and ns.PlateThemeNow and ns.PlateThemeNow()
	if key == "LookTexture" then
		if value == nil then value = plateTheme and plateTheme.texture or on and db.styleTexture or "game" end
		return value == "game" and L["The game's"] or (ns.StyleTextureName and ns.StyleTextureName(value) or value),
			value
	elseif key == "LookFont" then
		-- (General's font doesn't reach full plates' names: the game's.)
		if value == nil then value = "game" end
		return value == "game" and L["The game's"] or ns.StyleFontName(value), value
	elseif key == "LookBorder" then
		if value == nil then value = plateTheme and plateTheme.border or on and db.styleBorder or "game" end
		return L[BORDER_WORDS[value] or "The game's"], value
	elseif key == "LookOutline" then
		if value == nil then value = AllNames(key) end
		if value == nil then return L["The game's"], -1 end
		return L[OUTLINE_WORDS[value] or "None"], value
	elseif key == "LookShadow" then
		if value == nil then value = AllNames(key) or "game" end
		return L[SHADOW_WORDS[value] or "The game's"], value
	elseif key == "LookGradient" then
		if value == nil then value = "off" end
		return value == "on" and L["On"] or L["Off"], value
	elseif key == "LookLevel" then
		if value == nil then value = "show" end
		return value == "hide" and L["Hidden"] or L["Shown"], value
	end
end

-- Where a row's Look setting comes from (the Look panel's tags): { text =
-- This row, Default row's, General's (Set by theme: <name> while it's what
-- the theme wrote), Name Style's or The game's; own = the row's own; parent =
-- what it'd inherit, short = that in a word, for the Inherit tile }.
local function Below(key)
	local L = ns.L
	local db = ns.db or {}
	if key == "LookTexture" or key == "LookBorder" then
		-- (A plate theme picked on the page: its own. PlateThemes.lua.)
		local plateTheme = db.styleGeneral and ns.PlateThemeNow and ns.PlateThemeNow()
		if plateTheme then return L["Plate theme: %s"]:format(L[plateTheme.name]), L["theme"] end
		local general = key == "LookTexture" and "styleTexture" or "styleBorder"
		local value = db.styleGeneral and db[general]
		if value ~= nil and value ~= false and value ~= "game" then
			local theme = ns.ActiveStyleTheme and ns.ActiveStyleTheme()
			local themed = theme and theme.key ~= "game" and ns.ThemeSetting and ns.ThemeSetting(general)
			if themed ~= nil and themed == value then return L["Set by theme: %s"]:format(L[theme.name]), L["theme"] end
			return L["General's"], L["General"]
		end
	elseif AllNames(key) ~= nil then
		return L["Name Style's"], L["Name Style"]
	end
	return L["The game's"], nil
end
function ns.PlateRowSource(kind, key)
	local L = ns.L
	local parent, short
	if kind ~= "others" and Own(key, "others") ~= nil then
		parent, short = L["Default row's"], L["Default row"]
	else
		parent, short = Below(key)
	end
	local own = Own(key, kind) ~= nil
	return { text = own and L["This row"] or parent, own = own, parent = parent, short = short }
end
end) -- (ns.Module "style")
