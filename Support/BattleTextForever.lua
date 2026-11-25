-- BattleText Forever (scrolling combat text for WoW Forever): it draws your
-- incoming damage, heals and notices in scroll areas of its own, and can
-- turn the game's floating combat text off (its hideBlizzard option, off by
-- default since 1.43.0). Text on You (Style/SelfTextStyle.lua) copies the game's text, so with
-- both on: the Addon Conflicts row. Theirs (the default): Text on You stands
-- aside. Ours: Text on You draws, and holds the game's floating text on (it
-- needs it); its incoming area is hidden at alpha 0, its outgoing left be.
-- Read from BattleText Forever 1.29.0 (MIT), 2026-11-21: settings in
-- BattleTextForeverDB (enabled), areas BattleTextForever<Label> frames.
-- Rechecked against 1.43.0, 2026-11-25: a character can have settings of its
-- own (BattleTextForeverCharDB), so the switch is read from the live ones.

local _, ns = ...

ns.WhenAddonLoads("BattleTextForever", function()
	ns.AddConflict({ key = "style:selftext", addon = "BattleText Forever", label = "Combat text on you", group = "style",
		styleSwitch = "selfTextStyle",
		about = "Your combat text: the Style hub's Text on You page, or BattleText Forever's Incoming, Healing and Notifications areas",
		theirs = function()
			-- (Its live settings: a character with settings of its own keeps
			-- its switch in BattleTextForeverCharDB.settings, not in the shared
			-- BattleTextForeverDB. BattleTextForever.db is whichever it uses,
			-- Settings.lua:654-662 in 1.43.0.)
			local addon = _G.BattleTextForever
			local db = type(addon) == "table" and addon.db
			if not (type(db) == "table" and type(db.enabled) == "boolean") then
				local char = _G.BattleTextForeverCharDB
				db = type(char) == "table" and char.own == true and char.settings or _G.BattleTextForeverDB
			end
			return not (type(db) == "table" and db.enabled == false)
		end,
		ours = function() return ns.StyleOn("selfTextStyle") end,
		hide = { "BattleTextForeverIncoming", "BattleTextForeverHealing", "BattleTextForeverNotifications" },
		onPick = function() if ns.RefreshSelfTextStyle then ns.RefreshSelfTextStyle() end end })
end)
