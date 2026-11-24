-- Entering a PvP fight's card vs Entering combat's Show in rows, every state
-- (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-23-pvp-card-where-combat.md):
--   python -I Tools/offline/run.py Tools/offline/pvpcardrowmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/pvpcardrowmatrix.lua --base <ref>
-- Card Vision, Entering combat ticked; a fight starts against a mob or an
-- enemy player (your target), the PvP fight row on or off, and each card's
-- Show in row saying here or not (Entering combat's limited to dungeons,
-- say, out in the world). Each cell: the card that plays (combatIn,
-- combatPvp or none). The rule (e902b95, release review 2026-11-23): the
-- PvP card plays only in place of Entering combat's, so where Entering
-- combat's Show in row says no, no fight card plays, against players too.
-- (Ticks on and off: Tools/offline/pvpcardmatrix.lua.)
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

local rows = {}
local RowOnNow = ns.RowOnNow
ns.RowOnNow = function(row, ...)
	if rows[row] ~= nil then return rows[row] end
	return RowOnNow(row, ...)
end

local played
local Fire = ns.Cards.Fire
-- (The card fired, if it's allowed to show: its row's answer, ns.CardAllowed.)
ns.Cards.Fire = function(id, card, ...)
	if (id == "combatIn" or id == "combatPvp") and ns.CardAllowed(id, "enter") then played = id end
	return Fire(id, card, ...)
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "pvpcard-rows",
	fixed = { client = client },
	dims = {
		{ "enterRow", { "here", "not" } },
		{ "pvp", { "on", "off" } },
		{ "pvpRow", { "here", "not" } },
		{ "foe", { "mob", "player" } },
	},
	cell = function(c)
		ns.db.cards = true
		ns.db.combatOnEnter = true
		ns.db.cardCombatPvpOn = c.pvp == "on"
		rows["card:combatIn"] = c.enterRow == "here"
		rows["card:combatPvp"] = c.pvpRow == "here"
		for k in pairs(units) do units[k] = nil end
		units.target = c.foe == "player" and { guid = "Player-1-0001", player = true, enemy = true }
			or { guid = "Creature-0-1-2-3-4-5", player = false, enemy = true }
		played = nil
		ns.CardFightCard(true)
		if ns.Cards.Current and ns.Cards.Stop then pcall(ns.Cards.Stop) end
		return "card=" .. (played or "none")
	end,
	pins = {
		-- (Entering combat's Show in row says not here: no fight card at all.)
		{ "", "card=none" },
		-- (It says here: its card, against a mob, with the PvP row off or its Show in row saying no.)
		{ "enterRow=here", "card=combatIn" },
		-- (Both say here, the PvP row on, against a player: the PvP card in its place.)
		{ "enterRow=here pvp=on pvpRow=here foe=player", "card=combatPvp" },
	},
})
