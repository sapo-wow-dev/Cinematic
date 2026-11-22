-- The settings defaults that pages made on first open (Options.lua's lazyPages)
-- make as they're built: their tabs' switches (tabOn:...). Put into DEFAULTS
-- here, as the files load, so profiles, sharing and Reset carry them before
-- the page has ever been opened. Made by Tools/offline/lazyaudit.lua --write
-- (each client's list); its check fails when a page's build makes one not here.
-- Data only.
local _, ns = ...

ns.LAZY_PAGE_DEFAULTS = {
	-- forever: start
	forever = {
		["tabOn:Chat/page:2"] = true,
		["tabOn:Chat/page:3"] = true,
		["tabOn:Chat/page:4"] = true,
		["tabOn:Chat/page:5"] = true,
		["tabOn:Graphics+/tab:1"] = true,
		["tabOn:Graphics+/tab:2"] = true,
		["tabOn:Graphics+/tab:3"] = true,
		["tabOn:Graphics+/tab:4"] = true,
		["tabOn:Graphics+/tab:5"] = true,
		["tabOn:Nameplates:Enemy"] = true,
		["tabOn:Nameplates:Friendly"] = true,
		["tabOn:Nameplates:Instances"] = true,
		["tabOn:Nameplates:Names"] = true,
		["tabOn:Nameplates:NamesExtras"] = true,
		["tabOn:Nameplates:NamesPlayers"] = true,
		["tabOn:Nameplates:NamesService"] = true,
		["tabOn:Nameplates:Parts"] = true,
		["tabOn:Nameplates:Target"] = true,
	},
	-- forever: end
	-- retail: start
	retail = {
		["tabOn:Chat/page:2"] = true,
		["tabOn:Chat/page:3"] = true,
		["tabOn:Chat/page:4"] = true,
		["tabOn:Chat/page:5"] = true,
		["tabOn:Graphics+/tab:1"] = true,
		["tabOn:Graphics+/tab:2"] = true,
		["tabOn:Graphics+/tab:3"] = true,
		["tabOn:Graphics+/tab:4"] = true,
		["tabOn:Graphics+/tab:5"] = true,
		["tabOn:Nameplates:Enemy"] = true,
		["tabOn:Nameplates:Friendly"] = true,
		["tabOn:Nameplates:Instances"] = true,
		["tabOn:Nameplates:Names"] = true,
		["tabOn:Nameplates:NamesExtras"] = true,
		["tabOn:Nameplates:NamesPlayers"] = true,
		["tabOn:Nameplates:NamesService"] = true,
		["tabOn:Nameplates:Parts"] = true,
		["tabOn:Nameplates:Target"] = true,
	},
	-- retail: end
}

local list = ns.LAZY_PAGE_DEFAULTS[ns.isRetail and "retail" or "forever"]
for key, value in pairs(list or {}) do
	if ns.DEFAULTS[key] == nil then ns.DEFAULTS[key] = value end
end
