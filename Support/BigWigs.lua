-- Cinematic: BigWigs (and LittleWigs, its dungeon and delve fights, which run
-- on BigWigs' own frames). None of its windows is named, so each row finds
-- its frame among UIParent's unnamed children by what's on it:
--  - Timer bars: unlike DBM's, each bar is a frame of its own on UIParent
--    (LibCandyBar's), only placed by its anchors, so each is found by the
--    BigWigs fight it was started for (its "bigwigs:module" value). Bars are
--    made at the first timers and reused after, so a new one can show for a
--    moment before the next scan finds it.
--  - Info box, alternate power, proximity and battle res: one frame each,
--    found by the parts it keeps on itself.
-- Its messages and the big countdown aren't faded, like the game's raid
-- warnings. It leaves its frames' alpha alone, so they aren't hooked.
local _, ns = ...
local L = ns.L

local function Usable(frame)
	return not (frame.IsForbidden and frame:IsForbidden())
end

for _, known in ipairs({
	{
		key = "bigwigsBars", label = "BigWigs timer bars", short = "BigWigs bars",
		about = L["its timer bars"],
		note = L["Its messages aren't faded, like the game's raid warnings."],
		match = function(frame)
			if not Usable(frame) or type(frame.candyBarBar) ~= "table" or type(frame.Get) ~= "function"
				or type(frame.data) ~= "table" then
				return false
			end
			return frame:Get("bigwigs:module") ~= nil
		end,
	},
	{
		key = "bigwigsInfo", label = "BigWigs info box", short = "BigWigs info box",
		about = L["its info box"],
		match = function(frame)
			return Usable(frame) and frame.display2 ~= nil and frame.headerFrame ~= nil and frame.xxx1 ~= nil
		end,
	},
	{
		key = "bigwigsAltPower", label = "BigWigs alternate power", short = "BigWigs alt power",
		about = L["its alternate power list"],
		match = function(frame)
			return Usable(frame) and frame.expand ~= nil and frame.bar ~= nil and frame.bg ~= nil
				and frame.title ~= nil
		end,
	},
	{
		key = "bigwigsProximity", label = "BigWigs proximity", short = "BigWigs proximity",
		about = L["its proximity window"],
		match = function(frame)
			return Usable(frame) and frame.ability ~= nil and frame.sound ~= nil and frame.tooltip ~= nil
		end,
	},
	{
		key = "bigwigsBattleRes", label = "BigWigs battle res", short = "BigWigs battle res",
		about = L["its battle res timer"],
		match = function(frame)
			return Usable(frame) and frame.cdText ~= nil and frame.chargesText ~= nil and frame.cooldown ~= nil
				and frame.updater ~= nil
		end,
	},
}) do
	known.addon, known.suite = "BigWigs", "BigWigs"
	table.insert(ns.ADDON_FRAMES, known)
end
