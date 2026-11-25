-- Style Studio frame: Tooltips (the Tooltip Style page, Style/TooltipStyle.lua).
-- The reference spec (Tools/style-studio/plan.md section 8): every look setting the
-- page had, by its db key, in the recipes' order.
local _, ns = ...
ns.Module("style", function()
local L = ns.L
local R = ns.Studio.R

local function BarOn(db) return db.tooltipBar ~= "none" end

ns.StyleFrame("tooltips", {
	label = L["Tooltips"], band = "Interface", sub = "Info", subRank = 3, page = "Tooltip Style", switch = "tooltipStyle",
	refresh = function() if ns.RefreshTooltipStyle then ns.RefreshTooltipStyle() end end,
	preview = function(parent, width) return ns.MakeTooltipPreview(parent, width) end,
	looks = {
		{ id = "clean", label = L["Clean"], values = { tooltipEdge = "thin", tooltipBack = "dark", tooltipAlpha = 0.9,
			tooltipOutline = 0, tooltipShadow = "on", tooltipBar = "under" } },
		{ id = "bold", label = L["Bold"], values = { tooltipEdge = "colored", tooltipTextSize = 1.15, tooltipOutline = 1,
			tooltipNames = "class", tooltipBar = "top", tooltipBarHeight = 6 } },
	},
	parts = {
		{ id = "panel", label = L["Panel"], region = function(p) return p.unitTip end, groups = {
			R.Group("Background",
				R.Color("tooltipBack", L["Background"], { { "game", L["The game's"] }, { "dark", L["Dark"] },
					{ "custom", L["Custom"] } }, { "tooltipBackR", "tooltipBackG", "tooltipBackB" }, "custom"),
				R.Slider("tooltipAlpha", L["Opacity"], 20, 100, 5, "%", { scale = 100, tip = L["How see-through the background is."] })),
			R.Group("Border", R.Border("tooltipEdge", { game = true, colored = true,
				tip = L["The tooltip's edge, plain or in the unit's or item's color."] })),
		} },
		{ id = "text", label = L["Words"], region = function(p) return p.unitTip and p.unitTip.lines and p.unitTip.lines[2] end, groups = {
			R.Group("Text",
				R.Font("tooltipFont"),
				R.Slider("tooltipTextSize", L["Size"], 80, 140, 5, "%", { scale = 100, tip = L["How big the words are, next to their usual size."] }),
				R.Choice("tooltipNames", L["Name color"], { { "game", L["The game's"] },
					{ "class", L["Class or reaction"], L["Players' names in class colors, NPCs' in red, yellow or green."] } }),
				R.Outline("tooltipOutline"),
				R.Shadow("tooltipShadow")),
		} },
		{ id = "health", label = L["Health bar"], region = function(p) return p.unitTip and p.unitTip.bar end, groups = {
			R.Group("Bar",
				R.Choice("tooltipBar", L["Position"], { { "under", L["Under it"] }, { "top", L["Along the top"] }, { "none", L["None"] } }),
				R.Texture("tooltipBarTexture", { test = BarOn }),
				R.Color("tooltipBarColor", L["Color"], { { "game", L["The game's"] }, { "custom", L["Custom"] } },
					{ "tooltipBarR", "tooltipBarG", "tooltipBarB" }, "custom", { test = BarOn }),
				R.Choice("tooltipGradient", L["Gradient"], { { "off", L["Off"] }, { "shade", L["Darker"] }, { "on", L["Your color"] } },
					{ test = BarOn }),
				R.Swatch(L["Fades to"], { "tooltipGradR", "tooltipGradG", "tooltipGradB" },
					{ test = function(db) return BarOn(db) and db.tooltipGradient == "on" end }),
				R.Choice("tooltipGradDir", L["Direction"], { { "right", L["Left to right"] }, { "left", L["Right to left"] },
					{ "down", L["Top to bottom"] } }, { test = function(db) return BarOn(db) and db.tooltipGradient ~= "off" end }),
				R.Slider("tooltipBarGround", L["Background"], 0, 100, 5, "%", { scale = 100, tip = L["How dark it is behind the bar."], test = BarOn }),
				R.Slider("tooltipBarHeight", L["Height"], 2, 12, 1, "px", { test = BarOn })),
		} },
	},
})
end) -- (ns.Module "style")
