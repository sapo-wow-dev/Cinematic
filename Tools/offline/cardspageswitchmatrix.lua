-- The Cards page's switch over its rows' switches (Core.lua: PAGE_SWITCH's
-- cards list, read by ns.Setting and ns.PageSetting), every state (the audit
-- kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-23-cards-pvp-page-switch.md):
--   python -I Tools/offline/run.py Tools/offline/cardspageswitchmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/cardspageswitchmatrix.lua --base <ref>
-- Card Vision's switch (cards) on or off, a row's own tick on or off, CineMode
-- on or off with Allow outside CineMode (outsideCineCards) ticked or not; the
-- rows: Entering a PvP fight (cardCombatPvpOn, missing from the list before)
-- and a neighbor, Duel (cardDuelOn). The rule (the user's: a page's switch
-- gates all on it): the page's switch off = every setting on it off; outside
-- CineMode with the tick off, Setting reads off too (PageSetting, the pages'
-- greying, doesn't ask).

local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local db = ns.db

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "cards-page-switch",
	fixed = { client = client },
	dims = {
		{ "row", { "cardCombatPvpOn", "cardDuelOn" } },
		{ "cards", { "on", "off" } },
		{ "tick", { "on", "off" } },
		{ "cine", { "on", "off" } },
		{ "outside", { "on", "off" } },
	},
	cell = function(c)
		local was = ns.lastCinematic
		db.cards = c.cards == "on"
		db[c.row] = c.tick == "on"
		db.outsideCineCards = c.outside == "on"
		ns.lastCinematic = c.cine == "on"
		local out = ("setting=%s page=%s"):format(tostring(ns.Setting(c.row) and true or false),
			tostring(ns.PageSetting(c.row) and true or false))
		ns.lastCinematic = was
		db.cards, db.outsideCineCards = true, true
		return out
	end,
	pins = {
		-- (Its own tick on, Card Vision on: on.)
		{ "tick=on", "setting=true page=true" },
		{ "tick=off", "setting=false page=false" },
		-- (Card Vision off: every row off, the pages' greying too.)
		{ "cards=off", "setting=false page=false" },
		-- (Out of CineMode with Allow outside CineMode off: off, the page still shows its tick.)
		{ "tick=on cards=on cine=off outside=off", "setting=false page=true" },
	},
})
