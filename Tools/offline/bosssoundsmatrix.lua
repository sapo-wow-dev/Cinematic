-- The Boss event's kill and wipe sounds as a boss fight ends (the audit kit's
-- matrix, Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-cards-boss-sounds.md):
--   python -I Tools/offline/run.py Tools/offline/bosssoundsmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/bosssoundsmatrix.lua forever --base <ref>
-- ENCOUNTER_END with a win or a wipe; the Boss event's row ticked or not, its
-- Settings tab and its Sounds tab on or off. Each cell: the sound asked for
-- (kill, wipe) or none. The rule: a sound only with the row ticked, its
-- Settings tab on (CardOn) and its Sounds tab on (as the cards' own sounds,
-- Cards.lua's Show).
local client = arg and arg[1] or "forever"
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local db = ns.db
local played
ns.PlayCombatCueSound = function(edge) played = edge end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "boss-sounds",
	fixed = { client = client },
	dims = {
		{ "result", { "win", "wipe" } },
		{ "row", { "on", "off" } },
		{ "settingsTab", { "on", "off" } },
		{ "soundsTab", { "on", "off" } },
	},
	cell = function(c)
		db.enabled, db.cards = true, true
		db.cardBossOn = c.row == "on"
		db["tabOn:Card:boss:settings"] = c.settingsTab == "on"
		db["tabOn:Card:boss:sounds"] = c.soundsTab == "on"
		played = nil
		wow.Fire("ENCOUNTER_START", 1, "Ragnaros", 1, 20)
		wow.Fire("ENCOUNTER_END", 1, "Ragnaros", 1, 20, c.result == "win" and 1 or 0)
		return "sound=" .. tostring(played or "none")
	end,
	pins = {
		{ "", "sound=none" },
		{ "result=win row=on settingsTab=on soundsTab=on", "sound=kill" },
		{ "result=wipe row=on settingsTab=on soundsTab=on", "sound=wipe" },
	},
})
