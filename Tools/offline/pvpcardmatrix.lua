-- Entering a PvP fight's card vs Entering combat's, every state (the audit
-- kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-23-pvp-card-needs-combat.md):
--   python -I Tools/offline/run.py Tools/offline/pvpcardmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/pvpcardmatrix.lua --base <ref>
-- A fight starts against a mob or an enemy player (your target), with Card
-- Vision on or off, the Entering combat row on or off and the PvP fight row on
-- or off. Each cell: the card that plays (combatIn, combatPvp or none).
-- The rule (release review 2026-11-23, the user's OK to fix): the PvP card
-- plays in place of Entering combat's, so with Entering combat unticked no
-- fight card plays at all, against players too.
local client = arg and arg[1] or "forever"
local units = {}
-- luacheck: push ignore 111 112 113 121 122 212
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function()
	C_Timer.After = function() end
	IsInInstance = function() return false, "none" end
	UnitExists = function(unit)
		local base = unit:match("^(.-)target$")
		if base and base ~= "" then return false end
		return units[unit] ~= nil
	end
	UnitGUID = function(unit) return units[unit] and units[unit].guid or nil end
	UnitIsPlayer = function(unit) return units[unit] and units[unit].player or false end
	UnitCanAttack = function(_, unit) return units[unit] and units[unit].enemy or false end
	UnitIsUnit = function() return false end
end)
-- luacheck: pop

local played
local Fire = ns.Cards.Fire
-- (The card fired, if it's allowed to show: Fire's own return also counts
-- waits and the stand-in's screen, so its row's answer, ns.CardAllowed.)
ns.Cards.Fire = function(id, card, ...)
	if (id == "combatIn" or id == "combatPvp") and ns.CardAllowed(id, "enter") then played = id end
	return Fire(id, card, ...)
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "pvpcard-fight",
	fixed = { client = client },
	dims = {
		{ "cards", { "on", "off" } },
		{ "enter", { "on", "off" } },
		{ "pvp", { "on", "off" } },
		{ "foe", { "mob", "player" } },
	},
	cell = function(c)
		ns.db.cards = c.cards == "on"
		ns.db.combatOnEnter = c.enter == "on"
		ns.db.cardCombatPvpOn = c.pvp == "on"
		for k in pairs(units) do units[k] = nil end
		units.target = c.foe == "player" and { guid = "Player-1-0001", player = true, enemy = true }
			or { guid = "Creature-0-1-2-3-4-5", player = false, enemy = true }
		played = nil
		ns.CardFightCard(true)
		if ns.Cards.Current and ns.Cards.Stop then pcall(ns.Cards.Stop) end
		return "card=" .. (played or "none")
	end,
	pins = {
		-- (Entering combat unticked, or Card Vision off: no fight card at all.)
		{ "", "card=none" },
		-- (Entering combat on: its card against a mob, and against a player with the PvP row off.)
		{ "cards=on enter=on", "card=combatIn" },
		-- (Both rows on, against a player: the PvP card in its place.)
		{ "cards=on enter=on pvp=on foe=player", "card=combatPvp" },
	},
})
