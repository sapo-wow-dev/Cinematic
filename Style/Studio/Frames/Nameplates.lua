-- Style Studio frames: Nameplates (Tools/style-studio/plan.md section 7).
--   "plates": the Nameplate Style page (its Default tab's editor). Variants: Default
--     (the Default row, "others") first, then each Smart row on the grid, in its order;
--     each property is that row's own Look setting (PlateRowLook.lua's keys, as its
--     drawer's Look panel had them), "default" (Usual) following the Default row.
--   "platelayout": the Nameplate Layout page (Forever). Variants: the Layout for
--     choices (All plates, then each kind); each part's Place, as the parts panel had
--     it, in db.plateLayoutData (fields). The page's stage stays its drag/guides stage.
-- (Tests, shown and notes take the variant they're drawn for: fn(db, variant).)
local _, ns = ...
ns.Module("style", function()
local L = ns.L
local Studio = ns.Studio
local R = Studio.R

local FIRST = "others"
local function Note(v) return v or FIRST end
local function MarkKey(kind, key) return kind == "target" and "targetArrow" .. key or kind .. "Mark" .. key end
local function DB() return ns.GetDB and ns.GetDB() or ns.db end

-- A row's own Look setting as a field (the drawer's Look panel's FieldOf): nil saved
-- while it's the Default row's; its Color<part> ticks and PlateR/G/B as the row has them.
local fields = {}
local function LookField(kind, key)
	local id = kind .. "|" .. key
	if fields[id] then return fields[id] end
	local part = key:match("^Color(%u%l+)$")
	local dbKey = part and (kind .. key) or MarkKey(kind, key)
	local base = ns.MarkRowBase and ns.MarkRowBase(kind) or kind
	local default
	if part then
		default = ns.DEFAULTS[base .. key] and true or false
	elseif key == "PlateR" or key == "PlateG" or key == "PlateB" then
		default = 1
	else
		default = ns.PLATE_LOOK_DEFAULTS and ns.PLATE_LOOK_DEFAULTS[key]
	end
	local field = { default = default, dbKey = dbKey }
	function field.get()
		local db = DB()
		if not db then return default end
		if part then return ns.TargetMarkOwn(key, kind) and true or false end
		if key == "PlateR" or key == "PlateG" or key == "PlateB" then return ns.TargetMarkOwn(key, kind) or 1 end
		local value = db[dbKey]
		if value == nil then return default end
		return value
	end
	function field.set(value)
		local db = DB()
		if not db then return end
		local LD = ns.PLATE_LOOK_DEFAULTS or {}
		if not part and LD[key] ~= nil and value == LD[key] then value = nil end
		db[dbKey] = value
	end
	fields[id] = field
	return field
end
local function Look(key) return function(v) return LookField(Note(v), key) end end
-- A row's plain setting: its db key while DEFAULTS has it, else a field with the
-- default its kind's would have (a row added on the page: Core's MarkRowDefault).
local function RowKey(kind, key)
	local dbKey = MarkKey(kind, key)
	if ns.DEFAULTS[dbKey] ~= nil then return dbKey end
	local id = kind .. "|row|" .. key
	if not fields[id] then
		local default = ns.MarkRowDefault and ns.MarkRowDefault(dbKey)
		fields[id] = { default = default, get = function()
			local db = DB()
			local value = db and db[dbKey]
			if value == nil then return default end
			return value
		end, set = function(value) local db = DB() if db then db[dbKey] = value end end }
	end
	return fields[id]
end
-- A setting every plate shares: its key on Default; on a row, shown as it is
-- (greyed: set on Default), never counted as the row's own.
local mirrors = {}
local function Global(key)
	return function(v)
		v = Note(v)
		if v == FIRST then return key end
		mirrors[key] = mirrors[key] or { mirror = true, get = function() local db = DB() return db and db[key] end,
			set = function() end }
		return mirrors[key]
	end
end
local function MirrorDefault(key)
	if type(key) == "table" then return key.get() end
	return ns.DEFAULTS[key]
end
-- (A row's own look counts whatever its Plate color since 2026-11-25: every setting
-- follows Default till it's set, PlateRowLook.lua's Own. No "while Custom" test here.)
local function LookValue(v, key) return LookField(Note(v), key).get() end
local function Targeted(_, v)
	v = Note(v)
	local base = ns.MarkRowBase and ns.MarkRowBase(v)
	return v ~= FIRST and (base == "target" or base == "aggro")
end
-- A row's Plate color (its drawer's Plate line): an aggro row's Your target's is its
-- AlsoSame; a color with no part ticked gets Bar ticked, so it shows.
local function PlateColorField(kind)
	local id = kind .. "|platecolor"
	if fields[id] then return fields[id] end
	local plateKey, sameKey = MarkKey(kind, "PlateColor"), MarkKey(kind, "AlsoSame")
	local function Aggro() return ns.MarkRowBase(kind) == "aggro" end
	local made = { default = ns.DEFAULTS[plateKey] or (ns.MarkRowDefault and ns.MarkRowDefault(plateKey)) or "-" }
	function made.get()
		if not DB() then return made.default end
		if Aggro() and ns.TargetMarkOwn("AlsoSame", kind) then return "target" end
		return ns.TargetMarkOwn("PlateColor", kind) or "-"
	end
	function made.set(value)
		local db = DB()
		if not db then return end
		if Aggro() then db[sameKey] = value == "target" elseif value == "target" then value = "same" end
		if value ~= "target" then db[plateKey] = value end
		if value ~= "-" and value ~= "game" then
			local base, any = ns.MarkRowBase(kind), false
			for _, part in ipairs({ "Name", "Bar", "Border" }) do
				if (part ~= "Border" or base == "target" or base == "aggro") and ns.TargetMarkOwn("Color" .. part, kind) then any = true end
			end
			if not any then db[kind .. "ColorBar"] = true end
		end
	end
	fields[id] = made
	return made
end

local USUAL = L["Usual"]

-- A color of the variant being edited: a swatch on its row's r, g, b fields (picking
-- one may set another of its fields, setKey, to setTo).
local function ColorSwatch(label, keys, tip, setKey, setTo, test)
	return R.Swatch(label, function(v)
		v = Note(v)
		return { LookField(v, keys[1]), LookField(v, keys[2]), LookField(v, keys[3]) }
	end, { tip = tip, test = test, setKey = setKey and Look(setKey) or nil, setTo = setTo })
end

-- The rows on the grid as variants: Default first, then the grid's order. (Made
-- again as the Studio draws: rows come and go on the Smart tab.)
local VARIANTS = { { id = FIRST, label = L["Default"] } }
local function RowLabel(id)
	if ns.PlateRowLabel then
		local ok, label = pcall(ns.PlateRowLabel, id)
		if ok and label then return label end
	end
	return id
end
function ns.PlateStudioVariants()
	local order = {}
	if ns.TargetMarkOrder and DB() then
		local ok, list = pcall(ns.TargetMarkOrder)
		if ok and type(list) == "table" then order = list end
	end
	for i = #VARIANTS, 2, -1 do VARIANTS[i] = nil end
	for _, id in ipairs(order) do
		if id ~= FIRST then VARIANTS[#VARIANTS + 1] = { id = id, label = RowLabel(id) } end
	end
	return VARIANTS
end

-- The page's preview's game plate (the Nameplate Style one, or the Studio's own).
local function CopyOf(p)
	local inner = p and (p.lookPreview or p)
	local game = inner and inner.gamePlate
	return game and game.IsShown and game:IsShown() and game.gameCopy or nil
end
local function Region(path)
	return function(p)
		local copy = CopyOf(p)
		local value = copy
		for name in path:gmatch("[^.]+") do value = type(value) == "table" and value[name] or nil end
		return value
	end
end

-- The theme tiles: Follow main theme, the game's, then every plate theme.
local function ThemeTiles()
	local list = { { value = "main", text = L["Follow main theme"] } }
	local rest = {}
	for _, theme in ipairs(ns.PlateThemeList and ns.PlateThemeList() or {}) do
		local entry = { value = theme.key, text = L[theme.name] or theme.name }
		if theme.texture and theme.texture ~= "game" and ns.StyleTexturePath then
			local path, atlas = ns.StyleTexturePath(theme.texture)
			entry.texture, entry.atlas = path, atlas
		end
		if theme.key == "game" then table.insert(list, 2, entry) else rest[#rest + 1] = entry end
	end
	for _, each in ipairs(rest) do list[#list + 1] = each end
	return list
end

-- (The first choice of a row's list: "Default's" on a Smart row (it follows Default), the
-- theme's on Default itself: the mock 2026-11-25.)
local function Usual(first, options, v)
	local word = Note(v) == FIRST and L["Theme's"] or L["Default's"]
	local list = { { value = first.value ~= nil and first.value or first[1], text = word } }
	for _, each in ipairs(options) do list[#list + 1] = each end
	return list
end
local function OnlyDefault(_, v) return Note(v) == FIRST end
local function OnlyRow(_, v) return Note(v) ~= FIRST end

-- Default's colors, one line per kind of unit (Class only for players), and each one's
-- Fade: PlateParts' KindColour, Core's plateKindColor_/plateKindFade_ (the mock, 2026-11-25).
local PLATE_KINDS = { { "enemyPlayers", "Enemy players", true }, { "friendlyPlayers", "Friendly players", true },
	{ "hostileNpcs", "Hostile NPCs" }, { "neutralNpcs", "Neutral NPCs" }, { "friendlyNpcs", "Friendly NPCs" },
	{ "tapped", "Not your kill" } }
local GAME_KIND = { enemyPlayers = { 0.8, 0.16, 0.12 }, friendlyPlayers = { 0.18, 0.44, 0.84 }, hostileNpcs = { 0.8, 0.16, 0.12 },
	neutralNpcs = { 0.9, 0.78, 0.1 }, friendlyNpcs = { 0.18, 0.71, 0.18 }, tapped = { 0.54, 0.54, 0.54 } }
local function KindColorProp(kind, label, players)
	local key = "plateKindColor_" .. kind
	return R.Color(key, L[label], function()
		local list = { { value = "game", text = L["The game's"], color = GAME_KIND[kind] } }
		if players then list[#list + 1] = { value = "class", text = L["Class"], sub = L["Each player's class color"] } end
		list[#list + 1] = { value = "theme", text = L["Theme's accent"] }
		list[#list + 1] = { value = "custom", text = L["My own"], sub = L["From the palette"] }
		return list
	end, { key .. "R", key .. "G", key .. "B" }, "custom", { shown = OnlyDefault,
		tip = L["This kind of unit's plate color, under every Smart row."] })
end
local function KindFadeProp(kind, label)
	local key = "plateKindFade_" .. kind
	return R.Color(key, L[label], {
		{ value = "none", text = L["None"], sub = L["One color all along the bar"] },
		{ value = "darker", text = L["Darker"], sub = L["Fades to a darker shade of its color"] },
		{ value = "lighter", text = L["Lighter"], sub = L["Fades to a lighter shade of its color"] },
		{ value = "custom", text = L["Into a color"], sub = L["Fades into a color from the palette"] } },
		{ key .. "R", key .. "G", key .. "B" }, "custom", { shown = OnlyDefault,
		tip = L["How this kind's bar color runs along it, left to right."] })
end
local defaultColors, defaultFades = {}, {}
for _, each in ipairs(PLATE_KINDS) do
	defaultColors[#defaultColors + 1] = KindColorProp(each[1], each[2], each[3])
	defaultFades[#defaultFades + 1] = KindFadeProp(each[1], each[2])
end
local function Group(recipe, label, tip, ...)
	local g = R.Group(recipe, ...)
	g.label, g.tip = label, tip
	return g
end

-- A Smart row's mark (Options.lua's MARK_STYLES; the drawer's Mark line before the mock):
-- its style, color, size, opacity and movement. Rows only.
local function MarkStyles(v)
	v = Note(v)
	local base = ns.MarkRowBase and ns.MarkRowBase(v)
	local list = { { "none", L["None"] } }
	if base == "aggro" then list[#list + 1] = { "same", L["Your target's"] } end
	for _, each in ipairs({ { "arrow", "Arrow" }, { "chevron", "Chevron" }, { "diamond", "Diamond" }, { "glow", "Glow" },
		{ "brackets", "Brackets" }, { "carets", "Carets" }, { "corners", "Corners" }, { "underline", "Underline" } }) do
		-- (The unit under the mouse: just the marks over its plate.)
		if base ~= "mouseover" or each[1] == "arrow" or each[1] == "chevron" or each[1] == "diamond" then
			list[#list + 1] = { each[1], L[each[2]] }
		end
	end
	return list
end
-- (A row's plain setting's value now: its db key's or its default's.)
local function LookValueRow(v, key)
	local k = RowKey(Note(v), key)
	if type(k) == "table" then return k.get() end
	local db = DB()
	local value = db and db[k]
	if value == nil then value = ns.DEFAULTS[k] end
	return value
end
local function MarkShown(_, v) local s = LookValueRow(v, "Style") return s ~= nil and s ~= "none" end
local markPart = { id = "mark", label = L["Mark"], shown = function(v) return Note(v) ~= FIRST end, groups = {
	Group("Look", "Mark", nil,
		R.Choice(function(v) return RowKey(Note(v), "Style") end, L["Mark"], MarkStyles, { tip = L["The row's mark over the plate."] }),
		R.Color(function(v) return RowKey(Note(v), "Color") end, L["Color"], {
			{ value = "gold", text = L["Gold"], color = { 0.91, 0.72, 0.29 } },
			{ value = "reaction", text = L["By reaction"], sub = L["Red, yellow or green by how the unit sees you"] },
			{ value = "class", text = L["Class colors"], sub = L["Players in their class color; NPCs by reaction"] },
			{ value = "custom", text = L["My own"], sub = L["From the palette"] } },
			function(v) v = Note(v) return { RowKey(v, "R"), RowKey(v, "G"), RowKey(v, "B") } end, "custom",
			{ shown = MarkShown, tip = L["The mark's color."] }),
		R.Slider(function(v) return RowKey(Note(v), "Size") end, L["Size"], 50, 200, 5, "%", { scale = 100, shown = MarkShown,
			tip = L["The mark's size."] }),
		R.Slider(function(v) return RowKey(Note(v), "Opacity") end, L["Opacity"], 10, 100, 5, "%", { scale = 100,
			shown = MarkShown, tip = L["The mark's own opacity (the plate's is on the Bar tab)."] }),
		R.Switch(function(v) return RowKey(Note(v), "Bob") end, L["Moving"], { shown = MarkShown,
			tip = L["Makes the mark move or pulse."] })),
} }

local plateParts = {
	markPart,
	{ id = "bar", label = L["Bar"], region = Region("HealthBarsContainer"), groups = {
		Group("Look", "Theme", L["Texture and border in one pick. Change either below on its own."],
			{ kind = "tiles", label = L["Theme"], key = Global("plateTheme"), options = function()
					local list = ThemeTiles()
					for _, each in ipairs(list) do
						each.tint = each.tint or { 0.85, 0.15, 0.12 } -- (a bar's red, as the plates)
						-- ("Follow main theme": its name says which, the mock's "Main theme (Gilded Codex)")
						if each.value == "main" then
							local main = ns.ActiveStyleTheme and ns.ActiveStyleTheme()
							each.short = main and main.name and L["Main theme (%s)"]:format(L[main.name]) or each.text
						end
					end
					return list
				end,
				default = MirrorDefault, shown = OnlyDefault,
				tip = L["The plates' bar, its texture and border, in one pick. Set on Default."] },
			R.Note(function()
				local theme = ns.PlateThemeNow and ns.PlateThemeNow()
				return theme and L["%s is picked here, so it stays when the main theme changes."]:format(L[theme.name])
					or L["The bars follow the main theme's texture and border."]
			end, { shown = OnlyDefault })),
		-- (A row: when it applies (a tooltip on its heading) and its rule.)
		Group("Look", "When", nil,
			R.Note(function(_, v)
				v = Note(v)
				local db = DB() or {}
				local key = v .. "When"
				local rule = type(db.frameRules) == "table" and db.frameRules[key]
				local name = RowLabel(v)
				if v == FIRST then name = L["Default"] end
				if type(rule) == "string" and rule:find("%S") then return L["%s applies when: %s"]:format(name, rule) end
				if db[key] ~= false then return L["%s applies always."]:format(name) end
				return L["%s applies as its When column on the Smart tab says."]:format(name)
			end, { shown = OnlyRow }),
			R.Button(L["Edit rule"], function(host)
				if ns.PlateRowEditRule then ns.PlateRowEditRule(host and host.variant or FIRST) end
			end, { shown = OnlyRow, tip = L["Opens the rule editor on when this row applies."] })),
		Group("Bar", "Bar", nil,
			{ kind = "tiles", label = L["Texture"], key = Look("LookTexture"), inherit = "default",
				tip = L["The health bar's fill."],
				options = function(v)
					local list = Usual({ value = "default", text = USUAL }, ns.StyleTextureChoices and
						ns.StyleTextureChoices(L["The game's"], "LookTexture") or {}, v)
					for _, each in ipairs(list) do each.tint = each.tint or { 0.85, 0.15, 0.12 } end
					return list
				end },
			R.Choice(Look("LookBorder"), L["Border"], function(v)
				return Usual({ "default", USUAL }, { { "game", L["The game's"] }, { "none", L["None"] },
					{ "thin", L["Thin"] }, { "thick", L["Thick"] }, { "custom", L["My own"] } }, v)
			end, { inherit = "default", tip = L["The health bar's border."] }),
			R.Slider(Look("LookBorderSize"), L["Border size"], 1, 10, 1, "px", { inherit = 1,
				shown = function(_, v) return LookValue(v, "LookBorder") == "custom" end,
				tip = L["How thick the border is, in pixels."] }),
			(function()
				local p = ColorSwatch(L["Border color"], { "LookBorderR", "LookBorderG", "LookBorderB" },
					L["The border's color, from the palette."], "LookBorder", "custom")
				p.shown = function(_, v) return LookValue(v, "LookBorder") == "custom" end
				return p
			end)(),
			R.Choice(Look("LookLevel"), L["Level box"], function(v)
				return Usual({ "default", USUAL }, { { "show", L["Shown"] }, { "hide", L["Hidden"] } }, v)
			end, { inherit = "default", shown = function(_, v) return not ns.isRetail and OnlyRow(nil, v) end,
				tip = L["Whether this row's plates show their level box. Every plate's is on the Layout tab."] })),
		-- (Groups are sorted by recipe (Editor.lua): "Place" keeps Size after Bar.)
		Group("Place", "Size", L["Next to the game's plate."],
			R.Slider(function(v) v = Note(v) return v == FIRST and "plateStyleWidth" or RowKey(v, "PlateWidth") end,
				L["Width"], 25, 300, 5, "%", { scale = 100, shown = function() return (ns.plateSizes or {}).width and true or false end,
					tip = L["The health bar's width: every plate's on Default, times that on a row's plates."] }),
			R.Slider(function(v) v = Note(v) return v == FIRST and "plateStyleHeight" or RowKey(v, "PlateHeight") end,
				L["Height"], 50, 300, 5, "%", { scale = 100, shown = function() return (ns.plateSizes or {}).height and true or false end,
					tip = L["The health bar's height: every plate's on Default, times that on a row's plates."] }),
			R.Slider(function(v) return RowKey(Note(v), "Alpha") end, L["Opacity"], 0, 100, 5, "%", { scale = 100,
				shown = OnlyRow, tip = L["The plate's opacity while this row fits it."] })),
	} },
	{ id = "colors", label = L["Colors"], groups = {
		-- (Default: a line per kind of unit, then each one's Fade.)
		Group("Look", "Colors", L["Each kind of unit's plate color, under every Smart row. Class is for players only."],
			unpack(defaultColors)),
		Group("Bar", "Fade", L["How each kind's bar color runs along it, left to right."], unpack(defaultFades)),
		-- (A row: what color it gives its plates, which parts take it, and its Fade.)
		Group("Look", "Plate color", nil,
			R.Color(function(v) return PlateColorField(Note(v)) end, L["Plate color"], function(v)
				local list = { { "-", L["Don't change"], sub = L["The plate keeps the color the rows below give it"] },
					{ "game", L["The game's"], sub = L["The game's own colors, whatever the rows below say"] },
					{ "default", L["Default's colors"], sub = L["By kind of unit, from Default's Colors"] },
					{ "same", L["Mark's color"], sub = L["The same color as this row's mark"] } }
				local now = Note(v) ~= FIRST and PlateColorField(Note(v)).get()
				if ns.MarkRowBase and v and ns.MarkRowBase(Note(v)) == "aggro" then list[#list + 1] = { "target", L["Your target's"] } end
				list[#list + 1] = { "gold", L["Gold"], color = { 0.91, 0.72, 0.29 } }
				list[#list + 1] = { "custom", L["One color"], sub = L["From the palette"] }
				-- (Kept while a row still has them: before 2026-11-25 rows picked these.)
				if now == "reaction" then list[#list + 1] = { "reaction", L["By reaction"] } end
				if now == "class" then list[#list + 1] = { "class", L["Class colors"] } end
				return list
			end, function(v) v = Note(v) return { LookField(v, "PlateR"), LookField(v, "PlateG"), LookField(v, "PlateB") } end,
				"custom", { inherit = "-", shown = OnlyRow, tip = L["Which color this row gives its plates."] }),
			R.Switch(Look("ColorBar"), L["Bar in it"], { shown = OnlyRow, tip = L["The health bar in the row's plate color."] }),
			R.Switch(Look("ColorName"), L["Name in it"], { shown = OnlyRow, tip = L["The name in the row's plate color."] }),
			R.Switch(Look("ColorBorder"), L["Border in it"], { shown = function(db, v) return Targeted(db, v) end,
				tip = L["The border the game puts round your target's health bar, in the row's plate color."] })),
		Group("Bar", "Fade", nil,
			R.Color(Look("LookGradient"), L["Fade"], function(v)
				return Usual({ value = "default", text = USUAL }, {
					{ value = "off", text = L["None"], sub = L["One color all along the bar"] },
					{ value = "darker", text = L["Darker"], sub = L["Fades to a darker shade of its color"] },
					{ value = "lighter", text = L["Lighter"], sub = L["Fades to a lighter shade of its color"] },
					{ value = "on", text = L["Into a color"], sub = L["Fades into a color from the palette"] } }, v)
			end, function(v) v = Note(v) return { LookField(v, "LookGradR"), LookField(v, "LookGradG"), LookField(v, "LookGradB") } end,
				"on", { inherit = "default", shown = OnlyRow, tip = L["How this row's bar color runs along it, left to right."] })),
	} },
	{ id = "name", label = L["Name"], region = Region("name"), groups = {
		Group("Text", "Text", nil,
			{ kind = "tiles", label = L["Font"], key = Look("LookFont"), inherit = "default",
				tip = L["The name's font."],
				options = function(v)
					return Usual({ value = "default", text = USUAL }, ns.StyleFontChoices and ns.StyleFontChoices() or {}, v)
				end },
			R.Slider(Look("LookTextSize"), L["Size"], 50, 200, 5, "%", { scale = 100, inherit = 1,
				tip = L["The name's size, next to its usual size."] }),
			R.Choice(Look("LookOutline"), L["Outline"], function(v)
				return Usual({ -1, USUAL }, { { 0, L["None"] }, { 1, L["Thin"] }, { 2, L["Thick"] } }, v)
			end, { inherit = -1, tip = L["A dark line around the name's letters."] }),
			R.Choice(Look("LookShadow"), L["Shadow"], function(v)
				return Usual({ "default", USUAL }, { { "game", L["The game's"] }, { "on", L["On"] }, { "none", L["None"] } }, v)
			end, { inherit = "default", tip = L["A dark shadow behind the letters, down and to the right."] })),
		-- ("Border" sorts after Text: the name's Color under its letters.)
		Group("Border", "Color", L["Same as the bar: each name takes its unit's color from Colors."],
			R.Color("plateNameColor", L["Color"], {
				{ value = "game", text = L["The game's"], sub = L["As the game draws it"] },
				{ value = "same", text = L["Same as the bar"], sub = L["Each name in its unit's color from Colors"] },
				{ value = "custom", text = L["My own"], sub = L["From the palette"] } },
				{ "plateNameColorR", "plateNameColorG", "plateNameColorB" }, "custom", { shown = OnlyDefault })),
	} },
}

ns.StyleFrame("plates", {
	label = L["Nameplates"], band = "Interface", sub = "Nameplates", subRank = 1, switch = "handlePlateStyle",
	pickers = true, -- (the mock's grammar: pickers, tabs, tooltips, Undo/Redo as words: Studio.lua)
	pages = { ["Nameplate Style"] = FIRST },
	variants = VARIANTS,
	refresh = function()
		if ns.PlateLooksChanged then ns.PlateLooksChanged() end
		if ns.RefreshTargetArrows then ns.RefreshTargetArrows() end
		if ns.RefreshPlateHealthStyle then ns.RefreshPlateHealthStyle() end
		if ns.RefreshPlateStylePage then ns.RefreshPlateStylePage() end
	end,
	-- (The Studio's stage: the Look panel's previewer, dressed as the variant shown.)
	preview = function(parent, width)
		local holder = ns.MakePlateRowLookPreview(parent, width, FIRST)
		local refresh = holder.Refresh
		holder.Refresh = function(self, ...)
			local win = ns.StyleStudioWindow and ns.StyleStudioWindow()
			self.kind = win and win.host and win.host.f == Studio.frames.plates and win.host.variant or FIRST
			return refresh(self, ...)
		end
		return holder
	end,
	status = function()
		ns.PlateStudioVariants() -- (the grid's rows now)
		return nil
	end,
	parts = plateParts,
})

-- Nameplate Layout ---------------------------------------------------------------------
local FOR = {
	{ id = "all", label = L["All plates"] }, { id = "hostile", label = L["Hostile"] }, { id = "neutral", label = L["Neutral"] },
	{ id = "friendly", label = L["Friendly NPCs"] }, { id = "player", label = L["Players"] },
}
-- The layout a kind's fields read (its own when ticked, else All plates') and write
-- (made, a kind's from a copy of All plates': the page's Editing).
local function Copy(value)
	if type(value) ~= "table" then return value end
	local made = {}
	for key, each in pairs(value) do made[key] = Copy(each) end
	return made
end
local function OwnFromAll(layout)
	if not layout or layout.own then return end
	for key in pairs(layout) do layout[key] = nil end
	for key, each in pairs(Copy(ns.PlateLayoutGet("all")) or {}) do layout[key] = each end
	if type(layout.parts) ~= "table" then layout.parts = {} end
	layout.own, layout.started = true, true
end
function ns.PlateLayoutEditing(kind, create)
	local layout = ns.PlateLayoutGet(kind, create)
	if create and layout and kind ~= "all" then OwnFromAll(layout) end
	return layout
end
function ns.PlateLayoutShown(kind)
	if kind ~= "all" then
		local own = ns.PlateLayoutGet(kind)
		if own and own.own then return own end
	end
	return ns.PlateLayoutGet("all")
end
local function LNote(v) return v or "all" end
local layoutFields = {}
-- A part's field (part nil: the layout's own, its center's).
local function LayoutField(kind, partKey, field, default)
	local id = kind .. "|" .. tostring(partKey) .. "|" .. field
	if layoutFields[id] then return layoutFields[id] end
	local made = { default = default }
	function made.get()
		local layout = ns.PlateLayoutShown(kind)
		local p = partKey and ns.PlateLayoutPart(layout, partKey) or layout
		local value = p and p[field]
		if value == nil then return default end
		return value
	end
	function made.set(value)
		if not DB() then return end
		local layout = ns.PlateLayoutEditing(kind, true)
		local p = partKey and ns.PlateLayoutPart(layout, partKey, true) or layout
		if value == default then value = nil end
		p[field] = value
	end
	layoutFields[id] = made
	return made
end
-- A change the page made itself (a drag, an arrow key) as one Undo step: the part's
-- fields put back as before, then written through the Studio.
local RECORD_DEFAULT = { x = 0, y = 0 }
function ns.PlateLayoutRecord(kind, partKey, before)
	local f = Studio.frames.platelayout
	if not (f and partKey) then return end
	local writes = {}
	for field, default in pairs(RECORD_DEFAULT) do
		local made = LayoutField(kind or "all", partKey, field, default)
		local now = made.get()
		local was = before[field]
		if was == nil then was = default end
		if now ~= was then
			made.set(was)
			writes[#writes + 1] = { made, now }
		end
	end
	if #writes > 0 then
		local label = partKey
		for _, part in ipairs(ns.PLATE_LAYOUT_PARTS or {}) do if part.key == partKey then label = L[part.label] end end
		Studio.Apply(f, L["Nameplate Layout"] .. " · " .. label .. " · " .. L["Moved"], writes)
	end
end
local function LField(partKey, field, default)
	return function(v) return LayoutField(LNote(v), partKey, field, default) end
end
local function Hung(partKey)
	return function(_, v)
		local p = ns.PlateLayoutPart(ns.PlateLayoutShown(LNote(v)), partKey)
		return p and p.to and true or false
	end
end
local function CustomCenter(_, v)
	local layout = ns.PlateLayoutShown(LNote(v))
	return layout and layout.center == "custom"
end
local COUNT_DEFAULT = function(key) return (ns.PLATE_LAYOUT_DEFAULT_COUNT or {})[key] or "always" end
local function LayoutPlate()
	local page = ns.plateLayoutPage
	return page and page.holder and page.holder.gamePlate
end

local layoutParts = {
	{ id = "plate", label = L["Plate"], groups = {
		R.Group("Place",
			R.Choice(LField(nil, "center", "bar"), L["Center"], { { "bar", L["Bar (the game's)"], L["The plate sits as the game puts it."] },
				{ "balanced", L["Balanced"], L["Moved so what's shown is centered on its unit."] },
				{ "custom", L["Custom"], L["Moved by your own amount."] } }, {
				tip = L["Where the plate sits on its unit."] }),
			R.Slider(LField(nil, "cx", 0), L["Left/right"], -250, 250, 1, "px", { test = CustomCenter,
				tip = L["Moves the whole plate left or right."] }),
			R.Slider(LField(nil, "cy", 0), L["Down/up"], -150, 150, 1, "px", { test = CustomCenter,
				tip = L["Moves the whole plate down or up."] })),
	} },
}
-- (Whether each part shows: the Style parts' Shown (styleOver_platePart*) moved here, the
-- user 2026-11-25: "we have a layout tab that should control all that".)
local SHOWN_ROW = { health = "platePartHealth", name = "platePartName", level = "platePartLevel",
	debuffs = "platePartDebuffs", buffs = "platePartBuffs", marker = "platePartRaidMarker",
	elite = "platePartClassification", cast = "platePartCastBar" }
for _, part in ipairs(ns.PLATE_LAYOUT_PARTS or {}) do
	local key = part.key
	local props = {}
	if SHOWN_ROW[key] then props[1] = R.Shown(SHOWN_ROW[key]) end
	if part.hang then
		props[#props + 1] = R.Drop(LField(key, "to", "game"), L["Hang on"], function()
			local choices = { { "game", L["Where the game hangs it"] } }
			local plate = LayoutPlate()
			for _, other in ipairs(ns.PLATE_LAYOUT_PARTS) do
				if other.key ~= key and not (ns.PlateLayoutWouldLoop and plate and plate.gameCopy
					and ns.PlateLayoutWouldLoop(plate, key, other.key)) then
					choices[#choices + 1] = { other.key, L["On: %s"]:format(L[other.label]) }
				end
			end
			choices[#choices + 1] = { "plate", L["On: the plate's middle"] }
			return choices
		end, { tip = L["What this part hangs on. Moving that part moves this one with it."] })
		local sides = {}
		for _, side in ipairs(ns.PLATE_LAYOUT_SIDES) do sides[#sides + 1] = { side, L[ns.PLATE_LAYOUT_SIDE_INFO[side][5]] } end
		props[#props + 1] = R.Drop(LField(key, "side", "right"), L["Side"], sides, { test = Hung(key),
			tip = L["Which side of that part it sits on."] })
	end
	props[#props + 1] = R.Slider(LField(key, "x", 0), L["Left/right"], -250, 250, 1, "px",
		{ tip = L["Moves it left or right, in the plate's own units. The arrow keys over the plate do the same."] })
	props[#props + 1] = R.Slider(LField(key, "y", 0), L["Down/up"], -150, 150, 1, "px",
		{ tip = L["Moves it down or up, in the plate's own units."] })
	if part.scale then
		props[#props + 1] = R.Slider(LField(key, "scale", 1), L["Size"], 50, 200, 5, "%", { scale = 100,
			tip = L["How big it is, times the game's size."] })
	end
	if part.hang then
		props[#props + 1] = R.Slider(LField(key, "gap", 0), L["Gap"], -20, 40, 1, "px", { test = Hung(key),
			tip = L["How far it sits from the part it hangs on."] })
	end
	local counts = { { "always", L["Always counts"] } }
	if part.frame then counts[#counts + 1] = { "shown", L["Counts while shown"] } end
	counts[#counts + 1] = { "never", L["Doesn't count"] }
	props[#props + 1] = R.Choice(LField(key, "count", COUNT_DEFAULT(key)), L["Balance"], counts, {
		tip = L["Whether this part counts when Center is Balanced: always, only while it's up, or never."] })
	if key ~= "health" and key ~= "cast" then
		props[#props + 1] = R.Button(L["Mirror"], function(host)
			local kind = host and host.variant or "all"
			local f = Studio.frames.platelayout
			-- (One Undo step: its fields before and after.)
			local writes = {}
			local list = { "x", "side" }
			local before = {}
			for i, field in ipairs(list) do before[i] = LayoutField(kind, key, field, field == "side" and "right" or 0).get() end
			if ns.PlateLayoutMirror then ns.PlateLayoutMirror(ns.PlateLayoutEditing(kind, true), key, LayoutPlate()) end
			for i, field in ipairs(list) do
				local fieldT = LayoutField(kind, key, field, field == "side" and "right" or 0)
				local after = fieldT.get()
				fieldT.set(before[i])
				writes[#writes + 1] = { fieldT, after }
			end
			Studio.Apply(f, L["Mirror"] .. " · " .. L[part.label], writes)
		end, { tip = L["Puts it on the other side of the bar, as far out."] })
	end
	props[#props + 1] = R.Note(function()
		local what = ns.PlateLayoutHiddenBySettings and ns.PlateLayoutHiddenBySettings(key)
		return what and L["Your game's nameplate settings hide %s, so it won't show on your plates."]:format(L[what]) or ""
	end, { shown = function() return ns.PlateLayoutHiddenBySettings and ns.PlateLayoutHiddenBySettings(key) ~= nil or false end })
	local onCopy = Region(part.path)
	layoutParts[#layoutParts + 1] = { id = key, label = L[part.label],
		-- (Not on the page's stage: its own hits pick and drag there.)
		region = function(p) if p and p.layoutStage then return nil end return onCopy(p) end,
		groups = { R.Group("Place", unpack(props)) } }
end
-- (Smart's marks over the plate: their two raises, from the Smart tab's All marks line, the
-- user 2026-11-25 ("why not layout?"). Not a part of the game's plate: one place for every
-- kind of plate, whatever Layout for says.)
layoutParts[#layoutParts + 1] = { id = "smartMarks", label = L["Smart marks"], groups = {
	R.Group("Place",
		R.Note(L["Smart's marks over the plates. The same for every kind of plate."]),
		R.Slider("targetArrowY", L["Down/up with a plate"], -40, 40, 1, "px",
			{ tip = L["Moves the marks up or down while the plate shows."] }),
		R.Slider("targetArrowBareY", L["Down/up without a plate"], -40, 40, 1, "px",
			{ tip = L["Moves the marks up or down while the plate is hidden."] })),
} }

-- The presets as Looks: each one Undo step (the Studio counts the fields before and after).
local function Preset(which, label, tip)
	return { id = which, label = label, tip = tip, apply = function(variant)
		if ns.PlateLayoutPreset then ns.PlateLayoutPreset(ns.PlateLayoutEditing(variant or "all", true), which, LayoutPlate()) end
	end }
end

ns.StyleFrame("platelayout", {
	label = L["Nameplate Layout"], band = "Interface", sub = "Nameplates", subRank = 2, page = "Nameplate Layout",
	switch = "plateLayout", shown = function() return not ns.isRetail end,
	pickers = true, -- (the mock's grammar, as Nameplate Style's)
	variants = FOR,
	variantsLabel = L["Layout for"], -- (its variants dropdown's name)
	looks = {
		Preset("game", L["Game's"], L["Every part where the game puts it."]),
		Preset("balanced", L["Balanced"], L["The game's places, the plate centered on its unit."]),
		Preset("compact", L["Compact"], L["The level box and marker inside the bar, balanced."]),
		Preset("namein", L["Name in the bar"], L["The name inside the health bar."]),
	},
	refresh = function()
		if ns.PlateLayoutChanged then ns.PlateLayoutChanged() end
		if ns.RefreshTargetArrows then ns.RefreshTargetArrows() end -- (its Smart marks part)
		local page = ns.plateLayoutPage
		if page and page.Redraw then page.Redraw() end
		if page and page.Refresh then page.Refresh() end
	end,
	preview = function(parent, width)
		local holder = ns.MakePlateRowLookPreview(parent, width, FIRST)
		local refresh = holder.Refresh
		holder.Refresh = function(self, ...)
			refresh(self, ...)
			local win = ns.StyleStudioWindow and ns.StyleStudioWindow()
			local kind = win and win.host and win.host.variant or "all"
			if self.gamePlate and self.gamePlate.gameCopy and ns.PlateLayoutApply then
				ns.PlateLayoutApply(self.gamePlate, ns.PlateLayoutShown(type(kind) == "string" and kind or "all") or false)
			end
		end
		return holder
	end,
	parts = layoutParts,
})
end) -- (ns.Module "style")
