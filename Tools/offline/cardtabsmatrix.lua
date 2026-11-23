-- Card Vision's Events tabs before the page is opened (the audit kit's
-- matrix, Tools/offline/matrix.lua; fix card Tools/audits/2026-11-23-card-tabs-lazy.md):
--   python -I Tools/offline/run.py Tools/offline/cardtabsmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/cardtabsmatrix.lua --base <ref>
-- After a login or /reload, Card Vision's settings page not opened yet: Card
-- Vision on or off, one Events tab's switch (as saved) on or off, and a card
-- on that tab ticked. Each cell: whether the card's row reads on
-- (ns.Setting, what every card asks).
-- The rule (the switch tree, release review 2026-11-23): on only with Card
-- Vision, its tab and its own tick on, opened or not.
local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local db = ns.db

-- (Each tab: its switch and a card on it.)
local TABS = {
	combat = { tab = "tabOn:Card Vision/events:1", key = "cardDeathOn" },
	bosses = { tab = "tabOn:Card Vision/events:2", key = "cardRareOn" },
	places = { tab = "tabOn:Card Vision/events:3", key = "cardRestedOn" },
	story = { tab = "tabOn:Card Vision/events:4", key = "cardQuestOn" },
	progress = { tab = "tabOn:Card Vision/events:5", key = "cardLevelUpOn" },
	pvp = { tab = "tabOn:Card Vision/events:6", key = "cardDuelOn" },
}

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "cardtabs-unopened",
	fixed = { client = client },
	dims = {
		{ "tab", { "combat", "bosses", "places", "story", "progress", "pvp" } },
		{ "cards", { "on", "off" } },
		{ "tabSwitch", { "on", "off" } },
	},
	cell = function(c)
		local t = TABS[c.tab]
		db.cards = c.cards == "on"
		db[t.tab] = c.tabSwitch == "on"
		db[t.key] = true
		local out = ns.Setting(t.key) and "on" or "off"
		db[t.tab], db.cards = true, true
		return out
	end,
	pins = {
		{ "", "off" },
		{ "cards=on tabSwitch=on", "on" },
	},
})
