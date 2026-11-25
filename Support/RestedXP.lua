-- Cinematic: RestedXP Guides, whose guide window stands in for the game's
-- quest tracker. Its guide, quest item and target buttons, level splits and
-- waypoint arrow are a row each on the Addons page. The guide, buttons and
-- splits rode on the HUD page's Quest tracker row before (till 2026-11-19),
-- so until set they take that row's ticks (follows). The arrow starts as a
-- new row does: players keep it up to find their way while the guide fades,
-- as TomTom's arrow.
--
-- The guide (its mouseover fading), the arrow and the splits (their opacity
-- settings) set their own alpha: they're its own frames, so they're hooked.
local _, ns = ...
local L = ns.L

for _, known in ipairs({
	{ key = "rxpGuide", label = "RestedXP guide", about = L["its guide window"], names = { "RXPFrame" },
		follows = "quests" },
	{ key = "rxpItem", label = "RestedXP quest item", about = L["its quest item button"], names = { "RXPItemFrame" },
		follows = "quests" },
	{ key = "rxpTarget", label = "RestedXP targets", about = L["its target buttons"], names = { "RXPTargetFrame" },
		follows = "quests" },
	{ key = "rxpSplits", label = "RestedXP level splits", about = L["its level splits"],
		follows = "quests" },
	{ key = "rxpArrow", label = "RestedXP arrow", about = L["its waypoint arrow"], names = { "RXPG_ARROW" } },
}) do
	known.addon, known.suite, known.short, known.hookAlpha = "RXPGuides", "RestedXP Guides", known.label, true
	table.insert(ns.ADDON_FRAMES, known)
end

-- Its level splits window (off until turned on in its options) lost its own
-- name in v4.11: it's one of its small windows, named in the order they're
-- made (RXPV2MiniFrame1, 2...), as its quest item and target windows are
-- (those still get a name of their own). Found by the background setting
-- only the splits window carries; it joins its row while that row is on, as
-- a named row frame would.
local function IsSplitsWindow(frame)
	local widget = type(frame) == "table" and rawget(frame, "obj")
	return type(widget) == "table" and rawget(widget, "hideBackgroundSetting") == "hideSplitsBackground"
end

ns.WhenAddonLoads("RXPGuides", function()
	ns.AddScanner(function()
		if not ns.IsAddonFramesOn("rxpSplits") then return end
		for i = 1, 20 do
			local frame = _G["RXPV2MiniFrame" .. i]
			if frame == nil then break end
			if IsSplitsWindow(frame) and not ns.IsFaded(frame) then
				ns.AddFoundFrame(frame, "addon:rxpSplits", true, true)
			end
		end
	end)
end)

-- It hooks the bag and quest log toggles after the game's (hooksecurefunc:
-- its bag helpers, its quest log cleanup button), so those globals are a new
-- function, but the game's still runs first. Ours on them hook (Shoulder Cam's
-- bag hold) or call the global (Reload reopening the quest log): both fine.
-- (Literal strings: Tools/addon-kit/diff.py reads these from this file's text.)
ns.AddonKitExpect("RXPGuides", "touch.ToggleAllBags", "sameAsLogin", "its hooksecurefunc: the game's still runs first")
ns.AddonKitExpect("RXPGuides", "touch.ToggleBag", "sameAsLogin", "its hooksecurefunc: the game's still runs first")
ns.AddonKitExpect("RXPGuides", "touch.ToggleQuestLog", "sameAsLogin", "its hooksecurefunc: the game's still runs first")
