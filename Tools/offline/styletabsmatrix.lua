-- A Style page's tabs over its look (the audit kit's matrix, Tools/offline/matrix.lua;
-- fix card Tools/audits/2026-11-25-style-look-tabs.md):
--   python -I Tools/offline/run.py Tools/offline/styletabsmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/styletabsmatrix.lua forever --base <ref>
-- Chat Bubble Style (read through ns.StyleLook, StylePages.lua): its page's
-- switch, its Bubbles tab and its Behind Bubbles tab, each on or off. Each
-- cell: what the bubbles read (bubblesBack: Dark set, "ours", or "game") and
-- what speech from behind you reads (speechBehindScale: 0.5 set, "ours" or
-- "game"). The rule (a tab is a container): ours only with the page and that
-- setting's own tab on; the other tab off changes nothing.
-- (Audit 2026-11-25, C2: only the page's switch was asked.)

local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local db = ns.db
if ns.MapTabContainers then ns.MapTabContainers() end -- (a timer in game)
local TAB1, TAB2 = "tabOn:Bubble Style/page:1", "tabOn:Bubble Style/page:2"

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "style-look-tabs",
	fixed = { client = client },
	dims = {
		{ "page", { "on", "off" } },
		{ "bubbles", { "on", "off" } },
		{ "behind", { "on", "off" } },
	},
	cell = function(c)
		db.styleGeneral, db.bubblesStyle = true, c.page == "on"
		db[TAB1], db[TAB2] = c.bubbles == "on", c.behind == "on"
		db.bubblesBack, db.speechBehindScale = "dark", 0.5
		local look = ns.BubbleLook()
		local out = ("bubble=%s behind=%s"):format(look.bubblesBack == "dark" and "ours" or "game",
			tonumber(look.speechBehindScale) == 0.5 and "ours" or "game")
		db[TAB1], db[TAB2], db.bubblesStyle = true, true, true
		db.bubblesBack, db.speechBehindScale = "game", 1
		return out
	end,
	pins = {
		{ "", "bubble=game behind=game" },
		{ "page=on bubbles=on behind=on", "bubble=ours behind=ours" },
		{ "page=on bubbles=on behind=off", "bubble=ours behind=game" },
		{ "page=on bubbles=off behind=on", "bubble=game behind=ours" },
	},
})
