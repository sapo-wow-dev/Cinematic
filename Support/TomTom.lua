-- Cinematic: TomTom, waypoints with an arrow on screen. Its arrow and its
-- coordinates box are named frames on UIParent, a row each. Its minimap pins
-- are the minimap's children and go with it.
--
-- The arrow sets its own alpha from its options (an alpha slider), so it's
-- hooked: faded, it's ours times its own. Set to click-through, the arrow
-- turns its mouse off, so it's hovered by where it is on screen.
local _, ns = ...
local L = ns.L

for _, known in ipairs({
	{
		key = "tomtomArrow", label = "TomTom arrow", short = "TomTom arrow",
		about = L["its waypoint arrow"], names = { "TomTomCrazyArrow" }, hookAlpha = true,
	},
	{
		key = "tomtomCoords", label = "TomTom coordinates", short = "TomTom coords",
		about = L["its coordinates box"], names = { "TomTomBlock" },
	},
}) do
	known.addon, known.suite = "TomTom", "TomTom"
	table.insert(ns.ADDON_FRAMES, known)
end

-- (Frames.lua, which makes the list, loads after this file.)
ns.WhenAddonLoads("TomTom", function()
	ns.HOVER_BY_RECT.TomTomCrazyArrow = true
end)
