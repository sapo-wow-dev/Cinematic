-- Style Studio frames: the Style hub's Interface > Combat band (Tools/style-studio/plan.md
-- section 7): Unit frames (Style/UnitStyle.lua), Cast bars (one frame for the three cast
-- pages, Style/PlateCastStyle.lua), Personal resources (Style/PersonalStyle.lua), Raid
-- frames (Style/RaidStyle.lua), Action bars (Style/ActionBarStyle.lua) and the Cooldown
-- Manager (Style/CdmStyle.lua). Every look setting those pages had, by its db key.
local _, ns = ...
ns.Module("style", function()
local L = ns.L
local Studio = ns.Studio
local R = Studio.R

-- Variants with copies of their own ------------------------------------------------
-- Unit, raid and cast frames keep a copy of each setting per variant (<key>_<ID>),
-- used while the variant has its own look. A property's key, test, shown and color keys
-- are functions of the variant (the model passes it). The preview, a part's region, the
-- status line and a choice's options aren't told it: they read the variant the host
-- showing this frame is on.
local pageHosts = {} -- [frame id] = { the pages' editor hosts }
local function HostVariant(fid)
	local f = Studio.frames[fid]
	local win = ns.StyleStudioWindow and ns.StyleStudioWindow()
	local host = win and win.host
	local winOn = host and f and host.f == f and win:IsShown()
	if winOn then
		local ok, over = pcall(win.IsMouseOver, win)
		if ok and over then return host.variant end
	end
	for _, h in ipairs(pageHosts[fid] or {}) do
		if h:IsVisible() then return h.variant end
	end
	if winOn then return host.variant end
	return f and Studio.FirstVariant(f)
end
local VariantNow = HostVariant
ns.StudioHostVariant = HostVariant -- (other frames' stages: Names.lua)
-- A page's editor host (its variant is the one it shows).
function ns.StudioPageHost(fid, host)
	local list = pageHosts[fid] or {}
	pageHosts[fid] = list
	list[#list + 1] = host
end
-- fn(db, variant): a test or shown by the variant the model passes (nil, "any": the
-- host's).
local function ByVariant(fid, fn)
	return function(db, v)
		if v == nil then v = HostVariant(fid) end
		return fn(db or ns.GetDB() or {}, v)
	end
end
-- A color property whose keys are the variant's: rgb = fn(variant) -> { r, g, b keys }.
local function VariantRgb(_, prop, rgbOf)
	prop.rgb = rgbOf
	return prop
end
-- A key maker for a frame: K(base) -> fn(variant) -> the variant's key.
local function Keyer(_, first, own)
	return function(base)
		return function(v)
			if v == nil or v == first then return base end
			return own(base, v)
		end
	end
end
-- (A variant with no such setting: a field that reads value and keeps nothing.)
local function Nothing(value)
	return { get = function() return value end, set = function() end, default = value }
end
-- A border by the variant: its kind, Custom's size and its color (R.Border's three).
local function VariantBorder(fid, kindKey, sizeKey, rgbOf, opts)
	local kind, size, color = R.Border(kindKey, opts)
	local test = opts.test
	size.key = sizeKey
	size.test = ByVariant(fid, function(db, v)
		return (not test or test(db, v)) and Studio.Get(kindKey(v)) == "custom"
	end)
	VariantRgb(fid, color, rgbOf)
	return kind, size, color
end
-- A color alone (a swatch) by the variant.
local function VariantSwatch(fid, label, rgbOf, opts)
	return VariantRgb(fid, R.Swatch(label, nil, opts), rgbOf)
end
local function RgbOf(K, stem)
	return function(v) return { K(stem .. "R")(v), K(stem .. "G")(v), K(stem .. "B")(v) } end
end
-- Outline saved as words ("general", "game", "none", "thin", "thick"): R.Outline's
-- General's entry under its saved word.
local function WordOutline(key, opts)
	local prop = R.Outline(key, { values = { "none", "thin", "thick" }, game = "game", tip = opts and opts.tip })
	local options = prop.options
	prop.options = function()
		local list = options()
		for _, o in ipairs(list) do if o[1] == -1 then o[1] = "general" end end
		return list
	end
	for k, v in pairs(opts or {}) do if prop[k] == nil then prop[k] = v end end
	return prop
end
-- The variant's "Look from": follows the first, or its own copy.
local FOLLOWED = Nothing("default") -- (the first variant's Look from: it's what the others follow)
local function LookFrom(_, first, field, options, opts)
	local key = function(v)
		if v == nil or v == first then return FOLLOWED end
		return field(v)
	end
	-- (Hidden on the first variant: it's the one the others follow.)
	local prop = R.Choice(key, L["Look from"], options, opts)
	-- (opts.hideOn: variants it's gone from, the nameplates' cast bars: each setting follows or not.)
	prop.shown = function(_, v) return v ~= first and not (opts and opts.hideOn and opts.hideOn[v]) end
	return prop
end

local GRADIENTS = { { "off", L["Off"] }, { "shade", L["Darker"], L["It fades to a darker shade of its own color."] },
	{ "on", L["Your color"], L["It fades to the color you pick."] } }
local DIRECTIONS = { { "right", L["Left to right"], L["Its color at the left."] },
	{ "left", L["Right to left"], L["Its color at the right."] },
	{ "down", L["Top to bottom"], L["Its color at the top: lit from above."] } }
local function HealthChoices(gameTip)
	return function()
		local list = { { "game", L["The game's"], gameTip },
			{ "class", L["Class or reaction"], L["Players in their class color, everyone else red, yellow or green by how they see you."] },
			{ "custom", L["Custom"] } }
		-- (By health: only where the game has color curves.)
		if ns.CanColorByHealth then
			list[#list + 1] = { "health", L["By health"], L["Full, half and empty health in colors of your own, shifting as health drops."] }
		end
		return list
	end
end

-- Unit frames ---------------------------------------------------------------------
local UNIT_VARIANTS = { { id = "default", label = L["Default"] }, { id = "PLAYER", label = L["Player"] },
	{ id = "TARGET", label = L["Target"] }, { id = "FOCUS", label = L["Focus"] }, { id = "PET", label = L["Pet"] },
	{ id = "TOT", label = L["Target of target"] }, { id = "PARTY", label = L["Party"] } }
local UK = Keyer("unit", "default", function(base, v)
	-- (A border's size and color: ufBorder_<ID><part>.)
	local part = base:match("^ufBorder(%u%l*)$")
	if part and part ~= "" then return "ufBorder_" .. v .. part end
	return base .. "_" .. v
end)
local function RaidDrawsParty() return ns.RaidStyleParty and ns.RaidStyleParty() and true or false end
-- (A variant's settings can change: Default's, a frame's while it has its own look;
-- not the party's while the game draws it as raid frames.)
local function UnitOwn(db, v)
	if v == "PARTY" and RaidDrawsParty() then return false end
	if v == nil or v == "default" then return true end
	return db["ufOwn_" .. v] and true or false
end
local UnitTest = ByVariant("unit", UnitOwn)
local function UnitIs(key, ...)
	local want = { ... }
	return ByVariant("unit", function(db, v)
		if not UnitOwn(db, v) then return false end
		local now = Studio.Get(UK(key)(v))
		for _, w in ipairs(want) do if now == w then return true end end
		return false
	end)
end
local unitOwnFields = {}
local function UnitOwnField(v)
	if not unitOwnFields[v] then
		unitOwnFields[v] = { default = "default",
			get = function() local db = ns.GetDB() return db and db["ufOwn_" .. v] and "own" or "default" end,
			set = function(value) if ns.UnitStyleSetOwn then ns.UnitStyleSetOwn(v, value == "own") end end }
	end
	return unitOwnFields[v]
end
-- (A part's Shown, the Overrides page's: unitPart<frame><part>, the frames that have it.)
local OVER_FRAME = { PLAYER = "Player", TARGET = "Target", FOCUS = "Focus", PET = "Pet", TOT = "ToT" }
local function OverKey(v, part)
	local frame = OVER_FRAME[v or ""]
	local key = frame and ("styleOver_unitPart" .. frame .. part)
	return key and ns.DEFAULTS[key] ~= nil and key or nil
end
local function UnitShown(part)
	local prop = R.Shown("unitPartPlayer" .. part, { free = true,
		test = function() return not ns.PageOn or ns.PageOn("styleOverrides") end })
	local nothing = Nothing("row")
	prop.key = function(v) return OverKey(v, part) or nothing end
	prop.shown = ByVariant("unit", function(_, v) return OverKey(v, part) ~= nil end)
	return prop
end
local function RaidPartyNote()
	local shown = ByVariant("unit", function(_, v) return v == "PARTY" and RaidDrawsParty() end)
	return R.Note(L["The game draws your party as raid frames now, so Raid Style sets its look."], { shown = shown }),
		R.Button(L["Open Raid Style"], function() ns.OpenStylePage("Raid Style", "raid", "PARTY") end, { shown = shown })
end
local function UnitFollowsNote()
	return R.Note(L["Follows Default. Bar's Look from gives it a look of its own."], {
		shown = ByVariant("unit", function(db, v)
			return v ~= "default" and not (v == "PARTY" and RaidDrawsParty()) and not db["ufOwn_" .. v]
		end) })
end
-- (Which sample a variant's parts are found on: Default's, the player's.)
local function UnitSample(p)
	local v = VariantNow("unit")
	return p and p.units and p.units[(v and v ~= "default") and v or "PLAYER"]
end
local SHAPES = {
	{ "game", L["The game's"], L["The game's round frame."] },
	{ "circle", L["Circle"], L["A thin ring in place of the game's frame art."] },
	{ "square", L["Square"], L["A square portrait with a thin edge, in place of the game's frame art."] },
	{ "hex", L["Hexagon"], L["A six-sided portrait, in place of the game's frame art."] },
	{ "diamond", L["Diamond"], L["A diamond portrait, in place of the game's frame art."] },
	{ "arch", L["Arch"], L["A portrait in a pointed window, in place of the game's frame art."] },
	{ "cut", L["Cut square"], L["A square portrait with small cut corners, in place of the game's frame art."] },
	{ "eye", L["Eye"], L["A tall, narrow portrait with a point at each end, in place of the game's frame art."] },
	{ "octagon", L["Octagon"], L["An eight-sided portrait, in place of the game's frame art."] },
	{ "shield", L["Shield"], L["A portrait on a shield, in place of the game's frame art."] },
	{ "petal", L["Leaf"], L["A rounded portrait with two sharp corners, in place of the game's frame art."] },
	{ "crystal", L["Crystal"], L["A wide cut crystal, in place of the game's frame art."] },
	{ "none", L["None"], L["No portrait and no frame art: just the name and bars."] },
}

local partyNote, partyButton = RaidPartyNote()
ns.StyleFrame("unit", {
	label = L["Unit frames"], band = "Interface", sub = "Combat", subRank = 1, page = "Unit Style", switch = "ufStyle",
	refresh = function() if ns.RefreshUnitStyle then ns.RefreshUnitStyle() end end,
	preview = function(parent, width)
		local p = ns.MakeUnitStylePreview(parent, width, function(id)
			local win = ns.StyleStudioWindow and ns.StyleStudioWindow()
			if win and win.host then win.host:Pick(nil, id or "default") end
		end)
		local refresh = p.Refresh
		function p.Refresh(self)
			local v = VariantNow("unit")
			refresh(self, v ~= "default" and v or nil)
		end
		return p
	end,
	variants = UNIT_VARIANTS,
	parts = {
		{ id = "bar", label = L["Bars"], region = function(p) local u = UnitSample(p) return u and u.health end, groups = {
			R.Group("Look",
				LookFrom("unit", "default", UnitOwnField, {
					{ "default", L["Follows Default"], L["This frame looks as Default says."] },
					{ "own", L["Its own look"], L["This frame has its own copy of every setting here."] },
				}, { inherit = "default", default = "default", free = true,
					tip = L["Whether this frame looks as Default says or has its own look."],
					test = ByVariant("unit", function(_, v) return not (v == "PARTY" and RaidDrawsParty()) end) }),
				partyNote, partyButton, UnitFollowsNote(), UnitShown("Health")),
			R.Group("Bar",
				R.Texture(UK("ufTexture"), { tip = L["The bars' fill, including textures other addons share."], test = UnitTest }),
				VariantRgb("unit", R.Color(UK("ufHealthColor"), L["Health color"], HealthChoices(), nil, "custom",
					{ test = UnitTest, tip = L["The health bar's color."] }), RgbOf(UK, "ufHealth")),
				VariantSwatch("unit", L["At full"], RgbOf(UK, "ufHealth"), { test = UnitIs("ufHealthColor", "health"),
					shown = function() return ns.CanColorByHealth and true or false end, tip = L["Its color at full health, for By health."] }),
				VariantSwatch("unit", L["At half"], RgbOf(UK, "ufHealthMid"), { test = UnitIs("ufHealthColor", "health"),
					shown = function() return ns.CanColorByHealth and true or false end, tip = L["Its color at half health, for By health."] }),
				VariantSwatch("unit", L["Empty"], RgbOf(UK, "ufHealthLow"), { test = UnitIs("ufHealthColor", "health"),
					shown = function() return ns.CanColorByHealth and true or false end, tip = L["Its color as health runs out, for By health."] }),
				R.Choice(UK("ufGradient"), L["Gradient"], GRADIENTS, { test = UnitTest, tip = L["The health bar's gradient."] }),
				VariantSwatch("unit", L["Fades to"], RgbOf(UK, "ufGrad"), { test = UnitIs("ufGradient", "on"),
					tip = L["The color the health bar fades to."] }),
				R.Choice(UK("ufPowerGradient"), L["Power gradient"], GRADIENTS, { test = UnitTest, tip = L["The power bar's gradient."] }),
				VariantSwatch("unit", L["Power fades to"], RgbOf(UK, "ufPowerGrad"), { test = UnitIs("ufPowerGradient", "on"),
					tip = L["The color the power bar fades to."] }),
				R.Choice(UK("ufGradDir"), L["Direction"], DIRECTIONS, { tip = L["Which way both gradients go."],
					test = ByVariant("unit", function(db, v)
						return UnitOwn(db, v) and (Studio.Get(UK("ufGradient")(v)) ~= "off" or Studio.Get(UK("ufPowerGradient")(v)) ~= "off")
					end) })),
			R.Group("Background",
				R.Slider(UK("ufBack"), L["Background"], 0, 100, 5, "%", { scale = 100, test = UnitTest,
					tip = L["How dark it is behind the bars, with a border of ours."] })),
		} },
		{ id = "portrait", label = L["Portrait"], region = function(p) local u = UnitSample(p) return u and u.portrait end, groups = {
			R.Group("Look", UnitFollowsNote(), UnitShown("Portrait")),
			R.Group("Icon",
				R.Choice(UK("ufPortrait"), L["Portrait"], { { "game", L["The game's"], L["Their face."] },
					{ "class", L["Class icon"], L["A player's class icon in place of their face (NPCs keep theirs)."] } },
					{ test = UnitTest, tip = L["Their face, or a player's class icon."] }),
				R.Drop(UK("ufShape"), L["Shape"], function()
					local list = {}
					for _, each in ipairs(SHAPES) do list[#list + 1] = { value = each[1], text = each[2], tip = each[3] } end
					return list
				end, { test = UnitTest, tip = L["The portrait's shape, in place of the game's frame art."] })),
		} },
		{ id = "name", label = L["Name"], region = function(p) local u = UnitSample(p) return u and u.name end, groups = {
			R.Group("Look", UnitFollowsNote(), UnitShown("Name")),
			R.Group("Text",
				R.Font(UK("ufFont"), { tip = L["The font for names."], test = UnitTest }),
				R.Slider(UK("ufNameSize"), L["Size"], 50, 150, 5, "%", { scale = 100, test = UnitTest,
					tip = L["The name's size compared to the game's."] }),
				R.Choice(UK("ufNameColor"), L["Color"], { { "game", L["The game's"] }, { "class", L["Class or reaction"] },
					{ "white", L["White"] }, { "theme", L["The theme's"], L["The main theme's accent color."] } },
					{ test = UnitTest, tip = L["The name's color."] }),
				R.Outline(UK("ufOutline"), { test = UnitTest }),
				R.Shadow(UK("ufShadow"), { test = UnitTest }),
				R.Choice(UK("ufNameCut"), L["Long names"], {
					{ "game", L["The game's"], L["A name too long for its frame ends in \"...\"."] },
					{ "first", L["First name"], L["Long names lose their last words instead of ending in \"...\"."] },
				}, { test = UnitTest, tip = L["How a name too long for its frame is cut."] })),
			-- (Only the target and focus frames have the strip: on their variants and Default's.)
			R.Group("Background",
				VariantRgb("unit", R.Color(UK("ufNameBack"), L["Name background"], {
					{ "auto", L["Auto"], L["The game's, hidden with a portrait shape of ours."] },
					{ "game", L["The game's"], L["Colored by how they see you."] },
					{ "hide", L["Hidden"], L["No colored strip behind the name."] },
					{ "custom", L["Custom"] },
				}, nil, "custom", { test = UnitTest, tip = L["The colored strip behind the target's and focus's name."],
					shown = ByVariant("unit", function(_, v) return v == "default" or v == "TARGET" or v == "FOCUS" end) }),
					RgbOf(UK, "ufNameBack"))),
		} },
		{ id = "level", label = L["Level"], groups = {
			R.Group("Look", UnitShown("Level"),
				R.Note(L["The level shows as the Unit Frames page says."], {
					shown = ByVariant("unit", function(_, v) return OverKey(v, "Level") == nil end) })),
		} },
		{ id = "border", label = L["Border"], region = function(p) local u = UnitSample(p) return u and u.health end, groups = {
			R.Group("Look", UnitFollowsNote(), UnitShown("Art")),
			R.Group("Border", VariantBorder("unit", UK("ufBorder"), UK("ufBorderSize"), RgbOf(UK, "ufBorder"),
				{ game = true, test = UnitTest, tip = L["The border around each bar: the game's frame or one of ours."] })),
		} },
	},
})

-- Raid frames ---------------------------------------------------------------------
local RAID_VARIANTS = { { id = "default", label = L["Default"] }, { id = "RAID", label = L["Raid"] },
	{ id = "PARTY", label = L["Party"] } }
-- (Arena frames: only retail has them.)
if ns.isRetail then RAID_VARIANTS[#RAID_VARIANTS + 1] = { id = "ARENA", label = L["Arena"] } end
local RK = Keyer("raid", "default", function(base, v)
	local part = base:match("^rfBorder(%u%l*)$")
	if part and part ~= "" then return "rfBorder_" .. v .. part end
	return base .. "_" .. v
end)
local function UnitDrawsParty() return not RaidDrawsParty() end
local function RaidOwn(db, v)
	if v == "PARTY" and UnitDrawsParty() then return false end
	if v == nil or v == "default" then return true end
	return db["rfOwn_" .. v] and true or false
end
local RaidTest = ByVariant("raid", RaidOwn)
local function RaidIs(key, ...)
	local want = { ... }
	return ByVariant("raid", function(db, v)
		if not RaidOwn(db, v) then return false end
		local now = Studio.Get(RK(key)(v))
		for _, w in ipairs(want) do if now == w then return true end end
		return false
	end)
end
local raidOwnFields = {}
local function RaidOwnField(v)
	if not raidOwnFields[v] then
		raidOwnFields[v] = { default = "default",
			get = function() local db = ns.GetDB() return db and db["rfOwn_" .. v] and "own" or "default" end,
			set = function(value) if ns.RaidStyleSetOwn then ns.RaidStyleSetOwn(v, value == "own") end end }
	end
	return raidOwnFields[v]
end
local function RaidFollowsNote()
	return R.Note(L["Follows Default. Bar's Look from gives it a look of its own."], {
		shown = ByVariant("raid", function(db, v)
			return v ~= "default" and not (v == "PARTY" and UnitDrawsParty()) and not db["rfOwn_" .. v]
		end) })
end
local unitPartyShown = ByVariant("raid", function(_, v) return v == "PARTY" and UnitDrawsParty() end)
local function RaidTile(p)
	local v = VariantNow("raid")
	local want = v == "PARTY" and "PARTY" or "RAID"
	for _, tile in ipairs(p and p.tiles or {}) do if tile.id == want then return tile end end
end

ns.StyleFrame("raid", {
	label = L["Raid frames"], band = "Interface", sub = "Combat", subRank = 1, page = "Raid Style", switch = "rfStyle",
	refresh = function() if ns.RefreshRaidStyle then ns.RefreshRaidStyle() end end,
	preview = function(parent, width)
		local p = ns.MakeRaidStylePreview(parent, width, function(id)
			local win = ns.StyleStudioWindow and ns.StyleStudioWindow()
			if win and win.host then win.host:Pick(nil, id or "default") end
		end)
		local refresh = p.Refresh
		function p.Refresh(self)
			local v = VariantNow("raid")
			refresh(self, v ~= "default" and v or nil)
		end
		return p
	end,
	variants = RAID_VARIANTS,
	parts = {
		{ id = "bar", label = L["Health bar"], region = function(p) local t = RaidTile(p) return t and t.health end, groups = {
			R.Group("Look",
				LookFrom("raid", "default", RaidOwnField, {
					{ "default", L["Follows Default"], L["This group looks as Default says."] },
					{ "own", L["Its own look"], L["This group has its own copy of every setting here."] },
				}, { inherit = "default", default = "default", free = true,
					tip = L["Whether this group looks as Default says or has its own look."],
					test = ByVariant("raid", function(_, v) return not (v == "PARTY" and UnitDrawsParty()) end) }),
				R.Note(L["The game draws your party as its own frames now, so Unit Style sets its look."], { shown = unitPartyShown }),
				R.Button(L["Open Unit Style"], function() ns.OpenStylePage("Unit Style", "unit", "PARTY") end, { shown = unitPartyShown }),
				RaidFollowsNote()),
			R.Group("Bar",
				R.Texture(RK("rfTexture"), { tip = L["The health bar's fill, including textures other addons share."], test = RaidTest }),
				VariantRgb("raid", R.Color(RK("rfHealthColor"), L["Color"], HealthChoices(L["As the game's options say (class colors, or green)."]),
					nil, "custom", { test = RaidTest, tip = L["The health bar's color."] }), RgbOf(RK, "rfHealth")),
				VariantSwatch("raid", L["At full"], RgbOf(RK, "rfHealth"), { test = RaidIs("rfHealthColor", "health"),
					shown = function() return ns.CanColorByHealth and true or false end, tip = L["Its color at full health, for By health."] }),
				VariantSwatch("raid", L["At half"], RgbOf(RK, "rfHealthMid"), { test = RaidIs("rfHealthColor", "health"),
					shown = function() return ns.CanColorByHealth and true or false end, tip = L["Its color at half health, for By health."] }),
				VariantSwatch("raid", L["Empty"], RgbOf(RK, "rfHealthLow"), { test = RaidIs("rfHealthColor", "health"),
					shown = function() return ns.CanColorByHealth and true or false end, tip = L["Its color as health runs out, for By health."] }),
				R.Choice(RK("rfGradient"), L["Gradient"], GRADIENTS, { test = RaidTest, tip = L["The health bar's gradient."] }),
				VariantSwatch("raid", L["Fades to"], RgbOf(RK, "rfGrad"), { test = RaidIs("rfGradient", "on"),
					tip = L["The color the health bar fades to."] }),
				R.Choice(RK("rfGradDir"), L["Direction"], DIRECTIONS, { tip = L["Which way the gradient goes."],
					test = ByVariant("raid", function(db, v) return RaidOwn(db, v) and Studio.Get(RK("rfGradient")(v)) ~= "off" end) })),
			R.Group("Background",
				R.Slider(RK("rfBack"), L["Bar background"], 0, 100, 5, "%", { scale = 100,
					tip = L["How dark it is behind the health bar, with a border of ours."],
					test = ByVariant("raid", function(db, v) return RaidOwn(db, v) and Studio.Get(RK("rfBorder")(v)) ~= "game" end) })),
		} },
		{ id = "name", label = L["Name"], region = function(p) local t = RaidTile(p) return t and t.name end, groups = {
			R.Group("Look", RaidFollowsNote()),
			R.Group("Text",
				R.Font(RK("rfFont"), { tip = L["The font for names."], test = RaidTest }),
				R.Slider(RK("rfNameSize"), L["Size"], 50, 150, 5, "%", { scale = 100, test = RaidTest,
					tip = L["The name's size compared to the game's."] }),
				R.Choice(RK("rfNameColor"), L["Color"], { { "game", L["The game's"] }, { "class", L["Class or reaction"] },
					{ "white", L["White"] }, { "theme", L["The theme's"], L["The main theme's accent color."] } },
					{ test = RaidTest, tip = L["The name's color."] }),
				R.Outline(RK("rfOutline"), { test = RaidTest }),
				R.Shadow(RK("rfShadow"), { test = RaidTest })),
		} },
		{ id = "border", label = L["Border"], region = function(p) return RaidTile(p) end, groups = {
			R.Group("Look", RaidFollowsNote()),
			R.Group("Border", VariantBorder("raid", RK("rfBorder"), RK("rfBorderSize"), RgbOf(RK, "rfBorder"),
				{ game = true, test = RaidTest, tip = L["The border around each frame: the game's or one of ours."] })),
		} },
		{ id = "tile", label = L["Tile"], region = function(p) local t = RaidTile(p) return t and t.ground or t end, groups = {
			R.Group("Look", RaidFollowsNote()),
			R.Group("Background",
				VariantRgb("raid", R.Color(RK("rfGroundColor"), L["Tile background"], { { "game", L["The game's"] },
					{ "custom", L["Custom"], L["Tints the game's background a color of your own."] } }, nil, "custom",
					{ test = RaidTest, tip = L["The game's background behind each frame, or tinted a color of your own."] }),
					RgbOf(RK, "rfGround")),
				R.Slider(RK("rfGround"), L["Opacity"], 0, 100, 5, "%", { scale = 100, test = RaidTest,
					tip = L["How solid the game's dark background behind each frame is."] })),
		} },
	},
})

-- Cast bars -----------------------------------------------------------------------
-- One frame for the three cast pages (decision 4): Unit Cast Style opens on Default,
-- Player Cast Style on Your cast bar, Cast Bar Style on Nameplates.
local CK = Keyer("cast", "default", function(base, v) return base .. "_" .. v end)
-- (The nameplates' (PLATE) each setting its own or Default's, one by one, the user 2026-11-25:
-- Look from "locks everything". A field: Default's value while its own is empty; set, its own;
-- set to what Default has, empty again (follows it once more). PlateCastStyle.lua's View reads
-- it the same way.)
local plateFields = {}
local function PlateField(base)
	if not plateFields[base] then
		local own = base .. "_PLATE"
		plateFields[base] = {
			get = function()
				local db = ns.GetDB()
				local mine = db and db[own]
				if mine ~= nil then return mine end
				return ns.StyleKeyGet(base)
			end,
			set = function(value)
				local db = ns.GetDB()
				if not db then return end
				if value == ns.StyleKeyGet(base) then db[own] = nil else db[own] = value end
			end,
			default = ns.DEFAULTS[base],
			plateOwn = own,
		}
	end
	return plateFields[base]
end
do
	local keyer = CK
	CK = function(base)
		local each = keyer(base)
		return function(v)
			if v == "PLATE" then return PlateField(base) end
			return each(v)
		end
	end
end
local function CastId(v) return (v ~= nil and v ~= "default") and v or nil end
local function CastSwitch(v) return ns.CastSwitchFor and ns.CastSwitchFor(CastId(v)) or "unitCastStyle" end
-- (A variant's settings can change: Default's while a cast page is on, a kind's
-- while it's restyled and has its own look.)
local function CastOwn(db, v)
	local id = CastId(v)
	if not id then return ns.StyleOn(CastSwitch(v), db) end
	if id == "PLATE" then return ns.CastActive and ns.CastActive(id, db) or false end -- (every setting open)
	return ns.CastActive and ns.CastActive(id, db) and db["plateCastOwn_" .. id] and true or false
end
local CastTest = ByVariant("cast", CastOwn)
local function CastWith(fn) return ByVariant("cast", function(db, v) return CastOwn(db, v) and fn(db, v) end) end
local CastFilled = CastWith(function(_, v) return ns.CastFillOurs and ns.CastFillOurs(Studio.Get(CK("plateCastFill")(v))) end)
local castLookFields = {}
local function CastLookField(v)
	if not castLookFields[v] then
		castLookFields[v] = { default = v == "PLATE" and "default" or "game",
			get = function() return ns.CastLookPick and ns.CastLookPick(v) end,
			set = function(value) if ns.CastPickLook then ns.CastPickLook(v, value) end end }
	end
	return castLookFields[v]
end
local function CastLookOptions()
	local v = VariantNow("cast")
	local list = {}
	if v ~= "PLATE" then
		list[#list + 1] = { "game", L["The game's"], L["Cinematic leaves these cast bars alone."] }
		list[#list + 1] = { "other", L["Nameplates'"], L["The game's nameplate cast bar look."] }
	else
		list[#list + 1] = { "other", L["Unit frames'"], L["The game's unit frame cast bar look."] }
	end
	list[#list + 1] = { "default", L["Follows Default"], L["They look as Default says."] }
	if v == "PLAYER" or v == "TARGET" then
		list[#list + 1] = { "frame", L["Unit frame's"],
			L["Makes it part of the unit frame, with its fill, border and font, right under its bars."] }
	end
	list[#list + 1] = { "own", L["Its own look"], L["These bars have their own copy of every setting here."] }
	return list
end
local function CastSample(p)
	return p and p.samples and p.samples[1]
end
local function OnlyOn(...)
	local want = { ... }
	return ByVariant("cast", function(_, v)
		for _, w in ipairs(want) do if v == w then return true end end
		return false
	end)
end
-- (Your bar's width unit: px picked empty, it's filled with the bar's width now.)
local playerWidthUnit = { default = "pct",
	get = function() local db = ns.GetDB() return db and db.plateCastPlayerWidthUnit end,
	set = function(value)
		local db = ns.GetDB()
		if not db then return end
		db.plateCastPlayerWidthUnit = value
		if value == "px" and (tonumber(db.plateCastPlayerWidthPx) or 0) <= 0 then
			db.plateCastPlayerWidthPx = ns.CastPlayerBarPixels and ns.CastPlayerBarPixels() or 200
		end
	end }
local castUnitIs = function(unit) return CastWith(function(db) return (db.plateCastPlayerWidthUnit == "px") == (unit == "px") end) end

ns.StyleFrame("cast", {
	label = L["Cast bars"], band = "Interface", sub = "Combat", subRank = 1,
	pages = { ["Unit Cast Style"] = "default", ["Player Cast Style"] = "PLAYER", ["Cast Bar Style"] = "PLATE" },
	refresh = function() if ns.RefreshPlateCastStyle then ns.RefreshPlateCastStyle() end end,
	preview = function(parent, width)
		return ns.MakeCastStylePreview and ns.MakeCastStylePreview(parent, width, function() return CastId(VariantNow("cast")) end)
	end,
	-- (Each variant under its own page's switch: why it isn't showing, and the switch that turns it on.)
	status = function(db)
		local v = VariantNow("cast")
		local switch = CastSwitch(v)
		if ns.StyleOn(switch, db) then return nil end
		return L["Off: this cast bar page's Enable Page is off, so nothing here shows in the game."], "off", L["Turn on"], function()
			local writes = {}
			if not db.styleGeneral then writes[#writes + 1] = { "styleGeneral", true } end
			if not db[switch] then writes[#writes + 1] = { switch, true } end
			Studio.Apply(Studio.frames.cast, L["Cast bars"] .. " · " .. L["Turn on"], writes)
		end
	end,
	variants = { { id = "default", label = L["Default"] }, { id = "PLAYER", label = L["Your cast bar"] },
		{ id = "TARGET", label = L["Target & focus"] }, { id = "BOSS", label = L["Boss & arena"] },
		{ id = "PLATE", label = L["Nameplates"] } },
	parts = {
		{ id = "bar", label = L["Bar"], region = CastSample, groups = {
			R.Group("Look",
				LookFrom("cast", "default", CastLookField, CastLookOptions, { free = true, hideOn = { PLATE = true },
					tip = L["Pick how these cast bars look."] })),
			R.Group("Bar",
				R.Texture(CK("plateCastFill"), { tip = L["The bar's fill, including textures other addons share."], test = CastTest }),
				R.Switch(CK("plateCastSpark"), L["Spark"], { test = CastTest, tip = L["The spark at the fill's end."] }),
				-- (Its size: the nameplates' (and Default's, for them), and yours its width.)
				R.Slider(CK("plateCastWidth"), L["Width"], 50, 150, 5, "%", { scale = 100, client = "forever", test = CastTest,
					shown = OnlyOn("default", "PLATE"), tip = L["Its width compared to the game's, growing out from its middle. Nameplates only."] }),
				R.Slider(CK("plateCastHeight"), L["Height"], 50, 300, 10, "%", { scale = 100, test = CastTest,
					shown = OnlyOn("default", "PLATE"), tip = L["The cast bar's height compared to the game's."] }),
				R.Choice(playerWidthUnit, L["Width in"], { { "pct", L["Percent"], L["Its width as a percent of the game's."] },
					{ "px", L["Pixels"], L["Its width in screen pixels, so the same number gives two bars the same width."] } },
					{ test = CastTest, shown = OnlyOn("PLAYER"), default = "pct",
						tip = L["Your cast bar's width, growing out from where it's anchored. Its height and position come from Edit Mode."] }),
				R.Slider("plateCastPlayerWidth", L["Width"], 20, 200, 5, "%", { scale = 100, test = castUnitIs("pct"),
					shown = OnlyOn("PLAYER"), tip = L["Your cast bar's width as a percent of the game's."] }),
				R.Slider("plateCastPlayerWidthPx", L["Width"], 10, 2000, 5, "px", { test = castUnitIs("px"),
					shown = OnlyOn("PLAYER"), tip = L["Your cast bar's width in screen pixels."] })),
			-- (The border in the bar's part, as the mock's, 2026-11-25: it was a part of its own.)
			R.Group("Border", VariantBorder("cast", CK("plateCastBorder"), CK("plateCastBorderSize"), RgbOf(CK, "plateCastBorder"),
				{ game = true, test = CastTest, tip = L["The cast bar's border: the game's or one of ours."] })),
			R.Group("Background",
				R.Slider(CK("plateCastBack"), L["Background"], 0, 100, 5, "%", { scale = 100, test = CastFilled,
					tip = L["How dark it is behind the fill. This only works with a fill of your own; the game's keeps its own."] })),
		} },
		-- (The colors a part of their own, as the mock's Cast Bars tab (Bar · Colors · Spell name ·
		-- Icon), 2026-11-25. They color a fill of ours; the game's keeps its own.)
		{ id = "colors", label = L["Colors"], region = CastSample, groups = {
			R.Group("Colors",
				VariantSwatch("cast", L["Casting"], RgbOf(CK, "plateCast"), { test = CastFilled, tip = L["The color of a cast."] }),
				VariantSwatch("cast", L["Channeling"], RgbOf(CK, "plateCastChannel"), { test = CastFilled, tip = L["The color of a channel."] }),
				VariantSwatch("cast", L["Can't be interrupted"], RgbOf(CK, "plateCastLocked"), { test = CastFilled,
					tip = L["The color of a cast or channel that can't be interrupted."] }),
				VariantSwatch("cast", L["Interrupted"], RgbOf(CK, "plateCastStop"), { test = CastFilled,
					tip = L["The color of an interrupted cast. The game doesn't report this in every fight."] })),
		} },
		{ id = "text", label = L["Spell name"], region = function(p) local s = CastSample(p) return s and s.Text end, groups = {
			R.Group("Text",
				R.Switch(CK("plateCastText"), L["Shown"], { test = CastTest, tip = L["The spell's name."] }),
				R.Font(CK("plateCastFont"), { test = CastTest }),
				R.Slider(CK("plateCastTextSize"), L["Size"], 50, 300, 10, "%", { scale = 100, test = CastTest,
					tip = L["Its size, next to the game's."] }),
				VariantRgb("cast", R.Color(CK("plateCastTextColor"), L["Color"], { { "game", L["The game's"] }, { "custom", L["Custom"] } },
					nil, "custom", { test = CastTest, tip = L["The spell's name and seconds left in a color of your own."] }),
					RgbOf(CK, "plateCastText")),
				WordOutline(CK("plateCastOutline"), { test = CastTest }),
				R.Shadow(CK("plateCastShadow"), { test = CastTest }),
				R.Switch(CK("plateCastTimer"), L["Seconds left"], { test = CastTest,
					tip = L["Shows the seconds left at the cast bar's right end."] })),
		} },
		{ id = "icon", label = L["Icon"], region = function(p) local s = CastSample(p) return s and s.Icon end, groups = {
			R.Group("Icon",
				R.Switch(CK("plateCastIcon"), L["Shown"], { test = CastTest, tip = L["The spell's icon."] }),
				R.Slider(CK("plateCastIconSize"), L["Size"], 50, 300, 10, "%", { scale = 100,
					test = CastWith(function(_, v) return Studio.Get(CK("plateCastIcon")(v)) end),
					tip = L["The icon's size compared to the game's."] }),
				R.Switch(CK("plateCastShield"), L["Shield"], { test = CastTest,
					tip = L["The game's shield over the icon while the cast can't be interrupted."] }),
				R.Switch(CK("plateCastImportant"), L["Important mark"], { test = CastTest,
					tip = L["The game's mark on casts it counts as important, ones worth interrupting or getting out of."] }),
				R.Switch(CK("plateCastTarget"), L["Who it's cast at"], { test = CastTest,
					tip = L["The game's mark and name for who the spell is cast at."] })),
		} },
	},
})

-- Personal resources --------------------------------------------------------------
local function ManaOn(db) return db.prdMana and true or false end
local function PrdWidth(label, key, which, tip, test)
	local unit = key .. "Unit"
	local field = { default = "pct",
		get = function() local db = ns.GetDB() return db and db[unit] end,
		set = function(value)
			local db = ns.GetDB()
			if not db then return end
			db[unit] = value
			-- (px picked empty: filled with the bar's width now.)
			if value == "px" and (tonumber(db[key .. "Px"]) or 0) <= 0 then
				db[key .. "Px"] = ns.PersonalBarPixels and ns.PersonalBarPixels(which) or 200
			end
		end }
	local function Is(mode) return function(db) return (not test or test(db)) and (db[unit] == "px") == (mode == "px") end end
	return R.Choice(field, label, { { "pct", L["Percent"], L["Its width as a percent of the game's."] },
			{ "px", L["Pixels"], L["Its width in screen pixels, so the same number gives two bars the same width."] } },
			{ test = test, tip = tip, syn = "width" }),
		R.Slider(key, L["Width"], 20, 200, 5, "%", { scale = 100, test = Is("pct"), tip = tip }),
		R.Slider(key .. "Px", L["Width"], 10, 2000, 5, "px", { test = Is("px"), tip = tip })
end
local function PrdBar(p, which) return p and p[which] end
ns.StyleFrame("prd", {
	label = L["Personal resources"], band = "Interface", sub = "Combat", subRank = 1, page = "Personal Style", switch = "prdStyle",
	refresh = function() if ns.RefreshPersonalStyle then ns.RefreshPersonalStyle() end end,
	preview = function(parent, width) return ns.MakePersonalPreview(parent, width) end,
	parts = {
		{ id = "bars", label = L["Bars"], region = function(p) return PrdBar(p, "health") end, groups = {
			R.Group("Bar",
				R.Texture("prdTexture", { tip = L["The bars' fill, including textures other addons share."] }),
				R.Choice("prdGradDir", L["Direction"], DIRECTIONS, { tip = L["Which way the bars' gradients go."],
					test = function(db) return db.prdGradient ~= "off" or db.prdPowerGradient ~= "off" end })),
			R.Group("Border", R.Border("prdBorder", { game = true,
				tip = L["The bars' border: the game's or one of ours."] })),
			R.Group("Background",
				R.Slider("prdBack", L["Background"], 0, 100, 5, "%", { scale = 100,
					tip = L["How dark it is behind the bars, with a border of ours."],
					test = function() return ns.StyleLook("prdStyle").prdBorder ~= "game" end })),
		} },
		{ id = "health", label = L["Health bar"], region = function(p) return PrdBar(p, "health") end, groups = {
			R.Group("Bar",
				R.Color("prdHealthColor", L["Color"], { { "game", L["The game's"] }, { "class", L["Class"], L["Your class's color."] },
					{ "custom", L["Custom"] } }, { "prdHealthR", "prdHealthG", "prdHealthB" }, "custom", { tip = L["The health bar's color."] }),
				R.Choice("prdGradient", L["Gradient"], GRADIENTS, { tip = L["The health bar's gradient."] }),
				R.Swatch(L["Fades to"], { "prdGradR", "prdGradG", "prdGradB" }, { tip = L["The color the health bar fades to."],
					test = function(db) return db.prdGradient == "on" end }),
				R.Slider("prdHealthHeight", L["Height"], 50, 200, 5, "%", { scale = 100,
					tip = L["The health bar's height compared to the game's."] }),
				PrdWidth(L["Width in"], "prdHealthWidth", "health", L["The health bar's width, growing out from its middle."])),
		} },
		{ id = "power", label = L["Power bar"], region = function(p) return PrdBar(p, "power") end, groups = {
			R.Group("Bar",
				R.Choice("prdPowerGradient", L["Gradient"], GRADIENTS, { tip = L["The power bars' gradient, Cine Mana Bar's too."] }),
				R.Swatch(L["Fades to"], { "prdPowerGradR", "prdPowerGradG", "prdPowerGradB" }, { tip = L["The color the power bars fade to."],
					test = function(db) return db.prdPowerGradient == "on" end }),
				R.Slider("prdPowerHeight", L["Height"], 50, 200, 5, "%", { scale = 100,
					tip = L["The power bar's height compared to the game's."] }),
				PrdWidth(L["Width in"], "prdPowerWidth", "power", L["The power bar's width, growing out from its middle."])),
		} },
		{ id = "mana", label = L["Cine Mana Bar"], region = function(p) return PrdBar(p, "mana") end, groups = {
			R.Group("Bar",
				R.Note(L["Off: the Personal Resources page's mana bar row turns it on."], {
					shown = function(db) return ns.PERSONAL_MANA and not ManaOn(db) end }),
				R.Color("prdManaColor", L["Color"], { { "game", L["The game's"] }, { "custom", L["Custom"] } },
					{ "prdManaR", "prdManaG", "prdManaB" }, "custom", { test = ManaOn,
					shown = function() return ns.PERSONAL_MANA and true or false end, tip = L["The mana bar's color."] }),
				R.Slider("prdManaHeight", L["Height"], 50, 200, 5, "%", { scale = 100, test = ManaOn,
					shown = function() return ns.PERSONAL_MANA and true or false end,
					tip = L["The mana bar's height compared to the power bar's."] }),
				PrdWidth(L["Width in"], "prdManaWidth", "mana",
					L["The mana bar's width as a percent of the game's power bar, growing out from its middle."], ManaOn)),
		} },
		{ id = "pieces", label = L["Class resource"], region = function(p) return p and p.pieces end, groups = {
			R.Group("Icon",
				R.Slider("prdPiecesScale", L["Size"], 50, 200, 5, "%", { scale = 100,
					tip = L["How big your class resource is compared to the game's size."] })),
		} },
	},
})
-- (The mana bar's width and its unit: hidden where there's no mana bar of ours.)
do
	local f = Studio.frames.prd
	for _, each in ipairs(Studio.Props(f, "mana")) do
		if each.prop.kind ~= "text" and not each.prop.shown then
			each.prop.shown = function() return ns.PERSONAL_MANA and true or false end
		end
	end
end

-- Action bars ---------------------------------------------------------------------
local function ActionButton(p, i) return p and p.buttons and p.buttons[i] end
ns.StyleFrame("action", {
	label = L["Action bars"], band = "Interface", sub = "Combat", subRank = 1, page = "Action Style", switch = "abStyle",
	refresh = function() if ns.RefreshActionBarStyle then ns.RefreshActionBarStyle() end end,
	preview = function(parent) return ns.MakeActionBarPreview(parent) end,
	-- (Dominos reuses the game's buttons, Masque skins them: the look stays off with either.)
	status = function()
		local by = ns.ActionBarsSkinnedBy and ns.ActionBarsSkinnedBy()
		if by == "Dominos" then return L["Dominos draws your action bars, so this look stays off while it's loaded."], "warn" end
		if by == "Masque" then return L["Masque skins your action buttons, so this look stays off while it's loaded."], "warn" end
	end,
	parts = {
		{ id = "icon", label = L["Icon"], region = function(p) return ActionButton(p, 1) end, groups = {
			R.Group("Icon",
				R.Choice("abShape", L["Shape"], { { "game", L["The game's"] },
					{ "square", L["Square"], L["Square icons with their edges trimmed."] },
					{ "round", L["Round"], L["Round icons, with the cooldown sweep and the highlights round too."] } },
					{ tip = L["The action buttons' shape."] }),
				R.Slider("abAlpha", L["Opacity"], 20, 100, 5, "%", { scale = 100,
					tip = L["How see-through the action buttons are; lower if they look too bright."] })),
		} },
		{ id = "slot", label = L["Empty slot"], region = function(p) return ActionButton(p, 4) end, groups = {
			R.Group("Background",
				R.Switch("abSlots", L["Background"], { tip = L["Shows the game's background on empty action slots."] })),
		} },
		{ id = "border", label = L["Border"], region = function(p) return ActionButton(p, 2) end, groups = {
			R.Group("Border", R.Border("abEdge", { game = true, colored = L["Class color"], syn = "outline",
				tip = L["The outline around each action button."] })),
		} },
	},
})

-- Cooldown Manager ----------------------------------------------------------------
-- (Each part its page's folder tab, a container: right-click turns it off.)
local function TabOn(n) return function() return not ns.CdmStyleTabOn or ns.CdmStyleTabOn(n) end end
local function TabOff(n)
	return R.Note(L["Off: right-click its tab on the page to turn it on."], {
		shown = function() return ns.CdmStyleTabOn and not ns.CdmStyleTabOn(n) end })
end
local function RingIs(...)
	local want = { ... }
	return function(db)
		if not TabOn(1)() then return false end
		for _, w in ipairs(want) do if db.cdmRingColor == w then return true end end
		return false
	end
end
local function Pipped(db)
	return TabOn(3)() and (db.cdmBothLook == nil or db.cdmBothLook == "ring" or db.cdmBothLook == "edge" or db.cdmBothLook == "row")
end
ns.StyleFrame("cdm", {
	label = L["Cooldown Manager"], band = "Interface", sub = "Combat", subRank = 1, page = "Cooldown Manager Style", switch = "cdmStyle",
	refresh = function()
		if ns.ApplyCooldownRing then ns.ApplyCooldownRing() end
		if ns.ApplyCooldownBoth then ns.ApplyCooldownBoth() end
		-- (The icons' shape: Action Bar Style's pass, which waits out a fight.)
		if ns.RefreshActionBarStyle then ns.RefreshActionBarStyle() end
	end,
	preview = function(parent, width) return ns.MakeCdmStudioPreview(parent, width) end,
	parts = {
		{ id = "ring", label = L["Drain ring"], region = function(p) return p and p.ring end, groups = {
			R.Group("Look", TabOff(1),
				R.Choice("cdmRingStyle", L["Style"], {
					{ "pips", L["Pips"], L["Eight chunky segments round the icon."] },
					{ "smooth", L["Smooth"], L["One thin ring round the icon."] },
					{ "liquid", L["Liquid"], L["The icon empties from the top down."] },
					{ "bar", L["Bar under"], L["A thin bar under the icon."] },
				}, { test = TabOn(1), tip = L["How the ring is drawn."] }),
				R.Slider("cdmRingScale", L["Size"], 110, 180, 5, "%", { scale = 100, tip = L["How big the ring is next to the icon."],
					test = function(db) return TabOn(1)() and (db.cdmRingStyle == "pips" or db.cdmRingStyle == "smooth") end }),
				R.Slider("cdmRingTrack", L["Empty part"], 0, 90, 5, "%", { scale = 100, test = TabOn(1),
					tip = L["How dark the spent part shows. 0: hidden."] }),
				R.Color("cdmRingColor", L["Color"], {
					{ "class", L["Class"], L["The ring in your class's color."] },
					{ "grad", L["Gradient"], L["From the full end's color to the empty end's: what's left turns toward the empty color as it drains."] },
					{ "custom", L["Custom"] },
					{ "white", L["White"], L["A plain white ring."] },
				}, { "cdmRingR", "cdmRingG", "cdmRingB" }, "custom", { test = TabOn(1), tip = L["The ring's color."] }),
				R.Swatch(L["Full end"], { "cdmGradFullR", "cdmGradFullG", "cdmGradFullB" }, { test = RingIs("grad"),
					tip = L["The gradient's color where the shield is full."] }),
				R.Swatch(L["Empty end"], { "cdmGradEmptyR", "cdmGradEmptyG", "cdmGradEmptyB" }, { test = RingIs("grad"),
					tip = L["The gradient's color where the shield runs out."] }),
				R.Note(L["Which buffs get a ring, and the game's timer: the Cooldown Manager page, under Look."])),
			-- (The amount on the icon: from its middle, nudged.)
			R.Group("Text",
				R.Slider("cdmAmountSize", L["Size"], 8, 20, 1, "px", { test = TabOn(1), tip = L["How big the amount's text is."] })),
			R.Group("Place",
				R.Slider("cdmAmountX", L["Left/right"], -30, 30, 1, "px", { test = TabOn(1),
					tip = L["Moves the amount left or right from the icon's middle."] }),
				R.Slider("cdmAmountY", L["Down/up"], -30, 30, 1, "px", { test = TabOn(1),
					tip = L["Moves the amount down or up from the icon's middle."] })),
		} },
		{ id = "icons", label = L["Icons"], region = function(p) return p and p.ring end, groups = {
			R.Group("Icon", TabOff(2),
				R.Choice("cdmIconShape", L["Shape"], {
					{ "bars", L["Same as action bars"], L["The icons take Action Bar Style's shape."] },
					{ "square", L["Square"], L["Square icons, whatever the action buttons are."] },
					{ "round", L["Round"], L["Round icons, whatever the action buttons are."] },
				}, { test = TabOn(2), tip = L["The Cooldown Manager icons' shape."] })),
		} },
		{ id = "both", label = L["Cooldown + DoT"], region = function(p) return p and p.both end, groups = {
			R.Group("Look", TabOff(3),
				R.Choice("cdmBothLook", L["Look"], {
					{ "ring", L["Ring"], L["Pips in a ring round the icon."] },
					{ "edge", L["Edge pips"], L["Square pips along the icon's edge."] },
					{ "row", L["Row pips"], L["A row of square pips under the icon."] },
					{ "bar", L["Bar under"], L["A thin bar under the icon."] },
					{ "corner", L["Corner number"], L["The cooldown's seconds in the icon's corner."] },
				}, { test = TabOn(3), tip = L["How a spell's cooldown shows over its DoT."] }),
				R.Choice("cdmBothPips", L["Pips"], {
					{ 4, "4", L["Four pips: a big step each."] },
					{ 8, "8", L["Eight pips."] },
					{ 12, "12", L["Twelve pips: small steps."] },
				}, { test = Pipped, tip = L["How many pips the cooldown is cut into."] }),
				R.Color("cdmBothColor", L["Color"], {
					{ "custom", L["Custom"] },
					{ "class", L["Class"], L["Your class's color."] },
					{ "white", L["White"], L["Plain white."] },
				}, { "cdmBothR", "cdmBothG", "cdmBothB" }, "custom", { test = TabOn(3), tip = L["The cooldown's color."] }),
				R.Note(L["Which spells show both: the Cooldown Manager page, Look, Shows."])),
		} },
	},
})
-- (Each part's settings under its tab's switch, a container, the tab under the page's:
-- with the tab off, ns.MasterOff and ns.StyleLook read them off, as when they sat on
-- the tab's frame (ns.MapTabContainers).)
do
	local f = Studio.frames.cdm
	local TABS = { ring = ns.CDM_STYLE_RING_TAB or 1, icons = ns.CDM_STYLE_ICONS_TAB or 2, both = ns.CDM_STYLE_BOTH_TAB or 3 }
	for _, part in ipairs(f.parts) do
		local tab = ("tabOn:%s:%d"):format(ns.CDM_STYLE_TABS or "Cooldown Manager Style/look", TABS[part.id])
		if ns.DEFAULTS[tab] == nil then ns.DEFAULTS[tab] = true end
		local keys = {}
		for _, each in ipairs(Studio.Props(f, part.id)) do
			if type(each.prop.key) == "string" then keys[#keys + 1] = each.prop.key end
			for _, rk in ipairs(each.prop.rgb or {}) do keys[#keys + 1] = rk end
		end
		ns.SetPageMaster(keys, tab)
		ns.SetPageMaster({ tab }, "cdmStyle")
	end
end
end) -- (ns.Module "style")
