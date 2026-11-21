-- BattleText Forever (scrolling combat text for WoW Forever): it draws your
-- incoming damage, heals and notices in scroll areas of its own, and turns
-- the game's floating combat text off (enableFloatingCombatText 0) to make
-- room. Text on You (Style/SelfTextStyle.lua) copies the game's text, so with
-- both on: the Addon Conflicts row. Theirs (the default): Text on You stands
-- aside. Ours: Text on You draws, and holds the game's floating text on (it
-- needs it); its incoming area is hidden at alpha 0, its outgoing left be.
-- Read from BattleText Forever 1.29.0 (MIT), 2026-11-21: settings in
-- BattleTextForeverDB (enabled), areas BattleTextForever<Label> frames.

local _, ns = ...

ns.WhenAddonLoads("BattleTextForever", function()
	ns.AddConflict({ key = "style:selftext", addon = "BattleText Forever", label = "Combat text on you", group = "style",
		styleSwitch = "selfTextStyle",
		about = "Your combat text: the Style hub's Text on You page, or BattleText Forever's Incoming, Healing and Notifications areas",
		theirs = function()
			local db = _G.BattleTextForeverDB
			return not (type(db) == "table" and db.enabled == false)
		end,
		ours = function() return ns.StyleOn("selfTextStyle") end,
		hide = { "BattleTextForeverIncoming", "BattleTextForeverHealing", "BattleTextForeverNotifications" },
		onPick = function() if ns.RefreshSelfTextStyle then ns.RefreshSelfTextStyle() end end })
end)
