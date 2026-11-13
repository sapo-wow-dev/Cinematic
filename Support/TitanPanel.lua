-- Cinematic: Titan Panel, info bars along the top and bottom of the screen.
-- Its bars (four full-width ones, ten short ones) are named frames on
-- UIParent, a row each. Each sets its own
-- alpha from its transparency option, so they're hooked: faded, a bar is ours
-- times its own. Its auto-hide strips (Titan_Bar__Hider_...) are invisible
-- hover areas and are left alone.
local _, ns = ...
local L = ns.L

for _, known in ipairs({
	{ key = "titanTop", label = "Titan Panel top bar", short = "Titan top",
		about = L["its top bar"], names = { "Titan_Bar__Display_Bar" } },
	{ key = "titanTop2", label = "Titan Panel second top bar", short = "Titan top 2",
		about = L["its second top bar"], names = { "Titan_Bar__Display_Bar2" } },
	{ key = "titanBottom", label = "Titan Panel bottom bar", short = "Titan bottom",
		about = L["its bottom bar"], names = { "Titan_Bar__Display_AuxBar" } },
	{ key = "titanBottom2", label = "Titan Panel second bottom bar", short = "Titan bottom 2",
		about = L["its second bottom bar"], names = { "Titan_Bar__Display_AuxBar2" } },
}) do
	known.addon, known.suite, known.hookAlpha = "Titan", "Titan Panel", true
	table.insert(ns.ADDON_FRAMES, known)
end

-- Its short bars, ten that can be placed anywhere (off until the player
-- turns one on).
for i = 1, 10 do
	local number = ("%02d"):format(i)
	table.insert(ns.ADDON_FRAMES, {
		key = "titanShort" .. i, addon = "Titan", suite = "Titan Panel", hookAlpha = true,
		label = "Titan Panel short bar " .. i, short = "Titan short " .. i,
		about = L["one of its short bars"],
		names = { "Titan_Bar__Display_Short" .. number },
	})
end
