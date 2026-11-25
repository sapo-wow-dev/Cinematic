-- Style Studio frames: the Atmosphere band, Tint, Letterbox and Weather (their Style
-- tabs: Style/TintStyle.lua, Style/LetterboxStyle.lua). Every look setting those pages
-- had, by its db key, in the recipes' order. The Tint page's data editors (your own
-- tints, each place's mood, the day's colors) edit lists, not keys: they stay its own
-- UI under the editor, shown with the part they belong to.
local _, ns = ...
ns.Module("style", function()
local L = ns.L
local R = ns.Studio.R

-- (Their pages and pictures need the Atmosphere part: left out, none built, Modules.lua.)
local function Atmosphere() return not ns.ModuleLoaded or ns.ModuleLoaded("atmosphere") end

-- Tint -------------------------------------------------------------------------------
local TIME_LOOKS = { timeofday = true, zonetime = true }
local ZONE_LOOKS = { zone = true, zonetime = true }

ns.StyleFrame("tint", {
	label = L["Tint"], band = "Atmosphere", sub = "Effects", page = "Tint Style", switch = "tintStyle", shown = Atmosphere,
	refresh = function() if ns.RefreshTint then ns.RefreshTint() end end,
	preview = function(parent, width) return ns.MakeTintPreview(parent, width) end,
	parts = {
		{ id = "look", label = L["Look"], region = function(p) return p.scene end, groups = {
			R.Group("Look",
				{ kind = "tiles", label = L["Look"], key = "tintPreset", few = 4, syn = "preset color grading",
					tip = L["The color grading: a main look, a one-color look or a tint of your own."],
					options = function() return ns.TintLookChoices and ns.TintLookChoices() or {} end },
				R.Slider("tintStrength", L["Strength"], 5, 100, 1, "%", { scale = 100,
					tip = L["How strongly the tint colors the world, for every look."] })),
		} },
		{ id = "time", label = L["Time of day"], groups = {
			R.Group("Look",
				R.Note(L["Not in your look: pick Time of day or Zone + time of day."],
					{ shown = function(db) return not TIME_LOOKS[db.tintPreset] end }),
				R.Choice("tintClock", L["Clock"], {
					{ "game", L["Game time"], L["Follows the game's own day and night."] },
					{ "local", L["My clock"], L["Follows your computer's clock."] } },
					{ tip = L["Which clock the time of day follows."] }),
				R.Slider("timeTintStrength", L["Strength"], 0, 100, 5, "%", { scale = 100,
					tip = L["How strongly the time-of-day part applies."], syn = "time of day strength" })),
		} },
		{ id = "zones", label = L["Zones"], groups = {
			R.Group("Look",
				R.Note(L["Not in your look: pick Zone or Zone + time of day."],
					{ shown = function(db) return not ZONE_LOOKS[db.tintPreset] end }),
				R.Note(L["Each place's mood: set on the Tint Style page, under these settings."])),
		} },
	},
})

-- Letterbox --------------------------------------------------------------------------
local function ByHeight(db) return db.letterboxSizeBy ~= "aspect" end
local function SizeGroup(...)
	local group = R.Group("Look", ...)
	group.label = "Size"
	return group
end

ns.StyleFrame("letterbox", {
	label = L["Letterbox"], band = "Atmosphere", sub = "Effects", page = "Letterbox Style", switch = "letterboxStyle", shown = Atmosphere,
	refresh = function()
		-- (Linked, the bottom bar keeps the top's height, as the page's two boxes did:
		-- unlinked, it starts from the height it showed.)
		local db = ns.GetDB()
		if db and db.letterboxLinked ~= false then db.letterboxSizeBottom = db.letterboxSize end
		if ns.RefreshLetterbox then ns.RefreshLetterbox() end
	end,
	preview = function(parent, width) return ns.MakeLetterboxPreview(parent, width) end,
	test = function() if ns.TestLetterboxPreviews then ns.TestLetterboxPreviews() end end,
	parts = {
		{ id = "bars", label = L["Bars"], region = function(p) return p.bars and p.bars.top end, groups = {
			SizeGroup(
				R.Choice("letterboxSizeBy", L["Set by"], {
					{ "height", L["Height"], L["Each bar a share of the screen's height."] },
					{ "aspect", L["A film's frame"], L["Shapes the space between the bars like a movie screen, on any monitor."] } },
					{ tip = L["How the bars' height is set."] }),
				R.Slider("letterboxSize", L["Top bar"], 0, 25, 1, "%", { scale = 100, test = ByHeight,
					tip = L["How tall the top bar is, as a share of the screen's height."] }),
				R.Switch("letterboxLinked", L["Same top and bottom"], { test = ByHeight,
					tip = L["Both bars the same height, the top bar's."] }),
				R.Slider("letterboxSizeBottom", L["Bottom bar"], 0, 25, 1, "%", { scale = 100,
					test = function(db) return ByHeight(db) and db.letterboxLinked == false end,
					tip = L["How tall the bottom bar is, as a share of the screen's height."] }),
				R.Choice("letterboxAspect", L["Frame"], { { 2.39, L["2.39:1 (cinema)"] }, { 2, L["2:1"] }, { 1.85, L["1.85:1"] } },
					{ test = function(db) return db.letterboxSizeBy == "aspect" end,
						tip = L["The film's frame the space between the bars takes."] })),
			R.Group("Bar",
				R.Color("letterboxColor", L["Color"], { { "black", L["Black"] }, { "custom", L["Custom"] } },
					{ "letterboxR", "letterboxG", "letterboxB" }, "custom", { tip = L["The bars' color."] }),
				R.Slider("letterboxAlpha", L["Opacity"], 10, 100, 5, "%", { scale = 100, tip = L["How see-through the bars are."] })),
		} },
		{ id = "edge", label = L["Edge"], region = function(p) return p.bars and p.bars.topFeather end, groups = {
			R.Group("Look",
				R.Choice("letterboxEdge", L["Inner edge"], { { "hard", L["Hard"] },
					{ "soft", L["Soft (feathered)"], L["The bars fade into the scene past their edge."] } },
					{ tip = L["The bars' inner edge: sharp, or fading into the scene."] }),
				R.Slider("letterboxFeather", L["Feather"], 5, 80, 5, "px", { test = function(db) return db.letterboxEdge == "soft" end,
					tip = L["How far past the bars' edge they fade into the scene."] })),
		} },
		{ id = "line", label = L["Line"], region = function(p) return p.bars and p.bars.topLine end, groups = {
			R.Group("Border",
				R.Color("letterboxLine", L["Line"], { { "none", L["None"] }, { "gold", L["Gold"] }, { "custom", L["Custom"] } },
					{ "letterboxLineR", "letterboxLineG", "letterboxLineB" }, "custom",
					{ tip = L["A line along the bars' inner edge."] })),
		} },
		{ id = "motion", label = L["Coming in and going"], groups = {
			R.Group("Motion",
				R.Choice("letterboxMotion", L["How"], { { "slide", L["Slide in"], L["The bars grow in from the screen's edges."] },
					{ "fade", L["Fade in"], L["The bars fade in at their full height."] } },
					{ tip = L["How the bars come in and go."] }),
				R.Slider("letterboxTime", L["How long"], 0, 3, 0.1, "s", { words = { [0] = L["With the UI"] },
					tip = L["How long the bars take to come in or go. At 0, with the UI's fade."] })),
		} },
	},
})

-- Weather ----------------------------------------------------------------------------
local weatherParts = {}
for _, name in ipairs({ "Rain", "Snow", "Sandstorm" }) do -- (ns.WEATHER_NAMES: the Weather Style page's weather<Name>R/G/B)
	weatherParts[#weatherParts + 1] = { id = name:lower(), label = L[name],
		region = function(p) local pane = p.paneOf and p.paneOf[name] return pane and pane.sky end,
		groups = { R.Group("Look", R.Swatch(L["Color"], { "weather" .. name .. "R", "weather" .. name .. "G", "weather" .. name .. "B" },
			{ tip = L["This weather's tint. White is no change; darker colors darken the scene more."] })) } }
end
weatherParts[#weatherParts + 1] = { id = "blend", label = L["Coming in and going"], groups = {
	R.Group("Motion", R.Slider("weatherBlendTime", L["How long"], 1, 20, 1, "s",
		{ tip = L["How long the weather's tint takes to come in, or to go as it clears or you step inside."] })) } }

ns.StyleFrame("weather", {
	label = L["Weather"], band = "Atmosphere", sub = "Effects", page = "Weather Style", switch = "weatherStyle", shown = Atmosphere,
	refresh = function() if ns.RefreshTint then ns.RefreshTint() end end,
	preview = function(parent, width) return ns.MakeWeatherPreview(parent, width) end,
	-- Test: the real weather tint over the world for a few seconds (the Weather page's pick).
	test = function()
		if not (ns.PreviewEffect and ns.WeatherTypeOf) then return end
		local db = ns.GetDB() or {}
		ns.PreviewEffect("weather", 8, ns.WeatherTypeOf(db.weatherPreviewKind or "Rain"))
	end,
	parts = weatherParts,
})
end) -- (ns.Module "style")
