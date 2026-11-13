-- Cinematic: HealBot Continued, healing frames. It draws up to ten frames of
-- its own on UIParent (f1_HealBot_Action to f10_HealBot_Action, numbered as
-- in its options: which units each shows is the player's choice there), a
-- row each. They're made from the game's secure templates, which take an
-- alpha even in a fight. It only sets the alpha of the parts inside them
-- (range, aggro, auras), never of a frame itself, so they aren't hooked.
-- It can hide the game's party frames; those rows then have nothing to fade.
local _, ns = ...
local L = ns.L

for i = 1, 10 do
	table.insert(ns.ADDON_FRAMES, {
		key = "healbot" .. i, addon = "HealBot", suite = "HealBot Continued",
		label = "HealBot frame " .. i, short = "HealBot " .. i,
		about = L["one of its healing frames"],
		names = { "f" .. i .. "_HealBot_Action" },
	})
end
