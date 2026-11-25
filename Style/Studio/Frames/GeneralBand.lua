-- Style Studio frames: the Style hub's General band (Tools/style-studio/plan.md section 7).
--   general   Everything: the Themes page's Quick settings (fonts, bar texture, shapes,
--             nameplate style, outline and border), Style/GeneralStyle.lua.
--   overrides Style Overrides: each part's Shown, a part per tab (StyleOverrides.lua).
--   recolor   Trackers & bars: the Interface Recolor page (InterfaceRecolor.lua).
--   minimap   Minimap Style (MinimapStyle.lua).
-- Every look setting each page had, by its db key (or its field), in the recipes' order.
local _, ns = ...
ns.Module("style", function()
local L = ns.L
local R = ns.Studio.R

-- A quick setting's field (StyleThemes.lua): what Reset gives it, its reset().
local function FieldReset(field) return field.reset and field.reset() end

local function Shown(p, region)
	-- (The drawn plate's parts, while it's the one up: not the game's copy.)
	return p.plate and p.plate:IsShown() and p[region] or nil
end

-- General ------------------------------------------------------------------------------
local function RefreshGeneral()
	if ns.RefreshAllStyles then ns.RefreshAllStyles() end
	if ns.ApplyMenuSkin then ns.ApplyMenuSkin() end
	if ns.generalStylePreview then ns.generalStylePreview:Refresh() end
	if ns.themesStylePreview then ns.themesStylePreview:Refresh() end
end

local PANEL_SHAPES = {
	{ value = "square", text = L["Square"] }, { value = "round", text = L["Rounded"] },
	{ value = "chamfer", text = L["Chamfered"] }, { value = "blade", text = L["Blade"] },
	{ value = "notch", text = L["Notched"] }, { value = "sigil", text = L["Sigil"] },
	{ value = "veil", text = L["Veil"] },
	{ value = "plate", text = L["Plate"] }, { value = "leaf", text = L["Leaf"] },
	{ value = "facet", text = L["Faceted"] }, { value = "soft", text = L["Soft"] },
	{ value = "frame", text = L["Slightly rounded"] },
}

ns.StyleFrame("general", {
	-- (sub: the Themes row they're on, General > Themes; the Studio's crumbs need one.)
	label = L["Everything"], band = "General", sub = "Themes", subRank = 0, page = "Style Themes",
	-- (Both of General's pages open it; the editor sits on Themes' Quick settings.)
	pages = { ["Style General"] = false, ["Style Themes"] = false },
	switch = "styleGeneral",
	refresh = RefreshGeneral,
	preview = function(parent, width) return ns.MakeGeneralPlatePreview(parent, width) end,
	parts = {
		{ id = "text", label = L["Text"], region = function(p) return Shown(p, "plateName") end, groups = {
			R.Group("Text",
				R.Font(ns.ThemeQuickField("styleFont"), { label = L["Text font"], default = FieldReset,
					tip = L["The text font for pages that follow General."] }),
				R.Font(ns.ThemeTitleFontField(), { label = L["Title font"], default = FieldReset,
					tip = L["The big title font on cards."] }),
				R.Font(ns.ThemeSmallFontField(), { label = L["Small names font"], default = FieldReset,
					tip = L["The font for names on unit and raid frames."] }),
				R.Outline("styleOutline", { own = L["The game's"],
					tip = L["A black outline around the letters on pages that follow General."] }),
				R.Shadow("styleShadow")),
		} },
		{ id = "bars", label = L["Bars"], region = function(p) return Shown(p, "plateBar") end, groups = {
			R.Group("Bar",
				R.Texture(ns.ThemeQuickField("styleTexture"), { label = L["Bar texture"], default = FieldReset,
					tip = L["The bar texture for pages that follow General."] }),
				R.Choice(ns.ThemeQuickField("styleBarShape"), L["Bar shape"], {
					{ "square", L["Square"] }, { "capsule", L["Capsule"] }, { "chisel", L["Chiseled"] },
					{ "soft", L["Soft"] }, { "bevel", L["Beveled"] } },
					{ default = FieldReset, tip = L["The shape of unit frame and resource bar ends."] })),
		} },
		{ id = "shapes", label = L["Panels and buttons"], groups = {
			R.Group("Look",
				R.Drop(ns.ThemeQuickField("stylePanel"), L["Panel shape"], PANEL_SHAPES,
					{ default = FieldReset, tip = L["The outline of tooltips, chat bubbles, dialogue and roll panels."] }),
				-- (The Action Bars page's Shape row, ActionBarStyle.lua.)
				R.Choice(ns.ThemeQuickField("abShape"), L["Button shape"], {
					{ "game", L["The game's"] }, { "square", L["Square"] }, { "round", L["Round"] } },
					{ default = FieldReset, tip = L["The shape of the action buttons."] }),
				-- (The game's own nameplate Style, retail's Options > Nameplates: held while
				-- one's picked, PlateHealthStyle.lua. Only where the client has it.)
				R.Drop("stylePlate", L["Nameplate style"], function()
					local list = { { value = "game", text = L["The game's"], tip = L["Whatever the game's own Options have."] } }
					for i, name in ipairs(ns.GamePlateStyles and ns.GamePlateStyles() or {}) do
						list[#list + 1] = { value = i - 1, text = L[name] }
					end
					return list
				end, { tip = L["The size and shape of the game's nameplates."],
					shown = function() return ns.GamePlateStyles and ns.GamePlateStyles() ~= nil end })),
		} },
		{ id = "border", label = L["Border"], region = function(p) return Shown(p, "plateBar") end, groups = {
			R.Group("Border", R.Border("styleBorder", { game = true,
				tip = L["The border around bars, panels and buttons that follow General."] })),
		} },
	},
})

-- Overrides ----------------------------------------------------------------------------
do
	local IDS = { "you", "target", "pet", "plates", "bars" }
	local parts = {}
	local tabKeys = ns.STYLE_OVERRIDE_TAB_KEYS or {}
	for i, section in ipairs(ns.StyleOverrideSections and ns.StyleOverrideSections() or {}) do
		local tabKey = tabKeys[i]
		local function TabOn() return not tabKey or ns.PageOn(tabKey) end
		local props = {}
		if tabKey then
			-- (Its tab's switch, the folder tab's right-click before: ns.TabContainer. A
			-- field that's always "as it is" to Reset: a reset leaves switches be, as
			-- Reset page always has.)
			local field = {
				get = function() local db = ns.GetDB() return db ~= nil and db[tabKey] ~= false end,
				set = function(value) ns.GetDB()[tabKey] = value and true or false end,
			}
			-- (Short: "Use these overrides" was cut off in its row, run q66f9.)
			props[1] = R.Switch(field, L["Overrides"], { tip = L["Turns this part's overrides on or off."],
				default = function(k) return k.get() end })
		end
		for _, row in ipairs(section[2]) do
			local p = R.Shown(row[1], { test = TabOn })
			p.label = row[2]
			props[#props + 1] = p
		end
		parts[#parts + 1] = { id = IDS[i] or ("tab" .. i), label = section[1], groups = { R.Group("Look", unpack(props)) } }
	end
	ns.StyleFrame("overrides", {
		label = L["Overrides"], band = "General", sub = "Themes", subRank = 0, page = "Style Overrides", switch = "styleOverrides",
		refresh = function()
			if ns.ApplyUnitFrameParts then ns.ApplyUnitFrameParts() end
			if ns.ApplyBarArtOverride then ns.ApplyBarArtOverride() end
			if ns.RefreshActionBarStyle then ns.RefreshActionBarStyle() end
		end,
		parts = parts,
	})
end

-- Trackers & bars (Interface Recolor) --------------------------------------------------
do
	-- (Its colors are the theme's ring color: with the game's look, nothing to color.)
	local function Ringed() return ns.ThemeRing and ns.ThemeRing() ~= nil end
	local function S(key, label, tip) return R.Switch(key, label, { tip = tip, test = Ringed }) end
	local parts = {
		{ id = "tracker", label = L["Quest tracker"], groups = {
			R.Group("Look",
				S("qtHeaders", L["Header bars"], L["Gives the quest tracker's header bars the theme's panel look."]),
				S("qtTitles", L["Quest name color"], L["Colors quest names in the theme's color."])),
			R.Group("Text", S("qtFont", L["Text font"], L["Uses General's text font for the quest tracker headers."])),
			R.Group("Bar", S("qtBars", L["Bars and buttons"],
				L["Uses General's bar texture for progress bars, and the theme's color for the fold buttons."])),
		} },
	}
	-- (The game's own damage meter: only on clients that have it.)
	if _G.C_DamageMeter then
		parts[#parts + 1] = { id = "meter", label = L["Damage meter"], groups = {
			R.Group("Look", S("dmFrame", L["Frame color"], L["Colors the damage meter's frame in the theme's color."])),
			R.Group("Text", S("dmFont", L["Text font"], L["Uses General's text font for its names and numbers."])),
			R.Group("Bar", S("dmBars", L["Bar texture"], L["Uses General's bar texture for its bars, each in its own color."])),
		} }
	end
	-- (Classic clients' own swing timer: none on retail.)
	if not ns.isRetail then
		parts[#parts + 1] = { id = "swing", label = L["Swing timer"], groups = {
			R.Group("Look", S("swFrame", L["Frame color"], L["Colors the swing timer frames in the theme's color."])),
			R.Group("Text", S("swFont", L["Text font"], L["Uses General's text font for the bars' text."])),
			R.Group("Bar", S("swBars", L["Bar texture"],
				L["Uses General's bar texture for the bars' fill, with each weapon in its own color."])),
		} }
	end
	parts[#parts + 1] = { id = "xp", label = L["XP and reputation bars"], groups = {
		R.Group("Look", S("irStatus", L["Frame color"], L["Colors the XP and reputation bar frames in the theme's color."])),
		R.Group("Text", S("xpFont", L["Text font"], L["Uses General's text font for their numbers."])),
		R.Group("Bar", S("xpBars", L["Bar color"], L["Colors the experience bar's fill in the theme's mana color."])),
	} }
	parts[#parts + 1] = { id = "raid", label = L["Raid frames"], groups = {
		R.Group("Look", S("irRaidFrame", L["Frame color"], L["Colors the raid and party frame borders in the theme's color."])),
		R.Group("Bar", S("irRaidHealth", L["Health bars"], L["Colors the health bars in the theme's color."])),
		R.Group("Background", S("irRaidGround", L["Background"], L["Shades the dark behind each health bar in the theme's color."])),
	} }
	parts[#parts + 1] = { id = "recolor", label = L["Recolor"], groups = {
		R.Group("Look",
			S("irBarArt", L["Action bar art"], L["The gryphons (or wyverns) at the ends of action bar 1, and " ..
				"the band its buttons sit on."]),
			S("irChat", L["Chat"], L["The chat windows' tabs, the box you type in and their buttons."]),
			S("irBuffs", L["Buffs"], L["Colors the buff borders by the minimap in the theme's color."]),
			S("irMicro", L["Menu and bag buttons"], L["Colors the frames around the menu and bag buttons in the theme's color."]),
			S("irCast", L["Your cast bar"], L["Colors your cast bar's frame in the theme's color."]),
			S("irSmall", L["Small windows"], L["Popups, the loot window, the ready check, the game menu and the " ..
				"queue's eye."]),
			S("irBig", L["Big windows"], L["Colors the frames of your bags, the map and the game's other big windows."])),
	} }
	ns.StyleFrame("recolor", {
		label = L["Trackers & bars"], band = "Interface", sub = "Info", subRank = 4, page = "Interface Recolor",
		switch = "irStyle",
		refresh = function()
			if ns.RefreshInterfaceRecolor then ns.RefreshInterfaceRecolor() end
			if ns.RefreshMinimapStyle then ns.RefreshMinimapStyle() end
			if ns.RefreshQuestTrackerStyle then ns.RefreshQuestTrackerStyle() end
		end,
		status = function()
			if not Ringed() then
				return L["These colors come from a theme: with the game's look there's nothing to color. Pick a theme."], "warn",
					L["Open"], function() ns.OpenOptions("Style Themes") end
			end
		end,
		parts = parts,
	})
end

-- Minimap ------------------------------------------------------------------------------
do
	local function Ringed() return ns.ThemeRing and ns.ThemeRing() ~= nil end
	local function Square(db) return db.mmSquare == true end
	local function Bordered(db) return Square(db) and (tonumber(db.mmSquareBorderSize) or 0) > 0 end
	-- (The border color also colors the round map's button rings, with a theme that
	-- has no ring color: so not greyed then. Audit 2026-11-25; MinimapStyle's Refresh.)
	local function ColorUsed(db) return Bordered(db) or (db.mmButtons ~= false and not Ringed()) end
	local map = { R.Slider("mmScale", L["Size"], 50, 200, 5, "%", { scale = 100, tip = L["How big the minimap is."] }),
		R.Switch("mmSquare", L["Square minimap"], { tip = L["Makes the minimap square."], client = "forever" }),
		R.Switch("mmShade", L["Shade inside the edge"], { tip = L["A little shading just inside the ring, so the map looks set into it."],
			test = function(db) return Ringed() and not Square(db) end }) }
	-- (The Hide rows under a Hide heading, their old names: for good, not just in CineMode.)
	local function Hide(...)
		local group = R.Group("Look", ...)
		group.label = "Hide"
		return group
	end
	local hide = Hide(R.Switch("mmHideZoom", L["Zoom buttons"], { tip = L["Hides the minimap's zoom buttons."] }),
		-- (WoW Forever's day and night dial.)
		R.Switch("mmHideDial", L["Day and night dial"], { tip = L["Hides the day and night dial on the minimap's edge."],
			shown = function() local c = _G.MinimapCluster return type(c) == "table" and c.DielFrame ~= nil end }))
	local parts = {
		{ id = "map", label = L["Map"], region = function(p) return p.map end, groups = { R.Group("Look", unpack(map)), hide } },
	}
	if not ns.isRetail then -- (the square map: untested on retail, hidden there)
		parts[#parts + 1] = { id = "border", label = L["Border"], region = function(p) return p.map end, groups = {
			R.Group("Border",
				R.Slider("mmSquareBorderSize", L["Size"], 0, 6, 1, "px",
					{ tip = L["How thick the border round the square minimap is. 0: no border."], test = Square }),
				R.Color("mmBorderColor", L["Color"], { { "theme", L["Theme"] }, { "black", L["Black"] }, { "white", L["White"] },
					{ "gold", L["Gold"] }, { "class", L["Class color"] } }, nil, nil,
					{ tip = L["Theme uses your theme's ring color, or black when it has none."], test = ColorUsed })),
		} }
	end
	parts[#parts + 1] = { id = "buttons", label = L["Ring buttons"], region = function(p) return p.buttons and p.buttons[1] end, groups = {
		R.Group("Look", R.Switch("mmButtons", L["Color the buttons' rings"],
			{ tip = L["Colors the rings around minimap buttons in your theme's ring color, or the border color when it has none."] })),
	} }
	parts[#parts + 1] = { id = "zone", label = L["Zone bar"], region = function(p) return p.zone end, groups = {
		R.Group("Look",
			R.Switch("mmZoneBar", L["Zone bar in the theme's look"], { tip = L["Gives the zone name bar the theme's panel look."],
				test = function(db) return Ringed() and db.mmHideZoneBar ~= true end }),
			R.Note(L["Shade and the zone bar's look come with themes that have a ring color."],
				{ shown = function() return not Ringed() end })),
		Hide(R.Switch("mmHideZoneBar", L["Zone bar"], { tip = L["Hides the zone name bar over the minimap."] })),
		R.Group("Place", R.Switch("mmHeaderInside", L["Zone name and clock inside"],
			{ tip = L["Puts the zone name at the top of the square minimap and the clock in its corner."], client = "forever",
				test = function(db) return Square(db) and db.mmHideZoneBar ~= true end })),
	} }
	ns.StyleFrame("minimap", {
		label = L["Minimap"], band = "Interface", sub = "Info", subRank = 5, page = "Minimap Style", switch = "minimapStyle",
		refresh = function() if ns.RefreshMinimapStyle then ns.RefreshMinimapStyle() end end,
		preview = function(parent, width) return ns.MakeMinimapPreview(parent, width) end,
		parts = parts,
	})
end
end) -- (ns.Module "style")
