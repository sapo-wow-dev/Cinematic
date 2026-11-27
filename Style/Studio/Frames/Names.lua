-- Style Studio frames: Names (the Name Style page, Options.lua's CreateNameStylePanel)
-- and Chat bubbles (the Bubble Style page, Style/BubbleStyle.lua). Every look setting
-- each page had, by its db key (Tools/style-studio/plan.md section 8).
--
-- Names' variants are Name Style's rows (ns.NAME_ROWS: Default, then each kind), each
-- setting a field over nameLook<row><setting> (Default: plateName<setting>): it shows
-- the value the row has now (its own, else the row it goes by, the name theme's or
-- the game's), and picking the value it would go by anyway hands it back ("inherit",
-- D12 of the 2026-11-14 revamp). Plates/NameRowLook.lua reads them.
local _, ns = ...
ns.Module("style", function()
local L = ns.L
local Studio = ns.Studio
local R = Studio.R

-- (Shown, test, notes and color keys take the row they're drawn for: fn(db, variant),
-- rgb fn(variant). A row that doesn't have a setting gets a key that holds nothing.)
local function RowOf(v) return v or "all" end
-- (For the stage and the parts' regions, which aren't told the row: the one the host
-- showing Names is on.)
function ns.NameStageRow()
	return RowOf(ns.StudioHostVariant and ns.StudioHostVariant("names"))
end

-- A key that holds nothing (a row without this setting).
local NONE = { get = function() return nil end, set = function() end }
-- What a row's own value reads as for Reset: never equal to a real value.
local OWN = {}

-- What a row gets for a setting with none of its own: the row it goes by, else the
-- name theme's, else the game's.
local function Inherited(row, setting)
	if row == "all" then
		local themed = ns.NameThemeLook and ns.NameThemeLook()
		if themed and themed[setting] ~= nil then return themed[setting] end
		return ns.NAME_LOOK_GAME[setting]
	end
	return (ns.NameLookValue(ns.NAME_ROW_PARENT[row] or "all", setting))
end
local function RowDefault(row, key)
	if row == "all" then return ns.DEFAULTS[key] end
	return ns.NameRowDefault(key)
end
local function Save(row, setting, value)
	local key = ns.NameLookKey(row, setting)
	if value == RowDefault(row, key) then value = nil end
	ns.GetDB()[key] = value
end
-- (Its own letters picked for the second line: it starts as a copy of the name's,
-- so nothing changes till you change it. 2026-11-17.)
local LINE2_COPY = { Font = "Line2Font", Outline = "Line2Outline", OutlineColor = "Line2OutlineColor",
	Shadow = "Line2Shadow", ShadowAlpha = "Line2ShadowAlpha" }
local function CopyNameToLine2(row)
	for from, into in pairs(LINE2_COPY) do Save(row, into, (ns.NameLookValue(row, from))) end
	local r, g, b = ns.NameLookColor(row, "OutlineColor")
	Save(row, "Line2OutlineColorR", r)
	Save(row, "Line2OutlineColorG", g)
	Save(row, "Line2OutlineColorB", b)
end

local fields = {}
local function Field(row, setting)
	local id = row .. "|" .. setting
	if fields[id] then return fields[id] end
	local dbKey = ns.NameLookKey(row, setting)
	-- (Letters noHover, 2026-11-26: Its own copies the name's font, outline and shadow to the
	-- second line, which setting Match the name back leaves: pointing at it saved the copy.
	-- Tools/audits/2026-11-26-plate-hover.md.)
	local field = { dbKey = dbKey, noHover = setting == "Line2Match" or nil }
	function field.get() return (ns.NameLookValue(row, setting)) end
	function field.own()
		local db = ns.GetDB()
		local value = db and db[dbKey]
		return value ~= nil and value ~= "inherit"
	end
	function field.set(value)
		local db = ns.GetDB()
		if value == OWN or value == "inherit" or value == nil then db[dbKey] = nil return end
		if setting == "Line2Match" and value == false and ns.NameLookValue(row, "Line2Match") ~= false then
			CopyNameToLine2(row)
		end
		if value == Inherited(row, setting) then value = nil end
		db[dbKey] = value
	end
	fields[id] = field
	return field
end
-- A setting's default as the Studio asks it: a row's own value counts as yours.
local function NameDefault(key)
	if type(key) == "string" then return ns.DEFAULTS[key] end
	if type(key) == "table" then
		if key.own then return key.own() and OWN or key.get() end
		return key.default
	end
	return nil
end

-- Which rows have what (the old page's choices per row, 2026-11-16): each row's
-- colors (a row not here, every one: Default, Your target).
local NAME_COLOR_PARTS = {
	GroupMembers = { class = true, Friends = true }, Friends = { class = true, Friends = true },
	Enemies = { class = true, Enemies = true, Hostile = true },
	ServiceNPCs = { Friendly = true }, FriendlyNPCs = { Friendly = true },
	NeutralNPCs = { Neutral = true }, HostileNPCs = { Hostile = true },
	FriendlyMinions = { Friendly = true }, GroupMinions = { Friendly = true }, EnemyMinions = { Hostile = true },
}
for _, each in ipairs(ns.NAME_ROWS) do
	if each.service then NAME_COLOR_PARTS[each.key] = { Friendly = true } end
end
local function Parts(row) return NAME_COLOR_PARTS[row] end
local function NpcRow(row) local p = Parts(row) return p ~= nil and not p.Friends and not p.Enemies end
local function Service(row) return row == "all" or row == "ServiceNPCs" or row:find("^Service") ~= nil end
local function IsAll(row) return row == "all" end
local function Not(fn) return function(row) return not fn(row) end end

-- A name setting's key on a row (applies: the rows that have it).
local function NK(setting, applies)
	return function(v)
		local row = v or "all"
		if applies and not applies(row) then return NONE end
		return Field(row, setting)
	end
end
-- A page-wide key, on the Default row only.
local function AllOnly(key)
	return function(v) if (v or "all") == "all" then return key end return NONE end
end
-- Shown only on the rows that have it (no row asked: "any", shown).
local function On(applies)
	return function(_, v) if v == nil then return true end return applies(v) end
end
local function Value(v, setting) return ns.NameLookValue(RowOf(v), setting) end
-- (Value's one value only: tonumber's second argument would be read as a base.)
local function OutlineOn(prefix) return function(_, v) return (tonumber((Value(v, prefix .. "Outline"))) or 0) > 0 end end
local function Own2(_, v) return Value(v, "Line2Match") == false end
-- A color's three keys on the row drawn: Default's db keys; a kind's, fields over its
-- nameLook<row><base>R/G/B, starting as Core's row defaults (ns.NameRowDefault).
local colorFields = {}
local function ColorKey(row, key)
	if row == "all" then return key end
	if not colorFields[key] then
		local default = ns.NameRowDefault(key)
		colorFields[key] = { default = default,
			get = function() local db = ns.GetDB() local value = db and db[key] if value == nil then return default end return value end,
			set = function(value) local db = ns.GetDB() if not db then return end if value == default then value = nil end db[key] = value end }
	end
	return colorFields[key]
end
local function RowRgb(base)
	return function(v)
		local row = RowOf(v)
		local list = {}
		for i, part in ipairs({ "R", "G", "B" }) do list[i] = ColorKey(row, ns.NameLookKey(row, base .. part)) end
		return list
	end
end

-- A name setting's property: its key per row and default (a row's own value counts
-- as yours, NameDefault; Reset hands it back), and a color's keys.
local function N(prop, setting, applies, base)
	prop.key = NK(setting, applies)
	prop.default = NameDefault
	if applies then prop.shown = On(applies) end
	if base then prop.rgb = RowRgb(base) end
	return prop
end
-- A color with no choice of its own: picking one makes its setting the row's (on).
local function Swatch(label, base, setting, on, test, tip)
	return R.Swatch(label, RowRgb(base), { setKey = NK(setting), setTo = on, test = test, tip = tip })
end

-- Text: its font, size, opacity, outline and shadow (the name's, or the second line's own).
local USUAL = { "usual", L["General's or the game's"] }
local function OutlineProps(prefix, test)
	local colorBase = prefix == "" and "Outline" or "Line2OutlineColor"
	local outline = N(R.Outline(nil, { tip = L["A border around the letters."], test = test }), prefix .. "Outline")
	local color = N(R.Color(nil, L["Outline color"], { { "black", L["Black"] },
		{ "custom", L["Custom"], L["An outline in your own color; costs more with many names up."] } }, {}, "custom",
		{ test = function(db, v) return (not test or test(db, v)) and OutlineOn(prefix)(db, v) end }), prefix .. "OutlineColor", nil, colorBase)
	local shadow = N(R.Shadow(nil, { on = true, none = false, game = false, test = test,
		tip = L["A dark shadow behind the letters so they stand out."] }), prefix .. "Shadow")
	local strength = N(R.Slider(nil, L["Shadow strength"], 0, 100, 5, "%", { scale = 100, tip = L["How dark the shadow is."],
		test = function(db, v) return (not test or test(db, v)) and Value(v, prefix .. "Shadow") == true end }), prefix .. "ShadowAlpha")
	return outline, color, shadow, strength
end

-- The name theme: a whole look in one pick, under every row (NameThemes.lua).
local function ThemeOptions()
	local list = { { value = "main", text = L["Follow main theme"] } }
	for _, theme in ipairs(ns.NameThemeList and ns.NameThemeList() or {}) do
		local entry = { value = theme.key, text = L[theme.name], tip = theme.tip and L[theme.tip] or nil }
		if theme.key == "game" then table.insert(list, 2, entry) else list[#list + 1] = entry end
	end
	return list
end
local function ThemeNote()
	local db = ns.GetDB() or {}
	local theme = ns.NameThemeNow and ns.NameThemeNow()
	if (db.nameTheme or "main") == "main" then
		return theme and L["Following the main theme: %s's names."]:format(L[theme.name])
			or L["Following the main theme: the game's names."]
	end
	return L["%s, picked here, so it stays when the main theme changes."]:format(theme and L[theme.name] or "")
end

-- Color by: the colors each row's names can take (the Default row: no One color,
-- every kind of name in one color would undo the rows' own; an NPC row: its
-- reaction's color below is its one color).
local function ColorClass(row)
	if row == "all" then return "all" end
	if not Parts(row) then return "mixed" end
	if NpcRow(row) then return "npc" end
	return "players"
end
local SEE_YOU = { true, L["How they see you"], L["Red for hostile, yellow for neutral and green for friendly units."] }
local CLASS = { "class", L["Class"], L["Players in their class color, everyone else by their reaction to you."] }
local ONE = { "one", L["One color"] }
local PLATES = { false, L["The plate's"], L["The plate's own color, white or gray."] }
local function ColorBy(class, choices)
	local function Is(row) return ColorClass(row) == class end
	if class == "all" or class == "npc" then
		return N(R.Choice(nil, L["Color by"], choices), "Colour", Is)
	end
	return N(R.Color(nil, L["Color by"], choices, {}, "one"), "Colour", Is, "Colour")
end
local function Reacting(_, v)
	local mode = Value(v, "Colour")
	return mode ~= "one" and mode ~= false
end
local function Has(part) return function(row) local p = Parts(row) return row ~= "all" and (not p or p[part] == true) end end

-- How far names are: our own sizing on WoW Forever (PlateParts' Look), retail's
-- plates size themselves. The stage draws names near or far (ns.NameStageScale).
-- (A field Reset may hand OWN or nil to: its default then.)
local function Guarded(field)
	local set = field.set
	field.set = function(value)
		if value == OWN or value == nil then value = field.default end
		return set(value)
	end
	return field
end
local stageAt = "near"
local STAGE_AT = Guarded({ get = function() return stageAt end, set = function(value) stageAt = value end, default = "near" })
function ns.NameStageScale()
	if stageAt ~= "far" or ns.isRetail then return 1 end
	local db = ns.GetDB() or {}
	local ratio = tonumber(db.plateNameFarStep) or 1
	if db.plateNameSizeBy == "zoom" then
		local close, far = tonumber(db.plateNameCloseSize) or 1, tonumber(db.plateNameFarSize) or 1
		if close > 0 then ratio = ratio * far / close end
	end
	return math.max(0.15, ratio)
end
local function CameraNote()
	local zoom = math.floor((GetCameraZoom and GetCameraZoom() or 0) + 0.5)
	return L["The camera is %d yards from you: every name is sized as if its unit were about %d yards from it."]:format(zoom,
		zoom + 16)
end

-- The NPC titles' own settings (every row that shows them): Show as and the brackets' two ticks as one pick.
local SERVICE_ICONS = Guarded({
	get = function() return ns.GetDB().nameServiceIcons and true or false end,
	set = function(value) ns.GetDB().nameServiceIcons = value end,
	default = ns.DEFAULTS.nameServiceIcons and true or false,
})
local BRACKETS_DEFAULT = not ns.DEFAULTS.nameServiceBrackets and "never"
	or (ns.DEFAULTS.nameServiceBracketsWithName and "always" or "alone")
local SERVICE_BRACKETS = Guarded({
	get = function()
		local db = ns.GetDB()
		if not db.nameServiceBrackets then return "never" end
		return db.nameServiceBracketsWithName and "always" or "alone"
	end,
	set = function(value)
		local db = ns.GetDB()
		if value == BRACKETS_DEFAULT then -- (both ticks as they start)
			db.nameServiceBrackets, db.nameServiceBracketsWithName = ns.DEFAULTS.nameServiceBrackets,
				ns.DEFAULTS.nameServiceBracketsWithName
			return
		end
		db.nameServiceBrackets = value ~= "never"
		db.nameServiceBracketsWithName = value == "always"
	end,
	default = BRACKETS_DEFAULT,
})
local function ServiceKey(field) return function(v) if Service(v or "all") then return field end return NONE end end

local function Group(recipe, label, ...)
	local group = R.Group(recipe, ...)
	group.label = label
	return group
end
local function Spot(p) return p and p.SpotOf and p:SpotOf(ns.NameStageRow()) end

-- (Each row's label as shown now: NAME_ROWS' are translated once the language is known.)
local variants = {}
for _, row in ipairs(ns.NAME_ROWS) do
	local key = row.key
	variants[#variants + 1] = setmetatable({ id = key }, { __index = function(_, field)
		if field == "label" then return ns.NameRowLabel(key) or key end
	end })
end

local AROUND = { { "both", L["What shows"], L["Round whatever shows: the name, the line under it, or both."] },
	{ "name", L["Name only"], L["Round the name alone; hidden while only its title shows."] } }
local function GlowOn(_, v) return Value(v, "Glow") ~= "none" end
local function BandOn(_, v) return Value(v, "Back") ~= "none" end
local function BandEdged(db, v) return BandOn(db, v) and Value(v, "BackBorder") == "line" end

ns.StyleFrame("names", {
	label = L["Names"], band = "Interface", sub = "Nameplates", subRank = 2, page = "Name Style", switch = "plateNameStyle",
	refresh = function()
		if ns.NameRowsChanged then ns.NameRowsChanged() end
		if ns.RefreshPlateNameStyle then ns.RefreshPlateNameStyle() end
		-- (Default's outline and shadow reach full plates' names too: PlateRowLook.lua.)
		if ns.RefreshTargetArrows then ns.RefreshTargetArrows() end
		if ns.ServiceKindsChanged then ns.ServiceKindsChanged() end
		if ns.RefreshAllPlates then ns.RefreshAllPlates() end
		if ns.RefreshPlateGuilds then ns.RefreshPlateGuilds() end
		if ns.plates and ns.plates.FarStepChanged then ns.plates.FarStepChanged() end
	end,
	preview = function(parent, width) return ns.MakeNameStylePreview and ns.MakeNameStylePreview(parent, width) end,
	-- Where these names are now: the game's own names over heads can't be styled by addons.
	status = function()
		local cine = ns.lastCinematic and true or false
		if not cine then
			return L["You're not in CineMode, so names over heads are the game's own; the preview shows this page's look."], "warn"
		end
		if not (ns.PlatesForcedHere and ns.PlatesForcedHere(cine)) then
			return L["Names here are the game's own (in dungeons and raids, or with the Nameplates page off), which this page can't change."],
				"warn", L["Open"], function() ns.OpenOptions("Nameplates") end
		end
	end,
	variants = variants,
	parts = {
		{ id = "text", label = L["Text"], region = function(p) local s = Spot(p) return s and s.text end, groups = {
			Group("Look", "Name theme",
				{ kind = "tiles", label = L["Name theme"], key = AllOnly("nameTheme"), options = ThemeOptions, few = 4,
					shown = On(IsAll), tip = L["A whole look for every name in one pick."] },
				R.Note(ThemeNote, { shown = On(IsAll) })),
			R.Group("Text",
				N(R.Font(nil, { first = USUAL, tip = L["The names' font."] }), "Font"),
				-- (Up to 400%, 2026-11-16: a target's name can be made to stand out.)
				N(R.Slider(nil, L["Size"], 50, 400, 10, "%", { scale = 100, tip = L["How big the names are compared to the plates' own."] }), "Size"),
				N(R.Slider(nil, L["Opacity"], 20, 100, 5, "%", { scale = 100,
					tip = L["How see-through the names are, on top of their fades."] }), "Alpha"),
				OutlineProps("")),
		} },
		{ id = "color", label = L["Color"], groups = {
			R.Group("Text",
				ColorBy("all", { SEE_YOU, CLASS, PLATES }),
				ColorBy("mixed", { SEE_YOU, CLASS, ONE, PLATES }),
				ColorBy("players", { CLASS, ONE, PLATES }),
				ColorBy("npc", { PLATES }),
				N(R.Color(nil, L["Friendly players"], {
					{ "blue", L["Blue"], L["Blue, like the game's names over their heads."] },
					{ "class", L["Class colors"], L["Their class's color; also turns on the game's class colors for nameplates."] },
					{ "white", L["White"] }, { "custom", L["Custom"] } }, {}, "custom", { test = Reacting }), "Friends", Has("Friends"), "Friends"),
				N(R.Choice(nil, L["Enemy players"], { { "react", L["Hostile's color"] }, { "class", L["Class colors"] } },
					{ test = Reacting }), "Enemies", Has("Enemies")),
				N(R.Color(nil, L["Hostile"], { { "game", L["The game's"] }, { "custom", L["Custom"] } }, {}, "custom",
					{ tip = L["NPCs of this reaction in a color of your own."] }), "Hostile", Has("Hostile"), "Hostile"),
				N(R.Color(nil, L["Neutral"], { { "game", L["The game's"] }, { "custom", L["Custom"] } }, {}, "custom",
					{ tip = L["NPCs of this reaction in a color of your own."] }), "Neutral", Has("Neutral"), "Neutral"),
				N(R.Color(nil, L["Friendly"], { { "game", L["The game's"] }, { "custom", L["Custom"] } }, {}, "custom",
					{ tip = L["NPCs of this reaction in a color of your own."] }), "Friendly", Has("Friendly"), "Friendly")),
		} },
		{ id = "glow", label = L["Glow"], region = function(p) local s = Spot(p) return s and s.glow and s.glow:IsShown() and s.glow or nil end,
			groups = {
			Group("Look", "Glow",
				N(R.Choice(nil, L["Glow"], { { "none", L["Off"] }, { "soft", L["On"], L["A soft light behind the name."] } }), "Glow"),
				N(R.Choice(nil, L["Around"], AROUND, { test = GlowOn }), "GlowAround"),
				Swatch(L["Color"], "Glow", "Glow", "soft", GlowOn, L["The glow's color."]),
				-- (Past 100%: brighter, a second glow over the first. 2026-11-17.)
				N(R.Slider(nil, L["Strength"], 10, 150, 5, "%", { scale = 100, tip = L["How strong the glow is."], test = GlowOn }), "GlowAlpha"),
				N(R.Slider(nil, L["Size"], 50, 300, 10, "%", { scale = 100, tip = L["How far the glow spreads around the name."],
					test = GlowOn }), "GlowSize")),
		} },
		{ id = "band", label = L["Band"], region = function(p) local s = Spot(p) return s and s.back and s.back:IsShown() and s.back or nil end,
			groups = {
			Group("Background", "Band",
				N(R.Choice(nil, L["Band"], { { "none", L["Off"] }, { "band", L["On"], L["A band of color behind the name."] } }), "Back"),
				N(R.Choice(nil, L["Around"], AROUND, { test = BandOn }), "BackAround"),
				Swatch(L["Color"], "Back", "Back", "band", BandOn, L["The band's color."]),
				N(R.Slider(nil, L["Opacity"], 10, 100, 5, "%", { scale = 100, tip = L["How see-through the band is."], test = BandOn }), "BackAlpha")),
			-- (A border round the band, 2026-11-16: its color and size.)
			R.Group("Border",
				N(R.Choice(nil, L["Border"], { { "none", L["None"] }, { "line", L["Line"], L["A line around the band."] } },
					{ test = BandOn }), "BackBorder"),
				Swatch(L["Color"], "BackBorder", "BackBorder", "line", BandEdged, L["The band's border color."]),
				N(R.Slider(nil, L["Size"], 1, 4, 1, "px", { tip = L["How thick the band's border is, in pixels."], test = BandEdged }),
					"BackBorderSize")),
		} },
		{ id = "line2", label = L["Second line"], region = function(p) local s = Spot(p) return s and s.line end, groups = {
			-- (Its letters: the name's, or its own, starting as a copy of the name's. 2026-11-17.)
			R.Group("Text",
				N(R.Choice(nil, L["Letters"], {
					{ true, L["Match the name"], L["The name's font, outline and shadow. Size, opacity and color stay this line's own."] },
					{ false, L["Its own"], L["Its own font, outline and shadow, starting from the name's."] } }), "Line2Match"),
				N(R.Font(nil, { first = USUAL, tip = L["The second line's font."], test = Own2 }), "Line2Font"),
				N(R.Slider(nil, L["Size"], 50, 120, 5, "%", { scale = 100,
					tip = L["The guild or title under the name, sized compared to the name."] }), "Line2Size"),
				N(R.Slider(nil, L["Opacity"], 20, 100, 5, "%", { scale = 100, tip = L["How see-through the line under the name is."] }),
					"Line2Alpha"),
				N(R.Color(nil, L["Color"], { { "name", L["Name's"] }, { "grey", L["Gray"] }, { "gold", L["Gold"] },
					{ "custom", L["Custom"] } }, {}, "custom"), "Line2Color", nil, "Line2Color"),
				OutlineProps("Line2", Own2)),
		} },
		{ id = "titles", label = L["NPC titles"], groups = {
			R.Group("Text",
				R.Choice(ServiceKey(SERVICE_ICONS), L["Show as"], { { false, L["Text"] },
					{ true, L["Icon"], L["An icon in place of a service NPC's title (an anvil for repairs...)."] } },
					{ noReset = true, shown = On(Service) }),
				R.Slider(ServiceKey("nameServiceIconScale"), L["Icon size"], 50, 200, 5, "%", { scale = 100,
					tip = L["How big the title icons are."], shown = On(Service),
					test = function(db) return db.nameServiceIcons end }),
				R.Choice(ServiceKey(SERVICE_BRACKETS), L["Brackets"], { { "never", L["Never"] },
					{ "alone", L["Title alone"], L["Puts < > around a title shown without its NPC's name."] },
					{ "always", L["Always"], L["Puts < > around every title, including under the name."] } },
					{ noReset = true, shown = On(Service) }),
				R.Note(L["Titles are set on Default and the Service NPCs rows."], { shown = On(Not(Service)) })),
		} },
		-- (Shown again 2026-11-25, decision 3: hidden since 2026-11-16, still read by the plates.)
		{ id = "distance", label = L["Distance"], groups = {
			Group("Look", "Preview",
				R.Choice(STAGE_AT, L["Preview"], { { "near", L["Near"], L["Names close by, the camera zoomed in."] },
					{ "far", L["Far"], L["Names more than 28 yards away, the camera zoomed out."] } },
					{ free = true, client = "forever", shown = On(IsAll), tip = L["Shows the names near or far in the preview."] }),
				R.Note(L["Retail's plates size names by distance themselves."], { client = "retail", shown = On(IsAll) })),
			R.Group("Text",
				R.Choice(AllOnly("plateNameSizeBy"), L["Size by"], {
					{ "zoom", L["Zoom"], L["Names grow as you zoom in and shrink as you zoom out."] },
					{ "fixed", L["Fixed"], L["Names keep one size at any zoom."] } }, { client = "forever", shown = On(IsAll) }),
				R.Choice(AllOnly("plateNameFarStep"), L["Far names"], {
					{ 1, L["Same size"], L["Far names stay the size of near ones."] },
					{ 0.9, L["A bit smaller"], L["Names more than 28 yards from you get 10% smaller, in one step."] },
					{ 0.8, L["Smaller"], L["Names more than 28 yards from you get 20% smaller, in one step."] },
					{ 0.65, L["Much smaller"], L["Names more than 28 yards from you get 35% smaller, in one step."] } },
					{ client = "forever", shown = On(IsAll) }),
				R.Slider(AllOnly("plateNameCloseSize"), L["Close size"], 50, 300, 5, "%", { scale = 100, client = "forever",
					shown = On(IsAll), tip = L["How big names are with the camera zoomed all the way in."] }),
				R.Slider(AllOnly("plateNameFarSize"), L["Far size"], 20, 100, 5, "%", { scale = 100, client = "forever",
					shown = On(IsAll), tip = L["How big names are with the camera zoomed far out."] }),
				R.Switch(AllOnly("plateNameFixedSize"), L["Same size"], { client = "retail", shown = On(IsAll),
					tip = L["Names keep one size at any distance."] })),
			R.Group("Place",
				R.Slider(AllOnly("plateNameCloseY"), L["Close raise"], -60, 60, 1, "px", { client = "forever", shown = On(IsAll),
					tip = L["Moves names up or down with the camera zoomed all the way in."] }),
				R.Slider(AllOnly("plateNameFarY"), L["Far raise"], -60, 10, 1, "px", { client = "forever", shown = On(IsAll),
					tip = L["Moves names up or down with the camera zoomed far out."] }),
				R.Slider(AllOnly("plateNameY"), L["Raise"], -30, 30, 1, "px", { client = "retail", shown = On(IsAll),
					tip = L["Moves the names up (or down, below 0) from where the plates put them."] }),
				-- (Every unit counts as 16 yards from you: PlateParts' UNIT_YARDS.)
				R.Note(CameraNote, { client = "forever", shown = On(IsAll) })),
			R.Group("Motion",
				R.Slider(AllOnly("plateNameHideDelay"), L["Hide delay"], 0, 10, 0.1, "s", { shown = On(IsAll),
					tip = L["How long a unit stays out of sight before its name hides."] }),
				R.Slider(AllOnly("plateNameFadeTime"), L["Fade time"], 0, 5, 0.1, "s", { shown = On(IsAll),
					tip = L["How long a name takes to fade in or out."] }),
				R.Note(L["Distance settings are the same for every name: they're on Default."], { shown = On(Not(IsAll)) })),
		} },
	},
})

-- Chat bubbles -------------------------------------------------------------------------
local function Boxed(db) return db.bubblesBack ~= "none" end
local function Own(db) return db.bubblesBack == "dark" or db.bubblesBack == "custom" end
-- Speech from behind you shows only with the Chat pages' four switches on (Speech.lua).
local function Behind(db)
	return db.handleBubbles and not (ns.MasterOff and ns.MasterOff("handleBubbles", db)) and db.chatPeek and db.chatHideBubbled
		and db.chatSpeechBehind and true or false
end
ns.SpeechBehindOn = Behind
local function Tailed(db) return Behind(db) and db.bubblesBack ~= "none" and db.bubblesTail end

-- The outline: 0 none, 1 thin, 2 thick, 3 thick with a drop shadow (-1 General's):
-- read as Outline (Thick for 3) and Shadow (On for 3), each writing the one key.
local OUTLINE = {
	get = function() local v = ns.GetDB().bubblesOutline if v == 3 then return 2 end return v end,
	set = function(value)
		local db = ns.GetDB()
		if value == 2 and db.bubblesOutline == 3 then return end -- (Thick kept with its shadow)
		db.bubblesOutline = value
	end,
	default = ns.DEFAULTS.bubblesOutline,
}
local SHADOW = {
	get = function() return ns.GetDB().bubblesOutline == 3 and "on" or "game" end,
	set = function(value)
		local db = ns.GetDB()
		if value == "on" then db.bubblesOutline = 3 elseif db.bubblesOutline == 3 then db.bubblesOutline = 2 end
	end,
	default = "game",
}
local outlineProp = R.Outline("bubblesOutline", { tip = L["A black outline around the letters so they stand out."] })
outlineProp.key = Guarded(OUTLINE)
local shadowProp = R.Shadow(Guarded(SHADOW), { tip = L["A drop shadow behind the letters, with a thick outline."],
	test = function(db) return db.bubblesOutline == 2 or db.bubblesOutline == 3 end })
do -- (No None: without a thick outline it's the game's shadow.)
	local options = shadowProp.options
	shadowProp.options = function()
		local list = {}
		for _, o in ipairs(options()) do if o[1] ~= "none" then list[#list + 1] = o end end
		return list
	end
end

-- The Chat pages' switches speech from behind you needs, the first missing one's page.
local BEHIND_SWITCHES = {
	{ "handleBubbles", "Chat Bubbles", "Chat bubbles" },
	{ "chatPeek", "Show chat when a message arrives", "Chat" },
	{ "chatHideBubbled", "Hide speech you can see as a bubble", "Chat" },
	{ "chatSpeechBehind", "Show off-screen bubbles", "Chat bubbles" },
}

ns.StyleFrame("bubbles", {
	label = L["Chat bubbles"], band = "Interface", sub = "Info", subRank = 1, page = "Bubble Style", switch = "bubblesStyle",
	refresh = function() if ns.RefreshBubbleStyle then ns.RefreshBubbleStyle() end end,
	preview = function(parent, width) return ns.MakeBubblePreview(parent, width) end,
	status = function(db)
		if Behind(db) then return nil end
		local missing, page = {}, nil
		for _, each in ipairs(BEHIND_SWITCHES) do
			local off = not db[each[1]] or (each[1] == "handleBubbles" and ns.MasterOff and ns.MasterOff("handleBubbles", db))
			if off then
				missing[#missing + 1] = L[each[2]]
				page = page or each[3]
			end
		end
		return L["Speech from behind you shows once these are on: %s."]:format(table.concat(missing, ", ")), "warn",
			L["Open"], function() ns.OpenOptions(page) end
	end,
	parts = {
		{ id = "bubble", label = L["Bubble"], region = function(p) return p.say end, groups = {
			R.Group("Border", R.Border("bubblesEdge", { test = Own, tip = L["The outline around Dark or Custom bubbles."] })),
			R.Group("Background",
				R.Color("bubblesBack", L["Background"], {
					{ "game", L["The game's"], L["The game's own bubble."] },
					{ "dark", L["Dark"], L["A flat dark bubble."] },
					{ "custom", L["Custom"], L["A flat bubble in a color of your own."] },
					{ "none", L["None"], L["Just the words, with no bubble. An outline makes them easier to read."] },
				}, { "bubblesBackR", "bubblesBackG", "bubblesBackB" }, "custom"),
				R.Slider("bubblesAlpha", L["Opacity"], 20, 100, 5, "%", { scale = 100, tip = L["How see-through the bubble is."],
					test = Boxed })),
		} },
		{ id = "words", label = L["Words"], region = function(p) return p.say and p.say.text end, groups = {
			R.Group("Text",
				R.Font("bubblesFont", { tip = L["The font for bubble text."] }),
				R.Slider("bubblesTextScale", L["Size"], 50, 200, 5, "%", { scale = 100,
					tip = L["How big the words are, next to their usual size."] }),
				outlineProp,
				shadowProp),
		} },
		{ id = "tail", label = L["Tail"], region = function(p) return p.SayTail and p:SayTail() end, groups = {
			R.Group("Look",
				R.Switch("bubblesTail", L["Tail"], { tip = L["Shows the little point under the bubble, pointing at who's talking."],
					test = Boxed })),
		} },
		{ id = "behind", label = L["Behind bubbles"], region = function(p) return p.behind end, groups = {
			R.Group("Look",
				R.Button(L["Test"], function() ns.TestSpeechBehind() end, { test = Behind,
					tip = L["Shows a line of speech from behind you, from you, as it looks now."] }),
				R.Button(L["Move"], function() ns.MoveSpeechBehind() end, { test = Behind,
					tip = L["Shows a box where speech from behind you appears: drag it where you want the lines."] }),
				R.Switch("speechBehindName", L["Show who said it"], { tip = L["Starts each line with the speaker's name."], test = Behind }),
				R.Switch("speechBehindClassColor", L["In class color"], { tip = L["Shows players' names in their class color."],
					test = function(db) return Behind(db) and db.speechBehindName end })),
			R.Group("Text",
				R.Slider("speechBehindScale", L["Size"], 50, 100, 5, "%", { scale = 100, test = Behind,
					tip = L["How big speech from behind you is compared to a bubble overhead. Smaller makes it seem farther away."] }),
				R.Slider("speechBehindAlpha", L["Opacity"], 30, 100, 5, "%", { scale = 100, test = Behind,
					tip = L["How solid speech from behind you looks. Fainter makes it seem muffled and out of view."] }),
				R.Slider("speechBehindWidth", L["Max width"], 200, 1000, 20, "px", { test = Behind,
					tip = L["How wide a line gets before it wraps."] }),
				R.Choice("speechBehindAlign", L["Align"], { { "auto", L["By where it's moved to"] }, { "LEFT", L["Left"] },
					{ "CENTER", L["Center"] }, { "RIGHT", L["Right"] } }, { test = Behind,
					tip = L["How the lines line up: left, center or right."] })),
			R.Group("Place",
				R.Switch("speechBehindTailTop", L["Tail on top"], { tip = L["Puts the bubble's tail on top, pointing up."], test = Tailed }),
				R.Switch("speechBehindTailFlip", L["Flip the tail"], { tip = L["The tail curls the other way, as if seen in a mirror."],
					test = Tailed }),
				R.Slider("speechBehindTailPos", L["Tail position"], 0, 100, 5, "%", { scale = 100, test = Tailed,
					tip = L["Where the tail sits along the bubble, from left to right."] })),
			R.Group("Motion",
				R.Switch("speechBehindRise", L["Rise up from below the screen"], { tip = L["Lines slide up from the bottom of the screen."],
					test = Behind }),
				R.Switch("speechBehindSink", L["Sink as lines come in"], { tip = L["Older lines slide down as new ones come in."],
					test = Behind })),
		} },
	},
})

-- The pages' folder tabs' switches, kept (a tab is a container: off, every setting
-- on it reads off, ns.StyleLook / ns.MasterOff): each the first row of its parts,
-- their keys mastered under it as ns.TabContainer / MapTabContainers had them (the
-- editor's rows carry no settingKey for MapTabContainers to walk).
local function TabSwitch(frameId, partIds, tabKey, pageKey, label, tip, keys, shown)
	if ns.DEFAULTS[tabKey] == nil then ns.DEFAULTS[tabKey] = true end
	ns.SetPageMaster({ tabKey }, pageKey)
	local f = Studio.frames[frameId]
	local field = {
		get = function() local db = ns.GetDB() return db == nil or db[tabKey] ~= false end,
		set = function(value) ns.GetDB()[tabKey] = value and true or false end,
	}
	-- (Always "as it is" to Reset: a reset leaves switches be, as Reset page always has.)
	local switch = R.Switch(field, label, { tip = tip, noReset = true, shown = shown })
	local mastered, wanted, only = {}, {}, {}
	for _, id in ipairs(partIds) do wanted[id] = true end
	for _, key in ipairs(keys or {}) do only[key] = true end
	for _, part in ipairs(f.parts) do
		if wanted[part.id] then
			for _, group in ipairs(part.groups) do
				for _, prop in ipairs(group.props) do
					local key = Studio.KeyOf(prop, Studio.FirstVariant(f))
					-- (Greyed with the tab: what it holds; keys given, those alone.)
					if not keys or only[key] then
						local old = prop.test
						prop.test = function(db, v) return ns.PageOn(tabKey) and (not old or old(db, v)) end
					end
					if not keys then
						if type(key) == "string" then mastered[#mastered + 1] = key end
						for _, rk in ipairs(Studio.RGB(prop, Studio.FirstVariant(f)) or {}) do mastered[#mastered + 1] = rk end
					end
				end
			end
			if part.groups[1] and part.groups[1].recipe == "Look" then
				table.insert(part.groups[1].props, 1, switch)
			else
				table.insert(part.groups, 1, R.Group("Look", switch))
			end
		end
	end
	ns.SetPageMaster(keys or mastered, tabKey)
end
TabSwitch("bubbles", { "bubble", "words", "tail" }, "tabOn:Bubble Style/page:1", "bubblesStyle", L["Bubbles"],
	L["Turns the bubbles' look on or off: off, they look as the game draws them."], nil)
ns.SetPageMaster({ "bubblesOutline" }, "tabOn:Bubble Style/page:1") -- (its two rows' field)
TabSwitch("bubbles", { "behind" }, "tabOn:Bubble Style/page:2", "bubblesStyle", L["Behind Bubbles"],
	L["Turns the look of speech from behind you on or off."], nil)
-- (Name Style's Size tab, WoW Forever: Size by and Far names were on it. Its Look
-- tab held no setting of its own: its rows' popups, never mapped.)
if not ns.isRetail then
	TabSwitch("names", { "distance" }, "tabOn:Name Style/page:2", "plateNameStyle", L["Size"],
		L["Turns Size by and Far names on or off."], { "plateNameSizeBy", "plateNameFarStep" }, On(IsAll))
end
end) -- (ns.Module "style")
