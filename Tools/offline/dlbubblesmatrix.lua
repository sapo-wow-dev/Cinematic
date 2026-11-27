-- Chat bubbles with DaylightUI's chat on (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-26-daylight-bubbles.md):
--   python -I Tools/offline/run.py Tools/offline/dlbubblesmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/dlbubblesmatrix.lua forever --base <ref>
-- Its chat part on for this character as our pages are made (it loads after
-- us); then DaylightUI not loaded yet, or loaded with its Chat bubbles toggle
-- not read yet (its module comes on at login), on, or off; and the Chat Bubble
-- Style page's switch on or off. Each cell: whether our bubble look applies
-- (ns.StyleOn) and whether the page is made.
-- The rule (2026-11-26): while DaylightUI draws its bubbles (or may: not known
-- yet), ours stands aside; with its toggle off, ours applies as before c65bdfc.
-- The page stays out either way: it's made as we load, before DaylightUI's
-- saved settings are there to say.
local client = arg and arg[1] or "forever"
local ENABLED = { DaylightUI = true, DaylightUI_Chat = true }
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function()
	rawset(C_AddOns, "GetAddOnEnableState", function(name, character)
		if character ~= nil then return 0 end -- (with a character: wrong on Forever)
		return ENABLED[name] and 2 or 0
	end)
	rawset(C_AddOns, "IsAddOnLoadable", function(name) return ENABLED[name] == true end)
end)
local db = ns.db
db.styleGeneral = true

local chat = {}
local dui = {
	Get = function(_, scope, path)
		if scope == "Chat" then return chat[path] end -- (not "and chat[path] or nil": false would read nil)
		return nil
	end,
	GetModule = function() return nil end,
}

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "dl-bubbles",
	fixed = { client = client },
	dims = {
		{ "dui", { "notyet", "loaded" } },
		{ "theirs", { "unread", "on", "off" } },
		{ "page", { "on", "off" } },
	},
	cell = function(c)
		rawset(_G, "DaylightUI", c.dui == "loaded" and dui or nil)
		chat.bubbles = ({ unread = nil, on = true, off = false })[c.theirs]
		db.bubblesStyle = c.page == "on"
		local look = ns.StyleOn("bubblesStyle") and "on" or "off"
		local made = ns.PageGone("Bubble Style") and "gone" or "made"
		return ("look=%s page=%s"):format(look, made)
	end,
	pins = {
		-- (Its bubbles drawn, or not known yet: ours stands aside, no page.)
		{ "", "look=off page=gone" },
		-- (Its Chat bubbles toggle off: ours, as before c65bdfc. The page can't
		-- follow: made before its saved settings load.)
		{ "dui=loaded theirs=off page=on", "look=on page=gone" },
	},
})
rawset(_G, "DaylightUI", nil)
