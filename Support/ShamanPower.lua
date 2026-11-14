-- Cinematic: ShamanPower, a shaman's totem bar, shield and cooldown buttons
-- (WoW Forever). Its totem bar stands in for the game's, so it fades with the
-- Totem bar row on the Standard Frames page. Its cooldown bar has no game bar
-- to follow and gets a row of its own on the Advanced Frames page.
--
-- Its totem buttons sit on the bar but ignore the bar's alpha, so each is
-- listed by name, with the bar's Drop All and shield buttons. All of them set
-- their own alpha (its opacity sliders, its own combat and target fades, full
-- opacity while a totem is down), so they're hooked: faded, it's ours times
-- its own. Its flyouts only open while the bar is hovered, so they're left be.
-- Its optional modules (trackers, alerts, range strips) aren't listed.
local _, ns = ...
local L = ns.L

table.insert(ns.ADDON_FRAMES, {
	key = "shamanPowerCooldowns", addon = "ShamanPower", suite = "ShamanPower",
	label = "ShamanPower cooldown bar", short = "ShamanPower cooldowns",
	about = L["its cooldown bar"],
	note = L["Its totem bar fades with the Totem bar row on the Standard Frames page."],
	names = { "ShamanPowerCooldownBar" },
	hookAlpha = true,
})

ns.WhenAddonLoads("ShamanPower", function()
	ns.FadeWithRows({
		{ "totems", "bars", "ShamanPowerAuto", "ShamanPowerAutoDropAll",
			"ShamanPowerTotemBtn1", "ShamanPowerTotemBtn2", "ShamanPowerTotemBtn3", "ShamanPowerTotemBtn4",
			"ShamanPowerEarthShieldBtn", "ShamanPowerCompactShieldBtn" },
	})
end)
